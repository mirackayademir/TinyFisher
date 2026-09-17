@tool
extends Node2D

# Editor preview V35.
# Shows the approved HQ canyon at its original aspect ratio in the 20-180 m band
# and previews the softened 180-250 m abyss transition used at runtime.

const CanyonTextureLoader = preload("res://scenes/canyon_texture_loader.gd")

const PREVIEW_ROOT_NAME: String = "__GeneratedEnvironmentPreview"
const CANYON_TOP_M: float = 20.0
const CANYON_BOTTOM_M: float = 180.0
const CANYON_FADE_START_M: float = 168.0
const CANYON_FADE_END_M: float = 194.0
const ABYSS_TOP_M: float = 180.0
const WORLD_MAX_DEPTH_M: float = 250.0
const WORLD_PIXELS_PER_METER: float = 34.5
const MAP_WIDTH_PX: float = 5500.0
const FALLBACK_LEFT: float = -1000.0
const FALLBACK_RIGHT: float = 4500.0
const FALLBACK_ZERO_Y: float = 392.6
const TERRAIN_Z: int = -7
const ABYSS_BACKGROUND_Z: int = -8
const ABYSS_ROCK_Z: int = -7
const ABYSS_BLEND_Z: int = -6
const DEEP_WATER_MARGIN_PX: float = 760.0

@export var show_preview: bool = true
@export var show_editor_depth_band: bool = true

var _preview_root: Node2D = null
var _terrain_texture: Texture2D = null
var _source_region: Rect2 = Rect2()
var _build_attempted: bool = false


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

	if is_instance_valid(_preview_root):
		_preview_root.visible = true
	elif not _build_attempted:
		_rebuild_preview()


func _rebuild_preview() -> void:
	if not Engine.is_editor_hint():
		return

	_clear_preview()
	if not show_preview:
		return

	_build_attempted = true
	if _terrain_texture == null:
		_terrain_texture = CanyonTextureLoader.build_texture()
	if _terrain_texture == null:
		push_warning("Editor HQ canyon preview olusturulamadi.")
		return

	_source_region = CanyonTextureLoader.visible_region(_terrain_texture)
	if _source_region.size.x <= 0.0 or _source_region.size.y <= 0.0:
		push_warning("Editor HQ canyon visible region gecersiz.")
		return

	_preview_root = Node2D.new()
	_preview_root.name = PREVIEW_ROOT_NAME
	_preview_root.z_as_relative = false
	add_child(_preview_root, false, Node.INTERNAL_MODE_BACK)

	var bounds: Vector2 = _world_bounds()
	var canyon_top_y: float = _world_y_for_depth(CANYON_TOP_M)
	var canyon_bottom_y: float = _world_y_for_depth(CANYON_BOTTOM_M)
	var abyss_bottom_y: float = _world_y_for_depth(WORLD_MAX_DEPTH_M)
	var world_width: float = maxf(bounds.y - bounds.x, 1.0)
	var canyon_height: float = maxf(canyon_bottom_y - canyon_top_y, 1.0)

	# Lock the source aspect ratio to the exact 20-180 m vertical gameplay band.
	var uniform_scale: float = canyon_height / _source_region.size.y
	var drawn_width: float = _source_region.size.x * uniform_scale
	var horizontal_padding: float = maxf((world_width - drawn_width) * 0.5, 0.0)
	if drawn_width > world_width:
		uniform_scale = world_width / _source_region.size.x
		drawn_width = world_width
		horizontal_padding = 0.0

	_build_editor_deep_water(bounds, abyss_bottom_y + DEEP_WATER_MARGIN_PX)
	_build_editor_abyss(bounds, canyon_bottom_y, abyss_bottom_y)
	if show_editor_depth_band:
		_build_editor_depth_band(bounds, canyon_top_y, canyon_bottom_y)

	var atlas: AtlasTexture = AtlasTexture.new()
	atlas.atlas = _terrain_texture
	atlas.region = _source_region

	var sprite: Sprite2D = Sprite2D.new()
	sprite.name = "TerrainSpriteHQ_Preview"
	sprite.centered = false
	sprite.texture = atlas
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	sprite.position = Vector2(bounds.x + horizontal_padding, canyon_top_y)
	sprite.scale = Vector2(uniform_scale, uniform_scale)
	sprite.z_as_relative = false
	sprite.z_index = TERRAIN_Z
	_preview_root.add_child(sprite, false, Node.INTERNAL_MODE_BACK)

	_preview_root.set_meta("preview_source", "single_file_hq_canyon")
	_preview_root.set_meta("canyon_depth_top_m", CANYON_TOP_M)
	_preview_root.set_meta("canyon_depth_bottom_m", CANYON_BOTTOM_M)
	_preview_root.set_meta("abyss_depth_top_m", ABYSS_TOP_M)
	_preview_root.set_meta("world_max_depth_m", WORLD_MAX_DEPTH_M)
	_preview_root.set_meta("map_left_x", bounds.x)
	_preview_root.set_meta("map_right_x", bounds.y)
	_preview_root.set_meta("source_region", _source_region)
	_preview_root.set_meta("fit_scale", sprite.scale)
	_preview_root.set_meta("aspect_locked", true)
	_preview_root.set_meta("horizontal_padding_px", horizontal_padding)
	_preview_root.set_meta("world_pixels_per_meter", WORLD_PIXELS_PER_METER)
	_preview_root.set_meta("compact_map_width_px", MAP_WIDTH_PX)

	print(
		"EDITOR CANYON V35: HQ 20-180M ASPECT LOCKED / ABYSS 180-250M / source=", _source_region.size,
		" scale=", snappedf(uniform_scale, 0.001),
		" pad=", snappedf(horizontal_padding, 1.0),
		"px / ENV 9/36=OFF"
	)


