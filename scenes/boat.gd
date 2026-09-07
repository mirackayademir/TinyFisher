extends CharacterBody2D

@export var speed: float = 220.0

var can_move: bool = true


func _physics_process(_delta):
	if not can_move:
		velocity = Vector2.ZERO
		return

	var direction := Input.get_axis("move_left", "move_right")

	velocity.x = direction * speed
	velocity.y = 0.0

	move_and_slide()


func set_movement_enabled(enabled: bool) -> void:
	can_move = enabled

	if not enabled:
		velocity = Vector2.ZERO


func _on_hook_area_entered(area: Area2D) -> void:
	pass # Replace with function body.
