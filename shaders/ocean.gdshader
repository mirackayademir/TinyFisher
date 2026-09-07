shader_type canvas_item;

void fragment() {
	vec2 uv = UV;
	vec2 suv = SCREEN_UV;
	float t = TIME;

	// Daha sade, Cat Goes Fishing hissine yakın ama özgün deniz paleti.
	float depth = clamp(uv.y, 0.0, 1.0);
	vec3 top_color = vec3(0.055, 0.45, 0.64);
	vec3 mid_color = vec3(0.025, 0.24, 0.40);
	vec3 deep_color = vec3(0.010, 0.085, 0.18);

	vec3 water = mix(top_color, mid_color, smoothstep(0.0, 0.48, depth));
	water = mix(water, deep_color, smoothstep(0.42, 1.0, depth));

	// Sakin, geniş yatay su katmanları.
	float band_a = sin(depth * 28.0 + suv.x * 8.0 - t * 0.55);
	float band_b = sin(depth * 48.0 - suv.x * 11.0 + t * 0.38);
	water += vec3(0.018, 0.052, 0.072) * band_a * (1.0 - depth * 0.55);
	water += vec3(0.010, 0.030, 0.045) * band_b * 0.55;

	// Yüzeyden aşağı doğru çok hafif ışık huzmeleri.
	float ray = sin(suv.x * 21.0 + t * 0.34) * 0.5 + 0.5;
	ray *= sin(suv.x * 11.0 - t * 0.22) * 0.5 + 0.5;
	water += vec3(0.035, 0.095, 0.11) * ray * (1.0 - smoothstep(0.0, 0.68, depth));

	// Üst çizgide hareketli dalga/köpük görünümü.
	float wave_y = 0.012
		+ sin(suv.x * 31.0 + t * 1.65) * 0.0045
		+ sin(suv.x * 67.0 - t * 1.05) * 0.0022;
	float crest_dist = abs(uv.y - wave_y);
	float crest = 1.0 - smoothstep(0.0015, 0.0085, crest_dist);
	float crest_break = 0.72 + 0.28 * (sin(suv.x * 73.0 + t * 2.0) * 0.5 + 0.5);
	water = mix(water, vec3(0.78, 0.94, 0.96), crest * crest_break * 0.88);

	// Dalganın hemen altındaki koyu gölge su yüzeyini daha hacimli gösterir.
	float under_wave = 1.0 - smoothstep(0.010, 0.034, abs(uv.y - wave_y - 0.015));
	water = mix(water, vec3(0.025, 0.23, 0.36), under_wave * 0.22);

	// Pixel-art görünümü için sınırlı renk adımları.
	water = floor(clamp(water, 0.0, 1.0) * 28.0) / 28.0;
	COLOR = vec4(water, 1.0);
}
