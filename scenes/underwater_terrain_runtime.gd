extends Node

# TinyFisher grounded canyon compositor.
#
# V24 keeps the exact grounded canyon layout from V23 and adds the next
# approved environment asset: shallow_kelp_01.png.
#
# Important placement rule:
# - The current map has no real solid 0-20 m shelf yet.
# - Kelp is therefore NOT allowed to float in the shallow-water band.
# - It is attached only to the highest existing solid canyon ledges.
# - Each kelp pivot is anchored at its base, so sway animation cannot detach
#   the plant from the rock surface.
# - No collision is added; this remains visual terrain/decor only.

const TERRAIN_NODE_NAME := "UnderwaterCanyonTerrain20To100"
const LAYOUT_VERSION := 24

const TOP_M := 20.0
const BOTTOM_M := 100.0
const SEABED_DEPTH_M := 100.0

const FALLBACK_LEFT := -1000.0
const FALLBACK_RIGHT := 11000.0
const FALLBACK_PPM := 34.5
const FALLBACK_ZERO_Y := 392.6

# Water is -9. Keep the canyon above the water shader and behind gameplay.
const TERRAIN_Z := -4

# Exact horizontal composition. With the current 1280 px viewport and the
# natural width of the tall rock, this leaves a navigable open-water channel
# without allowing multiple formations to pile on top of one another.
const SPIRE_SPACING_X := 2200.0
const FIRST_SPIRE_OFFSET_X := 900.0
const MIN_HORIZONTAL_GAP := 90.0

const ROCK_TALL := "res://assets/environment/deep_sea/deep_sea_rock_01.png"
const ROCK_FLOOR := "res://assets/environment/deep_sea/deep_sea_rock_02.png"
const KELP_TEXTURE := "res://assets/environment/shallow/shallow_kelp_01.png"

# Top edge of each seabed-connected spire. The pattern repeats across X.
# These are not sprite center depths: they are the exact desired TOP depth.
const SPIRE_TOP_DEPTH_PATTERN := [44.0, 48.0, 52.0, 46.0, 50.0, 45.0]

# The map currently has no grounded 0-20 m shelf. Only the highest existing
# ledges are eligible for kelp, so the shallow asset never floats in blue water.
const KELP_MAX_LEDGE_DEPTH_M := 48.0
const KELP_TARGET_HEIGHT_PATTERN := [155.0, 132.0, 146.0, 125.0]
const KELP_SWAY_SPEED := 0.85
const KELP_SWAY_RADIANS := 0.035

var _scene_id := 0
var _world: Node2D = null
var _root: Node2D = null
var _last_ppm := -1.0
var _last_left := INF
var _last_right := INF

var _textures: Dictionary = {}
var _occupied_x: Array[Vector2] = []
var _kelp_pivots: Array[Node2D] = []
var _kelp_time := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	print("UNDERWATER TERRAIN V24: GROUNDED CANYON + GROUNDED KELP / NO FLOATING DECOR")


func _process(delta: float) -> void:
	var scene := get_tree().current_scene
	if scene == null:
		_reset()
		return

	if scene.get_instance_id() != _scene_id:
		_scene_id = scene.get_instance_id()
		_world = scene as Node2D
		_root = null
		_last_ppm = -1.0
		_last_left = INF
		_last_right = INF
		_kelp_pivots.clear()
		_kelp_time = 0.0

	if _world == null:
		return

	var bounds := _get_world_horizontal_bounds()
	var ppm := _pixels_per_meter()

	if not is_instance_valid(_root):
		_rebuild_terrain(bounds, ppm)
	elif not is_equal_approx(bounds.x, _last_left) \
	or not is_equal_approx(bounds.y, _last_right) \
	or not is_equal_approx(ppm, _last_ppm):
		_rebuild_terrain(bounds, ppm)

	_animate_kelp(delta)


