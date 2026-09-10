extends Node

# Environment runtime destegi.
# 7/36 surface_foam_01.png: hareketli ana dalgaya baglanir.
# 8/36 sun_rays_01.png: tek, duzenli bir gunes huzmesi kumesi olarak kullanilir.
# 9/36 shallow_rock_01.png: SIMDİLIK ATLANDI / gorunmez.
# 10/36 shallow_fish_school_01_TEMP.png: 0-20m bandinda aralikli arka-plan balik suruleri.
# 11/36 shallow_kelp_01.png: liman/kayi altinda, kokleri acik suda gorunmeyecek sekilde.

const FOAM_TEXTURE: Texture2D = preload("res://assets/environment/surface/surface_foam_01.png")
const SUN_RAYS_TEXTURE: Texture2D = preload("res://assets/environment/surface/sun_rays_01.png")
const SHALLOW_FISH_SCHOOL_TEXTURE: Texture2D = preload("res://assets/environment/shallow/shallow_fish_school_01_TEMP.png")
const SHALLOW_KELP_TEXTURE: Texture2D = preload("res://assets/environment/shallow/shallow_kelp_01.png")

const WATER_SURFACE_Y: float = 360.0
const SUN_X: float = 1060.0
const SUN_TARGET_SIZE: float = 175.0
const SUN_RAYS_WIDTH: float = 1450.0
const SUN_RAYS_DEPTH_HEIGHT: float = 540.0

const FISH_SCHOOL_TARGET_WIDTH: float = 220.0
const KELP_TARGET_HEIGHT: float = 190.0

var _bound_line: Line2D = null
var _ray_root: Node2D = null
var _sun_light_parallax: Parallax2D = null
var _fish_school_root: Node2D = null
var _kelp_root: Node2D = null
var _anim_time: float = 0.0
var _scene_id: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	print("ENV RUNTIME: 7/36 kopuk + 8/36 huzme + 9/36 kaya atlandi + 10/36 balik suruleri + 11/36 liman kelbi")


func _process(delta: float) -> void:
	var current_scene: Node = get_tree().current_scene
	if current_scene == null:
		_reset_scene_refs()
		return

	var current_id: int = current_scene.get_instance_id()
	if current_id != _scene_id:
		_scene_id = current_id
		_bound_line = null
		_ray_root = null
		_sun_light_parallax = null
		_fish_school_root = null
		_kelp_root = null
		_anim_time = 0.0

	_sync_surface_foam(current_scene)
	_ensure_sun_light_group(current_scene)
	_ensure_sun_rays(current_scene)
	_remove_skipped_rocks(current_scene)
	_ensure_shallow_fish_schools(current_scene)
	_ensure_shallow_kelp(current_scene)
	_animate_shallow_environment(delta)


func _reset_scene_refs() -> void:
	_bound_line = null
	_ray_root = null
	_sun_light_parallax = null
	_fish_school_root = null
	_kelp_root = null
	_anim_time = 0.0
	_scene_id = 0


# -----------------------------------------------------------------------------
# 7 / 36 - SURFACE FOAM
# -----------------------------------------------------------------------------

func _sync_surface_foam(current_scene: Node) -> void:
	var static_foam: CanvasItem = current_scene.get_node_or_null(
		"EnvironmentLayers/SurfaceLayers/SurfaceFoamLayer/SurfaceFoamArt"
	) as CanvasItem
	if static_foam != null:
		static_foam.visible = false

	var wave_line: Line2D = current_scene.get_node_or_null("SurfaceWaveFoam") as Line2D
	if wave_line == null:
		_bound_line = null
		return

	if _bound_line == wave_line:
		return

	_bound_line = wave_line
	_apply_foam_texture(_bound_line)


func _apply_foam_texture(line: Line2D) -> void:
	line.texture = FOAM_TEXTURE
	line.texture_mode = Line2D.LINE_TEXTURE_TILE
	line.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	line.width = 9.0
	line.default_color = Color(1.0, 1.0, 1.0, 0.72)
	line.joint_mode = Line2D.LINE_JOINT_ROUND
	line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	line.end_cap_mode = Line2D.LINE_CAP_ROUND
	line.antialiased = false


