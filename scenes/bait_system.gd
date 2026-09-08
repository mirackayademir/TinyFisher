extends Node

# İlk yem sistemi.
# 1: Solucan      -> Sardalya / Levrek
# 2: Karides      -> Levrek / Uskumru
# 3: Canlı Sardalya -> Ton Balığı / Kılıç Balığı / Köpekbalığı
# Fener Balığı derinde Karides ve Canlı Sardalya'ya daha düşük ilgi gösterebilir.
#
# Solucan ve karides şimdilik test/ilk sürüm için sınırsızdır.
# Canlı Sardalya gerçekten oyuncunun envanterinden 1 Sardalya tüketir.
# Yem su içinde yay gibi salınır; uygun balıklar mesafeye ve yeme göre kademeli yaklaşır.

const BAIT_WORM: String = "Solucan"
const BAIT_SHRIMP: String = "Karides"
const BAIT_LIVE_SARDINE: String = "Canlı Sardalya"
const FISH_COLLISION_LAYER: int = 2
const FISH_SCAN_INTERVAL: float = 0.55

const SARDINE_TEXTURE: Texture2D = preload("res://assets/sardalya.png")

var selected_bait: String = BAIT_WORM

var _world: Node2D = null
var _hook: Area2D = null
var _hud: CanvasLayer = null
var _scene_id: int = 0
var _fish_scan_timer: float = 0.0
var _fish_nodes: Array[Node] = []
var _was_deployed: bool = false
var _time: float = 0.0

var _bait_panel: Panel = null
var _bait_title: Label = null
var _bait_options: Label = null
var _feedback_timer: float = 0.0
var _feedback_text: String = ""

var _bait_root: Node2D = null
var _worm_line: Line2D = null
var _worm_head: Polygon2D = null
var _shrimp_body: Polygon2D = null
var _shrimp_tail: Polygon2D = null
var _shrimp_antenna_a: Line2D = null
var _shrimp_antenna_b: Line2D = null
var _live_sardine: Sprite2D = null

var _last_hook_y: float = 0.0
var _sway_angle: float = 0.0
var _sway_velocity: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey:
		return

	var key_event: InputEventKey = event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return

	var requested_bait: String = ""
	if key_event.keycode == KEY_1 or key_event.physical_keycode == KEY_1:
		requested_bait = BAIT_WORM
	elif key_event.keycode == KEY_2 or key_event.physical_keycode == KEY_2:
		requested_bait = BAIT_SHRIMP
	elif key_event.keycode == KEY_3 or key_event.physical_keycode == KEY_3:
		requested_bait = BAIT_LIVE_SARDINE
	else:
		return

	if _hook != null and bool(_hook.get("deployed")):
		_show_feedback("Yemi değiştirmek için önce oltayı topla", 1.25)
		get_viewport().set_input_as_handled()
		return

	selected_bait = requested_bait
	if selected_bait == BAIT_LIVE_SARDINE and _get_sardine_count() <= 0:
		_show_feedback("Canlı Sardalya seçildi — envanterde Sardalya yok", 1.45)
	else:
		_show_feedback(selected_bait + " kancaya hazır", 0.85)

	_update_bait_hud()
	_update_bait_visual_visibility()
	get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	_time += delta
	_ensure_scene_nodes()
	if _world == null or _hook == null or _hud == null:
		return

	var deployed: bool = bool(_hook.get("deployed"))
	if deployed and not _was_deployed:
		_on_cast_started()
	elif not deployed and _was_deployed:
		_on_cast_finished()
	_was_deployed = deployed

	if _feedback_timer > 0.0:
		_feedback_timer -= delta
		if _feedback_timer <= 0.0:
			_feedback_text = ""

	_fish_scan_timer -= delta
	if _fish_scan_timer <= 0.0:
		_fish_scan_timer = FISH_SCAN_INTERVAL
		_refresh_fish_cache()

	_update_fish_bait_behavior(delta)
	_update_bait_physics(delta)
	_update_bait_hud()
	_update_bait_visual_visibility()


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
	_fish_nodes.clear()
	_bait_panel = null
	_bait_title = null
	_bait_options = null
	_bait_root = null
	_worm_line = null
	_worm_head = null
	_shrimp_body = null
	_shrimp_tail = null
	_shrimp_antenna_a = null
	_shrimp_antenna_b = null
	_live_sardine = null
	_was_deployed = false

	if _world == null:
		return

	_hook = _world.get_node_or_null("Boat/Hook") as Area2D
	_hud = _world.get_node_or_null("HUD") as CanvasLayer
	if _hook == null or _hud == null:
		return

	_last_hook_y = _hook.global_position.y
	_setup_bait_hud()
	_setup_bait_visuals()
	_refresh_fish_cache()
	_update_bait_hud()


