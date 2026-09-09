extends Node

# Leviathan test runtime.
# 6. madde: kabarcik + su izi.
# V6: Parcaciklar texture'in tum canvasina gore degil, gorunen alpha sinirindaki gercek kuyruga baglanir.
# Boss/yem/UI sistemlerine dokunulmaz.

const FISH_TYPE: String = "Abyssal Leviathan"
const FISH_VALUE: int = 1250
const FISH_TEXTURE_PATH: String = "res://assets/leviathan.webp"
const FISH_SCENE: PackedScene = preload("res://scenes/fish.tscn")
const FOAM_TEXTURE: Texture2D = preload("res://assets/foam_particle.svg")

const TEST_BOAT_OFFSET_X: float = 850.0
const TEST_DEPTH_Y: float = 600.0
const RETRY_SECONDS: float = 0.5
const FALLBACK_TAIL_DISTANCE: float = 235.0

var _texture: Texture2D = null
var _world: Node2D = null
var _boat: Node2D = null
var _leviathan: Area2D = null
var _sprite: Sprite2D = null
var _retry_timer: float = 0.0
var _spawned: bool = false

var _wake_particles: CPUParticles2D = null
var _bubble_particles: CPUParticles2D = null
var _tail_anchor_sprite_local: Vector2 = Vector2.ZERO
var _tail_anchor_ready: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_try_load_texture()
	_try_setup_and_spawn()


func _process(delta: float) -> void:
	if _spawned:
		_update_particle_effects()
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
	_setup_particle_effects()
	_spawned = true

	print("LEVIATHAN TEST SPAWN OK: ", fish.global_position)
	print("LEVIATHAN EFFECT 6 V6 ACTIVE: VISIBLE-TAIL ANCHOR")


func _configure_visual(fish: Area2D) -> void:
	var sprite: Sprite2D = fish.get_node_or_null("FishSprite") as Sprite2D
	if sprite == null:
		push_error("Leviathan FishSprite bulunamadi")
		return

	sprite.texture = _texture
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.scale = Vector2(0.34, 0.34)
	sprite.z_index = 0
	_cache_tail_anchor(sprite)

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


func _cache_tail_anchor(sprite: Sprite2D) -> void:
	_tail_anchor_ready = false
	_tail_anchor_sprite_local = Vector2.ZERO

	if sprite.texture == null:
		return

	var image: Image = sprite.texture.get_image()
	if image == null or image.is_empty():
		return

	# get_used_rect(), bos/transparent canvas'i atip sadece gorunen piksellerin sinirini verir.
	# Leviathan gorselinin dogal halinde kafa solda, kuyruk sagda.
	var used_rect: Rect2i = image.get_used_rect()
	if used_rect.size.x <= 0 or used_rect.size.y <= 0:
		return

	var texture_size: Vector2 = Vector2(
		float(sprite.texture.get_width()),
		float(sprite.texture.get_height())
	)

	var tail_pixel: Vector2 = Vector2(
		float(used_rect.position.x + used_rect.size.x - 1),
		float(used_rect.position.y) + float(used_rect.size.y) * 0.52
	)

	if sprite.centered:
		tail_pixel -= texture_size * 0.5

	_tail_anchor_sprite_local = tail_pixel + sprite.offset
	_tail_anchor_ready = true

	print("LEVIATHAN GERCEK KUYRUK ANCHOR HAZIR: ", _tail_anchor_sprite_local)


