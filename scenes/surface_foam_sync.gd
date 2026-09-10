extends Node

# Surface/0-20m environment runtime.
# 20-100m terrain bu dosyada YONETILMEZ.
# Terrain yalnizca UnderwaterTerrainRuntime autoload tarafindan yonetilir.

const FOAM_TEXTURE: Texture2D = preload("res://assets/environment/surface/surface_foam_01.png")
const SUN_RAYS_TEXTURE: Texture2D = preload("res://assets/environment/surface/sun_rays_01.png")
const SHALLOW_FISH_SCHOOL_TEXTURE: Texture2D = preload("res://assets/environment/shallow/shallow_fish_school_01_TEMP.png")

const WATER_SURFACE_Y: float = 360.0
const SUN_X: float = 1060.0
const SUN_TARGET_SIZE: float = 175.0
const SUN_RAYS_WIDTH: float = 1450.0
const SUN_RAYS_DEPTH_HEIGHT: float = 540.0
const FISH_SCHOOL_TARGET_WIDTH: float = 220.0

var _bound_line: Line2D = null
var _ray_root: Node2D = null
var _sun_light_parallax: Parallax2D = null
var _fish_school_root: Node2D = null
var _anim_time: float = 0.0
var _scene_id: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	print("ENV RUNTIME: surface + shallow fish | terrain separate")


func _process(delta: float) -> void:
	var current_scene: Node = get_tree().current_scene
	if current_scene == null:
		return

	var current_id: int = current_scene.get_instance_id()
	if current_id != _scene_id:
		_scene_id = current_id
		_bound_line = null
		_ray_root = null
		_sun_light_parallax = null
		_fish_school_root = null
		_anim_time = 0.0

	_sync_surface_foam(current_scene)
	_ensure_sun_light_group(current_scene)
	_ensure_sun_rays(current_scene)
	_remove_skipped_rocks(current_scene)
	_remove_paused_shallow_kelp(current_scene)
	_ensure_shallow_fish_schools(current_scene)
	_animate_shallow_environment(delta)


func _sync_surface_foam(current_scene: Node) -> void:
	var static_foam: CanvasItem = current_scene.get_node_or_null(
		"EnvironmentLayers/SurfaceLayers/SurfaceFoamLayer/SurfaceFoamArt"
	) as CanvasItem
	if static_foam != null:
		static_foam.visible = false

	var wave_line: Line2D = current_scene.get_node_or_null("SurfaceWaveFoam") as Line2D
	if wave_line == null or _bound_line == wave_line:
		return

	_bound_line = wave_line
	wave_line.texture = FOAM_TEXTURE
	wave_line.texture_mode = Line2D.LINE_TEXTURE_TILE
	wave_line.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	wave_line.width = 9.0
	wave_line.default_color = Color(1.0, 1.0, 1.0, 0.72)
	wave_line.joint_mode = Line2D.LINE_JOINT_ROUND
	wave_line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	wave_line.end_cap_mode = Line2D.LINE_CAP_ROUND
	wave_line.antialiased = false


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


func _ensure_sun_rays(_current_scene: Node) -> void:
	if is_instance_valid(_ray_root) or not is_instance_valid(_sun_light_parallax):
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

	var shader: Shader = Shader.new()
	shader.code = (
		"shader_type canvas_item;\n"
		+ "render_mode blend_add;\n"
		+ "uniform float opacity = 0.15;\n"
		+ "void fragment(){\n"
		+ " vec4 tex=texture(TEXTURE,UV);\n"
		+ " float a=smoothstep(0.0,0.1,UV.y)"
		+ "*(1.0-smoothstep(0.52,1.0,UV.y))"
		+ "*smoothstep(0.0,0.12,UV.x)"
		+ "*(1.0-smoothstep(0.88,1.0,UV.x));\n"
		+ " COLOR=vec4(tex.rgb,tex.a*a*opacity);\n"
		+ "}\n"
	)

	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = shader

	var sprite: Sprite2D = Sprite2D.new()
	sprite.name = "SunRaysMain"
	sprite.texture = SUN_RAYS_TEXTURE
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.material = material
	sprite.position = Vector2(
		SUN_X,
		WATER_SURFACE_Y + 4.0 + SUN_RAYS_DEPTH_HEIGHT * 0.5
	)
	sprite.scale = Vector2(
		SUN_RAYS_WIDTH / texture_size.x,
		SUN_RAYS_DEPTH_HEIGHT / texture_size.y
	)
	_ray_root.add_child(sprite)


func _remove_skipped_rocks(current_scene: Node) -> void:
	var old_rock: Node = current_scene.get_node_or_null(
		"EnvironmentLayers/UnderwaterLayers/MidDecorLayer/ShallowRock01Art"
	)
	if old_rock != null and not old_rock.is_queued_for_deletion():
		old_rock.queue_free()


func _remove_paused_shallow_kelp(current_scene: Node) -> void:
	var old_kelp: Node = current_scene.get_node_or_null(
		"EnvironmentLayers/UnderwaterLayers/BackgroundDecorLayer/ShallowKelp11"
	)
	if old_kelp != null and not old_kelp.is_queued_for_deletion():
		old_kelp.queue_free()


func _ensure_shallow_fish_schools(current_scene: Node) -> void:
	if is_instance_valid(_fish_school_root):
		return

	var decor_layer: Node2D = current_scene.get_node_or_null(
		"EnvironmentLayers/UnderwaterLayers/BackgroundDecorLayer"
	) as Node2D
	if decor_layer == null:
		return

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
		sprite.scale = Vector2(
			direction * fit_scale * size_variation,
			fit_scale * size_variation
		)
		sprite.modulate = Color(0.78, 0.90, 0.96, 0.42 + float(i % 3) * 0.04)
		sprite.set_meta("origin", placements[i])
		sprite.set_meta("phase", float(i) * 0.83)
		_fish_school_root.add_child(sprite)


func _animate_shallow_environment(delta: float) -> void:
	_anim_time += delta
	if not is_instance_valid(_fish_school_root):
		return

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
