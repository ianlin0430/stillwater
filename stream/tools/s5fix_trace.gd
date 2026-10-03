extends SceneTree
# S5-fix probe (scratch): traces one fish's motion in the test_obstacles run shape.
# -- --seed=31 --scene=shipwreck --preset=min --id=11 --from=60 --to=100 [--every=5]
func arg(n: String, f: String) -> String:
	for s: String in OS.get_cmdline_user_args():
		if s.begins_with("--"+n+"="): return s.trim_prefix("--"+n+"=")
	return f
func _initialize() -> void:
	var sv:=int(arg("seed","31")); var sc:=arg("scene","shipwreck"); var pr:=arg("preset","min")
	var id:=int(arg("id","11")); var t0:=float(arg("from","0")); var t1:=float(arg("to","100")); var every:=int(arg("every","5"))
	var w:=StreamWorld.new(sv,1000,sc)
	var d: Dictionary=w.scene.preset(pr)
	for slot in d: w.set_decor(slot,d[slot])
	w.state.light_hour=12.0
	w.state.ecology_remainder=-1.0e9
	var obs: Array=w.scene.obstacles(w.state.decor[sc])
	var lead: Dictionary=w.state.animals.filter(func(x): return x.species=="green_chromis")[0]
	if arg("debug","0")=="1": w.debug_id=id
	var trips: Dictionary={}
	var TE=load("res://tests/test_obstacles.gd")
	for i in 7000:
		if i>=4500:
			for a: Dictionary in w.state.animals:
				if a.species=="green_chromis" and a!=lead: continue
				if not trips.has(a.id) or Vector2(a.x,a.y).distance_to(Vector2(a.tx,a.ty))<60.0:
					trips[a.id]=trips.get(a.id,0)+1
					var end: Vector2=_trip_end(w,a,obs,trips[a.id])
					a.tx=end.x; a.ty=end.y
					a.activity="Schooling" if a==lead else "Hovering"
				a.decision_at=w.state.elapsed+1.0e6
		w.advance_live(0.2)
		var t:=(i+1)*0.2
		if t<t0 or t>t1 or i%every!=0: continue
		for a in w.state.animals:
			if a.id!=id: continue
			var s:="w%s t%.1f %s hd%.2f tn%.2f sp%.1f p(%.0f,%.0f) v(%.1f,%.1f) dir%d act %s t(%.0f,%.0f) aim %s" % [str(a.has("nav_wait")),t,a.species,a.heading,a.turn,a.speed,a.x,a.y,a.vx,a.vy,a.direction,a.activity,a.tx,a.ty,str(w._aim(a).round())]
			s+=" avoid(%.1f,%.1f)" % [a.get("avoid_x",0.0),a.get("avoid_y",0.0)]
			if a.has("nav_tx"):
				var r: PackedVector2Array=w._radii_of(a)
				var to: Vector2=w._navigate(a,Vector2(a.x,a.y),w._aim(a),r)
				s+=" steer(%.0f,%.0f) wait %s" % [to.x,to.y,str(w._must_wait(a,Vector2(a.x,a.y),(to-Vector2(a.x,a.y)).normalized()))]
			if a.has("nav_tx"):
				s+=" nav k%d from(%.0f,%.0f) to(%.0f,%.0f) route %s" % [a.nav_k,a.nav_x,a.nav_y,a.nav_tx,a.nav_ty,str(Array(w._route(a)).map(func(v): return v.round()))]
			var nb: Array=[]
			for o in w.state.animals:
				if o.id!=a.id and Vector2(o.x,o.y).distance_to(Vector2(a.x,a.y))<90: nb.append("%d@(%.0f,%.0f)" % [o.id,o.x,o.y])
			s+=" nb "+str(nb)
			print(s)
	quit()
func _trip_end(w, a: Dictionary, obs: Array, k: int) -> Vector2:
	var band: Array=w.band(a.species)
	var x: float=(1120.0-float(int(a.id)%4)*80.0) if a.x<640.0 else (160.0+float(int(a.id)%4)*80.0)
	var h: Vector2=ReefFishArt.extent_for(a.species)*w.animal_scale(a)*0.5
	for j in 40:
		var y: float=lerpf(band[0]+h.y,band[1]-h.y,StreamWorld._hash01(int(a.id)*31+k,j))
		if y>=w.bed_y(x)-h.y: continue
		if obs.all(func(o): return Vector2((x-o.cx)/(o.rx+h.x),(y-o.cy)/(o.ry+h.y)).length()>=1.0): return Vector2(x,y)
	return Vector2(x,band[0]+h.y)
