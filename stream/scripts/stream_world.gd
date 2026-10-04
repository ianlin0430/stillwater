class_name StreamWorld
extends RefCounted

# World v3 (2026-09-28): Stillwater Reef starts a new world; older formats are not read (StreamStore).
const VERSION: int = 3
const MAX_ANIMALS: int = 24
const MAX_AWAY: float = 259200.0
const DAY: float = 86400.0
# Reef v3 cast (2026-09-28 redesign, S4): the green chromis stays; the clownfish, seahorse and royal
# gramma replace the lawnmower blenny, purple firefish and yellow tang. All four eat microfauna.
const ACTIVE_SPECIES: Array[String] = ["green_chromis","clownfish","seahorse","royal_gramma"]
const SPECIES: Dictionary = {
	# Authored rates; each species breaks even at food 10 (cost = 0.4 x bite). Sized by offline probe
	# (docs/ecology.md "Reef v3 cast sizing"); the chromis values are unchanged since 2026-09-24.
	"green_chromis": {"label":"Green chromis","latin":"Chromis viridis","initial":6,"mature":30.0,"lifespan":180.0,"body":0.5,"reserve":3.5,"cost":0.2,"bite":0.5,"brood":2,"breed":0.1,"cooldown":8.0,"pool":"microfauna","k_food":10.0},
	"clownfish": {"label":"Clownfish","latin":"Amphiprion ocellaris","initial":2,"mature":45.0,"lifespan":300.0,"body":0.6,"reserve":4.0,"cost":0.2,"bite":0.5,"brood":2,"breed":0.06,"cooldown":12.0,"pool":"microfauna","k_food":10.0},
	"seahorse": {"label":"Seahorse","latin":"Hippocampus kuda","initial":2,"mature":60.0,"lifespan":300.0,"body":0.5,"reserve":3.5,"cost":0.16,"bite":0.4,"brood":2,"breed":0.05,"cooldown":14.0,"pool":"microfauna","k_food":10.0},
	"royal_gramma": {"label":"Royal gramma","latin":"Gramma loreto","initial":2,"mature":40.0,"lifespan":240.0,"body":0.4,"reserve":3.0,"cost":0.16,"bite":0.4,"brood":2,"breed":0.07,"cooldown":10.0,"pool":"microfauna","k_food":10.0}}
# Ecology v2 (docs/plans/2026-09-22-self-sustaining-ecosystem.md). Rates are per day, applied per one-minute tick.
# Reef v3 cast (S2 probe, 2026-09-28): caps 8+3+4+3 = 18, opening cast 6+2+2+2 = 12 (SPECIES.initial).
# These two are the only places the cast sizes live; the arrival limit (habitat_cap) and the
# long-run band follow from them. Each cap fits the scene's homes (tests/test_scene_data.gd):
# clownfish <= anemone capacity, seahorse <= hitches of the required plant, gramma <= rock spots.
const CAP: Dictionary = {"green_chromis":8,"clownfish":3,"seahorse":4,"royal_gramma":3}
const POOLS: Array[String] = ["nutrients","stem","floating","biofilm","microfauna","detritus"]
# Opening pools (R11, set with the earlier shrimp cast).
const OPENING: Dictionary = {"nutrients":0.4,"stem":45.0,"floating":24.0,"biofilm":32.0,"microfauna":24.0,"detritus":8.0}
const PLANTS: Dictionary = {
	"floating": {"r":1.3,"m":0.025,"max":40.0,"seed":0.4},
	"stem": {"r":0.8,"m":0.02,"max":120.0,"seed":1.0},
	"biofilm": {"r":6.0,"m":0.03,"max":30.0,"per_stem":0.4,"seed":0.5}}
const K_NUTRIENT: float = 3.0
const MICRO: Dictionary = {"r":1.2,"m":0.06,"max":80.0,"k":25.0}
const DECAY: float = 0.08
# Microfauna input 1.2 a day (S2, 2026-09-28; was 0.35): four species now share the one food pool.
const STREAM_IN: Dictionary = {"nutrients":0.7,"microfauna":1.2}
const STREAM_OUT: Dictionary = {"nutrients":0.05,"microfauna":0.015,"detritus":0.04,"floating":0.005}
# Chromis school: the lowest-id chromis leads; each other member holds its own slot
# (golden-angle direction, radius in `spread` px, flattened vertically, mirrored with the
# leader's heading) and hurries (`catch_up` x speed) when more than `regroup` px from it.
# Members keep `spacing` px apart. A resting fish within `hold` px of its spot stops steering
# toward it and keeps its facing: it glides to a stop and hovers (2026-09-26, user: resting
# chromis bobbed up and down at night from small repeated corrections); within `hold` px of the
# spot's depth it never corrects its depth.
const CHROMIS: Dictionary = {"spread":[34.0,80.0],"regroup":120.0,"catch_up":1.8,"spacing":36.0,"breathe":0.12,"hold":10.0}
# A species is rescued from upstream only when it can no longer breed here: one or none left
# (2026-09-24; was two, when each species had six places and two was a third of them).
const RESCUE_AT: int = 1
# Never dies out (2026-09-28, user decision; plan §4.3): a rescue is certain. When a species is at
# or below RESCUE_AT at the hourly migration check, one arrival is scheduled RESCUE_DELAY seconds
# later (one rng draw, 2-22 h); checks are hourly, so it arrives within 24 h of the drop.
const RESCUE_DELAY: Array[float] = [7200.0,79200.0]
# Never starves (2026-09-28, user decision; plan §4.3): energy has a floor of FLOOR x reserve.
# Metabolism is paid only down to it; what cannot be paid is not paid (nothing is taken from any
# pool, so the ledger still balances). Breeding needs 0.74 x reserve, so a fish at the floor never
# breeds. Each animal-minute that meets the floor adds one to totals.floor_hits.
const FLOOR: float = 0.1
# Opening ages in days (R11): one opener per stratum of [lo, hi]. The long-run gates derive
# the old-age deaths the opening cast must produce from these (tests/ecology_acceptance.gd).
const OPENING_AGE: Dictionary = {"fish":[40.0,150.0]}
const ARRIVAL_RATE: float = 1.0/504.0
# An unexplained position jump larger than this in one motion tick is a relocation
# (animals carry relocated_at). Generic: fish layer clamping stays under 1 px in normal
# play, so only a fish found outside its band, e.g. from an edited save, is snapped back and marked.
const RELOCATION: float = 3.0
# Terrain comes from the scene file (ReefScene, data/scenes/<id>.json): bed, depth bands, x bounds,
# exits, obstacles and homes. A new world starts in this scene (switching comes in S11).
const DEFAULT_SCENE: String = "reef"
# Homes of the new fish (S4, the simplest behaviour; the full behaviours are S6-S8): each lives at
# a home from the scene's decor - the clownfish share the anemone (up to its capacity), a seahorse
# takes a hitch point of its own, a royal gramma a cave (a shelter whose `use` names it) or else a
# rock spot of the scene. By day it swims (`Hovering`) to points within `radius` px of its home,
# a new one every `dwell` s; at night it rests beside it. Assigned without any rng draw.
const HOME: Dictionary = {
	"clownfish":{"kind":"anemone","radius":60.0,"dwell":[6.0,15.0]},
	"seahorse":{"kind":"hitch","radius":30.0,"dwell":[15.0,40.0]},
	"royal_gramma":{"kind":"shelter","radius":50.0,"dwell":[5.0,12.0]}}
# Feeding (user decision 2026-09-23: real food, never required). A pinch is `particles` of
# `mass` dropped just below the surface (y `surface`); at most `daily` mass per simulated day.
# Particles sink `sink` px/s; fish with room notice food within `notice` px and eat it within
# `eat` px. Food on the bed becomes detritus `decay` seconds after it settles.
# Every pellet eaten is an `ate` event (no journal text); the journal keeps only the latest `max_bites`. See
# docs/BACKEND_SNAPSHOT_EVENTS.md.
const FOOD: Dictionary = {"particles":5,"mass":0.05,"daily":1.0,"max":40,"surface":56.0,"sink":10.0,"notice":260.0,"eat":12.0,"decay":900.0,"max_bites":10}
# Tap the glass: fish within `radius` dart up to `dart` px away for `seconds`. Presentation of the
# tap only; no ecology effect, nothing saved.
const STARTLE: Dictionary = {"radius":260.0,"dart":150.0,"seconds":3.0}
# Cursor lure: for `interest` seconds after the cursor comes to rest, the chromis school leader
# choosing its next move within `range` of it looks with probability `chance`, hovering `stand_off`
# px to the side for `look` seconds. Jitter under `still` px keeps the same lure. Never saved.
const LURE: Dictionary = {"range":320.0,"chance":0.5,"interest":45.0,"look":[6.0,12.0],"stand_off":36.0,"still":8.0}
# Adult body [length, height] in world px, halved for juveniles like the rig. Used to keep bodies
# apart. Chromis from its approved art (ReefRig.LOOK). The three new fish (S4, 2026-09-28): Codex's
# conservative sprite envelopes from the H3 handoff (assets/reef/PROVENANCE.md "H3 backend BODY
# handoff", from ReefFishArt.extent_for); the seahorse is upright, narrow in x and tall in y.
const BODY: Dictionary = {"green_chromis":[68.0,39.0],"clownfish":[69.0,44.0],"seahorse":[37.0,61.0],"royal_gramma":[68.0,37.0]}
# Body separation between swimmers (2026-09-25). Each pair is measured in the ellipse of their
# combined half bodies times `margin` (x 1.17 for two species, x `same` for two of one species);
# a fish reacts to where the pair will be up to `look` s ahead, dodging mostly up or down (the
# upper fish rises), and never closes in once inside `close`; the younger id gives way. Chromis
# space themselves (CHROMIS) and a resting chromis stays put.
# Swimming (2026-09-25, user: "natural first"). Per species: `cruise` px/s (x 0.82-1.18 per id),
# `turn` max heading rate rad/s (x `startle_turn` when startled), `pitch` max nose up/down rad and
# `pitch_rate` rad/s, water `drag` /s, stroke power `push` (terminal speed = push x wanted), `gap`
# burst-and-glide band (0 = smooth rowing with `respond` /s and a `row` surge every `stroke` s),
# pectoral `brake` px/s2, `scull` px/s at a standstill, `drift` rise-and-fall share while travelling.
# `edge`: px over which a climb or dive eases off before a depth-band edge; `ramp`: how fast (/s)
# thrust can build toward full. The three new fish (S4, provisional until S6-S8): the clownfish and
# gramma swim in bursts like the chromis, a little slower; the seahorse rows slowly and evenly.
const SWIM: Dictionary = {
	"green_chromis":{"cruise":17.0,"turn":4.0,"pitch":0.7,"pitch_rate":0.8,"drag":0.9,"push":2.0,"gap":0.3,"brake":24.0,"scull":6.0,"drift":0.22},
	"clownfish":{"cruise":12.0,"turn":3.0,"pitch":0.5,"pitch_rate":0.6,"drag":0.9,"push":2.0,"gap":0.3,"brake":20.0,"scull":5.0,"drift":0.15},
	"seahorse":{"cruise":4.0,"turn":1.0,"pitch":0.2,"pitch_rate":0.3,"drag":0.6,"push":2.0,"gap":0.0,"respond":0.8,"row":0.05,"stroke":1.2,"brake":4.0,"scull":3.0,"drift":0.1},
	"royal_gramma":{"cruise":13.0,"turn":3.5,"pitch":0.6,"pitch_rate":0.7,"drag":0.9,"push":2.0,"gap":0.3,"brake":22.0,"scull":5.0,"drift":0.15},
	"startle_speed":2.4,"startle_turn":4.0,"turn_gain":3.0,"edge":40.0,"ramp":2.0}
