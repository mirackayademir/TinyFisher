extends Node

# TinyFisher environment asset 9 / 36 - shallow_rock_01.png
# V2: rocks are anchored to the real canyon alpha surface and parented directly
# to the canyon terrain. This prevents floating/invisible placements and stops
# the old MidDecor rebuild loop from printing every frame.

const ROOT_NAME: String = "ShallowRock01Art"
const TEXTURE_PATH: String = "res://assets/environment/shallow/shallow_rock_01.png"
const TERRAIN_NAME: String = "UnderwaterCanyonTerrain20To100"
const TERRAIN_SPRITE_NAME: String = "TerrainSpriteHQ"
const ALPHA_THRESHOLD: float = 0.10

const LEFT_RATIO: float = 0.16
const RIGHT_RATIO: float = 0.84
const LEFT_WORLD_HEIGHT: float = 360.0
const RIGHT_WORLD_HEIGHT: float = 320.0
const SURFACE_EMBED_LOCAL_PX: float = 10.0

var _scene_id: int = 0
var _terrain_id: int = 0
var _world: Node2D = null
var _root: Node2D = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	print("SHALLOW ROCK 01 RUNTIME V2: REAL CANYON SURFACE / ENVIRONMENT 9/36")


func _process(_delta: float) -> void:
	var scene: Node = get_tree().current_scene
	if scene == null:
		_reset()
		return

	if scene.get_instance_id() != _scene_id:
		_scene_id = scene.get_instance_id()
		_world = scene as Node2D
		_terrain_id = 0
		_root = null

	if _world == null:
		return

	var terrain: Node2D = _world.get_node_or_null(TERRAIN_NAME) as Node2D
	if terrain == null:
		return

	if terrain.get_instance_id() != _terrain_id:
		_terrain_id = terrain.get_instance_id()
		_root = null

	if is_instance_valid(_root):
		return

	var existing: Node2D = terrain.get_node_or_null(ROOT_NAME) as Node2D
	if existing != null:
		_root = existing
		return

	_build_rocks(terrain)


func _build_rocks(terrain: Node2D) -> void:
	var terrain_sprite: Sprite2D = terrain.get_node_or_null(TERRAIN_SPRITE_NAME) as Sprite2D
	if terrain_sprite == null or terrain_sprite.texture == null:
		return

	var canyon_image: Image = terrain_sprite.texture.get_image()
	if canyon_image == null or canyon_image.is_empty():
		return

	var source_texture: Texture2D = load(TEXTURE_PATH) as Texture2D
	if source_texture == null:
		push_warning("shallow_rock_01 texture yuklenemedi.")
		return

	var rock_texture: Texture2D = _crop_to_used_alpha(source_texture)
	var rock_size: Vector2 = rock_texture.get_size()
	if rock_size.x <= 0.0 or rock_size.y <= 0.0:
		return

	var left_surface: Vector2 = _find_surface_near_ratio(canyon_image, LEFT_RATIO)
	var right_surface: Vector2 = _find_surface_near_ratio(canyon_image, RIGHT_RATIO)
	if left_surface.x < 0.0 or right_surface.x < 0.0:
		push_warning("shallow_rock_01 canyon yuzeyi bulunamadi.")
		return

	_root = Node2D.new()
	_root.name = ROOT_NAME
	_root.z_index = 3
	_root.set_meta("environment_asset_index", 9)
	_root.set_meta("environment_asset_total", 36)
	_root.set_meta("placement", "alpha_surface_anchored")
	terrain.add_child(_root)

	_add_rock_local(
		rock_texture,
		left_surface + Vector2(0.0, SURFACE_EMBED_LOCAL_PX),
		LEFT_WORLD_HEIGHT,
		0.018,
		false,
		terrain,
		"ShallowRock01_Left"
	)
	_add_rock_local(
		rock_texture,
		right_surface + Vector2(0.0, SURFACE_EMBED_LOCAL_PX),
		RIGHT_WORLD_HEIGHT,
		-0.022,
		true,
		terrain,
		"ShallowRock01_Right"
	)

	var left_world: Vector2 = terrain.to_global(left_surface)
	var right_world: Vector2 = terrain.to_global(right_surface)
	print(
		"ENVIRONMENT: 9/36 aktif - shallow_rock_01 / surface anchors=",
		Vector2(snappedf(left_world.x, 1.0), snappedf(left_world.y, 1.0)),
		" & ",
		Vector2(snappedf(right_world.x, 1.0), snappedf(right_world.y, 1.0))
	)


func _add_rock_local(
	texture: Texture2D,
	bottom_anchor_local: Vector2,
	target_world_height: float,
	rotation_value: float,
	flip_x: bool,
	terrain: Node2D,
	node_name: String
) -> void:
	var size: Vector2 = texture.get_size()
	if size.x <= 0.0 or size.y <= 0.0:
		return

	var terrain_scale_y: float = maxf(absf(terrain.global_scale.y), 0.001)
	var target_local_height: float = target_world_height / terrain_scale_y
	var scale_value: float = target_local_height / size.y

	var sprite: Sprite2D = Sprite2D.new()
	sprite.name = node_name
	sprite.texture = texture
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	sprite.position = Vector2(bottom_anchor_local.x, bottom_anchor_local.y - target_local_height * 0.5)
	sprite.scale = Vector2(-scale_value if flip_x else scale_value, scale_value)
	sprite.rotation = rotation_value
	sprite.modulate = Color(0.92, 0.97, 1.0, 1.0)
	_root.add_child(sprite)


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


func _reset() -> void:
	_scene_id = 0
	_terrain_id = 0
	_world = null
	_root = null
