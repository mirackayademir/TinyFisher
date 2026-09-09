extends Node

# Leviathan test runtime.
# Amaç: Leviathan görselini ve tek tek eklenen özel efektleri güvenli biçimde test etmek.
# Boss/yem/UI mantığını ilgili adımlara gelene kadar devre dışı tutuyoruz.

const FISH_TYPE: String = "Abyssal Leviathan"
const FISH_VALUE: int = 1250
const FISH_TEXTURE_PATH: String = "res://assets/leviathan.webp"
const FISH_SCENE: PackedScene = preload("res://scenes/fish.tscn")

const TEST_BOAT_OFFSET_X: float = 850.0
const TEST_DEPTH_Y: float = 600.0
const RETRY_SECONDS: float = 0.5

# 6. madde: Kabarcık / su izi.
# İz, Leviathan'ın kuyruğundan kopup suda kalır; balık yön değiştirince otomatik olarak
# kuyruğun diğer tarafına geçer. Efekt yalnızca Leviathan runtime'ında çalışır.
const WAKE_TAIL_OFFSET_X: float = 245.0
const WAKE_TAIL_OFFSET_Y: float = 18.0
const WAKE_MAX_POINTS: int = 16
const WAKE_SAMPLE_SECONDS: float = 0.055
const BUBBLE_BASE_SECONDS: float = 0.16
const BUBBLE_MIN_RADIUS: float = 2.5
const BUBBLE_MAX_RADIUS: float = 7.0

var _texture: Texture2D = null
var _world: Node2D = null
var _boat: Node2D = null
var _leviathan: Area2D = null
var _retry_timer: float = 0.0
var _spawned: bool = false

var _wake_outer: Line2D = null
var _wake_inner: Line2D = null
var _wake_points: Array[Vector2] = []
var _wake_sample_timer: float = 0.0
var _bubble_timer: float = 0.0
var _effect_time: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_try_load_texture()
	_try_setup_and_spawn()


func _process(delta: float) -> void:
	if _spawned:
		_update_wake_effects(delta)
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

	_world.add_child(fish)
	_configure_visual(fish)

	_leviathan = fish
	_setup_wake_effects()
	_spawned = true
	print("LEVIATHAN TEST SPAWN OK: ", fish.global_position)


func _configure_visual(fish: Area2D) -> void:
	var sprite: Sprite2D = fish.get_node_or_null("FishSprite") as Sprite2D
	if sprite == null:
		push_error("Leviathan FishSprite bulunamadi")
		return

	sprite.texture = _texture
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.scale = Vector2(0.34, 0.34)

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


func _setup_wake_effects() -> void:
	if _world == null or _leviathan == null:
		return

	_wake_outer = Line2D.new()
	_wake_outer.name = "LeviathanWakeOuter"
	_wake_outer.width = 18.0
	_wake_outer.default_color = Color(0.18, 0.47, 0.61, 0.11)
	_wake_outer.antialiased = true
	_wake_outer.z_index = -2
	_world.add_child(_wake_outer)

	_wake_inner = Line2D.new()
	_wake_inner.name = "LeviathanWakeInner"
	_wake_inner.width = 6.0
	_wake_inner.default_color = Color(0.48, 0.78, 0.88, 0.16)
	_wake_inner.antialiased = true
	_wake_inner.z_index = -1
	_world.add_child(_wake_inner)

	_wake_points.clear()
	var first_point: Vector2 = _world.to_local(_get_tail_global_position())
	for i in range(4):
		_wake_points.append(first_point)
	_apply_wake_points()


func _update_wake_effects(delta: float) -> void:
	if not is_instance_valid(_leviathan) or _world == null:
		return

	_effect_time += delta
	_wake_sample_timer -= delta
	_bubble_timer -= delta

	if _wake_sample_timer <= 0.0:
		_wake_sample_timer = WAKE_SAMPLE_SECONDS
		_sample_wake_point()

	if _bubble_timer <= 0.0:
		var velocity_value: float = absf(float(_leviathan.get("current_swim_velocity_x")))
		var speed_factor: float = clampf(velocity_value / 30.0, 0.65, 1.65)
		_bubble_timer = BUBBLE_BASE_SECONDS / speed_factor
		_spawn_bubble_cluster(speed_factor)


