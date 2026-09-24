extends SceneTree
# Live-path movement checks for the 0.4.1 roaming rules (the chromis school and the yellow tang since 2026-09-24).
var failures: Array[String]=[]
# Roaming destinations are clamped to x 130..1150 (StreamWorld._roaming_x).
const SPAN: float=1020.0

func track(seed_value: int, hour: float, ticks: int) -> Dictionary:
	var world:=StreamWorld.new(seed_value,1000)
	world.state.light_hour=hour
	var tracks: Dictionary={}
	for a: Dictionary in world.state.animals.filter(func(x): return x.species in StreamWorld.DEPTH):
		tracks[a.id]={"species":a.species,"low":a.x,"high":a.x,"previous":Vector2(a.x,a.y),"max_step":0.0,"edge":0,"rim":0,"flip":0,"vy":0.0,"distance":0.0,"still":0,"xs":[],"turns":[],"heading":0.0}
	for tick in ticks:
		world.advance_live(0.2)
		for a: Dictionary in world.state.animals:
			if a.species in StreamWorld.HOMES:
				# Eels and firefish never roam: they stay at their burrow (tests/test_world.gd).
				if a.x!=a.burrow_x or a.y!=a.burrow_y:
					failures.append("Burrow dweller left its burrow: "+a.species)
				continue
			if a.species=="lawnmower_blenny":
				# Blennies hop along the bed (tests/test_world.gd blenny_checks).
				if absf(a.y-StreamWorld.floor_y(a.x))>0.0001:
					failures.append("Blenny left the bed")
				continue
			if not tracks.has(a.id): continue
			var t: Dictionary=tracks[a.id]
			var p:=Vector2(a.x,a.y)
			t.low=minf(t.low,a.x)
			t.high=maxf(t.high,a.x)
			t.max_step=maxf(t.max_step,p.distance_to(t.previous))
			t.distance+=p.distance_to(t.previous)
			t.previous=p
			t.xs.append(a.x)
			var vx: float=a.get("vx",0.0)
			if absf(vx)>3.0:
				if t.heading!=0.0 and signf(vx)!=t.heading:
					t.turns.append(a.x)
				t.heading=signf(vx)
			if a.x<90 or a.x>1190 or not is_finite(a.y):
				failures.append("Invalid movement bounds")
			if a.x<=108 or a.x>=1172:
				t.edge+=1
			if a.activity in ["Resting","Surface feeding","Displaying"]:
				t.still+=1
			# Only count reversals big enough to read on screen as a twitch.
			var vy: float=a.get("vy",0.0)
			if absf(vy)>3.0 and absf(t.vy)>3.0 and signf(vy)!=signf(t.vy):
				t.flip+=1
			t.vy=vy
			var band: Array=StreamWorld.DEPTH[a.species]
			if a.y<band[0]-0.01 or a.y>band[1]+0.01:
				failures.append("Fish left its depth band: "+a.species)
			if a.y<=band[0]+1.0 or a.y>=band[1]-1.0:
				t.rim+=1
	var summary: Dictionary={}
	var by_species: Dictionary={}
	for t: Dictionary in tracks.values():
		by_species[t.species]=by_species.get(t.species,[])+[t]
	for t: Dictionary in tracks.values():
		var s: Dictionary=summary.get(t.species,{"spans":[],"edge":0.0,"rim":0.0,"flips_per_minute":0.0,"distance":0.0,"resting_share":0.0,"n":0})
		s.spans.append(snappedf(t.high-t.low,0.1))
		s.edge=maxf(s.edge,float(t.edge)/ticks)
		s.rim=maxf(s.rim,float(t.rim)/ticks)
		s.flips_per_minute=maxf(s.flips_per_minute,float(t.flip)/(ticks*0.2/60.0))
		s.distance+=t.distance
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
		s.spans.sort()
		# Route variety (see check_routes): mean horizontal separation of every pair of
		# individuals over the run, and the spread of the places they turn around.
		var group: Array=by_species[species]
		var pairs: Array=[]
		for i in group.size():
			for j in range(i+1,group.size()):
				var total: float=0.0
				for k in ticks:
					total+=absf(group[i].xs[k]-group[j].xs[k])
				pairs.append(snappedf(total/ticks/SPAN,0.001))
		pairs.sort()
		var turns: Array=[]
		for t: Dictionary in group:
			turns.append_array(t.turns)
		turns.sort()
		s.pair_separation=pairs
		s.turns=turns.size()
		s.turn_iqr=snappedf((turns[turns.size()*3/4]-turns[turns.size()/4])/SPAN,0.001) if turns.size()>=4 else 0.0
	return summary

