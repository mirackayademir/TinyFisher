@tool
extends RefCounted

# TinyFisher canyon texture loader.
#
# Priority:
# 1) Lossless single-file HQ PNG inside the project.
# 2) Single-file HQ WebP inside the project.
# 3) In the editor only, recover the approved source from common Windows folders,
#    save it into the project as canyon_hq.png and use it immediately.
# 4) Historical SHA-256 verified V15 canyon only as an emergency fallback.

const HQ_PNG_PATH: String = "res://assets/environment/terrain/canyon_hq.png"
const HQ_WEBP_PATH: String = "res://assets/environment/terrain/canyon_hq.webp"
const HQ_EXPECTED_WIDTH: int = 1226
const HQ_EXPECTED_HEIGHT: int = 1283

const APPROVED_SOURCE_FILENAMES: Array[String] = [
	"Codex Görseli 12 Eyl 2026 18_35_49(2).png",
	"Codex Görseli 12 Eyl 2026 18_35_49.png",
	"canyon_hq.png",
	"canyon_hq.webp"
]

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

	if Engine.is_editor_hint():
		hq_texture = _recover_hq_asset_from_common_folders()
		if hq_texture != null:
			return hq_texture

	push_warning(
		"HQ canyon source projede veya ortak klasorlerde bulunamadi; "
		+ "SHA-256 ile dogrulanmis V15 emergency fallback kullaniliyor."
	)

	var fallback_texture: Texture2D = _build_verified_fallback_texture()
	if fallback_texture != null:
		return fallback_texture

	push_error("CANYON yuklenemedi: HQ asset ve verified fallback kullanilamiyor.")
	return null


static func _load_hq_asset() -> Texture2D:
	var png_texture: Texture2D = _load_hq_path(HQ_PNG_PATH)
	if png_texture != null:
		print("HQ CANYON SOURCE: lossless PNG")
		return png_texture

	var webp_texture: Texture2D = _load_hq_path(HQ_WEBP_PATH)
	if webp_texture != null:
		print("HQ CANYON SOURCE: WebP")
		return webp_texture

	return null


static func _load_hq_path(resource_path: String) -> Texture2D:
	# First prefer Godot's imported texture when available.
	if ResourceLoader.exists(resource_path):
		var resource: Resource = ResourceLoader.load(resource_path)
		var imported_texture: Texture2D = resource as Texture2D
		if imported_texture != null:
			var imported_image: Image = imported_texture.get_image()
			if _validate_hq_image(imported_image, resource_path):
				_print_hq_ok(imported_image, resource_path)
				return imported_texture

	# Newly copied files can exist before the editor finishes importing them.
	# Decode the source file directly so the preview does not have to wait.
	var absolute_path: String = ProjectSettings.globalize_path(resource_path)
	if not FileAccess.file_exists(absolute_path):
		return null

	var image: Image = Image.new()
	var load_error: Error = image.load(absolute_path)
	if load_error != OK:
		push_warning("HQ canyon dosyasi decode edilemedi: %s (%s)" % [resource_path, error_string(load_error)])
		return null

	if not _validate_hq_image(image, resource_path):
		return null

	_print_hq_ok(image, resource_path)
	return ImageTexture.create_from_image(image)


static func _recover_hq_asset_from_common_folders() -> Texture2D:
	var search_roots: Array[String] = [
		OS.get_system_dir(OS.SYSTEM_DIR_DOWNLOADS),
		OS.get_system_dir(OS.SYSTEM_DIR_DESKTOP),
		OS.get_system_dir(OS.SYSTEM_DIR_PICTURES),
		OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS)
	]

	for root: String in search_roots:
		if root.is_empty() or not DirAccess.dir_exists_absolute(root):
			continue

		for file_name: String in APPROVED_SOURCE_FILENAMES:
			var source_path: String = _find_named_file(root, file_name, 2)
			if source_path.is_empty():
				continue

			var image: Image = Image.new()
			var load_error: Error = image.load(source_path)
			if load_error != OK:
				continue
			if not _validate_hq_image(image, source_path):
				continue

			var destination_absolute: String = ProjectSettings.globalize_path(HQ_PNG_PATH)
			var save_error: Error = image.save_png(destination_absolute)
			if save_error != OK:
				push_warning(
					"HQ canyon bulundu fakat proje icine kaydedilemedi: %s" % error_string(save_error)
				)
			else:
				print("HQ CANYON AUTO-RECOVERED: %s -> %s" % [source_path, HQ_PNG_PATH])

			_print_hq_ok(image, source_path)
			return ImageTexture.create_from_image(image)

	return null


static func _find_named_file(base_dir: String, file_name: String, remaining_depth: int) -> String:
	var direct_path: String = base_dir.path_join(file_name)
	if FileAccess.file_exists(direct_path):
		return direct_path

	if remaining_depth <= 0:
		return ""

	var dir: DirAccess = DirAccess.open(base_dir)
	if dir == null:
		return ""

	dir.list_dir_begin()
	var entry: String = dir.get_next()
	while not entry.is_empty():
		if dir.current_is_dir() and entry != "." and entry != ".." and not entry.begins_with("."):
			var child_dir: String = base_dir.path_join(entry)
			var found: String = _find_named_file(child_dir, file_name, remaining_depth - 1)
			if not found.is_empty():
				dir.list_dir_end()
				return found
		entry = dir.get_next()
	dir.list_dir_end()
	return ""


static func _validate_hq_image(image: Image, source_label: String) -> bool:
	if image == null or image.is_empty():
		return false

	if image.get_width() != HQ_EXPECTED_WIDTH or image.get_height() != HQ_EXPECTED_HEIGHT:
		push_warning(
			"HQ canyon boyutu uyusmuyor: %s got=%dx%d expected=%dx%d" % [
				source_label,
				image.get_width(),
				image.get_height(),
				HQ_EXPECTED_WIDTH,
				HQ_EXPECTED_HEIGHT
			]
		)
		return false

	if image.detect_alpha() == Image.ALPHA_NONE:
		push_warning("HQ canyon alpha kanali yok: " + source_label)
		return false

	var used_rect: Rect2i = image.get_used_rect()
	if used_rect.size.x <= 0 or used_rect.size.y <= 0:
		push_warning("HQ canyon gorunur alpha alani bos: " + source_label)
		return false

	return true


static func _print_hq_ok(image: Image, source_label: String) -> void:
	var used_rect: Rect2i = image.get_used_rect()
	print(
		"HQ CANYON ASSET OK: %dx%d RGBA / alpha_used=%dx%d / source=%s" % [
			image.get_width(),
			image.get_height(),
			used_rect.size.x,
			used_rect.size.y,
			source_label
		]
	)


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
