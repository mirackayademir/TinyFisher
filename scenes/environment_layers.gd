extends Node

# TinyFisher katmanli dunya altyapisi.
# 36 environment gorseli TEK TEK eklenecek.
# Aktif: 1) sky_base_01.png  2) sun_01_TEMP.png  3) horizon_land_01.png
#        4) ocean_surface_base_01.png  5) wave_back_01.png  6) wave_front_01.png

const ENV_ROOT_NAME: String = "EnvironmentLayers"
const DECOR_SEED: int = 9042026
const WATER_SURFACE_Y: float = 360.0
const WORLD_LEFT_X: float = -1000.0
const WORLD_RIGHT_X: float = 11000.0

const SKY_BOTTOM_CROP_PX: float = 14.0
const SKY_WATER_OVERLAP_PX: float = 42.0

const Z_LEGACY_SKY: int = -11
const Z_SKY_BASE: int = -10
const Z_SUN: int = -7
const Z_HORIZON: int = -10
const Z_OCEAN_SURFACE: int = -8
const Z_WAVE_BACK: int = -7
const Z_SUN_RAYS: int = -7
const Z_BACKGROUND_DECOR: int = -6
const Z_MID_DECOR: int = -5
const Z_LANDMARK_DECOR: int = -4
const Z_WAVE_FRONT: int = -3
const Z_SURFACE_FOAM: int = -2
const Z_FOREGROUND_DECOR: int = -1
const Z_PARTICLES: int = -1

const ZONE_SHALLOW: String = "shallow"
const ZONE_OPEN_BLUE: String = "open_blue"
const ZONE_DEEP: String = "deep"
const ZONE_ABYSS: String = "abyss"

const SKY_TEXTURE_PATH: String = "res://assets/environment/surface/sky_base_01.png"
const SUN_TEXTURE_PATH: String = "res://assets/environment/surface/sun_01_TEMP.png"
const HORIZON_TEXTURE_PATH: String = "res://assets/environment/surface/horizon_land_01.png"
const OCEAN_SURFACE_TEXTURE_PATH: String = "res://assets/environment/surface/ocean_surface_base_01.png"
const WAVE_BACK_TEXTURE_PATH: String = "res://assets/environment/surface/wave_back_01.png"
const WAVE_FRONT_TEXTURE_PATH: String = "res://assets/environment/surface/wave_front_01.png"

var _scene_id: int = 0
var _world: Node2D = null
var _environment_root: Node2D = null
var _layers: Dictionary = {}
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.seed = DECOR_SEED
	print("ENVIRONMENT LAYERS V13: WAVE FRONT 6/36")


func _process(_delta: float) -> void:
	_ensure_environment_layers()


func _ensure_environment_layers() -> void:
	var current_scene: Node = get_tree().current_scene
	if current_scene == null:
		return

	var current_id: int = current_scene.get_instance_id()
	if current_id == _scene_id and is_instance_valid(_world) and is_instance_valid(_environment_root):
		return

	_scene_id = current_id
	_world = current_scene as Node2D
	_environment_root = null
	_layers.clear()

	if _world == null:
		return

	_prepare_base_layer_order()

	_environment_root = _world.get_node_or_null(ENV_ROOT_NAME) as Node2D
	if _environment_root == null:
		_environment_root = Node2D.new()
		_environment_root.name = ENV_ROOT_NAME
		_world.add_child(_environment_root)

	_build_layer_tree()
	_build_sky_only()
	_build_sun_only()
	_build_horizon_only()
	_build_ocean_surface_only()
	_build_wave_back_only()
	_build_wave_front_only()
	print("ENVIRONMENT: 6/36 aktif")


func _prepare_base_layer_order() -> void:
	var legacy_sky: CanvasItem = _world.get_node_or_null("Sky") as CanvasItem
	if legacy_sky != null:
		legacy_sky.z_index = Z_LEGACY_SKY

	var water: CanvasItem = _world.get_node_or_null("Water") as CanvasItem
	if water != null:
		water.z_index = -9


