@tool
extends Node2D

# Editor preview V36.
# The HQ canyon is the whole playable depth: 20-180 m.
# Only a short 180-186 m visual bottom cap is shown below it; there is no
# playable 180-250 m abyss in this layout.

const CanyonTextureLoader = preload("res://scenes/canyon_texture_loader.gd")
const FishCatalog = preload("res://scenes/fish_catalog.gd")

const PREVIEW_ROOT_NAME: String = "__GeneratedEnvironmentPreview"
const CANYON_TOP_M: float = 20.0
const CANYON_BOTTOM_M: float = 180.0
const VISUAL_BOTTOM_M: float = 186.0
const WORLD_PIXELS_PER_METER: float = 34.5
const MAP_WIDTH_PX: float = 5500.0
const FALLBACK_LEFT: float = -1000.0
const FALLBACK_RIGHT: float = 4500.0
const FALLBACK_ZERO_Y: float = 392.6
const TERRAIN_Z: int = -7
const BOTTOM_Z: int = -8
const DEEP_WATER_MARGIN_PX: float = 48.0
const FISH_PREVIEW_Z: int = 6
const FISH_LABEL_Z: int = 7

@export var show_preview: bool = true
@export var show_editor_depth_band: bool = true
@export var show_fish_preview: bool = true
@export var show_fish_labels: bool = true

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

	# Preview root is created before runtime-only previews so fish/assets remain
	# visible in the editor even if the HQ canyon preview cannot be built.
	_preview_root = Node2D.new()
	_preview_root.name = PREVIEW_ROOT_NAME
	_preview_root.z_as_relative = false
	add_child(_preview_root, false, Node.INTERNAL_MODE_BACK)

	_hide_runtime_placeholder_fish()
	if show_fish_preview:
		_build_fish_preview()

	if _terrain_texture == null:
		_terrain_texture = CanyonTextureLoader.build_texture()
	if _terrain_texture == null:
		push_warning("Editor HQ canyon preview olusturulamadi; fish/object preview remains available.")
		return

	_source_region = CanyonTextureLoader.visible_region(_terrain_texture)
	if _source_region.size.x <= 0.0 or _source_region.size.y <= 0.0:
		push_warning("Editor HQ canyon visible region gecersiz; fish/object preview remains available.")
		return

	var bounds: Vector2 = _world_bounds()
	var canyon_top_y: float = _world_y_for_depth(CANYON_TOP_M)
	var canyon_bottom_y: float = _world_y_for_depth(CANYON_BOTTOM_M)
	var visual_bottom_y: float = _world_y_for_depth(VISUAL_BOTTOM_M)
	var world_width: float = maxf(bounds.y - bounds.x, 1.0)
	var canyon_height: float = maxf(canyon_bottom_y - canyon_top_y, 1.0)

	var uniform_scale: float = canyon_height / _source_region.size.y
	var drawn_width: float = _source_region.size.x * uniform_scale
	var horizontal_padding: float = maxf((world_width - drawn_width) * 0.5, 0.0)
	if drawn_width > world_width:
		uniform_scale = world_width / _source_region.size.x
		drawn_width = world_width
		horizontal_padding = 0.0

	_build_editor_deep_water(bounds, visual_bottom_y + DEEP_WATER_MARGIN_PX)
	_build_editor_bottom_cap(bounds, canyon_bottom_y, visual_bottom_y)
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
	_preview_root.set_meta("playable_max_depth_m", CANYON_BOTTOM_M)
	_preview_root.set_meta("visual_bottom_m", VISUAL_BOTTOM_M)
	_preview_root.set_meta("map_left_x", bounds.x)
	_preview_root.set_meta("map_right_x", bounds.y)
	_preview_root.set_meta("source_region", _source_region)
	_preview_root.set_meta("fit_scale", sprite.scale)
	_preview_root.set_meta("aspect_locked", true)
	_preview_root.set_meta("horizontal_padding_px", horizontal_padding)
	_preview_root.set_meta("world_pixels_per_meter", WORLD_PIXELS_PER_METER)

	print(
		"EDITOR CANYON V36: HQ 20-180M / HOOK MAX 180M / VISUAL BOTTOM 186M / source=", _source_region.size,
		" scale=", snappedf(uniform_scale, 0.001),
		" pad=", snappedf(horizontal_padding, 1.0), "px"
	)



func _hide_runtime_placeholder_fish() -> void:
	var world: Node = get_parent()
	if world == null:
		return

	# world.tscn keeps one Fish child as an editor/runtime template. The real game
	# removes it at runtime and spawns the catalog population, so hide the template
	# in this dedicated editor preview to avoid a duplicate Sardalya.
	var placeholder: CanvasItem = world.get_node_or_null("FishingSpot/Fish") as CanvasItem
	if placeholder != null:
		placeholder.visible = false


