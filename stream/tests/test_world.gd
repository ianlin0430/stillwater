extends SceneTree
var checks: int=0
var failures: Array[String]=[]

func check(value: bool, message: String) -> void:
	checks+=1
	if not value:
		failures.append(message)
		printerr("FAIL: "+message)

func same(a: StreamWorld, b: StreamWorld) -> bool:
	return var_to_bytes(a.export_state())==var_to_bytes(b.export_state())

func reset_material(w: StreamWorld) -> void:
	w.state.ledger={"initial":w.material(),"in":0.0,"out":0.0}

# Hungry fish right beside newborn fish on a bare bed (the old worst case had shrimplets).
func no_predation() -> bool:
	for offline: bool in [false,true]:
		var w:=StreamWorld.new(42,1000)
		w.state.resources.stem=0.0
		for i in 2:
			var young: Dictionary=w.spawn("green_chromis",3)
			young.x=900.0+i*40
		for f: Dictionary in w.state.animals:
			f.energy=StreamWorld.SPECIES[f.species].reserve*0.4
			f.x=910.0
			f.y=w.band(f.species)[1]
		if offline:
			w.advance_offline(StreamWorld.DAY*3)
		else:
			w.advance_live(1800)
		if w.state.causes.has("predation") or w.state.events.any(func(e): return e.kind=="feeding"):
			return false
	return not StreamWorld.new().has_method("exposure")

func _initialize() -> void:
	var start: int=Time.get_ticks_msec()
	var a:=StreamWorld.new(42,1000)
	var b:=StreamWorld.new(42,1000)
	# The one place these tests pin the cast (reef v3, 2026-09-28 redesign; S2 numbers in docs/ecology.md
	# "Reef v3 cast sizing"); others read the constants.
	check(StreamWorld.ACTIVE_SPECIES==["green_chromis","clownfish","seahorse","royal_gramma"] and StreamWorld.CAP=={"green_chromis":8,"clownfish":3,"seahorse":4,"royal_gramma":3} and StreamWorld.habitat_cap()==18 and StreamWorld.ACTIVE_SPECIES.map(func(k): return StreamWorld.SPECIES[k].initial)==[6,2,2,2] and StreamWorld.RESCUE_AT==1,"Reef v3 cast: chromis/clownfish/seahorse/royal gramma, caps 8/3/4/3 (18), opening 6/2/2/2, rescue at one")
	check(StreamWorld.STREAM_IN=={"nutrients":0.7,"microfauna":1.2} and StreamWorld.OPENING_AGE=={"fish":[40.0,150.0]} and StreamWorld.FLOOR==0.1,"S2 numbers: microfauna input 1.2, opening ages 40-150 for every species, energy floor 0.1 x reserve")
	var opening: Dictionary={}
	for k: String in StreamWorld.ACTIVE_SPECIES:
		opening[k]=StreamWorld.SPECIES[k].initial
	check(a.counts()==opening and a.state.animals.size()==opening.values().reduce(func(x,y): return x+y),"A new world opens with exactly the opening cast, no threadfin, shrimp or hatchetfish")
	check(a.state.animals.all(func(x): return x.x>=150 and x.x<=1130),"Opening fish are spread inside the stream")
	check(["crayfish","shrimp","hatchet","threadfin","garden_eel","yellow_tang","purple_firefish","lawnmower_blenny","firefish"].all(func(k): return a.spawn(k).is_empty() and not StreamWorld.SPECIES.has(k)),"Removed species (the old reef cast included) cannot spawn")
	check(StreamWorld.validate(a.export_state()),"Initial state validates")
	a.advance_live(120)
	for i in 600:
		b.advance_live(0.2)
	check(same(a,b),"Live seeded repeatability across batching")
	check(absf(a.residual())<0.000001,"Live material ledger balances")
	var snap: Dictionary=a.snapshot()
	snap.animals.clear()
	snap.resources.biofilm=0
	check(same(a,b),"Snapshot edits cannot change world")
	var c:=StreamWorld.new()
	check(c.restore(a.export_state()),"Restore succeeds")
	a.advance_live(120)
	c.advance_live(120)
	check(same(a,c),"Live RNG continues after restoration")
	var path: String="user://qa-test.world"
	check(StreamStore.save(path,a)==OK,"Atomic save succeeds")
	check(c.restore(StreamStore.read(path)),"Checksummed save loads")
	check(same(a,c),"Complete save round trip")
	a.advance_offline(3600)
	check(StreamStore.save(path,a)==OK,"Backup rotates")
	var f:=FileAccess.open(path,FileAccess.WRITE)
	f.store_var({"format":"corrupt"})
	f.close()
	var recovered: Dictionary=StreamStore.load_or_create(path,1000)
	check(recovered.backup,"Corrupt primary recovers verified backup")
	var future: Dictionary=a.export_state()
	future.version=99
	check(not c.restore(future),"Future version rejected")
	future=a.export_state()
	future.animals[0].energy=NAN
	check(not c.restore(future),"Nonfinite state rejected")
	future=a.export_state()
	future.animals[0].recent=[{"text":"incomplete"}]
	check(not c.restore(future),"Malformed history rejected")
	future=a.export_state()
	future.animals.append(future.animals[0].duplicate(true))
	check(not c.restore(future),"Duplicate identities rejected")
	future=a.export_state()
	future.animals[0].activity=44
	check(not c.restore(future),"Wrong-type activity rejected")
	var damaged_path: String="user://qa-future.world"
	f=FileAccess.open(damaged_path,FileAccess.WRITE)
	f.store_var({"format":"future"})
	f.close()
	var original: PackedByteArray=FileAccess.get_file_as_bytes(damaged_path)
	recovered=StreamStore.load_or_create(damaged_path,5000)
	check(recovered.preserved and recovered.path!=damaged_path,"Unreadable original gets separate destination")
	check(original==FileAccess.get_file_as_bytes(damaged_path),"Original bytes preserved")
	DirAccess.remove_absolute(recovered.path)
	DirAccess.remove_absolute(damaged_path)
	a=StreamWorld.new(123,1000000)
	b=StreamWorld.new(123,1000000)
	var catch_start: int=Time.get_ticks_msec()
	var report: Dictionary=a.catch_up(1000000+StreamWorld.DAY*30)
	var catch_ms: int=Time.get_ticks_msec()-catch_start
	b.advance_offline(StreamWorld.DAY*3)
	check(report.capped and report.seconds==StreamWorld.MAX_AWAY,"Long absence capped to 72 hours")
	check(a.state.elapsed==b.state.elapsed,"Three-day cap advances intended duration")
	check(a.state.animals==b.state.animals,"Offline seeded outcomes repeat")
	check(catch_ms<2000,"72-hour catch-up under two seconds")
	var after: PackedByteArray=var_to_bytes(a.export_state())
	a.catch_up(1000000+StreamWorld.DAY*30)
	check(after==var_to_bytes(a.export_state()),"Same checkpoint cannot double-advance")
	a.catch_up(999999)
	check(after==var_to_bytes(a.export_state()),"Clock reversal cannot advance or regress checkpoint")
	check(absf(a.residual())<0.00001,"Offline resource ledger balances")
	check(a.state.animals.size()<=24,"Offline active population bounded")
	a=StreamWorld.new(14,1000)
	a.advance_live(15)
	a.advance_offline(80)
	check(absf(a.state.elapsed-95)<0.0001 and absf(a.state.ecology_remainder-35)<0.0001,"Partial minutes preserved across modes")
	# Transaction interruption: durable checkpoint is old until the new state is committed.
	a=StreamWorld.new(8,1000)
	StreamStore.save(path,a)
	var interrupted:=StreamWorld.new()
	interrupted.restore(StreamStore.read(path))
	interrupted.catch_up(1000+7200)
	recovered=StreamStore.load_or_create(path,1000+7200)
	check(same(interrupted,recovered.world),"Interrupted uncommitted catch-up replays exactly once")
	recovered=StreamStore.load_or_create(path,1000+7200)
	check(same(interrupted,recovered.world),"Committed catch-up not repeated on reopen")
	guarantee_checks()
	a=StreamWorld.new(33)
	var gone: Dictionary=a.state.animals[0]
	a._remove(gone,"old age")
	var deaths: int=a.state.totals.death
	a._remove(gone,"old age")
	check(a.state.totals.death==deaths,"An individual is never removed twice")
	check(absf(a.residual())<0.00001,"Death returns material as detritus")
	check(a.state.archive[-1].cause=="old age","Cause of death remains inspectable")
	check(no_predation(),"No animal eats another, live or offline")
	a=StreamWorld.new(3)
	while a.counts().green_chromis<StreamWorld.CAP.green_chromis:
		a.spawn("green_chromis",30)
	var mother: Dictionary=chromis(a)[0]
	# Two reserves: enough for a full brood of two chromis.
	mother.energy=StreamWorld.SPECIES.green_chromis.reserve*2
	reset_material(a)
	a._breed(mother)
	check(a.state.totals.dispersal==2,"Young disperse when local habitat is occupied")
	check(absf(a.residual())<0.00001,"Offspring dispersal recorded in boundary ledger")
	# R7: at the chromis space cap, remove two others to open room for a brood of two.
	for x: Dictionary in a.state.animals.filter(func(x): return x.species=="green_chromis" and x.id!=mother.id).slice(0,2):
		a._remove(x,"departure")
	mother.energy=StreamWorld.SPECIES.green_chromis.reserve*2
	reset_material(a)
	a._breed(mother)
	check(a.state.totals.birth==2,"Vacant habitat admits offspring")
	check(a.state.animals[-1].parent==mother.id,"Newborn lineage retained")
	check(absf(a.residual())<0.00001,"Birth transfers parental material")
	a=StreamWorld.new(9)
	var swimmer: Dictionary=chromis(a)[0]
	swimmer.activity="Schooling"
	# At rest and already facing its way (a fish still turning sculls sideways at up to SWIM.scull).
	swimmer.direction=1.0
	swimmer.heading=0.0
	swimmer.tx=swimmer.x+100
	swimmer.ty=swimmer.y
	swimmer.decision_at=1000
	var old_x: float=swimmer.x
	a.advance_live(0.2)
	check(swimmer.vx<=3.0001 and swimmer.x>old_x,"Fish accelerate gradually from rest")
	ecosystem_checks()
	fish_only_checks()
	feeding_checks()
	startle_checks()
	lure_checks()
	chromis_checks()
	new_cast_checks()
	var acceptance=preload("res://tests/ecology_acceptance.gd")
	# Gates derived from the configured cast (docs/ecology.md "Reef v3 cast sizing", criterion C6,
	# written before the S2 probe), 180 days: the 6 chromis openers must reach old age, the earliest
	# by day 76, and 6 + 6 open places = 12 offspring; band 12..18.
	check(acceptance.certain_old_age(180)==6 and acceptance.first_old_age_bound()==76 and acceptance.offspring_needed(180)==12 and acceptance.population_band()==[12,18],"Derived gates: 6 old-age deaths by day 76, 12 offspring, band 12-18")
	var need: int=acceptance.offspring_needed(180)
	check(acceptance.reproduction_passes({"births":6,"dispersal":need-6,"arrivals":2,"days":180}),"Dispersed offspring count toward reproduction")
	check(not acceptance.reproduction_passes({"births":6,"dispersal":need-7,"arrivals":2,"days":180}),"One offspring short of the threshold fails")
	check(acceptance.old_age_passes({"old_age":6,"first_old_age_day":76,"days":180}) and not acceptance.old_age_passes({"old_age":5,"first_old_age_day":40,"days":180}) and not acceptance.old_age_passes({"old_age":9,"first_old_age_day":77,"days":180}),"Old-age gate: at least 6, the first by day 76")
	check(not acceptance.local_replacement_passes({"births":2,"dispersal":30,"arrivals":7}),"Dispersal cannot disguise immigration-dominated replacement")
	check(acceptance.local_replacement_passes({"births":17,"dispersal":14,"arrivals":7}),"Retained births still exceed arrivals")
	var result: Dictionary={"checks":checks,"failures":failures,"seconds":(Time.get_ticks_msec()-start)/1000.0,"catch_up_72h_ms":catch_ms}
	f=FileAccess.open("res://artifacts/tests.json",FileAccess.WRITE)
	f.store_string(JSON.stringify(result,"  "))
	print(JSON.stringify(result))
	for suffix: String in ["",".bak",".tmp"]:
		DirAccess.remove_absolute(path+suffix)
	quit(0 if failures.is_empty() else 1)

