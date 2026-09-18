extends Area2D

const FishCatalog = preload("res://scenes/fish_catalog.gd")

@export var fish_scene: PackedScene
@export var respawn_time: float = 1.15
@export var ocean_center: Vector2 = Vector2(5000.0, 2050.0)

var respawning: bool = false
var rare_spawn_roll_timer: float = 0.0

const FISH_TYPES: Array[String] = FishCatalog.FISH_ORDER
const RARE_FISH_TYPE: String = "Abyssal Leviathan"
const RARE_SPAWN_CHANCE: float = 0.018
const RARE_CHECK_INTERVAL: float = 6.0

const SARDINE_SCHOOL_GLOBAL_CENTERS: Array[Vector2] = [
	Vector2(1350.0, 640.0),
	Vector2(2150.0, 700.0),
	Vector2(3150.0, 625.0),
	Vector2(4250.0, 715.0),
	Vector2(5250.0, 665.0)
]


func _ready() -> void:
	global_position = ocean_center

	var collision: CollisionShape2D = get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision != null:
		collision.position = Vector2.ZERO
		var shape: RectangleShape2D = collision.shape as RectangleShape2D
		if shape != null:
			shape.size = Vector2(10000.0, 3900.0)

	for child: Node in get_children():
		if child.has_method("hook_to"):
			remove_child(child)
			child.queue_free()

	_spawn_initial_population()
	rare_spawn_roll_timer = randf_range(2.5, RARE_CHECK_INTERVAL)


func _process(delta: float) -> void:
	if not respawning and get_fish_count() < get_target_total():
		respawning = true
		respawn_fish()

	rare_spawn_roll_timer -= delta
	if rare_spawn_roll_timer <= 0.0:
		rare_spawn_roll_timer = RARE_CHECK_INTERVAL
		_try_spawn_rare_fish()


func get_target_total() -> int:
	var total: int = 0
	for fish_type: String in FISH_TYPES:
		total += FishCatalog.get_target_count(fish_type)
	return total


func get_fish_count() -> int:
	var count: int = 0
	for child: Node in get_children():
		if child.has_method("hook_to") and String(child.get("fish_type")) != RARE_FISH_TYPE:
			count += 1
	return count


func get_type_count(fish_type: String) -> int:
	var count: int = 0
	for child: Node in get_children():
		if child.has_method("hook_to") and String(child.get("fish_type")) == fish_type:
			count += 1
	return count


func _target_for_type(fish_type: String) -> int:
	return FishCatalog.get_target_count(fish_type)


func _spawn_initial_population() -> void:
	for fish_type: String in FISH_TYPES:
		var target_count: int = _target_for_type(fish_type)
		for i: int in range(target_count):
			spawn_fish_type(fish_type, i)


func respawn_fish() -> void:
	await get_tree().create_timer(respawn_time).timeout

	var selected_type: String = ""
	var largest_missing: int = 0

	for fish_type: String in FISH_TYPES:
		var missing_count: int = _target_for_type(fish_type) - get_type_count(fish_type)
		if missing_count > largest_missing:
			largest_missing = missing_count
			selected_type = fish_type

	if largest_missing > 0 and selected_type != "":
		spawn_fish_type(selected_type, randi())

	respawning = false


func _try_spawn_rare_fish() -> void:
	if get_type_count(RARE_FISH_TYPE) > 0:
		return
	if randf() > RARE_SPAWN_CHANCE:
		return
	spawn_fish_type(RARE_FISH_TYPE, randi())


func spawn_fish_type(fish_type: String, index_seed: int = 0) -> void:
	if fish_scene == null:
		return

	var new_fish: Node2D = fish_scene.instantiate() as Node2D
	if new_fish == null:
		return

	if fish_type == RARE_FISH_TYPE:
		_configure_abyssal_leviathan(new_fish)
	elif fish_type == "Sardalya":
		_configure_sardine(new_fish, index_seed)
	else:
		_configure_catalog_fish(new_fish, fish_type)

	add_child(new_fish)


func _local_from_global(target: Vector2) -> Vector2:
	return target - ocean_center


func _configure_sardine(fish: Node2D, index_seed: int) -> void:
	var school_count: int = SARDINE_SCHOOL_GLOBAL_CENTERS.size()
	var school_index: int = absi(index_seed) % school_count
	var school_center: Vector2 = SARDINE_SCHOOL_GLOBAL_CENTERS[school_index]
	var target_global: Vector2 = school_center + Vector2(randf_range(-55.0, 55.0), randf_range(-22.0, 22.0))

	fish.position = _local_from_global(target_global)
	_apply_catalog_stats(fish, "Sardalya")


func _configure_catalog_fish(fish: Node2D, fish_type: String) -> void:
	fish.position = _local_from_global(FishCatalog.get_spawn_position(fish_type))
	_apply_catalog_stats(fish, fish_type)


func _apply_catalog_stats(fish: Node2D, fish_type: String) -> void:
	fish.set("fish_type", fish_type)
	fish.set("fish_value", FishCatalog.get_value(fish_type))
	fish.set("swim_speed", FishCatalog.random_profile_range(fish_type, "speed", 70.0))
	fish.set("swim_distance", FishCatalog.random_profile_range(fish_type, "distance", 180.0))
	fish.set("bob_height", FishCatalog.random_profile_range(fish_type, "bob", 5.0))


func _configure_abyssal_leviathan(fish: Node2D) -> void:
	var target_global: Vector2 = Vector2(randf_range(6750.0, 9900.0), randf_range(3520.0, 3800.0))
	fish.position = _local_from_global(target_global)
	fish.set("fish_type", RARE_FISH_TYPE)
	fish.set("fish_value", 1250)
	fish.set("swim_speed", randf_range(24.0, 31.0))
	fish.set("swim_distance", randf_range(500.0, 820.0))
	fish.set("bob_height", randf_range(12.0, 18.0))
