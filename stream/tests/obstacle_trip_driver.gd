extends RefCounted
# The original S5 forced-trip input, shared with captured regression replay.
static func trip_end(w, a: Dictionary, obs: Array, k: int) -> Vector2:
	var band: Array=w.band(a.species)
	var x: float=(1120.0-float(int(a.id)%4)*80.0) if a.x<640.0 else (160.0+float(int(a.id)%4)*80.0)
	var h: Vector2=ReefFishArt.extent_for(a.species)*w.animal_scale(a)*0.5
	for j in 40:
		var y: float=lerpf(band[0]+h.y,band[1]-h.y,StreamWorld._hash01(int(a.id)*31+k,j))
		if y>=w.bed_y(x)-h.y:
			continue
		if obs.all(func(o): return Vector2((x-o.cx)/(o.rx+h.x),(y-o.cy)/(o.ry+h.y)).length()>=1.0):
			return Vector2(x,y)
	return Vector2(x,band[0]+h.y)

static func step(w, trips: Dictionary, obs: Array) -> void:
	var lead: Dictionary=w.state.animals.filter(func(a): return a.species=="green_chromis")[0]
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
