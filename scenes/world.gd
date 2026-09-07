extends Node2D

const MAX_UPGRADE_LEVEL: int = 5
const UPGRADE_COSTS: Array[int] = [50, 100, 175, 275, 400]
const WATER_SURFACE_Y: float = 360.0

@onready var dock_prompt: Label = $DockPrompt
@onready var dock_menu: Panel = $DockMenu
@onready var upgrade_menu: Panel = $UpgradeMenu
@onready var dock_sprite: Sprite2D = $Dock
@onready var dock_collision: CollisionShape2D = $DockArea/CollisionShape2D
@onready var boat: CharacterBody2D = $Boat
@onready var hook = $Boat/Hook
@onready var money_label: Label = $MoneyLabel
@onready var hud = $HUD

@onready var fish_icon_1: TextureRect = $HUD/InventoryPanel/InventorySlots/Slot1/FishIcon
@onready var fish_icon_2: TextureRect = $HUD/InventoryPanel/InventorySlots/Slot2/FishIcon
@onready var fish_icon_3: TextureRect = $HUD/InventoryPanel/InventorySlots/Slot3/FishIcon
@onready var fish_icon_4: TextureRect = $HUD/InventoryPanel/InventorySlots/Slot4/FishIcon

@onready var boat_speed_button: Button = $UpgradeMenu/BoatSpeedButton
@onready var rod_speed_button: Button = $UpgradeMenu/RodSpeedButton
@onready var capacity_button: Button = $UpgradeMenu/CapacityButton
@onready var fight_ease_button: Button = $UpgradeMenu/FightEaseButton
@onready var upgrade_info_label: Label = $UpgradeMenu/InfoLabel

var boat_in_dock_area: bool = false
var docked: bool = false
var money: int = 0
var money_panel: Panel

var boat_speed_level: int = 0
var rod_speed_level: int = 0
var capacity_level: int = 0
var fight_ease_level: int = 0

var _sea_time: float = 0.0
var _surface_shadow: Line2D
var _surface_foam: Line2D

# Balık türleri başlangıçta anonimdir. Oyuncu o türü ilk kez yakalayınca ikonu kalıcı olarak açılır.
var discovered_fish: Dictionary = {
	"Sardalya": false,
	"Levrek": false,
	"Uskumru": false,
	"Ton Balığı": false
}


func _ready() -> void:
	dock_prompt.visible = false
	dock_menu.visible = false
	upgrade_menu.visible = false
	_setup_harbor()
	_setup_surface_waves()
	_setup_money_hud()
	_setup_inventory_discovery()
	_apply_upgrades()
	update_money_label()
	_refresh_upgrade_menu()


func _setup_harbor() -> void:
	# Liman büyük kalır; limana yaklaşınca Boat kamerası sola kayıp uzaklaşarak tamamına yakınını gösterir.
	dock_sprite.scale = Vector2(4.35, 4.35)
	dock_sprite.position = Vector2(165.0, 255.0)

	# Tekne limanın görselinin içinden geçmez; iskelenin sağında durur.
	boat.min_world_x = 470.0

	# Yanaşma / geliştirme alanı büyüyen iskeleye göre genişletildi.
	dock_collision.position = Vector2(650.0, 335.0)
	var dock_shape := dock_collision.shape as RectangleShape2D
	if dock_shape != null:
		dock_shape.size = Vector2(360.0, 190.0)

	dock_prompt.position = Vector2(555.0, 150.0)
	dock_prompt.size = Vector2(245.0, 34.0)

	upgrade_menu.position = Vector2(265.0, 48.0)
	upgrade_menu.size = Vector2(560.0, 405.0)


func _setup_inventory_discovery() -> void:
	# Dört slot başta boş/anonim görünür. İlk yakalamada ilgili görsel açılır.
	fish_icon_1.visible = false
	fish_icon_2.visible = false
	fish_icon_3.visible = false
	fish_icon_4.visible = false


func _update_inventory_discovery() -> void:
	if hud.inventory.get("Sardalya", 0) > 0:
		discovered_fish["Sardalya"] = true
	if hud.inventory.get("Levrek", 0) > 0:
		discovered_fish["Levrek"] = true
	if hud.inventory.get("Uskumru", 0) > 0:
		discovered_fish["Uskumru"] = true
	if hud.inventory.get("Ton Balığı", 0) > 0:
		discovered_fish["Ton Balığı"] = true

	fish_icon_1.visible = discovered_fish["Sardalya"]
	fish_icon_2.visible = discovered_fish["Levrek"]
	fish_icon_3.visible = discovered_fish["Uskumru"]
	fish_icon_4.visible = discovered_fish["Ton Balığı"]


