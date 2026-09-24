class_name StreamWorld
extends RefCounted

const VERSION: int = 2
const MAX_ANIMALS: int = 24
const MAX_AWAY: float = 259200.0
const DAY: float = 86400.0
const ACTIVE_SPECIES: Array[String] = ["lawnmower_blenny","purple_firefish","green_chromis","garden_eel"]
const SPECIES: Dictionary = {
	# Legacy entries: threadfin (2026-09-24), hatchetfish and shrimp (2026-09-23) and crayfish (2026-09-22) were removed
	# from the cast; kept only so older saves validate, upgrade and still show their history.
	"shrimp": {"label":"Cherry shrimp","latin":"Neocaridina davidi","initial":0,"mature":21.0,"lifespan":120.0,"body":0.3,"reserve":3.0,"cost":0.22,"bite":0.5,"brood":2,"breed":0.12,"cooldown":7.0,"pool":"biofilm"},
	"crayfish": {"label":"Blue crayfish","latin":"Procambarus alleni","initial":0,"mature":35.0,"lifespan":540.0,"body":3.0,"reserve":12.0,"cost":0.65,"bite":1.2,"brood":2,"breed":0.035,"cooldown":21.0,"pool":"detritus"},
	"threadfin": {"label":"Threadfin rainbowfish","latin":"Iriatherina werneri","initial":0,"mature":28.0,"lifespan":180.0,"body":0.7,"reserve":4.0,"cost":0.3,"bite":0.7,"brood":2,"breed":0.06,"cooldown":10.0,"pool":"microfauna","k_food":10.0},
	"hatchet": {"label":"Marbled hatchetfish","latin":"Carnegiella strigata","initial":0,"mature":28.0,"lifespan":180.0,"body":0.8,"reserve":4.0,"cost":0.32,"bite":0.75,"brood":2,"breed":0.04,"cooldown":14.0,"pool":"microfauna","k_food":10.0},
	# Added 2026-09-23 by user decision; a marine fish, kept in this freshwater stream on purpose.
	"garden_eel": {"label":"Spotted garden eel","latin":"Heteroconger hassi","initial":2,"mature":90.0,"lifespan":365.0,"body":0.9,"reserve":5.0,"cost":0.22,"bite":0.55,"brood":2,"breed":0.04,"cooldown":20.0,"pool":"microfauna","k_food":10.0},
	# Stillwater Reef cast (user decision 2026-09-24). Authored rates; sizing in docs/ecology.md.
	"lawnmower_blenny": {"label":"Lawnmower blenny","latin":"Salarias fasciatus","initial":2,"mature":45.0,"lifespan":240.0,"body":0.8,"reserve":4.5,"cost":0.24,"bite":0.6,"brood":2,"breed":0.07,"cooldown":12.0,"pool":"biofilm","k_food":10.0},
	# Purple firefish replaced the red firefish (N. magnifica, key "firefish") on 2026-09-24, before any
	# user save held one, so the red key was dropped rather than kept as a legacy entry.
	"purple_firefish": {"label":"Purple firefish","latin":"Nemateleotris decora","initial":2,"mature":35.0,"lifespan":200.0,"body":0.5,"reserve":3.5,"cost":0.18,"bite":0.45,"brood":2,"breed":0.08,"cooldown":10.0,"pool":"microfauna","k_food":10.0},
	"green_chromis": {"label":"Green chromis","latin":"Chromis viridis","initial":5,"mature":30.0,"lifespan":180.0,"body":0.5,"reserve":3.5,"cost":0.2,"bite":0.5,"brood":2,"breed":0.1,"cooldown":8.0,"pool":"microfauna","k_food":10.0}}
# Ecology v2 (docs/plans/2026-09-22-self-sustaining-ecosystem.md). Rates are per day, applied per one-minute tick.
# Reef cast since 2026-09-24: caps 3+3+6+4 = 16, opening cast 2+2+5+2 = 11 (SPECIES.initial),
# sized against the food pools by offline probe (tools/cast_probe.gd, docs/ecology.md). These
# two are the only places the cast sizes live; the arrival limit (habitat_cap) and the
# long-run band follow from them.
const CAP: Dictionary = {"lawnmower_blenny":3,"purple_firefish":3,"green_chromis":6,"garden_eel":4}
# Species that arrive once, not live, in a save from before the reef (see restore()).
const REEF_CAST: Array[String] = ["lawnmower_blenny","purple_firefish","green_chromis"]
const POOLS: Array[String] = ["nutrients","stem","floating","biofilm","microfauna","detritus"]
# Opening pools (R11, set with the earlier shrimp cast); also the v1 upgrade fill (R12).
const OPENING: Dictionary = {"nutrients":0.4,"stem":45.0,"floating":24.0,"biofilm":32.0,"microfauna":24.0,"detritus":8.0}
const PLANTS: Dictionary = {
	"floating": {"r":1.3,"m":0.025,"max":40.0,"seed":0.4},
	"stem": {"r":0.8,"m":0.02,"max":120.0,"seed":1.0},
	"biofilm": {"r":6.0,"m":0.03,"max":30.0,"per_stem":0.4,"seed":0.5}}