const SEPARATE: Dictionary = {"margin":1.2,"look":5.0,"gain":1.6,"close":1.05,"same":1.25,"perch":1.15}
# Obstacles (S5, 2026-09-29; plan §3.2; user 2026-09-28: decor is an obstacle the fish go around,
# never through, and every move is smooth and natural, not realistic). The obstacles are the
# scene's terrain plus each slot's decor (ReefScene.obstacles, axis-aligned ellipses). Each swimmer:
# - aims clear of them (_aim): a target inside an obstacle widened by `body` x its half body (so a
#   body clear of that overlaps the obstacle by at most a fifth) is moved out to its edge;
# - swims straight at its aim when the straight line is clear; when an obstacle is in the way it
#   follows a route round (_navigate, NAV), steering at the furthest point of the route it can see,
#   which slides along the route as the view opens: one smooth arc round each obstacle;
# - never has its centre inside one (_keep_out): a step that would cross an edge slides along it.
# Beside its own home (its home point inside the widened ellipse: a gramma at its cave, a seahorse
# on the cave rock's hitch) a fish keeps only its centre `pad` px out. A fish found inside an
# obstacle (decor set down over it) swims straight out the short way at `escape` x its cruise,
# never snapped. What else steers it (spacing, making way for other fish) never pushes it into an
# obstacle: within `hold` beyond its widened radii the part heading in fades out, and inside them it
# eases back out, by `out` x cruise x how deep it is (_hold_off).
const OBSTACLE: Dictionary = {"pad":4.0,"body":0.8,"escape":0.6,"hold":0.35,"out":1.0,"ahead":1.0}
# Routes round obstacles (S5): planned on a grid of `cell` px (A*), again only once the aim moves
# more than `replan` px (or the fish has been pushed that far off its route).
# (S5-fix) A cell with less than `room` x the body height of open water around it costs up to
# 1 + `narrow` times a step in open water.
# `lane`: a passage narrower than lane x the body (length across, height up and down) is one
# fish at a time (_must_wait).
const NAV: Dictionary = {"cell":10.0,"replan":24.0,"leave":3.0,"room":1.0,"narrow":3.0,"lane":1.4,"moved":10.0,"patience":6.0,"give":8.0}
const NAMES: Dictionary = {"green_chromis":["Jade","Mint","Lagoon","Kelp","Glass","Pearl"],"clownfish":["Poppy","Ember"],"seahorse":["Drift","Kelpie"],"royal_gramma":["Violet","Dusk"]}
var rng := RandomNumberGenerator.new()
var motion_rng := RandomNumberGenerator.new()
var state: Dictionary
# Live-only cursor lure {x, y, since}; empty when there is none. Not part of state.
var lure: Dictionary = {}
# True only while a live ecology tick runs; stamps events the stage may play.
var _live: bool = false
# How urgently the last _avoid() call had to dodge (0 = clear, up to 1). Scratch, never saved.
var _dodge: float = 0.0
# How close the last _around() call found the obstacle in the way (0 = clear, 1 = at its edge or
# inside), and whether the fish was inside one. Scratch, never saved.
var _close: float = 0.0
var _escaping: bool = false
# The direction of the route leg the last _navigate() call steered along (ZERO when none).
var _leg: Vector2 = Vector2.ZERO
# Per-tick scratch that _move() fills before moving anyone (2026-09-27, speed only; never saved):
# the non-chromis animals in state.animals order and each animal's _body() by id. Within a motion
# tick no animal is added or removed and no species or age changes.
var _not_chromis: Array = []
var _bodies: Dictionary = {}
# The world's scene (state.scene) and what is read from it once (never saved): depth band per
# species [top, bottom], x bounds (swim: where a fish may be; roam: where it may aim) and the homes.
var scene: ReefScene
var _bands: Dictionary = {}
var _swim_x: Vector2
var _roam_x: Vector2
var _feed_x: Vector2
var _homes: Dictionary = {}
# The obstacles of the scene with its current decor (ReefScene.obstacles): terrain first, then each
# slot's, as {cx, cy, rx, ry}. Re-read whenever the scene or the decor changes; never saved.
var _obstacles: Array = []
# Navigation scratch (S5, never saved): the water grid per species and size, and each fish's
# route by id (both planned again, the same, after a restore or a decor change).
var _grids: Dictionary = {}
var _routes: Dictionary = {}
var _open_targets: Dictionary = {}
# The default scene, for the static floor_y (frontend callers).
static var _default_scene: ReefScene = null
# Every scene, read once, for validate() (static) and the new world's decor.
static var _scenes: Dictionary = {}

static func _scene_of(scene_id: String) -> ReefScene:
	if not _scenes.has(scene_id):
		_scenes[scene_id]=ReefScene.open(scene_id)
	return _scenes[scene_id]

func _init(world_seed: int = 240921, wall_time: float = 0, scene_id: String = DEFAULT_SCENE) -> void:
	rng.seed = world_seed
	motion_rng.seed = world_seed + 7919
	if not ReefScene.ids().has(scene_id):
		scene_id=DEFAULT_SCENE
	# Decor (S5): each scene's slots {slot_id: style or ""}, every scene starting at its defaults.
	var decor: Dictionary={}
	for id: String in ReefScene.ids():
		decor[id]=_scene_of(id).default_decor()
	state = {"version":VERSION,"seed":world_seed,"scene":scene_id,"decor":decor,"elapsed":0.0,"ecology_remainder":0.0,"motion_remainder":0.0,"motion_ticks":0,"ecology_ticks":0,"next_id":1,"next_event":1,"wall_checkpoint":wall_time,"animals":[],"archive":[],"events":[],"history":[],"resources":OPENING.duplicate(),"ledger":{"initial":0.0,"in":0.0,"out":0.0},"totals":{"birth":0,"death":0,"arrival":0,"departure":0,"dispersal":0,"floor_hits":0},"causes":{},"light_hour":12.0}
	_use_scene(scene_id)
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
				var at: Vector2=_clear_spot(species,Vector2(560.0+i*40.0,280.0+(i%2)*30))
				animal.x=at.x
				animal.y=at.y
			animal.tx=animal.x
			animal.ty=animal.y
	state.ledger.initial = material()
	_event("begin",{},"A small world begins beneath the surface.")
	_sample()

# Reads the scene's terrain and homes (never saved; a restored world reads its state.scene again).
func _use_scene(scene_id: String) -> void:
	scene=ReefScene.open(scene_id)
	var b: Dictionary=scene.bounds()
	_swim_x=Vector2(b.swim_x[0],b.swim_x[1])
	_roam_x=Vector2(b.roam_x[0],b.roam_x[1])
	_feed_x=Vector2(b.feed_x[0],b.feed_x[1])
	for species: String in ACTIVE_SPECIES:
		var band: Vector2=scene.band(species)
		_bands[species]=[band.x,band.y]
	_use_decor()

# Reads the obstacles and the homes of the current scene's decor (never saved).
func _use_decor() -> void:
	_obstacles=scene.obstacles(state.decor[state.scene])
	_grids.clear()
	_routes.clear()
	_open_targets.clear()
	for species: String in HOME:
		_homes[species]=_home_spots(species)

# Puts `style` in `slot` of the current scene (S5; plan §5.1, H4): one of the slot's styles, or ""
# to empty a slot that is not required (the anemone and the hitch plant change style but are never
# cleared). False, changing nothing, for anything else. Decor is presentation and habitat, never
# ecology: it adds no food and changes no cap, draws from neither rng and moves nobody at once. A
# fish whose home went moves to the free home nearest it (the anemone's new centre, another hitch,
# cave or rock spot) and swims there; one the new decor covers swims out (_move), never snapped.
func set_decor(slot: String, style: String) -> bool:
	if not scene.allows(slot,style):
		return false
	var decor: Dictionary=state.decor[state.scene]
	if decor[slot]==style:
		return true
	decor[slot]=style
	_use_decor()
	for a: Dictionary in state.animals:
		# (Each fish plans its way round afresh.)
		_forget_around(a)
		for key: String in ["pass_claims","pass_tx","pass_ty","pass_from_x","pass_from_y","pass_route"]:
			a.erase(key)
	_rehome()
	return true

# After a decor change: a fish keeps its home if the decor still has it (moving with it when it
# moved, e.g. a new anemone style); the others, in id order, take the free home nearest the old
# one and choose their next move now. No rng draw.
func _rehome() -> void:
	var lost: Array=[]
	for a: Dictionary in state.animals:
		if not a.has("home"):
			continue
		var same: Dictionary={}
		for h: Dictionary in _homes[a.species]:
			if _home_key(h)==_home_key(a.home):
				same=h
		if same.is_empty():
			lost.append(a)
		elif a.home_x!=same.x or a.home_y!=same.y:
			a.home_x=same.x
			a.home_y=same.y
			a.decision_at=minf(a.decision_at,state.elapsed)
	for a: Dictionary in lost:
		# (Not counted as taken while it looks: its old key matches no home now.)
		var h: Dictionary=_nearest_free(a.species,Vector2(a.home_x,a.home_y))
		a.home={"kind":h.kind,"slot":h.slot,"i":h.i}
		a.home_x=h.x
		a.home_y=h.y
		a.decision_at=minf(a.decision_at,state.elapsed)

# Depth band [top, bottom] of a species in this world's scene.
func band(species: String) -> Array:
	return _bands[species]

# Bed height at x in this world's scene.
func bed_y(x: float) -> float:
	return scene.floor_y(x)

# Bed height at x in the default scene (the frontend's static call, main.gd and stream_events.gd;
# plan H3 moves those to the world's own scene). Equal to bed_y while S4 has one scene.
static func floor_y(x: float) -> float:
	if _default_scene==null:
		_default_scene=ReefScene.open(DEFAULT_SCENE)
	return _default_scene.floor_y(x)

func animal_scale(a: Dictionary) -> float:
	var juvenile: bool = a.age < SPECIES[a.species].mature
	return 0.5 if juvenile else 1.0

# A chromis somewhere in midwater (motion_rng only).
func _place(species: String) -> Vector2:
	var x: float = motion_rng.randf_range(150,1130)
	var y: float = motion_rng.randf_range(220,390)
	return Vector2(x,y)

func spawn(species: String, age: float = 0, parent: int = 0) -> Dictionary:
	if species not in ACTIVE_SPECIES or state.animals.size()>=MAX_ANIMALS:
		return {}
	var cfg: Dictionary = SPECIES[species]
	var home: Dictionary = _free_home(species,parent) if HOME.has(species) else {}
	var p: Vector2 = _clear_spot(species,_near_home(species,home,state.next_id) if not home.is_empty() else _place(species))
	var a: Dictionary = {"id":state.next_id,"species":species,"name":cfg.label+" "+str(state.next_id),"sex":"female" if rng.randf()<0.5 else "male","age":age,"parent":parent,"born":state.elapsed,"body":cfg.body*(0.45 if age<cfg.mature else 1.0),"energy":cfg.reserve*(0.35 if age<cfg.mature else 0.67),"x":p.x,"y":p.y,"tx":p.x,"ty":p.y,"direction":1.0 if p.x<640 else -1.0,"activity":"Resting","decision_at":0.0,"last_breed":-cfg.cooldown,"recent":[],"hunger":0.0}
	a.lifespan=cfg.lifespan*rng.randf_range(0.85,1.15)
	if not home.is_empty():
		a.home={"kind":home.kind,"slot":home.slot,"i":home.i}
		a.home_x=home.x
		a.home_y=home.y
	state.next_id += 1
	state.animals.append(a)
	return a

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
	if kind=="ate":
		# Bites are for the stage, not the story: out of `recent`, and only the latest few kept.
		var bites: Array=state.events.filter(func(x): return x.kind=="ate")
		for i in bites.size()-FOOD.max_bites:
			state.events.erase(bites[i])
	elif not a.is_empty():
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
	x=clampf(x,_feed_x.x,_feed_x.y)
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

# Taps the glass at (x, y). Returns how many animals noticed. Each darts away inside its band.
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
		var away: Vector2=(p-hit)/gap if gap>0.01 else Vector2(a.direction,0)
		var band: Array=_bands[a.species]
		var to: Vector2=p+away*STARTLE.dart*(1.0-0.5*gap/reach)
		a.activity="Startled"
		a.tx=clampf(to.x,_roam_x.x,_roam_x.y)
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
		if a.species=="green_chromis" and a.activity in ["Schooling","Resting"]:
			a.decision_at=minf(a.decision_at,state.elapsed+1.0)

func clear_lure() -> void:
	lure={}

func _sink_food(delta: float) -> void:
	for f: Dictionary in state.food:
		if f.settled:
			continue
		f.y+=FOOD.sink*delta
		var bed: float=bed_y(f.x)-2
		if f.y>=bed:
			f.y=bed
			f.settled=true
			f.settled_at=state.elapsed

# Nearest drifting food this fish can reach within its layer, if it has room to eat.
func _seek_food(a: Dictionary) -> bool:
	var best: Dictionary={}
	var band: Array=_bands[a.species]
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
	# Aim where the sinking pellet will be when the fish gets there (at most 3 s ahead).
	a.ty=clampf(best.y+FOOD.sink*minf(3.0,Vector2(a.x,a.y).distance_to(Vector2(best.x,best.y))/SWIM[a.species].cruise),band[0],band[1])
	# Choose again as soon as the food is gone.
	a.decision_at=state.elapsed
	return true

# Food mass becomes the eater's energy (80%) and detritus (20%), as with natural food (R6).
# Only live motion eats food, so the bite is always a live `ate` event: actor x/y, pellet food_x/food_y.
func _eat(a: Dictionary, f: Dictionary) -> void:
	a.energy+=f.mass*0.8
	state.resources.detritus+=f.mass*0.2
	state.food.erase(f)
	a.erase("food_id")
	_live=true
	_event("ate",a,"",{"food_id":f.id,"food_x":f.x,"food_y":f.y})
	_live=false

