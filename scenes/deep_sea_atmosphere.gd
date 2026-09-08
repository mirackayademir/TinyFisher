extends Node

# Derin deniz atmosferi + yem sistemi aynı çalışan autoload içinde tutuluyor.
# Bu dosya zaten derinlik kararmasını çalıştırdığı için yem HUD'u ve yem fiziği
# de aynı runtime üzerinden kesin olarak kuruluyor.

const SHALLOW_START_M: float = 18.0
const HOOK_LIGHT_START_M: float = 58.0
const SCAN_INTERVAL: float = 0.30
const FISH_COLLISION_LAYER: int = 2

const BAIT_WORM: String = "Solucan"
const BAIT_SHRIMP: String = "Karides"
const BAIT_LIVE_SARDINE: String = "Canlı Sardalya"
const SARDINE_TEXTURE: Texture2D = preload("res://assets/sardalya.png")

var selected_bait: String = BAIT_WORM

var _world: Node2D = null
var _hook: Area2D = null
var _hud: CanvasLayer = null
var _canvas_modulate: CanvasModulate = null
var _hook_light: PointLight2D = null
var _light_texture: Texture2D = null
var _scene_id: int = 0
var _scan_timer: float = 0.0
var _time: float = 0.0
var _fish_nodes: Array[Node] = []
var _was_deployed: bool = false

# Yem HUD
var _bait_panel: Panel = null
var _bait_title: Label = null
var _bait_options: Label = null
var _bait_feedback: Label = null
var _feedback_timer: float = 0.0

# Kanca üzerindeki yem çizimleri
var _bait_root: Node2D = null
var _worm: Line2D = null
var _worm_head: Polygon2D = null
var _shrimp_body: Polygon2D = null
var _shrimp_tail: Polygon2D = null
var _shrimp_ant_a: Line2D = null
var _shrimp_ant_b: Line2D = null
var _live_sardine: Sprite2D = null

# Su içinde sarkaç benzeri hareket
var _last_hook_y: float = 0.0
var _sway_angle: float = 0.0
var _sway_velocity: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_light_texture = _create_radial_light_texture(128)


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return

	var key_event: InputEventKey = event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return

	var requested: String = ""
	if key_event.physical_keycode == KEY_1:
		requested = BAIT_WORM
	elif key_event.physical_keycode == KEY_2:
		requested = BAIT_SHRIMP
	elif key_event.physical_keycode == KEY_3:
		requested = BAIT_LIVE_SARDINE
	else:
		return

	if _hook != null and bool(_hook.get("deployed")):
		_show_bait_feedback("Önce oltayı topla, sonra yemi değiştir", 1.3)
		return

	selected_bait = requested
	if selected_bait == BAIT_LIVE_SARDINE and _get_sardine_count() <= 0:
		_show_bait_feedback("Canlı Sardalya seçildi ama envanterde yok", 1.5)
	else:
		_show_bait_feedback(selected_bait + " seçildi", 0.9)
	_update_bait_hud()
	_update_bait_visibility()


func _process(delta: float) -> void:
	_time += delta
	_ensure_scene_nodes()
	if _world == null or _hook == null:
		return

	var depth_m: float = _get_current_depth_meters()
	_update_ambient(depth_m)
	_update_hook_light(depth_m)

	var deployed: bool = bool(_hook.get("deployed"))
	if deployed and not _was_deployed:
		_on_cast_started()
	elif not deployed and _was_deployed:
		_on_cast_finished()
	_was_deployed = deployed

	if _feedback_timer > 0.0:
		_feedback_timer -= delta

	_scan_timer -= delta
	if _scan_timer <= 0.0:
		_scan_timer = SCAN_INTERVAL
		_refresh_fish_cache()
		_update_angler_lights()

	_update_bait_physics(delta)
	_update_bait_visibility()
	_update_bait_hud()
	_update_fish_bait_behavior(delta)


