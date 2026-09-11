@tool
extends RefCounted

# TinyFisher final canyon source.
# The old 965x722 V15 reconstruction is retired from the active path.
# Runtime/editor now load one transparent HQ PNG directly so no decode/upscale
# chain can silently destroy the visual quality.

const FINAL_CANYON_PATH: String = "res://assets/environment/terrain/canyon_final_hq_transparent.png"
const TARGET_WIDTH: int = 4096
const TARGET_HEIGHT: int = 4286
const MIN_ACCEPTABLE_WIDTH: int = 3000


static func build_texture() -> Texture2D:
	if not ResourceLoader.exists(FINAL_CANYON_PATH):
		push_error(
			"FINAL CANYON asset eksik: %s\n4096x4286 transparent PNG bu yola konmali." % FINAL_CANYON_PATH
		)
		return null

	var texture: Texture2D = load(FINAL_CANYON_PATH) as Texture2D
	if texture == null:
		push_error("FINAL CANYON texture yuklenemedi: " + FINAL_CANYON_PATH)
		return null

	var image: Image = texture.get_image()
	if image == null or image.is_empty():
		push_error("FINAL CANYON image okunamadi.")
		return null

	var width: int = image.get_width()
	var height: int = image.get_height()
	if width < MIN_ACCEPTABLE_WIDTH:
		push_warning(
			"FINAL CANYON beklenenden dusuk cozumurlukte: %dx%d. Hedef=%dx%d" % [
				width, height, TARGET_WIDTH, TARGET_HEIGHT
			]
		)

	var used_rect: Rect2i = image.get_used_rect()
	if used_rect.size.x <= 0 or used_rect.size.y <= 0:
		push_error("FINAL CANYON alpha alani bos.")
		return null

	print(
		"FINAL CANYON HQ READY: %dx%d / alpha_used=%dx%d / direct PNG / no runtime upscale" % [
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
