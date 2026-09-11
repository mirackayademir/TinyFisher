extends Node

# TinyFisher environment asset 8 / 36 - sun_rays_01.png
# Also bootstraps the independent kelp-cluster compositor so project.godot
# does not need another autoload entry.

const ROOT_NAME := "SunRaysArt"
const LAYER_PATH := "EnvironmentLayers/UnderwaterLayers/SunRaysLayer"
const TEXTURE_PATH := "res://assets/environment/surface/sun_rays_01.png"
const KELP_CLUSTER_SCRIPT := preload("res://scenes/kelp_cluster_runtime.gd")

const WATER_SURFACE_Y := 360.0
const WORLD_LEFT_X := -1000.0
const WORLD_RIGHT_X := 11000.0

const TARGET_HEIGHT := 760.0
const TOP_OVERLAP := 16.0
const TILE_OVERLAP := 70.0
const BASE_ALPHA := 0.16

var _scene_id := 0
var _world: Node2D = null
var _root: Node2D = null
var _kelp_cluster_runtime: Node = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_kelp_cluster_runtime()
	print("SUN RAYS RUNTIME V2: ENVIRONMENT 8/36 + KELP CLUSTER BOOTSTRAP")


func _process(_delta: float) -> void:
	_ensure_kelp_cluster_runtime()
	_ensure_sun_rays()


func _ensure_kelp_cluster_runtime() -> void:
	if is_instance_valid(_kelp_cluster_runtime):
		return

	_kelp_cluster_runtime = KELP_CLUSTER_SCRIPT.new() as Node
	if _kelp_cluster_runtime == null:
		push_warning("Kelp cluster runtime olusturulamadi.")
		return

	_kelp_cluster_runtime.name = "KelpClusterRuntime"
	add_child(_kelp_cluster_runtime)


func _ensure_sun_rays() -> void:
	var scene := get_tree().current_scene
	if scene == null:
		_reset()
		return

	if scene.get_instance_id() != _scene_id:
		_scene_id = scene.get_instance_id()
		_world = scene as Node2D
		_root = null

	if _world == null:
		return

	if is_instance_valid(_root):
		return

	var layer := _world.get_node_or_null(LAYER_PATH) as Node2D
	if layer == null:
		return

	var existing := layer.get_node_or_null(ROOT_NAME) as Node2D
	if existing != null:
		_root = existing
		return

	var texture := load(TEXTURE_PATH) as Texture2D
	if texture == null:
		push_warning("Sun rays texture yuklenemedi: " + TEXTURE_PATH)
		return

	var texture_size := texture.get_size()
	if texture_size.x <= 0.0 or texture_size.y <= 0.0:
		push_warning("Sun rays texture boyutu gecersiz.")
		return

	_root = Node2D.new()
	_root.name = ROOT_NAME
	_root.set_meta("environment_asset_index", 8)
	_root.set_meta("environment_asset_total", 36)
	_root.set_meta("depth_band_m", Vector2(0.0, 22.0))
	layer.add_child(_root)

	var material := _make_ray_material()
	var scale_factor := TARGET_HEIGHT / texture_size.y
	var tile_width := maxf(texture_size.x * scale_factor, 1.0)
	var step_width := maxf(tile_width - TILE_OVERLAP, 1.0)
	var center_y := WATER_SURFACE_Y - TOP_OVERLAP + TARGET_HEIGHT * 0.5
	var x := WORLD_LEFT_X + tile_width * 0.5
	var tile_index := 0

	while x < WORLD_RIGHT_X + tile_width * 0.5:
		var sprite := Sprite2D.new()
		sprite.name = "SunRays_%02d" % tile_index
		sprite.texture = texture
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite.material = material
		sprite.position = Vector2(x, center_y)
		sprite.scale = Vector2(
			-scale_factor if tile_index % 2 == 1 else scale_factor,
			scale_factor
		)
		sprite.modulate = Color(0.86, 0.96, 1.0, 1.0)
		_root.add_child(sprite)

		x += step_width
		tile_index += 1

	print("ENVIRONMENT: 8/36 aktif - sun_rays_01 / tiles=%d" % tile_index)


func _make_ray_material() -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = (
		"shader_type canvas_item;\n"
		+ "render_mode unshaded;\n"
		+ "uniform float base_alpha = 0.16;\n"
		+ "void fragment() {\n"
		+ "    vec4 tex = texture(TEXTURE, UV);\n"
		+ "    float top_soft = smoothstep(0.00, 0.08, UV.y);\n"
		+ "    float bottom_soft = 1.0 - smoothstep(0.70, 1.00, UV.y);\n"
		+ "    float pulse = 0.92 + 0.08 * sin(TIME * 0.65 + UV.x * 8.0);\n"
		+ "    float alpha = tex.a * top_soft * bottom_soft * base_alpha * pulse;\n"
		+ "    COLOR = vec4(tex.rgb, alpha);\n"
		+ "}\n"
	)

	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("base_alpha", BASE_ALPHA)
	return material


func _reset() -> void:
	_scene_id = 0
	_world = null
	_root = null
