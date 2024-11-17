shader_type spatial;
uniform vec4 eye_color = vec4(0.0, 0.0, 0.0, 1.0);         // Black for the eyes
uniform vec4 eye_highlight_color = vec4(1.0, 1.0, 1.0, 1.0); // White for the highlight
uniform float eye_radius_x = 0.12;
uniform float eye_radius_y = 0.15;
uniform float highlight_radius = 0.07;
uniform vec2 left_eye_position = vec2(0.4, 0.4);
uniform vec2 right_eye_position = vec2(0.95, 0.4);
// Function to calculate elliptical distance
float elliptical_distance(vec2 uv, vec2 center, float radius_x, float radius_y) {
    vec2 delta = uv - center;
    return (delta.x / radius_x) * (delta.x / radius_x) + (delta.y / radius_y) * (delta.y / radius_y);
}
void fragment() {
    vec2 uv = UV;
    // Only render eyes on one side of the UV map
    if (uv.x < 0.0 || uv.x > 0.58) {
        discard;
    }
    vec3 final_color = vec3(0.0); // Start with black color
    float alpha = 0.0; // Start fully transparent
    // Left eye
    float dist_left = elliptical_distance(uv, left_eye_position, eye_radius_x, eye_radius_y);
    if (dist_left < 5.0) {
        final_color = eye_color.rgb;
        alpha = eye_color.a; // Set alpha to 1.0 (fully opaque)
        // Highlight for the left eye
        float dist_left_highlight = length(uv - (left_eye_position + vec2(eye_radius_x * 0.3, -eye_radius_y * 0.3)));
        if (dist_left_highlight < highlight_radius) {
            final_color = eye_highlight_color.rgb;
            alpha = eye_highlight_color.a;
        }
    }
    // Right eye
    float dist_right = elliptical_distance(uv, right_eye_position, eye_radius_x, eye_radius_y);
    if (dist_right < 2.0) {
        final_color = eye_color.rgb;
        alpha = eye_color.a; // Set alpha to 1.0 (fully opaque)
        // Highlight for the right eye
        float dist_right_highlight = length(uv - (right_eye_position + vec2(eye_radius_x * 0.3, -eye_radius_y * 0.3)));
        if (dist_right_highlight < highlight_radius) {
            final_color = eye_highlight_color.rgb;
            alpha = eye_highlight_color.a;
        }
    }
    ALBEDO = final_color;
    ALPHA = alpha;
    // Discard fully transparent pixels
    if (alpha == 0.0) {
        discard;
    }
}