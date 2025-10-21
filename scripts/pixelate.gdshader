shader_type canvas_item;

uniform float pixel_size : hint_range(1.0, 16.0) = 2.0;

void fragment() {
	// Pixelate the screen coordinates
	vec2 pixelated_uv = floor(FRAGCOORD.xy / pixel_size) * pixel_size;
	pixelated_uv = pixelated_uv / SCREEN_PIXEL_SIZE;
	
	// Use the pixelated coordinates
	vec2 local_uv = (pixelated_uv - SCREEN_UV * SCREEN_PIXEL_SIZE) / SCREEN_PIXEL_SIZE;
	
	// Apply the color
	COLOR = COLOR;
	
	// Snap the position
	vec2 snapped = floor(UV * vec2(1.0 / pixel_size)) * pixel_size;
	if (distance(UV, snapped) > pixel_size * 0.5) {
		COLOR.a = 0.0;
	}
}
