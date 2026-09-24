extends SceneTree
var checks: int=0
var failures: Array[String]=[]
func check(value: bool, message: String) -> void:
	checks+=1
	if not value: failures.append(message)
func _initialize() -> void: call_deferred("run")
func tick(stage: Node2D, seconds: float) -> void:
	for i in int(seconds*30): stage.animate(1.0/30)
func run() -> void:
	var world:=StreamWorld.new(42,1000)
	world.state.light_hour=12
	var snapshot: Dictionary=world.snapshot()
	for a: Dictionary in snapshot.animals:
		if a.species in ["garden_eel","purple_firefish"]:
			a.extend=1.0
			a.activity="Swaying" if a.species=="garden_eel" else "Hovering"
	var before: PackedByteArray=var_to_bytes(world.export_state())
	var frozen: PackedByteArray=var_to_bytes(snapshot)
	var stage:=StreamStage.new()
	root.add_child(stage)
	stage.apply_snapshot(snapshot)
	tick(stage,0.5)
	check(stage.rigs.size()==11,"Four-species opening cast shows eleven fish while backend migration is pending")
	var by_species: Dictionary={}
	for id: int in stage.rigs:
		var rig: ReefRig=stage.rigs[id]
		by_species[rig.species]=rig
		check(rig.fish.texture==ReefRig.EEL if rig.species=="garden_eel" else rig.fish.texture==ReefRig.ATLAS,"Uses new reef textures")
	check(not by_species.has("garden_eel"),"Deferred garden eel has no rig or visible hole")
	var fire: ReefRig=by_species.purple_firefish
	var blenny: ReefRig=by_species.lawnmower_blenny
	var tang: ReefRig=by_species.yellow_tang
	var chromis: ReefRig=by_species.green_chromis
	check(tang.extent.x>blenny.extent.x and blenny.extent.x>fire.extent.x and fire.extent.x>chromis.extent.x,"Tang is largest and chromis smallest")
	var night: Dictionary=snapshot.duplicate(true)
	for a: Dictionary in night.animals:
		if a.species in ["garden_eel","purple_firefish"]:
			a.extend=0.0
			a.activity="Sleeping"
	stage.apply_snapshot(night)
	tick(stage,0.3)
	check(not fire.body_visible,"Sleeping burrow fish have no visible body")
	stage.apply_snapshot(snapshot)
	tick(stage,2)
	check(fire.body_visible and fire.extension>0.99,"Purple firefish smoothly returns from its hole")
	check(absf(fire.visual_offset.y+fire.actor.hover_y)<1,"Hover height follows the backend's per-individual field")
	check(stage.pick(fire.selection_position())==fire.individual_id,"Picking tracks visible hovering body rather than buried anchor")
	var grazing: Dictionary=tang.actor.duplicate(true)
	grazing.activity="Grazing"
	grazing.direction=-1.0
	grazing.contact_x=tang.position.x-22.0
	grazing.contact_y=tang.position.y
	tang.face_target=-1
	tang.apply_actor(grazing)
	tang.animate(0.1)
	check(tang.mouth_position().distance_to(Vector2(grazing.contact_x,grazing.contact_y))<0.01,"Grazing mouth meets backend contact without moving body center")
	var root_point: Vector2=blenny.position
	blenny.activity="Hopping"
	blenny.position.x+=2
	blenny.animate(1.0/30)
	check(blenny.hop_height>0 and blenny.position.y==root_point.y,"Hop lifts visual body only, backend ground anchor preserved")
	blenny.activity="Perching"
	for i in 30: blenny.animate(1.0/30)
	check(blenny.hop_height==0,"Perching settles precisely onto the substrate")
	chromis.face_target=-chromis.facing
	for i in 60: chromis.animate(1.0/30)
	check(is_equal_approx(chromis.facing,chromis.face_target) and is_equal_approx(chromis.tail_facing,chromis.facing),"Head-led turn finishes with attached tail")
	check(var_to_bytes(snapshot)==frozen,"Rig updates never mutate snapshots")
	check(var_to_bytes(world.export_state())==before,"Rig interactions preserve simulation and both random states")
	stage.queue_free()
	print(JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