func _move(delta: float) -> void:
	if not state.get("food",[]).is_empty():
		_sink_food(delta)
	# The lowest-id chromis leads the school (it decides; the others follow). Empty if none.
	var lead: Dictionary={}
	_not_chromis.clear()
	_bodies.clear()
	for o: Dictionary in state.animals:
		_bodies[o.id]=_body(o)
		if o.species!="green_chromis":
			_not_chromis.append(o)
		elif lead.is_empty() or o.id<lead.id:
			lead=o
	for a: Dictionary in state.animals:
		var p:=Vector2(a.x,a.y)
		var species: String=a.species
		var chromis: bool=species=="green_chromis"
		var startled: bool=a.activity=="Startled" and state.elapsed<a.decision_at
		var follower: bool=chromis and a.id!=lead.id
		if not startled and not _seek_food(a):
			if follower:
				_follow(a,lead)
			elif state.elapsed>=a.decision_at:
				if chromis:
					_choose_activity(a)
				else:
					_choose_home(a)
		# Its band, but never so low that the body dips into the bed (a scene's band may reach below
		# the bed where the sand rises, e.g. the royal gramma's; S4 audit_space).
		var band: Array=[_bands[species][0],minf(_bands[species][1],bed_y(p.x)-_bodies[a.id].y*0.5)]
		# (Targets are always in the band; an edited one is aimed at the band edge. One inside an
		# obstacle is aimed at its edge, S5.)
		var radii: PackedVector2Array=_radii_of(a)
		# Select a real destination, rather than steering at a substitute while the
		# decision system still believes the old destination is outstanding.
		if not follower and not startled and not a.has("food_id") and not _obstacles.is_empty():
			var chosen: Vector2=Vector2(a.tx,a.ty)
			if not a.has("home_x") or chosen.distance_to(Vector2(a.home_x,a.home_y))>HOME[species].radius:
				var open: Vector2=_open_target(a,chosen)
				a.tx=open.x
				a.ty=open.y
		var target: Vector2=_aim(a,radii)
		var offset: Vector2=target-p
		# A resting fish already within `hold` px of its spot's depth never corrects its depth:
		# nudged aside (spacing) it glides straight back, level (2026-09-26).
		var resting: bool=a.activity=="Resting"
		# (Twice that beside an obstacle, where its spot is moved to the obstacle's edge and slides up
		# and down the edge as the slot breathes, S5.)
		var pushed: bool=target.distance_squared_to(Vector2(a.tx,clampf(a.ty,band[0],band[1])))>0.01
		if resting and absf(offset.y)<CHROMIS.hold*(2.0 if pushed else 1.0):
			offset.y=0.0
		var gap: float=offset.length()
		var cfg: Dictionary=SWIM[species]
		var cruise: float=cfg.cruise*(0.82+0.36*float((int(a.id)*37)%101)/100.0)
		var speed: float=cruise
		if resting:
			speed=1.2
		elif a.activity=="Startled":
			speed*=SWIM.startle_speed
		elif follower:
			speed*=CHROMIS.catch_up if gap>CHROMIS.regroup else 1.15
		# Arrive: never faster than the fish can brake to a stop at the target.
		# (Chasing a sinking pellet it keeps closing in: no slower than twice the sink speed.)
		var top: float=minf(speed,maxf(sqrt(2.0*cfg.brake*gap),2.0*FOOD.sink if a.activity=="Feeding" else 0.0))
		var arrive: Vector2=offset/gap*top if gap>0.01 else Vector2.ZERO
		var home_hover: bool=a.has("home_x") and a.activity=="Hovering" and p.distance_to(Vector2(a.home_x,a.home_y))<HOME[species].radius+_bodies[a.id].x and target.distance_to(Vector2(a.home_x,a.home_y))<HOME[species].radius
		if home_hover:
			arrive=arrive.limit_length(cfg.scull*0.9)
		var hovering: bool=resting and gap<CHROMIS.hold
		if hovering:
			arrive=Vector2.ZERO
		# Around the obstacle in the way, if any (S5): the same pace, along the way round.
		var way: Vector2=Vector2.ZERO
		_close=0.0
		_leg=Vector2.ZERO
		_escaping=false
		if hovering:
			_forget_around(a)
		else:
			way=_around(a,p,target,band,radii)
		# Reserve all single-file spans before setting out, including straight approaches.
		# A denied excursion chooses a staging destination in open water; it never queues
		# inside the neck. Claims live on the animal so save/restore preserves ownership.
		if not hovering and not startled and not _escaping and not follower:
			if not _reserve_route(a,p,target):
				var staging: Vector2=_staging_target(a,p,target)
				a.tx=staging.x
				a.ty=staging.y
				_forget_around(a)
				target=_aim(a,radii)
				offset=target-p
				gap=offset.length()
				way=_around(a,p,target,band,radii)
				arrive=offset.normalized()*minf(speed,sqrt(2.0*cfg.brake*gap))
		var waiting: bool=false
		if not hovering and not _escaping and gap>NAV.replan and _obstacles.is_empty() and _gives_way(a,p):
			waiting=true
			way=Vector2.ZERO
			arrive=Vector2.ZERO
		if waiting:
			a.nav_wait=1
		else:
			a.erase("nav_wait")
		# A way steeper than its nose can pitch is climbed (or sunk) slowly: no faster than it can
		# scull up the difference, with its forward stroke kept to the level part (_swim `climbing`).
		# (Near an obstacle, within 1.3 x its widened radii, it rises and sinks by sculling only, never
		# by swimming on forward: a climb does not carry it into the obstacle.)
		var climbing: bool=_close>0.0 and (way!=Vector2.ZERO or follower) or gap>40.0 and absf(offset.y)>absf(offset.x)*sin(cfg.pitch)
		if way!=Vector2.ZERO:
			var steep: float=absf(way.y)-absf(way.x)*sin(cfg.pitch)
			if steep>0.0 and not _escaping:
				climbing=true
				_close=1.0
				top=minf(top,cfg.scull/steep)
			arrive=way*(maxf(top,OBSTACLE.escape*cruise) if _escaping else top)
		# Everything else steering adds on top of arriving: rise and fall, spacing, dodging.
		var desired:=Vector2.ZERO
		# A gentle rise and fall while travelling, fading out on approach; no per-frame randomness.
		# (Not while going around an obstacle: the arc is its rise and fall.)
		if a.activity=="Schooling" and not follower and gap>35 and way==Vector2.ZERO:
			var bend: float=sin(state.elapsed*(0.28+float(int(a.id)%5)*0.025)+a.id*1.73)
			desired.y+=bend*speed*cfg.drift*minf(1,gap/100)
		# School members keep their spacing; bodies keep apart across the pool (_avoid).
		if chromis:
			var spacing: float=CHROMIS.spacing
			for other: Dictionary in state.animals:
				if other.id==a.id or other.species!=species:
					continue
				var apart: Vector2=p-Vector2(other.x,other.y)
				var dist: float=apart.length()
				if dist<spacing and dist>0.01:
					var room: Vector2=apart.normalized()*(spacing-dist)*0.16
					# At rest the leader holds its place and the others make room sideways only,
					# so spacing never bobs a resting school up and down (2026-09-26).
					if resting:
						room=Vector2(0.0 if follower==false else room.x,0.0)
					desired+=room
		# Give way smoothly: the steering _avoid() adds is eased over about three ticks (0.3 a
		# tick; 0.5 still let a chromis flip up and down every tick, 2026-09-26), so a meeting reads
		# as one sweeping dodge, not a twitch each tick.
		var change: Vector2=_avoid(a,p,arrive+desired,cruise)-arrive-desired
		var was: Vector2=Vector2(a.get("avoid_x",0.0),a.get("avoid_y",0.0))
		var steer: Vector2=was.lerp(change,0.3)
		a.avoid_x=steer.x
		a.avoid_y=steer.y
		_dodge=maxf(minf(1.0,steer.length()/cruise),_close)
		desired+=steer
		# Nor does it push a body into an obstacle (S5): near one's widened edge the part heading in
		# fades out.
		# (On a route it does not ease out: the route already leads out of the widened edge.)
		desired=_hold_off(p,desired,radii,cruise if way==Vector2.ZERO else 0.0)
		# Soft edges: what steering adds toward a band edge or a side wall eases off over the last
		# `edge` px (arriving already stops at its in-band target).
		desired.y*=clampf(((p.y-band[0]) if desired.y<0 else (band[1]-p.y))/SWIM.edge,0.0,1.0)
		desired.x*=clampf(((p.x-_swim_x.x) if desired.x<0 else (_swim_x.y-p.x))/SWIM.edge,0.0,1.0)
		# (Climbing or sinking near an obstacle it sculls up or down faster than it swims along, so
		# there its way in is held off too: it never sinks onto a rock it is passing over.)
		desired+=_hold_off(p,arrive,radii,0.0,true) if climbing and not _escaping else arrive
		# (S5-fix) And all of it together never carries a body deeper into an obstacle, and eases it
		# back out inside the widened edge, wherever it is going: a dodge round another fish beside a
		# mast had pressed a chromis to a 0.47 overlap along the mast's side.
		if not _escaping:
			desired=_hold_off(p,desired,radii,cruise)
		# Which way to face: a resting fish settled on its spot keeps its facing, a school member
		# settled in its slot faces the way the leader does (so the school turns almost together).
		var face: float=0.0
		if hovering or waiting or home_hover:
			face=a.direction
		elif way!=Vector2.ZERO:
			# On a route round an obstacle it faces along its leg; only a clearly sideways leg turns
			# it round (S5).
			var leg: Vector2=_leg if not _escaping else way
			# (S5-fix: when the leg runs up or down but the way it swims runs clearly sideways, the
			# way: a seahorse on a vertical leg had kept facing away from where it swam, and stalled.)
			face=signf(leg.x) if absf(leg.x)>=0.45 else (signf(way.x) if absf(way.x)>=0.45 else a.direction)
		elif climbing:
			face=signf(offset.x) if absf(offset.x)>0.45*gap else a.direction
		elif follower and gap<40 and _close==0.0:
			# (A school member settled in its slot faces with the leader, unless an obstacle is near.)
			face=lead.direction
		if home_hover:
			desired=desired.limit_length(cfg.scull*0.9)
		var velocity: Vector2=_swim(a,desired,speed,cruise,cfg,delta,a.activity=="Startled",face,climbing)
		var free: Vector2=p+velocity*delta
		# Keep each fish in its own layer (the shoaling push once carried hatchetfish down).
		var lo:=Vector2(_swim_x.x,band[0])
		var hi:=Vector2(_swim_x.y,band[1])
		var next: Vector2=free.clamp(lo,hi)
		if next.distance_to(free)>RELOCATION:
			a.relocated_at=state.elapsed
		# Its centre never enters an obstacle: a step across an edge slides along it (S5).
		var kept: Vector2=_keep_out(p,next,lo,hi,radii)
		if kept!=next:
			velocity=(kept-p)/delta
			next=kept
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


func _body(a: Dictionary) -> Vector2:
	var b: Array=BODY[a.species]
	return Vector2(b[0],b[1])*animal_scale(a)

# Steers `desired` (px/s) so this swimmer's body keeps clear of the others (SEPARATE).
func _avoid(a: Dictionary, p: Vector2, desired: Vector2, speed: float) -> Vector2:
	_dodge=0.0
	# A resting chromis stays put; the others go around it.
	if a.activity=="Resting" and a.species=="green_chromis":
		return desired
	var own: Vector2=_bodies[a.id]
	var v:=Vector2(a.get("vx",0.0),a.get("vy",0.0))
	var push:=Vector2.ZERO
	var margin: float=SEPARATE.margin
	var look: float=SEPARATE.look
	var gain: float=SEPARATE.gain
	# For a chromis no other chromis counts (the school spaces itself).
	for o: Dictionary in (_not_chromis if a.species=="green_chromis" else state.animals):
		# Clownfish sharing their anemone nestle together (plan §3.1); they do not push each other out.
		if o.id==a.id or a.species=="clownfish" and o.species=="clownfish" and o.home==a.home:
			continue
		var mixed: bool=o.species!=a.species
		# (S5-fix: two seahorses keep only SEPARATE.perch apart, enough that their bodies never
		# overlap by a fifth: hitch points on one plant lie closer than the general spacing, and a
		# seahorse kept off its own hitch by its neighbour hovered above it for minutes.)
		var r: Vector2=(own+_bodies[o.id])*0.5*(SEPARATE.perch if a.species=="seahorse" and o.species=="seahorse" else margin*(1.17 if mixed else SEPARATE.same))
		var rel: Vector2=p-Vector2(o.x,o.y)
		var relv: Vector2=v-Vector2(o.get("vx",0.0),o.get("vy",0.0))
		var t: float=clampf(-rel.dot(relv)/maxf(relv.length_squared(),0.0001),0.0,look)
		var ahead: Vector2=rel+relv*t
		var now: float=Vector2(rel.x/r.x,rel.y/r.y).length()
		var q: float=minf(now,Vector2(ahead.x/r.x,ahead.y/r.y).length())
		if q>=1.0:
			continue
		var schooling: bool=a.species=="green_chromis"
		var yields: float=(1.0 if a.id>o.id else 0.0) if schooling==(o.species=="green_chromis") else (1.0 if schooling else 0.0)
		if a.has("nav_wait") and not o.has("nav_wait"):
			yields=1.0
		elif o.has("nav_wait") and not a.has("nav_wait"):
			yields=0.0
		var travelling: bool=Vector2(o.tx-o.x,o.ty-o.y).length()>40.0 and o.activity!="Resting"
		if yields==0.0 and travelling and now>=0.8:
			continue
		# Dodge up or down, away from the other (the upper fish rises; ids break a tie).
		var up: float=signf(rel.y) if absf(rel.y)>1.0 else (1.0 if a.id>o.id else -1.0)
		var side: float=signf(rel.x) if absf(rel.x)>1.0 else 0.0
		var vertical: bool=absf(desired.y)>absf(desired.x)
		# A vertical traveller commits to one passing side for its destination. Changing
		# sides as crossing neighbours pass its nose leaves it sculling in place.
		if vertical and yields>0.0 and a.species=="seahorse":
			if not a.has("nav_dodge_side") or a.tx!=a.get("nav_dodge_tx") or a.ty!=a.get("nav_dodge_ty"):
				a.nav_dodge_side=side if side!=0.0 else a.direction
				a.nav_dodge_tx=a.tx
				a.nav_dodge_ty=a.ty
			side=a.nav_dodge_side
		var dodge: Vector2=Vector2(side if side!=0.0 else (1.0 if a.id>o.id else -1.0),up*0.25) if vertical else Vector2(side*0.5,up)
		push+=dodge.normalized()*speed*gain*(1.0-q)
		_dodge=maxf(_dodge,1.0-q)
		# The younger id holds back as a meeting nears; inside the other's space nobody presses on
		# toward it. What it held back it swims along the other's edge instead, on its dodging side
		# (or, passing above or below, on toward where it was going): it goes round, it does not
		# wait (S5-fix; holding back alone left two fish face to face for minutes).
		# (S5-fix: a swimming chromis gives way to the slower fish, not they to the school: shoved
		# down by a passing school, a clownfish ended up under a ledge and turned round and back.)
		# (A fish waiting at a passage gives way to everyone; one coming out does not wait for it.)
		var holding: float=SEPARATE.close
		if a.has("nav_wait") and not o.has("nav_wait"):
			yields=1.0
		elif o.has("nav_wait") and not a.has("nav_wait"):
			yields=0.0
			holding=0.85
		if now<holding or yields>0.0:
			var n: Vector2=Vector2(rel.x/(r.x*r.x),rel.y/(r.y*r.y)).normalized()
			var toward: float=-desired.dot(n)
			if toward>0.0:
				var k: float=1.0 if now<holding else yields*clampf((1.0-q)*3.0,0.0,1.0)
				var along:=Vector2(-n.y,n.x)
				# (Meeting above or below, it slides off to the side it is already on, ids breaking a
				# tie; never back the way it is heading: that would turn it round.)
				var aside: float=side if side!=0.0 else (1.0 if a.id>o.id else -1.0)
				if vertical and a.species=="seahorse" and signf(along.x)!=aside or (not vertical or a.species!="seahorse") and (absf(along.y)>0.3 and signf(along.y)!=up or absf(along.y)<=0.3 and signf(along.x)!=aside):
					along=-along
				if along.x*desired.x<0.0 and absf(desired.x)>0.45*desired.length():
					along.x=0.0
				desired+=(n+along)*toward*k
	return desired+push


