extends Area2D

const BASE_DEPTH_PIXELS: float = 1700.0
const DEPTH_PER_LEVEL: float = 350.0

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

	collision_layer = 0
	collision_mask = 2
	area_entered.connect(_on_hook_area_entered)
	hook_line.width = 2.0
	hook_line.default_color = Color(0.88, 0.92, 0.95, 0.95)
	hook_line.points = PackedVector2Array([start_position, start_position])
	camera.position = Vector2(350.0, camera_surface_y)


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


func is_reeling() -> bool:
	return Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or Input.is_physical_key_pressed(KEY_W)


func set_reel_speed_level(level: int) -> void:
	reel_speed = 240.0 + (float(level) * reel_speed_per_level)


func set_depth_level(level: int) -> void:
	# Sonraki geliştirme sisteminde doğrudan kullanılmak üzere hazır.
	max_depth = BASE_DEPTH_PIXELS + (float(level) * DEPTH_PER_LEVEL)


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
