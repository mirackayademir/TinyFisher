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

# Daha doğal yüzüş için hız doğrudan değiştirilmez; balık hedef hıza ivmelenir.
var current_swim_velocity_x: float = 0.0
var swim_acceleration: float = 260.0
var vertical_response: float = 42.0
var turn_roll: float = 0.0
var turn_roll_strength: float = 5.0
var base_tail_speed: float = 6.0
var base_tail_strength: float = 24.0
var base_body_strength: float = 4.0
var was_dashing: bool = false

var angler_glow_outer: Polygon2D
var angler_glow_inner: Polygon2D
var sword_speed_trail: Line2D

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
	current_swim_velocity_x = swim_speed * direction * 0.65

	if fish_collision.shape != null:
		fish_collision.shape = fish_collision.shape.duplicate()

	# Her balık kendi shader parametrelerine sahip olsun; büyük türlerin kuyruk fiziği ayrışır.
	if fish_sprite.material != null:
		fish_sprite.material = fish_sprite.material.duplicate()

	var scene_root: Node = get_tree().current_scene
	if scene_root != null:
		world_hook = scene_root.get_node_or_null("Boat/Hook") as Area2D

	update_fish_visual()
	_setup_special_visuals()
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

	var target_velocity_x: float = swim_speed * behavior_speed_multiplier * direction
	current_swim_velocity_x = move_toward(
		current_swim_velocity_x,
		target_velocity_x,
		swim_acceleration * delta
	)
	global_position.x += current_swim_velocity_x * delta

	var active_swim_distance: float = swim_distance * behavior_range_multiplier
	if global_position.x >= start_x + active_swim_distance:
		global_position.x = start_x + active_swim_distance
		direction = -1.0
		current_swim_velocity_x *= 0.25
		update_sprite_direction()
		play_turn_animation()
	elif global_position.x <= start_x - active_swim_distance:
		global_position.x = start_x - active_swim_distance
		direction = 1.0
		current_swim_velocity_x *= 0.25
		update_sprite_direction()
		play_turn_animation()


func update_species_behavior(delta: float) -> void:
	behavior_speed_multiplier = 1.0
	behavior_range_multiplier = 1.0
	behavior_vertical_target = 0.0
	was_dashing = false

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
		vertical_response * delta
	)
	turn_roll = move_toward(turn_roll, 0.0, deg_to_rad(34.0) * delta)


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
			behavior_vertical_target = clampf((global_position.y - world_hook.global_position.y) * 0.32, -18.0, 18.0)
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
			behavior_vertical_target = clampf((global_position.y - world_hook.global_position.y) * 0.38, -28.0, 28.0)
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
	# Uzun süre akıcı seyir, ardından gerçek kılıç balığı gibi ani hız patlamaları.
	var dash_wave: float = sin(behavior_time * 1.48 + swim_phase)
	was_dashing = dash_wave > 0.62
	behavior_speed_multiplier = 2.18 if was_dashing else 0.82
	behavior_range_multiplier = 1.55
	behavior_vertical_target = sin(behavior_time * 0.66 + swim_phase) * 15.0

	if decision_timer <= 0.0:
		if randf() < 0.18:
			direction *= -1.0
			update_sprite_direction()
			play_turn_animation()
		decision_timer = randf_range(1.0, 1.9)

	if not _hook_can_attract_fish():
		_avoid_occupied_hook(270.0, 1.45)
		return

	var hook_distance: float = global_position.distance_to(world_hook.global_position)
	if hook_distance < 470.0:
		direction = 1.0 if world_hook.global_position.x > global_position.x else -1.0
		behavior_range_multiplier = 1.95
		behavior_vertical_target = clampf(world_hook.global_position.y - start_y, -145.0, 145.0)
		behavior_speed_multiplier = 1.35
		update_sprite_direction()
		if hook_distance < 185.0:
			behavior_speed_multiplier = 2.45
			was_dashing = true


func _update_shark_behavior() -> void:
	# Köpekbalığı yüksek kütleli: yavaş yön değiştirir, geniş dönüş yapar, saldırıda ivmelenir.
	behavior_speed_multiplier = 0.68 + absf(sin(behavior_time * 0.52 + swim_phase)) * 0.18
	behavior_range_multiplier = 1.80
	behavior_vertical_target = sin(behavior_time * 0.28 + swim_phase) * 17.0

	if decision_timer <= 0.0:
		if randf() < 0.13:
			direction *= -1.0
			update_sprite_direction()
			play_turn_animation()
		decision_timer = randf_range(1.6, 2.8)

	if not _hook_can_attract_fish():
		_avoid_occupied_hook(330.0, 1.18)
		return

	var hook_distance: float = global_position.distance_to(world_hook.global_position)
	if hook_distance < 560.0:
		direction = 1.0 if world_hook.global_position.x > global_position.x else -1.0
		behavior_speed_multiplier = 1.02
		behavior_range_multiplier = 2.1
		behavior_vertical_target = clampf(world_hook.global_position.y - start_y, -175.0, 175.0)
		update_sprite_direction()
		if hook_distance < 220.0:
			behavior_speed_multiplier = 1.72
			was_dashing = true


