shader_type canvas_item;

uniform float progress : hint_range(0.0, 1.0) = 0.0;

void fragment() {
    // Convert UV to center-based coordinates (-1 to 1)
    vec2 center_uv = (UV - 0.265) * 1.5;
    
    // Calculate distance from center
    float dist = length(center_uv);
    
    // Create circular mask
    float circle_radius = 1.0 - progress;
    float mask = smoothstep(circle_radius - 0.01, circle_radius + 0.01, dist);
    
    // Output black with the circular mask
    COLOR = vec4(0.0, 0.0, 0.0, mask);
}