extends Node

# Leviathan kontrolu ikinci bir balik spawn ETMEZ.
# Ekranda gercekten gorunen LeviathanVisualTest Sprite2D'sini hedefler.
# STEP 9A: Temel boss mucadelesi.
# Leviathan yeme kadar yaklasir, yemi kapar ve ozel direnç bari acilir.
# Sol tik / W ile sarildikca 100 direnç sifira iner; sifirda Leviathan yakalanir.
# Misina kopmasi, fazlar ve ozel saldirilar sonraki adimlarda eklenecek.

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

const BOSS_BITE_DISTANCE: float = 145.0
const BOSS_MAX_RESISTANCE: float = 100.0
const BOSS_REEL_DAMAGE_PER_SECOND: float = 20.0
const BOSS_STRUGGLE_X: float = 11.0
const BOSS_STRUGGLE_Y: float = 7.0
const BOSS_RESULT_SECONDS: float = 1.8

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

var _boss_active: bool = false
var _boss_caught: bool = false
var _boss_resistance: float = BOSS_MAX_RESISTANCE
var _boss_time: float = 0.0
var _boss_hook_local_position: Vector2 = Vector2.ZERO
var _boss_saved_collision_mask: int = 2
var _boss_result_timer: float = 0.0

var _boss_panel: Panel = null
var _boss_bar: ProgressBar = null
var _boss_title: Label = null
var _boss_hint: Label = null
var _boss_fill_style: StyleBoxFlat = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# ApprovedFishArt priority=100. Biz sonra calisip gorunen sprite'a son hareketi uygulariz.
	process_priority = 200
	print("LEVIATHAN CONTROLLER V12: STEP 9A BOSS FIGHT FOUNDATION")


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
	_boss_active = false
	_boss_caught = false
	_boss_resistance = BOSS_MAX_RESISTANCE
	_boss_result_timer = 0.0
	print("LEVIATHAN V12 HEDEF BULUNDU: ", _leviathan_sprite.get_path())
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
	print("LEVIATHAN V12 ANIMASYON GORUNEN SPRITE'A UYGULANDI")


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

	# STEP 9A: Leviathan yemin dibine geldiginde normal balik sistemi yerine
	# kendi boss mucadelesini baslatir.
	if final_distance <= BOSS_BITE_DISTANCE:
		_start_boss_fight(hook)


func _start_boss_fight(hook: Area2D) -> void:
	if _boss_active or _boss_caught or hook == null:
		return

	_boss_active = true
	_boss_resistance = BOSS_MAX_RESISTANCE
	_boss_time = 0.0
	_boss_hook_local_position = hook.position
	_boss_saved_collision_mask = hook.collision_mask

	# Boss sirasinda oltanin normal baliklara temas etmesini gecici kapat.
	# Hook scriptini degistirmeden mevcut olta noktasini burada sabit tutuyoruz.
	hook.collision_mask = 0
	hook.set("deployed", true)

	var root: Node = get_tree().current_scene
	if root != null:
		var hud: Node = root.get_node_or_null("HUD")
		if hud != null and hud.has_method("reset_fight"):
			hud.call("reset_fight")

	_ensure_boss_hud()
	_update_boss_hud()

	if _boss_panel != null:
		_boss_panel.visible = true

	print("LEVIATHAN YEMI KAPTI! BOSS MUCadeLESI BASLADI — DIRENC 100")


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

	# Hook.gd normal inis/cikis hesabini yapmaya devam etse bile boss aktifken
	# her frame yakalandigi noktaya sabitlenir. Boylece mevcut olta sistemi bozulmaz.
	hook.set("deployed", true)
	hook.position = _boss_hook_local_position

	var reeling: bool = Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or Input.is_physical_key_pressed(KEY_W)
	if reeling:
		_boss_resistance = maxf(0.0, _boss_resistance - BOSS_REEL_DAMAGE_PER_SECOND * delta)

	# Ilk prototipte Leviathan sadece yemin cevresinde guclu sekilde cirpinir.
	# Sonraki adimlarda bu bolum fazlar, ani kacislar ve ip gerilimi ile genisletilecek.
	if is_instance_valid(_leviathan_sprite):
		var to_hook: Vector2 = hook.global_position - _hunt_position
		if to_hook.length() > STOP_DISTANCE:
			_hunt_position = _hunt_position.move_toward(
				hook.global_position - to_hook.normalized() * STOP_DISTANCE,
				90.0 * delta
			)

		var struggle: Vector2 = Vector2(
			sin(_boss_time * 6.2) * BOSS_STRUGGLE_X,
			sin(_boss_time * 8.1 + 0.7) * BOSS_STRUGGLE_Y
		)
		_leviathan_sprite.global_position = _hunt_position + struggle

		var final_to_hook: Vector2 = hook.global_position - _leviathan_sprite.global_position
		if absf(final_to_hook.x) > 2.0:
			_leviathan_sprite.flip_h = final_to_hook.x > 0.0
		_leviathan_sprite.rotation = clampf(final_to_hook.y * 0.0009, -0.11, 0.11) + sin(_boss_time * 7.0) * 0.018
		_set_hunt_shader_state(true, STOP_DISTANCE)
		_update_hunt_glow(STOP_DISTANCE)

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
