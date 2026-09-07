extends CharacterBody2D

@export var speed: float = 220.0
@export var speed_per_level: float = 35.0
@export var min_world_x: float = -145.0

@export var rod_rest_rotation: float = 0.0
@export var rod_reel_rotation: float = -0.16
@export var rod_cast_back_rotation: float = 0.22
@export var rod_cast_forward_rotation: float = -0.32

var can_move: bool = true
var _cast_animating: bool = false
var _rod_tween: Tween
var _sea_time: float = 0.0
var _boat_visual_base_position: Vector2
var _rod_base_position: Vector2

@onready var hook = $Hook
@onready var rod_pivot: Node2D = $RodPivot
@onready var rod_tip: Marker2D = $RodPivot/RodTip
@onready var boat_visual: Sprite2D = $BoatVisual
@onready var wake_particles: CPUParticles2D = $WakeParticles


func _ready() -> void:
	_boat_visual_base_position = boat_visual.position
	_rod_base_position = rod_pivot.position
	wake_particles.emitting = false


func _physics_process(delta: float) -> void:
	if not can_move:
		velocity = Vector2.ZERO
	else:
		var direction := Input.get_axis("move_left", "move_right")
		velocity.x = direction * speed
		velocity.y = 0.0
		move_and_slide()

	# Limanın görselinin içine geçme. Sol sınır, yanaşma/yükseltme alanını açık bırakır.
	if global_position.x < min_world_x:
		global_position.x = min_world_x
		if velocity.x < 0.0:
			velocity.x = 0.0

	_update_surface_motion(delta)
	_update_wake()
	_update_rod_pose(delta)


func _update_surface_motion(delta: float) -> void:
	_sea_time += delta
	var bob := sin(_sea_time * 2.15) * 3.2 + sin(_sea_time * 1.12 + 0.7) * 1.4
	var tilt := sin(_sea_time * 1.65) * 0.008

	boat_visual.position = _boat_visual_base_position + Vector2(0.0, bob)
	boat_visual.rotation = tilt
	rod_pivot.position.y = _rod_base_position.y + bob * 0.85


func _update_wake() -> void:
	var moving := can_move and absf(velocity.x) > 20.0
	wake_particles.emitting = moving

	if not moving:
		return

	var movement_sign := signf(velocity.x)
	wake_particles.direction = Vector2(-movement_sign, 0.10)

	# Köpük her zaman hareket yönünün arkasından çıkar.
	if movement_sign > 0.0:
		wake_particles.position = Vector2(78.0, 38.0)
	else:
		wake_particles.position = Vector2(900.0, 38.0)


func _update_rod_pose(delta: float) -> void:
	if _cast_animating:
		return

	var target_rotation := rod_rest_rotation
	if hook.deployed and hook.is_reeling():
		target_rotation = rod_reel_rotation

	rod_pivot.rotation = lerp_angle(
		rod_pivot.rotation,
		target_rotation,
		clampf(delta * 9.0, 0.0, 1.0)
	)


func play_cast_animation() -> void:
	if is_instance_valid(_rod_tween):
		_rod_tween.kill()

	_cast_animating = true
	_rod_tween = create_tween()
	_rod_tween.set_trans(Tween.TRANS_SINE)
	_rod_tween.set_ease(Tween.EASE_OUT)
	_rod_tween.tween_property(rod_pivot, "rotation", rod_cast_back_rotation, 0.11)
	_rod_tween.tween_property(rod_pivot, "rotation", rod_cast_forward_rotation, 0.16)
	_rod_tween.tween_property(rod_pivot, "rotation", rod_rest_rotation, 0.20)
	_rod_tween.finished.connect(_on_cast_animation_finished)


func _on_cast_animation_finished() -> void:
	_cast_animating = false


func get_line_origin_local() -> Vector2:
	return to_local(rod_tip.global_position)


func set_speed_level(level: int) -> void:
	speed = 220.0 + (float(level) * speed_per_level)


func set_movement_enabled(enabled: bool) -> void:
	can_move = enabled

	if not enabled:
		velocity = Vector2.ZERO
		wake_particles.emitting = false


func _on_hook_area_entered(area: Area2D) -> void:
	pass