func _build_layer_tree() -> void:
	if not is_instance_valid(_environment_root):
		return

	var sky_parallax: Parallax2D = _ensure_parallax("SkyParallax", Vector2(0.08, 0.02))
	_register_layer("SkyBaseLayer", _ensure_node2d(sky_parallax, "SkyBaseLayer", Z_SKY_BASE))
	_register_layer("SunLayer", _ensure_node2d(sky_parallax, "SunLayer", Z_SUN))
	_register_layer("HorizonLandLayer", _ensure_node2d(sky_parallax, "HorizonLandLayer", Z_HORIZON))

	var surface_layers: Node2D = _ensure_node2d(_environment_root, "SurfaceLayers", 0)
	_register_layer("OceanSurfaceLayer", _ensure_node2d(surface_layers, "OceanSurfaceLayer", Z_OCEAN_SURFACE))
	_register_layer("WaveBackLayer", _ensure_node2d(surface_layers, "WaveBackLayer", Z_WAVE_BACK))
	_register_layer("WaveFrontLayer", _ensure_node2d(surface_layers, "WaveFrontLayer", Z_WAVE_FRONT))
	_register_layer("SurfaceFoamLayer", _ensure_node2d(surface_layers, "SurfaceFoamLayer", Z_SURFACE_FOAM))

	var underwater_layers: Node2D = _ensure_node2d(_environment_root, "UnderwaterLayers", 0)
	_register_layer("SunRaysLayer", _ensure_node2d(underwater_layers, "SunRaysLayer", Z_SUN_RAYS))
	_register_layer("BackgroundDecorLayer", _ensure_node2d(underwater_layers, "BackgroundDecorLayer", Z_BACKGROUND_DECOR))
	_register_layer("MidDecorLayer", _ensure_node2d(underwater_layers, "MidDecorLayer", Z_MID_DECOR))
	_register_layer("LandmarkDecorLayer", _ensure_node2d(underwater_layers, "LandmarkDecorLayer", Z_LANDMARK_DECOR))
	_register_layer("ForegroundDecorLayer", _ensure_node2d(underwater_layers, "ForegroundDecorLayer", Z_FOREGROUND_DECOR))
	_register_layer("ParticleLayer", _ensure_node2d(underwater_layers, "ParticleLayer", Z_PARTICLES))
	_register_layer("RuntimeDecor", _ensure_node2d(_environment_root, "RuntimeDecor", 0))


# -----------------------------------------------------------------------------
# GORSEL 1 / 36 - SKY
# -----------------------------------------------------------------------------

func _build_sky_only() -> void:
	var layer: Node2D = get_layer("SkyBaseLayer")
	if layer == null or layer.get_node_or_null("SkyBaseArt") != null:
		return

	var source_texture: Texture2D = _load_texture(SKY_TEXTURE_PATH)
	if source_texture == null:
		return

	var source_size: Vector2 = source_texture.get_size()
	if source_size.x <= 0.0 or source_size.y <= SKY_BOTTOM_CROP_PX:
		return

	var cropped_texture: AtlasTexture = AtlasTexture.new()
	cropped_texture.atlas = source_texture
	cropped_texture.region = Rect2(0.0, 0.0, source_size.x, source_size.y - SKY_BOTTOM_CROP_PX)

	var texture_size: Vector2 = cropped_texture.get_size()
	var root: Node2D = Node2D.new()
	root.name = "SkyBaseArt"
	layer.add_child(root)

	var target_height: float = 860.0
	var scale_factor: float = target_height / texture_size.y
	var center_y: float = WATER_SURFACE_Y + SKY_WATER_OVERLAP_PX - target_height * 0.5
	_add_tiled_strip(root, cropped_texture, scale_factor, center_y, null, 1.0)


# -----------------------------------------------------------------------------
# GORSEL 2 / 36 - SUN
# -----------------------------------------------------------------------------

func _build_sun_only() -> void:
	var layer: Node2D = get_layer("SunLayer")
	if layer == null or layer.get_node_or_null("SunArt") != null:
		return

	var texture: Texture2D = _load_texture(SUN_TEXTURE_PATH)
	if texture == null:
		return

	var texture_size: Vector2 = texture.get_size()
	if texture_size.x <= 0.0 or texture_size.y <= 0.0:
		return

	var fit_scale: float = minf(120.0 / texture_size.x, 120.0 / texture_size.y)
	var sprite: Sprite2D = Sprite2D.new()
	sprite.name = "SunArt"
	sprite.texture = texture
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.position = Vector2(1060.0, 235.0)
	sprite.scale = Vector2.ONE * fit_scale
	sprite.modulate = Color(1.0, 1.0, 1.0, 0.94)
	layer.add_child(sprite)


# -----------------------------------------------------------------------------
# GORSEL 3 / 36 - HORIZON LAND
# -----------------------------------------------------------------------------

func _build_horizon_only() -> void:
	var layer: Node2D = get_layer("HorizonLandLayer")
	if layer == null or layer.get_node_or_null("HorizonLandArt") != null:
		return

	var texture: Texture2D = _load_texture(HORIZON_TEXTURE_PATH)
	if texture == null:
		return

	var texture_size: Vector2 = texture.get_size()
	if texture_size.x <= 0.0 or texture_size.y <= 0.0:
		return

	var root: Node2D = Node2D.new()
	root.name = "HorizonLandArt"
	layer.add_child(root)

	var target_height: float = 72.0
	var scale_factor: float = target_height / texture_size.y
	var center_y: float = WATER_SURFACE_Y - target_height * 0.5 + 22.0
	_add_tiled_strip(root, texture, scale_factor, center_y, null, 1.0, Color(0.78, 0.80, 0.92, 0.82))


