extends Node

# TinyFisher 20-100 m tek-parca dunya terrain temeli.
# Bu surum terrain'i kameraya kilitlemez: dogrudan World koordinatlarina oturur.
# 20 m -> 100 m fiziksel bant, mevcut olta olceginde 80 m * 34.5 px = 2760 px.
# Yatayda World/Water rect'i esas alinir: mevcut map -1000 -> 11000 = 12000 px.
# Collision YOK; balik, kanca ve gelecek 36 environment asset terrain'in onunde calisir.

const TERRAIN_NODE_NAME: String = "UnderwaterReefTerrain20To100"
const LAYOUT_VERSION: int = 11

const TERRAIN_TOP_DEPTH_METERS: float = 20.0
const TERRAIN_BOTTOM_DEPTH_METERS: float = 100.0

const FALLBACK_WORLD_LEFT_X: float = -1000.0
const FALLBACK_WORLD_RIGHT_X: float = 11000.0
const REFERENCE_MAP_WIDTH: float = 12000.0
const REFERENCE_BAND_HEIGHT: float = 2760.0

const TERRAIN_Z_INDEX: int = -7

var _scene_id: int = 0
var _world: Node2D = null
var _terrain_root: Node2D = null

var _last_left_x: float = INF
var _last_map_width: float = INF
var _last_top_y: float = INF
var _last_band_height: float = INF


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	print("UNDERWATER TERRAIN V11: WORLD-ANCHORED 20-100m / CAMERA LOCK OFF / COLLISION OFF")


func _process(_delta: float) -> void:
	var current_scene: Node = get_tree().current_scene
	if current_scene == null:
		_reset_refs()
		return

	var current_id: int = current_scene.get_instance_id()
	if current_id != _scene_id:
		_scene_id = current_id
		_world = current_scene as Node2D
		_terrain_root = null
		_last_left_x = INF
		_last_map_width = INF
		_last_top_y = INF
		_last_band_height = INF

	if _world == null:
		return

	_ensure_terrain()
	_sync_terrain_to_world()


func _reset_refs() -> void:
	_scene_id = 0
	_world = null
	_terrain_root = null
	_last_left_x = INF
	_last_map_width = INF
	_last_top_y = INF
	_last_band_height = INF


func _ensure_terrain() -> void:
	if is_instance_valid(_terrain_root):
		return

	_remove_old_terrain()

	_terrain_root = Node2D.new()
	_terrain_root.name = TERRAIN_NODE_NAME
	_terrain_root.z_as_relative = false
	_terrain_root.z_index = TERRAIN_Z_INDEX
	_terrain_root.set_meta("layout_version", LAYOUT_VERSION)
	_terrain_root.set_meta("collisionless", true)
	_terrain_root.set_meta("camera_locked", false)
	_terrain_root.set_meta("depth_top_m", TERRAIN_TOP_DEPTH_METERS)
	_terrain_root.set_meta("depth_bottom_m", TERRAIN_BOTTOM_DEPTH_METERS)
	_world.add_child(_terrain_root)

	var profile: PackedVector2Array = _terrain_profile()

	# Ana kaya kutlesi: kenarlarda erken baslar, merkezde ancak Abyss'e dogru tabana iner.
	# Boylece 20-80 m ortasinda havada duran duz bir "deniz tabani" olusmaz.
	_add_mass_layer(
		"RockMassBase",
		_build_mass_polygon(profile, 0.0),
		Color(0.095, 0.145, 0.225, 0.985),
		0
	)

	# Ic katmanlar ana poligonun tamamen icinde kalir; yeni dekorlarla z-fighting yapmaz.
	_add_mass_layer(
		"RockMassMidShadow",
		_build_mass_polygon(profile, 116.0),
		Color(0.058, 0.094, 0.158, 0.82),
		1
	)
	_add_mass_layer(
		"RockMassDeepShadow",
		_build_mass_polygon(profile, 336.0),
		Color(0.030, 0.050, 0.098, 0.88),
		2
	)

	_add_profile_line(
		"RockRim",
		profile,
		12.0,
		Color(0.235, 0.335, 0.445, 0.96),
		3
	)
	_add_profile_line(
		"RockInnerRim",
		_offset_profile(profile, 88.0),
		7.0,
		Color(0.125, 0.205, 0.305, 0.88),
		3
	)

	_sync_terrain_to_world(true)

	var bounds: Vector2 = _get_world_horizontal_bounds()
	var top_y: float = _world_y_for_depth(TERRAIN_TOP_DEPTH_METERS)
	var bottom_y: float = _world_y_for_depth(TERRAIN_BOTTOM_DEPTH_METERS)
	print(
		"UNDERWATER TERRAIN V11 OK | x=", bounds.x, "..", bounds.y,
		" | width=", bounds.y - bounds.x,
		" | y20=", top_y,
		" | y100=", bottom_y,
		" | height=", bottom_y - top_y,
		" | collision=OFF | camera_lock=OFF"
	)