const K_NUTRIENT: float = 3.0
const MICRO: Dictionary = {"r":1.2,"m":0.06,"max":80.0,"k":25.0}
const DECAY: float = 0.08
const STREAM_IN: Dictionary = {"nutrients":0.7,"microfauna":0.35}
const STREAM_OUT: Dictionary = {"nutrients":0.05,"microfauna":0.015,"detritus":0.04,"floating":0.005}
# Swimming depth bands, a little wider than the authored targets in _choose_activity.
const DEPTH: Dictionary = {"green_chromis":[180.0,430.0]}
# Chromis school: the lowest-id chromis leads; each other member holds its own slot
# (golden-angle direction, radius in `spread` px, flattened vertically, mirrored with the
# leader's heading) and hurries (`catch_up` x speed) when more than `regroup` px from it.
# Members keep `spacing` px apart.
const CHROMIS: Dictionary = {"spread":[34.0,80.0],"regroup":120.0,"catch_up":1.8,"spacing":36.0}
# A species is rescued from upstream only when it can no longer breed here: one or none left
# (2026-09-24; was two, when each species had six places and two was a third of them).
const RESCUE_AT: int = 1
# Opening ages in days (R11): one opener per stratum of [lo, hi]. The long-run gates derive
# the old-age deaths the opening cast must produce from these (tests/ecology_acceptance.gd).
const OPENING_AGE: Dictionary = {"fish":[40.0,150.0],"garden_eel":[100.0,220.0]}
const RESCUE_RATE: float = 1.0/96.0
const ARRIVAL_RATE: float = 1.0/504.0
# An unexplained position jump larger than this in one motion tick is a relocation
# (animals carry relocated_at). Generic: fish layer clamping stays under 1 px in normal
# play, so since the shrimp (whose surface snap crossed it) left, only a fish found
# outside its band, e.g. from an edited save, is snapped back and marked.
const RELOCATION: float = 3.0
# Garden eel burrow sites on the open sand between the stones and the plants, filled
# nearest-first; an eel never leaves its burrow. A fish within `dx` sideways and `dy`
# above the burrow mouth (the bottom of the chromis layer) sends it down for `seconds`.
const BURROWS: Array[float] = [650.0,684.0,616.0,718.0,582.0,752.0,548.0,786.0]
const EEL_WARY: Dictionary = {"dx":48.0,"dy":200.0,"seconds":4.0}
# Firefish burrows: their own patch left of the eel colony (at least 60 px from every eel
# site). A firefish hovers `hover_y` px (per individual, in `hover`) above its burrow and
# hides for `seconds` when a swimming fish or a moving blenny comes within EEL_WARY.
const FIRE_BURROWS: Array[float] = [420.0,452.0,388.0,484.0]
const FIRE: Dictionary = {"seconds":6.0,"hover":[24.0,40.0]}
const HOMES: Dictionary = {"garden_eel":BURROWS,"purple_firefish":FIRE_BURROWS}
# Feeding (user decision 2026-09-23: real food, never required). A pinch is `particles` of
# `mass` dropped just below the surface (y `surface`); at most `daily` mass per simulated day.
# Particles sink `sink` px/s; fish with room notice food within `notice` px and eat it within
# `eat` px; a swaying garden eel snatches food within `eel_dx` of its burrow and `eel_reach`
# above it. Food on the bed becomes detritus `decay` seconds after it settles. See
# docs/BACKEND_SNAPSHOT_EVENTS.md.
const FOOD: Dictionary = {"particles":5,"mass":0.05,"daily":1.0,"max":40,"surface":56.0,"sink":10.0,"notice":260.0,"eat":12.0,"eel_dx":22.0,"eel_reach":80.0,"decay":900.0}
# Tap the glass: fish within `radius` dart up to `dart` px away for `seconds`; eels in reach
# stay down `eel_seconds`. Presentation of the tap only; no ecology effect, nothing saved.
const STARTLE: Dictionary = {"radius":260.0,"dart":150.0,"seconds":3.0,"eel_seconds":5.0}
# Cursor lure: for `interest` seconds after the cursor comes to rest, a fish choosing its next
# move within `range` of it looks with probability `chance`, hovering `stand_off` px to the side
# for `look` seconds. Jitter under `still` px keeps the same lure. Never saved.
const LURE: Dictionary = {"range":320.0,"chance":0.5,"interest":45.0,"look":[6.0,12.0],"stand_off":36.0,"still":8.0}
# Lawnmower blenny on the bed: `y` is always floor_y(x). Grazing/perching dwell ranges (s), hop
# length (px) and speeds (px/s); a hop turns away from another blenny within `space` px.
const BLENNY: Dictionary = {"graze":[6.0,20.0],"perch":[4.0,12.0],"sleep":[60.0,120.0],"hop":[20.0,90.0],"hop_speed":45.0,"dart_speed":90.0,"space":120.0}
const NAMES: Dictionary = {"green_chromis":["Jade","Mint","Lagoon","Kelp","Glass"],"garden_eel":["Dune","Sprig"],"lawnmower_blenny":["Moss","Pebble"],"purple_firefish":["Ember","Flicker"]}
var rng := RandomNumberGenerator.new()
var motion_rng := RandomNumberGenerator.new()
var state: Dictionary
# Live-only cursor lure {x, y, since}; empty when there is none. Not part of state.
var lure: Dictionary = {}
# True only while a live ecology tick runs; stamps events the stage may play.
var _live: bool = false

func _init(world_seed: int = 240921, wall_time: float = 0) -> void:
	rng.seed = world_seed
	motion_rng.seed = world_seed + 7919
	state = {"version":VERSION,"seed":world_seed,"elapsed":0.0,"ecology_remainder":0.0,"motion_remainder":0.0,"motion_ticks":0,"ecology_ticks":0,"next_id":1,"next_event":1,"wall_checkpoint":wall_time,"animals":[],"archive":[],"events":[],"history":[],"resources":OPENING.duplicate(),"ledger":{"initial":0.0,"in":0.0,"out":0.0},"totals":{"birth":0,"death":0,"arrival":0,"departure":0,"dispersal":0,"molt":0,"predation":0},"causes":{},"light_hour":12.0,"eel_colony":true,"reef_cast":true}
	for species: String in ACTIVE_SPECIES:
		var n: int = int(SPECIES[species].initial)
		var lo: float = OPENING_AGE.get(species,OPENING_AGE.fish)[0]
		var hi: float = OPENING_AGE.get(species,OPENING_AGE.fish)[1]
		# Staggered opening ages (R11): one per age stratum, in seeded random order.
		var ages: Array[float] = []
		for i in n:
			ages.append(lo+(hi-lo)*(i+rng.randf())/n)
		for i in range(n-1,0,-1):
			var j: int = rng.randi_range(0,i)
			var t: float = ages[i]
			ages[i]=ages[j]
			ages[j]=t
		for i in n:
			var animal: Dictionary = spawn(species, ages[i])
			# Past the authored names an animal keeps spawn's "<label> <id>".
			if i<NAMES[species].size():
				animal.name = NAMES[species][i]
			animal.sex = "female" if i%2==0 else "male"
			if species=="green_chromis":
				# The opening school, together in midwater.
				animal.x=560.0+i*40.0
				animal.y=280.0+(i%2)*30
			animal.tx=animal.x
			animal.ty=animal.y
	state.ledger.initial = material()
	_event("begin",{},"A small world begins beneath the surface.")
	_sample()

static func floor_y(x: float) -> float:
	return 597.0 + sin(x*0.006)*9.0 + sin(x*0.017)*3.0

func animal_scale(a: Dictionary) -> float:
	var juvenile: bool = a.age < SPECIES[a.species].mature
	return 0.5 if juvenile else 1.0

