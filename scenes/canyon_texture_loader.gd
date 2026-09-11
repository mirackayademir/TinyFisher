@tool
extends RefCounted

# TinyFisher final canyon source.
# The approved transparent canyon is stored as one Q95 RGBA WebP split into
# 41 Base64 text chunks. Editor preview and runtime both reconstruct the exact
# same source bytes through this loader; no runtime resize/upscale is performed.

const FINAL_DATA_DIR: String = "res://assets/environment/terrain/runtime_data_final"
const PART_PREFIX: String = "canyon_final_q95_part"
const PART_COUNT: int = 41
const CHUNK_BASE64_LENGTH: int = 16000
const EXPECTED_BASE64_LENGTH: int = 642596
const EXPECTED_RAW_BYTES: int = 481946
const EXPECTED_WIDTH: int = 1226
const EXPECTED_HEIGHT: int = 1283
const EXPECTED_SHA256: String = "b00865a0d42d6488159f9ecf4cbde30df86873d96036f6630d548ec68f429679"


static func build_texture() -> Texture2D:
	var chunks: PackedStringArray = PackedStringArray()
	var final_chunk_length: int = EXPECTED_BASE64_LENGTH - (CHUNK_BASE64_LENGTH * (PART_COUNT - 1))

	for part_index: int in range(PART_COUNT):
		var part_path: String = "%s/%s%02d.txt" % [FINAL_DATA_DIR, PART_PREFIX, part_index]
		if not FileAccess.file_exists(part_path):
			push_error(
				"FINAL CANYON data eksik: part%02d bulunamadi (%s). Beklenen toplam: %d parca." % [
					part_index, part_path, PART_COUNT
				]
			)
			return null

		var file: FileAccess = FileAccess.open(part_path, FileAccess.READ)
		if file == null:
			push_error(
				"FINAL CANYON data okunamadi: part%02d (%s). FileAccess error=%s" % [
					part_index, part_path, error_string(FileAccess.get_open_error())
				]
			)
			return null

		var chunk: String = file.get_as_text().strip_edges()
		var expected_chunk_length: int = CHUNK_BASE64_LENGTH
		if part_index == PART_COUNT - 1:
			expected_chunk_length = final_chunk_length

		if chunk.length() != expected_chunk_length:
			push_error(
				"FINAL CANYON part%02d uzunluk hatasi: got=%d expected=%d" % [
					part_index, chunk.length(), expected_chunk_length
				]
			)
			return null

		chunks.append(chunk)

	var encoded: String = "".join(chunks)
	if encoded.length() != EXPECTED_BASE64_LENGTH:
		push_error(
			"FINAL CANYON Base64 uzunluk hatasi: got=%d expected=%d" % [
				encoded.length(), EXPECTED_BASE64_LENGTH
			]
		)
		return null

	var raw: PackedByteArray = Marshalls.base64_to_raw(encoded)
	if raw.size() != EXPECTED_RAW_BYTES:
		push_error(
			"FINAL CANYON raw byte hatasi: got=%d expected=%d" % [
				raw.size(), EXPECTED_RAW_BYTES
			]
		)
		return null

	var hash_context: HashingContext = HashingContext.new()
	var hash_start_error: Error = hash_context.start(HashingContext.HASH_SHA256)
	if hash_start_error != OK:
		push_error("FINAL CANYON SHA256 baslatilamadi: " + error_string(hash_start_error))
		return null

	var hash_update_error: Error = hash_context.update(raw)
	if hash_update_error != OK:
		push_error("FINAL CANYON SHA256 hesaplanamadi: " + error_string(hash_update_error))
		return null

	var actual_sha256: String = hash_context.finish().hex_encode()
	if actual_sha256 != EXPECTED_SHA256:
		push_error(
			"FINAL CANYON SHA256 uyusmuyor: got=%s expected=%s" % [
				actual_sha256, EXPECTED_SHA256
			]
		)
		return null

	var image: Image = Image.new()
	var decode_error: Error = image.load_webp_from_buffer(raw)
	if decode_error != OK:
		push_error("FINAL CANYON WebP decode hatasi: " + error_string(decode_error))
		return null

	if image.is_empty():
		push_error("FINAL CANYON WebP decode edildi ancak image bos.")
		return null

	var width: int = image.get_width()
	var height: int = image.get_height()
	if width != EXPECTED_WIDTH or height != EXPECTED_HEIGHT:
		push_error(
			"FINAL CANYON boyut hatasi: got=%dx%d expected=%dx%d" % [
				width, height, EXPECTED_WIDTH, EXPECTED_HEIGHT
			]
		)
		return null

	if image.detect_alpha() == Image.ALPHA_NONE:
		push_error("FINAL CANYON alpha kanali yok; onaylanan RGBA kaynak bekleniyor.")
		return null

	var used_rect: Rect2i = image.get_used_rect()
	if used_rect.size.x <= 0 or used_rect.size.y <= 0:
		push_error("FINAL CANYON alpha alani bos.")
		return null

	var texture: ImageTexture = ImageTexture.create_from_image(image)
	if texture == null:
		push_error("FINAL CANYON ImageTexture olusturulamadi.")
		return null

	print(
		"FINAL CANYON VERIFIED: %d parts / %d bytes / SHA256=OK / %dx%d RGBA / alpha_used=%dx%d" % [
			PART_COUNT,
			raw.size(),
			width,
			height,
			used_rect.size.x,
			used_rect.size.y
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
