extends SceneTree
# Natural fish motion (user request 2026-09-25): burst-and-glide speed, rate-limited heading,
# curved paths, soft depth-band edges, body separation, and the per-animal motion fields the rig
# reads (docs/BACKEND_SNAPSHOT_EVENTS.md "Natural motion"). Since S4 (2026-09-28) the cast is the
# chromis, clownfish, seahorse and royal gramma; the tang, firefish and blenny checks went with them.
var checks: int=0
var failures: Array[String]=[]
var numbers: Dictionary={}
# Read at run time so this suite reports failing checks (not a parse error) on older backends.
var SWIM: Dictionary=(StreamWorld as Script).get_script_constant_map().get("SWIM",{"startle_turn":1.0,"green_chromis":{"turn":0.0,"cruise":17.0,"pitch":0.45}})
const NEW: Array[String] = ["clownfish","seahorse","royal_gramma"]

func check(value: bool, message: String) -> void:
	checks+=1
	if not value:
		failures.append(message)
		printerr("FAIL: "+message)

func of(w: StreamWorld, species: String) -> Array:
	return w.state.animals.filter(func(x): return x.species==species)

func only(w: StreamWorld, keep: Callable) -> void:
	for x: Dictionary in w.state.animals.duplicate():
		if not keep.call(x):
			w.state.animals.erase(x)
	w.state.ledger.initial=w.material()-w.state.ledger["in"]+w.state.ledger.out

# Adult art size [length, height] (ReefFishArt.extent_for: the chromis from ReefRig.LOOK, the new
# fish from their approved art), scaled like the rig for juveniles.
func body(w: StreamWorld, a: Dictionary) -> Vector2:
	return ReefFishArt.extent_for(a.species)*w.animal_scale(a)

# How deep two bodies' boxes interpenetrate, as a fraction of the pair's combined half-extents
# on the shallower axis: 0 = boxes apart or touching, 1 = centres coincide.
func overlap(w: StreamWorld, a: Dictionary, b: Dictionary) -> float:
	var r: Vector2=(body(w,a)+body(w,b))*0.5
	return maxf(0.0,minf(1.0-absf(a.x-b.x)/r.x,1.0-absf(a.y-b.y)/r.y))

# Seed list of a multi-seed gate. `--seeds=a,b,c` after `--` overrides every list (for a CI
# sweep over more worlds); without it each gate keeps its own default.
func seeds(fallback: Array) -> Array:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--seeds="):
			return Array(arg.trim_prefix("--seeds=").split(",",false)).map(func(x: String): return x.to_int())
	return fallback

func cv(values: Array) -> float:
	if values.size()<2:
		return 0.0
	var mean: float=0.0
	for v: float in values: mean+=v
	mean/=values.size()
	var sq: float=0.0
	for v: float in values: sq+=(v-mean)*(v-mean)
	return sqrt(sq/values.size())/maxf(mean,0.0001)

func _initialize() -> void:
	var started: int=Time.get_ticks_msec()
	kinematics_checks()
	band_edge_checks()
	separation_checks()
	feeding_checks()
	night_rest_checks()
	determinism_checks()
	obstacle_checks()
	escape_checks()
	numbers.ms=Time.get_ticks_msec()-started
	print(JSON.stringify({"checks":checks,"failures":failures,"numbers":numbers}))
	quit(0 if failures.is_empty() else 1)

