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
	"Kılıç Balığı",
	"Köpekbalığı",
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
		"depth_label": "8–12 m",
		"texture_path": "res://assets/sardalya.png",
		"behavior_id": "school",
		"target_count": 12,
		"spawn_x": [1250.0, 5250.0],
		"spawn_y": [610.0, 730.0],
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
		"depth_label": "15–25 m",
		"texture_path": "res://assets/levrek2.png",
		"behavior_id": "curious",
		"target_count": 6,
		"spawn_x": [1250.0, 3900.0],
		"spawn_y": [820.0, 1080.0],
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
		"depth_label": "25–38 m",
		"texture_path": "res://assets/uskumru.png",
		"behavior_id": "burst",
		"target_count": 6,
		"spawn_x": [2200.0, 5350.0],
		"spawn_y": [1110.0, 1420.0],
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
		"depth_label": "38–50 m",
		"texture_path": "res://assets/tonbaligi.png",
		"behavior_id": "surge",
		"target_count": 4,
		"spawn_x": [3400.0, 6500.0],
		"spawn_y": [1480.0, 1810.0],
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
	"Kılıç Balığı": {
		"value": 130,
		"habitat": "Uzak açık deniz",
		"depth_label": "52–62 m",
		"texture_path": "res://assets/kilic_baligi.svg",
		"behavior_id": "dash",
		"target_count": 3,
		"spawn_x": [4300.0, 7800.0],
		"spawn_y": [2150.0, 2450.0],
		"speed": [72.0, 90.0],
		"distance": [430.0, 680.0],
		"bob": [6.0, 8.0],
		"visual_scale": 0.40,
		"swim_wave_speed": 3.1,
		"swim_wave_angle": 2.2,
		"acceleration": 430.0,
		"vertical_response": 58.0,
		"turn_roll": 7.5,
		"tail_strength": 18.0,
		"tail_speed": 6.4,
		"body_strength": 2.6,
		"collision": [165.0, 50.0],
		"hook_struggle_angle": 22.0,
		"fight": [315.0, 0.27, 19.0, 32.0, 58.0],
		"tension": [29.0, 24.0, 10.0]
	},
	"Köpekbalığı": {
		"value": 220,
		"habitat": "Derin av bölgesi",
		"depth_label": "68–82 m",
		"texture_path": "res://assets/kopekbaligi.svg",
		"behavior_id": "predator",
		"target_count": 2,
		"spawn_x": [5200.0, 9000.0],
		"spawn_y": [2600.0, 3050.0],
		"speed": [42.0, 55.0],
		"distance": [560.0, 820.0],
		"bob": [7.0, 10.0],
		"visual_scale": 0.43,
		"swim_wave_speed": 1.65,
		"swim_wave_angle": 1.35,
		"acceleration": 92.0,
		"vertical_response": 26.0,
		"turn_roll": 10.0,
		"tail_strength": 15.0,
		"tail_speed": 3.6,
		"body_strength": 2.2,
		"collision": [185.0, 72.0],
		"hook_struggle_angle": 11.0,
		"fight": [225.0, 0.42, 17.5, 35.0, 60.0],
		"tension": [35.0, 21.0, 13.0]
	},
	"Fener Balığı": {
		"value": 300,
		"habitat": "Karanlık derinlik",
		"depth_label": "88–100 m",
		"texture_path": "res://assets/fener_baligi.svg",
		"behavior_id": "hover",
		"target_count": 3,
		"spawn_x": [5900.0, 10000.0],
		"spawn_y": [3300.0, 3720.0],
		"speed": [28.0, 38.0],
		"distance": [180.0, 330.0],
		"bob": [10.0, 14.0],
		"visual_scale": 0.43,
		"swim_wave_speed": 1.75,
		"swim_wave_angle": 3.0,
		"acceleration": 70.0,
		"vertical_response": 20.0,
		"turn_roll": 7.0,
		"tail_strength": 10.0,
		"tail_speed": 3.2,
		"body_strength": 2.8,
		"collision": [120.0, 84.0],
		"hook_struggle_angle": 15.0,
		"fight": [180.0, 0.50, 18.0, 31.0, 56.0],
		"tension": [31.0, 22.0, 11.0]
	}
	,
	"Barakuda": {
		"value": 160,
		"habitat": "Açık deniz / avcı",
		"depth_label": "10–15 m (TEST)"
		"texture_path": "res://assets/fish/barakuda.svg",
		"behavior_id": "hunter",
		"target_count": 1
		"spawn_x": [600.0, 650.0]
		"spawn_y": [720.0, 750.0]
		"speed": [22.0, 28.0]
		"distance": [40.0, 65.0]
		"bob": [4.0, 7.0],
		"visual_scale": 1.18
		"swim_wave_speed": 3.9,
		"swim_wave_angle": 0.8
		"acceleration": 460.0,
		"vertical_response": 62.0,
		"turn_roll": 7.0,
		"tail_strength": 0.0
		"tail_speed": 7.2,
		"body_strength": 0.0
		"collision": [145.0, 42.0],
		"hook_struggle_angle": 23.0,
		"fight": [295.0, 0.30, 20.0, 31.0, 60.0],
		"tension": [28.0, 24.0, 9.5],
		"asset_status": "exact_embedded_test"
	},
	"Müren": {
		"value": 115,
		"habitat": "Kanyon duvarları / kaya oyukları",
		"depth_label": "10–15 m (TEST)"
		"texture_path": "res://assets/fish/muren.svg",
		"behavior_id": "ambush",
		"target_count": 1
		"spawn_x": [900.0, 950.0]
		"spawn_y": [810.0, 840.0]
		"speed": [16.0, 22.0]
		"distance": [35.0, 55.0]
		"bob": [2.0, 4.5],
		"visual_scale": 1.18
		"swim_wave_speed": 2.6,
		"swim_wave_angle": 0.8
		"acceleration": 520.0,
		"vertical_response": 34.0,
		"turn_roll": 11.0,
		"tail_strength": 0.0
		"tail_speed": 5.4,
		"body_strength": 0.0
		"collision": [155.0, 38.0],
		"hook_struggle_angle": 27.0,
		"fight": [235.0, 0.38, 21.0, 29.0, 62.0],
		"tension": [27.0, 23.0, 10.0],
		"asset_status": "exact_embedded_test"
	},
	"Vatoz": {
		"value": 140,
		"habitat": "Kumluk dip / kanyon tabanı",
		"depth_label": "10–15 m (TEST)"
		"texture_path": "res://assets/fish/vatoz.svg",
		"behavior_id": "glide",
		"target_count": 1
		"spawn_x": [800.0, 850.0]
		"spawn_y": [780.0, 810.0]
		"speed": [16.0, 22.0]
		"distance": [35.0, 60.0]
		"bob": [7.0, 12.0],
		"visual_scale": 1.18
		"swim_wave_speed": 1.45,
		"swim_wave_angle": 0.6
		"acceleration": 95.0,
		"vertical_response": 22.0,
		"turn_roll": 4.0,
		"tail_strength": 0.0
		"tail_speed": 2.3,
		"body_strength": 0.0
		"collision": [150.0, 78.0],
		"hook_struggle_angle": 10.0,
		"fight": [185.0, 0.52, 20.0, 27.0, 70.0],
		"tension": [24.0, 27.0, 8.0],
		"asset_status": "exact_embedded_test"
	},
	"Deniz Şeytanı": {
		"value": 360,
		"habitat": "Karanlık kanyon / dip avcısı",
		"depth_label": "10–15 m (TEST)"
		"texture_path": "res://assets/fish/deniz_seytani.svg",
		"behavior_id": "lurker",
		"target_count": 1
		"spawn_x": [1000.0, 1050.0]
		"spawn_y": [840.0, 870.0]
		"speed": [12.0, 18.0]
		"distance": [30.0, 50.0]
		"bob": [8.0, 14.0],
		"visual_scale": 1.22
		"swim_wave_speed": 1.55,
		"swim_wave_angle": 0.6
		"acceleration": 88.0,
		"vertical_response": 24.0,
		"turn_roll": 8.0,
		"tail_strength": 0.0
		"tail_speed": 3.0,
		"body_strength": 0.0
		"collision": [135.0, 92.0],
		"hook_struggle_angle": 17.0,
		"fight": [205.0, 0.44, 16.0, 36.0, 52.0],
		"tension": [34.0, 20.0, 13.5],
		"asset_status": "exact_embedded_test"
	},
	"Kalamar": {
		"value": 205,
		"habitat": "Derin açık su / kanyon ağzı",
		"depth_label": "10–15 m (TEST)"
		"texture_path": "res://assets/fish/kalamar.svg",
		"behavior_id": "jet",
		"target_count": 1
		"spawn_x": [700.0, 750.0]
		"spawn_y": [750.0, 780.0]
		"speed": [18.0, 24.0]
		"distance": [35.0, 60.0]
		"bob": [10.0, 17.0],
		"visual_scale": 1.18
		"swim_wave_speed": 2.2,
		"swim_wave_angle": 0.8
		"acceleration": 540.0,
		"vertical_response": 72.0,
		"turn_roll": 12.0,
		"tail_strength": 0.0
		"tail_speed": 4.6,
		"body_strength": 0.0
		"collision": [118.0, 86.0],
		"hook_struggle_angle": 25.0,
		"fight": [255.0, 0.34, 18.0, 33.0, 58.0],
		"tension": [31.0, 22.0, 11.5],
		"asset_status": "exact_embedded_test"
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
