extends SceneTree
# S5-fix (docs/plans/2026-09-28-redesign-backend.md, "S5-fix 判準", written 2026-09-30 before the
# fix and never retuned): the obstacle checks on the first 16 WIDE seeds, both scenes x their "min"
# and "max" decor, with the give-way exclusion S5 added after seeing results taken out again.
# - stuck: a 30 s window (150 ticks) in which a fish trying to get somewhere (not Resting or
#   Startled, over 40 px from its aim, StreamWorld._aim) moves under 15 px net is "no progress",
#   whether or not it was making way for another fish; the only exception is a fish staying within
#   one HOME radius of its own home (every tick of the window). Gates: no-progress windows that are
#   obstacle-related (on a route round an obstacle at any tick of the window, or more than half its
#   ticks within 1.3 x any obstacle widened by the half body) = 0; and no fish has 2 no-progress
#   windows in a row (a window with progress, or the fish arriving/resting, ends a run; a new target
#   drops the unfinished window but not the run);
# - flips: per navigation target (nav_tx/nav_ty unchanged, even across ticks without a route), the
#   facing flips while on a route are at most the reversals the first route planned for that target
#   requires plus one when it started facing away (test_natural_motion `reversals`); a re-plan adds
#   no allowance;
# - hesitation: a facing flip while going round (on a route) or travelling (not Resting, over 40 px
#   from its aim) within 1.5 x an obstacle (widened by the half body) that follows another such flip
#   near the same obstacle within 10 s counts once; per scene/decor/seed the count is at most the
#   count of the same seed, same scene and decor positions with every obstacle taken out (control;
#   "same positions": measured against where the obstacles would be). (Interpretation noted in the
#   S5-fix report: the control has no routes, so "going round" is read as "going round or
#   travelling" on both sides, the same measure for both.)
# - unchanged gates, on the 16 seeds: body/obstacle overlap <= 0.2 away from the fish's own home,
#   centre inside an obstacle 0 ticks, lead-chromis path kinks < 0.25 (test_natural_motion's
#   kinematics measure, default world), step change going round <= 1.25 x open water, heading rate
#   within SWIM.turn, no teleport or relocation, and audit_space's rules (band, swimming width, above
#   the bed, centre outside every obstacle) every tick.
# Run shape (as test_natural_motion obstacle_checks): 15 daytime minutes of ordinary life, then 8
# minutes of trips across the scene for every swimmer (the school leader leads the school).
# Arguments after `--`: --seeds=a,b --scenes=reef --presets=min --parts=obstacles,kinks (to split a
# local run; the default is everything, for CI).
const Trips=preload("res://tests/obstacle_trip_driver.gd")
const Seeds=preload("res://tests/seed_lists.gd")
const COUNT: int = 16
var SWIM: Dictionary=(StreamWorld as Script).get_script_constant_map().get("SWIM",{})
var HOME: Dictionary=(StreamWorld as Script).get_script_constant_map().get("HOME",{})
var checks: int=0
var failures: Array[String]=[]
var numbers: Dictionary={}
var verbose: bool="--verbose" in OS.get_cmdline_user_args()
var stable_horse_pass: bool="--stable-horse-pass" in OS.get_cmdline_user_args()
var trace_hitch_path: bool="--trace-hitch-path" in OS.get_cmdline_user_args()

func check(value: bool, message: String) -> void:
	checks+=1
	if not value:
		failures.append(message)
		printerr("FAIL: "+message)

func arg(name: String, fallback: Array) -> Array:
	for s: String in OS.get_cmdline_user_args():
		if s.begins_with("--"+name+"="):
			return Array(s.trim_prefix("--"+name+"=").split(",",false))
	return fallback

func of(w, species: String) -> Array:
	return w.state.animals.filter(func(x): return x.species==species)

func body(w, a: Dictionary) -> Vector2:
	return ReefFishArt.extent_for(a.species)*w.animal_scale(a)

func raw_q(p: Vector2, o: Dictionary) -> float:
	return Vector2((p.x-o.cx)/o.rx,(p.y-o.cy)/o.ry).length()

