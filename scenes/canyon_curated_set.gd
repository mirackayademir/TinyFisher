extends Node

# TinyFisher — Canyon Curated Set V2
# Prototype-approved placement pass. Props are positioned in HQ canyon local
# source coordinates so they stay locked to the same ledges when the terrain
# is fitted/scaled to the 20–180 m gameplay band.

const TERRAIN_NODE_NAME: String = "UnderwaterCanyonTerrain20To180"
const ROOT_NAME: String = "CanyonCuratedSetV2"
const LAYOUT_VERSION: int = 2

const SHEET_WIDTH: int = 768
const SHEET_HEIGHT: int = 256
const CELL_SIZE: Vector2 = Vector2(256.0, 256.0)

const SHEET_PART_PATHS: Array[String] = [
	"res://assets/environment/terrain/runtime_data/canyon_curated_sheet_part00.txt",
	"res://assets/environment/terrain/runtime_data/canyon_curated_sheet_part01.txt",
	"res://assets/environment/terrain/runtime_data/canyon_curated_sheet_part02.txt",
	"res://assets/environment/terrain/runtime_data/canyon_curated_sheet_part03.txt",
	"res://assets/environment/terrain/runtime_data/canyon_curated_sheet_part04.txt",
	"res://assets/environment/terrain/runtime_data/canyon_curated_sheet_part05.txt",
	"res://assets/environment/terrain/runtime_data/canyon_curated_sheet_part06.txt",
	"res://assets/environment/terrain/runtime_data/canyon_curated_sheet_part07.txt",
	"res://assets/environment/terrain/runtime_data/canyon_curated_sheet_part08.txt",
	"res://assets/environment/terrain/runtime_data/canyon_curated_sheet_part09.txt"
]

const CELL_ANCHOR: Rect2 = Rect2(0.0, 0.0, 256.0, 256.0)
const CELL_CHAIN: Rect2 = Rect2(256.0, 0.0, 256.0, 256.0)
const CELL_WRECK: Rect2 = Rect2(512.0, 0.0, 256.0, 256.0)

var _scene_id: int = 0
var _world: Node2D = null
var _terrain: Node2D = null
var _root: Node2D = null
var _sheet_texture: Texture2D = null
var _sheet_build_attempted: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	print("CANYON CURATED SET V2: PROTOTYPE PLACEMENT / 7 POI / CANYON-LOCKED")


func _process(_delta: float) -> void:
	var scene: Node = get_tree().current_scene
	if scene == null:
		_reset_scene_state()
		return

	if scene.get_instance_id() != _scene_id:
		_scene_id = scene.get_instance_id()
		_world = scene as Node2D
		_terrain = null
		_root = null

	if _world == null:
		return

	_ensure_curated_set()


func _reset_scene_state() -> void:
	_scene_id = 0
	_world = null
	_terrain = null
	_root = null


func _ensure_curated_set() -> void:
	if is_instance_valid(_root):
		return

	_terrain = _world.get_node_or_null(TERRAIN_NODE_NAME) as Node2D
	if _terrain == null:
		return
	if _terrain.get_node_or_null("TerrainSpriteHQ") == null:
		return

	if _sheet_texture == null and not _sheet_build_attempted:
		_sheet_build_attempted = true
		_sheet_texture = _build_sheet_texture()
	if _sheet_texture == null:
		return

	_remove_old_curated_nodes()

	_root = Node2D.new()
	_root.name = ROOT_NAME
	_root.z_as_relative = true
	_root.z_index = 1
	_root.set_meta("layout_version", LAYOUT_VERSION)
	_root.set_meta("prototype_locked", true)
	_root.set_meta("placement_space", "canyon_local_source_px")
	_root.set_meta("canyon_priority", "hero_environment")
	_terrain.add_child(_root)

	# Placement follows the user's marked prototype. All coordinates are local
	# to the visible HQ canyon artwork, not arbitrary world/depth coordinates.
	# Props stay intentionally restrained so the canyon remains the hero.
	_add_prop("POI_01_LeftUpperChain", CELL_CHAIN, Vector2(156.0, 689.0), 92.0, -11.0, 0.88, false)
	_add_prop("POI_02_RightUpperWreck", CELL_WRECK, Vector2(1030.0, 731.0), 112.0, 7.0, 0.90, true)
	_add_prop("POI_03_DistantCenterAnchor", CELL_ANCHOR, Vector2(644.0, 1015.0), 48.0, -4.0, 0.68, false)
	_add_prop("POI_04_InnerRightChain", CELL_CHAIN, Vector2(756.0, 1021.0), 68.0, 12.0, 0.80, true)
	_add_prop("POI_05_LeftLowerAnchor", CELL_ANCHOR, Vector2(332.0, 1093.0), 126.0, -9.0, 0.94, false)
	_add_prop("POI_06_RightLowerAnchor", CELL_ANCHOR, Vector2(920.0, 1088.0), 120.0, 9.0, 0.93, true)
	_add_prop("POI_07_BottomLeftWreck", CELL_WRECK, Vector2(579.0, 1142.0), 132.0, 8.0, 0.92, false)

	print("CANYON CURATED SET V2 READY: 7 prototype POIs locked to HQ canyon source")


