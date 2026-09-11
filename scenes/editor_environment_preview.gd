@tool
extends Node2D

# Editor-only preview for TinyFisher's runtime-generated underwater terrain.
# This node NEVER builds gameplay terrain while the game is running.
# It exists only so the 2D editor can show the same canyon/kelp composition
# that runtime scripts create after pressing Play.

const PREVIEW_ROOT_NAME: String = "__GeneratedEnvironmentPreview"

const WORLD_LEFT_X: float = -1000.0
const WORLD_RIGHT_X: float = 11000.0
const FALLBACK_PPM: float = 34.5
const FALLBACK_ZERO_Y: float = 392.6
const SEABED_DEPTH_M: float = 100.0

const SPIRE_SPACING_X: float = 2200.0
const FIRST_SPIRE_OFFSET_X: float = 900.0
const MIN_HORIZONTAL_GAP: float = 90.0
const SPIRE_TOP_DEPTH_PATTERN: Array[float] = [44.0, 48.0, 52.0, 46.0, 50.0, 45.0]

const ROCK_TALL_PATH: String = "res://assets/environment/deep_sea/deep_sea_rock_01.png"
const ROCK_FLOOR_PATH: String = "res://assets/environment/deep_sea/deep_sea_rock_02.png"
const KELP_PATH: String = "res://assets/environment/shallow/shallow_kelp_01.png"

const ALPHA_THRESHOLD: float = 0.18
const APEX_CLEARANCE_PX: int = 28
const PROFILE_MARGIN_RATIO: float = 0.10
const SEARCH_RADIUS_RATIO: float = 0.075
const STABILITY_WINDOW_RATIO: float = 0.022
const MAX_LOCAL_ROUGHNESS_PX: int = 34
const MIN_SOURCE_X_SPACING_PX: float = 46.0
const SUPPORT_HALF_WIDTH_RATIO: float = 0.020
const SUPPORT_DEPTH_RATIO: float = 0.060
const MIN_SUPPORT_FILL_RATIO: float = 0.40
const CONTACT_HALF_WIDTH_RATIO: float = 0.034
const CONTACT_DEPTH_RATIO: float = 0.052
const MAX_NEIGHBOR_SURFACE_DELTA_PX: int = 30
const MIN_COLUMN_CONTINUITY: float = 0.90
const MIN_STRONG_COLUMN_RATIO: float = 0.62
const KELP_WORLD_CLEARANCE_PX: float = 14.0
const MAX_BASE_LEAN_RADIANS: float = 0.24

const TARGET_X_RATIOS: Array[float] = [0.17, 0.29, 0.41, 0.70, 0.83]
const HEIGHT_PATTERN: Array[float] = [104.0, 121.0, 111.0, 128.0, 98.0]
const CANDIDATE_RATIO_OFFSETS: Array[float] = [0.0, -0.035, 0.035, -0.070, 0.070, -0.105, 0.105]
const KELP_TINT: Color = Color(0.40, 0.55, 0.55, 0.76)

@export var show_preview: bool = true
@export var show_editor_depth_band: bool = true

var _preview_root: Node2D = null
var _rock_tall: Texture2D = null
var _rock_floor: Texture2D = null
var _kelp_texture: Texture2D = null
var _kelp_base_source_px: Vector2 = Vector2(-1.0, -1.0)
var _kelp_used_rect: Rect2i = Rect2i()
var _occupied_x: Array[Vector2] = []


func _ready() -> void:
	if not Engine.is_editor_hint():
		visible = false
		set_process(false)
		return

	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("_rebuild_preview")


func _process(_delta: float) -> void:
	if not Engine.is_editor_hint():
		return

	if not show_preview:
		if is_instance_valid(_preview_root):
			_preview_root.visible = false
		return

	if not is_instance_valid(_preview_root):
		_rebuild_preview()
	else:
		_preview_root.visible = true


