extends SceneTree
# S5-fix probe: facing flips per fish (travelling), bare or dressed.
func arg(n: String, f: String) -> String:
	for s: String in OS.get_cmdline_user_args():
		if s.begins_with("--"+n+"="): return s.trim_prefix("--"+n+"=")
	return f
func _initialize() -> void:
	var w:=StreamWorld.new(int(arg("seed","240921")),1000,arg("scene","shipwreck"))
	var d: Dictionary=w.scene.preset(arg("preset","min"))
	for slot in d: w.set_decor(slot,d[slot])
	w.state.light_hour=12.0
	w.state.ecology_remainder=-1.0e9
	if arg("bare","1")=="1":
		w._obstacles=[]; w._grids.clear(); w._routes.clear()
	var prev: Dictionary={}
	var flips: Dictionary={}
	var samples: Array=[]
	for i in int(arg("ticks","4500")):
		w.advance_live(0.2)
		for a in w.state.animals:
			if prev.has(a.id) and prev[a.id]!=a.direction:
				var k: String="%d %s %s" % [a.id,a.species,a.activity]
				flips[k]=flips.get(k,0)+1
				if samples.size()<int(arg("show","0")) and a.id==int(arg("id","-1")):
					var nb: Array=[]
					for o in w.state.animals:
						if o.id!=a.id and Vector2(o.x,o.y).distance_to(Vector2(a.x,a.y))<120: nb.append("%d@(%.0f,%.0f)v(%.1f,%.1f)" % [o.id,o.x,o.y,o.vx,o.vy])
					samples.append("t%.1f p(%.0f,%.0f) v(%.1f,%.1f) t(%.0f,%.0f) avoid(%.1f,%.1f) nb %s" % [i*0.2,a.x,a.y,a.vx,a.vy,a.tx,a.ty,a.avoid_x,a.avoid_y,str(nb)])
			prev[a.id]=a.direction
	print(flips)
	for s in samples: print(s)
	quit()
