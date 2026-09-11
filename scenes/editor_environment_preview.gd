@tool
extends Node2D

# Editor preview of the exact compact runtime canyon layout.
# V30 also previews environment asset 9/36 (shallow_rock_01) using the same
# canyon alpha-surface anchoring used at runtime.

const CanyonTextureLoader = preload("res://scenes/canyon_texture_loader.gd")

const PREVIEW_ROOT_NAME: String = "__GeneratedEnvironmentPreview"
const TOP_M: float = 20.0
const WORLD_PIXELS_PER_METER: float = 34.5
const MAP_WIDTH_PX: float = 5500.0
const FALLBACK_LEFT: float = -1000.0
const FALLBACK_RIGHT: float = 4500.0
const FALLBACK_ZERO_Y: float = 392.6
const TERRAIN_Z: int = -7
const SHALLOW_ROCK_Z: int = -4
const DEEP_WATER_MARGIN_PX: float = 700.0

const SHALLOW_ROCK_PATH: String = "res://assets/environment/shallow/shallow_rock_01.png"
const SHALLOW_LEFT_RATIO: float = 0.16
const SHALLOW_RIGHT_RATIO: float = 0.84
const SHALLOW_LEFT_HEIGHT: float = 360.0
const SHALLOW_RIGHT_HEIGHT: float = 320.0
const ALPHA_THRESHOLD: float = 0.10

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
	var top_y: float = _world_y_for_depth(TOP_M)
	var world_width: float = maxf(bounds.y - bounds.x, 1.0)
	var uniform_scale: float = world_width / _source_region.size.x
	var world_height: float = _source_region.size.y * uniform_scale
	var bottom_y: float = top_y + world_height
	var bottom_m: float = TOP_M + (world_height / WORLD_PIXELS_PER_METER)

	_build_editor_deep_water(bounds, bottom_y + DEEP_WATER_MARGIN_PX)
	if show_editor_depth_band:
		_build_editor_depth_band(bounds, top_y, bottom_y)

	var atlas: AtlasTexture = AtlasTexture.new()
	atlas.atlas = _terrain_texture
	atlas.region = _source_region

	var sprite: Sprite2D = Sprite2D.new()
	sprite.name = "TerrainSpriteHQ_Preview"
	sprite.centered = false
	sprite.texture = atlas
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	sprite.position = Vector2(bounds.x, top_y)
	sprite.scale = Vector2(uniform_scale, uniform_scale)
	sprite.z_as_relative = false
	sprite.z_index = TERRAIN_Z
	_preview_root.add_child(sprite, false, Node.INTERNAL_MODE_BACK)

	_build_shallow_rock_preview(bounds, top_y, uniform_scale)

	_preview_root.set_meta("preview_source", "verified_v15_hq_lanczos")
	_preview_root.set_meta("depth_top_m", TOP_M)
	_preview_root.set_meta("depth_bottom_m", bottom_m)
	_preview_root.set_meta("world_y_top", top_y)
	_preview_root.set_meta("world_y_bottom", bottom_y)
	_preview_root.set_meta("map_left_x", bounds.x)
	_preview_root.set_meta("map_right_x", bounds.y)
	_preview_root.set_meta("source_region", _source_region)
	_preview_root.set_meta("fit_scale", sprite.scale)
	_preview_root.set_meta("aspect_locked", true)
	_preview_root.set_meta("world_pixels_per_meter", WORLD_PIXELS_PER_METER)
	_preview_root.set_meta("compact_map_width_px", MAP_WIDTH_PX)

	print(
		"EDITOR CANYON V30: compact=", snappedf(world_width, 1.0),
		"px top=", TOP_M,
		"m bottom=", snappedf(bottom_m, 0.1),
		"m texture=", _source_region.size,
		" scale=", snappedf(uniform_scale, 0.001),
		" / ENV 9/36 preview=ON"
	)