# Speed, heading and path shape of the swimmers over ten daytime minutes, three seeds.
func kinematics_checks() -> void:
	var fields_ok: bool=true
	var heading_ok: bool=true
	var no_teleport: bool=true
	var direction_ok: bool=true
	var chromis_speeds: Array=[]
	var chromis_all: Array=[]
	var glide_speeds: Array=[]
	var max_turn: Dictionary={"green_chromis":0.0,"clownfish":0.0,"seahorse":0.0,"royal_gramma":0.0}
	var bends: Array=[]
	var kinks: float=0.0
	for seed_value: int in seeds([42,812,240921]):
		var w:=StreamWorld.new(seed_value,1000)
		w.state.light_hour=12.0
		var lead: Dictionary=of(w,"green_chromis")[0]
		var prev: Dictionary={}
		var run: Dictionary={}
		for i in 3000:
			w.advance_live(0.2)
			for a: Dictionary in w.state.animals:
				fields_ok=fields_ok and ["heading","pitch","speed","thrust","turn"].all(func(k): return a.has(k) and is_finite(float(a[k])))
				fields_ok=fields_ok and a.thrust>=0.0 and a.thrust<=1.0 and a.heading>=0.0 and a.heading<=PI
				if absf(cos(a.heading))>0.05:
					direction_ok=direction_ok and a.direction==signf(cos(a.heading))
				var v:=Vector2(a.vx,a.vy)
				if prev.has(a.id):
					var p: Dictionary=prev[a.id]
					var dh: float=absf(a.heading-p.heading)
					var rate: float=SWIM[a.species].turn*(SWIM.startle_turn if a.activity=="Startled" or p.activity=="Startled" else 1.0)
					heading_ok=heading_ok and dh<=rate*0.2+0.0001
					max_turn[a.species]=maxf(max_turn[a.species],dh)
					no_teleport=no_teleport and Vector2(a.x,a.y).distance_to(p.pos)<=0.2*SWIM[a.species].cruise*1.18*2.4*1.35 and a.get("relocated_at",-1.0)<0
					# Path shape while cruising straight on (not mid-reversal): the direction of travel
					# on screen changes a little every tick (curved), never in a sharp kink.
					# (Dodges around a tang, when avoid_x/avoid_y steer, are quicker on purpose.)
					var calm: bool=Vector2(a.get("avoid_x",0.0),a.get("avoid_y",0.0)).length()<1.0 and Vector2(a.x,a.y).distance_to(Vector2(a.tx,a.ty))>40
					if a==lead and calm and a.activity=="Schooling" and v.length()>6 and p.v.length()>6 and absf(cos(a.heading))>0.95 and absf(cos(p.heading))>0.95:
						var bend: float=absf(angle_difference(p.v.angle(),v.angle()))
						bends.append(bend)
						# A kink shows when the fish is under way (a slow steep climb may swing more,
						# but moves under 2 px a tick).
						if v.length()>12 and p.v.length()>12:
							kinks=maxf(kinks,bend)
				prev[a.id]={"heading":a.heading,"pos":Vector2(a.x,a.y),"v":v,"activity":a.activity}
				# Steady cruising: under way, facing along the path, well short of the destination,
				# for at least 5 s (the first 2 s of each stretch, speeding up, are left out).
				if a==lead:
					var steady: bool=a.activity in ["Schooling","Cruising"] and a.speed>3.0 and absf(cos(a.heading))>0.95 and Vector2(a.x,a.y).distance_to(Vector2(a.tx,a.ty))>120
					if steady:
						run[a.id]=run.get(a.id,[])+[a.speed]
					if not steady or i==2999:
						var r: Array=run.get(a.id,[])
						if r.size()>=25:
							chromis_speeds.append(cv(r.slice(10)))
							chromis_all.append_array(r.slice(10))
						run.erase(a.id)
	# The rowing (smooth) style, now the seahorse's (was the yellow tang's), measured in open water
	# of their own: two seahorses sent on long trips across their band, ten daytime minutes, three
	# seeds (S4 seahorses only swim about their hitch; the steadiness measure needs long stretches).
	for seed_value: int in seeds([42,812,240921]):
		var w:=StreamWorld.new(seed_value,1000)
		only(w,func(x): return x.species=="seahorse")
		w.state.light_hour=12.0
		w.state.ecology_remainder=-1.0e9
		var run: Dictionary={}
		for i in 3000:
			for a: Dictionary in w.state.animals:
				if Vector2(a.x,a.y).distance_to(Vector2(a.tx,a.ty))<150.0:
					a.tx=1100.0 if a.x<640.0 else 180.0
					a.ty=a.y
					a.activity="Hovering"
				a.decision_at=w.state.elapsed+1.0e6
			w.advance_live(0.2)
			for a: Dictionary in w.state.animals:
				var steady: bool=a.speed>1.0 and absf(cos(a.heading))>0.95 and Vector2(a.x,a.y).distance_to(Vector2(a.tx,a.ty))>120 and Vector2(a.avoid_x,a.avoid_y).length()<1.0
				if steady:
					run[a.id]=run.get(a.id,[])+[a.speed]
				if not steady or i==2999:
					var r: Array=run.get(a.id,[])
					if r.size()>=25:
						glide_speeds.append(cv(r.slice(10)))
					run.erase(a.id)
	var chromis_cv: float=0.0
	for c: float in chromis_speeds: chromis_cv+=c/chromis_speeds.size()
	var glide_cv: float=0.0
	for c: float in glide_speeds: glide_cv+=c/glide_speeds.size()
	var mean_bend: float=0.0
	for b: float in bends: mean_bend+=b
	mean_bend/=maxf(1,bends.size())
	numbers.speed={"chromis_lead_cv":snappedf(chromis_cv,0.001),"chromis_min":snappedf(chromis_all.min(),0.01) if not chromis_all.is_empty() else 0.0,"chromis_max":snappedf(chromis_all.max(),0.01) if not chromis_all.is_empty() else 0.0,"seahorse_cv":snappedf(glide_cv,0.001),"stretches":[chromis_speeds.size(),glide_speeds.size()]}
	numbers.heading={"max_change_per_tick":max_turn.duplicate()}
	numbers.path={"mean_bend_per_tick":snappedf(mean_bend,0.0001),"max_bend_per_tick":snappedf(kinks,0.001),"samples":bends.size()}
	check(fields_ok,"Every swimmer carries finite heading (0..pi), pitch, speed, thrust (0..1) and turn")
	check(direction_ok,"direction stays the sign of cos(heading) for older consumers")
	check(heading_ok,"Heading turns at a limited rate: no instant flips (max per tick %s)" % str(max_turn))
	check(max_turn.green_chromis>0.3 and NEW.all(func(k): return max_turn[k]>0.05),"Fish of every species do turn around (heading changes %s)" % str(max_turn))
	check(no_teleport,"No teleports: every step is within the fastest dash and never marked as a relocation")
	check(chromis_cv>0.08 and chromis_cv<0.6,"Chromis swim in bursts and glides: cruising speed varies (CV %.3f)" % chromis_cv)
	check(chromis_speeds.size()>=5 and glide_speeds.size()>=5 and glide_cv<chromis_cv*0.5 and glide_cv<0.08,"Seahorses row more evenly than the chromis (CV %.3f vs %.3f)" % [glide_cv,chromis_cv])
	check(bends.size()>200 and mean_bend>0.004 and kinks<0.25,"Cruising paths curve gently (mean %.4f rad/tick, max %.3f above 12 px/s)" % [mean_bend,kinks])

