extends Node2D

@onready var dock_prompt: Label = $DockPrompt
@onready var dock_menu: Panel = $DockMenu
@onready var boat: CharacterBody2D = $Boat
@onready var money_label: Label = $MoneyLabel
@onready var hud = $HUD

var boat_in_dock_area: bool = false
var docked: bool = false

var money: int = 0


func _ready() -> void:
	dock_prompt.visible = false
	dock_menu.visible = false
	update_money_label()


func _process(_delta: float) -> void:
	if boat_in_dock_area and Input.is_action_just_pressed("dock") and not docked and not $Boat/Hook.deployed:
		docked = true
		boat.set_movement_enabled(false)

		dock_prompt.visible = false
		dock_menu.visible = true
		$Boat/Camera2D.position.y = $Boat/Hook.camera_surface_y

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

	print("BALIKLAR SATILDI! +$", total_value)


func update_money_label() -> void:
	money_label.text = "$" + str(money)
