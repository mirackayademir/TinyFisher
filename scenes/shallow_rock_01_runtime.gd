extends Node

# TinyFisher environment asset 9 / 36 - shallow_rock_01.png
# V3: rocks are smaller and seated on broad, solid canyon terraces instead of
# the first opaque alpha pixel. This rejects thin baked plants/protrusions and
# gives each decorative rock a slight world-space embed into the canyon.

const ROOT_NAME: String = "ShallowRock01Art"
const TEXTURE_PATH: String = "res://assets/environment/shallow/shallow_rock_01.png"
const TERRAIN_NAME: String = "UnderwaterCanyonTerrain20To100"
const TERRAIN_SPRITE_NAME: String = "TerrainSpriteHQ"
const ALPHA_THRESHOLD: float = 0.10

const LEFT_RATIO: float = 0.29
const RIGHT_RATIO: float = 0.73
const LEFT_WORLD_HEIGHT: float = 230.0
const RIGHT_WORLD_HEIGHT: float = 205.0
const SURFACE_EMBED_WORLD_PX: float = 24.0

const SEARCH_RADIUS_RATIO: float = 0.055
const SUPPORT_HALF_WIDTH_PX: int = 14
const SUPPORT_DEPTH_PX: int = 30
const MIN_SUPPORT_FILL: float = 0.58
const FLATNESS_SAMPLE_PX: int = 18
const MAX_SURFACE_ROUGHNESS_PX: int = 28

var _scene_id: int = 0
var _terrain_id: int = 0
var _world: Node2D = null
var _root: Node2D = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	print("SHALLOW ROCK 01 RUNTIME V3: BROAD TERRACE SEATING / ENVIRONMENT 9/36")


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

	var left_surface: Vector2 = _find_broad_surface_near_ratio(canyon_image, LEFT_RATIO)
	var right_surface: Vector2 = _find_broad_surface_near_ratio(canyon_image, RIGHT_RATIO)
	if left_surface.x < 0.0 or right_surface.x < 0.0:
		push_warning("shallow_rock_01 icin genis canyon terasi bulunamadi.")
		return

	_root = Node2D.new()
	_root.name = ROOT_NAME
	_root.z_index = 3
	_root.set_meta("environment_asset_index", 9)
	_root.set_meta("environment_asset_total", 36)
	_root.set_meta("placement", "broad_solid_terrace")
	terrain.add_child(_root)

	_add_rock_local(
		rock_texture,
		left_surface,
		LEFT_WORLD_HEIGHT,
		0.014,
		false,
		terrain,
		"ShallowRock01_Left"
	)
	_add_rock_local(
		rock_texture,
		right_surface,
		RIGHT_WORLD_HEIGHT,
		-0.018,
		true,
		terrain,
		"ShallowRock01_Right"
	)

	var left_world: Vector2 = terrain.to_global(left_surface)
	var right_world: Vector2 = terrain.to_global(right_surface)
	print(
		"ENVIRONMENT: 9/36 aktif - shallow_rock_01 V3 / terrace anchors=",
		Vector2(snappedf(left_world.x, 1.0), snappedf(left_world.y, 1.0)),
		" & ",
		Vector2(snappedf(right_world.x, 1.0), snappedf(right_world.y, 1.0))
	)


func _add_rock_local(
	texture: Texture2D,
	surface_anchor_local: Vector2,
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
	var embed_local: float = SURFACE_EMBED_WORLD_PX / terrain_scale_y
	var scale_value: float = target_local_height / size.y

	var sprite: Sprite2D = Sprite2D.new()
	sprite.name = node_name
	sprite.texture = texture
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	sprite.position = Vector2(
		surface_anchor_local.x,
		surface_anchor_local.y - target_local_height * 0.5 + embed_local
	)
	sprite.scale = Vector2(-scale_value if flip_x else scale_value, scale_value)
	sprite.rotation = rotation_value
	sprite.modulate = Color(0.88, 0.94, 0.99, 0.98)
	_root.add_child(sprite)


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


func _reset() -> void:
	_scene_id = 0
	_terrain_id = 0
	_world = null
	_root = null
