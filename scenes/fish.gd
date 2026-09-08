extends Area2D

@export var fish_type: String = "Sardalya"
@export var fish_value: int = 10

@export var swim_speed: float = 70.0
@export var swim_distance: float = 180.0
@export var bob_height: float = 5.0

var start_x: float
var start_y: float
var direction: float = 1.0

var is_hooked: bool = false
var hook_ref: Area2D
var hook_offset: Vector2
var last_visual_type: String = ""

var swim_wave_time: float = 0.0
var swim_wave_speed: float = 3.0
var swim_wave_angle: float = 3.0
var swim_phase: float = 0.0
var base_sprite_scale: Vector2 = Vector2.ONE

var behavior_time: float = 0.0
var decision_timer: float = 0.0
var behavior_state: int = 0
var behavior_speed_multiplier: float = 1.0
var behavior_range_multiplier: float = 1.0
var behavior_vertical_offset: float = 0.0
var behavior_vertical_target: float = 0.0
var sardine_school_key: int = 0
var world_hook: Area2D = null

const SARDALYA_TEXTURE: Texture2D = preload("res://assets/sardalya.png")
const LEVREK_TEXTURE: Texture2D = preload("res://assets/levrek2.png")
const USKUMRU_TEXTURE: Texture2D = preload("res://assets/uskumru.png")
const TON_BALIGI_TEXTURE: Texture2D = preload("res://assets/tonbaligi.png")
const KILIC_BALIGI_TEXTURE: Texture2D = preload("res://assets/kilic_baligi.svg")
const KOPEKBALIGI_TEXTURE: Texture2D = preload("res://assets/kopekbaligi.svg")
const FENER_BALIGI_TEXTURE: Texture2D = preload("res://assets/fener_baligi.svg")

@onready var fish_sprite: Sprite2D = $FishSprite
@onready var fish_collision: CollisionShape2D = $CollisionShape2D


func _ready() -> void:
	start_x = global_position.x
	start_y = global_position.y
	swim_phase = randf_range(0.0, TAU)
	sardine_school_key = int(round(start_x / 800.0))
	decision_timer = randf_range(0.35, 1.25)

	if fish_collision.shape != null:
		fish_collision.shape = fish_collision.shape.duplicate()

	var scene_root: Node = get_tree().current_scene
	if scene_root != null:
		world_hook = scene_root.get_node_or_null("Boat/Hook") as Area2D

	update_fish_visual()
	update_sprite_direction()


func _physics_process(delta: float) -> void:
	if fish_type != last_visual_type:
		update_fish_visual()

	if is_hooked:
		if is_instance_valid(hook_ref):
			global_position = hook_ref.global_position + hook_offset
		else:
			release_from_hook()
		return

	behavior_time += delta
	decision_timer -= delta
	update_species_behavior(delta)
	update_swim_animation(delta)

	global_position.x += swim_speed * behavior_speed_multiplier * direction * delta

	var active_swim_distance: float = swim_distance * behavior_range_multiplier
	if global_position.x >= start_x + active_swim_distance:
		global_position.x = start_x + active_swim_distance
		direction = -1.0
		update_sprite_direction()
		play_turn_animation()
	elif global_position.x <= start_x - active_swim_distance:
		global_position.x = start_x - active_swim_distance
		direction = 1.0
		update_sprite_direction()
		play_turn_animation()


func update_species_behavior(delta: float) -> void:
	behavior_speed_multiplier = 1.0
	behavior_range_multiplier = 1.0
	behavior_vertical_target = 0.0

	match fish_type:
		"Sardalya":
			_update_sardine_behavior()
		"Levrek":
			_update_levrek_behavior()
		"Uskumru":
			_update_uskumru_behavior()
		"Ton Balığı":
			_update_tuna_behavior()
		"Kılıç Balığı":
			_update_swordfish_behavior()
		"Köpekbalığı":
			_update_shark_behavior()
		"Fener Balığı":
			_update_angler_behavior()
		_:
			behavior_speed_multiplier = 1.0

	behavior_vertical_offset = move_toward(
		behavior_vertical_offset,
		behavior_vertical_target,
		42.0 * delta
	)


