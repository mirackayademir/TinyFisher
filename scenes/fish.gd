extends Area2D

const FishCatalog = preload("res://scenes/fish_catalog.gd")

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

# Wave-1 gerçek raster balıklar için eklemli görsel rig.
# İlk profil: Barakuda. Diğer dört balık tek tek aynı sisteme eklenecek.
var articulated_rig: Node2D
var rig_tail: Node2D
var rig_rear_body: Node2D
var rig_core_body: Node2D
var rig_head: Node2D
var rig_moray_tail_tip: Node2D
var rig_moray_mid_tail: Node2D
var rig_moray_front_body: Node2D
var rig_moray_mesh: MeshInstance2D
var rig_ray_mesh: MeshInstance2D
var rig_squid_mesh: MeshInstance2D
var rig_sea_devil_mesh: MeshInstance2D
var rig_shark_mesh: MeshInstance2D
var rig_shark_gills: Array[Line2D] = []
var rig_sea_glow_1: Polygon2D
var rig_sea_glow_2: Polygon2D
var rig_sea_glow_3: Polygon2D
var rig_gill: Line2D
var rig_jaw: Line2D
var rig_texture_size: Vector2 = Vector2.ZERO
var rig_time: float = 0.0

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

	match FishCatalog.get_behavior_id(fish_type):
		"school":
			_update_sardine_behavior()
		"curious":
			_update_levrek_behavior()
		"burst":
			_update_uskumru_behavior()
		"surge":
			_update_tuna_behavior()
		"predator":
			_update_shark_behavior()
		"hover":
			_update_angler_behavior()
		"hunter":
			_update_barracuda_behavior()
		"ambush":
			_update_moray_behavior()
		"glide":
			_update_ray_behavior()
		"lurker":
			_update_sea_devil_behavior()
		"jet":
			_update_squid_behavior()
		_:
			behavior_speed_multiplier = 1.0

	# Bütün türler için ortak "yemi alma" katmanı.
	# Türün kendi yüzüş karakterini korur, fakat aktif ve boş kanca yakındaysa
	# balığın kancayı ıskalayıp sonsuza kadar etrafında dolaşmasını engeller.
	_apply_hook_bite_assist()

	behavior_vertical_offset = move_toward(
		behavior_vertical_offset,
		behavior_vertical_target,
		vertical_response * delta
	)
	turn_roll = move_toward(turn_roll, 0.0, deg_to_rad(34.0) * delta)



func _apply_hook_bite_assist() -> void:
	if not _hook_can_attract_fish():
		return

	var hook_distance: float = global_position.distance_to(world_hook.global_position)
	var collision_size: Vector2 = FishCatalog.get_collision_size(fish_type)
	var fish_span: float = maxf(collision_size.x, collision_size.y)

	# Büyük balıklar biraz daha uzaktan yemi fark eder; küçüklerde menzil daha dar kalır.
	var attraction_radius: float = clampf(135.0 + fish_span * 0.55, 150.0, 290.0)
	if hook_distance > attraction_radius:
		return

	var to_hook_x: float = world_hook.global_position.x - global_position.x
	if absf(to_hook_x) > 2.0:
		direction = 1.0 if to_hook_x > 0.0 else -1.0

	var desired_vertical: float = world_hook.global_position.y - start_y
	var vertical_limit: float = clampf(65.0 + fish_span * 0.48, 80.0, 180.0)
	behavior_vertical_target = clampf(desired_vertical, -vertical_limit, vertical_limit)
	behavior_range_multiplier = maxf(behavior_range_multiplier, 1.45)

	# Kancaya yaklaştıkça yeme doğru kararlı bir son hamle yapar.
	var proximity: float = 1.0 - clampf(hook_distance / attraction_radius, 0.0, 1.0)
	var bite_speed: float = lerpf(1.05, 1.85, proximity)
	behavior_speed_multiplier = maxf(behavior_speed_multiplier, bite_speed)

	if hook_distance < 72.0:
		behavior_speed_multiplier = maxf(behavior_speed_multiplier, 1.95)
		behavior_vertical_target = clampf(
			world_hook.global_position.y - start_y,
			-vertical_limit,
			vertical_limit
		)

	update_sprite_direction()


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


func _update_barracuda_behavior() -> void:
	# Uzun sakin devriye + yeme yaklasinca tek hamlede hizlanma.
	var cruise_wave: float = sin(behavior_time * 0.92 + swim_phase)
	behavior_speed_multiplier = 0.92 + absf(cruise_wave) * 0.22
	behavior_range_multiplier = 1.55
	behavior_vertical_target = sin(behavior_time * 0.72 + swim_phase) * 8.0

	if decision_timer <= 0.0:
		if randf() < 0.14:
			direction *= -1.0
			update_sprite_direction()
			play_turn_animation()
		decision_timer = randf_range(1.1, 2.1)

	if not _hook_can_attract_fish():
		_avoid_occupied_hook(260.0, 1.38)
		return

	var hook_distance: float = global_position.distance_to(world_hook.global_position)
	if hook_distance < 520.0:
		direction = 1.0 if world_hook.global_position.x > global_position.x else -1.0
		behavior_vertical_target = clampf(world_hook.global_position.y - start_y, -120.0, 120.0)
		behavior_speed_multiplier = 1.28
		update_sprite_direction()
		if hook_distance < 180.0:
			behavior_speed_multiplier = 2.55
			behavior_range_multiplier = 2.05
			was_dashing = true


func _update_moray_behavior() -> void:
	# Kaya kovugunda pusuda bekler; yem yakinlasinca kisa ama cok sert bir atak yapar.
	behavior_speed_multiplier = 0.26 + absf(sin(behavior_time * 0.54 + swim_phase)) * 0.16
	behavior_range_multiplier = 0.62
	behavior_vertical_target = sin(behavior_time * 1.1 + swim_phase) * 5.0

	if not _hook_can_attract_fish():
		_avoid_occupied_hook(155.0, 0.82)
		return

	var hook_distance: float = global_position.distance_to(world_hook.global_position)
	if hook_distance < 245.0:
		direction = 1.0 if world_hook.global_position.x > global_position.x else -1.0
		behavior_vertical_target = clampf(world_hook.global_position.y - start_y, -75.0, 75.0)
		update_sprite_direction()

		if hook_distance < 115.0:
			behavior_speed_multiplier = 3.0
			behavior_range_multiplier = 1.35
			was_dashing = true
		else:
			behavior_speed_multiplier = 0.55


func _update_ray_behavior() -> void:
	# Vatoz zemine paralel, genis ve sakin bir hat izler; dikey hareketi kanat cirpmasi gibi yumusaktir.
	var glide_wave: float = sin(behavior_time * 0.44 + swim_phase)
	behavior_speed_multiplier = 0.72 + absf(glide_wave) * 0.16
	behavior_range_multiplier = 1.75
	behavior_vertical_target = sin(behavior_time * 0.58 + swim_phase) * 22.0

	if decision_timer <= 0.0:
		if randf() < 0.10:
			direction *= -1.0
			update_sprite_direction()
			play_turn_animation()
		decision_timer = randf_range(2.0, 3.8)

	if _hook_can_attract_fish():
		var hook_distance: float = global_position.distance_to(world_hook.global_position)
		if hook_distance < 280.0:
			direction = 1.0 if world_hook.global_position.x > global_position.x else -1.0
			behavior_speed_multiplier = 0.94
			behavior_vertical_target = clampf(world_hook.global_position.y - start_y, -80.0, 80.0)
			update_sprite_direction()


func _update_sea_devil_behavior() -> void:
	# Derinde neredeyse sabit asili kalir; yem yakindaysa yavasca sokulup son anda hamle yapar.
	var drift: float = sin(behavior_time * 0.38 + swim_phase)
	behavior_speed_multiplier = 0.22 + absf(drift) * 0.18
	behavior_range_multiplier = 0.70
	behavior_vertical_target = sin(behavior_time * 0.74 + swim_phase) * 27.0

	if decision_timer <= 0.0:
		if randf() < 0.20:
			direction *= -1.0
			update_sprite_direction()
		decision_timer = randf_range(1.8, 3.1)

	if not _hook_can_attract_fish():
		_avoid_occupied_hook(190.0, 0.72)
		return

	var hook_distance: float = global_position.distance_to(world_hook.global_position)
	if hook_distance < 360.0:
		direction = 1.0 if world_hook.global_position.x > global_position.x else -1.0
		behavior_vertical_target = clampf(world_hook.global_position.y - start_y, -110.0, 110.0)
		behavior_speed_multiplier = 0.58
		update_sprite_direction()
		if hook_distance < 105.0:
			behavior_speed_multiplier = 1.95
			was_dashing = true


