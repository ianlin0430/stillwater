extends SceneTree
# Natural fish motion (user request 2026-09-25): burst-and-glide speed, rate-limited heading,
# curved paths, soft depth-band edges, body separation between tangs and around tangs,
# blennies resting clear of firefish burrows, and the per-animal motion fields the rig reads
# (docs/BACKEND_SNAPSHOT_EVENTS.md "Natural motion").
var checks: int=0
var failures: Array[String]=[]
var numbers: Dictionary={}
# Read at run time so this suite reports failing checks (not a parse error) on older backends.
var SWIM: Dictionary=(StreamWorld as Script).get_script_constant_map().get("SWIM",{"startle_turn":1.0,"green_chromis":{"turn":0.0,"cruise":17.0,"pitch":0.45},"yellow_tang":{"turn":0.0,"cruise":20.0,"pitch":0.3}})

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

# Adult art size [length, height] (ReefRig.LOOK), scaled like the rig for juveniles.
func body(w: StreamWorld, a: Dictionary) -> Vector2:
	var look: Dictionary=ReefRig.LOOK[a.species]
	return Vector2(look.width,look.width*look.region.size.y/look.region.size.x)*w.animal_scale(a)

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
	blenny_checks()
	firefish_checks()
	tang_grazing_checks()
	night_rest_checks()
	encounter_checks()
	determinism_checks()
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
	var tang_speeds: Array=[]
	var max_turn: Dictionary={"green_chromis":0.0,"yellow_tang":0.0}
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
				if a.species not in StreamWorld.DEPTH:
					continue
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
	# The tangs' own gliding style, measured in open water of their own (dodging the school
	# is quicker on purpose): two tangs, ten daytime minutes, three seeds.
	for seed_value: int in seeds([42,812,240921]):
		var w:=StreamWorld.new(seed_value,1000)
		only(w,func(x): return x.species=="yellow_tang")
		w.state.light_hour=12.0
		var run: Dictionary={}
		for i in 3000:
			w.advance_live(0.2)
			for a: Dictionary in w.state.animals:
				var steady: bool=a.activity=="Cruising" and a.speed>3.0 and absf(cos(a.heading))>0.95 and Vector2(a.x,a.y).distance_to(Vector2(a.tx,a.ty))>120 and Vector2(a.avoid_x,a.avoid_y).length()<1.0
				if steady:
					run[a.id]=run.get(a.id,[])+[a.speed]
				if not steady or i==2999:
					var r: Array=run.get(a.id,[])
					if r.size()>=25:
						tang_speeds.append(cv(r.slice(10)))
					run.erase(a.id)
	var chromis_cv: float=0.0
	for c: float in chromis_speeds: chromis_cv+=c/chromis_speeds.size()
	var tang_cv: float=0.0
	for c: float in tang_speeds: tang_cv+=c/tang_speeds.size()
	var mean_bend: float=0.0
	for b: float in bends: mean_bend+=b
	mean_bend/=maxf(1,bends.size())
	numbers.speed={"chromis_lead_cv":snappedf(chromis_cv,0.001),"chromis_min":snappedf(chromis_all.min(),0.01) if not chromis_all.is_empty() else 0.0,"chromis_max":snappedf(chromis_all.max(),0.01) if not chromis_all.is_empty() else 0.0,"tang_cv":snappedf(tang_cv,0.001),"stretches":[chromis_speeds.size(),tang_speeds.size()]}
	numbers.heading={"max_change_per_tick":{"green_chromis":snappedf(max_turn.green_chromis,0.001),"yellow_tang":snappedf(max_turn.yellow_tang,0.001)}}
	numbers.path={"mean_bend_per_tick":snappedf(mean_bend,0.0001),"max_bend_per_tick":snappedf(kinks,0.001),"samples":bends.size()}
	check(fields_ok,"Every swimmer carries finite heading (0..pi), pitch, speed, thrust (0..1) and turn")
	check(direction_ok,"direction stays the sign of cos(heading) for older consumers")
	check(heading_ok,"Heading turns at a limited rate: no instant flips (max %.3f / %.3f rad per tick)" % [max_turn.green_chromis,max_turn.yellow_tang])
	check(max_turn.green_chromis>0.3 and max_turn.yellow_tang>0.05,"Fish do turn around (heading changes)")
	check(no_teleport,"No teleports: every step is within the fastest dash and never marked as a relocation")
	check(chromis_cv>0.08 and chromis_cv<0.6,"Chromis swim in bursts and glides: cruising speed varies (CV %.3f)" % chromis_cv)
	check(chromis_speeds.size()>=5 and tang_speeds.size()>=5 and tang_cv<chromis_cv*0.5 and tang_cv<0.08,"Tangs glide more evenly than the chromis (CV %.3f vs %.3f)" % [tang_cv,chromis_cv])
	check(bends.size()>200 and mean_bend>0.004 and kinks<0.25,"Cruising paths curve gently (mean %.4f rad/tick, max %.3f above 12 px/s)" % [mean_bend,kinks])