func _ensure_scene_nodes() -> void:
	var current_scene: Node = get_tree().current_scene
	if current_scene == null:
		return

	var current_id: int = current_scene.get_instance_id()
	if _scene_id == current_id and is_instance_valid(_world) and is_instance_valid(_hook) and is_instance_valid(_hud):
		return

	_scene_id = current_id
	_world = current_scene as Node2D
	_hook = null
	_hud = null
	_canvas_modulate = null
	_hook_light = null
	_bait_panel = null
	_bait_title = null
	_bait_options = null
	_bait_feedback = null
	_bait_root = null
	_worm = null
	_worm_head = null
	_shrimp_body = null
	_shrimp_tail = null
	_shrimp_ant_a = null
	_shrimp_ant_b = null
	_live_sardine = null
	_fish_nodes.clear()
	_was_deployed = false

	if _world == null:
		return

	_hook = _world.get_node_or_null("Boat/Hook") as Area2D
	_hud = _world.get_node_or_null("HUD") as CanvasLayer
	if _hook == null or _hud == null:
		return

	_canvas_modulate = _world.get_node_or_null("DeepSeaCanvasModulate") as CanvasModulate
	if _canvas_modulate == null:
		_canvas_modulate = CanvasModulate.new()
		_canvas_modulate.name = "DeepSeaCanvasModulate"
		_canvas_modulate.color = Color.WHITE
		_world.add_child(_canvas_modulate)

	_hook_light = _hook.get_node_or_null("DeepSeaHookLight") as PointLight2D
	if _hook_light == null:
		_hook_light = PointLight2D.new()
		_hook_light.name = "DeepSeaHookLight"
		_hook_light.texture = _light_texture
		_hook_light.color = Color(0.46, 0.74, 1.0, 1.0)
		_hook_light.energy = 0.0
		_hook_light.texture_scale = 2.8
		_hook_light.shadow_enabled = false
		_hook_light.z_index = 20
		_hook.add_child(_hook_light)

	_last_hook_y = _hook.global_position.y
	_setup_bait_hud()
	_setup_bait_visuals()
	_refresh_fish_cache()
	_update_bait_hud()


# -----------------------------------------------------------------------------
# DERİNLİK / IŞIK
# -----------------------------------------------------------------------------

func _get_current_depth_meters() -> float:
	if _hook == null or not bool(_hook.get("deployed")):
		return 0.0

	var start_position: Vector2 = _hook.get("start_position")
	var max_depth: float = float(_hook.get("max_depth"))
	var max_depth_meters: float = float(_hook.get("max_depth_meters"))
	var depth_pixels: float = clampf(_hook.position.y - start_position.y, 0.0, max_depth)
	return (depth_pixels / maxf(max_depth, 1.0)) * max_depth_meters


func _update_ambient(depth_m: float) -> void:
	if _canvas_modulate == null:
		return

	var target: Color = Color.WHITE
	if depth_m <= SHALLOW_START_M:
		target = Color.WHITE
	elif depth_m < 35.0:
		target = Color.WHITE.lerp(Color(0.62, 0.76, 0.88, 1.0), inverse_lerp(SHALLOW_START_M, 35.0, depth_m))
	elif depth_m < 55.0:
		target = Color(0.62, 0.76, 0.88, 1.0).lerp(Color(0.32, 0.48, 0.62, 1.0), inverse_lerp(35.0, 55.0, depth_m))
	elif depth_m < 72.0:
		target = Color(0.32, 0.48, 0.62, 1.0).lerp(Color(0.15, 0.26, 0.39, 1.0), inverse_lerp(55.0, 72.0, depth_m))
	elif depth_m < 86.0:
		target = Color(0.15, 0.26, 0.39, 1.0).lerp(Color(0.075, 0.14, 0.24, 1.0), inverse_lerp(72.0, 86.0, depth_m))
	else:
		target = Color(0.075, 0.14, 0.24, 1.0).lerp(Color(0.025, 0.055, 0.11, 1.0), clampf(inverse_lerp(86.0, 100.0, depth_m), 0.0, 1.0))
	_canvas_modulate.color = _canvas_modulate.color.lerp(target, 0.14)


func _update_hook_light(depth_m: float) -> void:
	if _hook_light == null:
		return
	if depth_m < HOOK_LIGHT_START_M or not bool(_hook.get("deployed")):
		_hook_light.energy = lerpf(_hook_light.energy, 0.0, 0.20)
		return
	var depth_t: float = clampf(inverse_lerp(HOOK_LIGHT_START_M, 100.0, depth_m), 0.0, 1.0)
	_hook_light.energy = lerpf(_hook_light.energy, lerpf(0.46, 1.62, depth_t), 0.14)
	_hook_light.texture_scale = lerpf(2.20, 3.05, depth_t)