func _update_squid_behavior() -> void:
	# Kalamar duz yuzmek yerine jet darbeleriyle ileri atilir ve hafif dikey zikzak yapar.
	var jet_wave: float = sin(behavior_time * 2.15 + swim_phase)
	var jet_active: bool = jet_wave > 0.64
	behavior_speed_multiplier = 2.35 if jet_active else 0.46
	behavior_range_multiplier = 1.32
	behavior_vertical_target = sin(behavior_time * 1.52 + swim_phase) * 30.0
	was_dashing = jet_active

	if decision_timer <= 0.0:
		if randf() < 0.31:
			direction *= -1.0
			update_sprite_direction()
			play_turn_animation()
		decision_timer = randf_range(0.8, 1.55)

	if not _hook_can_attract_fish():
		_avoid_occupied_hook(210.0, 1.32)
		return

	var hook_distance: float = global_position.distance_to(world_hook.global_position)
	if hook_distance < 350.0:
		direction = 1.0 if world_hook.global_position.x > global_position.x else -1.0
		behavior_vertical_target = clampf(world_hook.global_position.y - start_y, -135.0, 135.0)
		update_sprite_direction()
		if hook_distance < 150.0:
			behavior_speed_multiplier = 2.8
			was_dashing = true


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
	var exact_art: bool = FishCatalog.is_wave_1_species(fish_type) or fish_type == "Köpekbalığı"

	# Onayli 5 raster balikta resmi bukup karartma: kaynak goruntu birebir kalsin.
	if exact_art:
		fish_sprite.rotation = motion_pitch * 0.25 + turn_roll * 0.25
		fish_sprite.skew = 0.0
	else:
		fish_sprite.rotation = wave_rotation + motion_pitch + turn_roll
		fish_sprite.skew = wave * 0.024

	var speed_ratio: float = clampf(absf(current_swim_velocity_x) / maxf(swim_speed, 1.0), 0.25, 2.6)

	if articulated_rig != null:
		articulated_rig.rotation = motion_pitch * 0.18 + turn_roll * 0.18
		_update_articulated_rig(delta, speed_ratio)

	var stretch_x: float = 1.0
	var squash_y: float = 1.0
	if not exact_art:
		stretch_x = 1.0 + minf(speed_ratio - 1.0, 1.0) * 0.025
		squash_y = 1.0 - absf(wave) * 0.018
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

	if exact_art:
		base_modulate = Color.WHITE

	if fish_type == "Fener Balığı":
		var lure_pulse: float = 0.78 + absf(sin(behavior_time * 2.35)) * 0.34
		base_modulate.b = minf(1.16, base_modulate.b * (0.96 + lure_pulse * 0.08))
		_update_angler_glow(lure_pulse)

	fish_sprite.modulate = base_modulate
	if articulated_rig != null:
		articulated_rig.modulate = Color.WHITE
	_update_shader_motion(speed_ratio)


func update_fish_visual() -> void:
	last_visual_type = fish_type
	var profile: Dictionary = FishCatalog.get_profile(fish_type)
	var visual_profile: Dictionary = profile
	var texture: Texture2D = FishCatalog.get_texture(fish_type)

	if texture == null:
		push_error("FISH VISUAL: texture could not be loaded for " + fish_type + "; using safe placeholder.")
		visual_profile = FishCatalog.get_profile("Sardalya")
		texture = FishCatalog.get_texture("Sardalya")

	fish_sprite.texture = texture

	var visual_scale: float = float(visual_profile.get("visual_scale", 0.06))
	base_sprite_scale = Vector2.ONE * visual_scale
	swim_wave_speed = float(visual_profile.get("swim_wave_speed", 4.0))
	swim_wave_angle = float(visual_profile.get("swim_wave_angle", 2.5))
	bob_height = float(profile.get("bob", [3.5, 3.5])[0])
	swim_acceleration = float(profile.get("acceleration", 260.0))
	vertical_response = float(profile.get("vertical_response", 42.0))
	turn_roll_strength = float(visual_profile.get("turn_roll", 5.0))
	base_tail_strength = float(visual_profile.get("tail_strength", 24.0))
	base_tail_speed = float(visual_profile.get("tail_speed", 6.0))
	base_body_strength = float(visual_profile.get("body_strength", 4.0))
	_set_collision_size(FishCatalog.get_collision_size(fish_type))

	fish_sprite.scale = base_sprite_scale
	_apply_base_shader_params()
	_setup_articulated_rig()


func _setup_articulated_rig() -> void:
	fish_sprite.visible = true
	if is_instance_valid(articulated_rig):
		articulated_rig.queue_free()
	articulated_rig = null
	rig_tail = null
	rig_rear_body = null
	rig_core_body = null
	rig_head = null
	rig_moray_tail_tip = null
	rig_moray_mid_tail = null
	rig_moray_front_body = null
	rig_moray_mesh = null
	rig_ray_mesh = null
	rig_squid_mesh = null
	rig_sea_devil_mesh = null
	rig_shark_mesh = null
	rig_shark_gills.clear()
	rig_sea_glow_1 = null
	rig_sea_glow_2 = null
	rig_sea_glow_3 = null
	rig_gill = null
	rig_jaw = null
	rig_time = 0.0

	# Wave-1 animasyonlarını tek tek ekliyoruz.
	if fish_type not in ["Barakuda", "Müren", "Vatoz", "Deniz Şeytanı", "Kalamar", "Köpekbalığı"] or fish_sprite.texture == null:
		return

	rig_texture_size = fish_sprite.texture.get_size()
	if rig_texture_size.x <= 1.0 or rig_texture_size.y <= 1.0:
		return

	articulated_rig = Node2D.new()
	articulated_rig.name = fish_type + "ArticulatedRig"
	articulated_rig.z_index = fish_sprite.z_index
	add_child(articulated_rig)

	if fish_type == "Barakuda":
		# Barakuda: baş stabil, kuyrukta güçlü itiş.
		rig_tail = _create_rig_region("TailFin", 0.00, 0.28, 0.25, 1)
		rig_rear_body = _create_rig_region("RearBody", 0.20, 0.53, 0.49, 2)
		rig_core_body = _create_rig_region("CoreBody", 0.45, 0.79, 0.72, 3)
		rig_head = _create_rig_region("Head", 0.68, 1.00, 0.70, 4)
		_setup_barracuda_face_details()
	elif fish_type == "Müren":
		# Müren artık parçalı sprite kullanmıyor.
		# 48 kolonlu deformasyon mesh'i gövde + kuyruğu tek parça S şeklinde kıvırır.
		rig_moray_mesh = _create_moray_wave_mesh()
		_setup_moray_face_details()
	elif fish_type == "Vatoz":
		# Vatozda itişi kuyruk değil geniş pektoral yüzgeçler üretir.
		# İnce mesh, kanat kenarlarına doğru büyüyen ilerleyen dalga ile süzülme hissi verir.
		rig_ray_mesh = _create_ray_fin_mesh()
	elif fish_type == "Deniz Şeytanı":
		# Deniz Şeytanı ağır gövdeli dip avcısıdır:
		# kuyruk itişi belirgin, gövde ağır, küçük yüzgeçler titreşimli ve fenerler bağımsızdır.
		rig_sea_devil_mesh = _create_sea_devil_mesh()
		_setup_sea_devil_face_details()
		_setup_sea_devil_glows()
	elif fish_type == "Kalamar":
		# Kalamarın ana itişi kuyruk sallamak değil, mantoyu kasıp suyu jet olarak atmaktır.
		# Mesh manto kasılmasını, yüzgeç dalgasını ve gecikmeli tentakül akışını ayrı ayrı işler.
		rig_squid_mesh = _create_squid_independent_limbs_mesh()
	elif fish_type == "Köpekbalığı":
		# Köpekbalığı: kafa sakin kalır; gövdedeki dalga kuyruğa doğru büyür.
		# Tek parça deformasyon mesh'i sprite dilimlerinin oluşturduğu kırılmaları önler.
		rig_shark_mesh = _create_shark_wave_mesh()
		_setup_shark_face_details()

	fish_sprite.visible = false
	_update_rig_direction()


func _create_rig_region(
	segment_name: String,
	x0_ratio: float,
	x1_ratio: float,
	pivot_ratio: float,
	draw_order: int
) -> Node2D:
	var pivot := Node2D.new()
	pivot.name = segment_name + "Pivot"
	var pivot_x: float = rig_texture_size.x * pivot_ratio
	pivot.position = Vector2(pivot_x - rig_texture_size.x * 0.5, 0.0)
	pivot.z_index = draw_order
	articulated_rig.add_child(pivot)

	var part := Sprite2D.new()
	part.name = segment_name
	part.texture = fish_sprite.texture
	part.centered = false
	part.region_enabled = true
	var x0: float = floor(rig_texture_size.x * x0_ratio)
	var x1: float = ceil(rig_texture_size.x * x1_ratio)
	part.region_rect = Rect2(x0, 0.0, maxf(1.0, x1 - x0), rig_texture_size.y)
	part.position = Vector2(x0 - pivot_x, -rig_texture_size.y * 0.5)
	part.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	pivot.add_child(part)
	return pivot


