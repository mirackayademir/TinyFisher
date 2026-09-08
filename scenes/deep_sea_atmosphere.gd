extends Node

# Derin deniz atmosferi:
# - Sığ suda ortam neredeyse değişmez.
# - 20 m sonrasında ışık belirgin şekilde azalır.
# - 60 m sonrasında kancanın çevresindeki ışık önemli hale gelir.
# - 80-100 m arası gerçekten karanlık derin denizdir.
# - Fener Balıkları kendi sıcak, titreşen ışıklarını taşır.
# HUD ayrı CanvasLayer'da olduğu için karanlıktan etkilenmez.

const SHALLOW_START_M: float = 18.0
const HOOK_LIGHT_START_M: float = 58.0
const ANGLER_SCAN_INTERVAL: float = 0.30
const AMBIENT_LERP_SPEED: float = 0.16

var _world: Node2D = null
var _hook: Area2D = null
var _canvas_modulate: CanvasModulate = null
var _hook_light: PointLight2D = null
var _light_texture: Texture2D = null
var _angler_scan_timer: float = 0.0
var _scene_id: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_light_texture = _create_radial_light_texture(128)


func _process(delta: float) -> void:
	_ensure_scene_nodes()
	if _world == null or _hook == null or _canvas_modulate == null or _hook_light == null:
		return

	var depth_m: float = _get_current_depth_meters()
	_update_ambient(depth_m)
	_update_hook_light(depth_m)

	_angler_scan_timer -= delta
	if _angler_scan_timer <= 0.0:
		_angler_scan_timer = ANGLER_SCAN_INTERVAL
		_update_angler_lights()


func _ensure_scene_nodes() -> void:
	var current_scene: Node = get_tree().current_scene
	if current_scene == null:
		return

	var current_id: int = current_scene.get_instance_id()
	if _scene_id == current_id and is_instance_valid(_world) and is_instance_valid(_hook):
		return

	_scene_id = current_id
	_world = current_scene as Node2D
	if _world == null:
		return

	_hook = _world.get_node_or_null("Boat/Hook") as Area2D
	if _hook == null:
		return

	_canvas_modulate = _world.get_node_or_null("DeepSeaCanvasModulate") as CanvasModulate
	if _canvas_modulate == null:
		_canvas_modulate = CanvasModulate.new()
		_canvas_modulate.name = "DeepSeaCanvasModulate"
		_canvas_modulate.color = Color.WHITE
		_world.add_child(_canvas_modulate)

	_hook_light = _hook.get_node_or_null("DeepSeaHookLight") as PointLight2D
	if _hook_light == null:
		_hook_light = PointLight2D.new()
		_hook_light.name = "DeepSeaHookLight"
		_hook_light.texture = _light_texture
		_hook_light.color = Color(0.46, 0.73, 1.0, 1.0)
		_hook_light.energy = 0.0
		_hook_light.texture_scale = 2.45
		_hook_light.shadow_enabled = false
		_hook_light.z_index = 20
		_hook.add_child(_hook_light)


func _get_current_depth_meters() -> float:
	if _hook == null or not bool(_hook.get("deployed")):
		return 0.0

	var start_position: Vector2 = _hook.get("start_position")
	var max_depth: float = float(_hook.get("max_depth"))
	var max_depth_meters: float = float(_hook.get("max_depth_meters"))
	var depth_pixels: float = clampf(_hook.position.y - start_position.y, 0.0, max_depth)
	var depth_ratio: float = depth_pixels / maxf(max_depth, 1.0)
	return depth_ratio * max_depth_meters


