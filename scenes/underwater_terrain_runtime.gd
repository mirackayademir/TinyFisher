extends Node

# TinyFisher 20-100m fake-3D reef terrain.
# Kaynak gorselin sol / orta / sag kara kutleleri AYRI crop olarak kullanilir.
# Tek dev sprite, tile, tekrar ve 20m'de ani pop-in YOK.
# Y ekseni dunya derinligine sabittir; X ekseni kamera kadrajina 1:1 hizalanir.
# Collision yoktur; baliklar ve kanca terrain'in onunden gecer.

const TERRAIN_TEXTURE_PATH: String = "res://assets/environment/terrain/underwater_terrain_20_100.png"
const TERRAIN_NODE_NAME: String = "UnderwaterReefTerrain20To100"
const LAYOUT_VERSION: int = 9

var _scene_id: int = 0
var _world: Node2D = null
var _camera: Camera2D = null
var _terrain_root: Node2D = null
var _terrain_texture: Texture2D = null
var _load_failed: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	print("UNDERWATER TERRAIN V9: depth chunks / no pop-in / no tile / collision OFF")


func _process(_delta: float) -> void:
	var current_scene: Node = get_tree().current_scene
	if current_scene == null:
		_reset_refs()
		return

	var current_id: int = current_scene.get_instance_id()
	if current_id != _scene_id:
		_scene_id = current_id
		_world = current_scene as Node2D
		_camera = null
		_terrain_root = null
		_terrain_texture = null
		_load_failed = false

	if _world == null:
		return

	_camera = _world.get_node_or_null("Boat/Camera2D") as Camera2D
	if _camera == null:
		return

	_ensure_terrain()
	_update_horizontal_alignment()


func _reset_refs() -> void:
	_scene_id = 0
	_world = null
	_camera = null
	_terrain_root = null
	_terrain_texture = null
	_load_failed = false


func _ensure_terrain() -> void:
	if is_instance_valid(_terrain_root):
		return
	if _load_failed:
		return

	_remove_old_terrain()

	var texture: Texture2D = _load_png_direct()
	if texture == null:
		_load_failed = true
		return

	var source_size: Vector2 = texture.get_size()
	if source_size.x <= 0.0 or source_size.y <= 0.0:
		push_error("UNDERWATER TERRAIN: texture boyutu gecersiz")
		_load_failed = true
		return

	_terrain_root = Node2D.new()
	_terrain_root.name = TERRAIN_NODE_NAME
	_terrain_root.z_as_relative = false
	# Water -9. Terrain -7: suyun onunde, oynanis objelerinin arkasinda.
	_terrain_root.z_index = -7
	_terrain_root.set_meta("layout_version", LAYOUT_VERSION)
	_terrain_root.set_meta("collisionless", true)
	_world.add_child(_terrain_root)

	# Kaynak gorsel yaklasik 16:9. Uc benzersiz bolgeye ayiriyoruz.
	# Her parca kendi oranini korur; tum resmi 20-100m'ye germiyoruz.
	var left_rect := Rect2(
		0.0,
		0.0,
		floor(source_size.x * 0.38),
		source_size.y
	)
	var center_rect := Rect2(
		floor(source_size.x * 0.29),
		floor(source_size.y * 0.29),
		floor(source_size.x * 0.47),
		floor(source_size.y * 0.71)
	)
	var right_rect := Rect2(
		floor(source_size.x * 0.70),
		0.0,
		source_size.x - floor(source_size.x * 0.70),
		source_size.y
	)

	# 20-100m boyunca birbirinden farkli uc kara kutlesi.
	# Ilk parca ekrana 20m'de bir anda acilmaz; dunya Y konumunda durdugu icin
	# kamera indikce ustten/kenardan dogal olarak kadraja girer.
	_create_chunk("Reef_Left_20_42", left_rect, 22.0, -830.0, 650.0)
	_create_chunk("Reef_Center_43_70", center_rect, 45.0, -325.0, 650.0)
	_create_chunk("Reef_Right_70_100", right_rect, 72.0, 230.0, 620.0)

	_update_horizontal_alignment()

	print(
		"UNDERWATER TERRAIN V9 OK | source=", source_size,
		" | chunks=3 | depth=20-100m | tile=OFF | stretch=OFF | collision=OFF"
	)


