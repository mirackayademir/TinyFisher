extends Node

# Abyssal Leviathan boss sistemi.
# Oyuncunun onayladigi PNG dosyasi birebir su yoldan kullanilir:
# res://assets/rare/abyssal_leviathan.png
# Dosya henuz repoda yoksa autoload projeyi bozmaz; asset geldiginde runtime aktif olur.

const FISH_TYPE: String = "Abyssal Leviathan"
const FISH_VALUE: int = 1250
const FISH_TEXTURE_PATH: String = "res://assets/rare/abyssal_leviathan.png"
const FISH_SCENE: PackedScene = preload("res://scenes/fish.tscn")

const TEST_GUARANTEED_SPAWN: bool = true
const NATURAL_SPAWN_CHANCE: float = 0.018
const RESPAWN_CHECK_SECONDS: float = 7.0
const TEXTURE_RETRY_SECONDS: float = 1.0

# 92-100 m civari derin deniz bolgesi.
const SPAWN_MIN_X: float = 6500.0
const SPAWN_MAX_X: float = 9800.0
const SPAWN_MIN_Y: float = 3420.0
const SPAWN_MAX_Y: float = 3710.0

const LIVE_SARDINE: String = "Canlı Sardalya"
const FISH_COLLISION_LAYER: int = 2

var _texture: Texture2D = null
var _world: Node2D = null
var _hook: Area2D = null
var _hud: CanvasLayer = null
var _fish_book_grid: GridContainer = null
var _fish_book_progress: Label = null
var _sell_button: Button = null

var _scene_id: int = 0
var _spawned_once: bool = false
var _spawn_timer: float = 0.0
var _texture_retry_timer: float = 0.0
var _missing_texture_warned: bool = false
var _discovered: bool = false
var _last_hooked_id: int = 0
var _time: float = 0.0

var _rare_slot: Panel = null
var _rare_slot_icon: TextureRect = null
var _rare_slot_count: Label = null
var _rare_book_card: Panel = null
var _rare_book_icon: TextureRect = null
var _rare_book_name: Label = null
var _rare_book_detail: Label = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# DeepSeaAtmosphere once calissin; yem collision kararinin ustune Leviathan kurali yazilsin.
	process_priority = 100
	_try_load_texture()


func _process(delta: float) -> void:
	_time += delta

	if _texture == null:
		_texture_retry_timer -= delta
		if _texture_retry_timer <= 0.0:
			_texture_retry_timer = TEXTURE_RETRY_SECONDS
			_try_load_texture()
		return

	_ensure_scene()
	if _world == null or _hook == null or _hud == null:
		return

	_ensure_inventory_entry()
	_ensure_rare_inventory_slot()
	_ensure_fish_book_card()
	_update_spawn(delta)
	_update_leviathan(delta)
	_update_boss_fight_override()
	_update_catch_popup()
	_update_ui()


func _try_load_texture() -> void:
	if _texture != null:
		return
	if not ResourceLoader.exists(FISH_TEXTURE_PATH):
		if not _missing_texture_warned:
			push_warning("Abyssal Leviathan asset bekleniyor: " + FISH_TEXTURE_PATH)
			_missing_texture_warned = true
		return

	var loaded: Resource = load(FISH_TEXTURE_PATH)
	_texture = loaded as Texture2D
	if _texture != null:
		_missing_texture_warned = false
		print("ABYSSAL LEVIATHAN ASSET HAZIR: ", FISH_TEXTURE_PATH)


func _ensure_scene() -> void:
	var scene: Node = get_tree().current_scene
	if scene == null:
		return

	var current_id: int = scene.get_instance_id()
	if current_id == _scene_id and is_instance_valid(_world) and is_instance_valid(_hook) and is_instance_valid(_hud):
		return

	_scene_id = current_id
	_world = scene as Node2D
	_hook = null
	_hud = null
	_fish_book_grid = null
	_fish_book_progress = null
	_sell_button = null
	_rare_slot = null
	_rare_slot_icon = null
	_rare_slot_count = null
	_rare_book_card = null
	_rare_book_icon = null
	_rare_book_name = null
	_rare_book_detail = null
	_last_hooked_id = 0
	_spawn_timer = 0.0

	if _world == null:
		return

	_hook = _world.get_node_or_null("Boat/Hook") as Area2D
	_hud = _world.get_node_or_null("HUD") as CanvasLayer
	_fish_book_grid = _world.get("fish_book_grid") as GridContainer
	_fish_book_progress = _world.get("fish_book_progress") as Label
	_sell_button = _world.get_node_or_null("DockMenu/VBoxContainer/SellButton") as Button

	if _sell_button != null and not _sell_button.pressed.is_connected(_on_sell_pressed):
		_sell_button.pressed.connect(_on_sell_pressed)

	if TEST_GUARANTEED_SPAWN and not _spawned_once:
		_spawn_leviathan()
		_spawned_once = true


