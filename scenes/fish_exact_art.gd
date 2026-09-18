extends RefCounted

# TinyFisher — Exact Fish Art Loader
# Kullanici tarafindan onaylanan 5 balik resmi kayipsiz WebP olarak kucultuldu.
# Binary import bozulmalarini tamamen atlamak icin base64 metin parcalarindan
# runtime'da yeniden kurulur.

const PARTS: Dictionary = {
	"Barakuda": [
		"res://assets/fish/runtime_data/barakuda_part00.txt",
		"res://assets/fish/runtime_data/barakuda_part01.txt"
	],
	"Müren": [
		"res://assets/fish/runtime_data/muren_part00.txt",
		"res://assets/fish/runtime_data/muren_part01.txt"
	],
	"Vatoz": [
		"res://assets/fish/runtime_data/vatoz_part00.txt",
		"res://assets/fish/runtime_data/vatoz_part01.txt"
	],
	"Deniz Şeytanı": [
		"res://assets/fish/runtime_data/deniz_seytani_part00.txt",
		"res://assets/fish/runtime_data/deniz_seytani_part01.txt"
	],
	"Kalamar": [
		"res://assets/fish/runtime_data/kalamar_part00.txt",
		"res://assets/fish/runtime_data/kalamar_part01.txt"
	]
}

const EXPECTED_SIZE: Dictionary = {
	"Barakuda": Vector2i(110, 75),
	"Müren": Vector2i(110, 80),
	"Vatoz": Vector2i(110, 82),
	"Deniz Şeytanı": Vector2i(105, 78),
	"Kalamar": Vector2i(110, 80)
}

static var _cache: Dictionary = {}


static func has_fish(fish_type: String) -> bool:
	return PARTS.has(fish_type)


static func get_texture(fish_type: String) -> Texture2D:
	var cached: Variant = _cache.get(fish_type)
	if cached is Texture2D:
		return cached as Texture2D

	var paths_value: Variant = PARTS.get(fish_type)
	if not (paths_value is Array):
		return null

	var encoded: String = ""
	for path_value: Variant in paths_value:
		var path: String = String(path_value)
		if not FileAccess.file_exists(path):
			push_error("FISH EXACT ART part missing: " + fish_type + " -> " + path)
			return null
		var file: FileAccess = FileAccess.open(path, FileAccess.READ)
		if file == null:
			push_error("FISH EXACT ART part open failed: " + fish_type + " -> " + path)
			return null
		encoded += file.get_as_text().strip_edges()

	var raw: PackedByteArray = Marshalls.base64_to_raw(encoded)
	if raw.is_empty():
		push_error("FISH EXACT ART base64 decode failed: " + fish_type)
		return null

	var image: Image = Image.new()
	var decode_error: Error = image.load_webp_from_buffer(raw)
	if decode_error != OK or image.is_empty():
		push_error("FISH EXACT ART WebP decode failed: %s (%s)" % [fish_type, error_string(decode_error)])
		return null

	var expected: Vector2i = EXPECTED_SIZE.get(fish_type, Vector2i.ZERO)
	if expected != Vector2i.ZERO and image.get_size() != expected:
		push_error(
			"FISH EXACT ART size mismatch: %s got=%s expected=%s" % [
				fish_type,
				str(image.get_size()),
				str(expected)
			]
		)
		return null

	var texture: ImageTexture = ImageTexture.create_from_image(image)
	if texture == null:
		push_error("FISH EXACT ART texture creation failed: " + fish_type)
		return null

	_cache[fish_type] = texture
	print("FISH EXACT ART OK: %s [%dx%d]" % [fish_type, image.get_width(), image.get_height()])
	return texture