func _terrain_profile() -> PackedVector2Array:
	# Referans alan: 12000 x 2760 px.
	# Profil, tek bir U-sekilli kara kutlesidir: sol/sag kayalik duvarlar + Abyss tabani.
	# Tum noktalar 4 px grid'e yakin tutuldu; pixel-art katmanlariyla uyumludur.
	return PackedVector2Array([
		Vector2(0.0, 220.0),
		Vector2(360.0, 264.0),
		Vector2(760.0, 360.0),
		Vector2(1200.0, 520.0),
		Vector2(1680.0, 740.0),
		Vector2(2160.0, 1012.0),
		Vector2(2640.0, 1320.0),
		Vector2(3160.0, 1600.0),
		Vector2(3680.0, 1872.0),
		Vector2(4200.0, 2108.0),
		Vector2(4720.0, 2260.0),
		Vector2(5240.0, 2372.0),
		Vector2(5760.0, 2448.0),
		Vector2(6280.0, 2420.0),
		Vector2(6800.0, 2352.0),
		Vector2(7320.0, 2240.0),
		Vector2(7840.0, 2100.0),
		Vector2(8360.0, 1880.0),
		Vector2(8840.0, 1620.0),
		Vector2(9320.0, 1380.0),
		Vector2(9760.0, 1140.0),
		Vector2(10200.0, 920.0),
		Vector2(10600.0, 748.0),
		Vector2(11000.0, 588.0),
		Vector2(11400.0, 428.0),
		Vector2(11720.0, 308.0),
		Vector2(12000.0, 248.0)
	])


func _build_mass_polygon(profile: PackedVector2Array, inset_y: float) -> PackedVector2Array:
	var polygon: PackedVector2Array = PackedVector2Array()
	for point: Vector2 in profile:
		polygon.append(
			Vector2(
				point.x,
				minf(point.y + inset_y, REFERENCE_BAND_HEIGHT - 8.0)
			)
		)

	polygon.append(Vector2(REFERENCE_MAP_WIDTH, REFERENCE_BAND_HEIGHT))
	polygon.append(Vector2(0.0, REFERENCE_BAND_HEIGHT))
	return polygon


func _offset_profile(profile: PackedVector2Array, offset_y: float) -> PackedVector2Array:
	var result: PackedVector2Array = PackedVector2Array()
	for point: Vector2 in profile:
		result.append(
			Vector2(
				point.x,
				minf(point.y + offset_y, REFERENCE_BAND_HEIGHT - 8.0)
			)
		)
	return result


func _add_mass_layer(
	layer_name: String,
	polygon_points: PackedVector2Array,
	layer_color: Color,
	layer_z: int
) -> void:
	var polygon: Polygon2D = Polygon2D.new()
	polygon.name = layer_name
	polygon.polygon = polygon_points
	polygon.color = layer_color
	polygon.z_index = layer_z
	_terrain_root.add_child(polygon)


func _add_profile_line(
	line_name: String,
	line_points: PackedVector2Array,
	line_width: float,
	line_color: Color,
	line_z: int
) -> void:
	var line: Line2D = Line2D.new()
	line.name = line_name
	line.points = line_points
	line.width = line_width
	line.default_color = line_color
	line.z_index = line_z
	line.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_terrain_root.add_child(line)


