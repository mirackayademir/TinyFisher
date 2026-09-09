extends Node

# Balik gorsel duzeltmeleri + Leviathan test gorseli.
# Onayli WebP dosyalari bozuk oldugu icin mevcut SVG'lere guvenli geri donus yapilir.
# Leviathan testi ise dogrudan Sprite2D olarak denize eklenir; fish.gd/autoload/boss
# mantigina bagli degildir. Boylece once gorselin oyunda kesin gorundugunu dogrulariz.

const KILIC_OLD: String = "res://assets/kilic_baligi.svg"
const KOPEK_OLD: String = "res://assets/kopekbaligi.svg"
const FENER_OLD: String = "res://assets/fener_baligi.svg"
const LEVIATHAN_TEXTURE_PATH: String = "res://assets/leviathan.webp"

const SCAN_INTERVAL: float = 0.10
const BAIT_SCALE: Vector2 = Vector2(0.72, 0.72)
const BAIT_HOOK_OFFSET: Vector2 = Vector2(3.5, 7.0)

# TEST: Baslangicta teknenin sol-alt tarafinda, ekranda gorunecek konum.
const LEVIATHAN_TEST_OFFSET: Vector2 = Vector2(-360.0, 250.0)
const LEVIATHAN_TEST_SCALE: Vector2 = Vector2(0.75, 0.75)

# Leviathan doğal yüzüş ayarları.
const LEVIATHAN_SWIM_RANGE_X: float = 170.0
const LEVIATHAN_SWIM_CYCLE_SPEED: float = 0.42
const LEVIATHAN_BOB_HEIGHT: float = 10.0
const LEVIATHAN_TURN_SPEED_THRESHOLD: float = 7.0

# Görsel üzerindeki fener ve göz konumları texture boyutuna oranlı tutulur.
# Böylece asset çözünürlüğü değişse bile ışıklar doğru bölgeye yakın kalır.
const LEVIATHAN_LURE_X_RATIO: float = 0.466
const LEVIATHAN_LURE_Y_RATIO: float = -0.047
const LEVIATHAN_EYE_X_RATIO: float = 0.248
const LEVIATHAN_EYE_Y_RATIO: float = -0.095

var _scan_timer: float = 0.0
var _time: float = 0.0
var _kilic_approved: Texture2D = null
var _kopek_approved: Texture2D = null
var _fener_approved: Texture2D = null
var _leviathan_texture: Texture2D = null
var _leviathan_sprite: Sprite2D = null
var _leviathan_origin: Vector2 = Vector2.ZERO
var _leviathan_facing_right: bool = true
var _leviathan_glow_texture: Texture2D = null
var _leviathan_lure_glow: Sprite2D = null
var _leviathan_eye_glow: Sprite2D = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_priority = 100
	_load_safe_textures()
	_load_leviathan_texture()
	_apply_to_current_scene()
	_align_bait_to_hook()


func _process(delta: float) -> void:
	_time += delta
	_ensure_leviathan_test()
	_ensure_leviathan_glows()
	_animate_leviathan_test()
	_update_leviathan_glows()
	_align_bait_to_hook()

	_scan_timer -= delta
	if _scan_timer > 0.0:
		return
	_scan_timer = SCAN_INTERVAL
	_apply_to_current_scene()


func _load_safe_textures() -> void:
	_kilic_approved = load(KILIC_OLD) as Texture2D
	_kopek_approved = load(KOPEK_OLD) as Texture2D
	_fener_approved = load(FENER_OLD) as Texture2D


func _load_leviathan_texture() -> void:
	if _leviathan_texture != null:
		return
	if not ResourceLoader.exists(LEVIATHAN_TEXTURE_PATH):
		push_error("LEVIATHAN TEST: texture bulunamadi: " + LEVIATHAN_TEXTURE_PATH)
		return

	_leviathan_texture = load(LEVIATHAN_TEXTURE_PATH) as Texture2D
	if _leviathan_texture == null:
		push_error("LEVIATHAN TEST: texture yuklenemedi: " + LEVIATHAN_TEXTURE_PATH)
		return

	print("LEVIATHAN TEST TEXTURE HAZIR: ", LEVIATHAN_TEXTURE_PATH)


func _ensure_leviathan_test() -> void:
	if is_instance_valid(_leviathan_sprite):
		return

	if _leviathan_texture == null:
		_load_leviathan_texture()
		if _leviathan_texture == null:
			return

	var root: Node2D = get_tree().current_scene as Node2D
	if root == null:
		return

	var boat: Node2D = root.get_node_or_null("Boat") as Node2D
	if boat == null:
		return

	var existing: Sprite2D = root.get_node_or_null("LeviathanVisualTest") as Sprite2D
	if existing != null:
		_leviathan_sprite = existing
		_leviathan_origin = existing.global_position
		return

	var sprite: Sprite2D = Sprite2D.new()
	sprite.name = "LeviathanVisualTest"
	sprite.texture = _leviathan_texture
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.scale = LEVIATHAN_TEST_SCALE
	sprite.z_index = 3
	sprite.global_position = boat.global_position + LEVIATHAN_TEST_OFFSET
	root.add_child(sprite)

	_leviathan_sprite = sprite
	_leviathan_origin = sprite.global_position
	print("LEVIATHAN TEST DENIZE EKLENDI: ", _leviathan_origin)


