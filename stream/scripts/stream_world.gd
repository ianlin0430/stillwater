class_name StreamWorld
extends RefCounted

const VERSION: int = 2
const MAX_ANIMALS: int = 24
const MAX_AWAY: float = 259200.0
const DAY: float = 86400.0
const ACTIVE_SPECIES: Array[String] = ["shrimp","threadfin","hatchet"]
const SPECIES: Dictionary = {
	"shrimp": {"label":"Cherry shrimp","latin":"Neocaridina davidi","initial":6,"mature":21.0,"lifespan":120.0,"body":0.3,"reserve":3.0,"cost":0.22,"bite":0.5,"brood":2,"breed":0.12,"cooldown":7.0,"pool":"biofilm","k_food":6.0},
	# Legacy entry: crayfish were removed from the cast; kept only so older saves validate.
	"crayfish": {"label":"Blue crayfish","latin":"Procambarus alleni","initial":0,"mature":35.0,"lifespan":540.0,"body":3.0,"reserve":12.0,"cost":0.65,"bite":1.2,"brood":2,"breed":0.035,"cooldown":21.0,"pool":"detritus"},
	"threadfin": {"label":"Threadfin rainbowfish","latin":"Iriatherina werneri","initial":4,"mature":28.0,"lifespan":180.0,"body":0.7,"reserve":4.0,"cost":0.3,"bite":0.7,"brood":2,"breed":0.06,"cooldown":10.0,"pool":"microfauna","k_food":10.0},
	"hatchet": {"label":"Marbled hatchetfish","latin":"Carnegiella strigata","initial":4,"mature":28.0,"lifespan":180.0,"body":0.8,"reserve":4.0,"cost":0.32,"bite":0.75,"brood":2,"breed":0.04,"cooldown":14.0,"pool":"microfauna","k_food":10.0}}
# Ecology v2 (docs/plans/2026-09-22-self-sustaining-ecosystem.md). Rates are per day, applied per one-minute tick.
const CAP: Dictionary = {"shrimp":8,"threadfin":5,"hatchet":5}
const POOLS: Array[String] = ["nutrients","stem","floating","biofilm","microfauna","detritus"]
# Opening pools, near the settled state with a full cast (R11); also the v1 upgrade fill (R12).
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
const SHRIMP_DETRITUS_K: float = 30.0
const NURSERY_X: float = 640.0
const NURSERY_HALF: float = 95.0
const NURSERY_SHARE: float = 0.35
const PREY_RATE: float = 0.3
# Live encounters: fish take shrimplets from the water column below them. The
# horizontal gap must be within PREY_RANGE and the shrimplet at most PREY_DIVE
# below the fish, i.e. a threadfin in the lower half of its layer (y>=~310 over a
# bed at ~600). A plain 220 px radius never reached the bed from the hatchetfish
# band and only from the bottom edge of the threadfin band, so live predation ran
# at about a tenth of the offline approximation.
const PREY_RANGE: float = 220.0
const PREY_DIVE: float = 290.0
# Swimming depth bands, a little wider than the authored targets in _choose_activity.
const DEPTH: Dictionary = {"threadfin":[200.0,420.0],"hatchet":[88.0,208.0]}
const OFFLINE_ENCOUNTER: float = 0.5
const RESCUE_RATE: float = 1.0/96.0
const ARRIVAL_RATE: float = 1.0/504.0
# An unexplained position jump larger than this in one motion tick is a relocation
# (animals carry relocated_at). Fish layer clamping stays under 1 px; the shrimp
# surface snap when Exploring starts off the bed is what crosses it.
const RELOCATION: float = 3.0
const NAMES: Dictionary = {"shrimp":["Ember","Poppy","Ruby","Coral","Fern","Pepper"],"threadfin":["Silk","Reed","Willow","Glimmer"],"hatchet":["Marble","Mica","Dapple","Flint"]}
var rng := RandomNumberGenerator.new()
var motion_rng := RandomNumberGenerator.new()
var state: Dictionary
# True only while a live ecology tick runs; stamps events the stage may play.
var _live: bool = false