func _rebuild_preview() -> void:
	if not Engine.is_editor_hint():
		return

	_clear_preview()
	if not show_preview:
		return

	_load_assets()
	if _rock_tall == null or _rock_floor == null:
		return

	_preview_root = Node2D.new()
	_preview_root.name = PREVIEW_ROOT_NAME
	_preview_root.z_as_relative = false
	add_child(_preview_root, false, Node.INTERNAL_MODE_BACK)

	var bounds: Vector2 = _world_bounds()
	if show_editor_depth_band:
		_build_editor_depth_band(bounds)

	_occupied_x.clear()
	_build_seabed_mass(bounds)
	_build_spires(bounds)
	_build_floor_rocks(bounds)


func _clear_preview() -> void:
	if is_instance_valid(_preview_root):
		remove_child(_preview_root)
		_preview_root.free()
	_preview_root = null
	_occupied_x.clear()


func _load_assets() -> void:
	_rock_tall = load(ROCK_TALL_PATH) as Texture2D
	_rock_floor = load(ROCK_FLOOR_PATH) as Texture2D
	_kelp_texture = load(KELP_PATH) as Texture2D

	if _kelp_texture != null:
		var kelp_image: Image = _kelp_texture.get_image()
		if kelp_image != null and not kelp_image.is_empty():
			_kelp_base_source_px = _find_kelp_base_pixel(kelp_image)
			_kelp_used_rect = kelp_image.get_used_rect()


func _build_editor_depth_band(bounds: Vector2) -> void:
	var top_y: float = _world_y_for_depth(20.0)
	var bottom_y: float = _world_y_for_depth(100.0) + 850.0
	var polygon: Polygon2D = Polygon2D.new()
	polygon.name = "EditorDepthBand"
	polygon.z_as_relative = false
	polygon.z_index = -8
	polygon.polygon = PackedVector2Array([
		Vector2(bounds.x, top_y),
		Vector2(bounds.y, top_y),
		Vector2(bounds.y, bottom_y),
		Vector2(bounds.x, bottom_y)
	])
	polygon.color = Color(0.025, 0.075, 0.12, 0.58)
	_preview_root.add_child(polygon, false, Node.INTERNAL_MODE_BACK)


func _build_seabed_mass(bounds: Vector2) -> void:
	var seabed_y: float = _world_y_for_depth(SEABED_DEPTH_M)
	var bottom_y: float = seabed_y + 900.0
	var width: float = bounds.y - bounds.x
	var step: float = 400.0
	var point_count: int = int(ceil(width / step)) + 1
	var points: PackedVector2Array = PackedVector2Array()

	for i: int in range(point_count + 1):
		var x: float = minf(bounds.x + float(i) * step, bounds.y)
		var wave: float = sin(float(i) * 1.37) * 18.0 + sin(float(i) * 0.53) * 11.0
		points.append(Vector2(x, seabed_y + wave))

	points.append(Vector2(bounds.y, bottom_y))
	points.append(Vector2(bounds.x, bottom_y))

	var seabed: Polygon2D = Polygon2D.new()
	seabed.name = "PreviewSeabedMass"
	seabed.z_as_relative = false
	seabed.z_index = -5
	seabed.polygon = points
	seabed.color = Color(0.018, 0.055, 0.095, 1.0)
	_preview_root.add_child(seabed, false, Node.INTERNAL_MODE_BACK)


func _build_spires(bounds: Vector2) -> void:
	if _rock_tall == null:
		return

	var x: float = bounds.x + FIRST_SPIRE_OFFSET_X
	var index: int = 0
	while x <= bounds.y + FIRST_SPIRE_OFFSET_X:
		var top_depth: float = SPIRE_TOP_DEPTH_PATTERN[index % SPIRE_TOP_DEPTH_PATTERN.size()]
		_add_spire(x, top_depth, index)
		x += SPIRE_SPACING_X
		index += 1