func _update_sardine_behavior() -> void:
	var school_wave: float = sin(behavior_time * 0.72 + float(sardine_school_key) * 1.35)
	var wanted_direction: float = 1.0 if school_wave >= 0.0 else -1.0

	if wanted_direction != direction and absf(school_wave) > 0.12:
		direction = wanted_direction
		update_sprite_direction()

	behavior_speed_multiplier = 0.90 + absf(sin(behavior_time * 1.7 + swim_phase)) * 0.18
	behavior_range_multiplier = 0.95
	behavior_vertical_target = sin(behavior_time * 0.9 + float(sardine_school_key)) * 4.0

	if _hook_is_active():
		var hook_distance: float = global_position.distance_to(world_hook.global_position)
		if hook_distance < 92.0:
			direction = -1.0 if world_hook.global_position.x > global_position.x else 1.0
			behavior_speed_multiplier = 1.35
			behavior_range_multiplier = 1.18
			behavior_vertical_target = clampf(
				(global_position.y - world_hook.global_position.y) * 0.32,
				-18.0,
				18.0
			)
			update_sprite_direction()


func _update_levrek_behavior() -> void:
	behavior_speed_multiplier = 0.72 + absf(sin(behavior_time * 1.25 + swim_phase)) * 0.22
	behavior_vertical_target = sin(behavior_time * 0.62 + swim_phase) * 7.0

	if not _hook_can_attract_fish():
		behavior_state = 0
		_avoid_occupied_hook(145.0, 1.12)
		return

	var hook_distance: float = global_position.distance_to(world_hook.global_position)
	if hook_distance > 285.0:
		behavior_state = 0
		return

	if decision_timer <= 0.0:
		behavior_state = 1 if randf() < 0.72 else 2
		decision_timer = randf_range(0.65, 1.35)

	if behavior_state == 1:
		direction = 1.0 if world_hook.global_position.x > global_position.x else -1.0
		behavior_speed_multiplier = 0.82
		behavior_range_multiplier = 1.35
		behavior_vertical_target = clampf(world_hook.global_position.y - start_y, -95.0, 95.0)
		update_sprite_direction()
	elif behavior_state == 2:
		direction = -1.0 if world_hook.global_position.x > global_position.x else 1.0
		behavior_speed_multiplier = 0.52
		behavior_range_multiplier = 1.12
		behavior_vertical_target = clampf((start_y - world_hook.global_position.y) * 0.12, -22.0, 22.0)
		update_sprite_direction()


func _update_uskumru_behavior() -> void:
	var burst_wave: float = sin(behavior_time * 2.45 + swim_phase)
	behavior_speed_multiplier = 1.72 if burst_wave > 0.48 else 0.92
	behavior_vertical_target = sin(behavior_time * 2.0 + swim_phase) * 12.0
	behavior_range_multiplier = 1.15

	if decision_timer <= 0.0:
		if randf() < 0.28:
			direction *= -1.0
			update_sprite_direction()
			play_turn_animation()
		decision_timer = randf_range(0.75, 1.65)

	if _hook_is_active():
		var hook_distance: float = global_position.distance_to(world_hook.global_position)
		if hook_distance < 105.0 and randf() < 0.018:
			direction = -1.0 if world_hook.global_position.x > global_position.x else 1.0
			behavior_speed_multiplier = 1.95
			behavior_vertical_target = clampf(
				(global_position.y - world_hook.global_position.y) * 0.38,
				-28.0,
				28.0
			)
			update_sprite_direction()


