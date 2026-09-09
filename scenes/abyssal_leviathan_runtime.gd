extends Node2D

# Leviathan test runtime.
# 6. madde: kabarcik + su izi.
# V4: Efektler child Polygon/Line node'lari yerine dogrudan CanvasItem _draw() ile cizilir.
# Bu, onceki gorunmeme sorununda z-index/child transform ihtimalini tamamen devreden cikarir.

const FISH_TYPE: String = "Abyssal Leviathan"
const FISH_VALUE: int = 1250
const FISH_TEXTURE_PATH: String = "res://assets/leviathan.webp"
const FISH_SCENE: PackedScene = preload("res://scenes/fish.tscn")

const TEST_BOAT_OFFSET_X: float = 850.0
const TEST_DEPTH_Y: float = 600.0
const RETRY_SECONDS: float = 0.5

const TRAIL_SAMPLE_SECONDS: float = 0.045
const TRAIL_MAX_POINTS: int = 24
const BUBBLE_INTERVAL: float = 0.10
const TAIL_VISUAL_FACTOR: float = 0.38

var _texture: Texture2D = null
var _world: Node2D = null
var _boat: Node2D = null
var _leviathan: Area2D = null
var _sprite: Sprite2D = null
var _retry_timer: float = 0.0
var _spawned: bool = false

var _effect_time: float = 0.0
var _trail_timer: float = 0.0
var _bubble_timer: float = 0.0
var _trail_points: Array[Vector2] = []
var _bubbles: Array[Dictionary] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	z_index = 200
	_try_load_texture()
	_try_setup_and_spawn()


func _process(delta: float) -> void:
	if _spawned:
		_update_direct_effects(delta)
		queue_redraw()
		return

	_retry_timer -= delta
	if _retry_timer > 0.0:
		return
	_retry_timer = RETRY_SECONDS

	if _texture == null:
		_try_load_texture()
	_try_setup_and_spawn()


func _draw() -> void:
	if not _spawned or not is_instance_valid(_leviathan) or not is_instance_valid(_sprite):
		return

	_draw_wake()
	_draw_bubbles()


func _try_load_texture() -> void:
	if _texture != null:
		return
	if not ResourceLoader.exists(FISH_TEXTURE_PATH):
		push_warning("Leviathan texture bekleniyor: " + FISH_TEXTURE_PATH)
		return

	_texture = load(FISH_TEXTURE_PATH) as Texture2D
	if _texture == null:
		push_error("Leviathan texture yuklenemedi: " + FISH_TEXTURE_PATH)
		return

	print("LEVIATHAN TEXTURE HAZIR: ", FISH_TEXTURE_PATH)


func _try_setup_and_spawn() -> void:
	if _spawned or _texture == null:
		return

	var scene: Node = get_tree().current_scene
	if scene == null:
		return

	_world = scene as Node2D
	if _world == null:
		return

	_boat = _world.get_node_or_null("Boat") as Node2D
	if _boat == null:
		return

	_spawn_test_leviathan()


func _spawn_test_leviathan() -> void:
	var fish: Area2D = FISH_SCENE.instantiate() as Area2D
	if fish == null:
		push_error("Leviathan icin fish.tscn olusturulamadi")
		return

	fish.name = "AbyssalLeviathan"
	fish.set("fish_type", FISH_TYPE)
	fish.set("fish_value", FISH_VALUE)
	fish.set("swim_speed", 30.0)
	fish.set("swim_distance", 260.0)
	fish.set("bob_height", 6.0)
	fish.global_position = Vector2(
		_boat.global_position.x + TEST_BOAT_OFFSET_X,
		TEST_DEPTH_Y
	)
	fish.z_index = 15

	_world.add_child(fish)
	_configure_visual(fish)

	_leviathan = fish
	_sprite = fish.get_node_or_null("FishSprite") as Sprite2D
	_spawned = true

	_trail_points.clear()
	var first_tail: Vector2 = _tail_draw_position()
	for i in range(7):
		_trail_points.append(first_tail + Vector2(float(i) * 5.0, 0.0))

	# Ilk karede de gorunur kabarcik olsun.
	for i in range(6):
		_spawn_bubble(float(i) * 0.08)

	queue_redraw()
	print("LEVIATHAN TEST SPAWN OK: ", fish.global_position)
	print("LEVIATHAN EFFECT 6 V4 ACTIVE: DIRECT CANVAS DRAW")


func _configure_visual(fish: Area2D) -> void:
	var sprite: Sprite2D = fish.get_node_or_null("FishSprite") as Sprite2D
	if sprite == null:
		push_error("Leviathan FishSprite bulunamadi")
		return

	sprite.texture = _texture
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.scale = Vector2(0.34, 0.34)
	sprite.z_index = 0

	# fish.gd bilinmeyen turu Sardalya gorseline cevirmesin.
	fish.set("last_visual_type", FISH_TYPE)
	fish.set("base_sprite_scale", Vector2(0.34, 0.34))
	fish.set("swim_wave_speed", 1.2)
	fish.set("swim_wave_angle", 1.2)
	fish.set("swim_acceleration", 70.0)
	fish.set("vertical_response", 18.0)
	fish.set("turn_roll_strength", 7.0)
	fish.set("base_tail_strength", 8.0)
	fish.set("base_tail_speed", 2.8)
	fish.set("base_body_strength", 1.8)

	var collision: CollisionShape2D = fish.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision != null:
		var rect: RectangleShape2D = collision.shape as RectangleShape2D
		if rect != null:
			rect.size = Vector2(560.0, 170.0)