func body_q(w, a: Dictionary, o: Dictionary) -> float:
	var h: Vector2=body(w,a)*0.5
	return Vector2((a.x-o.cx)/(o.rx+h.x),(a.y-o.cy)/(o.ry+h.y)).length()

func beside_home(w, a: Dictionary, o: Dictionary) -> bool:
	if not a.has("home_x"):
		return false
	var h: Vector2=body(w,a)*0.5
	return Vector2((a.home_x-o.cx)/(o.rx+h.x),(a.home_y-o.cy)/(o.ry+h.y)).length()<1.0

# (test_natural_motion's, unchanged.)
func reversals(route: PackedVector2Array, facing: float) -> int:
	var n: int=0
	var way: float=facing
	for i in range(1,route.size()):
		var dx: float=route[i].x-route[i-1].x
		if absf(dx)<0.45*route[i].distance_to(route[i-1]) or absf(dx)<0.5:
			continue
		if way!=0.0 and signf(dx)!=way:
			n+=1
		way=signf(dx)
	return n


func _initialize() -> void:
	var started: int=Time.get_ticks_msec()
	var parts: Array=arg("parts",["obstacles","kinks"])
	if not StreamWorld.new(42,1000).has_method("set_decor"):
		check(false,"StreamWorld.set_decor exists (S5)")
	else:
		if "obstacles" in parts:
			obstacle_checks()
		if "kinks" in parts:
			kink_checks()
	numbers.ms=Time.get_ticks_msec()-started
	print(JSON.stringify({"checks":checks,"failures":failures,"numbers":numbers}))
	quit(0 if failures.is_empty() else 1)

func seed_list() -> Array:
	return arg("seeds",Seeds.WIDE.slice(0,COUNT)).map(func(x): return int(x))