func _place(species: String) -> Vector2:
	var x: float = motion_rng.randf_range(150,1130)
	var y: float = floor_y(x)
	if species=="green_chromis":
		y = motion_rng.randf_range(220,390)
	return Vector2(x,y)

func spawn(species: String, age: float = 0, parent: int = 0) -> Dictionary:
	if species not in ACTIVE_SPECIES or state.animals.size()>=MAX_ANIMALS:
		return {}
	var cfg: Dictionary = SPECIES[species]
	var p: Vector2 = _burrow(parent,species) if species in HOMES else _place(species)
	# next_molt, molting_until and shelter are legacy fields validate() still requires;
	# nothing molts or shelters since the shrimp left (2026-09-23).
	var a: Dictionary = {"id":state.next_id,"species":species,"name":cfg.label+" "+str(state.next_id),"sex":"female" if rng.randf()<0.5 else "male","age":age,"parent":parent,"born":state.elapsed,"body":cfg.body*(0.45 if age<cfg.mature else 1.0),"energy":cfg.reserve*(0.35 if age<cfg.mature else 0.67),"x":p.x,"y":p.y,"tx":p.x,"ty":p.y,"direction":1.0 if p.x<640 else -1.0,"activity":"Resting","decision_at":0.0,"last_breed":-cfg.cooldown,"next_molt":age+99999.0,"molting_until":-1.0,"shelter":240.0 if state.next_id%2==1 else 1030.0,"recent":[],"hunger":0.0}
	a.lifespan=cfg.lifespan*rng.randf_range(0.85,1.15)
	if species in HOMES:
		a.burrow_x=p.x
		a.burrow_y=p.y
		if species=="purple_firefish":
			a.hover_y=FIRE.hover[0]+float((int(a.id)*7)%int(FIRE.hover[1]-FIRE.hover[0]+1))
		_burrower(a)
	state.next_id += 1
	state.animals.append(a)
	return a

# Moving a newly placed animal sideways; an eel stays at its burrow.
func _bed_align(a: Dictionary, x: float) -> void:
	if a.species in HOMES:
		return
	a.x=x
	if a.species=="lawnmower_blenny":
		a.y=floor_y(x)
		a.tx=a.x
		a.ty=a.y

# `id` is the actor; `seq` is the event's own id (see docs/BACKEND_SNAPSHOT_EVENTS.md).
func _event(kind: String, a: Dictionary, text: String, extra: Dictionary = {}) -> void:
	var e: Dictionary = {"time":state.elapsed,"kind":kind,"id":a.get("id",0),"text":text,"seq":state.next_event,"live":_live}
	state.next_event+=1
	if a.has("x"):
		e.x=a.x
		e.y=a.y
	e.merge(extra)
	state.events.append(e)
	if state.events.size()>160:
		state.events.pop_front()
	if state.totals.has(kind):
		state.totals[kind]+=1
	if not a.is_empty():
		a.recent.append(e.duplicate())
		if a.recent.size()>6:
			a.recent.pop_front()

func advance_live(seconds: float) -> void:
	if not is_finite(seconds) or seconds<0:
		return
	state.motion_remainder += seconds
	while state.motion_remainder >= 0.2-0.00000001:
		state.motion_remainder = maxf(0,state.motion_remainder-0.2)
		state.motion_ticks+=1
		state.elapsed+=0.2
		_move(0.2)
		state.ecology_remainder+=0.2
		if state.ecology_remainder>=60-0.000001:
			state.ecology_remainder=maxf(0,state.ecology_remainder-60)
			_ecology(false)

func advance_offline(seconds: float) -> Dictionary:
	var span: float = clampf(seconds,0,MAX_AWAY) if is_finite(seconds) else 0.0
	if span<=0:
		return {"seconds":0.0,"capped":false,"events":{}}
	var before: Dictionary = state.totals.duplicate()
	var whole: float = state.ecology_remainder+span
	var ticks: int = int(floor(whole/60))
	var initial_remainder: float = state.ecology_remainder
	for i in ticks:
		state.elapsed += 60-initial_remainder if i==0 else 60
		_ecology(true)
	state.ecology_remainder=fmod(whole,60.0)
	state.elapsed += state.ecology_remainder if ticks>0 else span
	# Discard sub-frame movement interpolation, never ecological time.
	state.motion_remainder=0.0
	for a: Dictionary in state.animals:
		a.decision_at=state.elapsed
	var report: Dictionary = {"seconds":span,"capped":seconds>MAX_AWAY,"events":{}}
	for key: String in before:
		report.events[key]=state.totals[key]-before[key]
	return report

func catch_up(now: float) -> Dictionary:
	if not is_finite(now):
		return {"seconds":0.0,"capped":false,"events":{}}
	var duration: float = maxf(0,now-state.wall_checkpoint)
	var report: Dictionary = advance_offline(duration)
	# Do not move the checkpoint backwards if the system clock is corrected.
	state.wall_checkpoint=maxf(now,state.wall_checkpoint)
	return report

# Public live interactions (called from main.gd only). See docs/BACKEND_SNAPSHOT_EVENTS.md.
# Drops a pinch of food at the surface at x. False past the daily cap (the UI says "they're full").
func feed(x: float) -> bool:
	if not is_finite(x):
		return false
	var day: int=int(state.elapsed/DAY)
	var fed: Dictionary=state.get("fed",{"day":day,"mass":0.0})
	if fed.day!=day:
		fed={"day":day,"mass":0.0}
	var amount: float=FOOD.particles*FOOD.mass
	var food: Array=state.get("food",[])
	if fed.mass+amount>FOOD.daily+0.000001 or food.size()+FOOD.particles>FOOD.max:
		return false
	x=clampf(x,130,1150)
	# Fixed offsets by particle id: no draw from rng or motion_rng.
	for i in FOOD.particles:
		var id: int=state.get("next_food",1)
		state.next_food=id+1
		food.append({"id":id,"x":x+float((id*37)%11-5)*4.0,"y":FOOD.surface+float((id*13)%5)*3.0,"mass":FOOD.mass,"settled":false,"settled_at":-1.0})
	state.food=food
	fed.mass+=amount
	state.fed=fed
	state.ledger["in"]+=amount
	_live=true
	_event("fed",{},"A pinch of food drifted down from the surface.",{"x":x,"y":FOOD.surface})
	_live=false
	return true

