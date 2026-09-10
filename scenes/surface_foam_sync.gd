extends Node

# 7/36 surface_foam_01.png duzeltmesi.
# Eski sabit Sprite2D kopuk seridini gizler ve ayni texture'i
# World tarafindaki hareketli SurfaceWaveFoam Line2D'sine baglar.
# Boylece kopuk, dalganin sin/cos hareketini birebir takip eder.

const FOAM_TEXTURE: Texture2D = preload("res://assets/environment/surface/surface_foam_01.png")

var _bound_line: Line2D = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	print("SURFACE FOAM SYNC: hareketli dalgaya baglanmaya hazir")


func _process(_delta: float) -> void:
	var current_scene: Node = get_tree().current_scene
	if current_scene == null:
		_bound_line = null
		return

	# EnvironmentLayers V14'te uretilen sabit kopuk seridi artik kullanilmiyor.
	# Hareketli ana dalga ile ayrisip arkada iz birakmasin diye tamamen gizliyoruz.
	var static_foam: CanvasItem = current_scene.get_node_or_null(
		"EnvironmentLayers/SurfaceLayers/SurfaceFoamLayer/SurfaceFoamArt"
	) as CanvasItem
	if static_foam != null:
		static_foam.visible = false

	var wave_line: Line2D = current_scene.get_node_or_null("SurfaceWaveFoam") as Line2D
	if wave_line == null:
		_bound_line = null
		return

	if _bound_line == wave_line:
		return

	_bound_line = wave_line
	_apply_foam_texture(_bound_line)


func _apply_foam_texture(line: Line2D) -> void:
	line.texture = FOAM_TEXTURE
	line.texture_mode = Line2D.LINE_TEXTURE_TILE
	line.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	line.width = 9.0
	line.default_color = Color(1.0, 1.0, 1.0, 0.72)
	line.joint_mode = Line2D.LINE_JOINT_ROUND
	line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	line.end_cap_mode = Line2D.LINE_CAP_ROUND
	line.antialiased = false
	print("SURFACE FOAM SYNC: kopuk hareketli dalgaya baglandi")