# A fish heading up into the top of its band eases off instead of stopping dead at the edge.
func band_edge_checks() -> void:
	var w:=StreamWorld.new(42,1000)
	only(w,func(x): return x==of(w,"yellow_tang")[0])
	w.state.light_hour=12.0
	var t: Dictionary=of(w,"yellow_tang")[0]
	var band: Array=StreamWorld.DEPTH.yellow_tang
	t.x=500.0
	t.y=band[0]+60.0
	t.tx=900.0
	t.ty=band[0]-200.0
	t.activity="Cruising"
	t.decision_at=w.state.elapsed+600
	t.heading=0.0
	t.pitch=-SWIM.yellow_tang.pitch
	t.speed=SWIM.yellow_tang.cruise
	t.vx=t.speed*cos(t.pitch)
	t.vy=t.speed*sin(t.pitch)
	var inside: bool=true
	var jolt: float=0.0
	var vy0: float=t.vy
	var last: float=t.vy
	for i in 150:
		w.advance_live(0.2)
		inside=inside and t.y>=band[0]-0.001 and not t.has("relocated_at")
		jolt=maxf(jolt,absf(t.vy-last))
		last=t.vy
	numbers.band_edge={"start_vy":snappedf(vy0,0.01),"max_vy_change_per_tick":snappedf(jolt,0.01),"end_gap":snappedf(t.y-band[0],0.1)}
	check(inside,"A fish steering above its band stays inside it without a relocation")
	check(jolt<2.5 and absf(last)<1.0 and t.y-band[0]<20.0,"It slows its climb smoothly at the band edge (max vy change %.2f px/s per tick)" % jolt)

# Bodies keep apart: tang with tang, chromis around tangs (Codex recording 2026-09-25).
func separation_checks() -> void:
	var tang_max: float=0.0
	var tang_share: float=0.0
	var mixed_max: float=0.0
	var mixed_ticks: int=0
	var ticks: int=0
	var spread_sum: float=0.0
	var per_seed: Dictionary={}
	# 7, 11, 314 and 2 are regression seeds: a chromis pinned at a band edge or corner by a
	# cruising tang was run into there (2026-09-27, before the tang went around it).
	for seed_value: int in seeds([42,812,240921,7,11,314,2]):
		var w:=StreamWorld.new(seed_value,1000)
		w.state.light_hour=12.0
		var seed_max: float=0.0
		var seed_deep: int=0
		for i in 4500:
			w.advance_live(0.2)
			ticks+=1
			var tg: Array=of(w,"yellow_tang")
			var ch: Array=of(w,"green_chromis")
			if tg.size()==2:
				var o: float=overlap(w,tg[0],tg[1])
				tang_max=maxf(tang_max,o)
				if o>0.0: tang_share+=1
			for t: Dictionary in tg:
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
	numbers.tang_overlap={"max_fraction":snappedf(tang_max,0.001),"ticks_touching_share":snappedf(tang_share/ticks,0.0001)}
	numbers.chromis_through_tang={"max_fraction":snappedf(mixed_max,0.001),"ticks_over_quarter":mixed_ticks,"per_seed_max_and_deep_ticks":per_seed}
	numbers.school_spread=snappedf(spread_sum/ticks,0.1)
	check(tang_max<=0.2,"Two tangs never overlap by more than a fifth of their bodies (max %.3f)" % tang_max)
	check(mixed_max<=0.4 and mixed_ticks<ticks*0.002,"Chromis go around tangs instead of through them (max %.3f, %d deep ticks)" % [mixed_max,mixed_ticks])
	check(spread_sum/ticks<StreamWorld.CHROMIS.regroup*0.6,"The school stays together (mean spread %.1f px)" % (spread_sum/ticks))

