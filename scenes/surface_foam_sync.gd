extends Node

# Environment runtime destegi.
# 7/36 surface_foam_01.png: hareketli ana dalgaya baglanir.
# 8/36 sun_rays_01.png: tek, duzenli bir gunes huzmesi kumesi olarak kullanilir.
# 9/36 shallow_rock_01.png: SIMDİLIK ATLANDI / gorunmez.
# 10/36 shallow_fish_school_01_TEMP.png: 0-20m bandinda aralikli arka-plan balik suruleri.
# 11/36 shallow_kelp_01.png: terrain kurulana kadar DURDURULDU / gorunmez.
# TERRAIN FOUNDATION: 20m+ collision'siz fake-3D kara/resif omurgasi.

const FOAM_TEXTURE: Texture2D = preload("res://assets/environment/surface/surface_foam_01.png")
const SUN_RAYS_TEXTURE: Texture2D = preload("res://assets/environment/surface/sun_rays_01.png")
const SHALLOW_FISH_SCHOOL_TEXTURE: Texture2D = preload("res://assets/environment/shallow/shallow_fish_school_01_TEMP.png")

const WATER_SURFACE_Y: float = 360.0
const SUN_X: float = 1060.0
const SUN_TARGET_SIZE: float = 175.0
const SUN_RAYS_WIDTH: float = 1450.0
const SUN_RAYS_DEPTH_HEIGHT: float = 540.0
const FISH_SCHOOL_TARGET_WIDTH: float = 220.0

const TERRAIN_START_Y: float = 1040.0
const TERRAIN_WORLD_LEFT: float = -1000.0
const TERRAIN_WORLD_RIGHT: float = 11000.0

var _bound_line: Line2D = null
var _ray_root: Node2D = null
var _sun_light_parallax: Parallax2D = null
var _fish_school_root: Node2D = null
var _terrain_root: Node2D = null
var _anim_time: float = 0.0
var _scene_id: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	print("ENV RUNTIME: surface + shallow fish + 20m+ fake-3D terrain foundation")


func _process(delta: float) -> void:
	var current_scene: Node = get_tree().current_scene
	if current_scene == null:
		_reset_scene_refs()
		return

	var current_id: int = current_scene.get_instance_id()
	if current_id != _scene_id:
		_scene_id = current_id
		_bound_line = null
		_ray_root = null
		_sun_light_parallax = null
		_fish_school_root = null
		_terrain_root = null
		_anim_time = 0.0

	_sync_surface_foam(current_scene)
	_ensure_sun_light_group(current_scene)
	_ensure_sun_rays(current_scene)
	_remove_skipped_rocks(current_scene)
	_remove_paused_shallow_kelp(current_scene)
	_ensure_shallow_fish_schools(current_scene)
	_ensure_underwater_terrain(current_scene)
	_animate_shallow_environment(delta)


func _reset_scene_refs() -> void:
	_bound_line = null
	_ray_root = null
	_sun_light_parallax = null
	_fish_school_root = null
	_terrain_root = null
	_anim_time = 0.0
	_scene_id = 0


# -----------------------------------------------------------------------------
# 7 / 36 - SURFACE FOAM
# -----------------------------------------------------------------------------

func _sync_surface_foam(current_scene: Node) -> void:
	var static_foam: CanvasItem = current_scene.get_node_or_null(
		"EnvironmentLayers/SurfaceLayers/SurfaceFoamLayer/SurfaceFoamArt"
	) as CanvasItem
	if static_foam != null:
		static_foam.visible = false

	var wave_line: Line2D = current_scene.get_node_or_null("SurfaceWaveFoam") as Line2D
	if wave_line == null:
		_bound_line = null
		return

	if _bound_line == wave_line:
		return

	_bound_line = wave_line
	_apply_foam_texture(_bound_line)


