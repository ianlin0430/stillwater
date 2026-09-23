extends SceneTree
# Live-path movement checks for the 0.4.1 roaming rules.
var failures: Array[String]=[]
var worst_below_bed: float=0.0

func track(seed_value: int, hour: float, ticks: int) -> Dictionary:
	var world:=StreamWorld.new(seed_value,1000)
	world.state.light_hour=hour
	var tracks: Dictionary={}
	for a: Dictionary in world.state.animals.filter(func(x): return x.species!="garden_eel"):
		tracks[a.id]={"species":a.species,"low":a.x,"high":a.x,"previous":Vector2(a.x,a.y),"max_step":0.0,"edge":0,"rim":0,"flip":0,"vy":0.0,"distance":0.0,"still":0,"below":0.0}
	for tick in ticks:
		world.advance_live(0.2)
		for a: Dictionary in world.state.animals:
			if a.species=="garden_eel":
				# Eels never roam: they stay in their burrow (tests/test_world.gd eel_checks).
				if a.x!=a.burrow_x or a.y!=a.burrow_y:
					failures.append("Garden eel left its burrow")
				continue
			if a.species=="shrimp":
				# Every shrimp, including young born mid-run, stays on the bed.
				worst_below_bed=maxf(worst_below_bed,a.y-StreamWorld.floor_y(a.x))
			if not tracks.has(a.id): continue
			var t: Dictionary=tracks[a.id]
			var p:=Vector2(a.x,a.y)
			t.low=minf(t.low,a.x)
			t.high=maxf(t.high,a.x)
			t.max_step=maxf(t.max_step,p.distance_to(t.previous))
			t.distance+=p.distance_to(t.previous)
			t.previous=p
			if a.x<90 or a.x>1190 or not is_finite(a.y):
				failures.append("Invalid movement bounds")
			if a.x<=108 or a.x>=1172:
				t.edge+=1
			if a.activity in ["Resting","Grazing","Surface feeding","Displaying"]:
				t.still+=1
			# Only count reversals big enough to read on screen as a twitch.
			var vy: float=a.get("vy",0.0)
			if absf(vy)>3.0 and absf(t.vy)>3.0 and signf(vy)!=signf(t.vy):
				t.flip+=1
			t.vy=vy
			if a.species=="shrimp":
				t.below=maxf(t.below,a.y-StreamWorld.floor_y(a.x))
			else:
				var band: Array=StreamWorld.DEPTH[a.species]
				if a.y<band[0]-0.01 or a.y>band[1]+0.01:
					failures.append("Fish left its depth band: "+a.species)
				if a.y<=band[0]+1.0 or a.y>=band[1]-1.0:
					t.rim+=1
	var summary: Dictionary={}
	for t: Dictionary in tracks.values():
		var s: Dictionary=summary.get(t.species,{"spans":[],"edge":0.0,"rim":0.0,"flips_per_minute":0.0,"distance":0.0,"resting_share":0.0,"below":0.0,"n":0})
		s.spans.append(snappedf(t.high-t.low,0.1))
		s.edge=maxf(s.edge,float(t.edge)/ticks)
		s.rim=maxf(s.rim,float(t.rim)/ticks)
		s.flips_per_minute=maxf(s.flips_per_minute,float(t.flip)/(ticks*0.2/60.0))
		s.distance+=t.distance
		s.below=maxf(s.below,t.below)
		s.resting_share+=float(t.still)/ticks
		s.n+=1
		summary[t.species]=s
	for species: String in summary:
		var s: Dictionary=summary[species]
		s.distance=snappedf(s.distance/s.n,1.0)
		s.resting_share=snappedf(s.resting_share/s.n,0.001)
		s.edge=snappedf(s.edge,0.001)
		s.rim=snappedf(s.rim,0.001)
		s.flips_per_minute=snappedf(s.flips_per_minute,0.01)
		s.below=snappedf(s.below,0.01)
		s.spans.sort()
	return summary

func check_spans(species: String, s: Dictionary) -> void:
	var ordered: Array=s.spans
	var median: float=ordered[ordered.size()/2]
	if median<(350 if species=="shrimp" else 500):
		failures.append("Ten-minute daytime roaming remains too localized: "+species)
	if ordered[-1]-ordered[0]<20:
		failures.append("Individuals follow overly uniform routes: "+species)

func _initialize() -> void:
	var runs: Array=[]
	for seed_value: int in [42,812,240921]:
		var day: Dictionary=track(seed_value,12.0,9000)
		var night: Dictionary=track(seed_value,2.0,9000)
		for species: String in day:
			var s: Dictionary=day[species]
			check_spans(species,s)
			if s.edge>0.05:
				failures.append("Individuals hug the stream walls: "+species)
			if s.rim>0.15:
				failures.append("Individuals hug a depth-band edge: "+species)
			if s.flips_per_minute>3.0:
				failures.append("High-frequency vertical jitter: "+species)
			if species!="shrimp":
				# Night rules stay as authored; this only confirms they still show.
				if night[species].distance>=s.distance*0.8:
					failures.append("Night no longer slows "+species)
				if night[species].resting_share<=s.resting_share:
					failures.append("Night no longer settles "+species)
		runs.append({"seed":seed_value,"day":day,"night":night})
	# Same tolerance as the long_run depth audit (tests/long_run.gd audit_depth).
	if worst_below_bed>1.0:
		failures.append("Shrimp sank through the stream bed")
	print(JSON.stringify({"runs":runs,"worst_below_bed":snappedf(worst_below_bed,0.01),"failures":failures}))
	quit(0 if failures.is_empty() else 1)
