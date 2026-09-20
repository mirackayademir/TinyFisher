extends RefCounted

# Kürek Balığı görselini Git üzerinden güvenli metin olarak saklanan base64 kaynaktan kurar.
# Binary PNG/WebP dosyasına bağımlı değildir; Godot import cache hatalarını bypass eder.
const DATA_PATH: String = "res://generation/runtime_encoded/fish/kurek_baligi.b64"

static var _cached_texture: Texture2D = null


static func get_texture() -> Texture2D:
	if _cached_texture != null:
		return _cached_texture

	var file: FileAccess = FileAccess.open(DATA_PATH, FileAccess.READ)
	if file == null:
		push_error("OARFISH ART: base64 source missing -> " + DATA_PATH)
		return null

	var encoded: String = file.get_as_text().strip_edges()
	if encoded.is_empty():
		push_error("OARFISH ART: base64 source is empty")
		return null

	var raw: PackedByteArray = Marshalls.base64_to_raw(encoded)
	if raw.is_empty():
		push_error("OARFISH ART: base64 decode failed")
		return null

	var image := Image.new()
	var load_error: Error = image.load_png_from_buffer(raw)
	if load_error != OK or image.is_empty():
		push_error("OARFISH ART: PNG buffer decode failed (%s)" % error_string(load_error))
		return null

	_cached_texture = ImageTexture.create_from_image(image)
	print("OARFISH ART OK: runtime PNG [%dx%d]" % [image.get_width(), image.get_height()])
	return _cached_texture
