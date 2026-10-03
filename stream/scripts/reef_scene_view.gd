class_name ReefSceneView
extends Node2D
# Visual scene resource; S4 remains responsible for choosing the simulation scene.
@export_enum("reef", "shipwreck") var scene_id: String="reef"
var scene: ReefScene
var decorations: Array[ReefDecorView]=[]

func _ready() -> void:
	texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	scene=ReefScene.open(scene_id)
	var background:=Sprite2D.new()
	background.texture=load(scene.background())
	background.centered=false
	background.scale=Vector2(1280,720)/background.texture.get_size()
	add_child(background)
	for slot: Dictionary in scene.slots():
		if slot.default=="": continue
		var decor:=ReefDecorView.new()
		decor.style=slot.default
		decor.definition=scene.decor[decor.style]
		decor.position=slot.anchor
		decor.phase=decorations.size()*1.7
		add_child(decor)
		decorations.append(decor)

func advance(delta: float) -> void:
	for decor: ReefDecorView in decorations: decor.advance(delta)