func _update_direct_effects(delta: float) -> void:
	if not is_instance_valid(_leviathan) or not is_instance_valid(_sprite):
		return

	_effect_time += delta
	_trail_timer -= delta
	_bubble_timer -= delta

	if _trail_timer <= 0.0:
		_trail_timer = TRAIL_SAMPLE_SECONDS
		var point: Vector2 = _tail_draw_position()
		if not _trail_points.is_empty() and _trail_points[_trail_points.size() - 1].distance_to(point) > 350.0:
			_trail_points.clear()
		_trail_points.append(point)
		while _trail_points.size() > TRAIL_MAX_POINTS:
			_trail_points.remove_at(0)

	if _bubble_timer <= 0.0:
		var speed_value: float = absf(float(_leviathan.get("current_swim_velocity_x")))
		var speed_ratio: float = clampf(speed_value / 30.0, 0.65, 1.55)
		_bubble_timer = BUBBLE_INTERVAL / speed_ratio
		_spawn_bubble(0.0)
		if speed_ratio > 1.05 and randf() < 0.55:
			_spawn_bubble(0.0)

	_update_bubbles(delta)


func _tail_draw_position() -> Vector2:
	if not is_instance_valid(_leviathan) or not is_instance_valid(_sprite) or _sprite.texture == null:
		return Vector2.ZERO

	# Texture boyutundan kuyruk noktasini hesapliyoruz; sabit piksel tahmini kullanmiyoruz.
	var visual_width: float = float(_sprite.texture.get_width()) * absf(_sprite.scale.x)
	var tail_offset_x: float = visual_width * TAIL_VISUAL_FACTOR
	var side: float = -1.0 if _sprite.flip_h else 1.0
	var world_tail: Vector2 = _leviathan.global_position + Vector2(
		tail_offset_x * side,
		8.0 + sin(_effect_time * 2.1) * 4.0
	)
	return to_local(world_tail)


func _spawn_bubble(age_offset: float) -> void:
	if not is_instance_valid(_leviathan) or not is_instance_valid(_sprite):
		return

	var tail_pos: Vector2 = _tail_draw_position()
	var velocity_x: float = float(_leviathan.get("current_swim_velocity_x"))
	var back_sign: float = -signf(velocity_x)
	if is_zero_approx(back_sign):
		back_sign = -1.0 if not _sprite.flip_h else 1.0

	var life: float = randf_range(1.0, 1.55)
	var bubble := {
		"pos": tail_pos + Vector2(randf_range(-10.0, 10.0), randf_range(-16.0, 18.0)),
		"vel": Vector2(back_sign * randf_range(18.0, 42.0), -randf_range(34.0, 64.0)),
		"life": maxf(0.15, life - age_offset),
		"max_life": life,
		"radius": randf_range(3.5, 7.5)
	}
	_bubbles.append(bubble)


func _update_bubbles(delta: float) -> void:
	for i in range(_bubbles.size() - 1, -1, -1):
		var bubble: Dictionary = _bubbles[i]
		var pos: Vector2 = bubble["pos"]
		var vel: Vector2 = bubble["vel"]
		var life: float = float(bubble["life"])

		pos += vel * delta
		vel.x += sin(_effect_time * 4.0 + float(i)) * 5.0 * delta
		life -= delta

		if life <= 0.0:
			_bubbles.remove_at(i)
			continue

		bubble["pos"] = pos
		bubble["vel"] = vel
		bubble["life"] = life
		_bubbles[i] = bubble


func _draw_wake() -> void:
	if _trail_points.size() < 2:
		return

	var points := PackedVector2Array(_trail_points)

	# Genis mavi su izi.
	draw_polyline(points, Color(0.25, 0.82, 1.0, 0.42), 18.0, true)
	# Ortadaki parlak kopuk cizgisi.
	draw_polyline(points, Color(0.82, 0.97, 1.0, 0.86), 5.0, true)

	# Eski noktalarda dagilan kopuk adaciklari.
	for i in range(_trail_points.size()):
		if i % 2 != 0:
			continue
		var age_ratio: float = float(i + 1) / float(_trail_points.size())
		var radius: float = lerpf(3.0, 8.5, age_ratio)
		var wobble := Vector2(0.0, sin(_effect_time * 5.0 + float(i)) * 4.0)
		draw_circle(_trail_points[i] + wobble, radius, Color(0.72, 0.94, 1.0, 0.18 + age_ratio * 0.34))


func _draw_bubbles() -> void:
	for bubble in _bubbles:
		var pos: Vector2 = bubble["pos"]
		var life: float = float(bubble["life"])
		var max_life: float = maxf(float(bubble["max_life"]), 0.001)
		var radius: float = float(bubble["radius"])
		var alpha: float = clampf(life / max_life, 0.0, 1.0)

		# Dis halka + minik beyaz yansima.
		draw_circle(pos, radius, Color(0.82, 0.97, 1.0, 0.88 * alpha), false, 2.2, true)
		draw_circle(pos + Vector2(-radius * 0.30, -radius * 0.30), maxf(1.0, radius * 0.18), Color(1.0, 1.0, 1.0, 0.95 * alpha))
