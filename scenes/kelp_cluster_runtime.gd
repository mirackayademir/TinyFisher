extends Node

# Replaces the old one-kelp-per-spire composition with deterministic clusters.
# Placement is still fully pixel-grounded: every root is locked to a real
# opaque rock-surface pixel and the apex region is explicitly forbidden.

const TERRAIN_NODE_NAME: String = "UnderwaterCanyonTerrain20To100"
const KELP_TEXTURE_PATH: String = "res://assets/environment/shallow/shallow_kelp_01.png"

const ALPHA_THRESHOLD: float = 0.18
const APEX_CLEARANCE_PX: int = 28
const PROFILE_MARGIN_RATIO: float = 0.10
const SEARCH_RADIUS_RATIO: float = 0.075
const STABILITY_WINDOW_RATIO: float = 0.022
const MAX_LOCAL_ROUGHNESS_PX: int = 34
const MIN_SOURCE_X_SPACING_PX: float = 46.0
const SWAY_SPEED: float = 0.82
const SWAY_RADIANS: float = 0.025
const MAX_BASE_LEAN_RADIANS: float = 0.24

# Five non-central zones: left/lower shoulder, left slope, mid-left slope,
# right slope and right/lower shoulder. There is intentionally no 0.50 apex slot.
const TARGET_X_RATIOS: Array[float] = [0.17, 0.29, 0.41, 0.70, 0.83]
const HEIGHT_PATTERN: Array[float] = [108.0, 128.0, 116.0, 136.0, 101.0]

var _scene_id: int = 0
var _terrain_id: int = 0
var _world: Node2D = null
var _terrain: Node2D = null
var _kelp_texture: Texture2D = null
var _kelp_base_source_px: Vector2 = Vector2(-1.0, -1.0)
var _pivots: Array[Node2D] = []
var _time: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_kelp_geometry()
	print("KELP CLUSTER RUNTIME V1: MULTI-SLOPE PIXEL GROUNDING")


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


func _rebuild_clusters() -> void:
	if _terrain == null or _kelp_texture == null or _kelp_base_source_px.x < 0.0:
		return

	# Remove V25's single apex kelps and any cluster from an earlier pass.
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
		var created: int = _decorate_spire(spire, spire_index)
		total_kelps += created

	print("KELP CLUSTERS: spires=%d / kelp=%d / apex=forbidden" % [spires.size(), total_kelps])


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

	# Alternate between 5 and 4 plants so the silhouette does not repeat.
	var wanted_count: int = 5 if spire_index % 2 == 0 else 4
	var ratios: Array[float] = TARGET_X_RATIOS.duplicate()
	if wanted_count == 4:
		ratios.remove_at(2)

	var used_source_x: Array[float] = []
	var created: int = 0

	for local_index: int in range(ratios.size()):
		var surface_px: Vector2 = _find_surface_near_ratio(
			rock_image,
			ratios[local_index],
			global_top_y,
			used_source_x
		)
		if surface_px.x < 0.0:
			continue

		used_source_x.append(surface_px.x)
		var anchor_local: Vector2 = _source_pixel_to_rendered_offset(surface_px, rock_size, spire.scale)
		var anchor_world: Vector2 = spire.position + anchor_local

		var height_index: int = (spire_index * 2 + local_index) % HEIGHT_PATTERN.size()
		var target_height: float = HEIGHT_PATTERN[height_index]
		var scale_factor: float = target_height / kelp_size.y
		var flip_x: float = -1.0 if (spire_index + local_index) % 2 == 1 else 1.0
		var kelp_scale: Vector2 = Vector2(flip_x * scale_factor, scale_factor)

		var base_lean: float = _surface_lean_at(rock_image, int(floor(surface_px.x)))
		# Mirroring the rock reverses the visible slope direction.
		if spire.scale.x < 0.0:
			base_lean = -base_lean
		base_lean = clampf(base_lean, -MAX_BASE_LEAN_RADIANS, MAX_BASE_LEAN_RADIANS)

		var pivot: Node2D = Node2D.new()
		pivot.name = "KelpClusterPivot_%02d_%02d" % [spire_index, local_index]
		pivot.position = anchor_world
		pivot.z_index = 2
		pivot.set_meta("grounded", true)
		pivot.set_meta("grounding_method", "alpha_surface_profile")
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
		sprite.modulate = Color(0.60, 0.83, 0.76, 0.86)
		pivot.add_child(sprite)

		pivot.rotation = base_lean
		_pivots.append(pivot)
		created += 1

	return created


func _find_surface_near_ratio(
	image: Image,
	target_ratio: float,
	global_top_y: int,
	used_source_x: Array[float]
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

		# Explicit apex exclusion: no plant may sit on the candle-like summit.
		if y < global_top_y + APEX_CLEARANCE_PX:
			continue

		var too_close: bool = false
		for used_x: float in used_source_x:
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

		var distance_penalty: float = absf(float(x - target_x)) * 2.0
		var roughness_penalty: float = float(roughness) * 1.4
		# Slight preference for lower shoulder points after the apex is excluded.
		var lower_reward: float = float(y - global_top_y) * 0.08
		var score: float = distance_penalty + roughness_penalty - lower_reward

		if score < best_score:
			best_score = score
			best_x = x
			best_y = y

	if best_x < 0:
		return Vector2(-1.0, -1.0)
	return Vector2(float(best_x) + 0.5, float(best_y) + 0.5)


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
