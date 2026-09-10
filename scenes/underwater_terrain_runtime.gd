extends Node

# TinyFisher 20-100m arka-plan reef terrain runtime.
# Bu sistem terrain PNG'sini tek dev sprite olarak esnetmez.
# 1280px ekran-genisligi hucreleri halinde dunya koordinatlarina SABIT dizer.
# Collision yoktur; baliklar ve kanca terrain'in onunden rahatca gecer.

const TERRAIN_TEXTURE_PATH: String = "res://assets/environment/terrain/underwater_terrain_20_100.png"
const TERRAIN_NODE_NAME: String = "UnderwaterReefTerrain20To100"
const LAYOUT_VERSION: int = 4

const WORLD_LEFT_X: float = -1000.0
const WORLD_RIGHT_X: float = 11000.0
const TARGET_TILE_WIDTH: float = 1280.0
const TARGET_ROW_STEP: float = 650.0
const START_DEPTH_METERS: float = 20.0
const END_DEPTH_METERS: float = 100.0

var _scene_id: int = 0
var _world: Node2D = null
var _terrain_root: Node2D = null
var _terrain_texture: Texture2D = null
var _cropped_texture: Texture2D = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	print("UNDERWATER TERRAIN V4: 20-100m sabit hucre sistemi hazir")


func _process(_delta: float) -> void:
	var current_scene: Node = get_tree().current_scene
	if current_scene == null:
		_reset_refs()
		return

	var current_id: int = current_scene.get_instance_id()
	if current_id != _scene_id:
		_scene_id = current_id
		_world = current_scene as Node2D
		_terrain_root = null

	if _world == null:
		return

	_ensure_terrain()


func _reset_refs() -> void:
	_scene_id = 0
	_world = null
	_terrain_root = null


func _ensure_terrain() -> void:
	if is_instance_valid(_terrain_root):
		return

	# SurfaceFoamSync'in eski tek-dev-sprite terrain'i varsa kaldir.
	_remove_legacy_terrain_nodes()

	var existing: Node2D = _world.get_node_or_null(TERRAIN_NODE_NAME) as Node2D
	if existing != null:
		var version: int = int(existing.get_meta("layout_version", 0))
		if version == LAYOUT_VERSION:
			_terrain_root = existing
			_ensure_surface_sync_proxy()
			return
		_world.remove_child(existing)
		existing.queue_free()

	var texture: Texture2D = _load_terrain_texture()
	if texture == null:
		return

	var source_size: Vector2 = texture.get_size()
	if source_size.x <= 0.0 or source_size.y <= 0.0:
		push_error("UNDERWATER TERRAIN: texture size gecersiz")
		return

	# Ustteki gereksiz saf seffaf boslugun kucuk bir kismini kirpiyoruz.
	# Boylece ilk kara parcalari gercekten 20m civarinda gorunmeye baslar.
	var crop_top: float = floor(source_size.y * 0.05)
	var crop_height: float = maxf(1.0, source_size.y - crop_top)
	var atlas: AtlasTexture = AtlasTexture.new()
	atlas.atlas = texture
	atlas.region = Rect2(0.0, crop_top, source_size.x, crop_height)
	_cropped_texture = atlas

	_terrain_root = Node2D.new()
	_terrain_root.name = TERRAIN_NODE_NAME
	_terrain_root.z_as_relative = false
	_terrain_root.z_index = -7
	_terrain_root.set_meta("layout_version", LAYOUT_VERSION)
	_terrain_root.set_meta("collisionless", true)
	_world.add_child(_terrain_root)

	var y_start: float = _world_y_for_depth(START_DEPTH_METERS)
	var y_end: float = _world_y_for_depth(END_DEPTH_METERS)
	if y_end <= y_start:
		y_start = 1080.0
		y_end = 3850.0

	var cropped_size: Vector2 = _cropped_texture.get_size()
	var uniform_scale: float = TARGET_TILE_WIDTH / cropped_size.x
	var tile_height: float = cropped_size.y * uniform_scale

	# 20m'den 100m'ye kadar satirlar. Her satir bir oncekinden yarim hucre
	# kaydirilir; tekrar hissi azalir ama hicbir sey kamera ile kaymaz.
	var row_count: int = int(ceil((y_end - y_start) / TARGET_ROW_STEP)) + 1
	for row: int in range(row_count):
		var row_top: float = y_start + float(row) * TARGET_ROW_STEP
		var row_center_y: float = row_top + tile_height * 0.5
		var stagger: float = 0.0 if row % 2 == 0 else TARGET_TILE_WIDTH * 0.5
		var start_x: float = WORLD_LEFT_X - stagger - TARGET_TILE_WIDTH * 0.5
		var tile_index: int = 0
		var x: float = start_x

		while x < WORLD_RIGHT_X + TARGET_TILE_WIDTH:
			var sprite: Sprite2D = Sprite2D.new()
			sprite.name = "Terrain_R%02d_C%02d" % [row, tile_index]
			sprite.texture = _cropped_texture
			sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			sprite.centered = true
			sprite.position = Vector2(x, row_center_y)

			var flip: float = -1.0 if (row + tile_index) % 2 == 1 else 1.0
			sprite.scale = Vector2(uniform_scale * flip, uniform_scale)

			# Arka planda kalacak kadar soluk, ama kaybolmayacak kadar belirgin.
			var depth_t: float = clampf(float(row) / maxf(float(row_count - 1), 1.0), 0.0, 1.0)
			var brightness: float = lerpf(0.92, 0.72, depth_t)
			sprite.modulate = Color(brightness * 0.84, brightness * 0.94, brightness, 0.82)
			sprite.z_index = 0
			_terrain_root.add_child(sprite)

			x += TARGET_TILE_WIDTH
			tile_index += 1

	# Eski SurfaceFoamSync terrain fonksiyonunun tekrar devreye girmesini engeller.
	_ensure_surface_sync_proxy()

	print(
		"UNDERWATER TERRAIN V4: texture=", source_size,
		" tile=", Vector2(TARGET_TILE_WIDTH, tile_height),
		" rows=", row_count,
		" y=", Vector2(y_start, y_end),
		" collision=OFF"
	)


