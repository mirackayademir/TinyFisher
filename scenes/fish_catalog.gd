extends RefCounted

const FishExactArt = preload("res://scenes/fish_exact_art.gd")

# TinyFisher — Fish Catalog V1
# Baliklarin statik verileri icin tek kaynak.
# Yeni bir tur eklerken once buraya profil eklenir; spawn, HUD, balik defteri,
# mucadele ve temel yuzus animasyonu bu profilden beslenir.

const FISH_ORDER: Array[String] = [
	"Sardalya",
	"Levrek",
	"Uskumru",
	"Ton Balığı",
	"Köpekbalığı",
	"Kılıç Balığı",
	"Fener Balığı",
	"Barakuda",
	"Müren",
	"Vatoz",
	"Deniz Şeytanı",
	"Kalamar"
]

const EXPANSION_WAVE_1: Array[String] = [
	"Barakuda",
	"Müren",
	"Vatoz",
	"Deniz Şeytanı",
	"Kalamar"
]

const PROFILES: Dictionary = {
	"Sardalya": {
		"value": 10,
		"habitat": "Sığ su / sürüler",
		"depth_label": "15–20 m (TEST)",
		"texture_path": "res://assets/sardalya.png",
		"behavior_id": "school",
		"target_count": 12,
		"spawn_x": [1250.0, 5250.0],
		"spawn_y": [820.0, 980.0],
		"speed": [68.0, 77.0],
		"distance": [72.0, 118.0],
		"bob": [2.0, 3.2],
		"visual_scale": 0.06,
		"swim_wave_speed": 4.0,
		"swim_wave_angle": 2.5,
		"acceleration": 320.0,
		"vertical_response": 52.0,
		"turn_roll": 5.0,
		"tail_strength": 26.0,
		"tail_speed": 7.0,
		"body_strength": 4.0,
		"collision": [55.0, 24.0],
		"hook_struggle_angle": 18.0,
		"fight": [95.0, 1.0, 36.0, 11.0, 112.0],
		"tension": [8.0, 34.0, 2.0]
	},
	"Levrek": {
		"value": 25,
		"habitat": "Orta sular",
		"depth_label": "15–20 m (TEST)",
		"texture_path": "res://assets/levrek2.png",
		"behavior_id": "curious",
		"target_count": 6,
		"spawn_x": [1250.0, 3900.0],
		"spawn_y": [820.0, 980.0],
		"speed": [48.0, 62.0],
		"distance": [210.0, 380.0],
		"bob": [3.5, 5.0],
		"visual_scale": 0.08,
		"swim_wave_speed": 3.3,
		"swim_wave_angle": 3.0,
		"acceleration": 235.0,
		"vertical_response": 46.0,
		"turn_roll": 6.0,
		"tail_strength": 24.0,
		"tail_speed": 5.8,
		"body_strength": 4.0,
		"collision": [68.0, 30.0],
		"hook_struggle_angle": 18.0,
		"fight": [145.0, 0.70, 31.0, 17.0, 92.0],
		"tension": [14.0, 30.0, 4.0]
	},
	"Uskumru": {
		"value": 40,
		"habitat": "Açık deniz",
		"depth_label": "15–20 m (TEST)",
		"texture_path": "res://assets/uskumru.png",
		"behavior_id": "burst",
		"target_count": 6,
		"spawn_x": [2200.0, 5350.0],
		"spawn_y": [820.0, 980.0],
		"speed": [78.0, 98.0],
		"distance": [270.0, 480.0],
		"bob": [4.0, 5.5],
		"visual_scale": 0.09,
		"swim_wave_speed": 4.8,
		"swim_wave_angle": 4.0,
		"acceleration": 390.0,
		"vertical_response": 68.0,
		"turn_roll": 8.0,
		"tail_strength": 30.0,
		"tail_speed": 8.2,
		"body_strength": 4.5,
		"collision": [76.0, 30.0],
		"hook_struggle_angle": 18.0,
		"fight": [205.0, 0.46, 26.0, 23.0, 76.0],
		"tension": [20.0, 27.0, 6.0]
	},
	"Ton Balığı": {
		"value": 75,
		"habitat": "Derin açık deniz",
		"depth_label": "15–20 m (TEST)",
		"texture_path": "res://assets/tonbaligi.png",
		"behavior_id": "surge",
		"target_count": 4,
		"spawn_x": [3400.0, 6500.0],
		"spawn_y": [820.0, 980.0],
		"speed": [40.0, 54.0],
		"distance": [330.0, 560.0],
		"bob": [5.0, 7.0],
		"visual_scale": 0.12,
		"swim_wave_speed": 2.4,
		"swim_wave_angle": 2.0,
		"acceleration": 170.0,
		"vertical_response": 38.0,
		"turn_roll": 5.0,
		"tail_strength": 24.0,
		"tail_speed": 4.8,
		"body_strength": 3.8,
		"collision": [95.0, 38.0],
		"hook_struggle_angle": 18.0,
		"fight": [265.0, 0.32, 22.0, 29.0, 64.0],
		"tension": [25.0, 25.0, 8.0]
	},
	"Köpekbalığı": {
		"value": 240,
		"habitat": "Açık deniz avcısı",
		"depth_label": "15–20 m (TEST)",
		"texture_path": "res://generation/fish/kopek_baligi.webp",
		"behavior_id": "predator",
		"target_count": 2,
		"spawn_x": [1200.0, 2300.0],
		"spawn_y": [820.0, 980.0],
		"speed": [46.0, 60.0],
		"distance": [300.0, 520.0],
		"bob": [5.0, 8.0],
		"visual_scale": 0.62,
		"swim_wave_speed": 1.9,
		"swim_wave_angle": 1.5,
		"acceleration": 125.0,
		"vertical_response": 30.0,
		"turn_roll": 8.0,
		"tail_strength": 18.0,
		"tail_speed": 4.2,
		"body_strength": 2.5,
		"collision": [195.0, 72.0],
		"hook_struggle_angle": 12.0,
		"fight": [280.0, 0.32, 20.0, 31.0, 58.0],
		"tension": [32.0, 22.0, 12.0]
	},
	"Kılıç Balığı": {
		"value": 220,
		"habitat": "Açık deniz / hızlı avcı",
		"depth_label": "15–20 m (TEST)",
		"texture_path": "res://generation/fish/kilic_baligi.webp",
		"behavior_id": "swordfish",
		"target_count": 1,
		# TEST: Kullanici F5'te hemen gorebilsin diye limanin saginda, yuzeye yakin dogar.
		"spawn_x": [650.0, 760.0],
		"spawn_y": [600.0, 690.0],
		"speed": [48.0, 64.0],
		"distance": [170.0, 230.0],
		"bob": [4.0, 6.5],
		"visual_scale": 0.68,
		"swim_wave_speed": 5.0,
		"swim_wave_angle": 0.35,
		"acceleration": 520.0,
		"vertical_response": 72.0,
		"turn_roll": 3.0,
		"tail_strength": 16.0,
		"tail_speed": 8.5,
		"body_strength": 1.1,
		"collision": [160.0, 50.0],
		"hook_struggle_angle": 14.0,
		"fight": [315.0, 0.28, 19.0, 33.0, 56.0],
		"tension": [31.0, 22.0, 12.0],
		"asset_status": "animated_user_art_harbor_test"
	},

	"Fener Balığı": {
		"value": 320,
		"habitat": "Karanlık derinlik / pusu avcısı",
		"depth_label": "15–20 m (TEST)",
		"texture_path": "res://generation/fish/fener_baligi_yeni.webp",
		"behavior_id": "hover",
		"target_count": 1,
		# TEST: yeni görseli F5'te hemen görebilmek için limanın yakınında doğar.
		"spawn_x": [790.0, 900.0],
		"spawn_y": [650.0, 760.0],
		"speed": [16.0, 22.0],
		"distance": [95.0, 145.0],
		"bob": [9.0, 14.0],
		"visual_scale": 0.56,
		"swim_wave_speed": 1.55,
		"swim_wave_angle": 2.2,
		"acceleration": 82.0,
		"vertical_response": 22.0,
		"turn_roll": 5.0,
		"tail_strength": 11.0,
		"tail_speed": 3.4,
		"body_strength": 2.5,
		"collision": [118.0, 82.0],
		"hook_struggle_angle": 15.0,
		"fight": [190.0, 0.48, 18.0, 32.0, 55.0],
		"tension": [32.0, 21.0, 11.5],
		"asset_status": "new_generated_art_harbor_test"
	},
	"Barakuda": {
		"value": 160,
		"habitat": "Açık deniz / avcı",
		"depth_label": "15–20 m (TEST)",
		"texture_path": "res://generation/fish/barakuda.webp",
		"behavior_id": "hunter",
		"target_count": 1,
		"spawn_x": [600.0, 650.0],
		"spawn_y": [820.0, 980.0],
		"speed": [22.0, 28.0],
		"distance": [40.0, 65.0],
		"bob": [4.0, 7.0],
		"visual_scale": 1.12,
		"swim_wave_speed": 2.2,
		"swim_wave_angle": 0.35,
		"acceleration": 220.0,
		"vertical_response": 38.0,
		"turn_roll": 2.0,
		"tail_strength": 0.0,
		"tail_speed": 4.0,
		"body_strength": 0.0,
		"collision": [125.0, 36.0],
		"hook_struggle_angle": 12.0,
		"fight": [295.0, 0.30, 20.0, 31.0, 60.0],
		"tension": [28.0, 24.0, 9.5],
		"asset_status": "exact_user_art_test"
	},
	"Müren": {
		"value": 115,
		"habitat": "Kanyon duvarları / kaya oyukları",
		"depth_label": "15–20 m (TEST)",
		"texture_path": "res://generation/fish/muren.webp",
		"behavior_id": "ambush",
		"target_count": 1,
		"spawn_x": [900.0, 950.0],
		"spawn_y": [820.0, 980.0],
		"speed": [14.0, 20.0],
		"distance": [30.0, 50.0],
		"bob": [2.0, 4.0],
		"visual_scale": 1.18,
		"swim_wave_speed": 1.8,
		"swim_wave_angle": 0.30,
		"acceleration": 180.0,
		"vertical_response": 28.0,
		"turn_roll": 2.0,
		"tail_strength": 0.0,
		"tail_speed": 3.0,
		"body_strength": 0.0,
		"collision": [130.0, 34.0],
		"hook_struggle_angle": 12.0,
		"fight": [235.0, 0.38, 21.0, 29.0, 62.0],
		"tension": [27.0, 23.0, 10.0],
		"asset_status": "exact_user_art_test"
	},
	"Vatoz": {
		"value": 140,
		"habitat": "Kumluk dip / kanyon tabanı",
		"depth_label": "15–20 m (TEST)",
		"texture_path": "res://generation/fish/vatoz.webp",
		"behavior_id": "glide",
		"target_count": 1,
		"spawn_x": [800.0, 850.0],
		"spawn_y": [820.0, 980.0],
		"speed": [14.0, 20.0],
		"distance": [30.0, 50.0],
		"bob": [5.0, 8.0],
		"visual_scale": 1.18,
		"swim_wave_speed": 1.2,
		"swim_wave_angle": 0.20,
		"acceleration": 90.0,
		"vertical_response": 20.0,
		"turn_roll": 1.5,
		"tail_strength": 0.0,
		"tail_speed": 2.0,
		"body_strength": 0.0,
		"collision": [130.0, 68.0],
		"hook_struggle_angle": 8.0,
		"fight": [185.0, 0.52, 20.0, 27.0, 70.0],
		"tension": [24.0, 27.0, 8.0],
		"asset_status": "exact_user_art_test"
	},
	"Deniz Şeytanı": {
		"value": 360,
		"habitat": "Karanlık kanyon / dip avcısı",
		"depth_label": "15–20 m (TEST)",
		"texture_path": "res://generation/fish/deniz_seytani.webp",
		"behavior_id": "lurker",
		"target_count": 1,
		"spawn_x": [1000.0, 1050.0],
		"spawn_y": [820.0, 980.0],
		"speed": [10.0, 16.0],
		"distance": [25.0, 45.0],
		"bob": [5.0, 9.0],
		"visual_scale": 1.12,
		"swim_wave_speed": 1.1,
		"swim_wave_angle": 0.20,
		"acceleration": 75.0,
		"vertical_response": 18.0,
		"turn_roll": 1.5,
		"tail_strength": 0.0,
		"tail_speed": 2.0,
		"body_strength": 0.0,
		"collision": [120.0, 72.0],
		"hook_struggle_angle": 10.0,
		"fight": [205.0, 0.44, 16.0, 36.0, 52.0],
		"tension": [34.0, 20.0, 13.5],
		"asset_status": "exact_user_art_test"
	},
	"Kalamar": {
		"value": 205,
		"habitat": "Derin açık su / kanyon ağzı",
		"depth_label": "15–20 m (TEST)",
		"texture_path": "res://generation/fish/kalamar.webp",
		"behavior_id": "jet",
		"target_count": 1,
		"spawn_x": [700.0, 750.0],
		"spawn_y": [820.0, 980.0],
		"speed": [16.0, 22.0],
		"distance": [30.0, 50.0],
		"bob": [6.0, 10.0],
		"visual_scale": 1.16,
		"swim_wave_speed": 1.5,
		"swim_wave_angle": 0.25,
		"acceleration": 180.0,
		"vertical_response": 30.0,
		"turn_roll": 2.0,
		"tail_strength": 0.0,
		"tail_speed": 3.0,
		"body_strength": 0.0,
		"collision": [120.0, 66.0],
		"hook_struggle_angle": 10.0,
		"fight": [255.0, 0.34, 18.0, 33.0, 58.0],
		"tension": [31.0, 22.0, 11.5],
		"asset_status": "exact_user_art_test"
	}

}


