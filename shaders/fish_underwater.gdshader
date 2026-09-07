shader_type canvas_item;

uniform float tail_strength = 32.0;
uniform float tail_speed = 6.0;
uniform float body_strength = 5.0;

void vertex() {
	// Balığın kuyruğu (sol taraf) daha çok, kafa tarafı çok az esner.
	float tail_mask = pow(1.0 - UV.x, 2.4);
	float body_mask = smoothstep(0.18, 0.78, 1.0 - abs(UV.x - 0.52) * 1.7);
	float tail_wave = sin(TIME * tail_speed + UV.x * 10.0);
	float body_wave = sin(TIME * tail_speed * 0.52 + UV.x * 5.0 + 0.8);
	VERTEX.y += tail_wave * tail_strength * tail_mask;
	VERTEX.y += body_wave * body_strength * body_mask;
}

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	float shimmer = 0.965 + 0.035 * sin(TIME * 2.2 + SCREEN_UV.y * 36.0 + SCREEN_UV.x * 15.0);
	float depth_tint = clamp((SCREEN_UV.y - 0.38) * 0.35, 0.0, 0.16);
	vec3 underwater_tint = mix(tex.rgb, vec3(0.035, 0.30, 0.46), 0.10 + depth_tint);
	COLOR = vec4(underwater_tint * shimmer, tex.a) * COLOR;
}