# Natural swimming (2026-09-25): the body turns at a limited rate, through facing the glass
# (heading 0 = facing right, pi = facing left); the nose pitches up or down gently; speed along
# the body follows burst-and-glide strokes (chromis) or smooth rowing (seahorse) against water drag,
# with pectoral braking and, only at low speed, a little sculling that lets the fish settle
# exactly. Returns the screen velocity (px/s); stores heading, pitch, speed, thrust and turn.
func _swim(a: Dictionary, desired: Vector2, cap: float, cruise: float, cfg: Dictionary, delta: float, quick: bool, face: float, climbing: bool = false) -> Vector2:
	var psi: float=a.heading if a.has("heading") else (0.0 if a.direction>0 else PI)
	var theta: float=a.get("pitch",0.0)
	var s: float=a.speed if a.has("speed") else Vector2(a.get("vx",0.0),a.get("vy",0.0)).length()
	var turn: float=a.get("turn",0.0)
	var want: float=desired.length()
	var facing: float=face
	if facing==0.0:
		# (Only for a clear sideways lead: a mostly vertical move keeps the current facing.)
		var now: float=1.0 if cos(psi)>=0.0 else -1.0
		if want>0.5 and (absf(desired.x)>0.45*want or desired.x*now<0.0 and absf(desired.x)>0.15*want):
			facing=signf(desired.x)
		elif absf(cos(psi))<0.3 and absf(turn)>0.01:
			# Mid-turn with nowhere in particular to go: finish the turn.
			facing=-signf(turn)
		else:
			facing=1.0 if cos(psi)>=0.0 else -1.0
	var rate: float=cfg.turn*(SWIM.startle_turn if quick else 1.0)
	turn=move_toward(turn,clampf(((0.0 if facing>0 else PI)-psi)*SWIM.turn_gain,-rate,rate),rate*5.0*delta)
	var turned: float=clampf(psi+turn*delta,0.0,PI)
	turn=(turned-psi)/delta
	psi=turned
	# Headway: less while turning, hardly any while still facing away from the way to go.
	# Headway: what lies ahead of the body (none while still facing away), and some to climb or dive.
	# (Climbing round an obstacle steeper than it can pitch, S5: only the level part; it sculls the rest.)
	var along: float=maxf(0.0,desired.x*cos(psi))+(0.0 if climbing else absf(desired.y)*0.6)
	along=minf(along,cruise*SWIM.startle_speed)
	var full: float=cfg.push*cfg.drag*maxf(cruise,1.0)
	var thrust: float=a.get("thrust",0.0)
	var accel: float
	if cfg.gap>0.0:
		# Burst and glide: stroke hard up to (1+gap) x the wanted speed, coast down to (1-gap) x.
		var bursting: bool=thrust>0.0
		if s<along*(1.0-cfg.gap):
			bursting=true
		elif s>along*(1.0+cfg.gap):
			bursting=false
		accel=cfg.push*cfg.drag*along if bursting and along>0.2 else 0.0
	else:
		# Rowing: steady strokes hold the wanted speed, with a slight surge on each stroke.
		accel=clampf(cfg.drag*along+cfg.respond*(along-s),0.0,cfg.push*cfg.drag*maxf(cap,cruise))
		accel*=1.0+cfg.row*sin(state.elapsed*TAU/cfg.stroke+a.id)
	# A stroke builds up over a moment (SWIM.ramp); gliding starts at once.
	accel=minf(accel,(thrust+SWIM.ramp*delta)*full)
	s=maxf(0.0,s+(accel-cfg.drag*s)*delta)
	if accel==0.0 and s>along*(1.0+cfg.gap)+0.5:
		# Flare the pectorals to brake.
		s=maxf(along,s-cfg.brake*(3.0 if quick else 1.0)*delta)
	var urgent: float=_dodge
	var level: float=maxf(absf(desired.x),0.35*cap+0.5)
	theta=move_toward(theta,clampf(atan2(desired.y,level),-cfg.pitch,cfg.pitch),cfg.pitch_rate*delta)
	var body:=Vector2(cos(psi)*cos(theta),sin(theta))*s
	# Sculling with the pectorals, a few px/s: in any direction only near a standstill; across
	# the body (mostly up or down) also while getting out of another body's way. It never
	# works along the body, so it cannot smooth away the burst-and-glide.
	var slow: float=clampf(1.0-s/(0.5*cruise),0.0,1.0)
	var axis:=Vector2(cos(psi),0.0) if absf(cos(psi))>0.01 else Vector2.ZERO
	var miss: Vector2=desired-body
	var ahead: Vector2=axis*miss.dot(axis)
	var settle: float=slow if want<cfg.scull or climbing and urgent>0.0 else 0.0
	var velocity: Vector2=body+ahead.limit_length(cfg.scull*settle)+(miss-ahead).limit_length(cfg.scull*maxf(urgent,slow))
	a.heading=psi
	a.pitch=theta
	a.speed=s
	a.turn=turn
	a.thrust=clampf(accel/full,0.0,1.0)
	if absf(cos(psi))>0.05:
		a.direction=signf(cos(psi))
	return velocity

# A fixed pseudo-random number in [0, 1) for (a, b): scheduling without drawing from an RNG.
static func _hash01(a: int, b: int) -> float:
	var h: int=((a*73856093)^(b*19349663))&0xFFFFFFF
	h=((h^(h>>13))*1274126177)&0xFFFFFFF
	h=h^(h>>16)
	return float(h&0xFFFF)/65536.0

# The homes a species can take in this scene's current decor, in order: the required slots first
# (the anemone, the required hitch plant), then the others in scene order; for the royal gramma
# the caves of its slots, then the scene's rock spots. Each {kind, slot, i, x, y, capacity}.
func _home_spots(species: String) -> Array:
	var out: Array=[]
	var kind: String=HOME[species].kind
	var decor: Dictionary=state.decor[state.scene]
	for required: bool in [true,false]:
		for s: Dictionary in scene.slots():
			if (s.required!="")!=required:
				continue
			var fx: Dictionary=scene.effects(s.id,decor.get(s.id,""))
			if kind=="anemone" and not fx.anemone.is_empty():
				out.append({"kind":"anemone","slot":s.id,"i":0,"x":fx.anemone.cx,"y":fx.anemone.cy,"capacity":fx.anemone.capacity})
			elif kind=="hitch":
				for i in fx.hitches.size():
					out.append({"kind":"hitch","slot":s.id,"i":i,"x":fx.hitches[i].x,"y":fx.hitches[i].y,"capacity":1})
			elif kind=="shelter":
				for i in fx.shelters.size():
					if "royal_gramma" in fx.shelters[i].use:
						out.append({"kind":"shelter","slot":s.id,"i":i,"x":fx.shelters[i].x,"y":fx.shelters[i].y,"capacity":1})
	if kind=="shelter":
		var rocks: Array[Vector2]=scene.rock_spots()
		for i in rocks.size():
			out.append({"kind":"rock","slot":"","i":i,"x":rocks[i].x,"y":rocks[i].y,"capacity":1})
	# (S5-fix) Only homes an adult can swim to from the main water: a spot in a pocket closed off
	# for its body (shipwreck rock spot 1 with the minimum decor) left the fish trying for it all
	# day. Kept all if none opens onto it.
	var open: Array=out.filter(func(h): return _opens(species,Vector2(h.x,h.y)))
	return open if not open.is_empty() else out

# Whether an adult of the species can reach point p (moved clear of the obstacles and into its
# band as its aim would be) from the main water: a cell of the main water within 2 cells of it.
func _opens(species: String, p: Vector2) -> bool:
	var grid: Array=_grid(species+"/"+str(1.0),species,1.0)
	var part: PackedInt32Array=grid[3]
	var w: int=int(1280.0/NAV.cell)
	var h: int=int(720.0/NAV.cell)
	var half: float=BODY[species][1]*0.5
	var band: Array=[_bands[species][0],minf(_bands[species][1],bed_y(p.x)-half)]
	var radii:=PackedVector2Array()
	for o: Dictionary in _obstacles:
		radii.append(Vector2(o.rx,o.ry)+Vector2(BODY[species][0],BODY[species][1])*0.5*OBSTACLE.body)
	var t: Vector2=_clear_of(Vector2(p.x,clampf(p.y,band[0],band[1])),band,radii,Vector2.INF)
	var gx: int=int(t.x/NAV.cell)
	var gy: int=int(t.y/NAV.cell)
	for y in range(maxi(0,gy-2),mini(h,gy+3)):
		for x in range(maxi(0,gx-2),mini(w,gx+3)):
			if part[y*w+x]==grid[4]:
				return true
	return false

static func _home_key(h: Dictionary) -> String:
	return "%s/%s/%d" % [h.kind,h.slot,h.i]

# The free home nearest the parent's (or the first home), no randomness. Past every capacity
# (never within the caps, which fit the homes) the first home is shared.
func _free_home(species: String, parent: int) -> Dictionary:
	var spots: Array=_homes[species]
	var from:=Vector2(spots[0].x,spots[0].y)
	for o: Dictionary in state.animals:
		if o.id==parent and o.species==species and o.has("home"):
			from=Vector2(o.home_x,o.home_y)
	return _nearest_free(species,from)

# The free home nearest `from` (a home is taken up to its capacity), else the first home.
func _nearest_free(species: String, from: Vector2) -> Dictionary:
	var spots: Array=_homes[species]
	var used: Dictionary={}
	for o: Dictionary in state.animals:
		if o.species!=species or not o.has("home"):
			continue
		var key: String=_home_key(o.home)
		used[key]=used.get(key,0)+1
	var best: Dictionary=spots[0]
	var gap: float=INF
	for s: Dictionary in spots:
		var d: float=from.distance_to(Vector2(s.x,s.y))
		if used.get(_home_key(s),0)<s.capacity and d<gap:
			best=s
			gap=d
	return best

# A fixed spot of its own beside the home (by id, no draw), inside the band and the x bounds and
# with an adult body clear of the bed.
func _near_home(species: String, home: Dictionary, id: int) -> Vector2:
	var r: float=HOME[species].radius*0.5
	var x: float=clampf(home.x+(_hash01(id,1)*2.0-1.0)*r,_roam_x.x,_roam_x.y)
	var y: float=home.y+(_hash01(id,2)*2.0-1.0)*r*0.6
	return Vector2(x,_in_water(species,x,y))

# Obstacle helpers (S5). The radii fish a keeps its centre out of each obstacle (in _obstacles
# order) when aiming and steering: widened by OBSTACLE.body x its half body, or only by
# OBSTACLE.pad where its own home lies inside that (a gramma at its cave, a seahorse on the cave
# rock's hitch: there only its centre keeps out). a = {} (a new fish being placed) keeps `pad` px.
func _radii_of(a: Dictionary) -> PackedVector2Array:
	var out:=PackedVector2Array()
	out.resize(_obstacles.size())
	var half:=Vector2.ZERO
	if not a.is_empty():
		half=(_bodies[a.id] if _bodies.has(a.id) else _body(a))*0.5*OBSTACLE.body
	for i in _obstacles.size():
		var o: Dictionary=_obstacles[i]
		var r:=Vector2(o.rx+half.x,o.ry+half.y)
		if a.is_empty() or a.has("home_x") and Vector2((a.home_x-o.cx)/r.x,(a.home_y-o.cy)/r.y).length_squared()<1.0:
			r=Vector2(o.rx+OBSTACLE.pad,o.ry+OBSTACLE.pad)
		out[i]=r
	return out

