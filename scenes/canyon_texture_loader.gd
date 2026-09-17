@tool
extends RefCounted

# TinyFisher canyon texture loader.
# Primary source is the approved single-file HQ canyon asset.
# The historical hash-verified V15 payload is kept only as an emergency fallback.

const HQ_ASSET_PATH: String = "res://assets/environment/terrain/canyon_hq.webp"
const HQ_EXPECTED_WIDTH: int = 1226
const HQ_EXPECTED_HEIGHT: int = 1283

const FALLBACK_EXPECTED_B64: int = 74540
const FALLBACK_EXPECTED_BYTES: int = 55904
const FALLBACK_EXPECTED_WIDTH: int = 965
const FALLBACK_EXPECTED_HEIGHT: int = 722
const FALLBACK_EXPECTED_SHA256: String = "44d51db26db819b7ca6c950bf4cc67b1074a41da859272337ef1a2b2763395f4"

const FALLBACK_PART_PATHS: Array[String] = [
	"res://assets/environment/terrain/runtime_data/canyon_20_100_part0.txt",
	"res://assets/environment/terrain/runtime_data/canyon_20_100_part1.txt",
	"res://assets/environment/terrain/runtime_data/canyon_20_100_part2a.txt",
	"res://assets/environment/terrain/runtime_data/canyon_20_100_part2b.txt",
	"res://assets/environment/terrain/runtime_data/canyon_20_100_part2c.txt",
	"res://assets/environment/terrain/runtime_data/canyon_20_100_part3a.txt",
	"res://assets/environment/terrain/runtime_data/canyon_20_100_part3b.txt",
	"res://assets/environment/terrain/runtime_data/canyon_20_100_part3c.txt",
	"res://assets/environment/terrain/runtime_data/canyon_20_100_part4a.txt",
	"res://assets/environment/terrain/runtime_data/canyon_20_100_part4b.txt",
	"res://assets/environment/terrain/runtime_data/canyon_20_100_part4c.txt",
	"res://assets/environment/terrain/runtime_data/canyon_20_100_part5a.txt",
	"res://assets/environment/terrain/runtime_data/canyon_20_100_part5b0.txt",
	"res://assets/environment/terrain/runtime_data/canyon_20_100_part5b1.txt",
	"res://assets/environment/terrain/runtime_data/canyon_20_100_part5b2.txt",
	"res://assets/environment/terrain/runtime_data/canyon_20_100_part5b3.txt",
	"res://assets/environment/terrain/runtime_data/canyon_20_100_part5c.txt",
	"res://assets/environment/terrain/runtime_data/canyon_20_100_part6.txt"
]


static func build_texture() -> Texture2D:
	var hq_texture: Texture2D = _load_hq_asset()
	if hq_texture != null:
		return hq_texture

	push_warning(
		"HQ canyon asset kullanilamadi; SHA-256 ile dogrulanmis V15 emergency fallback kullaniliyor."
	)

	var fallback_texture: Texture2D = _build_verified_fallback_texture()
	if fallback_texture != null:
		return fallback_texture

	push_error("CANYON yuklenemedi: HQ asset ve verified fallback kullanilamiyor.")
	return null


static func _load_hq_asset() -> Texture2D:
	if not ResourceLoader.exists(HQ_ASSET_PATH):
		return null

	var resource: Resource = ResourceLoader.load(HQ_ASSET_PATH)
	var texture: Texture2D = resource as Texture2D
	if texture == null:
		push_warning("HQ canyon asset Texture2D olarak yuklenemedi: " + HQ_ASSET_PATH)
		return null

	if texture.get_width() != HQ_EXPECTED_WIDTH or texture.get_height() != HQ_EXPECTED_HEIGHT:
		push_warning(
			"HQ canyon asset boyutu uyusmuyor: got=%dx%d expected=%dx%d" % [
				texture.get_width(),
				texture.get_height(),
				HQ_EXPECTED_WIDTH,
				HQ_EXPECTED_HEIGHT
			]
		)
		return null

	var image: Image = texture.get_image()
	if image == null or image.is_empty():
		push_warning("HQ canyon asset image verisi okunamadi.")
		return null

	if image.detect_alpha() == Image.ALPHA_NONE:
		push_warning("HQ canyon asset alpha kanali olmadan import edilmis.")
		return null

	var used_rect: Rect2i = image.get_used_rect()
	if used_rect.size.x <= 0 or used_rect.size.y <= 0:
		push_warning("HQ canyon asset gorunur alpha alani bos.")
		return null

	print(
		"HQ CANYON ASSET OK: %dx%d RGBA / alpha_used=%dx%d / single-file" % [
			texture.get_width(),
			texture.get_height(),
			used_rect.size.x,
			used_rect.size.y
		]
	)
	return texture