# Two hungry tangs and the school at a pinch: everyone still eats, the tangs take turns.
func feeding_checks() -> void:
	var w:=StreamWorld.new(42,1000)
	w.state.light_hour=12.0
	w.advance_live(10)
	var tg: Array=of(w,"yellow_tang")
	for a: Dictionary in w.state.animals:
		a.energy=1.0
	w.state.ledger.initial=w.material()-w.state.ledger["in"]+w.state.ledger.out
	var worst: float=0.0
	var eaters: Dictionary={}
	var cursor: int=w.state.next_event-1
	for k in 4:
		w.feed((tg[0].x+tg[1].x)*0.5)
		for i in 450:
			w.advance_live(0.2)
			worst=maxf(worst,overlap(w,tg[0],tg[1]))
			for e: Dictionary in StreamWorld.events_after(w.state.events,cursor):
				if e.kind=="ate": eaters[e.id]=true
			cursor=w.state.next_event-1
	numbers.feeding={"tang_overlap_max":snappedf(worst,0.001),"eaters":eaters.size(),"tangs_ate":tg.filter(func(t): return eaters.has(t.id)).size()}
	check(tg.all(func(t): return eaters.has(t.id)),"Both hungry tangs reach food")
	check(of(w,"green_chromis").any(func(c): return eaters.has(c.id)),"Chromis still reach food beside the tangs")
	check(worst<=0.2,"Feeding tangs keep apart (max overlap %.3f)" % worst)
	check(absf(w.residual())<0.00001,"Feeding keeps the ledger balanced")

func occupied(w: StreamWorld) -> Array:
	return of(w,"purple_firefish").map(func(f): return f.burrow_x)

# Blennies never perch, graze or sleep where a firefish hovers over its burrow.
func blenny_checks() -> void:
	var margin: float=StreamWorld.BLENNY.get("burrow_clear",0.0)
	check(margin>=(ReefRig.LOOK.lawnmower_blenny.width+ReefRig.LOOK.purple_firefish.width)*0.5,"The burrow margin covers half a blenny plus half a firefish (%d px)" % margin)
	var bad: int=0
	var closest: float=INF
	var rests: int=0
	var hops: Array=[]
	for seed_value: int in seeds([42,812,240921]):
		var w:=StreamWorld.new(seed_value,1000)
		w.state.light_hour=6.5
		# A full firefish patch, so every burrow is in play.
		var mom: Dictionary=of(w,"purple_firefish")[0]
		for n in 2:
			mom.energy=StreamWorld.SPECIES.purple_firefish.reserve
			w._breed(mom)
		var hop: Dictionary={}
		for i in 12000:
			w.advance_live(0.2)
			for b: Dictionary in of(w,"lawnmower_blenny"):
				if b.activity in ["Perching","Grazing","Sleeping"]:
					rests+=1
					for x: float in occupied(w):
						closest=minf(closest,absf(b.x-x))
						if absf(b.x-x)<margin: bad+=1
				# Hop speed profile: a flick off the bed, then a slowing glide to the landing.
				if b.activity=="Hopping":
					if not hop.has(b.id): hop[b.id]=[]
					if absf(b.vx)>0.0: hop[b.id].append(absf(b.vx))
				elif hop.has(b.id):
					if hop[b.id].size()>=3: hops.append(hop[b.id])
					hop.erase(b.id)
	var decel: int=hops.filter(func(h): return h[0]>=h[-1]*2.0 and h.max()<=StreamWorld.BLENNY.hop_speed+0.001).size()
	numbers.blenny={"rest_ticks":rests,"rest_ticks_in_margin":bad,"min_rest_distance_to_burrow":snappedf(closest,0.1),"hops":hops.size(),"decelerating_hops":decel}
	check(rests>1000 and bad==0,"Blennies never rest within %d px of an occupied firefish burrow (%d of %d rest ticks, closest %.1f px)" % [margin,bad,rests,closest])
	check(hops.size()>20 and decel>=hops.size()*0.9,"A hop starts with a flick and slows to land (%d of %d hops)" % [decel,hops.size()])
	# Static: a grazing tang's body never covers a blenny on the bed.
	var clear: bool=true
	for s: Array in StreamWorld.TANG.spots:
		var hold: Vector2=StreamWorld._tang_hold(s)
		var tang_box:=Rect2(hold-Vector2(61,87.2*0.66),Vector2(122,87.2))
		for x in range(130,1151,5):
			var bl:=Rect2(Vector2(x,StreamWorld.floor_y(x))-Vector2(50,42.3*0.47),Vector2(100,42.3))
			clear=clear and not tang_box.intersects(bl)
	check(clear,"No tang grazing spot puts a tang body over the bed where blennies rest")