func _apply_foam_texture(line: Line2D) -> void:
	line.texture = FOAM_TEXTURE
	line.texture_mode = Line2D.LINE_TEXTURE_TILE
	line.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	line.width = 9.0
	line.default_color = Color(1.0, 1.0, 1.0, 0.72)
	line.joint_mode = Line2D.LINE_JOINT_ROUND
	line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	line.end_cap_mode = Line2D.LINE_CAP_ROUND
	line.antialiased = false


# -----------------------------------------------------------------------------
# GUNES + 8 / 36 SUN RAYS ORTAK PARALLAX
# -----------------------------------------------------------------------------

func _ensure_sun_light_group(current_scene: Node) -> void:
	var environment_root: Node2D = current_scene.get_node_or_null("EnvironmentLayers") as Node2D
	if environment_root == null:
		return

	_sun_light_parallax = environment_root.get_node_or_null("SunLightParallax") as Parallax2D
	if _sun_light_parallax == null:
		_sun_light_parallax = Parallax2D.new()
		_sun_light_parallax.name = "SunLightParallax"
		_sun_light_parallax.scroll_scale = Vector2(0.08, 1.0)
		environment_root.add_child(_sun_light_parallax)
	else:
		_sun_light_parallax.scroll_scale = Vector2(0.08, 1.0)

	var sun_layer: Node2D = current_scene.get_node_or_null(
		"EnvironmentLayers/SkyParallax/SunLayer"
	) as Node2D
	if sun_layer == null:
		sun_layer = _sun_light_parallax.get_node_or_null("SunLayer") as Node2D
	if sun_layer != null and sun_layer.get_parent() != _sun_light_parallax:
		sun_layer.reparent(_sun_light_parallax, false)

	var rays_layer: Node2D = current_scene.get_node_or_null(
		"EnvironmentLayers/UnderwaterLayers/SunRaysLayer"
	) as Node2D
	if rays_layer == null:
		rays_layer = _sun_light_parallax.get_node_or_null("SunRaysLayer") as Node2D
	if rays_layer != null and rays_layer.get_parent() != _sun_light_parallax:
		rays_layer.reparent(_sun_light_parallax, false)

	_resize_sun()


func _resize_sun() -> void:
	if not is_instance_valid(_sun_light_parallax):
		return

	var sun_sprite: Sprite2D = _sun_light_parallax.get_node_or_null("SunLayer/SunArt") as Sprite2D
	if sun_sprite == null or sun_sprite.texture == null:
		return

	var texture_size: Vector2 = sun_sprite.texture.get_size()
	if texture_size.x <= 0.0 or texture_size.y <= 0.0:
		return

	var fit_scale: float = minf(
		SUN_TARGET_SIZE / texture_size.x,
		SUN_TARGET_SIZE / texture_size.y
	)
	sun_sprite.position = Vector2(SUN_X, 225.0)
	sun_sprite.scale = Vector2.ONE * fit_scale
	sun_sprite.modulate = Color(1.0, 1.0, 1.0, 0.96)


# -----------------------------------------------------------------------------
# 8 / 36 - SUN RAYS
# -----------------------------------------------------------------------------

