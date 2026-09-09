extends Node

# Leviathan kontrolu artik ikinci bir balik spawn ETMEZ.
# ApprovedFishArt tarafindan ekranda gercekten gorunen LeviathanVisualTest Sprite2D'sini bulur
# ve animasyonu direkt ona uygular. Boylece degisiklikler gorunmeyen/ikinci Leviathan'a gitmez.

const LEVIATHAN_NODE_NAME: String = "LeviathanVisualTest"
const LEVIATHAN_SWIM_SHADER: Shader = preload("res://shaders/leviathan_swim.gdshader")
const RETRY_SECONDS: float = 0.20

var _leviathan_sprite: Sprite2D = null
var _retry_timer: float = 0.0
var _material_applied: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	print("LEVIATHAN CONTROLLER V8: VISIBLE SPRITE TARGET MODE")


func _process(delta: float) -> void:
	if is_instance_valid(_leviathan_sprite):
		if not _material_applied:
			_apply_visible_leviathan_material()
		return

	_retry_timer -= delta
	if _retry_timer > 0.0:
		return
	_retry_timer = RETRY_SECONDS
	_find_visible_leviathan()


func _find_visible_leviathan() -> void:
	var root: Node = get_tree().current_scene
	if root == null:
		return

	var sprite: Sprite2D = root.get_node_or_null(LEVIATHAN_NODE_NAME) as Sprite2D
	if sprite == null:
		return

	_leviathan_sprite = sprite
	_material_applied = false
	print("LEVIATHAN V8 HEDEF BULUNDU: ", _leviathan_sprite.get_path())
	_apply_visible_leviathan_material()


func _apply_visible_leviathan_material() -> void:
	if not is_instance_valid(_leviathan_sprite):
		return

	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = LEVIATHAN_SWIM_SHADER

	# Ilk testte hareket bilerek belirgin. Calistigini gordukten sonra dogallastiririz.
	material.set_shader_parameter("tail_strength", 0.060)
	material.set_shader_parameter("tail_speed", 3.0)
	material.set_shader_parameter("body_strength", 0.018)

	_leviathan_sprite.material = material
	_material_applied = true

	print("LEVIATHAN V8 ANIMASYON DIREKT GORUNEN SPRITE'A UYGULANDI")
