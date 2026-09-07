extends CharacterBody2D

@export var speed: float = 220.0
@export var speed_per_level: float = 35.0

@export var rod_rest_rotation: float = 0.0
@export var rod_reel_rotation: float = -0.16
@export var rod_cast_back_rotation: float = 0.22
@export var rod_cast_forward_rotation: float = -0.32

var can_move: bool = true
var _cast_animating: bool = false
var _rod_tween: Tween

@onready var hook = $Hook
@onready var rod_pivot: Node2D = $RodPivot
@onready var rod_tip: Marker2D = $RodPivot/RodTip


func _physics_process(delta: float) -> void:
	if not can_move:
		velocity = Vector2.ZERO
	else:
		var direction := Input.get_axis("move_left", "move_right")
		velocity.x = direction * speed
		velocity.y = 0.0
		move_and_slide()

	_update_rod_pose(delta)


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


func _on_hook_area_entered(area: Area2D) -> void:
	pass
