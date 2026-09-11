extends Node

# High-quality 20-100 m canyon terrain.
# The accepted source art is stored as lossless base64 text chunks in Git,
# reconstructed in memory at runtime, and fitted mathematically to the real
# Water world bounds + live hook depth scale. It never follows the camera.

const TERRAIN_NODE_NAME := "UnderwaterCanyonTerrain20To100"
const LAYOUT_VERSION := 18

const TOP_M := 20.0
const BOTTOM_M := 100.0
const SOURCE_CROP_TOP_PX := 27
const EXPECTED_SOURCE_WIDTH := 2048
const EXPECTED_SOURCE_HEIGHT := 682
const EXPECTED_BASE64_LENGTH := 165516

# IMPORTANT: part_02a and part_02b are continuations of part_02, not
# replacements. The complete verified payload order is therefore:
# 00 -> 01 -> 02 -> 02a -> 02b -> 03 -> 04 -> 05 -> 06 -> 07.
const LOSSLESS_PART_PATHS := [
	"res://assets/environment/terrain/runtime_data/hq_lossless/part_00.txt",
	"res://assets/environment/terrain/runtime_data/hq_lossless/part_01.txt",
	"res://assets/environment/terrain/runtime_data/hq_lossless/part_02.txt",
	"res://assets/environment/terrain/runtime_data/hq_lossless/part_02a.txt",
	"res://assets/environment/terrain/runtime_data/hq_lossless/part_02b.txt",
	"res://assets/environment/terrain/runtime_data/hq_lossless/part_03.txt",
	"res://assets/environment/terrain/runtime_data/hq_lossless/part_04.txt",
	"res://assets/environment/terrain/runtime_data/hq_lossless/part_05.txt",
	"res://assets/environment/terrain/runtime_data/hq_lossless/part_06.txt",
	"res://assets/environment/terrain/runtime_data/hq_lossless/part_07.txt"
]

const FALLBACK_LEFT := -1000.0
const FALLBACK_RIGHT := 11000.0
const FALLBACK_PPM := 34.5
const FALLBACK_ZERO_Y := 392.6
const TERRAIN_Z := -7

var _scene_id := 0
var _world: Node2D
var _root: Node2D
var _sprite: Sprite2D
var _source_region := Rect2()
var _terrain_texture: Texture2D
var _last_left := INF
var _last_width := INF
var _last_top_y := INF
var _last_height := INF


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	print("UNDERWATER TERRAIN V18: LOSSLESS CHUNK RUNTIME / EXACT 20-100M MAP FIT")


func _process(_delta: float) -> void:
	var scene := get_tree().current_scene
	if scene == null:
		_reset()
		return

	if scene.get_instance_id() != _scene_id:
		_scene_id = scene.get_instance_id()
		_world = scene as Node2D
		_root = null
		_sprite = null
		_last_left = INF
		_last_width = INF
		_last_top_y = INF
		_last_height = INF

	if _world == null:
		return

	_ensure_terrain()
	_fit_to_world()


func _reset() -> void:
	_scene_id = 0
	_world = null
	_root = null
	_sprite = null
	_last_left = INF
	_last_width = INF
	_last_top_y = INF
	_last_height = INF


func _ensure_terrain() -> void:
	if is_instance_valid(_root) and is_instance_valid(_sprite):
		return

	_remove_old_terrain()

	if _terrain_texture == null:
		_terrain_texture = _build_lossless_texture()
	if _terrain_texture == null:
		return

	var source_width := _terrain_texture.get_width()
	var source_height := _terrain_texture.get_height()
	if source_width <= 0 or source_height <= SOURCE_CROP_TOP_PX:
		push_error("HQ terrain texture boyutu gecersiz: %dx%d" % [source_width, source_height])
		return

	_source_region = Rect2(
		0.0,
		float(SOURCE_CROP_TOP_PX),
		float(source_width),
		float(source_height - SOURCE_CROP_TOP_PX)
	)

	var atlas := AtlasTexture.new()
	atlas.atlas = _terrain_texture
	atlas.region = _source_region

	_root = Node2D.new()
	_root.name = TERRAIN_NODE_NAME
	_root.z_as_relative = false
	_root.z_index = TERRAIN_Z
	_root.set_meta("layout_version", LAYOUT_VERSION)
	_root.set_meta("collisionless", true)
	_root.set_meta("camera_locked", false)
	_root.set_meta("depth_top_m", TOP_M)
	_root.set_meta("depth_bottom_m", BOTTOM_M)
	_root.set_meta("texture_source", "hq_lossless_runtime_chunks")
	_world.add_child(_root)

	_sprite = Sprite2D.new()
	_sprite.name = "TerrainSpriteHQ"
	_sprite.centered = false
	_sprite.texture = atlas
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_sprite.position = Vector2.ZERO
	_sprite.z_index = 0
	_root.add_child(_sprite)

	_fit_to_world(true)


