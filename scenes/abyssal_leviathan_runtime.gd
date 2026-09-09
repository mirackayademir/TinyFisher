extends Node

# Leviathan kontrolu ikinci bir balik spawn ETMEZ.
# Ekranda gercekten gorunen LeviathanVisualTest Sprite2D'sini hedefler.
# 8A: Yem algilama + yeme dogru yonelme. Isirma/boss mucadelesi HENUZ yok.

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
const RETURN_SPEED: float = 115.0

var _leviathan_sprite: Sprite2D = null
var _retry_timer: float = 0.0
var _material_applied: bool = false

var _hunt_override_active: bool = false
var _hunt_position: Vector2 = Vector2.ZERO
var _detected_bait: String = ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# ApprovedFishArt priority=100. Biz sonra calisip gorunen sprite'a son hareketi uygulariz.
	process_priority = 200
	print("LEVIATHAN CONTROLLER V9: STEP 8A BAIT DETECTION")


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
	print("LEVIATHAN V9 HEDEF BULUNDU: ", _leviathan_sprite.get_path())
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
	print("LEVIATHAN V9 ANIMASYON GORUNEN SPRITE'A UYGULANDI")


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
	var hunt_speed: float = _get_hunt_speed(selected_bait)
	if detection_radius <= 0.0 or hunt_speed <= 0.0:
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
		print("LEVIATHAN YEM ALGILADI: ", selected_bait, " mesafe=", int(distance))
	elif _detected_bait != selected_bait:
		_detected_bait = selected_bait
		print("LEVIATHAN YEM DEGISTI: ", selected_bait)

	# 8A'da sadece yaklasir ve yemin onunde durur. Isirma 9. maddede gelecek.
	if distance > STOP_DISTANCE:
		var travel: float = minf(hunt_speed * delta, distance - STOP_DISTANCE)
		_hunt_position += to_bait.normalized() * travel

	var final_to_bait: Vector2 = hook.global_position - _hunt_position
	_leviathan_sprite.global_position = _hunt_position

	# Kafayi yeme cevir.
	if absf(final_to_bait.x) > 3.0:
		_leviathan_sprite.flip_h = final_to_bait.x > 0.0

	# Yeme dogru cok hafif dalis/yukselis acisi.
	_leviathan_sprite.rotation = clampf(final_to_bait.y * 0.00065, -0.075, 0.075)

	# Av modunda kuyruk biraz hizlanir; oyuncu algilamayi gozle de fark eder.
	_set_hunt_shader_state(true)


func _return_to_patrol(delta: float) -> void:
	if not _hunt_override_active or not is_instance_valid(_leviathan_sprite):
		_set_hunt_shader_state(false)
		return

	# ApprovedFishArt bu frame normal devriye konumunu zaten hesaplayip sprite'a yazdi.
	# O konumu hedef alip av modundan yumusakca cikiyoruz.
	var patrol_position: Vector2 = _leviathan_sprite.global_position
	_hunt_position = _hunt_position.move_toward(patrol_position, RETURN_SPEED * delta)
	_leviathan_sprite.global_position = _hunt_position

	if _hunt_position.distance_to(patrol_position) <= 4.0:
		_hunt_override_active = false
		_detected_bait = ""
		_set_hunt_shader_state(false)
		print("LEVIATHAN YEMI KAYBETTI: DEVRİYEYE DONDU")


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


func _set_hunt_shader_state(hunting: bool) -> void:
	if not is_instance_valid(_leviathan_sprite):
		return
	var material: ShaderMaterial = _leviathan_sprite.material as ShaderMaterial
	if material == null:
		return

	if hunting:
		material.set_shader_parameter("tail_strength", 0.070)
		material.set_shader_parameter("tail_speed", 4.0)
	else:
		material.set_shader_parameter("tail_strength", 0.060)
		material.set_shader_parameter("tail_speed", 3.0)
