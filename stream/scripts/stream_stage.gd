class_name StreamStage
extends Node2D

var rigs: Dictionary = {}
var targets: Dictionary = {}
var selected: int = -1
var zoom: float = 1.0
var center: Vector2 = Vector2(640,360)
var natural_light: float = 1.0
var viewing_light: bool = false
var dimmer: CanvasModulate
var background: Sprite2D
var snapshot: Dictionary = {}
var water_clock: float = 0
var motes: Node2D
var water_material: ShaderMaterial

func _ready() -> void:
	texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	background=Sprite2D.new()
	background.texture=preload("res://assets/pixel/stream-fish-shrimp.png")
	background.centered=false
	background.scale=Vector2(1280.0/background.texture.get_width(),720.0/background.texture.get_height())
	background.z_index=-20
	water_material=ShaderMaterial.new()
	water_material.shader=preload("res://scripts/stream_water.gdshader")
	background.material=water_material
	add_child(background)
	motes=Node2D.new()
	motes.set_script(preload("res://scripts/stream_motes.gd"))
	motes.z_index=2
	add_child(motes)
	dimmer=CanvasModulate.new()
	add_child(dimmer)

func apply_snapshot(value: Dictionary) -> void:
	snapshot=value
	var present: Dictionary = {}
	for a: Dictionary in value.animals:
		present[a.id]=true
		var cfg: Dictionary = StreamWorld.SPECIES[a.species]
		var size_factor: float = 1.0
		if a.species=="shrimp":
			size_factor=0.48 if a.age<cfg.mature else 0.75
		else:
			size_factor=0.5 if a.age<cfg.mature else 1.0
		var p := Vector2(a.x,a.y)
		if a.species=="shrimp":
			p.y-=12*size_factor
		targets[a.id]=p
		if not rigs.has(a.id):
			var new_rig: Node2D = SwimmerRig.new()
			new_rig.species=a.species
			new_rig.individual_id=a.id
			new_rig.body_scale=size_factor
			new_rig.position=p
			new_rig.facing=a.direction
			new_rig.face_target=a.direction
			new_rig.scale=Vector2.ONE*size_factor
			new_rig.z_index=3 if a.species=="shrimp" else 1
			if new_rig is SwimmerRig:
				new_rig.sex=a.sex
			add_child(new_rig)
			rigs[a.id]=new_rig
		var rig: Node2D = rigs[a.id]
		rig.activity=a.activity
		rig.face_target=a.direction
		rig.body_scale=size_factor
		rig.scale=Vector2.ONE*size_factor
		rig.dim=0.64 if a.activity in ["Sheltering","Molting"] else 1.0
		# As an animal enters its dark crevice, retain only a faint silhouette.
		var shelter_depth: float=clampf(1.0-absf(a.x-a.shelter)/75.0,0,1) if a.activity in ["Sheltering","Molting"] else 0.0
		rig.modulate.a=1.0-shelter_depth*0.78
	for id: int in rigs.keys():
		if not present.has(id):
			rigs[id].queue_free()
			rigs.erase(id)
			targets.erase(id)

func animate(delta: float) -> void:
	water_clock+=delta
	water_material.set_shader_parameter("water_clock",water_clock)
	motes.advance(delta)
	for id: int in rigs:
		var rig: Node2D = rigs[id]
		rig.position=rig.position.lerp(targets[id],minf(1,delta*9))
		rig.selected=id==selected
		rig.animate(delta)
	var half: Vector2 = Vector2(640,360)/zoom
	center=center.clamp(half,Vector2(1280,720)-half)
	scale=Vector2.ONE*zoom
	position=Vector2(640,360)-center*zoom
	var light: float = maxf(natural_light,0.88 if viewing_light else 0.0)
	dimmer.color=Color(0.30,0.44,0.56).lerp(Color(1.0,0.98,0.92),light)

func pick(viewport_point: Vector2) -> int:
	var world_point: Vector2 = (viewport_point-position)/zoom
	var id: int = -1
	var best: float = INF
	for key: int in rigs:
		var rig: Node2D = rigs[key]
		var diff: Vector2 = world_point-rig.position
		var radius: Vector2 = Vector2(56,32)*rig.body_scale
		var distance: float = (diff/radius).length()
		if distance<1.2 and distance<best:
			best=distance
			id=key
	return id