func _ensure_sun_rays(_current_scene: Node) -> void:
	if is_instance_valid(_ray_root):
		return
	if not is_instance_valid(_sun_light_parallax):
		return

	var rays_layer: Node2D = _sun_light_parallax.get_node_or_null("SunRaysLayer") as Node2D
	if rays_layer == null:
		return

	var existing: Node2D = rays_layer.get_node_or_null("SunRaysArt") as Node2D
	if existing != null:
		_ray_root = existing
		return

	var texture_size: Vector2 = SUN_RAYS_TEXTURE.get_size()
	if texture_size.x <= 0.0 or texture_size.y <= 0.0:
		return

	_ray_root = Node2D.new()
	_ray_root.name = "SunRaysArt"
	rays_layer.add_child(_ray_root)

	var ray_shader: Shader = Shader.new()
	ray_shader.code = (
		"shader_type canvas_item;\n"
		+ "render_mode blend_add;\n"
		+ "uniform float opacity = 0.15;\n"
		+ "void fragment() {\n"
		+ "    vec4 tex = texture(TEXTURE, UV);\n"
		+ "    float top_fade = smoothstep(0.00, 0.10, UV.y);\n"
		+ "    float depth_fade = 1.0 - smoothstep(0.52, 1.00, UV.y);\n"
		+ "    float side_fade = smoothstep(0.00, 0.12, UV.x) * (1.0 - smoothstep(0.88, 1.00, UV.x));\n"
		+ "    COLOR = vec4(tex.rgb, tex.a * top_fade * depth_fade * side_fade * opacity);\n"
		+ "}\n"
	)

	var ray_material: ShaderMaterial = ShaderMaterial.new()
	ray_material.shader = ray_shader

	var ray_sprite: Sprite2D = Sprite2D.new()
	ray_sprite.name = "SunRaysMain"
	ray_sprite.texture = SUN_RAYS_TEXTURE
	ray_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	ray_sprite.material = ray_material
	ray_sprite.position = Vector2(
		SUN_X,
		WATER_SURFACE_Y + 4.0 + SUN_RAYS_DEPTH_HEIGHT * 0.5
	)
	ray_sprite.scale = Vector2(
		SUN_RAYS_WIDTH / texture_size.x,
		SUN_RAYS_DEPTH_HEIGHT / texture_size.y
	)
	_ray_root.add_child(ray_sprite)


# -----------------------------------------------------------------------------
# 9 / 36 - SHALLOW ROCK 01 - SIMDİLIK ATLANDI
# -----------------------------------------------------------------------------

func _remove_skipped_rocks(current_scene: Node) -> void:
	var old_rock: Node = current_scene.get_node_or_null(
		"EnvironmentLayers/UnderwaterLayers/MidDecorLayer/ShallowRock01Art"
	)
	if old_rock != null and not old_rock.is_queued_for_deletion():
		old_rock.queue_free()


# -----------------------------------------------------------------------------
# 11 / 36 - SHALLOW KELP - TERRAIN GELENE KADAR DURDURULDU
# -----------------------------------------------------------------------------

func _remove_paused_shallow_kelp(current_scene: Node) -> void:
	var old_kelp: Node = current_scene.get_node_or_null(
		"EnvironmentLayers/UnderwaterLayers/BackgroundDecorLayer/ShallowKelp11"
	)
	if old_kelp != null and not old_kelp.is_queued_for_deletion():
		old_kelp.queue_free()


# -----------------------------------------------------------------------------
# 10 / 36 - SHALLOW FISH SCHOOL 01 TEMP
# -----------------------------------------------------------------------------

func _ensure_shallow_fish_schools(current_scene: Node) -> void:
	if is_instance_valid(_fish_school_root):
		return

	var decor_layer: Node2D = current_scene.get_node_or_null(
		"EnvironmentLayers/UnderwaterLayers/BackgroundDecorLayer"
	) as Node2D
	if decor_layer == null:
		return

	var old_single: Node = decor_layer.get_node_or_null("ShallowFishSchool01")
	if old_single != null and not old_single.is_queued_for_deletion():
		old_single.queue_free()

	var existing: Node2D = decor_layer.get_node_or_null("ShallowFishSchools10") as Node2D
	if existing != null:
		_fish_school_root = existing
		return

	var texture_size: Vector2 = SHALLOW_FISH_SCHOOL_TEXTURE.get_size()
	if texture_size.x <= 0.0 or texture_size.y <= 0.0:
		return

	var fit_scale: float = FISH_SCHOOL_TARGET_WIDTH / texture_size.x

	_fish_school_root = Node2D.new()
	_fish_school_root.name = "ShallowFishSchools10"
	decor_layer.add_child(_fish_school_root)

	var placements: Array[Vector2] = [
		Vector2(1320.0, 650.0),
		Vector2(1850.0, 520.0),
		Vector2(2380.0, 760.0),
		Vector2(2910.0, 600.0),
		Vector2(3440.0, 900.0),
		Vector2(3970.0, 700.0),
		Vector2(4500.0, 980.0),
		Vector2(5030.0, 560.0),
		Vector2(5560.0, 820.0),
		Vector2(6090.0, 670.0)
	]

	for i: int in range(placements.size()):
		var sprite: Sprite2D = Sprite2D.new()
		sprite.name = "ShallowFishSchool_%02d" % i
		sprite.texture = SHALLOW_FISH_SCHOOL_TEXTURE
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite.position = placements[i]

		var size_variation: float = 0.88 + float(i % 4) * 0.05
		var direction: float = -1.0 if i % 3 == 1 else 1.0
		sprite.scale = Vector2(direction * fit_scale * size_variation, fit_scale * size_variation)
		sprite.modulate = Color(0.78, 0.90, 0.96, 0.42 + float(i % 3) * 0.04)
		sprite.set_meta("origin", placements[i])
		sprite.set_meta("phase", float(i) * 0.83)
		_fish_school_root.add_child(sprite)

	print("SHALLOW FISH SCHOOL: 10/36 0-20m bandina 10 arka-plan surusu yayildi")


