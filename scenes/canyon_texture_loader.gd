@tool
extends RefCounted

# Single verified source of truth for the accepted 20-100 m HQ canyon artwork.
# The binary .webp committed at assets/environment/terrain is incomplete, so we
# rebuild the original lossless WebP in memory from the verified base64 chunks.

const SOURCE_CROP_TOP_PX: int = 27
const EXPECTED_SOURCE_WIDTH: int = 2048
const EXPECTED_SOURCE_HEIGHT: int = 682
const EXPECTED_RAW_SIZE: int = 107932

const LOSSLESS_PART_PATHS: Array[String] = [
	"res://assets/environment/terrain/runtime_data/hq_lossless/part_00.txt",
	"res://assets/environment/terrain/runtime_data/hq_lossless/part_01.txt",
	"res://assets/environment/terrain/runtime_data/hq_lossless/part_02a.txt",
	"res://assets/environment/terrain/runtime_data/hq_lossless/part_02b.txt",
	"res://assets/environment/terrain/runtime_data/hq_lossless/part_03.txt",
	"res://assets/environment/terrain/runtime_data/hq_lossless/part_04.txt",
	"res://assets/environment/terrain/runtime_data/hq_lossless/part_05.txt",
	"res://assets/environment/terrain/runtime_data/hq_lossless/part_06.txt",
	"res://assets/environment/terrain/runtime_data/hq_lossless/part_07.txt"
]


static func build_texture() -> Texture2D:
	var payload: String = ""

	for path: String in LOSSLESS_PART_PATHS:
		if not FileAccess.file_exists(path):
			push_error("HQ canyon parcasi eksik: " + path)
			return null

		var file: FileAccess = FileAccess.open(path, FileAccess.READ)
		if file == null:
			push_error("HQ canyon parcasi acilamadi: " + path)
			return null

		var chunk: String = file.get_as_text()
		chunk = chunk.replace("\n", "")
		chunk = chunk.replace("\r", "")
		chunk = chunk.replace("\t", "")
		chunk = chunk.replace(" ", "")
		payload += chunk

	if payload.length() < 16:
		push_error("HQ canyon payload RIFF basligi icin fazla kisa.")
		return null

	var header: PackedByteArray = Marshalls.base64_to_raw(payload.substr(0, 16))
	if header.size() < 12:
		push_error("HQ canyon RIFF basligi decode edilemedi.")
		return null

	if header[0] != 82 or header[1] != 73 or header[2] != 70 or header[3] != 70 \
	or header[8] != 87 or header[9] != 69 or header[10] != 66 or header[11] != 80:
		push_error("HQ canyon payload RIFF/WEBP imzasi gecersiz.")
		return null

	var riff_payload_size: int = int(header[4]) \
		+ int(header[5]) * 256 \
		+ int(header[6]) * 65536 \
		+ int(header[7]) * 16777216
	var expected_raw_size: int = riff_payload_size + 8
	var expected_base64_length: int = int(ceil(float(expected_raw_size) / 3.0)) * 4

	if expected_raw_size != EXPECTED_RAW_SIZE:
		push_error(
			"HQ canyon RIFF boyutu beklenenden farkli. Beklenen=%d Gelen=%d" % [
				EXPECTED_RAW_SIZE,
				expected_raw_size
			]
		)
		return null

	if expected_base64_length > payload.length():
		push_error(
			"HQ canyon payload eksik. Gereken base64=%d Gelen=%d" % [
				expected_base64_length,
				payload.length()
			]
		)
		return null

	# Trim only transfer garbage after the authoritative RIFF boundary.
	payload = payload.substr(0, expected_base64_length)
	if payload.length() % 4 != 0:
		push_error("HQ canyon base64 payload 4-byte hizasinda degil.")
		return null

	var raw: PackedByteArray = Marshalls.base64_to_raw(payload)
	if raw.size() != expected_raw_size:
		push_error(
			"HQ canyon decode boyutu uyusmuyor. Beklenen=%d Gelen=%d" % [
				expected_raw_size,
				raw.size()
			]
		)
		return null

	var image: Image = Image.new()
	var decode_error: int = image.load_webp_from_buffer(raw)
	if decode_error != OK or image.is_empty():
		push_error("HQ canyon WebP decode edilemedi. Error=%d" % decode_error)
		return null

	if image.get_width() != EXPECTED_SOURCE_WIDTH or image.get_height() != EXPECTED_SOURCE_HEIGHT:
		push_error(
			"HQ canyon kaynak boyutu dogrulanamadi. Beklenen=%dx%d Gelen=%dx%d" % [
				EXPECTED_SOURCE_WIDTH,
				EXPECTED_SOURCE_HEIGHT,
				image.get_width(),
				image.get_height()
			]
		)
		return null

	print(
		"HQ CANYON OK: %d parca / %d byte / %dx%d" % [
			LOSSLESS_PART_PATHS.size(),
			raw.size(),
			image.get_width(),
			image.get_height()
		]
	)

	return ImageTexture.create_from_image(image)


static func visible_region(texture: Texture2D) -> Rect2:
	if texture == null:
		return Rect2()
	return Rect2(
		0.0,
		float(SOURCE_CROP_TOP_PX),
		float(texture.get_width()),
		float(texture.get_height() - SOURCE_CROP_TOP_PX)
	)