static func is_wave_1_species(fish_type: String) -> bool:
	return fish_type in EXPANSION_WAVE_1


static func is_asset_ready(fish_type: String) -> bool:
	return get_texture(fish_type) != null


static func get_profile(fish_type: String) -> Dictionary:
	var profile: Variant = PROFILES.get(fish_type)
	if profile is Dictionary:
		return profile
	return PROFILES["Sardalya"]


static func get_value(fish_type: String) -> int:
	return int(get_profile(fish_type).get("value", 0))


static func get_habitat(fish_type: String) -> String:
	return String(get_profile(fish_type).get("habitat", "Bilinmiyor"))


static func get_depth_label(fish_type: String) -> String:
	return String(get_profile(fish_type).get("depth_label", "???"))


static func get_behavior_id(fish_type: String) -> String:
	return String(get_profile(fish_type).get("behavior_id", "school"))


static func get_target_count(fish_type: String) -> int:
	return int(get_profile(fish_type).get("target_count", 0))


static func get_texture(fish_type: String) -> Texture2D:
	# Yeni 5 tur icin kullanicinin onayladigi birebir raster sanatini,
	# Godot importer'a bagimli olmadan base64 parcalarindan kur.
	if FishExactArt.has_fish(fish_type):
		var exact_texture: Texture2D = FishExactArt.get_texture(fish_type)
		if exact_texture != null:
			return exact_texture

	var texture_path: String = String(get_profile(fish_type).get("texture_path", ""))
	if texture_path.is_empty():
		push_error("FISH TEXTURE: empty texture path for " + fish_type)
		return null

	# Normal Godot import yolu. Proje icinde .godot/imported hazirsa en hizli yol budur.
	if ResourceLoader.exists(texture_path):
		var resource: Resource = ResourceLoader.load(texture_path)
		var imported_texture: Texture2D = resource as Texture2D
		if imported_texture != null:
			return imported_texture

	# Git pull sonrasi Godot henuz PNG'yi import etmediyse kaynak dosyayi
	# dogrudan decode et. Boylece yeni baliklar Sardalya fallback'ine dusmez.
	var absolute_path: String = ProjectSettings.globalize_path(texture_path)
	if not FileAccess.file_exists(absolute_path):
		push_error("FISH TEXTURE FILE NOT FOUND: " + fish_type + " -> " + texture_path)
		return null

	var image: Image = Image.new()
	var load_error: Error = OK

	if texture_path.get_extension().to_lower() == "svg":
		var svg_file: FileAccess = FileAccess.open(absolute_path, FileAccess.READ)
		if svg_file == null:
			push_error("FISH SVG OPEN FAILED: " + fish_type + " -> " + texture_path)
			return null
		var svg_source: String = svg_file.get_as_text()
		load_error = image.load_svg_from_string(svg_source, 1.0)
	else:
		load_error = image.load(absolute_path)

	if load_error != OK or image.is_empty():
		push_error(
			"FISH TEXTURE DECODE FAILED: %s -> %s (%s)" % [
				fish_type,
				texture_path,
				error_string(load_error)
			]
		)
		return null

	print(
		"FISH TEXTURE DIRECT LOAD OK: %s -> %s [%dx%d]" % [
			fish_type,
			texture_path,
			image.get_width(),
			image.get_height()
		]
	)
	return ImageTexture.create_from_image(image)


