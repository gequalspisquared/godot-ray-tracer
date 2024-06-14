#[compute]
#version 460

// Invocations
layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

layout(push_constant, std430) uniform PushConstants {
    float time;
};

// Image buffer in
layout(set = 0, binding = 0, rgba32f) uniform image2D output_texture;

// Types
struct Ray {
    vec3 origin;
    vec3 direction;
};

vec3 at(Ray ray, float t) {
    return ray.origin + ray.direction*t;
}

void main() {
    ivec2 screen_size = imageSize(output_texture);
    float w = float(screen_size.x);
    float h = float(screen_size.y);

    vec4 color = vec4(
        gl_GlobalInvocationID.x / (w - 1),
        gl_GlobalInvocationID.y / (h - 1),
        0.0,
        1.0
    );
    ivec2 texel = ivec2(gl_GlobalInvocationID.xy);
    imageStore(output_texture, texel, color);
}