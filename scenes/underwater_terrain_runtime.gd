extends Node

# Stable world-anchored 20-100 m underwater terrain compositor.
#
# IMPORTANT:
# The previous HQ canyon path depended on a reconstructed WebP payload stored
# in text chunks. That transfer is not reliable enough for runtime use and was
# the reason the sea could stay completely empty. V21 removes that dependency
# from gameplay and builds the canyon directly from the already-approved,
# high-resolution transparent rock PNG assets that are in this repository.
#
# Result: no base64 / RIFF decode, no per-frame error spam, no external binary
# reconstruction. The terrain is deterministic, collisionless and fixed in
# world space. Every horizontal map section receives visible rock formations
# in the 20-100 m band, so the camera cannot enter an empty blue section.

const TERRAIN_NODE_NAME := "UnderwaterCanyonTerrain20To100"
const LAYOUT_VERSION := 21

const TOP_M := 20.0
const BOTTOM_M := 100.0

const FALLBACK_LEFT := -1000.0
const FALLBACK_RIGHT := 11000.0
const FALLBACK_PPM := 34.5
const FALLBACK_ZERO_Y := 392.6

# Water is -9. Environment underwater background is -6. Keep canyon above
# legacy water but behind fish/gameplay objects.
const TERRAIN_Z := -5

const SEGMENT_WIDTH := 1050.0

const ROCK_SHALLOW_01 := "res://assets/environment/shallow/shallow_rock_01.png"
const ROCK_SHALLOW_02 := "res://assets/environment/shallow/shallow_rock_02.png"
const ROCK_OPEN_01 := "res://assets/environment/open_blue/open_blue_rock_01.png"
const ROCK_OPEN_02 := "res://assets/environment/open_blue/open_blue_rock_02.png"
const ROCK_DEEP_01 := "res://assets/environment/deep_sea/deep_sea_rock_01.png"
const ROCK_DEEP_02 := "res://assets/environment/deep_sea/deep_sea_rock_02.png"
const ROCK_ABYSS_CAVE := "res://assets/environment/abyss/abyss_cave_01.png"

var _scene_id := 0
var _world: Node2D = null
var _root: Node2D = null
var _last_ppm := -1.0
var _last_left := INF
var _last_right := INF

var _textures: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	print("UNDERWATER TERRAIN V21: STABLE HQ ROCK COMPOSITOR / 20-100M")


func _process(_delta: float) -> void:
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

	if _world == null:
		return

	var bounds := _get_world_horizontal_bounds()
	var ppm := _pixels_per_meter()

	if not is_instance_valid(_root):
		_rebuild_terrain(bounds, ppm)
		return

	# Rebuild only when the actual world/depth scale changes. This keeps future
	# line-depth upgrades compatible without doing work every frame.
	if not is_equal_approx(bounds.x, _last_left) \
	or not is_equal_approx(bounds.y, _last_right) \
	or not is_equal_approx(ppm, _last_ppm):
		_rebuild_terrain(bounds, ppm)


func _reset() -> void:
	_scene_id = 0
	_world = null
	_root = null
	_last_ppm = -1.0
	_last_left = INF
	_last_right = INF


func _rebuild_terrain(bounds: Vector2, ppm: float) -> void:
	_remove_old_terrain()
	_cache_textures()

	if _textures.is_empty():
		push_error("Underwater terrain: kullanilabilir kaya texture'i bulunamadi.")
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
	_root.set_meta("terrain_source", "approved_hq_png_composite")
	_world.add_child(_root)

	_build_canyon(bounds)

	_last_left = bounds.x
	_last_right = bounds.y
	_last_ppm = ppm

	print(
		"HQ CANYON ACTIVE: V%d / X %.0f..%.0f / %.2f px-m / 20-100m" % [
			LAYOUT_VERSION,
			bounds.x,
			bounds.y,
			ppm
		]
	)


func _cache_textures() -> void:
	if not _textures.is_empty():
		return

	var paths := [
		ROCK_SHALLOW_01,
		ROCK_SHALLOW_02,
		ROCK_OPEN_01,
		ROCK_OPEN_02,
		ROCK_DEEP_01,
		ROCK_DEEP_02,
		ROCK_ABYSS_CAVE
	]

	for path_variant in paths:
		var path := String(path_variant)
		var texture := load(path) as Texture2D
		if texture != null and texture.get_width() > 0 and texture.get_height() > 0:
			_textures[path] = texture
		else:
			push_warning("Underwater terrain texture atlandi: " + path)