# -----------------------------------------------------------------------------
# GORSEL 4 / 36 - OCEAN SURFACE BASE
# -----------------------------------------------------------------------------

func _build_ocean_surface_only() -> void:
	var layer: Node2D = get_layer("OceanSurfaceLayer")
	if layer == null or layer.get_node_or_null("OceanSurfaceArt") != null:
		return

	var texture: Texture2D = _load_texture(OCEAN_SURFACE_TEXTURE_PATH)
	if texture == null:
		return

	var texture_size: Vector2 = texture.get_size()
	if texture_size.x <= 0.0 or texture_size.y <= 0.0:
		return

	var root: Node2D = Node2D.new()
	root.name = "OceanSurfaceArt"
	layer.add_child(root)

	var fade_shader: Shader = Shader.new()
	fade_shader.code = (
		"shader_type canvas_item;\n"
		+ "uniform float opacity = 0.14;\n"
		+ "void fragment() {\n"
		+ "    vec4 tex = texture(TEXTURE, UV);\n"
		+ "    float top_soft = smoothstep(0.00, 0.12, UV.y);\n"
		+ "    float bottom_soft = 1.0 - smoothstep(0.48, 1.00, UV.y);\n"
		+ "    COLOR = vec4(tex.rgb, tex.a * top_soft * bottom_soft * opacity);\n"
		+ "}\n"
	)

	var fade_material: ShaderMaterial = ShaderMaterial.new()
	fade_material.shader = fade_shader

	var world_width: float = WORLD_RIGHT_X - WORLD_LEFT_X
	var target_height: float = 44.0

	var sprite: Sprite2D = Sprite2D.new()
	sprite.name = "OceanSurfaceSingleStrip"
	sprite.texture = texture
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.material = fade_material
	sprite.position = Vector2(WORLD_LEFT_X + world_width * 0.5, WATER_SURFACE_Y + target_height * 0.5)
	sprite.scale = Vector2(world_width / texture_size.x, target_height / texture_size.y)
	root.add_child(sprite)


# -----------------------------------------------------------------------------
# GORSEL 5 / 36 - WAVE BACK
# -----------------------------------------------------------------------------

func _build_wave_back_only() -> void:
	var layer: Node2D = get_layer("WaveBackLayer")
	if layer == null or layer.get_node_or_null("WaveBackArt") != null:
		return

	var texture: Texture2D = _load_texture(WAVE_BACK_TEXTURE_PATH)
	if texture == null:
		return

	var texture_size: Vector2 = texture.get_size()
	if texture_size.x <= 0.0 or texture_size.y <= 0.0:
		return

	var root: Node2D = Node2D.new()
	root.name = "WaveBackArt"
	layer.add_child(root)

	var target_height: float = 30.0
	var y_scale: float = target_height / texture_size.y
	var tile_width: float = texture_size.x
	var center_y: float = WATER_SURFACE_Y - 7.0
	var x: float = WORLD_LEFT_X + tile_width * 0.5
	var tile_index: int = 0

	while x < WORLD_RIGHT_X + tile_width * 0.5:
		var sprite: Sprite2D = Sprite2D.new()
		sprite.name = "WaveBack_%02d" % tile_index
		sprite.texture = texture
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite.position = Vector2(x, center_y)
		sprite.scale = Vector2(-1.0 if tile_index % 2 == 1 else 1.0, y_scale)
		sprite.modulate = Color(0.84, 0.94, 1.0, 0.34)
		root.add_child(sprite)

		x += tile_width - 2.0
		tile_index += 1


# -----------------------------------------------------------------------------
# GORSEL 6 / 36 - WAVE FRONT
# -----------------------------------------------------------------------------

