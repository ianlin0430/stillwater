extends "res://tests/test_natural_motion.gd"
var worst_pair: Dictionary={}
func overlap(w: StreamWorld, a: Dictionary, b: Dictionary) -> float:
	var value: float=super.overlap(w,a,b)
	if a.species==b.species and a.species in ["seahorse","royal_gramma"] and value>worst_pair.get("value",0.0):
		worst_pair={"value":value,"seed":w.state.seed,"time":w.state.elapsed,"a":a.duplicate(true),"b":b.duplicate(true)}
	return value
func _initialize() -> void:
	band_edge_checks()
	separation_checks()
	print("PAIR "+JSON.stringify(worst_pair))
	worst_pair={}
	feeding_checks()
	print("FOODPAIR "+JSON.stringify(worst_pair))
	var passes: Dictionary={}
	for species: String in ["clownfish","seahorse","royal_gramma"]:
		for dy: float in [-30.0,0.0,30.0]:
			passes[species+str(dy)]=night_pass(species,dy)
	var w:=StreamWorld.new(42,1000)
	w.state.light_hour=12.0
	var far: Dictionary={}
	for i in 9000:
		w.advance_live(0.2)
		for a: Dictionary in w.state.animals:
			if a.has("home_x"):
				var d: float=Vector2(a.x,a.y).distance_to(Vector2(a.home_x,a.home_y))
				if d>far.get(a.species,{}).get("distance",0.0):
					far[a.species]={"distance":d,"time":w.state.elapsed,"fish":a.duplicate(true)}
	print(JSON.stringify({"checks":checks,"failures":failures,"numbers":numbers,"passes":passes,"home":far}))
	quit()