func _animate_leviathan_test() -> void:
	if not is_instance_valid(_leviathan_sprite):
		return

	# Ana yüzüş: sinüs eğrisi dönüş noktalarında doğal olarak yavaşlar.
	var swim_phase: float = _time * LEVIATHAN_SWIM_CYCLE_SPEED
	var wave_x: float = sin(swim_phase) * LEVIATHAN_SWIM_RANGE_X
	var velocity_x: float = cos(swim_phase) * LEVIATHAN_SWIM_RANGE_X * LEVIATHAN_SWIM_CYCLE_SPEED

	# İki farklı frekans üst üste bindirilerek mekanik tekdüze salınım kırılır.
	var wave_y: float = sin(_time * 0.72) * LEVIATHAN_BOB_HEIGHT
	wave_y += sin(_time * 1.47 + 0.65) * 2.5
	var velocity_y: float = cos(_time * 0.72) * LEVIATHAN_BOB_HEIGHT * 0.72
	velocity_y += cos(_time * 1.47 + 0.65) * 2.5 * 1.47

	_leviathan_sprite.global_position = _leviathan_origin + Vector2(wave_x, wave_y)

	# Yön sadece belirgin yatay hareket varken değişir; dönüş anında titreşmez.
	if velocity_x > LEVIATHAN_TURN_SPEED_THRESHOLD:
		_leviathan_facing_right = true
	elif velocity_x < -LEVIATHAN_TURN_SPEED_THRESHOLD:
		_leviathan_facing_right = false
	_leviathan_sprite.flip_h = _leviathan_facing_right

	# Yukarı-aşağı hareket ederken kafa çok hafif eğilir.
	var swim_pitch: float = clampf(velocity_y * 0.0021, -0.035, 0.035)
	var body_roll: float = sin(_time * 0.95) * 0.008
	_leviathan_sprite.rotation = swim_pitch + body_roll

	# Tek parça sprite ile gövdenin suyu ittiği hissini veren çok hafif deformasyon.
	var body_wave: float = sin(_time * 2.15)
	var facing_sign: float = 1.0 if _leviathan_facing_right else -1.0
	_leviathan_sprite.skew = body_wave * 0.026 * facing_sign

	var stretch_x: float = 1.0 + absf(body_wave) * 0.012
	var squash_y: float = 1.0 - absf(body_wave) * 0.008
	_leviathan_sprite.scale = Vector2(
		LEVIATHAN_TEST_SCALE.x * stretch_x,
		LEVIATHAN_TEST_SCALE.y * squash_y
	)


func _ensure_leviathan_glows() -> void:
	if not is_instance_valid(_leviathan_sprite):
		return
	if is_instance_valid(_leviathan_lure_glow) and is_instance_valid(_leviathan_eye_glow):
		return

	if _leviathan_glow_texture == null:
		_leviathan_glow_texture = _create_radial_glow_texture(96)

	var additive: CanvasItemMaterial = CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD

	var lure: Sprite2D = Sprite2D.new()
	lure.name = "LeviathanLureGlow"
	lure.texture = _leviathan_glow_texture
	lure.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	lure.material = additive
	lure.z_index = 2
	lure.modulate = Color(1.0, 0.10, 0.035, 0.92)
	_leviathan_sprite.add_child(lure)

	var eye: Sprite2D = Sprite2D.new()
	eye.name = "LeviathanEyeGlow"
	eye.texture = _leviathan_glow_texture
	eye.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	eye.material = additive
	eye.z_index = 2
	eye.modulate = Color(0.10, 0.92, 1.0, 0.88)
	_leviathan_sprite.add_child(eye)

	_leviathan_lure_glow = lure
	_leviathan_eye_glow = eye
	print("LEVIATHAN FENER + GOZ ISIGI AKTIF")