func _update_spawn(delta: float) -> void:
	if _find_leviathan() != null:
		return

	_spawn_timer -= delta
	if _spawn_timer > 0.0:
		return

	_spawn_timer = RESPAWN_CHECK_SECONDS
	if randf() <= NATURAL_SPAWN_CHANCE:
		_spawn_leviathan()


func _spawn_leviathan() -> void:
	if _world == null or _texture == null:
		return

	var fish: Area2D = FISH_SCENE.instantiate() as Area2D
	if fish == null:
		return

	fish.name = "AbyssalLeviathan"
	fish.set("fish_type", FISH_TYPE)
	fish.set("fish_value", FISH_VALUE)
	fish.set("swim_speed", randf_range(28.0, 36.0))
	fish.set("swim_distance", randf_range(360.0, 520.0))
	fish.set("bob_height", randf_range(9.0, 14.0))
	fish.global_position = Vector2(
		randf_range(SPAWN_MIN_X, SPAWN_MAX_X),
		randf_range(SPAWN_MIN_Y, SPAWN_MAX_Y)
	)
	_world.add_child(fish)
	_configure_visual(fish)
	print("ABYSSAL LEVIATHAN DERINLIKLERDE BELIRDI")


func _configure_visual(fish: Area2D) -> void:
	var sprite: Sprite2D = fish.get_node_or_null("FishSprite") as Sprite2D
	if sprite == null or _texture == null:
		return

	# PNG yeniden cizilmez veya filtrelenmez; ayni raster asset kullanilir.
	sprite.texture = _texture
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.scale = Vector2(0.34, 0.34)
	fish.set("last_visual_type", FISH_TYPE)
	fish.set("base_sprite_scale", Vector2(0.34, 0.34))

	# Agir, buyuk bir derin deniz canlisi hissi.
	fish.set("swim_wave_speed", 1.18)
	fish.set("swim_wave_angle", 1.15)
	fish.set("swim_acceleration", 68.0)
	fish.set("vertical_response", 16.0)
	fish.set("turn_roll_strength", 8.0)
	fish.set("base_tail_strength", 8.5)
	fish.set("base_tail_speed", 2.7)
	fish.set("base_body_strength", 1.7)

	var direction: float = float(fish.get("direction"))
	sprite.flip_h = direction > 0.0

	var collision: CollisionShape2D = fish.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision != null:
		var rect: RectangleShape2D = collision.shape as RectangleShape2D
		if rect != null:
			rect.size = Vector2(560.0, 170.0)

	_ensure_lure_light(fish)


func _update_leviathan(delta: float) -> void:
	var fish: Area2D = _find_leviathan()
	if fish == null:
		return

	var sprite: Sprite2D = fish.get_node_or_null("FishSprite") as Sprite2D
	if sprite != null:
		sprite.texture = _texture
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite.scale = Vector2(0.34, 0.34)
		sprite.flip_h = float(fish.get("direction")) > 0.0

	var light: PointLight2D = fish.get_node_or_null("LeviathanLureLight") as PointLight2D
	if light != null:
		light.position.x = 320.0 if sprite != null and sprite.flip_h else -320.0
		light.energy = 1.18 + sin(_time * 2.35) * 0.24

	if bool(fish.get("is_hooked")):
		fish.collision_layer = FISH_COLLISION_LAYER
		return

	# DeepSeaAtmosphere bilinmeyen turleri collision disina cikardigi icin boss yem kuralini
	# burada sonradan uygulariz: Leviathan yalnizca Canli Sardalya ile yakalanabilir.
	var bait_ok: bool = _selected_bait() == LIVE_SARDINE
	fish.collision_layer = FISH_COLLISION_LAYER if bait_ok else 0
	if not bait_ok or not bool(_hook.get("deployed")) or _hook.get("hooked_fish") != null:
		return

	var to_bait: Vector2 = _hook.global_position - fish.global_position
	var distance: float = to_bait.length()
	if distance <= 10.0 or distance > 920.0:
		return

	var pull: float = (1.0 - clampf(distance / 920.0, 0.0, 1.0)) * 105.0
	fish.global_position += to_bait.normalized() * pull * delta
	if absf(to_bait.x) > 12.0:
		fish.set("direction", 1.0 if to_bait.x > 0.0 else -1.0)


func _selected_bait() -> String:
	var atmosphere: Node = get_node_or_null("/root/DeepSeaAtmosphere")
	if atmosphere == null:
		return ""
	return String(atmosphere.get("selected_bait"))


