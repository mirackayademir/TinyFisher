extends Node2D

const MAX_UPGRADE_LEVEL: int = 5
const UPGRADE_COSTS: Array[int] = [50, 100, 175, 275, 400]
const WATER_SURFACE_Y: float = 360.0
const CAMERA_NORMAL_X: float = 350.0
const CAMERA_HARBOR_X: float = -160.0
const BASE_DEPTH_METERS: int = 50
const DEPTH_METERS_PER_LEVEL: int = 10

const FISH_ORDER: Array[String] = [
	"Sardalya",
	"Levrek",
	"Uskumru",
	"Ton Balığı",
	"Kılıç Balığı",
	"Köpekbalığı",
	"Fener Balığı"
]

const SARDALYA_TEXTURE: Texture2D = preload("res://assets/sardalya.png")
const LEVREK_TEXTURE: Texture2D = preload("res://assets/levrek2.png")
const USKUMRU_TEXTURE: Texture2D = preload("res://assets/uskumru.png")
const TON_BALIGI_TEXTURE: Texture2D = preload("res://assets/tonbaligi.png")
const KILIC_BALIGI_TEXTURE: Texture2D = preload("res://assets/kilic_baligi.svg")
const KOPEKBALIGI_TEXTURE: Texture2D = preload("res://assets/kopekbaligi.svg")
const FENER_BALIGI_TEXTURE: Texture2D = preload("res://assets/fener_baligi.svg")

@onready var dock_prompt: Label = $DockPrompt
@onready var dock_menu: Panel = $DockMenu
@onready var dock_menu_vbox: VBoxContainer = $DockMenu/VBoxContainer
@onready var dock_sell_button: Button = $DockMenu/VBoxContainer/SellButton
@onready var dock_upgrade_button: Button = $DockMenu/VBoxContainer/UpgradeButton
@onready var dock_leave_button: Button = $DockMenu/VBoxContainer/LeaveButton
@onready var upgrade_menu: Panel = $UpgradeMenu
@onready var dock_sprite: Sprite2D = $Dock
@onready var dock_collision: CollisionShape2D = $DockArea/CollisionShape2D
@onready var boat: CharacterBody2D = $Boat
@onready var boat_camera: Camera2D = $Boat/Camera2D
@onready var hook = $Boat/Hook
@onready var money_label: Label = $MoneyLabel
@onready var hud = $HUD

@onready var boat_speed_button: Button = $UpgradeMenu/BoatSpeedButton
@onready var rod_speed_button: Button = $UpgradeMenu/RodSpeedButton
@onready var capacity_button: Button = $UpgradeMenu/CapacityButton
@onready var fight_ease_button: Button = $UpgradeMenu/FightEaseButton
@onready var upgrade_info_label: Label = $UpgradeMenu/InfoLabel
@onready var upgrade_back_button: Button = $UpgradeMenu/BackButton

var boat_in_dock_area: bool = false
var docked: bool = false
var money: int = 0
var money_panel: Panel
var depth_button: Button
var line_strength_button: Button
var fish_book_button: Button

var fish_book_panel: Panel
var fish_book_grid: GridContainer
var fish_book_progress: Label
var fish_book_back_button: Button
var fish_book_icons: Dictionary = {}
var fish_book_titles: Dictionary = {}
var fish_book_details: Dictionary = {}

var boat_speed_level: int = 0
var rod_speed_level: int = 0
var depth_level: int = 0
var capacity_level: int = 0
var fight_ease_level: int = 0
var line_strength_level: int = 0

var _sea_time: float = 0.0
var _surface_shadow: Line2D
var _surface_foam: Line2D
var _camera_tween: Tween

var discovered_fish: Dictionary = {
	"Sardalya": false,
	"Levrek": false,
	"Uskumru": false,
	"Ton Balığı": false,
	"Kılıç Balığı": false,
	"Köpekbalığı": false,
	"Fener Balığı": false
}


func _ready() -> void:
	dock_prompt.visible = false
	dock_menu.visible = false
	upgrade_menu.visible = false
	_setup_harbor()
	_setup_fish_book_button()
	_setup_dock_menu()
	_setup_upgrade_buttons()
	_setup_fish_book_ui()
	_setup_surface_waves()
	_setup_money_hud()
	_setup_inventory_discovery()
	_apply_upgrades()
	update_money_label()
	_refresh_upgrade_menu()