func firefish_checks() -> void:
	var w:=StreamWorld.new(42,1000)
	only(w,func(x): return x.species=="purple_firefish")
	w.state.light_hour=12.0
	var f: Dictionary=of(w,"purple_firefish")[0]
	var flicks: int=0
	var pitch_max: float=0.0
	for i in 600:
		w.advance_live(0.2)
		flicks+=int(f.get("flick",0.0)>0.5)
		pitch_max=maxf(pitch_max,absf(f.get("pitch",0.0)))
	check(f.x==f.burrow_x and f.y==f.burrow_y and f.vx==0.0 and f.speed==0.0,"A hovering firefish stays at its burrow (x/y contract unchanged)")
	check(flicks>=2 and flicks<=30 and pitch_max>0.0 and pitch_max<0.15 and f.thrust>0.0 and f.thrust<0.4,"Hovering: small balancing (pitch %.3f, thrust %.2f) and an occasional dorsal flick (%d in 2 min)" % [pitch_max,f.thrust,flicks])
	w.startle(f.burrow_x,f.burrow_y-30,1.0)
	check(f.activity=="Hiding" and f.thrust==1.0,"A startled firefish dashes into its burrow at full thrust")
	w.advance_live(1.0)
	check(f.thrust<0.5,"The dash is brief")
	numbers.firefish={"flicks_2min":flicks,"pitch_max":snappedf(pitch_max,0.001)}

# Grazing in profile (user 2026-09-26: the grazing tang looked squashed): the body centre holds
# half the tang's body length (x its scale) out from the rock contact, facing the rock, so the
# mouth meets the rock without the frontend foreshortening the fish.
func tang_grazing_checks() -> void:
	var half: float=StreamWorld.BODY.yellow_tang[0]*0.5
	check(is_equal_approx(float(StreamWorld.TANG.reach),half),"TANG.reach is half the adult tang body (%.1f px, reach %.1f)" % [half,float(StreamWorld.TANG.reach)])
	var worst: float=0.0
	var facing_min: float=1.0
	var grazes: Dictionary={"adult":0,"juvenile":0}
	for seed_value: int in seeds([42,812,240921]):
		var w:=StreamWorld.new(seed_value,1000)
		w.state.light_hour=12.0
		var tg: Array=of(w,"yellow_tang")
		# One juvenile (half size) per world: it holds half as far out.
		tg[1].age=10.0
		for i in 6000:
			w.advance_live(0.2)
			for t: Dictionary in tg:
				if t.activity!="Grazing":
					continue
				var side: float=0.0
				for s: Array in StreamWorld.TANG.spots:
					if s[0]==t.get("contact_x") and s[1]==t.get("contact_y"):
						side=s[2]
				if side==0.0:
					worst=INF
					continue
				var want:=Vector2(t.contact_x+side*half*w.animal_scale(t),t.contact_y)
				worst=maxf(worst,want.distance_to(Vector2(t.x,t.y)))
				facing_min=minf(facing_min,cos(t.heading)*-side)
				grazes["juvenile" if w.animal_scale(t)<1.0 else "adult"]+=1
	numbers.tang_grazing={"max_hold_error":snappedf(worst,0.01),"min_facing_cos":snappedf(facing_min,0.001),"adult_ticks":grazes.adult,"juvenile_ticks":grazes.juvenile}
	check(grazes.adult>100 and grazes.juvenile>100,"Adult and juvenile tangs both graze (%d / %d ticks)" % [grazes.adult,grazes.juvenile])
	check(worst<6.0,"Grazing body centre sits half a body length x scale out from the contact, within the 5 px arrival plus coasting (worst %.2f px off)" % worst)
	check(facing_min>=0.9,"A grazing tang faces its rock (min cos %.3f)" % facing_min)
	# Every hold (adult and juvenile) is inside the tang band and the swimming x range.
	var inside: bool=true
	for s: Array in StreamWorld.TANG.spots:
		for scale: float in [1.0,0.5]:
			var h: Vector2=StreamWorld._tang_hold(s,scale)
			inside=inside and h.x>=100.0 and h.x<=1180.0 and h.y>=StreamWorld.DEPTH.yellow_tang[0] and h.y<=StreamWorld.DEPTH.yellow_tang[1]
	check(inside,"Every grazing hold lies inside the tang band")