func strip_animals(w: StreamWorld) -> void:
	w.state.animals.clear()
	reset_material(w)

func ecosystem_checks() -> void:
	# R2 light: the model keeps its own clock; floating plants shade the water below.
	var w:=StreamWorld.new(5)
	w.state.light_hour=23.5
	w.advance_offline(3600)
	check(absf(w.state.light_hour-0.5)<0.0001,"Light clock advances one hour per 60 ticks and wraps")
	w.state.light_hour=12.0
	check(absf(w.natural_light()-1.0)<0.0001,"Noon light is full")
	w.state.light_hour=3.0
	check(w.natural_light()==0.0,"Night has no natural light")
	w.state.light_hour=12.0
	w.state.resources.floating=0.0
	var open_light: float=w.sub_light()
	w.state.resources.floating=StreamWorld.PLANTS.floating.max
	check(absf(w.sub_light()-open_light*0.5)<0.0001,"Full floating cover halves underwater light")
	# R3: without light no plant grows (they only decay).
	w=StreamWorld.new(5)
	strip_animals(w)
	w.state.light_hour=0.0
	var before: Dictionary=w.state.resources.duplicate()
	w.advance_offline(3600*4)
	for plant: String in ["stem","floating","biofilm"]:
		check(w.state.resources[plant]<before[plant],"No growth in darkness: "+plant)
	check(w.state.resources.nutrients>=before.nutrients,"Darkness takes no nutrients")
	# R5: with no animals the pools converge from different starts and stay conserved.
	var p:=StreamWorld.new(6)
	strip_animals(p)
	var q:=StreamWorld.new(6)
	strip_animals(q)
	q.state.resources.nutrients*=3.0
	q.state.resources.detritus*=0.2
	q.state.resources.stem*=0.3
	reset_material(q)
	var gap_start: float=absf(p.material()-q.material())
	var mid: Dictionary={}
	# Exchange with the stream is slow: the gap between two starts halves roughly every 140 days.
	for day in 360:
		for hour in 24:
			for world: StreamWorld in [p,q]:
				world.advance_offline(3600)
				for arrival: Dictionary in world.state.animals.duplicate():
					world._remove(arrival,"departure")
		if day==339:
			mid=p.state.resources.duplicate()
	check(absf(p.material()-q.material())<gap_start*0.25,"Different starts converge toward one material total")
	for pool: String in StreamWorld.POOLS:
		check(p.state.resources[pool]>0.0,"Pool stays positive without animals: "+pool)
		check(absf(p.state.resources[pool]-mid[pool])<=maxf(0.05*mid[pool],0.05),"Pool settles without animals: "+pool)
	check(absf(p.residual())<0.00001 and absf(q.residual())<0.00001,"Animal-free pools conserve material")
	# R3: biofilm grazed to nothing grows back from its seed floor.
	w=StreamWorld.new(7)
	strip_animals(w)
	w.state.resources.biofilm=0.0
	reset_material(w)
	for hour in 24*40:
		w.advance_offline(3600)
		for arrival: Dictionary in w.state.animals.duplicate():
			w._remove(arrival,"departure")
	check(w.state.resources.biofilm>0.3*w.biofilm_max(),"Grazed-off biofilm recovers")
	check(absf(w.residual())<0.00001,"Seed top-up recorded as stream input")
	# R7: births over the species space cap drift downstream.
	w=StreamWorld.new(3)
	while w.counts().green_chromis<StreamWorld.CAP.green_chromis:
		w.spawn("green_chromis",30)
	check(w.counts().green_chromis==StreamWorld.CAP.green_chromis,"Threadfin at space cap")
	var mom: Dictionary=chromis(w)[0]
	mom.energy=StreamWorld.SPECIES.green_chromis.reserve*2
	reset_material(w)
	w._breed(mom)
	check(w.state.totals.dispersal==2 and w.state.totals.birth==0 and w.counts().green_chromis==StreamWorld.CAP.green_chromis,"Space cap sends offspring downstream")
	check(absf(w.residual())<0.00001,"Capped offspring leave through the ledger")
	# Offspring and arrivals are moved sideways after spawn placed them; they stay in their layer.
	var placed_ok: bool=true
	var w2:=StreamWorld.new(9)
	for i in 300:
		var species: String="green_chromis"
		var mother: Dictionary=w2.state.animals.filter(func(x): return x.species==species)[0]
		mother.energy=StreamWorld.SPECIES[species].reserve*2
		mother.x=float(130+(i*41)%1000)
		var placed: int=w2.state.animals.size()
		w2._breed(mother)
		w2._arrive(species)
		for i2 in range(placed,w2.state.animals.size()):
			var a: Dictionary=w2.state.animals[i2]
			var band: Array=w2.band(a.species)
			placed_ok=placed_ok and a.y>=band[0] and a.y<=band[1] and a.x>=120 and a.x<=1150
		while w2.state.animals.size()>12:
			w2.state.animals.pop_back()
	check(placed_ok,"Relocated offspring and arrivals start inside their depth band")
	# R8: individual lifespans vary by at most 15%.
	var spans_ok: bool=true
	var ages_ok: bool=true
	for s in 12:
		w=StreamWorld.new(1000+s)
		for i in 6:
			w.spawn(StreamWorld.ACTIVE_SPECIES[i%4],1)
		for animal: Dictionary in w.state.animals:
			var base: float=StreamWorld.SPECIES[animal.species].lifespan
			spans_ok=spans_ok and animal.lifespan>=base*0.85 and animal.lifespan<=base*1.15
			if animal.age>1:
				# R11 range: every species [40, 150].
				var span: Array=StreamWorld.OPENING_AGE.get(animal.species,StreamWorld.OPENING_AGE.fish)
				var lo: float=span[0]
				var hi: float=span[1]
				ages_ok=ages_ok and animal.age>=lo and animal.age<=hi and animal.age<animal.lifespan
	check(spans_ok,"Lifespans within 0.85-1.15 of species lifespan")
	check(ages_ok,"Opening ages staggered within R11 ranges")
	check(StreamWorld.SPECIES.green_chromis.lifespan==180.0,"Chromis lifespan 180")
	# R10: a vanished species is rescued from upstream (certain, within 24 h: guarantee_checks);
	# adults never wander off.
	w=StreamWorld.new(11)
	for animal: Dictionary in w.state.animals.duplicate():
		if animal.species=="green_chromis":
			w.state.animals.erase(animal)
	reset_material(w)
	w.advance_offline(StreamWorld.DAY)
	check(w.counts().green_chromis>0,"Rescue arrival restores a missing species within a day")
	check(w.state.totals.departure==0,"No random adult departures")
	# Reproducibility within a mode, and a pool-bearing snapshot.
	var r1:=StreamWorld.new(19)
	var r2:=StreamWorld.new(19)
	r1.advance_offline(StreamWorld.DAY*2)
	r1.advance_offline(StreamWorld.DAY*2)
	r2.advance_offline(StreamWorld.DAY*2)
	r2.advance_offline(StreamWorld.DAY)
	r2.advance_offline(StreamWorld.DAY)
	check(same(r1,r2),"Offline seeded run reproducible across batching")
	check(StreamWorld.POOLS.all(func(k): return r1.snapshot().resources.has(k)),"Snapshot exposes all pools")