func _animate_shallow_environment(delta: float) -> void:
	_anim_time += delta

	if not is_instance_valid(_fish_school_root):
		return

	for child: Node in _fish_school_root.get_children():
		var sprite: Sprite2D = child as Sprite2D
		if sprite == null:
			continue

		var origin: Vector2 = sprite.get_meta("origin", sprite.position)
		var phase: float = float(sprite.get_meta("phase", 0.0))
		sprite.position = origin + Vector2(
			sin(_anim_time * 0.26 + phase) * 24.0,
			sin(_anim_time * 0.51 + phase) * 5.0
		)


# -----------------------------------------------------------------------------
# TERRAIN FOUNDATION - 20m+ COLLISION'SIZ FAKE 3D KARA / RESIF PARCALARI
# -----------------------------------------------------------------------------

func _ensure_underwater_terrain(current_scene: Node) -> void:
	if is_instance_valid(_terrain_root):
		return

	var decor_layer: Node2D = current_scene.get_node_or_null(
		"EnvironmentLayers/UnderwaterLayers/BackgroundDecorLayer"
	) as Node2D
	if decor_layer == null:
		return

	var existing: Node2D = decor_layer.get_node_or_null("UnderwaterTerrainFoundation") as Node2D
	if existing != null:
		_terrain_root = existing
		return

	_terrain_root = Node2D.new()
	_terrain_root.name = "UnderwaterTerrainFoundation"
	_terrain_root.z_index = -1
	decor_layer.add_child(_terrain_root)

	var open_blue: Node2D = Node2D.new()
	open_blue.name = "OpenBlueTerrain_20_50m"
	_terrain_root.add_child(open_blue)

	var deep_sea: Node2D = Node2D.new()
	deep_sea.name = "DeepSeaTerrain_50_80m"
	_terrain_root.add_child(deep_sea)

	var abyss: Node2D = Node2D.new()
	abyss.name = "AbyssTerrain_80_100m"
	_terrain_root.add_child(abyss)

	_build_open_blue_terrain(open_blue)
	_build_deep_sea_terrain(deep_sea)
	_build_abyss_terrain(abyss)

	print("TERRAIN FOUNDATION: 20m-100m collision'siz fake-3D kara parcalari kuruldu")


