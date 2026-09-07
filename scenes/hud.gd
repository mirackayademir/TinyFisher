extends CanvasLayer

@export var max_fish_capacity: int = 8

const SARDALYA_TEXTURE = preload("res://assets/sardalya.png")
const LEVREK_TEXTURE = preload("res://assets/levrek2.png")
const USKUMRU_TEXTURE = preload("res://assets/uskumru.png")
const TON_BALIGI_TEXTURE = preload("res://assets/tonbaligi.png")

@onready var inventory_panel: Panel = $InventoryPanel
@onready var inventory_slots: HBoxContainer = $InventoryPanel/InventorySlots
@onready var slot_1: Panel = $InventoryPanel/InventorySlots/Slot1
@onready var slot_2: Panel = $InventoryPanel/InventorySlots/Slot2
@onready var slot_3: Panel = $InventoryPanel/InventorySlots/Slot3
@onready var slot_4: Panel = $InventoryPanel/InventorySlots/Slot4
@onready var fish_icon_1: TextureRect = $InventoryPanel/InventorySlots/Slot1/FishIcon
@onready var fish_icon_2: TextureRect = $InventoryPanel/InventorySlots/Slot2/FishIcon
@onready var fish_icon_3: TextureRect = $InventoryPanel/InventorySlots/Slot3/FishIcon
@onready var fish_icon_4: TextureRect = $InventoryPanel/InventorySlots/Slot4/FishIcon
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
@onready var catch_title_label: Label = $CatchPopup/Title
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
var _fight_time: float = 0.0
var _fight_title: Label
var _fight_hint: Label
var _catch_status: Label
var _catch_sparks: Array = []

var inventory: Dictionary = {
	"Sardalya": 0,
	"Levrek": 0,
	"Uskumru": 0,
	"Ton Balığı": 0
}


func _ready() -> void:
	_setup_inventory_visuals()
	update_inventory()

	for control in find_children("*", "Control", true, false):
		control.mouse_filter = Control.MOUSE_FILTER_IGNORE

	_setup_fight_visuals()
	_setup_catch_visuals()
	layout_fight_bar()
	layout_catch_popup()
	reset_fight()
	catch_popup.visible = false


func _setup_inventory_visuals() -> void:
	inventory_panel.position = Vector2(14.0, 14.0)
	inventory_panel.size = Vector2(310.0, 78.0)
	inventory_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.018, 0.055, 0.09, 0.90)
	panel_style.border_color = Color(0.18, 0.48, 0.62, 0.92)
	panel_style.border_width_left = 2
	panel_style.border_width_top = 2
	panel_style.border_width_right = 2
	panel_style.border_width_bottom = 2
	panel_style.corner_radius_top_left = 7
	panel_style.corner_radius_top_right = 7
	panel_style.corner_radius_bottom_left = 7
	panel_style.corner_radius_bottom_right = 7
	inventory_panel.add_theme_stylebox_override("panel", panel_style)

	inventory_slots.position = Vector2(7.0, 7.0)
	inventory_slots.add_theme_constant_override("separation", 6)

	var slots: Array[Panel] = [slot_1, slot_2, slot_3, slot_4]
	var icons: Array[TextureRect] = [fish_icon_1, fish_icon_2, fish_icon_3, fish_icon_4]
	var labels: Array[Label] = [count_label_1, count_label_2, count_label_3, count_label_4]
	var textures: Array[Texture2D] = [SARDALYA_TEXTURE, LEVREK_TEXTURE, USKUMRU_TEXTURE, TON_BALIGI_TEXTURE]

	for i in range(4):
		var slot := slots[i]
		var icon := icons[i]
		var label := labels[i]

		slot.custom_minimum_size = Vector2(68.0, 64.0)
		var slot_style := StyleBoxFlat.new()
		slot_style.bg_color = Color(0.025, 0.09, 0.14, 0.92)
		slot_style.border_color = Color(0.16, 0.34, 0.43, 0.95)
		slot_style.border_width_left = 2
		slot_style.border_width_top = 2
		slot_style.border_width_right = 2
		slot_style.border_width_bottom = 2
		slot_style.corner_radius_top_left = 5
		slot_style.corner_radius_top_right = 5
		slot_style.corner_radius_bottom_left = 5
		slot_style.corner_radius_bottom_right = 5
		slot.add_theme_stylebox_override("panel", slot_style)

		icon.texture = textures[i]
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.modulate = Color(1.08, 1.08, 1.08, 1.0)

		label.add_theme_font_size_override("font_size", 18)
		label.add_theme_color_override("font_color", Color.WHITE)
		label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 1))
		label.add_theme_constant_override("shadow_offset_x", 2)
		label.add_theme_constant_override("shadow_offset_y", 2)


