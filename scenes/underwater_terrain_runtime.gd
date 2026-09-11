extends Node

# TinyFisher grounded canyon compositor.
#
# V25 removes approximate kelp placement completely.
# Kelp roots are now pixel-locked to the ACTUAL visible rock surface:
# - Rock PNG alpha is scanned to find a stable opaque upper surface point.
# - Kelp PNG alpha is scanned to find the real bottom/root pixel.
# - Both source pixels are transformed through the exact Sprite2D scale/flip.
# - The two pixels are mapped to the same world coordinate.
#
# Result: transparent padding inside either PNG can no longer make kelp float.
# This is visual terrain only; it intentionally has no collision yet.

const TERRAIN_NODE_NAME := "UnderwaterCanyonTerrain20To100"
const LAYOUT_VERSION := 25

const TOP_M := 20.0
const BOTTOM_M := 100.0
const SEABED_DEPTH_M := 100.0

const FALLBACK_LEFT := -1000.0
const FALLBACK_RIGHT := 11000.0
const FALLBACK_PPM := 34.5
const FALLBACK_ZERO_Y := 392.6

# Water is -9. Keep the canyon above the water shader and behind gameplay.
const TERRAIN_Z := -4

const SPIRE_SPACING_X := 2200.0
const FIRST_SPIRE_OFFSET_X := 900.0
const MIN_HORIZONTAL_GAP := 90.0

const ROCK_TALL := "res://assets/environment/deep_sea/deep_sea_rock_01.png"
const ROCK_FLOOR := "res://assets/environment/deep_sea/deep_sea_rock_02.png"
const KELP_TEXTURE := "res://assets/environment/shallow/shallow_kelp_01.png"

# Top edge of each sprite rectangle. Visible rock pixels are calculated from
# alpha and are NOT assumed to live on this rectangle edge.
const SPIRE_TOP_DEPTH_PATTERN := [44.0, 48.0, 52.0, 46.0, 50.0, 45.0]

# There is still no real 0-20 m solid shelf. Only the highest existing canyon
# formations receive kelp for now.
const KELP_MAX_LEDGE_DEPTH_M := 48.0
const KELP_TARGET_HEIGHT_PATTERN := [155.0, 132.0, 146.0, 125.0]
const KELP_SWAY_SPEED := 0.85
const KELP_SWAY_RADIANS := 0.035

# Alpha geometry settings. Pixels below this threshold are treated as
# transparent so anti-aliased fringe pixels do not become fake support points.
const ALPHA_THRESHOLD := 0.18
const ROCK_SCAN_MIN_X_RATIO := 0.16
const ROCK_SCAN_MAX_X_RATIO := 0.84
const ROCK_SURFACE_WINDOW_RATIO := 0.035
const ROCK_MAX_LOCAL_ROUGHNESS_PX := 34
const KELP_BASE_SAMPLE_ROWS := 8

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

