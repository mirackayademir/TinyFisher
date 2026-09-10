extends Node

# TinyFisher katmanli dunya altyapisi.
# 36 parcalik environment seti bu autoload tarafindan katmanlara yerlestirilir.
# Her sey gorseldir; balik, kanca, tekne ve liman oynanisina fizik eklemez.

const ENV_ROOT_NAME: String = "EnvironmentLayers"
const DECOR_SEED: int = 9042026
const WATER_SURFACE_Y: float = 360.0
const WORLD_LEFT_X: float = -1000.0
const WORLD_RIGHT_X: float = 11000.0

# World.tscn icindeki Sky=-10 ve Water=-9. Yeni cizimler bunlarin ustunde,
# baliklarin (z=0) ve teknenin (z=2) arkasinda kalir.
const Z_SKY_BASE: int = -8
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

const SURFACE_PATH: String = "res://assets/environment/surface/"

var _scene_id: int = 0
var _world: Node2D = null
var _environment_root: Node2D = null
var _layers: Dictionary = {}
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.seed = DECOR_SEED
	print("ENVIRONMENT LAYERS V2: 36 ASSET KATMAN SISTEMI HAZIR")


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

	_environment_root = _world.get_node_or_null(ENV_ROOT_NAME) as Node2D
	if _environment_root == null:
		_environment_root = Node2D.new()
		_environment_root.name = ENV_ROOT_NAME
		_world.add_child(_environment_root)

	_build_layer_tree()
	_build_surface_art()
	print("ENVIRONMENT LAYERS: katmanlar + yuzey seti kuruldu")


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
# 1/6 - SURFACE (8 GORSEL)
# -----------------------------------------------------------------------------

func _build_surface_art() -> void:
	# 1) Ana gokyuzu. Yatayda tekrar eder; mevcut sunset shader bosluklarda taban olur.
	_add_horizontal_strip(
		"SkyBaseLayer",
		"SkyBaseArt",
		SURFACE_PATH + "sky_base_01.png",
		-70.0,
		860.0,
		Color.WHITE
	)

	# 2) Gunes. Ufuk cizgisinin ustunde ve limandan biraz ileride gorunur.
	_add_fitted_sprite(
		"SunLayer",
		"SunArt",
		SURFACE_PATH + "sun_01_TEMP.png",
		Vector2(2350.0, 95.0),
		Vector2(190.0, 190.0),
		Color(1.0, 1.0, 1.0, 0.96)
	)

	# 3) Uzak kara silueti. Su cizgisine oturur ve parallax katmaninda kalir.
	_add_horizontal_strip(
		"HorizonLandLayer",
		"HorizonLandArt",
		SURFACE_PATH + "horizon_land_01.png",
		305.0,
		150.0,
		Color(0.88, 0.92, 1.0, 0.92)
	)

	# 4) Deniz yuzeyi tabani. Sadece ust su bolgesini kaplar; derinlik shaderi altta devam eder.
	_add_horizontal_strip(
		"OceanSurfaceLayer",
		"OceanSurfaceArt",
		SURFACE_PATH + "ocean_surface_base_01.png",
		535.0,
		350.0,
		Color(1.0, 1.0, 1.0, 0.90)
	)

	# 5) Arkadaki dalga sirasi.
	_add_horizontal_strip(
		"WaveBackLayer",
		"WaveBackArt",
		SURFACE_PATH + "wave_back_01.png",
		354.0,
		58.0,
		Color(1.0, 1.0, 1.0, 0.82)
	)

	# 6) Ondeki dalga sirasi.
	_add_horizontal_strip(
		"WaveFrontLayer",
		"WaveFrontArt",
		SURFACE_PATH + "wave_front_01.png",
		371.0,
		72.0,
		Color(1.0, 1.0, 1.0, 0.92)
	)

	# 7) Kopuk. Teknenin ve baliklarin arkasinda, su cizgisinin hemen altinda.
	_add_horizontal_strip(
		"SurfaceFoamLayer",
		"SurfaceFoamArt",
		SURFACE_PATH + "surface_foam_01.png",
		382.0,
		42.0,
		Color(1.0, 1.0, 1.0, 0.74)
	)

	# 8) Gunes huzmeleri. Yuzeyden sig suya dogru yumusak gecis verir.
	_add_horizontal_strip(
		"SunRaysLayer",
		"SunRaysArt",
		SURFACE_PATH + "sun_rays_01.png",
		650.0,
		560.0,
		Color(1.0, 1.0, 1.0, 0.34)
	)


func _add_horizontal_strip(
	layer_name: String,
	root_name: String,
	texture_path: String,
	center_y: float,
	target_height: float,
	tint: Color
) -> void:
	var layer: Node2D = get_layer(layer_name)
	if layer == null or layer.get_node_or_null(root_name) != null:
		return

	var texture: Texture2D = _load_texture(texture_path)
	if texture == null:
		return

	var texture_size: Vector2 = texture.get_size()
	if texture_size.x <= 0.0 or texture_size.y <= 0.0:
		return

	var root: Node2D = Node2D.new()
	root.name = root_name
	layer.add_child(root)

	var scale_factor: float = target_height / texture_size.y
	var tile_width: float = maxf(texture_size.x * scale_factor, 1.0)
	var x: float = WORLD_LEFT_X + tile_width * 0.5
	var tile_index: int = 0

	while x < WORLD_RIGHT_X + tile_width * 0.5:
		var sprite: Sprite2D = Sprite2D.new()
		sprite.name = "Tile_%02d" % tile_index
		sprite.texture = texture
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite.position = Vector2(x, center_y)
		sprite.scale = Vector2.ONE * scale_factor
		sprite.modulate = tint
		root.add_child(sprite)

		x += tile_width - 1.0
		tile_index += 1


func _add_fitted_sprite(
	layer_name: String,
	node_name: String,
	texture_path: String,
	world_position: Vector2,
	max_size: Vector2,
	tint: Color
) -> void:
	var layer: Node2D = get_layer(layer_name)
	if layer == null or layer.get_node_or_null(node_name) != null:
		return

	var texture: Texture2D = _load_texture(texture_path)
	if texture == null:
		return

	var texture_size: Vector2 = texture.get_size()
	if texture_size.x <= 0.0 or texture_size.y <= 0.0:
		return

	var fit_scale: float = minf(
		max_size.x / texture_size.x,
		max_size.y / texture_size.y
	)

	var sprite: Sprite2D = Sprite2D.new()
	sprite.name = node_name
	sprite.texture = texture
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.position = world_position
	sprite.scale = Vector2.ONE * fit_scale
	sprite.modulate = tint
	layer.add_child(sprite)


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
	# Liman cevresine RNG dekor sokmuyoruz. Ilk 1400 px elle tasarlanacak.
	return Vector2(1400.0, WORLD_RIGHT_X - 300.0)


func get_surface_y() -> float:
	return WATER_SURFACE_Y
