extends RefCounted
const Trips=preload("res://tests/obstacle_trip_driver.gd")

static func run(check: Callable, variant: bool=false) -> Dictionary:
	var results: Dictionary={}
	var home_rules: Dictionary=(StreamWorld as Script).get_script_constant_map().get("HOME",{})
	for label: String in ["shipwreck-min-17","shipwreck-max-42"]:
		var file:=FileAccess.open("res://tests/fixtures/"+label+"-stall.var",FileAccess.READ)
		check.call(file!=null,"Obstacle stall fixture exists: "+label)
		if file==null: continue
		var context: Dictionary=file.get_var()
		file.close()
		var w: StreamWorld=StreamWorld.new()
		if variant: w=load("res://tests/obstacle_horse_pass_probe.gd").new()
		# S5 deliberately freezes ecology with a negative test-only remainder.
		# Validate every real save field with a legal remainder, then restore the
		# original freeze before checking exact state. Do not weaken save rules.
		var loadable: Dictionary=context.world.duplicate(true)
		loadable.ecology_remainder=0.0
		var restored: bool=StreamWorld.validate(loadable) and w.restore(loadable)
		if restored:
			w.state.ecology_remainder=context.world.ecology_remainder
			restored=var_to_bytes(w.export_state())==var_to_bytes(context.world)
		check.call(restored,"Obstacle stall restores exact world and forced-trip input: "+label)
		if not restored: continue
		var windows: Dictionary=context.window
		var runs: Dictionary=context.runs
		var longest: int=0
		var obstacle_stalls: int=0
		var until: int=6300 if "min" in label else 5550
		for i: int in range(context.tick,until):
			# The capture is after this tick's trip assignment, before advance.
			if i!=context.tick: Trips.step(w,context.trips,context.obstacles)
			w.advance_live(.2)
			for a: Dictionary in w.state.animals:
				if a.species!="seahorse": continue
				var p:=Vector2(a.x,a.y)
				if a.activity in ["Resting","Startled"] or p.distance_to(w._aim(a))<=40.0:
					windows.erase(a.id)
					runs[a.id]=0
					continue
				var target:=Vector2(a.tx,a.ty)
				var s: Dictionary=windows.get(a.id,{})
				if s.is_empty() or s.to!=target:
					s={"from":p,"n":0,"going":0,"near":0,"home":0,"to":target}
				s.n+=1
				if a.has("nav_tx"): s.going+=1
				var h: Vector2=ReefFishArt.extent_for(a.species)*w.animal_scale(a)*.5
				var near: bool=context.obstacles.any(func(o): return Vector2((p.x-o.cx)/(o.rx+h.x),(p.y-o.cy)/(o.ry+h.y)).length()<1.3)
				if near: s.near+=1
				if a.has("home_x") and p.distance_to(Vector2(a.home_x,a.home_y))<=home_rules[a.species].radius: s.home+=1
				if s.n>=150:
					if p.distance_to(s.from)<15.0 and s.home!=s.n:
						runs[a.id]=runs.get(a.id,0)+1
						longest=maxi(longest,runs[a.id])
						if s.going>0 or s.near*2>s.n: obstacle_stalls+=1
					else: runs[a.id]=0
					s={"from":p,"n":0,"going":0,"near":0,"home":0,"to":target}
				windows[a.id]=s
		check.call(longest<2,"Exact original stall has no two consecutive no-progress windows: %s (%d)" % [label,longest])
		check.call(obstacle_stalls==0,"Exact original stall has no obstacle-related no-progress window: %s (%d)" % [label,obstacle_stalls])
		results[label]={"longest":longest,"obstacle_stalls":obstacle_stalls}
	return results
