extends Node

# Final safety pass for generated kelp clusters.
# The cluster compositor already avoids generated-kelp overlap, but the source
# rock PNG itself contains thin baked vegetation/details. Alpha alone can make
# those details look like valid terrain. This guard re-checks every generated
# root against the actual source texture and deletes any plant that is not
# sitting on a broad, continuous rock mass.

const TERRAIN_NODE_NAME: String = "UnderwaterCanyonTerrain20To100"
const ALPHA_THRESHOLD: float = 0.18

# Source-pixel contact test. For a real rock surface, many neighboring columns
# must begin at roughly the same height and stay opaque continuously downward.
# Thin baked kelp/branches fail this test even if solid rock exists farther below.
const CONTACT_HALF_WIDTH_RATIO: float = 0.034
const CONTACT_DEPTH_RATIO: float = 0.052
const MAX_NEIGHBOR_SURFACE_DELTA_PX: int = 30
const MIN_COLUMN_CONTINUITY: float = 0.90
const MIN_STRONG_COLUMN_RATIO: float = 0.62

var _scene_id: int = 0
var _world: Node2D = null
var _terrain: Node2D = null
var _removed_total: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	print("KELP ROCK CONTACT GUARD V1: BAKED-VEGETATION REJECTION")


func _process(_delta: float) -> void:
	var scene: Node = get_tree().current_scene
	if scene == null:
		_reset()
		return

	if scene.get_instance_id() != _scene_id:
		_scene_id = scene.get_instance_id()
		_world = scene as Node2D
		_terrain = null
		_removed_total = 0

	if _world == null:
		return

	var terrain: Node2D = _world.get_node_or_null(TERRAIN_NODE_NAME) as Node2D
	if terrain == null:
		return
	_terrain = terrain

	_validate_unchecked_kelps()


func _reset() -> void:
	_scene_id = 0
	_world = null
	_terrain = null
	_removed_total = 0


func _validate_unchecked_kelps() -> void:
	if _terrain == null:
		return

	var removed_this_pass: int = 0
	var accepted_this_pass: int = 0

	for child: Node in _terrain.get_children():
		if not child.name.begins_with("KelpClusterPivot_"):
			continue
		if bool(child.get_meta("rock_contact_guard_checked", false)):
			continue

		var pivot: Node2D = child as Node2D
		if pivot == null:
			continue

		var source_spire_name: String = String(pivot.get_meta("source_spire", ""))
		var source_pixel_variant: Variant = pivot.get_meta("rock_source_pixel", Vector2(-1.0, -1.0))
		if source_spire_name.is_empty() or not (source_pixel_variant is Vector2):
			_remove_bad_kelp(pivot, "missing_source_metadata")
			removed_this_pass += 1
			continue

		var source_pixel: Vector2 = source_pixel_variant as Vector2
		var spire: Sprite2D = _terrain.get_node_or_null(source_spire_name) as Sprite2D
		if spire == null or spire.texture == null:
			_remove_bad_kelp(pivot, "missing_source_spire")
			removed_this_pass += 1
			continue

		var image: Image = spire.texture.get_image()
		if image == null or image.is_empty():
			_remove_bad_kelp(pivot, "missing_source_image")
			removed_this_pass += 1
			continue

		if not _has_broad_continuous_rock_contact(image, source_pixel):
			_remove_bad_kelp(pivot, "thin_or_baked_vegetation_support")
			removed_this_pass += 1
			continue

		pivot.set_meta("rock_contact_guard_checked", true)
		pivot.set_meta("rock_contact_guard", "broad_continuous_rock")
		accepted_this_pass += 1

	if removed_this_pass > 0 or accepted_this_pass > 0:
		_removed_total += removed_this_pass
		print(
			"KELP CONTACT GUARD: accepted=%d / removed=%d / removed_total=%d" % [
				accepted_this_pass,
				removed_this_pass,
				_removed_total
			]
		)


func _remove_bad_kelp(pivot: Node2D, reason: String) -> void:
	if pivot == null or pivot.get_parent() == null:
		return
	pivot.set_meta("rejected_by_contact_guard", reason)
	pivot.get_parent().remove_child(pivot)
	pivot.queue_free()


func _has_broad_continuous_rock_contact(image: Image, source_pixel: Vector2) -> bool:
	var width: int = image.get_width()
	var height: int = image.get_height()
	if width <= 0 or height <= 0:
		return false

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

		# A baked plant usually rises well above the surrounding actual rock.
		# Real rock shoulders remain locally coherent across neighboring columns.
		if absi(local_top_y - source_y) > MAX_NEIGHBOR_SURFACE_DELTA_PX:
			continue

		var end_y: int = mini(height - 1, local_top_y + depth)
		if end_y <= local_top_y:
			continue

		var opaque_count: int = 0
		var run_count: int = 0
		for y: int in range(local_top_y, end_y + 1):
			run_count += 1
			if image.get_pixel(x, y).a >= ALPHA_THRESHOLD:
				opaque_count += 1

		if run_count <= 0:
			continue

		var continuity: float = float(opaque_count) / float(run_count)
		if continuity >= MIN_COLUMN_CONTINUITY:
			strong_columns += 1

	if sampled_columns <= 0:
		return false

	var strong_ratio: float = float(strong_columns) / float(sampled_columns)
	return strong_ratio >= MIN_STRONG_COLUMN_RATIO


func _top_opaque_y(image: Image, x: int) -> int:
	if x < 0 or x >= image.get_width():
		return -1

	for y: int in range(image.get_height()):
		if image.get_pixel(x, y).a >= ALPHA_THRESHOLD:
			return y
	return -1
