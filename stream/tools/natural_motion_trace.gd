extends SceneTree
# Evidence for natural motion (not a test): 180 simulated seconds across day and night, seed 42, of every
# animal's motion fields, one row per 0.2 s tick, written to artifacts/natural-motion/clownfish-<scene>.json.
# godot --headless --path <stream> --script tools/natural_motion_trace.gd -- --scene=reef
# H5: includes clownfish nestle/home and feed, tap, cursor and night transitions.

func _initialize() -> void:
	var scene_id: String="reef"
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--scene="): scene_id=arg.trim_prefix("--scene=")
	var w:=StreamWorld.new(42,1000,scene_id)
	var clown: Dictionary=w.state.animals.filter(func(a): return a.species=="clownfish")[0]
	w.state.light_hour=12.0
	# Settle into ordinary daytime swimming first; one pinch of food at 20 s shows feeding too.
	w.advance_live(30)
	var rows: Dictionary={}
	for i in 900:
		if i==100:
			w.feed(clown.home_x)
		if i==400: w.startle(clown.x,clown.y)
		if i==500: w.set_lure(Vector2(clown.x,clown.y))
		if i==550: w.clear_lure()
		if i==650: w.state.light_hour=1.0
		w.advance_live(0.2)
		for a: Dictionary in w.state.animals:
			var key: String="%s %d" % [a.species,a.id]
			if not rows.has(key):
				rows[key]=[]
			var r: Dictionary={"t":snappedf(w.state.elapsed,0.1),"activity":a.activity,"x":snappedf(a.x,0.01),"y":snappedf(a.y,0.01),"vx":snappedf(a.get("vx",0.0),0.01),"vy":snappedf(a.get("vy",0.0),0.01),"direction":a.direction}
			for k: String in ["heading","pitch","speed","thrust","turn","nestle","home_x","home_y"]:
				if a.has(k):
					r[k]=snappedf(float(a[k]),0.001)
			if a.has("home"): r.home=a.home.duplicate(true)
			rows[key].append(r)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://artifacts/natural-motion"))
	var f:=FileAccess.open("res://artifacts/natural-motion/clownfish-"+scene_id+".json",FileAccess.WRITE)
	f.store_string(JSON.stringify({"seed":42,"scene":scene_id,"start":30.0,"seconds":180.0,"tick":0.2,"fed_at":50.0,"tapped_at":110.0,"lure_at":130.0,"lure_cleared_at":140.0,"night_at":160.0,"animals":rows},"  "))
	f.close()
	# Per-animal summary: speed range and variation, largest heading change per tick.
	var summary: Dictionary={}
	for key: String in rows:
		var sp: Array=rows[key].map(func(r): return r.get("speed",0.0))
		var mean: float=0.0
		for v: float in sp: mean+=v/sp.size()
		var sq: float=0.0
		for v: float in sp: sq+=(v-mean)*(v-mean)/sp.size()
		var dh: float=0.0
		for k in range(1,rows[key].size()):
			dh=maxf(dh,absf(rows[key][k].get("heading",0.0)-rows[key][k-1].get("heading",0.0)))
		summary[key]={"speed_min":snappedf(sp.min(),0.01),"speed_max":snappedf(sp.max(),0.01),"speed_cv":snappedf(sqrt(sq)/maxf(mean,0.0001),0.001),"max_heading_change_per_tick":snappedf(dh,0.001),"thrust_max":snappedf(rows[key].map(func(r): return r.get("thrust",0.0)).max(),0.01)}
	print(JSON.stringify({"failures":[],"scene":scene_id,"path":"res://artifacts/natural-motion/clownfish-"+scene_id+".json","animals":summary}))
	quit()