# A fish heading up into the top of its band eases off instead of stopping dead at the edge.
func band_edge_checks() -> void:
	var w:=StreamWorld.new(42,1000)
	only(w,func(x): return x==of(w,"clownfish")[0])
	w.state.light_hour=12.0
	var t: Dictionary=of(w,"clownfish")[0]
	var band: Array=w.band("clownfish")
	# (S4, the tang's scene scaled to the clownfish's cruise, 12 px/s against the tang's 20: it starts
	# 60 x 12/20 = 36 px below the top, runs 150 x 20/12 = 250 ticks, and heads for x 1150, which it
	# does not reach in that time, so it is the band edge, not the end of its trip, that stops the
	# climb. The thresholds are the tang's.)
	var ticks: int=int(150*20.0/SWIM.clownfish.cruise)
	t.x=500.0
	t.y=band[0]+60.0*SWIM.clownfish.cruise/20.0
	t.tx=1150.0
	t.ty=band[0]-200.0
	t.activity="Hovering"
	t.decision_at=w.state.elapsed+600
	t.heading=0.0
	t.pitch=-SWIM.clownfish.pitch
	t.speed=SWIM.clownfish.cruise
	t.vx=t.speed*cos(t.pitch)
	t.vy=t.speed*sin(t.pitch)
	var inside: bool=true
	var jolt: float=0.0
	var vy0: float=t.vy
	var last: float=t.vy
	for i in ticks:
		w.advance_live(0.2)
		inside=inside and t.y>=band[0]-0.001 and not t.has("relocated_at")
		jolt=maxf(jolt,absf(t.vy-last))
		last=t.vy
	numbers.band_edge={"start_vy":snappedf(vy0,0.01),"max_vy_change_per_tick":snappedf(jolt,0.01),"end_gap":snappedf(t.y-band[0],0.1)}
	check(inside,"A fish steering above its band stays inside it without a relocation")
	check(jolt<2.5 and absf(last)<1.0 and t.y-band[0]<20.0,"It slows its climb smoothly at the band edge (max vy change %.2f px/s per tick)" % jolt)

# Bodies keep apart (Codex recording 2026-09-25; since S4 the new cast): two fish of one species
# with a home of their own (seahorse, gramma) by the old tang-tang limit, a chromis and any other
# fish by the old chromis-tang limits. (Clownfish sharing their anemone nestle together, plan §3.1.)
func separation_checks() -> void:
	var same_max: float=0.0
	var same_share: float=0.0
	var mixed_max: float=0.0
	var mixed_ticks: int=0
	var ticks: int=0
	var spread_sum: float=0.0
	var per_seed: Dictionary={}
	for seed_value: int in seeds([42,812,240921,7,11,314,2]):
		var w:=StreamWorld.new(seed_value,1000)
		w.state.light_hour=12.0
		var seed_max: float=0.0
		var seed_deep: int=0
		for i in 4500:
			w.advance_live(0.2)
			ticks+=1
			var ch: Array=of(w,"green_chromis")
			var others: Array=w.state.animals.filter(func(x): return x.species!="green_chromis")
			for k: String in ["seahorse","royal_gramma"]:
				var g: Array=of(w,k)
				for m in g.size():
					for n in range(m+1,g.size()):
						var o: float=overlap(w,g[m],g[n])
						same_max=maxf(same_max,o)
						if o>0.0: same_share+=1
			for t: Dictionary in others:
				for c: Dictionary in ch:
					var o: float=overlap(w,t,c)
					seed_max=maxf(seed_max,o)
					if o>0.25: seed_deep+=1
			var c0:=Vector2.ZERO
			for c: Dictionary in ch: c0+=Vector2(c.x,c.y)
			c0/=ch.size()
			var s: float=0.0
			for c: Dictionary in ch: s+=c0.distance_to(Vector2(c.x,c.y))
			spread_sum+=s/ch.size()
		mixed_max=maxf(mixed_max,seed_max)
		mixed_ticks+=seed_deep
		per_seed[str(seed_value)]=[snappedf(seed_max,0.001),seed_deep]
	numbers.same_species_overlap={"max_fraction":snappedf(same_max,0.001),"ticks_touching_share":snappedf(same_share/ticks,0.0001)}
	numbers.chromis_through_others={"max_fraction":snappedf(mixed_max,0.001),"ticks_over_quarter":mixed_ticks,"per_seed_max_and_deep_ticks":per_seed}
	numbers.school_spread=snappedf(spread_sum/ticks,0.1)
	check(same_max<=0.2,"Two seahorses or two grammas never overlap by more than a fifth of their bodies (max %.3f)" % same_max)
	check(mixed_max<=0.4 and mixed_ticks<ticks*0.002,"Chromis and the other fish go around each other (max %.3f, %d deep ticks)" % [mixed_max,mixed_ticks])
	check(spread_sum/ticks<StreamWorld.CHROMIS.regroup*0.6,"The school stays together (mean spread %.1f px)" % (spread_sum/ticks))