# advance_offline caps each call at MAX_AWAY; longer spans go in pieces.
func offline(w: StreamWorld, seconds: float) -> void:
	while seconds>0:
		w.advance_offline(minf(seconds,StreamWorld.MAX_AWAY))
		seconds-=StreamWorld.MAX_AWAY

func by_id(w: StreamWorld, id: int) -> Dictionary:
	for x: Dictionary in w.state.animals:
		if x.id==id:
			return x
	return {}

func ids(list: Array) -> Array:
	return list.map(func(x): return x.id)

# Fish only: nothing molts, broods or carries shrimp-era fields; motion fields are still checked.
func fish_only_checks() -> void:
	# New animals carry no shrimp-only fields and nothing molts or broods.
	var n:=StreamWorld.new(42,1000)
	var cursor: int=n.state.next_event-1
	offline(n,StreamWorld.DAY*20)
	var seen: Array=StreamWorld.events_after(n.state.events,cursor)
	check(n.state.animals.all(func(x): return not x.has("tint") and not x.has("brood_until")) and not seen.any(func(e): return e.kind in ["berried","molt"]) and seen.any(func(e): return e.kind in ["birth","dispersal"]),"Fish breed; no tint, brood or molt appears")
	var bad: Dictionary=StreamWorld.new(5).export_state()
	bad.animals.filter(func(x): return x.species=="clownfish")[0].heading=INF
	check(not StreamWorld.validate(bad),"Non-finite motion field rejected")

func chromis(w: StreamWorld) -> Array:
	return w.state.animals.filter(func(x): return x.species=="green_chromis")

func food_mass(w: StreamWorld) -> float:
	var total: float=0.0
	for f: Dictionary in w.state.get("food",[]):
		total+=f.mass
	return total

# What the interactions must never touch: both RNGs, the pools and every animal's ecology.
func ecology_of(w: StreamWorld) -> Array:
	return [w.rng.state,w.state.resources,w.state.totals,w.state.ledger,w.state.animals.map(func(x): return [x.id,x.energy,x.body,x.age,x.last_breed])]

