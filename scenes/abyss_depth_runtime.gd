extends Node

# TinyFisher depth expansion runtime V2.
# Expands the playable ocean to 250 m and builds a continuous abyss biome under
# the approved 20-180 m HQ canyon. The canyon edge is deliberately blended into
# the abyss so 180 m does not read as a hard horizontal cut.

const WORLD_PIXELS_PER_METER: float = 34.5
const WORLD_MAX_DEPTH_M: int = 250
const CANYON_FADE_START_M: float = 168.0
const ABYSS_TOP_M: float = 180.0
const CANYON_FADE_END_M: float = 194.0
const ABYSS_BOTTOM_M: float = 250.0
const MAP_WIDTH_PX: float = 5500.0
const FALLBACK_LEFT: float = -1000.0
const FALLBACK_RIGHT: float = 4500.0
const FALLBACK_ZERO_Y: float = 392.6
const ABYSS_NODE_NAME: String = "AbyssDepthZone180To250"
const ABYSS_BACKGROUND_Z: int = -8
const ABYSS_ROCK_Z: int = -7
const ABYSS_BLEND_Z: int = -6
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
	print("ABYSS DEPTH V2: 250M WORLD / CANYON FADE 168-194M / ABYSS 180-250M")


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
	_abyss_root.z_index = ABYSS_BACKGROUND_Z
	_abyss_root.set_meta("depth_top_m", ABYSS_TOP_M)
	_abyss_root.set_meta("depth_bottom_m", ABYSS_BOTTOM_M)
	_abyss_root.set_meta("fade_start_m", CANYON_FADE_START_M)
	_abyss_root.set_meta("fade_end_m", CANYON_FADE_END_M)
	_abyss_root.set_meta("world_max_depth_m", WORLD_MAX_DEPTH_M)
	_abyss_root.set_meta("biome", "abyss")
	_world.add_child(_abyss_root)

	_build_depth_backdrop(bounds, top_y, bottom_y)
	_build_side_continuation(bounds, bottom_y)
	_build_floor_ridge(bounds, bottom_y)
	_build_bioluminescent_specks(bounds)
	_build_depth_haze(bounds)
	_build_canyon_blend(bounds)

	_last_bounds = bounds
	_last_top_y = top_y
	_last_bottom_y = bottom_y

	print(
		"ABYSS V2 READY: ", ABYSS_TOP_M, "-", ABYSS_BOTTOM_M,
		"m / fade=", CANYON_FADE_START_M, "-", CANYON_FADE_END_M,
		"m / world_bottom=", snappedf(bottom_y, 1.0), "px"
	)


func _build_depth_backdrop(bounds: Vector2, top_y: float, bottom_y: float) -> void:
	var top_color: Color = Color(0.004, 0.028, 0.060, 0.82)
	var middle_color: Color = Color(0.003, 0.018, 0.040, 0.92)
	var bottom_color: Color = Color(0.001, 0.006, 0.016, 0.99)
	var band_count: int = 14

	for i: int in range(band_count):
		var t0: float = float(i) / float(band_count)
		var t1: float = float(i + 1) / float(band_count)
		var y0: float = lerpf(top_y, bottom_y, t0)
		var y1: float = lerpf(top_y, bottom_y, t1)
		var color_t: Color
		if t1 < 0.48:
			color_t = top_color.lerp(middle_color, t1 / 0.48)
		else:
			color_t = middle_color.lerp(bottom_color, (t1 - 0.48) / 0.52)

		var band: Polygon2D = _make_rect_polygon(bounds.x, bounds.y, y0, y1)
		band.name = "AbyssDepthBand%02d" % i
		band.z_as_relative = false
		band.z_index = ABYSS_BACKGROUND_Z
		band.color = color_t
		_abyss_root.add_child(band)