func _update_tuna_behavior() -> void:
	var surge_wave: float = sin(behavior_time * 1.15 + swim_phase)
	behavior_speed_multiplier = 1.48 if surge_wave > 0.72 else 0.86
	behavior_vertical_target = sin(behavior_time * 0.48 + swim_phase) * 10.0
	behavior_range_multiplier = 1.20

	if not _hook_can_attract_fish():
		_avoid_occupied_hook(210.0, 1.28)
		return

	var hook_distance: float = global_position.distance_to(world_hook.global_position)
	if hook_distance < 360.0:
		direction = 1.0 if world_hook.global_position.x > global_position.x else -1.0
		behavior_speed_multiplier = 1.34
		behavior_range_multiplier = 1.75
		behavior_vertical_target = clampf(world_hook.global_position.y - start_y, -135.0, 135.0)
		update_sprite_direction()

		if hook_distance < 135.0:
			behavior_speed_multiplier = 1.72


func _update_swordfish_behavior() -> void:
	# Kılıç balığı açık denizde uzun süzülür, sonra çok kısa ve sert deparlar atar.
	var dash_wave: float = sin(behavior_time * 1.65 + swim_phase)
	behavior_speed_multiplier = 1.85 if dash_wave > 0.68 else 0.90
	behavior_range_multiplier = 1.45
	behavior_vertical_target = sin(behavior_time * 0.78 + swim_phase) * 18.0

	if decision_timer <= 0.0:
		if randf() < 0.22:
			direction *= -1.0
			update_sprite_direction()
		decision_timer = randf_range(0.85, 1.65)

	if not _hook_can_attract_fish():
		_avoid_occupied_hook(250.0, 1.38)
		return

	var hook_distance: float = global_position.distance_to(world_hook.global_position)
	if hook_distance < 430.0:
		direction = 1.0 if world_hook.global_position.x > global_position.x else -1.0
		behavior_speed_multiplier = 1.48
		behavior_range_multiplier = 1.85
		behavior_vertical_target = clampf(world_hook.global_position.y - start_y, -155.0, 155.0)
		update_sprite_direction()
		if hook_distance < 150.0:
			behavior_speed_multiplier = 2.15


func _update_shark_behavior() -> void:
	# Köpekbalığı daha ağır hareket eder ama hedefe karar verdiğinde güçlü biçimde yaklaşır.
	behavior_speed_multiplier = 0.70 + absf(sin(behavior_time * 0.62 + swim_phase)) * 0.22
	behavior_range_multiplier = 1.65
	behavior_vertical_target = sin(behavior_time * 0.34 + swim_phase) * 20.0

	if decision_timer <= 0.0:
		if randf() < 0.16:
			direction *= -1.0
			update_sprite_direction()
		decision_timer = randf_range(1.3, 2.4)

	if not _hook_can_attract_fish():
		_avoid_occupied_hook(300.0, 1.16)
		return

	var hook_distance: float = global_position.distance_to(world_hook.global_position)
	if hook_distance < 520.0:
		direction = 1.0 if world_hook.global_position.x > global_position.x else -1.0
		behavior_speed_multiplier = 1.12
		behavior_range_multiplier = 2.0
		behavior_vertical_target = clampf(world_hook.global_position.y - start_y, -185.0, 185.0)
		update_sprite_direction()
		if hook_distance < 175.0:
			behavior_speed_multiplier = 1.58


func _update_angler_behavior() -> void:
	# Fener balığı derinde neredeyse asılı kalır; düzensiz dikey hareketlerle kancaya sokulur.
	var hover_wave: float = sin(behavior_time * 0.72 + swim_phase)
	behavior_speed_multiplier = 0.42 + absf(hover_wave) * 0.20
	behavior_range_multiplier = 0.78
	behavior_vertical_target = sin(behavior_time * 1.18 + swim_phase) * 28.0

	if decision_timer <= 0.0:
		if randf() < 0.34:
			direction *= -1.0
			update_sprite_direction()
		decision_timer = randf_range(1.0, 2.1)

	if not _hook_can_attract_fish():
		_avoid_occupied_hook(190.0, 0.88)
		return

	var hook_distance: float = global_position.distance_to(world_hook.global_position)
	if hook_distance < 310.0:
		direction = 1.0 if world_hook.global_position.x > global_position.x else -1.0
		behavior_speed_multiplier = 0.82
		behavior_range_multiplier = 1.18
		behavior_vertical_target = clampf(world_hook.global_position.y - start_y, -120.0, 120.0)
		update_sprite_direction()


