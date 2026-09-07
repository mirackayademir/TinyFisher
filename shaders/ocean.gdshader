shader_type canvas_item;

void fragment() {
	vec2 suv = SCREEN_UV;
	vec2 uv = UV;
	float t = TIME;

	// Daha canlı ama derinleştikçe sakinleşen deniz paleti.
	float depth = clamp(uv.y * 1.18, 0.0, 1.0);
	vec3 surface_color = vec3(0.025, 0.46, 0.66);
	vec3 mid_color = vec3(0.018, 0.25, 0.43);
	vec3 deep_color = vec3(0.008, 0.065, 0.16);
	vec3 water = mix(surface_color, mid_color, smoothstep(0.0, 0.48, depth));
	water = mix(water, deep_color, smoothstep(0.42, 1.0, depth));

	// Birbirinden farklı hızlarda akan dalga katmanları.
	float long_wave = sin(suv.x * 34.0 + t * 1.55 + sin(suv.x * 8.0 - t * 0.55) * 1.1);
	float medium_wave = sin(suv.x * 71.0 - t * 2.15 + suv.y * 17.0);
	float short_wave = sin((suv.x * 1.35 + suv.y * 0.45) * 108.0 + t * 3.1);
	float wave_mix = long_wave * 0.52 + medium_wave * 0.31 + short_wave * 0.17;
	water += vec3(0.025, 0.095, 0.13) * wave_mix * (1.0 - depth * 0.72);

	// Gün batımının kırık, titreşen sıcak yansıması.
	float reflection_lane = 1.0 - smoothstep(0.035, 0.22, abs(suv.x - 0.76));
	float reflection_noise = sin(suv.x * 143.0 + t * 2.4) + sin(suv.y * 89.0 - t * 1.9);
	float reflection_bits = smoothstep(0.45, 1.25, reflection_noise);
	water += vec3(0.34, 0.13, 0.035) * reflection_lane * reflection_bits * (1.0 - depth) * 0.78;

	// Su altındaki hareketli ışık kırılmaları.
	float ca = sin(suv.x * 67.0 + suv.y * 35.0 + t * 1.8 + sin(suv.y * 21.0));
	float cb = sin(suv.x * 44.0 - suv.y * 51.0 - t * 1.25);
	float cc = sin((suv.x - suv.y) * 92.0 + t * 0.85);
	float caustic = smoothstep(1.28, 2.05, ca + cb + cc * 0.42);
	water += vec3(0.055, 0.19, 0.22) * caustic * (1.0 - depth * 0.72);

	// Yüzeye yakın birkaç farklı köpüklü dalga sırası.
	float surface_mask = 1.0 - smoothstep(0.0, 0.075, uv.y);
	float crest_a = smoothstep(0.63, 0.88, sin(suv.x * 76.0 + t * 2.55 + sin(suv.x * 17.0) * 0.8) * 0.5 + 0.5);
	float crest_b = smoothstep(0.72, 0.94, sin(suv.x * 119.0 - t * 2.0 + 1.4) * 0.5 + 0.5);
	float crest = max(crest_a * 0.82, crest_b * 0.62);
	water = mix(water, vec3(0.80, 0.96, 0.98), crest * surface_mask * 0.86);

	// Çok hafif askıdaki parçacık hissi; balıklar boş bir renk bloğunda durmasın.
	float speck = step(0.986, fract(sin(dot(floor(suv * vec2(320.0, 190.0)), vec2(12.9898, 78.233))) * 43758.5453));
	water += vec3(0.08, 0.14, 0.17) * speck * (0.35 + depth * 0.35);

	// Pixel-art paletini koru.
	water = floor(clamp(water, 0.0, 1.0) * 30.0) / 30.0;
	COLOR = vec4(water, 1.0);
}
