#[compute]
#version 460

// Invocations
layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

layout(push_constant, std430) uniform PushConstants {
    float time;
};

// Image buffer in
layout(set = 0, binding = 0, rgba32f) uniform restrict writeonly image2D output_texture;

// Types
struct Ray {
    vec3 origin;
    vec3 direction;
};

struct HitRecord {
    vec3 point;
    vec3 normal;
    float t;
    bool front_face;
};

void hit_record_set_normal_face(inout HitRecord record, Ray ray, vec3 outward_normal) {
    record.front_face = dot(ray.direction, outward_normal) < 0.0;
    record.normal = record.front_face ? outward_normal : -outward_normal;
}

struct Sphere {
    // vec4 data; // xyz is center, w is radius
    vec3 center;
    float radius;
};

layout(set = 1, binding = 0, std430) restrict buffer WorldSpheres {
    int num_spheres;
    int padding[3];
    Sphere spheres[];
} world_spheres;

struct Interval {
    float min;
    float max;
};

float interval_size(Interval interval) {
    return interval.max - interval.min;
}

bool interval_contains(Interval interval, float x) {
    return interval.min <= x && x <= interval.max;
}

bool interval_surrounds(Interval interval, float x) {
    return interval.min < x && x < interval.max;
}

float interval_clamp(Interval interval, float x) {
    return clamp(x, interval.min, interval.max);
}

struct Camera {
    float focal_length;
    float viewport_height;
    float viewport_width;
    vec3 viewport_u;
    vec3 viewport_v;
    vec3 pixel_delta_u;
    vec3 pixel_delta_v;
    vec3 center;
    vec3 viewport_upper_left;
    vec3 pixel00_loc;
};

float rand(vec2 co) {
    return fract(sin(dot(co, vec2(12.9898, 78.233))) * 43758.5453);
}

float rand_range(vec2 co, float min, float max) {
    return min + (max - min)*rand(co);
}

vec3 rand_square(vec2 co) {
    return vec3(rand(co), rand(co + vec2(1.0, 1.0)), 0.0);
}

vec3 at(Ray ray, float t) {
    return ray.origin + ray.direction*t;
}

bool hit_sphere(Sphere sphere, Ray ray, Interval ray_t, inout HitRecord record) {
    vec3 oc = sphere.center - ray.origin;
    float a = dot(ray.direction, ray.direction);
    float h = dot(ray.direction, oc);
    float c = dot(oc, oc) - sphere.radius*sphere.radius;
    float discriminant = h*h - a*c;

    if (discriminant < 0.0) {
        return false;
    } 

    float sqrtd = sqrt(discriminant);

    float root = (h - sqrtd) / a;
    if (!interval_surrounds(ray_t, root)) {
        root = (h + sqrtd) / a;
        if (!interval_surrounds(ray_t, root)) {
            return false;
        }
    }

    record.t = root;
    record.point = at(ray, record.t);
    vec3 outward_normal = (record.point - sphere.center) / sphere.radius;
    hit_record_set_normal_face(record, ray, outward_normal);

    return true;
}

bool world_hit(Ray ray, Interval ray_t, inout HitRecord record) {
    HitRecord temp_record;
    bool hit_anything = false;
    float closest_so_far = ray_t.max;

    for (int i = 0; i < world_spheres.num_spheres; i++) {
        if (hit_sphere(world_spheres.spheres[i], ray, Interval(ray_t.min, closest_so_far), temp_record)) {
            hit_anything = true;
            closest_so_far = temp_record.t;
            record = temp_record;
        }
    }

    return hit_anything;
}

vec4 ray_color(Ray ray) {
    HitRecord record;
    if (world_hit(ray, Interval(0.0, 1000.0), record)) {
        return vec4(0.5*(record.normal + vec3(1.0, 1.0, 1.0)), 1.0);
    }

    vec3 dir = normalize(ray.direction);
    float a = 0.5*(dir.y + 1.0);
    vec3 b = (1.0 - a) * vec3(1.0, 1.0, 1.0) + a*vec3(0.5, 0.7, 1.0);
    return vec4(b, 1.0);
}

Ray get_ray(Camera camera, int i) {
    vec3 offset = rand_square(gl_GlobalInvocationID.xy * i);
    vec3 pixel_sample = camera.pixel00_loc + ((offset.x + gl_GlobalInvocationID.x) * camera.pixel_delta_u)
                                           + ((offset.y + gl_GlobalInvocationID.y) * camera.pixel_delta_v);
    vec3 ray_dir = pixel_sample - camera.center;
    Ray ray = {camera.center, ray_dir};

    return ray;
}

Camera create_camera() {
    Camera camera;

    ivec2 screen_size  = imageSize(output_texture);
    float image_width  = float(screen_size.x);
    float image_height = float(screen_size.y);
    float aspect_ratio = image_width / image_height;

    camera.focal_length = 1.0;

    camera.viewport_height = 2.0;
    camera.viewport_width  = camera.viewport_height*aspect_ratio;
    camera.center = vec3(0.0, 0.0, 0.0);

    camera.viewport_u = vec3(camera.viewport_width, 0.0, 0.0);
    camera.viewport_v = vec3(0.0, -camera.viewport_height, 0.0);

    camera.pixel_delta_u = camera.viewport_u / image_width;
    camera.pixel_delta_v = camera.viewport_v / image_height;

    camera.viewport_upper_left = camera.center - vec3(0.0, 0.0, camera.focal_length) -
                                 camera.viewport_u / 2.0 - camera.viewport_v / 2.0;
    camera.pixel00_loc = camera.viewport_upper_left + 0.5*(camera.pixel_delta_u + camera.pixel_delta_v);

    return camera;
}

void main() {
    // Config stuff
    int samples_per_pixel = 10;

    float pixel_samples_scale = 1.0 / samples_per_pixel;

    Camera camera = create_camera();
    ivec2 screen_size  = imageSize(output_texture);

    vec4 color = vec4(0.0, 0.0, 0.0, 0.0);
    for (int i = 0; i < samples_per_pixel; i++) {
        Ray ray = get_ray(camera, i);
        color += ray_color(ray);
    }
    color *= pixel_samples_scale;
    ivec2 texel = ivec2(gl_GlobalInvocationID.xy);
    imageStore(output_texture, texel, color);
}