# Pinches over the new fish's homes, beside the school: every species still eats, and two
# seahorses or two grammas keep apart while feeding. (S4: the chromis are full for the first three
# pinches and hungry for the last. Hungry chromis sink nothing past their band, so beside a hungry
# school the fish below it get no pellet until S12 gives each species its own feeding.)
func feeding_checks() -> void:
	var w:=StreamWorld.new(42,1000)
	w.state.light_hour=12.0
	w.advance_live(10)
	for a: Dictionary in w.state.animals:
		a.energy=StreamWorld.SPECIES[a.species].reserve if a.species=="green_chromis" else 1.0
	w.state.ledger.initial=w.material()-w.state.ledger["in"]+w.state.ledger.out
	var worst: float=0.0
	var eaters: Dictionary={}
	var cursor: int=w.state.next_event-1
	var spots: Array=NEW.map(func(k): return of(w,k)[0].home_x)
	spots.append(of(w,"green_chromis")[0].x)
	for k in 4:
		if k==3:
			for c: Dictionary in of(w,"green_chromis"):
				c.energy=1.0
			w.state.ledger.initial=w.material()-w.state.ledger["in"]+w.state.ledger.out
		w.feed(spots[k])
		for i in 450:
			w.advance_live(0.2)
			for sp: String in ["seahorse","royal_gramma"]:
				var g: Array=of(w,sp)
				worst=maxf(worst,overlap(w,g[0],g[1]))
			for e: Dictionary in StreamWorld.events_after(w.state.events,cursor):
				if e.kind=="ate": eaters[e.id]=true
			cursor=w.state.next_event-1
	var ate: Dictionary={}
	for sp: String in StreamWorld.ACTIVE_SPECIES:
		ate[sp]=of(w,sp).filter(func(a): return eaters.has(a.id)).size()
	numbers.feeding={"same_species_overlap_max":snappedf(worst,0.001),"eaters":eaters.size(),"by_species":ate}
	check(NEW.all(func(k): return ate[k]>=1),"Hungry clownfish, seahorses and grammas reach food over their homes (%s)" % str(ate))
	check(ate.green_chromis>=1,"Chromis still reach food beside them")
	check(worst<=0.2,"Feeding seahorses and grammas keep apart (max overlap %.3f)" % worst)
	check(absf(w.residual())<0.00001,"Feeding keeps the ledger balanced")