func _update_leviathan_glows() -> void:
	if not is_instance_valid(_leviathan_sprite):
		return
	if not is_instance_valid(_leviathan_lure_glow) or not is_instance_valid(_leviathan_eye_glow):
		return
	if _leviathan_texture == null:
		return

	var texture_size: Vector2 = _leviathan_texture.get_size()
	var head_sign: float = 1.0 if _leviathan_facing_right else -1.0

	# Sprite flip_h çocuk node'ları çevirmediği için ışık noktalarını yönle birlikte elle aynalarız.
	_leviathan_lure_glow.position = Vector2(
		texture_size.x * LEVIATHAN_LURE_X_RATIO * head_sign,
		texture_size.y * LEVIATHAN_LURE_Y_RATIO
	)
	_leviathan_eye_glow.position = Vector2(
		texture_size.x * LEVIATHAN_EYE_X_RATIO * head_sign,
		texture_size.y * LEVIATHAN_EYE_Y_RATIO
	)

	# Fener ağır ve belirgin, göz ise daha küçük ve hızlı titreşen bir ışık verir.
	var lure_pulse: float = 0.88 + sin(_time * 2.45) * 0.12
	var lure_breathe: float = 0.52 + lure_pulse * 0.16
	_leviathan_lure_glow.scale = Vector2.ONE * lure_breathe
	_leviathan_lure_glow.modulate.a = 0.72 + lure_pulse * 0.20

	var eye_pulse: float = 0.90 + sin(_time * 4.6 + 0.8) * 0.10
	_leviathan_eye_glow.scale = Vector2.ONE * (0.24 + eye_pulse * 0.07)
	_leviathan_eye_glow.modulate.a = 0.66 + eye_pulse * 0.24


func _create_radial_glow_texture(size: int) -> Texture2D:
	var image: Image = Image.create(size, size, false, Image.FORMAT_RGBA8)
	var center: Vector2 = Vector2(float(size - 1) * 0.5, float(size - 1) * 0.5)
	var radius: float = float(size) * 0.5

	for y: int in range(size):
		for x: int in range(size):
			var distance_ratio: float = Vector2(float(x), float(y)).distance_to(center) / radius
			var alpha: float = pow(clampf(1.0 - distance_ratio, 0.0, 1.0), 2.25)
			image.set_pixel(x, y, Color(1.0, 1.0, 1.0, alpha))

	return ImageTexture.create_from_image(image)


func get_texture_for_fish(fish_type: String) -> Texture2D:
	match fish_type:
		"Kılıç Balığı":
			return _kilic_approved
		"Köpekbalığı":
			return _kopek_approved
		"Fener Balığı":
			return _fener_approved
		_:
			return null


func _apply_to_current_scene() -> void:
	var root: Node = get_tree().current_scene
	if root == null:
		return
	_scan_node(root)


func _align_bait_to_hook() -> void:
	var root: Node = get_tree().current_scene
	if root == null:
		return

	var hook: Node2D = root.get_node_or_null("Boat/Hook") as Node2D
	if hook == null:
		return

	var bait_root: Node2D = hook.get_node_or_null("BaitVisualRoot") as Node2D
	if bait_root == null:
		return

	var t: float = float(Time.get_ticks_msec()) * 0.001
	bait_root.position = BAIT_HOOK_OFFSET + Vector2(sin(t * 0.80) * 0.8, sin(t * 1.15) * 0.45)
	bait_root.scale = BAIT_SCALE


func _scan_node(node: Node) -> void:
	if node is Sprite2D:
		_replace_sprite(node as Sprite2D)
	elif node is TextureRect:
		_replace_texture_rect(node as TextureRect)

	for child: Node in node.get_children():
		_scan_node(child)


func _replace_sprite(sprite: Sprite2D) -> void:
	if sprite.texture == null:
		return

	var old_path: String = sprite.texture.resource_path
	var fish_type: String = ""
	var approved: Texture2D = null

	match old_path:
		KILIC_OLD:
			fish_type = "Kılıç Balığı"
			approved = _kilic_approved
		KOPEK_OLD:
			fish_type = "Köpekbalığı"
			approved = _kopek_approved
		FENER_OLD:
			fish_type = "Fener Balığı"
			approved = _fener_approved
		_:
			return

	if approved == null:
		return

	sprite.texture = approved
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_compensate_fish_scale(sprite, fish_type)


func _replace_texture_rect(rect: TextureRect) -> void:
	if rect.texture == null:
		return

	var approved: Texture2D = null
	match rect.texture.resource_path:
		KILIC_OLD:
			approved = _kilic_approved
		KOPEK_OLD:
			approved = _kopek_approved
		FENER_OLD:
			approved = _fener_approved
		_:
			return

	if approved == null:
		return

	rect.texture = approved
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func _compensate_fish_scale(sprite: Sprite2D, fish_type: String) -> void:
	var fish: Node = sprite.get_parent()
	if fish == null or not fish.has_method("hook_to"):
		return

	var target_scale: Vector2 = Vector2.ONE
	match fish_type:
		"Kılıç Balığı":
			target_scale = Vector2(0.57, 0.57)
		"Köpekbalığı":
			target_scale = Vector2(0.61, 0.61)
		"Fener Balığı":
			target_scale = Vector2(0.55, 0.55)
		_:
			return

	fish.set("base_sprite_scale", target_scale)
	sprite.scale = target_scale
