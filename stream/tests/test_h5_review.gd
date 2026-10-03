extends SceneTree
const RIG=preload("res://tools/review_fixtures/h5_fish_rig.gd")
const Fixture=preload("res://tools/review_fixtures/h5_snapshots.gd")
var checks: int=0
var failures: Array[String]=[]
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok: failures.append(message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var scene:=ReefScene.open("reef")
	for index in 3:
		var species: String=Fixture.SPECIES[index]
		var rig=RIG.new()
		rig.species=species
		root.add_child(rig)
		var definition: Dictionary=scene.decor[Fixture.STYLES[index]]
		var before: PackedByteArray=var_to_bytes(definition)
		var max_error: float=0
		var max_drift: float=0
		var full_width: bool=true
		var inputs_untouched: bool=true
		var hidden: bool=false
		var returned: bool=false
		for frame in 960:
			var t: float=frame/60.0
			var a:=Fixture.actor_at(species,t,definition)
			var input:=var_to_bytes(a)
			rig.position=Vector2(a.x,a.y)
			rig.apply_actor(a)
			rig.animate(1.0/60)
			inputs_untouched=inputs_untouched and var_to_bytes(a)==input
			full_width=full_width and absf(rig.facing)==1 and rig.contact_projection==1
			if species=="seahorse":
				if a.has("hitch_x"): max_error=maxf(max_error,rig.tail_contact().distance_to(Vector2(a.hitch_x,a.hitch_y)))
				else: max_drift=maxf(max_drift,a.speed)
			elif species=="royal_gramma":
				if frame==288: hidden=rig.den_extension==0 and not rig.body_visible and rig.fish_material.get_shader_parameter("den_clip")
				if frame==540: returned=rig.den_extension==1 and rig.body_visible
			else:
				if frame==360: hidden=rig.nestle==1 and rig.visual_offset.y>19
				if frame==720: returned=rig.nestle<.2 and rig.visual_offset.y<5
		check(inputs_untouched and var_to_bytes(definition)==before,species+": review never mutates actor or shared decor")
		check(full_width,species+": direct mirror without squeezed intermediate frames")
		if species=="seahorse":
			check(max_error<.001,"Tail remains on the supplied hitch through lean")
			check(max_drift<=6.0 and max_drift>3.0,"Fixture drifts within 3–6 world units/s away from easing endpoints")
			for side: float in [-1,1]:
				var a:=Fixture.actor_at(species,0,definition)
				a.heading=PI if side<0 else 0.0
				a.direction=side
				a.lean=.3
				rig.position=Vector2(20,-90)
				rig.apply_actor(a)
				rig.animate(.4)
				check(rig.tail_contact().distance_to(Vector2(a.hitch_x,a.hitch_y))<.001,"Mirroring preserves tail contact on side "+str(side))
		else:
			check(hidden,species+": completes readable entry")
			check(returned,species+": emerges again")
			check(rig.modulate.a==1,species+": occlusion does not substitute a whole-body fade")
		var paused: Array=[rig.phase,rig.nestle,rig.den_extension,rig.lean,rig.visual_offset,rig.clasp_blend]
		rig.animate(0)
		check(paused==[rig.phase,rig.nestle,rig.den_extension,rig.lean,rig.visual_offset,rig.clasp_blend],species+": pause freezes the full pose")
		if species=="royal_gramma":
			var a:=Fixture.actor_at(species,0,definition)
			a.home.kind="rock"
			a.extend=.3
			rig.apply_actor(a)
			rig.animate(1)
			check(rig.body_visible and not rig.fish_material.get_shader_parameter("den_clip"),"Rock fallback stays visible; no fictitious cave mouth")
			for side: float in [-1,1]:
				a.home.kind="shelter"
				a.den_side=side
				a.x=a.den_x+side*42
				a.extend=0.0
				rig.position=Vector2(a.x,a.y)
				rig.apply_actor(a)
				rig.animate(1)
				check(not rig.body_visible and rig.fish_material.get_shader_parameter("den_side")==side and ((rig.position+rig.visual_offset).x-a.den_x)*side<0,"Entry clips on the correct side of the cave: "+str(side))
		rig.free()
	print(JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