# Taps the glass at (x, y). Returns how many animals noticed.
func startle(x: float, y: float, strength: float = 1.0) -> int:
	if not (is_finite(x) and is_finite(y) and is_finite(strength)) or strength<=0:
		return 0
	var hit:=Vector2(x,y)
	var reach: float=STARTLE.radius*clampf(strength,0.2,1.0)
	var noticed: int=0
	for a: Dictionary in state.animals:
		var p:=Vector2(a.x,a.y)
		var gap: float=p.distance_to(hit)
		if gap>=reach:
			continue
		noticed+=1
		if a.species in HOMES:
			a.decision_at=maxf(a.decision_at,state.elapsed+STARTLE.eel_seconds)
			_burrower(a)
			continue
		if a.species=="lawnmower_blenny":
			var side: float=signf(a.x-x) if absf(a.x-x)>0.01 else a.direction
			a.activity="Startled"
			a.tx=clampf(a.x+side*STARTLE.dart*(1.0-0.5*gap/reach),130,1150)
			a.decision_at=state.elapsed+STARTLE.seconds
			a.erase("food_id")
			continue
		var away: Vector2=(p-hit)/gap if gap>0.01 else Vector2(a.direction,0)
		var band: Array=DEPTH[a.species]
		var to: Vector2=p+away*STARTLE.dart*(1.0-0.5*gap/reach)
		a.activity="Startled"
		a.tx=clampf(to.x,130,1150)
		a.ty=clampf(to.y,band[0],band[1])
		a.decision_at=state.elapsed+STARTLE.seconds
		a.erase("food_id")
	return noticed

# The cursor resting in the water at `point` (world coordinates).
func set_lure(point: Vector2) -> void:
	if not point.is_finite():
		return
	if not lure.is_empty() and Vector2(lure.x,lure.y).distance_to(point)<LURE.still:
		return
	lure={"x":point.x,"y":point.y,"since":state.elapsed}
	# The school leader looks up at once (followers follow it; see _choose_activity).
	for a: Dictionary in state.animals:
		if a.species in DEPTH and a.activity in ["Schooling","Resting"]:
			a.decision_at=minf(a.decision_at,state.elapsed+1.0)

func clear_lure() -> void:
	lure={}

func _sink_food(delta: float) -> void:
	for f: Dictionary in state.food:
		if f.settled:
			continue
		f.y+=FOOD.sink*delta
		var bed: float=floor_y(f.x)-2
		if f.y>=bed:
			f.y=bed
			f.settled=true
			f.settled_at=state.elapsed

# Nearest drifting food this fish can reach within its layer, if it has room to eat.
func _seek_food(a: Dictionary) -> bool:
	var best: Dictionary={}
	var band: Array=DEPTH[a.species]
	if SPECIES[a.species].reserve-a.energy>=FOOD.mass*0.8:
		var gap: float=FOOD.notice
		for f: Dictionary in state.get("food",[]):
			if f.settled or f.y>band[1]+FOOD.eat:
				continue
			var d: float=Vector2(a.x,a.y).distance_to(Vector2(f.x,clampf(f.y,band[0],band[1])))
			if d<gap:
				best=f
				gap=d
	if best.is_empty():
		a.erase("food_id")
		return false
	a.activity="Feeding"
	a.food_id=best.id
	a.tx=best.x
	a.ty=clampf(best.y,band[0],band[1])
	# Choose again as soon as the food is gone.
	a.decision_at=state.elapsed
	return true

# Food mass becomes the eater's energy (80%) and detritus (20%), as with natural food (R6).
func _eat(a: Dictionary, f: Dictionary) -> void:
	a.energy+=f.mass*0.8
	state.resources.detritus+=f.mass*0.2
	state.food.erase(f)
	a.erase("food_id")

func _move(delta: float) -> void:
	if not state.get("food",[]).is_empty():
		_sink_food(delta)
	var lead: Dictionary=_lead()
	for a: Dictionary in state.animals:
		if a.species in HOMES:
			_burrower(a)
			continue
		if a.species=="lawnmower_blenny":
			_blenny(a,delta)
			continue
		var p:=Vector2(a.x,a.y)
		var species: String=a.species
		var startled: bool=a.activity=="Startled" and state.elapsed<a.decision_at
		var follower: bool=not lead.is_empty() and a.id!=lead.id
		if not startled and not _seek_food(a):
			if follower:
				_follow(a,lead)
			elif state.elapsed>=a.decision_at:
				_choose_activity(a)
		var target:=Vector2(a.tx,a.ty)
		var offset: Vector2=target-p
		var speed: float=17.0
		speed*=0.82+0.36*float((int(a.id)*37)%101)/100.0
		var acceleration: float=15.0
		if a.activity in ["Resting","Displaying"]:
			speed=1.2
		elif a.activity=="Startled":
			speed*=2.4
			acceleration=45.0
		elif follower:
			speed*=CHROMIS.catch_up if offset.length()>CHROMIS.regroup else 1.15
		var desired: Vector2=offset.normalized()*minf(speed,sqrt(2.0*acceleration*offset.length()))
		# Gentle changing headings for the leader, fading out on approach; no per-frame randomness.
		if a.activity=="Schooling" and not follower and offset.length()>35:
			var bend: float=sin(state.elapsed*(0.28+float(int(a.id)%5)*0.025)+a.id*1.73)
			desired+=offset.normalized().orthogonal()*bend*speed*0.22*minf(1,offset.length()/100)
		for other: Dictionary in state.animals:
			if other.id==a.id or other.species!=species:
				continue
			var apart: Vector2=p-Vector2(other.x,other.y)
			if apart.length()<CHROMIS.spacing and apart.length()>0.01:
				desired+=apart.normalized()*(CHROMIS.spacing-apart.length())*0.16
		var velocity:=Vector2(a.get("vx",0.0),a.get("vy",0.0))
		velocity=velocity.move_toward(desired,acceleration*delta)
		var free: Vector2=p+velocity*delta
		# Keep each fish in its own layer (the shoaling push once carried hatchetfish down).
		var band: Array = DEPTH[species]
		var next: Vector2=free.clamp(Vector2(100,band[0]),Vector2(1180,band[1]))
		if absf(velocity.x)>1.3:
			a.direction=1.0 if velocity.x>0 else -1.0
		if next.distance_to(free)>RELOCATION:
			a.relocated_at=state.elapsed
		a.x=next.x
		a.y=next.y
		a.vx=velocity.x
		a.vy=velocity.y
		if a.has("food_id"):
			for f: Dictionary in state.food:
				if f.id==a.food_id and next.distance_to(Vector2(f.x,f.y))<FOOD.eat:
					_eat(a,f)
					break
		if next.distance_to(target)<5 and velocity.length()<7 and a.activity=="Schooling" and not follower:
			a.activity="Resting"
			a.decision_at=state.elapsed+motion_rng.randf_range(4,18)