# -----------------------------------------------------------------------------
# GUNES + 8 / 36 SUN RAYS ORTAK PARALLAX
# -----------------------------------------------------------------------------

func _ensure_sun_light_group(current_scene: Node) -> void:
	var environment_root: Node2D = current_scene.get_node_or_null("EnvironmentLayers") as Node2D
	if environment_root == null:
		return

	_sun_light_parallax = environment_root.get_node_or_null("SunLightParallax") as Parallax2D
	if _sun_light_parallax == null:
		_sun_light_parallax = Parallax2D.new()
		_sun_light_parallax.name = "SunLightParallax"
		_sun_light_parallax.scroll_scale = Vector2(0.08, 1.0)
		environment_root.add_child(_sun_light_parallax)
	else:
		_sun_light_parallax.scroll_scale = Vector2(0.08, 1.0)

	var sun_layer: Node2D = current_scene.get_node_or_null(
		"EnvironmentLayers/SkyParallax/SunLayer"
	) as Node2D
	if sun_layer == null:
		sun_layer = _sun_light_parallax.get_node_or_null("SunLayer") as Node2D
	if sun_layer != null and sun_layer.get_parent() != _sun_light_parallax:
		sun_layer.reparent(_sun_light_parallax, false)

	var rays_layer: Node2D = current_scene.get_node_or_null(
		"EnvironmentLayers/UnderwaterLayers/SunRaysLayer"
	) as Node2D
	if rays_layer == null:
		rays_layer = _sun_light_parallax.get_node_or_null("SunRaysLayer") as Node2D
	if rays_layer != null and rays_layer.get_parent() != _sun_light_parallax:
		rays_layer.reparent(_sun_light_parallax, false)

	_resize_sun()


func _resize_sun() -> void:
	if not is_instance_valid(_sun_light_parallax):
		return

	var sun_sprite: Sprite2D = _sun_light_parallax.get_node_or_null("SunLayer/SunArt") as Sprite2D
	if sun_sprite == null or sun_sprite.texture == null:
		return

	var texture_size: Vector2 = sun_sprite.texture.get_size()
	if texture_size.x <= 0.0 or texture_size.y <= 0.0:
		return

	var fit_scale: float = minf(
		SUN_TARGET_SIZE / texture_size.x,
		SUN_TARGET_SIZE / texture_size.y
	)
	sun_sprite.position = Vector2(SUN_X, 225.0)
	sun_sprite.scale = Vector2.ONE * fit_scale
	sun_sprite.modulate = Color(1.0, 1.0, 1.0, 0.96)


# -----------------------------------------------------------------------------
# 8 / 36 - SUN RAYS
# -----------------------------------------------------------------------------

