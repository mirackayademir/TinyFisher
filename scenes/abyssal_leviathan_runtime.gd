extends Node

# Leviathan kontrolu ikinci bir balik spawn ETMEZ.
# Ekranda gorunen LeviathanVisualTest Sprite2D'sini hedefler.
# STEP 9C: Agiz-kanca temas cilasi.
# - Yem gorulunce agresif ve hizli yaklasir.
# - Yaklasma hizi arttikca kuyruk animasyonu da hizlanir.
# - Boss basladiginda kanca fener ucuna degil, dislerin arasina kilitlenir.

const LEVIATHAN_NODE_NAME: String = "LeviathanVisualTest"
const LEVIATHAN_SWIM_SHADER: Shader = preload("res://shaders/leviathan_swim.gdshader")
const RETRY_SECONDS: float = 0.20

const BAIT_SHRIMP: String = "Karides"
const BAIT_LIVE_SARDINE: String = "Canlı Sardalya"

const SHRIMP_DETECTION_RADIUS: float = 430.0
const LIVE_SARDINE_DETECTION_RADIUS: float = 720.0
const SHRIMP_HUNT_SPEED: float = 175.0
const LIVE_SARDINE_HUNT_SPEED: float = 230.0
const STALK_SLOW_RADIUS: float = 185.0
const RETURN_SPEED: float = 150.0

# Texture merkezine gore acik agzin/dislerin orta noktasini hedefler.
# Kaynak gorselde kafa solda; flip_h=true oldugunda kafa saga gecer.
const LEVIATHAN_MOUTH_X_RATIO: float = 0.360
const LEVIATHAN_MOUTH_Y_RATIO: float = 0.015
const BOSS_BITE_DISTANCE: float = 16.0

const BOSS_MAX_RESISTANCE: float = 100.0
const BOSS_REEL_DAMAGE_PER_SECOND: float = 20.0
const BOSS_RESULT_SECONDS: float = 1.8

# ApprovedFishArt'taki gercek kafa uzerindeki isik oranlari.
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
var _hunt_speed_factor: float = 0.0

var _boss_active: bool = false
var _boss_caught: bool = false
var _boss_resistance: float = BOSS_MAX_RESISTANCE
var _boss_time: float = 0.0
var _boss_hook_local_position: Vector2 = Vector2.ZERO
var _boss_saved_collision_mask: int = 2
var _boss_result_timer: float = 0.0
var _boss_base_rotation: float = 0.0
var _boss_facing_right: bool = true

var _boss_panel: Panel = null
var _boss_bar: ProgressBar = null
var _boss_title: Label = null
var _boss_hint: Label = null
var _boss_fill_style: StyleBoxFlat = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# ApprovedFishArt priority=100. Biz sonra calisip son hareketi uygulariz.
	process_priority = 200
	print("LEVIATHAN CONTROLLER V14: STEP 9C TEETH HOOK LOCK")


