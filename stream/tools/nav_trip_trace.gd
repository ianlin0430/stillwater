extends "res://tests/test_obstacles.gd"
# Diagnostic replay of run()'s world/target schedule. All trip endpoints call the
# original helper; this tool reports snapshots and makes no pass/fail judgment.
func _initialize() -> void:
	var seed_value: int=int(arg("seeds",["17"])[0])
	var scene_id: String=arg("scenes",["shipwreck"])[0]
	var preset: String=arg("presets",["max"])[0]
	var id: int=int(arg("id",["10"])[0])
	var w:=StreamWorld.new(seed_value,1000,scene_id)
	var decor: Dictionary=w.scene.preset(preset)
	for slot: String in decor:
		w.set_decor(slot,decor[slot])
	w.state.light_hour=12.0
	w.state.ecology_remainder=-1.0e9
	var obs: Array=w.scene.obstacles(w.state.decor[scene_id])
	var lead: Dictionary=of(w,"green_chromis")[0]
	var trips: Dictionary={}
	var snapshots: Array=[]
	for i in 7000:
		if i>=4500:
			for a: Dictionary in w.state.animals:
				if a.species=="green_chromis" and a!=lead:
					continue
				if not trips.has(a.id) or Vector2(a.x,a.y).distance_to(Vector2(a.tx,a.ty))<60.0:
					trips[a.id]=trips.get(a.id,0)+1
					var end: Vector2=trip_end(w,a,obs,trips[a.id])
					a.tx=end.x
					a.ty=end.y
					a.activity="Schooling" if a==lead else "Hovering"
					a.decision_at=w.state.elapsed+1.0e6
		w.advance_live(0.2)
		if i%5==0 and w.state.elapsed>=1030.0 and w.state.elapsed<=1120.0:
			for a: Dictionary in w.state.animals:
				if a.id==id:
					snapshots.append({"t":w.state.elapsed,"animal":a.duplicate(true),"aim":str(w._aim(a)),"route":str(w._route(a)) if a.has("nav_tx") else "direct","home_intent":w.has_method("_has_home_intent") and w._has_home_intent(a)})
	print(JSON.stringify({"diagnostic_only":true,"seed":seed_value,"scene":scene_id,"preset":preset,"snapshots":snapshots}))
	quit()