func _ensure_sun_rays(_current_scene: Node) -> void:
	if is_instance_valid(_ray_root):
		return
	if not is_instance_valid(_sun_light_parallax):
		return

	var rays_layer: Node2D = _sun_light_parallax.get_node_or_null("SunRaysLayer") as Node2D
	if rays_layer == null:
		return

	var existing: Node2D = rays_layer.get_node_or_null("SunRaysArt") as Node2D
	if existing != null:
		_ray_root = existing
		return

	var texture_size: Vector2 = SUN_RAYS_TEXTURE.get_size()
	if texture_size.x <= 0.0 or texture_size.y <= 0.0:
		return

	_ray_root = Node2D.new()
	_ray_root.name = "SunRaysArt"
	rays_layer.add_child(_ray_root)

	var ray_shader: Shader = Shader.new()
	ray_shader.code = (
		"shader_type canvas_item;\n"
		+ "render_mode blend_add;\n"
		+ "uniform float opacity = 0.15;\n"
		+ "void fragment() {\n"
		+ "    vec4 tex = texture(TEXTURE, UV);\n"
		+ "    float top_fade = smoothstep(0.00, 0.10, UV.y);\n"
		+ "    float depth_fade = 1.0 - smoothstep(0.52, 1.00, UV.y);\n"
		+ "    float side_fade = smoothstep(0.00, 0.12, UV.x) * (1.0 - smoothstep(0.88, 1.00, UV.x));\n"
		+ "    COLOR = vec4(tex.rgb, tex.a * top_fade * depth_fade * side_fade * opacity);\n"
		+ "}\n"
	)

	var ray_material: ShaderMaterial = ShaderMaterial.new()
	ray_material.shader = ray_shader

	var ray_sprite: Sprite2D = Sprite2D.new()
	ray_sprite.name = "SunRaysMain"
	ray_sprite.texture = SUN_RAYS_TEXTURE
	ray_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	ray_sprite.material = ray_material
	ray_sprite.position = Vector2(
		SUN_X,
		WATER_SURFACE_Y + 4.0 + SUN_RAYS_DEPTH_HEIGHT * 0.5
	)
	ray_sprite.scale = Vector2(
		SUN_RAYS_WIDTH / texture_size.x,
		SUN_RAYS_DEPTH_HEIGHT / texture_size.y
	)
	_ray_root.add_child(ray_sprite)


# -----------------------------------------------------------------------------
# 9 / 36 - SHALLOW ROCK 01 - SIMDİLIK ATLANDI
# -----------------------------------------------------------------------------

func _remove_skipped_rocks(current_scene: Node) -> void:
	var old_rock: Node = current_scene.get_node_or_null(
		"EnvironmentLayers/UnderwaterLayers/MidDecorLayer/ShallowRock01Art"
	)
	if old_rock != null and not old_rock.is_queued_for_deletion():
		old_rock.queue_free()


# -----------------------------------------------------------------------------
# 10 / 36 - SHALLOW FISH SCHOOL 01 TEMP
# -----------------------------------------------------------------------------

func _ensure_shallow_fish_schools(current_scene: Node) -> void:
	if is_instance_valid(_fish_school_root):
		return

	var decor_layer: Node2D = current_scene.get_node_or_null(
		"EnvironmentLayers/UnderwaterLayers/BackgroundDecorLayer"
	) as Node2D
	if decor_layer == null:
		return

	var old_single: Node = decor_layer.get_node_or_null("ShallowFishSchool01")
	if old_single != null and not old_single.is_queued_for_deletion():
		old_single.queue_free()

	var existing: Node2D = decor_layer.get_node_or_null("ShallowFishSchools10") as Node2D
	if existing != null:
		_fish_school_root = existing
		return

	var texture_size: Vector2 = SHALLOW_FISH_SCHOOL_TEXTURE.get_size()
	if texture_size.x <= 0.0 or texture_size.y <= 0.0:
		return

	var fit_scale: float = FISH_SCHOOL_TARGET_WIDTH / texture_size.x

	_fish_school_root = Node2D.new()
	_fish_school_root.name = "ShallowFishSchools10"
	decor_layer.add_child(_fish_school_root)

	var placements: Array[Vector2] = [
		Vector2(1320.0, 650.0),
		Vector2(1850.0, 520.0),
		Vector2(2380.0, 760.0),
		Vector2(2910.0, 600.0),
		Vector2(3440.0, 900.0),
		Vector2(3970.0, 700.0),
		Vector2(4500.0, 980.0),
		Vector2(5030.0, 560.0),
		Vector2(5560.0, 820.0),
		Vector2(6090.0, 670.0)
	]

	for i: int in range(placements.size()):
		var sprite: Sprite2D = Sprite2D.new()
		sprite.name = "ShallowFishSchool_%02d" % i
		sprite.texture = SHALLOW_FISH_SCHOOL_TEXTURE
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite.position = placements[i]

		var size_variation: float = 0.88 + float(i % 4) * 0.05
		var direction: float = -1.0 if i % 3 == 1 else 1.0
		sprite.scale = Vector2(direction * fit_scale * size_variation, fit_scale * size_variation)
		sprite.modulate = Color(0.78, 0.90, 0.96, 0.42 + float(i % 3) * 0.04)
		sprite.set_meta("origin", placements[i])
		sprite.set_meta("phase", float(i) * 0.83)
		_fish_school_root.add_child(sprite)

	print("SHALLOW FISH SCHOOL: 10/36 0-20m bandina 10 arka-plan surusu yayildi")


