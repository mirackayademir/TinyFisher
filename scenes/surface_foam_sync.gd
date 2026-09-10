extends Node

# Environment runtime destegi.
# 7/36 surface_foam_01.png: hareketli ana dalgaya baglanir.
# 8/36 sun_rays_01.png: tek, duzenli bir gunes huzmesi kumesi olarak kullanilir.
# 9/36 shallow_rock_01.png: liman/kayi tarafindan suya uzanan sig resif duvari.

const FOAM_TEXTURE: Texture2D = preload("res://assets/environment/surface/surface_foam_01.png")
const SUN_RAYS_TEXTURE: Texture2D = preload("res://assets/environment/surface/sun_rays_01.png")
const SHALLOW_ROCK_TEXTURE: Texture2D = preload("res://assets/environment/shallow/shallow_rock_01.png")

const WATER_SURFACE_Y: float = 360.0
const SUN_X: float = 1060.0
const SUN_TARGET_SIZE: float = 175.0
const SUN_RAYS_WIDTH: float = 1450.0
const SUN_RAYS_DEPTH_HEIGHT: float = 540.0

var _bound_line: Line2D = null
var _ray_root: Node2D = null
var _rock_root: Node2D = null
var _sun_light_parallax: Parallax2D = null
var _scene_id: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	print("ENV RUNTIME: 7/36 kopuk + 8/36 huzme + 9/36 kiyi resifi hazir")


func _process(_delta: float) -> void:
	var current_scene: Node = get_tree().current_scene
	if current_scene == null:
		_reset_scene_refs()
		return

	var current_id: int = current_scene.get_instance_id()
	if current_id != _scene_id:
		_scene_id = current_id
		_bound_line = null
		_ray_root = null
		_rock_root = null
		_sun_light_parallax = null

	_sync_surface_foam(current_scene)
	_ensure_sun_light_group(current_scene)
	_ensure_sun_rays(current_scene)
	_ensure_shallow_rock(current_scene)


func _reset_scene_refs() -> void:
	_bound_line = null
	_ray_root = null
	_rock_root = null
	_sun_light_parallax = null
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
# 9 / 36 - SHALLOW ROCK 01 / KIYI RESIFI
# -----------------------------------------------------------------------------

func _ensure_shallow_rock(current_scene: Node) -> void:
	if is_instance_valid(_rock_root):
		return

	var decor_layer: Node2D = current_scene.get_node_or_null(
		"EnvironmentLayers/UnderwaterLayers/MidDecorLayer"
	) as Node2D
	if decor_layer == null:
		return

	var existing: Node2D = decor_layer.get_node_or_null("ShallowRock01Art") as Node2D
	if existing != null:
		_rock_root = existing
		return

	var texture_size: Vector2 = SHALLOW_ROCK_TEXTURE.get_size()
	if texture_size.x <= 0.0 or texture_size.y <= 0.0:
		return

	_rock_root = Node2D.new()
	_rock_root.name = "ShallowRock01Art"
	decor_layer.add_child(_rock_root)

	# Eski surumde kayalar acik denizde tek basina durdugu icin havada asili gorunuyordu.
	# Artik sadece liman/kayi tarafinda, birbirinin ustune binen bir resif duvari kuruyoruz.
	# Buyuk kutle solda dunya disina tasar; kucuk kutleler saga-yukariya dogru seyreklesir.
	# Boylece gorunen alt kenarlar birbirine gomulur ve kaya "denizin ortasinda" durmaz.
	var placements: Array[Vector3] = [
		Vector3(-40.0, 1045.0, 1.12),
		Vector3(205.0, 955.0, 0.92),
		Vector3(390.0, 845.0, 0.72),
		Vector3(525.0, 735.0, 0.56)
	]

	for i: int in range(placements.size()):
		var placement: Vector3 = placements[i]
		var scale_value: float = placement.z
		var scaled_height: float = texture_size.y * scale_value

		var sprite: Sprite2D = Sprite2D.new()
		sprite.name = "ShallowReefRock_%02d" % i
		sprite.texture = SHALLOW_ROCK_TEXTURE
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite.position = Vector2(placement.x, placement.y - scaled_height * 0.5)
		sprite.scale = Vector2(-scale_value if i % 2 == 1 else scale_value, scale_value)
		sprite.modulate = Color(0.84, 0.94, 1.0, 0.94)
		_rock_root.add_child(sprite)

	print("SHALLOW ROCK: 9/36 acik denizden kaldirildi; liman tarafinda kiyi resifi kuruldu")