func _update_angler_behavior() -> void:
	# Derin suda nötr yüzdürme hissi: yatay hareket az, dikey salınım ağır ve gecikmeli.
	var hover_wave: float = sin(behavior_time * 0.63 + swim_phase)
	behavior_speed_multiplier = 0.34 + absf(hover_wave) * 0.18
	behavior_range_multiplier = 0.72
	behavior_vertical_target = sin(behavior_time * 0.96 + swim_phase) * 31.0

	if decision_timer <= 0.0:
		if randf() < 0.26:
			direction *= -1.0
			update_sprite_direction()
			play_turn_animation()
		decision_timer = randf_range(1.3, 2.5)

	if not _hook_can_attract_fish():
		_avoid_occupied_hook(205.0, 0.82)
		return

	var hook_distance: float = global_position.distance_to(world_hook.global_position)
	if hook_distance < 330.0:
		direction = 1.0 if world_hook.global_position.x > global_position.x else -1.0
		behavior_speed_multiplier = 0.73
		behavior_range_multiplier = 1.16
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
	behavior_vertical_target = clampf((global_position.y - world_hook.global_position.y) * 0.20, -35.0, 35.0)
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

	var vertical_error: float = behavior_vertical_target - behavior_vertical_offset
	var motion_pitch: float = deg_to_rad(clampf(vertical_error * 0.045, -4.5, 4.5))
	var wave_rotation: float = deg_to_rad(wave * swim_wave_angle * 0.34)
	fish_sprite.rotation = wave_rotation + motion_pitch + turn_roll
	fish_sprite.skew = wave * 0.024

	var speed_ratio: float = clampf(absf(current_swim_velocity_x) / maxf(swim_speed, 1.0), 0.25, 2.6)
	var stretch_x: float = 1.0 + minf(speed_ratio - 1.0, 1.0) * 0.025
	var squash_y: float = 1.0 - absf(wave) * 0.018
	if was_dashing:
		stretch_x += 0.035
		squash_y -= 0.025

	fish_sprite.scale = Vector2(base_sprite_scale.x * stretch_x, base_sprite_scale.y * squash_y)
	global_position.y = start_y + behavior_vertical_offset + slow_wave * bob_height

	var depth_ratio: float = clampf((global_position.y - 360.0) / 2800.0, 0.0, 1.0)
	var base_modulate := Color(
		lerpf(1.0, 0.62, depth_ratio),
		lerpf(1.0, 0.78, depth_ratio),
		lerpf(1.0, 0.94, depth_ratio),
		1.0
	)

	if fish_type == "Fener Balığı":
		var lure_pulse: float = 0.78 + absf(sin(behavior_time * 2.35)) * 0.34
		base_modulate.b = minf(1.16, base_modulate.b * (0.96 + lure_pulse * 0.08))
		_update_angler_glow(lure_pulse)
	elif fish_type == "Kılıç Balığı":
		_update_sword_trail(was_dashing, speed_ratio)

	fish_sprite.modulate = base_modulate
	_update_shader_motion(speed_ratio)


