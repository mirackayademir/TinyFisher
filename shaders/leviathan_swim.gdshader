shader_type canvas_item;

// Abyssal Leviathan icin gercek gorunen texture deformasyonu.
// Sprite2D sadece 4 vertexli bir quad oldugu icin vertex shader ile gercek govde/kuyruk
// kivrilmasi elde edilemiyordu. Bu surum UV'yi piksel bazinda buker.
// Gorselin dogal halinde kafa solda, kuyruk sagda.
uniform float tail_strength = 0.060;
uniform float tail_speed = 3.0;
uniform float body_strength = 0.018;

void fragment() {
	float x = UV.x;
	float phase = TIME * tail_speed;

	// Kafa tarafini sakin tut, govde arkaya dogru yumusakca esnesin.
	float body_mask = smoothstep(0.16, 0.86, x);
	float body_wave = sin(phase * 0.55 + x * 5.2 + 0.55);

	// Kuyruk son bolgede cok daha kuvvetli calisir.
	float tail_mask = pow(smoothstep(0.48, 1.0, x), 1.55);
	float tail_wave = sin(phase + x * 10.5);

	vec2 warped_uv = UV;
	warped_uv.y += body_wave * body_strength * body_mask;
	warped_uv.y += tail_wave * tail_strength * tail_mask;

	// Hafif yatay sikisma/acilma; duz karton hissini azaltir.
	warped_uv.x += cos(phase * 0.62 + x * 6.0) * 0.006 * tail_mask;

	// KRITIK FIX: UV sinir disina cikinca texture diger kenardan tekrar etmesin.
	// Onceki durumda kuyruk x>1.0 oldugunda kafa/fenerdeki kirmizi pikseller
	// kuyruk ucunda tekrar gorunup sahte bir kirmizi parlama olusturuyordu.
	float inside_x = step(0.0, warped_uv.x) * step(warped_uv.x, 1.0);
	float inside_y = step(0.0, warped_uv.y) * step(warped_uv.y, 1.0);
	float inside = inside_x * inside_y;
	vec2 safe_uv = clamp(warped_uv, vec2(0.001), vec2(0.999));
	vec4 tex = texture(TEXTURE, safe_uv) * inside;

	float shimmer = 0.97 + 0.03 * sin(TIME * 1.7 + SCREEN_UV.y * 31.0 + SCREEN_UV.x * 11.0);
	float depth_tint = clamp((SCREEN_UV.y - 0.38) * 0.30, 0.0, 0.14);
	vec3 underwater_tint = mix(tex.rgb, vec3(0.025, 0.22, 0.34), 0.08 + depth_tint);
	COLOR = vec4(underwater_tint * shimmer, tex.a) * COLOR;
}
