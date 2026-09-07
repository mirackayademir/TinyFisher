extends Area2D

@export var fish_type: String = "Sardalya"
@export var fish_value: int = 10

@export var swim_speed: float = 70.0
@export var swim_distance: float = 180.0

var start_x: float
var direction: float = 1.0

var is_hooked: bool = false
var hook_ref: Area2D
var hook_offset: Vector2

var last_visual_type: String = ""

var swim_wave_time: float = 0.0
var swim_wave_speed: float = 3.0
var swim_wave_angle: float = 3.0

const SARDALYA_TEXTURE = preload("res://assets/sardalya.png")
const LEVREK_TEXTURE = preload("res://assets/levrek2.png")
const USKUMRU_TEXTURE = preload("res://assets/uskumru.png")
const TON_BALIGI_TEXTURE = preload("res://assets/tonbaligi.png")

@onready var fish_sprite: Sprite2D = $FishSprite


func _ready() -> void:
	start_x = global_position.x
	update_fish_visual()
	update_sprite_direction()


func _physics_process(delta: float) -> void:
	if fish_type != last_visual_type:
		update_fish_visual()

	if is_hooked:
		if is_instance_valid(hook_ref):
			global_position = hook_ref.global_position + hook_offset
		else:
			release_from_hook()
		return

	update_swim_animation(delta)

	global_position.x += swim_speed * direction * delta

	if global_position.x >= start_x + swim_distance:
		global_position.x = start_x + swim_distance
		direction = -1.0
		update_sprite_direction()

	elif global_position.x <= start_x - swim_distance:
		global_position.x = start_x - swim_distance
		direction = 1.0
		update_sprite_direction()


func update_swim_animation(delta: float) -> void:
	swim_wave_time += delta * swim_wave_speed

	var wave: float = sin(swim_wave_time)

	fish_sprite.rotation = deg_to_rad(
		wave * swim_wave_angle
	)


func update_fish_visual() -> void:
	last_visual_type = fish_type

	match fish_type:
		"Sardalya":
			fish_sprite.texture = SARDALYA_TEXTURE
			fish_sprite.scale = Vector2(0.06, 0.06)
			swim_wave_speed = 4.0
			swim_wave_angle = 2.5

		"Levrek":
			fish_sprite.texture = LEVREK_TEXTURE
			fish_sprite.scale = Vector2(0.08, 0.08)
			swim_wave_speed = 3.3
			swim_wave_angle = 3.0

		"Uskumru":
			fish_sprite.texture = USKUMRU_TEXTURE
			fish_sprite.scale = Vector2(0.09, 0.09)
			swim_wave_speed = 4.8
			swim_wave_angle = 4.0

		"Ton Balığı":
			fish_sprite.texture = TON_BALIGI_TEXTURE
			fish_sprite.scale = Vector2(0.12, 0.12)
			swim_wave_speed = 2.4
			swim_wave_angle = 2.0

		_:
			fish_sprite.texture = SARDALYA_TEXTURE
			fish_sprite.scale = Vector2(0.06, 0.06)
			swim_wave_speed = 4.0
			swim_wave_angle = 2.5


func update_sprite_direction() -> void:
	if direction > 0:
		fish_sprite.flip_h = false
	else:
		fish_sprite.flip_h = true


func play_hooked_animation() -> void:
	var original_rotation: float = fish_sprite.rotation

	var tween := create_tween()

	tween.tween_property(
		fish_sprite,
		"rotation",
		deg_to_rad(12.0),
		0.07
	)

	tween.tween_property(
		fish_sprite,
		"rotation",
		deg_to_rad(-12.0),
		0.07
	)

	tween.tween_property(
		fish_sprite,
		"rotation",
		deg_to_rad(10.0),
		0.07
	)

	tween.tween_property(
		fish_sprite,
		"rotation",
		deg_to_rad(-10.0),
		0.07
	)

	tween.tween_property(
		fish_sprite,
		"rotation",
		original_rotation,
		0.07
	)


func hook_to(hook: Area2D) -> void:
	if is_hooked:
		return

	is_hooked = true
	hook_ref = hook
	hook_offset = Vector2.ZERO
	global_position = hook.global_position

	play_hooked_animation()


func release_from_hook() -> void:
	is_hooked = false
	hook_ref = null
	start_x = global_position.x