func _reset() -> void:
	_scene_id = 0
	_world = null
	_root = null
	_last_ppm = -1.0
	_last_left = INF
	_last_right = INF
	_occupied_x.clear()
	_kelp_pivots.clear()
	_kelp_time = 0.0


func _rebuild_terrain(bounds: Vector2, ppm: float) -> void:
	_remove_old_terrain()
	_cache_textures()

	if not _textures.has(ROCK_TALL) or not _textures.has(ROCK_FLOOR):
		push_error("Underwater terrain: gerekli HQ kaya texture'lari bulunamadi.")
		return

	_root = Node2D.new()
	_root.name = TERRAIN_NODE_NAME
	_root.z_as_relative = false
	_root.z_index = TERRAIN_Z
	_root.set_meta("layout_version", LAYOUT_VERSION)
	_root.set_meta("collisionless", true)
	_root.set_meta("camera_locked", false)
	_root.set_meta("depth_top_m", TOP_M)
	_root.set_meta("depth_bottom_m", BOTTOM_M)
	_root.set_meta("terrain_source", "grounded_hq_png_canyon")
	_root.set_meta("environment_asset_kelp", true)
	_world.add_child(_root)

	_occupied_x.clear()
	_kelp_pivots.clear()
	_build_seabed_mass(bounds)
	_build_grounded_spires(bounds)
	_build_floor_detail(bounds)
	_build_grounded_kelp(bounds)

	_last_left = bounds.x
	_last_right = bounds.y
	_last_ppm = ppm

	print(
		"HQ CANYON GROUNDED: V%d / X %.0f..%.0f / %.2f px-m / terrain=%d / kelp=%d" % [
			LAYOUT_VERSION,
			bounds.x,
			bounds.y,
			ppm,
			_occupied_x.size(),
			_kelp_pivots.size()
		]
	)


func _cache_textures() -> void:
	if not _textures.is_empty():
		return

	for path_variant in [ROCK_TALL, ROCK_FLOOR, KELP_TEXTURE]:
		var path := String(path_variant)
		var texture := load(path) as Texture2D
		if texture != null and texture.get_width() > 0 and texture.get_height() > 0:
			_textures[path] = texture
		else:
			push_warning("Underwater terrain texture atlandi: " + path)


func _build_seabed_mass(bounds: Vector2) -> void:
	if not is_instance_valid(_root):
		return

	var seabed_y := _world_y_for_depth(SEABED_DEPTH_M)
	var bottom_y := seabed_y + 900.0
	var width := bounds.y - bounds.x
	var step := 400.0
	var point_count := int(ceil(width / step)) + 1

	var points := PackedVector2Array()

	# A deterministic, low-amplitude contour. This is the solid visual mass that
	# every canyon rock touches; it prevents a rock base from ever hanging in blue.
	for i in range(point_count + 1):
		var x := minf(bounds.x + float(i) * step, bounds.y)
		var wave := sin(float(i) * 1.37) * 18.0 + sin(float(i) * 0.53) * 11.0
		points.append(Vector2(x, seabed_y + wave))

	points.append(Vector2(bounds.y, bottom_y))
	points.append(Vector2(bounds.x, bottom_y))

	var seabed := Polygon2D.new()
	seabed.name = "SeabedMass"
	seabed.polygon = points
	seabed.color = Color(0.018, 0.055, 0.095, 1.0)
	seabed.z_index = -1
	_root.add_child(seabed)


func _build_grounded_spires(bounds: Vector2) -> void:
	var texture: Texture2D = _textures.get(ROCK_TALL) as Texture2D
	if texture == null:
		return

	var x := bounds.x + FIRST_SPIRE_OFFSET_X
	var index := 0

	# Include one formation slightly beyond the right edge so the world boundary
	# never exposes a naked cut in the composition.
	while x <= bounds.y + FIRST_SPIRE_OFFSET_X:
		var top_depth := float(SPIRE_TOP_DEPTH_PATTERN[index % SPIRE_TOP_DEPTH_PATTERN.size()])
		_add_grounded_spire(texture, x, top_depth, index)
		x += SPIRE_SPACING_X
		index += 1