func _setup_particle_effects() -> void:
	if not is_instance_valid(_leviathan):
		return

	# Ana su/kopuk izi. Teknedeki calisan sistemle ayni temel yapi.
	_wake_particles = CPUParticles2D.new()
	_wake_particles.name = "LeviathanWakeParticles"
	_wake_particles.z_index = -1
	_wake_particles.emitting = true
	_wake_particles.amount = 52
	_wake_particles.lifetime = 0.95
	_wake_particles.randomness = 0.58
	_wake_particles.local_coords = false
	_wake_particles.texture = FOAM_TEXTURE
	_wake_particles.spread = 20.0
	_wake_particles.gravity = Vector2(0.0, -3.0)
	_wake_particles.initial_velocity_min = 30.0
	_wake_particles.initial_velocity_max = 68.0
	_wake_particles.scale_amount_min = 0.70
	_wake_particles.scale_amount_max = 1.75
	_wake_particles.color = Color(0.84, 0.97, 1.0, 0.90)
	_leviathan.add_child(_wake_particles)

	# Daha seyrek ve yukari cikan kabarcik/kopuk parcaciklari.
	_bubble_particles = CPUParticles2D.new()
	_bubble_particles.name = "LeviathanBubbleParticles"
	_bubble_particles.z_index = -1
	_bubble_particles.emitting = true
	_bubble_particles.amount = 28
	_bubble_particles.lifetime = 1.55
	_bubble_particles.randomness = 0.72
	_bubble_particles.local_coords = false
	_bubble_particles.texture = FOAM_TEXTURE
	_bubble_particles.spread = 28.0
	_bubble_particles.gravity = Vector2(0.0, -14.0)
	_bubble_particles.initial_velocity_min = 16.0
	_bubble_particles.initial_velocity_max = 34.0
	_bubble_particles.scale_amount_min = 0.32
	_bubble_particles.scale_amount_max = 0.92
	_bubble_particles.color = Color(0.72, 0.93, 1.0, 0.72)
	_leviathan.add_child(_bubble_particles)

	_update_particle_effects()


func _get_tail_anchor_on_leviathan() -> Vector2:
	if not is_instance_valid(_leviathan) or not is_instance_valid(_sprite):
		return Vector2.ZERO

	# Guvenli fallback: texture'in tum genisligini kullanma. Buyuk transparent canvas
	# kabarcigi yuzlerce piksel oteye tasiyordu.
	if not _tail_anchor_ready:
		var fallback_side: float = -1.0 if _sprite.flip_h else 1.0
		return Vector2(FALLBACK_TAIL_DISTANCE * fallback_side, 8.0)

	var sprite_local_anchor: Vector2 = _tail_anchor_sprite_local

	# Sprite2D.flip_h node transformunu degistirmez; goruntu cizimini aynalar.
	# Bu yuzden kuyruk anchor'ini da elle aynaliyoruz.
	if _sprite.flip_h:
		sprite_local_anchor.x = -sprite_local_anchor.x
	if _sprite.flip_v:
		sprite_local_anchor.y = -sprite_local_anchor.y

	# Sprite'in scale/rotation/position degerlerini hesaba katip gercek dunya noktasini bul.
	var global_anchor: Vector2 = _sprite.to_global(sprite_local_anchor)
	return _leviathan.to_local(global_anchor)


func _update_particle_effects() -> void:
	if not is_instance_valid(_leviathan) or not is_instance_valid(_sprite):
		return
	if not is_instance_valid(_wake_particles) or not is_instance_valid(_bubble_particles):
		return
	if _sprite.texture == null:
		return

	# Gorselin dogal halinde kafa solda, kuyruk sagda.
	# flip_h oldugunda kuyruk sola gecer.
	var tail_side: float = -1.0 if _sprite.flip_h else 1.0
	var tail_anchor: Vector2 = _get_tail_anchor_on_leviathan()

	_wake_particles.position = tail_anchor
	_bubble_particles.position = tail_anchor + Vector2(0.0, -2.0)

	# Parcalar kuyruktan geriye dogru akar.
	_wake_particles.direction = Vector2(tail_side, 0.03)
	_bubble_particles.direction = Vector2(tail_side * 0.28, -1.0).normalized()

	# Balik hizlandikca kopuk biraz yogunlasir.
	var speed_value: float = absf(float(_leviathan.get("current_swim_velocity_x")))
	var speed_ratio: float = clampf(speed_value / 30.0, 0.55, 1.55)
	_wake_particles.speed_scale = lerpf(0.80, 1.35, (speed_ratio - 0.55) / 1.0)
	_bubble_particles.speed_scale = lerpf(0.78, 1.18, (speed_ratio - 0.55) / 1.0)
