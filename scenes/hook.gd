extends Area2D

const BASE_DEPTH_PIXELS: float = 1700.0
const DEPTH_PER_LEVEL: float = 350.0
const BASE_DEPTH_METERS: int = 50
const DEPTH_METERS_PER_LEVEL: int = 10

# TEST MODU: Yeni derin su balıklarını geliştirme kasmadan deneyebilmek için
# fiziksel olta erişimini geçici olarak maksimum seviyede tutuyoruz.
# İlerleme dengesi testleri başladığında false yapılacak.
const TEST_FULL_DEPTH_UNLOCK: bool = true
const TEST_DEPTH_LEVEL: int = 5

@export var hook_speed: float = 220.0
@export var reel_speed: float = 240.0
@export var reel_speed_per_level: float = 40.0
@export var max_depth: float = BASE_DEPTH_PIXELS
@export var camera_surface_y: float = 0.0
@export var camera_deep_y: float = 1420.0
@export var camera_follow_speed: float = 4.0

var start_position: Vector2
var deployed: bool = false
var hooked_fish: Area2D = null
var depth_level: int = 0
var max_depth_meters: int = BASE_DEPTH_METERS
var depth_panel: Panel
var depth_label: Label

var line_tension: float = 0.0
var tension_gain_rate: float = 15.0
var tension_recovery_rate: float = 28.0
var tension_fish_pull: float = 4.0
var tension_time: float = 0.0
var tension_panel: Panel
var tension_bar: ProgressBar
var tension_label: Label
var tension_hint: Label
var tension_fill_style: StyleBoxFlat
var line_break_feedback_timer: float = 0.0
var line_strength_level: int = 0

@onready var hook_line: Line2D = $"../HookLine"
@onready var hud = $"../../HUD"
@onready var camera: Camera2D = $"../Camera2D"
@onready var boat: CharacterBody2D = $".."
@onready var world = $"../.."


func _ready() -> void:
	start_position = position
	max_depth = maxf(max_depth, BASE_DEPTH_PIXELS)
	camera_deep_y = maxf(camera_deep_y, 1420.0)

	var water: ColorRect = world.get_node_or_null("Water") as ColorRect
	if water != null:
		water.offset_bottom = maxf(water.offset_bottom, 2700.0)

	collision_layer = 0
	collision_mask = 2
	area_entered.connect(_on_hook_area_entered)
	hook_line.width = 2.0
	hook_line.default_color = Color(0.88, 0.92, 0.95, 0.95)
	hook_line.points = PackedVector2Array([start_position, start_position])
	camera.position = Vector2(350.0, camera_surface_y)

	_setup_depth_hud()
	_setup_tension_hud()
	_update_depth_hud()
	_update_tension_hud()


func _setup_depth_hud() -> void:
	depth_panel = Panel.new()
	depth_panel.name = "DepthPanel"
	depth_panel.z_index = 92
	depth_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(depth_panel)

	var panel_style: StyleBoxFlat = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.015, 0.075, 0.12, 0.92)
	panel_style.border_color = Color(0.22, 0.72, 0.92, 0.92)
	panel_style.border_width_left = 2
	panel_style.border_width_top = 2
	panel_style.border_width_right = 2
	panel_style.border_width_bottom = 2
	panel_style.corner_radius_top_left = 8
	panel_style.corner_radius_top_right = 8
	panel_style.corner_radius_bottom_left = 8
	panel_style.corner_radius_bottom_right = 8
	depth_panel.add_theme_stylebox_override("panel", panel_style)

	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	depth_panel.size = Vector2(190.0, 48.0)
	depth_panel.position = Vector2((viewport_size.x - depth_panel.size.x) * 0.5, 16.0)
	depth_panel.visible = false

	depth_label = Label.new()
	depth_label.name = "DepthLabel"
	depth_label.position = Vector2(8.0, 5.0)
	depth_label.size = Vector2(174.0, 38.0)
	depth_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	depth_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	depth_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	depth_label.add_theme_font_size_override("font_size", 20)
	depth_label.add_theme_color_override("font_color", Color(0.83, 0.96, 1.0, 1.0))
	depth_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.9))
	depth_label.add_theme_constant_override("shadow_offset_x", 2)
	depth_label.add_theme_constant_override("shadow_offset_y", 2)
	depth_panel.add_child(depth_label)