# 2026-09-23 user decision: real food, never required (docs/BACKEND_SNAPSHOT_EVENTS.md "Feeding").
func feeding_checks() -> void:
	var cfg: Dictionary=StreamWorld.FOOD
	var pinch: float=cfg.particles*cfg.mass
	# Without feeding nothing new appears in the state, and no-op calls change nothing.
	var plain:=StreamWorld.new(42,1000)
	var quiet:=StreamWorld.new(42,1000)
	for i in 300:
		plain.advance_live(0.2)
		quiet.clear_lure()
		quiet.startle(-5000,-5000,1.0)
		quiet.advance_live(0.2)
	quiet.advance_offline(StreamWorld.DAY)
	plain.advance_offline(StreamWorld.DAY)
	check(same(plain,quiet),"Unfed world with no-op interaction calls is byte-identical")
	check(["food","next_food","fed"].all(func(k): return not plain.state.has(k)) and plain.state.animals.all(func(x): return not x.has("food_id")),"An unfed world carries no food fields")
	# A pinch enters through ledger.in and is saved.
	var w:=StreamWorld.new(42,1000)
	w.state.light_hour=12.0
	var cursor: int=w.state.next_event-1
	var ledger_in: float=w.state.ledger["in"]
	check(w.feed(640.0),"Feeding the pool succeeds")
	var fed: Array=StreamWorld.events_after(w.state.events,cursor)
	check(fed.size()==1 and fed[0].kind=="fed" and fed[0].live==true and fed[0].x==640.0 and fed[0].id==0 and fed[0].has("seq"),"One live fed event at x")
	check(w.state.food.size()==cfg.particles and w.state.food.all(func(f): return f.settled==false and f.y<=cfg.surface+15 and absf(f.x-640)<=25),"A pinch is a few particles at the surface")
	check(absf(w.state.ledger["in"]-ledger_in-pinch)<0.000001 and absf(w.residual())<0.00001,"Food mass enters through ledger.in")
	check(StreamWorld.validate(w.export_state()),"World with food validates")
	var c:=StreamWorld.new()
	check(c.restore(w.export_state()) and c.state.food==w.state.food and same(c,w),"Food survives save and load")
	# Food sinks; fish notice it and eat it; the pool keeps balancing.
	var y0: float=w.state.food[0].y
	w.advance_live(2)
	check(w.state.food.is_empty() or w.state.food[0].y>y0,"Food sinks")
	var saw_feeding: bool=false
	for i in 600:
		w.advance_live(0.2)
		saw_feeding=saw_feeding or w.state.animals.any(func(x): return x.activity=="Feeding" and x.has("food_id"))
		if absf(w.residual())>0.00001:
			break
	check(saw_feeding,"Fish swim to food (activity Feeding with food_id)")
	check(absf(w.residual())<0.00001,"Food eaten or settling keeps material balanced")
	# A hungry fish below a pinch gains exactly the eaten food as energy (80%).
	var h:=StreamWorld.new(8,1000)
	var twin:=StreamWorld.new(8,1000)
	for world: StreamWorld in [h,twin]:
		for x: Dictionary in world.state.animals.duplicate():
			if x!=chromis(world)[0]:
				world.state.animals.erase(x)
		var fish: Dictionary=chromis(world)[0]
		fish.energy=1.0
		fish.x=500.0
		fish.y=230.0
		fish.tx=500.0
		fish.ty=230.0
		reset_material(world)
	h.feed(500.0)
	h.advance_live(60)
	twin.advance_live(60)
	var eaten: float=pinch-food_mass(h)
	check(eaten>=cfg.mass-0.000001,"The fish ate at least one particle")
	# Each pellet eaten live is one `ate` event naming the eater and the pellet (for exact bites).
	var fish_h: Dictionary=chromis(h)[0]
	var bites: Array=h.state.events.filter(func(e): return e.kind=="ate")
	var pinch_ids: Array=range(1,cfg.particles+1)
	check(bites.size()==int(round(eaten/cfg.mass)) and bites.all(func(e): return e.live==true and e.id==fish_h.id and e.has("seq") and e.food_id in pinch_ids and e.has("x") and e.has("y") and absf(e.food_x-e.x)<=cfg.eat and absf(e.food_y-e.y)<=cfg.eat),"One live ate event per pellet eaten: actor id, food_id, actor x/y and pellet food_x/food_y")
	check(bites.map(func(e): return e.food_id).size()==bites.map(func(e): return e.food_id).reduce(func(acc,x): return acc if x in acc else acc+[x],[]).size(),"Each pellet is eaten once")
	check(bites.all(func(e): return e.text=="") and not fish_h.recent.any(func(e): return e.kind=="ate") and not h.state.totals.has("ate"),"Bites add no journal text, stay out of the animal's recent story and the totals")
	check(StreamWorld.validate(h.export_state()),"A world with ate events validates")
	check(absf(chromis(h)[0].energy-chromis(twin)[0].energy-eaten*0.8)<0.0001 and absf(h.residual())<0.00001,"Eaten food becomes that fish's energy (80%, 20% detritus)")
	# A full fish ignores food.
	var full:=StreamWorld.new(8,1000)
	for x: Dictionary in full.state.animals.duplicate():
		if x!=chromis(full)[0]:
			full.state.animals.erase(x)
	chromis(full)[0].energy=StreamWorld.SPECIES.green_chromis.reserve
	reset_material(full)
	full.feed(chromis(full)[0].x)
	full.advance_live(60)
	check(absf(food_mass(full)-pinch)<0.000001 and chromis(full)[0].activity!="Feeding" and not full.state.events.any(func(e): return e.kind=="ate"),"A full fish ignores food (no ate event)")
	# Daily cap: a few pinches per simulated day, then "they're full".
	var d:=StreamWorld.new(5,1000)
	var n: int=0
	while d.feed(300.0+n*100):
		n+=1
		if n>50:
			break
	check(n==int(round(cfg.daily/pinch)) and n>=2,"The daily cap allows %d pinches" % n)
	var before: PackedByteArray=var_to_bytes(d.export_state())
	check(not d.feed(640.0) and var_to_bytes(d.export_state())==before,"Past the cap feed returns false and changes nothing")
	check(not d.feed(NAN) and not d.feed(INF),"Non-finite positions are refused")
	d.advance_offline(StreamWorld.DAY)
	check(d.feed(640.0),"The next simulated day accepts food again")
	# Without fish, food settles on the bed and turns into detritus.
	var bare:=StreamWorld.new(6,1000)
	strip_animals(bare)
	bare.feed(300.0)
	var settled: bool=false
	for i in 400:
		bare.advance_live(0.2)
		settled=settled or bare.state.food.any(func(f): return f.settled and absf(f.y-(StreamWorld.floor_y(f.x)-2))<0.001 and f.settled_at>0)
	check(settled and bare.state.food.size()==cfg.particles,"Uneaten food settles on the bed")
	bare.advance_live(cfg.decay+120)
	check(bare.state.food.is_empty() and absf(bare.residual())<0.00001 and not bare.state.events.any(func(e): return e.kind=="ate"),"Settled food becomes detritus after a while (decay is not a bite)")
	# Offline catch-up: drifting food just settles and decays, nobody chases it.
	var off:=StreamWorld.new(9,1000)
	off.feed(640.0)
	off.advance_offline(120)
	check(off.state.food.all(func(f): return f.settled) and off.state.animals.all(func(x): return x.activity!="Feeding"),"Offline, drifting food settles without a chase")
	off.advance_offline(StreamWorld.DAY)
	check(off.state.food.is_empty() and absf(off.residual())<0.00001 and StreamWorld.validate(off.export_state()) and not off.state.events.any(func(e): return e.kind=="ate"),"Offline food decays and the ledger balances; nobody bites offline")
	# Overfeeding at the cap for 60 days only raises detritus within bounds.
	var fat:=StreamWorld.new(812,1000)
	var lean:=StreamWorld.new(812,1000)
	var peak: Array=[0.0,0.0]
	for day in 60:
		while fat.feed(640.0):
			pass
		fat.advance_offline(StreamWorld.DAY)
		lean.advance_offline(StreamWorld.DAY)
		peak=[maxf(peak[0],fat.state.resources.detritus),maxf(peak[1],lean.state.resources.detritus)]
	check(peak[0]<=peak[1]+cfg.daily/0.12+1.0 and absf(fat.residual())<0.00001 and StreamWorld.validate(fat.export_state()),"Sixty days at the cap keep detritus bounded (%.2f vs %.2f unfed)" % peak)
	# Bites never crowd the journal: only the latest few ate events are kept.
	var busy:=StreamWorld.new(42,1000)
	busy.state.light_hour=12.0
	for x: Dictionary in busy.state.animals:
		x.energy=1.0
	var ate_seen: int=0
	var cursor_b: int=busy.state.next_event-1
	for day in 3:
		for k in 4:
			busy.feed(300.0+k*200.0)
			for i in 900:
				busy.advance_live(0.2)
				ate_seen+=StreamWorld.events_after(busy.state.events,cursor_b).filter(func(e): return e.kind=="ate").size()
				cursor_b=busy.state.next_event-1
				for x: Dictionary in busy.state.animals:
					x.energy=minf(x.energy,1.0)
		busy.advance_offline(StreamWorld.DAY-4*900*0.2)
	var kept_bites: int=busy.state.events.filter(func(e): return e.kind=="ate").size()
	check(ate_seen>cfg.max_bites and kept_bites<=cfg.max_bites and busy.state.events.any(func(e): return e.kind=="begin"),"The journal keeps at most %d ate events (%d bites in three fed days) and older events stay" % [cfg.max_bites,ate_seen])
	# Validation of the new optional fields.
	var bad: Dictionary=d.export_state()
	check(bad.food.size()==cfg.particles,"Fixture for food validation holds a pinch")
	bad.food[0].mass=NAN
	check(not StreamWorld.validate(bad),"Non-finite food mass rejected")
	bad=d.export_state()
	bad.food[0].id=bad.next_food
	check(not StreamWorld.validate(bad),"Food id at or beyond next_food rejected")
	bad=d.export_state()
	bad.food[0].settled="yes"
	check(not StreamWorld.validate(bad),"Non-boolean settled rejected")
	bad=d.export_state()
	bad.animals[0].food_id="1"
	check(not StreamWorld.validate(bad),"Non-integer food_id rejected")
	bad=d.export_state()
	bad.fed.mass=-1.0
	check(not StreamWorld.validate(bad),"Negative fed mass rejected")
	bad=d.export_state()
	bad.food="none"
	check(not StreamWorld.validate(bad),"Non-array food rejected")