# t moved out of every obstacle (radii): to the edge straight out from the centre, or sideways
# when that would leave the band [top, bottom]; kept in the band and the swimming width. Up to three
# rounds for obstacles that touch; if it is then still inside one's widened edge it stays there,
# and if inside the obstacle itself, `fallback` (a Vector2.INF fallback keeps it: a fish's route
# then ends as near as it gets, _navigate).
func _clear_of(t: Vector2, band: Array, radii: PackedVector2Array, fallback: Vector2) -> Vector2:
	# (Three rounds straight out; then, for a spot squeezed between two, three rounds straight up
	# or down, the nearer way that stays in the band.)
	for k in 6:
		var moved: bool=false
		for i in _obstacles.size():
			var o: Dictionary=_obstacles[i]
			var r: Vector2=radii[i]
			var n:=Vector2((t.x-o.cx)/r.x,(t.y-o.cy)/r.y)
			var q: float=n.length()
			if q>=1.0:
				continue
			moved=true
			var out: Vector2
			if k<3:
				var dir: Vector2=n/q if q>0.0001 else Vector2(0.0,-1.0)
				out=Vector2(o.cx+dir.x*r.x*1.03,o.cy+dir.y*r.y*1.03)
				if out.y<band[0] or out.y>band[1]:
					out=Vector2(o.cx+(1.0 if t.x>=o.cx else -1.0)*r.x*sqrt(maxf(0.0,1.0-n.y*n.y))*1.03,t.y)
			else:
				var half: float=r.y*sqrt(maxf(0.0,1.0-n.x*n.x))*1.03
				var up: float=o.cy-half
				var down: float=o.cy+half
				out=Vector2(t.x,up if up>=band[0] and (t.y-up<=down-t.y or down>band[1]) else down)
			t=Vector2(clampf(out.x,_swim_x.x,_swim_x.y),clampf(out.y,band[0],band[1]))
		if not moved:
			return t
	for o: Dictionary in _obstacles:
		if fallback!=Vector2.INF and Vector2((t.x-o.cx)/(o.rx+OBSTACLE.pad),(t.y-o.cy)/(o.ry+OBSTACLE.pad)).length_squared()<1.0:
			return fallback
	return t

# A new fish's spot (spawn, birth, arrival, the opening school) kept `pad` px clear of every
# obstacle, in its band above the bed.
func _clear_spot(species: String, p: Vector2) -> Vector2:
	var band: Array=[_bands[species][0],minf(_bands[species][1],bed_y(p.x)-BODY[species][1]*0.5)]
	return _clear_of(p,band,_radii_of({}),p)

# Where fish a aims this tick: its target, in its band (above the sand there, its body clear of it)
# and clear of the obstacles (_radii_of) as far as it can be. (a.tx/a.ty are left as chosen.)
func _aim(a: Dictionary, radii: PackedVector2Array = PackedVector2Array()) -> Vector2:
	if radii.is_empty():
		radii=_radii_of(a)
	var band: Array=[_bands[a.species][0],minf(_bands[a.species][1],bed_y(a.tx)-(_bodies[a.id] if _bodies.has(a.id) else _body(a)).y*0.5)]
	return _clear_of(Vector2(a.tx,clampf(a.ty,band[0],band[1])),band,radii,Vector2.INF)

# Roaming destinations belong to the main water even after the single-file spans are
# removed. A clear spot in a pocket behind a neck is not a useful place to roam.
# Derived cache only: recomputed identically after restore; no random draws.
func _open_target(a: Dictionary, target: Vector2) -> Vector2:
	var cls: String=a.species+"/"+str(animal_scale(a))
	var grid: Array=_grid(cls,a.species,animal_scale(a))
	var part: PackedInt32Array=grid[6]
	var main: int=grid[7]
	var lanes: PackedInt32Array=_grid("traffic","clownfish",1.0)[5]
	var w: int=int(1280.0/NAV.cell)
	var cell: int=clampi(int(target.y/NAV.cell),0,71)*w+clampi(int(target.x/NAV.cell),0,w-1)
	if part[cell]==main and lanes[cell]<0:
		return target
	var key: Array=[cls,target.x,target.y]
	if _open_targets.has(key):
		return _open_targets[key]
	var best: Vector2=target
	var distance: float=INF
	for i in part.size():
		if part[i]!=main or lanes[i]>=0:
			continue
		var spot: Vector2=_centre(i,w)
		var d: float=target.distance_squared_to(spot)
		if d<distance:
			distance=d
			best=spot
	_open_targets[key]=best
	return best

# v without the part that heads into an obstacle, over the last `hold` of its widened radii (radii)
# and inside them; inside them it also eases out, up to `out` x cruise at the obstacle's own edge.
func _hold_off(p: Vector2, v: Vector2, radii: PackedVector2Array, cruise: float, ahead: bool = false) -> Vector2:
	for i in _obstacles.size():
		var o: Dictionary=_obstacles[i]
		# (Not beside its own home, where only its centre keeps out: a gramma at its cave.)
		if radii[i].x<=o.rx+OBSTACLE.pad+0.001:
			continue
		var r: Vector2=radii[i]*(1.0+OBSTACLE.hold)
		var P:=Vector2((p.x-o.cx)/r.x,(p.y-o.cy)/r.y)
		var q: float=P.length()
		if q>=1.0 or q<0.0001:
			continue
		var n:=Vector2(P.x/r.x,P.y/r.y).normalized()
		var into: float=v.dot(n)
		# (S5-fix, `ahead`: for the climb along its way, only a way that would take it inside the
		# widened edge within OBSTACLE.ahead s is held off; one that passes the edge, as a route round
		# the obstacle does, is left alone: holding that off too had a clownfish creeping round a
		# rock's tip at 1 px/s.)
		var at: Vector2=p+v*OBSTACLE.ahead
		if into<0.0 and (not ahead or Vector2((at.x-o.cx)/radii[i].x,(at.y-o.cy)/radii[i].y).length_squared()<1.0):
			v-=n*into*clampf((1.0-q)/(1.0-1.0/(1.0+OBSTACLE.hold)),0.0,1.0)
		var inner: float=q*(1.0+OBSTACLE.hold)
		if inner<1.0:
			v+=n*OBSTACLE.out*cruise*(1.0-inner)
	return v

# Whole-route claims use one shared geometry, not species-dependent lane labels.
# Claims are acquired atomically in the deterministic animal update order, released
# after arrival or a destination change. School members travel under the leader's claim.
func _reserve_route(a: Dictionary, p: Vector2, target: Vector2) -> bool:
	if _obstacles.is_empty():
		return true
	var lane: PackedInt32Array=_grid("traffic","clownfish",1.0)[5]
	var same: bool=a.has("pass_tx") and target.distance_to(Vector2(a.pass_tx,a.pass_ty))<1.0
	if same and a.get("pass_route",false)==a.has("nav_tx") and (not a.has("nav_tx") or a.get("pass_from_x",p.x)==a.nav_x and a.get("pass_from_y",p.y)==a.nav_y) and p.distance_to(target)>NAV.replan:
		return true
	a.erase("pass_claims")
	a.erase("pass_tx")
	a.erase("pass_ty")
	if p.distance_to(target)<=NAV.replan:
		return true
	var route: PackedVector2Array=_route(a) if a.has("nav_tx") else PackedVector2Array([p,target])
	var claims: Array[int]=[]
	for j in range(1,route.size()):
		var steps: int=maxi(1,int(ceil(route[j-1].distance_to(route[j])/NAV.cell)))
		for k in range(steps+1):
			var label: int=_lane_at(lane,route[j-1].lerp(route[j],float(k)/steps))
			if label>=0 and not claims.has(label):
				claims.append(label)
	for o: Dictionary in state.animals:
		if o.id==a.id or a.species=="green_chromis" and o.species=="green_chromis" or a.species=="clownfish" and o.species=="clownfish" and a.home==o.home:
			continue
		var at:=Vector2(o.x,o.y)
		# Expired claims must not block another fish earlier in the update order.
		if not o.has("pass_tx") or Vector2(o.tx,o.ty).distance_to(Vector2(o.pass_tx,o.pass_ty))>NAV.replan or at.distance_to(Vector2(o.pass_tx,o.pass_ty))<=NAV.replan:
			continue
		for label: int in o.get("pass_claims",[]):
			if claims.has(label):
				return false
	a.pass_route=a.has("nav_tx")
	a.pass_claims=claims
	a.pass_tx=target.x
	a.pass_ty=target.y
	a.pass_from_x=a.get("nav_x",p.x)
	a.pass_from_y=a.get("nav_y",p.y)
	return true

# Keep swimming in the direction of the excursion while the passage is occupied.
# Prefer a visible open-water spot away from the passage; if none exists, settle nearby.
func _staging_target(a: Dictionary, p: Vector2, target: Vector2) -> Vector2:
	var grid: Array=_grid(a.species+"/"+str(animal_scale(a)),a.species,animal_scale(a))
	var parts: PackedInt32Array=grid[6]
	var lane: PackedInt32Array=_grid("traffic","clownfish",1.0)[5]
	var radii: PackedVector2Array=_radii_of(a)
	var forward: Vector2=(target-p).normalized()
	var preferred: Vector2=p+forward*100.0
	var best: Vector2=p
	var score: float=INF
	var w: int=int(1280.0/NAV.cell)
	for i in parts.size():
		if parts[i]!=grid[7] or lane[i]>=0:
			continue
		var spot: Vector2=_centre(i,w)
		if p.distance_squared_to(spot)>160.0*160.0 or (spot-p).dot(forward)<0.0:
			continue
		var d: float=spot.distance_squared_to(preferred)
		if d<score and _blocker(p,spot,radii,-1)<0:
			best=spot
			score=d
	return best

func _gives_way(a: Dictionary, p: Vector2) -> bool:
	if a.get("nav_give",-1.0)>state.elapsed:
		return true
	if not a.has("nav_ct") or p.distance_to(Vector2(a.nav_cx,a.nav_cy))>NAV.moved:
		a.nav_cx=p.x
		a.nav_cy=p.y
		a.nav_ct=state.elapsed
		return false
	if state.elapsed-a.nav_ct<NAV.patience:
		return false
	var own: Vector2=_bodies[a.id]
	var schooling: bool=a.species=="green_chromis"
	var lane: PackedInt32Array=_grid(a.species+"/"+str(animal_scale(a)),a.species,animal_scale(a))[5]
	var mine: int=_lane_at(lane,p)
	for o: Dictionary in state.animals:
		if o.id==a.id or schooling and o.species=="green_chromis":
			continue
		var other: bool=o.species=="green_chromis"
		var yields: bool=(a.id>o.id) if schooling==other else schooling
		# (Both in one passage: the later comer gives way, and backs out the way it came.)
		if mine>=0 and _lane_at(lane,Vector2(o.x,o.y))==mine and a.has("nav_lane_t") and o.has("nav_lane_t") and a.nav_lane_t!=o.nav_lane_t:
			yields=a.nav_lane_t>o.nav_lane_t
		if not yields:
			continue
		var r: Vector2=(own+_bodies[o.id])*0.5*SEPARATE.margin*1.3
		if Vector2((p.x-o.x)/r.x,(p.y-o.y)/r.y).length_squared()<1.0:
			a.nav_give=state.elapsed+NAV.give
			a.nav_ct=state.elapsed
			return true
	return false

func _lane_at(lane: PackedInt32Array, p: Vector2) -> int:
	var w: int=int(1280.0/NAV.cell)
	var gx: int=int(p.x/NAV.cell)
	var gy: int=int(p.y/NAV.cell)
	if gx<0 or gy<0 or gx>=w or gy>=int(720.0/NAV.cell):
		return -1
	return lane[gy*w+gx]

func _forget_around(a: Dictionary) -> void:
	for key: String in ["nav_x","nav_y","nav_tx","nav_ty","nav_k","nav_f","nav_vx","nav_vy"]:
		a.erase(key)

# The nearest obstacle (index, or -1) the straight line p -> t runs into: the line passes inside
# its widened ellipse (radii; from inside one, deeper in). `skip` is left out.
func _blocker(p: Vector2, t: Vector2, radii: PackedVector2Array, skip: int) -> int:
	var way: Vector2=t-p
	var length: float=way.length()
	var first: int=-1
	var nearest: float=INF
	for i in _obstacles.size():
		if i==skip:
			continue
		var o: Dictionary=_obstacles[i]
		var r: Vector2=radii[i]
		# (Quick reject: the line's box misses the ellipse's box.)
		if minf(p.x,t.x)>o.cx+r.x or maxf(p.x,t.x)<o.cx-r.x or minf(p.y,t.y)>o.cy+r.y or maxf(p.y,t.y)<o.cy-r.y:
			continue
		var P:=Vector2((p.x-o.cx)/r.x,(p.y-o.cy)/r.y)
		var d:=Vector2(way.x/r.x,way.y/r.y)
		var s: float=clampf(-P.dot(d)/maxf(d.length_squared(),1.0e-12),0.0,1.0)
		if (P+d*s).length()>=minf(1.0,P.length())-0.001:
			# (From inside the widened edge a line may run level or out, but never across the
			# obstacle itself.)
			if P.length()>=1.0:
				continue
			var R0:=Vector2((p.x-o.cx)/o.rx,(p.y-o.cy)/o.ry)
			var D:=Vector2(way.x/o.rx,way.y/o.ry)
			var u: float=clampf(-R0.dot(D)/maxf(D.length_squared(),1.0e-12),0.0,1.0)
			if R0.length_squared()<1.0 or (R0+D*u).length()>=1.0:
				continue
			s=u
		if length*s<nearest:
			nearest=length*s
			first=i
	return first

