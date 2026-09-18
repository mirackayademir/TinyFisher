extends RefCounted

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
		"depth_label": "42–62 m",
		"texture_path": "res://assets/fish/barakuda.png",
		"behavior_id": "hunter",
		"target_count": 2,
		"spawn_x": [3900.0, 7600.0],
		"spawn_y": [1700.0, 2320.0],
		"speed": [92.0, 118.0],
		"distance": [420.0, 720.0],
		"bob": [4.0, 7.0],
		"visual_scale": 0.50,
		"swim_wave_speed": 3.9,
		"swim_wave_angle": 2.1,
		"acceleration": 460.0,
		"vertical_response": 62.0,
		"turn_roll": 7.0,
		"tail_strength": 20.0,
		"tail_speed": 7.2,
		"body_strength": 3.0,
		"collision": [145.0, 42.0],
		"hook_struggle_angle": 23.0,
		"fight": [295.0, 0.30, 20.0, 31.0, 60.0],
		"tension": [28.0, 24.0, 9.5],
		"asset_status": "live"
	},
	"Müren": {
		"value": 115,
		"habitat": "Kanyon duvarları / kaya oyukları",
		"depth_label": "55–76 m",
		"texture_path": "res://assets/fish/muren.png",
		"behavior_id": "ambush",
		"target_count": 2,
		"spawn_x": [2600.0, 8200.0],
		"spawn_y": [2140.0, 2860.0],
		"speed": [26.0, 38.0],
		"distance": [130.0, 260.0],
		"bob": [2.0, 4.5],
		"visual_scale": 0.46,
		"swim_wave_speed": 2.6,
		"swim_wave_angle": 5.0,
		"acceleration": 520.0,
		"vertical_response": 34.0,
		"turn_roll": 11.0,
		"tail_strength": 34.0,
		"tail_speed": 5.4,
		"body_strength": 7.0,
		"collision": [155.0, 38.0],
		"hook_struggle_angle": 27.0,
		"fight": [235.0, 0.38, 21.0, 29.0, 62.0],
		"tension": [27.0, 23.0, 10.0],
		"asset_status": "live"
	},
	"Vatoz": {
		"value": 140,
		"habitat": "Kumluk dip / kanyon tabanı",
		"depth_label": "35–58 m",
		"texture_path": "res://assets/fish/vatoz.png",
		"behavior_id": "glide",
		"target_count": 2,
		"spawn_x": [2200.0, 7200.0],
		"spawn_y": [1550.0, 2200.0],
		"speed": [34.0, 48.0],
		"distance": [360.0, 620.0],
		"bob": [7.0, 12.0],
		"visual_scale": 0.46,
		"swim_wave_speed": 1.45,
		"swim_wave_angle": 1.2,
		"acceleration": 95.0,
		"vertical_response": 22.0,
		"turn_roll": 4.0,
		"tail_strength": 8.0,
		"tail_speed": 2.3,
		"body_strength": 6.5,
		"collision": [150.0, 78.0],
		"hook_struggle_angle": 10.0,
		"fight": [185.0, 0.52, 20.0, 27.0, 70.0],
		"tension": [24.0, 27.0, 8.0],
		"asset_status": "live"
	},
	"Deniz Şeytanı": {
		"value": 360,
		"habitat": "Karanlık kanyon / dip avcısı",
		"depth_label": "82–98 m",
		"texture_path": "res://assets/fish/deniz_seytani.png",
		"behavior_id": "lurker",
		"target_count": 1,
		"spawn_x": [5600.0, 9800.0],
		"spawn_y": [3120.0, 3650.0],
		"speed": [24.0, 34.0],
		"distance": [180.0, 340.0],
		"bob": [8.0, 14.0],
		"visual_scale": 0.44,
		"swim_wave_speed": 1.55,
		"swim_wave_angle": 3.8,
		"acceleration": 88.0,
		"vertical_response": 24.0,
		"turn_roll": 8.0,
		"tail_strength": 13.0,
		"tail_speed": 3.0,
		"body_strength": 3.4,
		"collision": [135.0, 92.0],
		"hook_struggle_angle": 17.0,
		"fight": [205.0, 0.44, 16.0, 36.0, 52.0],
		"tension": [34.0, 20.0, 13.5],
		"asset_status": "live"
	},
	"Kalamar": {
		"value": 205,
		"habitat": "Derin açık su / kanyon ağzı",
		"depth_label": "64–90 m",
		"texture_path": "res://assets/fish/kalamar.png",
		"behavior_id": "jet",
		"target_count": 2,
		"spawn_x": [4300.0, 9200.0],
		"spawn_y": [2450.0, 3340.0],
		"speed": [42.0, 58.0],
		"distance": [280.0, 520.0],
		"bob": [10.0, 17.0],
		"visual_scale": 0.45,
		"swim_wave_speed": 2.2,
		"swim_wave_angle": 4.4,
		"acceleration": 540.0,
		"vertical_response": 72.0,
		"turn_roll": 12.0,
		"tail_strength": 15.0,
		"tail_speed": 4.6,
		"body_strength": 6.0,
		"collision": [118.0, 86.0],
		"hook_struggle_angle": 25.0,
		"fight": [255.0, 0.34, 18.0, 33.0, 58.0],
		"tension": [31.0, 22.0, 11.5],
		"asset_status": "live"
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
	var texture_path: String = String(get_profile(fish_type).get("texture_path", ""))
	if texture_path.is_empty() or not ResourceLoader.exists(texture_path):
		return null
	return ResourceLoader.load(texture_path) as Texture2D


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