func _setup_barracuda_face_details() -> void:
	# Solungaç: iki ince kavis. Nefes alırken aralık ve görünürlük hafifçe değişir.
	rig_gill = Line2D.new()
	rig_gill.name = "GillPulse"
	rig_gill.width = 1.45
	rig_gill.default_color = Color(0.12, 0.14, 0.15, 0.50)
	rig_gill.antialiased = true
	var gx: float = rig_texture_size.x * 0.735 - rig_texture_size.x * 0.5
	var gy: float = -rig_texture_size.y * 0.5
	rig_gill.points = PackedVector2Array([
		Vector2(gx, gy + rig_texture_size.y * 0.40),
		Vector2(gx - 1.5, gy + rig_texture_size.y * 0.51),
		Vector2(gx + 0.5, gy + rig_texture_size.y * 0.62)
	])
	rig_gill.z_index = 7
	articulated_rig.add_child(rig_gill)

	# Çene çizgisi çok az açılıp kapanır; resmin kendi ağız hattını bastırmaz.
	rig_jaw = Line2D.new()
	rig_jaw.name = "JawBreath"
	rig_jaw.width = 1.15
	rig_jaw.default_color = Color(0.07, 0.08, 0.09, 0.36)
	rig_jaw.antialiased = true
	var y0: float = -rig_texture_size.y * 0.5 + rig_texture_size.y * 0.59
	rig_jaw.points = PackedVector2Array([
		Vector2(rig_texture_size.x * 0.80 - rig_texture_size.x * 0.5, y0),
		Vector2(rig_texture_size.x * 0.91 - rig_texture_size.x * 0.5, y0 + 1.5),
		Vector2(rig_texture_size.x * 0.975 - rig_texture_size.x * 0.5, y0 + 0.5)
	])
	rig_jaw.z_index = 8
	articulated_rig.add_child(rig_jaw)


func _create_moray_wave_mesh() -> MeshInstance2D:
	var mesh_instance := MeshInstance2D.new()
	mesh_instance.name = "MorayContinuousWaveMesh"
	mesh_instance.z_index = 4
	articulated_rig.add_child(mesh_instance)

	var columns: int = 48
	var rows: int = 4
	var vertices := PackedVector2Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()

	for y_index in range(rows + 1):
		var v: float = float(y_index) / float(rows)
		var local_y: float = (v - 0.5) * rig_texture_size.y
		for x_index in range(columns + 1):
			var u: float = float(x_index) / float(columns)
			var local_x: float = (u - 0.5) * rig_texture_size.x
			vertices.append(Vector2(local_x, local_y))
			uvs.append(Vector2(u, v))

	for y_index in range(rows):
		for x_index in range(columns):
			var row_width: int = columns + 1
			var a: int = y_index * row_width + x_index
			var b: int = a + 1
			var c_index: int = a + row_width
			var d: int = c_index + 1
			indices.append(a)
			indices.append(c_index)
			indices.append(b)
			indices.append(b)
			indices.append(c_index)
			indices.append(d)

	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices

	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh_instance.mesh = mesh

	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;
render_mode unshaded;

uniform sampler2D fish_texture : source_color, filter_linear;
uniform float wave_phase = 0.0;
uniform float wave_amplitude = 11.0;
uniform float wave_frequency = 8.6;
uniform float secondary_amount = 1.0;

void vertex() {
	// Kaynak görselde baş sağ tarafta.
	// 0.72'den sonra deformasyon hızla söner; baş neredeyse tamamen sabit kalır.
	float head_lock = 1.0 - smoothstep(0.67, 0.87, UV.x);

	// Kuyrukta en yüksek, gövdenin ortasında orta kuvvette dalga.
	float tail_gain = pow(clamp(1.0 - UV.x, 0.0, 1.0), 0.58);
	float body_gain = mix(0.42, 1.0, tail_gain);
	float mask = head_lock * body_gain;

	// Yaklaşık 1.35 dalga: ekranda net bir S silüeti oluşturur.
	float main_wave = sin(wave_phase + UV.x * wave_frequency);
	float secondary_wave = sin(wave_phase * 0.54 + UV.x * 4.35 + 1.15);

	VERTEX.y += main_wave * wave_amplitude * mask;
	// Çok küçük yatay sıkışma/genişleme kıvrımı daha organik gösterir.
	VERTEX.x += secondary_wave * wave_amplitude * 0.10 * mask * secondary_amount;
}

void fragment() {
	vec4 tex = texture(fish_texture, UV);
	COLOR = tex * COLOR;
}
"""

	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("fish_texture", fish_sprite.texture)
	material.set_shader_parameter("wave_phase", 0.0)
	material.set_shader_parameter("wave_amplitude", 11.0)
	material.set_shader_parameter("wave_frequency", 8.6)
	material.set_shader_parameter("secondary_amount", 1.0)
	mesh_instance.material = material
	return mesh_instance



func _create_shark_wave_mesh() -> MeshInstance2D:
	var mesh_instance := MeshInstance2D.new()
	mesh_instance.name = "SharkContinuousSwimMesh"
	mesh_instance.z_index = 4
	articulated_rig.add_child(mesh_instance)

	var columns: int = 56
	var rows: int = 6
	var vertices := PackedVector2Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()

	for y_index in range(rows + 1):
		var v: float = float(y_index) / float(rows)
		var local_y: float = (v - 0.5) * rig_texture_size.y
		for x_index in range(columns + 1):
			var u: float = float(x_index) / float(columns)
			var local_x: float = (u - 0.5) * rig_texture_size.x
			vertices.append(Vector2(local_x, local_y))
			uvs.append(Vector2(u, v))

	for y_index in range(rows):
		for x_index in range(columns):
			var row_width: int = columns + 1
			var a: int = y_index * row_width + x_index
			var b: int = a + 1
			var c_index: int = a + row_width
			var d: int = c_index + 1
			indices.append(a)
			indices.append(c_index)
			indices.append(b)
			indices.append(b)
			indices.append(c_index)
			indices.append(d)

	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices

	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh_instance.mesh = mesh

	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;
render_mode unshaded;

uniform sampler2D fish_texture : source_color, filter_nearest;
uniform float swim_phase = 0.0;
uniform float tail_amplitude = 6.0;
uniform float body_amount = 1.0;

void vertex() {
	// Görsel sağa bakıyor: kuyruk UV.x=0, kafa UV.x=1.
	// Gerçek köpekbalığı yüzüşünde kafa neredeyse sabit, dalga kuyruğa doğru büyür.
	float tail_gain = pow(clamp(1.0 - UV.x, 0.0, 1.0), 1.28);
	float head_lock = 1.0 - smoothstep(0.70, 0.94, UV.x);
	float body_gain = mix(0.16, 1.0, tail_gain);
	float mask = head_lock * body_gain * body_amount;

	// Tek geniş dalga + çok küçük ikinci harmonik: güçlü ama lastik gibi olmayan itiş.
	float main_wave = sin(swim_phase + UV.x * 5.45);
	float harmonic = sin(swim_phase * 0.58 + UV.x * 3.10 + 1.20);

	VERTEX.y += main_wave * tail_amplitude * mask;
	VERTEX.x += harmonic * tail_amplitude * 0.032 * mask;
}

void fragment() {
	vec4 tex = texture(fish_texture, UV);
	COLOR = tex * COLOR;
}
"""

	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("fish_texture", fish_sprite.texture)
	material.set_shader_parameter("swim_phase", 0.0)
	material.set_shader_parameter("tail_amplitude", 6.0)
	material.set_shader_parameter("body_amount", 1.0)
	mesh_instance.material = material
	return mesh_instance


func _setup_shark_face_details() -> void:
	# Kaynak sprite 330x110. Solungaçlar başın hemen arkasında dört ayrı yarık olarak nefes alır.
	var gill_x: float = rig_texture_size.x * 0.735 - rig_texture_size.x * 0.5
	var gill_y: float = rig_texture_size.y * 0.515 - rig_texture_size.y * 0.5
	var spacing: float = maxf(2.2, rig_texture_size.x * 0.014)

	for index: int in range(4):
		var gill := Line2D.new()
		gill.name = "SharkGill%02d" % (index + 1)
		gill.width = maxf(1.0, rig_texture_size.y * 0.0105)
		gill.default_color = Color(0.035, 0.075, 0.13, 0.74)
		gill.antialiased = false
		gill.position = Vector2(gill_x + spacing * float(index), gill_y + float(index) * 0.35)
		var half_length: float = rig_texture_size.y * (0.080 - float(index) * 0.004)
		gill.points = PackedVector2Array([
			Vector2(-1.0, -half_length),
			Vector2(0.6, 0.0),
			Vector2(-0.5, half_length)
		])
		gill.z_index = 8
		articulated_rig.add_child(gill)
		rig_shark_gills.append(gill)

	# Kaynak görselde ağız zaten mevcut. Ekstra jaw overlay çizgisi,
	# balığın burnunun önüne taşan siyah artifact ürettiği için kullanılmıyor.
	rig_jaw = null


