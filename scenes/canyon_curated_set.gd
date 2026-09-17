extends Node

# TinyFisher — Canyon Curated Set v1
# First POI pass for the locked HQ canyon (20-180 m).
# Uses only three curated props and keeps the canyon itself untouched.

const ROOT_NAME: String = "CanyonCuratedSetV1"
const LAYOUT_VERSION: int = 1
const WORLD_PIXELS_PER_METER: float = 34.5
const MAP_WIDTH_PX: float = 5500.0
const FALLBACK_LEFT: float = -1000.0
const FALLBACK_RIGHT: float = 4500.0
const FALLBACK_ZERO_Y: float = 392.6

const ANCHOR_TEXTURE: String = "res://assets/environment/abyss/abyss_anchor_01.png"
const CHAIN_TEXTURE: String = "res://assets/environment/deep_sea/deep_sea_chain_01_TEMP.png"
const WRECK_TEXTURE: String = "res://assets/environment/deep_sea/deep_sea_wreck_01.png"

var _scene_id: int = 0
var _world: Node2D = null
var _root: Node2D = null
var _style_material: ShaderMaterial = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_style_material = _build_style_material()
	print("CANYON CURATED SET V1: anchor + chain + small wreck")


func _process(_delta: float) -> void:
	var scene: Node = get_tree().current_scene
	if scene == null:
		_reset_scene_state()
		return

	if scene.get_instance_id() != _scene_id:
		_scene_id = scene.get_instance_id()
		_world = scene as Node2D
		_root = null

	if _world == null:
		return

	_ensure_curated_set()


func _reset_scene_state() -> void:
	_scene_id = 0
	_world = null
	_root = null


func _ensure_curated_set() -> void:
	if is_instance_valid(_root):
		return

	var underwater_layers: Node = _world.get_node_or_null("EnvironmentLayers/UnderwaterLayers")
	if underwater_layers == null:
		return

	var landmark_layer: Node2D = underwater_layers.get_node_or_null("LandmarkDecorLayer") as Node2D
	var mid_layer: Node2D = underwater_layers.get_node_or_null("MidDecorLayer") as Node2D
	if landmark_layer == null or mid_layer == null:
		return

	_remove_old_curated_set()

	_root = Node2D.new()
	_root.name = ROOT_NAME
	_root.set_meta("layout_version", LAYOUT_VERSION)
	_root.set_meta("canyon_locked", true)
	_root.set_meta("curated_assets", PackedStringArray(["anchor", "chain", "small_wreck"]))
	landmark_layer.add_child(_root)

	var bounds: Vector2 = _get_world_horizontal_bounds()
	var width: float = maxf(bounds.y - bounds.x, 1.0)

	# POI 1 — 45-65 m: small wreck + half-buried anchor.
	var wreck_x: float = bounds.x + width * 0.33
	var wreck_y: float = _world_y_for_depth(58.0)
	_add_prop(
		_root,
		"CuratedSmallWreck_58m",
		WRECK_TEXTURE,
		Vector2(wreck_x, wreck_y),
		420.0,
		deg_to_rad(-7.0),
		0.88
	)

	var anchor_x: float = bounds.x + width * 0.405
	var anchor_y: float = _world_y_for_depth(55.0)
	_add_prop(
		_root,
		"CuratedAnchor_55m",
		ANCHOR_TEXTURE,
		Vector2(anchor_x, anchor_y),
		190.0,
		deg_to_rad(13.0),
		0.92
	)

	# POI 2 — 85-105 m: lone old chain hinting at something deeper.
	var chain_root: Node2D = Node2D.new()
	chain_root.name = "CuratedChainPOI_96m"
	mid_layer.add_child(chain_root)
	var chain_x: float = bounds.x + width * 0.68
	var chain_y: float = _world_y_for_depth(96.0)
	_add_prop(
		chain_root,
		"CuratedOldChain_96m",
		CHAIN_TEXTURE,
		Vector2(chain_x, chain_y),
		300.0,
		deg_to_rad(-18.0),
		0.82
	)
	_root.set_meta("chain_runtime_path", chain_root.get_path())

	print(
		"CANYON CURATED SET READY: wreck=58m anchor=55m chain=96m / bounds=",
		bounds.x, "..", bounds.y
	)