func _init(world_seed: int = 240921, wall_time: float = 0) -> void:
	rng.seed = world_seed
	motion_rng.seed = world_seed + 7919
	state = {"version":VERSION,"seed":world_seed,"elapsed":0.0,"ecology_remainder":0.0,"motion_remainder":0.0,"motion_ticks":0,"ecology_ticks":0,"next_id":1,"next_event":1,"wall_checkpoint":wall_time,"animals":[],"archive":[],"events":[],"history":[],"resources":OPENING.duplicate(),"ledger":{"initial":0.0,"in":0.0,"out":0.0},"totals":{"birth":0,"death":0,"arrival":0,"departure":0,"dispersal":0,"molt":0,"predation":0},"causes":{},"light_hour":12.0}
	for species: String in ACTIVE_SPECIES:
		var n: int = int(SPECIES[species].initial)
		var lo: float = 25.0 if species=="shrimp" else 40.0
		var hi: float = 100.0 if species=="shrimp" else 150.0
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
			animal.name = NAMES[species][i]
			animal.sex = "female" if i%2==0 else "male"
			if species=="shrimp":
				animal.x=[170.0,415.0,550.0,755.0,860.0,1120.0][i]
			elif species=="threadfin":
				animal.x=245.0+i*245.0
				animal.y=275.0+(i%2)*55
			else:
				animal.x=300.0+i*205.0
				animal.y=125.0+(i%2)*30
			if species=="shrimp":
				animal.y=floor_y(animal.x)
			animal.tx=animal.x
			animal.ty=animal.y
	state.ledger.initial = material()
	_event("begin",{},"A small world begins beneath the surface.")
	_sample()

static func floor_y(x: float) -> float:
	return 597.0 + sin(x*0.006)*9.0 + sin(x*0.017)*3.0

func animal_scale(a: Dictionary) -> float:
	var juvenile: bool = a.age < SPECIES[a.species].mature
	if a.species=="shrimp":
		return 0.48 if juvenile else 0.75
	return 0.5 if juvenile else 1.0

func _place(species: String) -> Vector2:
	var x: float = motion_rng.randf_range(150,1130)
	var y: float = floor_y(x)
	if species=="threadfin":
		y = motion_rng.randf_range(220,400)
	elif species=="hatchet":
		y = motion_rng.randf_range(90,190)
	elif species=="shrimp":
		y -= motion_rng.randf_range(0,25)
	return Vector2(x,y)

func spawn(species: String, age: float = 0, parent: int = 0) -> Dictionary:
	if species not in ACTIVE_SPECIES or state.animals.size()>=MAX_ANIMALS:
		return {}
	var cfg: Dictionary = SPECIES[species]
	var p: Vector2 = _place(species)
	var a: Dictionary = {"id":state.next_id,"species":species,"name":cfg.label+" "+str(state.next_id),"sex":"female" if rng.randf()<0.5 else "male","age":age,"parent":parent,"born":state.elapsed,"body":cfg.body*(0.45 if age<cfg.mature else 1.0),"energy":cfg.reserve*(0.35 if age<cfg.mature else 0.67),"x":p.x,"y":p.y,"tx":p.x,"ty":p.y,"direction":1.0 if p.x<640 else -1.0,"activity":"Resting","decision_at":0.0,"last_breed":-cfg.cooldown,"next_molt":age+(rng.randf_range(8,16) if species in ["crayfish","shrimp"] else 99999.0),"molting_until":-1.0,"shelter":240.0 if state.next_id%2==1 else 1030.0,"recent":[],"hunger":0.0}
	a.lifespan=cfg.lifespan*rng.randf_range(0.85,1.15)
	state.next_id += 1
	state.animals.append(a)
	return a

# Moving a newly placed animal sideways: spawn sampled y against its own x, so a
# shrimp kept that height and could end up inside the stream bed.
func _bed_align(a: Dictionary, x: float) -> void:
	if a.species=="shrimp":
		a.y=floor_y(x)+(a.y-floor_y(a.x))
	a.x=x

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