func _create_ray_fin_mesh() -> MeshInstance2D:
	var mesh_instance := MeshInstance2D.new()
	mesh_instance.name = "RayPectoralFinMesh"
	mesh_instance.z_index = 4
	articulated_rig.add_child(mesh_instance)

	# Daha sık dikey grid: geniş kanatların kenar kıvrımı daha yumuşak olsun.
	var columns: int = 48
	var rows: int = 12
	var vertices := PackedVector2Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()

	for y_index in range(rows + 1):
		var v: float = float(y_index) / float(rows)
		var local_y: float = (v - 0.5) * rig_texture_size.y
		for x_index in range(columns + 1):
			var u: float = float(x_index) / float(columns)
			var local_x: float = (u - 0.5) * rig_texture_size.x
			vertices.append(Vector2(local_x, local_y))
			uvs.append(Vector2(u, v))

	for y_index in range(rows):
		for x_index in range(columns):
			var row_width: int = columns + 1
			var a: int = y_index * row_width + x_index
			var b: int = a + 1
			var c_index: int = a + row_width
			var d: int = c_index + 1
			indices.append(a)
			indices.append(c_index)
			indices.append(b)
			indices.append(b)
			indices.append(c_index)
			indices.append(d)

	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices

	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh_instance.mesh = mesh

	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;
render_mode unshaded;

uniform sampler2D fish_texture : source_color, filter_linear;
uniform float flap_phase = 0.0;
uniform float flap_amplitude = 13.5;
uniform float tail_amplitude = 3.4;
uniform float glide_lift = 0.0;

void vertex() {
	// Kaynak çizimde baş sağda, kuyruk solda.
	float center_y = 0.535;
	float y_delta = UV.y - center_y;
	float edge_distance = abs(y_delta);

	// Gövde merkezi sabit kalsın; kanat ucuna yaklaştıkça kıvrım katlanarak büyüsün.
	float edge_mask = smoothstep(0.065, 0.33, edge_distance);
	float tip_mask = pow(edge_mask, 1.55);
	float body_core = 1.0 - smoothstep(0.03, 0.115, edge_distance);

	// Pektoral yüzgeç bölgesi: kuyruğu ve baş ucunu mümkün olduğunca dışarıda bırak.
	float rear_fade = smoothstep(0.17, 0.33, UV.x);
	float head_fade = 1.0 - smoothstep(0.77, 0.96, UV.x);
	float wing_mask = edge_mask * rear_fade * head_fade;

	// Ana kanat dalgası önden arkaya akar.
	float travel = (1.0 - UV.x) * 5.65;
	float wing_wave = sin(flap_phase + travel);

	// Kanat uçlarında ikinci, gecikmeli bir esneme vardır.
	// Bu küçük ikinci dalga videodaki daha canlı "çırpma" hissini verir.
	float tip_wave = sin(flap_phase * 0.86 + travel * 1.18 + 0.72);

	float side = y_delta >= 0.0 ? 1.0 : -1.0;
	VERTEX.y += side * wing_wave * flap_amplitude * wing_mask;
	VERTEX.y += side * tip_wave * flap_amplitude * 0.34 * tip_mask * rear_fade * head_fade;

	// Kanat vuruşunda kenarlar hafif ileri-geri esner.
	VERTEX.x += cos(flap_phase + travel + 0.85) * flap_amplitude * 0.095 * wing_mask;
	VERTEX.x += cos(flap_phase * 0.82 + travel * 1.12) * flap_amplitude * 0.035 * tip_mask;

	// Uzun kuyruk itiş üretmiyor; kanat hareketini gecikmeli takip ediyor.
	float tail_x = 1.0 - smoothstep(0.16, 0.52, UV.x);
	float tail_y = 1.0 - smoothstep(0.055, 0.18, abs(UV.y - 0.43));
	float tail_mask = tail_x * tail_y;
	float tail_wave = sin(flap_phase * 0.68 + UV.x * 8.2 + 1.55);
	VERTEX.y += tail_wave * tail_amplitude * tail_mask;

	// Merkez disk çok az yükselip alçalır; asıl hareket kanatlarda kalır.
	VERTEX.y += glide_lift * body_core * head_fade;
}