func _setup_tension_hud() -> void:
	tension_panel = Panel.new()
	tension_panel.name = "LineTensionPanel"
	tension_panel.z_index = 93
	tension_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(tension_panel)

	var panel_style: StyleBoxFlat = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.018, 0.045, 0.075, 0.94)
	panel_style.border_color = Color(0.20, 0.64, 0.76, 0.95)
	panel_style.border_width_left = 2
	panel_style.border_width_top = 2
	panel_style.border_width_right = 2
	panel_style.border_width_bottom = 2
	panel_style.corner_radius_top_left = 8
	panel_style.corner_radius_top_right = 8
	panel_style.corner_radius_bottom_left = 8
	panel_style.corner_radius_bottom_right = 8
	tension_panel.add_theme_stylebox_override("panel", panel_style)

	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	tension_panel.size = Vector2(390.0, 82.0)
	tension_panel.position = Vector2((viewport_size.x - tension_panel.size.x) * 0.5, 214.0)
	tension_panel.visible = false

	tension_label = Label.new()
	tension_label.name = "TensionLabel"
	tension_label.position = Vector2(14.0, 7.0)
	tension_label.size = Vector2(362.0, 24.0)
	tension_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tension_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	tension_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tension_label.add_theme_font_size_override("font_size", 17)
	tension_label.add_theme_color_override("font_color", Color(0.84, 0.95, 1.0, 1.0))
	tension_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.9))
	tension_label.add_theme_constant_override("shadow_offset_x", 1)
	tension_label.add_theme_constant_override("shadow_offset_y", 1)
	tension_panel.add_child(tension_label)

	tension_bar = ProgressBar.new()
	tension_bar.name = "TensionBar"
	tension_bar.position = Vector2(18.0, 34.0)
	tension_bar.size = Vector2(354.0, 20.0)
	tension_bar.min_value = 0.0
	tension_bar.max_value = 100.0
	tension_bar.value = 0.0
	tension_bar.show_percentage = false
	tension_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var bar_bg: StyleBoxFlat = StyleBoxFlat.new()
	bar_bg.bg_color = Color(0.025, 0.08, 0.11, 1.0)
	bar_bg.border_color = Color(0.10, 0.27, 0.34, 1.0)
	bar_bg.border_width_left = 1
	bar_bg.border_width_top = 1
	bar_bg.border_width_right = 1
	bar_bg.border_width_bottom = 1
	bar_bg.corner_radius_top_left = 5
	bar_bg.corner_radius_top_right = 5
	bar_bg.corner_radius_bottom_left = 5
	bar_bg.corner_radius_bottom_right = 5
	tension_bar.add_theme_stylebox_override("background", bar_bg)

	tension_fill_style = StyleBoxFlat.new()
	tension_fill_style.bg_color = Color(0.20, 0.82, 0.50, 0.96)
	tension_fill_style.corner_radius_top_left = 4
	tension_fill_style.corner_radius_top_right = 4
	tension_fill_style.corner_radius_bottom_left = 4
	tension_fill_style.corner_radius_bottom_right = 4
	tension_bar.add_theme_stylebox_override("fill", tension_fill_style)
	tension_panel.add_child(tension_bar)

	tension_hint = Label.new()
	tension_hint.name = "TensionHint"
	tension_hint.position = Vector2(12.0, 57.0)
	tension_hint.size = Vector2(366.0, 18.0)
	tension_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tension_hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	tension_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tension_hint.text = "Gerilim yükselirse sarmayı bırak ve misinayı dinlendir"
	tension_hint.add_theme_font_size_override("font_size", 12)
	tension_hint.add_theme_color_override("font_color", Color(0.70, 0.84, 0.89, 0.92))
	tension_panel.add_child(tension_hint)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		deploy()
		get_viewport().set_input_as_handled()


func deploy() -> void:
	if deployed or world.docked or not hud.can_add_fish():
		return

	deployed = true
	boat.set_movement_enabled(true)
	boat.play_cast_animation()
	_update_depth_hud()


func _physics_process(delta: float) -> void:
	if Input.is_physical_key_pressed(KEY_S):
		deploy()

	if line_break_feedback_timer > 0.0:
		line_break_feedback_timer -= delta
		if line_break_feedback_timer <= 0.0 and tension_panel != null:
			tension_panel.visible = false

	if deployed:
		if is_instance_valid(hooked_fish):
			_update_line_tension(delta)
			if not deployed:
				_update_line_visual()
				_update_depth_hud()
				return

			if hud.is_fight_won() and is_reeling():
				position.y -= reel_speed * delta
		else:
			position.y += (-reel_speed if is_reeling() else hook_speed) * delta

		position.y = clampf(position.y, start_position.y, start_position.y + max_depth)
		position.x = start_position.x

		if position.y <= start_position.y:
			land_catch()
		elif not is_instance_valid(hooked_fish):
			for area: Area2D in get_overlapping_areas():
				_on_hook_area_entered(area)

	hook_line.set_point_position(0, boat.get_line_origin_local())
	hook_line.set_point_position(1, position)
	_update_line_visual()
	update_camera(delta)
	_update_depth_hud()
	_update_tension_hud()


