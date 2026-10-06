extends "res://tests/test_obstacles.gd"
var tracked: Dictionary={}
func body_q(w, a: Dictionary, o: Dictionary) -> float:
	var key: int=w.get_instance_id()
	if not tracked.has(key): tracked[key]={}
	var all: Dictionary=tracked[key]
	var previous: Dictionary=all.get(a.id,{})
	if previous.get("time",-1.0)!=w.state.elapsed:
		var going: bool=a.has("nav_tx")
		var plan: Array=[a.get("nav_x"),a.get("nav_y"),a.get("nav_tx"),a.get("nav_ty")] if going else []
		var turns: int=previous.get("turns",0)
		var allowance: int=previous.get("allowance",0)
		if plan!=previous.get("plan",[]):
			turns=0
			allowance=reversals(w._route(a),previous.get("direction",a.direction)) if going else 0
		elif going and a.activity!="Startled" and a.direction!=previous.get("direction",a.direction):
			turns+=1
			if turns>allowance:
				print("EXCESS "+JSON.stringify({"seed":w.state.seed,"scene":w.state.scene,"time":w.state.elapsed,"fish":a,"turns":turns,"allowed":allowance,"route":str(w._route(a))}))
		all[a.id]={"time":w.state.elapsed,"plan":plan,"turns":turns,"allowance":allowance,"direction":a.direction}
	return super.body_q(w,a,o)
