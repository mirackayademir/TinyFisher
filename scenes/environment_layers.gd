extends Node

# TinyFisher katmanli dunya altyapisi.
# 36 environment gorseli TEK TEK eklenecek.
# Su an sadece 1. gorsel aktif: sky_base_01.png

const ENV_ROOT_NAME: String = "EnvironmentLayers"
const DECOR_SEED: int = 9042026
const WATER_SURFACE_Y: float = 360.0
const WORLD_LEFT_X: float = -1000.0
const WORLD_RIGHT_X: float = 11000.0

# Sky assetinin en altindaki sert bant kirpilir; kalan ufuk bandi da
# denizin arkasina sokularak su cizgisinin altinda gizlenir.
const SKY_BOTTOM_CROP_PX: float = 14.0
const SKY_WATER_OVERLAP_PX: float = 42.0

# Siralama: eski shader gokyuzu en arkada, yeni sky onun ustunde,
# Water ise ikisinin de ustunde. Boylece sky denizin ustune tasmaz.
const Z_LEGACY_SKY: int = -11
const Z_SKY_BASE: int = -10
const Z_SUN: int = -7
const Z_HORIZON: int = -6
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

var _scene_id: int = 0
var _world: Node2D = null
var _environment_root: Node2D = null
var _layers: Dictionary = {}
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.seed = DECOR_SEED
	print("ENVIRONMENT LAYERS V5: SKY UFUK BANDI SU ALTINA GIZLENDI")


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
	print("ENVIRONMENT: sadece SKY 1/36 aktif - ufuk bandi su arkasinda")


func _prepare_base_layer_order() -> void:
	# Eski shader gokyuzu fallback olarak en arkada kalir.
	var legacy_sky: CanvasItem = _world.get_node_or_null("Sky") as CanvasItem
	if legacy_sky != null:
		legacy_sky.z_index = Z_LEGACY_SKY

	# Water mevcut z=-9 degerinde kalir ve yeni sky'i orter.
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

	var runtime_decor: Node2D = _ensure_node2d(_environment_root, "RuntimeDecor", 0)
	_register_layer("RuntimeDecor", runtime_decor)


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
	cropped_texture.region = Rect2(
		0.0,
		0.0,
		source_size.x,
		source_size.y - SKY_BOTTOM_CROP_PX
	)

	var texture_size: Vector2 = cropped_texture.get_size()
	if texture_size.x <= 0.0 or texture_size.y <= 0.0:
		return

	var root: Node2D = Node2D.new()
	root.name = "SkyBaseArt"
	layer.add_child(root)

	var target_height: float = 860.0
	var scale_factor: float = target_height / texture_size.y

	# Sky'in alt 42 ekran-piksellik kismi Water'in arkasina girer.
	# Asset icindeki duz turuncu ufuk bandi artik suyun ustunde gorunemez.
	var center_y: float = WATER_SURFACE_Y + SKY_WATER_OVERLAP_PX - (target_height * 0.5)
	var tile_width: float = maxf(texture_size.x * scale_factor, 1.0)
	var x: float = WORLD_LEFT_X + tile_width * 0.5
	var tile_index: int = 0

	while x < WORLD_RIGHT_X + tile_width * 0.5:
		var sprite: Sprite2D = Sprite2D.new()
		sprite.name = "Tile_%02d" % tile_index
		sprite.texture = cropped_texture
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite.position = Vector2(x, center_y)
		sprite.scale = Vector2.ONE * scale_factor
		root.add_child(sprite)

		x += tile_width - 1.0
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
