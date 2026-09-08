extends Node

# Miraç tarafından onaylanan üç detaylı balık görselini oyunun her yerinde
# eski prototip SVG'lerin yerine kullanır. WebP dosyaları Godot import zincirine
# bırakılmıyor; ham dosya baytları okunup ImageTexture olarak oluşturuluyor.
# Böylece editor import/preload sorunu olsa bile ekranda onaylanan görseller çıkar.

const KILIC_OLD: String = "res://assets/kilic_baligi.svg"
const KOPEK_OLD: String = "res://assets/kopekbaligi.svg"
const FENER_OLD: String = "res://assets/fener_baligi.svg"

const KILIC_PATH: String = "res://assets/approved/kilic_baligi.webp"
const KOPEK_PATH: String = "res://assets/approved/kopekbaligi.webp"
const FENER_PATH: String = "res://assets/approved/fener_baligi.webp"

const SCAN_INTERVAL: float = 0.10

var _scan_timer: float = 0.0
var _kilic_approved: Texture2D = null
var _kopek_approved: Texture2D = null
var _fener_approved: Texture2D = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_approved_textures()
	_apply_to_current_scene()


func _process(delta: float) -> void:
	_scan_timer -= delta
	if _scan_timer > 0.0:
		return
	_scan_timer = SCAN_INTERVAL
	_apply_to_current_scene()


func _load_approved_textures() -> void:
	_kilic_approved = _load_webp_direct(KILIC_PATH)
	_kopek_approved = _load_webp_direct(KOPEK_PATH)
	_fener_approved = _load_webp_direct(FENER_PATH)


func _load_webp_direct(path: String) -> Texture2D:
	if not FileAccess.file_exists(path):
		push_error("Onaylı balık görseli bulunamadı: " + path)
		return null

	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(path)
	if bytes.is_empty():
		push_error("Onaylı balık görseli okunamadı: " + path)
		return null

	var image: Image = Image.new()
	var load_error: Error = image.load_webp_from_buffer(bytes)
	if load_error != OK or image.is_empty():
		push_error("Onaylı balık WebP görseli çözülemedi: " + path + " hata=" + str(load_error))
		return null

	return ImageTexture.create_from_image(image)


func get_texture_for_fish(fish_type: String) -> Texture2D:
	match fish_type:
		"Kılıç Balığı":
			return _kilic_approved
		"Köpekbalığı":
			return _kopek_approved
		"Fener Balığı":
			return _fener_approved
		_:
			return null


func _apply_to_current_scene() -> void:
	var root: Node = get_tree().current_scene
	if root == null:
		return
	_scan_node(root)


func _scan_node(node: Node) -> void:
	if node is Sprite2D:
		_replace_sprite(node as Sprite2D)
	elif node is TextureRect:
		_replace_texture_rect(node as TextureRect)

	for child: Node in node.get_children():
		_scan_node(child)


func _replace_sprite(sprite: Sprite2D) -> void:
	if sprite.texture == null:
		return

	var old_path: String = sprite.texture.resource_path
	var fish_type: String = ""
	var approved: Texture2D = null

	match old_path:
		KILIC_OLD:
			fish_type = "Kılıç Balığı"
			approved = _kilic_approved
		KOPEK_OLD:
			fish_type = "Köpekbalığı"
			approved = _kopek_approved
		FENER_OLD:
			fish_type = "Fener Balığı"
			approved = _fener_approved
		_:
			return

	if approved == null:
		return

	sprite.texture = approved
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_compensate_fish_scale(sprite, fish_type)


func _replace_texture_rect(rect: TextureRect) -> void:
	if rect.texture == null:
		return

	var approved: Texture2D = null
	match rect.texture.resource_path:
		KILIC_OLD:
			approved = _kilic_approved
		KOPEK_OLD:
			approved = _kopek_approved
		FENER_OLD:
			approved = _fener_approved
		_:
			return

	if approved == null:
		return

	rect.texture = approved
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func _compensate_fish_scale(sprite: Sprite2D, fish_type: String) -> void:
	var fish: Node = sprite.get_parent()
	if fish == null or not fish.has_method("hook_to"):
		return

	var target_scale: Vector2 = Vector2.ONE
	match fish_type:
		"Kılıç Balığı":
			target_scale = Vector2(0.57, 0.57)
		"Köpekbalığı":
			target_scale = Vector2(0.61, 0.61)
		"Fener Balığı":
			target_scale = Vector2(0.55, 0.55)
		_:
			return

	fish.set("base_sprite_scale", target_scale)
	sprite.scale = target_scale
