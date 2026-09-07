extends Area2D

@export var hook_speed: float = 180.0
@export var reel_speed: float = 240.0
@export var max_depth: float = 736.0
@export var camera_surface_y: float = 0.0
@export var camera_deep_y: float = 520.0
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
	collision_layer = 0
	collision_mask = 2
	area_entered.connect(_on_hook_area_entered)
	hook_line.width = 3.0
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
	# Cat Goes Fishing hissi: olta sudayken de tekne A/D ile hareket edebilir.
	# Kanca Boat'un child'i olduğu için yatayda tekneyle beraber taşınır ve ip dik kalır.
	boat.set_movement_enabled(true)


func _physics_process(delta: float) -> void:
	if Input.is_physical_key_pressed(KEY_S):
		deploy()

	if deployed:
		if is_instance_valid(hooked_fish):
			if hud.is_fight_won() and is_reeling():
				position.y -= reel_speed * delta
		else:
			# Boş olta otomatik batar; sarma her zaman önceliklidir.
			position.y += (-reel_speed if is_reeling() else hook_speed) * delta

		position.y = clampf(position.y, start_position.y, start_position.y + max_depth)
		# X yerel koordinatta sabit kalır. Boat hareket edince kanca dünya uzayında onunla gider.
		position.x = start_position.x

		if position.y <= start_position.y:
			land_catch()
		elif not is_instance_valid(hooked_fish):
			# Yeni atışta halihazırda üst üste gelen balığı da yakala.
			for area in get_overlapping_areas():
				_on_hook_area_entered(area)

	hook_line.set_point_position(0, start_position)
	hook_line.set_point_position(1, position)
	update_camera(delta)


func is_reeling() -> bool:
	return Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or Input.is_physical_key_pressed(KEY_W)


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
