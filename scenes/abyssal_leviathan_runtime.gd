extends Node

# Leviathan test runtime.
# 6. madde: görünür kabarcık + su izi efekti.
# Boss/yem/UI sistemlerine dokunmuyoruz.

const FISH_TYPE: String = "Abyssal Leviathan"
const FISH_VALUE: int = 1250
const FISH_TEXTURE_PATH: String = "res://assets/leviathan.webp"
const FISH_SCENE: PackedScene = preload("res://scenes/fish.tscn")

const TEST_BOAT_OFFSET_X: float = 850.0
const TEST_DEPTH_Y: float = 600.0
const RETRY_SECONDS: float = 0.5

# Leviathan görselinin doğal yönünde kafa solda, kuyruk sağda.
# flip_h olduğunda kuyruk tarafı otomatik tersine döner.
const TAIL_OFFSET_X: float = 145.0
const TAIL_OFFSET_Y: float = 10.0

const WAKE_INTERVAL: float = 0.055
const BUBBLE_INTERVAL: float = 0.12

var _texture: Texture2D = null
var _world: Node2D = null
var _boat: Node2D = null
var _leviathan: Area2D = null
var _sprite: Sprite2D = null
var _retry_timer: float = 0.0
var _spawned: bool = false

var _wake_timer: float = 0.0
var _bubble_timer: float = 0.0
var _effect_time: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_try_load_texture()
	_try_setup_and_spawn()


func _process(delta: float) -> void:
	if _spawned:
		_update_water_effects(delta)
		return

	_retry_timer -= delta
	if _retry_timer > 0.0:
		return
	_retry_timer = RETRY_SECONDS

	if _texture == null:
		_try_load_texture()
	_try_setup_and_spawn()


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

	# Efekt katmanlarını kesin biçimde suyun üstüne çıkarıyoruz.
	fish.z_index = 15
	_world.add_child(fish)
	_configure_visual(fish)

	_leviathan = fish
	_sprite = fish.get_node_or_null("FishSprite") as Sprite2D
	_spawned = true

	# İlk karede bile efekt görülsün.
	for i in range(6):
		_spawn_wake_puff(float(i) * 10.0)
	for i in range(5):
		_spawn_bubble(i)

	print("LEVIATHAN TEST SPAWN OK: ", fish.global_position)
	print("LEVIATHAN EFFECT 6 ACTIVE: wake + bubbles")


func _configure_visual(fish: Area2D) -> void:
	var sprite: Sprite2D = fish.get_node_or_null("FishSprite") as Sprite2D
	if sprite == null:
		push_error("Leviathan FishSprite bulunamadi")
		return

	sprite.texture = _texture
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.scale = Vector2(0.34, 0.34)
	sprite.z_index = 0

	# fish.gd bilinmeyen turu Sardalya görseline çevirmesin.
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


func _update_water_effects(delta: float) -> void:
	if _world == null or not is_instance_valid(_leviathan) or not is_instance_valid(_sprite):
		return

	_effect_time += delta
	_wake_timer -= delta
	_bubble_timer -= delta

	if _wake_timer <= 0.0:
		_wake_timer = WAKE_INTERVAL
		_spawn_wake_puff(0.0)

	if _bubble_timer <= 0.0:
		_bubble_timer = BUBBLE_INTERVAL
		var count: int = 1
		var speed_value: float = absf(float(_leviathan.get("current_swim_velocity_x")))
		if speed_value > 24.0 and randf() < 0.55:
			count = 2
		for i in range(count):
			_spawn_bubble(i)


func _tail_side_sign() -> float:
	if is_instance_valid(_sprite) and _sprite.flip_h:
		return -1.0
	return 1.0


func _get_tail_global_position() -> Vector2:
	if not is_instance_valid(_leviathan):
		return Vector2.ZERO

	var side: float = _tail_side_sign()
	return _leviathan.global_position + Vector2(
		TAIL_OFFSET_X * side,
		TAIL_OFFSET_Y + sin(_effect_time * 2.0) * 5.0
	)