func _process(delta: float) -> void:
	if _boss_caught:
		_update_boss_result(delta)
		return

	if is_instance_valid(_leviathan_sprite):
		if not _material_applied:
			_apply_visible_leviathan_material()

		if _boss_active:
			_update_boss_fight(delta)
		else:
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
	_hunt_speed_factor = 0.0
	_boss_active = false
	_boss_caught = false
	_boss_resistance = BOSS_MAX_RESISTANCE
	_boss_result_timer = 0.0
	print("LEVIATHAN V14 HEDEF BULUNDU: ", _leviathan_sprite.get_path())
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
	print("LEVIATHAN V14 ANIMASYON GORUNEN SPRITE'A UYGULANDI")


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
	var center_to_bait: Vector2 = hook.global_position - current_position
	var center_distance: float = center_to_bait.length()

	# Bir kez algiladiktan sonra yem sinirin biraz disina ciksa bile hemen vazgecmez.
	var active_radius: float = detection_radius * (1.22 if _hunt_override_active else 1.0)
	if center_distance > active_radius:
		_return_to_patrol(delta)
		return

	if not _hunt_override_active:
		_hunt_override_active = true
		_hunt_position = _leviathan_sprite.global_position
		_detected_bait = selected_bait
		_hunt_time = 0.0
		print("LEVIATHAN YEM ALGILADI: ", selected_bait, " mesafe=", int(center_distance))
	elif _detected_bait != selected_bait:
		_detected_bait = selected_bait
		_hunt_time = 0.0
		print("LEVIATHAN YEM DEGISTI: ", selected_bait)

	_hunt_time += delta

	# Once kafayi yeme cevir. Agiz noktasi bu yonde hesaplanacak.
	var facing_vector: Vector2 = hook.global_position - _hunt_position
	if absf(facing_vector.x) > 3.0:
		_leviathan_sprite.flip_h = facing_vector.x > 0.0

	_leviathan_sprite.global_position = _hunt_position
	var aim_rotation: float = clampf(facing_vector.y * 0.00072, -0.085, 0.085)
	_leviathan_sprite.rotation = aim_rotation

	# Merkez yerine agiz ile kanca arasindaki mesafeyi baz aliyoruz.
	var mouth_position: Vector2 = _get_mouth_global_position()
	var mouth_to_bait: Vector2 = hook.global_position - mouth_position
	var mouth_distance: float = mouth_to_bait.length()

	# Yem gorulunce agresif yaklasir; son mesafede sadece hafif fren yapar.
	var speed_multiplier: float = 1.15
	if mouth_distance < STALK_SLOW_RADIUS:
		var near_t: float = clampf(inverse_lerp(BOSS_BITE_DISTANCE, STALK_SLOW_RADIUS, mouth_distance), 0.0, 1.0)
		speed_multiplier = lerpf(0.72, 1.05, near_t)
	elif center_distance < detection_radius * 0.60:
		speed_multiplier = 1.08

	_hunt_speed_factor = speed_multiplier
	var hunt_speed: float = base_hunt_speed * speed_multiplier

	if mouth_distance > BOSS_BITE_DISTANCE:
		var travel: float = minf(hunt_speed * delta, mouth_distance - BOSS_BITE_DISTANCE)
		if mouth_distance > 0.001:
			_hunt_position += mouth_to_bait.normalized() * travel

	# Hareketten sonra sprite'i yeni konuma al ve hafif avci salinimi ekle.
	var new_center_to_bait: Vector2 = hook.global_position - _hunt_position
	if absf(new_center_to_bait.x) > 3.0:
		_leviathan_sprite.flip_h = new_center_to_bait.x > 0.0

	var close_amount: float = 1.0 - clampf(inverse_lerp(BOSS_BITE_DISTANCE, 320.0, mouth_distance), 0.0, 1.0)
	var stalk_offset_y: float = sin(_hunt_time * 2.2) * 2.8 * (1.0 - close_amount)
	_leviathan_sprite.global_position = _hunt_position + Vector2(0.0, stalk_offset_y)

	var final_center_to_bait: Vector2 = hook.global_position - _leviathan_sprite.global_position
	var predatory_nod: float = sin(_hunt_time * 2.4) * 0.008 * (1.0 - close_amount)
	_leviathan_sprite.rotation = clampf(final_center_to_bait.y * 0.00072, -0.085, 0.085) + predatory_nod

	var final_mouth_position: Vector2 = _get_mouth_global_position()
	var final_mouth_distance: float = final_mouth_position.distance_to(hook.global_position)

	# Hiz arttikca kuyruk da gercekten daha hizli calisir.
	_set_hunt_shader_state(true, final_mouth_distance, speed_multiplier)
	_update_hunt_glow(final_mouth_distance)

	if final_mouth_distance <= BOSS_BITE_DISTANCE:
		_start_boss_fight(hook)


func _get_mouth_local_position() -> Vector2:
	if not is_instance_valid(_leviathan_sprite) or _leviathan_sprite.texture == null:
		return Vector2.ZERO

	var texture_size: Vector2 = _leviathan_sprite.texture.get_size()
	var head_sign: float = 1.0 if _leviathan_sprite.flip_h else -1.0
	return Vector2(
		texture_size.x * LEVIATHAN_MOUTH_X_RATIO * head_sign,
		texture_size.y * LEVIATHAN_MOUTH_Y_RATIO
	)


func _get_mouth_global_position() -> Vector2:
	if not is_instance_valid(_leviathan_sprite):
		return Vector2.ZERO
	return _leviathan_sprite.to_global(_get_mouth_local_position())


func _lock_mouth_to_hook(hook_global_position: Vector2) -> void:
	if not is_instance_valid(_leviathan_sprite):
		return

	# Rotation/scale uygulandiktan sonra dislerin orta noktasinin gercek global
	# konumunu bulup aradaki fark kadar tum sprite'i tasiyoruz.
	var mouth_global: Vector2 = _get_mouth_global_position()
	_leviathan_sprite.global_position += hook_global_position - mouth_global
	_hunt_position = _leviathan_sprite.global_position