func _build_sheet_texture() -> Texture2D:
	var encoded: String = ""

	for path: String in SHEET_PART_PATHS:
		if not FileAccess.file_exists(path):
			push_error("CANYON CURATED sheet part missing: " + path)
			return null

		var file: FileAccess = FileAccess.open(path, FileAccess.READ)
		if file == null:
			push_error("CANYON CURATED sheet part cannot open: " + path)
			return null
		encoded += file.get_as_text().strip_edges()

	var raw: PackedByteArray = Marshalls.base64_to_raw(encoded)
	if raw.is_empty():
		push_error("CANYON CURATED sheet base64 decode failed")
		return null

	var image: Image = Image.new()
	var decode_error: Error = image.load_webp_from_buffer(raw)
	if decode_error != OK or image.is_empty():
		push_error("CANYON CURATED WebP decode failed: " + error_string(decode_error))
		return null

	if image.get_width() != SHEET_WIDTH or image.get_height() != SHEET_HEIGHT:
		push_error(
			"CANYON CURATED sheet size mismatch: got=%dx%d expected=%dx%d" % [
				image.get_width(), image.get_height(), SHEET_WIDTH, SHEET_HEIGHT
			]
		)
		return null

	if not image.has_mipmaps():
		var mip_error: Error = image.generate_mipmaps()
		if mip_error != OK:
			push_warning("CANYON CURATED mipmap generation failed: " + error_string(mip_error))

	var texture: ImageTexture = ImageTexture.create_from_image(image)
	if texture == null:
		push_error("CANYON CURATED ImageTexture creation failed")
		return null
	return texture


func _add_prop(
	node_name: String,
	region: Rect2,
	local_position: Vector2,
	target_long_side_px: float,
	rotation_degrees: float,
	alpha: float,
	flip_h: bool
) -> void:
	if _root == null or _sheet_texture == null:
		return

	var atlas: AtlasTexture = AtlasTexture.new()
	atlas.atlas = _sheet_texture
	atlas.region = region

	var sprite: Sprite2D = Sprite2D.new()
	sprite.name = node_name
	sprite.texture = atlas
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	sprite.centered = true
	sprite.position = local_position
	sprite.rotation = deg_to_rad(rotation_degrees)
	sprite.scale = Vector2.ONE * (target_long_side_px / CELL_SIZE.x)
	sprite.flip_h = flip_h
	sprite.modulate = Color(0.94, 0.98, 1.0, alpha)
	sprite.z_index = 0
	sprite.set_meta("canyon_curated", true)
	sprite.set_meta("prototype_position", local_position)
	sprite.set_meta("target_long_side_px", target_long_side_px)
	_root.add_child(sprite)


func _remove_old_curated_nodes() -> void:
	if _world == null:
		return

	var old_paths: Array[String] = [
		TERRAIN_NODE_NAME + "/CanyonCuratedSetV1",
		TERRAIN_NODE_NAME + "/" + ROOT_NAME,
		"EnvironmentLayers/UnderwaterLayers/LandmarkDecorLayer/CanyonCuratedSetV1",
		"EnvironmentLayers/UnderwaterLayers/LandmarkDecorLayer/" + ROOT_NAME,
		"EnvironmentLayers/UnderwaterLayers/MidDecorLayer/CuratedChainPOI_96m"
	]

	for path: String in old_paths:
		var old: Node = _world.get_node_or_null(path)
		if old != null:
			old.get_parent().remove_child(old)
			old.queue_free()