func _create_chunk(
	chunk_name: String,
	region: Rect2,
	top_depth_m: float,
	x_offset: float,
	target_width: float
) -> void:
	if _terrain_texture == null or _terrain_root == null:
		return
	if region.size.x <= 0.0 or region.size.y <= 0.0:
		return

	var atlas := AtlasTexture.new()
	atlas.atlas = _terrain_texture
	atlas.region = region

	var sprite := Sprite2D.new()
	sprite.name = chunk_name
	sprite.texture = atlas
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.centered = false

	# X/Y ayni scale: oran bozulmaz. Dev 12k stretch YOK.
	var uniform_scale: float = target_width / region.size.x
	sprite.scale = Vector2.ONE * uniform_scale
	sprite.position = Vector2(
		x_offset,
		_world_y_for_depth(top_depth_m)
	)

	# Derinlik atmosferi zaten karartiyor; sadece hafif arka-plan soluklugu.
	sprite.modulate = Color(0.86, 0.93, 0.97, 0.90)
	sprite.z_index = 0
	_terrain_root.add_child(sprite)


func _update_horizontal_alignment() -> void:
	if not is_instance_valid(_terrain_root) or not is_instance_valid(_camera):
		return

	# Parallax yok. Kara parcasi kadrajla saga-sola savrulmaz.
	# Sadece X merkezini kameraya 1:1 baglariz; Y koordinatlari gercek dunya derinligidir.
	_terrain_root.global_position.x = _camera.global_position.x
	_terrain_root.global_position.y = 0.0


func _pixels_per_meter() -> float:
	var hook: Node2D = _world.get_node_or_null("Boat/Hook") as Node2D
	if hook == null:
		return 34.5

	var max_depth_pixels: float = float(hook.get("max_depth"))
	var max_depth_meters: float = float(hook.get("max_depth_meters"))
	if max_depth_pixels <= 0.0 or max_depth_meters <= 0.0:
		return 34.5

	return max_depth_pixels / max_depth_meters


func _world_y_for_depth(depth_meters: float) -> float:
	var boat: Node2D = _world.get_node_or_null("Boat") as Node2D
	var hook: Node2D = _world.get_node_or_null("Boat/Hook") as Node2D
	if boat == null or hook == null:
		return 392.6 + depth_meters * 34.5

	var hook_start_y: float = hook.position.y
	var start_variant: Variant = hook.get("start_position")
	if start_variant is Vector2:
		hook_start_y = (start_variant as Vector2).y

	return boat.global_position.y + hook_start_y + depth_meters * _pixels_per_meter()


func _load_png_direct() -> Texture2D:
	if _terrain_texture != null:
		return _terrain_texture

	var absolute_path: String = ProjectSettings.globalize_path(TERRAIN_TEXTURE_PATH)
	if not FileAccess.file_exists(absolute_path):
		push_error("UNDERWATER TERRAIN: PNG DOSYASI YOK | " + absolute_path)
		return null

	var image := Image.new()
	var err: Error = image.load(absolute_path)
	if err != OK:
		push_error("UNDERWATER TERRAIN: PNG OKUNAMADI | error=%d | %s" % [err, absolute_path])
		return null

	if image.get_width() <= 0 or image.get_height() <= 0:
		push_error("UNDERWATER TERRAIN: PNG bos image verdi")
		return null

	_terrain_texture = ImageTexture.create_from_image(image)
	return _terrain_texture


func _remove_old_terrain() -> void:
	var old_direct: Node = _world.get_node_or_null(TERRAIN_NODE_NAME)
	if old_direct != null:
		_world.remove_child(old_direct)
		old_direct.queue_free()

	var background_layer: Node = _world.get_node_or_null(
		"EnvironmentLayers/UnderwaterLayers/BackgroundDecorLayer"
	)
	if background_layer != null:
		var old_background: Node = background_layer.get_node_or_null(TERRAIN_NODE_NAME)
		if old_background != null:
			background_layer.remove_child(old_background)
			old_background.queue_free()

		var old_foundation: Node = background_layer.get_node_or_null("UnderwaterTerrainFoundation")
		if old_foundation != null:
			background_layer.remove_child(old_foundation)
			old_foundation.queue_free()