func _build_open_blue_terrain(parent: Node2D) -> void:
	var top_color: Color = Color(0.30, 0.58, 0.61, 0.90)
	var side_color: Color = Color(0.10, 0.31, 0.39, 0.94)
	var shadow_color: Color = Color(0.035, 0.16, 0.23, 0.55)

	var chunks: Array[Dictionary] = [
		{"x": -180.0, "y": 1140.0, "w": 1500.0, "h": 460.0, "ledge": 70.0, "mirror": false},
		{"x": 1450.0, "y": 1320.0, "w": 1280.0, "h": 410.0, "ledge": 64.0, "mirror": true},
		{"x": 3060.0, "y": 1110.0, "w": 1580.0, "h": 500.0, "ledge": 76.0, "mirror": false},
		{"x": 4850.0, "y": 1390.0, "w": 1380.0, "h": 430.0, "ledge": 68.0, "mirror": true},
		{"x": 6500.0, "y": 1180.0, "w": 1640.0, "h": 500.0, "ledge": 74.0, "mirror": false},
		{"x": 8400.0, "y": 1360.0, "w": 1480.0, "h": 450.0, "ledge": 68.0, "mirror": true},
		{"x": 10100.0, "y": 1160.0, "w": 1720.0, "h": 520.0, "ledge": 78.0, "mirror": false}
	]

	_build_terrain_chunk_list(parent, "open_blue", chunks, top_color, side_color, shadow_color)


func _build_deep_sea_terrain(parent: Node2D) -> void:
	var top_color: Color = Color(0.18, 0.39, 0.45, 0.92)
	var side_color: Color = Color(0.055, 0.19, 0.27, 0.96)
	var shadow_color: Color = Color(0.018, 0.08, 0.14, 0.62)

	var chunks: Array[Dictionary] = [
		{"x": -120.0, "y": 2110.0, "w": 1850.0, "h": 620.0, "ledge": 78.0, "mirror": true},
		{"x": 1900.0, "y": 2390.0, "w": 1500.0, "h": 580.0, "ledge": 72.0, "mirror": false},
		{"x": 3800.0, "y": 2050.0, "w": 1800.0, "h": 650.0, "ledge": 82.0, "mirror": true},
		{"x": 5900.0, "y": 2480.0, "w": 1650.0, "h": 590.0, "ledge": 76.0, "mirror": false},
		{"x": 7900.0, "y": 2150.0, "w": 1880.0, "h": 650.0, "ledge": 84.0, "mirror": true},
		{"x": 10050.0, "y": 2440.0, "w": 1750.0, "h": 620.0, "ledge": 78.0, "mirror": false}
	]

	_build_terrain_chunk_list(parent, "deep_sea", chunks, top_color, side_color, shadow_color)


func _build_abyss_terrain(parent: Node2D) -> void:
	var top_color: Color = Color(0.105, 0.23, 0.30, 0.94)
	var side_color: Color = Color(0.025, 0.085, 0.14, 0.97)
	var shadow_color: Color = Color(0.005, 0.025, 0.055, 0.72)

	var chunks: Array[Dictionary] = [
		{"x": 100.0, "y": 3150.0, "w": 2200.0, "h": 780.0, "ledge": 88.0, "mirror": false},
		{"x": 2700.0, "y": 3480.0, "w": 1850.0, "h": 720.0, "ledge": 82.0, "mirror": true},
		{"x": 5050.0, "y": 3070.0, "w": 2250.0, "h": 800.0, "ledge": 92.0, "mirror": false},
		{"x": 7750.0, "y": 3510.0, "w": 2050.0, "h": 740.0, "ledge": 86.0, "mirror": true},
		{"x": 10200.0, "y": 3130.0, "w": 2300.0, "h": 820.0, "ledge": 94.0, "mirror": false}
	]

	_build_terrain_chunk_list(parent, "abyss", chunks, top_color, side_color, shadow_color)


func _build_terrain_chunk_list(
	parent: Node2D,
	zone_name: String,
	chunks: Array[Dictionary],
	top_color: Color,
	side_color: Color,
	shadow_color: Color
) -> void:
	for i: int in range(chunks.size()):
		var data: Dictionary = chunks[i]
		_add_fake_3d_terrain_chunk(
			parent,
			"%s_chunk_%02d" % [zone_name, i],
			zone_name,
			Vector2(float(data["x"]), maxf(float(data["y"]), TERRAIN_START_Y)),
			float(data["w"]),
			float(data["h"]),
			float(data["ledge"]),
			top_color,
			side_color,
			shadow_color,
			bool(data["mirror"])
		)


