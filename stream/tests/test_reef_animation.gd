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
	check(stage.rigs.size()==world.state.animals.size(),"Every individual in the current four-species backend has a visible rig")
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
	check(fire.portal!=null and fire.portal.get_index()<fire.fish.get_index(),"Burrow rear wall draws above background and behind the fish")
	check(fire.portal.z_index==0 and fire.portal.front.z_index==1,"Raised burrow lip occludes the fish while the rear wall remains above the backdrop")
	check(tang.extent.x>blenny.extent.x and blenny.extent.x>fire.extent.x and fire.extent.x>chromis.extent.x,"Tang is largest and chromis smallest")
	var night: Dictionary=snapshot.duplicate(true)
	for a: Dictionary in night.animals:
		if a.species in ["garden_eel","purple_firefish"]:
			a.extend=0.0
			a.activity="Sleeping"
	stage.apply_snapshot(night)
	tick(stage,0.7)
	check(not fire.body_visible,"Sleeping burrow fish have no visible body")
	stage.apply_snapshot(snapshot)
	tick(stage,2)
	check(fire.body_visible and fire.extension>0.99,"Purple firefish smoothly returns from its hole")
	check(absf(fire.visual_offset.y+fire.actor.hover_y)<1,"Hover height follows the backend's per-individual field")
	check(stage.pick(fire.selection_position())==fire.individual_id,"Picking tracks visible hovering body rather than buried anchor")
	var grazing: Dictionary=tang.actor.duplicate(true)
	grazing.activity="Grazing"
	grazing.direction=-1.0
	grazing.heading=PI
	grazing.contact_x=tang.position.x-tang.extent.x*.5*tang.body_scale
	grazing.contact_y=tang.position.y
	tang.face_target=-1
	tang.apply_actor(grazing)
	for i in 40: tang.animate(1.0/30)
	check(is_equal_approx(tang.contact_projection,1.0),"Grazing preserves tang body proportions instead of squeezing to the contact distance")
	check(tang.mouth_position().distance_to(Vector2(grazing.contact_x,grazing.contact_y))<0.05,"Grazing mouth meets backend contact without moving body center")
	check(tang.contact_offset.length()<0.05,"Size-scaled backend grazing reach needs no compensating body displacement")
	var root_point: Vector2=blenny.position
	var launch: Dictionary=blenny.actor.duplicate(true)
	launch.activity="Hopping"
	launch.thrust=1.0
	launch.speed=30.0
	blenny.apply_actor(launch)
	blenny.position.x+=2
	blenny.animate(1.0/30)
	check(blenny.hop_height>0 and blenny.position.y==root_point.y,"Hop lifts visual body only, backend ground anchor preserved")
	blenny.activity="Perching"
	for i in 30: blenny.animate(1.0/30)
	check(blenny.hop_height==0,"Perching settles precisely onto the substrate")
	var turning: Dictionary=chromis.actor.duplicate(true)
	turning.heading=PI
	turning.direction=-1
	chromis.face_target=-1
	chromis.apply_actor(turning)
	for i in 60: chromis.animate(1.0/30)
	check(is_equal_approx(chromis.facing,chromis.face_target) and is_equal_approx(chromis.tail_facing,chromis.facing),"Head-led turn finishes with attached tail")
	fire.target_extension=0
	fire.extension=0
	fire.begin_arrival()
	fire.animate(0.1)
	check(fire.body_visible and fire.visual_pitch==0 and fire.visual_offset.y<0,"Night arrival swims above sand before hiding")
	for i in 75: fire.animate(1.0/30)
	check(not fire.body_visible,"Night arrival finishes by entering the burrow")
	fire.arrival_age=-1
	fire.target_extension=1
	fire.extension=1
	fire.animate(1.0/30)
	fire.target_extension=0
	for i in 6: fire.animate(1.0/30)
	check(fire.body_visible and fire.extension>0,"Retreat remains readable after 0.2 s instead of instantly hiding")
	check(absf(fire.visual_pitch)>1.4 and fire.visual_offset.y<0,"Head bends toward the entrance above sand before the body descends")
	check(fire.fish_material.get_shader_parameter("portal") and not fire.fish_material.get_shader_parameter("clip_sand"),"Firefish uses its local aperture, never a whole-scene sand-plane cut")
	for i in 20: fire.animate(1.0/30)
	check(not fire.body_visible and fire.visual_offset.y>fire.extent.x*.5,"Body is hidden only after the tail has passed below the sand")
	var eating: Dictionary=snapshot.duplicate(true)
	eating.events.append({"seq":eating.next_event,"kind":"ate","id":fire.individual_id,"live":true})
	eating.next_event+=1
	stage.apply_snapshot(eating)
	check(fire.bite_timer==0.35 and tang.bite_timer==0,"Explicit ate event animates only its actor")
	stage.animate(0)
	check(fire.bite_timer==0.35,"Pause freezes the actual bite")
	tick(stage,0.5)
	stage.apply_snapshot(eating)
	check(fire.bite_timer==0,"The event cursor prevents repeated bites")
	var offline_bite: Dictionary=eating.duplicate(true)
	offline_bite.events.append({"seq":offline_bite.next_event,"kind":"ate","id":fire.individual_id,"live":false})
	offline_bite.next_event+=1
	stage.apply_snapshot(offline_bite)
	check(fire.bite_timer==0,"Offline food events do not replay mouth animation")
	check(var_to_bytes(snapshot)==frozen,"Rig updates never mutate snapshots")
	check(var_to_bytes(world.export_state())==before,"Rig interactions preserve simulation and both random states")
	# Replay a complete turn as 0.2 s snapshots, rendering six frames per snapshot.
	var largest_step: float=0
	var previous_facing: float=chromis.facing
	var turn_pose: Dictionary=chromis.actor.duplicate(true)
	turn_pose.heading=PI
	turn_pose.thrust=0.0
	chromis.apply_actor(turn_pose)
	chromis.animate(.2)
	previous_facing=chromis.facing
	var neutral_phase: float=chromis.water_phase
	turn_pose.thrust=0.0
	turn_pose.speed=30.0
	for step in 16:
		turn_pose.heading=PI*(1-float(step)/15)
		turn_pose.turn=-PI/3.0
		turn_pose.direction=1 if cos(turn_pose.heading)>=0 else -1
		chromis.apply_actor(turn_pose)
		for frame in 6:
			chromis.animate(1.0/30)
			largest_step=maxf(largest_step,absf(chromis.facing-previous_facing))
			previous_facing=chromis.facing
	check(largest_step<0.08,"A snapshot turn never flips the rendered orientation in one frame")
	check(absf(chromis.water_phase-neutral_phase)<0.6,"Zero thrust eases out of the previous stroke instead of running a fixed loop")
	var fallback: Dictionary={"activity":"Resting","direction":-1,"species":"green_chromis"}
	chromis.apply_actor(fallback)
	chromis.animate(.2)
	check(chromis.pose.heading==PI and chromis.pose.thrust==0 and chromis.pose.speed==0,"Legacy snapshots default direction to heading and all other motion to zero")
	chromis.effort=1
	chromis.animate(1.0/30)
	check(chromis.effort>0.7 and chromis.effort<1,"Stopping thrust eases out rather than snapping fins shut")
	for i in 90: chromis.animate(1.0/30)
	check(chromis.effort<.001,"Coasting reaches a quiet resting stroke")
	var flick_pose: Dictionary=fire.actor.duplicate(true)
	flick_pose.flick=1
	fire.apply_actor(flick_pose)
	fire.animate(1.0/30)
	check(fire.ray_flick>0,"Firefish flick raises the dorsal ray")
	flick_pose.flick=0
	fire.apply_actor(flick_pose)
	for i in 90: fire.animate(1.0/30)
	check(absf(fire.ray_flick)<.001,"Dorsal ray returns after the flick instead of staying raised")
	stage.queue_free()
	print(JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