func _setup_harbor() -> void:
	# Onaylanan büyük liman boyutuna dokunmuyoruz.
	dock_sprite.scale = Vector2(7.8, 7.8)
	dock_sprite.position = Vector2(310.0, 250.0)
	boat.min_world_x = 520.0

	dock_collision.position = Vector2(1120.0, 335.0)
	var dock_shape: RectangleShape2D = dock_collision.shape as RectangleShape2D
	if dock_shape != null:
		dock_shape.size = Vector2(700.0, 240.0)

	dock_prompt.position = Vector2(770.0, 145.0)
	dock_prompt.size = Vector2(270.0, 38.0)
	dock_prompt.add_theme_font_size_override("font_size", 18)

	upgrade_menu.position = Vector2(330.0, 18.0)
	upgrade_menu.size = Vector2(620.0, 565.0)


func _setup_fish_book_button() -> void:
	fish_book_button = dock_menu_vbox.get_node_or_null("FishBookButton") as Button
	if fish_book_button == null:
		fish_book_button = Button.new()
		fish_book_button.name = "FishBookButton"
		fish_book_button.text = "Balık Defteri"
		dock_menu_vbox.add_child(fish_book_button)
		dock_menu_vbox.move_child(fish_book_button, 2)

	if not fish_book_button.pressed.is_connected(_on_fish_book_button_pressed):
		fish_book_button.pressed.connect(_on_fish_book_button_pressed)


func _setup_dock_menu() -> void:
	dock_menu.position = Vector2(360.0, 38.0)
	dock_menu.size = Vector2(410.0, 360.0)

	var panel_style: StyleBoxFlat = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.06, 0.055, 0.09, 0.95)
	panel_style.border_color = Color(0.58, 0.38, 0.24, 0.95)
	panel_style.border_width_left = 4
	panel_style.border_width_top = 4
	panel_style.border_width_right = 4
	panel_style.border_width_bottom = 4
	panel_style.corner_radius_top_left = 10
	panel_style.corner_radius_top_right = 10
	panel_style.corner_radius_bottom_left = 10
	panel_style.corner_radius_bottom_right = 10
	dock_menu.add_theme_stylebox_override("panel", panel_style)

	dock_menu_vbox.position = Vector2(55.0, 44.0)
	dock_menu_vbox.size = Vector2(300.0, 275.0)
	dock_menu_vbox.add_theme_constant_override("separation", 10)

	var dock_buttons: Array[Button] = [dock_sell_button, dock_upgrade_button, fish_book_button, dock_leave_button]
	for button: Button in dock_buttons:
		button.custom_minimum_size = Vector2(300.0, 54.0)
		button.add_theme_font_size_override("font_size", 18)


func _setup_upgrade_buttons() -> void:
	depth_button = upgrade_menu.get_node_or_null("DepthButton") as Button
	if depth_button == null:
		depth_button = Button.new()
		depth_button.name = "DepthButton"
		upgrade_menu.add_child(depth_button)
	if not depth_button.pressed.is_connected(_on_depth_button_pressed):
		depth_button.pressed.connect(_on_depth_button_pressed)

	line_strength_button = upgrade_menu.get_node_or_null("LineStrengthButton") as Button
	if line_strength_button == null:
		line_strength_button = Button.new()
		line_strength_button.name = "LineStrengthButton"
		upgrade_menu.add_child(line_strength_button)
	if not line_strength_button.pressed.is_connected(_on_line_strength_button_pressed):
		line_strength_button.pressed.connect(_on_line_strength_button_pressed)

	var upgrade_buttons: Array[Button] = [
		boat_speed_button,
		rod_speed_button,
		depth_button,
		capacity_button,
		fight_ease_button,
		line_strength_button
	]

	for i: int in range(upgrade_buttons.size()):
		var button: Button = upgrade_buttons[i]
		button.position = Vector2(60.0, 100.0 + float(i) * 50.0)
		button.size = Vector2(500.0, 42.0)
		button.add_theme_font_size_override("font_size", 16)

	upgrade_info_label.position = Vector2(60.0, 405.0)
	upgrade_info_label.size = Vector2(500.0, 62.0)
	upgrade_info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	upgrade_info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	upgrade_back_button.position = Vector2(230.0, 490.0)
	upgrade_back_button.size = Vector2(160.0, 36.0)