func _add_fake_3d_terrain_chunk(
	parent: Node2D,
	chunk_name: String,
	zone_name: String,
	center: Vector2,
	width: float,
	wall_height: float,
	ledge_depth: float,
	top_color: Color,
	side_color: Color,
	shadow_color: Color,
	mirror_profile: bool
) -> void:
	var chunk: Node2D = Node2D.new()
	chunk.name = chunk_name
	chunk.position = center
	chunk.set_meta("terrain_zone", zone_name)
	chunk.set_meta("collisionless", true)
	parent.add_child(chunk)

	var x_factors: Array[float] = [-0.50, -0.39, -0.27, -0.13, 0.02, 0.18, 0.34, 0.50]
	var y_profile: Array[float] = [0.0, -18.0, -9.0, -34.0, -16.0, -30.0, -8.0, 0.0]
	var front_edge: PackedVector2Array = PackedVector2Array()

	for i: int in range(x_factors.size()):
		var profile_index: int = y_profile.size() - 1 - i if mirror_profile else i
		front_edge.append(Vector2(x_factors[i] * width, y_profile[profile_index]))

	var depth_shift: float = ledge_depth * 0.58
	var back_edge: PackedVector2Array = PackedVector2Array()
	for point: Vector2 in front_edge:
		back_edge.append(point + Vector2(depth_shift, -ledge_depth))

	var side_points: PackedVector2Array = PackedVector2Array()
	for point: Vector2 in front_edge:
		side_points.append(point)
	side_points.append(Vector2(width * 0.50, wall_height))
	side_points.append(Vector2(-width * 0.50, wall_height))

	var side: Polygon2D = Polygon2D.new()
	side.name = "CliffFace"
	side.polygon = side_points
	side.color = side_color
	chunk.add_child(side)

	var right_shadow: Polygon2D = Polygon2D.new()
	right_shadow.name = "CliffShadow"
	right_shadow.polygon = PackedVector2Array([
		front_edge[5],
		front_edge[6],
		front_edge[7],
		Vector2(width * 0.50, wall_height),
		Vector2(width * 0.16, wall_height)
	])
	right_shadow.color = shadow_color
	chunk.add_child(right_shadow)

	var top_points: PackedVector2Array = PackedVector2Array()
	for point: Vector2 in back_edge:
		top_points.append(point)
	for i: int in range(front_edge.size() - 1, -1, -1):
		top_points.append(front_edge[i])

	var top_face: Polygon2D = Polygon2D.new()
	top_face.name = "TopSurface"
	top_face.polygon = top_points
	top_face.color = top_color
	chunk.add_child(top_face)

	var back_line: Line2D = Line2D.new()
	back_line.name = "BackRim"
	back_line.points = back_edge
	back_line.width = 3.0
	back_line.default_color = Color(top_color.r * 0.70, top_color.g * 0.78, top_color.b * 0.82, 0.80)
	back_line.antialiased = false
	chunk.add_child(back_line)

	var front_line: Line2D = Line2D.new()
	front_line.name = "FrontRim"
	front_line.points = front_edge
	front_line.width = 4.0
	front_line.default_color = Color(
		minf(1.0, top_color.r + 0.12),
		minf(1.0, top_color.g + 0.12),
		minf(1.0, top_color.b + 0.10),
		0.92
	)
	front_line.antialiased = false
	chunk.add_child(front_line)

	var anchors: Node2D = Node2D.new()
	anchors.name = "DecorAnchors"
	chunk.add_child(anchors)

	var anchor_indices: Array[int] = [1, 3, 5, 6]
	for anchor_i: int in range(anchor_indices.size()):
		var edge_index: int = anchor_indices[anchor_i]
		var marker: Marker2D = Marker2D.new()
		marker.name = "Anchor_%02d" % anchor_i
		marker.position = front_edge[edge_index] + Vector2(depth_shift * 0.42, -ledge_depth * 0.42)
		marker.set_meta("terrain_anchor", true)
		marker.set_meta("terrain_zone", zone_name)
		anchors.add_child(marker)
