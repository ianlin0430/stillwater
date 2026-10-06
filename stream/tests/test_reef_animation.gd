extends SceneTree
# Production animation contract for the approved four-species cast.
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
	var before: PackedByteArray=var_to_bytes(world.export_state())
	var frozen: PackedByteArray=var_to_bytes(snapshot)
	var stage:=StreamStage.new()
	root.add_child(stage)
	stage.apply_snapshot(snapshot)
	tick(stage,.5)
	check(stage.rigs.size()==world.state.animals.size(),"Every individual in the current backend has a visible rig")
	var by_species: Dictionary={}
	for id: int in stage.rigs:
		var rig: ReefRig=stage.rigs[id]
		by_species[rig.species]=rig
		check(rig.fish.texture==rig.art_texture(),rig.species+": approved reef texture")
		check(rig.body_visible,rig.species+": daylight body is visible")
	check(by_species.size()==4,"The production cast has exactly four species")
	var chromis: ReefRig=by_species.green_chromis
	var horse=by_species.seahorse
	var gramma=by_species.royal_gramma
	var clown=by_species.clownfish
	check(horse.tail_contact().distance_to(Vector2(horse.actor.hitch_x,horse.actor.hitch_y))<.05,"Held tail meets the backend hitch exactly")
	var anchor: Vector2=horse.position
	var lean_pose: Dictionary=horse.actor.duplicate(true)
	lean_pose.lean=.25
	horse.apply_actor(lean_pose)
	for i in 60: horse.animate(1.0/30)
	check(horse.position==anchor and horse.tail_contact().distance_to(Vector2(lean_pose.hitch_x,lean_pose.hitch_y))<.05,"Gentle lean preserves fish centre and tail contact")
	check(horse.clasp_blend>.999 and horse.fish_material.get_shader_parameter("clasp")>.999,"Held pose closes the tail clasp")
	var drifting: Dictionary=lean_pose.duplicate(true)
	drifting.erase("hitch_x")
	drifting.erase("hitch_y")
	drifting.activity="Drifting"
	horse.apply_actor(drifting)
	for i in 120: horse.animate(1.0/30)
	check(horse.clasp_blend<.001 and horse.held_offset.length()<.01,"Release eases the clasp and visual offset back to swimming")
	var hidden: Dictionary=gramma.actor.duplicate(true)
	hidden.home={"kind":"shelter","slot":"cave","i":0}
	hidden.den_x=gramma.position.x
	hidden.den_y=gramma.position.y
	hidden.den_side=-1.0
	hidden.extend=0.0
	hidden.activity="Sleeping"
	gramma.apply_actor(hidden)
	for i in 30: gramma.animate(1.0/30)
	check(not gramma.body_visible and gramma.den_extension==0,"Night gramma body hides fully in the den")
	check(gramma.fish_material.get_shader_parameter("den_clip"),"Den entry uses the local cave clipping shader")
	hidden.extend=1.0
	hidden.activity="Hovering"
	gramma.apply_actor(hidden)
	for i in 30: gramma.animate(1.0/30)
	check(gramma.body_visible and gramma.den_extension==1,"Day gramma emerges fully")
	check(not gramma.fish_material.get_shader_parameter("den_clip") and gramma.visual_offset==Vector2.ZERO,"Fully emerged gramma releases cave clipping and offset")
	hidden.home.kind="rock"
	hidden.extend=0.0
	hidden.activity="Sleeping"
	gramma.apply_actor(hidden)
	for i in 30: gramma.animate(1.0/30)
	check(gramma.body_visible and not gramma.fish_material.get_shader_parameter("den_clip"),"Rock fallback residents remain visible at night")
	check(clown.nestle>0 and clown.visual_offset.y>0,"Clownfish nestling pose settles among the anemone")
	var eating: Dictionary=snapshot.duplicate(true)
	eating.events.append({"seq":eating.next_event,"kind":"ate","id":gramma.individual_id,"live":true})
	eating.next_event+=1
	stage.apply_snapshot(eating)
	check(gramma.bite_timer==.35 and horse.bite_timer==0,"Explicit ate event animates only its actor")
	stage.animate(0)
	check(gramma.bite_timer==.35,"Pause freezes the actual bite")
	tick(stage,.5)
	stage.apply_snapshot(eating)
	check(gramma.bite_timer==0,"The event cursor prevents repeated bites")
	var offline: Dictionary=eating.duplicate(true)
	offline.events.append({"seq":offline.next_event,"kind":"ate","id":gramma.individual_id,"live":false})
	offline.next_event+=1
	stage.apply_snapshot(offline)
	check(gramma.bite_timer==0,"Offline food events do not replay mouth animation")
	check(var_to_bytes(snapshot)==frozen,"Rig updates never mutate snapshots")
	check(var_to_bytes(world.export_state())==before,"Rig interactions preserve simulation and both random states")
	# Replay a complete turn as 0.2 s snapshots, rendering six frames per snapshot.
	var mirror_changes: int=0
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
			if chromis.facing!=previous_facing: mirror_changes+=1
			previous_facing=chromis.facing
	check(mirror_changes==1,"A complete snapshot turn mirrors exactly once")
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
	var side_step: Dictionary={"species":"green_chromis","activity":"Resting","direction":1,"heading":0.0,"speed":0.0,"thrust":0.0,"vx":-6.0,"vy":0.0}
	chromis.apply_actor(side_step)
	for i in 30: chromis.animate(1.0/30)
	check(chromis.pectoral_effort>.08 and chromis.pectoral_effort<.15 and chromis.facing>.99,"Spacing recovery uses a gentle independent pectoral stroke")
	check(chromis.fish_material.get_shader_parameter("tail_drive")<.001,"Resting spacing recovery does not recruit tail propulsion")
	var held_fin: float=chromis.pectoral_phase
	chromis.animate(0)
	check(chromis.pectoral_phase==held_fin,"Pause freezes the independent pectoral stroke")
	side_step.vx=0.0
	chromis.apply_actor(side_step)
	for i in 60: chromis.animate(1.0/30)
	check(chromis.pectoral_effort<.001,"Spacing recovery stroke eases to rest when displacement stops")
	stage.queue_free()
	print(JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