func _add_spire(center_x: float, top_depth_m: float, index: int) -> void:
	var source_size: Vector2 = _rock_tall.get_size()
	if source_size.x <= 0.0 or source_size.y <= 0.0:
		return

	var top_y: float = _world_y_for_depth(top_depth_m)
	var seabed_y: float = _seabed_y_at_x(center_x)
	var target_height: float = maxf(seabed_y - top_y, 1.0)
	var scale_factor: float = target_height / source_size.y
	var rendered_width: float = source_size.x * scale_factor
	var interval: Vector2 = Vector2(center_x - rendered_width * 0.5, center_x + rendered_width * 0.5)
	if not _reserve_interval(interval):
		return

	var spire: Sprite2D = Sprite2D.new()
	spire.name = "PreviewSpire_%02d" % index
	spire.texture = _rock_tall
	spire.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	spire.position = Vector2(center_x, seabed_y - target_height * 0.5)
	spire.scale = Vector2(-scale_factor if index % 2 == 1 else scale_factor, scale_factor)
	spire.z_as_relative = false
	spire.z_index = -4
	spire.modulate = Color(0.76, 0.86, 0.97, 0.98)
	_preview_root.add_child(spire, false, Node.INTERNAL_MODE_BACK)

	_build_kelp_for_spire(spire, index)


func _build_floor_rocks(bounds: Vector2) -> void:
	if _rock_floor == null:
		return

	var source_size: Vector2 = _rock_floor.get_size()
	if source_size.x <= 0.0 or source_size.y <= 0.0:
		return

	var x: float = bounds.x + FIRST_SPIRE_OFFSET_X + SPIRE_SPACING_X * 0.5
	var index: int = 0
	var target_width: float = 480.0
	var scale_factor: float = target_width / source_size.x
	var rendered_height: float = source_size.y * scale_factor

	while x <= bounds.y:
		var interval: Vector2 = Vector2(x - target_width * 0.5, x + target_width * 0.5)
		if _reserve_interval(interval):
			var rock: Sprite2D = Sprite2D.new()
			rock.name = "PreviewFloorRock_%02d" % index
			rock.texture = _rock_floor
			rock.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			rock.position = Vector2(x, _seabed_y_at_x(x) - rendered_height * 0.5)
			rock.scale = Vector2(-scale_factor if index % 2 == 1 else scale_factor, scale_factor)
			rock.z_as_relative = false
			rock.z_index = -4
			rock.modulate = Color(0.65, 0.76, 0.89, 1.0)
			_preview_root.add_child(rock, false, Node.INTERNAL_MODE_BACK)
		x += SPIRE_SPACING_X
		index += 1


func _build_kelp_for_spire(spire: Sprite2D, spire_index: int) -> void:
	if _kelp_texture == null or _kelp_base_source_px.x < 0.0 or spire.texture == null:
		return

	var rock_image: Image = spire.texture.get_image()
	if rock_image == null or rock_image.is_empty():
		return

	var rock_size: Vector2 = spire.texture.get_size()
	var kelp_size: Vector2 = _kelp_texture.get_size()
	var global_top_y: int = _find_global_top_y(rock_image)
	if global_top_y < 0:
		return

	var wanted_count: int = 5 if spire_index % 2 == 0 else 4
	var ratios: Array[float] = TARGET_X_RATIOS.duplicate()
	if wanted_count == 4:
		ratios.remove_at(2)

	var used_source_x: Array[float] = []
	var used_world_bounds: Array[Rect2] = []

	for local_index: int in range(ratios.size()):
		var height_index: int = (spire_index * 2 + local_index) % HEIGHT_PATTERN.size()
		var target_height: float = HEIGHT_PATTERN[height_index]
		var scale_factor: float = target_height / kelp_size.y
		var flip_x: float = -1.0 if (spire_index + local_index) % 2 == 1 else 1.0
		var kelp_scale: Vector2 = Vector2(flip_x * scale_factor, scale_factor)
		var blocked_source_x: Array[float] = used_source_x.duplicate()

		for ratio_offset: float in CANDIDATE_RATIO_OFFSETS:
			var target_ratio: float = clampf(ratios[local_index] + ratio_offset, PROFILE_MARGIN_RATIO, 1.0 - PROFILE_MARGIN_RATIO)
			var surface_px: Vector2 = _find_surface_near_ratio(rock_image, target_ratio, global_top_y, blocked_source_x)
			if surface_px.x < 0.0:
				continue
			if not _has_broad_continuous_rock_contact(rock_image, surface_px):
				blocked_source_x.append(surface_px.x)
				continue

			var anchor_local: Vector2 = _source_pixel_to_rendered_offset(surface_px, rock_size, spire.scale)
			var anchor_world: Vector2 = spire.position + anchor_local
			var base_lean: float = _surface_lean_at(rock_image, int(floor(surface_px.x)))
			if spire.scale.x < 0.0:
				base_lean = -base_lean
			base_lean = clampf(base_lean, -MAX_BASE_LEAN_RADIANS, MAX_BASE_LEAN_RADIANS)

			var candidate_bounds: Rect2 = _kelp_world_bounds(anchor_world, kelp_scale, base_lean)
			if _intersects_any(candidate_bounds, used_world_bounds):
				blocked_source_x.append(surface_px.x)
				continue

			var pivot: Node2D = Node2D.new()
			pivot.name = "PreviewKelp_%02d_%02d" % [spire_index, local_index]
			pivot.position = anchor_world
			pivot.rotation = base_lean
			pivot.z_as_relative = false
			pivot.z_index = -2
			_preview_root.add_child(pivot, false, Node.INTERNAL_MODE_BACK)

			var sprite: Sprite2D = Sprite2D.new()
			sprite.texture = _kelp_texture
			sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			sprite.scale = kelp_scale
			var kelp_base_rendered: Vector2 = _source_pixel_to_rendered_offset(_kelp_base_source_px, kelp_size, kelp_scale)
			sprite.position = -kelp_base_rendered
			sprite.modulate = KELP_TINT
			pivot.add_child(sprite, false, Node.INTERNAL_MODE_BACK)

			used_source_x.append(surface_px.x)
			used_world_bounds.append(candidate_bounds)
			break