func _sync_terrain_to_world(force: bool = false) -> void:
	if not is_instance_valid(_terrain_root) or _world == null:
		return

	var bounds: Vector2 = _get_world_horizontal_bounds()
	var left_x: float = bounds.x
	var map_width: float = maxf(bounds.y - bounds.x, 1.0)

	var top_y: float = _world_y_for_depth(TERRAIN_TOP_DEPTH_METERS)
	var bottom_y: float = _world_y_for_depth(TERRAIN_BOTTOM_DEPTH_METERS)
	var band_height: float = maxf(bottom_y - top_y, 1.0)

	if (
		not force
		and is_equal_approx(left_x, _last_left_x)
		and is_equal_approx(map_width, _last_map_width)
		and is_equal_approx(top_y, _last_top_y)
		and is_equal_approx(band_height, _last_band_height)
	):
		return

	# Kritik fark: X kamera konumundan GELMEZ. Terrain mapin kendi dunya koordinatinda kalir.
	_terrain_root.global_position = Vector2(left_x, top_y)
	_terrain_root.scale = Vector2(
		map_width / REFERENCE_MAP_WIDTH,
		band_height / REFERENCE_BAND_HEIGHT
	)

	_terrain_root.set_meta("map_left_x", left_x)
	_terrain_root.set_meta("map_right_x", bounds.y)
	_terrain_root.set_meta("world_y_20m", top_y)
	_terrain_root.set_meta("world_y_100m", bottom_y)

	_last_left_x = left_x
	_last_map_width = map_width
	_last_top_y = top_y
	_last_band_height = band_height


func _get_world_horizontal_bounds() -> Vector2:
	# Map genisligi zaten World/Water rect'inde tanimli; ayni kaynagi kullanarak sabitleri kopyalamiyoruz.
	var water: Control = _world.get_node_or_null("Water") as Control
	if water != null:
		var left_x: float = water.position.x
		var right_x: float = water.position.x + water.size.x
		if right_x - left_x >= 1280.0:
			return Vector2(left_x, right_x)

	return Vector2(FALLBACK_WORLD_LEFT_X, FALLBACK_WORLD_RIGHT_X)


func _pixels_per_meter() -> float:
	var hook: Node2D = _world.get_node_or_null("Boat/Hook") as Node2D
	if hook == null:
		return 34.5

	var max_depth_pixels: float = float(hook.get("max_depth"))
	var max_depth_meters: float = float(hook.get("max_depth_meters"))
	if max_depth_pixels <= 0.0 or max_depth_meters <= 0.0:
		return 34.5

	return max_depth_pixels / max_depth_meters


func _world_y_for_depth(depth_meters: float) -> float:
	var boat: Node2D = _world.get_node_or_null("Boat") as Node2D
	var hook: Node2D = _world.get_node_or_null("Boat/Hook") as Node2D
	if boat == null or hook == null:
		return 392.6 + depth_meters * 34.5

	var hook_start_y: float = hook.position.y
	var start_variant: Variant = hook.get("start_position")
	if start_variant is Vector2:
		hook_start_y = (start_variant as Vector2).y

	return boat.global_position.y + hook_start_y + depth_meters * _pixels_per_meter()


func _remove_old_terrain() -> void:
	# V10 ve daha eski kamera-kilitli terrain kalintilarini tek seferde temizle.
	var old_direct: Node = _world.get_node_or_null(TERRAIN_NODE_NAME)
	if old_direct != null:
		_world.remove_child(old_direct)
		old_direct.queue_free()

	var background_layer: Node = _world.get_node_or_null(
		"EnvironmentLayers/UnderwaterLayers/BackgroundDecorLayer"
	)
	if background_layer != null:
		var old_background: Node = background_layer.get_node_or_null(TERRAIN_NODE_NAME)
		if old_background != null:
			background_layer.remove_child(old_background)
			old_background.queue_free()

		var old_foundation: Node = background_layer.get_node_or_null("UnderwaterTerrainFoundation")
		if old_foundation != null:
			background_layer.remove_child(old_foundation)
			old_foundation.queue_free()
