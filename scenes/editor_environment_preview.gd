@tool
extends Node2D

# Editor preview V34.
# Shows the approved HQ canyon locked to 20-180 m and the new 180-250 m abyss
# transition so editor and runtime share the same depth plan.

const CanyonTextureLoader = preload("res://scenes/canyon_texture_loader.gd")

const PREVIEW_ROOT_NAME: String = "__GeneratedEnvironmentPreview"
const CANYON_TOP_M: float = 20.0
const CANYON_BOTTOM_M: float = 180.0
const ABYSS_TOP_M: float = 180.0
const WORLD_MAX_DEPTH_M: float = 250.0
const WORLD_PIXELS_PER_METER: float = 34.5
const MAP_WIDTH_PX: float = 5500.0
const FALLBACK_LEFT: float = -1000.0
const FALLBACK_RIGHT: float = 4500.0
const FALLBACK_ZERO_Y: float = 392.6
const TERRAIN_Z: int = -7
const ABYSS_Z: int = -8
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
	sprite.position = Vector2(bounds.x, canyon_top_y)
	sprite.scale = Vector2(
		world_width / _source_region.size.x,
		canyon_height / _source_region.size.y
	)
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
	_preview_root.set_meta("world_pixels_per_meter", WORLD_PIXELS_PER_METER)
	_preview_root.set_meta("compact_map_width_px", MAP_WIDTH_PX)

	print(
		"EDITOR CANYON V34: HQ 20-180M / ABYSS 180-250M / source=", _source_region.size,
		" scale=", sprite.scale,
		" / ENV 9/36=OFF"
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

	var deep_water: Polygon2D = Polygon2D.new()
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
	var transition_start: float = _world_y_for_depth(174.0)
	var transition_end: float = _world_y_for_depth(190.0)
	for i: int in range(4):
		var t0: float = float(i) / 4.0
		var t1: float = float(i + 1) / 4.0
		var transition: Polygon2D = _make_rect_polygon(
			bounds.x,
			bounds.y,
			lerpf(transition_start, transition_end, t0),
			lerpf(transition_start, transition_end, t1)
		)
		transition.name = "EditorAbyssTransition%02d" % i
		transition.z_as_relative = false
		transition.z_index = ABYSS_Z
		transition.color = Color(0.004, 0.018, 0.035, lerpf(0.06, 0.34, t1))
		_preview_root.add_child(transition, false, Node.INTERNAL_MODE_BACK)

	var top_color: Color = Color(0.006, 0.028, 0.052, 0.78)
	var bottom_color: Color = Color(0.0015, 0.004, 0.010, 0.98)
	for i: int in range(9):
		var t0: float = float(i) / 9.0
		var t1: float = float(i + 1) / 9.0
		var band: Polygon2D = _make_rect_polygon(
			bounds.x,
			bounds.y,
			lerpf(top_y, bottom_y, t0),
			lerpf(top_y, bottom_y, t1)
		)
		band.name = "EditorAbyssBand%02d" % i
		band.z_as_relative = false
		band.z_index = ABYSS_Z
		band.color = top_color.lerp(bottom_color, t1)
		_preview_root.add_child(band, false, Node.INTERNAL_MODE_BACK)

	var width: float = bounds.y - bounds.x
	var left_rock: Polygon2D = Polygon2D.new()
	left_rock.name = "EditorAbyssLeftSilhouette"
	left_rock.z_as_relative = false
	left_rock.z_index = ABYSS_Z
	left_rock.color = Color(0.002, 0.012, 0.022, 0.96)
	left_rock.polygon = PackedVector2Array([
		Vector2(bounds.x, bottom_y),
		Vector2(bounds.x, _world_y_for_depth(214.0)),
		Vector2(bounds.x + width * 0.08, _world_y_for_depth(221.0)),
		Vector2(bounds.x + width * 0.15, _world_y_for_depth(230.0)),
		Vector2(bounds.x + width * 0.23, _world_y_for_depth(238.0)),
		Vector2(bounds.x + width * 0.31, _world_y_for_depth(246.0)),
		Vector2(bounds.x + width * 0.37, bottom_y)
	])
	_preview_root.add_child(left_rock, false, Node.INTERNAL_MODE_BACK)

	var right_rock: Polygon2D = Polygon2D.new()
	right_rock.name = "EditorAbyssRightSilhouette"
	right_rock.z_as_relative = false
	right_rock.z_index = ABYSS_Z
	right_rock.color = Color(0.002, 0.012, 0.022, 0.96)
	right_rock.polygon = PackedVector2Array([
		Vector2(bounds.y, bottom_y),
		Vector2(bounds.y, _world_y_for_depth(216.0)),
		Vector2(bounds.y - width * 0.07, _world_y_for_depth(222.0)),
		Vector2(bounds.y - width * 0.14, _world_y_for_depth(231.0)),
		Vector2(bounds.y - width * 0.22, _world_y_for_depth(239.0)),
		Vector2(bounds.y - width * 0.30, _world_y_for_depth(247.0)),
		Vector2(bounds.y - width * 0.36, bottom_y)
	])
	_preview_root.add_child(right_rock, false, Node.INTERNAL_MODE_BACK)

	for i: int in range(20):
		var x_ratio: float = fmod(float(i * 37 + 11), 101.0) / 100.0
		var depth_m: float = 194.0 + fmod(float(i * 23 + 7), 51.0)
		var x: float = bounds.x + width * x_ratio
		var y: float = _world_y_for_depth(depth_m)
		var size: float = 2.5 + float(i % 3) * 0.8
		var speck: Polygon2D = Polygon2D.new()
		speck.name = "EditorAbyssGlow%02d" % i
		speck.z_as_relative = false
		speck.z_index = ABYSS_Z
		speck.polygon = PackedVector2Array([
			Vector2(x, y - size),
			Vector2(x + size, y),
			Vector2(x, y + size),
			Vector2(x - size, y)
		])
		speck.color = Color(0.20, 0.70, 0.95, 0.28 + float(i % 4) * 0.03)
		_preview_root.add_child(speck, false, Node.INTERNAL_MODE_BACK)


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
	band.color = Color(0.025, 0.075, 0.12, 0.12)
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