func update_fish_visual() -> void:
	last_visual_type = fish_type

	match fish_type:
		"Sardalya":
			fish_sprite.texture = SARDALYA_TEXTURE
			base_sprite_scale = Vector2(0.06, 0.06)
			swim_wave_speed = 4.0
			swim_wave_angle = 2.5
			bob_height = 3.5
			swim_acceleration = 320.0
			vertical_response = 52.0
			turn_roll_strength = 5.0
			base_tail_strength = 26.0
			base_tail_speed = 7.0
			base_body_strength = 4.0
			_set_collision_size(Vector2(55.0, 24.0))
		"Levrek":
			fish_sprite.texture = LEVREK_TEXTURE
			base_sprite_scale = Vector2(0.08, 0.08)
			swim_wave_speed = 3.3
			swim_wave_angle = 3.0
			bob_height = 4.5
			swim_acceleration = 235.0
			vertical_response = 46.0
			turn_roll_strength = 6.0
			base_tail_strength = 24.0
			base_tail_speed = 5.8
			base_body_strength = 4.0
			_set_collision_size(Vector2(68.0, 30.0))
		"Uskumru":
			fish_sprite.texture = USKUMRU_TEXTURE
			base_sprite_scale = Vector2(0.09, 0.09)
			swim_wave_speed = 4.8
			swim_wave_angle = 4.0
			bob_height = 5.0
			swim_acceleration = 390.0
			vertical_response = 68.0
			turn_roll_strength = 8.0
			base_tail_strength = 30.0
			base_tail_speed = 8.2
			base_body_strength = 4.5
			_set_collision_size(Vector2(76.0, 30.0))
		"Ton Balığı":
			fish_sprite.texture = TON_BALIGI_TEXTURE
			base_sprite_scale = Vector2(0.12, 0.12)
			swim_wave_speed = 2.4
			swim_wave_angle = 2.0
			bob_height = 6.0
			swim_acceleration = 170.0
			vertical_response = 38.0
			turn_roll_strength = 5.0
			base_tail_strength = 24.0
			base_tail_speed = 4.8
			base_body_strength = 3.8
			_set_collision_size(Vector2(95.0, 38.0))
		"Kılıç Balığı":
			fish_sprite.texture = KILIC_BALIGI_TEXTURE
			base_sprite_scale = Vector2(0.40, 0.40)
			swim_wave_speed = 3.1
			swim_wave_angle = 2.2
			bob_height = 6.0
			swim_acceleration = 430.0
			vertical_response = 58.0
			turn_roll_strength = 7.5
			base_tail_strength = 18.0
			base_tail_speed = 6.4
			base_body_strength = 2.6
			_set_collision_size(Vector2(165.0, 50.0))
		"Köpekbalığı":
			fish_sprite.texture = KOPEKBALIGI_TEXTURE
			base_sprite_scale = Vector2(0.43, 0.43)
			swim_wave_speed = 1.65
			swim_wave_angle = 1.35
			bob_height = 7.0
			swim_acceleration = 92.0
			vertical_response = 26.0
			turn_roll_strength = 10.0
			base_tail_strength = 15.0
			base_tail_speed = 3.6
			base_body_strength = 2.2
			_set_collision_size(Vector2(185.0, 72.0))
		"Fener Balığı":
			fish_sprite.texture = FENER_BALIGI_TEXTURE
			base_sprite_scale = Vector2(0.43, 0.43)
			swim_wave_speed = 1.75
			swim_wave_angle = 3.0
			bob_height = 10.0
			swim_acceleration = 70.0
			vertical_response = 20.0
			turn_roll_strength = 7.0
			base_tail_strength = 10.0
			base_tail_speed = 3.2
			base_body_strength = 2.8
			_set_collision_size(Vector2(120.0, 84.0))
		_:
			fish_sprite.texture = SARDALYA_TEXTURE
			base_sprite_scale = Vector2(0.06, 0.06)
			swim_wave_speed = 4.0
			swim_wave_angle = 2.5
			bob_height = 3.5
			swim_acceleration = 260.0
			vertical_response = 42.0
			turn_roll_strength = 5.0
			base_tail_strength = 24.0
			base_tail_speed = 6.0
			base_body_strength = 4.0
			_set_collision_size(Vector2(55.0, 24.0))

	fish_sprite.scale = base_sprite_scale
	_apply_base_shader_params()


func _setup_special_visuals() -> void:
	if fish_type == "Fener Balığı":
		angler_glow_outer = Polygon2D.new()
		angler_glow_outer.polygon = PackedVector2Array([
			Vector2(0.0, -16.0), Vector2(16.0, 0.0), Vector2(0.0, 16.0), Vector2(-16.0, 0.0)
		])
		angler_glow_outer.color = Color(1.0, 0.54, 0.13, 0.16)
		angler_glow_outer.z_index = -1
		add_child(angler_glow_outer)

		angler_glow_inner = Polygon2D.new()
		angler_glow_inner.polygon = PackedVector2Array([
			Vector2(0.0, -5.0), Vector2(5.0, 0.0), Vector2(0.0, 5.0), Vector2(-5.0, 0.0)
		])
		angler_glow_inner.color = Color(1.0, 0.88, 0.42, 0.88)
		add_child(angler_glow_inner)
		_update_angler_glow(1.0)

	if fish_type == "Kılıç Balığı":
		sword_speed_trail = Line2D.new()
		sword_speed_trail.width = 3.0
		sword_speed_trail.default_color = Color(0.20, 0.57, 0.92, 0.0)
		sword_speed_trail.z_index = -1
		sword_speed_trail.antialiased = false
		add_child(sword_speed_trail)
		_update_sword_trail(false, 1.0)


