extends SceneTree
var failures: Array[String]=[]
func _initialize() -> void:
	var runs: Array=[]
	for seed_value: int in [42,812,240921]:
		var world:=StreamWorld.new(seed_value,1000)
		world.state.light_hour=12.0
		var tracks: Dictionary={}
		for a: Dictionary in world.state.animals:
			tracks[a.id]={"species":a.species,"low":a.x,"high":a.x,"previous":Vector2(a.x,a.y),"max_step":0.0}
		for tick in 3000:
			world.advance_live(0.2)
			for a: Dictionary in world.state.animals:
				if not tracks.has(a.id): continue
				var t: Dictionary=tracks[a.id]
				var p:=Vector2(a.x,a.y)
				t.low=minf(t.low,a.x)
				t.high=maxf(t.high,a.x)
				t.max_step=maxf(t.max_step,p.distance_to(t.previous))
				t.previous=p
				if a.x<90 or a.x>1190 or not is_finite(a.y):
					failures.append("Invalid movement bounds")
		var spans: Dictionary={"shrimp":[],"threadfin":[],"hatchet":[]}
		for t: Dictionary in tracks.values():
			spans[t.species].append(snappedf(t.high-t.low,0.1))
		for species: String in spans:
			var ordered: Array=spans[species].duplicate()
			ordered.sort()
			var median: float=ordered[ordered.size()/2]
			if median<(350 if species=="shrimp" else 500):
				failures.append("Ten-minute daytime roaming remains too localized: "+species)
			if ordered[-1]-ordered[0]<20:
				failures.append("Individuals follow overly uniform routes: "+species)
		runs.append({"seed":seed_value,"horizontal_ranges":spans})
	print(JSON.stringify({"runs":runs,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
