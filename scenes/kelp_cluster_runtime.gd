extends Node

# TinyFisher kelp cluster compositor V2.
# Every kelp root is still alpha-pixel grounded, but placement now also:
# - rejects thin pre-existing rock/plant protrusions by checking solid support below,
# - rejects world-space overlap between generated kelps,
# - searches nearby fallback points instead of stacking plants,
# - uses a darker blue-green tint so kelp blends into the canyon.

const TERRAIN_NODE_NAME: String = "UnderwaterCanyonTerrain20To100"
const KELP_TEXTURE_PATH: String = "res://assets/environment/shallow/shallow_kelp_01.png"

const ALPHA_THRESHOLD: float = 0.18
const APEX_CLEARANCE_PX: int = 28
const PROFILE_MARGIN_RATIO: float = 0.10
const SEARCH_RADIUS_RATIO: float = 0.075
const STABILITY_WINDOW_RATIO: float = 0.022
const MAX_LOCAL_ROUGHNESS_PX: int = 34
const MIN_SOURCE_X_SPACING_PX: float = 46.0

# A valid root must sit on a real rock mass, not on a thin opaque strand/detail.
const SUPPORT_HALF_WIDTH_RATIO: float = 0.020
const SUPPORT_DEPTH_RATIO: float = 0.060
const MIN_SUPPORT_FILL_RATIO: float = 0.40

# Generated plants must keep a real screen-space gap from each other.
const KELP_WORLD_CLEARANCE_PX: float = 14.0

const SWAY_SPEED: float = 0.82
const SWAY_RADIANS: float = 0.025
const MAX_BASE_LEAN_RADIANS: float = 0.24

# No 0.50 summit slot. These target left/right shoulders and lower slopes.
const TARGET_X_RATIOS: Array[float] = [0.17, 0.29, 0.41, 0.70, 0.83]
const HEIGHT_PATTERN: Array[float] = [104.0, 121.0, 111.0, 128.0, 98.0]

# If the preferred point is occupied, search around it instead of stacking.
const CANDIDATE_RATIO_OFFSETS: Array[float] = [0.0, -0.035, 0.035, -0.070, 0.070, -0.105, 0.105]

# Dark, desaturated blue-green. It deliberately stays subordinate to the rock.
const KELP_TINT: Color = Color(0.40, 0.55, 0.55, 0.76)

var _scene_id: int = 0
var _terrain_id: int = 0
var _world: Node2D = null
var _terrain: Node2D = null
var _kelp_texture: Texture2D = null
var _kelp_base_source_px: Vector2 = Vector2(-1.0, -1.0)
var _kelp_used_rect: Rect2i = Rect2i()
var _pivots: Array[Node2D] = []
var _time: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_kelp_geometry()
	print("KELP CLUSTER RUNTIME V2: SUPPORT FILTER + OVERLAP GUARD + DARK TINT")


func _process(delta: float) -> void:
	var scene: Node = get_tree().current_scene
	if scene == null:
		_reset_scene()
		return

	if scene.get_instance_id() != _scene_id:
		_scene_id = scene.get_instance_id()
		_world = scene as Node2D
		_terrain = null
		_terrain_id = 0
		_pivots.clear()
		_time = 0.0

	if _world == null:
		return

	var terrain: Node2D = _world.get_node_or_null(TERRAIN_NODE_NAME) as Node2D
	if terrain == null:
		return

	if terrain.get_instance_id() != _terrain_id:
		_terrain = terrain
		_terrain_id = terrain.get_instance_id()
		_rebuild_clusters()

	_animate(delta)


func _reset_scene() -> void:
	_scene_id = 0
	_terrain_id = 0
	_world = null
	_terrain = null
	_pivots.clear()
	_time = 0.0


func _load_kelp_geometry() -> void:
	_kelp_texture = load(KELP_TEXTURE_PATH) as Texture2D
	if _kelp_texture == null:
		push_warning("Kelp cluster texture yuklenemedi: " + KELP_TEXTURE_PATH)
		return

	var image: Image = _kelp_texture.get_image()
	if image == null or image.is_empty():
		push_warning("Kelp cluster alpha geometry okunamadi.")
		return

	_kelp_base_source_px = _find_kelp_base_pixel(image)
	_kelp_used_rect = image.get_used_rect()