func _update_angler_glow(pulse: float) -> void:
	if angler_glow_outer == null or angler_glow_inner == null:
		return
	var x_sign: float = 1.0 if direction > 0.0 else -1.0
	var lure_position := Vector2(18.0 * x_sign, -47.0)
	angler_glow_outer.position = lure_position
	angler_glow_inner.position = lure_position
	angler_glow_outer.scale = Vector2.ONE * lerpf(0.86, 1.28, pulse)
	angler_glow_outer.color.a = lerpf(0.10, 0.25, pulse)
	angler_glow_inner.scale = Vector2.ONE * lerpf(0.84, 1.14, pulse)
	angler_glow_inner.color.a = lerpf(0.64, 1.0, pulse)


func _update_sword_trail(active: bool, speed_ratio: float) -> void:
	if sword_speed_trail == null:
		return
	var x_sign: float = 1.0 if direction > 0.0 else -1.0
	if x_sign > 0.0:
		sword_speed_trail.points = PackedVector2Array([Vector2(-112.0, -2.0), Vector2(-56.0, 0.0), Vector2(-20.0, 1.0)])
	else:
		sword_speed_trail.points = PackedVector2Array([Vector2(112.0, -2.0), Vector2(56.0, 0.0), Vector2(20.0, 1.0)])
	var alpha: float = clampf((speed_ratio - 1.25) * 0.28, 0.0, 0.30) if active else 0.0
	sword_speed_trail.default_color = Color(0.22, 0.62, 0.96, alpha)
	sword_speed_trail.width = lerpf(2.0, 4.0, clampf(speed_ratio / 2.4, 0.0, 1.0))


func _apply_base_shader_params() -> void:
	var shader_material: ShaderMaterial = fish_sprite.material as ShaderMaterial
	if shader_material == null:
		return
	shader_material.set_shader_parameter("tail_strength", base_tail_strength)
	shader_material.set_shader_parameter("tail_speed", base_tail_speed)
	shader_material.set_shader_parameter("body_strength", base_body_strength)


func _update_shader_motion(speed_ratio: float) -> void:
	var shader_material: ShaderMaterial = fish_sprite.material as ShaderMaterial
	if shader_material == null:
		return
	var speed_factor: float = clampf(speed_ratio, 0.45, 2.15)
	shader_material.set_shader_parameter("tail_speed", base_tail_speed * lerpf(0.78, 1.45, speed_factor / 2.15))
	shader_material.set_shader_parameter("tail_strength", base_tail_strength * lerpf(0.86, 1.15, speed_factor / 2.15))


func _set_collision_size(new_size: Vector2) -> void:
	if fish_collision == null:
		return
	var rect_shape: RectangleShape2D = fish_collision.shape as RectangleShape2D
	if rect_shape != null:
		rect_shape.size = new_size


func update_sprite_direction() -> void:
	fish_sprite.flip_h = direction < 0.0
	if fish_type == "Fener Balığı":
		_update_angler_glow(1.0)
	if fish_type == "Kılıç Balığı":
		_update_sword_trail(was_dashing, 1.0)


func play_turn_animation() -> void:
	turn_roll = -direction * deg_to_rad(turn_roll_strength)
	var tween: Tween = create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(fish_sprite, "scale:y", base_sprite_scale.y * 0.84, 0.09)
	tween.tween_property(fish_sprite, "scale:y", base_sprite_scale.y, 0.15)


func play_hooked_animation() -> void:
	var tween: Tween = create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)
	var struggle_angle: float = 18.0
	if fish_type == "Köpekbalığı":
		struggle_angle = 11.0
	elif fish_type == "Fener Balığı":
		struggle_angle = 15.0
	elif fish_type == "Kılıç Balığı":
		struggle_angle = 22.0

	tween.tween_property(fish_sprite, "rotation", deg_to_rad(struggle_angle), 0.07)
	tween.tween_property(fish_sprite, "rotation", deg_to_rad(-struggle_angle), 0.07)
	tween.tween_property(fish_sprite, "rotation", deg_to_rad(struggle_angle * 0.65), 0.07)
	tween.tween_property(fish_sprite, "rotation", deg_to_rad(-struggle_angle * 0.65), 0.07)
	tween.tween_property(fish_sprite, "rotation", 0.0, 0.10)

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
	current_swim_velocity_x = 0.0
	play_hooked_animation()


func release_from_hook() -> void:
	is_hooked = false
	hook_ref = null
	start_x = global_position.x
	start_y = global_position.y
	behavior_vertical_offset = 0.0
	behavior_vertical_target = 0.0
	behavior_state = 0
	current_swim_velocity_x = swim_speed * direction * 0.45
	turn_roll = 0.0
	fish_sprite.rotation = 0.0
	fish_sprite.skew = 0.0
	fish_sprite.scale = base_sprite_scale
