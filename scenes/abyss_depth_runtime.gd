extends Node

# TinyFisher depth cap runtime V3.
# The approved HQ canyon is the playable vertical world: 20-180 m.
# The hook is hard-capped at 180 m and only a very short visual bottom strip
# remains below the canyon so the map does not end on an ugly hard line.

const WORLD_PIXELS_PER_METER: float = 34.5
const WORLD_MAX_DEPTH_M: int = 180
const BOTTOM_VISUAL_END_M: float = 186.0
const MAP_WIDTH_PX: float = 5500.0
const FALLBACK_LEFT: float = -1000.0
const FALLBACK_RIGHT: float = 4500.0
const FALLBACK_ZERO_Y: float = 392.6
const BOTTOM_NODE_NAME: String = "CanyonBottomCap180"
const BOTTOM_Z: int = -8
const WATER_BOTTOM_MARGIN_PX: float = 48.0

# level 0 + five upgrade levels; final upgrade reaches the canyon floor.
const DEPTH_LEVELS_METERS: Array[int] = [60, 100, 130, 150, 165, 180]

# Keep the canyon floor reachable while environment placement is being tested.
const TEST_FULL_DEPTH_UNLOCK: bool = true

var _scene_id: int = 0
var _world: Node2D = null
var _hook: Area2D = null
var _bottom_root: Node2D = null
var _last_bounds: Vector2 = Vector2(INF, INF)
var _last_top_y: float = INF
var _last_bottom_y: float = INF


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	print("DEPTH CAP V3: PLAYABLE MAX 180M / CANYON FLOOR = HOOK LIMIT")


func _process(_delta: float) -> void:
	var scene: Node = get_tree().current_scene
	if scene == null:
		_reset_scene_state()
		return

	if scene.get_instance_id() != _scene_id:
		_scene_id = scene.get_instance_id()
		_world = scene as Node2D
		_hook = null
		_bottom_root = null
		_last_bounds = Vector2(INF, INF)
		_last_top_y = INF
		_last_bottom_y = INF

	if _world == null:
		return

	_hook = _world.get_node_or_null("Boat/Hook") as Area2D
	if _hook == null:
		return

	_apply_depth_limits()
	_ensure_bottom_cap()


func _reset_scene_state() -> void:
	_scene_id = 0
	_world = null
	_hook = null
	_bottom_root = null
	_last_bounds = Vector2(INF, INF)
	_last_top_y = INF
	_last_bottom_y = INF


func _apply_depth_limits() -> void:
	if _hook == null:
		return

	var upgrade_level: int = clampi(int(_hook.get("depth_level")), 0, DEPTH_LEVELS_METERS.size() - 1)
	var effective_level: int = DEPTH_LEVELS_METERS.size() - 1 if TEST_FULL_DEPTH_UNLOCK else upgrade_level
	var target_meters: int = DEPTH_LEVELS_METERS[effective_level]
	var target_pixels: float = float(target_meters) * WORLD_PIXELS_PER_METER

	_hook.set("max_depth_meters", target_meters)
	_hook.set("max_depth", target_pixels)
	_hook.set("camera_deep_y", maxf(1420.0, target_pixels - 360.0))

	var water: Control = _world.get_node_or_null("Water") as Control
	if water != null:
		var required_bottom: float = _world_y_for_depth(BOTTOM_VISUAL_END_M) + WATER_BOTTOM_MARGIN_PX
		water.offset_bottom = maxf(water.offset_bottom, required_bottom)


