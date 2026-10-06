extends SceneTree
var checks: int=0
var failures: Array[String]=[]
func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok: failures.append(message)
func _initialize() -> void:
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