# Nearest free burrow site of the species' patch to the parent's burrow (or the patch
# centre). No randomness.
func _burrow(parent: int, species: String) -> Vector2:
	var sites: Array = HOMES[species]
	var taken: Array = []
	var home: float = sites[0]
	for e: Dictionary in state.animals:
		if e.species==species:
			taken.append(e.burrow_x)
			if e.id==parent:
				home=e.burrow_x
	var best: float = sites[-1]
	var gap: float = INF
	for x: float in sites:
		if x not in taken and absf(x-home)<gap:
			best=x
			gap=absf(x-home)
	return Vector2(best,floor_y(best))

# Garden eels and firefish: out by day (eels swaying, firefish hovering), asleep in the
# burrow at night, down for a moment when a fish passes just above (firefish also duck
# for a moving blenny). `extend` is the pose the stage eases toward (0 in, 1 out).
func _burrower(a: Dictionary) -> void:
	a.vx=0.0
	a.vy=0.0
	var eel: bool=a.species=="garden_eel"
	if state.light_hour<7 or state.light_hour>19:
		a.activity="Sleeping"
	else:
		for o: Dictionary in state.animals:
			var passing: bool=o.species in DEPTH or (not eel and o.species=="lawnmower_blenny" and o.activity in ["Hopping","Startled","Feeding"])
			if passing and absf(o.x-a.burrow_x)<EEL_WARY.dx and a.burrow_y-o.y<EEL_WARY.dy:
				a.decision_at=state.elapsed+(EEL_WARY.seconds if eel else FIRE.seconds)
		if state.elapsed<a.decision_at:
			a.activity="Retracted" if eel else "Hiding"
		else:
			a.activity="Swaying" if eel else "Hovering"
	a.extend=1.0 if a.activity in ["Swaying","Hovering"] else 0.0
	if a.extend==1.0 and not state.get("food",[]).is_empty() and SPECIES[a.species].reserve-a.energy>=FOOD.mass*0.8:
		for f: Dictionary in state.food:
			if not f.settled and absf(f.x-a.burrow_x)<FOOD.eel_dx and f.y>a.burrow_y-FOOD.eel_reach and f.y<a.burrow_y:
				_eat(a,f)
				break

# Perches, grazes and hops along the bed; pecks up settled food; sleeps where it is at night.
func _blenny(a: Dictionary, delta: float) -> void:
	var startled: bool=a.activity=="Startled" and state.elapsed<a.decision_at
	if not startled and not _peck(a) and (state.elapsed>=a.decision_at or a.activity=="Startled"):
		_choose_blenny(a)
	var speed: float={"Hopping":BLENNY.hop_speed,"Feeding":BLENNY.hop_speed,"Startled":BLENNY.dart_speed}.get(a.activity,0.0)
	var step: float=clampf(a.tx-a.x,-speed*delta,speed*delta)
	var y: float=floor_y(a.x+step)
	a.vx=step/delta
	a.vy=(y-a.y)/delta
	if step!=0.0:
		a.direction=signf(step)
	a.x+=step
	a.y=y
	if a.has("food_id"):
		for f: Dictionary in state.food:
			if f.id==a.food_id and absf(a.x-f.x)<FOOD.eat:
				_eat(a,f)
				break
	if a.activity=="Hopping" and a.x==a.tx:
		a.activity="Perching"
		a.decision_at=state.elapsed+motion_rng.randf_range(BLENNY.perch[0],BLENNY.perch[1])

func _choose_blenny(a: Dictionary) -> void:
	a.tx=a.x
	a.ty=a.y
	var r: float=motion_rng.randf()
	if state.light_hour<7 or state.light_hour>19:
		a.activity="Sleeping"
		a.decision_at=state.elapsed+motion_rng.randf_range(BLENNY.sleep[0],BLENNY.sleep[1])
	elif r<0.45:
		a.activity="Grazing"
		a.decision_at=state.elapsed+motion_rng.randf_range(BLENNY.graze[0],BLENNY.graze[1])
	elif r<0.75:
		a.activity="Perching"
		a.decision_at=state.elapsed+motion_rng.randf_range(BLENNY.perch[0],BLENNY.perch[1])
	else:
		var side: float=-1.0 if motion_rng.randf()<0.5 else 1.0
		for o: Dictionary in state.animals:
			if o.species=="lawnmower_blenny" and o.id!=a.id and absf(o.x-a.x)<BLENNY.space:
				side=signf(a.x-o.x) if o.x!=a.x else side
		var to: float=a.x+side*motion_rng.randf_range(BLENNY.hop[0],BLENNY.hop[1])
		if to<130 or to>1150:
			to=a.x-(to-a.x)
		a.activity="Hopping"
		a.tx=clampf(to,130,1150)
		a.decision_at=state.elapsed+BLENNY.hop[1]/BLENNY.hop_speed+1.0

# A hungry blenny hops to the nearest settled food within notice range and pecks it up.
func _peck(a: Dictionary) -> bool:
	var best: Dictionary={}
	if SPECIES[a.species].reserve-a.energy>=FOOD.mass*0.8:
		var gap: float=FOOD.notice
		for f: Dictionary in state.get("food",[]):
			if f.settled and absf(f.x-a.x)<gap:
				best=f
				gap=absf(f.x-a.x)
	if best.is_empty():
		a.erase("food_id")
		if a.activity=="Feeding":
			a.decision_at=state.elapsed
			a.activity="Perching"
		return false
	a.activity="Feeding"
	a.food_id=best.id
	a.tx=clampf(best.x,130,1150)
	a.ty=floor_y(a.tx)
	return true

# The lowest-id chromis leads the school (it decides; the others follow). Empty if none.
func _lead() -> Dictionary:
	var lead: Dictionary={}
	for a: Dictionary in state.animals:
		if a.species=="green_chromis" and (lead.is_empty() or a.id<lead.id):
			lead=a
	return lead

