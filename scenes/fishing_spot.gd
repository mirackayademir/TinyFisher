extends Area2D

@export var fish_scene: PackedScene
@export var max_fish: int = 8
@export var respawn_time: float = 1.6

var respawning: bool = false


func _ready() -> void:
	var missing_fish: int = max_fish - get_fish_count()

	for i in range(missing_fish):
		spawn_one_fish()


func _process(_delta: float) -> void:
	if not respawning and get_fish_count() < max_fish:
		respawning = true
		respawn_fish()


func get_fish_count() -> int:
	var count: int = 0

	for child in get_children():
		if child.has_method("hook_to"):
			count += 1

	return count


func respawn_fish() -> void:
	await get_tree().create_timer(respawn_time).timeout

	if get_fish_count() < max_fish:
		spawn_one_fish()

	respawning = false


func spawn_one_fish() -> void:
	if fish_scene == null:
		return

	var new_fish = fish_scene.instantiate()

	new_fish.position = Vector2(
		randf_range(-310.0, 310.0),
		randf_range(-150.0, 220.0)
	)
	new_fish.swim_distance = randf_range(150.0, 280.0)

	var roll: int = randi_range(1, 100)

	if roll <= 45:
		new_fish.fish_type = "Sardalya"
		new_fish.fish_value = 10
		new_fish.swim_speed = randf_range(68.0, 82.0)

	elif roll <= 75:
		new_fish.fish_type = "Levrek"
		new_fish.fish_value = 25
		new_fish.swim_speed = randf_range(50.0, 64.0)

	elif roll <= 92:
		new_fish.fish_type = "Uskumru"
		new_fish.fish_value = 40
		new_fish.swim_speed = randf_range(78.0, 96.0)

	else:
		new_fish.fish_type = "Ton Balığı"
		new_fish.fish_value = 75
		new_fish.swim_speed = randf_range(40.0, 52.0)

	add_child(new_fish)