func _build_side_continuation(bounds: Vector2, bottom_y: float) -> void:
	var left: float = bounds.x
	var right: float = bounds.y
	var width: float = right - left

	# Far walls continue the visual language of the HQ canyon without trying to
	# redraw the detailed source art. They are intentionally silhouette-like.
	var left_far: Polygon2D = Polygon2D.new()
	left_far.name = "AbyssLeftFarWall"
	left_far.z_as_relative = false
	left_far.z_index = ABYSS_ROCK_Z
	left_far.color = Color(0.004, 0.026, 0.050, 0.96)
	left_far.polygon = PackedVector2Array([
		Vector2(left, _world_y_for_depth(176.0)),
		Vector2(left + width * 0.040, _world_y_for_depth(183.0)),
		Vector2(left + width * 0.075, _world_y_for_depth(190.0)),
		Vector2(left + width * 0.115, _world_y_for_depth(202.0)),
		Vector2(left + width * 0.155, _world_y_for_depth(216.0)),
		Vector2(left + width * 0.205, _world_y_for_depth(231.0)),
		Vector2(left + width * 0.265, _world_y_for_depth(243.0)),
		Vector2(left + width * 0.310, bottom_y),
		Vector2(left, bottom_y)
	])
	_abyss_root.add_child(left_far)

	var right_far: Polygon2D = Polygon2D.new()
	right_far.name = "AbyssRightFarWall"
	right_far.z_as_relative = false
	right_far.z_index = ABYSS_ROCK_Z
	right_far.color = Color(0.004, 0.026, 0.050, 0.96)
	right_far.polygon = PackedVector2Array([
		Vector2(right, _world_y_for_depth(176.0)),
		Vector2(right - width * 0.038, _world_y_for_depth(184.0)),
		Vector2(right - width * 0.072, _world_y_for_depth(191.0)),
		Vector2(right - width * 0.110, _world_y_for_depth(203.0)),
		Vector2(right - width * 0.152, _world_y_for_depth(217.0)),
		Vector2(right - width * 0.202, _world_y_for_depth(232.0)),
		Vector2(right - width * 0.258, _world_y_for_depth(244.0)),
		Vector2(right - width * 0.305, bottom_y),
		Vector2(right, bottom_y)
	])
	_abyss_root.add_child(right_far)

	# Slightly brighter inner ridges keep the lower biome readable instead of a
	# single black rectangle.
	var left_inner: Polygon2D = Polygon2D.new()
	left_inner.name = "AbyssLeftInnerRidge"
	left_inner.z_as_relative = false
	left_inner.z_index = ABYSS_ROCK_Z
	left_inner.color = Color(0.008, 0.045, 0.078, 0.74)
	left_inner.polygon = PackedVector2Array([
		Vector2(left, bottom_y),
		Vector2(left + width * 0.080, _world_y_for_depth(194.0)),
		Vector2(left + width * 0.110, _world_y_for_depth(201.0)),
		Vector2(left + width * 0.135, _world_y_for_depth(210.0)),
		Vector2(left + width * 0.170, _world_y_for_depth(219.0)),
		Vector2(left + width * 0.205, _world_y_for_depth(229.0)),
		Vector2(left + width * 0.245, _world_y_for_depth(239.0)),
		Vector2(left + width * 0.285, _world_y_for_depth(248.0)),
		Vector2(left + width * 0.305, bottom_y)
	])
	_abyss_root.add_child(left_inner)

	var right_inner: Polygon2D = Polygon2D.new()
	right_inner.name = "AbyssRightInnerRidge"
	right_inner.z_as_relative = false
	right_inner.z_index = ABYSS_ROCK_Z
	right_inner.color = Color(0.008, 0.045, 0.078, 0.74)
	right_inner.polygon = PackedVector2Array([
		Vector2(right, bottom_y),
		Vector2(right - width * 0.078, _world_y_for_depth(195.0)),
		Vector2(right - width * 0.108, _world_y_for_depth(202.0)),
		Vector2(right - width * 0.134, _world_y_for_depth(211.0)),
		Vector2(right - width * 0.168, _world_y_for_depth(220.0)),
		Vector2(right - width * 0.202, _world_y_for_depth(230.0)),
		Vector2(right - width * 0.242, _world_y_for_depth(240.0)),
		Vector2(right - width * 0.282, _world_y_for_depth(248.0)),
		Vector2(right - width * 0.302, bottom_y)
	])
	_abyss_root.add_child(right_inner)


