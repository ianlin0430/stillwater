extends "res://tests/test_obstacles.gd"
# Diagnostic only: original run() schedule, reporting facing and route changes.
var seen: Dictionary={}
func _initialize() -> void:
	for c: Array in [[812,"reef","min"],[5,"shipwreck","min"],[3,"shipwreck","max"]]:
		seen.clear()
		var result: Dictionary=run(c[0],c[1],c[2],false)
		print("PROBE "+JSON.stringify({"case":c,"result":result}))
	print(JSON.stringify({"diagnostic_only":true,"failures":[]}))
	quit()
func body_q(w, a: Dictionary, o: Dictionary) -> float:
	if "--trace-facing" in OS.get_cmdline_user_args():
		var key: int=int(a.id)
		var old: Dictionary=seen.get(key,{})
		if old.get("t",-1.0)!=w.state.elapsed:
			var flipped: bool=old.has("animal") and old.animal.direction!=a.direction
			var route: String=str(w._route(a)) if a.has("nav_tx") else "direct"
			if flipped and (a.species=="royal_gramma" or a.has("nav_tx")):
				print("FACING "+JSON.stringify({"seed":w.state.seed,"scene":w.state.scene,"t":w.state.elapsed,"animal":a.duplicate(true),"previous":old,"route":route,"home_intent":w._has_home_intent(a)}))
			seen[key]={"t":w.state.elapsed,"animal":a.duplicate(true),"route":route}
	return super.body_q(w,a,o)
