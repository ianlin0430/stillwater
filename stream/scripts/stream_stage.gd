class_name StreamStage
extends Node2D

const MotionSmoother=preload("res://scripts/motion_smoother.gd")
var rigs: Dictionary = {}
var event_cursor: int = -1
var deaths: Dictionary = {}
var events_layer: Node2D
var base_opacity: Dictionary = {}
const MAX_DEATHS: int = 24
# Garden eel art remains behind the user review gate; never render it as a hatchetfish.
const PRESENTED_SPECIES: Array[String] = ["threadfin","hatchet"]
var smoother=MotionSmoother.new()
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
var habitat: Node2D
var interaction_enabled: bool=true

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
	habitat=preload("res://scripts/stream_habitat.gd").new()
	habitat.z_index=0
	add_child(habitat)
	events_layer=preload("res://scripts/stream_events.gd").new()
	events_layer.z_index=3
	add_child(events_layer)
	dimmer=CanvasModulate.new()
	add_child(dimmer)

func apply_snapshot(value: Dictionary) -> void:
	var latest: int=value.get("next_event",1)-1
	var reset: bool=event_cursor<0 or latest<event_cursor or float(value.elapsed)<smoother.elapsed or (not snapshot.is_empty() and value.get("seed")!=snapshot.get("seed"))
	if reset:
		for id: int in rigs: rigs[id].queue_free()
		rigs.clear()
		deaths.clear()
		base_opacity.clear()
		events_layer.clear()
		smoother=MotionSmoother.new()
	else:
		for event: Dictionary in StreamWorld.events_after(value.get("events",[]),event_cursor):
			if event.get("live",false): events_layer.accept(event,value)
			if event.get("live",false) and event.kind=="death" and event.get("cause","") in ["old age","starvation"]:
				_begin_death(event,value)
	event_cursor=latest
	snapshot=value.duplicate(true)
	habitat.apply_snapshot(value)
	var present: Dictionary = {}
	var jumps: Array = []
	for a: Dictionary in value.animals:
		if not a.species in PRESENTED_SPECIES: continue
		var cfg: Dictionary = StreamWorld.SPECIES[a.species]
		var size_factor: float=0.5 if a.age<cfg.mature else 1.0
		var p:=Vector2(a.x,a.y)
		present[a.id]=p
		if a.get("relocated_at",-1)>smoother.elapsed:
			jumps.append(a.id)
		if not rigs.has(a.id):
			var new_rig: Node2D = SwimmerRig.new()
			new_rig.species=a.species
			new_rig.individual_id=a.id
			new_rig.body_scale=size_factor
			new_rig.position=p
			new_rig.facing=a.direction
			new_rig.face_target=a.direction
			new_rig.scale=Vector2.ONE*size_factor
			new_rig.z_index=1
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
		base_opacity[a.id]=1.0-shelter_depth*0.78
		rig.modulate.a=base_opacity[a.id]
	for id: int in rigs.keys():
		if not present.has(id) and not deaths.has(id):
			rigs[id].queue_free()
			rigs.erase(id)
			base_opacity.erase(id)
	var snapped: bool=smoother.push(value.elapsed,present,jumps,value.get("motion_remainder",0.0))
	for id: int in rigs:
		if present.has(id) and (snapped or id in jumps):
			rigs[id].position=present[id]
			rigs[id].reset_contact()

func animate(delta: float) -> void:
	water_clock+=delta
	water_material.set_shader_parameter("water_clock",water_clock)
	motes.advance(delta)
	habitat.advance(delta)
	smoother.advance(delta)
	for id: int in rigs.keys():
		var rig: Node2D = rigs[id]
		if deaths.has(id):
			var death: Dictionary=deaths[id]
			death.age+=maxf(delta,0)
			if death.age>=2:
				rig.queue_free()
				rigs.erase(id)
				deaths.erase(id)
				base_opacity.erase(id)
				continue
			var t: float=death.age/2.0
			rig.position=death.origin+Vector2(0,minf(28.0,maxf(0,640-death.origin.y))*t)
			rig.modulate.a=death.opacity*(1-t)*(1-t)
		else:
			rig.position=smoother.position(id)
			rig.modulate.a=base_opacity.get(id,1.0)
		rig.selected=id==selected
	events_layer.advance(delta,float(snapshot.get("elapsed",0)),rigs)
	for id: int in rigs:
		if not deaths.has(id): rigs[id].animate(delta)
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
		if deaths.has(key): continue
		var rig: Node2D = rigs[key]
		var diff: Vector2 = world_point-rig.position
		var radius: Vector2 = Vector2(56,32)*rig.body_scale
		var distance: float = (diff/radius).length()
		if distance<1.2 and distance<best:
			best=distance
			id=key
	return id

func interact(viewport_point: Vector2, strength: float=1.0) -> void:
	if interaction_enabled:
		habitat.touch((viewport_point-position)/zoom,strength)

func describe_environment(viewport_point: Vector2) -> String:
	return habitat.describe((viewport_point-position)/zoom)

func _begin_death(event: Dictionary, value: Dictionary) -> void:
	var id: int=event.id
	events_layer.fades.erase(id)
	if deaths.has(id) or deaths.size()>=MAX_DEATHS: return
	var archived: Dictionary={}
	for a: Dictionary in value.get("archive",[]):
		if a.id==id:
			archived=a
			break
	if archived.is_empty() or not archived.species in PRESENTED_SPECIES: return
	if not rigs.has(id):
		var rig:=SwimmerRig.new()
		rig.species=archived.species
		rig.individual_id=id
		rig.sex=archived.sex
		rig.body_scale=0.5 if archived.age<StreamWorld.SPECIES[archived.species].mature else 1.0
		rig.scale=Vector2.ONE*rig.body_scale
		rig.facing=archived.direction
		rig.face_target=archived.direction
		rig.z_index=1
		add_child(rig)
		rigs[id]=rig
	var rig: Node2D=rigs[id]
	var origin:=Vector2(event.get("x",archived.x),event.get("y",archived.y))
	rig.position=origin
	rig.reset_contact()
	rig.activity="Resting"
	deaths[id]={"age":0.0,"origin":origin,"opacity":rig.modulate.a,"appearance":archived.duplicate(true)}

func visible_ids() -> Array[int]:
	var ids: Array[int]=[]
	for a: Dictionary in snapshot.get("animals",[]):
		if a.species in PRESENTED_SPECIES and rigs.has(a.id): ids.append(a.id)
	return ids
