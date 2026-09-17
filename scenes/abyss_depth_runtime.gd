extends Node

# TinyFisher depth expansion runtime.
# Keeps the current upgrade API intact while expanding the playable ocean to 250 m.
# During content testing the full depth remains unlocked; later we can disable the
# test flag and the same runtime will follow the real depth upgrade level.

const WORLD_PIXELS_PER_METER: float = 34.5
const WORLD_MAX_DEPTH_M: int = 250
const ABYSS_TOP_M: float = 180.0
const ABYSS_BOTTOM_M: float = 250.0
const MAP_WIDTH_PX: float = 5500.0
const FALLBACK_LEFT: float = -1000.0
const FALLBACK_RIGHT: float = 4500.0
const FALLBACK_ZERO_Y: float = 392.6
const ABYSS_NODE_NAME: String = "AbyssDepthZone180To250"
const ABYSS_Z: int = -8
const WATER_BOTTOM_MARGIN_PX: float = 760.0

# level 0 + five upgrade levels
const DEPTH_LEVELS_METERS: Array[int] = [60, 100, 150, 200, 225, 250]

# Keep full depth open while we place environment/fish content.
const TEST_FULL_DEPTH_UNLOCK: bool = true

var _scene_id: int = 0
var _world: Node2D = null
var _hook: Area2D = null
var _abyss_root: Node2D = null
var _last_bounds: Vector2 = Vector2(INF, INF)
var _last_top_y: float = INF
var _last_bottom_y: float = INF


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	print("ABYSS DEPTH V1: 250M WORLD / HQ CANYON 20-180M / ABYSS 180-250M")


func _process(_delta: float) -> void:
	var scene: Node = get_tree().current_scene
	if scene == null:
		_reset_scene_state()
		return

	if scene.get_instance_id() != _scene_id:
		_scene_id = scene.get_instance_id()
		_world = scene as Node2D
		_hook = null
		_abyss_root = null
		_last_bounds = Vector2(INF, INF)
		_last_top_y = INF
		_last_bottom_y = INF

	if _world == null:
		return

	_hook = _world.get_node_or_null("Boat/Hook") as Area2D
	if _hook == null:
		return

	_apply_depth_limits()
	_ensure_abyss_zone()


func _reset_scene_state() -> void:
	_scene_id = 0
	_world = null
	_hook = null
	_abyss_root = null
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
		var required_bottom: float = _world_y_for_depth(float(WORLD_MAX_DEPTH_M)) + WATER_BOTTOM_MARGIN_PX
		water.offset_bottom = maxf(water.offset_bottom, required_bottom)


func _ensure_abyss_zone() -> void:
	var bounds: Vector2 = _get_world_horizontal_bounds()
	var top_y: float = _world_y_for_depth(ABYSS_TOP_M)
	var bottom_y: float = _world_y_for_depth(ABYSS_BOTTOM_M)

	if is_instance_valid(_abyss_root) \
	and bounds.is_equal_approx(_last_bounds) \
	and is_equal_approx(top_y, _last_top_y) \
	and is_equal_approx(bottom_y, _last_bottom_y):
		return

	if is_instance_valid(_abyss_root):
		_world.remove_child(_abyss_root)
		_abyss_root.queue_free()

	var existing: Node = _world.get_node_or_null(ABYSS_NODE_NAME)
	if existing != null:
		_world.remove_child(existing)
		existing.queue_free()

	_abyss_root = Node2D.new()
	_abyss_root.name = ABYSS_NODE_NAME
	_abyss_root.z_as_relative = false
	_abyss_root.z_index = ABYSS_Z
	_abyss_root.set_meta("depth_top_m", ABYSS_TOP_M)
	_abyss_root.set_meta("depth_bottom_m", ABYSS_BOTTOM_M)
	_abyss_root.set_meta("world_max_depth_m", WORLD_MAX_DEPTH_M)
	_abyss_root.set_meta("biome", "abyss")
	_world.add_child(_abyss_root)

	_build_transition(bounds, top_y)
	_build_depth_bands(bounds, top_y, bottom_y)
	_build_bottom_silhouettes(bounds)
	_build_bioluminescent_specks(bounds)

	_last_bounds = bounds
	_last_top_y = top_y
	_last_bottom_y = bottom_y

	print(
		"ABYSS ZONE READY: ", ABYSS_TOP_M, "-", ABYSS_BOTTOM_M,
		"m / world_bottom=", snappedf(bottom_y, 1.0), "px"
	)