# -----------------------------------------------------------------------------
# YEM HUD
# -----------------------------------------------------------------------------

func _setup_bait_hud() -> void:
	_bait_panel = _hud.get_node_or_null("BaitPanel") as Panel
	if _bait_panel == null:
		_bait_panel = Panel.new()
		_bait_panel.name = "BaitPanel"
		_bait_panel.z_index = 250
		_bait_panel.position = Vector2(720.0, 540.0)
		_bait_panel.size = Vector2(545.0, 86.0)
		_bait_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_hud.add_child(_bait_panel)

		var style: StyleBoxFlat = StyleBoxFlat.new()
		style.bg_color = Color(0.012, 0.045, 0.075, 0.96)
		style.border_color = Color(0.95, 0.63, 0.19, 0.98)
		style.border_width_left = 3
		style.border_width_top = 3
		style.border_width_right = 3
		style.border_width_bottom = 3
		style.corner_radius_top_left = 8
		style.corner_radius_top_right = 8
		style.corner_radius_bottom_left = 8
		style.corner_radius_bottom_right = 8
		_bait_panel.add_theme_stylebox_override("panel", style)

	_bait_panel.visible = true

	_bait_title = _bait_panel.get_node_or_null("BaitTitle") as Label
	if _bait_title == null:
		_bait_title = Label.new()
		_bait_title.name = "BaitTitle"
		_bait_title.position = Vector2(12.0, 5.0)
		_bait_title.size = Vector2(520.0, 28.0)
		_bait_title.add_theme_font_size_override("font_size", 18)
		_bait_title.add_theme_color_override("font_color", Color(1.0, 0.84, 0.42, 1.0))
		_bait_title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.95))
		_bait_title.add_theme_constant_override("shadow_offset_x", 2)
		_bait_title.add_theme_constant_override("shadow_offset_y", 2)
		_bait_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_bait_panel.add_child(_bait_title)

	_bait_options = _bait_panel.get_node_or_null("BaitOptions") as Label
	if _bait_options == null:
		_bait_options = Label.new()
		_bait_options.name = "BaitOptions"
		_bait_options.position = Vector2(12.0, 34.0)
		_bait_options.size = Vector2(520.0, 24.0)
		_bait_options.add_theme_font_size_override("font_size", 14)
		_bait_options.add_theme_color_override("font_color", Color(0.83, 0.94, 0.98, 1.0))
		_bait_options.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_bait_panel.add_child(_bait_options)

	_bait_feedback = _bait_panel.get_node_or_null("BaitFeedback") as Label
	if _bait_feedback == null:
		_bait_feedback = Label.new()
		_bait_feedback.name = "BaitFeedback"
		_bait_feedback.position = Vector2(12.0, 59.0)
		_bait_feedback.size = Vector2(520.0, 20.0)
		_bait_feedback.add_theme_font_size_override("font_size", 12)
		_bait_feedback.add_theme_color_override("font_color", Color(0.62, 0.84, 0.76, 1.0))
		_bait_feedback.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_bait_panel.add_child(_bait_feedback)


func _update_bait_hud() -> void:
	if _bait_panel == null or _bait_title == null or _bait_options == null or _bait_feedback == null:
		return

	# Mücadele sırasında yem seçimi kullanılamadığı için paneli gizle.
	# Böylece Fight HUD ve Misina Gerilimi HUD'u ile hiçbir zaman çakışmaz.
	var fight_active: bool = _hook != null and _hook.get("hooked_fish") != null
	_bait_panel.visible = not fight_active
	if fight_active:
		return

	var target_text: String = ""
	if selected_bait == BAIT_WORM:
		target_text = "Sardalya / Levrek"
	elif selected_bait == BAIT_SHRIMP:
		target_text = "Levrek / Uskumru"
	else:
		target_text = "Ton / Kılıç / Köpekbalığı"

	_bait_title.text = "YEM: " + selected_bait.to_upper() + "  →  " + target_text
	_bait_options.text = "[1] Solucan ∞     [2] Karides ∞     [3] Canlı Sardalya x%d" % _get_sardine_count()
	if _feedback_timer > 0.0:
		_bait_feedback.text = "• " + _bait_feedback.text.trim_prefix("• ")
	else:
		_bait_feedback.text = "1 / 2 / 3 ile yem seç — yem kancanın altında hareket eder"