func _process(delta: float) -> void:
	_fight_time += delta

	if not fight_active:
		return

	move_catch_zone()
	move_fish_marker(delta)
	update_fight_progress(delta)

	fish_marker.modulate.a = 0.78 + sin(_fight_time * 8.0) * 0.18
	catch_zone.modulate.a = 0.70 + sin(_fight_time * 5.0 + 0.8) * 0.14


func _setup_fight_visuals() -> void:
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.018, 0.055, 0.095, 0.94)
	panel_style.border_color = Color(0.19, 0.63, 0.78, 0.95)
	panel_style.border_width_left = 3
	panel_style.border_width_top = 3
	panel_style.border_width_right = 3
	panel_style.border_width_bottom = 3
	panel_style.corner_radius_top_left = 10
	panel_style.corner_radius_top_right = 10
	panel_style.corner_radius_bottom_left = 10
	panel_style.corner_radius_bottom_right = 10
	fight_panel.add_theme_stylebox_override("panel", panel_style)

	var bar_bg := StyleBoxFlat.new()
	bar_bg.bg_color = Color(0.025, 0.09, 0.14, 1.0)
	bar_bg.border_color = Color(0.10, 0.28, 0.36, 1.0)
	bar_bg.border_width_left = 2
	bar_bg.border_width_top = 2
	bar_bg.border_width_right = 2
	bar_bg.border_width_bottom = 2
	bar_bg.corner_radius_top_left = 6
	bar_bg.corner_radius_top_right = 6
	bar_bg.corner_radius_bottom_left = 6
	bar_bg.corner_radius_bottom_right = 6
	fight_bar.add_theme_stylebox_override("background", bar_bg)

	var bar_fill := StyleBoxFlat.new()
	bar_fill.bg_color = Color(0.16, 0.68, 0.79, 0.92)
	bar_fill.corner_radius_top_left = 5
	bar_fill.corner_radius_top_right = 5
	bar_fill.corner_radius_bottom_left = 5
	bar_fill.corner_radius_bottom_right = 5
	fight_bar.add_theme_stylebox_override("fill", bar_fill)
	fight_bar.min_value = 0.0
	fight_bar.max_value = 100.0
	fight_bar.show_percentage = false

	fish_marker.color = Color(1.0, 0.57, 0.16, 0.95)
	catch_zone.color = Color(0.18, 0.95, 0.55, 0.60)

	_fight_title = fight_panel.get_node_or_null("FightTitle") as Label
	if _fight_title == null:
		_fight_title = Label.new()
		_fight_title.name = "FightTitle"
		fight_panel.add_child(_fight_title)
	_fight_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fight_title.add_theme_font_size_override("font_size", 22)
	_fight_title.add_theme_color_override("font_color", Color(1.0, 0.82, 0.40, 1.0))
	_fight_title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	_fight_title.add_theme_constant_override("shadow_offset_x", 2)
	_fight_title.add_theme_constant_override("shadow_offset_y", 2)
	_fight_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	_fight_hint = fight_panel.get_node_or_null("FightHint") as Label
	if _fight_hint == null:
		_fight_hint = Label.new()
		_fight_hint.name = "FightHint"
		fight_panel.add_child(_fight_hint)
	_fight_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fight_hint.text = "Yeşil alanı balığın üstünde tut ve SAR"
	_fight_hint.add_theme_font_size_override("font_size", 13)
	_fight_hint.add_theme_color_override("font_color", Color(0.78, 0.92, 0.96, 0.9))
	_fight_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