func _update_line_tension(delta: float) -> void:
	if not is_instance_valid(hooked_fish) or not hud.fight_active:
		return

	tension_time += delta
	var pull_wave: float = 0.55 + absf(sin(tension_time * 3.1)) * 0.75
	var reeling: bool = is_reeling()

	if reeling:
		line_tension += (tension_gain_rate + tension_fish_pull * pull_wave) * delta
	else:
		line_tension -= tension_recovery_rate * delta

	line_tension = clampf(line_tension, 0.0, 100.0)
	_update_tension_hud()

	if line_tension >= 100.0:
		_break_line()


func _configure_tension_for_fish(fish_type: String) -> void:
	match fish_type:
		"Sardalya":
			tension_gain_rate = 8.0
			tension_recovery_rate = 34.0
			tension_fish_pull = 2.0
		"Levrek":
			tension_gain_rate = 14.0
			tension_recovery_rate = 30.0
			tension_fish_pull = 4.0
		"Uskumru":
			tension_gain_rate = 20.0
			tension_recovery_rate = 27.0
			tension_fish_pull = 6.0
		"Ton Balığı":
			tension_gain_rate = 25.0
			tension_recovery_rate = 25.0
			tension_fish_pull = 8.0
		"Kılıç Balığı":
			tension_gain_rate = 29.0
			tension_recovery_rate = 24.0
			tension_fish_pull = 10.0
		"Köpekbalığı":
			tension_gain_rate = 35.0
			tension_recovery_rate = 21.0
			tension_fish_pull = 13.0
		"Fener Balığı":
			tension_gain_rate = 31.0
			tension_recovery_rate = 22.0
			tension_fish_pull = 11.0
		_:
			tension_gain_rate = 14.0
			tension_recovery_rate = 30.0
			tension_fish_pull = 4.0

	var ease_level: int = int(hud.fight_ease_level)
	tension_gain_rate = maxf(5.0, tension_gain_rate - float(ease_level) * 1.2)
	tension_recovery_rate += float(ease_level) * 1.0

	var strength_multiplier: float = maxf(0.60, 1.0 - float(line_strength_level) * 0.08)
	tension_gain_rate *= strength_multiplier
	tension_fish_pull *= strength_multiplier
	tension_recovery_rate += float(line_strength_level) * 2.2

	line_tension = 12.0
	tension_time = 0.0
	line_break_feedback_timer = 0.0
	_update_tension_hud()


func _update_tension_hud() -> void:
	if tension_panel == null or tension_bar == null or tension_label == null:
		return

	if line_break_feedback_timer > 0.0:
		tension_panel.visible = true
		return

	var show_tension: bool = deployed and is_instance_valid(hooked_fish) and hud.fight_active
	tension_panel.visible = show_tension
	if not show_tension:
		return

	tension_bar.value = line_tension
	tension_label.text = "MİSİNA GERİLİMİ  %d%%" % int(round(line_tension))

	if line_tension < 55.0:
		tension_fill_style.bg_color = Color(0.20, 0.82, 0.50, 0.96)
		tension_label.add_theme_color_override("font_color", Color(0.80, 0.96, 0.88, 1.0))
		tension_hint.text = "Güvenli — balığı kontrollü şekilde sar"
	elif line_tension < 82.0:
		tension_fill_style.bg_color = Color(0.96, 0.72, 0.18, 0.98)
		tension_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.48, 1.0))
		tension_hint.text = "DİKKAT — kısa süre sarmayı bırak"
	else:
		tension_fill_style.bg_color = Color(0.96, 0.22, 0.16, 1.0)
		tension_label.add_theme_color_override("font_color", Color(1.0, 0.42, 0.34, 1.0))
		tension_hint.text = "TEHLİKE — misina kopmak üzere!"