func _spawn_wake_puff(extra_back: float) -> void:
	if _world == null or not is_instance_valid(_leviathan):
		return

	var side: float = _tail_side_sign()
	var origin: Vector2 = _get_tail_global_position() + Vector2(side * extra_back, randf_range(-8.0, 8.0))

	# Dış, geniş su girdabı.
	var outer := Polygon2D.new()
	outer.name = "LeviathanWakePuff"
	outer.polygon = _make_circle_polygon(10.0, 16)
	outer.color = Color(0.42, 0.84, 0.97, randf_range(0.28, 0.40))
	outer.z_index = 13
	_world.add_child(outer)
	outer.global_position = origin
	outer.scale = Vector2(randf_range(1.5, 2.1), randf_range(0.42, 0.62))

	var outer_life: float = randf_range(0.65, 0.92)
	var outer_target_pos: Vector2 = outer.position + Vector2(side * randf_range(52.0, 86.0), randf_range(-7.0, 7.0))
	var outer_target_scale: Vector2 = Vector2(outer.scale.x * randf_range(1.8, 2.5), outer.scale.y * randf_range(1.15, 1.5))
	var outer_tween: Tween = outer.create_tween()
	outer_tween.set_parallel(true)
	outer_tween.set_trans(Tween.TRANS_SINE)
	outer_tween.set_ease(Tween.EASE_OUT)
	outer_tween.tween_property(outer, "position", outer_target_pos, outer_life)
	outer_tween.tween_property(outer, "scale", outer_target_scale, outer_life)
	outer_tween.tween_property(outer, "modulate:a", 0.0, outer_life)
	outer_tween.set_parallel(false)
	outer_tween.tween_callback(outer.queue_free)

	# Ortada daha parlak kısa köpük şeridi.
	if randf() < 0.72:
		var inner := Polygon2D.new()
		inner.name = "LeviathanWakeFoam"
		inner.polygon = _make_circle_polygon(5.0, 12)
		inner.color = Color(0.83, 0.97, 1.0, randf_range(0.48, 0.68))
		inner.z_index = 14
		_world.add_child(inner)
		inner.global_position = origin + Vector2(side * randf_range(0.0, 8.0), randf_range(-5.0, 5.0))
		inner.scale = Vector2(randf_range(1.2, 1.7), randf_range(0.35, 0.52))

		var inner_life: float = randf_range(0.40, 0.64)
		var inner_target_pos: Vector2 = inner.position + Vector2(side * randf_range(34.0, 58.0), randf_range(-5.0, 5.0))
		var inner_tween: Tween = inner.create_tween()
		inner_tween.set_parallel(true)
		inner_tween.set_trans(Tween.TRANS_SINE)
		inner_tween.set_ease(Tween.EASE_OUT)
		inner_tween.tween_property(inner, "position", inner_target_pos, inner_life)
		inner_tween.tween_property(inner, "scale", inner.scale * Vector2(1.8, 1.25), inner_life)
		inner_tween.tween_property(inner, "modulate:a", 0.0, inner_life)
		inner_tween.set_parallel(false)
		inner_tween.tween_callback(inner.queue_free)


func _spawn_bubble(index: int) -> void:
	if _world == null or not is_instance_valid(_leviathan):
		return

	var side: float = _tail_side_sign()
	var bubble := Polygon2D.new()
	bubble.name = "LeviathanBubble"
	var radius: float = randf_range(3.0, 7.5)
	bubble.polygon = _make_circle_polygon(radius, 12)
	bubble.color = Color(0.84, 0.97, 1.0, randf_range(0.58, 0.82))
	bubble.z_index = 14
	_world.add_child(bubble)

	bubble.global_position = _get_tail_global_position() + Vector2(
		side * (randf_range(8.0, 28.0) + float(index) * 8.0),
		randf_range(-22.0, 22.0)
	)
	bubble.scale = Vector2.ONE * randf_range(0.70, 1.12)

	var life: float = randf_range(0.85, 1.35)
	var target_position: Vector2 = bubble.position + Vector2(
		side * randf_range(18.0, 48.0),
		-randf_range(42.0, 78.0)
	)
	var target_scale: Vector2 = bubble.scale * randf_range(1.25, 1.65)

	var tween: Tween = bubble.create_tween()
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(bubble, "position", target_position, life)
	tween.tween_property(bubble, "scale", target_scale, life)
	tween.tween_property(bubble, "modulate:a", 0.0, life)
	tween.set_parallel(false)
	tween.tween_callback(bubble.queue_free)


func _make_circle_polygon(radius: float, segments: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in range(segments):
		var angle: float = TAU * float(i) / float(segments)
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	return points
