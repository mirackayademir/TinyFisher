extends Node

# High-quality 20-100 m canyon terrain.
# The supplied source art is fitted mathematically to the real Water world
# bounds and the live hook depth scale. It is world-anchored, collisionless
# and never follows the camera.

const TERRAIN_NODE_NAME := "UnderwaterCanyonTerrain20To100"
const TERRAIN_TEXTURE_PATH := "res://assets/environment/terrain/underwater_canyon_20_100_hq.webp"
const LAYOUT_VERSION := 17

const TOP_M := 20.0
const BOTTOM_M := 100.0

# Accepted source: 2048 x 682. Rows 0..26 are fully transparent.
# We crop only that empty strip. Every visible source pixel is preserved.
const SOURCE_REGION := Rect2(0.0, 27.0, 2048.0, 655.0)

const FALLBACK_LEFT := -1000.0
const FALLBACK_RIGHT := 11000.0
const FALLBACK_PPM := 34.5
const FALLBACK_ZERO_Y := 392.6
const TERRAIN_Z := -7

var _scene_id := 0
var _world: Node2D
var _root: Node2D
var _sprite: Sprite2D
var _last_left := INF
var _last_width := INF
var _last_top_y := INF
var _last_height := INF


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	print("UNDERWATER TERRAIN V17: ACCEPTED HQ CANYON / EXACT 20-100M MAP FIT")


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

	var source_texture := load(TERRAIN_TEXTURE_PATH) as Texture2D
	if source_texture == null:
		push_error("HQ terrain texture bulunamadi: " + TERRAIN_TEXTURE_PATH)
		return

	var atlas := AtlasTexture.new()
	atlas.atlas = source_texture
	atlas.region = SOURCE_REGION

	_root = Node2D.new()
	_root.name = TERRAIN_NODE_NAME
	_root.z_as_relative = false
	_root.z_index = TERRAIN_Z
	_root.set_meta("layout_version", LAYOUT_VERSION)
	_root.set_meta("collisionless", true)
	_root.set_meta("camera_locked", false)
	_root.set_meta("depth_top_m", TOP_M)
	_root.set_meta("depth_bottom_m", BOTTOM_M)
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


func _fit_to_world(force := false) -> void:
	if not is_instance_valid(_root) or not is_instance_valid(_sprite) or _world == null:
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
	# The visible source rectangle is mapped directly to those world bounds so
	# the previous terrain footprint/position is not changed.
	_root.global_position = Vector2(left, top_y)
	_root.scale = Vector2(
		width / SOURCE_REGION.size.x,
		height / SOURCE_REGION.size.y
	)

	_root.set_meta("map_left_x", left)
	_root.set_meta("map_right_x", bounds.y)
	_root.set_meta("world_y_20m", top_y)
	_root.set_meta("world_y_100m", bottom_y)
	_root.set_meta("source_visible_size", SOURCE_REGION.size)
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