func _build_lossless_texture() -> Texture2D:
	var payload := ""

	for path_variant in LOSSLESS_PART_PATHS:
		var path := String(path_variant)
		if not FileAccess.file_exists(path):
			push_error("HQ terrain runtime parcasi eksik: " + path)
			return null

		var file := FileAccess.open(path, FileAccess.READ)
		if file == null:
			push_error("HQ terrain runtime parcasi acilamadi: " + path)
			return null

		var chunk := file.get_as_text()
		chunk = chunk.replace("\n", "")
		chunk = chunk.replace("\r", "")
		chunk = chunk.replace("\t", "")
		chunk = chunk.replace(" ", "")
		payload += chunk

	if payload.length() != EXPECTED_BASE64_LENGTH:
		push_error(
			"HQ terrain payload uzunlugu hatali. Beklenen=%d Gelen=%d" % [
				EXPECTED_BASE64_LENGTH,
				payload.length()
			]
		)
		return null

	if payload.length() % 4 != 0:
		push_error("HQ terrain base64 payload 4-byte hizasinda degil.")
		return null

	var raw := Marshalls.base64_to_raw(payload)
	if raw.is_empty():
		push_error("HQ terrain base64 decode bos veri dondurdu.")
		return null

	var image := Image.new()
	var decode_error := image.load_webp_from_buffer(raw)
	if decode_error != OK:
		# Kept as a safety decoder only; the verified source is expected to be WebP.
		decode_error = image.load_png_from_buffer(raw)

	if decode_error != OK or image.is_empty():
		push_error("HQ terrain runtime gorseli decode edilemedi. Error=%d" % decode_error)
		return null

	if image.get_width() != EXPECTED_SOURCE_WIDTH or image.get_height() != EXPECTED_SOURCE_HEIGHT:
		push_error(
			"HQ terrain kaynak boyutu dogrulanamadi. Beklenen=%dx%d Gelen=%dx%d" % [
				EXPECTED_SOURCE_WIDTH,
				EXPECTED_SOURCE_HEIGHT,
				image.get_width(),
				image.get_height()
			]
		)
		return null

	print(
		"HQ TERRAIN OK: %d parca / %d base64 char / %d byte / %dx%d" % [
			LOSSLESS_PART_PATHS.size(),
			payload.length(),
			raw.size(),
			image.get_width(),
			image.get_height()
		]
	)

	return ImageTexture.create_from_image(image)


func _fit_to_world(force := false) -> void:
	if not is_instance_valid(_root) or not is_instance_valid(_sprite) or _world == null:
		return
	if _source_region.size.x <= 0.0 or _source_region.size.y <= 0.0:
		return

	var bounds := _get_world_horizontal_bounds()
	var left := bounds.x
	var width := maxf(bounds.y - bounds.x, 1.0)
	var top_y := _world_y_for_depth(TOP_M)
	var bottom_y := _world_y_for_depth(BOTTOM_M)
	var height := maxf(bottom_y - top_y, 1.0)

	if not force \
	and is_equal_approx(left, _last_left) \
	and is_equal_approx(width, _last_width) \
	and is_equal_approx(top_y, _last_top_y) \
	and is_equal_approx(height, _last_height):
		return

	# Exact map fit:
	# X -> complete Water width (-1000..11000 = 12000 px in world.tscn)
	# Y -> exact live 20..100 m band (34.5 px/m in current full-depth test).
	# Only the 27 fully-transparent source rows are cropped; every visible pixel
	# is mapped directly into the requested world/depth footprint.
	_root.global_position = Vector2(left, top_y)
	_root.scale = Vector2(
		width / _source_region.size.x,
		height / _source_region.size.y
	)

	_root.set_meta("map_left_x", left)
	_root.set_meta("map_right_x", bounds.y)
	_root.set_meta("world_y_20m", top_y)
	_root.set_meta("world_y_100m", bottom_y)
	_root.set_meta("source_visible_size", _source_region.size)
	_root.set_meta("fit_scale", _root.scale)

	_last_left = left
	_last_width = width
	_last_top_y = top_y
	_last_height = height


func _get_world_horizontal_bounds() -> Vector2:
	var water := _world.get_node_or_null("Water") as Control
	if water != null:
		var left := water.position.x
		var right := water.position.x + water.size.x
		if right - left >= 1280.0:
			return Vector2(left, right)
	return Vector2(FALLBACK_LEFT, FALLBACK_RIGHT)


func _pixels_per_meter() -> float:
	var hook := _world.get_node_or_null("Boat/Hook") as Node2D
	if hook == null:
		return FALLBACK_PPM

	var max_depth_pixels := float(hook.get("max_depth"))
	var max_depth_meters := float(hook.get("max_depth_meters"))
	if max_depth_pixels <= 0.0 or max_depth_meters <= 0.0:
		return FALLBACK_PPM
	return max_depth_pixels / max_depth_meters


func _world_y_for_depth(depth_meters: float) -> float:
	var boat := _world.get_node_or_null("Boat") as Node2D
	var hook := _world.get_node_or_null("Boat/Hook") as Node2D
	if boat == null or hook == null:
		return FALLBACK_ZERO_Y + depth_meters * FALLBACK_PPM

	var hook_start_y := hook.position.y
	var start_variant: Variant = hook.get("start_position")
	if start_variant is Vector2:
		hook_start_y = (start_variant as Vector2).y

	return boat.global_position.y + hook_start_y + depth_meters * _pixels_per_meter()


func _remove_old_terrain() -> void:
	var old_names: Array[String] = [
		"UnderwaterReefTerrain20To100",
		"UnderwaterTerrainFoundation",
		TERRAIN_NODE_NAME
	]

	for node_name in old_names:
		var direct := _world.get_node_or_null(node_name)
		if direct != null:
			_world.remove_child(direct)
			direct.queue_free()

	var bg := _world.get_node_or_null("EnvironmentLayers/UnderwaterLayers/BackgroundDecorLayer")
	if bg != null:
		for node_name in old_names:
			var child := bg.get_node_or_null(node_name)
			if child != null:
				bg.remove_child(child)
				child.queue_free()
