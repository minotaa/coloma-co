shader_type canvas_item;

uniform vec3 shock_color : source_color = vec3(1.0, 0.0, 0.0);
uniform float amplitude = 30.0;
uniform float frequency = 10.0;
uniform float shock_time = 0.0; // Controlled from GDScript

void vertex() {
	float decay = exp(-3.0 * shock_time);
	VERTEX.x += amplitude * decay * sin(frequency * shock_time);
}

void fragment() {
	float decay = exp(-3.0 * shock_time);
	vec3 normal_color = texture(TEXTURE, UV).rgb;
	COLOR.rgb = normal_color + shock_color * decay;
}