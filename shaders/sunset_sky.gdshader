shader_type canvas_item;

void fragment() {
	vec2 uv = SCREEN_UV;

	vec3 top = vec3(0.20, 0.10, 0.32);
	vec3 mid = vec3(0.72, 0.25, 0.34);
	vec3 horizon = vec3(1.00, 0.56, 0.24);

	float vertical = clamp(uv.y / 0.58, 0.0, 1.0);
	vec3 sky = mix(top, mid, smoothstep(0.0, 0.58, vertical));
	sky = mix(sky, horizon, smoothstep(0.48, 1.0, vertical));

	// Pixel-art renk bantları.
	sky = floor(sky * 22.0) / 22.0;

	// Gün batımı güneşi.
	vec2 sun_pos = vec2(0.78, 0.43);
	float sun_dist = length((uv - sun_pos) * vec2(1.0, 1.65));
	float sun = 1.0 - step(0.085, sun_dist);
	vec3 sun_color = vec3(1.0, 0.82, 0.38);
	sky = mix(sky, sun_color, sun);

	// Ufukta yatay pixel bulut şeritleri.
	float cloud_a = step(0.72, sin(uv.x * 46.0 + 0.8)) * step(abs(uv.y - 0.23), 0.025);
	float cloud_b = step(0.50, sin(uv.x * 31.0 + 2.1)) * step(abs(uv.y - 0.31), 0.018);
	float cloud_c = step(0.82, sin(uv.x * 57.0 + 4.2)) * step(abs(uv.y - 0.16), 0.015);
	float clouds = clamp(cloud_a + cloud_b + cloud_c, 0.0, 1.0);
	vec3 cloud_color = mix(vec3(0.40, 0.17, 0.36), vec3(0.94, 0.39, 0.31), uv.y * 1.7);
	sky = mix(sky, cloud_color, clouds * 0.72);

	// İnce gün batımı parıltısı.
	float glow = max(0.0, 1.0 - length((uv - sun_pos) * vec2(0.72, 1.4)) * 2.7);
	sky += vec3(0.16, 0.07, 0.02) * glow;

	COLOR = vec4(sky, 1.0);
}
