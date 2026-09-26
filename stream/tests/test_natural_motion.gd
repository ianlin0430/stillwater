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
	for seed_value: int in [42,812,240921]:
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
	for seed_value: int in [42,812,240921]:
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
	for seed_value: int in [42,812,240921]:
		var w:=StreamWorld.new(seed_value,1000)
		w.state.light_hour=12.0
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
					mixed_max=maxf(mixed_max,o)
					if o>0.25: mixed_ticks+=1
			var c0:=Vector2.ZERO
			for c: Dictionary in ch: c0+=Vector2(c.x,c.y)
			c0/=ch.size()
			var s: float=0.0
			for c: Dictionary in ch: s+=c0.distance_to(Vector2(c.x,c.y))
			spread_sum+=s/ch.size()
	numbers.tang_overlap={"max_fraction":snappedf(tang_max,0.001),"ticks_touching_share":snappedf(tang_share/ticks,0.0001)}
	numbers.chromis_through_tang={"max_fraction":snappedf(mixed_max,0.001),"ticks_over_quarter":mixed_ticks}
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
	for seed_value: int in [42,812,240921]:
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
	for seed_value: int in [42,812,240921]:
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