func _ensure_lure_light(fish: Area2D) -> void:
	if fish.get_node_or_null("LeviathanLureLight") != null:
		return

	var image: Image = Image.create(96, 96, false, Image.FORMAT_RGBA8)
	var center: Vector2 = Vector2(47.5, 47.5)
	for y: int in range(96):
		for x: int in range(96):
			var d: float = Vector2(float(x), float(y)).distance_to(center) / 48.0
			var power: float = pow(clampf(1.0 - d, 0.0, 1.0), 2.0)
			image.set_pixel(x, y, Color(power, power, power, 1.0))

	var light: PointLight2D = PointLight2D.new()
	light.name = "LeviathanLureLight"
	light.texture = ImageTexture.create_from_image(image)
	light.color = Color(1.0, 0.13, 0.08, 1.0)
	light.texture_scale = 2.35
	light.energy = 1.18
	light.shadow_enabled = false
	light.z_index = 25
	light.position = Vector2(-320.0, -18.0)
	fish.add_child(light)


func _update_boss_fight_override() -> void:
	var hooked_value: Variant = _hook.get("hooked_fish")
	if hooked_value == null or not is_instance_valid(hooked_value):
		_last_hooked_id = 0
		return

	var fish: Area2D = hooked_value as Area2D
	if fish == null or String(fish.get("fish_type")) != FISH_TYPE:
		return

	var current_id: int = fish.get_instance_id()
	if current_id == _last_hooked_id:
		return
	_last_hooked_id = current_id

	# Oyundaki en zor boss mucadelesi.
	_hook.set("tension_gain_rate", 43.0)
	_hook.set("tension_recovery_rate", 18.0)
	_hook.set("tension_fish_pull", 17.0)
	_hook.set("line_tension", 18.0)

	_hud.set("fish_move_speed", 335.0)
	_hud.set("fish_change_interval", 0.24)
	_hud.set("fight_gain_speed", 15.0)
	_hud.set("fight_loss_speed", 39.0)

	var marker: ColorRect = _hud.get_node_or_null("FightPanel/FightBar/FishMarker") as ColorRect
	var zone: ColorRect = _hud.get_node_or_null("FightPanel/FightBar/CatchZone") as ColorRect
	if marker != null:
		marker.size.x = 28.0
	if zone != null:
		zone.size.x = 48.0


func _ensure_inventory_entry() -> void:
	var inv_value: Variant = _hud.get("inventory")
	if typeof(inv_value) != TYPE_DICTIONARY:
		return
	var inventory: Dictionary = inv_value
	if not inventory.has(FISH_TYPE):
		inventory[FISH_TYPE] = 0
		_hud.set("inventory", inventory)


func _ensure_rare_inventory_slot() -> void:
	if is_instance_valid(_rare_slot):
		return

	var panel: Panel = _hud.get_node_or_null("RareFishSlot") as Panel
	if panel == null:
		panel = Panel.new()
		panel.name = "RareFishSlot"
		panel.position = Vector2(14.0, 98.0)
		panel.size = Vector2(170.0, 62.0)
		panel.z_index = 102
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_hud.add_child(panel)

		var style: StyleBoxFlat = StyleBoxFlat.new()
		style.bg_color = Color(0.035, 0.025, 0.06, 0.94)
		style.border_color = Color(0.88, 0.25, 0.22, 0.96)
		style.border_width_left = 2
		style.border_width_top = 2
		style.border_width_right = 2
		style.border_width_bottom = 2
		style.corner_radius_top_left = 6
		style.corner_radius_top_right = 6
		style.corner_radius_bottom_left = 6
		style.corner_radius_bottom_right = 6
		panel.add_theme_stylebox_override("panel", style)

		var icon: TextureRect = TextureRect.new()
		icon.name = "Icon"
		icon.position = Vector2(5.0, 4.0)
		icon.size = Vector2(108.0, 54.0)
		icon.texture = _texture
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(icon)

		var count: Label = Label.new()
		count.name = "Count"
		count.position = Vector2(116.0, 5.0)
		count.size = Vector2(49.0, 52.0)
		count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		count.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		count.add_theme_font_size_override("font_size", 20)
		count.add_theme_color_override("font_color", Color(1.0, 0.76, 0.42, 1.0))
		count.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(count)

	_rare_slot = panel
	_rare_slot_icon = panel.get_node("Icon") as TextureRect
	_rare_slot_count = panel.get_node("Count") as Label


