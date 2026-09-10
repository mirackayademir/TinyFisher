extends Node

# TinyFisher 20-100 m underwater canyon terrain.
# Accepted PNG is placed as one world-anchored Sprite2D, with exact map/depth scaling.
# No camera-following, no procedural mountain, no collision, no duplicate terrain layers.

const TERRAIN_NODE_NAME: String = "UnderwaterCanyonTerrain20To100"
const TERRAIN_TEXTURE_PATH: String = "res://assets/environment/terrain/underwater_canyon_20_100.png"
const LAYOUT_VERSION: int = 13

const TERRAIN_TOP_DEPTH_METERS: float = 20.0
const TERRAIN_BOTTOM_DEPTH_METERS: float = 100.0

# Accepted/cropped asset dimensions measured from the actual alpha bounds.
const SOURCE_WIDTH: float = 976.0
const SOURCE_HEIGHT: float = 1405.0

const FALLBACK_WORLD_LEFT_X: float = -1000.0
const FALLBACK_WORLD_RIGHT_X: float = 11000.0
const FALLBACK_PIXELS_PER_METER: float = 34.5
const FALLBACK_HOOK_ZERO_WORLD_Y: float = 392.6

# Water is -9 and underwater decor begins at -6.
# Terrain stays entirely at -7 so it is above water and behind all later decor assets.
const TERRAIN_Z_INDEX: int = -7

var _scene_id: int = 0
var _world: Node2D = null
var _terrain_root: Node2D = null
var _terrain_sprite: Sprite2D = null

var _last_left_x: float = INF
var _last_map_width: float = INF
var _last_top_y: float = INF
var _last_band_height: float = INF


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	print("UNDERWATER TERRAIN V13: ACCEPTED PNG / EXACT WORLD FIT / COLLISION OFF")


func _process(_delta: float) -> void:
	var current_scene: Node = get_tree().current_scene
	if current_scene == null:
		_reset_refs()
		return

	var current_id: int = current_scene.get_instance_id()
	if current_id != _scene_id:
		_scene_id = current_id
		_world = current_scene as Node2D
		_terrain_root = null
		_terrain_sprite = null
		_last_left_x = INF
		_last_map_width = INF
		_last_top_y = INF
		_last_band_height = INF

	if _world == null:
		return

	_ensure_terrain()
	_sync_terrain_to_world()


func _reset_refs() -> void:
	_scene_id = 0
	_world = null
	_terrain_root = null
	_terrain_sprite = null
	_last_left_x = INF
	_last_map_width = INF
	_last_top_y = INF
	_last_band_height = INF


func _ensure_terrain() -> void:
	if is_instance_valid(_terrain_root) and is_instance_valid(_terrain_sprite):
		return

	_remove_all_terrain_variants()

	var source_texture: Texture2D = load(TERRAIN_TEXTURE_PATH) as Texture2D
	if source_texture == null:
		push_error("Terrain texture bulunamadi: " + TERRAIN_TEXTURE_PATH)
		return

	var texture_size: Vector2 = source_texture.get_size()
	if not is_equal_approx(texture_size.x, SOURCE_WIDTH) or not is_equal_approx(texture_size.y, SOURCE_HEIGHT):
		push_error(
			"Terrain texture olcusu beklenenden farkli. Beklenen: "
			+ str(Vector2(SOURCE_WIDTH, SOURCE_HEIGHT))
			+ " gelen: " + str(texture_size)
		)
		return

	_terrain_root = Node2D.new()
	_terrain_root.name = TERRAIN_NODE_NAME
	_terrain_root.z_as_relative = false
	_terrain_root.z_index = TERRAIN_Z_INDEX
	_terrain_root.set_meta("layout_version", LAYOUT_VERSION)
	_terrain_root.set_meta("collisionless", true)
	_terrain_root.set_meta("camera_locked", false)
	_terrain_root.set_meta("source_size", Vector2(SOURCE_WIDTH, SOURCE_HEIGHT))
	_terrain_root.set_meta("depth_top_m", TERRAIN_TOP_DEPTH_METERS)
	_terrain_root.set_meta("depth_bottom_m", TERRAIN_BOTTOM_DEPTH_METERS)
	_world.add_child(_terrain_root)

	_terrain_sprite = Sprite2D.new()
	_terrain_sprite.name = "AcceptedCanyonSprite"
	_terrain_sprite.texture = source_texture
	_terrain_sprite.centered = false
	_terrain_sprite.position = Vector2.ZERO
	_terrain_sprite.z_as_relative = true
	_terrain_sprite.z_index = 0
	_terrain_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_terrain_root.add_child(_terrain_sprite)

	_sync_terrain_to_world(true)

	var bounds: Vector2 = _get_world_horizontal_bounds()
	var top_y: float = _world_y_for_depth(TERRAIN_TOP_DEPTH_METERS)
	var bottom_y: float = _world_y_for_depth(TERRAIN_BOTTOM_DEPTH_METERS)
	var expected_scale_x: float = (bounds.y - bounds.x) / SOURCE_WIDTH
	var expected_scale_y: float = (bottom_y - top_y) / SOURCE_HEIGHT

	print(
		"UNDERWATER TERRAIN V13 OK | x=", bounds.x, "..", bounds.y,
		" | map_width=", bounds.y - bounds.x,
		" | y20=", top_y,
		" | y100=", bottom_y,
		" | band_height=", bottom_y - top_y,
		" | source=", Vector2(SOURCE_WIDTH, SOURCE_HEIGHT),
		" | scale=", Vector2(expected_scale_x, expected_scale_y),
		" | z=", TERRAIN_Z_INDEX,
		" | collision=OFF | camera_lock=OFF"
	)