func _build_transition(bounds: Vector2, abyss_top_y: float) -> void:
	var transition_start: float = _world_y_for_depth(174.0)
	var transition_end: float = _world_y_for_depth(190.0)
	var steps: int = 4

	for i: int in range(steps):
		var t0: float = float(i) / float(steps)
		var t1: float = float(i + 1) / float(steps)
		var y0: float = lerpf(transition_start, transition_end, t0)
		var y1: float = lerpf(transition_start, transition_end, t1)
		var band: Polygon2D = _make_rect_polygon(bounds.x, bounds.y, y0, y1)
		band.name = "AbyssTransition%02d" % i
		band.color = Color(0.004, 0.018, 0.035, lerpf(0.06, 0.34, t1))
		_abyss_root.add_child(band)


func _build_depth_bands(bounds: Vector2, top_y: float, bottom_y: float) -> void:
	var top_color: Color = Color(0.006, 0.028, 0.052, 0.78)
	var bottom_color: Color = Color(0.0015, 0.004, 0.010, 0.98)
	var band_count: int = 9

	for i: int in range(band_count):
		var t0: float = float(i) / float(band_count)
		var t1: float = float(i + 1) / float(band_count)
		var y0: float = lerpf(top_y, bottom_y, t0)
		var y1: float = lerpf(top_y, bottom_y, t1)
		var band: Polygon2D = _make_rect_polygon(bounds.x, bounds.y, y0, y1)
		band.name = "AbyssBand%02d" % i
		band.color = top_color.lerp(bottom_color, t1)
		_abyss_root.add_child(band)


func _build_bottom_silhouettes(bounds: Vector2) -> void:
	var left: float = bounds.x
	var right: float = bounds.y
	var width: float = right - left
	var bottom_y: float = _world_y_for_depth(250.0)

	var left_rock: Polygon2D = Polygon2D.new()
	left_rock.name = "AbyssLeftSilhouette"
	left_rock.color = Color(0.002, 0.012, 0.022, 0.96)
	left_rock.polygon = PackedVector2Array([
		Vector2(left, bottom_y),
		Vector2(left, _world_y_for_depth(214.0)),
		Vector2(left + width * 0.08, _world_y_for_depth(221.0)),
		Vector2(left + width * 0.15, _world_y_for_depth(230.0)),
		Vector2(left + width * 0.23, _world_y_for_depth(238.0)),
		Vector2(left + width * 0.31, _world_y_for_depth(246.0)),
		Vector2(left + width * 0.37, bottom_y)
	])
	_abyss_root.add_child(left_rock)

	var right_rock: Polygon2D = Polygon2D.new()
	right_rock.name = "AbyssRightSilhouette"
	right_rock.color = Color(0.002, 0.012, 0.022, 0.96)
	right_rock.polygon = PackedVector2Array([
		Vector2(right, bottom_y),
		Vector2(right, _world_y_for_depth(216.0)),
		Vector2(right - width * 0.07, _world_y_for_depth(222.0)),
		Vector2(right - width * 0.14, _world_y_for_depth(231.0)),
		Vector2(right - width * 0.22, _world_y_for_depth(239.0)),
		Vector2(right - width * 0.30, _world_y_for_depth(247.0)),
		Vector2(right - width * 0.36, bottom_y)
	])
	_abyss_root.add_child(right_rock)


func _build_bioluminescent_specks(bounds: Vector2) -> void:
	var width: float = bounds.y - bounds.x
	for i: int in range(26):
		var x_ratio: float = fmod(float(i * 37 + 11), 101.0) / 100.0
		var depth_m: float = 194.0 + fmod(float(i * 23 + 7), 51.0)
		var x: float = bounds.x + width * x_ratio
		var y: float = _world_y_for_depth(depth_m)
		var size: float = 2.4 + float(i % 4) * 0.8

		var speck: Polygon2D = Polygon2D.new()
		speck.name = "AbyssGlow%02d" % i
		speck.polygon = PackedVector2Array([
			Vector2(x, y - size),
			Vector2(x + size, y),
			Vector2(x, y + size),
			Vector2(x - size, y)
		])
		match i % 3:
			0:
				speck.color = Color(0.20, 0.78, 0.92, 0.38)
			1:
				speck.color = Color(0.28, 0.55, 1.0, 0.30)
			_:
				speck.color = Color(0.48, 0.32, 0.92, 0.24)
		_abyss_root.add_child(speck)


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