func _setup_fish_book_ui() -> void:
	fish_book_panel = Panel.new()
	fish_book_panel.name = "FishBookPanel"
	fish_book_panel.z_index = 110
	fish_book_panel.size = Vector2(1000.0, 620.0)

	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	fish_book_panel.position = Vector2(
		maxf((viewport_size.x - fish_book_panel.size.x) * 0.5, 0.0),
		maxf((viewport_size.y - fish_book_panel.size.y) * 0.5, 0.0)
	)
	hud.add_child(fish_book_panel)
	fish_book_panel.visible = false

	var panel_style: StyleBoxFlat = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.018, 0.045, 0.075, 0.98)
	panel_style.border_color = Color(0.25, 0.67, 0.78, 0.96)
	panel_style.border_width_left = 4
	panel_style.border_width_top = 4
	panel_style.border_width_right = 4
	panel_style.border_width_bottom = 4
	panel_style.corner_radius_top_left = 14
	panel_style.corner_radius_top_right = 14
	panel_style.corner_radius_bottom_left = 14
	panel_style.corner_radius_bottom_right = 14
	fish_book_panel.add_theme_stylebox_override("panel", panel_style)

	var title: Label = Label.new()
	title.position = Vector2(30.0, 16.0)
	title.size = Vector2(940.0, 42.0)
	title.text = "BALIK DEFTERİ"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color(1.0, 0.82, 0.42, 1.0))
	fish_book_panel.add_child(title)

	fish_book_progress = Label.new()
	fish_book_progress.position = Vector2(30.0, 58.0)
	fish_book_progress.size = Vector2(940.0, 28.0)
	fish_book_progress.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	fish_book_progress.add_theme_font_size_override("font_size", 16)
	fish_book_progress.add_theme_color_override("font_color", Color(0.70, 0.88, 0.94, 1.0))
	fish_book_panel.add_child(fish_book_progress)

	fish_book_grid = GridContainer.new()
	fish_book_grid.columns = 3
	fish_book_grid.position = Vector2(35.0, 96.0)
	fish_book_grid.size = Vector2(930.0, 450.0)
	fish_book_grid.add_theme_constant_override("h_separation", 12)
	fish_book_grid.add_theme_constant_override("v_separation", 12)
	fish_book_panel.add_child(fish_book_grid)

	for fish_type: String in FISH_ORDER:
		_create_fish_book_card(fish_type)

	fish_book_back_button = Button.new()
	fish_book_back_button.text = "Geri"
	fish_book_back_button.position = Vector2(400.0, 560.0)
	fish_book_back_button.size = Vector2(200.0, 42.0)
	fish_book_back_button.add_theme_font_size_override("font_size", 18)
	fish_book_panel.add_child(fish_book_back_button)
	fish_book_back_button.pressed.connect(_on_fish_book_back_pressed)

	_refresh_fish_book()