func _setup_surface_waves() -> void:
	_surface_shadow = Line2D.new()
	_surface_shadow.name = "SurfaceWaveShadow"
	_surface_shadow.z_index = 0
	_surface_shadow.width = 8.0
	_surface_shadow.default_color = Color(0.02, 0.26, 0.42, 0.72)
	_surface_shadow.antialiased = false
	add_child(_surface_shadow)

	_surface_foam = Line2D.new()
	_surface_foam.name = "SurfaceWaveFoam"
	_surface_foam.z_index = 0
	_surface_foam.width = 3.0
	_surface_foam.default_color = Color(0.80, 0.95, 0.98, 0.88)
	_surface_foam.antialiased = false
	add_child(_surface_foam)

	_update_surface_waves()


func _surface_height_at(x: float) -> float:
	return (
		WATER_SURFACE_Y
		+ sin(x * 0.018 + _sea_time * 1.72) * 5.2
		+ sin(x * 0.043 - _sea_time * 1.08 + 0.8) * 2.2
	)


func _update_surface_waves() -> void:
	if _surface_shadow == null or _surface_foam == null:
		return

	var shadow_points := PackedVector2Array()
	var foam_points := PackedVector2Array()

	for x in range(-1000, 11001, 28):
		var wave_y := _surface_height_at(float(x))
		shadow_points.append(Vector2(float(x), wave_y + 3.0))
		foam_points.append(Vector2(float(x), wave_y))

	_surface_shadow.points = shadow_points
	_surface_foam.points = foam_points


func _setup_money_hud() -> void:
	# Para CanvasLayer altında kalır; kanca derine inse bile sağ üstten ayrılmaz.
	money_panel = Panel.new()
	money_panel.name = "MoneyPanel"
	money_panel.z_index = 90
	money_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(money_panel)

	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.02, 0.055, 0.095, 0.92)
	panel_style.border_color = Color(0.95, 0.66, 0.24, 0.95)
	panel_style.border_width_left = 3
	panel_style.border_width_top = 3
	panel_style.border_width_right = 3
	panel_style.border_width_bottom = 3
	panel_style.corner_radius_top_left = 8
	panel_style.corner_radius_top_right = 8
	panel_style.corner_radius_bottom_left = 8
	panel_style.corner_radius_bottom_right = 8
	money_panel.add_theme_stylebox_override("panel", panel_style)

	var viewport_size := get_viewport().get_visible_rect().size
	money_panel.size = Vector2(154.0, 50.0)
	money_panel.position = Vector2(viewport_size.x - money_panel.size.x - 18.0, 16.0)

	money_label.reparent(money_panel, false)
	money_label.position = Vector2(12.0, 7.0)
	money_label.size = Vector2(130.0, 36.0)
	money_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	money_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	money_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	money_label.add_theme_font_size_override("font_size", 24)
	money_label.add_theme_color_override("font_color", Color(1.0, 0.84, 0.36, 1.0))
	money_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	money_label.add_theme_constant_override("shadow_offset_x", 2)
	money_label.add_theme_constant_override("shadow_offset_y", 2)


func _process(delta: float) -> void:
	_sea_time += delta
	_update_surface_waves()
	_update_inventory_discovery()

	if boat_in_dock_area and Input.is_action_just_pressed("dock") and not docked and not hook.deployed:
		docked = true
		boat.set_movement_enabled(false)
		dock_prompt.visible = false
		dock_menu.visible = true
		upgrade_menu.visible = false
		$Boat/Camera2D.position.y = hook.camera_surface_y
		print("LIMANA YANASTIN")


func _on_dock_area_body_entered(body: Node2D) -> void:
	if body.name == "Boat":
		boat_in_dock_area = true
		if not docked:
			dock_prompt.visible = true
			dock_prompt.text = "[E] Limana Yanaş"


func _on_dock_area_body_exited(body: Node2D) -> void:
	if body.name == "Boat":
		boat_in_dock_area = false
		dock_prompt.visible = false


func _on_leave_button_pressed() -> void:
	docked = false
	dock_menu.visible = false
	upgrade_menu.visible = false
	boat.set_movement_enabled(true)

	if boat_in_dock_area:
		dock_prompt.visible = true
		dock_prompt.text = "[E] Limana Yanaş"


