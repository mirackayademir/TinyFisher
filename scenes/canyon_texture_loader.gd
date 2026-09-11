@tool
extends RefCounted

# Single source of truth for TinyFisher's accepted 20-100 m canyon.
#
# The later 2048x682 HQ transfer is structurally corrupted even though its RIFF
# header survives. Do not attempt to repair or guess around that payload.
# Instead we restore the older V15 source whose complete binary was explicitly
# verified by byte length AND SHA-256 before WebP decoding.
#
# If any text chunk is damaged, reordered or incomplete this loader refuses to
# create a texture rather than feeding uncertain bytes to Godot's WebP decoder.

const EXPECTED_B64: int = 74540
const EXPECTED_BYTES: int = 55904
const EXPECTED_SOURCE_WIDTH: int = 965
const EXPECTED_SOURCE_HEIGHT: int = 722
const EXPECTED_SHA256: String = "44d51db26db819b7ca6c950bf4cc67b1074a41da859272337ef1a2b2763395f4"

const VERIFIED_PART_PATHS: Array[String] = [
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
	var encoded: String = ""

	for path: String in VERIFIED_PART_PATHS:
		if not FileAccess.file_exists(path):
			push_error("VERIFIED CANYON parcasi eksik: " + path)
			return null

		var file: FileAccess = FileAccess.open(path, FileAccess.READ)
		if file == null:
			push_error("VERIFIED CANYON parcasi acilamadi: " + path)
			return null

		# These chunks were originally split at exact base64 boundaries. Only
		# surrounding line endings are removed; no overlap/trimming guesses.
		encoded += file.get_as_text().strip_edges()

	if encoded.length() != EXPECTED_B64:
		push_error(
			"VERIFIED CANYON base64 boyutu bozuk. Beklenen=%d Gelen=%d" % [
				EXPECTED_B64,
				encoded.length()
			]
		)
		return null

	var raw: PackedByteArray = Marshalls.base64_to_raw(encoded)
	if raw.size() != EXPECTED_BYTES:
		push_error(
			"VERIFIED CANYON byte boyutu bozuk. Beklenen=%d Gelen=%d" % [
				EXPECTED_BYTES,
				raw.size()
			]
		)
		return null

	# This is the authoritative integrity check. Passing it proves we reconstructed
	# exactly the byte sequence accepted by the historical V15 terrain system.
	var hashing: HashingContext = HashingContext.new()
	var hash_start_error: int = hashing.start(HashingContext.HASH_SHA256)
	if hash_start_error != OK:
		push_error("VERIFIED CANYON SHA256 baslatilamadi. Error=%d" % hash_start_error)
		return null

	hashing.update(raw)
	var actual_sha: String = hashing.finish().hex_encode()
	if actual_sha != EXPECTED_SHA256:
		push_error(
			"VERIFIED CANYON SHA256 uyusmuyor. Beklenen=%s Gelen=%s" % [
				EXPECTED_SHA256,
				actual_sha
			]
		)
		return null

	var image: Image = Image.new()
	var decode_error: int = image.load_webp_from_buffer(raw)
	if decode_error != OK or image.is_empty():
		push_error("VERIFIED CANYON WebP decode edilemedi. Error=%d" % decode_error)
		return null

	if image.get_width() != EXPECTED_SOURCE_WIDTH or image.get_height() != EXPECTED_SOURCE_HEIGHT:
		push_error(
			"VERIFIED CANYON boyutu uyusmuyor. Beklenen=%dx%d Gelen=%dx%d" % [
				EXPECTED_SOURCE_WIDTH,
				EXPECTED_SOURCE_HEIGHT,
				image.get_width(),
				image.get_height()
			]
		)
		return null

	print(
		"VERIFIED CANYON OK: %d parca / %d byte / SHA256=OK / %dx%d" % [
			VERIFIED_PART_PATHS.size(),
			raw.size(),
			image.get_width(),
			image.get_height()
		]
	)

	return ImageTexture.create_from_image(image)


static func visible_region(texture: Texture2D) -> Rect2:
	if texture == null:
		return Rect2()

	# V15 was authored and accepted using its complete 965x722 canvas; unlike the
	# broken later transfer it does not need a guessed transparent-row crop.
	return Rect2(0.0, 0.0, float(texture.get_width()), float(texture.get_height()))
