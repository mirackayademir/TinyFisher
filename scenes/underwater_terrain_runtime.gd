extends Node

# TinyFisher 20-100m collision'siz arka-plan reef terrain runtime.
# TEK PNG kullanilir: tile, tekrar, satir veya parallax YOK.
# Baliklar ve kanca terrain'in onunden gecer.

const TERRAIN_TEXTURE_PATH: String = "res://assets/environment/terrain/underwater_terrain_20_100.png"
const TERRAIN_NODE_NAME: String = "UnderwaterReefTerrain20To100"
const LAYOUT_VERSION: int = 6

const WORLD_LEFT_X: float = -1000.0
const WORLD_RIGHT_X: float = 11000.0
const START_DEPTH_METERS: float = 20.0
const END_DEPTH_METERS: float = 100.0

# Onaylanan gorselin ustundeki bos seffaf alani atiyoruz.
# Mevcut PNG 1280x720 ve asil terrain yaklasik y=60'ta basliyor.
const CROP_TOP_PX: float = 60.0
const CROP_BOTTOM_PX: float = 6.0

var _scene_id: int = 0
var _world: Node2D = null
var _terrain_root: Node2D = null
var _terrain_texture: Texture2D = null
var _load_failed: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	print("UNDERWATER TERRAIN V6: tek sabit 20-100m PNG")


func _process(_delta: float) -> void:
	var current_scene: Node = get_tree().current_scene
	if current_scene == null:
		return

	var current_id: int = current_scene.get_instance_id()
	if current_id != _scene_id:
		_scene_id = current_id
		_world = current_scene as Node2D
		_terrain_root = null
		_load_failed = false

	if _world == null or _load_failed:
		return

	_ensure_terrain()


func _ensure_terrain() -> void:
	if is_instance_valid(_terrain_root):
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

	var crop_top: float = clampf(CROP_TOP_PX, 0.0, source_size.y - 1.0)
	var crop_bottom: float = clampf(CROP_BOTTOM_PX, 0.0, source_size.y - crop_top - 1.0)
	var crop_height: float = source_size.y - crop_top - crop_bottom

	var atlas: AtlasTexture = AtlasTexture.new()
	atlas.atlas = texture
	atlas.region = Rect2(0.0, crop_top, source_size.x, crop_height)

	var y_start: float = _world_y_for_depth(START_DEPTH_METERS)
	var y_end: float = _world_y_for_depth(END_DEPTH_METERS)
	if y_end <= y_start:
		push_error("UNDERWATER TERRAIN: 20-100m Y araligi gecersiz")
		_load_failed = true
		return

	var world_width: float = WORLD_RIGHT_X - WORLD_LEFT_X
	var terrain_height: float = y_end - y_start
	var atlas_size: Vector2 = atlas.get_size()

	_terrain_root = Node2D.new()
	_terrain_root.name = TERRAIN_NODE_NAME
	_terrain_root.z_as_relative = false
	_terrain_root.z_index = -7
	_terrain_root.set_meta("layout_version", LAYOUT_VERSION)
	_terrain_root.set_meta("collisionless", true)
	_world.add_child(_terrain_root)

	var sprite: Sprite2D = Sprite2D.new()
	sprite.name = "ReefTerrainSingleArt"
	sprite.texture = atlas
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.centered = true
	sprite.position = Vector2(
		WORLD_LEFT_X + world_width * 0.5,
		y_start + terrain_height * 0.5
	)

	# Kullanici istegi: gorseli denizin 20-100m dikdortgenine TAM OTURT.
	# Aspect ratio korunmuyor; tek gorsel tum alan boyunca bir kez geriliyor.
	sprite.scale = Vector2(
		world_width / atlas_size.x,
		terrain_height / atlas_size.y
	)

	# Arka-plan / fake-3D hissi icin hafif soluk.
	sprite.modulate = Color(0.82, 0.90, 0.94, 0.74)
	_terrain_root.add_child(sprite)

	print(
		"UNDERWATER TERRAIN V6 OK | SINGLE IMAGE | source=", source_size,
		" crop=", atlas_size,
		" world_x=", Vector2(WORLD_LEFT_X, WORLD_RIGHT_X),
		" depth_y=", Vector2(y_start, y_end),
		" collision=OFF | repeat=OFF"
	)


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
		push_error(
			"UNDERWATER TERRAIN: PNG OKUNAMADI | error=%d | %s"
			% [err, absolute_path]
		)
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


func _world_y_for_depth(depth_meters: float) -> float:
	var boat: Node2D = _world.get_node_or_null("Boat") as Node2D
	var hook: Node2D = _world.get_node_or_null("Boat/Hook") as Node2D
	if boat == null or hook == null:
		return 392.6 + depth_meters * 34.5

	var max_depth_pixels: float = float(hook.get("max_depth"))
	var max_depth_meters: float = float(hook.get("max_depth_meters"))
	var hook_start_y: float = hook.position.y
	var start_variant: Variant = hook.get("start_position")
	if start_variant is Vector2:
		hook_start_y = (start_variant as Vector2).y

	if max_depth_pixels <= 0.0 or max_depth_meters <= 0.0:
		return 392.6 + depth_meters * 34.5

	var pixels_per_meter: float = max_depth_pixels / max_depth_meters
	return boat.global_position.y + hook_start_y + depth_meters * pixels_per_meter
