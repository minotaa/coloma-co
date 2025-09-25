// DitherFade.gdshader
shader_type canvas_item;

uniform float fade_amount : hint_range(0.0, 1.0) = 0.0;
uniform vec3 fade_color : source_color = vec3(0.0, 0.0, 0.0);
uniform float dither_scale : hint_range(1.0, 8.0) = 2.0;

float bayer_dither(vec2 coord) {
    // Simple 4x4 Bayer matrix as array lookups
    int x = int(coord.x) % 4;
    int y = int(coord.y) % 4;
    
    // Bayer 4x4 matrix values (0-15) normalized to 0-1
    float bayer_matrix[16] = float[](
        0.0/16.0, 8.0/16.0, 2.0/16.0, 10.0/16.0,
        12.0/16.0, 4.0/16.0, 14.0/16.0, 6.0/16.0,
        3.0/16.0, 11.0/16.0, 1.0/16.0, 9.0/16.0,
        15.0/16.0, 7.0/16.0, 13.0/16.0, 5.0/16.0
    );
    
    return bayer_matrix[y * 4 + x];
}

void fragment() {
    // Get screen coordinates
    vec2 screen_coord = SCREEN_UV / SCREEN_PIXEL_SIZE * dither_scale;
    
    // Get dither value from Bayer matrix
    float dither_value = bayer_dither(screen_coord);
    
    // Determine if this pixel should be fade color or transparent
    float alpha = step(fade_amount, dither_value);
    
    // Output fade color with calculated alpha
    COLOR = vec4(fade_color, 1.0 - alpha);
}