# -----------------------------------------------------------------------------
# 11 / 36 - SHALLOW KELP 01
# -----------------------------------------------------------------------------

func _ensure_shallow_kelp(current_scene: Node) -> void:
	if is_instance_valid(_kelp_root):
		return

	var decor_layer: Node2D = current_scene.get_node_or_null(
		"EnvironmentLayers/UnderwaterLayers/BackgroundDecorLayer"
	) as Node2D
	if decor_layer == null:
		return

	var existing: Node2D = decor_layer.get_node_or_null("ShallowKelp11") as Node2D
	if existing != null:
		_kelp_root = existing
		return

	var texture_size: Vector2 = SHALLOW_KELP_TEXTURE.get_size()
	if texture_size.x <= 0.0 or texture_size.y <= 0.0:
		return

	var fit_scale: float = KELP_TARGET_HEIGHT / texture_size.y

	_kelp_root = Node2D.new()
	_kelp_root.name = "ShallowKelp11"
	decor_layer.add_child(_kelp_root)

	# Kelp acik denize dagitilmaz. Sadece limanin su alti ayaklarinin arkasinda tutulur.
	# Pivotlar kok noktasidir; sprite yukariya tasindigi icin salinim kokten olur.
	var placements: Array[Vector3] = [
		Vector3(70.0, 650.0, 0.88),
		Vector3(205.0, 700.0, 1.00),
		Vector3(365.0, 735.0, 0.92),
		Vector3(520.0, 770.0, 0.80)
	]

	for i: int in range(placements.size()):
		var data: Vector3 = placements[i]
		var local_scale: float = fit_scale * data.z
		var scaled_height: float = texture_size.y * local_scale

		var pivot: Node2D = Node2D.new()
		pivot.name = "KelpPivot_%02d" % i
		pivot.position = Vector2(data.x, data.y)
		pivot.set_meta("phase", float(i) * 0.91)
		pivot.set_meta("base_rotation", -0.025 + float(i % 3) * 0.025)
		_kelp_root.add_child(pivot)

		var sprite: Sprite2D = Sprite2D.new()
		sprite.name = "Kelp_%02d" % i
		sprite.texture = SHALLOW_KELP_TEXTURE
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite.position = Vector2(0.0, -scaled_height * 0.5)
		sprite.scale = Vector2(local_scale * (-1.0 if i % 2 == 1 else 1.0), local_scale)
		sprite.modulate = Color(0.62, 0.86, 0.78, 0.55)
		pivot.add_child(sprite)

	print("SHALLOW KELP: 11/36 sadece liman alti/kayi bolgesine yerlestirildi")


func _animate_shallow_environment(delta: float) -> void:
	_anim_time += delta

	if is_instance_valid(_fish_school_root):
		for child: Node in _fish_school_root.get_children():
			var sprite: Sprite2D = child as Sprite2D
			if sprite == null:
				continue

			var origin: Vector2 = sprite.get_meta("origin", sprite.position)
			var phase: float = float(sprite.get_meta("phase", 0.0))
			sprite.position = origin + Vector2(
				sin(_anim_time * 0.26 + phase) * 24.0,
				sin(_anim_time * 0.51 + phase) * 5.0
			)

	if is_instance_valid(_kelp_root):
		for child: Node in _kelp_root.get_children():
			var pivot: Node2D = child as Node2D
			if pivot == null:
				continue

			var phase: float = float(pivot.get_meta("phase", 0.0))
			var base_rotation: float = float(pivot.get_meta("base_rotation", 0.0))
			pivot.rotation = base_rotation + sin(_anim_time * 0.72 + phase) * 0.055
