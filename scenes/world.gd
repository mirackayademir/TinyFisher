extends Node2D

const MAX_UPGRADE_LEVEL: int = 5
const UPGRADE_COSTS: Array[int] = [50, 100, 175, 275, 400]

@onready var dock_prompt: Label = $DockPrompt
@onready var dock_menu: Panel = $DockMenu
@onready var upgrade_menu: Panel = $UpgradeMenu
@onready var boat: CharacterBody2D = $Boat
@onready var hook = $Boat/Hook
@onready var money_label: Label = $MoneyLabel
@onready var hud = $HUD

@onready var boat_speed_button: Button = $UpgradeMenu/BoatSpeedButton
@onready var rod_speed_button: Button = $UpgradeMenu/RodSpeedButton
@onready var capacity_button: Button = $UpgradeMenu/CapacityButton
@onready var fight_ease_button: Button = $UpgradeMenu/FightEaseButton
@onready var upgrade_info_label: Label = $UpgradeMenu/InfoLabel

var boat_in_dock_area: bool = false
var docked: bool = false

var money: int = 0

var boat_speed_level: int = 0
var rod_speed_level: int = 0
var capacity_level: int = 0
var fight_ease_level: int = 0


func _ready() -> void:
	dock_prompt.visible = false
	dock_menu.visible = false
	upgrade_menu.visible = false
	_apply_upgrades()
	update_money_label()
	_refresh_upgrade_menu()


func _process(_delta: float) -> void:
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

	var total_fish: int = (
		sardalya_count
		+ levrek_count
		+ uskumru_count
		+ ton_baligi_count
	)

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