func _create_fish_book_card(fish_type: String) -> void:
	var card: Panel = Panel.new()
	card.custom_minimum_size = Vector2(300.0, 138.0)
	fish_book_grid.add_child(card)

	var card_style: StyleBoxFlat = StyleBoxFlat.new()
	card_style.bg_color = Color(0.025, 0.085, 0.125, 0.96)
	card_style.border_color = Color(0.13, 0.34, 0.43, 0.95)
	card_style.border_width_left = 2
	card_style.border_width_top = 2
	card_style.border_width_right = 2
	card_style.border_width_bottom = 2
	card_style.corner_radius_top_left = 8
	card_style.corner_radius_top_right = 8
	card_style.corner_radius_bottom_left = 8
	card_style.corner_radius_bottom_right = 8
	card.add_theme_stylebox_override("panel", card_style)

	var icon: TextureRect = TextureRect.new()
	icon.position = Vector2(8.0, 22.0)
	icon.size = Vector2(104.0, 94.0)
	icon.texture = _get_fish_texture(fish_type)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(icon)

	var name_label: Label = Label.new()
	name_label.position = Vector2(116.0, 12.0)
	name_label.size = Vector2(176.0, 30.0)
	name_label.add_theme_font_size_override("font_size", 18)
	name_label.add_theme_color_override("font_color", Color(1.0, 0.82, 0.42, 1.0))
	card.add_child(name_label)

	var detail_label: Label = Label.new()
	detail_label.position = Vector2(116.0, 43.0)
	detail_label.size = Vector2(176.0, 88.0)
	detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_label.add_theme_font_size_override("font_size", 12)
	detail_label.add_theme_color_override("font_color", Color(0.84, 0.93, 0.96, 1.0))
	card.add_child(detail_label)

	fish_book_icons[fish_type] = icon
	fish_book_titles[fish_type] = name_label
	fish_book_details[fish_type] = detail_label


func _refresh_fish_book() -> void:
	if fish_book_panel == null:
		return

	var discovered_count: int = 0
	for fish_type: String in FISH_ORDER:
		var discovered: bool = bool(discovered_fish.get(fish_type, false))
		var icon: TextureRect = fish_book_icons.get(fish_type) as TextureRect
		var title: Label = fish_book_titles.get(fish_type) as Label
		var details: Label = fish_book_details.get(fish_type) as Label
		if icon == null or title == null or details == null:
			continue

		if discovered:
			discovered_count += 1
			icon.modulate = Color.WHITE
			title.text = fish_type
			details.text = (
				"Değer: $" + str(_fish_value(fish_type))
				+ "\nBölge: " + _fish_habitat(fish_type)
				+ "\nDerinlik: " + _fish_depth(fish_type)
				+ "\nKeşfedildi"
			)
		else:
			icon.modulate = Color(0.015, 0.025, 0.035, 0.82)
			title.text = "???"
			details.text = "Henüz keşfedilmedi.\nDaha uzağa git ve daha derine in."

	fish_book_progress.text = "Keşif: " + str(discovered_count) + " / " + str(FISH_ORDER.size())


func _get_fish_texture(fish_type: String) -> Texture2D:
	match fish_type:
		"Levrek":
			return LEVREK_TEXTURE
		"Uskumru":
			return USKUMRU_TEXTURE
		"Ton Balığı":
			return TON_BALIGI_TEXTURE
		"Kılıç Balığı":
			return KILIC_BALIGI_TEXTURE
		"Köpekbalığı":
			return KOPEKBALIGI_TEXTURE
		"Fener Balığı":
			return FENER_BALIGI_TEXTURE
		_:
			return SARDALYA_TEXTURE


func _fish_value(fish_type: String) -> int:
	match fish_type:
		"Sardalya":
			return 10
		"Levrek":
			return 25
		"Uskumru":
			return 40
		"Ton Balığı":
			return 75
		"Kılıç Balığı":
			return 130
		"Köpekbalığı":
			return 220
		"Fener Balığı":
			return 300
		_:
			return 0


func _fish_habitat(fish_type: String) -> String:
	match fish_type:
		"Sardalya":
			return "Sığ su / sürüler"
		"Levrek":
			return "Orta sular"
		"Uskumru":
			return "Açık deniz"
		"Ton Balığı":
			return "Derin açık deniz"
		"Kılıç Balığı":
			return "Uzak açık deniz"
		"Köpekbalığı":
			return "Derin av bölgesi"
		"Fener Balığı":
			return "Karanlık derinlik"
		_:
			return "Bilinmiyor"


func _fish_depth(fish_type: String) -> String:
	match fish_type:
		"Sardalya":
			return "8–12 m"
		"Levrek":
			return "15–25 m"
		"Uskumru":
			return "25–38 m"
		"Ton Balığı":
			return "38–50 m"
		"Kılıç Balığı":
			return "52–62 m"
		"Köpekbalığı":
			return "68–82 m"
		"Fener Balığı":
			return "88–100 m"
		_:
			return "???"