func _start_boss_fight(hook: Area2D) -> void:
	if _boss_active or _boss_caught or hook == null:
		return

	_boss_active = true
	_boss_resistance = BOSS_MAX_RESISTANCE
	_boss_time = 0.0
	_boss_hook_local_position = hook.position
	_boss_saved_collision_mask = hook.collision_mask
	_boss_base_rotation = _leviathan_sprite.rotation if is_instance_valid(_leviathan_sprite) else 0.0
	_boss_facing_right = _leviathan_sprite.flip_h if is_instance_valid(_leviathan_sprite) else true

	# Boss sirasinda oltanin normal baliklara temas etmesini gecici kapat.
	hook.collision_mask = 0
	hook.set("deployed", true)

	if is_instance_valid(_leviathan_sprite):
		_leviathan_sprite.flip_h = _boss_facing_right
		_lock_mouth_to_hook(hook.global_position)

	var root: Node = get_tree().current_scene
	if root != null:
		var hud: Node = root.get_node_or_null("HUD")
		if hud != null and hud.has_method("reset_fight"):
			hud.call("reset_fight")

	_ensure_boss_hud()
	_update_boss_hud()

	if _boss_panel != null:
		_boss_panel.visible = true

	print("LEVIATHAN YEMI KAPTI! DISLER KANCAYA KILITLENDI — DIRENC 100")


func _update_boss_fight(delta: float) -> void:
	var root: Node = get_tree().current_scene
	if root == null:
		_cancel_boss_fight()
		return

	var hook: Area2D = root.get_node_or_null("Boat/Hook") as Area2D
	if hook == null:
		_cancel_boss_fight()
		return

	_boss_time += delta
	_hunt_time += delta
	_hunt_speed_factor = 1.30

	# Hook.gd normal inis/cikis hesabini yapmaya devam etse bile boss aktifken
	# her frame yakalandigi noktaya sabitlenir.
	hook.set("deployed", true)
	hook.position = _boss_hook_local_position

	var reeling: bool = Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or Input.is_physical_key_pressed(KEY_W)
	if reeling:
		_boss_resistance = maxf(0.0, _boss_resistance - BOSS_REEL_DAMAGE_PER_SECOND * delta)

	if is_instance_valid(_leviathan_sprite):
		# Yon sabit kalir; govde agiz noktasinin etrafinda cirpinir.
		_leviathan_sprite.flip_h = _boss_facing_right
		var struggle_rotation: float = sin(_boss_time * 7.2) * 0.030
		var secondary_rotation: float = sin(_boss_time * 3.4 + 0.8) * 0.012
		_leviathan_sprite.rotation = _boss_base_rotation + struggle_rotation + secondary_rotation

		# Dislerin orta noktasi tam kancada kalirken kuyruk/govde savrulur.
		_lock_mouth_to_hook(hook.global_position)
		_set_hunt_shader_state(true, 0.0, 1.30)
		_update_hunt_glow(0.0)

	_update_boss_hud()

	if _boss_resistance <= 0.0:
		_complete_boss_fight(hook)


func _complete_boss_fight(hook: Area2D) -> void:
	_boss_active = false
	_boss_caught = true
	_boss_resistance = 0.0
	_boss_result_timer = BOSS_RESULT_SECONDS

	if hook != null:
		hook.collision_mask = _boss_saved_collision_mask
		hook.set("deployed", false)
		var start_position_value: Variant = hook.get("start_position")
		if start_position_value is Vector2:
			hook.position = start_position_value

	var root: Node = get_tree().current_scene
	if root != null:
		var hud: Node = root.get_node_or_null("HUD")
		if hud != null and hud.has_method("reset_fight"):
			hud.call("reset_fight")

		var boat: Node = root.get_node_or_null("Boat")
		if boat != null and boat.has_method("set_movement_enabled"):
			boat.call("set_movement_enabled", true)

	if is_instance_valid(_leviathan_sprite):
		_leviathan_sprite.visible = false

	_update_boss_hud()
	if _boss_panel != null:
		_boss_panel.visible = true

	print("LEVIATHAN BOSS YAKALANDI! DIRENC 0")


func _cancel_boss_fight() -> void:
	_boss_active = false
	_boss_resistance = BOSS_MAX_RESISTANCE
	if _boss_panel != null:
		_boss_panel.visible = false