func _rebuild_clusters() -> void:
	if _terrain == null or _kelp_texture == null or _kelp_base_source_px.x < 0.0:
		return

	# Remove the old single-apex kelps and any previous cluster pass.
	for child: Node in _terrain.get_children():
		if child.name.begins_with("GroundedKelpPivot_") or child.name.begins_with("KelpClusterPivot_"):
			_terrain.remove_child(child)
			child.queue_free()

	_pivots.clear()
	_time = 0.0

	var spires: Array[Sprite2D] = []
	for child: Node in _terrain.get_children():
		if child is Sprite2D and child.name.begins_with("GroundedSpire_"):
			spires.append(child as Sprite2D)

	spires.sort_custom(func(a: Sprite2D, b: Sprite2D) -> bool: return a.position.x < b.position.x)

	var total_kelps: int = 0
	for spire_index: int in range(spires.size()):
		var spire: Sprite2D = spires[spire_index]
		total_kelps += _decorate_spire(spire, spire_index)

	print("KELP CLUSTERS V2: spires=%d / kelp=%d / overlap=guarded / thin_support=rejected" % [spires.size(), total_kelps])


func _decorate_spire(spire: Sprite2D, spire_index: int) -> int:
	if spire.texture == null:
		return 0

	var rock_image: Image = spire.texture.get_image()
	if rock_image == null or rock_image.is_empty():
		return 0

	var rock_size: Vector2 = spire.texture.get_size()
	var kelp_size: Vector2 = _kelp_texture.get_size()
	if rock_size.x <= 0.0 or rock_size.y <= 0.0 or kelp_size.y <= 0.0:
		return 0

	var global_top_y: int = _find_global_top_y(rock_image)
	if global_top_y < 0:
		return 0

	# Keep the requested 4-5 plant rhythm, but never force a bad position.
	var wanted_count: int = 5 if spire_index % 2 == 0 else 4
	var ratios: Array[float] = TARGET_X_RATIOS.duplicate()
	if wanted_count == 4:
		ratios.remove_at(2)

	var used_source_x: Array[float] = []
	var used_world_bounds: Array[Rect2] = []
	var created: int = 0

	for local_index: int in range(ratios.size()):
		var height_index: int = (spire_index * 2 + local_index) % HEIGHT_PATTERN.size()
		var target_height: float = HEIGHT_PATTERN[height_index]
		var scale_factor: float = target_height / kelp_size.y
		var flip_x: float = -1.0 if (spire_index + local_index) % 2 == 1 else 1.0
		var kelp_scale: Vector2 = Vector2(flip_x * scale_factor, scale_factor)

		# Keep rejected candidates blocked during this slot so fallback searches
		# cannot immediately return the same overlapping point.
		var blocked_source_x: Array[float] = used_source_x.duplicate()
		var placed: bool = false

		for ratio_offset: float in CANDIDATE_RATIO_OFFSETS:
			var target_ratio: float = clampf(
				ratios[local_index] + ratio_offset,
				PROFILE_MARGIN_RATIO,
				1.0 - PROFILE_MARGIN_RATIO
			)

			var surface_px: Vector2 = _find_surface_near_ratio(
				rock_image,
				target_ratio,
				global_top_y,
				blocked_source_x
			)
			if surface_px.x < 0.0:
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

			_create_kelp(
				spire,
				spire_index,
				local_index,
				surface_px,
				anchor_world,
				kelp_size,
				kelp_scale,
				base_lean
			)

			used_source_x.append(surface_px.x)
			used_world_bounds.append(candidate_bounds)
			created += 1
			placed = true
			break

		if not placed:
			# Better to leave one empty patch than create a visibly wrong overlap.
			continue

	return created


func _create_kelp(
	spire: Sprite2D,
	spire_index: int,
	local_index: int,
	surface_px: Vector2,
	anchor_world: Vector2,
	kelp_size: Vector2,
	kelp_scale: Vector2,
	base_lean: float
) -> void:
	var pivot: Node2D = Node2D.new()
	pivot.name = "KelpClusterPivot_%02d_%02d" % [spire_index, local_index]
	pivot.position = anchor_world
	pivot.z_index = 2
	pivot.set_meta("grounded", true)
	pivot.set_meta("grounding_method", "alpha_surface_profile_with_support_and_overlap_guard")
	pivot.set_meta("rock_source_pixel", surface_px)
	pivot.set_meta("source_spire", spire.name)
	pivot.set_meta("base_rotation", base_lean)
	pivot.set_meta("sway_phase", float(spire_index * 7 + local_index) * 1.19)
	_terrain.add_child(pivot)

	var sprite: Sprite2D = Sprite2D.new()
	sprite.name = "KelpVisual"
	sprite.texture = _kelp_texture
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.scale = kelp_scale

	var kelp_base_rendered: Vector2 = _source_pixel_to_rendered_offset(
		_kelp_base_source_px,
		kelp_size,
		kelp_scale
	)
	sprite.position = -kelp_base_rendered
	sprite.modulate = KELP_TINT
	pivot.add_child(sprite)

	pivot.rotation = base_lean
	_pivots.append(pivot)


