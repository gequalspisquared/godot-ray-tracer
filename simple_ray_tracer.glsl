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

struct Camera {
    float focal_length;
    float viewport_height;
    float viewport_width;
    vec3 center;
};

vec3 at(Ray ray, float t) {
    return ray.origin + ray.direction*t;
}

vec4 ray_color(Ray ray) {
    return vec4(0.0, 0.0, 0.0, 1.0);
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

    return camera;
}

void main() {
    Camera camera = create_camera();
    ivec2 screen_size  = imageSize(output_texture);
    float image_width  = float(screen_size.x);
    float image_height = float(screen_size.y);

    vec4 color = vec4(
        gl_GlobalInvocationID.x / (image_width - 1),
        gl_GlobalInvocationID.y / (image_height - 1),
        0.0,
        1.0
    );
    ivec2 texel = ivec2(gl_GlobalInvocationID.xy);
    imageStore(output_texture, texel, color);
}