func _show_bait_feedback(text: String, duration: float) -> void:
	_feedback_timer = duration
	if _bait_feedback != null:
		_bait_feedback.text = text


# -----------------------------------------------------------------------------
# YEM GÖRSELİ VE FİZİĞİ
# -----------------------------------------------------------------------------

func _setup_bait_visuals() -> void:
	_bait_root = _hook.get_node_or_null("BaitVisualRoot") as Node2D
	if _bait_root == null:
		_bait_root = Node2D.new()
		_bait_root.name = "BaitVisualRoot"
		_bait_root.position = Vector2(0.0, 24.0)
		_bait_root.z_index = 30
		_hook.add_child(_bait_root)

	_worm = Line2D.new()
	_worm.width = 5.0
	_worm.default_color = Color(0.93, 0.32, 0.24, 1.0)
	_worm.antialiased = false
	_bait_root.add_child(_worm)

	_worm_head = Polygon2D.new()
	_worm_head.color = Color(1.0, 0.55, 0.38, 1.0)
	_worm_head.polygon = PackedVector2Array([Vector2(-4,-3), Vector2(3,-3), Vector2(5,0), Vector2(3,4), Vector2(-4,3)])
	_bait_root.add_child(_worm_head)

	_shrimp_body = Polygon2D.new()
	_shrimp_body.color = Color(1.0, 0.42, 0.24, 1.0)
	_shrimp_body.polygon = PackedVector2Array([Vector2(-12,-5), Vector2(-5,-10), Vector2(6,-9), Vector2(14,-2), Vector2(12,7), Vector2(2,11), Vector2(-8,8), Vector2(-14,2)])
	_bait_root.add_child(_shrimp_body)

	_shrimp_tail = Polygon2D.new()
	_shrimp_tail.position = Vector2(-13.0, 2.0)
	_shrimp_tail.color = Color(1.0, 0.70, 0.38, 1.0)
	_shrimp_tail.polygon = PackedVector2Array([Vector2(0,0), Vector2(-10,-9), Vector2(-7,0), Vector2(-11,8)])
	_bait_root.add_child(_shrimp_tail)

	_shrimp_ant_a = Line2D.new()
	_shrimp_ant_a.width = 1.5
	_shrimp_ant_a.default_color = Color(1.0, 0.78, 0.48, 1.0)
	_bait_root.add_child(_shrimp_ant_a)

	_shrimp_ant_b = Line2D.new()
	_shrimp_ant_b.width = 1.5
	_shrimp_ant_b.default_color = Color(1.0, 0.78, 0.48, 1.0)
	_bait_root.add_child(_shrimp_ant_b)

	_live_sardine = Sprite2D.new()
	_live_sardine.texture = SARDINE_TEXTURE
	_live_sardine.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_live_sardine.scale = Vector2(0.052, 0.052)
	_live_sardine.position = Vector2(0.0, 6.0)
	_bait_root.add_child(_live_sardine)

	_update_bait_visibility()


func _update_bait_visibility() -> void:
	if _bait_root == null or _hook == null:
		return
	var show: bool = bool(_hook.get("deployed")) and _hook.get("hooked_fish") == null
	_bait_root.visible = show
	if not show:
		return

	var worm_on: bool = selected_bait == BAIT_WORM
	var shrimp_on: bool = selected_bait == BAIT_SHRIMP
	var sardine_on: bool = selected_bait == BAIT_LIVE_SARDINE
	_worm.visible = worm_on
	_worm_head.visible = worm_on
	_shrimp_body.visible = shrimp_on
	_shrimp_tail.visible = shrimp_on
	_shrimp_ant_a.visible = shrimp_on
	_shrimp_ant_b.visible = shrimp_on
	_live_sardine.visible = sardine_on


