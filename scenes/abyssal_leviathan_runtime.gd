extends Node

# Leviathan test runtime.
# 6. madde: kabarcik + su izi.
# Efektleri artik dunya koordinatlarinda degil, direkt Leviathan'in cocugu olarak ciziyoruz.
# Boylece kamera/z-index/koordinat kaynakli kaybolma ihtimali kalmiyor.

const FISH_TYPE: String = "Abyssal Leviathan"
const FISH_VALUE: int = 1250
const FISH_TEXTURE_PATH: String = "res://assets/leviathan.webp"
const FISH_SCENE: PackedScene = preload("res://scenes/fish.tscn")

const TEST_BOAT_OFFSET_X: float = 850.0
const TEST_DEPTH_Y: float = 600.0
const RETRY_SECONDS: float = 0.5

const TAIL_X: float = 135.0
const BUBBLE_INTERVAL: float = 0.11

var _texture: Texture2D = null
var _world: Node2D = null
var _boat: Node2D = null
var _leviathan: Area2D = null
var _sprite: Sprite2D = null
var _retry_timer: float = 0.0
var _spawned: bool = false
var _effect_time: float = 0.0
var _bubble_timer: float = 0.0

var _wake_outer: Polygon2D = null
var _wake_inner: Polygon2D = null
var _foam_top: Line2D = null
var _foam_bottom: Line2D = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_try_load_texture()
	_try_setup_and_spawn()


func _process(delta: float) -> void:
	if _spawned:
		_update_visible_wake(delta)
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
	fish.z_index = 15

	_world.add_child(fish)
	_configure_visual(fish)

	_leviathan = fish
	_sprite = fish.get_node_or_null("FishSprite") as Sprite2D
	_setup_visible_wake_rig()
	_spawned = true

	# Baslangicta bile kabarcik gorulsun.
	for i in range(5):
		_spawn_local_bubble(i)

	print("LEVIATHAN TEST SPAWN OK: ", fish.global_position)
	print("LEVIATHAN EFFECT 6 V3 ACTIVE: LOCAL WAKE RIG")


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


func _setup_visible_wake_rig() -> void:
	if not is_instance_valid(_leviathan):
		return

	_wake_outer = Polygon2D.new()
	_wake_outer.name = "LeviathanWakeOuter"
	_wake_outer.color = Color(0.20, 0.78, 1.0, 0.46)
	_wake_outer.z_index = -3
	_leviathan.add_child(_wake_outer)

	_wake_inner = Polygon2D.new()
	_wake_inner.name = "LeviathanWakeInner"
	_wake_inner.color = Color(0.76, 0.96, 1.0, 0.72)
	_wake_inner.z_index = -2
	_leviathan.add_child(_wake_inner)

	_foam_top = Line2D.new()
	_foam_top.name = "LeviathanFoamTop"
	_foam_top.width = 4.0
	_foam_top.default_color = Color(0.90, 0.99, 1.0, 0.88)
	_foam_top.antialiased = true
	_foam_top.z_index = -1
	_leviathan.add_child(_foam_top)

	_foam_bottom = Line2D.new()
	_foam_bottom.name = "LeviathanFoamBottom"
	_foam_bottom.width = 3.0
	_foam_bottom.default_color = Color(0.72, 0.94, 1.0, 0.72)
	_foam_bottom.antialiased = true
	_foam_bottom.z_index = -1
	_leviathan.add_child(_foam_bottom)

	_rebuild_wake_geometry()


func _update_visible_wake(delta: float) -> void:
	if not is_instance_valid(_leviathan) or not is_instance_valid(_sprite):
		return

	_effect_time += delta
	_bubble_timer -= delta
	_rebuild_wake_geometry()

	# Hiz arttikca iz biraz daha parlar.
	var speed_value: float = absf(float(_leviathan.get("current_swim_velocity_x")))
	var speed_ratio: float = clampf(speed_value / 30.0, 0.55, 1.45)
	_wake_outer.modulate.a = 0.72 + (speed_ratio - 0.55) * 0.18
	_wake_inner.modulate.a = 0.82 + (speed_ratio - 0.55) * 0.12

	if _bubble_timer <= 0.0:
		_bubble_timer = BUBBLE_INTERVAL / speed_ratio
		_spawn_local_bubble(0)
		if speed_ratio > 1.05 and randf() < 0.55:
			_spawn_local_bubble(1)


func _tail_side_sign() -> float:
	# Gorselin dogal halinde kuyruk sagda. flip_h olunca sola gecer.
	if is_instance_valid(_sprite) and _sprite.flip_h:
		return -1.0
	return 1.0


func _rebuild_wake_geometry() -> void:
	if _wake_outer == null or _wake_inner == null or _foam_top == null or _foam_bottom == null:
		return

	var side: float = _tail_side_sign()
	var wave_a: float = sin(_effect_time * 5.0) * 5.0
	var wave_b: float = sin(_effect_time * 4.0 + 1.7) * 7.0
	var tail_x: float = TAIL_X * side
	var x1: float = (TAIL_X + 42.0) * side
	var x2: float = (TAIL_X + 92.0) * side
	var x3: float = (TAIL_X + 150.0) * side

	_wake_outer.polygon = PackedVector2Array([
		Vector2(tail_x, -8.0 + wave_a * 0.15),
		Vector2(x1, -18.0 + wave_a),
		Vector2(x2, -24.0 + wave_b),
		Vector2(x3, -13.0 - wave_a),
		Vector2(x3, 13.0 - wave_a),
		Vector2(x2, 25.0 + wave_b),
		Vector2(x1, 18.0 + wave_a),
		Vector2(tail_x, 8.0 + wave_a * 0.15)
	])

	_wake_inner.polygon = PackedVector2Array([
		Vector2(tail_x, -3.0),
		Vector2(x1, -8.0 + wave_a * 0.55),
		Vector2(x2, -10.0 + wave_b * 0.45),
		Vector2(x3, -5.0),
		Vector2(x3, 5.0),
		Vector2(x2, 10.0 + wave_b * 0.45),
		Vector2(x1, 8.0 + wave_a * 0.55),
		Vector2(tail_x, 3.0)
	])

	_foam_top.points = PackedVector2Array([
		Vector2(tail_x, -5.0),
		Vector2(x1, -12.0 + wave_a),
		Vector2(x2, -14.0 + wave_b),
		Vector2(x3, -8.0 - wave_a)
	])
	_foam_bottom.points = PackedVector2Array([
		Vector2(tail_x, 6.0),
		Vector2(x1, 13.0 - wave_a),
		Vector2(x2, 15.0 - wave_b),
		Vector2(x3, 9.0 + wave_a)
	])


func _spawn_local_bubble(index: int) -> void:
	if not is_instance_valid(_leviathan):
		return

	var side: float = _tail_side_sign()
	var bubble := Polygon2D.new()
	bubble.name = "LeviathanBubble"
	var radius: float = randf_range(3.5, 7.5)
	bubble.polygon = _make_circle_polygon(radius, 12)
	bubble.color = Color(0.88, 0.98, 1.0, randf_range(0.72, 0.94))
	bubble.z_index = -1
	_leviathan.add_child(bubble)

	bubble.position = Vector2(
		(TAIL_X + randf_range(18.0, 78.0) + float(index) * 12.0) * side,
		randf_range(-20.0, 22.0)
	)
	bubble.scale = Vector2.ONE * randf_range(0.8, 1.25)

	var life: float = randf_range(0.8, 1.25)
	var target_position: Vector2 = bubble.position + Vector2(
		side * randf_range(26.0, 58.0),
		-randf_range(48.0, 82.0)
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
