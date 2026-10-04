extends SceneTree
# Reporting only: follow the contract's daylight setup and measure a real excursion.
func _initialize() -> void:
	var rows: Array=[]
	for scene_id: String in ["reef","shipwreck"]:
		var w:=StreamWorld.new(812,1000,scene_id)
		var a: Dictionary=w.state.animals.filter(func(x): return x.species=="clownfish")[0]
		w.state.animals=[a]
		w.state.ledger.initial=w.material()
		w.advance_live(120.0)
		w.state.light_hour=12.0
		for i in 3000:
			w.advance_live(0.2)
			if a.activity=="Nestling": break
		w.advance_live(10.0)
		for i in 3000:
			w.advance_live(0.2)
			if a.activity=="Foraging": break
		var start:=Vector2(a.x,a.y)
		var home:=Vector2(a.home_x,a.home_y)
		var row: Dictionary={"scene":scene_id,"activity":a.activity,"entry_time":w.state.elapsed,"target_offset":home.distance_to(Vector2(a.tx,a.ty)),"travel":0.0,"max_home_distance":home.distance_to(start),"outside_ticks":0}
		for i in 100:
			w.advance_live(0.2)
			var p:=Vector2(a.x,a.y)
			row.travel=maxf(row.travel,start.distance_to(p))
			row.max_home_distance=maxf(row.max_home_distance,home.distance_to(p))
			if not w._clown_inside(p): row.outside_ticks+=1
			if a.activity!="Foraging": break
		row.return_activity=a.activity
		rows.append(row)
	print(JSON.stringify({"rows":rows}))
	quit()
