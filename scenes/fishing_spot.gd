extends Area2D

@export var fish_scene: PackedScene
@export var respawn_time: float = 1.15
@export var ocean_center: Vector2 = Vector2(5000.0, 2050.0)

@export var sardine_target: int = 12
@export var levrek_target: int = 6
@export var uskumru_target: int = 6
@export var tuna_target: int = 4
@export var swordfish_target: int = 3
@export var shark_target: int = 2
@export var angler_target: int = 3

var respawning: bool = false

const FISH_TYPES: Array[String] = [
	"Sardalya",
	"Levrek",
	"Uskumru",
	"Ton Balığı",
	"Kılıç Balığı",
	"Köpekbalığı",
	"Fener Balığı"
]

const SARDINE_SCHOOL_GLOBAL_CENTERS: Array[Vector2] = [
	Vector2(1350.0, 640.0),
	Vector2(2150.0, 700.0),
	Vector2(3150.0, 625.0),
	Vector2(4250.0, 715.0),
	Vector2(5250.0, 665.0)
]


func _ready() -> void:
	# Alan artık yaklaşık x=0..10000 ve 100 m civarı derinliğe kadar uzanır.
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


func _process(_delta: float) -> void:
	if not respawning and get_fish_count() < get_target_total():
		respawning = true
		respawn_fish()


func get_target_total() -> int:
	return (
		sardine_target
		+ levrek_target
		+ uskumru_target
		+ tuna_target
		+ swordfish_target
		+ shark_target
		+ angler_target
	)


func get_fish_count() -> int:
	var count: int = 0
	for child: Node in get_children():
		if child.has_method("hook_to"):
			count += 1
	return count


func get_type_count(fish_type: String) -> int:
	var count: int = 0
	for child: Node in get_children():
		if child.has_method("hook_to") and String(child.fish_type) == fish_type:
			count += 1
	return count


func _target_for_type(fish_type: String) -> int:
	match fish_type:
		"Sardalya":
			return sardine_target
		"Levrek":
			return levrek_target
		"Uskumru":
			return uskumru_target
		"Ton Balığı":
			return tuna_target
		"Kılıç Balığı":
			return swordfish_target
		"Köpekbalığı":
			return shark_target
		"Fener Balığı":
			return angler_target
		_:
			return 0


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


func spawn_fish_type(fish_type: String, index_seed: int = 0) -> void:
	if fish_scene == null:
		return

	var new_fish: Node = fish_scene.instantiate()

	match fish_type:
		"Sardalya":
			_configure_sardine(new_fish, index_seed)
		"Levrek":
			_configure_levrek(new_fish)
		"Uskumru":
			_configure_uskumru(new_fish)
		"Ton Balığı":
			_configure_tuna(new_fish)
		"Kılıç Balığı":
			_configure_swordfish(new_fish)
		"Köpekbalığı":
			_configure_shark(new_fish)
		"Fener Balığı":
			_configure_angler(new_fish)
		_:
			_configure_sardine(new_fish, index_seed)

	add_child(new_fish)


func _local_from_global(target: Vector2) -> Vector2:
	return target - ocean_center


func _configure_sardine(fish: Node, index_seed: int) -> void:
	var school_count: int = SARDINE_SCHOOL_GLOBAL_CENTERS.size()
	var school_index: int = absi(index_seed) % school_count
	var school_center: Vector2 = SARDINE_SCHOOL_GLOBAL_CENTERS[school_index]
	var target_global: Vector2 = school_center + Vector2(randf_range(-55.0, 55.0), randf_range(-22.0, 22.0))

	fish.position = _local_from_global(target_global)
	fish.fish_type = "Sardalya"
	fish.fish_value = 10
	fish.swim_speed = randf_range(68.0, 77.0)
	fish.swim_distance = randf_range(72.0, 118.0)
	fish.bob_height = randf_range(2.0, 3.2)


func _configure_levrek(fish: Node) -> void:
	var target_global: Vector2 = Vector2(
		randf_range(1250.0, 3900.0),
		randf_range(820.0, 1080.0)
	)

	fish.position = _local_from_global(target_global)
	fish.fish_type = "Levrek"
	fish.fish_value = 25
	fish.swim_speed = randf_range(48.0, 62.0)
	fish.swim_distance = randf_range(210.0, 380.0)
	fish.bob_height = randf_range(3.5, 5.0)


func _configure_uskumru(fish: Node) -> void:
	var target_global: Vector2 = Vector2(
		randf_range(2200.0, 5350.0),
		randf_range(1110.0, 1420.0)
	)

	fish.position = _local_from_global(target_global)
	fish.fish_type = "Uskumru"
	fish.fish_value = 40
	fish.swim_speed = randf_range(78.0, 98.0)
	fish.swim_distance = randf_range(270.0, 480.0)
	fish.bob_height = randf_range(4.0, 5.5)


func _configure_tuna(fish: Node) -> void:
	var target_global: Vector2 = Vector2(
		randf_range(3400.0, 6500.0),
		randf_range(1480.0, 1810.0)
	)

	fish.position = _local_from_global(target_global)
	fish.fish_type = "Ton Balığı"
	fish.fish_value = 75
	fish.swim_speed = randf_range(40.0, 54.0)
	fish.swim_distance = randf_range(330.0, 560.0)
	fish.bob_height = randf_range(5.0, 7.0)


func _configure_swordfish(fish: Node) -> void:
	# 50 m başlangıç oltasının hemen altında başlar; ilk derinlik geliştirmeleri gerekir.
	var target_global: Vector2 = Vector2(
		randf_range(4300.0, 7800.0),
		randf_range(2150.0, 2450.0)
	)

	fish.position = _local_from_global(target_global)
	fish.fish_type = "Kılıç Balığı"
	fish.fish_value = 130
	fish.swim_speed = randf_range(72.0, 90.0)
	fish.swim_distance = randf_range(430.0, 680.0)
	fish.bob_height = randf_range(6.0, 8.0)


func _configure_shark(fish: Node) -> void:
	# Daha güçlü misina ve yaklaşık 70-80 m erişim isteyen büyük avcı.
	var target_global: Vector2 = Vector2(
		randf_range(5200.0, 9000.0),
		randf_range(2600.0, 3050.0)
	)

	fish.position = _local_from_global(target_global)
	fish.fish_type = "Köpekbalığı"
	fish.fish_value = 220
	fish.swim_speed = randf_range(42.0, 55.0)
	fish.swim_distance = randf_range(560.0, 820.0)
	fish.bob_height = randf_range(7.0, 10.0)


func _configure_angler(fish: Node) -> void:
	# Oyuncuyu 90-100 m bandına taşıyan ilk gerçek derin su türü.
	var target_global: Vector2 = Vector2(
		randf_range(5900.0, 10000.0),
		randf_range(3300.0, 3720.0)
	)

	fish.position = _local_from_global(target_global)
	fish.fish_type = "Fener Balığı"
	fish.fish_value = 300
	fish.swim_speed = randf_range(28.0, 38.0)
	fish.swim_distance = randf_range(180.0, 330.0)
	fish.bob_height = randf_range(10.0, 14.0)
