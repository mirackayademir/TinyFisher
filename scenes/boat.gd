extends CharacterBody2D

@export var speed: float = 220.0
@export var speed_per_level: float = 35.0
@export var min_world_x: float = 470.0
@export var harbor_dock_approach: float = 270.0

@export var rod_rest_rotation: float = 0.0
@export var rod_reel_rotation: float = -0.16
@export var rod_cast_back_rotation: float = 0.22
@export var rod_cast_forward_rotation: float = -0.32

@export var harbor_camera_threshold: float = 1300.0
@export var harbor_camera_x: float = -100.0
@export var sea_camera_x: float = 350.0
@export var harbor_zoom: float = 0.78
@export var sea_zoom: float = 1.0

var can_move: bool = true
var _cast_animating: bool = false
var _rod_tween: Tween
var _sea_time: float = 0.0
var _boat_visual_base_position: Vector2
var _rod_base_position: Vector2

@onready var hook = $Hook
@onready var rod_pivot: Node2D = $RodPivot
@onready var rod_tip: Marker2D = $RodPivot/RodTip
@onready var boat_visual: Sprite2D = $BoatVisual
@onready var wake_particles: CPUParticles2D = $WakeParticles
@onready var wake_trail: CPUParticles2D = $WakeTrail
@onready var camera: Camera2D = $Camera2D


func _ready() -> void:
	# Tekneyi su çizgisine biraz daha oturt.
	boat_visual.position.y += 11.0
	rod_pivot.position.y += 11.0
	_boat_visual_base_position = boat_visual.position
	_rod_base_position = rod_pivot.position

	# Köpük tekneyle birlikte hareket eder ve çok kısa iz bırakır.
	wake_particles.local_coords = true
	wake_trail.local_coords = true
	wake_particles.lifetime = 0.24
	wake_trail.lifetime = 0.38
	wake_particles.amount = 18
	wake_trail.amount = 12
	wake_particles.initial_velocity_min = 12.0
	wake_particles.initial_velocity_max = 28.0
	wake_trail.initial_velocity_min = 5.0
	wake_trail.initial_velocity_max = 14.0
	wake_particles.gravity = Vector2(0.0, 6.0)
	wake_trail.gravity = Vector2(0.0, 2.0)
	wake_particles.emitting = false
	wake_trail.emitting = false


func _physics_process(delta: float) -> void:
	if not can_move:
		velocity = Vector2.ZERO
	else:
		var direction := Input.get_axis("move_left", "move_right")
		velocity.x = direction * speed
		velocity.y = 0.0
		move_and_slide()

	# World liman ölçeğine dokunmadan, teknenin görünmez duvarını iskeleye kadar yaklaştır.
	# world.gd min_world_x değerini yanaşma bölgesi için korur; burada görsel tekne ofsetini telafi ediyoruz.
	var effective_min_world_x := min_world_x - harbor_dock_approach
	if global_position.x < effective_min_world_x:
		global_position.x = effective_min_world_x
		if velocity.x < 0.0:
			velocity.x = 0.0

	_update_surface_motion(delta)
	_update_camera_framing(delta)
	_update_wake()
	_update_rod_pose(delta)


func _update_surface_motion(delta: float) -> void:
	_sea_time += delta

	# World su çizgisiyle aynı iki dalga formu: tekne gerçekten dalganın üstünde yüzer.
	var wave_a := sin(global_position.x * 0.018 + _sea_time * 1.72) * 5.2
	var wave_b := sin(global_position.x * 0.043 - _sea_time * 1.08 + 0.8) * 2.2
	var bob := wave_a + wave_b
	var tilt := cos(global_position.x * 0.018 + _sea_time * 1.72) * 0.014
	var speed_tilt := clampf(velocity.x / maxf(speed, 1.0), -1.0, 1.0) * 0.006

	boat_visual.position = _boat_visual_base_position + Vector2(0.0, bob)
	boat_visual.rotation = tilt + speed_tilt
	rod_pivot.position.y = _rod_base_position.y + bob * 0.88


func _update_camera_framing(delta: float) -> void:
	# Limana yaklaşınca kamera sola kayar ve uzaklaşır; büyük limanın neredeyse tamamı görünür.
	# Denize açılınca tekrar normal oyun kadrajına döner.
	var near_harbor := global_position.x <= harbor_camera_threshold
	var target_x := harbor_camera_x if near_harbor else sea_camera_x
	var target_zoom_value := harbor_zoom if near_harbor else sea_zoom
	var blend := clampf(delta * 3.2, 0.0, 1.0)

	camera.position.x = lerpf(camera.position.x, target_x, blend)
	camera.zoom = camera.zoom.lerp(Vector2(target_zoom_value, target_zoom_value), blend)


func _update_wake() -> void:
	var moving := can_move and absf(velocity.x) > 20.0
	wake_particles.emitting = moving
	wake_trail.emitting = moving

	if not moving:
		return

	var movement_sign := signf(velocity.x)
	var speed_ratio := clampf(absf(velocity.x) / maxf(speed, 1.0), 0.30, 1.0)
	var foam_y := 49.0 + sin(_sea_time * 3.0) * 1.2

	wake_particles.direction = Vector2(-movement_sign, 0.02)
	wake_trail.direction = Vector2(-movement_sign, 0.015)
	wake_particles.speed_scale = lerpf(0.72, 0.98, speed_ratio)
	wake_trail.speed_scale = lerpf(0.68, 0.90, speed_ratio)

	# Görseldeki motor/kıç hizasına yaklaştırıldı; köpük artık teknenin çok gerisinde doğmaz.
	if movement_sign > 0.0:
		wake_particles.position = Vector2(305.0, foam_y)
		wake_trail.position = Vector2(322.0, foam_y + 2.0)
	else:
		wake_particles.position = Vector2(675.0, foam_y)
		wake_trail.position = Vector2(658.0, foam_y + 2.0)


func _update_rod_pose(delta: float) -> void:
	if _cast_animating:
		return

	var target_rotation := rod_rest_rotation
	if hook.deployed and hook.is_reeling():
		target_rotation = rod_reel_rotation

	rod_pivot.rotation = lerp_angle(
		rod_pivot.rotation,
		target_rotation,
		clampf(delta * 9.0, 0.0, 1.0)
	)


func play_cast_animation() -> void:
	if is_instance_valid(_rod_tween):
		_rod_tween.kill()

	_cast_animating = true
	_rod_tween = create_tween()
	_rod_tween.set_trans(Tween.TRANS_SINE)
	_rod_tween.set_ease(Tween.EASE_OUT)
	_rod_tween.tween_property(rod_pivot, "rotation", rod_cast_back_rotation, 0.11)
	_rod_tween.tween_property(rod_pivot, "rotation", rod_cast_forward_rotation, 0.16)
	_rod_tween.tween_property(rod_pivot, "rotation", rod_rest_rotation, 0.20)
	_rod_tween.finished.connect(_on_cast_animation_finished)


func _on_cast_animation_finished() -> void:
	_cast_animating = false


func get_line_origin_local() -> Vector2:
	return to_local(rod_tip.global_position)


func set_speed_level(level: int) -> void:
	speed = 220.0 + (float(level) * speed_per_level)


func set_movement_enabled(enabled: bool) -> void:
	can_move = enabled

	if not enabled:
		velocity = Vector2.ZERO
		wake_particles.emitting = false
		wake_trail.emitting = false


func _on_hook_area_entered(area: Area2D) -> void:
	pass
