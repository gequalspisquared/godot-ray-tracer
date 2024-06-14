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

struct Sphere {
    vec3 center;
    float radius;
};

layout(set = 1, binding = 0, std430) restrict buffer WorldSpheres {
    Sphere spheres[];
} world_spheres;

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

vec3 at(Ray ray, float t) {
    return ray.origin + ray.direction*t;
}

float hit_sphere(Sphere sphere, Ray ray) {
    vec3 oc = sphere.center - ray.origin;
    float a = dot(ray.direction, ray.direction);
    float h = dot(ray.direction, oc);
    float c = dot(oc, oc) - sphere.radius*sphere.radius;
    float discriminant = h*h - a*c;

    if (discriminant < 0.0) {
        return -1.0;
    } else {
        return (h - sqrt(discriminant)) / a;
    }
}

vec4 ray_color(Ray ray) {
    // vec3 center = vec3(0.0, 0.0, -1.0);
    // Sphere sphere = {center, 0.5};
    // float t = hit_sphere(sphere, ray);
    Sphere sphere = world_spheres.spheres[0];
    vec3 center = sphere.center;
    float t = hit_sphere(sphere, ray);
    if (t > 0.0) {
        vec3 normal = normalize(at(ray, t) - center);
        return vec4(0.5*(normal + vec3(1.0, 1.0, 1.0)), 1.0);
    }

    vec3 dir = normalize(ray.direction);
    float a = 0.5*(dir.y + 1.0);
    vec3 b = (1.0 - a) * vec3(1.0, 1.0, 1.0) + a*vec3(0.5, 0.7, 1.0);
    return vec4(b, 1.0);
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
    Camera camera = create_camera();
    ivec2 screen_size  = imageSize(output_texture);
    float image_width  = float(screen_size.x);
    float image_height = float(screen_size.y);

    vec3 pixel_center = camera.pixel00_loc + (gl_GlobalInvocationID.x * camera.pixel_delta_u)
                                           + (gl_GlobalInvocationID.y * camera.pixel_delta_v);
    vec3 ray_dir = pixel_center - camera.center;
    Ray ray = {camera.center, ray_dir};

    vec4 color = ray_color(ray);
    ivec2 texel = ivec2(gl_GlobalInvocationID.xy);
    imageStore(output_texture, texel, color);
}