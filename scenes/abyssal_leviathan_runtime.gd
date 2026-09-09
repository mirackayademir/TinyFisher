extends Node

# Leviathan kontrolu ikinci bir balik spawn ETMEZ.
# Ekranda gercekten gorunen LeviathanVisualTest Sprite2D'sini hedefler.
# 8B: Yem algilama cilasi — sinsi yaklasma, son mesafede yavaslama,
# yeme dogru kafa egimi ve av modunda guclenen fener nabzi.
# Isirma/boss mucadelesi HENUZ yok.

const LEVIATHAN_NODE_NAME: String = "LeviathanVisualTest"
const LEVIATHAN_SWIM_SHADER: Shader = preload("res://shaders/leviathan_swim.gdshader")
const RETRY_SECONDS: float = 0.20

const BAIT_SHRIMP: String = "Karides"
const BAIT_LIVE_SARDINE: String = "Canlı Sardalya"

const SHRIMP_DETECTION_RADIUS: float = 430.0
const LIVE_SARDINE_DETECTION_RADIUS: float = 720.0
const SHRIMP_HUNT_SPEED: float = 54.0
const LIVE_SARDINE_HUNT_SPEED: float = 82.0
const STOP_DISTANCE: float = 135.0
const STALK_SLOW_RADIUS: float = 260.0
const RETURN_SPEED: float = 115.0

# ApprovedFishArt'taki gercek kafa uzerindeki isik oranlari.
# Sprite2D.flip_h cocuk node'lari aynalamadigi icin av modunda bunlari
# gorunen kafa yonune gore burada zorla dogru tarafa tasiyoruz.
const LEVIATHAN_LURE_X_RATIO: float = 0.466
const LEVIATHAN_LURE_Y_RATIO: float = -0.047
const LEVIATHAN_EYE_X_RATIO: float = 0.248
const LEVIATHAN_EYE_Y_RATIO: float = -0.095

var _leviathan_sprite: Sprite2D = null
var _retry_timer: float = 0.0
var _material_applied: bool = false

var _hunt_override_active: bool = false
var _hunt_position: Vector2 = Vector2.ZERO
var _detected_bait: String = ""
var _hunt_time: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# ApprovedFishArt priority=100. Biz sonra calisip gorunen sprite'a son hareketi uygulariz.
	process_priority = 200
	print("LEVIATHAN CONTROLLER V11: STEP 8B GLOW HEAD SYNC FIX")


func _process(delta: float) -> void:
	if is_instance_valid(_leviathan_sprite):
		if not _material_applied:
			_apply_visible_leviathan_material()
		_update_bait_detection(delta)
		return

	_retry_timer -= delta
	if _retry_timer > 0.0:
		return
	_retry_timer = RETRY_SECONDS
	_find_visible_leviathan()


func _find_visible_leviathan() -> void:
	var root: Node = get_tree().current_scene
	if root == null:
		return

	var sprite: Sprite2D = root.get_node_or_null(LEVIATHAN_NODE_NAME) as Sprite2D
	if sprite == null:
		return

	_leviathan_sprite = sprite
	_material_applied = false
	_hunt_override_active = false
	_detected_bait = ""
	_hunt_time = 0.0
	print("LEVIATHAN V11 HEDEF BULUNDU: ", _leviathan_sprite.get_path())
	_apply_visible_leviathan_material()


func _apply_visible_leviathan_material() -> void:
	if not is_instance_valid(_leviathan_sprite):
		return

	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = LEVIATHAN_SWIM_SHADER
	material.set_shader_parameter("tail_strength", 0.060)
	material.set_shader_parameter("tail_speed", 3.0)
	material.set_shader_parameter("body_strength", 0.018)

	_leviathan_sprite.material = material
	_material_applied = true
	print("LEVIATHAN V11 ANIMASYON GORUNEN SPRITE'A UYGULANDI")