# One run: bare = the control (every obstacle taken out after the decor is set, so homes and trip
# ends are the same; obstacles are still measured where they would be).
func run(seed_value: int, scene_id: String, preset: String, bare: bool) -> Dictionary:
	var w: StreamWorld=StreamWorld.new(seed_value,1000,scene_id)
	if trace_hitch_path and not bare:
		w=load("res://tests/obstacle_stall_trace.gd").new(seed_value,1000,scene_id)
		w.set("trace_start",1180.0 if preset=="min" else 1000.0)
		w.set("trace_end",1250.0 if preset=="min" else 1100.0)
	if stable_horse_pass:
		w=load("res://tests/obstacle_horse_pass_probe.gd").new(seed_value,1000,scene_id)
	var d: Dictionary=w.scene.preset(preset)
	var dressed: bool=true
	for slot: String in d:
		dressed=w.set_decor(slot,d[slot]) and dressed
	dressed=dressed and w.state.decor[scene_id]==d
	w.state.light_hour=12.0
	w.state.ecology_remainder=-1.0e9
	var obs: Array=w.scene.obstacles(w.state.decor[scene_id])
	if bare:
		w._obstacles=[]
		w._grids.clear()
		w._routes.clear()
		for a: Dictionary in w.state.animals:
			w._forget_around(a)
	var swim: Array=w.scene.bounds().swim_x
	var lead: Dictionary=of(w,"green_chromis")[0]
	var r: Dictionary={"dressed":dressed,"inside":0,"soft":0.0,"jerk_around":0.0,"jerk_open":0.0,"heading_over":0,"teleports":0,"relocated":0,"audit":0,"detour_ticks":0,"windows":0,"noprog":0,"noprog_home":0,"noprog_obstacle":0,"noprog_list":[],"run_max":0,"run_list":[],"flips":0,"flips_allowed":0,"flips_excess":0,"flip_list":[],"hesitation":0,"hes_route":0,"hes_list":[]}
	var prev: Dictionary={}
	var trips: Dictionary={}
	var window: Dictionary={}
	var runs: Dictionary={}
	var episode: Dictionary={}
	var last_flip: Dictionary={}
	var last_going: Dictionary={}
	var captured: bool=false
	for i in 7000:
		if i>=4500:
			Trips.step(w,trips,obs)
		var requested: Dictionary={}
		if trace_hitch_path and i>=4500:
			for a: Dictionary in of(w,"seahorse"):
				requested[a.id]=Vector2(a.tx,a.ty)
				if not bare and not captured and i== (5900 if preset=="min" else 5000):
					DirAccess.make_dir_recursive_absolute("res://artifacts/obstacle-stall")
					var file:=FileAccess.open("res://artifacts/obstacle-stall/%s-%s-%d-before.var" % [scene_id,preset,seed_value],FileAccess.WRITE)
					file.store_var(w.export_state())
					var context:=FileAccess.open("res://artifacts/obstacle-stall/%s-%s-%d-%s-context.var" % [scene_id,preset,seed_value,"stable" if stable_horse_pass else "baseline"],FileAccess.WRITE)
					context.store_var({"world":w.export_state(),"trips":trips,"tick":i,"window":window,"runs":runs,"obstacles":obs})
					context.close()
					file.close()
					captured=true
		w.advance_live(0.2)
		if trace_hitch_path and i>=4500 and i%5==0 and (1180<=i*.2 and i*.2<=1250 if preset=="min" else 1000<=i*.2 and i*.2<=1100):
			var horses: Array=[]
			for a: Dictionary in of(w,"seahorse"):
				horses.append({"id":a.id,"activity":a.activity,"at":Vector2(a.x,a.y),"requested":requested[a.id],"actual":Vector2(a.tx,a.ty),"aim":w._aim(a),"home":w._hitch_center(a),"hitch_path":a.get("hitch_path",[]),"nav_target":Vector2(a.get("nav_tx",INF),a.get("nav_ty",INF)),"nav_wait":a.get("nav_wait",0),"claims":a.get("pass_claims",[]),"velocity":Vector2(a.vx,a.vy),"heading":a.heading,"direction":a.direction,"trip_face":a.get("trip_intent_face",0),"trip_route":a.get("trip_intent_route",false),"avoid":Vector2(a.get("avoid_x",0),a.get("avoid_y",0)),"body":w._body(a)})
			print("[DIAG-stall] "+JSON.stringify({"scene":scene_id,"preset":preset,"seed":seed_value,"bare":bare,"t":(i+1)*.2,"horses":horses,"neighbors":w.state.animals.filter(func(a): return a.species!="seahorse").map(func(a): return {"id":a.id,"species":a.species,"at":Vector2(a.x,a.y),"velocity":Vector2(a.vx,a.vy),"body":w._body(a),"activity":a.activity})}))
		var t: float=(i+1)*0.2
		for a: Dictionary in w.state.animals:
			var p:=Vector2(a.x,a.y)
			var cruise: float=SWIM[a.species].cruise*(0.82+0.36*float((int(a.id)*37)%101)/100.0)
			# audit_space's rules, every tick.
			var band: Array=w.band(a.species)
			if a.y<band[0] or a.y>band[1] or a.x<swim[0] or a.x>swim[1] or a.y>=w.bed_y(a.x):
				r.audit+=1
			var near: bool=false
			var close: Array=[]
			for oi in obs.size():
				var o: Dictionary=obs[oi]
				if absf(a.x-o.cx)>o.rx+80.0 or absf(a.y-o.cy)>o.ry+80.0:
					continue
				if raw_q(p,o)<1.0:
					r.inside+=1
				var bq: float=body_q(w,a,o)
				near=near or bq<1.3
				if bq<1.5:
					close.append(oi)
				if bq<1.0 and not beside_home(w,a,o):
					r.soft=maxf(r.soft,1.0-bq)
					if verbose and not bare and bq<0.8:
						print("SOFT seed %d %s/%s id %d %s t%.1f at %s obs %d overlap %.3f act %s going %s aim %s" % [seed_value,scene_id,preset,a.id,a.species,t,str(p.round()),oi,1.0-bq,a.activity,str(a.has("nav_tx")),str(w._aim(a).round())])
			if a.has("relocated_at"):
				r.relocated+=1
			var going: bool=a.has("nav_tx")
			if going:
				r.detour_ticks+=1
			var aim: Vector2=w._aim(a)
			var trying: bool=a.activity!="Resting" and a.activity!="Startled" and p.distance_to(aim)>40.0
			if prev.has(a.id):
				var q: Dictionary=prev[a.id]
				var step: Vector2=p-q.p
				var calm: bool=a.activity!="Startled" and q.activity!="Startled"
				if step.length()>0.2*SWIM[a.species].cruise*1.18*2.4*1.35:
					r.teleports+=1
				var rate: float=SWIM[a.species].turn*(SWIM.startle_turn if not calm else 1.0)
				if absf(a.heading-q.heading)>rate*0.2+0.0001:
					r.heading_over+=1
				if q.has("step") and calm:
					var jerk: float=(step-q.step).length()/(0.2*cruise)
					if going or q.going:
						r.jerk_around=maxf(r.jerk_around,jerk)
					elif not near:
						r.jerk_open=maxf(r.jerk_open,jerk)
				var flipped: bool=calm and a.direction!=q.direction
				# Flips per navigation target.
				if going:
					var key:=Vector2(a.nav_tx,a.nav_ty)
					var e: Dictionary=episode.get(a.id,{})
					if e.is_empty() or e.key!=key:
						_close_episode(r,a.id,e,seed_value)
						e={"key":key,"n":0,"allow":reversals(w._route(a),q.direction),"t":t}
						episode[a.id]=e
					if flipped:
						e.n+=1
						if verbose and not bare and e.n>e.allow:
							print("FLIP seed %d %s/%s id %d %s t%.1f at %s n%d allow%d route %s" % [seed_value,scene_id,preset,a.id,a.species,t,str(p.round()),e.n,e.allow,str(Array(w._route(a)).map(func(v): return v.round()))])
				# Hesitation: a second flip within 10 s near the same obstacle.
				if flipped and (going or trying):
					for oi: int in close:
						var k: String="%d/%d" % [a.id,oi]
						if last_flip.has(k) and t-last_flip[k]<=10.0:
							r.hesitation+=1
							if going and last_going.get(k,false):
								r.hes_route+=1
							if r.hes_list.size()<6:
								r.hes_list.append("seed %d id %d %s t%.1f obs %d at %s going=%s" % [seed_value,a.id,a.species,t,oi,str(p.round()),str(going)])
						last_flip[k]=t
						last_going[k]=going
				prev[a.id]={"p":p,"step":step,"activity":a.activity,"going":going,"direction":a.direction,"heading":a.heading}
			else:
				prev[a.id]={"p":p,"activity":a.activity,"going":going,"direction":a.direction,"heading":a.heading}
			# No-progress windows.
			if trying:
				var tgt:=Vector2(a.tx,a.ty)
				var follower: bool=a.species=="green_chromis" and a!=lead
				var s: Dictionary=window.get(a.id,{})
				if s.is_empty() or not follower and s.to!=tgt:
					s={"from":p,"n":0,"going":0,"near":0,"home":0,"to":tgt}
				s.n+=1
				if going:
					s.going+=1
				if near:
					s.near+=1
				if a.has("home_x") and p.distance_to(Vector2(a.home_x,a.home_y))<=HOME[a.species].radius:
					s.home+=1
				if s.n>=150:
					r.windows+=1
					var stalled: bool=p.distance_to(s.from)<15.0
					if stalled and s.home==s.n:
						r.noprog_home+=1
						runs[a.id]=0
					elif stalled:
						r.noprog+=1
						runs[a.id]=runs.get(a.id,0)+1
						var obstacle: bool=s.going>0 or s.near*2>s.n
						if obstacle:
							r.noprog_obstacle+=1
						if verbose and not bare:
							print("NOPROG seed %d %s/%s id %d %s t%.0f at %s aim %s home %s going%d near%d homeT%d obstacle=%s" % [seed_value,scene_id,preset,a.id,a.species,t,str(p.round()),str(aim.round()),str(Vector2(a.get("home_x",-1),a.get("home_y",-1))),s.going,s.near,s.home,str(obstacle)])
						if r.noprog_list.size()<8:
							r.noprog_list.append("seed %d id %d %s t%.0f at %s going%d near%d obstacle=%s" % [seed_value,a.id,a.species,t,str(p.round()),s.going,s.near,str(obstacle)])
						if runs[a.id]>r.run_max:
							r.run_max=runs[a.id]
							r.run_list=["seed %d id %d %s %d windows until t%.0f at %s" % [seed_value,a.id,a.species,runs[a.id],t,str(p.round())]]
					else:
						runs[a.id]=0
					s={"from":p,"n":0,"going":0,"near":0,"home":0,"to":tgt}
				window[a.id]=s
			else:
				window.erase(a.id)
				runs[a.id]=0
	for id in episode:
		_close_episode(r,id,episode[id],seed_value)
	return r

