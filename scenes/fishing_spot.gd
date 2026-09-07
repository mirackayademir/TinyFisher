extends Area2D

@export var fish_scene: PackedScene
@export var max_fish: int = 18
@export var respawn_time: float = 1.3
@export var ocean_center: Vector2 = Vector2(2600.0, 1150.0)

var respawning: bool = false

const SARDINE_SCHOOLS = [
	Vector2(-1200.0, -270.0),
	Vector2(-320.0, -235.0),
	Vector2(650.0, -285.0),
	Vector2(1480.0, -245.0)
]


func _ready() -> void:
	# Balık alanını sağa ve derine taşı. Limanın hemen dibinde balık doğmasın.
	global_position = ocean_center

	var collision := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision != null:
		collision.position = Vector2.ZERO
		var shape := collision.shape as RectangleShape2D
		if shape != null:
			shape.size = Vector2(4400.0, 1750.0)

	# Scene içine elle bırakılmış eski örnek balığı kaldır; bütün balıklar yeni derinlik kurallarına göre doğsun.
	for child in get_children():
		if child.has_method("hook_to"):
			remove_child(child)
			child.queue_free()

	for i in range(max_fish):
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
	var roll: int = randi_range(1, 100)

	if roll <= 45:
		_configure_sardine(new_fish)
	elif roll <= 73:
		_configure_levrek(new_fish)
	elif roll <= 91:
		_configure_uskumru(new_fish)
	else:
		_configure_tuna(new_fish)

	add_child(new_fish)


func _configure_sardine(fish) -> void:
	# Sardalyalar 4 küçük sürü halinde, birbirine yakın dolaşır.
	var school_center: Vector2 = SARDINE_SCHOOLS[randi_range(0, SARDINE_SCHOOLS.size() - 1)]
	fish.position = school_center + Vector2(randf_range(-58.0, 58.0), randf_range(-24.0, 24.0))
	fish.fish_type = "Sardalya"
	fish.fish_value = 10
	fish.swim_speed = randf_range(72.0, 78.0)
	fish.swim_distance = randf_range(90.0, 135.0)
	fish.bob_height = randf_range(2.5, 4.0)


func _configure_levrek(fish) -> void:
	# Levrek orta derinlikte ve daha geniş bölgede gezer.
	fish.position = Vector2(randf_range(-1600.0, 1800.0), randf_range(-40.0, 250.0))
	fish.fish_type = "Levrek"
	fish.fish_value = 25
	fish.swim_speed = randf_range(50.0, 64.0)
	fish.swim_distance = randf_range(220.0, 420.0)


func _configure_uskumru(fish) -> void:
	# Uskumru daha derinde ve daha hareketli.
	fish.position = Vector2(randf_range(-1250.0, 2050.0), randf_range(270.0, 560.0))
	fish.fish_type = "Uskumru"
	fish.fish_value = 40
	fish.swim_speed = randf_range(78.0, 98.0)
	fish.swim_distance = randf_range(260.0, 500.0)


func _configure_tuna(fish) -> void:
	# Ton balığı en derin ve daha sağdaki sularda görülür.
	fish.position = Vector2(randf_range(-550.0, 2150.0), randf_range(560.0, 800.0))
	fish.fish_type = "Ton Balığı"
	fish.fish_value = 75
	fish.swim_speed = randf_range(40.0, 54.0)
	fish.swim_distance = randf_range(320.0, 560.0)
