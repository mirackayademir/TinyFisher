@tool
extends RefCounted

# TinyFisher canyon source loader.
#
# Priority:
# 1) Use the approved final Q95 RGBA canyon only when all 41 chunks are complete
#    and the full payload passes byte length, SHA-256, WebP, size and alpha checks.
# 2) If that transfer is still incomplete/corrupt, automatically fall back to the
#    older V15 canyon whose complete binary is already hash-verified in the repo.
#
# This keeps editor preview/runtime usable without inventing missing HQ bytes.

const FINAL_DATA_DIR: String = "res://assets/environment/terrain/runtime_data_final"
const FINAL_PART_PREFIX: String = "canyon_final_q95_part"
const FINAL_PART_COUNT: int = 41
const FINAL_CHUNK_BASE64_LENGTH: int = 16000
const FINAL_EXPECTED_BASE64_LENGTH: int = 642596
const FINAL_EXPECTED_RAW_BYTES: int = 481946
const FINAL_EXPECTED_WIDTH: int = 1226
const FINAL_EXPECTED_HEIGHT: int = 1283
const FINAL_EXPECTED_SHA256: String = "b00865a0d42d6488159f9ecf4cbde30df86873d96036f6630d548ec68f429679"

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
	var final_texture: Texture2D = _try_build_final_texture()
	if final_texture != null:
		return final_texture

	push_warning(
		"FINAL CANYON transferi tamamlanmamis veya dogrulanamadi; "
		+ "SHA-256 ile dogrulanmis V15 canyon fallback kullaniliyor."
	)

	var fallback_texture: Texture2D = _build_verified_fallback_texture()
	if fallback_texture != null:
		return fallback_texture

	push_error("CANYON yuklenemedi: final Q95 ve verified V15 fallback kullanilamiyor.")
	return null


static func _try_build_final_texture() -> Texture2D:
	var chunks: PackedStringArray = PackedStringArray()
	var final_chunk_length: int = FINAL_EXPECTED_BASE64_LENGTH - (FINAL_CHUNK_BASE64_LENGTH * (FINAL_PART_COUNT - 1))

	for part_index: int in range(FINAL_PART_COUNT):
		var part_path: String = "%s/%s%02d.txt" % [FINAL_DATA_DIR, FINAL_PART_PREFIX, part_index]
		if not FileAccess.file_exists(part_path):
			push_warning("FINAL CANYON incomplete: part%02d bulunamadi." % part_index)
			return null

		var file: FileAccess = FileAccess.open(part_path, FileAccess.READ)
		if file == null:
			push_warning("FINAL CANYON incomplete: part%02d okunamadi." % part_index)
			return null

		var chunk: String = file.get_as_text().strip_edges()
		var expected_chunk_length: int = FINAL_CHUNK_BASE64_LENGTH
		if part_index == FINAL_PART_COUNT - 1:
			expected_chunk_length = final_chunk_length

		if chunk.length() != expected_chunk_length:
			push_warning(
				"FINAL CANYON incomplete: part%02d length=%d expected=%d." % [
					part_index,
					chunk.length(),
					expected_chunk_length
				]
			)
			return null

		chunks.append(chunk)

	var encoded: String = "".join(chunks)
	if encoded.length() != FINAL_EXPECTED_BASE64_LENGTH:
		push_warning(
			"FINAL CANYON incomplete: base64 length=%d expected=%d." % [
				encoded.length(), FINAL_EXPECTED_BASE64_LENGTH
			]
		)
		return null

	var raw: PackedByteArray = Marshalls.base64_to_raw(encoded)
	if raw.size() != FINAL_EXPECTED_RAW_BYTES:
		push_warning(
			"FINAL CANYON incomplete: raw bytes=%d expected=%d." % [
				raw.size(), FINAL_EXPECTED_RAW_BYTES
			]
		)
		return null

	var hash_context: HashingContext = HashingContext.new()
	var hash_start_error: Error = hash_context.start(HashingContext.HASH_SHA256)
	if hash_start_error != OK:
		push_warning("FINAL CANYON SHA256 baslatilamadi: " + error_string(hash_start_error))
		return null

	var hash_update_error: Error = hash_context.update(raw)
	if hash_update_error != OK:
		push_warning("FINAL CANYON SHA256 hesaplanamadi: " + error_string(hash_update_error))
		return null

	var actual_sha256: String = hash_context.finish().hex_encode()
	if actual_sha256 != FINAL_EXPECTED_SHA256:
		push_warning("FINAL CANYON SHA256 uyusmuyor; verified fallback kullanilacak.")
		return null

	var image: Image = Image.new()
	var decode_error: Error = image.load_webp_from_buffer(raw)
	if decode_error != OK or image.is_empty():
		push_warning("FINAL CANYON WebP decode edilemedi; verified fallback kullanilacak.")
		return null

	if image.get_width() != FINAL_EXPECTED_WIDTH or image.get_height() != FINAL_EXPECTED_HEIGHT:
		push_warning(
			"FINAL CANYON size=%dx%d expected=%dx%d; verified fallback kullanilacak." % [
				image.get_width(), image.get_height(), FINAL_EXPECTED_WIDTH, FINAL_EXPECTED_HEIGHT
			]
		)
		return null

	if image.detect_alpha() == Image.ALPHA_NONE:
		push_warning("FINAL CANYON alpha kanali yok; verified fallback kullanilacak.")
		return null

	var used_rect: Rect2i = image.get_used_rect()
	if used_rect.size.x <= 0 or used_rect.size.y <= 0:
		push_warning("FINAL CANYON alpha alani bos; verified fallback kullanilacak.")
		return null

	var texture: ImageTexture = ImageTexture.create_from_image(image)
	if texture == null:
		push_warning("FINAL CANYON texture olusturulamadi; verified fallback kullanilacak.")
		return null

	print(
		"FINAL CANYON VERIFIED: %d parts / %d bytes / SHA256=OK / %dx%d RGBA" % [
			FINAL_PART_COUNT,
			raw.size(),
			image.get_width(),
			image.get_height()
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