func _ensure_fish_book_card() -> void:
	if _fish_book_grid == null or is_instance_valid(_rare_book_card):
		return

	var card: Panel = Panel.new()
	card.name = "AbyssalLeviathanCard"
	card.custom_minimum_size = Vector2(300.0, 138.0)
	_fish_book_grid.add_child(card)

	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.025, 0.07, 0.97)
	style.border_color = Color(0.82, 0.20, 0.18, 0.96)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	card.add_theme_stylebox_override("panel", style)

	var tag: Label = Label.new()
	tag.position = Vector2(8.0, 5.0)
	tag.size = Vector2(104.0, 18.0)
	tag.text = "★ NADİR / BOSS"
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tag.add_theme_font_size_override("font_size", 10)
	tag.add_theme_color_override("font_color", Color(1.0, 0.40, 0.32, 1.0))
	card.add_child(tag)

	var icon: TextureRect = TextureRect.new()
	icon.position = Vector2(8.0, 25.0)
	icon.size = Vector2(104.0, 102.0)
	icon.texture = _texture
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(icon)

	var title: Label = Label.new()
	title.position = Vector2(116.0, 12.0)
	title.size = Vector2(176.0, 31.0)
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color(1.0, 0.70, 0.38, 1.0))
	card.add_child(title)

	var detail: Label = Label.new()
	detail.position = Vector2(116.0, 43.0)
	detail.size = Vector2(176.0, 88.0)
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail.add_theme_font_size_override("font_size", 11)
	detail.add_theme_color_override("font_color", Color(0.86, 0.92, 0.96, 1.0))
	card.add_child(detail)

	_rare_book_card = card
	_rare_book_icon = icon
	_rare_book_name = title
	_rare_book_detail = detail


func _update_catch_popup() -> void:
	var popup: Control = _hud.get_node_or_null("CatchPopup") as Control
	if popup == null or not popup.visible:
		return

	var name_label: Label = _hud.get_node_or_null("CatchPopup/Name") as Label
	var icon: TextureRect = _hud.get_node_or_null("CatchPopup/FishIcon") as TextureRect
	if name_label != null and name_label.text == FISH_TYPE:
		_discovered = true
		if icon != null:
			icon.texture = _texture
			icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			icon.modulate = Color.WHITE


func _update_ui() -> void:
	var amount: int = _get_count()
	if amount > 0:
		_discovered = true

	if _rare_slot != null:
		_rare_slot.visible = _discovered or amount > 0
	if _rare_slot_icon != null:
		_rare_slot_icon.texture = _texture
		_rare_slot_icon.modulate = Color.WHITE
	if _rare_slot_count != null:
		_rare_slot_count.text = "x%d" % amount if amount > 0 else ""

	if _rare_book_icon != null and _rare_book_name != null and _rare_book_detail != null:
		if _discovered:
			_rare_book_icon.modulate = Color.WHITE
			_rare_book_name.text = FISH_TYPE
			_rare_book_detail.text = "★ BOSS / NADİR\nDeğer: $1250\nDerinlik: 92–100 m\nYem: Canlı Sardalya"
		else:
			_rare_book_icon.modulate = Color(0.025, 0.035, 0.055, 1.0)
			_rare_book_name.text = "???"
			_rare_book_detail.text = "Derinlerde çok nadir ve devasa bir şey yaşıyor..."

	if _fish_book_progress != null:
		var base_count: int = 0
		var discovered_value: Variant = _world.get("discovered_fish")
		if typeof(discovered_value) == TYPE_DICTIONARY:
			for value: Variant in (discovered_value as Dictionary).values():
				if bool(value):
					base_count += 1
		_fish_book_progress.text = "Keşif: %d / 8" % (base_count + (1 if _discovered else 0))


func _on_sell_pressed() -> void:
	var amount: int = _get_count()
	if amount <= 0 or _world == null:
		return

	_world.set("money", int(_world.get("money")) + amount * FISH_VALUE)
	_set_count(0)
	if _world.has_method("update_money_label"):
		_world.call("update_money_label")
	if _world.has_method("_refresh_upgrade_menu"):
		_world.call("_refresh_upgrade_menu")
	print("ABYSSAL LEVIATHAN SATILDI! +$", amount * FISH_VALUE)


func _get_count() -> int:
	if _hud == null:
		return 0
	var inv_value: Variant = _hud.get("inventory")
	if typeof(inv_value) != TYPE_DICTIONARY:
		return 0
	return int((inv_value as Dictionary).get(FISH_TYPE, 0))


func _set_count(value: int) -> void:
	if _hud == null:
		return
	var inv_value: Variant = _hud.get("inventory")
	if typeof(inv_value) != TYPE_DICTIONARY:
		return
	var inventory: Dictionary = inv_value
	inventory[FISH_TYPE] = maxi(0, value)
	_hud.set("inventory", inventory)


func _find_leviathan() -> Area2D:
	if _world == null:
		return null
	return _find_leviathan_recursive(_world)


func _find_leviathan_recursive(node: Node) -> Area2D:
	if node is Area2D and String(node.get("fish_type")) == FISH_TYPE:
		return node as Area2D
	for child: Node in node.get_children():
		var found: Area2D = _find_leviathan_recursive(child)
		if found != null:
			return found
	return null
