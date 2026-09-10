extends Node

# TinyFisher 20-100m fake-3D arka-plan terrain.
# Onaylanan terrain gorseli TEK PARCA kullanilir.
# Tile / tekrar / dev dunya stretch YOK.
# 1280x720 oyun kadrajina oran korunarak oturur ve 20-100m boyunca kamerayi izler.
# Collision yoktur; baliklar ve kanca terrain'in onunden gecer.

const TERRAIN_TEXTURE_PATH: String = "res://assets/environment/terrain/underwater_terrain_20_100.png"
const TERRAIN_NODE_NAME: String = "UnderwaterReefTerrain20To100"
const LAYOUT_VERSION: int = 7
const START_DEPTH_METERS: float = 20.0
const END_DEPTH_METERS: float = 100.0

var _scene_id: int = 0
var _world: Node2D = null
var _hook: Node2D = null
var _camera: Camera2D = null
var _terrain_root: Node2D = null
var _terrain_sprite: Sprite2D = null
var _terrain_texture: Texture2D = null
var _load_failed: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	print("UNDERWATER TERRAIN V7: tek kadraj / tekrar yok / collision yok")


func _process(_delta: float) -> void:
	var current_scene: Node = get_tree().current_scene
	if current_scene == null:
		_reset_refs()
		return

	var current_id: int = current_scene.get_instance_id()
	if current_id != _scene_id:
		_scene_id = current_id
		_world = current_scene as Node2D
		_hook = null
		_camera = null
		_terrain_root = null
		_terrain_sprite = null
		_load_failed = false

	if _world == null:
		return

	_hook = _world.get_node_or_null("Boat/Hook") as Node2D
	_camera = _world.get_node_or_null("Boat/Camera2D") as Camera2D
	if _hook == null or _camera == null:
		return

	_ensure_terrain()
	_update_terrain()


func _reset_refs() -> void:
	_scene_id = 0
	_world = null
	_hook = null
	_camera = null
	_terrain_root = null
	_terrain_sprite = null
	_load_failed = false


func _ensure_terrain() -> void:
	if is_instance_valid(_terrain_root) and is_instance_valid(_terrain_sprite):
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
	# Water -9. Terrain -7: suyun onunde, balik/kancanin arkasinda.
	_terrain_root.z_index = -7
	_terrain_root.set_meta("layout_version", LAYOUT_VERSION)
	_terrain_root.set_meta("collisionless", true)
	_world.add_child(_terrain_root)

	_terrain_sprite = Sprite2D.new()
	_terrain_sprite.name = "ReefTerrainArt"
	_terrain_sprite.texture = texture
	_terrain_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_terrain_sprite.centered = true
	_terrain_sprite.z_index = 0
	# Biraz soluk: fake-3D arka plan hissi. Alpha kaybolacak kadar dusuk degil.
	_terrain_sprite.modulate = Color(0.72, 0.83, 0.90, 0.78)
	_terrain_root.add_child(_terrain_sprite)

	_fit_to_viewport(source_size)
	print("UNDERWATER TERRAIN V7 OK | source=", source_size, " | single-frame=true | collision=OFF")


func _fit_to_viewport(source_size: Vector2) -> void:
	if _terrain_sprite == null:
		return

	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		viewport_size = Vector2(1280.0, 720.0)

	# Orani ASLA bozma. Gorseli oyun dikdortgeninin icine sigdir.
	# 384x211 kaynak yaklasik 16:9 oldugu icin 1280 kadrajda ~1280x703 olur.
	var fit_scale: float = minf(
		viewport_size.x / source_size.x,
		viewport_size.y / source_size.y
	)
	_terrain_sprite.scale = Vector2.ONE * fit_scale

	# Asset alt hizali tasarlandi. Kadrajin altina oturt; kalan ufak bosluk ustte kalsin.
	var drawn_height: float = source_size.y * fit_scale
	_terrain_sprite.position = Vector2(0.0, (viewport_size.y - drawn_height) * 0.5)


func _update_terrain() -> void:
	if not is_instance_valid(_terrain_root) or not is_instance_valid(_terrain_sprite):
		return

	var depth_m: float = _current_depth_meters()
	_terrain_root.visible = depth_m >= START_DEPTH_METERS and depth_m <= END_DEPTH_METERS
	if not _terrain_root.visible:
		return

	# Tek 16:9 terrain resmi, onaylanan prototipteki gibi oyun kadrajini doldurur.
	# Dunya boyunca tekrar etmez. Kamera nereye giderse o anki 1280x720 su kadrajina oturur.
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		viewport_size = Vector2(1280.0, 720.0)

	var camera_center: Vector2 = _camera.global_position
	var source_size: Vector2 = _terrain_texture.get_size()
	var fit_scale: float = minf(viewport_size.x / source_size.x, viewport_size.y / source_size.y)
	var drawn_height: float = source_size.y * fit_scale

	# Sprite merkezi kamera merkezi. Asseti ekranin altina hizalamak icin kalan boslugu yukariya birak.
	_terrain_root.global_position = camera_center + Vector2(0.0, (viewport_size.y - drawn_height) * 0.5)
	_terrain_sprite.position = Vector2.ZERO


func _current_depth_meters() -> float:
	if _hook == null:
		return 0.0
	if not bool(_hook.get("deployed")):
		return 0.0

	var start_variant: Variant = _hook.get("start_position")
	var max_depth_pixels: float = float(_hook.get("max_depth"))
	var max_depth_meters: float = float(_hook.get("max_depth_meters"))
	if not (start_variant is Vector2) or max_depth_pixels <= 0.0 or max_depth_meters <= 0.0:
		return 0.0

	var start_position: Vector2 = start_variant as Vector2
	var depth_pixels: float = clampf(_hook.position.y - start_position.y, 0.0, max_depth_pixels)
	return (depth_pixels / max_depth_pixels) * max_depth_meters


func _load_png_direct() -> Texture2D:
	if _terrain_texture != null:
		return _terrain_texture

	var absolute_path: String = ProjectSettings.globalize_path(TERRAIN_TEXTURE_PATH)
	if not FileAccess.file_exists(absolute_path):
		push_error("UNDERWATER TERRAIN: PNG DOSYASI YOK | " + absolute_path)
		return null

	var image: Image = Image.new()
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