func _on_sell_button_pressed() -> void:
	var sardalya_count: int = hud.inventory.get("Sardalya", 0)
	var levrek_count: int = hud.inventory.get("Levrek", 0)
	var uskumru_count: int = hud.inventory.get("Uskumru", 0)
	var ton_baligi_count: int = hud.inventory.get("Ton Balığı", 0)

	var total_fish: int = sardalya_count + levrek_count + uskumru_count + ton_baligi_count
	if total_fish == 0:
		print("SATILACAK BALIK YOK!")
		return

	var total_value: int = 0
	total_value += sardalya_count * 10
	total_value += levrek_count * 25
	total_value += uskumru_count * 40
	total_value += ton_baligi_count * 75
	money += total_value

	hud.inventory["Sardalya"] = 0
	hud.inventory["Levrek"] = 0
	hud.inventory["Uskumru"] = 0
	hud.inventory["Ton Balığı"] = 0
	hud.update_inventory()
	update_money_label()
	_refresh_upgrade_menu()
	print("BALIKLAR SATILDI! +$", total_value)


func _on_upgrade_button_pressed() -> void:
	if not docked:
		return
	dock_menu.visible = false
	upgrade_menu.visible = true
	_refresh_upgrade_menu()


func _on_upgrade_back_button_pressed() -> void:
	upgrade_menu.visible = false
	if docked:
		dock_menu.visible = true


func _on_boat_speed_button_pressed() -> void:
	_buy_upgrade("boat_speed")


func _on_rod_speed_button_pressed() -> void:
	_buy_upgrade("rod_speed")


func _on_capacity_button_pressed() -> void:
	_buy_upgrade("capacity")


func _on_fight_ease_button_pressed() -> void:
	_buy_upgrade("fight_ease")


func _buy_upgrade(key: String) -> void:
	if not docked:
		return

	var level := _get_upgrade_level(key)
	if level >= MAX_UPGRADE_LEVEL:
		return

	var cost := UPGRADE_COSTS[level]
	if money < cost:
		upgrade_info_label.text = "Yeterli paran yok. Gereken: $" + str(cost)
		return

	money -= cost
	_set_upgrade_level(key, level + 1)
	_apply_upgrades()
	update_money_label()
	_refresh_upgrade_menu()


func _get_upgrade_level(key: String) -> int:
	match key:
		"boat_speed":
			return boat_speed_level
		"rod_speed":
			return rod_speed_level
		"capacity":
			return capacity_level
		"fight_ease":
			return fight_ease_level
		_:
			return 0


func _set_upgrade_level(key: String, level: int) -> void:
	match key:
		"boat_speed":
			boat_speed_level = level
		"rod_speed":
			rod_speed_level = level
		"capacity":
			capacity_level = level
		"fight_ease":
			fight_ease_level = level


func _apply_upgrades() -> void:
	boat.set_speed_level(boat_speed_level)
	hook.set_reel_speed_level(rod_speed_level)
	hud.set_capacity_level(capacity_level)
	hud.set_fight_ease_level(fight_ease_level)


func _refresh_upgrade_menu() -> void:
	boat_speed_button.text = _upgrade_button_text("Motor Gücü", boat_speed_level)
	rod_speed_button.text = _upgrade_button_text("Makara Hızı", rod_speed_level)
	capacity_button.text = _upgrade_button_text("Tekne Ambarı", capacity_level)
	fight_ease_button.text = _upgrade_button_text("Mücadele Desteği", fight_ease_level)

	boat_speed_button.disabled = not _can_afford_level(boat_speed_level)
	rod_speed_button.disabled = not _can_afford_level(rod_speed_level)
	capacity_button.disabled = not _can_afford_level(capacity_level)
	fight_ease_button.disabled = not _can_afford_level(fight_ease_level)
	upgrade_info_label.text = "Her geliştirme 5 seviyedir. Balık satıp para kazan."


func _upgrade_button_text(title: String, level: int) -> String:
	if level >= MAX_UPGRADE_LEVEL:
		return title + "  |  Seviye " + str(level) + "/5  |  MAX"
	return title + "  |  Seviye " + str(level) + "/5  |  $" + str(UPGRADE_COSTS[level])


func _can_afford_level(level: int) -> bool:
	if level >= MAX_UPGRADE_LEVEL:
		return false
	return money >= UPGRADE_COSTS[level]


func update_money_label() -> void:
	money_label.text = "$" + str(money)