# Cached source-pixel anchors. These are actual visible alpha pixels, not
# guessed world/depth coordinates.
var _rock_surface_source_px := Vector2(-1.0, -1.0)
var _kelp_base_source_px := Vector2(-1.0, -1.0)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	print("UNDERWATER TERRAIN V25: PIXEL-LOCKED ROCK/KELP GROUNDING")


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
	_cache_alpha_geometry()

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
	_root.set_meta("kelp_grounding", "alpha_pixel_lock")
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
		"HQ CANYON V%d / X %.0f..%.0f / %.2f px-m / terrain=%d / kelp=%d / rock_px=(%.1f,%.1f) / kelp_base_px=(%.1f,%.1f)" % [
			LAYOUT_VERSION,
			bounds.x,
			bounds.y,
			ppm,
			_occupied_x.size(),
			_kelp_pivots.size(),
			_rock_surface_source_px.x,
			_rock_surface_source_px.y,
			_kelp_base_source_px.x,
			_kelp_base_source_px.y
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


func _cache_alpha_geometry() -> void:
	if _rock_surface_source_px.x >= 0.0 and _kelp_base_source_px.x >= 0.0:
		return

	var rock_texture := _textures.get(ROCK_TALL) as Texture2D
	var kelp_texture := _textures.get(KELP_TEXTURE) as Texture2D
	if rock_texture == null or kelp_texture == null:
		return

	var rock_image := rock_texture.get_image()
	var kelp_image := kelp_texture.get_image()
	if rock_image == null or rock_image.is_empty():
		push_warning("Rock alpha geometry okunamadi.")
		return
	if kelp_image == null or kelp_image.is_empty():
		push_warning("Kelp alpha geometry okunamadi.")
		return

	_rock_surface_source_px = _find_stable_rock_surface_pixel(rock_image)
	_kelp_base_source_px = _find_kelp_base_pixel(kelp_image)

	if _rock_surface_source_px.x < 0.0:
		push_warning("Gercek kaya yuzey pikseli bulunamadi.")
	if _kelp_base_source_px.x < 0.0:
		push_warning("Gercek kelp kok pikseli bulunamadi.")


func _build_seabed_mass(bounds: Vector2) -> void:
	if not is_instance_valid(_root):
		return

	var seabed_y := _world_y_for_depth(SEABED_DEPTH_M)
	var bottom_y := seabed_y + 900.0
	var width := bounds.y - bounds.x
	var step := 400.0
	var point_count := int(ceil(width / step)) + 1
	var points := PackedVector2Array()

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
	var texture := _textures.get(ROCK_TALL) as Texture2D
	if texture == null:
		return

	var x := bounds.x + FIRST_SPIRE_OFFSET_X
	var index := 0

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
	var texture := _textures.get(ROCK_FLOOR) as Texture2D
	if texture == null:
		return

	var source_size := texture.get_size()
	if source_size.x <= 0.0 or source_size.y <= 0.0:
		return

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
	var kelp_texture := _textures.get(KELP_TEXTURE) as Texture2D
	if kelp_texture == null:
		push_warning("Kelp texture bulunamadi; terrain kelpsiz devam ediyor.")
		return
	if _rock_surface_source_px.x < 0.0 or _kelp_base_source_px.x < 0.0:
		push_warning("Alpha anchor geometry hazir degil; kelp spawn iptal edildi.")
		return

	var kelp_size := kelp_texture.get_size()
	if kelp_size.x <= 0.0 or kelp_size.y <= 0.0:
		return

	var x := bounds.x + FIRST_SPIRE_OFFSET_X
	var spire_index := 0
	var kelp_index := 0

	while x <= bounds.y:
		var top_depth := float(SPIRE_TOP_DEPTH_PATTERN[spire_index % SPIRE_TOP_DEPTH_PATTERN.size()])
		if top_depth <= KELP_MAX_LEDGE_DEPTH_M:
			var spire := _root.get_node_or_null("GroundedSpire_%02d" % spire_index) as Sprite2D
			if spire != null:
				var rock_size := spire.texture.get_size()
				var rock_anchor_local := _source_pixel_to_rendered_offset(
					_rock_surface_source_px,
					rock_size,
					spire.scale
				)
				var exact_anchor := spire.position + rock_anchor_local

				var target_height := float(
					KELP_TARGET_HEIGHT_PATTERN[kelp_index % KELP_TARGET_HEIGHT_PATTERN.size()]
				)
				var kelp_scale_factor := target_height / kelp_size.y
				var kelp_scale := Vector2(
					-kelp_scale_factor if kelp_index % 2 == 1 else kelp_scale_factor,
					kelp_scale_factor
				)

				var pivot := Node2D.new()
				pivot.name = "GroundedKelpPivot_%02d" % kelp_index
				pivot.position = exact_anchor
				pivot.z_index = 2
				pivot.set_meta("grounded", true)
				pivot.set_meta("grounding_method", "rock_alpha_pixel_to_kelp_alpha_pixel")
				pivot.set_meta("rock_source_pixel", _rock_surface_source_px)
				pivot.set_meta("kelp_base_source_pixel", _kelp_base_source_px)
				pivot.set_meta("source_spire", spire.name)
				pivot.set_meta("sway_phase", float(kelp_index) * 1.73)
				_root.add_child(pivot)

				var sprite := Sprite2D.new()
				sprite.name = "KelpVisual"
				sprite.texture = kelp_texture
				sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
				sprite.scale = kelp_scale

				# Shift the sprite so its REAL bottom opaque/root pixel lands exactly on
				# the pivot. This removes all transparent PNG bottom padding mathematically.
				var kelp_base_rendered := _source_pixel_to_rendered_offset(
					_kelp_base_source_px,
					kelp_size,
					kelp_scale
				)
				sprite.position = -kelp_base_rendered
				sprite.modulate = Color(0.62, 0.84, 0.78, 0.88)
				pivot.add_child(sprite)

				_kelp_pivots.append(pivot)
				kelp_index += 1

		x += SPIRE_SPACING_X
		spire_index += 1


func _find_stable_rock_surface_pixel(image: Image) -> Vector2:
	var width := image.get_width()
	var height := image.get_height()
	if width <= 0 or height <= 0:
		return Vector2(-1.0, -1.0)

	var min_x := clampi(int(round(float(width) * ROCK_SCAN_MIN_X_RATIO)), 0, width - 1)
	var max_x := clampi(int(round(float(width) * ROCK_SCAN_MAX_X_RATIO)), 0, width - 1)
	var window := maxi(4, int(round(float(width) * ROCK_SURFACE_WINDOW_RATIO)))

	var best_x := -1
	var best_y := -1
	var best_score := INF

	# Pick a high but locally stable opaque surface point. We intentionally avoid
	# a lone spike/anti-alias pixel by comparing neighboring surface columns.
	for x in range(min_x, max_x + 1, 2):
		var y := _top_opaque_y(image, x)
		if y < 0:
			continue

		var left_x := clampi(x - window, 0, width - 1)
		var right_x := clampi(x + window, 0, width - 1)
		var left_y := _top_opaque_y(image, left_x)
		var right_y := _top_opaque_y(image, right_x)
		if left_y < 0 or right_y < 0:
			continue

		var roughness := maxi(abs(y - left_y), abs(y - right_y))
		if roughness > ROCK_MAX_LOCAL_ROUGHNESS_PX:
			continue

		var slope_penalty := float(abs(right_y - left_y)) * 2.5
		var roughness_penalty := float(roughness) * 4.0
		var center_penalty := abs(float(x) - float(width) * 0.5) * 0.035
		var score := float(y) + slope_penalty + roughness_penalty + center_penalty

		if score < best_score:
			best_score = score
			best_x = x
			best_y = y

	# Fallback still uses a real alpha pixel; never a guessed depth coordinate.
	if best_x < 0:
		for x in range(min_x, max_x + 1):
			var y := _top_opaque_y(image, x)
			if y >= 0 and (best_y < 0 or y < best_y):
				best_x = x
				best_y = y

	if best_x < 0 or best_y < 0:
		return Vector2(-1.0, -1.0)

	# Pixel-center coordinates are used for exact Sprite2D transform math.
	return Vector2(float(best_x) + 0.5, float(best_y) + 0.5)


func _find_kelp_base_pixel(image: Image) -> Vector2:
	var width := image.get_width()
	var height := image.get_height()
	if width <= 0 or height <= 0:
		return Vector2(-1.0, -1.0)

	var bottom_y := -1
	for y in range(height - 1, -1, -1):
		var found := false
		for x in range(width):
			if image.get_pixel(x, y).a >= ALPHA_THRESHOLD:
				bottom_y = y
				found = true
				break
		if found:
			break

	if bottom_y < 0:
		return Vector2(-1.0, -1.0)

	# Average the opaque root pixels across the last few real rows. This gives the
	# actual visual root center even if the PNG has asymmetric transparent padding.
	var start_y := maxi(0, bottom_y - KELP_BASE_SAMPLE_ROWS + 1)
	var x_sum := 0.0
	var count := 0
	for y in range(start_y, bottom_y + 1):
		for x in range(width):
			if image.get_pixel(x, y).a >= ALPHA_THRESHOLD:
				x_sum += float(x) + 0.5
				count += 1

	var root_x := float(width) * 0.5
	if count > 0:
		root_x = x_sum / float(count)

	return Vector2(root_x, float(bottom_y) + 0.5)


func _top_opaque_y(image: Image, x: int) -> int:
	if x < 0 or x >= image.get_width():
		return -1

	for y in range(image.get_height()):
		if image.get_pixel(x, y).a >= ALPHA_THRESHOLD:
			return y
	return -1


func _source_pixel_to_rendered_offset(
	source_pixel: Vector2,
	texture_size: Vector2,
	sprite_scale: Vector2
) -> Vector2:
	# Sprite2D is centered by default. source_pixel is already a pixel-center
	# coordinate, therefore this maps the exact source pixel through scale/flip.
	var centered := source_pixel - texture_size * 0.5
	return Vector2(centered.x * sprite_scale.x, centered.y * sprite_scale.y)


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
