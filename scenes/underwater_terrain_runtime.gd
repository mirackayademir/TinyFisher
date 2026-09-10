extends Node

# TinyFisher fake-3D arka-plan terrain.
# Onaylanan terrain gorseli TEK PARCA kullanilir.
# Tile / tekrar / 20-100m stretch YOK.
# Gorsel dunyada sabit bir Y derinliginde durur; kamera asagi indikce DOGAL olarak kadraja girer.
# X ekseninde kamera kadrajina hizali kalir. Collision yoktur; baliklar ve kanca onunden gecer.

const TERRAIN_TEXTURE_PATH: String = "res://assets/environment/terrain/underwater_terrain_20_100.png"
const TERRAIN_NODE_NAME: String = "UnderwaterReefTerrain20To100"
const LAYOUT_VERSION: int = 8

# Kamera 720px yukseklikte oldugu icin terrain'i tam 20m dunya-Y'sine koyarsak
# oyuncu 20m'ye gelmeden alt kenari gorur. 24m civari baslatmak, terrain'in ekrana
# yaklasik 20m civarinda yavasca girmesini saglar.
const TERRAIN_ART_TOP_DEPTH_METERS: float = 24.0

var _scene_id: int = 0
var _world: Node2D = null
var _camera: Camera2D = null
var _terrain_root: Node2D = null
var _terrain_sprite: Sprite2D = null
var _terrain_texture: Texture2D = null
var _load_failed: bool = false
var _drawn_height: float = 0.0
var _terrain_center_y: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	print("UNDERWATER TERRAIN V8: world-depth placement / no pop-in / no tile")


func _process(_delta: float) -> void:
	var current_scene: Node = get_tree().current_scene
	if current_scene == null:
		_reset_refs()
		return

	var current_id: int = current_scene.get_instance_id()
	if current_id != _scene_id:
		_scene_id = current_id
		_world = current_scene as Node2D
		_camera = null
		_terrain_root = null
		_terrain_sprite = null
		_load_failed = false
		_drawn_height = 0.0
		_terrain_center_y = 0.0

	if _world == null:
		return

	_camera = _world.get_node_or_null("Boat/Camera2D") as Camera2D
	if _camera == null:
		return

	_ensure_terrain()
	_update_horizontal_alignment()


func _reset_refs() -> void:
	_scene_id = 0
	_world = null
	_camera = null
	_terrain_root = null
	_terrain_sprite = null
	_load_failed = false
	_drawn_height = 0.0
	_terrain_center_y = 0.0


func _ensure_terrain() -> void:
	if is_instance_valid(_terrain_root) and is_instance_valid(_terrain_sprite):
		return
	if _load_failed:
		return

	_remove_old_terrain()

	var texture: Texture2D = _load_png_direct()
	if texture == null:
		_load_failed = true
		return

	var source_size: Vector2 = texture.get_size()
	if source_size.x <= 0.0 or source_size.y <= 0.0:
		push_error("UNDERWATER TERRAIN: texture boyutu gecersiz")
		_load_failed = true
		return

	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	if viewport_size.x <= 0.0:
		viewport_size = Vector2(1280.0, 720.0)

	# SADECE genislige sigdir. X/Y ayni scale: oran bozulmaz.
	# Kaynak 16:9'a yakin oldugu icin 1280 genislikte yaklasik 700px yukseklik olur.
	var fit_scale: float = viewport_size.x / source_size.x
	_drawn_height = source_size.y * fit_scale

	# Terrain'i dunyada gercek bir derinlige koy. Kamera asagi indikce sprite kadraja girer;
	# depth==20 oldugunda visible=true gibi ani bir acilma YOK.
	var terrain_top_y: float = _world_y_for_depth(TERRAIN_ART_TOP_DEPTH_METERS)
	_terrain_center_y = terrain_top_y + _drawn_height * 0.5

	_terrain_root = Node2D.new()
	_terrain_root.name = TERRAIN_NODE_NAME
	_terrain_root.z_as_relative = false
	# Water -9. Terrain -7: suyun onunde, balik/kancanin arkasinda.
	_terrain_root.z_index = -7
	_terrain_root.set_meta("layout_version", LAYOUT_VERSION)
	_terrain_root.set_meta("collisionless", true)
	_world.add_child(_terrain_root)

	_terrain_sprite = Sprite2D.new()
	_terrain_sprite.name = "ReefTerrainArt"
	_terrain_sprite.texture = texture
	_terrain_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_terrain_sprite.centered = true
	_terrain_sprite.scale = Vector2.ONE * fit_scale
	_terrain_sprite.position = Vector2.ZERO
	_terrain_sprite.z_index = 0
	# Arka-plan hissi; DeepSeaAtmosphere zaten derinlige gore ekstra karartiyor.
	_terrain_sprite.modulate = Color(0.76, 0.86, 0.92, 0.82)
	_terrain_root.add_child(_terrain_sprite)

	_update_horizontal_alignment()

	var pixels_per_meter: float = _pixels_per_meter()
	var visual_depth_span: float = _drawn_height / maxf(pixels_per_meter, 0.001)
	print(
		"UNDERWATER TERRAIN V8 OK | source=", source_size,
		" | drawn=", Vector2(viewport_size.x, _drawn_height),
		" | top_depth=", TERRAIN_ART_TOP_DEPTH_METERS,
		"m | approx_bottom_depth=", TERRAIN_ART_TOP_DEPTH_METERS + visual_depth_span,
		"m | collision=OFF"
	)