func check_spans(species: String, s: Dictionary) -> void:
	var ordered: Array=s.spans
	var median: float=ordered[ordered.size()/2]
	if median<500:
		failures.append("Ten-minute daytime roaming remains too localized: "+species)

# Replaces the old "spread of ten-minute spans >= 20 px" test, which was ceiling-bound: every fish
# crosses nearly the whole 1020 px roaming width in ten minutes, so the spans sat at 0.90-1.00 of
# SPAN and their spread said nothing about the routes (seed 812 failed at 18.3 px while the fish
# were as independent as before). Neither measure below saturates:
# - two fish sharing one route (lockstep, held ~90 px apart by the shoaling push) would sit near
#   0.09 of SPAN apart on average; independent fish anywhere in the width average about 1/3;
# - fish bouncing wall to wall would turn only at the two ends (turn IQR near 1.0 of SPAN with no
#   turns in between, or near 0 if all turn at one place); varied routes turn all over the width.
# Green chromis (2026-09-24) school on purpose: for them the pair test is inverted, every pair
# must stay together (mean separation under 0.15 of the width), while the school's turns
# still spread over the width.
func check_routes(species: String, s: Dictionary) -> void:
	if species=="green_chromis":
		if s.pair_separation[-1]>=0.15:
			failures.append("The school falls apart (mean separation %.3f of the width)" % s.pair_separation[-1])
	elif s.pair_separation[0]<0.15:
		failures.append("Two individuals follow one route (mean separation %.3f of the width): %s" % [s.pair_separation[0],species])
	if s.turn_iqr<0.3 or s.turn_iqr>0.9:
		failures.append("Individuals turn around at the same places (turn IQR %.3f of the width): %s" % [s.turn_iqr,species])

func _initialize() -> void:
	# The route checks themselves must flag a lockstep, wall-to-wall route.
	check_routes("synthetic",{"pair_separation":[0.09],"turn_iqr":1.0})
	var seen: bool=failures.size()==2
	failures.clear()
	if not seen:
		failures.append("Route checks miss a uniform synthetic route")
	var runs: Array=[]
	for seed_value: int in [42,812,240921]:
		var day: Dictionary=track(seed_value,12.0,9000)
		var night: Dictionary=track(seed_value,2.0,9000)
		for species: String in day:
			var s: Dictionary=day[species]
			check_spans(species,s)
			check_routes(species,s)
			if s.edge>0.05:
				failures.append("Individuals hug the stream walls: "+species)
			if s.rim>0.15:
				failures.append("Individuals hug a depth-band edge: "+species)
			if s.flips_per_minute>3.0:
				failures.append("High-frequency vertical jitter: "+species)
			# Night rules stay as authored; this only confirms they still show.
			if night[species].distance>=s.distance*0.8:
				failures.append("Night no longer slows "+species)
			if night[species].resting_share<=s.resting_share:
				failures.append("Night no longer settles "+species)
		runs.append({"seed":seed_value,"day":day,"night":night})
	# The swimmers: the chromis school and (2026-09-24) the yellow tang, which roam independently.
	if runs.any(func(r): return r.day.keys()!=["green_chromis","yellow_tang"]):
		failures.append("Roaming does not track exactly the chromis and the yellow tang")
	print(JSON.stringify({"runs":runs,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