func _update_boss_result(delta: float) -> void:
	if _boss_result_timer <= 0.0:
		if _boss_panel != null:
			_boss_panel.visible = false
		return

	_boss_result_timer -= delta
	if _boss_result_timer <= 0.0 and _boss_panel != null:
		_boss_panel.visible = false


func _ensure_boss_hud() -> void:
	if is_instance_valid(_boss_panel):
		return

	var root: Node = get_tree().current_scene
	if root == null:
		return

	var hud: Node = root.get_node_or_null("HUD")
	if hud == null:
		return

	_boss_panel = Panel.new()
	_boss_panel.name = "LeviathanBossPanel"
	_boss_panel.z_index = 98
	_boss_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_boss_panel.size = Vector2(560.0, 96.0)

	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	_boss_panel.position = Vector2((viewport_size.x - _boss_panel.size.x) * 0.5, 106.0)

	var panel_style: StyleBoxFlat = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.045, 0.015, 0.025, 0.95)
	panel_style.border_color = Color(0.92, 0.12, 0.12, 0.98)
	panel_style.border_width_left = 3
	panel_style.border_width_top = 3
	panel_style.border_width_right = 3
	panel_style.border_width_bottom = 3
	panel_style.corner_radius_top_left = 9
	panel_style.corner_radius_top_right = 9
	panel_style.corner_radius_bottom_left = 9
	panel_style.corner_radius_bottom_right = 9
	_boss_panel.add_theme_stylebox_override("panel", panel_style)
	hud.add_child(_boss_panel)

	_boss_title = Label.new()
	_boss_title.name = "BossTitle"
	_boss_title.position = Vector2(14.0, 7.0)
	_boss_title.size = Vector2(532.0, 27.0)
	_boss_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_boss_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_boss_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_boss_title.add_theme_font_size_override("font_size", 20)
	_boss_title.add_theme_color_override("font_color", Color(1.0, 0.42, 0.36, 1.0))
	_boss_title.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.95))
	_boss_title.add_theme_constant_override("shadow_offset_x", 2)
	_boss_title.add_theme_constant_override("shadow_offset_y", 2)
	_boss_panel.add_child(_boss_title)

	_boss_bar = ProgressBar.new()
	_boss_bar.name = "BossResistanceBar"
	_boss_bar.position = Vector2(20.0, 38.0)
	_boss_bar.size = Vector2(520.0, 24.0)
	_boss_bar.min_value = 0.0
	_boss_bar.max_value = BOSS_MAX_RESISTANCE
	_boss_bar.value = BOSS_MAX_RESISTANCE
	_boss_bar.show_percentage = false
	_boss_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var bar_bg: StyleBoxFlat = StyleBoxFlat.new()
	bar_bg.bg_color = Color(0.07, 0.025, 0.035, 1.0)
	bar_bg.border_color = Color(0.28, 0.07, 0.08, 1.0)
	bar_bg.border_width_left = 1
	bar_bg.border_width_top = 1
	bar_bg.border_width_right = 1
	bar_bg.border_width_bottom = 1
	bar_bg.corner_radius_top_left = 5
	bar_bg.corner_radius_top_right = 5
	bar_bg.corner_radius_bottom_left = 5
	bar_bg.corner_radius_bottom_right = 5
	_boss_bar.add_theme_stylebox_override("background", bar_bg)

	_boss_fill_style = StyleBoxFlat.new()
	_boss_fill_style.bg_color = Color(0.92, 0.12, 0.10, 0.98)
	_boss_fill_style.corner_radius_top_left = 4
	_boss_fill_style.corner_radius_top_right = 4
	_boss_fill_style.corner_radius_bottom_left = 4
	_boss_fill_style.corner_radius_bottom_right = 4
	_boss_bar.add_theme_stylebox_override("fill", _boss_fill_style)
	_boss_panel.add_child(_boss_bar)

	_boss_hint = Label.new()
	_boss_hint.name = "BossHint"
	_boss_hint.position = Vector2(12.0, 67.0)
	_boss_hint.size = Vector2(536.0, 20.0)
	_boss_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_boss_hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_boss_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_boss_hint.add_theme_font_size_override("font_size", 13)
	_boss_hint.add_theme_color_override("font_color", Color(0.90, 0.83, 0.84, 0.96))
	_boss_panel.add_child(_boss_hint)

	_boss_panel.visible = false