# Night rest (user 2026-09-26: the chromis jittered up and down while resting at night): a slow,
# smooth hover with no repeated small up/down corrections. A vertical reversal is counted when a
# resting fish turns back by at least 0.5 px from its last vertical extreme. Before the fix: worst
# 4.06, mean 1.92 per minute (a resting leader crept to new spots, the slots breathed vertically,
# and spacing and small arrival corrections fought each other).
# The big fish goes around the small one (user decision 2026-09-27; replaces the sideways slide of
# 2026-09-26): a resting chromis stays nearly still when a tang passes and the tang goes around it.
# Since S4 (2026-09-28) "a tang" in this gate is any fish of another species (clownfish, seahorse,
# royal gramma) swimming close by: the tang is gone, the thresholds are unchanged.
# A pass is a run of ticks in which a swimming tang is close to a settled resting fish (within 1.5 x
# the pair's half boxes on both axes; until the 2026-09-27 review: a run in which the fish itself
# gave way, which no longer happens, so it measured nothing; a first version of the new measure
# also counted resting tangs lying beside the school for 100 s and fish still gliding into their
# slots at up to 18 px/s, which is the school settling, not a tang passing); there must be passes, and no pass may carry the fish
# CHROMIS.hold (10 px) sideways or 0.5 px (the reversal unit) up or down in total travel. At night
# the tangs keep out of the school as by day (the day gate's numbers: box overlap <= 0.4, deep
# pairs deeper than a quarter under 0.2 % of the ticks; until the 2026-09-27 review, of the
# tang-chromis tick pairs, 12 x looser).
# Thresholds from that spec, set before measuring.
func night_rest_checks() -> void:
	var worst: float=0.0
	var total_rev: int=0
	var own_rev: int=0
	var total_min: float=0.0
	var fast: float=0.0
	var episodes: Array=[]
	var mixed_max: float=0.0
	var mixed_deep: int=0
	var pairs: int=0
	var ticks: int=0
	var per_seed: Dictionary={}
	# 7, 11, 314 and 2: regression seeds shared with the day separation gate.
	for seed_value: int in seeds([42,812,240921,7,11,314,2]):
		var w:=StreamWorld.new(seed_value,1000)
		w.state.light_hour=1.0
		w.advance_live(60)
		var seed_max: float=0.0
		var seed_deep: int=0
		var seed_rev: int=0
		var seed_min: float=0.0
		var dodged: Dictionary={}
		var ext: Dictionary={}
		var way: Dictionary={}
		var revs: Dictionary={}
		var rest: Dictionary={}
		var at: Dictionary={}
		var episode: Dictionary={}
		for i in 3000:
			w.advance_live(0.2)
			ticks+=1
			for t: Dictionary in w.state.animals.filter(func(x): return x.species!="green_chromis"):
				for c: Dictionary in of(w,"green_chromis"):
					var o: float=overlap(w,t,c)
					seed_max=maxf(seed_max,o)
					pairs+=1
					if o>0.25: seed_deep+=1
			for a: Dictionary in of(w,"green_chromis"):
				var giving: bool=Vector2(a.get("avoid_x",0.0),a.get("avoid_y",0.0)).length()>0.2
				# Last time it was giving way to a body (a tang swimming past).
				if giving:
					dodged[a.id]=w.state.elapsed
				# A tang swimming close by (not resting or grazing; within 1.5 x the pair's half boxes on
				# both axes) of a settled resting chromis (under 1 px/s, within CHROMIS.hold of its
				# spot): how far the chromis travels (sideways, up or down) while the tang is near.
				var was: Vector2=at.get(a.id,Vector2(a.x,a.y))
				at[a.id]=Vector2(a.x,a.y)
				var near: bool=w.state.animals.filter(func(x): return x.species!="green_chromis").any(func(t): return not t.activity in ["Resting","Grazing"] and absf(t.x-a.x)<(body(w,t).x+body(w,a).x)*0.75 and absf(t.y-a.y)<(body(w,t).y+body(w,a).y)*0.75)
				if near and a.activity=="Resting" and (episode.has(a.id) or Vector2(a.vx,a.vy).length()<1.0 and Vector2(a.tx,a.ty).distance_to(Vector2(a.x,a.y))<StreamWorld.CHROMIS.hold):
					var e: Vector2=episode.get(a.id,Vector2.ZERO)
					episode[a.id]=e+(Vector2(absf(a.x-was.x),absf(a.y-was.y)) if episode.has(a.id) else Vector2.ZERO)
				elif episode.has(a.id):
					episodes.append(episode[a.id])
					episode.erase(a.id)
				if a.activity!="Resting":
					ext.erase(a.id)
					continue
				rest[a.id]=rest.get(a.id,0.0)+0.2
				if not ext.has(a.id):
					ext[a.id]=a.y
					way[a.id]=0
					continue
				fast=maxf(fast,absf(a.vy))
				var d: int=way[a.id]
				var moved: float=a.y-ext[a.id]
				if d==0:
					if absf(moved)>=0.5:
						way[a.id]=int(signf(moved))
						ext[a.id]=a.y
				elif moved*d>0.0:
					ext[a.id]=a.y
				elif absf(moved)>=0.5:
					revs[a.id]=revs.get(a.id,0)+1
					if w.state.elapsed-dodged.get(a.id,-INF)>5.0:
						own_rev+=1
					way[a.id]=-d
					ext[a.id]=a.y
		episodes.append_array(episode.values())
		for id in rest:
			if rest[id]>=60.0:
				worst=maxf(worst,revs.get(id,0)/(rest[id]/60.0))
			total_rev+=revs.get(id,0)
			total_min+=rest[id]/60.0
			seed_rev+=revs.get(id,0)
			seed_min+=rest[id]/60.0
		mixed_max=maxf(mixed_max,seed_max)
		mixed_deep+=seed_deep
		per_seed[str(seed_value)]={"tang_overlap_max":snappedf(seed_max,0.001),"deep_pairs":seed_deep,"reversals_per_min":snappedf(seed_rev/maxf(seed_min,0.001),0.01),"resting_minutes":snappedf(seed_min,0.1)}
	# S4: the new fish rest at their homes at night and rarely pass the school, so each also swims
	# across a resting chromis on purpose (both in their bands, head-on and 30 px above and below).
	for sp: String in NEW:
		for dy: float in [0.0,-30.0,30.0]:
			var r: Dictionary=night_pass(sp,dy)
			if r.passed:
				episodes.append(r.travel)
			else:
				episodes.append(Vector2(INF,INF))
			mixed_max=maxf(mixed_max,r.overlap)
			mixed_deep+=r.deep
	var mean: float=total_rev/maxf(total_min,0.001)
	var own: float=own_rev/maxf(total_min,0.001)
	var far:=Vector2.ZERO
	for e: Vector2 in episodes: far=Vector2(maxf(far.x,e.x),maxf(far.y,e.y))
	numbers.tang_passing_resting_chromis={"episodes":episodes.size(),"max_sideways_px":snappedf(far.x,0.01),"max_up_down_px":snappedf(far.y,0.01)}
	numbers.night_rest={"worst_reversals_per_min":snappedf(worst,0.01),"mean_reversals_per_min":snappedf(mean,0.01),"mean_without_a_passing_body_per_min":snappedf(own,0.01),"resting_fish_minutes":snappedf(total_min,0.1),"max_vy":snappedf(fast,0.01),"tang_overlap_max":snappedf(mixed_max,0.001),"deep_pairs":mixed_deep,"pairs":pairs,"ticks":ticks,"per_seed":per_seed}
	check(total_min>60.0,"Chromis rest at night (%.1f fish-minutes)" % total_min)
	# Unprovoked up/down corrections are gone. A resting fish no longer dodges a tang up or down
	# (2026-09-26: dodging and gliding back left 0.94 worst / 0.24 mean per minute); the tang goes
	# around it (2026-09-27).
	check(own<=0.05,"Resting chromis never bob on their own (%.2f vertical reversals per minute away from a passing tang; was 1.92 in all)" % own)
	check(worst<=1.0 and mean<=0.2,"Resting chromis reverse at most about once a minute even with tangs passing (worst %.2f, mean %.2f per minute; was 4.06 / 1.92, then 0.94 / 0.24 dodging tangs up and down)" % [worst,mean])
	# Measured whenever a tang comes close to a resting chromis (was: while the chromis itself gave
	# way, which it no longer does, so it measured nothing after 2026-09-27); it must see passes.
	check(not episodes.is_empty() and far.x<StreamWorld.CHROMIS.hold and far.y<0.5,"A resting chromis stays nearly still while a tang passes close by (%d passes, at most %.2f px sideways and %.2f px up or down)" % [episodes.size(),far.x,far.y])
	# Deep tang-chromis pairs per tick, the day separation gate's measure (was per pair, 12 x looser).
	check(mixed_max<=0.4 and mixed_deep<ticks*0.002,"At night the tangs go around the resting school (max overlap %.3f, %d deep pairs in %d ticks)" % [mixed_max,mixed_deep,ticks])