func _update_bait_detection(delta: float) -> void:
	if not is_instance_valid(_leviathan_sprite):
		return

	var root: Node = get_tree().current_scene
	if root == null:
		return

	var hook: Area2D = root.get_node_or_null("Boat/Hook") as Area2D
	var bait_system: Node = get_node_or_null("/root/DeepSeaAtmosphere")
	if hook == null or bait_system == null:
		_return_to_patrol(delta)
		return

	var deployed: bool = bool(hook.get("deployed"))
	var hooked_fish: Variant = hook.get("hooked_fish")
	var selected_bait: String = String(bait_system.get("selected_bait"))

	if not deployed or hooked_fish != null:
		_return_to_patrol(delta)
		return

	var detection_radius: float = _get_detection_radius(selected_bait)
	var base_hunt_speed: float = _get_hunt_speed(selected_bait)
	if detection_radius <= 0.0 or base_hunt_speed <= 0.0:
		_return_to_patrol(delta)
		return

	var current_position: Vector2 = _hunt_position if _hunt_override_active else _leviathan_sprite.global_position
	var to_bait: Vector2 = hook.global_position - current_position
	var distance: float = to_bait.length()

	# Bir kez algiladiktan sonra yem sinirin biraz disina ciksa bile hemen vazgecmez.
	var active_radius: float = detection_radius * (1.22 if _hunt_override_active else 1.0)
	if distance > active_radius:
		_return_to_patrol(delta)
		return

	if not _hunt_override_active:
		_hunt_override_active = true
		_hunt_position = _leviathan_sprite.global_position
		_detected_bait = selected_bait
		_hunt_time = 0.0
		print("LEVIATHAN YEM ALGILADI: ", selected_bait, " mesafe=", int(distance))
	elif _detected_bait != selected_bait:
		_detected_bait = selected_bait
		_hunt_time = 0.0
		print("LEVIATHAN YEM DEGISTI: ", selected_bait)

	_hunt_time += delta

	# Sinsi yaklasma: uzakta kontrollu, orta mesafede kararli,
	# son 260 px'de belirgin sekilde yavaslayarak yemi suzer.
	var speed_multiplier: float = 0.76
	if distance < STALK_SLOW_RADIUS:
		var near_t: float = clampf(inverse_lerp(STOP_DISTANCE, STALK_SLOW_RADIUS, distance), 0.0, 1.0)
		speed_multiplier = lerpf(0.18, 0.72, near_t)
	elif distance < detection_radius * 0.72:
		speed_multiplier = 0.92

	if distance > STOP_DISTANCE:
		var hunt_speed: float = base_hunt_speed * speed_multiplier
		var travel: float = minf(hunt_speed * delta, distance - STOP_DISTANCE)
		_hunt_position += to_bait.normalized() * travel

	var final_to_bait: Vector2 = hook.global_position - _hunt_position
	var final_distance: float = final_to_bait.length()

	# Yaklasirken cok hafif avci salinimi. Merkez konumu bozmaz; sadece ekranda
	# canli, temkinli bir yuzme hissi verir. Yeme cok yakinda salinim azalir.
	var stalk_amount: float = clampf(inverse_lerp(STOP_DISTANCE, 320.0, final_distance), 0.0, 1.0)
	var stalk_offset_y: float = sin(_hunt_time * 1.35) * 4.5 * stalk_amount
	_leviathan_sprite.global_position = _hunt_position + Vector2(0.0, stalk_offset_y)

	# Kafayi yeme cevir.
	if absf(final_to_bait.x) > 3.0:
		_leviathan_sprite.flip_h = final_to_bait.x > 0.0

	# Yeme dogru kafa egimi. Son mesafede biraz daha belirgin olur.
	var aim_rotation: float = clampf(final_to_bait.y * 0.00082, -0.095, 0.095)
	var predatory_nod: float = sin(_hunt_time * 1.10) * 0.010 * (1.0 - stalk_amount)
	_leviathan_sprite.rotation = aim_rotation + predatory_nod

	# Av modunda kuyruk/govde daha canli; fener ise yeme yaklastikca daha guclu nabiz atar.
	_set_hunt_shader_state(true, final_distance)
	_update_hunt_glow(final_distance)


func _return_to_patrol(delta: float) -> void:
	if not _hunt_override_active or not is_instance_valid(_leviathan_sprite):
		_set_hunt_shader_state(false, 9999.0)
		return

	# ApprovedFishArt bu frame normal devriye konumunu zaten hesaplayip sprite'a yazdi.
	# O konumu hedef alip av modundan yumusakca cikiyoruz.
	var patrol_position: Vector2 = _leviathan_sprite.global_position
	_hunt_position = _hunt_position.move_toward(patrol_position, RETURN_SPEED * delta)
	_leviathan_sprite.global_position = _hunt_position

	if _hunt_position.distance_to(patrol_position) <= 4.0:
		_hunt_override_active = false
		_detected_bait = ""
		_hunt_time = 0.0
		_set_hunt_shader_state(false, 9999.0)
		print("LEVIATHAN YEMI KAYBETTI: DEVRIYEYE DONDU")