func _update_boss_hud() -> void:
	_ensure_boss_hud()
	if _boss_panel == null or _boss_bar == null or _boss_title == null or _boss_hint == null:
		return

	_boss_bar.value = _boss_resistance

	if _boss_caught:
		_boss_title.text = "LEVIATHAN YAKALANDI!"
		_boss_hint.text = "Direnç 0 — ilk boss mücadele prototipi tamamlandı"
		if _boss_fill_style != null:
			_boss_fill_style.bg_color = Color(0.22, 0.86, 0.48, 1.0)
		return

	_boss_title.text = "LEVIATHAN  •  DİRENÇ %d%%" % int(round(_boss_resistance))
	_boss_hint.text = "SOL TIK / W ile sar — direnci sıfıra indir"
	if _boss_fill_style != null:
		_boss_fill_style.bg_color = Color(0.92, 0.12, 0.10, 0.98)


func _return_to_patrol(delta: float) -> void:
	if _boss_active or _boss_caught:
		return

	if not _hunt_override_active or not is_instance_valid(_leviathan_sprite):
		_set_hunt_shader_state(false, 9999.0, 0.0)
		return

	# ApprovedFishArt bu frame normal devriye konumunu zaten hesaplayip sprite'a yazdi.
	var patrol_position: Vector2 = _leviathan_sprite.global_position
	_hunt_position = _hunt_position.move_toward(patrol_position, RETURN_SPEED * delta)
	_leviathan_sprite.global_position = _hunt_position

	if _hunt_position.distance_to(patrol_position) <= 4.0:
		_hunt_override_active = false
		_detected_bait = ""
		_hunt_time = 0.0
		_hunt_speed_factor = 0.0
		_set_hunt_shader_state(false, 9999.0, 0.0)
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


func _set_hunt_shader_state(hunting: bool, distance: float, speed_factor: float = 1.0) -> void:
	if not is_instance_valid(_leviathan_sprite):
		return
	var material: ShaderMaterial = _leviathan_sprite.material as ShaderMaterial
	if material == null:
		return

	if hunting:
		var close_factor: float = 1.0 - clampf(inverse_lerp(BOSS_BITE_DISTANCE, 420.0, distance), 0.0, 1.0)
		var speed_t: float = clampf(inverse_lerp(0.70, 1.30, speed_factor), 0.0, 1.0)
		material.set_shader_parameter("tail_strength", lerpf(0.070, 0.092, speed_t) + close_factor * 0.006)
		material.set_shader_parameter("tail_speed", lerpf(4.2, 7.2, speed_t))
		material.set_shader_parameter("body_strength", lerpf(0.020, 0.027, speed_t) + close_factor * 0.002)
	else:
		material.set_shader_parameter("tail_strength", 0.060)
		material.set_shader_parameter("tail_speed", 3.0)
		material.set_shader_parameter("body_strength", 0.018)


func _update_hunt_glow(distance: float) -> void:
	if not is_instance_valid(_leviathan_sprite):
		return

	var lure: Sprite2D = _leviathan_sprite.get_node_or_null("LeviathanLureGlow") as Sprite2D
	var eye: Sprite2D = _leviathan_sprite.get_node_or_null("LeviathanEyeGlow") as Sprite2D
	var close_factor: float = 1.0 - clampf(inverse_lerp(BOSS_BITE_DISTANCE, 430.0, distance), 0.0, 1.0)

	if _leviathan_sprite.texture != null:
		var texture_size: Vector2 = _leviathan_sprite.texture.get_size()
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
		var pulse_speed: float = lerpf(3.2, 6.2, clampf(_hunt_speed_factor, 0.0, 1.30) / 1.30)
		var pulse: float = 0.5 + 0.5 * sin(_hunt_time * pulse_speed)
		var lure_scale: float = lerpf(0.66, 0.88, close_factor) + pulse * lerpf(0.035, 0.080, close_factor)
		lure.scale = Vector2.ONE * lure_scale
		lure.modulate.a = clampf(0.82 + close_factor * 0.14 + pulse * 0.04, 0.0, 1.0)

	if eye != null:
		var eye_pulse: float = 0.5 + 0.5 * sin(_hunt_time * 6.2 + 0.7)
		eye.scale = Vector2.ONE * (0.30 + close_factor * 0.045 + eye_pulse * 0.018)
		eye.modulate.a = clampf(0.78 + close_factor * 0.14 + eye_pulse * 0.04, 0.0, 1.0)