# One resting chromis at night and one fish of `species` swimming past it (from 300 px on one
# side to 300 px on the other, `dy` px off its depth). How far the chromis travels while the other
# is close (the night gate's pass measure), the deepest box overlap and deep ticks, and whether it
# got past within 60 s.
func night_pass(species: String, dy: float) -> Dictionary:
	var w:=StreamWorld.new(42,1000)
	w.state.light_hour=1.0
	var c: Dictionary=of(w,"green_chromis")[0]
	var f: Dictionary=of(w,species)[0]
	only(w,func(x): return x==c or x==f)
	w.state.ecology_remainder=-1.0e9
	var cb: Array=w.band("green_chromis")
	var fb: Array=w.band(species)
	var y: float=clampf((maxf(cb[0],fb[0])+minf(cb[1],fb[1]))*0.5,maxf(cb[0],fb[0])+40.0,minf(cb[1],fb[1])-40.0)
	var at:=Vector2(640,y)
	c.merge({"x":at.x,"y":at.y,"tx":at.x,"ty":at.y,"vx":0.0,"vy":0.0,"activity":"Resting","decision_at":w.state.elapsed+1.0e6,"direction":-1.0,"heading":PI,"pitch":0.0,"speed":0.0,"thrust":0.0,"turn":0.0,"avoid_x":0.0,"avoid_y":0.0},true)
	var fy: float=clampf(y+dy,fb[0],fb[1])
	f.merge({"x":340.0,"y":fy,"tx":940.0,"ty":fy,"vx":SWIM[species].cruise,"vy":0.0,"activity":"Hovering","decision_at":w.state.elapsed+1.0e6,"direction":1.0,"heading":0.0,"pitch":0.0,"speed":SWIM[species].cruise,"thrust":0.3,"turn":0.0,"avoid_x":0.0,"avoid_y":0.0},true)
	var r: Dictionary={"travel":Vector2.ZERO,"overlap":0.0,"deep":0,"passed":false}
	var was:=Vector2(c.x,c.y)
	for i in 300 if species!="seahorse" else 1200:
		w.advance_live(0.2)
		var near: bool=absf(f.x-c.x)<(body(w,f).x+body(w,c).x)*0.75 and absf(f.y-c.y)<(body(w,f).y+body(w,c).y)*0.75
		if near:
			r.travel+=Vector2(absf(c.x-was.x),absf(c.y-was.y))
		was=Vector2(c.x,c.y)
		var o: float=overlap(w,f,c)
		r.overlap=maxf(r.overlap,o)
		if o>0.25: r.deep+=1
		r.passed=r.passed or f.x-c.x>=(body(w,f).x+body(w,c).x)*0.5
	return r