func _sample_wake_point() -> void:
	if _wake_outer == null or _wake_inner == null:
		return

	var point: Vector2 = _world.to_local(_get_tail_global_position())
	if not _wake_points.is_empty():
		var last_point: Vector2 = _wake_points[_wake_points.size() - 1]
		# Ani sahne/teleport değişiminde ekranı boydan boya çizgiyle kesme.
		if last_point.distance_to(point) > 420.0:
			_wake_points.clear()

	_wake_points.append(point)
	while _wake_points.size() > WAKE_MAX_POINTS:
		_wake_points.remove_at(0)

	_apply_wake_points()


func _apply_wake_points() -> void:
	if _wake_outer == null or _wake_inner == null:
		return
	var packed_points := PackedVector2Array(_wake_points)
	_wake_outer.points = packed_points
	_wake_inner.points = packed_points

	var velocity_value: float = 0.0
	if is_instance_valid(_leviathan):
		velocity_value = absf(float(_leviathan.get("current_swim_velocity_x")))
	var speed_ratio: float = clampf(velocity_value / 30.0, 0.25, 1.8)
	_wake_outer.width = lerpf(10.0, 23.0, speed_ratio / 1.8)
	_wake_inner.width = lerpf(3.0, 8.0, speed_ratio / 1.8)
	_wake_outer.default_color.a = lerpf(0.055, 0.15, speed_ratio / 1.8)
	_wake_inner.default_color.a = lerpf(0.09, 0.21, speed_ratio / 1.8)


func _get_tail_global_position() -> Vector2:
	if not is_instance_valid(_leviathan):
		return Vector2.ZERO

	var direction_value: float = float(_leviathan.get("direction"))
	if is_zero_approx(direction_value):
		direction_value = 1.0

	var tail_offset := Vector2(
		-WAKE_TAIL_OFFSET_X * signf(direction_value),
		WAKE_TAIL_OFFSET_Y + sin(_effect_time * 2.2) * 8.0
	)
	return _leviathan.global_position + tail_offset


func _spawn_bubble_cluster(speed_factor: float) -> void:
	if _world == null or not is_instance_valid(_leviathan):
		return

	var bubble_count: int = 1
	if speed_factor > 1.15 and randf() < 0.48:
		bubble_count = 2
	if speed_factor > 1.45 and randf() < 0.25:
		bubble_count = 3

	for i in range(bubble_count):
		_spawn_single_bubble(i)


func _spawn_single_bubble(index: int) -> void:
	var bubble := Line2D.new()
	bubble.name = "LeviathanBubble"
	bubble.width = randf_range(1.2, 2.4)
	bubble.default_color = Color(0.58, 0.86, 0.96, randf_range(0.32, 0.58))
	bubble.antialiased = true
	bubble.z_index = -1

	var radius: float = randf_range(BUBBLE_MIN_RADIUS, BUBBLE_MAX_RADIUS)
	var circle_points := PackedVector2Array()
	var segments: int = 10
	for point_index in range(segments + 1):
		var angle: float = TAU * float(point_index) / float(segments)
		circle_points.append(Vector2(cos(angle), sin(angle)) * radius)
	bubble.points = circle_points

	_world.add_child(bubble)

	var direction_value: float = float(_leviathan.get("direction"))
	if is_zero_approx(direction_value):
		direction_value = 1.0
	var backwards_sign: float = -signf(direction_value)
	var spawn_global: Vector2 = _get_tail_global_position() + Vector2(
		randf_range(-16.0, 16.0) + backwards_sign * float(index) * 7.0,
		randf_range(-28.0, 25.0)
	)
	bubble.position = _world.to_local(spawn_global)
	bubble.scale = Vector2.ONE * randf_range(0.72, 1.12)

	var drift := Vector2(
		backwards_sign * randf_range(18.0, 48.0),
		-randf_range(34.0, 72.0)
	)
	var life: float = randf_range(0.85, 1.45)
	var target_position: Vector2 = bubble.position + drift
	var target_scale: Vector2 = bubble.scale * randf_range(1.35, 1.85)

	var tween: Tween = bubble.create_tween()
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(bubble, "position", target_position, life)
	tween.tween_property(bubble, "scale", target_scale, life)
	tween.tween_property(bubble, "modulate", Color(1.0, 1.0, 1.0, 0.0), life)
	tween.set_parallel(false)
	tween.tween_callback(bubble.queue_free)