void fragment() {
	vec4 tex = texture(fish_texture, UV);
	COLOR = tex * COLOR;
}
"""

	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("fish_texture", fish_sprite.texture)
	material.set_shader_parameter("flap_phase", 0.0)
	material.set_shader_parameter("flap_amplitude", 13.5)
	material.set_shader_parameter("tail_amplitude", 3.4)
	material.set_shader_parameter("glide_lift", 0.0)
	mesh_instance.material = material
	return mesh_instance


func _create_squid_independent_limbs_mesh() -> MeshInstance2D:
	var mesh_instance := MeshInstance2D.new()
	mesh_instance.name = "SquidIndependentLimbsMesh"
	mesh_instance.z_index = 4
	articulated_rig.add_child(mesh_instance)

	# Çok sık grid: her kol/tentakülün kendi dalgası komşu kola daha az taşsın.
	var columns: int = 72
	var rows: int = 28
	var vertices := PackedVector2Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()

	for y_index in range(rows + 1):
		var v: float = float(y_index) / float(rows)
		var local_y: float = (v - 0.5) * rig_texture_size.y
		for x_index in range(columns + 1):
			var u: float = float(x_index) / float(columns)
			var local_x: float = (u - 0.5) * rig_texture_size.x
			vertices.append(Vector2(local_x, local_y))
			uvs.append(Vector2(u, v))

	for y_index in range(rows):
		for x_index in range(columns):
			var row_width: int = columns + 1
			var a: int = y_index * row_width + x_index
			var b: int = a + 1
			var c_index: int = a + row_width
			var d: int = c_index + 1
			indices.append(a)
			indices.append(c_index)
			indices.append(b)
			indices.append(b)
			indices.append(c_index)
			indices.append(d)

	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices

	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh_instance.mesh = mesh

	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;
render_mode unshaded;

uniform sampler2D fish_texture : source_color, filter_linear;
uniform float motion_phase = 0.0;
uniform float swim_strength = 1.0;
uniform float jet_power = 0.0;
uniform float mantle_breath = 0.0;
uniform float fin_strength = 1.0;

float band_mask(float y, float center, float width) {
	return 1.0 - smoothstep(width * 0.42, width, abs(y - center));
}

void vertex() {
	// Kaynak çizimde kafa yaklaşık UV.x 0.50 civarında, kollar sola uzanıyor.
	// Kollar için hareket kafa dibinde sıfıra yaklaşır, uçlara doğru büyür.
	float arm_zone = (1.0 - smoothstep(0.46, 0.535, UV.x)) * smoothstep(0.08, 0.15, UV.x);
	float tip_gain = pow(clamp((0.535 - UV.x) / 0.44, 0.0, 1.0), 0.72);
	float base_gain = arm_zone * (0.28 + 0.72 * tip_gain);

	// Her kol için çizimdeki doğal eğriyi yaklaşık takip eden ayrı merkez hattı.
	// 8 kısa kol + 2 uzun av tentakülü = 10 bağımsız hareket.
	float c1 = 0.205 + UV.x * 0.59;
	float c2 = 0.330 + UV.x * 0.34;
	float c3 = 0.455 + UV.x * 0.15;
	float c4 = 0.515 + UV.x * 0.09;
	float c5 = 0.565 + UV.x * 0.05;
	float c6 = 0.620 - UV.x * 0.02;
	float c7 = 0.705 - UV.x * 0.20;
	float c8 = 0.825 - UV.x * 0.43;
	float c9 = 0.760 - UV.x * 0.31;
	float c10 = 0.650 - UV.x * 0.13;

	float m1 = band_mask(UV.y, c1, 0.050) * base_gain;
	float m2 = band_mask(UV.y, c2, 0.047) * base_gain;
	float m3 = band_mask(UV.y, c3, 0.042) * base_gain;
	float m4 = band_mask(UV.y, c4, 0.040) * base_gain;
	float m5 = band_mask(UV.y, c5, 0.039) * base_gain;
	float m6 = band_mask(UV.y, c6, 0.041) * base_gain;
	float m7 = band_mask(UV.y, c7, 0.046) * base_gain;
	float m8 = band_mask(UV.y, c8, 0.052) * base_gain;
	float m9 = band_mask(UV.y, c9, 0.046) * base_gain;
	float m10 = band_mask(UV.y, c10, 0.040) * base_gain;

	// Müren kuyruğundaki mantık: dalga kolun KÖKÜNDEN UCUNA doğru akar.
	// Kök sabit kalır, orta kısım kıvrılır, uçta S hareketi en geniş haline gelir.
	float arm_t = clamp((0.535 - UV.x) / 0.455, 0.0, 1.0);
	float root_lock = smoothstep(0.06, 0.30, arm_t);
	float s_gain = pow(arm_t, 0.78) * root_lock;
	float jet_damp = mix(1.0, 0.62, jet_power);

	// Her bacak kendi içinde yaklaşık 1.2–1.5 S dalgası taşır.
	// Faz ve frekanslar birbirinden farklıdır; hiçbir bacak diğerini kopyalamaz.
	float w1 = sin(motion_phase * 1.02 + arm_t * 8.55 + 0.10) + sin(motion_phase * 0.57 + arm_t * 16.2 + 1.10) * 0.20;
	float w2 = sin(motion_phase * 1.09 + arm_t * 8.95 + 0.74) + sin(motion_phase * 0.61 + arm_t * 16.9 + 1.85) * 0.18;
	float w3 = sin(motion_phase * 0.97 + arm_t * 9.30 + 1.42) + sin(motion_phase * 0.55 + arm_t * 17.4 + 2.55) * 0.17;
	float w4 = sin(motion_phase * 1.13 + arm_t * 8.70 + 2.08) + sin(motion_phase * 0.63 + arm_t * 16.5 + 3.20) * 0.16;
	float w5 = sin(motion_phase * 0.93 + arm_t * 9.55 + 2.72) + sin(motion_phase * 0.53 + arm_t * 17.8 + 3.84) * 0.16;
	float w6 = sin(motion_phase * 1.07 + arm_t * 9.10 + 3.38) + sin(motion_phase * 0.59 + arm_t * 16.8 + 4.42) * 0.17;
	float w7 = sin(motion_phase * 1.00 + arm_t * 8.45 + 4.00) + sin(motion_phase * 0.56 + arm_t * 16.0 + 5.10) * 0.18;
	float w8 = sin(motion_phase * 1.11 + arm_t * 8.80 + 4.66) + sin(motion_phase * 0.62 + arm_t * 16.6 + 5.82) * 0.21;
	float w9 = sin(motion_phase * 0.95 + arm_t * 9.20 + 5.30) + sin(motion_phase * 0.54 + arm_t * 17.2 + 0.32) * 0.20;
	float w10 = sin(motion_phase * 1.05 + arm_t * 8.65 + 5.88) + sin(motion_phase * 0.58 + arm_t * 16.4 + 0.96) * 0.18;

	// Uzun dış tentaküller biraz daha geniş, iç kollar biraz daha kontrollü.
	float dy =
		w1 * m1 * 10.2 +
		w2 * m2 * 8.6 +
		w3 * m3 * 7.4 +
		w4 * m4 * 6.8 +
		w5 * m5 * 6.5 +
		w6 * m6 * 6.9 +
		w7 * m7 * 8.1 +
		w8 * m8 * 11.0 +
		w9 * m9 * 9.6 +
		w10 * m10 * 7.7;

	// S eğrisi sadece dikey sallanma olmasın diye her bacakta gecikmeli yatay kıvrım da var.
	float dx =
		cos(motion_phase * 0.91 + arm_t * 8.55 + 0.55) * m1 * 2.25 +
		cos(motion_phase * 1.03 + arm_t * 8.95 + 1.24) * m2 * 1.90 +
		cos(motion_phase * 0.88 + arm_t * 9.30 + 1.92) * m3 * 1.60 +
		cos(motion_phase * 1.08 + arm_t * 8.70 + 2.58) * m4 * 1.45 +
		cos(motion_phase * 0.90 + arm_t * 9.55 + 3.22) * m5 * 1.40 +
		cos(motion_phase * 1.00 + arm_t * 9.10 + 3.88) * m6 * 1.50 +
		cos(motion_phase * 0.93 + arm_t * 8.45 + 4.50) * m7 * 1.80 +
		cos(motion_phase * 1.06 + arm_t * 8.80 + 5.16) * m8 * 2.45 +
		cos(motion_phase * 0.89 + arm_t * 9.20 + 5.80) * m9 * 2.10 +
		cos(motion_phase * 0.98 + arm_t * 8.65 + 0.30) * m10 * 1.70;

	// Birden fazla maskenin kökte üst üste bindiği yerde hareket patlamasın.
	float mask_sum = m1+m2+m3+m4+m5+m6+m7+m8+m9+m10;
	float overlap_guard = max(1.0, mask_sum * 0.72);

	VERTEX.y += (dy / overlap_guard) * s_gain * swim_strength * jet_damp;
	VERTEX.x += (dx / overlap_guard) * s_gain * swim_strength * jet_damp;

	// Jet sırasında bütün kollar geriye doğru biraz daha düzleşir.
	// Uçlarda etki büyük, kafa dibinde küçüktür.
	VERTEX.x -= jet_power * tip_gain * arm_zone * 4.6;

	// Manto artık ana animasyon değil; yalnızca hafif solunum yapıyor.
	float mantle_x = smoothstep(0.50, 0.59, UV.x) * (1.0 - smoothstep(0.84, 0.90, UV.x));
	float mantle_y = 1.0 - smoothstep(0.10, 0.31, abs(UV.y - 0.50));
	float mantle_mask = mantle_x * mantle_y;
	float radial = sign(UV.y - 0.50);
	VERTEX.y += radial * sin(motion_phase * 0.46) * mantle_breath * 0.72 * mantle_mask;

	// Sağdaki iki büyük yüzgeç birbirinden BAĞIMSIZ fazlarda açılıp kapanıyor.
	float fin_x = smoothstep(0.69, 0.75, UV.x) * (1.0 - smoothstep(0.91, 0.96, UV.x));
	float upper_fin = fin_x * (1.0 - smoothstep(0.47, 0.515, UV.y)) * smoothstep(0.24, 0.34, UV.y);
	float lower_fin = fin_x * smoothstep(0.505, 0.56, UV.y) * (1.0 - smoothstep(0.74, 0.82, UV.y));

	float upper_wave = sin(motion_phase * 0.78 + UV.x * 7.2 + 0.35);
	float lower_wave = sin(motion_phase * 0.86 + UV.x * 6.6 + 2.05);
	VERTEX.y -= upper_wave * 3.4 * upper_fin * fin_strength;
	VERTEX.y += lower_wave * 3.7 * lower_fin * fin_strength;
	VERTEX.x += cos(motion_phase * 0.71 + UV.x * 5.8) * 0.8 * upper_fin * fin_strength;
	VERTEX.x += cos(motion_phase * 0.81 + UV.x * 6.1 + 1.4) * 0.9 * lower_fin * fin_strength;
}

void fragment() {
	vec4 tex = texture(fish_texture, UV);
	COLOR = tex * COLOR;
}
"""

	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("fish_texture", fish_sprite.texture)
	material.set_shader_parameter("motion_phase", 0.0)
	material.set_shader_parameter("swim_strength", 1.0)
	material.set_shader_parameter("jet_power", 0.0)
	material.set_shader_parameter("mantle_breath", 1.0)
	material.set_shader_parameter("fin_strength", 1.0)
	mesh_instance.material = material
	return mesh_instance


func _create_sea_devil_mesh() -> MeshInstance2D:
	var mesh_instance := MeshInstance2D.new()
	mesh_instance.name = "SeaDevilHeavyBodyMesh"
	mesh_instance.z_index = 4
	articulated_rig.add_child(mesh_instance)

	var columns: int = 52
	var rows: int = 14
	var vertices := PackedVector2Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()

	for y_index in range(rows + 1):
		var v: float = float(y_index) / float(rows)
		var local_y: float = (v - 0.5) * rig_texture_size.y
		for x_index in range(columns + 1):
			var u: float = float(x_index) / float(columns)
			var local_x: float = (u - 0.5) * rig_texture_size.x
			vertices.append(Vector2(local_x, local_y))
			uvs.append(Vector2(u, v))

	for y_index in range(rows):
		for x_index in range(columns):
			var row_width: int = columns + 1
			var a: int = y_index * row_width + x_index
			var b: int = a + 1
			var c_index: int = a + row_width
			var d: int = c_index + 1
			indices.append(a)
			indices.append(c_index)
			indices.append(b)
			indices.append(b)
			indices.append(c_index)
			indices.append(d)

	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices

	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh_instance.mesh = mesh

	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;
render_mode unshaded;

uniform sampler2D fish_texture : source_color, filter_linear;
uniform float swim_phase = 0.0;
uniform float tail_amplitude = 8.0;
uniform float fin_amplitude = 2.8;
uniform float jaw_amplitude = 1.4;
uniform float lure_amplitude = 4.0;

