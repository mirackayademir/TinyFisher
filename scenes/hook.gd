extends Area2D

const BASE_DEPTH_PIXELS: float = 1700.0
const DEPTH_PER_LEVEL: float = 350.0
const BASE_DEPTH_METERS: int = 50
const DEPTH_METERS_PER_LEVEL: int = 10

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

@onready var hook_line: Line2D = $"../HookLine"
@onready var hud = $"../../HUD"
@onready var camera: Camera2D = $"../Camera2D"
@onready var boat: CharacterBody2D = $".."
@onready var world = $"../.."


func _ready() -> void:
	start_position = position

	# Scene'deki eski değer daha kısa olsa bile yeni başlangıç oltası yaklaşık 50 m'lik alanı tarar.
	max_depth = maxf(max_depth, BASE_DEPTH_PIXELS)
	camera_deep_y = maxf(camera_deep_y, 1420.0)

	# Derin kamera aşağı indiğinde deniz görseli bitmesin.
	var water := world.get_node_or_null("Water") as ColorRect
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
	_update_depth_hud()


func _setup_depth_hud() -> void:
	# Ekranın üst-ortasında sabit kalır; kamera derine inse bile HUD ile birlikte görünür.
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

	if deployed:
		if is_instance_valid(hooked_fish):
			if hud.is_fight_won() and is_reeling():
				position.y -= reel_speed * delta
		else:
			position.y += (-reel_speed if is_reeling() else hook_speed) * delta

		position.y = clampf(position.y, start_position.y, start_position.y + max_depth)
		position.x = start_position.x

		if position.y <= start_position.y:
			land_catch()
		elif not is_instance_valid(hooked_fish):
			for area in get_overlapping_areas():
				_on_hook_area_entered(area)

	hook_line.set_point_position(0, boat.get_line_origin_local())
	hook_line.set_point_position(1, position)
	update_camera(delta)
	_update_depth_hud()


func _update_depth_hud() -> void:
	if depth_panel == null or depth_label == null:
		return

	depth_panel.visible = deployed
	if not deployed:
		return

	var depth_pixels: float = clampf(position.y - start_position.y, 0.0, max_depth)
	var depth_ratio: float = depth_pixels / maxf(max_depth, 1.0)
	var current_depth_meters: int = int(round(depth_ratio * float(max_depth_meters)))
	depth_label.text = "DERİNLİK  %d / %d m" % [current_depth_meters, max_depth_meters]


func is_reeling() -> bool:
	return Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or Input.is_physical_key_pressed(KEY_W)


func set_reel_speed_level(level: int) -> void:
	reel_speed = 240.0 + (float(level) * reel_speed_per_level)


func set_depth_level(level: int) -> void:
	depth_level = clampi(level, 0, 5)
	max_depth = BASE_DEPTH_PIXELS + (float(depth_level) * DEPTH_PER_LEVEL)
	max_depth_meters = BASE_DEPTH_METERS + (depth_level * DEPTH_METERS_PER_LEVEL)

	# Daha derin geliştirmelerde kamera ve su alanı da yeni erişime uyum sağlar.
	camera_deep_y = 1420.0 + (float(depth_level) * 300.0)
	var water := world.get_node_or_null("Water") as ColorRect
	if water != null:
		water.offset_bottom = maxf(water.offset_bottom, 2700.0 + (float(depth_level) * 350.0))

	_update_depth_hud()


func land_catch() -> void:
	if is_instance_valid(hooked_fish):
		if hud.add_fish(hooked_fish.fish_type):
			hooked_fish.queue_free()
		else:
			hooked_fish.release_from_hook()

	hooked_fish = null
	deployed = false
	position = start_position
	hud.reset_fight()
	boat.set_movement_enabled(not world.docked)
	_update_depth_hud()


func update_camera(delta: float) -> void:
	var ratio: float = clampf((position.y - start_position.y) / maxf(max_depth, 1.0), 0.0, 1.0)
	var target_y: float = lerpf(camera_surface_y, camera_deep_y, ratio)
	camera.position.y = lerpf(camera.position.y, target_y, clampf(camera_follow_speed * delta, 0.0, 1.0))


func _on_hook_area_entered(area: Area2D) -> void:
	if not deployed or is_instance_valid(hooked_fish) or position.y <= start_position.y:
		return

	if area.has_method("hook_to") and not area.is_hooked and hud.can_add_fish():
		hooked_fish = area
		area.hook_to(self)
		hud.show_fight_bar(area.fish_type)