func determinism_checks() -> void:
	var a:=StreamWorld.new(812,1000)
	var b:=StreamWorld.new(812,1000)
	for w: StreamWorld in [a,b]:
		w.state.light_hour=12.0
		w.advance_live(300)
		w.feed(640.0)
		w.startle(600,300,1.0)
		w.advance_live(300)
	check(var_to_bytes(a.export_state())==var_to_bytes(b.export_state()),"Motion is deterministic for a fixed seed")
	var c:=StreamWorld.new()
	check(c.restore(a.export_state()) and StreamWorld.validate(a.export_state()),"A world with motion fields saves and validates")
	var bad: Dictionary=a.export_state()
	bad.animals.filter(func(x): return x.species=="clownfish")[0].heading=NAN
	check(not StreamWorld.validate(bad),"Non-finite heading rejected")
	# Older saves without the motion fields still move.
	var old: Dictionary=StreamWorld.new(42,1000).export_state()
	for x: Dictionary in old.animals:
		for k: String in ["heading","pitch","speed","thrust","turn"]:
			x.erase(k)
	var o:=StreamWorld.new()
	check(o.restore(old),"A save without motion fields loads")
	o.state.light_hour=12.0
	o.advance_live(30)
	check(o.state.animals.all(func(x): return x.has("heading")),"It gains motion fields on the first live tick")
	var t0: int=Time.get_ticks_usec()
	var p:=StreamWorld.new(42,1000)
	p.state.light_hour=12.0
	p.advance_live(600)
	numbers.us_per_tick=snappedf(float(Time.get_ticks_usec()-t0)/3000.0,0.1)

# --- Obstacles (S5, plan §3.2; user 2026-09-28: decor is an obstacle the fish go around, never
# through; the motion is smooth and natural, never realistic: one gentle arc, no jitter, no
# sudden switch). Thresholds written before the first measurement (2026-09-29):
# - hard: no fish centre is ever inside an obstacle ellipse (terrain + decor): 0 ticks;
# - soft: a body overlaps an obstacle by at most 0.2 (1 - q, q the centre's distance in the ellipse
#   widened by the half body; the fish-to-fish measure's 0.2), except an obstacle beside the
#   fish's own home (its home point inside that widened ellipse: a gramma at its cave);
# - no jitter: going around, the step-to-step change of a fish's displacement (per 0.2 s cruise)
#   is at most 1.25 x the largest one the same runs show away from any obstacle;
# - no back and forth: while following one route round obstacles (not startled) a fish flips its
#   facing no more often than the route itself turns back across the screen (between legs that
#   run clearly sideways, |dx| >= 0.45 x their length, the world's own rule for turning round),
#   plus once at the start when it faces away from the route's first such leg;
#   (first written, for a tangent-following design, as "going round one obstacle toward one target
#   a fish never flips its facing"; with routes the route may have to double back, so a flip it
#   requires is allowed and any other is not);
# - never stuck: no 30 s window in which a fish that is not resting stays over 40 px from where it
#   aims (StreamWorld._aim) and moves less than 15 px net; never marked relocated. (Windows in which
#   it spent most ticks making way for another fish, avoid_x/avoid_y over 1 px/s, are counted and
#   reported apart: two fish holding each other up happens with no obstacle at all, S4's body
#   separation, and is not what this slice changes.)
# Every scene x its "min" and "max" decor (ReefScene.preset) x the 8 motion seeds
# (tests/seed_lists.gd), 15 daytime minutes of ordinary life and then 8 minutes of trips across
# the whole scene for every swimmer (the school leader leads the school), so each one meets the obstacles.
const Seeds=preload("res://tests/seed_lists.gd")

# (Untyped, so this suite reports failing checks rather than a parse error on a backend without S5.)
func make(seed_value: int, scene_id: String) -> Variant:
	var cls: Variant=StreamWorld
	return cls.new(seed_value,1000,scene_id)

