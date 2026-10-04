extends "res://tools/regress_obstacles.gd"
func scene_parts() -> Array:
	return _selected("scenes",["reef","shipwreck"])
func decor_parts() -> Array:
	return _selected("presets",["min","max"])
func _selected(name: String, fallback: Array) -> Array:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--"+name+"="):
			return Array(arg.trim_prefix("--"+name+"=").split(",",false))
	return fallback
func _initialize() -> void:
	obstacle_checks()
	print(JSON.stringify({"checks":checks,"failures":failures,"numbers":numbers}))
	quit()
func obstacle_checks() -> void:
	var probe:=StreamWorld.new(42,1000)
	if not probe.has_method("set_decor") or not ReefScene.new().has_method("preset"):
		check(false,"StreamWorld.set_decor and ReefScene.preset exist (S5)")
		return
	var inside_ticks: int=0
	var soft: float=0.0
	var open_jerk: float=0.0
	var around_jerk: float=0.0
	var around_ticks: int=0
	var flips: int=0
	var stuck: Array=[]
	var relocated: int=0
	var detours: int=0
	var per: Dictionary={}
	for scene_id: String in scene_parts():
		for preset: String in decor_parts():
			var tag: String=scene_id+"/"+preset
			var row: Dictionary={"inside":0,"soft":0.0,"jerk_around":0.0,"jerk_open":0.0,"flips":0,"stuck":0,"held":0,"detour_ticks":0}
			for seed_value: int in seeds(Seeds.motion()):
				var w: Variant=make(seed_value,scene_id)
				check(dress(w,preset),tag+": the preset decor is accepted")
				w.state.light_hour=12.0
				w.state.ecology_remainder=-1.0e9
				var obs: Array=w.scene.obstacles(w.state.decor[scene_id])
				var lead: Dictionary=of(w,"green_chromis")[0]
				var prev: Dictionary={}
				var trips: Dictionary={}
				var window: Dictionary={}
				var turns: Dictionary={}
				var allowed: Dictionary={}
				for i in 7000:
					if i>=4500:
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
					w.advance_live(0.2)
					for a: Dictionary in w.state.animals:
						var p:=Vector2(a.x,a.y)
						var cruise: float=SWIM[a.species].cruise*(0.82+0.36*float((int(a.id)*37)%101)/100.0)
						var near: bool=false
						for o: Dictionary in obs:
							if absf(a.x-o.cx)>o.rx+60.0 or absf(a.y-o.cy)>o.ry+60.0:
								continue
							if raw_q(p,o)<1.0:
								row.inside+=1
							var bq: float=body_q(w,a,o)
							near=near or bq<1.3
							if bq<1.0 and not beside_home(w,a,o):
								row.soft=maxf(row.soft,1.0-bq)
						if a.has("relocated_at"):
							relocated+=1
						var going: bool=a.has("nav_tx")
						var plan: Array=[a.get("nav_x"),a.get("nav_y"),a.get("nav_tx"),a.get("nav_ty")] if going else []
						if going:
							row.detour_ticks+=1
						if prev.has(a.id):
							var q: Dictionary=prev[a.id]
							var step: Vector2=p-q.p
							if q.has("step") and a.activity!="Startled" and q.activity!="Startled":
								var jerk: float=(step-q.step).length()/(0.2*cruise)
								if going or q.going:
									row.jerk_around=maxf(row.jerk_around,jerk)
								elif not near:
									row.jerk_open=maxf(row.jerk_open,jerk)
							if going and plan==q.plan and a.activity!="Startled" and a.direction!=q.direction:
								turns[a.id]=turns.get(a.id,0)+1
							if plan!=q.plan:
								row.flips+=maxi(0,turns.get(a.id,0)-allowed.get(a.id,0))
								turns.erase(a.id)
								if going:
									allowed[a.id]=reversals(w._route(a),q.direction)
							prev[a.id]={"p":p,"step":step,"activity":a.activity,"going":going,"plan":plan,"direction":a.direction}
						else:
							prev[a.id]={"p":p,"activity":a.activity,"going":going,"plan":plan,"direction":a.direction}
							if going:
								allowed[a.id]=reversals(w._route(a),a.direction)
						# Stuck: 150 ticks (30 s) in a row away from its aim, and hardly anywhere.
						var aim: Vector2=w._aim(a)
						if a.activity!="Resting" and a.activity!="Startled" and p.distance_to(aim)>40.0:
							# (A new target starts a new window.)
							var s: Dictionary=window.get(a.id,{"from":p,"n":0,"held":0,"to":Vector2(a.tx,a.ty)})
							if s.to!=Vector2(a.tx,a.ty):
								s={"from":p,"n":0,"held":0,"to":Vector2(a.tx,a.ty)}
							s.n+=1
							if Vector2(a.get("avoid_x",0.0),a.get("avoid_y",0.0)).length()>1.0:
								s.held+=1
							if s.n>=150:
								if p.distance_to(s.from)<15.0 and s.held*2>s.n:
									row.held+=1
								elif p.distance_to(s.from)<15.0:
									row.stuck+=1
									stuck.append("%s seed %d id %d at %s" % [tag,seed_value,a.id,str(p.round())])
								s={"from":p,"n":0,"held":0,"to":Vector2(a.tx,a.ty)}
							window[a.id]=s
						else:
							window.erase(a.id)
				for id in turns:
					row.flips+=maxi(0,turns[id]-allowed.get(id,0))
			per[tag]=row
			inside_ticks+=row.inside
			soft=maxf(soft,row.soft)
			open_jerk=maxf(open_jerk,row.jerk_open)
			around_jerk=maxf(around_jerk,row.jerk_around)
			around_ticks+=row.detour_ticks
			flips+=row.flips
	for tag: String in per:
		for k: String in ["soft","jerk_around","jerk_open"]:
			per[tag][k]=snappedf(per[tag][k],0.001)
	numbers.obstacles={"per_scene_decor":per,"seeds":seeds(Seeds.motion()),"relocated_ticks":relocated,"stuck":stuck.slice(0,10)}
	check(inside_ticks==0,"No fish centre is ever inside an obstacle, 2 scenes x min/max decor x %d seeds (%d ticks inside)" % [seeds(Seeds.motion()).size(),inside_ticks])
	check(soft<=0.2,"Bodies overlap obstacles by at most 0.2 away from their own homes (max %.3f)" % soft)
	check(around_ticks>2000,"Fish do go around obstacles (%d fish-ticks going around)" % around_ticks)
	check(open_jerk>0.0 and around_jerk<=1.25*open_jerk,"Going around is no jerkier than open water (max step change %.3f vs %.3f x 1.25)" % [around_jerk,open_jerk])
	check(flips==0,"No back and forth: going around one obstacle toward one target a fish never flips its facing (%d flips)" % flips)
	check(stuck.is_empty(),"No fish gets stuck at an obstacle (%d stuck windows: %s)" % [stuck.size(),str(stuck.slice(0,3))])
	check(relocated==0,"Going around never relocates a fish (%d ticks)" % relocated)

