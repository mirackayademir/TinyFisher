extends CanvasLayer

@export var max_fish_capacity: int = 8

const SARDALYA_TEXTURE = preload("res://assets/sardalya.png")
const LEVREK_TEXTURE = preload("res://assets/levrek2.png")
const USKUMRU_TEXTURE = preload("res://assets/uskumru.png")
const TON_BALIGI_TEXTURE = preload("res://assets/tonbaligi.png")

@onready var count_label_1: Label = $InventoryPanel/InventorySlots/Slot1/CountLabel
@onready var count_label_2: Label = $InventoryPanel/InventorySlots/Slot2/CountLabel
@onready var count_label_3: Label = $InventoryPanel/InventorySlots/Slot3/CountLabel
@onready var count_label_4: Label = $InventoryPanel/InventorySlots/Slot4/CountLabel

@onready var fight_panel: Panel = $FightPanel
@onready var fight_bar: ProgressBar = $FightPanel/FightBar
@onready var fish_marker: ColorRect = $FightPanel/FightBar/FishMarker
@onready var catch_zone: ColorRect = $FightPanel/FightBar/CatchZone

@onready var catch_popup: Control = $CatchPopup
@onready var catch_card: Panel = $CatchPopup/Card
@onready var catch_fish_icon: TextureRect = $CatchPopup/FishIcon
@onready var catch_name_label: Label = $CatchPopup/Name
@onready var catch_glow: ColorRect = $CatchPopup/Glow

var fight_active: bool = false
var fight_won: bool = false
var fight_ease_level: int = 0

var fish_target_x: float = 0.0
var fish_move_speed: float = 120.0
var fish_change_interval: float = 0.8
var fish_change_timer: float = 0.0

var fight_gain_speed: float = 30.0
var fight_loss_speed: float = 18.0
var _catch_tween: Tween

var inventory: Dictionary = {
	"Sardalya": 0,
	"Levrek": 0,
	"Uskumru": 0,
	"Ton Balığı": 0
}


func _ready() -> void:
	update_inventory()

	# HUD elemanları balık tutma tıklamalarını yutmasın.
	for control in find_children("*", "Control", true, false):
		control.mouse_filter = Control.MOUSE_FILTER_IGNORE

	fight_panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	fight_bar.min_value = 0.0
	fight_bar.max_value = 100.0
	fight_bar.show_percentage = false

	var catch_style := StyleBoxFlat.new()
	catch_style.bg_color = Color(0.025, 0.07, 0.12, 0.94)
	catch_style.border_color = Color(0.92, 0.61, 0.20, 1.0)
	catch_style.border_width_left = 4
	catch_style.border_width_top = 4
	catch_style.border_width_right = 4
	catch_style.border_width_bottom = 4
	catch_style.corner_radius_top_left = 8
	catch_style.corner_radius_top_right = 8
	catch_style.corner_radius_bottom_left = 8
	catch_style.corner_radius_bottom_right = 8
	catch_card.add_theme_stylebox_override("panel", catch_style)

	layout_fight_bar()
	layout_catch_popup()
	reset_fight()
	catch_popup.visible = false


func _process(delta: float) -> void:
	if not fight_active:
		return

	move_catch_zone()
	move_fish_marker(delta)
	update_fight_progress(delta)


func layout_fight_bar() -> void:
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	fight_bar.position = Vector2(
		maxf((viewport_size.x - fight_bar.size.x) * 0.5, 0.0),
		70.0
	)

	fish_marker.position.y = 0.0
	fish_marker.size.y = fight_bar.size.y
	catch_zone.position.y = 0.0
	catch_zone.size.y = fight_bar.size.y


func layout_catch_popup() -> void:
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	catch_popup.position = Vector2(
		maxf((viewport_size.x - catch_popup.size.x) * 0.5, 0.0),
		maxf((viewport_size.y - catch_popup.size.y) * 0.43, 0.0)
	)
	catch_popup.pivot_offset = catch_popup.size * 0.5
	catch_fish_icon.pivot_offset = catch_fish_icon.size * 0.5


func move_catch_zone() -> void:
	var mouse_x: float = fight_bar.get_local_mouse_position().x
	var max_x: float = maxf(fight_bar.size.x - catch_zone.size.x, 0.0)

	catch_zone.position.x = clampf(
		mouse_x - catch_zone.size.x * 0.5,
		0.0,
		max_x
	)


func move_fish_marker(delta: float) -> void:
	fish_change_timer -= delta

	if fish_change_timer <= 0.0:
		var max_x: float = maxf(fight_bar.size.x - fish_marker.size.x, 0.0)
		fish_target_x = randf_range(0.0, max_x)
		fish_change_timer = fish_change_interval

	fish_marker.position.x = move_toward(
		fish_marker.position.x,
		fish_target_x,
		fish_move_speed * delta
	)