func _find_surface_near_ratio(image: Image, target_ratio: float, global_top_y: int, blocked_source_x: Array[float]) -> Vector2:
	var width: int = image.get_width()
	if width <= 0:
		return Vector2(-1.0, -1.0)

	var margin: int = maxi(1, int(round(float(width) * PROFILE_MARGIN_RATIO)))
	var target_x: int = clampi(int(round(float(width - 1) * target_ratio)), margin, width - 1 - margin)
	var radius: int = maxi(8, int(round(float(width) * SEARCH_RADIUS_RATIO)))
	var window: int = maxi(3, int(round(float(width) * STABILITY_WINDOW_RATIO)))
	var best_x: int = -1
	var best_y: int = -1
	var best_score: float = INF
	var min_x: int = maxi(margin, target_x - radius)
	var max_x: int = mini(width - 1 - margin, target_x + radius)

	for x: int in range(min_x, max_x + 1):
		var y: int = _top_opaque_y(image, x)
		if y < 0 or y < global_top_y + APEX_CLEARANCE_PX:
			continue

		var too_close: bool = false
		for used_x: float in blocked_source_x:
			if absf(float(x) - used_x) < MIN_SOURCE_X_SPACING_PX:
				too_close = true
				break
		if too_close:
			continue

		var left_x: int = clampi(x - window, 0, width - 1)
		var right_x: int = clampi(x + window, 0, width - 1)
		var left_y: int = _top_opaque_y(image, left_x)
		var right_y: int = _top_opaque_y(image, right_x)
		if left_y < 0 or right_y < 0:
			continue

		var roughness: int = maxi(absi(y - left_y), absi(y - right_y))
		if roughness > MAX_LOCAL_ROUGHNESS_PX:
			continue

		var support_fill: float = _support_fill_ratio(image, x, y)
		if support_fill < MIN_SUPPORT_FILL_RATIO:
			continue

		var score: float = absf(float(x - target_x)) * 2.0 + float(roughness) * 1.4 - float(y - global_top_y) * 0.08 - support_fill * 24.0
		if score < best_score:
			best_score = score
			best_x = x
			best_y = y

	if best_x < 0:
		return Vector2(-1.0, -1.0)
	return Vector2(float(best_x) + 0.5, float(best_y) + 0.5)