func _avoid_occupied_hook(radius: float, speed_multiplier: float) -> void:
	if not _hook_is_active() or _hook_is_available():
		return

	var hook_distance: float = global_position.distance_to(world_hook.global_position)
	if hook_distance >= radius:
		return

	var horizontal_delta: float = global_position.x - world_hook.global_position.x
	if absf(horizontal_delta) < 3.0:
		direction = -1.0 if randf() < 0.5 else 1.0
	else:
		direction = 1.0 if horizontal_delta > 0.0 else -1.0

	behavior_speed_multiplier = maxf(behavior_speed_multiplier, speed_multiplier)
	behavior_range_multiplier = maxf(behavior_range_multiplier, 1.25)
	behavior_vertical_target = clampf(
		(global_position.y - world_hook.global_position.y) * 0.20,
		-35.0,
		35.0
	)
	update_sprite_direction()


func _hook_is_active() -> bool:
	if not is_instance_valid(world_hook):
		return false
	var deployed_value: Variant = world_hook.get("deployed")
	return deployed_value is bool and deployed_value == true


func _hook_is_available() -> bool:
	if not _hook_is_active():
		return false
	var hooked_value: Variant = world_hook.get("hooked_fish")
	return hooked_value == null


func _hook_can_attract_fish() -> bool:
	return _hook_is_active() and _hook_is_available()


func update_swim_animation(delta: float) -> void:
	swim_wave_time += delta * swim_wave_speed

	var wave: float = sin(swim_wave_time + swim_phase)
	var slow_wave: float = sin(swim_wave_time * 0.55 + swim_phase)

	fish_sprite.rotation = deg_to_rad(wave * swim_wave_angle * 0.42)
	fish_sprite.skew = wave * 0.035
	fish_sprite.scale = Vector2(
		base_sprite_scale.x * (1.0 + absf(wave) * 0.018),
		base_sprite_scale.y * (1.0 - absf(wave) * 0.025)
	)
	global_position.y = start_y + behavior_vertical_offset + slow_wave * bob_height

	var depth_ratio: float = clampf((global_position.y - 360.0) / 2800.0, 0.0, 1.0)
	var base_modulate := Color(
		lerpf(1.0, 0.62, depth_ratio),
		lerpf(1.0, 0.78, depth_ratio),
		lerpf(1.0, 0.94, depth_ratio),
		1.0
	)

	if fish_type == "Fener Balığı":
		var lure_pulse: float = 0.92 + absf(sin(behavior_time * 2.4)) * 0.18
		base_modulate.b = minf(1.18, base_modulate.b * lure_pulse)
		base_modulate.g = minf(1.04, base_modulate.g * lure_pulse)

	fish_sprite.modulate = base_modulate