# Night rest (user 2026-09-26: the chromis jittered up and down while resting at night): a slow,
# smooth hover with no repeated small up/down corrections. A vertical reversal is counted when a
# resting fish turns back by at least 0.5 px from its last vertical extreme. Before the fix: worst
# 4.06, mean 1.92 per minute (a resting leader crept to new spots, the slots breathed vertically,
# and spacing and small arrival corrections fought each other).
# The big fish goes around the small one (user decision 2026-09-27; replaces the sideways slide of
# 2026-09-26): a resting chromis stays nearly still when a tang passes and the tang goes around it.
# A give-way episode is a run of ticks in which a resting fish is giving way (the same avoid >
# 0.2 px/s as below) that starts while it rests (not the tail of a dodge it began while swimming);
# no episode may carry it CHROMIS.hold (10 px) sideways or 0.5 px (the reversal unit) up or down in
# total travel, and at night the tangs keep out of the school as by day (the day gate's numbers:
# box overlap <= 0.4, deeper than a quarter on under 0.2 % of tang-chromis tick pairs).
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
		var calm: Dictionary={}
		for i in 3000:
			w.advance_live(0.2)
			for t: Dictionary in of(w,"yellow_tang"):
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
				var was: Vector2=at.get(a.id,Vector2(a.x,a.y))
				at[a.id]=Vector2(a.x,a.y)
				var settled: bool=calm.get(a.id,false)
				calm[a.id]=a.activity=="Resting" and not giving
				if giving and a.activity=="Resting":
					if settled or episode.has(a.id):
						var e: Vector2=episode.get(a.id,Vector2.ZERO)
						episode[a.id]=e+Vector2(absf(a.x-was.x),absf(a.y-was.y))
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
	var mean: float=total_rev/maxf(total_min,0.001)
	var own: float=own_rev/maxf(total_min,0.001)
	var far:=Vector2.ZERO
	for e: Vector2 in episodes: far=Vector2(maxf(far.x,e.x),maxf(far.y,e.y))
	numbers.give_way={"episodes":episodes.size(),"max_sideways_px":snappedf(far.x,0.01),"max_up_down_px":snappedf(far.y,0.01)}
	numbers.night_rest={"worst_reversals_per_min":snappedf(worst,0.01),"mean_reversals_per_min":snappedf(mean,0.01),"mean_without_a_passing_body_per_min":snappedf(own,0.01),"resting_fish_minutes":snappedf(total_min,0.1),"max_vy":snappedf(fast,0.01),"tang_overlap_max":snappedf(mixed_max,0.001),"deep_pairs":mixed_deep,"pairs":pairs,"per_seed":per_seed}
	check(total_min>60.0,"Chromis rest at night (%.1f fish-minutes)" % total_min)
	# Unprovoked up/down corrections are gone. A resting fish no longer dodges a tang up or down
	# (2026-09-26: dodging and gliding back left 0.94 worst / 0.24 mean per minute); the tang goes
	# around it (2026-09-27).
	check(own<=0.05,"Resting chromis never bob on their own (%.2f vertical reversals per minute away from a passing tang; was 1.92 in all)" % own)
	check(worst<=1.0 and mean<=0.2,"Resting chromis reverse at most about once a minute even with tangs passing (worst %.2f, mean %.2f per minute; was 4.06 / 1.92, then 0.94 / 0.24 dodging tangs up and down)" % [worst,mean])
	check(far.x<StreamWorld.CHROMIS.hold and far.y<0.5,"A resting chromis stays nearly still for a passing tang (%d give-way episodes, at most %.2f px sideways and %.2f px up or down)" % [episodes.size(),far.x,far.y])
	check(mixed_max<=0.4 and mixed_deep<pairs*0.002,"At night the tangs go around the resting school (max overlap %.3f, %d of %d tick pairs deeper than a quarter)" % [mixed_max,mixed_deep,pairs])