func update_fight_progress(delta: float) -> void:
	if not fight_active:
		return

	var fish_left: float = fish_marker.position.x
	var fish_right: float = fish_marker.position.x + fish_marker.size.x
	var zone_left: float = catch_zone.position.x
	var zone_right: float = catch_zone.position.x + catch_zone.size.x

	var fish_inside_zone: bool = fish_right >= zone_left and fish_left <= zone_right
	var reeling: bool = (
		Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
		or Input.is_physical_key_pressed(KEY_W)
	)

	if fish_inside_zone and reeling:
		fight_bar.value += fight_gain_speed * delta
	else:
		fight_bar.value -= fight_loss_speed * delta

	fight_bar.value = clampf(fight_bar.value, 0.0, 100.0)

	if fight_bar.value >= 100.0:
		fight_won = true
		fight_active = false
		fight_panel.visible = false
		print("MÜCADELE KAZANILDI!")


func show_fight_bar(fish_type: String) -> void:
	layout_fight_bar()
	fight_panel.visible = true
	fight_active = true
	fight_won = false
	fight_bar.value = 10.0
	fish_change_timer = 0.0

	var zone_width: float = 70.0

	match fish_type:
		"Sardalya":
			fish_move_speed = 90.0
			fish_change_interval = 1.0
			fight_gain_speed = 35.0
			fight_loss_speed = 12.0
			zone_width = 85.0

		"Levrek":
			fish_move_speed = 140.0
			fish_change_interval = 0.70
			fight_gain_speed = 30.0
			fight_loss_speed = 18.0
			zone_width = 70.0

		"Uskumru":
			fish_move_speed = 200.0
			fish_change_interval = 0.45
			fight_gain_speed = 25.0
			fight_loss_speed = 24.0
			zone_width = 60.0

		"Ton Balığı":
			fish_move_speed = 260.0
			fish_change_interval = 0.30
			fight_gain_speed = 21.0
			fight_loss_speed = 30.0
			zone_width = 50.0

		_:
			fish_move_speed = 120.0
			fish_change_interval = 0.8
			fight_gain_speed = 30.0
			fight_loss_speed = 18.0
			zone_width = 70.0

	# Mücadele Desteği yükseldikçe balık biraz sakinleşir,
	# yeşil alan genişler ve ilerleme daha affedici olur.
	var ease_multiplier := maxf(0.58, 1.0 - float(fight_ease_level) * 0.08)
	fish_move_speed *= ease_multiplier
	fight_gain_speed += float(fight_ease_level) * 2.0
	fight_loss_speed = maxf(8.0, fight_loss_speed - float(fight_ease_level) * 2.0)
	zone_width += float(fight_ease_level) * 8.0

	fish_marker.size = Vector2(24.0, fight_bar.size.y)
	catch_zone.size = Vector2(zone_width, fight_bar.size.y)

	fish_marker.position.x = 20.0
	catch_zone.position.x = clampf(
		fight_bar.size.x * 0.5 - catch_zone.size.x * 0.5,
		0.0,
		maxf(fight_bar.size.x - catch_zone.size.x, 0.0)
	)


func set_capacity_level(level: int) -> void:
	max_fish_capacity = 8 + (level * 2)


func set_fight_ease_level(level: int) -> void:
	fight_ease_level = level


func is_fight_won() -> bool:
	return fight_won


func reset_fight() -> void:
	fight_active = false
	fight_won = false
	fight_panel.visible = false
	fight_bar.value = 0.0


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
	show_catch_effect(fish_type)
	return true


func show_catch_effect(fish_type: String) -> void:
	if is_instance_valid(_catch_tween):
		_catch_tween.kill()

	layout_catch_popup()
	catch_name_label.text = fish_type
	catch_fish_icon.texture = _get_fish_texture(fish_type)
	catch_popup.visible = true
	catch_popup.modulate = Color.WHITE
	catch_popup.scale = Vector2(0.72, 0.72)
	catch_fish_icon.rotation = 0.0
	catch_fish_icon.modulate = Color(1.55, 1.38, 0.72, 1.0)
	catch_glow.color = Color(1.0, 0.72, 0.20, 0.12)

	_catch_tween = create_tween()
	_catch_tween.set_trans(Tween.TRANS_BACK)
	_catch_tween.set_ease(Tween.EASE_OUT)
	_catch_tween.tween_property(catch_popup, "scale", Vector2.ONE, 0.20)
	_catch_tween.parallel().tween_property(catch_fish_icon, "modulate", Color.WHITE, 0.38)
	_catch_tween.parallel().tween_property(catch_glow, "color", Color(1.0, 0.78, 0.25, 0.36), 0.22)
	_catch_tween.tween_property(catch_fish_icon, "rotation", deg_to_rad(5.0), 0.07)
	_catch_tween.tween_property(catch_fish_icon, "rotation", deg_to_rad(-5.0), 0.07)
	_catch_tween.tween_property(catch_fish_icon, "rotation", 0.0, 0.08)
	_catch_tween.tween_interval(0.85)
	_catch_tween.tween_property(catch_popup, "modulate", Color(1, 1, 1, 0), 0.32)
	_catch_tween.finished.connect(_hide_catch_popup)


func _hide_catch_popup() -> void:
	catch_popup.visible = false
	catch_popup.modulate = Color.WHITE
	catch_popup.scale = Vector2.ONE


func _get_fish_texture(fish_type: String) -> Texture2D:
	match fish_type:
		"Levrek":
			return LEVREK_TEXTURE
		"Uskumru":
			return USKUMRU_TEXTURE
		"Ton Balığı":
			return TON_BALIGI_TEXTURE
		_:
			return SARDALYA_TEXTURE


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