func update_fish_visual() -> void:
	last_visual_type = fish_type

	match fish_type:
		"Sardalya":
			fish_sprite.texture = SARDALYA_TEXTURE
			base_sprite_scale = Vector2(0.06, 0.06)
			swim_wave_speed = 4.0
			swim_wave_angle = 2.5
			bob_height = 3.5
			_set_collision_size(Vector2(55.0, 24.0))
		"Levrek":
			fish_sprite.texture = LEVREK_TEXTURE
			base_sprite_scale = Vector2(0.08, 0.08)
			swim_wave_speed = 3.3
			swim_wave_angle = 3.0
			bob_height = 4.5
			_set_collision_size(Vector2(68.0, 30.0))
		"Uskumru":
			fish_sprite.texture = USKUMRU_TEXTURE
			base_sprite_scale = Vector2(0.09, 0.09)
			swim_wave_speed = 4.8
			swim_wave_angle = 4.0
			bob_height = 5.0
			_set_collision_size(Vector2(76.0, 30.0))
		"Ton Balığı":
			fish_sprite.texture = TON_BALIGI_TEXTURE
			base_sprite_scale = Vector2(0.12, 0.12)
			swim_wave_speed = 2.4
			swim_wave_angle = 2.0
			bob_height = 6.0
			_set_collision_size(Vector2(95.0, 38.0))
		"Kılıç Balığı":
			fish_sprite.texture = KILIC_BALIGI_TEXTURE
			base_sprite_scale = Vector2(0.72, 0.72)
			swim_wave_speed = 3.2
			swim_wave_angle = 2.5
			bob_height = 7.0
			_set_collision_size(Vector2(132.0, 38.0))
		"Köpekbalığı":
			fish_sprite.texture = KOPEKBALIGI_TEXTURE
			base_sprite_scale = Vector2(0.78, 0.78)
			swim_wave_speed = 1.9
			swim_wave_angle = 1.6
			bob_height = 8.0
			_set_collision_size(Vector2(150.0, 54.0))
		"Fener Balığı":
			fish_sprite.texture = FENER_BALIGI_TEXTURE
			base_sprite_scale = Vector2(0.74, 0.74)
			swim_wave_speed = 2.1
			swim_wave_angle = 4.2
			bob_height = 11.0
			_set_collision_size(Vector2(88.0, 58.0))
		_:
			fish_sprite.texture = SARDALYA_TEXTURE
			base_sprite_scale = Vector2(0.06, 0.06)
			swim_wave_speed = 4.0
			swim_wave_angle = 2.5
			bob_height = 3.5
			_set_collision_size(Vector2(55.0, 24.0))

	fish_sprite.scale = base_sprite_scale


func _set_collision_size(new_size: Vector2) -> void:
	if fish_collision == null:
		return
	var rect_shape: RectangleShape2D = fish_collision.shape as RectangleShape2D
	if rect_shape != null:
		rect_shape.size = new_size


func update_sprite_direction() -> void:
	fish_sprite.flip_h = direction < 0.0


func play_turn_animation() -> void:
	var tween: Tween = create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(fish_sprite, "scale:y", base_sprite_scale.y * 0.78, 0.08)
	tween.tween_property(fish_sprite, "scale:y", base_sprite_scale.y, 0.12)


func play_hooked_animation() -> void:
	var tween: Tween = create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(fish_sprite, "rotation", deg_to_rad(14.0), 0.06)
	tween.tween_property(fish_sprite, "rotation", deg_to_rad(-14.0), 0.06)
	tween.tween_property(fish_sprite, "rotation", deg_to_rad(11.0), 0.06)
	tween.tween_property(fish_sprite, "rotation", deg_to_rad(-11.0), 0.06)
	tween.tween_property(fish_sprite, "rotation", 0.0, 0.08)

	var flash: Tween = create_tween()
	flash.tween_property(fish_sprite, "modulate", Color(1.5, 1.5, 1.15, 1.0), 0.08)
	flash.tween_property(fish_sprite, "modulate", Color.WHITE, 0.18)


func hook_to(hook: Area2D) -> void:
	if is_hooked:
		return

	is_hooked = true
	hook_ref = hook
	hook_offset = Vector2.ZERO
	global_position = hook.global_position
	play_hooked_animation()


func release_from_hook() -> void:
	is_hooked = false
	hook_ref = null
	start_x = global_position.x
	start_y = global_position.y
	behavior_vertical_offset = 0.0
	behavior_vertical_target = 0.0
	behavior_state = 0
	fish_sprite.rotation = 0.0
	fish_sprite.skew = 0.0
	fish_sprite.scale = base_sprite_scale