void vertex() {
	// Görselde baş sağ tarafta. Deniz Şeytanı gövdesi ağır ve rijittir.
	// Kuyruğa gidildikçe hareket katlanarak büyür, baş neredeyse kilitlidir.
	float tail_gain = 1.0 - smoothstep(0.18, 0.58, UV.x);
	float rear_body = (1.0 - smoothstep(0.36, 0.68, UV.x)) * smoothstep(0.10, 0.32, UV.x);
	float head_lock = 1.0 - smoothstep(0.64, 0.82, UV.x);

	float tail_wave = sin(swim_phase + UV.x * 5.9);
	float body_wave = sin(swim_phase * 0.72 + UV.x * 3.8 + 0.65);

	VERTEX.y += tail_wave * tail_amplitude * tail_gain;
	VERTEX.y += body_wave * tail_amplitude * 0.19 * rear_body * head_lock;

	// Pektoral / alt yüzgeçler küçük ve hızlı mikro-vuruşlar yapar.
	float lower_fin_y = smoothstep(0.58, 0.78, UV.y) * (1.0 - smoothstep(0.88, 0.98, UV.y));
	float fin_x = smoothstep(0.34, 0.48, UV.x) * (1.0 - smoothstep(0.68, 0.78, UV.x));
	float fin_mask = lower_fin_y * fin_x;
	float fin_wave = sin(swim_phase * 1.72 + UV.x * 10.0 + UV.y * 5.0);
	VERTEX.y += fin_wave * fin_amplitude * fin_mask;

	// Sırt yüzgeçleri de gövdeden bağımsız çok küçük titreşir.
	float dorsal_y = 1.0 - smoothstep(0.26, 0.43, UV.y);
	float dorsal_x = smoothstep(0.28, 0.42, UV.x) * (1.0 - smoothstep(0.72, 0.82, UV.x));
	VERTEX.x += sin(swim_phase * 1.28 + UV.x * 8.0) * fin_amplitude * 0.32 * dorsal_y * dorsal_x;

	// Alt çene nefesle açılır; kafa bütünü sallanmaz.
	float jaw_x = smoothstep(0.72, 0.84, UV.x);
	float jaw_y = smoothstep(0.57, 0.67, UV.y);
	float jaw_mask = jaw_x * jaw_y;
	VERTEX.y += (0.5 + 0.5 * sin(swim_phase * 0.58 + 0.9)) * jaw_amplitude * jaw_mask;

	// Fener saplarının bulunduğu üst-sağ bölge gövdeden bağımsız yumuşak salınır.
	// Transparan alanlar etkilenmediği için hareket esas olarak sap ve ışık uçlarında görünür.
	float lure_x = smoothstep(0.62, 0.74, UV.x);
	float lure_y = 1.0 - smoothstep(0.18, 0.43, UV.y);
	float lure_mask = lure_x * lure_y;
	float lure_wave = sin(swim_phase * 0.48 + UV.x * 7.5 + UV.y * 3.0);
	VERTEX.x += lure_wave * lure_amplitude * 0.55 * lure_mask;
	VERTEX.y += cos(swim_phase * 0.44 + UV.x * 6.0) * lure_amplitude * lure_mask;
}