func _setup_bait_hud() -> void:
	_bait_panel = _hud.get_node_or_null("BaitPanel") as Panel
	if _bait_panel == null:
		_bait_panel = Panel.new()
		_bait_panel.name = "BaitPanel"
		_bait_panel.z_index = 91
		_bait_panel.position = Vector2(14.0, 100.0)
		_bait_panel.size = Vector2(535.0, 72.0)
		_bait_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_hud.add_child(_bait_panel)

		var panel_style: StyleBoxFlat = StyleBoxFlat.new()
		panel_style.bg_color = Color(0.018, 0.055, 0.09, 0.92)
		panel_style.border_color = Color(0.23, 0.56, 0.67, 0.95)
		panel_style.border_width_left = 2
		panel_style.border_width_top = 2
		panel_style.border_width_right = 2
		panel_style.border_width_bottom = 2
		panel_style.corner_radius_top_left = 7
		panel_style.corner_radius_top_right = 7
		panel_style.corner_radius_bottom_left = 7
		panel_style.corner_radius_bottom_right = 7
		_bait_panel.add_theme_stylebox_override("panel", panel_style)

	_bait_title = _bait_panel.get_node_or_null("BaitTitle") as Label
	if _bait_title == null:
		_bait_title = Label.new()
		_bait_title.name = "BaitTitle"
		_bait_title.position = Vector2(12.0, 5.0)
		_bait_title.size = Vector2(510.0, 30.0)
		_bait_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_bait_title.add_theme_font_size_override("font_size", 17)
		_bait_title.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.9))
		_bait_title.add_theme_constant_override("shadow_offset_x", 1)
		_bait_title.add_theme_constant_override("shadow_offset_y", 1)
		_bait_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_bait_panel.add_child(_bait_title)

	_bait_options = _bait_panel.get_node_or_null("BaitOptions") as Label
	if _bait_options == null:
		_bait_options = Label.new()
		_bait_options.name = "BaitOptions"
		_bait_options.position = Vector2(12.0, 36.0)
		_bait_options.size = Vector2(510.0, 28.0)
		_bait_options.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_bait_options.add_theme_font_size_override("font_size", 13)
		_bait_options.add_theme_color_override("font_color", Color(0.74, 0.88, 0.92, 0.96))
		_bait_options.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_bait_panel.add_child(_bait_options)