func _build_canyon(bounds: Vector2) -> void:
	var width := maxf(bounds.y - bounds.x, 1.0)
	var segment_count := maxi(int(ceil(width / SEGMENT_WIDTH)), 1)

	# One deterministic three-depth formation per horizontal map segment.
	# At ~60 m there is a large formation in EVERY segment, which directly
	# prevents the empty-water problem visible in the reported screenshot.
	for i in range(segment_count + 1):
		var segment_left := bounds.x + float(i) * SEGMENT_WIDTH
		var center_x := segment_left + SEGMENT_WIDTH * 0.5
		var flip_a := -1.0 if i % 2 == 1 else 1.0
		var flip_b := -flip_a
		var phase := float(i % 4)

		# 20-45 m: smaller shelf / arch formations.
		var upper_path := ROCK_OPEN_02 if i % 3 == 0 else (ROCK_OPEN_01 if i % 3 == 1 else ROCK_SHALLOW_02)
		_add_rock(
			upper_path,
			Vector2(center_x - 180.0 + phase * 42.0, _world_y_for_depth(31.0 + phase * 2.3)),
			690.0 + phase * 55.0,
			flip_a,
			deg_to_rad(-6.0 + phase * 3.0),
			Color(0.80, 0.91, 1.0, 0.90)
		)

		# 45-75 m: this is the main canyon wall band. Keep it large and present
		# across the full 12k-wide world so 50-60 m never looks empty.
		var middle_path := ROCK_DEEP_01 if i % 2 == 0 else ROCK_DEEP_02
		_add_rock(
			middle_path,
			Vector2(center_x + 100.0 - phase * 36.0, _world_y_for_depth(59.0 + (phase - 1.5) * 2.4)),
			980.0 + phase * 70.0,
			flip_b,
			deg_to_rad(5.0 - phase * 2.6),
			Color(0.72, 0.83, 0.94, 0.97)
		)

		# Add a second overlapping deep rock to make the formation read as a
		# continuous canyon wall rather than a single floating boulder.
		_add_rock(
			ROCK_DEEP_02 if middle_path == ROCK_DEEP_01 else ROCK_DEEP_01,
			Vector2(center_x - 365.0 + phase * 28.0, _world_y_for_depth(64.5 + phase)),
			700.0 + phase * 45.0,
			flip_a,
			deg_to_rad(-10.0 + phase * 3.5),
			Color(0.66, 0.78, 0.90, 0.94)
		)

		# 78-100 m: heavier abyss formations. Every fourth segment uses the
		# approved cave landmark; the others stay as dense rock masses.
		var lower_path := ROCK_ABYSS_CAVE if i % 4 == 2 else ROCK_DEEP_01
		_add_rock(
			lower_path,
			Vector2(center_x + 70.0 - phase * 50.0, _world_y_for_depth(88.0 + phase * 1.8)),
			1180.0 + phase * 60.0,
			flip_a,
			deg_to_rad(-3.0 + phase * 2.0),
			Color(0.55, 0.68, 0.82, 0.98)
		)

	# A bottom ridge closes the 96-100 m edge so the world has a visual floor.
	_build_bottom_ridge(bounds)


func _build_bottom_ridge(bounds: Vector2) -> void:
	var ridge_path := ROCK_DEEP_02
	var spacing := 760.0
	var x := bounds.x - 100.0
	var index := 0

	while x <= bounds.y + spacing:
		_add_rock(
			ridge_path,
			Vector2(x, _world_y_for_depth(98.0) + 145.0),
			880.0,
			-1.0 if index % 2 == 1 else 1.0,
			deg_to_rad(-4.0 if index % 2 == 1 else 4.0),
			Color(0.48, 0.61, 0.75, 1.0)
		)
		x += spacing
		index += 1


func _add_rock(
	path: String,
	world_position: Vector2,
	target_width: float,
	flip_x: float,
	rotation_radians: float,
	tint: Color
) -> void:
	if not is_instance_valid(_root):
		return

	var texture: Texture2D = _textures.get(path) as Texture2D
	if texture == null:
		return

	var texture_size := texture.get_size()
	if texture_size.x <= 0.0 or texture_size.y <= 0.0:
		return

	var scale_factor := target_width / texture_size.x

	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	sprite.position = world_position
	sprite.rotation = rotation_radians
	sprite.scale = Vector2(scale_factor * flip_x, scale_factor)
	sprite.modulate = tint
	_root.add_child(sprite)


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
