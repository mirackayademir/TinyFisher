@tool
extends Node2D

# Editor preview of the exact compact runtime canyon layout.
# V31 previews environment asset 9/36 with the same broad-solid-terrace seating
# used by shallow_rock_01_runtime.gd.

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
const SHALLOW_LEFT_RATIO: float = 0.29
const SHALLOW_RIGHT_RATIO: float = 0.73
const SHALLOW_LEFT_HEIGHT: float = 230.0
const SHALLOW_RIGHT_HEIGHT: float = 205.0
const SHALLOW_EMBED_WORLD_PX: float = 24.0

const ALPHA_THRESHOLD: float = 0.10
const SEARCH_RADIUS_RATIO: float = 0.055
const SUPPORT_HALF_WIDTH_PX: int = 14
const SUPPORT_DEPTH_PX: int = 30
const MIN_SUPPORT_FILL: float = 0.58
const FLATNESS_SAMPLE_PX: int = 18
const MAX_SURFACE_ROUGHNESS_PX: int = 28

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
		"EDITOR CANYON V31: compact=", snappedf(world_width, 1.0),
		"px top=", TOP_M,
		"m bottom=", snappedf(bottom_m, 0.1),
		"m texture=", _source_region.size,
		" scale=", snappedf(uniform_scale, 0.001),
		" / ENV 9/36 terrace preview=ON"
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

	var left_surface: Vector2 = _find_broad_surface_near_ratio(canyon_image, SHALLOW_LEFT_RATIO)
	var right_surface: Vector2 = _find_broad_surface_near_ratio(canyon_image, SHALLOW_RIGHT_RATIO)
	if left_surface.x < 0.0 or right_surface.x < 0.0:
		push_warning("Editor shallow rock icin genis canyon terasi bulunamadi.")
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

	_add_preview_rock(rock_texture, left_anchor, SHALLOW_LEFT_HEIGHT, 0.014, false, "ShallowRock01_Left_Preview", root)
	_add_preview_rock(rock_texture, right_anchor, SHALLOW_RIGHT_HEIGHT, -0.018, true, "ShallowRock01_Right_Preview", root)


func _add_preview_rock(
	texture: Texture2D,
	surface_anchor: Vector2,
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
	sprite.position = Vector2(
		surface_anchor.x,
		surface_anchor.y - target_height * 0.5 + SHALLOW_EMBED_WORLD_PX
	)
	sprite.scale = Vector2(-scale_value if flip_x else scale_value, scale_value)
	sprite.rotation = rotation_value
	sprite.modulate = Color(0.88, 0.94, 0.99, 0.98)
	parent_node.add_child(sprite, false, Node.INTERNAL_MODE_BACK)


func _find_broad_surface_near_ratio(image: Image, ratio: float) -> Vector2:
	var width: int = image.get_width()
	var height: int = image.get_height()
	if width <= 0 or height <= 0:
		return Vector2(-1.0, -1.0)

	var target_x: int = clampi(int(round(float(width - 1) * ratio)), 0, width - 1)
	var radius: int = maxi(32, int(round(float(width) * SEARCH_RADIUS_RATIO)))
	var best_x: int = -1
	var best_y: int = -1
	var best_score: float = INF

	for x: int in range(maxi(0, target_x - radius), mini(width - 1, target_x + radius) + 1):
		var y: int = _solid_surface_y(image, x)
		if y < 0:
			continue

		var left_y: int = _solid_surface_y(image, clampi(x - FLATNESS_SAMPLE_PX, 0, width - 1))
		var right_y: int = _solid_surface_y(image, clampi(x + FLATNESS_SAMPLE_PX, 0, width - 1))
		if left_y < 0 or right_y < 0:
			continue

		var roughness: int = maxi(absi(y - left_y), absi(y - right_y))
		if roughness > MAX_SURFACE_ROUGHNESS_PX:
			continue

		var support: float = _support_fill_ratio(image, x, y)
		var score: float = absf(float(x - target_x)) * 1.35 + float(roughness) * 2.0 - support * 38.0
		if score < best_score:
			best_score = score
			best_x = x
			best_y = y

	if best_x < 0:
		return Vector2(-1.0, -1.0)
	return Vector2(float(best_x) + 0.5, float(best_y) + 0.5)


func _solid_surface_y(image: Image, x: int) -> int:
	if x < 0 or x >= image.get_width():
		return -1

	for y: int in range(image.get_height()):
		if image.get_pixel(x, y).a < ALPHA_THRESHOLD:
			continue
		if _support_fill_ratio(image, x, y) >= MIN_SUPPORT_FILL:
			return y
	return -1


func _support_fill_ratio(image: Image, source_x: int, surface_y: int) -> float:
	var min_x: int = clampi(source_x - SUPPORT_HALF_WIDTH_PX, 0, image.get_width() - 1)
	var max_x: int = clampi(source_x + SUPPORT_HALF_WIDTH_PX, 0, image.get_width() - 1)
	var min_y: int = clampi(surface_y + 1, 0, image.get_height() - 1)
	var max_y: int = clampi(surface_y + SUPPORT_DEPTH_PX, 0, image.get_height() - 1)
	if max_x < min_x or max_y < min_y:
		return 0.0

	var opaque: int = 0
	var total: int = 0
	for y: int in range(min_y, max_y + 1):
		for x: int in range(min_x, max_x + 1):
			total += 1
			if image.get_pixel(x, y).a >= ALPHA_THRESHOLD:
				opaque += 1

	if total <= 0:
		return 0.0
	return float(opaque) / float(total)


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
