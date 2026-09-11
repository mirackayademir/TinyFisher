extends Node

# TinyFisher environment asset 9 / 36 - shallow_rock_01.png
# First controlled shallow-rock pass. Two copies only, anchored to the upper
# canyon shoulders so the asset never floats in open water.

const ROOT_NAME: String = "ShallowRock01Art"
const LAYER_PATH: String = "EnvironmentLayers/UnderwaterLayers/MidDecorLayer"
const TEXTURE_PATH: String = "res://assets/environment/shallow/shallow_rock_01.png"
const TERRAIN_NAME: String = "UnderwaterCanyonTerrain20To100"

const FALLBACK_LEFT_X: float = -1000.0
const FALLBACK_RIGHT_X: float = 4500.0
const FALLBACK_CANYON_TOP_Y: float = 1082.6

var _scene_id: int = 0
var _world: Node2D = null
var _root: Node2D = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	print("SHALLOW ROCK 01 RUNTIME V1: ENVIRONMENT 9/36")


func _process(_delta: float) -> void:
	_ensure_art()


func _ensure_art() -> void:
	var scene: Node = get_tree().current_scene
	if scene == null:
		_reset()
		return

	if scene.get_instance_id() != _scene_id:
		_scene_id = scene.get_instance_id()
		_world = scene as Node2D
		_root = null

	if _world == null:
		return
	if is_instance_valid(_root):
		return

	var layer: Node2D = _world.get_node_or_null(LAYER_PATH) as Node2D
	if layer == null:
		return

	# Wait for the accepted canyon runtime. The rocks are positioned from its
	# actual top Y, not from a guessed editor coordinate.
	var terrain: Node2D = _world.get_node_or_null(TERRAIN_NAME) as Node2D
	if terrain == null:
		return

	var existing: Node2D = layer.get_node_or_null(ROOT_NAME) as Node2D
	if existing != null:
		_root = existing
		return

	var source_texture: Texture2D = load(TEXTURE_PATH) as Texture2D
	if source_texture == null:
		push_warning("shallow_rock_01 texture yuklenemedi.")
		return

	var rock_texture: Texture2D = _crop_to_used_alpha(source_texture)
	var rock_size: Vector2 = rock_texture.get_size()
	if rock_size.x <= 0.0 or rock_size.y <= 0.0:
		push_warning("shallow_rock_01 texture boyutu gecersiz.")
		return

	_root = Node2D.new()
	_root.name = ROOT_NAME
	_root.set_meta("environment_asset_index", 9)
	_root.set_meta("environment_asset_total", 36)
	_root.set_meta("depth_band_m", Vector2(18.0, 28.0))
	_root.set_meta("placement", "upper_canyon_shoulders")
	layer.add_child(_root)

	var bounds: Vector2 = _world_bounds()
	var width: float = bounds.y - bounds.x
	var canyon_top_y: float = _terrain_top_y(terrain)

	# Left shoulder: slightly larger, just inside the canyon wall.
	_add_rock(
		rock_texture,
		Vector2(bounds.x + width * 0.23, canyon_top_y + 95.0),
		245.0,
		0.025,
		false,
		"ShallowRock01_Left"
	)

	# Right shoulder: smaller mirrored copy to avoid obvious repetition.
	_add_rock(
		rock_texture,
		Vector2(bounds.x + width * 0.82, canyon_top_y + 125.0),
		205.0,
		-0.035,
		true,
		"ShallowRock01_Right"
	)

	print(
		"ENVIRONMENT: 9/36 aktif - shallow_rock_01 / canyon_top_y=",
		snappedf(canyon_top_y, 0.1),
		" / bounds=", bounds.x, "..", bounds.y
	)


func _add_rock(
	texture: Texture2D,
	bottom_anchor: Vector2,
	target_height: float,
	rotation_value: float,
	flip_x: bool,
	node_name: String
) -> void:
	var size: Vector2 = texture.get_size()
	if size.x <= 0.0 or size.y <= 0.0:
		return

	var scale_value: float = target_height / size.y
	var sprite: Sprite2D = Sprite2D.new()
	sprite.name = node_name
	sprite.texture = texture
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	sprite.position = Vector2(bottom_anchor.x, bottom_anchor.y - target_height * 0.5)
	sprite.scale = Vector2(-scale_value if flip_x else scale_value, scale_value)
	sprite.rotation = rotation_value
	sprite.modulate = Color(0.82, 0.91, 0.98, 0.94)
	_root.add_child(sprite)


func _terrain_top_y(terrain: Node2D) -> float:
	var value: Variant = terrain.get_meta("world_y_top", FALLBACK_CANYON_TOP_Y)
	if value is int or value is float:
		return value + 0.0
	return FALLBACK_CANYON_TOP_Y


func _world_bounds() -> Vector2:
	if _world != null:
		var water: Control = _world.get_node_or_null("Water") as Control
		if water != null:
			var left: float = water.position.x
			var right: float = water.position.x + water.size.x
			if right - left >= 1280.0:
				return Vector2(left, right)
	return Vector2(FALLBACK_LEFT_X, FALLBACK_RIGHT_X)


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


func _reset() -> void:
	_scene_id = 0
	_world = null
	_root = null