func _build_floor_ridge(bounds: Vector2, bottom_y: float) -> void:
	var width: float = bounds.y - bounds.x
	var floor: Polygon2D = Polygon2D.new()
	floor.name = "AbyssFloorRidge"
	floor.z_as_relative = false
	floor.z_index = ABYSS_ROCK_Z
	floor.color = Color(0.003, 0.020, 0.036, 0.98)
	floor.polygon = PackedVector2Array([
		Vector2(bounds.x, bottom_y),
		Vector2(bounds.x, _world_y_for_depth(245.0)),
		Vector2(bounds.x + width * 0.10, _world_y_for_depth(242.0)),
		Vector2(bounds.x + width * 0.19, _world_y_for_depth(247.0)),
		Vector2(bounds.x + width * 0.29, _world_y_for_depth(243.5)),
		Vector2(bounds.x + width * 0.39, _world_y_for_depth(248.5)),
		Vector2(bounds.x + width * 0.50, _world_y_for_depth(244.5)),
		Vector2(bounds.x + width * 0.61, _world_y_for_depth(248.0)),
		Vector2(bounds.x + width * 0.72, _world_y_for_depth(243.0)),
		Vector2(bounds.x + width * 0.82, _world_y_for_depth(247.0)),
		Vector2(bounds.x + width * 0.91, _world_y_for_depth(242.5)),
		Vector2(bounds.y, _world_y_for_depth(245.0)),
		Vector2(bounds.y, bottom_y)
	])
	_abyss_root.add_child(floor)


func _build_depth_haze(bounds: Vector2) -> void:
	# Sparse low-alpha haze bands add depth without hiding future fish.
	var haze_depths: Array[float] = [188.0, 204.0, 221.0, 236.0]
	for i: int in range(haze_depths.size()):
		var center_m: float = haze_depths[i]
		var half_height_m: float = 2.2 + float(i) * 0.6
		var haze: Polygon2D = _make_rect_polygon(
			bounds.x,
			bounds.y,
			_world_y_for_depth(center_m - half_height_m),
			_world_y_for_depth(center_m + half_height_m)
		)
		haze.name = "AbyssHaze%02d" % i
		haze.z_as_relative = false
		haze.z_index = ABYSS_BLEND_Z
		haze.color = Color(0.025, 0.095, 0.145, 0.035 + float(i) * 0.012)
		_abyss_root.add_child(haze)


func _build_canyon_blend(bounds: Vector2) -> void:
	# This overlay is intentionally above the canyon sprite. It starts almost
	# invisible before 180 m and gradually covers the hard source-image bottom.
	var start_y: float = _world_y_for_depth(CANYON_FADE_START_M)
	var end_y: float = _world_y_for_depth(CANYON_FADE_END_M)
	var steps: int = 10

	for i: int in range(steps):
		var t0: float = float(i) / float(steps)
		var t1: float = float(i + 1) / float(steps)
		var band: Polygon2D = _make_rect_polygon(
			bounds.x,
			bounds.y,
			lerpf(start_y, end_y, t0),
			lerpf(start_y, end_y, t1)
		)
		band.name = "CanyonToAbyssBlend%02d" % i
		band.z_as_relative = false
		band.z_index = ABYSS_BLEND_Z
		var alpha: float = lerpf(0.015, 0.82, pow(t1, 1.65))
		band.color = Color(0.003, 0.018, 0.038, alpha)
		_abyss_root.add_child(band)


func _build_bioluminescent_specks(bounds: Vector2) -> void:
	var width: float = bounds.y - bounds.x
	for i: int in range(44):
		var x_ratio: float = fmod(float(i * 37 + 11), 103.0) / 102.0
		var depth_m: float = 190.0 + fmod(float(i * 23 + 7), 57.0)
		var x: float = bounds.x + width * x_ratio
		var y: float = _world_y_for_depth(depth_m)
		var size: float = 2.8 + float(i % 5) * 0.85

		var speck: Polygon2D = Polygon2D.new()
		speck.name = "AbyssGlow%02d" % i
		speck.z_as_relative = false
		speck.z_index = ABYSS_BLEND_Z
		speck.polygon = PackedVector2Array([
			Vector2(x, y - size),
			Vector2(x + size * 0.70, y - size * 0.70),
			Vector2(x + size, y),
			Vector2(x + size * 0.70, y + size * 0.70),
			Vector2(x, y + size),
			Vector2(x - size * 0.70, y + size * 0.70),
			Vector2(x - size, y),
			Vector2(x - size * 0.70, y - size * 0.70)
		])
		match i % 4:
			0:
				speck.color = Color(0.18, 0.82, 1.0, 0.48)
			1:
				speck.color = Color(0.30, 0.62, 1.0, 0.40)
			2:
				speck.color = Color(0.42, 0.38, 1.0, 0.32)
			_:
				speck.color = Color(0.18, 0.68, 0.78, 0.36)
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
