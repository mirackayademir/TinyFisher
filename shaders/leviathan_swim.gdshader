shader_type canvas_item;

// Abyssal Leviathan icin ozel yuzme shader'i.
// Gorselin dogal halinde kafa solda, kuyruk sagda.
uniform float tail_strength = 14.0;
uniform float tail_speed = 2.6;
uniform float body_strength = 3.4;

void vertex() {
	float x = UV.x;
	float phase = TIME * tail_speed;

	// Govdeyi kafa tarafinda sakin tutup arkaya dogru giderek daha fazla kivir.
	float body_mask = smoothstep(0.10, 0.88, x);
	float body_wave = sin(phase * 0.52 + x * 4.8 + 0.55);

	// Kuyruk son %40'lik bolgede belirgin sekilde calisir.
	float tail_mask = pow(smoothstep(0.58, 1.0, x), 1.7);
	float tail_wave = sin(phase + x * 9.5);

	VERTEX.y += body_wave * body_strength * body_mask;
	VERTEX.y += tail_wave * tail_strength * tail_mask;

	// Cok hafif yatay esneme: karton gibi tek parca sallanma hissini azaltir.
	VERTEX.x += cos(phase * 0.48 + x * 4.0) * body_strength * 0.16 * body_mask;
}

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	float shimmer = 0.97 + 0.03 * sin(TIME * 1.7 + SCREEN_UV.y * 31.0 + SCREEN_UV.x * 11.0);
	float depth_tint = clamp((SCREEN_UV.y - 0.38) * 0.30, 0.0, 0.14);
	vec3 underwater_tint = mix(tex.rgb, vec3(0.025, 0.22, 0.34), 0.08 + depth_tint);
	COLOR = vec4(underwater_tint * shimmer, tex.a) * COLOR;
}
