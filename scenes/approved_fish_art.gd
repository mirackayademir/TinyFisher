extends Node

# Balık görsel düzeltmeleri + Leviathan test köprüsü.
# Onaylı WebP dosyaları şu an bozuk olduğu için Godot başlangıçta decode hatası veriyordu.
# Test sürecinde hatasız eski SVG texture'lara güvenli geri dönüş yapıyoruz.
# Leviathan autoload yerelde eksik olsa bile bu çalışan autoload üzerinden runtime başlatılır.

const KILIC_OLD: String = "res://assets/kilic_baligi.svg"
const KOPEK_OLD: String = "res://assets/kopekbaligi.svg"
const FENER_OLD: String = "res://assets/fener_baligi.svg"

const SCAN_INTERVAL: float = 0.10
const BAIT_SCALE: Vector2 = Vector2(0.72, 0.72)
const BAIT_HOOK_OFFSET: Vector2 = Vector2(3.5, 7.0)

const LEVIATHAN_RUNTIME_SCRIPT: Script = preload("res://scenes/abyssal_leviathan_runtime.gd")
const LEVIATHAN_TEST_MODE: bool = true
const LEVIATHAN_TEST_DEPTH_Y: float = 600.0
const LEVIATHAN_TEST_BOAT_OFFSET_X: float = 850.0

var _scan_timer: float = 0.0
var _kilic_approved: Texture2D = null
var _kopek_approved: Texture2D = null
var _fener_approved: Texture2D = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_priority = 100
	_load_safe_textures()
	_ensure_leviathan_runtime()
	_apply_to_current_scene()
	_align_bait_to_hook()


func _process(delta: float) -> void:
	_ensure_leviathan_runtime()
	_place_leviathan_for_test()
	_align_bait_to_hook()

	_scan_timer -= delta
	if _scan_timer > 0.0:
		return
	_scan_timer = SCAN_INTERVAL
	_apply_to_current_scene()


func _load_safe_textures() -> void:
	# Geçici güvenli fallback: bozuk WebP dosyalarını decode etmeye çalışma.
	_kilic_approved = load(KILIC_OLD) as Texture2D
	_kopek_approved = load(KOPEK_OLD) as Texture2D
	_fener_approved = load(FENER_OLD) as Texture2D


func _ensure_leviathan_runtime() -> void:
	# project.godot yerelde eski kaldıysa RareFishSystem autoload olmayabilir.
	# Böyle durumda bu autoload runtime'ı kendi altında tek kez başlatır.
	var singleton: Node = get_node_or_null("/root/RareFishSystem")
	if singleton != null:
		return
	if get_node_or_null("LeviathanRuntime") != null:
		return

	var runtime: Node = Node.new()
	runtime.name = "LeviathanRuntime"
	runtime.set_script(LEVIATHAN_RUNTIME_SCRIPT)
	add_child(runtime)
	print("LEVIATHAN RUNTIME TEST ICIN AKTIF")


func _place_leviathan_for_test() -> void:
	if not LEVIATHAN_TEST_MODE:
		return
	var root: Node = get_tree().current_scene
	if root == null:
		return

	var leviathan: Node2D = _find_node_recursive(root, "AbyssalLeviathan") as Node2D
	if leviathan == null or leviathan.has_meta("shallow_test_placed"):
		return

	var boat: Node2D = root.get_node_or_null("Boat") as Node2D
	var target_x: float = 1400.0
	if boat != null:
		target_x = boat.global_position.x + LEVIATHAN_TEST_BOAT_OFFSET_X

	leviathan.global_position = Vector2(target_x, LEVIATHAN_TEST_DEPTH_Y)
	leviathan.set_meta("shallow_test_placed", true)
	print("LEVIATHAN TEST KONUMUNA TASINDI: ", leviathan.global_position)


func _find_node_recursive(node: Node, target_name: String) -> Node:
	if node.name == target_name:
		return node
	for child: Node in node.get_children():
		var found: Node = _find_node_recursive(child, target_name)
		if found != null:
			return found
	return null


func get_texture_for_fish(fish_type: String) -> Texture2D:
	match fish_type:
		"Kılıç Balığı":
			return _kilic_approved
		"Köpekbalığı":
			return _kopek_approved
		"Fener Balığı":
			return _fener_approved
		_:
			return null


func _apply_to_current_scene() -> void:
	var root: Node = get_tree().current_scene
	if root == null:
		return
	_scan_node(root)


func _align_bait_to_hook() -> void:
	var root: Node = get_tree().current_scene
	if root == null:
		return

	var hook: Node2D = root.get_node_or_null("Boat/Hook") as Node2D
	if hook == null:
		return

	var bait_root: Node2D = hook.get_node_or_null("BaitVisualRoot") as Node2D
	if bait_root == null:
		return

	var t: float = float(Time.get_ticks_msec()) * 0.001
	bait_root.position = BAIT_HOOK_OFFSET + Vector2(sin(t * 0.80) * 0.8, sin(t * 1.15) * 0.45)
	bait_root.scale = BAIT_SCALE


func _scan_node(node: Node) -> void:
	if node is Sprite2D:
		_replace_sprite(node as Sprite2D)
	elif node is TextureRect:
		_replace_texture_rect(node as TextureRect)

	for child: Node in node.get_children():
		_scan_node(child)


func _replace_sprite(sprite: Sprite2D) -> void:
	if sprite.texture == null:
		return

	var old_path: String = sprite.texture.resource_path
	var fish_type: String = ""
	var approved: Texture2D = null

	match old_path:
		KILIC_OLD:
			fish_type = "Kılıç Balığı"
			approved = _kilic_approved
		KOPEK_OLD:
			fish_type = "Köpekbalığı"
			approved = _kopek_approved
		FENER_OLD:
			fish_type = "Fener Balığı"
			approved = _fener_approved
		_:
			return

	if approved == null:
		return

	sprite.texture = approved
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_compensate_fish_scale(sprite, fish_type)


func _replace_texture_rect(rect: TextureRect) -> void:
	if rect.texture == null:
		return

	var approved: Texture2D = null
	match rect.texture.resource_path:
		KILIC_OLD:
			approved = _kilic_approved
		KOPEK_OLD:
			approved = _kopek_approved
		FENER_OLD:
			approved = _fener_approved
		_:
			return

	if approved == null:
		return

	rect.texture = approved
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func _compensate_fish_scale(sprite: Sprite2D, fish_type: String) -> void:
	var fish: Node = sprite.get_parent()
	if fish == null or not fish.has_method("hook_to"):
		return

	var target_scale: Vector2 = Vector2.ONE
	match fish_type:
		"Kılıç Balığı":
			target_scale = Vector2(0.57, 0.57)
		"Köpekbalığı":
			target_scale = Vector2(0.61, 0.61)
		"Fener Balığı":
			target_scale = Vector2(0.55, 0.55)
		_:
			return

	fish.set("base_sprite_scale", target_scale)
	sprite.scale = target_scale
