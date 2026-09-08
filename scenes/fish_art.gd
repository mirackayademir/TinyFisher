extends RefCounted
class_name FishArt

const APPROVED_TEXTURE_FILES: Dictionary = {
	"Kılıç Balığı": "res://assets/approved/kilic_baligi.b64",
	"Köpekbalığı": "res://assets/approved/kopekbaligi.b64",
	"Fener Balığı": "res://assets/approved/fener_baligi.b64"
}

var _cache: Dictionary = {}


func get_texture(fish_type: String) -> Texture2D:
	if _cache.has(fish_type):
		return _cache[fish_type] as Texture2D

	if not APPROVED_TEXTURE_FILES.has(fish_type):
		return null

	var path: String = str(APPROVED_TEXTURE_FILES[fish_type])
	var encoded: String = FileAccess.get_file_as_string(path).strip_edges()
	if encoded.is_empty():
		push_error("Onaylı balık görseli okunamadı: " + path)
		return null

	var bytes: PackedByteArray = Marshalls.base64_to_raw(encoded)
	var image: Image = Image.new()
	var error: Error = image.load_png_from_buffer(bytes)
	if error != OK:
		push_error("Onaylı balık PNG verisi yüklenemedi: " + path)
		return null

	var texture: ImageTexture = ImageTexture.create_from_image(image)
	_cache[fish_type] = texture
	return texture
