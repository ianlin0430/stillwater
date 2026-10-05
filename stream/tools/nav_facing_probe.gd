extends "res://tests/test_obstacles.gd"
# Diagnostic only: original run() schedule, reporting facing and route changes.
var seen: Dictionary={}
func _initialize() -> void:
	for c: Array in [[812,"reef","min"],[5,"shipwreck","min"],[3,"shipwreck","max"]]:
		if c[0] not in seed_list() or c[1] not in arg("scenes",["reef","shipwreck"]) or c[2] not in arg("presets",["min","max"]):
			continue
		seen.clear()
		observed_at=-1.0
		var result: Dictionary=run(c[0],c[1],c[2],false)
		print("PROBE "+JSON.stringify({"case":c,"result":result}))
	print(JSON.stringify({"diagnostic_only":true,"failures":[]}))
	quit()
var observed_at: float=-1.0
func body_q(w, a: Dictionary, o: Dictionary) -> float:
	if "--trace-facing" in OS.get_cmdline_user_args() and observed_at!=w.state.elapsed:
		observed_at=w.state.elapsed
		for fish: Dictionary in w.state.animals:
			var key: int=int(fish.id)
			var old: Dictionary=seen.get(key,{})
			var flipped: bool=old.has("animal") and old.animal.direction!=fish.direction
			var route: String=str(w._route(fish)) if fish.has("nav_tx") else "direct"
			if flipped:
				print("FACING "+JSON.stringify({"seed":w.state.seed,"scene":w.state.scene,"t":w.state.elapsed,"animal":fish.duplicate(true),"previous":old,"route":route,"home_intent":w._has_home_intent(fish)}))
			seen[key]={"t":w.state.elapsed,"animal":fish.duplicate(true),"route":route}
	return super.body_q(w,a,o)