func _update_horizontal_alignment() -> void:
	if not is_instance_valid(_terrain_root) or not is_instance_valid(_camera):
		return

	# Y asla kamerayi takip etmez: terrain dunyada kendi derinliginde sabittir.
	# X, 1280px kadraji her zaman doldurmak icin kamera merkezine hizalanir.
	# Bu parallax degildir; terrain ekranda saga-sola bagimsiz kaymaz.
	_terrain_root.global_position = Vector2(_camera.global_position.x, _terrain_center_y)


func _pixels_per_meter() -> float:
	var hook: Node2D = _world.get_node_or_null("Boat/Hook") as Node2D
	if hook == null:
		return 34.5

	var max_depth_pixels: float = float(hook.get("max_depth"))
	var max_depth_meters: float = float(hook.get("max_depth_meters"))
	if max_depth_pixels <= 0.0 or max_depth_meters <= 0.0:
		return 34.5

	return max_depth_pixels / max_depth_meters


func _world_y_for_depth(depth_meters: float) -> float:
	var boat: Node2D = _world.get_node_or_null("Boat") as Node2D
	var hook: Node2D = _world.get_node_or_null("Boat/Hook") as Node2D
	if boat == null or hook == null:
		return 392.6 + depth_meters * 34.5

	var hook_start_y: float = hook.position.y
	var start_variant: Variant = hook.get("start_position")
	if start_variant is Vector2:
		hook_start_y = (start_variant as Vector2).y

	return boat.global_position.y + hook_start_y + depth_meters * _pixels_per_meter()


func _load_png_direct() -> Texture2D:
	if _terrain_texture != null:
		return _terrain_texture

	var absolute_path: String = ProjectSettings.globalize_path(TERRAIN_TEXTURE_PATH)
	if not FileAccess.file_exists(absolute_path):
		push_error("UNDERWATER TERRAIN: PNG DOSYASI YOK | " + absolute_path)
		return null

	var image: Image = Image.new()
	var err: Error = image.load(absolute_path)
	if err != OK:
		push_error("UNDERWATER TERRAIN: PNG OKUNAMADI | error=%d | %s" % [err, absolute_path])
		return null

	if image.get_width() <= 0 or image.get_height() <= 0:
		push_error("UNDERWATER TERRAIN: PNG bos image verdi")
		return null

	_terrain_texture = ImageTexture.create_from_image(image)
	return _terrain_texture


func _remove_old_terrain() -> void:
	var old_direct: Node = _world.get_node_or_null(TERRAIN_NODE_NAME)
	if old_direct != null:
		_world.remove_child(old_direct)
		old_direct.queue_free()

	var background_layer: Node = _world.get_node_or_null(
		"EnvironmentLayers/UnderwaterLayers/BackgroundDecorLayer"
	)
	if background_layer != null:
		var old_background: Node = background_layer.get_node_or_null(TERRAIN_NODE_NAME)
		if old_background != null:
			background_layer.remove_child(old_background)
			old_background.queue_free()

		var old_foundation: Node = background_layer.get_node_or_null("UnderwaterTerrainFoundation")
		if old_foundation != null:
			background_layer.remove_child(old_foundation)
			old_foundation.queue_free()