static func random_profile_range(fish_type: String, key: String, fallback: float = 0.0) -> float:
	var values: Variant = get_profile(fish_type).get(key)
	if not (values is Array) or values.size() < 2:
		return fallback
	return randf_range(float(values[0]), float(values[1]))


static func get_spawn_position(fish_type: String) -> Vector2:
	return Vector2(
		random_profile_range(fish_type, "spawn_x"),
		random_profile_range(fish_type, "spawn_y")
	)


static func get_collision_size(fish_type: String) -> Vector2:
	var values: Variant = get_profile(fish_type).get("collision", [55.0, 24.0])
	if values is Array and values.size() >= 2:
		return Vector2(float(values[0]), float(values[1]))
	return Vector2(55.0, 24.0)


static func get_fight_profile(fish_type: String) -> Array:
	var values: Variant = get_profile(fish_type).get("fight", [125.0, 0.8, 30.0, 18.0, 88.0])
	return values as Array


static func get_tension_profile(fish_type: String) -> Array:
	var values: Variant = get_profile(fish_type).get("tension", [14.0, 30.0, 4.0])
	return values as Array


static func create_inventory_state() -> Dictionary:
	var result: Dictionary = {}
	for fish_type: String in FISH_ORDER:
		result[fish_type] = 0
	return result


static func create_discovery_state() -> Dictionary:
	var result: Dictionary = {}
	for fish_type: String in FISH_ORDER:
		result[fish_type] = false
	return result