func _setup_bait_visuals() -> void:
	_bait_root = _hook.get_node_or_null("BaitVisualRoot") as Node2D
	if _bait_root == null:
		_bait_root = Node2D.new()
		_bait_root.name = "BaitVisualRoot"
		_bait_root.position = Vector2(0.0, 15.0)
		_bait_root.z_index = 7
		_hook.add_child(_bait_root)

	_worm_line = Line2D.new()
	_worm_line.name = "Worm"
	_worm_line.width = 4.0
	_worm_line.default_color = Color(0.77, 0.27, 0.22, 1.0)
	_worm_line.antialiased = false
	_bait_root.add_child(_worm_line)

	_worm_head = Polygon2D.new()
	_worm_head.name = "WormHead"
	_worm_head.color = Color(0.93, 0.42, 0.33, 1.0)
	_worm_head.polygon = PackedVector2Array([
		Vector2(-3.0, -2.0), Vector2(2.0, -3.0), Vector2(4.0, 0.0),
		Vector2(2.0, 3.0), Vector2(-3.0, 2.0)
	])
	_bait_root.add_child(_worm_head)

	_shrimp_body = Polygon2D.new()
	_shrimp_body.name = "ShrimpBody"
	_shrimp_body.color = Color(1.0, 0.48, 0.28, 1.0)
	_shrimp_body.polygon = PackedVector2Array([
		Vector2(-8.0, -3.0), Vector2(-3.0, -7.0), Vector2(5.0, -6.0),
		Vector2(10.0, -1.0), Vector2(8.0, 5.0), Vector2(1.0, 8.0),
		Vector2(-6.0, 5.0), Vector2(-10.0, 1.0)
	])
	_bait_root.add_child(_shrimp_body)

	_shrimp_tail = Polygon2D.new()
	_shrimp_tail.name = "ShrimpTail"
	_shrimp_tail.position = Vector2(-9.0, 1.0)
	_shrimp_tail.color = Color(1.0, 0.67, 0.38, 0.95)
	_shrimp_tail.polygon = PackedVector2Array([
		Vector2(0.0, 0.0), Vector2(-7.0, -7.0), Vector2(-5.0, 0.0), Vector2(-8.0, 6.0)
	])
	_bait_root.add_child(_shrimp_tail)

	_shrimp_antenna_a = Line2D.new()
	_shrimp_antenna_a.name = "ShrimpAntennaA"
	_shrimp_antenna_a.width = 1.3
	_shrimp_antenna_a.default_color = Color(1.0, 0.72, 0.46, 0.92)
	_bait_root.add_child(_shrimp_antenna_a)

	_shrimp_antenna_b = Line2D.new()
	_shrimp_antenna_b.name = "ShrimpAntennaB"
	_shrimp_antenna_b.width = 1.3
	_shrimp_antenna_b.default_color = Color(1.0, 0.72, 0.46, 0.92)
	_bait_root.add_child(_shrimp_antenna_b)

	_live_sardine = Sprite2D.new()
	_live_sardine.name = "LiveSardine"
	_live_sardine.texture = SARDINE_TEXTURE
	_live_sardine.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_live_sardine.scale = Vector2(0.035, 0.035)
	_live_sardine.position = Vector2(0.0, 4.0)
	_bait_root.add_child(_live_sardine)

	_update_bait_visual_visibility()


func _on_cast_started() -> void:
	if selected_bait == BAIT_LIVE_SARDINE:
		var sardine_count: int = _get_sardine_count()
		if sardine_count <= 0:
			selected_bait = BAIT_WORM
			_show_feedback("Canlı Sardalya yok — otomatik Solucan takıldı", 1.65)
		else:
			_set_sardine_count(sardine_count - 1)
			_show_feedback("Canlı Sardalya yem olarak kullanıldı", 1.15)

	_sway_angle = 0.0
	_sway_velocity = 0.0
	_last_hook_y = _hook.global_position.y
	_update_bait_hud()


func _on_cast_finished() -> void:
	_restore_all_fish_collision()
	_sway_angle = 0.0
	_sway_velocity = 0.0


func _get_sardine_count() -> int:
	if _hud == null:
		return 0
	var inventory_variant: Variant = _hud.get("inventory")
	if not inventory_variant is Dictionary:
		return 0
	var inventory: Dictionary = inventory_variant as Dictionary
	return int(inventory.get("Sardalya", 0))


func _set_sardine_count(new_count: int) -> void:
	if _hud == null:
		return
	var inventory_variant: Variant = _hud.get("inventory")
	if not inventory_variant is Dictionary:
		return
	var inventory: Dictionary = inventory_variant as Dictionary
	inventory["Sardalya"] = maxi(new_count, 0)
	_hud.set("inventory", inventory)
	if _hud.has_method("update_inventory"):
		_hud.call("update_inventory")


func _refresh_fish_cache() -> void:
	_fish_nodes.clear()
	if _world != null:
		_collect_fish_nodes(_world)