func dress(w: Variant, preset: String) -> bool:
	var d: Dictionary=w.scene.preset(preset)
	for slot: String in d:
		if not w.set_decor(slot,d[slot]):
			return false
	return w.state.decor[w.state.scene]==d

func raw_q(p: Vector2, o: Dictionary) -> float:
	return Vector2((p.x-o.cx)/o.rx,(p.y-o.cy)/o.ry).length()

func body_q(w: StreamWorld, a: Dictionary, o: Dictionary) -> float:
	var h: Vector2=body(w,a)*0.5
	return Vector2((a.x-o.cx)/(o.rx+h.x),(a.y-o.cy)/(o.ry+h.y)).length()

func beside_home(w: StreamWorld, a: Dictionary, o: Dictionary) -> bool:
	if not a.has("home_x"):
		return false
	var h: Vector2=body(w,a)*0.5
	return Vector2((a.home_x-o.cx)/(o.rx+h.x),(a.home_y-o.cy)/(o.ry+h.y)).length()<1.0

# A trip end for fish a: far across the scene, at a depth in its band clear of every obstacle.
# How often a route turns back across the screen: sign changes of x between legs that run clearly
# sideways (|dx| >= 0.45 x the leg), counting a fish facing `facing` at its start as a first leg.
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

func trip_end(w: StreamWorld, a: Dictionary, obs: Array, k: int) -> Vector2:
	var band: Array=w.band(a.species)
	# (Each fish its own end, spread over the far third, so trips do not all meet at one spot.)
	var x: float=(1120.0-float(int(a.id)%4)*80.0) if a.x<640.0 else (160.0+float(int(a.id)%4)*80.0)
	var h: Vector2=body(w,a)*0.5
	for j in 40:
		var y: float=lerpf(band[0]+h.y,band[1]-h.y,StreamWorld._hash01(int(a.id)*31+k,j))
		if y>=w.bed_y(x)-h.y:
			continue
		if obs.all(func(o): return Vector2((x-o.cx)/(o.rx+h.x),(y-o.cy)/(o.ry+h.y)).length()>=1.0):
			return Vector2(x,y)
	return Vector2(x,band[0]+h.y)

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
	for scene_id: String in ["reef","shipwreck"]:
		for preset: String in ["min","max"]:
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

# Decor set down over a fish (set_decor): it is not moved at once, and swims out smoothly within
# 10 s, never back in, never faster than it can swim, never marked relocated. One fish of each new
# species (the chromis band lies above every decor obstacle) under a rounded rock in reef slot s2.
func escape_checks() -> void:
	var probe:=StreamWorld.new(42,1000)
	if not probe.has_method("set_decor"):
		check(false,"StreamWorld.set_decor exists (S5)")
		return
	var out: Dictionary={}
	for species: String in NEW:
		var w: Variant=StreamWorld.new(42,1000)
		w.state.light_hour=12.0
		w.state.ecology_remainder=-1.0e9
		var f: Dictionary=of(w,species)[0]
		only(w,func(x): return x==f)
		var rock: Dictionary=w.scene.effects("s2","rounded_rock").obstacles[0]
		# (Inside the rock, and high enough for each fish's body to clear the sand.)
		f.merge({"x":rock.cx+6.0,"y":rock.cy-0.6*rock.ry,"tx":rock.cx+6.0,"ty":rock.cy-0.6*rock.ry,"vx":0.0,"vy":0.0,"speed":0.0,"decision_at":w.state.elapsed},true)
		var at:=Vector2(f.x,f.y)
		var rng_before: Array=[w.rng.state,w.motion_rng.state]
		check(w.set_decor("s2","rounded_rock"),"A rounded rock goes into reef slot s2")
		check(Vector2(f.x,f.y)==at and not f.has("relocated_at") and [w.rng.state,w.motion_rng.state]==rng_before,"Placing it moves nobody and draws nothing (%s)" % species)
		var left: float=-1.0
		var back_in: bool=false
		var fastest: float=0.0
		var prev: Vector2=at
		for i in 100:
			w.advance_live(0.2)
			var p:=Vector2(f.x,f.y)
			fastest=maxf(fastest,p.distance_to(prev))
			prev=p
			var q: float=raw_q(p,rock)
			if q>=1.0 and left<0.0:
				left=(i+1)*0.2
			elif q<1.0 and left>=0.0:
				back_in=true
		var limit: float=0.2*SWIM[species].cruise*1.18*2.4*1.35
		out[species]={"left_after_s":left,"max_step":snappedf(fastest,0.01),"limit":snappedf(limit,0.01)}
		check(left>0.0 and left<=10.0 and not back_in,"A %s under newly placed decor swims out within 10 s and stays out (%.1f s)" % [species,left])
		check(fastest<=limit and not f.has("relocated_at"),"It swims out, it is not snapped out (largest step %.2f px, limit %.2f)" % [fastest,limit])
	numbers.escape=out