func _close_episode(r: Dictionary, id: int, e: Dictionary, seed_value: int) -> void:
	if e.is_empty():
		return
	r.flips+=e.n
	r.flips_allowed+=e.allow
	var over: int=maxi(0,e.n-e.allow)
	r.flips_excess+=over
	if over>0 and r.flip_list.size()<6:
		r.flip_list.append("seed %d id %d from t%.0f: %d flips, %d allowed" % [seed_value,id,e.t,e.n,e.allow])

func obstacle_checks() -> void:
	var per: Dictionary={}
	var inside: int=0
	var soft: float=0.0
	var jerk_open: float=0.0
	var jerk_around: float=0.0
	var detour: int=0
	var noprog_obstacle: int=0
	var run_max: int=0
	var flips_excess: int=0
	var hes_over: Array=[]
	var other: Dictionary={"heading_over":0,"teleports":0,"relocated":0,"audit":0,"dressed":true}
	var lists: Dictionary={"noprog":[],"runs":[],"flips":[],"hes":[]}
	var seeds: Array=seed_list()
	for scene_id: String in arg("scenes",["reef","shipwreck"]):
		for preset: String in arg("presets",["min","max"]):
			var tag: String=scene_id+"/"+preset
			var row: Dictionary={"soft":0.0,"jerk_around":0.0,"jerk_open":0.0,"inside":0,"detour_ticks":0,"windows":0,"noprog":0,"noprog_home":0,"noprog_obstacle":0,"run_max":0,"flips":0,"flips_allowed":0,"flips_excess":0,"hesitation":{},"control_hesitation":{}}
			for seed_value: int in seeds:
				var r: Dictionary=run(seed_value,scene_id,preset,false)
				var c: Dictionary=run(seed_value,scene_id,preset,true)
				for k: String in ["inside","detour_ticks","windows","noprog","noprog_home","noprog_obstacle","flips","flips_allowed","flips_excess"]:
					row[k]+=r[k]
				for k: String in ["soft","jerk_around","jerk_open"]:
					row[k]=maxf(row[k],r[k])
				row.run_max=maxi(row.run_max,r.run_max)
				row.hesitation[str(seed_value)]=r.hesitation
				row.control_hesitation[str(seed_value)]=c.hesitation
				if r.hesitation>c.hesitation:
					hes_over.append("%s seed %d: %d vs control %d" % [tag,seed_value,r.hesitation,c.hesitation])
					lists.hes.append_array(r.hes_list.slice(0,2))
				for k: String in ["heading_over","teleports","relocated","audit"]:
					other[k]+=r[k]
				other.dressed=other.dressed and r.dressed
				lists.noprog.append_array(r.noprog_list.filter(func(x): return "obstacle=true" in x).slice(0,2))
				if r.run_max>=2:
					lists.runs.append_array(r.run_list)
				lists.flips.append_array(r.flip_list.slice(0,2))
				print("ROW %s seed %d: noprog %d (obstacle %d, run %d) flips %d/%d excess %d hes %d (route %d) vs %d soft %.3f jerk %.3f/%.3f (%d ms)" % [tag,seed_value,r.noprog,r.noprog_obstacle,r.run_max,r.flips,r.flips_allowed,r.flips_excess,r.hesitation,r.hes_route,c.hesitation,r.soft,r.jerk_around,r.jerk_open,Time.get_ticks_msec()])
			for k: String in ["soft","jerk_around","jerk_open"]:
				row[k]=snappedf(row[k],0.001)
			per[tag]=row
			inside+=row.inside
			soft=maxf(soft,row.soft)
			jerk_open=maxf(jerk_open,row.jerk_open)
			jerk_around=maxf(jerk_around,row.jerk_around)
			detour+=row.detour_ticks
			noprog_obstacle+=row.noprog_obstacle
			run_max=maxi(run_max,row.run_max)
			flips_excess+=row.flips_excess
	for k: String in lists:
		lists[k]=lists[k].slice(0,8)
	numbers.obstacles={"seeds":seeds,"per_scene_decor":per,"other":other,"examples":lists}
	check(other.dressed,"Every preset decor is accepted")
	check(inside==0,"No fish centre is ever inside an obstacle (%d ticks inside)" % inside)
	check(soft<=0.2,"Bodies overlap obstacles by at most 0.2 away from their own homes (max %.3f)" % soft)
	check(detour>2000,"Fish do go around obstacles (%d fish-ticks going around)" % detour)
	check(jerk_open>0.0 and jerk_around<=1.25*jerk_open,"Going around is no jerkier than open water (max step change %.3f vs %.3f x 1.25)" % [jerk_around,jerk_open])
	check(other.heading_over==0 and other.teleports==0 and other.relocated==0,"Heading rate, step length and relocation stay within the limits (%d/%d/%d)" % [other.heading_over,other.teleports,other.relocated])
	check(other.audit==0,"Every fish stays in its band, the swimming width and above the bed (%d violations)" % other.audit)
	check(noprog_obstacle==0,"No obstacle-related no-progress window, give-way windows included (%d: %s)" % [noprog_obstacle,str(lists.noprog.slice(0,3))])
	check(run_max<2,"No fish has two no-progress windows in a row (longest run %d: %s)" % [run_max,str(lists.runs.slice(0,3))])
	check(flips_excess==0,"Flips per navigation target stay within the first route's reversals, re-plans add none (%d over: %s)" % [flips_excess,str(lists.flips.slice(0,3))])
	check(hes_over.is_empty(),"Hesitation near obstacles no more than the obstacle-free control, per scene/decor/seed (%d over: %s)" % [hes_over.size(),str(hes_over.slice(0,4))])