# A school member holds its own slot beside the leader, mirrored with the leader's heading.
func _follow(a: Dictionary, lead: Dictionary) -> void:
	var k: float=float(a.id)*2.39996
	var r: float=CHROMIS.spread[0]+float((int(a.id)*17)%int(CHROMIS.spread[1]-CHROMIS.spread[0]))
	var band: Array=DEPTH[a.species]
	a.tx=clampf(lead.x+cos(k)*r*lead.direction,130,1150)
	a.ty=clampf(lead.y+sin(k)*r*0.5,band[0],band[1])
	var settled: bool=Vector2(a.x,a.y).distance_to(Vector2(a.tx,a.ty))<20
	a.activity="Resting" if lead.activity=="Resting" and settled else "Schooling"
	a.decision_at=state.elapsed

# The school leader's next move: a trip across the pool or a pause (mostly pauses at night).
func _choose_activity(a: Dictionary) -> void:
	var r: float=motion_rng.randf()
	var night: bool=state.light_hour<7 or state.light_hour>19
	var band: Array=DEPTH[a.species]
	a.decision_at=state.elapsed+motion_rng.randf_range(18,45)
	a.activity="Schooling"
	a.tx=_roaming_x(a,290,0.42)
	# Inset by the members' vertical reach so the whole school fits in the band.
	a.ty=motion_rng.randf_range(band[0]+CHROMIS.spread[1]*0.5,band[1]-CHROMIS.spread[1]*0.5)
	if r<0.16 or night and r<0.6:
		a.activity="Resting"
	# Give trips enough time to reach a destination instead of repeatedly
	# abandoning distant targets. Rest/feed choices keep their independent dwell time.
	if a.activity=="Schooling":
		var cruise: float=17.0
		cruise*=0.82+0.36*float((int(a.id)*37)%101)/100.0
		var distance: float=Vector2(a.tx-a.x,a.ty-a.y).length()
		a.decision_at=state.elapsed+distance/cruise+motion_rng.randf_range(5,14)
	# Only while a lure is set (live, never saved) does curiosity draw from motion_rng.
	if not lure.is_empty() and state.elapsed-lure.since<LURE.interest:
		var spot:=Vector2(lure.x,clampf(lure.y,band[0],band[1]))
		if Vector2(a.x,a.y).distance_to(spot)<LURE.range and motion_rng.randf()<LURE.chance:
			a.activity="Curious"
			a.tx=clampf(lure.x+(-1.0 if a.x<lure.x else 1.0)*LURE.stand_off,130,1150)
			a.ty=spot.y
			a.decision_at=state.elapsed+motion_rng.randf_range(LURE.look[0],LURE.look[1])
		# While the lure is fresh the leader keeps glancing at it.
		if a.activity!="Curious":
			a.decision_at=minf(a.decision_at,state.elapsed+5.0)

func _roaming_x(a: Dictionary, local_range: float, crossing_chance: float) -> float:
	if motion_rng.randf()<crossing_chance:
		# Occasionally visit the other side; each destination is still independently sampled.
		return motion_rng.randf_range(760,1130) if a.x<640 else motion_rng.randf_range(150,520)
	var direction: float=a.direction if motion_rng.randf()<0.65 else -a.direction
	var destination: float=a.x+direction*motion_rng.randf_range(40,local_range)
	# Reflect near the stream edges, avoiding repeated clamped targets at a wall.
	if destination<130: destination=260-destination
	if destination>1150: destination=2300-destination
	return clampf(destination,130,1150)

func natural_light() -> float:
	return clampf(sin((state.light_hour-6.0)/12.0*PI),0,1)

func sub_light() -> float:
	return natural_light()*(1.0-0.5*minf(1.0,state.resources.floating/PLANTS.floating.max))

func biofilm_max() -> float:
	return PLANTS.biofilm.max+PLANTS.biofilm.per_stem*state.resources.stem

func _excrete(amount: float) -> void:
	state.resources.nutrients+=amount*0.65
	state.resources.detritus+=amount*0.35

func _ecology(offline: bool) -> void:
	state.ecology_ticks+=1
	_live=not offline
	state.light_hour=fmod(state.light_hour+1.0/60.0,24.0)
	var r: Dictionary = state.resources
	var supply: float = state.get("supply_scale",1.0)
	# R5 stream exchange.
	for key: String in STREAM_IN:
		var inflow: float = STREAM_IN[key]*supply/1440
		r[key]+=inflow
		state.ledger["in"]+=inflow
	for key: String in STREAM_OUT:
		var outflow: float = r[key]*STREAM_OUT[key]/1440
		r[key]-=outflow
		state.ledger.out+=outflow
	# R3 plants: light brings energy, nutrients bring material.
	var sky: float = natural_light()
	var below: float = sub_light()
	for plant: String in PLANTS:
		var cfg: Dictionary = PLANTS[plant]
		var p: float = r[plant]
		var cap: float = biofilm_max() if plant=="biofilm" else cfg.max
		var light: float = sky if plant=="floating" else below
		var grow: float = minf(r.nutrients,cfg.r/1440*p*light*r.nutrients/(r.nutrients+K_NUTRIENT)*maxf(0,1-p/cap))
		var die: float = p*cfg.m/1440
		r.nutrients-=grow
		r[plant]+=grow-die
		r.detritus+=die
		var seed: float = cfg.seed*supply
		if r[plant]<seed:
			state.ledger["in"]+=seed-r[plant]
			r[plant]=seed
	# R4 microfauna graze detritus bacteria; detritus mineralises.
	var bloom: float = minf(r.detritus,MICRO.r/1440*r.microfauna*r.detritus/(r.detritus+MICRO.k)*maxf(0,1-r.microfauna/MICRO.max))
	var fade: float = r.microfauna*MICRO.m/1440
	# Like the animals (R1), microfauna turnover is half excreted as nutrients, half detritus.
	r.nutrients+=fade*0.5
	r.detritus+=fade*0.5-bloom
	r.microfauna+=bloom-fade
	var decay: float = r.detritus*DECAY/1440
	r.detritus-=decay
	r.nutrients+=decay
	if not state.get("food",[]).is_empty():
		_food_tick(offline)
	var males: Dictionary = {}
	for b: Dictionary in state.animals:
		if b.sex=="male" and b.age>=SPECIES[b.species].mature:
			males[b.species]=true
	var actors: Array = state.animals.duplicate()
	for a: Dictionary in actors:
		if not state.animals.has(a):
			continue
		var cfg: Dictionary = SPECIES[a.species]
		a.age+=1.0/1440
		var required: float = cfg.cost/1440
		var used: float = minf(a.energy,required)
		var deficit: float = required-used
		a.energy-=used
		_excrete(used)
		# R6 saturating intake, limited by the room left in reserve.
		var room: float = maxf(0,cfg.reserve-a.energy)/0.8
		var main: float = r[cfg.pool]
		var factor: float = main/(main+cfg.k_food)
		var food: float = minf(main,minf(room,cfg.bite/1440*factor))
		r[cfg.pool]-=food
		a.energy+=food*0.8
		r.detritus+=food*0.2
		var growth: float = minf(maxf(0,cfg.body-a.body),minf(a.energy*0.002,cfg.body/(cfg.mature*1440)))
		a.body+=growth
		a.energy-=growth
		a.hunger=clampf(1-a.energy/cfg.reserve,0,1)
		if a.energy<=deficit+0.000001:
			_remove(a,"starvation")
			continue
		if deficit>0:
			a.energy-=deficit
			_excrete(deficit)
		if a.age>=a.lifespan:
			_remove(a,"old age")
			continue
		if a.age>=cfg.mature and a.sex=="female" and a.energy>cfg.reserve*0.74 and a.age-a.last_breed>=cfg.cooldown:
			if males.has(a.species) and rng.randf()<cfg.breed/1440*factor:
				a.last_breed=a.age
				_breed(a)
	if state.ecology_ticks%60==0:
		_migration()
	if state.ecology_ticks%1440==0:
		_sample()
	_live=false