func _set_harbor_camera(active: bool) -> void:
	if is_instance_valid(_camera_tween):
		_camera_tween.kill()

	var target_x: float = CAMERA_HARBOR_X if active else CAMERA_NORMAL_X
	_camera_tween = create_tween()
	_camera_tween.set_trans(Tween.TRANS_SINE)
	_camera_tween.set_ease(Tween.EASE_IN_OUT)
	_camera_tween.tween_property(boat_camera, "position:x", target_x, 0.32)


func _setup_inventory_discovery() -> void:
	hud.set_discovery_state(discovered_fish)


func _update_inventory_discovery() -> void:
	for fish_type: String in FISH_ORDER:
		if int(hud.inventory.get(fish_type, 0)) > 0:
			discovered_fish[fish_type] = true

	hud.set_discovery_state(discovered_fish)

	if fish_book_panel != null and fish_book_panel.visible:
		_refresh_fish_book()


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

	var shadow_points: PackedVector2Array = PackedVector2Array()
	var foam_points: PackedVector2Array = PackedVector2Array()
	for x: int in range(-1000, 12001, 28):
		var wave_y: float = _surface_height_at(float(x))
		shadow_points.append(Vector2(float(x), wave_y + 3.0))
		foam_points.append(Vector2(float(x), wave_y))

	_surface_shadow.points = shadow_points
	_surface_foam.points = foam_points


func _setup_money_hud() -> void:
	money_panel = Panel.new()
	money_panel.name = "MoneyPanel"
	money_panel.z_index = 90
	money_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(money_panel)

	var panel_style: StyleBoxFlat = StyleBoxFlat.new()
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

	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
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
		fish_book_panel.visible = false
		boat_camera.position.y = hook.camera_surface_y
		print("LIMANA YANASTIN")


func _on_dock_area_body_entered(body: Node2D) -> void:
	if body.name == "Boat":
		boat_in_dock_area = true
		_set_harbor_camera(true)
		if not docked:
			dock_prompt.visible = true
			dock_prompt.text = "[E] Limana Yanaş"


func _on_dock_area_body_exited(body: Node2D) -> void:
	if body.name == "Boat":
		boat_in_dock_area = false
		dock_prompt.visible = false
		if not docked:
			_set_harbor_camera(false)


func _on_leave_button_pressed() -> void:
	docked = false
	dock_menu.visible = false
	upgrade_menu.visible = false
	fish_book_panel.visible = false
	boat.set_movement_enabled(true)
	_set_harbor_camera(false)

	if boat_in_dock_area:
		dock_prompt.visible = true
		dock_prompt.text = "[E] Limana Yanaş"


func _on_sell_button_pressed() -> void:
	var total_fish: int = 0
	var total_value: int = 0

	for fish_type: String in FISH_ORDER:
		var amount: int = int(hud.inventory.get(fish_type, 0))
		total_fish += amount
		total_value += amount * _fish_value(fish_type)

	if total_fish == 0:
		print("SATILACAK BALIK YOK!")
		return

	money += total_value
	for fish_type: String in FISH_ORDER:
		hud.inventory[fish_type] = 0

	hud.update_inventory()
	update_money_label()
	_refresh_upgrade_menu()
	print("BALIKLAR SATILDI! +$", total_value)


func _on_upgrade_button_pressed() -> void:
	if not docked:
		return
	dock_menu.visible = false
	fish_book_panel.visible = false
	upgrade_menu.visible = true
	_refresh_upgrade_menu()


func _on_upgrade_back_button_pressed() -> void:
	upgrade_menu.visible = false
	if docked:
		dock_menu.visible = true


func _on_fish_book_button_pressed() -> void:
	if not docked:
		return
	dock_menu.visible = false
	upgrade_menu.visible = false
	_refresh_fish_book()
	fish_book_panel.visible = true


func _on_fish_book_back_pressed() -> void:
	fish_book_panel.visible = false
	if docked:
		dock_menu.visible = true


func _on_boat_speed_button_pressed() -> void:
	_buy_upgrade("boat_speed")


func _on_rod_speed_button_pressed() -> void:
	_buy_upgrade("rod_speed")


func _on_depth_button_pressed() -> void:
	_buy_upgrade("depth")


func _on_capacity_button_pressed() -> void:
	_buy_upgrade("capacity")