func _setup_catch_visuals() -> void:
	var catch_style := StyleBoxFlat.new()
	catch_style.bg_color = Color(0.018, 0.052, 0.09, 0.96)
	catch_style.border_color = Color(1.0, 0.64, 0.18, 1.0)
	catch_style.border_width_left = 5
	catch_style.border_width_top = 5
	catch_style.border_width_right = 5
	catch_style.border_width_bottom = 5
	catch_style.corner_radius_top_left = 12
	catch_style.corner_radius_top_right = 12
	catch_style.corner_radius_bottom_left = 12
	catch_style.corner_radius_bottom_right = 12
	catch_card.add_theme_stylebox_override("panel", catch_style)

	catch_title_label.add_theme_font_size_override("font_size", 42)
	catch_name_label.add_theme_font_size_override("font_size", 28)
	catch_fish_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	_catch_status = catch_popup.get_node_or_null("CatchStatus") as Label
	if _catch_status == null:
		_catch_status = Label.new()
		_catch_status.name = "CatchStatus"
		catch_popup.add_child(_catch_status)
	_catch_status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_catch_status.text = "ENVANTERE EKLENDİ"
	_catch_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_catch_status.add_theme_font_size_override("font_size", 15)
	_catch_status.add_theme_color_override("font_color", Color(0.55, 0.92, 0.78, 0.95))

	_catch_sparks.clear()
	for spark in catch_popup.find_children("Spark*", "ColorRect", false, false):
		spark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		spark.pivot_offset = spark.size * 0.5
		_catch_sparks.append(spark)


func layout_fight_bar() -> void:
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var panel_size := Vector2(540.0, 138.0)
	fight_panel.position = Vector2(maxf((viewport_size.x - panel_size.x) * 0.5, 0.0), 34.0)
	fight_panel.size = panel_size

	_fight_title.position = Vector2(24.0, 12.0)
	_fight_title.size = Vector2(panel_size.x - 48.0, 30.0)
	_fight_hint.position = Vector2(24.0, 105.0)
	_fight_hint.size = Vector2(panel_size.x - 48.0, 22.0)

	fight_bar.position = Vector2(42.0, 58.0)
	fight_bar.size = Vector2(456.0, 36.0)
	fish_marker.position.y = 2.0
	fish_marker.size.y = 32.0
	catch_zone.position.y = 2.0
	catch_zone.size.y = 32.0


func layout_catch_popup() -> void:
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	catch_popup.size = Vector2(560.0, 340.0)
	catch_popup.position = Vector2(
		maxf((viewport_size.x - catch_popup.size.x) * 0.5, 0.0),
		maxf((viewport_size.y - catch_popup.size.y) * 0.43, 0.0)
	)
	catch_popup.pivot_offset = catch_popup.size * 0.5

	catch_title_label.position = Vector2(20.0, 18.0)
	catch_title_label.size = Vector2(520.0, 54.0)
	catch_glow.position = Vector2(126.0, 78.0)
	catch_glow.size = Vector2(308.0, 174.0)
	catch_fish_icon.position = Vector2(142.0, 82.0)
	catch_fish_icon.size = Vector2(276.0, 164.0)
	catch_fish_icon.pivot_offset = catch_fish_icon.size * 0.5
	catch_name_label.position = Vector2(20.0, 248.0)
	catch_name_label.size = Vector2(520.0, 40.0)
	_catch_status.position = Vector2(20.0, 292.0)
	_catch_status.size = Vector2(520.0, 24.0)


func move_catch_zone() -> void:
	var mouse_x: float = fight_bar.get_local_mouse_position().x
	var max_x: float = maxf(fight_bar.size.x - catch_zone.size.x, 0.0)
	catch_zone.position.x = clampf(mouse_x - catch_zone.size.x * 0.5, 0.0, max_x)


func move_fish_marker(delta: float) -> void:
	fish_change_timer -= delta

	if fish_change_timer <= 0.0:
		var max_x: float = maxf(fight_bar.size.x - fish_marker.size.x, 0.0)
		fish_target_x = randf_range(0.0, max_x)
		fish_change_timer = fish_change_interval

	fish_marker.position.x = move_toward(fish_marker.position.x, fish_target_x, fish_move_speed * delta)