# Tap the glass: a short dart away; no ecology effect, nothing saved (new fish: new_cast_checks).
func startle_checks() -> void:
	var w:=StreamWorld.new(42,1000)
	var twin:=StreamWorld.new(42,1000)
	for world: StreamWorld in [w,twin]:
		world.state.light_hour=12.0
		world.advance_live(20)
	var near: Dictionary=chromis(w)[0]
	var tap:=Vector2(near.x+30,near.y)
	var far: Array=w.state.animals.filter(func(x): return Vector2(x.x,x.y).distance_to(tap)>=StreamWorld.STARTLE.radius)
	var far_before: Array=far.map(func(x): return [x.activity,x.tx,x.ty,x.decision_at])
	var start: float=Vector2(near.x,near.y).distance_to(tap)
	var hits: int=w.startle(tap.x,tap.y,1.0)
	check(hits>=1 and near.activity=="Startled","A tap startles a nearby fish")
	check(far.map(func(x): return [x.activity,x.tx,x.ty,x.decision_at])==far_before,"Fish out of reach are not startled")
	w.advance_live(1.6)
	twin.advance_live(1.6)
	check(Vector2(near.x,near.y).distance_to(tap)>start+10,"The startled fish darts away from the tap")
	w.advance_live(StreamWorld.STARTLE.seconds+1)
	twin.advance_live(StreamWorld.STARTLE.seconds+1)
	check(near.activity!="Startled","It settles again after a few seconds")
	for i in 3000:
		w.advance_live(0.2)
		twin.advance_live(0.2)
	check(ecology_of(w)==ecology_of(twin),"Startle has no ecology effect (RNG, pools, energy, breeding)")
	check(StreamWorld.validate(w.export_state()) and not w.export_state().has("startle"),"Startle leaves no saved field")
	check(w.startle(NAN,0,1)==0 and w.startle(0,0,0)==0,"Invalid taps are ignored")

# Cursor lure: nearby curious fish drift over, keep their layer, lose interest; nothing saved.
func lure_checks() -> void:
	var w:=StreamWorld.new(42,1000)
	var twin:=StreamWorld.new(42,1000)
	for world: StreamWorld in [w,twin]:
		world.state.light_hour=12.0
	var spot:=Vector2(640,90)
	w.set_lure(spot)
	var band: Array=w.band("green_chromis")
	var curious: Dictionary={}
	var in_band: bool=true
	var came_close: bool=false
	var far_curious: bool=false
	for i in 300:
		w.advance_live(0.2)
		twin.advance_live(0.2)
		for a: Dictionary in chromis(w):
			in_band=in_band and a.y>=band[0] and a.y<=band[1]
			if a.activity=="Curious":
				if not curious.has(a.id):
					curious[a.id]=Vector2(a.x,a.y).distance_to(Vector2(spot.x,band[0]))
					far_curious=far_curious or curious[a.id]>StreamWorld.LURE.range
				came_close=came_close or (absf(a.x-spot.x)<StreamWorld.LURE.stand_off+25 and a.y<band[0]+30)
	check(not curious.is_empty(),"A resting cursor draws curious fish (%d)" % curious.size())
	check(not far_curious,"Only fish within range become curious")
	check(came_close,"A curious fish drifts over to look")
	check(in_band,"Curious fish keep their depth band when the lure is above it")
	# Interest fades: after the interest window no fish starts a new look.
	for i in int(StreamWorld.LURE.interest/0.2):
		w.advance_live(0.2)
		twin.advance_live(0.2)
	var late: bool=false
	for i in 600:
		w.advance_live(0.2)
		twin.advance_live(0.2)
		late=late or chromis(w).any(func(x): return x.activity=="Curious")
	check(not late,"Fish lose interest in a cursor that stays put")
	# The same resting point does not renew interest; a moved cursor does.
	var since: float=w.lure.since
	w.set_lure(spot+Vector2(2,1))
	check(w.lure.since==since,"Tiny cursor jitter keeps the same lure")
	w.clear_lure()
	check(w.lure.is_empty() and not w.export_state().has("lure"),"clear_lure removes it; the lure is never saved")
	for i in 600:
		w.advance_live(0.2)
		twin.advance_live(0.2)
	check(ecology_of(w)==ecology_of(twin),"The lure has no ecology effect")
	var r:=StreamWorld.new()
	w.set_lure(spot)
	check(r.restore(w.export_state()) and r.lure.is_empty(),"A restored world has no lure")

func centroid(list: Array) -> Vector2:
	var c:=Vector2.ZERO
	for x: Dictionary in list:
		c+=Vector2(x.x,x.y)
	return c/maxf(1,list.size())