func _move(delta: float) -> void:
	for a: Dictionary in state.animals:
		var p:=Vector2(a.x,a.y)
		var species: String=a.species
		if a.molting_until>state.elapsed/DAY:
			a.activity="Molting"
			a.tx=a.shelter
			a.ty=floor_y(a.shelter)-35
		elif state.elapsed>=a.decision_at:
			_choose_activity(a)
		var target:=Vector2(a.tx,a.ty)
		var offset: Vector2=target-p
		var speed: float=7.0 if species=="shrimp" else 17.0 if species=="threadfin" else 11.0
		speed*=0.82+0.36*float((int(a.id)*37)%101)/100.0
		var acceleration: float=28.0 if species=="shrimp" else 15.0
		if a.activity=="Swimming" and species=="shrimp":
			speed=19.0
		if a.activity=="Retreating":
			var escape_age: float=0.9-maxf(0,a.decision_at-state.elapsed)
			speed=105.0*exp(-escape_age*3.0)
			acceleration=500.0
		if a.activity in ["Resting","Grazing","Feeding","Surface feeding","Displaying"]:
			speed=0.0 if species=="shrimp" else 1.2
		var desired: Vector2=offset.normalized()*minf(speed,sqrt(2.0*acceleration*offset.length()))
		if species in ["threadfin","hatchet"]:
			# Gentle changing headings, fading out on approach; no per-frame randomness.
			if a.activity=="Swimming" and offset.length()>35:
				var bend: float=sin(state.elapsed*(0.28+float(int(a.id)%5)*0.025)+a.id*1.73)
				desired+=offset.normalized().orthogonal()*bend*speed*0.22*minf(1,offset.length()/100)
			for other: Dictionary in state.animals:
				if other.id==a.id or other.species!=species:
					continue
				var apart: Vector2=p-Vector2(other.x,other.y)
				if apart.length()<90 and apart.length()>0.01:
					desired+=apart.normalized()*(90-apart.length())*0.16
		var velocity:=Vector2(a.get("vx",0.0),a.get("vy",0.0))
		velocity=velocity.move_toward(desired,acceleration*delta)
		var free: Vector2=p+velocity*delta
		var next: Vector2=free
		if species in ["threadfin","hatchet"]:
			# Keep each fish in its own layer: the shoaling push used to carry
			# hatchetfish down into the threadfin band.
			var band: Array = DEPTH[species]
			next=next.clamp(Vector2(100,band[0]),Vector2(1180,band[1]))
		if species=="shrimp":
			if a.activity=="Exploring":
				next.y=_shrimp_surface(next.x)
			else:
				# The bed is x-dependent: a shrimp swimming off the bed climbs more
				# slowly than the bed rises under it and used to dip into it.
				next.y=minf(next.y,floor_y(next.x))
		if absf(velocity.x)>1.3 and a.activity!="Retreating":
			a.direction=1.0 if velocity.x>0 else -1.0
		if next.distance_to(free)>RELOCATION:
			a.relocated_at=state.elapsed
		a.x=next.x
		a.y=next.y
		a.vx=velocity.x
		a.vy=velocity.y
		if next.distance_to(target)<5 and velocity.length()<7 and a.activity in ["Exploring","Swimming","Settling"]:
			if species=="shrimp" and a.activity=="Swimming":
				a.activity="Settling"
				a.tx=a.x
				a.ty=_shrimp_surface(a.x)
			else:
				a.activity="Grazing" if species=="shrimp" else "Resting"
				a.decision_at=state.elapsed+motion_rng.randf_range(4,18)

static func _shrimp_surface(x: float) -> float:
	# Low mossy stones along the foreground grazing route.
	var mound: float=18.0*exp(-pow((x-520.0)/80.0,2.0))+14.0*exp(-pow((x-840.0)/90.0,2.0))
	return floor_y(x)-mound

