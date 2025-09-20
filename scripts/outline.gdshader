shader_type canvas_item;

uniform vec4 outline_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float outline_size : hint_range(0.1, 5.0) = 1.0;

void fragment() {
    vec4 tex_color = texture(TEXTURE, UV);
    vec4 final_color = tex_color;

    if (tex_color.a == 0.0) {
        vec2 pixel_size = vec2(1.0) / vec2(textureSize(TEXTURE, 0));
        
        // Check 8 surrounding pixels
        for (int i = -1; i <= 1; i++) {
            for (int j = -1; j <= 1; j++) {
                if (i == 0 && j == 0) continue; // skip self
                vec2 offset = vec2(float(i), float(j)) * pixel_size * outline_size;
                vec4 sample = texture(TEXTURE, UV + offset);
                if (sample.a > 0.0) {
                    final_color = outline_color;
                }
            }
        }
    }

    COLOR = final_color;
}