func _remove_legacy_terrain_nodes() -> void:
	# Eski terrain dogrudan World altinda olabilir.
	var direct_old: Node = _world.get_node_or_null(TERRAIN_NODE_NAME)
	if direct_old != null and int(direct_old.get_meta("layout_version", 0)) != LAYOUT_VERSION:
		_world.remove_child(direct_old)
		direct_old.queue_free()

	# Onceki SurfaceFoamSync surumleri BackgroundDecorLayer altina kuruyordu.
	var background_layer: Node = _world.get_node_or_null(
		"EnvironmentLayers/UnderwaterLayers/BackgroundDecorLayer"
	)
	if background_layer != null:
		var old_named: Node = background_layer.get_node_or_null(TERRAIN_NODE_NAME)
		if old_named != null and not bool(old_named.get_meta("terrain_proxy", false)):
			background_layer.remove_child(old_named)
			old_named.queue_free()

		var old_foundation: Node = background_layer.get_node_or_null("UnderwaterTerrainFoundation")
		if old_foundation != null:
			background_layer.remove_child(old_foundation)
			old_foundation.queue_free()


func _ensure_surface_sync_proxy() -> void:
	var background_layer: Node2D = _world.get_node_or_null(
		"EnvironmentLayers/UnderwaterLayers/BackgroundDecorLayer"
	) as Node2D
	if background_layer == null:
		return

	var existing: Node = background_layer.get_node_or_null(TERRAIN_NODE_NAME)
	if existing != null:
		if bool(existing.get_meta("terrain_proxy", false)):
			return
		background_layer.remove_child(existing)
		existing.queue_free()

	var proxy: Node2D = Node2D.new()
	proxy.name = TERRAIN_NODE_NAME
	proxy.visible = false
	proxy.set_meta("terrain_proxy", true)
	proxy.set_meta("collisionless", true)
	background_layer.add_child(proxy)


func _load_terrain_texture() -> Texture2D:
	if _terrain_texture != null:
		return _terrain_texture

	# Once Godot'un normal ResourceLoader yolunu dene.
	if ResourceLoader.exists(TERRAIN_TEXTURE_PATH):
		var resource: Resource = ResourceLoader.load(
			TERRAIN_TEXTURE_PATH,
			"Texture2D",
			ResourceLoader.CACHE_MODE_REUSE
		)
		if resource is Texture2D:
			_terrain_texture = resource as Texture2D
			return _terrain_texture

	# Import cache henuz hazir degilse kaynak PNG'yi mutlak disk yolundan oku.
	var image: Image = Image.new()
	var absolute_path: String = ProjectSettings.globalize_path(TERRAIN_TEXTURE_PATH)
	var load_error: Error = image.load(absolute_path)
	if load_error != OK:
		push_error(
			"UNDERWATER TERRAIN: PNG okunamadi | %s | absolute=%s | error=%d"
			% [TERRAIN_TEXTURE_PATH, absolute_path, load_error]
		)
		return null

	_terrain_texture = ImageTexture.create_from_image(image)
	return _terrain_texture


func _world_y_for_depth(depth_meters: float) -> float:
	var boat: Node2D = _world.get_node_or_null("Boat") as Node2D
	var hook: Node2D = _world.get_node_or_null("Boat/Hook") as Node2D
	if boat == null or hook == null:
		# Mevcut oyunun 100m test olcegine gore guvenli fallback.
		return 392.6 + depth_meters * 34.5

	var start_position_variant: Variant = hook.get("start_position")
	var max_depth_variant: Variant = hook.get("max_depth")
	var max_depth_meters_variant: Variant = hook.get("max_depth_meters")

	var hook_start_y: float = hook.position.y
	if start_position_variant is Vector2:
		hook_start_y = (start_position_variant as Vector2).y

	var max_depth_pixels: float = float(max_depth_variant)
	var max_depth_meters: float = float(max_depth_meters_variant)
	if max_depth_pixels <= 0.0 or max_depth_meters <= 0.0:
		return 392.6 + depth_meters * 34.5

	var pixels_per_meter: float = max_depth_pixels / max_depth_meters
	return boat.global_position.y + hook_start_y + depth_meters * pixels_per_meter