# The way (a unit vector) fish a at p swims toward t when an obstacle is in the straight way, or
# ZERO when none is (see OBSTACLE, NAV). Sets _close and _escaping.
func _around(a: Dictionary, p: Vector2, t: Vector2, band: Array, radii: PackedVector2Array) -> Vector2:
	var close: float=INF
	for i in _obstacles.size():
		var o: Dictionary=_obstacles[i]
		var raw:=Vector2((p.x-o.cx)/o.rx,(p.y-o.cy)/o.ry)
		if raw.length_squared()<1.0:
			# Decor set down over it: straight out the short way, up rather than into the sand.
			_forget_around(a)
			_close=1.0
			_escaping=true
			var out:=Vector2(raw.x/o.rx,raw.y/o.ry) if raw.length_squared()>0.000001 else Vector2(0.0,-1.0)
			if out.y>0.0 and o.cy+o.ry>band[1] or out.y<0.0 and o.cy-o.ry<band[0]:
				out.y=-out.y
			return out.normalized()
		close=minf(close,Vector2((p.x-o.cx)/radii[i].x,(p.y-o.cy)/radii[i].y).length())
	_close=clampf((1.3-close)/0.5,0.0,1.0)
	var travel: PackedVector2Array=radii.duplicate()
	var half: Vector2=_body(a)*0.5+Vector2.ONE*NAV.cell
	for i in _obstacles.size():
		var o: Dictionary=_obstacles[i]
		if travel[i].x>o.rx+OBSTACLE.pad+0.001:
			travel[i]=Vector2(o.rx+half.x,o.ry+half.y)
	# Route clearance governs both the decision to detour and visibility around corners.
	if p.distance_to(t)<NAV.replan or not a.has("nav_tx") and _blocker(p,t,travel,-1)<0:
		_forget_around(a)
		return Vector2.ZERO
	var to: Vector2=_navigate(a,p,t,travel)
	# (S5-fix) A route that ends where it is (nothing nearer its aim to reach) is no route: it hovers.
	if p.distance_to(Vector2(a.nav_tx,a.nav_ty))<NAV.replan:
		_forget_around(a)
		return Vector2.ZERO
	return (to-p).normalized() if p.distance_squared_to(to)>0.0001 else Vector2.ZERO

# The point fish a at p steers at on its route to t: the furthest point along the route it can see
# (the straight line to it clear of every widened obstacle), found by walking on from the last one
# and halving the next leg, so it slides smoothly round each obstacle. The route is planned from
# where the fish was when its aim last moved more than `replan` px (nav_x/nav_y to nav_tx/nav_ty,
# saved, so a restored world plans the same route), or again from where it is when it has been
# pushed off the route; nav_k is the leg it is on. A route that cannot
# reach t (no way through for its body) ends as near as it gets, and the fish takes that end as its
# target.
func _navigate(a: Dictionary, p: Vector2, t: Vector2, radii: PackedVector2Array) -> Vector2:
	if not a.has("nav_tx") or t.distance_to(Vector2(a.nav_tx,a.nav_ty))>NAV.replan:
		a.nav_x=p.x
		a.nav_y=p.y
		a.nav_tx=t.x
		a.nav_ty=t.y
		a.nav_k=0
		a.nav_f=0
		a.erase("nav_vx")
		a.erase("nav_vy")
	var route: PackedVector2Array=_route(a)
	# Pushed off its route (another fish making it give way) so that it no longer sees the end of
	# its leg: it plans again from here, once it is `replan` px from where it planned last.
	var leg: int=clampi(int(a.nav_k),0,route.size()-2)
	if _blocker(p,route[leg+1],radii,-1)>=0 and p.distance_to(Vector2(a.nav_x,a.nav_y))>NAV.replan:
		# (S5-fix: by way of the corner it was making for, so it keeps going round the same side;
		# planned afresh it had switched sides and turned round and back.)
		var via: Vector2=route[leg+1]
		var forward: float=a.direction
		var found: bool=false
		for j in range(leg+1,route.size()):
			if (route[j].x-p.x)*forward>=0.0 and _blocker(p,route[j],radii,-1)<0:
				via=route[j]
				found=true
				break
		# Keep the route's side and make room vertically before considering a back-leg.
		if not found:
			var lift:=Vector2(p.x,via.y)
			if _blocker(p,lift,radii,-1)<0:
				_leg=Vector2(0.0,signf(lift.y-p.y))
				return lift
		a.nav_x=p.x
		a.nav_y=p.y
		a.nav_k=0
		a.nav_f=0
		if via.distance_to(Vector2(a.nav_tx,a.nav_ty))>1.0:
			a.nav_vx=via.x
			a.nav_vy=via.y
		route=_route(a)
	var end: Vector2=route[route.size()-1]
	if end.distance_to(Vector2(a.nav_tx,a.nav_ty))>1.0:
		# Out of reach: settle for the end of the route.
		a.tx=end.x
		a.ty=end.y
		a.nav_tx=end.x
		a.nav_ty=end.y
	# Always at least the end of its leg; on along the next legs as far as it sees.
	# (At the end of its leg it goes on to the next even if its view is cut: the route was planned
	# for its size, the corner it cannot see round is one it is already at.)
	var k: int=clampi(int(a.nav_k),0,route.size()-2)
	while k+2<route.size() and (_blocker(p,route[k+2],radii,-1)<0 or p.distance_to(route[k+1])<NAV.cell*0.5):
		k+=1
	a.nav_k=k
	if k+2>=route.size():
		# (On the last leg, the way it actually swims to the end: having seen past a corner it may
		# cut straight across; the last leg itself had run straight down and kept a seahorse facing
		# away from where it swam, so it never swam on, S5-fix.)
		_leg=(route[k+1]-p).normalized() if p.distance_squared_to(route[k+1])>1.0 else (route[k+1]-route[k]).normalized()
		return route[k+1]
	var lo: float=0.0
	var hi: float=1.0
	for n in 4:
		var mid: float=(lo+hi)*0.5
		if _blocker(p,route[k+1].lerp(route[k+2],mid),radii,-1)<0:
			lo=mid
		else:
			hi=mid
	# (S5-fix: it faces along the furthest leg it has steered along on this route, never back to an
	# earlier one: as the view round a corner opened and closed the facing had switched between the
	# two legs, turning it round and back. nav_f is saved; a new or re-planned route starts at 0.)
	var f: int=maxi(int(a.get("nav_f",0)),k+1 if lo>0.0 else k)
	a.nav_f=f
	_leg=(route[f+1]-route[f]).normalized()
	var to: Vector2=route[k+1].lerp(route[k+2],lo)
	# (S5-fix: a leg of a step or two, the last nudge into a target, does not set its facing; the
	# way it swims does: a 7 px leg back had turned a chromis round eight times.)
	if lo>0.0 and route[k+1].distance_to(route[k+2])<2.0*NAV.cell and p.distance_squared_to(to)>1.0:
		_leg=(to-p).normalized()
	return to

# The planned route of fish a (from nav_x/nav_y to nav_tx/nav_ty, for its species and size), kept
# for as long as those stay the same (never saved: planned again the same after a restore).
func _route_class(a: Dictionary) -> String:
	var cls: String=a.species+"/"+str(animal_scale(a))
	if a.has("home_x"):
		cls+="/"+str(a.home_x)+"/"+str(a.home_y)
	return cls

func _route(a: Dictionary) -> PackedVector2Array:
	var cls: String=_route_class(a)
	var key: Array=[a.nav_x,a.nav_y,a.nav_tx,a.nav_ty,cls,a.get("nav_vx"),a.get("nav_vy")]
	var kept: Dictionary=_routes.get(a.id,{})
	if kept.get("key",[])!=key:
		var from:=Vector2(a.nav_x,a.nav_y)
		var to:=Vector2(a.nav_tx,a.nav_ty)
		var route: PackedVector2Array
		if a.has("nav_vx"):
			# (Re-planned by way of a corner, S5-fix: here to the corner, then on from it.)
			var via:=Vector2(a.nav_vx,a.nav_vy)
			route=_plan(cls,a.species,animal_scale(a),from,via)
			if route[route.size()-1].distance_to(via)<=1.0:
				var rest: PackedVector2Array=_plan(cls,a.species,animal_scale(a),via,to)
				route.append_array(rest.slice(1))
		else:
			route=_plan(cls,a.species,animal_scale(a),from,to)
		kept={"key":key,"route":route}
		_routes[a.id]=kept
	return kept.route

# The water a fish of this species and size can use, on a grid of NAV.cell px: 0 open, 1 within an
# obstacle widened by OBSTACLE.body x its half body (a route only leaves such an edge, never goes
# deeper into it, except to end there), 2 no water for it (within `pad` of an obstacle, outside its
# band or the swimming width, the sand: only crossed on the way out of such a spot), 3 an obstacle. The second array holds how deep in the widened edge a cell
# lies (the least normalised distance, below 1). Built when first needed, for the current decor.
func _grid(cls: String, species: String, scale: float) -> Array:
	if _grids.has(cls):
		return _grids[cls]
	var c: float=NAV.cell
	var w: int=int(1280.0/c)
	var h: int=int(720.0/c)
	var body: Vector2=Vector2(BODY[species][0],BODY[species][1])*scale
	var home_fields: PackedStringArray=cls.split("/")
	var home: Vector2=Vector2(float(home_fields[2]),float(home_fields[3])) if home_fields.size()==4 else Vector2.INF
	var traffic: bool=cls=="traffic"
	if traffic:
		body=Vector2(69.0,61.0)
	var half: Vector2=body*0.5+Vector2.ONE*NAV.cell
	var g:=PackedByteArray()
	g.resize(w*h)
	var depth:=PackedFloat32Array()
	depth.resize(w*h)
	depth.fill(1.0)
	for gx in w:
		var x: float=(gx+0.5)*c
		var top: float=_bands[species][0]
		var bottom: float=bed_y(x)-body.y*0.5 if traffic else minf(_bands[species][1],bed_y(x)-body.y*0.5)
		var near: Array=_obstacles.filter(func(o): return absf(x-o.cx)<o.rx+half.x)
		for gy in h:
			var y: float=(gy+0.5)*c
			var v: int=2 if x<_swim_x.x or x>_swim_x.y or y<top or y>bottom else 0
			for o: Dictionary in near:
				var dx: float=(x-o.cx)/o.rx
				var dy: float=(y-o.cy)/o.ry
				if dx*dx+dy*dy<1.0:
					v=3
					break
				dx=(x-o.cx)/(o.rx+OBSTACLE.pad)
				dy=(y-o.cy)/(o.ry+OBSTACLE.pad)
				if dx*dx+dy*dy<1.0:
					v=2
					continue
				var at_home: bool=home!=Vector2.INF and ((home-Vector2(o.cx,o.cy))/(Vector2(o.rx,o.ry)+body*0.5*OBSTACLE.body)).length_squared()<1.0
				var edge: Vector2=Vector2.ONE*OBSTACLE.pad if at_home else half
				dx=(x-o.cx)/(o.rx+edge.x)
				dy=(y-o.cy)/(o.ry+edge.y)
				if dx*dx+dy*dy<1.0 and v<2:
					v=1
					depth[gy*w+gx]=minf(depth[gy*w+gx],sqrt(dx*dx+dy*dy))
			g[gy*w+gx]=v
	# (S5-fix) How much room each open cell has: its distance in px to the nearest cell that is
	# not open water (two-pass chamfer), so routes keep to the middle of the water (NAV.room)...
	var room:=PackedFloat32Array()
	room.resize(w*h)
	for i in w*h:
		room[i]=0.0 if g[i]!=0 else INF
	for gy in h:
		for gx in w:
			var i: int=gy*w+gx
			if room[i]==0.0:
				continue
			var best: float=room[i]
			if gx>0: best=minf(best,room[i-1]+c)
			if gy>0:
				best=minf(best,room[i-w]+c)
				if gx>0: best=minf(best,room[i-w-1]+c*1.41421356)
				if gx<w-1: best=minf(best,room[i-w+1]+c*1.41421356)
			room[i]=best
	for gy in range(h-1,-1,-1):
		for gx in range(w-1,-1,-1):
			var i: int=gy*w+gx
			if room[i]==0.0:
				continue
			var best: float=room[i]
			if gx<w-1: best=minf(best,room[i+1]+c)
			if gy<h-1:
				best=minf(best,room[i+w]+c)
				if gx<w-1: best=minf(best,room[i+w+1]+c*1.41421356)
				if gx>0: best=minf(best,room[i+w-1]+c*1.41421356)
			room[i]=best
	# ...and which piece of open water each open cell belongs to (8 neighbours, no corner cutting),
	# the largest piece being the main water (a home only counts if it opens onto it, _home_spots).
	var part:=PackedInt32Array()
	part.resize(w*h)
	part.fill(-1)
	var sizes: Array[int]=[]
	for i in w*h:
		if g[i]!=0 or part[i]>=0:
			continue
		var label: int=sizes.size()
		var stack: Array[int]=[i]
		part[i]=label
		var n: int=0
		while not stack.is_empty():
			var cell: int=stack.pop_back()
			n+=1
			var cx: int=cell%w
			var cy: int=cell/w
			for d in 8:
				var nx: int=cx+STEP_X[d]
				var ny: int=cy+STEP_Y[d]
				if nx<0 or ny<0 or nx>=w or ny>=h:
					continue
				var nb: int=ny*w+nx
				if g[nb]!=0 or part[nb]>=0:
					continue
				if STEP_X[d]!=0 and STEP_Y[d]!=0 and (g[cy*w+nx]!=0 or g[ny*w+cx]!=0):
					continue
				part[nb]=label
				stack.append(nb)
		sizes.append(n)
	var main: int=-1
	for k in sizes.size():
		if main<0 or sizes[k]>sizes[main]:
			main=k
	# (S5-fix) Passages too narrow for two fish of this size to pass: open cells whose open span
	# across (left-right or up-down, to the first cell that is not open water) is under NAV.lane x
	# the body's length or height; labelled by connected piece (-1 elsewhere).
	var lane:=PackedInt32Array()
	lane.resize(w*h)
	lane.fill(-1)
	var narrow:=PackedByteArray()
	narrow.resize(w*h)
	# (The same spans for every species, from the largest body of the cast: a passage is one fish
	# at a time when two of the largest could not pass in it.)
	var big:=Vector2.ZERO
	for sp: String in BODY:
		big=Vector2(maxf(big.x,BODY[sp][0]),maxf(big.y,BODY[sp][1]))
	var span_x: float=NAV.lane*big.x
	var span_y: float=NAV.lane*big.y
	var reach_x: int=int(ceil(span_x/c))
	var reach_y: int=int(ceil(span_y/c))
	for gy in h:
		for gx in w:
			var i: int=gy*w+gx
			if g[i]!=0:
				continue
			if traffic and room[i]<maxf(big.x,big.y)*0.5*SEPARATE.margin:
				narrow[i]=1
				continue
			var l: int=0
			while l<reach_x and gx-l-1>=0 and g[i-l-1]==0: l+=1
			var r: int=0
			while r<reach_x and gx+r+1<w and g[i+r+1]==0: r+=1
			if l<reach_x and r<reach_x and gx-l-1>=0 and gx+r+1<w and (l+r+1)*c<span_x:
				narrow[i]=1
				continue
			var u: int=0
			while u<reach_y and gy-u-1>=0 and g[i-(u+1)*w]==0: u+=1
			var dn: int=0
			while dn<reach_y and gy+dn+1<h and g[i+(dn+1)*w]==0: dn+=1
			if u<reach_y and dn<reach_y and gy-u-1>=0 and gy+dn+1<h and (u+dn+1)*c<span_y:
				narrow[i]=1
	var lanes: int=0
	for i in w*h:
		if narrow[i]==0 or lane[i]>=0:
			continue
		var stack: Array[int]=[i]
		lane[i]=lanes
		while not stack.is_empty():
			var cell: int=stack.pop_back()
			var cx: int=cell%w
			var cy: int=cell/w
			for d in 8:
				var nx: int=cx+STEP_X[d]
				var ny: int=cy+STEP_Y[d]
				if nx<0 or ny<0 or nx>=w or ny>=h:
					continue
				var nb: int=ny*w+nx
				if narrow[nb]==1 and lane[nb]<0:
					lane[nb]=lanes
					stack.append(nb)
		lanes+=1
	if traffic:
		var original: PackedInt32Array=lane.duplicate()
		for i in w*h:
			if original[i]<0:
				continue
			for dy in range(-3,4):
				for dx in range(-3,4):
					var x: int=i%w+dx
					var y: int=i/w+dy
					if x>=0 and x<w and y>=0 and y<h and g[y*w+x]!=3 and lane[y*w+x]<0:
						lane[y*w+x]=original[i]
	# Connected open water without narrow spans. Require room to turn at a destination;
	# these are destinations, not a restriction on routes to an owner's home.
	var open_part:=PackedInt32Array()
	open_part.resize(w*h)
	open_part.fill(-1)
	var open_sizes: Array[int]=[]
	for i in w*h:
		if g[i]!=0 or lane[i]>=0 or room[i]<body.y*0.5 or open_part[i]>=0:
			continue
		var label: int=open_sizes.size()
		var stack: Array[int]=[i]
		open_part[i]=label
		var n: int=0
		while not stack.is_empty():
			var cell: int=stack.pop_back()
			n+=1
			var cx: int=cell%w
			var cy: int=cell/w
			for d in 4:
				var nx: int=cx+[-1,1,0,0][d]
				var ny: int=cy+[0,0,-1,1][d]
				if nx<0 or ny<0 or nx>=w or ny>=h:
					continue
				var nb: int=ny*w+nx
				if g[nb]!=0 or lane[nb]>=0 or room[nb]<body.y*0.5 or open_part[nb]>=0:
					continue
				open_part[nb]=label
				stack.append(nb)
		open_sizes.append(n)
	var open_main: int=-1
	for k in open_sizes.size():
		if open_main<0 or open_sizes[k]>open_sizes[open_main]:
			open_main=k
	_open_targets.clear()
	_grids[cls]=[g,depth,room,part,main,lane,open_part,open_main]
	return _grids[cls]