func _support_fill_ratio(image: Image, source_x: int, surface_y: int) -> float:
	var width: int = image.get_width()
	var height: int = image.get_height()
	var half_width: int = maxi(5, int(round(float(width) * SUPPORT_HALF_WIDTH_RATIO)))
	var depth: int = maxi(16, int(round(float(height) * SUPPORT_DEPTH_RATIO)))
	var min_x: int = clampi(source_x - half_width, 0, width - 1)
	var max_x: int = clampi(source_x + half_width, 0, width - 1)
	var min_y: int = clampi(surface_y + 2, 0, height - 1)
	var max_y: int = clampi(surface_y + depth, 0, height - 1)
	var opaque_count: int = 0
	var total_count: int = 0

	for y: int in range(min_y, max_y + 1):
		for x: int in range(min_x, max_x + 1):
			total_count += 1
			if image.get_pixel(x, y).a >= ALPHA_THRESHOLD:
				opaque_count += 1

	if total_count <= 0:
		return 0.0
	return float(opaque_count) / float(total_count)


func _has_broad_continuous_rock_contact(image: Image, source_pixel: Vector2) -> bool:
	var width: int = image.get_width()
	var height: int = image.get_height()
	var source_x: int = clampi(int(floor(source_pixel.x)), 0, width - 1)
	var source_y: int = clampi(int(floor(source_pixel.y)), 0, height - 1)
	var half_width: int = maxi(8, int(round(float(width) * CONTACT_HALF_WIDTH_RATIO)))
	var depth: int = maxi(18, int(round(float(height) * CONTACT_DEPTH_RATIO)))
	var min_x: int = clampi(source_x - half_width, 0, width - 1)
	var max_x: int = clampi(source_x + half_width, 0, width - 1)
	var strong_columns: int = 0
	var sampled_columns: int = 0

	for x: int in range(min_x, max_x + 1):
		var local_top_y: int = _top_opaque_y(image, x)
		if local_top_y < 0:
			continue
		sampled_columns += 1
		if absi(local_top_y - source_y) > MAX_NEIGHBOR_SURFACE_DELTA_PX:
			continue
		var end_y: int = mini(height - 1, local_top_y + depth)
		var opaque_count: int = 0
		var run_count: int = 0
		for y: int in range(local_top_y, end_y + 1):
			run_count += 1
			if image.get_pixel(x, y).a >= ALPHA_THRESHOLD:
				opaque_count += 1
		if run_count > 0 and float(opaque_count) / float(run_count) >= MIN_COLUMN_CONTINUITY:
			strong_columns += 1

	if sampled_columns <= 0:
		return false
	return float(strong_columns) / float(sampled_columns) >= MIN_STRONG_COLUMN_RATIO


func _kelp_world_bounds(anchor_world: Vector2, kelp_scale: Vector2, base_rotation: float) -> Rect2:
	var x0: float = float(_kelp_used_rect.position.x)
	var y0: float = float(_kelp_used_rect.position.y)
	var x1: float = float(_kelp_used_rect.position.x + _kelp_used_rect.size.x)
	var y1: float = float(_kelp_used_rect.position.y + _kelp_used_rect.size.y)
	var source_corners: Array[Vector2] = [Vector2(x0, y0), Vector2(x1, y0), Vector2(x1, y1), Vector2(x0, y1)]
	var min_world: Vector2 = Vector2(INF, INF)
	var max_world: Vector2 = Vector2(-INF, -INF)

	for source_corner: Vector2 in source_corners:
		var from_root: Vector2 = source_corner - _kelp_base_source_px
		var scaled: Vector2 = Vector2(from_root.x * kelp_scale.x, from_root.y * kelp_scale.y)
		var world_point: Vector2 = anchor_world + scaled.rotated(base_rotation)
		min_world.x = minf(min_world.x, world_point.x)
		min_world.y = minf(min_world.y, world_point.y)
		max_world.x = maxf(max_world.x, world_point.x)
		max_world.y = maxf(max_world.y, world_point.y)

	var clearance: Vector2 = Vector2(KELP_WORLD_CLEARANCE_PX, KELP_WORLD_CLEARANCE_PX)
	return Rect2(min_world - clearance, (max_world - min_world) + clearance * 2.0)


