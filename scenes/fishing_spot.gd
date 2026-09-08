extends Area2D

@export var fish_scene: PackedScene
@export var respawn_time: float = 1.15
@export var ocean_center: Vector2 = Vector2(3400.0, 1180.0)

# Bölge nüfusları. Böylece rastgelelik yüzünden bir türün tamamen kaybolması engellenir.
@export var sardine_target: int = 12
@export var levrek_target: int = 6
@export var uskumru_target: int = 6
@export var tuna_target: int = 4

var respawning: bool = false

# Sardalyalar yüzeye yakın, sıkı sürüler halinde yaşar.
# Koordinatlar dünya koordinatıdır; limandan uzaklaştıkça yeni sürüler görülür.
const SARDINE_SCHOOL_GLOBAL_CENTERS = [
	Vector2(1350.0, 640.0),
	Vector2(2150.0, 700.0),
	Vector2(3150.0, 625.0),
	Vector2(4250.0, 715.0),
	Vector2(5250.0, 665.0)
]


func _ready() -> void:
	# Su altı oyun alanının merkezi. Yaklaşık x=900..6500 ve yüzeyden ~50 m derine kadar alanı kapsar.
	global_position = ocean_center

	var collision := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision != null:
		collision.position = Vector2.ZERO
		var shape := collision.shape as RectangleShape2D
		if shape != null:
			shape.size = Vector2(5800.0, 1850.0)

	# Scene içine elle bırakılmış eski örnek balık varsa temizle.
	for child in get_children():
		if child.has_method("hook_to"):
			remove_child(child)
			child.queue_free()

	_spawn_initial_population()


func _process(_delta: float) -> void:
	if not respawning and get_fish_count() < get_target_total():
		respawning = true
		respawn_fish()


func get_target_total() -> int:
	return sardine_target + levrek_target + uskumru_target + tuna_target


func get_fish_count() -> int:
	var count: int = 0
	for child in get_children():
		if child.has_method("hook_to"):
			count += 1
	return count


func get_type_count(fish_type: String) -> int:
	var count: int = 0
	for child in get_children():
		if child.has_method("hook_to") and child.fish_type == fish_type:
			count += 1
	return count


func _spawn_initial_population() -> void:
	for i in range(sardine_target):
		spawn_fish_type("Sardalya", i)

	for i in range(levrek_target):
		spawn_fish_type("Levrek", i)

	for i in range(uskumru_target):
		spawn_fish_type("Uskumru", i)

	for i in range(tuna_target):
		spawn_fish_type("Ton Balığı", i)


func respawn_fish() -> void:
	await get_tree().create_timer(respawn_time).timeout

	# Yakalanan türün ekosistemdeki yerini tekrar doldur.
	# Bu sayede örneğin bütün ton balıklarının zamanla sardalyaya dönüşmesi gibi bir durum olmaz.
	var sardine_missing: int = sardine_target - get_type_count("Sardalya")
	var levrek_missing: int = levrek_target - get_type_count("Levrek")
	var uskumru_missing: int = uskumru_target - get_type_count("Uskumru")
	var tuna_missing: int = tuna_target - get_type_count("Ton Balığı")

	var largest_missing: int = maxi(maxi(sardine_missing, levrek_missing), maxi(uskumru_missing, tuna_missing))

	if largest_missing > 0:
		if sardine_missing == largest_missing:
			spawn_fish_type("Sardalya", randi())
		elif levrek_missing == largest_missing:
			spawn_fish_type("Levrek", randi())
		elif uskumru_missing == largest_missing:
			spawn_fish_type("Uskumru", randi())
		else:
			spawn_fish_type("Ton Balığı", randi())

	respawning = false


func spawn_fish_type(fish_type: String, index_seed: int = 0) -> void:
	if fish_scene == null:
		return

	var new_fish = fish_scene.instantiate()

	match fish_type:
		"Sardalya":
			_configure_sardine(new_fish, index_seed)
		"Levrek":
			_configure_levrek(new_fish)
		"Uskumru":
			_configure_uskumru(new_fish)
		"Ton Balığı":
			_configure_tuna(new_fish)
		_:
			_configure_sardine(new_fish, index_seed)

	add_child(new_fish)


func _local_from_global(target: Vector2) -> Vector2:
	return target - ocean_center


func _configure_sardine(fish, index_seed: int) -> void:
	# Yüzeye yakın bölge: yaklaşık 8-12 metre hissi.
	# Aynı sürüdeki balıklar dip dibe doğar ve kısa mesafelerde beraber gezinir.
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


func _configure_levrek(fish) -> void:
	# Orta sular: limana yakın başlayabilir ama sardalyadan belirgin biçimde daha derindedir.
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


func _configure_uskumru(fish) -> void:
	# Açık deniz / derin orta katman: daha sağda ve daha hızlı balıklar.
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


func _configure_tuna(fish) -> void:
	# Şimdilik ulaşılabilen en derin katman. Ton balığı limandan uzakta ve dip tarafa yakın yaşar.
	var target_global: Vector2 = Vector2(
		randf_range(3400.0, 6200.0),
		randf_range(1480.0, 1810.0)
	)

	fish.position = _local_from_global(target_global)
	fish.fish_type = "Ton Balığı"
	fish.fish_value = 75
	fish.swim_speed = randf_range(40.0, 54.0)
	fish.swim_distance = randf_range(330.0, 560.0)
	fish.bob_height = randf_range(5.0, 7.0)