func _update_bait_physics(delta: float) -> void:
	if _bait_root == null or _hook == null:
		return

	if not bool(_hook.get("deployed")):
		_bait_root.rotation = lerpf(_bait_root.rotation, 0.0, 0.22)
		_last_hook_y = _hook.global_position.y
		return

	var current_y: float = _hook.global_position.y
	var velocity_y: float = (current_y - _last_hook_y) / maxf(delta, 0.001)
	_last_hook_y = current_y
	var current_force: float = sin(_time * 0.85 + _hook.global_position.y * 0.002) * 0.75
	current_force += clampf(velocity_y / 500.0, -1.0, 1.0) * 0.20
	var acceleration: float = -_sway_angle * 7.0 - _sway_velocity * 3.2 + current_force
	_sway_velocity += acceleration * delta
	_sway_angle += _sway_velocity * delta
	_sway_angle = clampf(_sway_angle, -0.42, 0.42)
	_bait_root.rotation = _sway_angle
	_bait_root.position = Vector2(sin(_time * 0.8) * 2.0, 24.0 + sin(_time * 1.15) * 1.2)

	# Solucan kıvrılması
	var points: PackedVector2Array = PackedVector2Array()
	for i: int in range(8):
		var fi: float = float(i)
		points.append(Vector2(sin(_time * 6.2 + fi * 0.9) * (1.5 + fi * 0.35), fi * 3.5))
	_worm.points = points
	if points.size() > 0:
		_worm_head.position = points[points.size() - 1]

	# Karides kuyruğu ve antenleri
	_shrimp_body.rotation = sin(_time * 3.2) * 0.08
	_shrimp_tail.rotation = sin(_time * 5.3) * 0.36
	_shrimp_ant_a.points = PackedVector2Array([Vector2(10,-4), Vector2(20,-10), Vector2(31,-8 + sin(_time * 4.0) * 3.0)])
	_shrimp_ant_b.points = PackedVector2Array([Vector2(11,0), Vector2(21,5), Vector2(32,7 + sin(_time * 4.4 + 1.0) * 3.0)])

	# Canlı sardalya küçük yüzme/çırpınma hareketi
	_live_sardine.rotation = sin(_time * 6.0) * 0.13
	_live_sardine.position = Vector2(sin(_time * 3.4) * 3.2, 6.0 + sin(_time * 4.1) * 1.8)


# -----------------------------------------------------------------------------
# YEM TÜKETİMİ / BALIK ÇEKİMİ
# -----------------------------------------------------------------------------

func _on_cast_started() -> void:
	if selected_bait == BAIT_LIVE_SARDINE:
		var count: int = _get_sardine_count()
		if count <= 0:
			selected_bait = BAIT_WORM
			_show_bait_feedback("Canlı Sardalya yok — Solucan takıldı", 1.5)
		else:
			_set_sardine_count(count - 1)
			_show_bait_feedback("1 Sardalya canlı yem olarak kullanıldı", 1.2)
	_sway_angle = 0.0
	_sway_velocity = 0.0
	_last_hook_y = _hook.global_position.y


func _on_cast_finished() -> void:
	_restore_fish_collision()
	_sway_angle = 0.0
	_sway_velocity = 0.0


func _get_sardine_count() -> int:
	if _hud == null:
		return 0
	var inv: Variant = _hud.get("inventory")
	if typeof(inv) != TYPE_DICTIONARY:
		return 0
	var inventory: Dictionary = inv
	return int(inventory.get("Sardalya", 0))


func _set_sardine_count(value: int) -> void:
	if _hud == null:
		return
	var inv: Variant = _hud.get("inventory")
	if typeof(inv) != TYPE_DICTIONARY:
		return
	var inventory: Dictionary = inv
	inventory["Sardalya"] = maxi(value, 0)
	_hud.set("inventory", inventory)
	if _hud.has_method("update_inventory"):
		_hud.call("update_inventory")


func _refresh_fish_cache() -> void:
	_fish_nodes.clear()
	if _world != null:
		_collect_fish(_world)


func _collect_fish(node: Node) -> void:
	if node.has_method("hook_to") and node.has_method("release_from_hook"):
		_fish_nodes.append(node)
	for child: Node in node.get_children():
		_collect_fish(child)


func _bait_affinity(fish_type: String) -> float:
	if selected_bait == BAIT_WORM:
		if fish_type == "Sardalya": return 1.0
		if fish_type == "Levrek": return 0.86
	elif selected_bait == BAIT_SHRIMP:
		if fish_type == "Levrek": return 0.78
		if fish_type == "Uskumru": return 1.0
		if fish_type == "Fener Balığı": return 0.42
	elif selected_bait == BAIT_LIVE_SARDINE:
		if fish_type == "Ton Balığı": return 0.92
		if fish_type == "Kılıç Balığı": return 1.0
		if fish_type == "Köpekbalığı": return 1.15
		if fish_type == "Fener Balığı": return 0.32
	return 0.0