func spread(list: Array) -> float:
	var c: Vector2=centroid(list)
	var total: float=0.0
	for x: Dictionary in list:
		total+=c.distance_to(Vector2(x.x,x.y))
	return total/maxf(1,list.size())

# 2026-09-24 user decision: green chromis school in midwater, a loose group with a shared
# heading and individual offsets that regroups after being scattered.
func chromis_checks() -> void:
	var cfg: Dictionary=StreamWorld.SPECIES.get("green_chromis",{})
	check(cfg.get("label")=="Green chromis" and cfg.get("latin")=="Chromis viridis" and cfg.get("pool")=="microfauna" and StreamWorld.CAP.get("green_chromis")==8 and cfg.get("initial")==6,"Green chromis: microfauna, habitat for eight, opening school of six")
	var w:=StreamWorld.new(42,1000)
	var school: Array=chromis(w)
	var band: Array=w.band("green_chromis")
	check(school.size()==cfg.initial and school.all(func(x): return x.y>=band[0] and x.y<=band[1]) and spread(school)<StreamWorld.CHROMIS.regroup,"The opening chromis start together as a school in midwater")
	w.state.light_hour=12.0
	var in_band: bool=true
	var seen: Dictionary={}
	var loose: float=0.0
	var shared: int=0
	var moving: int=0
	var low: float=INF
	var high: float=-INF
	for i in 3000:
		w.advance_live(0.2)
		in_band=in_band and school.all(func(x): return x.y>=band[0]-0.01 and x.y<=band[1]+0.01)
		for x: Dictionary in school:
			seen[x.activity]=true
		loose+=spread(school)/3000.0
		var c: Vector2=centroid(school)
		low=minf(low,c.x)
		high=maxf(high,c.x)
		var lead: Dictionary=school[0]
		if absf(lead.vx)>6.0:
			moving+=1
			if school.filter(func(x): return signf(x.vx)==signf(lead.vx)).size()>=school.size()-1:
				shared+=1
	check(in_band,"Chromis keep to their midwater band")
	check(seen.keys().all(func(k): return k in ["Schooling","Resting"]) and seen.has("Schooling"),"By day chromis school and rest (%s)" % str(seen.keys()))
	check(loose<StreamWorld.CHROMIS.regroup and loose>12.0,"The school stays loose but together (mean spread %.0f px)" % loose)
	check(high-low>300,"The school roams the pool (%.0f px)" % (high-low))
	check(moving>100 and float(shared)/moving>0.7,"School members share the leader's heading (%d/%d)" % [shared,moving])
	# Leader succession: the next oldest id leads and the school carries on.
	w._remove(school[0],"old age")
	school=chromis(w)
	for i in 600:
		w.advance_live(0.2)
	check(spread(school)<StreamWorld.CHROMIS.regroup and school.all(func(x): return x.y>=band[0] and x.y<=band[1]),"When the leader dies the school follows the next one")
	# A tap scatters the nearby chromis; the school regroups.
	var t:=StreamWorld.new(42,1000)
	t.state.light_hour=12.0
	t.advance_live(20)
	var ts: Array=chromis(t)
	var c0: Vector2=centroid(ts)
	var hits: int=t.startle(c0.x,c0.y,1.0)
	check(hits>=3 and ts.filter(func(x): return x.activity=="Startled").size()>=3,"A tap scatters the school")
	t.advance_live(1.6)
	var scattered: float=spread(ts)
	t.advance_live(40)
	check(ts.all(func(x): return x.activity!="Startled") and spread(ts)<StreamWorld.CHROMIS.regroup and spread(ts)<scattered+40,"Then the chromis regroup (%.0f -> %.0f px)" % [scattered,spread(ts)])
	# Night slows them down: mostly resting together.
	var n:=StreamWorld.new(42,1000)
	n.state.light_hour=1.0
	var resting: int=0
	for i in 1500:
		n.advance_live(0.2)
		resting+=chromis(n).filter(func(x): return x.activity=="Resting").size()
	check(resting>1500*chromis(n).size()*0.3,"At night the school mostly rests")
	check(StreamWorld.validate(w.export_state()) and absf(w.residual())<0.00001,"Chromis world validates and balances")


func of(w: StreamWorld, species: String) -> Array:
	return w.state.animals.filter(func(x): return x.species==species)

# Keeps only the animals `keep` accepts, then rebalances the ledger.
func only(w: StreamWorld, keep: Callable) -> void:
	for x: Dictionary in w.state.animals.duplicate():
		if not keep.call(x):
			w.state.animals.erase(x)
	reset_material(w)

func in_band(w: StreamWorld, a: Dictionary) -> bool:
	var band: Array=w.band(a.species)
	return a.y>=band[0]-0.01 and a.y<=band[1]+0.01

func home_dist(a: Dictionary) -> float:
	return Vector2(a.x,a.y).distance_to(Vector2(a.home_x,a.home_y))

# The guarantees (user decisions 2026-09-28, plan §4.3): nobody starves (energy floor), and no
# species dies out (the last one waits for a companion; a rescue is certain within 24 h).
func guarantee_checks() -> void:
	var floor_of: Callable=func(x: Dictionary) -> float: return StreamWorld.SPECIES[x.species].reserve*StreamWorld.FLOOR
	# No food at all for 30 days (every pool empty, no inflow).
	var a:=StreamWorld.new(9)
	a.state.supply_scale=0.0
	for pool: String in StreamWorld.POOLS:
		a.state.resources[pool]=0.0
	for animal: Dictionary in a.state.animals:
		animal.energy=StreamWorld.SPECIES[animal.species].reserve*0.3
	reset_material(a)
	offline(a,StreamWorld.DAY*30)
	check(not a.state.causes.has("starvation") and a.state.totals.floor_hits>0,"No food for 30 days: animals reach the energy floor (%d floor hits) and none starves" % a.state.totals.floor_hits)
	check(a.state.animals.all(func(x): return x.energy>=floor_of.call(x)-0.000001),"Energy never drops below the floor")
	check(a.state.totals.birth==0 and a.state.totals.dispersal==0,"At the floor nobody breeds")
	check(a.state.causes.keys().all(func(k): return k=="old age"),"Without food only old age ends a life (%s)" % str(a.state.causes))
	check(absf(a.residual())<0.00001 and StreamWorld.validate(a.export_state()),"Unpaid metabolism takes nothing from any pool: the ledger balances")
	# The old forced-starvation setup (no energy, no body): still nobody starves.
	var z:=StreamWorld.new(9)
	z.state.supply_scale=0.0
	for pool: String in StreamWorld.POOLS:
		z.state.resources[pool]=0.0
	for animal: Dictionary in z.state.animals:
		animal.energy=0.0
		animal.body=0.0
	reset_material(z)
	z.advance_offline(3600)
	check(not z.state.causes.has("starvation") and z.state.animals.size()==12 and absf(z.residual())<0.00001,"Even with no energy and no food an animal does not starve")
	# An ordinary world never meets the floor (S2 probe criterion C1).
	var fed:=StreamWorld.new(42)
	offline(fed,StreamWorld.DAY*10)
	check(fed.state.totals.floor_hits==0,"Ten ordinary days never meet the floor")
	# The last one of a species outlives its lifespan until a companion comes.
	for species: String in StreamWorld.ACTIVE_SPECIES:
		var w:=StreamWorld.new(21,1000)
		var lone: Dictionary=of(w,species)[0]
		only(w,func(x): return x.species!=species or x==lone)
		lone.age=lone.lifespan+1.0
		var arrived: int=-1
		var died: int=-1
		var never_zero: bool=true
		for hour in 30:
			w.advance_offline(3600)
			never_zero=never_zero and w.counts()[species]>=1
			if arrived<0 and of(w,species).any(func(x): return x.id!=lone.id):
				arrived=hour+1
			if died<0 and not w.state.animals.has(lone):
				died=hour+1
		var end: Dictionary=w.state.archive.filter(func(x): return x.id==lone.id)[0] if died>0 else {}
		check(never_zero and arrived>0 and arrived<=24 and died>=arrived and end.get("cause","")=="old age","The last %s outlives its lifespan until a companion arrives (after %d h, within 24), then dies of old age (hour %d)" % [species,arrived,died])
	# A vanished species always comes back within 24 hours.
	var late: Array=[]
	for seed_value in range(1,25):
		for species: String in StreamWorld.ACTIVE_SPECIES:
			var w:=StreamWorld.new(seed_value,1000)
			only(w,func(x): return x.species!=species)
			for hour in 24:
				w.advance_offline(3600)
			if w.counts()[species]<1:
				late.append("%s/%d" % [species,seed_value])
	check(late.is_empty(),"Every vanished species is rescued within 24 hours (24 seeds x 4 species; late: %s)" % str(late))
	# A pending rescue is saved and validated.
	var p:=StreamWorld.new(5,1000)
	only(p,func(x): return x.species!="seahorse")
	p.advance_offline(3600)
	var saved: Dictionary=p.export_state()
	var back:=StreamWorld.new()
	check(saved.has("rescue") and saved.rescue.has("seahorse") and back.restore(saved) and same(back,p),"A pending rescue is saved and restored")
	back.advance_offline(StreamWorld.DAY)
	p.advance_offline(StreamWorld.DAY)
	check(same(back,p) and p.counts().seahorse>0,"The restored rescue arrives as it would have")
	saved.rescue={"yellow_tang":10.0}
	check(not StreamWorld.validate(saved),"A rescue for an unknown species is rejected")
	saved.rescue={"seahorse":NAN}
	check(not StreamWorld.validate(saved),"A non-finite rescue time is rejected")
	var bad: Dictionary=p.export_state()
	bad.totals.erase("floor_hits")
	check(not StreamWorld.validate(bad),"totals.floor_hits is required")