# A route from `from` to `to` over the grid (A*, 8 neighbours, no corner cutting; ties by cell
# order, so always the same), pulled straight between cells that see each other. Through open
# water, or out of a widened edge (never deeper into one), and into the one its end lies in. Ends at
# `to`, or when `to` cannot be reached, at the reachable cell nearest it.
func _plan(cls: String, species: String, scale: float, from: Vector2, to: Vector2) -> PackedVector2Array:
	var grid: Array=_grid(cls,species,scale)
	var g: PackedByteArray=grid[0]
	var depth: PackedFloat32Array=grid[1]
	var room: PackedFloat32Array=grid[2]
	var need: float=NAV.room*BODY[species][1]*scale
	var c: float=NAV.cell
	var w: int=int(1280.0/c)
	var h: int=int(720.0/c)
	var start: int=clampi(int(from.y/c),0,h-1)*w+clampi(int(from.x/c),0,w-1)
	var goal: int=clampi(int(to.y/c),0,h-1)*w+clampi(int(to.x/c),0,w-1)
	var cost:=PackedFloat32Array()
	cost.resize(w*h)
	cost.fill(INF)
	var prev:=PackedInt32Array()
	prev.resize(w*h)
	prev.fill(-1)
	var done:=PackedByteArray()
	done.resize(w*h)
	var heap_n: Array=[]
	var heap_k: Array=[]
	var gx: int=goal%w
	var gy: int=goal/w
	cost[start]=0.0
	_push(heap_n,heap_k,start,_octile(start%w-gx,start/w-gy))
	var best: int=start
	var best_h: float=INF
	while not heap_n.is_empty():
		var cell: int=_pop(heap_n,heap_k)
		if done[cell]==1:
			continue
		done[cell]=1
		var cx: int=cell%w
		var cy: int=cell/w
		var left: float=_octile(cx-gx,cy-gy)
		if left<best_h:
			best=cell
			best_h=left
		if cell==goal:
			break
		for d in 8:
			var dx: int=STEP_X[d]
			var dy: int=STEP_Y[d]
			var nx: int=cx+dx
			var ny: int=cy+dy
			if nx<0 or ny<0 or nx>=w or ny>=h:
				continue
			var n: int=ny*w+nx
			# (Out of a cell with no water for it, only where it started, beside its own home or
			# pressed to a band edge, it may cross such cells for `leave` cells to get out; never an
			# obstacle itself.)
			var out: bool=g[cell]>=2 and cost[cell]<=NAV.leave
			var closed: int=3 if out else 2
			if done[n]==1 or g[n]>=closed:
				continue
			if g[n]==1 and n!=goal and depth[n]<(0.0 if out else depth[cell])-0.001:
				continue
			if dx!=0 and dy!=0 and (g[cy*w+nx]>=closed or g[ny*w+cx]>=closed):
				continue
			# (A cell with less than NAV.room x its body height of water around it costs up to
			# 1 + NAV.narrow times more: a route keeps off narrow gaps and obstacle edges where
			# there is open water, S5-fix.)
			var step: float=cost[cell]+(1.41421356 if dx!=0 and dy!=0 else 1.0)*(1.0+NAV.narrow*maxf(0.0,1.0-room[n]/need))
			if step<cost[n]:
				cost[n]=step
				prev[n]=cell
				_push(heap_n,heap_k,n,step+_octile(nx-gx,ny-gy)+n*1.0e-9)
	var cells: Array[Vector2]=[]
	var at: int=best
	while at!=-1:
		cells.push_front(_centre(at,w))
		at=prev[at]
	cells[0]=from
	if best==goal:
		cells[-1]=to
	# Pulled straight: from each kept point on to the furthest cell it sees past every obstacle
	# (widened as for this species and size; out of one it starts in counts as seeing).
	var radii:=PackedVector2Array()
	var half: Vector2=Vector2(BODY[species][0],BODY[species][1])*scale*0.5+Vector2.ONE*NAV.cell
	var home_fields: PackedStringArray=cls.split("/")
	var home: Vector2=Vector2(float(home_fields[2]),float(home_fields[3])) if home_fields.size()==4 else Vector2.INF
	for o: Dictionary in _obstacles:
		var physical: Vector2=Vector2(BODY[species][0],BODY[species][1])*scale*0.5*OBSTACLE.body
		var at_home: bool=home!=Vector2.INF and ((home-Vector2(o.cx,o.cy))/(Vector2(o.rx,o.ry)+physical)).length_squared()<1.0
		radii.append(Vector2(o.rx+OBSTACLE.pad,o.ry+OBSTACLE.pad) if at_home else Vector2(o.rx+half.x,o.ry+half.y))
	var points: Array[Vector2]=[from]
	var i: int=0
	while i<cells.size()-1:
		var j: int=i+1
		while j+1<cells.size() and _blocker(points[-1],cells[j+1],radii,-1)<0:
			j+=1
		points.append(cells[j])
		i=j
	# (A route is at least a leg long.)
	if points.size()<2:
		points.append(to if best==goal else points[0])
	return PackedVector2Array(points)

func _centre(cell: int, w: int) -> Vector2:
	return Vector2((cell%w+0.5)*NAV.cell,(cell/w+0.5)*NAV.cell)

static func _octile(dx: int, dy: int) -> float:
	var x: int=absi(dx)
	var y: int=absi(dy)
	return maxi(x,y)+0.41421356*mini(x,y)

# A binary min-heap of cells keyed by cost (Arrays: shared with the caller).
const STEP_X: Array[int] = [1,-1,0,0,1,1,-1,-1]
const STEP_Y: Array[int] = [0,0,1,-1,1,-1,1,-1]
static func _push(nodes: Array, keys: Array, n: int, k: float) -> void:
	nodes.append(n)
	keys.append(k)
	var i: int=nodes.size()-1
	while i>0:
		var up: int=(i-1)/2
		if keys[up]<=k:
			break
		nodes[i]=nodes[up]
		keys[i]=keys[up]
		i=up
	nodes[i]=n
	keys[i]=k

static func _pop(nodes: Array, keys: Array) -> int:
	var top: int=nodes[0]
	var last: int=nodes.size()-1
	var n: int=nodes[last]
	var k: float=keys[last]
	nodes.resize(last)
	keys.resize(last)
	if last==0:
		return top
	var i: int=0
	while true:
		var child: int=i*2+1
		if child>=last:
			break
		if child+1<last and keys[child+1]<keys[child]:
			child+=1
		if keys[child]>=k:
			break
		nodes[i]=nodes[child]
		keys[i]=keys[child]
		i=child
	nodes[i]=n
	keys[i]=k
	return top

# The step p -> next (kept in lo..hi) with its centre out of every obstacle p is out of: across an
# edge it slides along the edge instead (the part across is dropped). If that still ends inside
# one (between two that touch), it stays at p.
func _keep_out(p: Vector2, next: Vector2, lo: Vector2, hi: Vector2, radii: PackedVector2Array = PackedVector2Array()) -> Vector2:
	var moved: bool=false
	for i in _obstacles.size():
		var o: Dictionary=_obstacles[i]
		var c:=Vector2(o.cx,o.cy)
		var r: Vector2=radii[i] if not radii.is_empty() else Vector2(o.rx,o.ry)
		var P1: Vector2=(next-c)/r
		if P1.length_squared()>=1.0:
			continue
		var P0: Vector2=(p-c)/r
		if P0.length_squared()<1.0:
			continue
		var d: Vector2=P1-P0
		var aa: float=maxf(d.length_squared(),1.0e-12)
		var b: float=P0.dot(d)
		var hit: float=clampf((-b-sqrt(maxf(0.0,b*b-aa*(P0.length_squared()-1.0))))/aa,0.0,1.0)
		var at: Vector2=P0+d*hit
		var tangent:=Vector2(-at.y,at.x)
		var q: Vector2=at+tangent*(d*(1.0-hit)).dot(tangent)/maxf(tangent.length_squared(),1.0e-12)
		next=(c+q/maxf(q.length(),0.000001)*1.0005*r).clamp(lo,hi)
		moved=true
	if moved:
		for o: Dictionary in _obstacles:
			if Vector2((next.x-o.cx)/o.rx,(next.y-o.cy)/o.ry).length_squared()<1.0 and Vector2((p.x-o.cx)/o.rx,(p.y-o.cy)/o.ry).length_squared()>=1.0:
				return p
	return next

# y kept in the species' band and an adult body's half height above the bed at x.
func _in_water(species: String, x: float, y: float) -> float:
	var band: Array=_bands[species]
	return clampf(y,band[0],minf(band[1],bed_y(x)-BODY[species][1]*0.5))

# A new fish's next move (S4, the simplest behaviour): by day a swim to a point near its home, at
# night a rest at its own spot beside it.
func _choose_home(a: Dictionary) -> void:
	var h: Dictionary=HOME[a.species]
	if state.light_hour<7 or state.light_hour>19:
		var rest: Vector2=_near_home(a.species,{"x":a.home_x,"y":a.home_y},int(a.id))
		a.activity="Resting"
		a.tx=rest.x
		a.ty=rest.y
		a.decision_at=state.elapsed+motion_rng.randf_range(60.0,120.0)
		return
	var angle: float=motion_rng.randf()*TAU
	var reach: float=h.radius*sqrt(motion_rng.randf())
	a.activity="Hovering"
	a.tx=clampf(a.home_x+cos(angle)*reach,_roam_x.x,_roam_x.y)
	a.ty=_in_water(a.species,a.tx,a.home_y+sin(angle)*reach*0.6)
	# (S5-fix) Only as far out as it sees from its home: a spot behind the next rock had sent a
	# gramma up and over it and back, turning round on the way, for a few px of hovering.
	var home:=Vector2(a.home_x,a.home_y)
	var spot:=Vector2(a.tx,a.ty)
	var radii: PackedVector2Array=_radii_of(a)
	if _blocker(home,spot,radii,-1)>=0:
		var lo: float=0.0
		var hi: float=1.0
		for n in 5:
			var mid: float=(lo+hi)*0.5
			if _blocker(home,home.lerp(spot,mid),radii,-1)<0:
				lo=mid
			else:
				hi=mid
		spot=home.lerp(spot,lo)
		a.tx=spot.x
		a.ty=_in_water(a.species,spot.x,spot.y)
	# (S5-fix) Not inside the room another fish keeps (_avoid's spacing) where it is now: two
	# hitch points closer than that kept a seahorse hovering short of its spot, never arriving.
	var own: Vector2=_bodies[a.id] if _bodies.has(a.id) else _body(a)
	for o: Dictionary in state.animals:
		if o.id==a.id or o.species=="green_chromis" or a.species=="clownfish" and o.species=="clownfish" and o.home==a.home:
			continue
		var r: Vector2=(own+(_bodies[o.id] if _bodies.has(o.id) else _body(o)))*0.5*(SEPARATE.perch if a.species=="seahorse" and o.species=="seahorse" else SEPARATE.margin*(1.17 if o.species!=a.species else SEPARATE.same))
		var rel:=Vector2((a.tx-o.x)/r.x,(a.ty-o.y)/r.y)
		var q: float=rel.length()
		if q<1.0:
			var out: Vector2=rel/q if q>0.0001 else Vector2(0.0,-1.0)
			a.tx=clampf(o.x+out.x*r.x*1.05,_roam_x.x,_roam_x.y)
			a.ty=_in_water(a.species,a.tx,o.y+out.y*r.y*1.05)
	a.decision_at=state.elapsed+motion_rng.randf_range(h.dwell[0],h.dwell[1])

