extends Node

# Leviathan test runtime.
# 6. madde (kabarcik/su izi) simdilik devre disi birakildi.
# 7. madde: Leviathan'a ozel gercek govde + kuyruk kivrilma shader'i.
# Boss/yem/UI sistemlerine dokunulmaz.

const FISH_TYPE: String = "Abyssal Leviathan"
const FISH_VALUE: int = 1250
const FISH_TEXTURE_PATH: String = "res://assets/leviathan.webp"
const FISH_SCENE: PackedScene = preload("res://scenes/fish.tscn")
const LEVIATHAN_SWIM_SHADER: Shader = preload("res://shaders/leviathan_swim.gdshader")

const TEST_BOAT_OFFSET_X: float = 850.0
const TEST_DEPTH_Y: float = 600.0
const RETRY_SECONDS: float = 0.5

var _texture: Texture2D = null
var _world: Node2D = null
var _boat: Node2D = null
var _leviathan: Area2D = null
var _sprite: Sprite2D = null
var _retry_timer: float = 0.0
var _spawned: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_try_load_texture()
	_try_setup_and_spawn()


func _process(delta: float) -> void:
	if _spawned:
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
	_spawned = true

	print("LEVIATHAN TEST SPAWN OK: ", fish.global_position)
	print("LEVIATHAN STEP 7 ACTIVE: BODY + TAIL BEND")
	print("LEVIATHAN STEP 6 PARTICLES: DISABLED")


func _configure_visual(fish: Area2D) -> void:
	var sprite: Sprite2D = fish.get_node_or_null("FishSprite") as Sprite2D
	if sprite == null:
		push_error("Leviathan FishSprite bulunamadi")
		return

	sprite.texture = _texture
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.scale = Vector2(0.34, 0.34)
	sprite.z_index = 0

	# Normal balik shader'i kuyrugu sol tarafta varsayiyor.
	# Leviathan'in kafasi solda, kuyrugu sagda oldugu icin ona ozel shader kullaniyoruz.
	var leviathan_material: ShaderMaterial = ShaderMaterial.new()
	leviathan_material.shader = LEVIATHAN_SWIM_SHADER
	leviathan_material.set_shader_parameter("tail_strength", 14.0)
	leviathan_material.set_shader_parameter("tail_speed", 2.6)
	leviathan_material.set_shader_parameter("body_strength", 3.4)
	sprite.material = leviathan_material

	# fish.gd bilinmeyen turu Sardalya gorseline cevirmesin.
	fish.set("last_visual_type", FISH_TYPE)
	fish.set("base_sprite_scale", Vector2(0.34, 0.34))
	fish.set("swim_wave_speed", 1.15)
	fish.set("swim_wave_angle", 0.8)
	fish.set("swim_acceleration", 70.0)
	fish.set("vertical_response", 18.0)
	fish.set("turn_roll_strength", 5.0)
	fish.set("base_tail_strength", 14.0)
	fish.set("base_tail_speed", 2.6)
	fish.set("base_body_strength", 3.4)

	var collision: CollisionShape2D = fish.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision != null:
		var rect: RectangleShape2D = collision.shape as RectangleShape2D
		if rect != null:
			rect.size = Vector2(560.0, 170.0)
