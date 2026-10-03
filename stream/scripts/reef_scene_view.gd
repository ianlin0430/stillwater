class_name ReefSceneView
extends Node2D
# Shared production/review visuals. Simulation scene selection belongs to StreamWorld.
@export_enum("reef", "shipwreck") var scene_id: String="reef"
var scene: ReefScene
var background: Sprite2D
var decorations: Array[ReefDecorView]=[]
var styles: Dictionary={}

func _ready() -> void:
	texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	background=Sprite2D.new()
	background.centered=false
	background.z_index=-20
	add_child(background)
	configure(ReefScene.open(scene_id))

func configure(next_scene: ReefScene, choices: Dictionary={}) -> void:
	var resolved: Dictionary=next_scene.default_decor()
	for slot: Dictionary in next_scene.slots():
		var chosen: String=choices.get(slot.id,slot.default)
		if chosen in slot.styles or (chosen=="" and slot.required==""):
			resolved[slot.id]=chosen
	if scene!=null and scene.id()==next_scene.id() and styles==resolved: return
	scene=next_scene
	scene_id=scene.id()
	styles=resolved
	background.texture=load(scene.background())
	background.scale=Vector2(1280,720)/background.texture.get_size()
	for decor: ReefDecorView in decorations:
		remove_child(decor)
		decor.queue_free()
	decorations.clear()
	for slot: Dictionary in scene.slots():
		if styles[slot.id]=="": continue
		var decor:=ReefDecorView.new()
		decor.style=styles[slot.id]
		decor.definition=scene.decor[decor.style]
		decor.position=slot.anchor
		decor.phase=decorations.size()*1.7
		add_child(decor)
		decorations.append(decor)

func advance(delta: float) -> void:
	for decor: ReefDecorView in decorations: decor.advance(delta)
