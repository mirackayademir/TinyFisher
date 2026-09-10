extends Node

# Yuzey efektleri runtime destegi.
# 7/36 surface_foam_01.png: hareketli ana dalgaya baglanir.
# 8/36 sun_rays_01.png: su yuzeyinden 0-20 m sig su bolgesine iner.

const FOAM_TEXTURE: Texture2D = preload("res://assets/environment/surface/surface_foam_01.png")
const SUN_RAYS_TEXTURE: Texture2D = preload("res://assets/environment/surface/sun_rays_01.png")

const WATER_SURFACE_Y: float = 360.0
const WORLD_LEFT_X: float = -1000.0
const WORLD_RIGHT_X: float = 11000.0
const SUN_RAYS_DEPTH_HEIGHT: float = 680.0 # Yaklasik 0-20 metre: 20m x ~34px
const SUN_RAYS_TILE_WIDTH: float = 1600.0

var _bound_line: Line2D = null
var _ray_root: Node2D = null
var _scene_id: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	print("SURFACE EFFECTS: 7/36 kopuk + 8/36 gunes huzmeleri hazir")


func _process(_delta: float) -> void:
	var current_scene: Node = get_tree().current_scene
	if current_scene == null:
		_bound_line = null
		_ray_root = null
		_scene_id = 0
		return

	var current_id: int = current_scene.get_instance_id()
	if current_id != _scene_id:
		_scene_id = current_id
		_bound_line = null
		_ray_root = null

	_sync_surface_foam(current_scene)
	_ensure_sun_rays(current_scene)


# -----------------------------------------------------------------------------
# 7 / 36 - SURFACE FOAM
# -----------------------------------------------------------------------------

func _sync_surface_foam(current_scene: Node) -> void:
	# EnvironmentLayers tarafinda uretilen sabit kopuk seridini gizliyoruz.
	# Ana dalga hareket ederken arkada ayri bir iz birakmasin.
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
	print("SURFACE FOAM SYNC: kopuk hareketli dalgaya baglandi")


# -----------------------------------------------------------------------------
# 8 / 36 - SUN RAYS
# -----------------------------------------------------------------------------

func _ensure_sun_rays(current_scene: Node) -> void:
	if is_instance_valid(_ray_root):
		return

	# EnvironmentLayers kendi katman agacini kurana kadar bekle.
	var rays_layer: Node2D = current_scene.get_node_or_null(
		"EnvironmentLayers/UnderwaterLayers/SunRaysLayer"
	) as Node2D
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

	# Huzmeler sadece sig suda gorunur. Ustte su cizgisinden yumusak girer,
	# 20 metreye yaklastikca sifira kaybolur; derin denize tasmaz.
	var ray_shader: Shader = Shader.new()
	ray_shader.code = (
		"shader_type canvas_item;\n"
		+ "render_mode blend_add;\n"
		+ "uniform float opacity = 0.20;\n"
		+ "void fragment() {\n"
		+ "    vec4 tex = texture(TEXTURE, UV);\n"
		+ "    float top_fade = smoothstep(0.00, 0.08, UV.y);\n"
		+ "    float depth_fade = 1.0 - smoothstep(0.58, 1.00, UV.y);\n"
		+ "    float side_fade = smoothstep(0.00, 0.07, UV.x) * (1.0 - smoothstep(0.93, 1.00, UV.x));\n"
		+ "    COLOR = vec4(tex.rgb, tex.a * top_fade * depth_fade * side_fade * opacity);\n"
		+ "}\n"
	)

	var ray_material: ShaderMaterial = ShaderMaterial.new()
	ray_material.shader = ray_shader

	var x_scale: float = SUN_RAYS_TILE_WIDTH / texture_size.x
	var y_scale: float = SUN_RAYS_DEPTH_HEIGHT / texture_size.y
	var center_y: float = WATER_SURFACE_Y + 4.0 + SUN_RAYS_DEPTH_HEIGHT * 0.5
	var x: float = WORLD_LEFT_X + SUN_RAYS_TILE_WIDTH * 0.5
	var index: int = 0

	while x < WORLD_RIGHT_X + SUN_RAYS_TILE_WIDTH * 0.5:
		var sprite: Sprite2D = Sprite2D.new()
		sprite.name = "SunRays_%02d" % index
		sprite.texture = SUN_RAYS_TEXTURE
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite.material = ray_material
		sprite.position = Vector2(x, center_y)
		sprite.scale = Vector2((-x_scale) if index % 2 == 1 else x_scale, y_scale)
		_ray_root.add_child(sprite)

		# Parcalar birbirine az miktarda biner; dikey dikiş izi kalmaz.
		x += SUN_RAYS_TILE_WIDTH - 80.0
		index += 1

	print("SUN RAYS: 8/36 sig su 0-20m katmanina eklendi")
