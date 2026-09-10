extends Node

# TinyFisher 20-100m fake-3D arka-plan terrain.
# Bu surumde ekranda YALNIZCA TEK Sprite2D vardir.
# Crop / parca / tile / tekrar / ani visible pop-in yoktur.
# Terrain kaynak verisi text parcalari halinde saklanir ve runtime'da tek texture'a donusturulur.
# 418x690 pixel-art kaynak 4x nearest ile 1672x2760 olur.
# 2760 px = oyunun 20m -> 100m fiziksel derinlik araligi.
# Collision yoktur; baliklar ve kanca terrain'in onunden gecer.

const TERRAIN_NODE_NAME: String = "UnderwaterReefTerrain20To100"
const LAYOUT_VERSION: int = 10
const TERRAIN_TOP_DEPTH_METERS: float = 20.0

const SOURCE_WIDTH: int = 418
const SOURCE_HEIGHT: int = 690
const PALETTE_COUNT: int = 128
const DISPLAY_SCALE: float = 4.0
const DISPLAY_WIDTH: float = 1672.0
const DISPLAY_HEIGHT: float = 2760.0
const RAW_DATA_SIZE: int = 288938

const DATA_PART_PATHS: Array[String] = [
	"res://assets/environment/terrain/runtime_data/terrain_20_100_part0.txt",
	"res://assets/environment/terrain/runtime_data/terrain_20_100_part1.txt",
	"res://assets/environment/terrain/runtime_data/terrain_20_100_part2.txt",
	"res://assets/environment/terrain/runtime_data/terrain_20_100_part3.txt",
	"res://assets/environment/terrain/runtime_data/terrain_20_100_part4.txt",
	"res://assets/environment/terrain/runtime_data/terrain_20_100_part5.txt",
	"res://assets/environment/terrain/runtime_data/terrain_20_100_part6.txt"
]

var _scene_id: int = 0
var _world: Node2D = null
var _camera: Camera2D = null
var _terrain_root: Node2D = null
var _terrain_sprite: Sprite2D = null
var _terrain_texture: Texture2D = null
var _load_failed: bool = false
var _terrain_top_y: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	print("UNDERWATER TERRAIN V10: single exact 20-100m texture / crop OFF / tile OFF")


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
		_terrain_top_y = 0.0

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
	_terrain_top_y = 0.0


func _ensure_terrain() -> void:
	if is_instance_valid(_terrain_root) and is_instance_valid(_terrain_sprite):
		return
	if _load_failed:
		return

	_remove_old_terrain()

	var texture: Texture2D = _build_texture_from_encoded_data()
	if texture == null:
		_load_failed = true
		return

	_terrain_texture = texture
	_terrain_top_y = _world_y_for_depth(TERRAIN_TOP_DEPTH_METERS)

	_terrain_root = Node2D.new()
	_terrain_root.name = TERRAIN_NODE_NAME
	_terrain_root.z_as_relative = false
	# Water -9. Terrain -7: su gorunur, terrain suyun icinde; oynanis objeleri onunde.
	_terrain_root.z_index = -7
	_terrain_root.set_meta("layout_version", LAYOUT_VERSION)
	_terrain_root.set_meta("collisionless", true)
	_world.add_child(_terrain_root)

	_terrain_sprite = Sprite2D.new()
	_terrain_sprite.name = "ReefTerrainArt"
	_terrain_sprite.texture = _terrain_texture
	_terrain_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_terrain_sprite.centered = false
	_terrain_sprite.scale = Vector2(DISPLAY_SCALE, DISPLAY_SCALE)
	# 1672 genislik, 1280 kadrajdan 196px sola + 196px saga tasar.
	# Bu sayede oran bozulmaz; X stretch yapilmaz.
	_terrain_sprite.position = Vector2(-DISPLAY_WIDTH * 0.5, 0.0)
	_terrain_sprite.modulate = Color(0.82, 0.90, 0.95, 0.88)
	_terrain_sprite.z_index = 0
	_terrain_root.add_child(_terrain_sprite)

	_update_horizontal_alignment()

	var ppm: float = _pixels_per_meter()
	var expected_height: float = 80.0 * ppm
	print(
		"UNDERWATER TERRAIN V10 OK | source=", Vector2(SOURCE_WIDTH, SOURCE_HEIGHT),
		" | display=", Vector2(DISPLAY_WIDTH, DISPLAY_HEIGHT),
		" | expected_20_100_height=", expected_height,
		" | sprite_count=1 | collision=OFF"
	)


func _update_horizontal_alignment() -> void:
	if not is_instance_valid(_terrain_root) or not is_instance_valid(_camera):
		return

	# X kadraja kilitli: tekne saga/sola giderken terrain ekranda kaymaz.
	# Y ASLA kamerayi takip etmez: 20-100m dunya derinliginde fiziksel olarak sabittir.
	_terrain_root.global_position = Vector2(_camera.global_position.x, _terrain_top_y)


func _build_texture_from_encoded_data() -> Texture2D:
	var encoded: String = ""
	for path: String in DATA_PART_PATHS:
		if not FileAccess.file_exists(path):
			push_error("UNDERWATER TERRAIN: veri parcasi yok | " + path)
			return null
		encoded += FileAccess.get_file_as_string(path).strip_edges()

	if encoded.is_empty():
		push_error("UNDERWATER TERRAIN: encoded terrain verisi bos")
		return null

	var compressed: PackedByteArray = Marshalls.base64_to_raw(encoded)
	if compressed.is_empty():
		push_error("UNDERWATER TERRAIN: base64 decode basarisiz")
		return null

	var raw: PackedByteArray = compressed.decompress(RAW_DATA_SIZE, FileAccess.COMPRESSION_GZIP)
	if raw.size() != RAW_DATA_SIZE:
		push_error(
			"UNDERWATER TERRAIN: gzip decode boyutu hatali | got=%d expected=%d"
			% [raw.size(), RAW_DATA_SIZE]
		)
		return null

	var width: int = raw.decode_u16(0)
	var height: int = raw.decode_u16(2)
	var palette_count: int = raw.decode_u16(4)
	if width != SOURCE_WIDTH or height != SOURCE_HEIGHT or palette_count != PALETTE_COUNT:
		push_error(
			"UNDERWATER TERRAIN: header hatali | %dx%d palette=%d"
			% [width, height, palette_count]
		)
		return null

	var palette_offset: int = 6
	var indices_offset: int = palette_offset + palette_count * 4
	var pixel_count: int = width * height
	if raw.size() < indices_offset + pixel_count:
		push_error("UNDERWATER TERRAIN: pixel verisi eksik")
		return null

	var rgba: PackedByteArray = PackedByteArray()
	rgba.resize(pixel_count * 4)

	for pixel_index: int in range(pixel_count):
		var palette_index: int = int(raw[indices_offset + pixel_index])
		if palette_index < 0 or palette_index >= palette_count:
			palette_index = 0

		var palette_pos: int = palette_offset + palette_index * 4
		var out_pos: int = pixel_index * 4
		rgba[out_pos] = raw[palette_pos]
		rgba[out_pos + 1] = raw[palette_pos + 1]
		rgba[out_pos + 2] = raw[palette_pos + 2]
		rgba[out_pos + 3] = raw[palette_pos + 3]

	var image: Image = Image.create_from_data(
		width,
		height,
		false,
		Image.FORMAT_RGBA8,
		rgba
	)
	if image == null or image.is_empty():
		push_error("UNDERWATER TERRAIN: Image olusturulamadi")
		return null

	return ImageTexture.create_from_image(image)


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