# Offline nobody chases food: drifting particles settle at once. Settled food turns to detritus.
func _food_tick(offline: bool) -> void:
	for f: Dictionary in state.food.duplicate():
		if offline and not f.settled:
			f.y=floor_y(f.x)-2
			f.settled=true
			f.settled_at=state.elapsed
		if f.settled and state.elapsed-f.settled_at>=FOOD.decay:
			state.resources.detritus+=f.mass
			state.food.erase(f)

func _breed(parent: Dictionary) -> void:
	if parent.species not in ACTIVE_SPECIES:
		return
	var cfg: Dictionary = SPECIES[parent.species]
	var cost: float = cfg.body*0.45+cfg.reserve*0.35
	for i in int(cfg.brood):
		if parent.energy<cost+cfg.reserve*0.2:
			break
		parent.energy-=cost
		if counts()[parent.species]>=CAP[parent.species] or state.animals.size()>=MAX_ANIMALS:
			state.ledger.out+=cost
			_event("dispersal",parent,"A youngster of "+parent.name+" dispersed into the surrounding stream.")
		else:
			var child: Dictionary = spawn(parent.species,0,parent.id)
			_bed_align(child,clampf(parent.x+rng.randf_range(-30,30),120,1150))
			_event("birth",child,"A young "+cfg.label.to_lower()+" was born to "+parent.name+".",{"target":parent.id})

func _remove(a: Dictionary, cause: String) -> void:
	if not state.animals.has(a):
		return
	var mass: float = a.body+a.energy
	if cause=="departure":
		state.ledger.out+=mass
		_event("departure",a,a.name+" moved downstream.")
	else:
		state.resources.detritus+=mass
		_event("death",a,a.name+" died from "+cause+".",{"cause":cause})
	state.causes[cause]=state.causes.get(cause,0)+1
	a.cause=cause
	a.ended=state.elapsed
	state.archive.append(a.duplicate(true))
	if state.archive.size()>96:
		state.archive.pop_front()
	state.animals.erase(a)

# R10: rescue a nearly vanished species; otherwise rare arrivals. Adults never wander off.
func _migration() -> void:
	var c: Dictionary = counts()
	for species: String in ACTIVE_SPECIES:
		if c[species]<=RESCUE_AT and rng.randf()<RESCUE_RATE:
			_arrive(species)
			c[species]+=1
	if rng.randf()<ARRIVAL_RATE:
		var species: String = ACTIVE_SPECIES[rng.randi_range(0,ACTIVE_SPECIES.size()-1)]
		if c[species]<CAP[species] and state.animals.size()<habitat_cap():
			_arrive(species)

func _arrive(species: String) -> Dictionary:
	var a: Dictionary = spawn(species,SPECIES[species].mature+rng.randf_range(0,20))
	if a.is_empty():
		return a
	_bed_align(a,1150.0 if rng.randf()<0.5 else 130.0)
	state.ledger["in"]+=a.body+a.energy
	_event("arrival",a,"A "+SPECIES[species].label.to_lower()+" arrived from upstream.")
	return a

func _sample() -> void:
	var sample: Dictionary = counts()
	sample.day=state.elapsed/DAY
	sample.material_residual=residual()
	state.history.append(sample)
	if state.history.size()>400:
		state.history.pop_front()

# The combined habitat caps (12; 16 with the hatchetfish, 22 with the shrimp).
static func habitat_cap() -> int:
	var total: int = 0
	for species: String in CAP:
		total+=int(CAP[species])
	return total

func counts() -> Dictionary:
	var c: Dictionary = {}
	for species: String in ACTIVE_SPECIES:
		c[species]=0
	for a: Dictionary in state.animals:
		c[a.species]+=1
	return c

func material() -> float:
	var total: float = 0
	for amount: float in state.resources.values():
		total+=amount
	for a: Dictionary in state.animals:
		total+=a.body+a.energy
	for f: Dictionary in state.get("food",[]):
		total+=f.mass
	return total

func residual() -> float:
	return material()-(state.ledger.initial+state.ledger["in"]-state.ledger.out)

func snapshot() -> Dictionary:
	return state.duplicate(true)

# Events a stage has not seen yet: those with an id above `seq`. Legacy events have no id.
static func events_after(events: Array, seq: int) -> Array:
	return events.filter(func(e: Dictionary) -> bool: return e.get("seq",0)>seq)

func export_state() -> Dictionary:
	var saved: Dictionary = snapshot()
	saved.rng=str(rng.state)
	saved.motion_rng=str(motion_rng.state)
	return saved