static func _build_verified_fallback_texture() -> Texture2D:
	var encoded: String = ""

	for path: String in FALLBACK_PART_PATHS:
		if not FileAccess.file_exists(path):
			push_error("VERIFIED CANYON fallback parcasi eksik: " + path)
			return null

		var file: FileAccess = FileAccess.open(path, FileAccess.READ)
		if file == null:
			push_error("VERIFIED CANYON fallback parcasi acilamadi: " + path)
			return null

		encoded += file.get_as_text().strip_edges()

	if encoded.length() != FALLBACK_EXPECTED_B64:
		push_error(
			"VERIFIED CANYON fallback base64 boyutu bozuk. Beklenen=%d Gelen=%d" % [
				FALLBACK_EXPECTED_B64,
				encoded.length()
			]
		)
		return null

	var raw: PackedByteArray = Marshalls.base64_to_raw(encoded)
	if raw.size() != FALLBACK_EXPECTED_BYTES:
		push_error(
			"VERIFIED CANYON fallback byte boyutu bozuk. Beklenen=%d Gelen=%d" % [
				FALLBACK_EXPECTED_BYTES,
				raw.size()
			]
		)
		return null

	var hashing: HashingContext = HashingContext.new()
	var hash_start_error: Error = hashing.start(HashingContext.HASH_SHA256)
	if hash_start_error != OK:
		push_error("VERIFIED CANYON fallback SHA256 baslatilamadi: " + error_string(hash_start_error))
		return null

	var hash_update_error: Error = hashing.update(raw)
	if hash_update_error != OK:
		push_error("VERIFIED CANYON fallback SHA256 hesaplanamadi: " + error_string(hash_update_error))
		return null

	var actual_sha: String = hashing.finish().hex_encode()
	if actual_sha != FALLBACK_EXPECTED_SHA256:
		push_error(
			"VERIFIED CANYON fallback SHA256 uyusmuyor. Beklenen=%s Gelen=%s" % [
				FALLBACK_EXPECTED_SHA256,
				actual_sha
			]
		)
		return null

	var image: Image = Image.new()
	var decode_error: Error = image.load_webp_from_buffer(raw)
	if decode_error != OK or image.is_empty():
		push_error("VERIFIED CANYON fallback WebP decode edilemedi: " + error_string(decode_error))
		return null

	if image.get_width() != FALLBACK_EXPECTED_WIDTH or image.get_height() != FALLBACK_EXPECTED_HEIGHT:
		push_error(
			"VERIFIED CANYON fallback boyutu uyusmuyor. Beklenen=%dx%d Gelen=%dx%d" % [
				FALLBACK_EXPECTED_WIDTH,
				FALLBACK_EXPECTED_HEIGHT,
				image.get_width(),
				image.get_height()
			]
		)
		return null

	var texture: ImageTexture = ImageTexture.create_from_image(image)
	if texture == null:
		push_error("VERIFIED CANYON fallback texture olusturulamadi.")
		return null

	print(
		"VERIFIED CANYON FALLBACK OK: %d parts / %d bytes / SHA256=OK / %dx%d" % [
			FALLBACK_PART_PATHS.size(),
			raw.size(),
			image.get_width(),
			image.get_height()
		]
	)
	return texture


static func visible_region(texture: Texture2D) -> Rect2:
	if texture == null:
		return Rect2()

	var image: Image = texture.get_image()
	if image == null or image.is_empty():
		return Rect2(0.0, 0.0, texture.get_width() + 0.0, texture.get_height() + 0.0)

	var used_rect: Rect2i = image.get_used_rect()
	if used_rect.size.x <= 0 or used_rect.size.y <= 0:
		return Rect2(0.0, 0.0, texture.get_width() + 0.0, texture.get_height() + 0.0)

	return Rect2(
		float(used_rect.position.x),
		float(used_rect.position.y),
		float(used_rect.size.x),
		float(used_rect.size.y)
	)