# test_natural_motion's path kink measure (lead chromis cruising straight on, default world), on
# the 16 seeds.
func kink_checks() -> void:
	var kinks: float=0.0
	var worst: int=0
	var bends: int=0
	var per: Dictionary={}
	for seed_value: int in seed_list():
		var w:=StreamWorld.new(seed_value,1000)
		w.state.light_hour=12.0
		var lead: Dictionary=of(w,"green_chromis")[0]
		var prev: Dictionary={}
		var most: float=0.0
		for i in 3000:
			w.advance_live(0.2)
			for a: Dictionary in w.state.animals:
				var v:=Vector2(a.vx,a.vy)
				if prev.has(a.id):
					var p: Dictionary=prev[a.id]
					var calm: bool=Vector2(a.get("avoid_x",0.0),a.get("avoid_y",0.0)).length()<1.0 and Vector2(a.x,a.y).distance_to(Vector2(a.tx,a.ty))>40
					if a==lead and calm and a.activity=="Schooling" and v.length()>6 and p.v.length()>6 and absf(cos(a.heading))>0.95 and absf(cos(p.heading))>0.95:
						var bend: float=absf(angle_difference(p.v.angle(),v.angle()))
						bends+=1
						if v.length()>12 and p.v.length()>12:
							most=maxf(most,bend)
				prev[a.id]={"heading":a.heading,"v":v}
		per[str(seed_value)]=snappedf(most,0.001)
		if most>kinks:
			kinks=most
			worst=seed_value
	numbers.kinks={"max":snappedf(kinks,0.001),"worst_seed":worst,"per_seed":per,"samples":bends}
	check(kinks<0.25,"Cruising paths never kink, 16 seeds (max %.3f rad/tick on seed %d)" % [kinks,worst])
