extends CanvasLayer

@export var max_fish_capacity: int = 8
@export var catch_zone_speed: float = 260.0

@onready var count_label_1: Label = $InventoryPanel/InventorySlots/Slot1/CountLabel
@onready var count_label_2: Label = $InventoryPanel/InventorySlots/Slot2/CountLabel
@onready var count_label_3: Label = $InventoryPanel/InventorySlots/Slot3/CountLabel
@onready var count_label_4: Label = $InventoryPanel/InventorySlots/Slot4/CountLabel

@onready var fight_panel: Panel = $FightPanel
@onready var fight_bar: ProgressBar = $FightPanel/FightBar
@onready var fish_marker: ColorRect = $FightPanel/FightBar/FishMarker
@onready var catch_zone: ColorRect = $FightPanel/FightBar/CatchZone

var fight_active: bool = false
var fight_won: bool = false

var fish_target_x: float = 0.0
var fish_move_speed: float = 120.0
var fish_change_interval: float = 0.8
var fish_change_timer: float = 0.0

var fight_gain_speed: float = 30.0
var fight_loss_speed: float = 18.0

var inventory: Dictionary = {
	"Sardalya": 0,
	"Levrek": 0,
	"Uskumru": 0,
	"Ton Balığı": 0
}


func _ready() -> void:
	update_inventory()
	# HUD overlays must not consume the fishing mouse buttons.
	for control in find_children("*", "Control", true, false):
		control.mouse_filter = Control.MOUSE_FILTER_IGNORE

	fight_panel.visible = false
	fight_active = false
	fight_won = false


func _process(delta: float) -> void:
	if not fight_active:
		return

	move_catch_zone(delta)
	move_fish_marker(delta)
	update_fight_progress(delta)


func move_catch_zone(delta: float) -> void:
	var direction: float = Input.get_axis("move_left", "move_right")
	if not is_zero_approx(direction):
		catch_zone.position.x += direction * catch_zone_speed * delta
	else:
		catch_zone.position.x = fight_bar.get_local_mouse_position().x - catch_zone.size.x * 0.5

	var max_x: float = fight_bar.size.x - catch_zone.size.x

	catch_zone.position.x = clamp(
		catch_zone.position.x,
		0.0,
		max_x
	)


func move_fish_marker(delta: float) -> void:
	fish_change_timer -= delta

	if fish_change_timer <= 0.0:
		var max_x: float = fight_bar.size.x - fish_marker.size.x

		fish_target_x = randf_range(0.0, max_x)
		fish_change_timer = fish_change_interval

	fish_marker.position.x = move_toward(
		fish_marker.position.x,
		fish_target_x,
		fish_move_speed * delta
	)


func update_fight_progress(delta: float) -> void:
	var fish_left: float = fish_marker.position.x
	var fish_right: float = fish_marker.position.x + fish_marker.size.x

	var zone_left: float = catch_zone.position.x
	var zone_right: float = catch_zone.position.x + catch_zone.size.x

	var fish_inside_zone: bool = (
		fish_right >= zone_left
		and fish_left <= zone_right
	)

	var reeling: bool = Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or Input.is_physical_key_pressed(KEY_W)
	if fish_inside_zone and reeling:
		fight_bar.value += fight_gain_speed * delta
	else:
		fight_bar.value -= fight_loss_speed * delta

	fight_bar.value = clamp(fight_bar.value, 0.0, 100.0)

	if fight_bar.value >= 100.0:
		fight_won = true
		fight_active = false
		fight_panel.visible = false

		print("MÜCADELE KAZANILDI!")


func show_fight_bar(fish_type: String) -> void:
	fight_panel.visible = true
	fight_active = true
	fight_won = false

	fight_bar.value = 0.0

	catch_zone.position.x = 100.0
	fish_marker.position.x = 20.0

	fish_change_timer = 0.0

	match fish_type:
		"Sardalya":
			fish_move_speed = 90.0
			fish_change_interval = 1.0
			fight_gain_speed = 35.0
			fight_loss_speed = 12.0
			catch_zone.size.x = 85.0

		"Levrek":
			fish_move_speed = 140.0
			fish_change_interval = 0.70
			fight_gain_speed = 30.0
			fight_loss_speed = 18.0
			catch_zone.size.x = 70.0

		"Uskumru":
			fish_move_speed = 200.0
			fish_change_interval = 0.45
			fight_gain_speed = 25.0
			fight_loss_speed = 24.0
			catch_zone.size.x = 60.0

		"Ton Balığı":
			fish_move_speed = 260.0
			fish_change_interval = 0.30
			fight_gain_speed = 21.0
			fight_loss_speed = 30.0
			catch_zone.size.x = 50.0


func is_fight_won() -> bool:
	return fight_won


func reset_fight() -> void:
	fight_active = false
	fight_won = false
	fight_panel.visible = false


func get_total_fish() -> int:
	var total: int = 0

	for amount in inventory.values():
		total += amount

	return total


func can_add_fish() -> bool:
	return get_total_fish() < max_fish_capacity


func add_fish(fish_type: String) -> bool:
	if not can_add_fish():
		return false

	if not inventory.has(fish_type):
		inventory[fish_type] = 0

	inventory[fish_type] += 1
	update_inventory()

	return true


func update_inventory() -> void:
	count_label_1.text = ""
	count_label_2.text = ""
	count_label_3.text = ""
	count_label_4.text = ""

	var sardalya_count: int = inventory.get("Sardalya", 0)
	var levrek_count: int = inventory.get("Levrek", 0)
	var uskumru_count: int = inventory.get("Uskumru", 0)
	var ton_baligi_count: int = inventory.get("Ton Balığı", 0)

	if sardalya_count > 0:
		count_label_1.text = str(sardalya_count)

	if levrek_count > 0:
		count_label_2.text = str(levrek_count)

	if uskumru_count > 0:
		count_label_3.text = str(uskumru_count)

	if ton_baligi_count > 0:
		count_label_4.text = str(ton_baligi_count)