# The big fish goes around the small one (user decision 2026-09-27, final): a chromis that cannot
# get out of a tang's way (resting, or pinned at a band edge or tank wall) stays nearly still, and
# the tang takes a smooth, wide arc above or below it. Controlled scenes, one chromis and one tang,
# 60 s each. Spec thresholds, set before measuring:
# - the chromis stays within CHROMIS.hold (10 px) of its resting spot and moves < 0.5 px up or
#   down (the reversal unit of the night-rest gate);
# - box overlap (overlap()) stays <= 0.25 (the "deep" quarter of the day separation gate);
# - the tang gets past the chromis (its centre beyond the chromis's by the pair's half box widths;
#   by a wall, where its course ends: level with it) within 40 s, in one smooth arc: its vy changes
#   sign at most twice on the way (a change counts from >= +0.1 to <= -0.1 px/s or back), and
#   until it comes within 50 px (x) of the end of its course no tick changes vx or vy by 2.5 px/s
#   or more (the band-edge jolt limit) and no step exceeds the kinematics no-teleport limit;
#   nobody is marked relocated. (Stopping at the end of the course is not part of the encounter:
#   a tang arriving anywhere overshoots a few px and turns back, before and after this change.)
func encounter(night: bool, c_at: Vector2, c_aim: Vector2, c_activity: String, t_from: Vector2, t_to: Vector2, abreast: bool) -> Dictionary:
	var w:=StreamWorld.new(42,1000)
	w.state.light_hour=1.0 if night else 12.0
	var c: Dictionary=of(w,"green_chromis")[0]
	var t: Dictionary=of(w,"yellow_tang")[0]
	only(w,func(x): return x==c or x==t)
	# No ecology minute inside the scene (no arrivals; the hour stays).
	w.state.ecology_remainder=-1.0e9
	var way: float=signf(t_to.x-t_from.x)
	c.merge({"x":c_at.x,"y":c_at.y,"tx":c_aim.x,"ty":c_aim.y,"vx":0.0,"vy":0.0,"activity":c_activity,"decision_at":w.state.elapsed+1.0e6,"direction":-way,"heading":0.0 if way<0.0 else PI,"pitch":0.0,"speed":0.0,"thrust":0.0,"turn":0.0,"avoid_x":0.0,"avoid_y":0.0},true)
	t.merge({"x":t_from.x,"y":t_from.y,"tx":t_to.x,"ty":t_to.y,"vx":20.0*way,"vy":0.0,"activity":"Cruising","decision_at":w.state.elapsed+1.0e6,"direction":way,"heading":0.0 if way>0.0 else PI,"pitch":0.0,"speed":20.0,"thrust":0.3,"turn":0.0,"avoid_x":0.0,"avoid_y":0.0},true)
	var half: float=(body(w,c).x+body(w,t).x)*0.5
	var step_limit: float=0.2*SWIM.yellow_tang.cruise*1.18*2.4*1.35
	var r: Dictionary={"chromis_off_px":0.0,"chromis_up_down_px":0.0,"overlap_max":0.0,"pass_s":-1.0,"vy_sign_changes":0,"tang_max_dv":0.0,"tang_max_step":0.0,"tang_detour_px":0.0,"relocated":false,"chromis_left_band":false}
	var sign: float=0.0
	var last:=Vector2(t.vx,t.vy)
	var at:=Vector2(t.x,t.y)
	var band: Array=StreamWorld.DEPTH.green_chromis
	for i in 300:
		w.advance_live(0.2)
		r.chromis_off_px=maxf(r.chromis_off_px,Vector2(c.x,c.y).distance_to(c_at))
		r.chromis_up_down_px=maxf(r.chromis_up_down_px,absf(c.y-c_at.y))
		r.overlap_max=maxf(r.overlap_max,overlap(w,c,t))
		r.tang_detour_px=maxf(r.tang_detour_px,absf(t.y-t_from.y))
		var v:=Vector2(t.vx,t.vy)
		if absf(at.x-t_to.x)>=50.0:
			r.tang_max_dv=maxf(r.tang_max_dv,maxf(absf(v.x-last.x),absf(v.y-last.y)))
			r.tang_max_step=maxf(r.tang_max_step,Vector2(t.x,t.y).distance_to(at))
		last=v
		at=Vector2(t.x,t.y)
		r.relocated=r.relocated or c.has("relocated_at") or t.has("relocated_at")
		r.chromis_left_band=r.chromis_left_band or c.y<band[0] or c.y>band[1] or c.x<100.0 or c.x>1180.0
		if r.pass_s<0.0:
			if absf(t.vy)>=0.1:
				if sign!=0.0 and signf(t.vy)!=sign:
					r.vy_sign_changes+=1
				sign=signf(t.vy)
			if (absf(t.x-c.x)<=half) if abreast else ((t.x-c.x)*way>=half):
				r.pass_s=(i+1)*0.2
	r.ok=r.chromis_off_px<=StreamWorld.CHROMIS.hold and r.chromis_up_down_px<0.5 and r.overlap_max<=0.25 and r.pass_s>=0.0 and r.pass_s<=40.0 and r.vy_sign_changes<=2 and r.tang_max_dv<2.5 and r.tang_max_step<=step_limit and not r.relocated
	for k: String in r:
		if r[k] is float: r[k]=snappedf(r[k],0.001)
	return r