func _find_surface_near_ratio(
	image: Image,
	target_ratio: float,
	global_top_y: int,
	blocked_source_x: Array[float]
) -> Vector2:
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
		if y < 0:
			continue

		# No candle-like summit placement.
		if y < global_top_y + APEX_CLEARANCE_PX:
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

		# Critical fix: a thin opaque strand is not a valid rock foundation.
		var support_fill: float = _support_fill_ratio(image, x, y)
		if support_fill < MIN_SUPPORT_FILL_RATIO:
			continue

		var distance_penalty: float = absf(float(x - target_x)) * 2.0
		var roughness_penalty: float = float(roughness) * 1.4
		var lower_reward: float = float(y - global_top_y) * 0.08
		var support_reward: float = support_fill * 24.0
		var score: float = distance_penalty + roughness_penalty - lower_reward - support_reward

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
	if width <= 0 or height <= 0:
		return 0.0

	var half_width: int = maxi(5, int(round(float(width) * SUPPORT_HALF_WIDTH_RATIO)))
	var depth: int = maxi(16, int(round(float(height) * SUPPORT_DEPTH_RATIO)))
	var min_x: int = clampi(source_x - half_width, 0, width - 1)
	var max_x: int = clampi(source_x + half_width, 0, width - 1)
	var min_y: int = clampi(surface_y + 2, 0, height - 1)
	var max_y: int = clampi(surface_y + depth, 0, height - 1)

	if max_x < min_x or max_y < min_y:
		return 0.0

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


func _kelp_world_bounds(anchor_world: Vector2, kelp_scale: Vector2, base_rotation: float) -> Rect2:
	if _kelp_used_rect.size.x <= 0 or _kelp_used_rect.size.y <= 0:
		var fallback_half_width: float = absf(kelp_scale.x) * 48.0
		var fallback_height: float = absf(kelp_scale.y) * 160.0
		return Rect2(
			anchor_world - Vector2(fallback_half_width + KELP_WORLD_CLEARANCE_PX, fallback_height + KELP_WORLD_CLEARANCE_PX),
			Vector2((fallback_half_width + KELP_WORLD_CLEARANCE_PX) * 2.0, fallback_height + KELP_WORLD_CLEARANCE_PX * 2.0)
		)

	var x0: float = float(_kelp_used_rect.position.x)
	var y0: float = float(_kelp_used_rect.position.y)
	var x1: float = float(_kelp_used_rect.position.x + _kelp_used_rect.size.x)
	var y1: float = float(_kelp_used_rect.position.y + _kelp_used_rect.size.y)

	var source_corners: Array[Vector2] = [
		Vector2(x0, y0),
		Vector2(x1, y0),
		Vector2(x1, y1),
		Vector2(x0, y1)
	]

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
	if width <= 0 or height <= 0:
		return Vector2(-1.0, -1.0)

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


func _source_pixel_to_rendered_offset(
	source_pixel: Vector2,
	texture_size: Vector2,
	sprite_scale: Vector2
) -> Vector2:
	var centered: Vector2 = source_pixel - texture_size * 0.5
	return Vector2(centered.x * sprite_scale.x, centered.y * sprite_scale.y)


func _animate(delta: float) -> void:
	if _pivots.is_empty():
		return

	_time += delta
	for pivot: Node2D in _pivots:
		if not is_instance_valid(pivot):
			continue
		var base_rotation: float = float(pivot.get_meta("base_rotation", 0.0))
		var phase: float = float(pivot.get_meta("sway_phase", 0.0))
		pivot.rotation = base_rotation + sin(_time * SWAY_SPEED + phase) * SWAY_RADIANS