func _build_wave_front_only() -> void:
	var layer: Node2D = get_layer("WaveFrontLayer")
	if layer == null or layer.get_node_or_null("WaveFrontArt") != null:
		return

	var texture: Texture2D = _load_texture(WAVE_FRONT_TEXTURE_PATH)
	if texture == null:
		return

	var texture_size: Vector2 = texture.get_size()
	if texture_size.x <= 0.0 or texture_size.y <= 0.0:
		return

	var root: Node2D = Node2D.new()
	root.name = "WaveFrontArt"
	layer.add_child(root)

	# On dalga mevcut hareketli beyaz Line2D'nin hemen altinda kalir.
	# Uzun 2048px civari parcalar + ayna sirasi ile kisa tekrar hissi olusmaz.
	var target_height: float = 24.0
	var x_scale: float = 1.10
	var y_scale: float = target_height / texture_size.y
	var tile_width: float = texture_size.x * x_scale
	var center_y: float = WATER_SURFACE_Y + 5.0
	var x: float = WORLD_LEFT_X + tile_width * 0.5
	var tile_index: int = 0

	while x < WORLD_RIGHT_X + tile_width * 0.5:
		var sprite: Sprite2D = Sprite2D.new()
		sprite.name = "WaveFront_%02d" % tile_index
		sprite.texture = texture
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite.position = Vector2(x, center_y)
		sprite.scale = Vector2((-x_scale) if tile_index % 2 == 1 else x_scale, y_scale)
		sprite.modulate = Color(0.90, 0.98, 1.0, 0.46)
		root.add_child(sprite)

		x += tile_width - 3.0
		tile_index += 1


func _add_tiled_strip(
	root: Node2D,
	texture: Texture2D,
	scale_factor: float,
	center_y: float,
	material: Material = null,
	overlap_px: float = 1.0,
	tint: Color = Color.WHITE
) -> void:
	var texture_size: Vector2 = texture.get_size()
	if texture_size.x <= 0.0 or texture_size.y <= 0.0:
		return

	var tile_width: float = maxf(texture_size.x * scale_factor, 1.0)
	var step_width: float = maxf(tile_width - overlap_px, 1.0)
	var x: float = WORLD_LEFT_X + tile_width * 0.5
	var tile_index: int = 0

	while x < WORLD_RIGHT_X + tile_width:
		var sprite: Sprite2D = Sprite2D.new()
		sprite.name = "Tile_%02d" % tile_index
		sprite.texture = texture
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite.position = Vector2(x, center_y)
		sprite.scale = Vector2.ONE * scale_factor
		sprite.modulate = tint
		if material != null:
			sprite.material = material
		root.add_child(sprite)

		x += step_width
		tile_index += 1


func _load_texture(path: String) -> Texture2D:
	if not ResourceLoader.exists(path):
		push_warning("ENVIRONMENT asset bulunamadi: " + path)
		return null

	var texture: Texture2D = load(path) as Texture2D
	if texture == null:
		push_warning("ENVIRONMENT texture yuklenemedi: " + path)
	return texture


func _ensure_parallax(node_name: String, scroll_scale_value: Vector2) -> Parallax2D:
	var existing: Parallax2D = _environment_root.get_node_or_null(node_name) as Parallax2D
	if existing != null:
		existing.scroll_scale = scroll_scale_value
		return existing

	var parallax: Parallax2D = Parallax2D.new()
	parallax.name = node_name
	parallax.scroll_scale = scroll_scale_value
	_environment_root.add_child(parallax)
	return parallax


func _ensure_node2d(parent: Node, node_name: String, z_value: int) -> Node2D:
	var existing: Node2D = parent.get_node_or_null(node_name) as Node2D
	if existing != null:
		existing.z_index = z_value
		return existing

	var node: Node2D = Node2D.new()
	node.name = node_name
	node.z_index = z_value
	parent.add_child(node)
	return node


func _register_layer(layer_name: String, layer: Node2D) -> void:
	if layer != null:
		_layers[layer_name] = layer


func get_layer(layer_name: String) -> Node2D:
	return _layers.get(layer_name) as Node2D


func get_depth_zone(depth_m: float) -> String:
	if depth_m < 20.0:
		return ZONE_SHALLOW
	if depth_m < 50.0:
		return ZONE_OPEN_BLUE
	if depth_m < 80.0:
		return ZONE_DEEP
	return ZONE_ABYSS


func get_zone_depth_range(zone: String) -> Vector2:
	match zone:
		ZONE_SHALLOW:
			return Vector2(0.0, 20.0)
		ZONE_OPEN_BLUE:
			return Vector2(20.0, 50.0)
		ZONE_DEEP:
			return Vector2(50.0, 80.0)
		ZONE_ABYSS:
			return Vector2(80.0, 100.0)
		_:
			return Vector2(0.0, 100.0)


func get_zone_density(zone: String) -> float:
	match zone:
		ZONE_SHALLOW:
			return 0.72
		ZONE_OPEN_BLUE:
			return 0.62
		ZONE_DEEP:
			return 0.45
		ZONE_ABYSS:
			return 0.28
		_:
			return 0.0


func make_deterministic_rng(salt: int = 0) -> RandomNumberGenerator:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = DECOR_SEED + salt
	return rng


func get_safe_horizontal_spawn_range() -> Vector2:
	return Vector2(1400.0, WORLD_RIGHT_X - 300.0)


func get_surface_y() -> float:
	return WATER_SURFACE_Y