func _collect_fish_nodes(node: Node) -> void:
	if node.has_method("hook_to") and node.has_method("release_from_hook"):
		_fish_nodes.append(node)
	for child: Node in node.get_children():
		_collect_fish_nodes(child)


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
			fish.set("world_hook", _hook)
			continue

		if bool(fish.get("is_hooked")):
			fish.set("collision_layer", FISH_COLLISION_LAYER)
			continue

		var fish_type: String = String(fish.get("fish_type"))
		var affinity: float = _bait_affinity(fish_type, selected_bait)

		# Uygun olmayan tür kancaya istemeden yapışmasın; uygun türler ise gerçekten yeme yönelir.
		fish.set("collision_layer", FISH_COLLISION_LAYER if affinity > 0.0 else 0)

		# Sardalya ve Uskumru eski davranış kodunda çıplak kancadan kaçıyor.
		# Yem kullanırken yaklaşmalarını burada fiziksel olarak yönetiyoruz.
		if affinity <= 0.0 or fish_type == "Sardalya" or fish_type == "Uskumru":
			fish.set("world_hook", null)
		else:
			fish.set("world_hook", _hook)

		if affinity <= 0.0 or hook_busy:
			continue

		var fish_2d: Node2D = fish as Node2D
		if fish_2d == null:
			continue

		var to_bait: Vector2 = _hook.global_position - fish_2d.global_position
		var distance: float = to_bait.length()
		var attraction_radius: float = _bait_attraction_radius(selected_bait) * (0.82 + affinity * 0.22)
		if distance <= 8.0 or distance >= attraction_radius:
			continue

		var distance_factor: float = 1.0 - clampf(distance / attraction_radius, 0.0, 1.0)
		var curiosity_pulse: float = 0.72 + 0.28 * sin(_time * 2.1 + float(fish.get_instance_id() % 1000) * 0.021)
		var pull_speed: float = _bait_pull_speed(selected_bait) * affinity * distance_factor * curiosity_pulse
		var pull: Vector2 = to_bait.normalized() * pull_speed * delta

		# Balık önce yanaşır, dikey eksende biraz daha temkinli davranır.
		pull.y *= 0.72
		fish_2d.global_position += pull

		if absf(to_bait.x) > 14.0:
			fish.set("direction", 1.0 if to_bait.x > 0.0 else -1.0)
			if fish.has_method("update_sprite_direction"):
				fish.call("update_sprite_direction")


func _bait_affinity(fish_type: String, bait: String) -> float:
	match bait:
		BAIT_WORM:
			match fish_type:
				"Sardalya": return 1.00
				"Levrek": return 0.86
				_: return 0.0
		BAIT_SHRIMP:
			match fish_type:
				"Levrek": return 0.78
				"Uskumru": return 1.00
				"Fener Balığı": return 0.48
				_: return 0.0
		BAIT_LIVE_SARDINE:
			match fish_type:
				"Ton Balığı": return 0.92
				"Kılıç Balığı": return 1.00
				"Köpekbalığı": return 1.15
				"Fener Balığı": return 0.34
				_: return 0.0
		_:
			return 0.0


func _bait_attraction_radius(bait: String) -> float:
	match bait:
		BAIT_WORM: return 285.0
		BAIT_SHRIMP: return 390.0
		BAIT_LIVE_SARDINE: return 620.0
		_: return 250.0


func _bait_pull_speed(bait: String) -> float:
	match bait:
		BAIT_WORM: return 42.0
		BAIT_SHRIMP: return 52.0
		BAIT_LIVE_SARDINE: return 68.0
		_: return 36.0


func _restore_all_fish_collision() -> void:
	for fish: Node in _fish_nodes:
		if not is_instance_valid(fish):
			continue
		fish.set("collision_layer", FISH_COLLISION_LAYER)
		if _hook != null:
			fish.set("world_hook", _hook)


func _update_bait_physics(delta: float) -> void:
	if _bait_root == null or _hook == null:
		return

	var deployed: bool = bool(_hook.get("deployed"))
	if not deployed:
		_bait_root.rotation = lerpf(_bait_root.rotation, 0.0, 0.22)
		_last_hook_y = _hook.global_position.y
		return

	var current_hook_y: float = _hook.global_position.y
	var hook_velocity_y: float = (current_hook_y - _last_hook_y) / maxf(delta, 0.001)
	_last_hook_y = current_hook_y

	# Su akıntısı + kancanın hızlanmasıyla küçük bir sarkaç/yay hareketi.
	var water_current: float = sin(_time * 0.72 + _hook.global_position.y * 0.0021) * 0.82
	water_current += sin(_time * 1.31 + _hook.global_position.x * 0.0013) * 0.28
	var movement_force: float = clampf(hook_velocity_y / 520.0, -1.0, 1.0) * 0.22
	var angular_acceleration: float = (-_sway_angle * 7.2) - (_sway_velocity * 3.4) + water_current + movement_force
	_sway_velocity += angular_acceleration * delta
	_sway_angle += _sway_velocity * delta
	_sway_angle = clampf(_sway_angle, -0.38, 0.38)
	_bait_root.rotation = _sway_angle
	_bait_root.position = Vector2(sin(_time * 0.83) * 1.8, 15.0 + sin(_time * 1.17) * 0.8)

	_update_worm_animation()
	_update_shrimp_animation()
	_update_live_sardine_animation()


