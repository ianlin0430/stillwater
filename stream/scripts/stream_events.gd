extends Node2D
# Presentation only. Never receives a world or its random generators.
const LIMIT: int=24
var fades: Dictionary={}
var ghosts: Array[Dictionary]=[]

func clear() -> void:
	fades.clear()
	for effect: Dictionary in ghosts: effect.rig.queue_free()
	ghosts.clear()

func accept(event: Dictionary, snapshot: Dictionary) -> void:
	var actor: Dictionary={}
	for a: Dictionary in snapshot.animals+snapshot.get("archive",[]):
		if a.id==event.id:
			actor=a
			break
	if actor.is_empty() or not actor.species in StreamStage.PRESENTED_SPECIES: return
	if event.kind in ["birth","arrival"]:
		if fades.size()<LIMIT:
			fades[event.id]={"age":0.0,"duration":1.5 if event.kind=="birth" else 2.0,"kind":event.kind,"side":-1.0 if actor.x<640 else 1.0}
	elif event.kind=="dispersal":
		if ghosts.size()>=LIMIT: return
		var rig:=ReefRig.new()
		rig.species=actor.species
		rig.detached=true
		rig.sex=actor.sex
		rig.individual_id=actor.id
		rig.body_scale=0.32
		rig.scale=Vector2.ONE*rig.body_scale
		rig.facing=1.0
		rig.face_target=rig.facing
		rig.tail_facing=rig.facing
		rig.activity="Swimming"
		var origin:=Vector2(event.get("x",actor.x),event.get("y",actor.y))
		rig.position=origin
		rig.modulate=Color(0.55,0.65,0.59,0.5)
		add_child(rig)
		ghosts.append({"rig":rig,"age":0.0,"origin":origin,"kind":event.kind,"until":event.get("until",snapshot.elapsed),"expired":0.0})

func advance(delta: float, _simulation_time: float, rigs: Dictionary) -> void:
	for id: int in fades.keys():
		if not rigs.has(id):
			fades.erase(id)
			continue
		var fade: Dictionary=fades[id]
		if not fade.get("started",false):
			fade.started=true
			if rigs[id].species in ["garden_eel","purple_firefish"]:
				if fade.kind=="arrival": rigs[id].begin_arrival()
				else: rigs[id].extension=0
		fade.age+=maxf(0,delta)
		var t: float=clampf(fade.age/fade.duration,0,1)
		rigs[id].modulate.a*=smoothstep(0,1,t)
		if fade.kind=="arrival" and not rigs[id].species in ["garden_eel","purple_firefish"]:
			rigs[id].position.x+=fade.side*130*pow(1-t,2)
		if t>=1: fades.erase(id)
	for effect: Dictionary in ghosts.duplicate():
		effect.age+=maxf(delta,0)
		var rig: SwimmerRig=effect.rig
		var t: float=minf(effect.age/4,1)
		rig.position=effect.origin.lerp(Vector2(1320,effect.origin.y-45),t)
		rig.modulate.a=0.5*sin(t*PI)
		rig.animate(delta)
		if t>=1:
			rig.queue_free()
			ghosts.erase(effect)
