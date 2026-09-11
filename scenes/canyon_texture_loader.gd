@tool
extends RefCounted

# Single source of truth for TinyFisher's verified canyon artwork.
#
# The historical V15 WebP is reconstructed from text chunks and verified by
# exact byte length + SHA-256 before decoding. The verified source is only
# 965x722, which is too small to be stretched across the 12k-wide world at
# gameplay zoom. After verification we therefore build a 4096px-wide HQ display
# texture with Lanczos resampling. This does not change the authoritative source
# data; it only gives Godot enough intermediate pixels to render the canyon
# smoothly at runtime.

const EXPECTED_B64: int = 74540
const EXPECTED_BYTES: int = 55904
const EXPECTED_SOURCE_WIDTH: int = 965
const EXPECTED_SOURCE_HEIGHT: int = 722
const EXPECTED_SHA256: String = "44d51db26db819b7ca6c950bf4cc67b1074a41da859272337ef1a2b2763395f4"

# 4096 is a safe, standard GPU texture width and is ~4.24x the verified source.
# Height is rounded from the original 965:722 aspect ratio.
const HQ_TEXTURE_WIDTH: int = 4096
const HQ_TEXTURE_HEIGHT: int = 3065

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

	# High-quality display rebuild. The verified source remains untouched above;
	# only the decoded in-memory image is resampled for rendering.
	image.resize(HQ_TEXTURE_WIDTH, HQ_TEXTURE_HEIGHT, Image.INTERPOLATE_LANCZOS)
	if image.get_width() != HQ_TEXTURE_WIDTH or image.get_height() != HQ_TEXTURE_HEIGHT:
		push_error("CANYON HQ resize basarisiz.")
		return null

	print(
		"CANYON HQ DISPLAY READY: %dx%d Lanczos" % [
			image.get_width(),
			image.get_height()
		]
	)

	return ImageTexture.create_from_image(image)


static func visible_region(texture: Texture2D) -> Rect2:
	if texture == null:
		return Rect2()

	return Rect2(0.0, 0.0, texture.get_width() + 0.0, texture.get_height() + 0.0)