func restore(saved: Dictionary) -> bool:
	if not validate(saved):
		return false
	state=saved.duplicate(true)
	rng.seed=state.seed
	motion_rng.seed=state.seed+7919
	rng.state=int(state.rng)
	motion_rng.state=int(state.motion_rng)
	state.erase("rng")
	state.erase("motion_rng")
	lure={}
	# Saves from before event ids start numbering at 1 (validate forbids ids without it).
	if not state.has("next_event"):
		state.next_event=1
	if state.version==1:
		_upgrade_v1()
	# The user explicitly removed crayfish (2026-09-22), shrimp and hatchetfish (2026-09-23), threadfin (2026-09-24)
	# from this pool. Preserve every other identity, archive each departure and account
	# for its exported material. An unhatched shrimp brood leaves with its mother:
	# its cost was never taken, so no young and no extra material.
	for a: Dictionary in state.animals.duplicate():
		if a.species not in ACTIVE_SPECIES:
			a.erase("brood_until")
			_remove(a,"departure")
	# Saves from before the garden eels (2026-09-23): a pair arrives once, like any
	# arrival but not live. A colony that later dies out is not replaced on load.
	if not state.get("eel_colony",false):
		for sex: String in ["female","male"]:
			var eel: Dictionary = _arrive("garden_eel")
			if not eel.is_empty():
				eel.sex=sex
		state.eel_colony=true
	# Saves from before the reef (2026-09-24): its opening cast arrives once, not live,
	# alternating female/male, after the threadfin (and older species) departed above.
	if not state.get("reef_cast",false):
		for species: String in REEF_CAST:
			for i in int(SPECIES[species].initial):
				var a: Dictionary = _arrive(species)
				if not a.is_empty():
					a.sex="female" if i%2==0 else "male"
		state.reef_cast=true
	return true

# R12: add the new pools from the stream (ledger.in) and give every animal a lifespan.
# Identities, names and lineage are untouched.
func _upgrade_v1() -> void:
	state.version=VERSION
	for pool: String in POOLS:
		if not state.resources.has(pool):
			state.resources[pool]=OPENING[pool]
			state.ledger["in"]+=OPENING[pool]
	state.causes={}
	for a: Dictionary in state.animals:
		# Older animals keep a short remaining life rather than all dying on upgrade.
		a.lifespan=maxf(SPECIES[a.species].lifespan*rng.randf_range(0.85,1.15),a.age+rng.randf_range(5,40))

static func validate(saved: Dictionary) -> bool:
	var version: Variant = saved.get("version",-1)
	if not version is int or version not in [1,VERSION]:
		return false
	for key: String in ["seed","next_id","motion_ticks","ecology_ticks"]:
		if not saved.get(key) is int or saved[key]<0:
			return false
	for key: String in ["elapsed","ecology_remainder","motion_remainder","wall_checkpoint","light_hour"]:
		if not _number(saved.get(key)) or saved[key]<0:
			return false
	if saved.ecology_remainder>=60 or saved.motion_remainder>=0.201:
		return false
	if saved.has("next_event") and (not saved.next_event is int or saved.next_event<1):
		return false
	for key: String in ["eel_colony","reef_cast"]:
		if saved.has(key) and not saved[key] is bool:
			return false
	if not _valid_food(saved):
		return false
	var next_event: int = saved.get("next_event",0)
	for key: String in ["rng","motion_rng"]:
		if not saved.get(key) is String or not saved[key].is_valid_int():
			return false
	for key: String in ["animals","archive","events","history"]:
		if not saved.get(key) is Array:
			return false
	if saved.animals.size()>MAX_ANIMALS or saved.archive.size()>96 or saved.events.size()>160 or saved.history.size()>400:
		return false
	for group: String in ["resources","ledger","totals"]:
		if not saved.get(group) is Dictionary:
			return false
		# totals.predation stays for older saves; predation was removed on 2026-09-23 and it never grows.
		var keys: Array = {"resources":["biofilm","detritus","microfauna"] if version==1 else POOLS,"ledger":["initial","in","out"],"totals":["birth","death","arrival","departure","dispersal","molt","predation"]}[group]
		for key: String in keys:
			if not _number(saved[group].get(key)) or saved[group][key]<0:
				return false
	var ids: Dictionary = {}
	for a: Variant in saved.animals+saved.archive:
		if not a is Dictionary or not a.get("id") is int or a.id<=0 or a.id>=saved.next_id or ids.has(a.id) or not SPECIES.has(a.get("species","")):
			return false
		ids[a.id]=true
		for key: String in ["name","sex","activity"]:
			if not a.get(key) is String:
				return false
		for key: String in ["age","born","body","energy","x","y","tx","ty","direction","decision_at","last_breed","next_molt","molting_until","shelter","hunger","parent"]:
			if not _number(a.get(key)):
				return false
		if a.has("food_id") and not a.food_id is int:
			return false
		for key: String in ["vx","vy","relocated_at","brood_until","tint","extend"]:
			if a.has(key) and not _number(a[key]):
				return false
		if a.get("brood_until",0)<0 or a.get("tint",0)<0 or a.get("tint",0)>1 or a.get("extend",0)<0 or a.get("extend",0)>1:
			return false
		if a.species in HOMES and (not _number(a.get("burrow_x")) or not _number(a.get("burrow_y"))):
			return false
		if a.species=="purple_firefish" and (not _number(a.get("hover_y")) or a.hover_y<0):
			return false
		if version>1 and a in saved.animals and (not _number(a.get("lifespan")) or a.lifespan<=0):
			return false
		if a.age<0 or a.body<0 or a.energy<0 or not a.get("recent") is Array or a.recent.size()>6:
			return false
		for e: Variant in a.recent:
			if not _valid_event(e,next_event):
				return false
	for e: Variant in saved.events:
		if not _valid_event(e,next_event):
			return false
	if version>1:
		if not saved.get("causes") is Dictionary:
			return false
		for count: Variant in saved.causes.values():
			if not _number(count) or count<0:
				return false
	return true

# Optional since 2026-09-23 (feeding); saves without them have no food.
static func _valid_food(saved: Dictionary) -> bool:
	if saved.has("fed") and (not saved.fed is Dictionary or not saved.fed.get("day") is int or saved.fed.day<0 or not _number(saved.fed.get("mass")) or saved.fed.mass<0):
		return false
	if not saved.has("food"):
		return true
	var next_food: Variant=saved.get("next_food")
	if not saved.food is Array or saved.food.size()>FOOD.max or not next_food is int or next_food<1:
		return false
	var seen: Dictionary={}
	for f: Variant in saved.food:
		if not f is Dictionary or not f.get("id") is int or f.id<1 or f.id>=next_food or seen.has(f.id) or not f.get("settled") is bool:
			return false
		seen[f.id]=true
		for key: String in ["x","y","mass","settled_at"]:
			if not _number(f.get(key)):
				return false
		if f.mass<=0:
			return false
	return true

static func _number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))

static func _valid_event(e: Variant, next_event: int) -> bool:
	if not e is Dictionary or e.has("seq") and (not e.seq is int or e.seq<1 or e.seq>=next_event):
		return false
	return e.get("text") is String and e.get("kind") is String and e.get("id") is int and _number(e.get("time"))