func _update_worm_animation() -> void:
	if _worm_line == null or _worm_head == null:
		return
	var points: PackedVector2Array = PackedVector2Array()
	for i: int in range(7):
		var fi: float = float(i)
		var x: float = sin(_time * 6.4 + fi * 0.92) * (1.2 + fi * 0.34)
		points.append(Vector2(x, fi * 3.1))
	_worm_line.points = points
	if points.size() > 0:
		_worm_head.position = points[points.size() - 1]
	_worm_head.rotation = sin(_time * 7.1) * 0.22


func _update_shrimp_animation() -> void:
	if _shrimp_body == null or _shrimp_tail == null or _shrimp_antenna_a == null or _shrimp_antenna_b == null:
		return
	_shrimp_body.rotation = sin(_time * 3.6) * 0.07
	_shrimp_tail.rotation = sin(_time * 5.2 + 0.6) * 0.32
	_shrimp_antenna_a.points = PackedVector2Array([
		Vector2(8.0, -3.0), Vector2(15.0, -8.0), Vector2(23.0, -7.0 + sin(_time * 4.1) * 3.0)
	])
	_shrimp_antenna_b.points = PackedVector2Array([
		Vector2(8.0, 0.0), Vector2(16.0, 3.0), Vector2(24.0, 5.0 + sin(_time * 4.5 + 1.1) * 3.0)
	])


func _update_live_sardine_animation() -> void:
	if _live_sardine == null:
		return
	_live_sardine.rotation = sin(_time * 5.6) * 0.10
	_live_sardine.position.x = sin(_time * 3.2) * 2.4
	_live_sardine.position.y = 4.0 + sin(_time * 4.0 + 0.4) * 1.3
	var squash: float = 1.0 + sin(_time * 7.0) * 0.035
	_live_sardine.scale = Vector2(0.035 * squash, 0.035 / squash)


func _update_bait_visual_visibility() -> void:
	if _bait_root == null or _hook == null:
		return
	var show_bait: bool = bool(_hook.get("deployed")) and _hook.get("hooked_fish") == null
	_bait_root.visible = show_bait
	if not show_bait:
		return

	var show_worm: bool = selected_bait == BAIT_WORM
	var show_shrimp: bool = selected_bait == BAIT_SHRIMP
	var show_sardine: bool = selected_bait == BAIT_LIVE_SARDINE
	_worm_line.visible = show_worm
	_worm_head.visible = show_worm
	_shrimp_body.visible = show_shrimp
	_shrimp_tail.visible = show_shrimp
	_shrimp_antenna_a.visible = show_shrimp
	_shrimp_antenna_b.visible = show_shrimp
	_live_sardine.visible = show_sardine


func _show_feedback(text: String, duration: float) -> void:
	_feedback_text = text
	_feedback_timer = duration


func _update_bait_hud() -> void:
	if _bait_title == null or _bait_options == null:
		return

	var sardine_count: int = _get_sardine_count()
	var description: String = ""
	match selected_bait:
		BAIT_WORM:
			description = "Sardalya • Levrek"
		BAIT_SHRIMP:
			description = "Levrek • Uskumru"
		BAIT_LIVE_SARDINE:
			description = "Ton • Kılıç • Köpekbalığı"

	if _feedback_timer > 0.0 and not _feedback_text.is_empty():
		_bait_title.text = _feedback_text
		_bait_title.add_theme_color_override("font_color", Color(1.0, 0.78, 0.36, 1.0))
	elif selected_bait == BAIT_LIVE_SARDINE and sardine_count <= 0:
		_bait_title.text = "YEM: CANLI SARDALYA — ENVANTERDE YOK"
		_bait_title.add_theme_color_override("font_color", Color(1.0, 0.42, 0.32, 1.0))
	else:
		_bait_title.text = "YEM: " + selected_bait.to_upper() + "   →   " + description
		_bait_title.add_theme_color_override("font_color", Color(0.94, 0.96, 0.83, 1.0))

	_bait_options.text = "[1] Solucan ∞     [2] Karides ∞     [3] Canlı Sardalya x%d" % sardine_count