func _choose_activity(a: Dictionary) -> void:
	var r: float=motion_rng.randf()
	var night: bool=state.light_hour<7 or state.light_hour>19
	a.decision_at=state.elapsed+motion_rng.randf_range(18,45)
	if a.species=="shrimp":
		if r<0.02:
			# An occasional current/startle response, not an invented predator.
			a.activity="Retreating"
			a.tx=clampf(a.x-a.direction*65,100,1180)
			a.ty=a.y-16
			a.decision_at=state.elapsed+0.9
		elif r<0.52:
			a.activity="Grazing" if r<0.4 else "Resting"
			a.tx=a.x
			a.ty=_shrimp_surface(a.x)
			if absf(a.y-a.ty)>4:
				a.activity="Settling"
		elif r<0.86:
			a.activity="Exploring"
			a.tx=_roaming_x(a,110,0.22)
			a.ty=_shrimp_surface(a.tx)
		else:
			a.activity="Swimming"
			a.tx=_roaming_x(a,180,0.35)
			a.ty=floor_y(a.tx)-motion_rng.randf_range(45,95)
	else:
		a.activity="Swimming"
		a.tx=_roaming_x(a,290,0.42)
		a.ty=motion_rng.randf_range(100,205) if a.species=="hatchet" else motion_rng.randf_range(205,415)
		if r<0.16:
			a.activity="Surface feeding" if a.species=="hatchet" else "Displaying"
		elif night and r<0.6:
			a.activity="Resting"


	# Give exploratory trips enough time to reach a destination instead of repeatedly
	# abandoning distant targets. Rest/feed choices keep their independent dwell time.
	if a.activity in ["Exploring","Swimming"]:
		var cruise: float=7.0 if a.species=="shrimp" and a.activity=="Exploring" else 19.0 if a.species=="shrimp" else 17.0 if a.species=="threadfin" else 11.0
		cruise*=0.82+0.36*float((int(a.id)*37)%101)/100.0
		var distance: float=Vector2(a.tx-a.x,a.ty-a.y).length()
		a.decision_at=state.elapsed+distance/cruise+motion_rng.randf_range(5,14)

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
		if a.species=="shrimp":
			var scraps: float = minf(r.detritus,minf(room-food,cfg.bite/1440*(1-factor)*r.detritus/(r.detritus+SHRIMP_DETRITUS_K)))
			r.detritus-=scraps
			food+=scraps
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
		if a.age>=a.next_molt:
			a.next_molt=a.age+(14 if a.age<cfg.mature else 28)
			a.molting_until=state.elapsed/DAY+0.16
			_event("molt",a,a.name+" molted and is sheltering while its shell hardens.",{"until":a.molting_until*DAY})
		if a.age>=cfg.mature and a.sex=="female" and a.energy>cfg.reserve*0.74 and a.age-a.last_breed>=cfg.cooldown:
			if males.has(a.species) and rng.randf()<cfg.breed/1440*factor:
				_breed(a)
	_predation(offline)
	if state.ecology_ticks%60==0:
		_migration()
	if state.ecology_ticks%1440==0:
		_sample()
	_live=false

# R9: chance a shrimplet is out in the open, from 0 (safe) to 1.
func exposure(a: Dictionary, offline: bool) -> float:
	if a.species!="shrimp" or a.age>=SPECIES.shrimp.mature:
		return 0.0
	if a.activity in ["Sheltering","Molting"] or a.molting_until>state.elapsed/DAY:
		return 0.0
	var open: float = 1.0-0.6*minf(1.0,state.resources.stem/PLANTS.stem.max)
	if offline:
		return open*(1.0-NURSERY_SHARE)
	return 0.0 if absf(a.x-NURSERY_X)<=NURSERY_HALF else open