func encounter_checks() -> void:
	var rest:=Vector2(640,320)
	var scenes: Dictionary={
		# (A) head-on: the tang cruises at the resting chromis's depth.
		"A_head_on":encounter(true,rest,rest,"Resting",Vector2(300,320),Vector2(1060,320),false),
		# (B) oblique: its course runs 50 px above the chromis.
		"B_oblique_50_above":encounter(true,rest,rest,"Resting",Vector2(300,270),Vector2(1060,270),false),
		# (C) by a wall: the chromis rests 25 px off it and the tang cruises at its depth to the wall.
		"C_left_wall":encounter(true,Vector2(125,320),Vector2(125,320),"Resting",Vector2(500,320),Vector2(110,320),true),
		"C_right_wall":encounter(true,Vector2(1155,320),Vector2(1155,320),"Resting",Vector2(780,320),Vector2(1170,320),true),
		# (C) by a band edge: 25 px under the top of the chromis band, the tang along it both ways
		# (no room above it inside the tang band, so it must pass below).
		"C_band_edge_going_right":encounter(true,Vector2(640,205),Vector2(640,205),"Resting",Vector2(300,205),Vector2(1060,205),false),
		"C_band_edge_going_left":encounter(true,Vector2(640,205),Vector2(640,205),"Resting",Vector2(980,205),Vector2(220,205),false)}
	var bad: Array=scenes.keys().filter(func(k): return not scenes[k].ok)
	numbers.encounter=scenes
	check(bad.is_empty(),"The tang goes around a resting chromis in one smooth arc and the chromis stays put (failing: %s)" % ", ".join(bad))
	# Daytime, pinned: a schooling chromis pressed into the top-left corner of its band (aiming
	# beyond it, so it never settles to rest) and a tang cruising to a point right next to it.
	var pinned: Dictionary=encounter(false,Vector2(104,184),Vector2(100,150),"Schooling",Vector2(450,300),Vector2(160,200),true)
	pinned.erase("ok")
	numbers.encounter_pinned=pinned
	check(pinned.overlap_max<=0.25 and not pinned.chromis_left_band and not pinned.relocated,"A tang yields to a schooling chromis pinned in a band corner (max overlap %.3f, chromis left its band: %s)" % [pinned.overlap_max,pinned.chromis_left_band])

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
	bad.animals.filter(func(x): return x.species=="yellow_tang")[0].heading=NAN
	check(not StreamWorld.validate(bad),"Non-finite heading rejected")
	# Older saves without the motion fields still move.
	var old: Dictionary=StreamWorld.new(42,1000).export_state()
	for x: Dictionary in old.animals:
		for k: String in ["heading","pitch","speed","thrust","turn","roll","flick"]:
			x.erase(k)
	var o:=StreamWorld.new()
	check(o.restore(old),"A save without motion fields loads")
	o.state.light_hour=12.0
	o.advance_live(30)
	check(o.state.animals.filter(func(x): return x.species in StreamWorld.DEPTH).all(func(x): return x.has("heading")),"It gains motion fields on the first live tick")
	var t0: int=Time.get_ticks_usec()
	var p:=StreamWorld.new(42,1000)
	p.state.light_hour=12.0
	p.advance_live(600)
	numbers.us_per_tick=snappedf(float(Time.get_ticks_usec()-t0)/3000.0,0.1)
