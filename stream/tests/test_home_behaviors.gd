extends SceneTree
var checks: int=0
var failures: Array[String]=[]
func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok: failures.append(message)
func _initialize() -> void:
	for scene_id: String in ReefScene.IDS:
		var w:=StreamWorld.new(42,1000,scene_id)
		w.state.light_hour=0
		w.advance_live(30)
		var horses: Array=w.state.animals.filter(func(a): return a.species=="seahorse")
		check(horses.all(func(a): return a.activity=="Hitched" and a.has("hitch_x") and a.has("hitch_y")),scene_id+": night seahorses hitched")
		check(horses.all(func(a): return Vector2(a.get("hitch_x",INF)-a.home_x,a.get("hitch_y",INF)-a.home_y).length()<.001),scene_id+": tail anchor equals home")
		var grammas: Array=w.state.animals.filter(func(a): return a.species=="royal_gramma")
		check(grammas.all(func(a): return a.activity=="Sleeping" and a.has("den_x") and a.has("extend")),scene_id+": grammas sleep at den")
		var rng_before: int=w.rng.state
		var motion_before: int=w.motion_rng.state
		for a: Dictionary in horses+grammas: w.startle(a.x,a.y)
		check(w.rng.state==rng_before and w.motion_rng.state==motion_before,scene_id+": retreat consumes neither RNG")
		check(grammas.all(func(a): return a.activity=="Sheltering"),scene_id+": grammas retreat on tap")
		check(StreamWorld.validate(w.export_state()),scene_id+": home poses validate")
		var restored:=StreamWorld.new()
		check(restored.restore(w.export_state()),scene_id+": home poses restore")
		w.advance_live(2)
		restored.advance_live(2)
		check(var_to_bytes(w.export_state())==var_to_bytes(restored.export_state()),scene_id+": continued poses are deterministic")
	print(JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