func _clear_preview() -> void:
	if is_instance_valid(_preview_root):
		remove_child(_preview_root)
		_preview_root.free()
	_preview_root = null


func _build_editor_deep_water(bounds: Vector2, required_bottom_y: float) -> void:
	var world: Node = get_parent()
	if world == null:
		return

	var water: Control = world.get_node_or_null("Water") as Control
	if water == null:
		return

	var existing_bottom_y: float = water.position.y + water.size.y
	if existing_bottom_y >= required_bottom_y:
		return

	var deep_water: Polygon2D = Node2D.new() as Polygon2D
	deep_water = Polygon2D.new()
	deep_water.name = "EditorDeepWaterExtension"
	deep_water.z_as_relative = false
	deep_water.z_index = -9
	deep_water.polygon = PackedVector2Array([
		Vector2(bounds.x, existing_bottom_y),
		Vector2(bounds.y, existing_bottom_y),
		Vector2(bounds.y, required_bottom_y),
		Vector2(bounds.x, required_bottom_y)
	])
	deep_water.color = Color(0.002, 0.012, 0.027, 1.0)
	_preview_root.add_child(deep_water, false, Node.INTERNAL_MODE_BACK)


func _build_editor_abyss(bounds: Vector2, top_y: float, bottom_y: float) -> void:
	var width: float = bounds.y - bounds.x

	# Background depth gradient.
	var top_color: Color = Color(0.004, 0.028, 0.060, 0.82)
	var middle_color: Color = Color(0.003, 0.018, 0.040, 0.92)
	var bottom_color: Color = Color(0.001, 0.006, 0.016, 0.99)
	for i: int in range(14):
		var t0: float = float(i) / 14.0
		var t1: float = float(i + 1) / 14.0
		var color_t: Color
		if t1 < 0.48:
			color_t = top_color.lerp(middle_color, t1 / 0.48)
		else:
			color_t = middle_color.lerp(bottom_color, (t1 - 0.48) / 0.52)
		var band: Polygon2D = _make_rect_polygon(
			bounds.x,
			bounds.y,
			lerpf(top_y, bottom_y, t0),
			lerpf(top_y, bottom_y, t1)
		)
		band.name = "EditorAbyssDepthBand%02d" % i
		band.z_as_relative = false
		band.z_index = ABYSS_BACKGROUND_Z
		band.color = color_t
		_preview_root.add_child(band, false, Node.INTERNAL_MODE_BACK)

	# Canyon-like lower wall silhouettes.
	var left_far: Polygon2D = Polygon2D.new()
	left_far.name = "EditorAbyssLeftWall"
	left_far.z_as_relative = false
	left_far.z_index = ABYSS_ROCK_Z
	left_far.color = Color(0.004, 0.026, 0.050, 0.96)
	left_far.polygon = PackedVector2Array([
		Vector2(bounds.x, _world_y_for_depth(176.0)),
		Vector2(bounds.x + width * 0.040, _world_y_for_depth(183.0)),
		Vector2(bounds.x + width * 0.075, _world_y_for_depth(190.0)),
		Vector2(bounds.x + width * 0.115, _world_y_for_depth(202.0)),
		Vector2(bounds.x + width * 0.155, _world_y_for_depth(216.0)),
		Vector2(bounds.x + width * 0.205, _world_y_for_depth(231.0)),
		Vector2(bounds.x + width * 0.265, _world_y_for_depth(243.0)),
		Vector2(bounds.x + width * 0.310, bottom_y),
		Vector2(bounds.x, bottom_y)
	])
	_preview_root.add_child(left_far, false, Node.INTERNAL_MODE_BACK)

	var right_far: Polygon2D = Polygon2D.new()
	right_far.name = "EditorAbyssRightWall"
	right_far.z_as_relative = false
	right_far.z_index = ABYSS_ROCK_Z
	right_far.color = Color(0.004, 0.026, 0.050, 0.96)
	right_far.polygon = PackedVector2Array([
		Vector2(bounds.y, _world_y_for_depth(176.0)),
		Vector2(bounds.y - width * 0.038, _world_y_for_depth(184.0)),
		Vector2(bounds.y - width * 0.072, _world_y_for_depth(191.0)),
		Vector2(bounds.y - width * 0.110, _world_y_for_depth(203.0)),
		Vector2(bounds.y - width * 0.152, _world_y_for_depth(217.0)),
		Vector2(bounds.y - width * 0.202, _world_y_for_depth(232.0)),
		Vector2(bounds.y - width * 0.258, _world_y_for_depth(244.0)),
		Vector2(bounds.y - width * 0.305, bottom_y),
		Vector2(bounds.y, bottom_y)
	])
	_preview_root.add_child(right_far, false, Node.INTERNAL_MODE_BACK)

	var floor: Polygon2D = Polygon2D.new()
	floor.name = "EditorAbyssFloorRidge"
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
	_preview_root.add_child(floor, false, Node.INTERNAL_MODE_BACK)

	# Faint depth haze.
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
		haze.name = "EditorAbyssHaze%02d" % i
		haze.z_as_relative = false
		haze.z_index = ABYSS_BLEND_Z
		haze.color = Color(0.025, 0.095, 0.145, 0.035 + float(i) * 0.012)
		_preview_root.add_child(haze, false, Node.INTERNAL_MODE_BACK)

	# Bioluminescent particles.
	for i: int in range(36):
		var x_ratio: float = fmod(float(i * 37 + 11), 103.0) / 102.0
		var depth_m: float = 190.0 + fmod(float(i * 23 + 7), 57.0)
		var x: float = bounds.x + width * x_ratio
		var y: float = _world_y_for_depth(depth_m)
		var size: float = 2.8 + float(i % 5) * 0.85
		var speck: Polygon2D = Polygon2D.new()
		speck.name = "EditorAbyssGlow%02d" % i
		speck.z_as_relative = false
		speck.z_index = ABYSS_BLEND_Z
		speck.polygon = PackedVector2Array([
			Vector2(x, y - size),
			Vector2(x + size, y),
			Vector2(x, y + size),
			Vector2(x - size, y)
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
		_preview_root.add_child(speck, false, Node.INTERNAL_MODE_BACK)

	# Foreground fade hides the hard lower edge of the source canyon.
	var fade_start_y: float = _world_y_for_depth(CANYON_FADE_START_M)
	var fade_end_y: float = _world_y_for_depth(CANYON_FADE_END_M)
	for i: int in range(10):
		var t0: float = float(i) / 10.0
		var t1: float = float(i + 1) / 10.0
		var fade: Polygon2D = _make_rect_polygon(
			bounds.x,
			bounds.y,
			lerpf(fade_start_y, fade_end_y, t0),
			lerpf(fade_start_y, fade_end_y, t1)
		)
		fade.name = "EditorCanyonToAbyssBlend%02d" % i
		fade.z_as_relative = false
		fade.z_index = ABYSS_BLEND_Z
		fade.color = Color(0.003, 0.018, 0.038, lerpf(0.015, 0.82, pow(t1, 1.65)))
		_preview_root.add_child(fade, false, Node.INTERNAL_MODE_BACK)


func _build_editor_depth_band(bounds: Vector2, top_y: float, bottom_y: float) -> void:
	var band: Polygon2D = Polygon2D.new()
	band.name = "EditorNaturalCanyonDepthBand"
	band.z_as_relative = false
	band.z_index = TERRAIN_Z - 1
	band.polygon = PackedVector2Array([
		Vector2(bounds.x, top_y),
		Vector2(bounds.y, top_y),
		Vector2(bounds.y, bottom_y),
		Vector2(bounds.x, bottom_y)
	])
	band.color = Color(0.025, 0.075, 0.12, 0.10)
	_preview_root.add_child(band, false, Node.INTERNAL_MODE_BACK)


func _make_rect_polygon(left: float, right: float, top: float, bottom: float) -> Polygon2D:
	var polygon: Polygon2D = Polygon2D.new()
	polygon.polygon = PackedVector2Array([
		Vector2(left, top),
		Vector2(right, top),
		Vector2(right, bottom),
		Vector2(left, bottom)
	])
	return polygon


func _world_bounds() -> Vector2:
	var world: Node = get_parent()
	if world != null:
		var water: Control = world.get_node_or_null("Water") as Control
		if water != null:
			var left: float = water.position.x
			var water_right: float = water.position.x + water.size.x
			var right: float = minf(water_right, left + MAP_WIDTH_PX)
			if right - left >= 1280.0:
				return Vector2(left, right)
	return Vector2(FALLBACK_LEFT, FALLBACK_RIGHT)


func _world_y_for_depth(depth_meters: float) -> float:
	var world: Node = get_parent()
	if world == null:
		return FALLBACK_ZERO_Y + depth_meters * WORLD_PIXELS_PER_METER

	var boat: Node2D = world.get_node_or_null("Boat") as Node2D
	var hook: Node2D = world.get_node_or_null("Boat/Hook") as Node2D
	if boat == null or hook == null:
		return FALLBACK_ZERO_Y + depth_meters * WORLD_PIXELS_PER_METER

	var hook_start_y: float = hook.position.y
	var start_variant: Variant = hook.get("start_position")
	if start_variant is Vector2:
		hook_start_y = (start_variant as Vector2).y

	return boat.global_position.y + hook_start_y + depth_meters * WORLD_PIXELS_PER_METER