# A school member holds its own slot beside the leader, mirrored with the leader's heading.
func _follow(a: Dictionary, lead: Dictionary) -> void:
	var k: float=float(a.id)*2.39996
	var r: float=CHROMIS.spread[0]+float((int(a.id)*17)%int(CHROMIS.spread[1]-CHROMIS.spread[0]))
	# The school's spacing breathes a little (slowly, +-`breathe`), side to side only: a vertical
	# breath read as a slow bob while resting (2026-09-26, user: chromis jittered at night).
	var breath: float=1.0+CHROMIS.breathe*sin(state.elapsed*0.23+float(a.id)*0.9)
	var band: Array=_bands[a.species]
	a.tx=clampf(lead.x+cos(k)*r*breath*lead.direction,_roam_x.x,_roam_x.y)
	a.ty=clampf(lead.y+sin(k)*r*0.5,band[0],band[1])
	# Settles within 20 px of its slot and keeps resting until 40 px off, so a resting fish does
	# not flip to schooling (and a quick catch-up stroke) each time it drifts a little.
	var gap: float=Vector2(a.x,a.y).distance_to(Vector2(a.tx,a.ty))
	var settled: bool=gap<(40.0 if a.activity=="Resting" else 20.0)
	a.activity="Resting" if lead.activity=="Resting" and settled else "Schooling"
	a.decision_at=state.elapsed

# The school leader's next move: a trip across the pool or a pause (mostly pauses at night).
func _choose_activity(a: Dictionary) -> void:
	var r: float=motion_rng.randf()
	var night: bool=state.light_hour<7 or state.light_hour>19
	var band: Array=_bands[a.species]
	a.decision_at=state.elapsed+motion_rng.randf_range(18,45)
	a.activity="Schooling"
	# Night trips are short and stay on this side (2026-09-28, S4; the yellow tang's night rule):
	# with the tang gone the chromis draws come in a new order, and on some seeds the school's
	# night trips added up to nearly its daytime distance (test_roaming "Night no longer slows").
	a.tx=_roaming_x(a,150.0 if night else 290.0,0.0 if night else 0.42)
	# Inset by the members' vertical reach so the whole school fits in the band.
	a.ty=motion_rng.randf_range(band[0]+CHROMIS.spread[1]*0.5,band[1]-CHROMIS.spread[1]*0.5)
	if r<0.16 or night and r<0.6:
		a.activity="Resting"
		# At night the school rests where it is (a slow hover), instead of creeping to a new
		# spot each choice and reversing up and down (2026-09-26).
		if night:
			a.tx=clampf(a.x,_roam_x.x,_roam_x.y)
			a.ty=clampf(a.y,band[0]+CHROMIS.spread[1]*0.5,band[1]-CHROMIS.spread[1]*0.5)
	# Give trips enough time to reach a destination instead of repeatedly
	# abandoning distant targets. Rest/feed choices keep their independent dwell time.
	if a.activity=="Schooling":
		var cruise: float=SWIM[a.species].cruise
		cruise*=0.82+0.36*float((int(a.id)*37)%101)/100.0
		var distance: float=Vector2(a.tx-a.x,a.ty-a.y).length()
		a.decision_at=state.elapsed+distance/cruise+motion_rng.randf_range(5,14)
	_look(a,band)

# Only while a lure is set (live, never saved) does curiosity draw from motion_rng.
func _look(a: Dictionary, band: Array) -> void:
	if not lure.is_empty() and state.elapsed-lure.since<LURE.interest:
		var spot:=Vector2(lure.x,clampf(lure.y,band[0],band[1]))
		if Vector2(a.x,a.y).distance_to(spot)<LURE.range and motion_rng.randf()<LURE.chance:
			a.activity="Curious"
			a.tx=clampf(lure.x+(-1.0 if a.x<lure.x else 1.0)*LURE.stand_off,_roam_x.x,_roam_x.y)
			a.ty=spot.y
			a.decision_at=state.elapsed+motion_rng.randf_range(LURE.look[0],LURE.look[1])
		# While the lure is fresh the leader keeps glancing at it.
		if a.activity!="Curious":
			a.decision_at=minf(a.decision_at,state.elapsed+5.0)

func _roaming_x(a: Dictionary, local_range: float, crossing_chance: float) -> float:
	var lo: float=_roam_x.x
	var hi: float=_roam_x.y
	var mid: float=(lo+hi)*0.5
	if motion_rng.randf()<crossing_chance:
		# Occasionally visit the other side; each destination is still independently sampled.
		return motion_rng.randf_range(mid+120,hi-20) if a.x<mid else motion_rng.randf_range(lo+20,mid-120)
	var direction: float=a.direction if motion_rng.randf()<0.65 else -a.direction
	var destination: float=a.x+direction*motion_rng.randf_range(40,local_range)
	# Reflect near the stream edges, avoiding repeated clamped targets at a wall.
	if destination<lo: destination=2*lo-destination
	if destination>hi: destination=2*hi-destination
	return clampf(destination,lo,hi)

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
		# Never starves (FLOOR): metabolism is paid only down to the floor; the rest is not paid.
		var required: float = cfg.cost/1440
		var floor_energy: float = cfg.reserve*FLOOR
		var used: float = clampf(a.energy-floor_energy,0.0,required)
		var unpaid: float = required-used
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
		# (Growth never takes energy below the floor either; above it this is the old rule.)
		var growth: float = minf(maxf(0,cfg.body-a.body),minf(minf(a.energy*0.002,cfg.body/(cfg.mature*1440)),maxf(0.0,a.energy-floor_energy)))
		a.body+=growth
		a.energy-=growth
		a.hunger=clampf(1-a.energy/cfg.reserve,0,1)
		if unpaid>0.0 or a.energy<floor_energy:
			state.totals.floor_hits+=1
		# Never dies out: the last of its species outlives its lifespan until a companion (a birth
		# or the certain rescue, _migration) arrives.
		if a.age>=a.lifespan and _has_company(a):
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

func _has_company(a: Dictionary) -> bool:
	for o: Dictionary in state.animals:
		if o.species==a.species and o.id!=a.id:
			return true
	return false

# Offline nobody chases food: drifting particles settle at once. Settled food turns to detritus.
func _food_tick(offline: bool) -> void:
	for f: Dictionary in state.food.duplicate():
		if offline and not f.settled:
			f.y=bed_y(f.x)-2
			f.settled=true
			f.settled_at=state.elapsed
		if f.settled and state.elapsed-f.settled_at>=FOOD.decay:
			state.resources.detritus+=f.mass
			state.food.erase(f)

# Young are born beside the parent (a chromis) or beside their own home (the others, which spawn
# gives them); past the cap they disperse.
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
			var base: float = child.home_x if child.has("home_x") else parent.x
			var at: Vector2=_clear_spot(child.species,Vector2(clampf(base+rng.randf_range(-30,30),_roam_x.x,_roam_x.y),child.y))
			child.x=at.x
			child.y=at.y
			child.tx=child.x
			child.ty=child.y
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

# R10: a species at or below RESCUE_AT gets a certain rescue (RESCUE_DELAY; state.rescue holds the
# due time per species until it arrives or the species recovers); otherwise rare arrivals.
# Adults never wander off.
func _migration() -> void:
	var c: Dictionary = counts()
	var due: Dictionary = state.get("rescue",{})
	for species: String in ACTIVE_SPECIES:
		if c[species]>RESCUE_AT:
			due.erase(species)
		elif not due.has(species):
			due[species]=state.elapsed+rng.randf_range(RESCUE_DELAY[0],RESCUE_DELAY[1])
		elif state.elapsed>=due[species]:
			due.erase(species)
			if not _arrive(species).is_empty():
				c[species]+=1
	if due.is_empty():
		state.erase("rescue")
	else:
		state.rescue=due
	if rng.randf()<ARRIVAL_RATE:
		var species: String = ACTIVE_SPECIES[rng.randi_range(0,ACTIVE_SPECIES.size()-1)]
		if c[species]<CAP[species] and state.animals.size()<habitat_cap():
			_arrive(species)

# An adult comes in at a scene exit (the x bounds on that side): a chromis at the depth spawn gave
# it, the others at the exit's depth inside their band; then it swims home.
func _arrive(species: String) -> Dictionary:
	var a: Dictionary = spawn(species,SPECIES[species].mature+rng.randf_range(0,20))
	if a.is_empty():
		return a
	var exits: Array[Vector2]=scene.exits()
	var exit: Vector2=exits[-1] if rng.randf()<0.5 else exits[0]
	var band: Array=_bands[species]
	var at:=Vector2(clampf(exit.x,_roam_x.x,_roam_x.y),clampf(exit.y,band[0],band[1]) if a.has("home") else a.y)
	at=_clear_spot(species,at)
	a.x=at.x
	a.y=at.y
	a.tx=a.x
	a.ty=a.y
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

# The combined habitat caps (18 for the reef v3 cast, 2026-09-28).
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
	_use_scene(state.scene)
	lure={}
	return true

static func validate(saved: Dictionary) -> bool:
	var version: Variant = saved.get("version",-1)
	if not version is int or version!=VERSION:
		return false
	if not saved.get("scene") is String or not ReefScene.ids().has(saved.scene):
		return false
	# Decor (S5): every scene's, each naming exactly its slots with styles they allow.
	if not saved.get("decor") is Dictionary or saved.decor.size()!=ReefScene.ids().size():
		return false
	for id: String in ReefScene.ids():
		if not _scene_of(id).valid_decor(saved.decor.get(id)):
			return false
	for key: String in ["seed","next_id","motion_ticks","ecology_ticks"]:
		if not saved.get(key) is int or saved[key]<0:
			return false
	for key: String in ["elapsed","ecology_remainder","motion_remainder","wall_checkpoint","light_hour"]:
		if not _number(saved.get(key)) or saved[key]<0:
			return false
	if saved.ecology_remainder>=60 or saved.motion_remainder>=0.201:
		return false
	if not saved.get("next_event") is int or saved.next_event<1:
		return false
	if not _valid_food(saved):
		return false
	if saved.has("rescue") and (not saved.rescue is Dictionary or not saved.rescue.keys().all(func(k): return k in ACTIVE_SPECIES) or not saved.rescue.values().all(func(t): return _number(t) and t>=0)):
		return false
	var next_event: int = saved.next_event
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
		var keys: Array = {"resources":POOLS,"ledger":["initial","in","out"],"totals":["birth","death","arrival","departure","dispersal","floor_hits"]}[group]
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
		for key: String in ["age","born","body","energy","x","y","tx","ty","direction","decision_at","last_breed","hunger","parent"]:
			if not _number(a.get(key)):
				return false
		if a.has("food_id") and not a.food_id is int:
			return false
		for key: String in ["vx","vy","relocated_at","avoid_x","avoid_y","heading","pitch","speed","thrust","turn"]:
			if a.has(key) and not _number(a[key]):
				return false
		# On a route round an obstacle (S5): planned from nav_x/nav_y to nav_tx/nav_ty, on leg nav_k.
		if a.has("nav_tx") and (not ["nav_x","nav_y","nav_tx","nav_ty"].all(func(k): return _number(a.get(k))) or not a.get("nav_k") is int or a.nav_k<0):
			return false
		# The new fish carry their home (HOME): {kind, slot, i} and its point home_x/home_y.
		if HOME.has(a.species) and not _valid_home(a):
			return false
		if a in saved.animals and (not _number(a.get("lifespan")) or a.lifespan<=0):
			return false
		if a.age<0 or a.body<0 or a.energy<0 or not a.get("recent") is Array or a.recent.size()>6:
			return false
		for e: Variant in a.recent:
			if not _valid_event(e,next_event):
				return false
	for e: Variant in saved.events:
		if not _valid_event(e,next_event):
			return false
	if not saved.get("causes") is Dictionary:
		return false
	for count: Variant in saved.causes.values():
		if not _number(count) or count<0:
			return false
	return true

static func _valid_home(a: Dictionary) -> bool:
	var h: Variant=a.get("home")
	if not h is Dictionary or not h.get("kind") in ["anemone","hitch","shelter","rock"] or not h.get("slot") is String or not h.get("i") is int or h.i<0:
		return false
	return _number(a.get("home_x")) and _number(a.get("home_y"))

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
