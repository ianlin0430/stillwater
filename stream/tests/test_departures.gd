extends SceneTree
var checks: int=0
var failures: Array[String]=[]
func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok: failures.append(message)

# Exercise presentation actors for every species in the actual authored terrain.
# The original live/offline ecology-trigger and save-continuation checks remain below.
static func all_cast_checks(verify: Callable) -> void:
	for scene_id: String in ReefScene.IDS:
		var world:=StreamWorld.new(42,1000,scene_id)
		var remaining: Array=world.state.animals.map(func(a): return a.id)
		var identities: Array=[]
		var ecology_rng: int=world.rng.state
		var motion_rng: int=world.motion_rng.state
		world._live=true
		for species: String in StreamWorld.ACTIVE_SPECIES:
			var fish: Dictionary=world.state.animals.filter(func(a): return a.species==species)[0]
			identities.append(fish.id)
			remaining.erase(fish.id)
			world._remove(fish,"old age")
		verify.call(world.state.departing.size()==4 and world.state.departing.all(func(a): return a.activity=="Leaving" and a.opacity==1 and a.until-world.state.elapsed<=120),scene_id+": every species receives a bounded visual departure")
		verify.call(world.state.events.filter(func(e): return e.kind=="death" and e.get("leaving",false)).map(func(e): return e.id)==identities,scene_id+": every departure event retains its identity")
		verify.call(world.state.departing.all(func(a): return not a.has("hitch_x") and not a.has("hitch_y") and not a.has("food_id")),scene_id+": departing residents release attachment and feeding state")
		verify.call(absf(world.residual())<.00001 and StreamWorld.validate(world.export_state()),scene_id+": all-species departures preserve material and save validity")
		var ecology: Array=[world.state.resources.duplicate(true),world.state.ledger.duplicate(true),world.state.totals.duplicate(true),world.state.causes.duplicate(true)]
		var finite: bool=true
		for i in 600:
			world.state.elapsed+=.2
			world._move_departing(.2)
			finite=finite and world.state.departing.all(func(a): return is_finite(a.x) and is_finite(a.y) and is_finite(a.opacity) and a.opacity>=0 and a.opacity<=1)
		verify.call(finite and world.state.departing.is_empty(),scene_id+": all four visual actors expire with finite positions and opacity")
		verify.call(world.state.animals.map(func(a): return a.id)==remaining and [world.state.resources,world.state.ledger,world.state.totals,world.state.causes]==ecology,scene_id+": presentation movement changes neither remaining cast nor ecology")
		verify.call(world.rng.state==ecology_rng and world.motion_rng.state==motion_rng,scene_id+": departures draw neither ecology nor motion RNG")

func _initialize() -> void:
	all_cast_checks(check)
	var w:=StreamWorld.new(42,1000)
	var fish: Dictionary=w.state.animals[0]
	var id: int=fish.id
	fish.lifespan=fish.age
	w.advance_live(60)
	check(not w.state.animals.any(func(a): return a.id==id),"Old fish leaves the ecological population immediately")
	check(w.state.archive.any(func(a): return a.id==id),"History retains the identity")
	check(w.state.departing.any(func(a): return a.id==id),"A live old-age departure has a visual actor")
	check(w.state.events.any(func(e): return e.kind=="death" and e.id==id and e.get("leaving",false)),"Event requests quiet departure")
	check(absf(w.residual())<.00001,"Ghost contributes no duplicate material")
	check(StreamWorld.validate(w.export_state()),"Departure save validates")
	var restored:=StreamWorld.new()
	check(restored.restore(w.export_state()),"Departure save restores")
	w.advance_live(10)
	restored.advance_live(10)
	check(var_to_bytes(w.export_state())==var_to_bytes(restored.export_state()),"Departure continuation deterministic")
	w.advance_live(120)
	check(w.state.departing.is_empty(),"Departure expires within two minutes")
	var offline:=StreamWorld.new(42,1000)
	offline.state.animals[0].lifespan=offline.state.animals[0].age
	offline.advance_offline(60)
	check(offline.state.departing.is_empty(),"Offline death never replays a ghost")
	print(JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