func _update_ambient(depth_m: float) -> void:
	var target: Color = Color.WHITE

	# 0-18 m: yüzeye yakın, parlak.
	if depth_m <= SHALLOW_START_M:
		target = Color.WHITE

	# 18-35 m: ilk fark burada gözle görülür hale gelir.
	elif depth_m < 35.0:
		var t1: float = inverse_lerp(SHALLOW_START_M, 35.0, depth_m)
		target = Color.WHITE.lerp(Color(0.68, 0.80, 0.90, 1.0), t1)

	# 35-55 m: orta su artık açık biçimde daha koyudur.
	elif depth_m < 55.0:
		var t2: float = inverse_lerp(35.0, 55.0, depth_m)
		target = Color(0.68, 0.80, 0.90, 1.0).lerp(Color(0.36, 0.51, 0.66, 1.0), t2)

	# 55-72 m: açık deniz ışığı hızla kaybolur.
	elif depth_m < 72.0:
		var t3: float = inverse_lerp(55.0, 72.0, depth_m)
		target = Color(0.36, 0.51, 0.66, 1.0).lerp(Color(0.18, 0.29, 0.42, 1.0), t3)

	# 72-86 m: köpekbalığı katmanı; çevre artık gerçekten karanlık.
	elif depth_m < 86.0:
		var t4: float = inverse_lerp(72.0, 86.0, depth_m)
		target = Color(0.18, 0.29, 0.42, 1.0).lerp(Color(0.085, 0.145, 0.24, 1.0), t4)

	# 86-100 m: Fener Balığı bölgesi. Kanca ışığı olmadan görüş çok sınırlı.
	else:
		var t5: float = clampf(inverse_lerp(86.0, 100.0, depth_m), 0.0, 1.0)
		target = Color(0.085, 0.145, 0.24, 1.0).lerp(Color(0.025, 0.045, 0.085, 1.0), t5)

	_canvas_modulate.color = _canvas_modulate.color.lerp(target, AMBIENT_LERP_SPEED)


func _update_hook_light(depth_m: float) -> void:
	if depth_m < HOOK_LIGHT_START_M or not bool(_hook.get("deployed")):
		_hook_light.energy = lerpf(_hook_light.energy, 0.0, 0.22)
		return

	var depth_t: float = clampf(inverse_lerp(HOOK_LIGHT_START_M, 100.0, depth_m), 0.0, 1.0)
	# Karanlık arttıkça ışık güçleniyor fakat görüş alanı kontrollü kalıyor.
	var target_energy: float = lerpf(0.70, 2.15, depth_t)
	_hook_light.energy = lerpf(_hook_light.energy, target_energy, 0.16)
	_hook_light.texture_scale = lerpf(2.05, 2.65, depth_t)


func _update_angler_lights() -> void:
	if _world == null:
		return
	_scan_for_anglers(_world)


func _scan_for_anglers(node: Node) -> void:
	if node.has_method("hook_to") and String(node.get("fish_type")) == "Fener Balığı":
		_ensure_angler_light(node)

	for child: Node in node.get_children():
		_scan_for_anglers(child)


func _ensure_angler_light(fish: Node) -> void:
	var fish_2d: Node2D = fish as Node2D
	if fish_2d == null:
		return

	var light: PointLight2D = fish_2d.get_node_or_null("AnglerNaturalLight") as PointLight2D
	if light == null:
		light = PointLight2D.new()
		light.name = "AnglerNaturalLight"
		light.texture = _light_texture
		light.texture_scale = 1.65
		light.color = Color(1.0, 0.46, 0.10, 1.0)
		light.shadow_enabled = false
		light.z_index = 21
		fish_2d.add_child(light)

	var phase: float = float(fish_2d.get_instance_id() % 1000) * 0.013
	var pulse: float = sin((Time.get_ticks_msec() * 0.001) * 2.6 + phase)
	light.energy = 1.45 + pulse * 0.28


func _create_radial_light_texture(size: int) -> Texture2D:
	var image: Image = Image.create(size, size, false, Image.FORMAT_RGBA8)
	var center: Vector2 = Vector2(float(size - 1), float(size - 1)) * 0.5
	var radius: float = float(size) * 0.5

	for y: int in range(size):
		for x: int in range(size):
			var distance_ratio: float = Vector2(float(x), float(y)).distance_to(center) / radius
			var intensity: float = pow(clampf(1.0 - distance_ratio, 0.0, 1.0), 2.35)
			image.set_pixel(x, y, Color(intensity, intensity, intensity, 1.0))

	return ImageTexture.create_from_image(image)
