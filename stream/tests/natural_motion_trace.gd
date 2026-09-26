extends SceneTree
# Evidence for natural motion (not a test): 60 simulated daytime seconds, seed 42, of every
# animal's motion fields, one row per 0.2 s tick, written to artifacts/natural-motion/trace.json.
# godot --headless --path . --script tests/natural_motion_trace.gd

func _initialize() -> void:
	var w:=StreamWorld.new(42,1000)
	w.state.light_hour=12.0
	# Settle into ordinary daytime swimming first; one pinch of food at 20 s shows feeding too.
	w.advance_live(30)
	var rows: Dictionary={}
	for i in 300:
		if i==100:
			w.feed(640.0)
		w.advance_live(0.2)
		for a: Dictionary in w.state.animals:
			var key: String="%s %d" % [a.species,a.id]
			if not rows.has(key):
				rows[key]=[]
			var r: Dictionary={"t":snappedf(w.state.elapsed,0.1),"activity":a.activity,"x":snappedf(a.x,0.01),"y":snappedf(a.y,0.01),"vx":snappedf(a.get("vx",0.0),0.01),"vy":snappedf(a.get("vy",0.0),0.01),"direction":a.direction}
			for k: String in ["heading","pitch","speed","thrust","turn","roll","flick","extend"]:
				if a.has(k):
					r[k]=snappedf(float(a[k]),0.001)
			rows[key].append(r)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://artifacts/natural-motion"))
	var f:=FileAccess.open("res://artifacts/natural-motion/trace.json",FileAccess.WRITE)
	f.store_string(JSON.stringify({"seed":42,"start":30.0,"seconds":60.0,"tick":0.2,"fed_at":50.0,"animals":rows},"  "))
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
	print(JSON.stringify(summary))
	quit()
