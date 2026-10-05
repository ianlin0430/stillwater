extends "res://tests/test_obstacles.gd"
# Diagnostic only: original run() schedule, reporting facing and route changes.
var seen: Dictionary={}
func _initialize() -> void:
	var cases: Array=[[812,"reef","min"],[5,"shipwreck","min"],[3,"shipwreck","max"]]
	if Array(OS.get_cmdline_user_args()).any(func(s): return s.begins_with("--seeds=") or s.begins_with("--scenes=") or s.begins_with("--presets=")):
		cases.clear()
		for scene_id: String in arg("scenes",["reef","shipwreck"]):
			for preset: String in arg("presets",["min","max"]):
				for seed_value: int in seed_list():
					cases.append([seed_value,scene_id,preset])
	for c: Array in cases:
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
