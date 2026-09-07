extends CharacterBody2D

@export var speed: float = 220.0
@export var speed_per_level: float = 35.0
@export var min_world_x: float = 470.0

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
@onready var wake_trail: CPUParticles2D = $WakeTrail


func _ready() -> void:
	# Tekneyi su çizgisine biraz daha oturt.
	boat_visual.position.y += 11.0
	rod_pivot.position.y += 11.0
	_boat_visual_base_position = boat_visual.position
	_rod_base_position = rod_pivot.position

	# Köpük artık dünya üzerinde geride kalmaz; kıçın hemen altında tekneyle birlikte akar.
	wake_particles.local_coords = true
	wake_trail.local_coords = true
	wake_particles.lifetime = 0.34
	wake_trail.lifetime = 0.52
	wake_particles.amount = 22
	wake_trail.amount = 16
	wake_particles.initial_velocity_min = 18.0
	wake_particles.initial_velocity_max = 42.0
	wake_trail.initial_velocity_min = 8.0
	wake_trail.initial_velocity_max = 22.0
	wake_particles.gravity = Vector2(0.0, 8.0)
	wake_trail.gravity = Vector2(0.0, 3.0)
	wake_particles.emitting = false
	wake_trail.emitting = false


func _physics_process(delta: float) -> void:
	if not can_move:
		velocity = Vector2.ZERO
	else:
		var direction := Input.get_axis("move_left", "move_right")
		velocity.x = direction * speed
		velocity.y = 0.0
		move_and_slide()

	# Limanın içine girme; sadece sağdaki yanaşma/geliştirme noktasına kadar yaklaş.
	if global_position.x < min_world_x:
		global_position.x = min_world_x
		if velocity.x < 0.0:
			velocity.x = 0.0

	_update_surface_motion(delta)
	_update_wake()
	_update_rod_pose(delta)


func _update_surface_motion(delta: float) -> void:
	_sea_time += delta

	# World su çizgisiyle aynı iki dalga formu: tekne gerçekten dalganın üstünde yüzer.
	var wave_a := sin(global_position.x * 0.018 + _sea_time * 1.72) * 5.2
	var wave_b := sin(global_position.x * 0.043 - _sea_time * 1.08 + 0.8) * 2.2
	var bob := wave_a + wave_b
	var tilt := cos(global_position.x * 0.018 + _sea_time * 1.72) * 0.014
	var speed_tilt := clampf(velocity.x / maxf(speed, 1.0), -1.0, 1.0) * 0.006

	boat_visual.position = _boat_visual_base_position + Vector2(0.0, bob)
	boat_visual.rotation = tilt + speed_tilt
	rod_pivot.position.y = _rod_base_position.y + bob * 0.88


func _update_wake() -> void:
	var moving := can_move and absf(velocity.x) > 20.0
	wake_particles.emitting = moving
	wake_trail.emitting = moving

	if not moving:
		return

	var movement_sign := signf(velocity.x)
	var speed_ratio := clampf(absf(velocity.x) / maxf(speed, 1.0), 0.30, 1.0)
	var foam_y := 49.0 + sin(_sea_time * 3.0) * 1.2

	wake_particles.direction = Vector2(-movement_sign, 0.02)
	wake_trail.direction = Vector2(-movement_sign, 0.015)
	wake_particles.speed_scale = lerpf(0.75, 1.05, speed_ratio)
	wake_trail.speed_scale = lerpf(0.70, 0.95, speed_ratio)

	# Köpük doğrudan kıçın altından başlar; uzun boşluk oluşmaz.
	if movement_sign > 0.0:
		wake_particles.position = Vector2(76.0, foam_y)
		wake_trail.position = Vector2(94.0, foam_y + 2.0)
	else:
		wake_particles.position = Vector2(904.0, foam_y)
		wake_trail.position = Vector2(886.0, foam_y + 2.0)


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
		wake_trail.emitting = false


func _on_hook_area_entered(area: Area2D) -> void:
	pass