func _sync_terrain_to_world(force: bool = false) -> void:
	if not is_instance_valid(_terrain_root) or not is_instance_valid(_terrain_sprite) or _world == null:
		return

	var bounds: Vector2 = _get_world_horizontal_bounds()
	var left_x: float = bounds.x
	var map_width: float = maxf(bounds.y - bounds.x, 1.0)

	var top_y: float = _world_y_for_depth(TERRAIN_TOP_DEPTH_METERS)
	var bottom_y: float = _world_y_for_depth(TERRAIN_BOTTOM_DEPTH_METERS)
	var band_height: float = maxf(bottom_y - top_y, 1.0)

	if (
		not force
		and is_equal_approx(left_x, _last_left_x)
		and is_equal_approx(map_width, _last_map_width)
		and is_equal_approx(top_y, _last_top_y)
		and is_equal_approx(band_height, _last_band_height)
	):
		return

	_terrain_root.global_position = Vector2(left_x, top_y)
	_terrain_root.scale = Vector2(
		map_width / SOURCE_WIDTH,
		band_height / SOURCE_HEIGHT
	)

	_terrain_root.set_meta("map_left_x", left_x)
	_terrain_root.set_meta("map_right_x", bounds.y)
	_terrain_root.set_meta("world_y_20m", top_y)
	_terrain_root.set_meta("world_y_100m", bottom_y)
	_terrain_root.set_meta("map_width", map_width)
	_terrain_root.set_meta("band_height", band_height)
	_terrain_root.set_meta("scale_x", map_width / SOURCE_WIDTH)
	_terrain_root.set_meta("scale_y", band_height / SOURCE_HEIGHT)

	_last_left_x = left_x
	_last_map_width = map_width
	_last_top_y = top_y
	_last_band_height = band_height


func _get_world_horizontal_bounds() -> Vector2:
	var water: Control = _world.get_node_or_null("Water") as Control
	if water != null:
		var left_x: float = water.position.x
		var right_x: float = water.position.x + water.size.x
		if right_x - left_x >= 1280.0:
			return Vector2(left_x, right_x)

	return Vector2(FALLBACK_WORLD_LEFT_X, FALLBACK_WORLD_RIGHT_X)


func _pixels_per_meter() -> float:
	var hook: Node2D = _world.get_node_or_null("Boat/Hook") as Node2D
	if hook == null:
		return FALLBACK_PIXELS_PER_METER

	var max_depth_pixels: float = float(hook.get("max_depth"))
	var max_depth_meters: float = float(hook.get("max_depth_meters"))
	if max_depth_pixels <= 0.0 or max_depth_meters <= 0.0:
		return FALLBACK_PIXELS_PER_METER

	return max_depth_pixels / max_depth_meters


func _hook_zero_world_y() -> float:
	var boat: Node2D = _world.get_node_or_null("Boat") as Node2D
	var hook: Node2D = _world.get_node_or_null("Boat/Hook") as Node2D
	if boat == null or hook == null:
		return FALLBACK_HOOK_ZERO_WORLD_Y

	var local_start_y: float = hook.position.y
	var start_variant: Variant = hook.get("start_position")
	if start_variant is Vector2:
		var stored_start: Vector2 = start_variant as Vector2
		if not is_zero_approx(stored_start.y) or is_zero_approx(hook.position.y):
			local_start_y = stored_start.y

	return boat.global_position.y + local_start_y


func _world_y_for_depth(depth_meters: float) -> float:
	return _hook_zero_world_y() + depth_meters * _pixels_per_meter()


func _hide_and_remove(node: Node) -> void:
	if node == null:
		return
	if node is CanvasItem:
		(node as CanvasItem).visible = false
	var parent_node: Node = node.get_parent()
	if parent_node != null:
		parent_node.remove_child(node)
	node.queue_free()


func _remove_all_terrain_variants() -> void:
	var terrain_names: Array[String] = [
		"UnderwaterReefTerrain20To100",
		"UnderwaterTerrainFoundation",
		"UnderwaterCanyonTerrain20To100"
	]

	for terrain_name: String in terrain_names:
		var direct_node: Node = _world.get_node_or_null(terrain_name)
		if direct_node != null:
			_hide_and_remove(direct_node)

	var background_layer: Node = _world.get_node_or_null(
		"EnvironmentLayers/UnderwaterLayers/BackgroundDecorLayer"
	)
	if background_layer != null:
		for terrain_name: String in terrain_names:
			var background_node: Node = background_layer.get_node_or_null(terrain_name)
			if background_node != null:
				_hide_and_remove(background_node)
