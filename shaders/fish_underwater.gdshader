shader_type canvas_item;

uniform float tail_strength = 32.0;
uniform float tail_speed = 6.0;

void vertex() {
	float tail_mask = pow(1.0 - UV.x, 2.0);
	VERTEX.y += sin(TIME * tail_speed + UV.x * 8.0) * tail_strength * tail_mask;
}

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	float shimmer = 0.96 + 0.04 * sin(TIME * 2.4 + SCREEN_UV.y * 38.0 + SCREEN_UV.x * 16.0);
	vec3 underwater_tint = mix(tex.rgb, vec3(0.05, 0.34, 0.50), 0.11);
	COLOR = vec4(underwater_tint * shimmer, tex.a) * COLOR;
}