func update_fight_progress(delta: float) -> void:
	if not fight_active:
		return

	var fish_left: float = fish_marker.position.x
	var fish_right: float = fish_marker.position.x + fish_marker.size.x
	var zone_left: float = catch_zone.position.x
	var zone_right: float = catch_zone.position.x + catch_zone.size.x
	var fish_inside_zone: bool = fish_right >= zone_left and fish_left <= zone_right
	var reeling: bool = Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or Input.is_physical_key_pressed(KEY_W)

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
	_fight_title.text = fish_type.to_upper() + "  •  MÜCADELE"

	var zone_width: float = 88.0

	match fish_type:
		"Sardalya":
			fish_move_speed = 95.0
			fish_change_interval = 1.0
			fight_gain_speed = 36.0
			fight_loss_speed = 11.0
			zone_width = 112.0

		"Levrek":
			fish_move_speed = 145.0
			fish_change_interval = 0.70
			fight_gain_speed = 31.0
			fight_loss_speed = 17.0
			zone_width = 92.0

		"Uskumru":
			fish_move_speed = 205.0
			fish_change_interval = 0.46
			fight_gain_speed = 26.0
			fight_loss_speed = 23.0
			zone_width = 76.0

		"Ton Balığı":
			fish_move_speed = 265.0
			fish_change_interval = 0.32
			fight_gain_speed = 22.0
			fight_loss_speed = 29.0
			zone_width = 64.0

		_:
			fish_move_speed = 125.0
			fish_change_interval = 0.8
			fight_gain_speed = 30.0
			fight_loss_speed = 18.0
			zone_width = 88.0

	var ease_multiplier := maxf(0.58, 1.0 - float(fight_ease_level) * 0.08)
	fish_move_speed *= ease_multiplier
	fight_gain_speed += float(fight_ease_level) * 2.0
	fight_loss_speed = maxf(8.0, fight_loss_speed - float(fight_ease_level) * 2.0)
	zone_width += float(fight_ease_level) * 10.0

	fish_marker.size = Vector2(28.0, 32.0)
	catch_zone.size = Vector2(zone_width, 32.0)
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
	catch_popup.scale = Vector2(0.58, 0.58)
	catch_popup.rotation = deg_to_rad(-1.8)
	catch_fish_icon.rotation = deg_to_rad(-5.0)
	catch_fish_icon.scale = Vector2(0.78, 0.78)
	catch_fish_icon.modulate = Color(1.7, 1.48, 0.76, 1.0)
	catch_glow.color = Color(1.0, 0.67, 0.12, 0.06)

	for spark in _catch_sparks:
		spark.scale = Vector2(0.15, 0.15)
		spark.modulate.a = 0.0

	_catch_tween = create_tween()
	_catch_tween.set_trans(Tween.TRANS_BACK)
	_catch_tween.set_ease(Tween.EASE_OUT)
	_catch_tween.tween_property(catch_popup, "scale", Vector2.ONE, 0.24)
	_catch_tween.parallel().tween_property(catch_popup, "rotation", 0.0, 0.24)
	_catch_tween.parallel().tween_property(catch_fish_icon, "scale", Vector2.ONE, 0.28)
	_catch_tween.parallel().tween_property(catch_fish_icon, "modulate", Color.WHITE, 0.42)
	_catch_tween.parallel().tween_property(catch_glow, "color", Color(1.0, 0.77, 0.18, 0.34), 0.24)

	for i in range(_catch_sparks.size()):
		var spark = _catch_sparks[i]
		_catch_tween.parallel().tween_property(spark, "modulate:a", 1.0, 0.10).set_delay(0.03 * i)
		_catch_tween.parallel().tween_property(spark, "scale", Vector2(1.65, 1.65), 0.18).set_delay(0.03 * i)

	_catch_tween.tween_property(catch_fish_icon, "rotation", deg_to_rad(4.0), 0.08)
	_catch_tween.tween_property(catch_fish_icon, "rotation", deg_to_rad(-4.0), 0.08)
	_catch_tween.tween_property(catch_fish_icon, "rotation", 0.0, 0.09)
	_catch_tween.tween_interval(1.05)
	_catch_tween.tween_property(catch_popup, "scale", Vector2(1.05, 1.05), 0.08)
	_catch_tween.tween_property(catch_popup, "modulate", Color(1, 1, 1, 0), 0.30)
	_catch_tween.finished.connect(_hide_catch_popup)


func _hide_catch_popup() -> void:
	catch_popup.visible = false
	catch_popup.modulate = Color.WHITE
	catch_popup.scale = Vector2.ONE
	catch_popup.rotation = 0.0


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