func _predation(offline: bool) -> void:
	var hunters: Array = []
	for b: Dictionary in state.animals:
		if b.species in ["threadfin","hatchet"] and b.hunger>0.3:
			hunters.append(b)
	if hunters.is_empty():
		return
	for a: Dictionary in state.animals.duplicate():
		var chance: float = PREY_RATE/1440*exposure(a,offline)
		if chance<=0:
			continue
		var hunter: Dictionary = {}
		if offline:
			chance*=OFFLINE_ENCOUNTER
		else:
			var best: float = PREY_RANGE
			for b: Dictionary in hunters:
				var drop: float = a.y-b.y
				if drop<0 or drop>PREY_DIVE:
					continue
				var d: float = absf(a.x-b.x)
				if d<best:
					best=d
					hunter=b
			if hunter.is_empty():
				continue
		if rng.randf()<chance:
			if hunter.is_empty():
				hunter=hunters[rng.randi_range(0,hunters.size()-1)]
			_remove(a,"predation",hunter)

func _breed(parent: Dictionary) -> void:
	if parent.species not in ACTIVE_SPECIES:
		return
	var cfg: Dictionary = SPECIES[parent.species]
	parent.last_breed=parent.age
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

func _remove(a: Dictionary, cause: String, predator: Dictionary = {}) -> void:
	if not state.animals.has(a):
		return
	var mass: float = a.body+a.energy
	if cause=="departure":
		state.ledger.out+=mass
		_event("departure",a,a.name+" moved downstream.")
	else:
		if not predator.is_empty():
			var gain: float = minf(mass*0.7,SPECIES[predator.species].reserve-predator.energy)
			predator.energy+=gain
			mass-=gain
			state.totals.predation+=1
			_event("feeding",predator,predator.name+" caught a young shrimp.",{"target":a.id})
		state.resources.detritus+=mass
		_event("death",a,a.name+" died from "+cause+".",{"cause":cause,"target":predator.id} if not predator.is_empty() else {"cause":cause})
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
		if c[species]<=2 and rng.randf()<RESCUE_RATE:
			_arrive(species)
			c[species]+=1
	if rng.randf()<ARRIVAL_RATE:
		var species: String = ACTIVE_SPECIES[rng.randi_range(0,ACTIVE_SPECIES.size()-1)]
		if c[species]<CAP[species] and state.animals.size()<18:
			_arrive(species)

func _arrive(species: String) -> void:
	var a: Dictionary = spawn(species,SPECIES[species].mature+rng.randf_range(0,20))
	if a.is_empty():
		return
	_bed_align(a,1150.0 if rng.randf()<0.5 else 130.0)
	state.ledger["in"]+=a.body+a.energy
	_event("arrival",a,"A "+SPECIES[species].label.to_lower()+" arrived from upstream.")

func _sample() -> void:
	var sample: Dictionary = counts()
	sample.day=state.elapsed/DAY
	sample.material_residual=residual()
	state.history.append(sample)
	if state.history.size()>400:
		state.history.pop_front()

func counts() -> Dictionary:
	var c: Dictionary = {"shrimp":0,"threadfin":0,"hatchet":0}
	for a: Dictionary in state.animals:
		c[a.species]+=1
	return c

func material() -> float:
	var total: float = 0
	for amount: float in state.resources.values():
		total+=amount
	for a: Dictionary in state.animals:
		total+=a.body+a.energy
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
	# Saves from before event ids start numbering at 1 (validate forbids ids without it).
	if not state.has("next_event"):
		state.next_event=1
	if state.version==1:
		_upgrade_v1()
	# The user explicitly removed crayfish from this pool. Preserve every other
	# identity, archive each departure and account for its exported material.
	for a: Dictionary in state.animals.duplicate():
		if a.species not in ACTIVE_SPECIES:
			_remove(a,"departure")
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
		for key: String in ["vx","vy","relocated_at"]:
			if a.has(key) and not _number(a[key]):
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

static func _number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))

static func _valid_event(e: Variant, next_event: int) -> bool:
	if not e is Dictionary or e.has("seq") and (not e.seq is int or e.seq<1 or e.seq>=next_event):
		return false
	return e.get("text") is String and e.get("kind") is String and e.get("id") is int and _number(e.get("time"))
