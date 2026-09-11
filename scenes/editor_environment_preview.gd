@tool
extends Node2D

# Editor-only preview of the exact terrain used by underwater_terrain_runtime.gd.
# It intentionally mirrors the accepted single HQ canyon fit instead of the
# obsolete repeated-spire compositor. Nothing from this script runs in gameplay.

const PREVIEW_ROOT_NAME: String = "__GeneratedEnvironmentPreview"
const TERRAIN_TEXTURE_PATH: String = "res://assets/environment/terrain/underwater_canyon_20_100_hq.webp"
const SOURCE_REGION: Rect2 = Rect2(0.0, 27.0, 2048.0, 655.0)

const TOP_M: float = 20.0
const BOTTOM_M: float = 100.0
const FALLBACK_LEFT: float = -1000.0
const FALLBACK_RIGHT: float = 11000.0
const FALLBACK_PPM: float = 34.5
const FALLBACK_ZERO_Y: float = 392.6
const TERRAIN_Z: int = -7

@export var show_preview: bool = true
@export var show_editor_depth_band: bool = true

var _preview_root: Node2D = null


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

	if not is_instance_valid(_preview_root):
		_rebuild_preview()
	else:
		_preview_root.visible = true


func _rebuild_preview() -> void:
	if not Engine.is_editor_hint():
		return

	_clear_preview()
	if not show_preview:
		return

	var source_texture: Texture2D = load(TERRAIN_TEXTURE_PATH) as Texture2D
	if source_texture == null:
		push_warning("Editor HQ canyon preview texture bulunamadi: " + TERRAIN_TEXTURE_PATH)
		return

	if source_texture.get_width() < int(SOURCE_REGION.size.x) \
	or source_texture.get_height() < int(SOURCE_REGION.position.y + SOURCE_REGION.size.y):
		push_warning(
			"Editor HQ canyon texture boyutu beklenenden kucuk: %dx%d" % [
				source_texture.get_width(),
				source_texture.get_height()
			]
		)
		return

	_preview_root = Node2D.new()
	_preview_root.name = PREVIEW_ROOT_NAME
	_preview_root.z_as_relative = false
	add_child(_preview_root, false, Node.INTERNAL_MODE_BACK)

	var bounds: Vector2 = _world_bounds()
	var top_y: float = _world_y_for_depth(TOP_M)
	var bottom_y: float = _world_y_for_depth(BOTTOM_M)
	var world_width: float = maxf(bounds.y - bounds.x, 1.0)
	var world_height: float = maxf(bottom_y - top_y, 1.0)

	if show_editor_depth_band:
		_build_editor_depth_band(bounds, top_y, bottom_y)

	var atlas: AtlasTexture = AtlasTexture.new()
	atlas.atlas = source_texture
	atlas.region = SOURCE_REGION

	var sprite: Sprite2D = Sprite2D.new()
	sprite.name = "TerrainSpriteHQ_Preview"
	sprite.centered = false
	sprite.texture = atlas
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	sprite.position = Vector2(bounds.x, top_y)
	sprite.scale = Vector2(
		world_width / SOURCE_REGION.size.x,
		world_height / SOURCE_REGION.size.y
	)
	sprite.z_as_relative = false
	sprite.z_index = TERRAIN_Z
	_preview_root.add_child(sprite, false, Node.INTERNAL_MODE_BACK)

	_preview_root.set_meta("preview_source", "accepted_hq_canyon_webp")
	_preview_root.set_meta("world_y_20m", top_y)
	_preview_root.set_meta("world_y_100m", bottom_y)
	_preview_root.set_meta("map_left_x", bounds.x)
	_preview_root.set_meta("map_right_x", bounds.y)
	_preview_root.set_meta("fit_scale", sprite.scale)


func _clear_preview() -> void:
	if is_instance_valid(_preview_root):
		remove_child(_preview_root)
		_preview_root.free()
	_preview_root = null


func _build_editor_depth_band(bounds: Vector2, top_y: float, bottom_y: float) -> void:
	var band: Polygon2D = Polygon2D.new()
	band.name = "EditorDepthBand20To100"
	band.z_as_relative = false
	band.z_index = TERRAIN_Z - 1
	band.polygon = PackedVector2Array([
		Vector2(bounds.x, top_y),
		Vector2(bounds.y, top_y),
		Vector2(bounds.y, bottom_y),
		Vector2(bounds.x, bottom_y)
	])
	# Only a subtle guide behind the canyon; it must not hide the source art.
	band.color = Color(0.025, 0.075, 0.12, 0.20)
	_preview_root.add_child(band, false, Node.INTERNAL_MODE_BACK)


func _world_bounds() -> Vector2:
	var world: Node = get_parent()
	if world != null:
		var water: Control = world.get_node_or_null("Water") as Control
		if water != null:
			var left: float = water.position.x
			var right: float = water.position.x + water.size.x
			if right - left >= 1280.0:
				return Vector2(left, right)

	return Vector2(FALLBACK_LEFT, FALLBACK_RIGHT)


func _pixels_per_meter() -> float:
	var world: Node = get_parent()
	if world == null:
		return FALLBACK_PPM

	var hook: Node2D = world.get_node_or_null("Boat/Hook") as Node2D
	if hook == null:
		return FALLBACK_PPM

	var max_depth_pixels: float = float(hook.get("max_depth"))
	var max_depth_meters: float = float(hook.get("max_depth_meters"))
	if max_depth_pixels <= 0.0 or max_depth_meters <= 0.0:
		return FALLBACK_PPM

	return max_depth_pixels / max_depth_meters


func _world_y_for_depth(depth_meters: float) -> float:
	var world: Node = get_parent()
	if world == null:
		return FALLBACK_ZERO_Y + depth_meters * FALLBACK_PPM

	var boat: Node2D = world.get_node_or_null("Boat") as Node2D
	var hook: Node2D = world.get_node_or_null("Boat/Hook") as Node2D
	if boat == null or hook == null:
		return FALLBACK_ZERO_Y + depth_meters * FALLBACK_PPM

	var hook_start_y: float = hook.position.y
	var start_variant: Variant = hook.get("start_position")
	if start_variant is Vector2:
		hook_start_y = (start_variant as Vector2).y

	return boat.global_position.y + hook_start_y + depth_meters * _pixels_per_meter()
