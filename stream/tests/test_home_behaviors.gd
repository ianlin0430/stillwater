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
		fixed_pose_checks(w,check)
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

# Reusable small fixture: no simulation loop, save or additional world startup.
static func fixed_pose_checks(w: StreamWorld, verify: Callable) -> void:
	var hour: float=w.state.light_hour
	var g: Dictionary=w.state.animals.filter(func(a): return a.species=="royal_gramma")[0].duplicate(true)
	g.home.kind="shelter"
	g.x=g.home_x
	g.y=g.home_y
	g.activity="Sheltering"
	g.decision_at=w.state.elapsed+10.0
	verify.call(w._fixed_home_pose(g),"A gramma in its active cave shelter is held")
	g.x+=200.0
	verify.call(not w._fixed_home_pose(g),"A gramma still returning to its cave is mobile")
	g.x=g.home_x
	g.decision_at=w.state.elapsed-1.0
	verify.call(not w._fixed_home_pose(g),"An expired shelter timer does not hold a gramma")
	g.activity="Sleeping"
	w.state.light_hour=12.0
	verify.call(not w._fixed_home_pose(g),"A stale daylight Sleeping label is mobile")
	w.state.light_hour=0.0
	verify.call(w._fixed_home_pose(g),"A nighttime cave sleeper is held")
	g.home.kind="rock"
	verify.call(not w._fixed_home_pose(g),"A rock perch has no clipped den hold")
	g.home.kind="shelter"
	g.activity="Hovering"
	verify.call(not w._fixed_home_pose(g),"An ordinary hovering resident is mobile")
	var h: Dictionary=w.state.animals.filter(func(a): return a.species=="seahorse")[0].duplicate(true)
	h.activity="Hitched"
	h.hitch_x=h.home_x
	verify.call(w._fixed_home_pose(h),"An attached horse is held")
	h.erase("hitch_x")
	verify.call(not w._fixed_home_pose(h),"An unattached horse is mobile")
	w.state.light_hour=hour