func _add_prop(
	parent: Node2D,
	node_name: String,
	texture_path: String,
	world_position: Vector2,
	target_long_side_px: float,
	rotation_radians: float,
	alpha: float
) -> Sprite2D:
	var texture: Texture2D = load(texture_path) as Texture2D
	if texture == null:
		push_warning("Canyon curated asset missing: " + texture_path)
		return null

	var texture_size: Vector2 = texture.get_size()
	var long_side: float = maxf(texture_size.x, texture_size.y)
	if long_side <= 0.0:
		return null

	var sprite: Sprite2D = Sprite2D.new()
	sprite.name = node_name
	sprite.texture = texture
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	sprite.global_position = world_position
	sprite.rotation = rotation_radians
	sprite.scale = Vector2.ONE * (target_long_side_px / long_side)
	sprite.modulate = Color(1.0, 1.0, 1.0, alpha)
	sprite.material = _style_material
	sprite.set_meta("canyon_curated", true)
	sprite.set_meta("source_texture", texture_path)
	parent.add_child(sprite)
	return sprite


func _build_style_material() -> ShaderMaterial:
	var shader: Shader = Shader.new()
	shader.code = (
		"shader_type canvas_item;\n"
		+ "uniform float saturation = 0.78;\n"
		+ "uniform float brightness = 0.92;\n"
		+ "uniform vec3 tint = vec3(0.88, 0.95, 1.00);\n"
		+ "void fragment() {\n"
		+ "    vec4 tex = texture(TEXTURE, UV);\n"
		+ "    float luma = dot(tex.rgb, vec3(0.299, 0.587, 0.114));\n"
		+ "    vec3 rgb = mix(vec3(luma), tex.rgb, saturation);\n"
		+ "    rgb *= tint * brightness;\n"
		+ "    COLOR = vec4(rgb, tex.a);\n"
		+ "}\n"
	)

	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = shader
	return material


func _get_world_horizontal_bounds() -> Vector2:
	if _world != null:
		var water: Control = _world.get_node_or_null("Water") as Control
		if water != null:
			var left: float = water.position.x
			var water_right: float = water.position.x + water.size.x
			var right: float = minf(water_right, left + MAP_WIDTH_PX)
			if right - left >= 1280.0:
				return Vector2(left, right)
	return Vector2(FALLBACK_LEFT, FALLBACK_RIGHT)


func _world_y_for_depth(depth_meters: float) -> float:
	if _world == null:
		return FALLBACK_ZERO_Y + depth_meters * WORLD_PIXELS_PER_METER

	var boat: Node2D = _world.get_node_or_null("Boat") as Node2D
	var hook: Node2D = _world.get_node_or_null("Boat/Hook") as Node2D
	if boat == null or hook == null:
		return FALLBACK_ZERO_Y + depth_meters * WORLD_PIXELS_PER_METER

	var hook_start_y: float = hook.position.y
	var start_variant: Variant = hook.get("start_position")
	if start_variant is Vector2:
		hook_start_y = (start_variant as Vector2).y

	return boat.global_position.y + hook_start_y + depth_meters * WORLD_PIXELS_PER_METER


func _remove_old_curated_set() -> void:
	if _world == null:
		return

	var old_root: Node = _world.get_node_or_null("EnvironmentLayers/UnderwaterLayers/LandmarkDecorLayer/" + ROOT_NAME)
	if old_root != null:
		old_root.queue_free()

	var old_chain: Node = _world.get_node_or_null("EnvironmentLayers/UnderwaterLayers/MidDecorLayer/CuratedChainPOI_96m")
	if old_chain != null:
		old_chain.queue_free()