func _add_grounded_spire(texture: Texture2D, center_x: float, top_depth_m: float, index: int) -> void:
	var source_size := texture.get_size()
	if source_size.x <= 0.0 or source_size.y <= 0.0:
		return

	var top_y := _world_y_for_depth(top_depth_m)
	var seabed_y := _seabed_y_at_x(center_x)
	var target_height := maxf(seabed_y - top_y, 1.0)

	# Uniform scale only: width is derived from the PNG's real aspect ratio.
	# deep_sea_rock_01 is 520x560, so there is no arbitrary X/Y stretching.
	var scale_factor := target_height / source_size.y
	var rendered_width := source_size.x * scale_factor

	var interval := Vector2(
		center_x - rendered_width * 0.5,
		center_x + rendered_width * 0.5
	)

	if not _reserve_interval(interval):
		return

	var sprite := Sprite2D.new()
	sprite.name = "GroundedSpire_%02d" % index
	sprite.texture = texture
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.position = Vector2(center_x, seabed_y - target_height * 0.5)
	sprite.scale = Vector2(
		-scale_factor if index % 2 == 1 else scale_factor,
		scale_factor
	)
	sprite.rotation = 0.0
	sprite.modulate = Color(0.76, 0.86, 0.97, 0.98)
	sprite.set_meta("grounded", true)
	sprite.set_meta("top_depth_m", top_depth_m)
	sprite.set_meta("bottom_depth_m", SEABED_DEPTH_M)
	_root.add_child(sprite)


func _build_floor_detail(bounds: Vector2) -> void:
	var texture: Texture2D = _textures.get(ROCK_FLOOR) as Texture2D
	if texture == null:
		return

	var source_size := texture.get_size()
	if source_size.x <= 0.0 or source_size.y <= 0.0:
		return

	# One small grounded boulder in the middle of each spire gap. Its exact width
	# is intentionally capped so the interval check keeps a visible gap from the
	# neighbouring spires. These only decorate the true 100 m seabed.
	var x := bounds.x + FIRST_SPIRE_OFFSET_X + SPIRE_SPACING_X * 0.5
	var index := 0
	var target_width := 480.0
	var scale_factor := target_width / source_size.x
	var rendered_height := source_size.y * scale_factor

	while x <= bounds.y:
		var interval := Vector2(x - target_width * 0.5, x + target_width * 0.5)
		if _reserve_interval(interval):
			var seabed_y := _seabed_y_at_x(x)
			var sprite := Sprite2D.new()
			sprite.name = "SeabedRock_%02d" % index
			sprite.texture = texture
			sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			sprite.position = Vector2(x, seabed_y - rendered_height * 0.5)
			sprite.scale = Vector2(
				-scale_factor if index % 2 == 1 else scale_factor,
				scale_factor
			)
			sprite.rotation = 0.0
			sprite.modulate = Color(0.65, 0.76, 0.89, 1.0)
			sprite.set_meta("grounded", true)
			_root.add_child(sprite)

		x += SPIRE_SPACING_X
		index += 1