func _update_line_visual() -> void:
	if hook_line == null:
		return

	if is_instance_valid(hooked_fish) and hud.fight_active:
		var ratio: float = clampf(line_tension / 100.0, 0.0, 1.0)
		hook_line.width = lerpf(2.0, 3.2, ratio)
		if line_tension < 55.0:
			hook_line.default_color = Color(0.88, 0.94, 0.97, 0.96)
		elif line_tension < 82.0:
			hook_line.default_color = Color(1.0, 0.82, 0.38, 0.98)
		else:
			var pulse: float = 0.72 + absf(sin(tension_time * 10.0)) * 0.28
			hook_line.default_color = Color(1.0, 0.25, 0.18, pulse)
	else:
		hook_line.width = 2.0
		hook_line.default_color = Color(0.88, 0.92, 0.95, 0.95)


func _break_line() -> void:
	if not deployed:
		return

	if is_instance_valid(hooked_fish):
		hooked_fish.release_from_hook()

	hooked_fish = null
	deployed = false
	position = start_position
	hud.reset_fight()
	boat.set_movement_enabled(not world.docked)

	line_tension = 100.0
	line_break_feedback_timer = 1.15
	if tension_panel != null and tension_label != null and tension_bar != null:
		tension_panel.visible = true
		tension_bar.value = 100.0
		tension_fill_style.bg_color = Color(1.0, 0.16, 0.12, 1.0)
		tension_label.text = "MİSİNA KOPTU!"
		tension_label.add_theme_color_override("font_color", Color(1.0, 0.32, 0.26, 1.0))
		tension_hint.text = "Balık kaçtı — daha güçlü misina kullan veya sarmayı aralıklarla yap"

	_update_depth_hud()
	_update_line_visual()


func _update_depth_hud() -> void:
	if depth_panel == null or depth_label == null:
		return

	depth_panel.visible = deployed
	if not deployed:
		return

	var depth_pixels: float = clampf(position.y - start_position.y, 0.0, max_depth)
	var depth_ratio: float = depth_pixels / maxf(max_depth, 1.0)
	var current_depth_meters: int = int(round(depth_ratio * float(max_depth_meters)))
	depth_label.text = "DERİNLİK  %d m" % current_depth_meters


func is_reeling() -> bool:
	return Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or Input.is_physical_key_pressed(KEY_W)


func set_reel_speed_level(level: int) -> void:
	reel_speed = 240.0 + (float(level) * reel_speed_per_level)


func set_depth_level(level: int) -> void:
	# Gerçek upgrade seviyesi saklanır; test sırasında fiziksel erişim geçici olarak 100 m'ye açılır.
	depth_level = clampi(level, 0, 5)
	var effective_depth_level: int = TEST_DEPTH_LEVEL if TEST_FULL_DEPTH_UNLOCK else depth_level

	max_depth = BASE_DEPTH_PIXELS + (float(effective_depth_level) * DEPTH_PER_LEVEL)
	max_depth_meters = BASE_DEPTH_METERS + (effective_depth_level * DEPTH_METERS_PER_LEVEL)

	camera_deep_y = 1420.0 + (float(effective_depth_level) * 300.0)
	var water: ColorRect = world.get_node_or_null("Water") as ColorRect
	if water != null:
		water.offset_bottom = maxf(water.offset_bottom, 2700.0 + (float(effective_depth_level) * 350.0))

	_update_depth_hud()


func set_line_strength_level(level: int) -> void:
	line_strength_level = clampi(level, 0, 5)


func land_catch() -> void:
	if is_instance_valid(hooked_fish):
		if hud.add_fish(String(hooked_fish.get("fish_type"))):
			hooked_fish.queue_free()
		else:
			hooked_fish.release_from_hook()

	hooked_fish = null
	deployed = false
	position = start_position
	hud.reset_fight()
	boat.set_movement_enabled(not world.docked)
	line_tension = 0.0
	line_break_feedback_timer = 0.0
	_update_depth_hud()
	_update_tension_hud()


func update_camera(delta: float) -> void:
	var ratio: float = clampf((position.y - start_position.y) / maxf(max_depth, 1.0), 0.0, 1.0)
	var target_y: float = lerpf(camera_surface_y, camera_deep_y, ratio)
	camera.position.y = lerpf(camera.position.y, target_y, clampf(camera_follow_speed * delta, 0.0, 1.0))


func _on_hook_area_entered(area: Area2D) -> void:
	if not deployed or is_instance_valid(hooked_fish) or position.y <= start_position.y:
		return

	if area.has_method("hook_to") and not bool(area.get("is_hooked")) and hud.can_add_fish():
		hooked_fish = area
		area.hook_to(self)
		var fish_type: String = String(area.get("fish_type"))
		_configure_tension_for_fish(fish_type)
		hud.show_fight_bar(fish_type)
		_update_tension_hud()
