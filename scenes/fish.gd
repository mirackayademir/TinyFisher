extends Area2D

@export var fish_type: String = "Sardalya"
@export var fish_value: int = 10

@export var swim_speed: float = 70.0
@export var swim_distance: float = 180.0
@export var bob_height: float = 5.0

var start_x: float
var start_y: float
var direction: float = 1.0

var is_hooked: bool = false
var hook_ref: Area2D
var hook_offset: Vector2

var last_visual_type: String = ""

var swim_wave_time: float = 0.0
var swim_wave_speed: float = 3.0
var swim_wave_angle: float = 3.0
var swim_phase: float = 0.0
var base_sprite_scale: Vector2 = Vector2.ONE

const SARDALYA_TEXTURE = preload("res://assets/sardalya.png")
const LEVREK_TEXTURE = preload("res://assets/levrek2.png")
const USKUMRU_TEXTURE = preload("res://assets/uskumru.png")
const TON_BALIGI_TEXTURE = preload("res://assets/tonbaligi.png")

@onready var fish_sprite: Sprite2D = $FishSprite


func _ready() -> void:
	start_x = global_position.x
	start_y = global_position.y
	swim_phase = randf_range(0.0, TAU)
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
		play_turn_animation()

	elif global_position.x <= start_x - swim_distance:
		global_position.x = start_x - swim_distance
		direction = 1.0
		update_sprite_direction()
		play_turn_animation()


func update_swim_animation(delta: float) -> void:
	swim_wave_time += delta * swim_wave_speed

	var wave: float = sin(swim_wave_time + swim_phase)
	var slow_wave: float = sin(swim_wave_time * 0.55 + swim_phase)

	# Balığın tamamını sallamak yerine küçük gövde salınımı + dikey yüzüş.
	fish_sprite.rotation = deg_to_rad(wave * swim_wave_angle * 0.42)
	fish_sprite.skew = wave * 0.035
	fish_sprite.scale = Vector2(
		base_sprite_scale.x * (1.0 + abs(wave) * 0.018),
		base_sprite_scale.y * (1.0 - abs(wave) * 0.025)
	)
	global_position.y = start_y + slow_wave * bob_height

	# Derine indikçe balık biraz daha mavi ve karanlık görünür.
	var depth_ratio := clampf((global_position.y - 360.0) / 900.0, 0.0, 1.0)
	fish_sprite.modulate = Color(
		lerpf(1.0, 0.68, depth_ratio),
		lerpf(1.0, 0.84, depth_ratio),
		1.0,
		1.0
	)


func update_fish_visual() -> void:
	last_visual_type = fish_type

	match fish_type:
		"Sardalya":
			fish_sprite.texture = SARDALYA_TEXTURE
			base_sprite_scale = Vector2(0.06, 0.06)
			swim_wave_speed = 4.0
			swim_wave_angle = 2.5
			bob_height = 3.5

		"Levrek":
			fish_sprite.texture = LEVREK_TEXTURE
			base_sprite_scale = Vector2(0.08, 0.08)
			swim_wave_speed = 3.3
			swim_wave_angle = 3.0
			bob_height = 4.5

		"Uskumru":
			fish_sprite.texture = USKUMRU_TEXTURE
			base_sprite_scale = Vector2(0.09, 0.09)
			swim_wave_speed = 4.8
			swim_wave_angle = 4.0
			bob_height = 5.0

		"Ton Balığı":
			fish_sprite.texture = TON_BALIGI_TEXTURE
			base_sprite_scale = Vector2(0.12, 0.12)
			swim_wave_speed = 2.4
			swim_wave_angle = 2.0
			bob_height = 6.0

		_:
			fish_sprite.texture = SARDALYA_TEXTURE
			base_sprite_scale = Vector2(0.06, 0.06)
			swim_wave_speed = 4.0
			swim_wave_angle = 2.5
			bob_height = 3.5

	fish_sprite.scale = base_sprite_scale


func update_sprite_direction() -> void:
	fish_sprite.flip_h = direction < 0.0


func play_turn_animation() -> void:
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(fish_sprite, "scale:y", base_sprite_scale.y * 0.78, 0.08)
	tween.tween_property(fish_sprite, "scale:y", base_sprite_scale.y, 0.12)


func play_hooked_animation() -> void:
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)

	tween.tween_property(fish_sprite, "rotation", deg_to_rad(14.0), 0.06)
	tween.tween_property(fish_sprite, "rotation", deg_to_rad(-14.0), 0.06)
	tween.tween_property(fish_sprite, "rotation", deg_to_rad(11.0), 0.06)
	tween.tween_property(fish_sprite, "rotation", deg_to_rad(-11.0), 0.06)
	tween.tween_property(fish_sprite, "rotation", 0.0, 0.08)

	var flash := create_tween()
	flash.tween_property(fish_sprite, "modulate", Color(1.5, 1.5, 1.15, 1.0), 0.08)
	flash.tween_property(fish_sprite, "modulate", Color.WHITE, 0.18)


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
	start_y = global_position.y
	fish_sprite.rotation = 0.0
	fish_sprite.skew = 0.0
	fish_sprite.scale = base_sprite_scale