func _intersects_any(candidate: Rect2, used_bounds: Array[Rect2]) -> bool:
	for used: Rect2 in used_bounds:
		if candidate.intersects(used):
			return true
	return false


func _find_global_top_y(image: Image) -> int:
	var width: int = image.get_width()
	var margin: int = maxi(1, int(round(float(width) * PROFILE_MARGIN_RATIO)))
	var best_y: int = -1
	for x: int in range(margin, width - margin):
		var y: int = _top_opaque_y(image, x)
		if y >= 0 and (best_y < 0 or y < best_y):
			best_y = y
	return best_y


func _surface_lean_at(image: Image, x: int) -> float:
	var width: int = image.get_width()
	var window: int = maxi(4, int(round(float(width) * STABILITY_WINDOW_RATIO)))
	var left_x: int = clampi(x - window, 0, width - 1)
	var right_x: int = clampi(x + window, 0, width - 1)
	var left_y: int = _top_opaque_y(image, left_x)
	var right_y: int = _top_opaque_y(image, right_x)
	if left_y < 0 or right_y < 0 or right_x == left_x:
		return 0.0
	return atan2(float(right_y - left_y), float(right_x - left_x))


func _find_kelp_base_pixel(image: Image) -> Vector2:
	var width: int = image.get_width()
	var height: int = image.get_height()
	var bottom_y: int = -1
	for y: int in range(height - 1, -1, -1):
		var found: bool = false
		for x: int in range(width):
			if image.get_pixel(x, y).a >= ALPHA_THRESHOLD:
				bottom_y = y
				found = true
				break
		if found:
			break
	if bottom_y < 0:
		return Vector2(-1.0, -1.0)

	var start_y: int = maxi(0, bottom_y - 7)
	var x_sum: float = 0.0
	var count: int = 0
	for y: int in range(start_y, bottom_y + 1):
		for x: int in range(width):
			if image.get_pixel(x, y).a >= ALPHA_THRESHOLD:
				x_sum += float(x) + 0.5
				count += 1
	var root_x: float = float(width) * 0.5
	if count > 0:
		root_x = x_sum / float(count)
	return Vector2(root_x, float(bottom_y) + 0.5)


func _top_opaque_y(image: Image, x: int) -> int:
	if x < 0 or x >= image.get_width():
		return -1
	for y: int in range(image.get_height()):
		if image.get_pixel(x, y).a >= ALPHA_THRESHOLD:
			return y
	return -1


func _source_pixel_to_rendered_offset(source_pixel: Vector2, texture_size: Vector2, sprite_scale: Vector2) -> Vector2:
	var centered: Vector2 = source_pixel - texture_size * 0.5
	return Vector2(centered.x * sprite_scale.x, centered.y * sprite_scale.y)


func _world_bounds() -> Vector2:
	var world: Node2D = get_parent() as Node2D
	if world != null:
		var water: Control = world.get_node_or_null("Water") as Control
		if water != null:
			var left: float = water.position.x
			var right: float = water.position.x + water.size.x
			if right - left >= 1280.0:
				return Vector2(left, right)
	return Vector2(WORLD_LEFT_X, WORLD_RIGHT_X)


func _world_y_for_depth(depth_meters: float) -> float:
	return FALLBACK_ZERO_Y + depth_meters * FALLBACK_PPM


func _seabed_y_at_x(world_x: float) -> float:
	var bounds: Vector2 = _world_bounds()
	var normalized: float = (world_x - bounds.x) / 400.0
	var wave: float = sin(normalized * 1.37) * 18.0 + sin(normalized * 0.53) * 11.0
	return _world_y_for_depth(SEABED_DEPTH_M) + wave


func _reserve_interval(interval: Vector2) -> bool:
	for used: Vector2 in _occupied_x:
		if interval.x < used.y + MIN_HORIZONTAL_GAP and interval.y > used.x - MIN_HORIZONTAL_GAP:
			return false
	_occupied_x.append(interval)
	return true