# S2 design numbers (docs/ecology.md "Reef v3 cast sizing", criteria table) and the homes each takes.
const NEW_CAST: Dictionary = {
	"clownfish":{"label":"Clownfish","latin":"Amphiprion ocellaris","cap":3,"mature":45.0,"lifespan":300.0,"body":0.6,"reserve":4.0,"cost":0.2,"bite":0.5,"breed":0.06,"cooldown":12.0,"homes":["anemone"]},
	"seahorse":{"label":"Seahorse","latin":"Hippocampus kuda","cap":4,"mature":60.0,"lifespan":300.0,"body":0.5,"reserve":3.5,"cost":0.16,"bite":0.4,"breed":0.05,"cooldown":14.0,"homes":["hitch"]},
	"royal_gramma":{"label":"Royal gramma","latin":"Gramma loreto","cap":3,"mature":40.0,"lifespan":240.0,"body":0.4,"reserve":3.0,"cost":0.16,"bite":0.4,"breed":0.07,"cooldown":10.0,"homes":["shelter","rock"]}}

func distinct_homes(list: Array) -> bool:
	var seen: Dictionary={}
	for x: Dictionary in list:
		seen[str(x.home)]=true
	return seen.size()==list.size()

# 2026-09-28 redesign (S4): clownfish, seahorse and royal gramma replace the blenny, firefish and
# tang. S4 gives them the simplest behaviour: each lives at a home from the scene (the anemone, a
# hitch point, a cave or rock spot), swims about it by day and rests beside it at night. Their full
# behaviours come in S6-S8.
func new_cast_checks() -> void:
	for species: String in NEW_CAST:
		var want: Dictionary=NEW_CAST[species]
		var cfg: Dictionary=StreamWorld.SPECIES.get(species,{})
		var numbers: bool=cfg.get("pool")=="microfauna" and cfg.get("initial")==2 and cfg.get("brood")==2 and cfg.get("k_food")==10.0 and StreamWorld.CAP.get(species)==want.cap
		for k: String in ["label","latin","mature","lifespan","body","reserve","cost","bite","breed","cooldown"]:
			numbers=numbers and cfg.get(k)==want[k]
		check(numbers,"%s: the S2 design numbers, microfauna, habitat for %d, opening pair" % [want.label,want.cap])
		check(absf(cfg.get("cost",0.0)-0.8*cfg.get("bite",0.0)*0.5)<0.000001,"%s breaks even at food 10 like the rest of the cast" % want.label)
	# The opening pairs, at their homes.
	var w:=StreamWorld.new(42,1000)
	for species: String in NEW_CAST:
		var pair: Array=of(w,species)
		var r: float=StreamWorld.HOME[species].radius
		check(pair.size()==2 and pair.any(func(x): return x.sex=="female") and pair.any(func(x): return x.sex=="male") and pair.all(func(x): return in_band(w,x) and x.home.kind in NEW_CAST[species].homes and home_dist(x)<=r),"A new world opens with a %s pair at its home, in its band" % species)
	check(of(w,"clownfish").all(func(x): return x.home==of(w,"clownfish")[0].home),"The clownfish share the anemone")
	# Up to the caps every fish has a home: the anemone holds all clownfish, one hitch or cave each.
	var full:=StreamWorld.new(7,1000)
	for species: String in NEW_CAST:
		while of(full,species).size()<StreamWorld.CAP[species]:
			full.spawn(species,50.0)
	var anemone: Dictionary=full.scene.effects("anemone",full.scene.default_decor().anemone).anemone
	check(of(full,"clownfish").size()==StreamWorld.CAP.clownfish and of(full,"clownfish").all(func(x): return x.home.kind=="anemone") and anemone.capacity>=StreamWorld.CAP.clownfish,"Clownfish up to their cap all live in the anemone (capacity %d)" % anemone.capacity)
	check(of(full,"seahorse").size()==StreamWorld.CAP.seahorse and distinct_homes(of(full,"seahorse")),"Seahorses up to their cap each hold a hitch point of their own")
	check(of(full,"royal_gramma").size()==StreamWorld.CAP.royal_gramma and distinct_homes(of(full,"royal_gramma")),"Royal grammas up to their cap each hold a cave or rock spot of their own")
	check(full.state.animals.filter(func(x): return x.has("home")).all(func(x): return x.home_x>=100.0 and x.home_x<=1180.0 and x.home_y>=full.band(x.species)[0] and x.home_y<=full.band(x.species)[1]),"Every home lies in its species' band and the swimming width")
	# By day they swim about their homes.
	var d:=StreamWorld.new(42,1000)
	d.state.light_hour=12.0
	var seen: Dictionary={}
	var band_ok: bool=true
	var far: Dictionary={}
	var travelled: Dictionary={}
	for i in 9000:
		var before: Dictionary={}
		for x: Dictionary in d.state.animals:
			before[x.id]=Vector2(x.x,x.y)
		d.advance_live(0.2)
		for x: Dictionary in d.state.animals:
			if not x.has("home"):
				continue
			seen[x.activity]=true
			band_ok=band_ok and in_band(d,x)
			far[x.species]=maxf(far.get(x.species,0.0),home_dist(x))
			travelled[x.id]=travelled.get(x.id,0.0)+Vector2(x.x,x.y).distance_to(before.get(x.id,Vector2(x.x,x.y)))
	check(band_ok,"The new fish keep to their depth bands")
	check(seen.has("Hovering") and seen.keys().all(func(k): return k in ["Hovering","Resting"]),"By day the new fish swim about their homes (%s)" % str(seen.keys()))
	for species: String in NEW_CAST:
		var r: float=StreamWorld.HOME[species].radius
		check(far.get(species,INF)<=2.0*r,"A %s stays near its home (at most %.0f px away, limit %.0f)" % [species,far.get(species,INF),2.0*r])
	check(travelled.size()==6 and travelled.values().all(func(v): return v>100.0),"Every new fish moves about (%s px in 30 min)" % str(travelled.values().map(func(v): return int(v))))
	# At night they rest beside their homes.
	var n:=StreamWorld.new(42,1000)
	n.state.light_hour=1.0
	n.advance_live(300)
	check(n.state.animals.filter(func(x): return x.has("home")).all(func(x): return x.activity=="Resting" and home_dist(x)<=StreamWorld.HOME[x.species].radius),"At night the new fish rest beside their homes")
	check(absf(d.residual())<0.00001 and StreamWorld.validate(d.export_state()) and StreamWorld.validate(n.export_state()),"New-cast worlds conserve material and validate")
	# They eat microfauna.
	var grazed:=StreamWorld.new(8,1000)
	var bare:=StreamWorld.new(8,1000)
	for x: Dictionary in grazed.state.animals:
		x.energy=1.0
	only(grazed,func(x): return x.has("home"))
	only(bare,func(x): return false)
	# (No rescue during the comparison: the absent species are held back.)
	grazed.state.rescue={"green_chromis":1.0e12}
	bare.state.rescue={"green_chromis":1.0e12,"clownfish":1.0e12,"seahorse":1.0e12,"royal_gramma":1.0e12}
	offline(grazed,StreamWorld.DAY*2)
	offline(bare,StreamWorld.DAY*2)
	check(grazed.state.animals.size()==6 and grazed.state.animals.all(func(x): return x.energy>1.0) and grazed.state.resources.microfauna<bare.state.resources.microfauna,"Hungry new fish feed on microfauna")
	for species: String in NEW_CAST:
		# A hungry fish goes for a pinch above its home and eats it.
		var f:=StreamWorld.new(42,1000)
		var fish: Dictionary=of(f,species)[0]
		fish.energy=1.0
		only(f,func(x): return x==fish)
		f.state.light_hour=12.0
		f.feed(fish.x)
		var chased: bool=false
		var kept: bool=true
		for i in 900:
			f.advance_live(0.2)
			chased=chased or fish.activity=="Feeding"
			kept=kept and in_band(f,fish)
		var bites: Array=f.state.events.filter(func(e): return e.kind=="ate" and e.id==fish.id and e.live and absf(e.food_x-e.x)<StreamWorld.FOOD.eat)
		check(chased and not bites.is_empty() and fish.energy>1.0 and kept and absf(f.residual())<0.00001,"A hungry %s chases drifting food above its home and eats it (%d bites)" % [species,bites.size()])
		# A tap startles it; it darts away inside its band, settles, and goes home.
		var t:=StreamWorld.new(42,1000)
		t.state.light_hour=12.0
		var tf: Dictionary=of(t,species)[0]
		var tap:=Vector2(tf.x+30,tf.y)
		var start: float=Vector2(tf.x,tf.y).distance_to(tap)
		check(t.startle(tap.x,tap.y,1.0)>=1 and tf.activity=="Startled","A tap startles a nearby %s" % species)
		t.advance_live(StreamWorld.STARTLE.seconds)
		var moved: float=Vector2(tf.x,tf.y).distance_to(tap)-start
		check(moved>(5.0 if species=="seahorse" else 10.0) and in_band(t,tf),"The %s darts away from the tap inside its band (%.1f px)" % [species,moved])
		t.advance_live(60)
		check(tf.activity!="Startled" and home_dist(tf)<=2.0*StreamWorld.HOME[species].radius,"Then it settles and returns to its home")
	# Young are born beside their own home; a full habitat sends them away; arrivals swim home.
	var b:=StreamWorld.new(3,1000)
	for species: String in NEW_CAST:
		var mom: Dictionary=of(b,species).filter(func(x): return x.sex=="female")[0]
		mom.energy=StreamWorld.SPECIES[species].reserve
		var cursor: int=b.state.next_event-1
		b._breed(mom)
		var born: Array=StreamWorld.events_after(b.state.events,cursor).filter(func(e): return e.kind=="birth")
		var kid: Dictionary=by_id(b,born[0].id) if born.size()==1 else {}
		check(not kid.is_empty() and kid.parent==mom.id and in_band(b,kid) and kid.home.kind in NEW_CAST[species].homes and home_dist(kid)<=StreamWorld.HOME[species].radius+30.0 and distinct_homes(of(b,species).filter(func(x): return x.home.kind!="anemone")),"A young %s is born beside a home of its own" % species)
		while of(b,species).size()<StreamWorld.CAP[species]:
			b.spawn(species,50.0)
		var dispersed: int=b.state.totals.dispersal
		mom.energy=StreamWorld.SPECIES[species].reserve
		reset_material(b)
		b._breed(mom)
		check(b.state.totals.dispersal==dispersed+1 and of(b,species).size()==StreamWorld.CAP[species] and absf(b.residual())<0.00001,"With every %s home taken, a young one disperses" % species)
	for species: String in NEW_CAST:
		var c:=StreamWorld.new(4,1000)
		c.state.light_hour=12.0
		var came: Dictionary=c._arrive(species)
		check(not came.is_empty() and came.x in [130.0,1150.0] and in_band(c,came) and came.home.kind in NEW_CAST[species].homes,"An arriving %s comes in at the edge, in its band, with a home" % species)
		c.advance_live(600)
		check(home_dist(came)<=2.0*StreamWorld.HOME[species].radius,"Then it swims home (%.0f px from it after 10 min)" % home_dist(came))
	# A home is required and checked.
	var v: Dictionary=StreamWorld.new(5,1000).export_state()
	var fish_v: Dictionary=v.animals.filter(func(x): return x.species=="seahorse")[0]
	fish_v.erase("home")
	check(not StreamWorld.validate(v),"A new fish without a home is rejected")
	v=StreamWorld.new(5,1000).export_state()
	v.animals.filter(func(x): return x.species=="royal_gramma")[0].home.kind="burrow"
	check(not StreamWorld.validate(v),"An unknown home kind is rejected")
	v=StreamWorld.new(5,1000).export_state()
	v.animals.filter(func(x): return x.species=="clownfish")[0].home_x="620"
	check(not StreamWorld.validate(v),"A non-numeric home point is rejected")
	v=StreamWorld.new(5,1000).export_state()
	v.scene="lagoon"
	check(not StreamWorld.validate(v),"An unknown scene is rejected")
	# The lure draws only the chromis school for now.
	var l:=StreamWorld.new(42,1000)
	l.state.light_hour=12.0
	l.set_lure(Vector2(620,420))
	var curious: bool=false
	for i in 600:
		l.advance_live(0.2)
		curious=curious or l.state.animals.any(func(x): return x.has("home") and x.activity=="Curious")
	check(not curious,"The new fish ignore the cursor lure")