func _ensure_bottom_cap() -> void:
	var bounds: Vector2 = _get_world_horizontal_bounds()
	var top_y: float = _world_y_for_depth(float(WORLD_MAX_DEPTH_M))
	var bottom_y: float = _world_y_for_depth(BOTTOM_VISUAL_END_M)

	if is_instance_valid(_bottom_root) \
	and bounds.is_equal_approx(_last_bounds) \
	and is_equal_approx(top_y, _last_top_y) \
	and is_equal_approx(bottom_y, _last_bottom_y):
		return

	_remove_old_depth_nodes()

	_bottom_root = Node2D.new()
	_bottom_root.name = BOTTOM_NODE_NAME
	_bottom_root.z_as_relative = false
	_bottom_root.z_index = BOTTOM_Z
	_bottom_root.set_meta("playable_max_depth_m", WORLD_MAX_DEPTH_M)
	_bottom_root.set_meta("visual_bottom_m", BOTTOM_VISUAL_END_M)
	_bottom_root.set_meta("hook_stops_at_canyon_floor", true)
	_world.add_child(_bottom_root)

	_build_bottom_strip(bounds, top_y, bottom_y)
	_build_floor_ridge(bounds, bottom_y)

	_last_bounds = bounds
	_last_top_y = top_y
	_last_bottom_y = bottom_y

	print(
		"CANYON BOTTOM CAP READY: hook=", WORLD_MAX_DEPTH_M,
		"m visual_end=", BOTTOM_VISUAL_END_M,
		"m"
	)


func _remove_old_depth_nodes() -> void:
	if _world == null:
		return

	var old_names: Array[String] = [
		"AbyssDepthZone180To250",
		BOTTOM_NODE_NAME
	]
	for node_name: String in old_names:
		var node: Node = _world.get_node_or_null(node_name)
		if node != null:
			_world.remove_child(node)
			node.queue_free()


func _build_bottom_strip(bounds: Vector2, top_y: float, bottom_y: float) -> void:
	var top_color: Color = Color(0.010, 0.040, 0.070, 0.98)
	var bottom_color: Color = Color(0.002, 0.010, 0.024, 1.0)
	var steps: int = 4

	for i: int in range(steps):
		var t0: float = float(i) / float(steps)
		var t1: float = float(i + 1) / float(steps)
		var band: Polygon2D = _make_rect_polygon(
			bounds.x,
			bounds.y,
			lerpf(top_y, bottom_y, t0),
			lerpf(top_y, bottom_y, t1)
		)
		band.name = "CanyonBottomBand%02d" % i
		band.color = top_color.lerp(bottom_color, t1)
		_bottom_root.add_child(band)


func _build_floor_ridge(bounds: Vector2, bottom_y: float) -> void:
	var width: float = bounds.y - bounds.x
	var ridge: Polygon2D = Polygon2D.new()
	ridge.name = "CanyonBottomFloor"
	ridge.color = Color(0.001, 0.006, 0.014, 1.0)
	ridge.polygon = PackedVector2Array([
		Vector2(bounds.x, bottom_y),
		Vector2(bounds.x, _world_y_for_depth(184.4)),
		Vector2(bounds.x + width * 0.12, _world_y_for_depth(184.9)),
		Vector2(bounds.x + width * 0.24, _world_y_for_depth(184.3)),
		Vector2(bounds.x + width * 0.37, _world_y_for_depth(185.2)),
		Vector2(bounds.x + width * 0.50, _world_y_for_depth(184.6)),
		Vector2(bounds.x + width * 0.63, _world_y_for_depth(185.1)),
		Vector2(bounds.x + width * 0.76, _world_y_for_depth(184.4)),
		Vector2(bounds.x + width * 0.88, _world_y_for_depth(184.9)),
		Vector2(bounds.y, _world_y_for_depth(184.4)),
		Vector2(bounds.y, bottom_y)
	])
	_bottom_root.add_child(ridge)


func _make_rect_polygon(left: float, right: float, top: float, bottom: float) -> Polygon2D:
	var polygon: Polygon2D = Polygon2D.new()
	polygon.polygon = PackedVector2Array([
		Vector2(left, top),
		Vector2(right, top),
		Vector2(right, bottom),
		Vector2(left, bottom)
	])
	return polygon


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
	if _world == null or _hook == null:
		return FALLBACK_ZERO_Y + depth_meters * WORLD_PIXELS_PER_METER

	var boat: Node2D = _world.get_node_or_null("Boat") as Node2D
	if boat == null:
		return FALLBACK_ZERO_Y + depth_meters * WORLD_PIXELS_PER_METER

	var hook_start_y: float = _hook.position.y
	var start_variant: Variant = _hook.get("start_position")
	if start_variant is Vector2:
		hook_start_y = (start_variant as Vector2).y

	return boat.global_position.y + hook_start_y + depth_meters * WORLD_PIXELS_PER_METER