void fragment() {
	vec4 tex = texture(fish_texture, UV);
	COLOR = tex * COLOR;
}
"""

	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("fish_texture", fish_sprite.texture)
	material.set_shader_parameter("swim_phase", 0.0)
	material.set_shader_parameter("tail_amplitude", 8.0)
	material.set_shader_parameter("fin_amplitude", 2.8)
	material.set_shader_parameter("jaw_amplitude", 1.4)
	material.set_shader_parameter("lure_amplitude", 4.0)
	mesh_instance.material = material
	return mesh_instance


func _setup_sea_devil_face_details() -> void:
	# Solungaç kapağı: ağır ve yavaş nefes.
	rig_gill = Line2D.new()
	rig_gill.name = "SeaDevilGillPulse"
	rig_gill.width = 1.55
	rig_gill.default_color = Color(0.13, 0.14, 0.11, 0.54)
	rig_gill.antialiased = true
	var gx: float = rig_texture_size.x * 0.705 - rig_texture_size.x * 0.5
	var gy: float = -rig_texture_size.y * 0.5
	rig_gill.points = PackedVector2Array([
		Vector2(gx, gy + rig_texture_size.y * 0.43),
		Vector2(gx - 3.0, gy + rig_texture_size.y * 0.54),
		Vector2(gx + 1.0, gy + rig_texture_size.y * 0.64)
	])
	rig_gill.z_index = 7
	articulated_rig.add_child(rig_gill)

	# Ağız çizgisi, normal nefeste küçük; saldırıda belirgin.
	rig_jaw = Line2D.new()
	rig_jaw.name = "SeaDevilJaw"
	rig_jaw.width = 1.35
	rig_jaw.default_color = Color(0.05, 0.055, 0.045, 0.46)
	rig_jaw.antialiased = true
	var y0: float = -rig_texture_size.y * 0.5 + rig_texture_size.y * 0.61
	rig_jaw.points = PackedVector2Array([
		Vector2(rig_texture_size.x * 0.77 - rig_texture_size.x * 0.5, y0),
		Vector2(rig_texture_size.x * 0.88 - rig_texture_size.x * 0.5, y0 + 2.0),
		Vector2(rig_texture_size.x * 0.985 - rig_texture_size.x * 0.5, y0 + 0.5)
	])
	rig_jaw.z_index = 8
	articulated_rig.add_child(rig_jaw)


func _create_soft_glow(glow_name: String, radius: float, glow_color: Color) -> Polygon2D:
	var glow := Polygon2D.new()
	glow.name = glow_name
	var points := PackedVector2Array()
	var sides: int = 16
	for i in range(sides):
		var angle: float = TAU * float(i) / float(sides)
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	glow.polygon = points
	glow.color = glow_color
	glow.z_index = 9
	articulated_rig.add_child(glow)
	return glow


func _setup_sea_devil_glows() -> void:
	# Orijinal PNG 620x349 oranında; pozisyonlar oranla hesaplandığı için çözünürlükten bağımsızdır.
	rig_sea_glow_1 = _create_soft_glow("SeaDevilGlowTop", 10.0, Color(0.68, 1.0, 0.76, 0.22))
	rig_sea_glow_2 = _create_soft_glow("SeaDevilGlowMid", 8.5, Color(0.68, 1.0, 0.76, 0.20))
	rig_sea_glow_3 = _create_soft_glow("SeaDevilGlowFront", 11.5, Color(0.70, 1.0, 0.78, 0.26))
	_update_sea_devil_glows(0.0)


func _update_sea_devil_glows(phase: float) -> void:
	if rig_sea_glow_1 == null or rig_sea_glow_2 == null or rig_sea_glow_3 == null:
		return

	var w: float = rig_texture_size.x
	var h: float = rig_texture_size.y
	var base_1 := Vector2(w * (0.694 - 0.5), h * (0.183 - 0.5))
	var base_2 := Vector2(w * (0.718 - 0.5), h * (0.270 - 0.5))
	var base_3 := Vector2(w * (0.887 - 0.5), h * (0.410 - 0.5))

	# Üç ışık aynı anda mekanik sallanmasın; her biri ayrı fazda gecikmeli hareket eder.
	rig_sea_glow_1.position = base_1 + Vector2(sin(phase * 0.46) * 2.7, cos(phase * 0.41) * 3.8)
	rig_sea_glow_2.position = base_2 + Vector2(sin(phase * 0.51 + 0.8) * 2.3, cos(phase * 0.44 + 0.6) * 3.0)
	rig_sea_glow_3.position = base_3 + Vector2(sin(phase * 0.43 + 1.6) * 3.2, cos(phase * 0.39 + 1.2) * 4.4)

	var p1: float = 0.78 + 0.22 * sin(phase * 1.15)
	var p2: float = 0.78 + 0.22 * sin(phase * 1.07 + 1.7)
	var p3: float = 0.82 + 0.18 * sin(phase * 1.22 + 0.9)
	rig_sea_glow_1.scale = Vector2.ONE * p1
	rig_sea_glow_2.scale = Vector2.ONE * p2
	rig_sea_glow_3.scale = Vector2.ONE * p3
	rig_sea_glow_1.color.a = 0.16 + p1 * 0.11
	rig_sea_glow_2.color.a = 0.14 + p2 * 0.10
	rig_sea_glow_3.color.a = 0.18 + p3 * 0.12


func _setup_moray_face_details() -> void:
	# Mürenin solungaç deliği küçük ama ritmik görünür.
	rig_gill = Line2D.new()
	rig_gill.name = "MorayGillPulse"
	rig_gill.width = 1.55
	rig_gill.default_color = Color(0.10, 0.12, 0.08, 0.62)
	rig_gill.antialiased = true
	var gx: float = rig_texture_size.x * 0.785 - rig_texture_size.x * 0.5
	var gy: float = -rig_texture_size.y * 0.5
	rig_gill.points = PackedVector2Array([
		Vector2(gx, gy + rig_texture_size.y * 0.44),
		Vector2(gx - 2.0, gy + rig_texture_size.y * 0.52),
		Vector2(gx + 1.0, gy + rig_texture_size.y * 0.59)
	])
	rig_gill.z_index = 7
	articulated_rig.add_child(rig_gill)

	# Müren ağzı doğal olarak sürekli hafif açıktır.
	# Pusuda yavaş nefesle, saldırıda daha belirgin açılır.
	rig_jaw = Line2D.new()
	rig_jaw.name = "MorayJawBreath"
	rig_jaw.width = 1.25
	rig_jaw.default_color = Color(0.055, 0.065, 0.045, 0.48)
	rig_jaw.antialiased = true
	var y0: float = -rig_texture_size.y * 0.5 + rig_texture_size.y * 0.56
	rig_jaw.points = PackedVector2Array([
		Vector2(rig_texture_size.x * 0.80 - rig_texture_size.x * 0.5, y0),
		Vector2(rig_texture_size.x * 0.90 - rig_texture_size.x * 0.5, y0 + 2.0),
		Vector2(rig_texture_size.x * 0.985 - rig_texture_size.x * 0.5, y0 + 0.8)
	])
	rig_jaw.z_index = 8
	articulated_rig.add_child(rig_jaw)


func _update_articulated_rig(delta: float, speed_ratio: float) -> void:
	if articulated_rig == null:
		return

	match fish_type:
		"Barakuda":
			_update_barracuda_rig(delta, speed_ratio)
		"Müren":
			_update_moray_rig(delta, speed_ratio)
		"Vatoz":
			_update_ray_rig(delta, speed_ratio)
		"Deniz Şeytanı":
			_update_sea_devil_rig(delta, speed_ratio)
		"Kalamar":
			_update_squid_rig(delta, speed_ratio)
		"Köpekbalığı":
			_update_shark_rig(delta, speed_ratio)



func _update_shark_rig(delta: float, speed_ratio: float) -> void:
	if rig_shark_mesh == null:
		return

	var speed_factor: float = clampf(speed_ratio, 0.35, 2.6)
	var motion_rate: float = lerpf(0.78, 1.62, clampf((speed_factor - 0.35) / 2.25, 0.0, 1.0))
	if was_dashing:
		motion_rate *= 1.30
	rig_time += delta * motion_rate

	var phase: float = rig_time * 2.65 + swim_phase
	var shark_material: ShaderMaterial = rig_shark_mesh.material as ShaderMaterial
	if shark_material != null:
		var amplitude: float = lerpf(4.2, 8.8, clampf(speed_factor / 2.25, 0.0, 1.0))
		if was_dashing:
			amplitude *= 1.26
		shark_material.set_shader_parameter("swim_phase", phase)
		shark_material.set_shader_parameter("tail_amplitude", amplitude)
		shark_material.set_shader_parameter("body_amount", lerpf(0.88, 1.08, clampf(speed_factor / 2.4, 0.0, 1.0)))

	# Kafa sabitliği için tüm gövde hareketi çok küçük tutulur; güç kuyruğun deformasyonundan gelir.
	articulated_rig.position.y = sin(rig_time * 0.72 + swim_phase) * 0.38
	articulated_rig.rotation += sin(rig_time * 0.60 + swim_phase + 0.35) * deg_to_rad(0.10)

	# Solungaçlar tek anda mekanik açılmasın; arkaya doğru çok küçük faz farkı kullan.
	var breath_phase: float = rig_time * 1.45 + swim_phase
	for index: int in range(rig_shark_gills.size()):
		var gill: Line2D = rig_shark_gills[index]
		if gill == null:
			continue
		var breath: float = (sin(breath_phase - float(index) * 0.16) + 1.0) * 0.5
		gill.scale = Vector2(
			lerpf(0.97, 1.035, breath),
			lerpf(0.91, 1.10, breath)
		)
		gill.default_color.a = lerpf(0.46, 0.82, breath)

	_update_rig_direction()


func _update_barracuda_rig(delta: float, speed_ratio: float) -> void:
	var speed_factor: float = clampf(speed_ratio, 0.55, 2.6)
	var cruise_factor: float = lerpf(0.82, 1.72, (speed_factor - 0.55) / 2.05)
	rig_time += delta * cruise_factor

	# Barakuda karakteri: kafa stabil, gövdede küçük S dalgası, kuyrukta güçlü itiş.
	var main_wave: float = sin(rig_time * 5.0 + swim_phase)
	var rear_wave: float = sin(rig_time * 5.0 + swim_phase + 0.72)
	var tail_wave: float = sin(rig_time * 5.0 + swim_phase + 1.28)
	var breath: float = (sin(rig_time * 1.72 + swim_phase) + 1.0) * 0.5

	var tail_amp: float = deg_to_rad(7.5 + minf(speed_factor, 2.2) * 4.2)
	if was_dashing:
		tail_amp *= 1.28

	if rig_tail != null:
		rig_tail.rotation = tail_wave * tail_amp
	if rig_rear_body != null:
		rig_rear_body.rotation = rear_wave * tail_amp * 0.40
	if rig_core_body != null:
		rig_core_body.rotation = main_wave * tail_amp * 0.13
	if rig_head != null:
		rig_head.rotation = -main_wave * deg_to_rad(0.65) + sin(rig_time * 0.92) * deg_to_rad(0.20)

	if rig_gill != null:
		rig_gill.scale.x = lerpf(0.92, 1.10, breath)
		rig_gill.scale.y = lerpf(0.96, 1.06, breath)
		rig_gill.default_color.a = lerpf(0.28, 0.62, breath)

	if rig_jaw != null:
		var jaw_points: PackedVector2Array = rig_jaw.points
		if jaw_points.size() == 3:
			var jaw_open: float = lerpf(0.0, 1.65, breath)
			jaw_points[1].y = -rig_texture_size.y * 0.5 + rig_texture_size.y * 0.59 + 1.5 + jaw_open
			jaw_points[2].y = -rig_texture_size.y * 0.5 + rig_texture_size.y * 0.59 + 0.5 + jaw_open * 0.55
			rig_jaw.points = jaw_points

	_update_rig_direction()


func _update_moray_rig(delta: float, speed_ratio: float) -> void:
	if rig_moray_mesh == null:
		return

	var speed_factor: float = clampf(speed_ratio, 0.35, 3.0)
	var motion_rate: float = lerpf(0.72, 1.90, (speed_factor - 0.35) / 2.65)
	if was_dashing:
		motion_rate *= 1.36
	rig_time += delta * motion_rate

	# Videodaki mantık: baş sabit, gövde ve kuyruk tek parça dansöz gibi S çizer.
	var moray_material: ShaderMaterial = rig_moray_mesh.material as ShaderMaterial
	if moray_material != null:
		var amplitude: float = lerpf(10.5, 15.5, clampf(speed_factor / 2.5, 0.0, 1.0))
		if was_dashing:
			amplitude *= 1.24
		moray_material.set_shader_parameter("wave_phase", rig_time * 3.20 + swim_phase)
		moray_material.set_shader_parameter("wave_amplitude", amplitude)
		moray_material.set_shader_parameter("wave_frequency", 8.6)
		moray_material.set_shader_parameter("secondary_amount", 1.0)

	var breath: float = (sin(rig_time * 1.22 + swim_phase) + 1.0) * 0.5

	# Başın kendisi kıvrılmaz; yalnızca tüm balığın doğal yüzüş pitch'i uygulanır.
	articulated_rig.position.y = sin(rig_time * 1.05 + swim_phase) * 0.35

	if rig_gill != null:
		rig_gill.scale.x = lerpf(0.86, 1.20, breath)
		rig_gill.scale.y = lerpf(0.92, 1.12, breath)
		rig_gill.default_color.a = lerpf(0.34, 0.82, breath)

	if rig_jaw != null:
		var jaw_points: PackedVector2Array = rig_jaw.points
		if jaw_points.size() == 3:
			var base_open: float = lerpf(1.0, 3.0, breath)
			var attack_open: float = 4.2 if was_dashing else 0.0
			var jaw_open: float = base_open + attack_open
			var jaw_y: float = -rig_texture_size.y * 0.5 + rig_texture_size.y * 0.56
			jaw_points[1].y = jaw_y + 2.0 + jaw_open
			jaw_points[2].y = jaw_y + 0.8 + jaw_open * 0.64
			rig_jaw.points = jaw_points
		rig_jaw.default_color.a = 0.66 if was_dashing else lerpf(0.36, 0.58, breath)

	_update_rig_direction()


func _update_ray_rig(delta: float, speed_ratio: float) -> void:
	if rig_ray_mesh == null:
		return

	var speed_factor: float = clampf(speed_ratio, 0.35, 2.2)
	# Kanat vuruşu biraz daha geniş; hızlanınca frekans artar ama telaşlı görünmez.
	var flap_rate: float = lerpf(1.42, 2.45, clampf((speed_factor - 0.35) / 1.85, 0.0, 1.0))
	rig_time += delta

	var ray_material: ShaderMaterial = rig_ray_mesh.material as ShaderMaterial
	if ray_material != null:
		var phase: float = rig_time * flap_rate + swim_phase
		var amplitude: float = lerpf(11.5, 16.8, clampf(speed_factor / 2.0, 0.0, 1.0))
		var tail_amount: float = lerpf(2.6, 4.4, clampf(speed_factor / 2.0, 0.0, 1.0))
		var lift: float = sin(phase * 0.50 + 0.6) * 0.90

		ray_material.set_shader_parameter("flap_phase", phase)
		ray_material.set_shader_parameter("flap_amplitude", amplitude)
		ray_material.set_shader_parameter("tail_amplitude", tail_amount)
		ray_material.set_shader_parameter("glide_lift", lift)

	# Disk gövdesi kanat vuruşuna karşı çok hafif dengeler; baş sabit kalır.
	articulated_rig.rotation += sin(rig_time * flap_rate + swim_phase + 1.1) * deg_to_rad(0.16)
	articulated_rig.position.y = sin(rig_time * 0.72 + swim_phase) * 0.55

	_update_rig_direction()


func _update_sea_devil_rig(delta: float, speed_ratio: float) -> void:
	if rig_sea_devil_mesh == null:
		return

	var speed_factor: float = clampf(speed_ratio, 0.25, 2.5)
	# Ağır avcı: yavaş temel ritim, saldırıda bir anda kuvvetli kuyruk.
	var motion_rate: float = lerpf(0.72, 1.42, clampf((speed_factor - 0.25) / 2.25, 0.0, 1.0))
	if was_dashing:
		motion_rate *= 1.48
	rig_time += delta

	var phase: float = rig_time * motion_rate * 2.15 + swim_phase
	var sea_material: ShaderMaterial = rig_sea_devil_mesh.material as ShaderMaterial
	if sea_material != null:
		var tail_amount: float = lerpf(5.5, 9.5, clampf(speed_factor / 2.2, 0.0, 1.0))
		var fin_amount: float = lerpf(2.0, 3.4, clampf(speed_factor / 2.0, 0.0, 1.0))
		var jaw_amount: float = 1.55
		var lure_amount: float = 4.0
		if was_dashing:
			tail_amount *= 1.55
			fin_amount *= 1.28
			jaw_amount = 4.2
			lure_amount = 5.6

		sea_material.set_shader_parameter("swim_phase", phase)
		sea_material.set_shader_parameter("tail_amplitude", tail_amount)
		sea_material.set_shader_parameter("fin_amplitude", fin_amount)
		sea_material.set_shader_parameter("jaw_amplitude", jaw_amount)
		sea_material.set_shader_parameter("lure_amplitude", lure_amount)

	# Gövde ağır olduğu için tüm balıkta çok küçük ataletsel salınım.
	articulated_rig.position.y = sin(rig_time * 0.58 + swim_phase) * 0.70
	articulated_rig.rotation += sin(rig_time * 0.66 + swim_phase + 0.4) * deg_to_rad(0.13)

	var breath: float = (sin(rig_time * 0.82 + swim_phase) + 1.0) * 0.5
	if rig_gill != null:
		rig_gill.scale.x = lerpf(0.91, 1.11, breath)
		rig_gill.scale.y = lerpf(0.95, 1.08, breath)
		rig_gill.default_color.a = lerpf(0.34, 0.66, breath)

	if rig_jaw != null:
		var jaw_points: PackedVector2Array = rig_jaw.points
		if jaw_points.size() == 3:
			var jaw_y: float = -rig_texture_size.y * 0.5 + rig_texture_size.y * 0.61
			var jaw_open: float = lerpf(0.6, 2.0, breath) + (4.8 if was_dashing else 0.0)
			jaw_points[1].y = jaw_y + 2.0 + jaw_open
			jaw_points[2].y = jaw_y + 0.5 + jaw_open * 0.58
			rig_jaw.points = jaw_points
		rig_jaw.default_color.a = 0.68 if was_dashing else lerpf(0.38, 0.54, breath)

	_update_sea_devil_glows(phase)
	_update_rig_direction()


func _update_squid_rig(delta: float, speed_ratio: float) -> void:
	if rig_squid_mesh == null:
		return

	var speed_factor: float = clampf(speed_ratio, 0.30, 3.0)
	rig_time += delta

	# Kollar yüzüş hızlandıkça biraz hızlanır; birbirlerinin fazını asla paylaşmaz.
	var motion_rate: float = lerpf(1.18, 1.95, clampf(speed_factor / 2.5, 0.0, 1.0))
	var phase: float = rig_time * motion_rate + swim_phase

	# Jet davranışı yalnızca kolları akış yönünde toplar.
	# Eski sürümdeki abartılı manto kasılması tamamen kaldırıldı.
	var jet_power: float = 1.0 if was_dashing else 0.0

	var squid_material: ShaderMaterial = rig_squid_mesh.material as ShaderMaterial
	if squid_material != null:
		var limb_strength: float = lerpf(0.98, 1.34, clampf(speed_factor / 2.5, 0.0, 1.0))
		var fin_strength: float = lerpf(0.82, 1.18, clampf(speed_factor / 2.2, 0.0, 1.0))
		if was_dashing:
			limb_strength *= 0.88
			fin_strength *= 0.76

		squid_material.set_shader_parameter("motion_phase", phase)
		squid_material.set_shader_parameter("swim_strength", limb_strength)
		squid_material.set_shader_parameter("jet_power", jet_power)
		squid_material.set_shader_parameter("mantle_breath", 1.0)
		squid_material.set_shader_parameter("fin_strength", fin_strength)

	# Gövde çok sakin; karakteri artık bacaklar ve iki bağımsız yüzgeç veriyor.
	articulated_rig.position.y = sin(rig_time * 0.72 + swim_phase) * 0.32
	articulated_rig.rotation += sin(rig_time * 0.58 + swim_phase + 0.45) * deg_to_rad(0.11)

	_update_rig_direction()


func _update_rig_direction() -> void:
	if articulated_rig == null:
		return
	var x_scale: float = absf(base_sprite_scale.x)
	articulated_rig.scale = Vector2(x_scale if direction > 0.0 else -x_scale, base_sprite_scale.y)


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
	_update_rig_direction()
	if fish_type == "Fener Balığı":
		_update_angler_glow(1.0)


func play_turn_animation() -> void:
	turn_roll = -direction * deg_to_rad(turn_roll_strength)
	if articulated_rig != null:
		return
	var tween: Tween = create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(fish_sprite, "scale:y", base_sprite_scale.y * 0.84, 0.09)
	tween.tween_property(fish_sprite, "scale:y", base_sprite_scale.y, 0.15)


func play_hooked_animation() -> void:
	var profile: Dictionary = FishCatalog.get_profile(fish_type)
	var struggle_angle: float = float(profile.get("hook_struggle_angle", 18.0))

	if articulated_rig != null:
		var rig_tween: Tween = create_tween()
		rig_tween.set_trans(Tween.TRANS_SINE)
		rig_tween.set_ease(Tween.EASE_IN_OUT)
		rig_tween.tween_property(articulated_rig, "rotation", deg_to_rad(struggle_angle * 0.55), 0.07)
		rig_tween.tween_property(articulated_rig, "rotation", deg_to_rad(-struggle_angle * 0.55), 0.07)
		rig_tween.tween_property(articulated_rig, "rotation", deg_to_rad(struggle_angle * 0.35), 0.07)
		rig_tween.tween_property(articulated_rig, "rotation", 0.0, 0.11)

		var rig_flash: Tween = create_tween()
		rig_flash.tween_property(articulated_rig, "modulate", Color(1.35, 1.35, 1.10, 1.0), 0.08)
		rig_flash.tween_property(articulated_rig, "modulate", Color.WHITE, 0.18)
		return

	var tween: Tween = create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)
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
	if articulated_rig != null:
		articulated_rig.rotation = 0.0
		articulated_rig.position = Vector2.ZERO
		articulated_rig.modulate = Color.WHITE
		for rig_node: Node2D in [
			rig_moray_tail_tip,
			rig_tail,
			rig_moray_mid_tail,
			rig_rear_body,
			rig_core_body,
			rig_moray_front_body,
			rig_head
		]:
			if rig_node != null:
				rig_node.rotation = 0.0
				rig_node.position.y = 0.0
		if rig_moray_mesh != null:
			var reset_material: ShaderMaterial = rig_moray_mesh.material as ShaderMaterial
			if reset_material != null:
				reset_material.set_shader_parameter("wave_phase", 0.0)
		if rig_ray_mesh != null:
			var ray_reset_material: ShaderMaterial = rig_ray_mesh.material as ShaderMaterial
			if ray_reset_material != null:
				ray_reset_material.set_shader_parameter("flap_phase", 0.0)
				ray_reset_material.set_shader_parameter("glide_lift", 0.0)
		if rig_sea_devil_mesh != null:
			var sea_reset_material: ShaderMaterial = rig_sea_devil_mesh.material as ShaderMaterial
			if sea_reset_material != null:
				sea_reset_material.set_shader_parameter("swim_phase", 0.0)
		if rig_squid_mesh != null:
			var squid_reset_material: ShaderMaterial = rig_squid_mesh.material as ShaderMaterial
			if squid_reset_material != null:
				squid_reset_material.set_shader_parameter("motion_phase", 0.0)
				squid_reset_material.set_shader_parameter("jet_power", 0.0)
				squid_reset_material.set_shader_parameter("swim_strength", 1.0)
				squid_reset_material.set_shader_parameter("fin_strength", 1.0)
		_update_rig_direction()
