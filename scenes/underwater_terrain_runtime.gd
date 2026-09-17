extends Node

# TinyFisher canyon runtime V32.
# Uses the approved single-file HQ canyon asset and locks it to the authored
# gameplay band 20-180 m. The 180-250 m abyss is handled by AbyssDepthRuntime.

const CanyonTextureLoader = preload("res://scenes/canyon_texture_loader.gd")

const TERRAIN_NODE_NAME: String = "UnderwaterCanyonTerrain20To180"
const LAYOUT_VERSION: int = 32
const TOP_M: float = 20.0
const BOTTOM_M: float = 180.0
const WORLD_MAX_DEPTH_M: float = 250.0
const WORLD_PIXELS_PER_METER: float = 34.5
const MAP_WIDTH_PX: float = 5500.0
const FALLBACK_LEFT: float = -1000.0
const FALLBACK_RIGHT: float = 4500.0
const FALLBACK_ZERO_Y: float = 392.6
const TERRAIN_Z: int = -7
const DEEP_WATER_MARGIN_PX: float = 760.0

var _scene_id: int = 0
var _world: Node2D = null
var _root: Node2D = null
var _sprite: Sprite2D = null
var _terrain_texture: Texture2D = null
var _source_region: Rect2 = Rect2()
var _texture_build_attempted: bool = false
var _last_left: float = INF
var _last_width: float = INF
var _last_top_y: float = INF
var _last_height: float = INF


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	print("UNDERWATER TERRAIN V32: HQ CANYON LOCKED 20-180M / ABYSS BELOW")


func _process(_delta: float) -> void:
	var scene: Node = get_tree().current_scene
	if scene == null:
		_reset_scene_state()
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


func _reset_scene_state() -> void:
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

	if _terrain_texture == null and not _texture_build_attempted:
		_texture_build_attempted = true
		_terrain_texture = CanyonTextureLoader.build_texture()

	if _terrain_texture == null:
		return

	_source_region = CanyonTextureLoader.visible_region(_terrain_texture)
	if _source_region.size.x <= 0.0 or _source_region.size.y <= 0.0:
		push_error("HQ canyon visible region gecersiz.")
		return

	var atlas: AtlasTexture = AtlasTexture.new()
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
	_root.set_meta("terrain_source", "single_file_hq_canyon")
	_root.set_meta("source_region", _source_region)
	_root.set_meta("exact_depth_band", true)
	_root.set_meta("world_pixels_per_meter", WORLD_PIXELS_PER_METER)
	_root.set_meta("compact_map_width_px", MAP_WIDTH_PX)
	_world.add_child(_root)

	_sprite = Sprite2D.new()
	_sprite.name = "TerrainSpriteHQ"
	_sprite.centered = false
	_sprite.texture = atlas
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_sprite.position = Vector2.ZERO
	_sprite.z_index = 0
	_root.add_child(_sprite)

	_fit_to_world(true)


func _fit_to_world(force: bool = false) -> void:
	if not is_instance_valid(_root) or not is_instance_valid(_sprite) or _world == null:
		return
	if _source_region.size.x <= 0.0 or _source_region.size.y <= 0.0:
		return

	var bounds: Vector2 = _get_world_horizontal_bounds()
	var left: float = bounds.x
	var width: float = maxf(bounds.y - bounds.x, 1.0)
	var top_y: float = _world_y_for_depth(TOP_M)
	var bottom_y: float = _world_y_for_depth(BOTTOM_M)
	var height: float = maxf(bottom_y - top_y, 1.0)

	_extend_deep_water(_world_y_for_depth(WORLD_MAX_DEPTH_M) + DEEP_WATER_MARGIN_PX)

	if not force \
	and is_equal_approx(left, _last_left) \
	and is_equal_approx(width, _last_width) \
	and is_equal_approx(top_y, _last_top_y) \
	and is_equal_approx(height, _last_height):
		return

	_root.global_position = Vector2(left, top_y)
	_root.scale = Vector2(
		width / _source_region.size.x,
		height / _source_region.size.y
	)

	_root.set_meta("map_left_x", left)
	_root.set_meta("map_right_x", bounds.y)
	_root.set_meta("world_y_top", top_y)
	_root.set_meta("world_y_bottom", bottom_y)
	_root.set_meta("source_visible_size", _source_region.size)
	_root.set_meta("fit_scale", _root.scale)

	_last_left = left
	_last_width = width
	_last_top_y = top_y
	_last_height = height

	if force:
		print(
			"HQ CANYON LOCKED: ", TOP_M, "-", BOTTOM_M,
			"m world=", snappedf(width, 1.0), "x", snappedf(height, 1.0),
			" scale=", _root.scale,
			" / source=", _source_region.size
		)


func _extend_deep_water(required_bottom_y: float) -> void:
	if _world == null:
		return

	var water: Control = _world.get_node_or_null("Water") as Control
	if water == null:
		return

	water.offset_bottom = maxf(water.offset_bottom, required_bottom_y)


func _get_world_horizontal_bounds() -> Vector2:
	if _world != null:
		var water: Control = _world.get_node_or_null("Water") as Control
		if water != null:
			var left: float = water.position.x
			var water_right: float = water.position.x + water.size.x
			var right: float = minf(water_right, left + MAP_WIDTH_PX)
			if right - left >= 1280.0:
				return Vector2(left, right)
	return Vector2(FALLBACK_LEFT, FALLBACK_RIGHT)


func _world_y_for_depth(depth_meters: float) -> float:
	if _world == null:
		return FALLBACK_ZERO_Y + depth_meters * WORLD_PIXELS_PER_METER

	var boat: Node2D = _world.get_node_or_null("Boat") as Node2D
	var hook: Node2D = _world.get_node_or_null("Boat/Hook") as Node2D
	if boat == null or hook == null:
		return FALLBACK_ZERO_Y + depth_meters * WORLD_PIXELS_PER_METER

	var hook_start_y: float = hook.position.y
	var start_variant: Variant = hook.get("start_position")
	if start_variant is Vector2:
		hook_start_y = (start_variant as Vector2).y

	return boat.global_position.y + hook_start_y + depth_meters * WORLD_PIXELS_PER_METER


func _remove_old_terrain() -> void:
	if _world == null:
		return

	var old_names: Array[String] = [
		"UnderwaterReefTerrain20To100",
		"UnderwaterTerrainFoundation",
		"UnderwaterCanyonTerrain20To100",
		TERRAIN_NODE_NAME
	]

	for node_name: String in old_names:
		var direct: Node = _world.get_node_or_null(node_name)
		if direct != null:
			_world.remove_child(direct)
			direct.queue_free()

	var bg: Node = _world.get_node_or_null("EnvironmentLayers/UnderwaterLayers/BackgroundDecorLayer")
	if bg != null:
		for node_name: String in old_names:
			var child: Node = bg.get_node_or_null(node_name)
			if child != null:
				bg.remove_child(child)
				child.queue_free()
