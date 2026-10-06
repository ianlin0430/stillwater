extends "res://tests/test_obstacles.gd"
# Reporting only: the inherited run, counters, controls and assertions are unchanged.
var seen: Dictionary={}
func body_q(w, a: Dictionary, o: Dictionary) -> float:
	var key: String=str(w.get_instance_id())+"/"+str(a.id)
	var old: Dictionary=seen.get(key,{})
	if old.get("t",-1.0)!=w.state.elapsed:
		var flipped: bool=old.has("direction") and old.direction!=a.direction
		var last: float=old.get("flip_at",-INF)
		if flipped and w.state.elapsed-last<=10.0:
			print("NAV_PAIR "+JSON.stringify({"seed":w.state.seed,"scene":w.state.scene,"t":w.state.elapsed,"animal":a.duplicate(true),"previous":old,"aim":str(w._aim(a)),"route":str(w._route(a)) if a.has("nav_tx") else "direct","home_intent":w.has_method("_has_home_intent") and w._has_home_intent(a)}))
		seen[key]={"t":w.state.elapsed,"direction":a.direction,"flip_at":w.state.elapsed if flipped else last,"p":str(Vector2(a.x,a.y)),"aim":str(w._aim(a)),"target":str(Vector2(a.tx,a.ty)),"nav":a.has("nav_tx")}
	return super.body_q(w,a,o)