func _on_fight_ease_button_pressed() -> void:
	_buy_upgrade("fight_ease")


func _on_line_strength_button_pressed() -> void:
	_buy_upgrade("line_strength")


func _buy_upgrade(key: String) -> void:
	if not docked:
		return

	var level: int = _get_upgrade_level(key)
	if level >= MAX_UPGRADE_LEVEL:
		return

	var cost: int = UPGRADE_COSTS[level]
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
		"depth":
			return depth_level
		"capacity":
			return capacity_level
		"fight_ease":
			return fight_ease_level
		"line_strength":
			return line_strength_level
		_:
			return 0


func _set_upgrade_level(key: String, level: int) -> void:
	match key:
		"boat_speed":
			boat_speed_level = level
		"rod_speed":
			rod_speed_level = level
		"depth":
			depth_level = level
		"capacity":
			capacity_level = level
		"fight_ease":
			fight_ease_level = level
		"line_strength":
			line_strength_level = level


func _apply_upgrades() -> void:
	boat.set_speed_level(boat_speed_level)
	hook.set_reel_speed_level(rod_speed_level)
	hook.set_depth_level(depth_level)
	hook.set_line_strength_level(line_strength_level)
	hud.set_capacity_level(capacity_level)
	hud.set_fight_ease_level(fight_ease_level)

	hook.camera_deep_y = maxf(hook.max_depth - 280.0, 1420.0)
	var water: ColorRect = $Water as ColorRect
	water.offset_bottom = maxf(water.offset_bottom, hook.max_depth + 1100.0)


func _refresh_upgrade_menu() -> void:
	boat_speed_button.text = _upgrade_button_text("Motor Gücü", boat_speed_level)
	rod_speed_button.text = _upgrade_button_text("Makara Hızı", rod_speed_level)
	depth_button.text = _depth_upgrade_button_text(depth_level)
	capacity_button.text = _upgrade_button_text("Tekne Ambarı", capacity_level)
	fight_ease_button.text = _upgrade_button_text("Mücadele Desteği", fight_ease_level)
	line_strength_button.text = _upgrade_button_text("Misina Dayanıklılığı", line_strength_level)

	boat_speed_button.disabled = not _can_afford_level(boat_speed_level)
	rod_speed_button.disabled = not _can_afford_level(rod_speed_level)
	depth_button.disabled = not _can_afford_level(depth_level)
	capacity_button.disabled = not _can_afford_level(capacity_level)
	fight_ease_button.disabled = not _can_afford_level(fight_ease_level)
	line_strength_button.disabled = not _can_afford_level(line_strength_level)

	var tension_reduction_percent: int = line_strength_level * 8
	upgrade_info_label.text = (
		"Olta erişimi: " + str(_current_depth_meters()) + " m.  "
		+ "Misina Sv." + str(line_strength_level) + "/5: gerilim artışı -%"
		+ str(tension_reduction_percent) + "."
	)


func _upgrade_button_text(title: String, level: int) -> String:
	if level >= MAX_UPGRADE_LEVEL:
		return title + "  |  Seviye " + str(level) + "/5  |  MAX"
	return title + "  |  Seviye " + str(level) + "/5  |  $" + str(UPGRADE_COSTS[level])


func _depth_upgrade_button_text(level: int) -> String:
	var meters: int = BASE_DEPTH_METERS + (level * DEPTH_METERS_PER_LEVEL)
	if level >= MAX_UPGRADE_LEVEL:
		return "Olta Derinliği  |  " + str(meters) + " m  |  MAX"
	return (
		"Olta Derinliği  |  " + str(meters) + " m → "
		+ str(meters + DEPTH_METERS_PER_LEVEL) + " m  |  $" + str(UPGRADE_COSTS[level])
	)


func _current_depth_meters() -> int:
	return BASE_DEPTH_METERS + (depth_level * DEPTH_METERS_PER_LEVEL)


func _can_afford_level(level: int) -> bool:
	if level >= MAX_UPGRADE_LEVEL:
		return false
	return money >= UPGRADE_COSTS[level]


func update_money_label() -> void:
	money_label.text = "$" + str(money)