func _build_grounded_kelp(bounds: Vector2) -> void:
	var texture: Texture2D = _textures.get(KELP_TEXTURE) as Texture2D
	if texture == null:
		push_warning("Kelp texture bulunamadi; terrain kelpsiz devam ediyor.")
		return

	var source_size := texture.get_size()
	if source_size.x <= 0.0 or source_size.y <= 0.0:
		return

	var x := bounds.x + FIRST_SPIRE_OFFSET_X
	var spire_index := 0
	var kelp_index := 0

	while x <= bounds.y:
		var top_depth := float(SPIRE_TOP_DEPTH_PATTERN[spire_index % SPIRE_TOP_DEPTH_PATTERN.size()])

		# Only the highest solid ledges receive this asset. We intentionally do not
		# fake a shallow floor just to place kelp at 0-20 m.
		if top_depth <= KELP_MAX_LEDGE_DEPTH_M:
			var anchor_y := _world_y_for_depth(top_depth) + 7.0
			var target_height := float(
				KELP_TARGET_HEIGHT_PATTERN[kelp_index % KELP_TARGET_HEIGHT_PATTERN.size()]
			)
			var scale_factor := target_height / source_size.y

			var pivot := Node2D.new()
			pivot.name = "GroundedKelpPivot_%02d" % kelp_index
			pivot.position = Vector2(x, anchor_y)
			pivot.z_index = 2
			pivot.set_meta("grounded", true)
			pivot.set_meta("anchor_depth_m", top_depth)
			pivot.set_meta("environment_asset", "shallow_kelp_01.png")
			pivot.set_meta("sway_phase", float(kelp_index) * 1.73)
			_root.add_child(pivot)

			# Sprite origin sits half a rendered plant above the pivot, making the
			# pivot itself the root/base of the kelp. Rotation therefore never makes
			# the root slide away from the rock.
			var sprite := Sprite2D.new()
			sprite.name = "KelpVisual"
			sprite.texture = texture
			sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			sprite.position = Vector2(0.0, -target_height * 0.5)
			sprite.scale = Vector2(
				-scale_factor if kelp_index % 2 == 1 else scale_factor,
				scale_factor
			)
			sprite.modulate = Color(0.62, 0.84, 0.78, 0.88)
			pivot.add_child(sprite)

			_kelp_pivots.append(pivot)
			kelp_index += 1

		x += SPIRE_SPACING_X
		spire_index += 1


func _animate_kelp(delta: float) -> void:
	if _kelp_pivots.is_empty():
		return

	_kelp_time += delta

	for pivot in _kelp_pivots:
		if not is_instance_valid(pivot):
			continue

		var phase := float(pivot.get_meta("sway_phase", 0.0))
		pivot.rotation = sin(_kelp_time * KELP_SWAY_SPEED + phase) * KELP_SWAY_RADIANS


func _reserve_interval(interval: Vector2) -> bool:
	for used in _occupied_x:
		if interval.x < used.y + MIN_HORIZONTAL_GAP and interval.y > used.x - MIN_HORIZONTAL_GAP:
			return false

	_occupied_x.append(interval)
	return true


func _seabed_y_at_x(world_x: float) -> float:
	var bounds := _get_world_horizontal_bounds()
	var normalized := (world_x - bounds.x) / 400.0
	var wave := sin(normalized * 1.37) * 18.0 + sin(normalized * 0.53) * 11.0
	return _world_y_for_depth(SEABED_DEPTH_M) + wave


func _get_world_horizontal_bounds() -> Vector2:
	if _world != null:
		var water := _world.get_node_or_null("Water") as Control
		if water != null:
			var left := water.position.x
			var right := water.position.x + water.size.x
			if right - left >= 1280.0:
				return Vector2(left, right)

	return Vector2(FALLBACK_LEFT, FALLBACK_RIGHT)


func _pixels_per_meter() -> float:
	if _world == null:
		return FALLBACK_PPM

	var hook := _world.get_node_or_null("Boat/Hook") as Node2D
	if hook == null:
		return FALLBACK_PPM

	var max_depth_pixels := float(hook.get("max_depth"))
	var max_depth_meters := float(hook.get("max_depth_meters"))
	if max_depth_pixels <= 0.0 or max_depth_meters <= 0.0:
		return FALLBACK_PPM

	return max_depth_pixels / max_depth_meters


func _world_y_for_depth(depth_meters: float) -> float:
	if _world == null:
		return FALLBACK_ZERO_Y + depth_meters * FALLBACK_PPM

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
	if _world == null:
		return

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

	_root = null