func _bait_radius() -> float:
	if selected_bait == BAIT_WORM: return 300.0
	if selected_bait == BAIT_SHRIMP: return 410.0
	return 650.0


func _bait_pull_speed() -> float:
	if selected_bait == BAIT_WORM: return 46.0
	if selected_bait == BAIT_SHRIMP: return 58.0
	return 76.0


func _update_fish_bait_behavior(delta: float) -> void:
	if _hook == null:
		return

	var deployed: bool = bool(_hook.get("deployed"))
	var hook_busy: bool = _hook.get("hooked_fish") != null
	for fish: Node in _fish_nodes:
		if not is_instance_valid(fish):
			continue
		if not deployed:
			fish.set("collision_layer", FISH_COLLISION_LAYER)
			continue
		if bool(fish.get("is_hooked")):
			fish.set("collision_layer", FISH_COLLISION_LAYER)
			continue

		var fish_type: String = String(fish.get("fish_type"))
		var affinity: float = _bait_affinity(fish_type)
		fish.set("collision_layer", FISH_COLLISION_LAYER if affinity > 0.0 else 0)
		if affinity <= 0.0 or hook_busy:
			continue

		var fish_2d: Node2D = fish as Node2D
		if fish_2d == null:
			continue
		var to_bait: Vector2 = _hook.global_position - fish_2d.global_position
		var distance: float = to_bait.length()
		var radius: float = _bait_radius() * (0.82 + affinity * 0.20)
		if distance < 10.0 or distance > radius:
			continue

		var distance_factor: float = 1.0 - clampf(distance / radius, 0.0, 1.0)
		var pulse: float = 0.78 + 0.22 * sin(_time * 2.0 + float(fish.get_instance_id() % 1000) * 0.02)
		var movement: Vector2 = to_bait.normalized() * _bait_pull_speed() * affinity * distance_factor * pulse * delta
		movement.y *= 0.72
		fish_2d.global_position += movement
		if absf(to_bait.x) > 12.0:
			fish.set("direction", 1.0 if to_bait.x > 0.0 else -1.0)
			if fish.has_method("update_sprite_direction"):
				fish.call("update_sprite_direction")


func _restore_fish_collision() -> void:
	for fish: Node in _fish_nodes:
		if is_instance_valid(fish):
			fish.set("collision_layer", FISH_COLLISION_LAYER)


# -----------------------------------------------------------------------------
# FENER BALIĞI IŞIĞI
# -----------------------------------------------------------------------------

func _update_angler_lights() -> void:
	for fish: Node in _fish_nodes:
		if not is_instance_valid(fish):
			continue
		if String(fish.get("fish_type")) != "Fener Balığı":
			continue
		var fish_2d: Node2D = fish as Node2D
		if fish_2d == null:
			continue
		var light: PointLight2D = fish_2d.get_node_or_null("AnglerNaturalLight") as PointLight2D
		if light == null:
			light = PointLight2D.new()
			light.name = "AnglerNaturalLight"
			light.texture = _light_texture
			light.texture_scale = 1.72
			light.color = Color(1.0, 0.49, 0.12, 1.0)
			light.shadow_enabled = false
			light.z_index = 21
			fish_2d.add_child(light)
		var phase: float = float(fish_2d.get_instance_id() % 1000) * 0.013
		light.energy = 1.28 + sin(_time * 2.6 + phase) * 0.24


func _create_radial_light_texture(size: int) -> Texture2D:
	var image: Image = Image.create(size, size, false, Image.FORMAT_RGBA8)
	var center: Vector2 = Vector2(float(size - 1), float(size - 1)) * 0.5
	var radius: float = float(size) * 0.5
	for y: int in range(size):
		for x: int in range(size):
			var distance_ratio: float = Vector2(float(x), float(y)).distance_to(center) / radius
			var intensity: float = pow(clampf(1.0 - distance_ratio, 0.0, 1.0), 2.15)
			image.set_pixel(x, y, Color(intensity, intensity, intensity, 1.0))
	return ImageTexture.create_from_image(image)