shader_type canvas_item;

void fragment() {
	vec2 uv = SCREEN_UV;
	float t = TIME;

	float depth = clamp((uv.y - 0.34) / 0.66, 0.0, 1.0);
	vec3 shallow = vec3(0.03, 0.42, 0.62);
	vec3 deep = vec3(0.015, 0.10, 0.24);
	vec3 water = mix(shallow, deep, depth);

	// Hareketli dalga katmanları.
	float wave1 = sin(uv.x * 48.0 + t * 2.4 + sin(uv.x * 13.0 - t) * 0.7);
	float wave2 = sin(uv.x * 83.0 - t * 1.7 + uv.y * 19.0);
	float wave3 = sin((uv.x + uv.y) * 36.0 + t * 1.25);
	float wave_mix = wave1 * 0.55 + wave2 * 0.30 + wave3 * 0.15;

	water += vec3(0.025, 0.085, 0.11) * wave_mix * (1.0 - depth * 0.55);

	// Gün batımının denizdeki sıcak yansıması.
	float reflection_lane = 1.0 - smoothstep(0.04, 0.23, abs(uv.x - 0.78));
	float reflection_flicker = step(0.52, sin(uv.x * 165.0 + uv.y * 93.0 + t * 3.0));
	water += vec3(0.24, 0.10, 0.025) * reflection_lane * reflection_flicker * (1.0 - depth) * 0.65;

	// Su altı ışık çizgileri / caustics.
	float caustic_a = sin(uv.x * 72.0 + t * 1.8 + sin(uv.y * 31.0));
	float caustic_b = sin(uv.x * 46.0 - t * 1.2 - uv.y * 44.0);
	float caustic = smoothstep(1.05, 1.55, caustic_a + caustic_b);
	water += vec3(0.03, 0.13, 0.16) * caustic * (0.9 - depth * 0.6);

	// Pixel-art hissi için renkleri hafif kuantize et.
	water = floor(water * 26.0) / 26.0;

	// Yüzeye yakın beyaz köpük çizgileri.
	float surface_mask = 1.0 - smoothstep(0.0, 0.045, depth);
	float foam = smoothstep(0.54, 0.86, sin(uv.x * 96.0 + t * 3.2) * 0.5 + 0.5);
	water = mix(water, vec3(0.78, 0.94, 0.96), foam * surface_mask * 0.72);

	COLOR = vec4(water, 1.0);
}