func _build_shallow_rock_preview(bounds: Vector2, top_y: float, canyon_scale: float) -> void:
	var source_texture: Texture2D = load(SHALLOW_ROCK_PATH) as Texture2D
	if source_texture == null:
		push_warning("Editor shallow_rock_01 preview texture yuklenemedi.")
		return

	var rock_texture: Texture2D = _crop_to_used_alpha(source_texture)
	var rock_size: Vector2 = rock_texture.get_size()
	if rock_size.x <= 0.0 or rock_size.y <= 0.0:
		return

	var canyon_image: Image = _terrain_texture.get_image()
	if canyon_image == null or canyon_image.is_empty():
		return

	var left_surface: Vector2 = _find_surface_near_ratio(canyon_image, SHALLOW_LEFT_RATIO)
	var right_surface: Vector2 = _find_surface_near_ratio(canyon_image, SHALLOW_RIGHT_RATIO)
	if left_surface.x < 0.0 or right_surface.x < 0.0:
		push_warning("Editor shallow rock icin canyon yuzeyi bulunamadi.")
		return

	var root: Node2D = Node2D.new()
	root.name = "ShallowRock01Preview"
	root.z_as_relative = false
	root.z_index = SHALLOW_ROCK_Z
	_preview_root.add_child(root, false, Node.INTERNAL_MODE_BACK)

	var left_anchor: Vector2 = Vector2(
		bounds.x + left_surface.x * canyon_scale,
		top_y + left_surface.y * canyon_scale
	)
	var right_anchor: Vector2 = Vector2(
		bounds.x + right_surface.x * canyon_scale,
		top_y + right_surface.y * canyon_scale
	)

	_add_preview_rock(rock_texture, left_anchor, SHALLOW_LEFT_HEIGHT, 0.018, false, "ShallowRock01_Left_Preview", root)
	_add_preview_rock(rock_texture, right_anchor, SHALLOW_RIGHT_HEIGHT, -0.022, true, "ShallowRock01_Right_Preview", root)


func _add_preview_rock(
	texture: Texture2D,
	bottom_anchor: Vector2,
	target_height: float,
	rotation_value: float,
	flip_x: bool,
	node_name: String,
	parent_node: Node2D
) -> void:
	var size: Vector2 = texture.get_size()
	if size.x <= 0.0 or size.y <= 0.0:
		return

	var scale_value: float = target_height / size.y
	var sprite: Sprite2D = Sprite2D.new()
	sprite.name = node_name
	sprite.texture = texture
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	sprite.position = Vector2(bottom_anchor.x, bottom_anchor.y - target_height * 0.5 + 10.0)
	sprite.scale = Vector2(-scale_value if flip_x else scale_value, scale_value)
	sprite.rotation = rotation_value
	sprite.modulate = Color(0.92, 0.97, 1.0, 1.0)
	parent_node.add_child(sprite, false, Node.INTERNAL_MODE_BACK)


func _find_surface_near_ratio(image: Image, ratio: float) -> Vector2:
	var width: int = image.get_width()
	var height: int = image.get_height()
	if width <= 0 or height <= 0:
		return Vector2(-1.0, -1.0)

	var target_x: int = clampi(int(round(float(width - 1) * ratio)), 0, width - 1)
	var search_radius: int = maxi(24, int(round(float(width) * 0.045)))
	var best_x: int = -1
	var best_y: int = height + 1
	var best_distance: int = width + 1

	for offset: int in range(search_radius + 1):
		var candidates: Array[int] = [target_x + offset]
		if offset > 0:
			candidates.append(target_x - offset)

		for x: int in candidates:
			if x < 0 or x >= width:
				continue
			var y: int = _top_opaque_y(image, x)
			if y < 0:
				continue
			var distance: int = absi(x - target_x)
			if distance < best_distance or (distance == best_distance and y < best_y):
				best_x = x
				best_y = y
				best_distance = distance

		if best_x >= 0 and offset > 20:
			break

	if best_x < 0:
		return Vector2(-1.0, -1.0)
	return Vector2(float(best_x) + 0.5, float(best_y) + 0.5)


func _top_opaque_y(image: Image, x: int) -> int:
	for y: int in range(image.get_height()):
		if image.get_pixel(x, y).a >= ALPHA_THRESHOLD:
			return y
	return -1


func _crop_to_used_alpha(source_texture: Texture2D) -> Texture2D:
	var source_size: Vector2 = source_texture.get_size()
	var image: Image = source_texture.get_image()
	if image == null or image.is_empty():
		return source_texture

	var used_rect: Rect2i = image.get_used_rect()
	if used_rect.size.x <= 0 or used_rect.size.y <= 0:
		return source_texture
	if used_rect.size.x >= int(source_size.x) and used_rect.size.y >= int(source_size.y):
		return source_texture

	var cropped: AtlasTexture = AtlasTexture.new()
	cropped.atlas = source_texture
	cropped.region = Rect2(
		float(used_rect.position.x),
		float(used_rect.position.y),
		float(used_rect.size.x),
		float(used_rect.size.y)
	)
	return cropped


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
	deep_water.color = Color(0.004, 0.025, 0.052, 1.0)
	_preview_root.add_child(deep_water, false, Node.INTERNAL_MODE_BACK)


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
	band.color = Color(0.025, 0.075, 0.12, 0.16)
	_preview_root.add_child(band, false, Node.INTERNAL_MODE_BACK)


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
