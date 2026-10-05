extends "res://tests/test_natural_motion.gd"
# The original eight-seed obstacle matrix and assertions, without other suites.
func _initialize() -> void:
	obstacle_checks()
	print(JSON.stringify({"checks":checks,"failures":failures,"numbers":numbers}))
	quit(0 if failures.is_empty() else 1)

# Optional reporting hook; the inherited counters and verdict stay unchanged.
var seen: Dictionary={}
func body_q(w, a: Dictionary, o: Dictionary) -> float:
	if "--trace-facing" in OS.get_cmdline_user_args():
		var key: String=str(w.get_instance_id())+"/"+str(a.id)
		var old: Dictionary=seen.get(key,{})
		if old.get("t",-1.0)!=w.state.elapsed:
			if old.has("animal") and old.animal.direction!=a.direction and a.has("nav_tx"):
				print("FACING "+JSON.stringify({"seed":w.state.seed,"scene":w.state.scene,"t":w.state.elapsed,"animal":a.duplicate(true),"previous":old,"route":str(w._route(a))}))
			seen[key]={"t":w.state.elapsed,"animal":a.duplicate(true),"route":str(w._route(a)) if a.has("nav_tx") else "direct"}
	return super.body_q(w,a,o)
