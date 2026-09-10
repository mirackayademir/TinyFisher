extends Node

# Accepted 20-100 m canyon. Art is rebuilt from repo-safe WebP base64 chunks.
const TERRAIN_NODE_NAME := "UnderwaterCanyonTerrain20To100"
const LAYOUT_VERSION := 14
const TOP_M := 20.0
const BOTTOM_M := 100.0
const SOURCE_SIZE := Vector2(965.0, 722.0)
const EXPECTED_B64 := 74540
const EXPECTED_BYTES := 55904
const EXPECTED_SHA256 := "44d51db26db819b7ca6c950bf4cc67b1074a41da859272337ef1a2b2763395f4"
const DATA_PARTS := [
	"res://assets/environment/terrain/runtime_data/canyon_20_100_part0.txt",
	"res://assets/environment/terrain/runtime_data/canyon_20_100_part1.txt",
	"res://assets/environment/terrain/runtime_data/canyon_20_100_part2.txt",
	"res://assets/environment/terrain/runtime_data/canyon_20_100_part3.txt",
	"res://assets/environment/terrain/runtime_data/canyon_20_100_part4.txt",
	"res://assets/environment/terrain/runtime_data/canyon_20_100_part5.txt",
	"res://assets/environment/terrain/runtime_data/canyon_20_100_part6.txt"
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
var _attempted := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	print("UNDERWATER TERRAIN V14: VERIFIED CANYON DATA / EXACT WORLD FIT")


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
		_attempted = false
	if _world == null:
		return
	_ensure_terrain()
	_fit_to_world()


func _reset() -> void:
	_scene_id = 0
	_world = null
	_root = null
	_sprite = null
	_attempted = false


func _ensure_terrain() -> void:
	if is_instance_valid(_root) and is_instance_valid(_sprite):
		return
	if _attempted:
		return
	_attempted = true
	_remove_old_terrain()

	var texture := _build_texture()
	if texture == null:
		push_error("UNDERWATER TERRAIN V14: canyon texture build failed")
		return

	_root = Node2D.new()
	_root.name = TERRAIN_NODE_NAME
	_root.z_as_relative = false
	_root.z_index = TERRAIN_Z
	_root.set_meta("layout_version", LAYOUT_VERSION)
	_root.set_meta("collisionless", true)
	_root.set_meta("camera_locked", false)
	_root.set_meta("source_sha256", EXPECTED_SHA256)
	_world.add_child(_root)

	_sprite = Sprite2D.new()
	_sprite.name = "AcceptedCanyonSprite"
	_sprite.texture = texture
	_sprite.centered = false
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_root.add_child(_sprite)
	_fit_to_world()

	var bounds := _world_bounds()
	var y20 := _depth_y(TOP_M)
	var y100 := _depth_y(BOTTOM_M)
	print("UNDERWATER TERRAIN V14 OK | x=", bounds.x, "..", bounds.y,
		" | y20=", y20, " | y100=", y100,
		" | scale=", Vector2((bounds.y - bounds.x) / SOURCE_SIZE.x, (y100 - y20) / SOURCE_SIZE.y),
		" | bytes=", EXPECTED_BYTES, " SHA256=OK | z=", TERRAIN_Z,
		" | collision=OFF | camera_lock=OFF")


func _build_texture() -> Texture2D:
	var encoded := ""
	for path: String in DATA_PARTS:
		if not FileAccess.file_exists(path):
			push_error("UNDERWATER TERRAIN V14 missing: " + path)
			return null
		var file := FileAccess.open(path, FileAccess.READ)
		if file == null:
			push_error("UNDERWATER TERRAIN V14 cannot open: " + path)
			return null
		encoded += file.get_as_text().strip_edges()

	if encoded.length() != EXPECTED_B64:
		push_error("UNDERWATER TERRAIN V14 base64 mismatch: " + str(encoded.length()))
		return null
	var bytes := Marshalls.base64_to_raw(encoded)
	if bytes.size() != EXPECTED_BYTES:
		push_error("UNDERWATER TERRAIN V14 byte mismatch: " + str(bytes.size()))
		return null

	var hashing := HashingContext.new()
	if hashing.start(HashingContext.HASH_SHA256) != OK:
		push_error("UNDERWATER TERRAIN V14 SHA256 init failed")
		return null
	hashing.update(bytes)
	if hashing.finish().hex_encode() != EXPECTED_SHA256:
		push_error("UNDERWATER TERRAIN V14 SHA256 mismatch")
		return null

	var image := Image.new()
	var err := image.load_webp_from_buffer(bytes)
	if err != OK:
		push_error("UNDERWATER TERRAIN V14 WebP decode failed: " + str(err))
		return null
	if Vector2(image.get_width(), image.get_height()) != SOURCE_SIZE:
		push_error("UNDERWATER TERRAIN V14 image size mismatch: " + str(image.get_size()))
		return null
	return ImageTexture.create_from_image(image)


func _fit_to_world() -> void:
	if not is_instance_valid(_root) or not is_instance_valid(_sprite) or _world == null:
		return
	var bounds := _world_bounds()
	var width := maxf(bounds.y - bounds.x, 1.0)
	var y20 := _depth_y(TOP_M)
	var y100 := _depth_y(BOTTOM_M)
	var height := maxf(y100 - y20, 1.0)
	_root.global_position = Vector2(bounds.x, y20)
	_root.scale = Vector2(width / SOURCE_SIZE.x, height / SOURCE_SIZE.y)
	_root.set_meta("map_left_x", bounds.x)
	_root.set_meta("map_right_x", bounds.y)
	_root.set_meta("world_y_20m", y20)
	_root.set_meta("world_y_100m", y100)


func _world_bounds() -> Vector2:
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
	var pixels := float(hook.get("max_depth"))
	var meters := float(hook.get("max_depth_meters"))
	return pixels / meters if pixels > 0.0 and meters > 0.0 else FALLBACK_PPM


func _hook_zero_y() -> float:
	var boat := _world.get_node_or_null("Boat") as Node2D
	var hook := _world.get_node_or_null("Boat/Hook") as Node2D
	if boat == null or hook == null:
		return FALLBACK_ZERO_Y
	var start_y := hook.position.y
	var stored = hook.get("start_position")
	if stored is Vector2:
		var p := stored as Vector2
		if not is_zero_approx(p.y) or is_zero_approx(hook.position.y):
			start_y = p.y
	return boat.global_position.y + start_y


func _depth_y(meters: float) -> float:
	return _hook_zero_y() + meters * _pixels_per_meter()


func _remove_node(node: Node) -> void:
	if node == null:
		return
	if node is CanvasItem:
		(node as CanvasItem).visible = false
	var parent := node.get_parent()
	if parent != null:
		parent.remove_child(node)
	node.queue_free()


func _remove_old_terrain() -> void:
	var names := ["UnderwaterReefTerrain20To100", "UnderwaterTerrainFoundation", TERRAIN_NODE_NAME]
	for terrain_name: String in names:
		_remove_node(_world.get_node_or_null(terrain_name))
	var layer := _world.get_node_or_null("EnvironmentLayers/UnderwaterLayers/BackgroundDecorLayer")
	if layer != null:
		for terrain_name: String in names:
			_remove_node(layer.get_node_or_null(terrain_name))