func _build_fish_preview() -> void:
	if _preview_root == null:
		return

	var fish_root: Node2D = Node2D.new()
	fish_root.name = "FishCatalogPreview"
	fish_root.z_as_relative = false
	_preview_root.add_child(fish_root, false, Node.INTERNAL_MODE_BACK)

	for fish_type: String in FishCatalog.FISH_ORDER:
		var profile: Dictionary = FishCatalog.get_profile(fish_type)
		var texture: Texture2D = FishCatalog.get_texture(fish_type)
		if texture == null:
			push_warning("EDITOR FISH PREVIEW: texture missing for " + fish_type)
			continue

		var spawn_position: Vector2 = _profile_spawn_midpoint(profile)
		var visual_scale: float = float(profile.get("visual_scale", 0.06))

		var sprite: Sprite2D = Sprite2D.new()
		sprite.name = _safe_preview_node_name(fish_type) + "_Preview"
		sprite.texture = texture
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite.position = spawn_position
		sprite.scale = Vector2.ONE * visual_scale
		sprite.z_as_relative = false
		sprite.z_index = FISH_PREVIEW_Z
		fish_root.add_child(sprite, false, Node.INTERNAL_MODE_BACK)

		if show_fish_labels:
			_build_fish_preview_label(fish_root, fish_type, spawn_position)

	fish_root.set_meta("preview_source", "FishCatalog.PROFILES")
	fish_root.set_meta("preview_count", FishCatalog.FISH_ORDER.size())


func _profile_spawn_midpoint(profile: Dictionary) -> Vector2:
	var spawn_x: Variant = profile.get("spawn_x", [800.0, 800.0])
	var spawn_y: Variant = profile.get("spawn_y", [700.0, 700.0])
	return Vector2(
		_range_midpoint(spawn_x, 800.0),
		_range_midpoint(spawn_y, 700.0)
	)


func _range_midpoint(value: Variant, fallback: float) -> float:
	if value is Array and value.size() >= 2:
		return (float(value[0]) + float(value[1])) * 0.5
	if value is float or value is int:
		return float(value)
	return fallback


func _build_fish_preview_label(parent: Node2D, fish_type: String, spawn_position: Vector2) -> void:
	var collision_size: Vector2 = FishCatalog.get_collision_size(fish_type)

	var label: Label = Label.new()
	label.name = _safe_preview_node_name(fish_type) + "_Label"
	label.text = fish_type
	label.position = spawn_position + Vector2(-90.0, -maxf(42.0, collision_size.y * 0.72))
	label.size = Vector2(180.0, 24.0)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.z_as_relative = false
	label.z_index = FISH_LABEL_Z
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", Color(0.92, 0.98, 1.0, 0.96))
	label.add_theme_color_override("font_outline_color", Color(0.01, 0.025, 0.04, 0.95))
	label.add_theme_constant_override("outline_size", 3)
	parent.add_child(label, false, Node.INTERNAL_MODE_BACK)


func _safe_preview_node_name(value: String) -> String:
	var result: String = value
	for character: String in [" ", "ı", "İ", "ş", "Ş", "ğ", "Ğ", "ü", "Ü", "ö", "Ö", "ç", "Ç"]:
		result = result.replace(character, "_")
	return result


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
	deep_water.color = Color(0.002, 0.010, 0.022, 1.0)
	_preview_root.add_child(deep_water, false, Node.INTERNAL_MODE_BACK)


func _build_editor_bottom_cap(bounds: Vector2, top_y: float, bottom_y: float) -> void:
	var top_color: Color = Color(0.010, 0.040, 0.070, 0.98)
	var bottom_color: Color = Color(0.002, 0.010, 0.024, 1.0)
	var steps: int = 4

	for i: int in range(steps):
		var t0: float = float(i) / float(steps)
		var t1: float = float(i + 1) / float(steps)
		var band: Polygon2D = _make_rect_polygon(
			bounds.x,
			bounds.y,
			lerpf(top_y, bottom_y, t0),
			lerpf(top_y, bottom_y, t1)
		)
		band.name = "EditorCanyonBottomBand%02d" % i
		band.z_as_relative = false
		band.z_index = BOTTOM_Z
		band.color = top_color.lerp(bottom_color, t1)
		_preview_root.add_child(band, false, Node.INTERNAL_MODE_BACK)

	var width: float = bounds.y - bounds.x
	var ridge: Polygon2D = Polygon2D.new()
	ridge.name = "EditorCanyonBottomFloor"
	ridge.z_as_relative = false
	ridge.z_index = BOTTOM_Z
	ridge.color = Color(0.001, 0.006, 0.014, 1.0)
	ridge.polygon = PackedVector2Array([
		Vector2(bounds.x, bottom_y),
		Vector2(bounds.x, _world_y_for_depth(184.4)),
		Vector2(bounds.x + width * 0.12, _world_y_for_depth(184.9)),
		Vector2(bounds.x + width * 0.24, _world_y_for_depth(184.3)),
		Vector2(bounds.x + width * 0.37, _world_y_for_depth(185.2)),
		Vector2(bounds.x + width * 0.50, _world_y_for_depth(184.6)),
		Vector2(bounds.x + width * 0.63, _world_y_for_depth(185.1)),
		Vector2(bounds.x + width * 0.76, _world_y_for_depth(184.4)),
		Vector2(bounds.x + width * 0.88, _world_y_for_depth(184.9)),
		Vector2(bounds.y, _world_y_for_depth(184.4)),
		Vector2(bounds.y, bottom_y)
	])
	_preview_root.add_child(ridge, false, Node.INTERNAL_MODE_BACK)


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
	band.color = Color(0.025, 0.075, 0.12, 0.08)
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