func _get_detection_radius(bait: String) -> float:
	match bait:
		BAIT_SHRIMP:
			return SHRIMP_DETECTION_RADIUS
		BAIT_LIVE_SARDINE:
			return LIVE_SARDINE_DETECTION_RADIUS
		_:
			return 0.0


func _get_hunt_speed(bait: String) -> float:
	match bait:
		BAIT_SHRIMP:
			return SHRIMP_HUNT_SPEED
		BAIT_LIVE_SARDINE:
			return LIVE_SARDINE_HUNT_SPEED
		_:
			return 0.0


func _set_hunt_shader_state(hunting: bool, distance: float) -> void:
	if not is_instance_valid(_leviathan_sprite):
		return
	var material: ShaderMaterial = _leviathan_sprite.material as ShaderMaterial
	if material == null:
		return

	if hunting:
		var close_factor: float = 1.0 - clampf(inverse_lerp(STOP_DISTANCE, 420.0, distance), 0.0, 1.0)
		material.set_shader_parameter("tail_strength", lerpf(0.066, 0.078, close_factor))
		material.set_shader_parameter("tail_speed", lerpf(3.55, 4.35, close_factor))
		material.set_shader_parameter("body_strength", lerpf(0.019, 0.023, close_factor))
	else:
		material.set_shader_parameter("tail_strength", 0.060)
		material.set_shader_parameter("tail_speed", 3.0)
		material.set_shader_parameter("body_strength", 0.018)


func _update_hunt_glow(distance: float) -> void:
	if not is_instance_valid(_leviathan_sprite):
		return

	# ApprovedFishArt av disinda isiklari gunceller. Av modunda ise runtime sprite'i
	# yeme gore flip_h ile cevirdigi icin cocuk glow node'lari otomatik aynalanmaz.
	# Bu nedenle fener ve goz isiklarini her av frame'inde GERCEK GORUNEN KAFA tarafina sabitleriz.
	var lure: Sprite2D = _leviathan_sprite.get_node_or_null("LeviathanLureGlow") as Sprite2D
	var eye: Sprite2D = _leviathan_sprite.get_node_or_null("LeviathanEyeGlow") as Sprite2D
	var close_factor: float = 1.0 - clampf(inverse_lerp(STOP_DISTANCE, 430.0, distance), 0.0, 1.0)

	if _leviathan_sprite.texture != null:
		var texture_size: Vector2 = _leviathan_sprite.texture.get_size()
		# Kaynak gorselde kafa solda. flip_h=true oldugunda gorunen kafa saga gecer.
		var head_sign: float = 1.0 if _leviathan_sprite.flip_h else -1.0
		if lure != null:
			lure.position = Vector2(
				texture_size.x * LEVIATHAN_LURE_X_RATIO * head_sign,
				texture_size.y * LEVIATHAN_LURE_Y_RATIO
			)
		if eye != null:
			eye.position = Vector2(
				texture_size.x * LEVIATHAN_EYE_X_RATIO * head_sign,
				texture_size.y * LEVIATHAN_EYE_Y_RATIO
			)

	if lure != null:
		var pulse: float = 0.5 + 0.5 * sin(_hunt_time * lerpf(3.0, 5.2, close_factor))
		var lure_scale: float = lerpf(0.66, 0.86, close_factor) + pulse * lerpf(0.035, 0.075, close_factor)
		lure.scale = Vector2.ONE * lure_scale
		lure.modulate.a = clampf(0.82 + close_factor * 0.14 + pulse * 0.04, 0.0, 1.0)

	if eye != null:
		var eye_pulse: float = 0.5 + 0.5 * sin(_hunt_time * 5.8 + 0.7)
		eye.scale = Vector2.ONE * (0.30 + close_factor * 0.045 + eye_pulse * 0.018)
		eye.modulate.a = clampf(0.78 + close_factor * 0.14 + eye_pulse * 0.04, 0.0, 1.0)
