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

# A shrimp as older saves carried it (the species left the cast on 2026-09-23),
# built from a fish record so it has every field validate() requires.
func legacy_shrimp(w: StreamWorld, age: float, parent: int = 0) -> Dictionary:
	var s: Dictionary=chromis(w)[0].duplicate(true)
	s.merge({"id":w.state.next_id,"species":"shrimp","name":"Cherry shrimp "+str(w.state.next_id),"age":age,"parent":parent,"body":0.3,"energy":2.0,"recent":[],"y":StreamWorld.floor_y(s.x),"activity":"Grazing","next_molt":age+12.0},true)
	w.state.next_id+=1
	w.state.animals.append(s)
	return s

# A save from before 2026-09-23: three juvenile shrimp were taken by fish.
func legacy_predation_save() -> Dictionary:
	var w:=StreamWorld.new(21,1000)
	w.advance_offline(3600)
	var fish: Dictionary=chromis(w)[0]
	for i in 3:
		var young: Dictionary=legacy_shrimp(w,4)
		w._event("feeding",fish,fish.name+" caught a young shrimp.",{"target":young.id})
		w._remove(young,"predation")
		w.state.events[-1].target=fish.id
	w.state.totals.predation=3
	return w.export_state()

# Hungry fish right beside newborn fish on a bare bed (the old worst case had shrimplets).
func no_predation() -> bool:
	for offline: bool in [false,true]:
		var w:=StreamWorld.new(42,1000)
		w.state.resources.stem=0.0
		for i in 2:
			var young: Dictionary=w.spawn("green_chromis",3)
			young.x=900.0+i*40
		for f: Dictionary in w.state.animals:
			if f.species in StreamWorld.DEPTH:
				f.energy=StreamWorld.SPECIES[f.species].reserve*0.4
				f.x=910.0
				f.y=StreamWorld.DEPTH[f.species][1]
		if offline:
			w.advance_offline(StreamWorld.DAY*3)
		else:
			w.advance_live(1800)
		if w.state.totals.predation!=0 or w.state.causes.has("predation") or w.state.events.any(func(e): return e.kind=="feeding"):
			return false
	return not StreamWorld.new().has_method("exposure")

func _initialize() -> void:
	var start: int=Time.get_ticks_msec()
	var a:=StreamWorld.new(42,1000)
	var b:=StreamWorld.new(42,1000)
	# The one place these tests pin the cast (user decision 2026-09-25: no garden eels); others read the constants.
	check(StreamWorld.ACTIVE_SPECIES==["lawnmower_blenny","purple_firefish","green_chromis","yellow_tang"] and StreamWorld.CAP=={"lawnmower_blenny":3,"purple_firefish":4,"green_chromis":8,"yellow_tang":2} and StreamWorld.habitat_cap()==17 and StreamWorld.ACTIVE_SPECIES.map(func(k): return StreamWorld.SPECIES[k].initial)==[2,2,6,2] and StreamWorld.RESCUE_AT==1,"Reef cast: blenny/purple firefish/chromis/yellow tang, caps 3/4/8/2 (17), opening 2/2/6/2, rescue at one")
	var opening: Dictionary={}
	for k: String in StreamWorld.ACTIVE_SPECIES:
		opening[k]=StreamWorld.SPECIES[k].initial
	check(a.counts()==opening and a.state.animals.size()==opening.values().reduce(func(x,y): return x+y),"A new world opens with exactly the opening cast, no threadfin, shrimp or hatchetfish")
	check(a.state.animals.all(func(x): return x.x>=150 and x.x<=1130),"Opening fish are spread inside the stream")
	check(a.spawn("crayfish").is_empty() and a.spawn("shrimp").is_empty() and a.spawn("hatchet").is_empty() and a.spawn("threadfin").is_empty() and a.spawn("garden_eel").is_empty(),"Removed species cannot spawn")
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
	# Deliberately empty food and reserves to force real starvation.
	a=StreamWorld.new(9)
	a.state.supply_scale=0.0
	for pool: String in StreamWorld.POOLS:
		a.state.resources[pool]=0.0
	for animal: Dictionary in a.state.animals:
		animal.energy=0.0
		animal.body=0.0
	reset_material(a)
	a.advance_offline(60)
	check(a.state.totals.death>0,"Starvation remains possible")
	check(absf(a.residual())<0.00001,"Starvation recycles remaining material")
	a=StreamWorld.new(33)
	var gone: Dictionary=a.state.animals[0]
	a._remove(gone,"old age")
	var deaths: int=a.state.totals.death
	a._remove(gone,"old age")
	check(a.state.totals.death==deaths,"An individual is never removed twice")
	check(absf(a.residual())<0.00001,"Death returns material as detritus")
	check(a.state.archive[-1].cause=="old age","Cause of death remains inspectable")
	# Predation was removed on 2026-09-23; saves made before still load.
	var legacy: Dictionary=legacy_predation_save()
	check(StreamWorld.validate(legacy),"Save with past predation deaths and feeding events validates")
	var old_world:=StreamWorld.new()
	check(old_world.restore(legacy),"Save with past predation restores")
	check(StreamStore.save(path,old_world)==OK and old_world.restore(StreamStore.read(path)),"Save with past predation round-trips through the store")
	check(old_world.state.archive.filter(func(x): return x.get("cause")=="predation").size()==3 and old_world.state.events.filter(func(e): return e.kind=="feeding").size()==3,"Past predation records remain inspectable")
	old_world.advance_offline(StreamWorld.DAY)
	old_world.advance_live(60)
	check(old_world.state.totals.predation==3 and old_world.state.causes.predation==3,"Past predation totals stay as saved")
	check(StreamWorld.validate(old_world.export_state()),"Advanced legacy save still validates")
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
	# Molting left with the shrimp: a due next_molt on a fish does nothing.
	a=StreamWorld.new(15)
	a.state.animals[0].next_molt=a.state.animals[0].age
	a.advance_offline(60)
	check(a.state.totals.molt==0 and a.state.animals.all(func(x): return x.activity!="Molting"),"Nothing molts any more")
	# Existing stream saves retain fish; removed crayfish get recorded departures.
	a=StreamWorld.new(31)
	var retained_ids: Array=[]
	for animal: Dictionary in a.state.animals:
		retained_ids.append(animal.id)
	var old_cray: Dictionary=a.state.animals[0].duplicate(true)
	old_cray.id=100
	old_cray.species="crayfish"
	old_cray.name="Cobalt"
	a.state.animals.append(old_cray)
	a.state.next_id=101
	reset_material(a)
	b=StreamWorld.new()
	check(b.restore(a.export_state()),"Earlier stream save remains readable")
	check(b.state.animals.all(func(x): return x.species!="crayfish") and b.state.totals.departure==1,"Removed crayfish recorded as departure")
	var restored_ids: Array=[]
	for animal: Dictionary in b.state.animals:
		restored_ids.append(animal.id)
	check(retained_ids==restored_ids,"Cast update preserves fish and eel identities")
	check(absf(b.residual())<0.00001,"Cast update accounts for departing material")
	c=StreamWorld.new()
	c.restore(b.export_state())
	check(c.state.totals.departure==1,"Cast update is idempotent")
	a=StreamWorld.new(9)
	var swimmer: Dictionary=chromis(a)[0]
	swimmer.activity="Schooling"
	swimmer.tx=swimmer.x+100
	swimmer.ty=swimmer.y
	swimmer.decision_at=1000
	var old_x: float=swimmer.x
	a.advance_live(0.2)
	check(swimmer.vx<=3.0001 and swimmer.x>old_x,"Fish accelerate gradually from rest")
	ecosystem_checks()
	shrimp_departure_checks()
	hatchet_departure_checks()
	eel_checks()
	feeding_checks()
	startle_checks()
	lure_checks()
	blenny_checks()
	firefish_checks()
	chromis_checks()
	tang_checks()
	reef_cast_checks()
	var acceptance=preload("res://tests/ecology_acceptance.gd")
	# Gates derived from the configured cast (docs/ecology.md "Acceptance gates"), 180 days:
	# 7 openers must reach old age (6 chromis, the older firefish), the earliest by day 76,
	# and 7 + 5 open places = 12 offspring; band 12..17 (docs/ecology.md, four-species cast 2026-09-25).
	check(acceptance.certain_old_age(180)==7 and acceptance.first_old_age_bound()==76 and acceptance.offspring_needed(180)==12 and acceptance.population_band()==[12,17],"Derived gates: 7 old-age deaths by day 76, 12 offspring, band 12-17")
	var need: int=acceptance.offspring_needed(180)
	check(acceptance.reproduction_passes({"births":6,"dispersal":need-6,"arrivals":2,"days":180}),"Dispersed offspring count toward reproduction")
	check(not acceptance.reproduction_passes({"births":6,"dispersal":need-7,"arrivals":2,"days":180}),"One offspring short of the threshold fails")
	check(acceptance.old_age_passes({"old_age":7,"first_old_age_day":76,"days":180}) and not acceptance.old_age_passes({"old_age":6,"first_old_age_day":40,"days":180}) and not acceptance.old_age_passes({"old_age":9,"first_old_age_day":77,"days":180}),"Old-age gate: at least 7, the first by day 76")
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
			var band: Array=StreamWorld.DEPTH[a.species]
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
			w.spawn(["green_chromis","purple_firefish"][i%2],1)
		for animal: Dictionary in w.state.animals:
			var base: float=StreamWorld.SPECIES[animal.species].lifespan
			spans_ok=spans_ok and animal.lifespan>=base*0.85 and animal.lifespan<=base*1.15
			if animal.age>1:
				# R11 ranges: fish [40, 150], yellow tang [130, 260] (adults).
				var span: Array=StreamWorld.OPENING_AGE.get(animal.species,StreamWorld.OPENING_AGE.fish)
				var lo: float=span[0]
				var hi: float=span[1]
				ages_ok=ages_ok and animal.age>=lo and animal.age<=hi and animal.age<animal.lifespan
	check(spans_ok,"Lifespans within 0.85-1.15 of species lifespan")
	check(ages_ok,"Opening ages staggered within R11 ranges")
	check(StreamWorld.SPECIES.green_chromis.lifespan==180.0 and StreamWorld.SPECIES.garden_eel.lifespan==365.0,"Species lifespans 180/365")
	# R10: a nearly vanished species is rescued from upstream; adults never wander off.
	w=StreamWorld.new(11)
	for animal: Dictionary in w.state.animals.duplicate():
		if animal.species=="green_chromis":
			w.state.animals.erase(animal)
	reset_material(w)
	# Rescue is a 1/96-per-hour draw: 24 days leave a 0.2% chance of none.
	for i in 8:
		if w.counts().green_chromis==0:
			w.advance_offline(StreamWorld.MAX_AWAY)
	check(w.counts().green_chromis>0,"Rescue arrival restores a missing species")
	check(w.state.totals.departure==0,"No random adult departures")
	# R12: a genuine v1 save upgrades with identities, names and lineage intact.
	var f:=FileAccess.open("res://tests/fixtures/v1-world.var",FileAccess.READ)
	var v1: Dictionary=f.get_var()
	f.close()
	check(v1.version==1 and StreamWorld.validate(v1),"v1 save still validates")
	var up:=StreamWorld.new()
	check(up.restore(v1),"v1 save restores")
	check(up.state.version==StreamWorld.VERSION and StreamWorld.VERSION==2,"Upgraded save is version 2")
	var kept: Array=[]
	var leaving: int=0
	for animal: Dictionary in v1.animals:
		if animal.species in StreamWorld.ACTIVE_SPECIES:
			kept.append([animal.id,animal.name,animal.parent,animal.sex])
		else:
			leaving+=1
	var now_ids: Array=[]
	var lifespans_ok: bool=true
	for animal: Dictionary in up.state.animals.filter(func(x): return x.id<v1.next_id):
		now_ids.append([animal.id,animal.name,animal.parent,animal.sex])
		lifespans_ok=lifespans_ok and animal.has("lifespan") and animal.lifespan>animal.age
	check(kept==now_ids,"Upgrade keeps ids, names and lineage")
	check(lifespans_ok,"Upgrade assigns lifespans")
	check(leaving==18 and up.state.totals.departure==v1.totals.departure+leaving and up.counts().keys().all(func(k): return k in StreamWorld.ACTIVE_SPECIES),"Upgrade records the crayfish, 8 shrimp, 5 hatchetfish and 4 threadfin as departures")
	check(up.state.archive.filter(func(x): return x.cause=="departure").map(func(x): return x.id)==v1.animals.filter(func(x): return x.species not in StreamWorld.ACTIVE_SPECIES).map(func(x): return x.id),"Departed v1 shrimp, hatchetfish, threadfin and crayfish are archived with their ids")
	check(StreamWorld.POOLS.all(func(k): return up.state.resources.has(k)),"Upgrade adds every material pool")
	check(absf(up.residual())<0.00001,"Upgrade conserves material")
	check(StreamWorld.validate(up.export_state()),"Upgraded state validates as v2")
	up.advance_offline(StreamWorld.DAY)
	check(absf(up.residual())<0.00001,"Upgraded world keeps conserving")
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

# 2026-09-23 user decision: no shrimp. Shrimp in a loaded save leave once, as recorded
# departures (like the crayfish before them); their history stays readable.
func shrimp_departure_checks() -> void:
	var w:=StreamWorld.new(42,1000)
	w.advance_offline(3600)
	var fish_before: Array=w.state.animals.map(func(x): return [x.id,x.name,x.parent,x.sex,x.species])
	var mom: Dictionary=legacy_shrimp(w,40)
	mom.sex="female"
	mom.tint=0.6
	mom.last_breed=mom.age
	mom.brood_until=w.state.elapsed+2*StreamWorld.DAY
	var kid: Dictionary=legacy_shrimp(w,5,mom.id)
	kid.tint=0.62
	var male: Dictionary=legacy_shrimp(w,30)
	male.sex="male"
	male.tint=0.4
	male.activity="Molting"
	male.molting_until=w.state.elapsed/StreamWorld.DAY+0.1
	var dead: Dictionary=legacy_shrimp(w,118)
	dead.tint=0.5
	w._event("berried",mom,mom.name+" is carrying eggs.",{"until":mom.brood_until})
	w._event("molt",male,male.name+" molted and is sheltering while its shell hardens.",{"until":male.molting_until*StreamWorld.DAY})
	w._event("birth",kid,"A young cherry shrimp was born to "+mom.name+".",{"target":mom.id})
	w._remove(dead,"old age")
	reset_material(w)
	var saved: Dictionary=w.export_state()
	var leaving: Array=[mom.duplicate(true),kid.duplicate(true),male.duplicate(true)]
	var mass: float=0.0
	for x: Dictionary in leaving:
		mass+=x.body+x.energy
	check(StreamWorld.validate(saved),"Save with shrimp mid-brood, tints and a molt validates")
	var r:=StreamWorld.new()
	check(r.restore(saved),"Save with shrimp restores")
	var fresh: Array=StreamWorld.events_after(r.state.events,saved.next_event-1)
	check(r.counts().keys()==StreamWorld.ACTIVE_SPECIES and r.state.animals.all(func(x): return x.species!="shrimp"),"No shrimp remain after loading")
	check(r.state.totals.departure==saved.totals.departure+3 and fresh.size()==3 and fresh.all(func(e): return e.kind=="departure" and e.live==false) and ids(fresh)==ids(leaving),"Each shrimp leaves once as a departure event that does not play")
	check(r.state.animals.map(func(x): return [x.id,x.name,x.parent,x.sex,x.species])==fish_before,"Fish and eels keep their ids, names, lineage and sex")
	var records: Array=r.state.archive.slice(-3)
	var same_records: bool=records.size()==3
	for i in mini(3,records.size()):
		var x: Dictionary=records[i]
		var was: Dictionary=leaving[i]
		same_records=same_records and x.cause=="departure" and x.id==was.id and x.name==was.name and x.parent==was.parent and x.sex==was.sex and x.tint==was.tint and x.recent.size()>=1
	check(same_records,"Departed shrimp are archived with id, name, parent, sex and tint")
	check(records.size()==3 and records[1].parent==mom.id and not records[0].has("brood_until"),"Lineage (young to mother) survives; the unhatched brood is cancelled")
	check(r.state.archive.filter(func(x): return x.id==dead.id and x.cause=="old age").size()==1,"A shrimp that died earlier stays in the archive")
	check(["berried","molt","birth"].all(func(k): return r.state.events.any(func(e): return e.kind==k and e.id in ids(leaving))),"Past shrimp events stay in the journal")
	check(absf(r.state.ledger.out-saved.ledger.out-mass)<0.000001 and absf(r.residual())<0.00001,"Departing shrimp material leaves through the ledger")
	check(StreamWorld.validate(r.export_state()),"Save after the departures validates")
	check(eels(r).is_empty() and r.state.totals.arrival==saved.totals.arrival,"Loading a reef save adds no arrivals")
	offline(r,StreamWorld.DAY*3)
	check(StreamWorld.events_after(r.state.events,saved.next_event-1).all(func(e): return not (e.kind in ["birth","dispersal"] and (e.get("target")==mom.id or e.id==mom.id))) and absf(r.residual())<0.00001,"The cancelled brood never hatches")
	var again:=StreamWorld.new()
	var archived: int=r.state.archive.size()
	var departures: int=r.state.totals.departure
	check(again.restore(r.export_state()) and again.state.totals.departure==departures and again.state.archive.size()==archived and absf(again.residual())<0.00001,"Loading again records no second departure")
	var path: String="user://qa-shrimp.world"
	var from_disk:=StreamWorld.new()
	check(StreamStore.save(path,w)==OK and from_disk.restore(StreamStore.read(path)) and from_disk.counts().keys()==StreamWorld.ACTIVE_SPECIES and from_disk.state.totals.departure==saved.totals.departure+3,"Shrimp departure also happens through the store")
	for suffix: String in ["",".bak",".tmp"]:
		DirAccess.remove_absolute(path+suffix)
	# The real pre-eel fixture: six tinted shrimp, one carrying eggs.
	var f:=FileAccess.open("res://tests/fixtures/v2-pre-eel.var",FileAccess.READ)
	var old: Dictionary=f.get_var()
	f.close()
	var shrimp: Array=old.animals.filter(func(x): return x.species=="shrimp")
	check(shrimp.size()==6 and shrimp.all(func(x): return x.has("tint")) and shrimp.filter(func(x): return x.has("brood_until")).size()==1,"Fixture has six tinted shrimp, one mid-brood")
	var up:=StreamWorld.new()
	check(up.restore(old),"Pre-eel save restores")
	var gone: Array=StreamWorld.events_after(up.state.events,old.next_event-1).filter(func(e): return e.kind=="departure")
	var leavers: Array=old.animals.filter(func(x): return x.species not in StreamWorld.ACTIVE_SPECIES)
	check(up.counts().keys()==StreamWorld.ACTIVE_SPECIES and leavers.size()==15 and up.state.totals.departure==old.totals.departure+15 and ids(gone)==ids(leavers),"All six fixture shrimp, four hatchetfish and five threadfin depart, once each")
	check(up.state.archive.filter(func(x): return x.species=="shrimp" and x.cause=="departure" and x.has("tint") and not x.has("brood_until")).size()==6,"Fixture shrimp are archived with tints, the brood cancelled")
	check(up.state.totals.birth==old.totals.birth and absf(up.residual())<0.00001 and StreamWorld.validate(up.export_state()),"No young from the cancelled brood; material balances")
	# New animals carry no shrimp-only fields and nothing molts or broods.
	var n:=StreamWorld.new(42,1000)
	var cursor: int=n.state.next_event-1
	offline(n,StreamWorld.DAY*20)
	var seen: Array=StreamWorld.events_after(n.state.events,cursor)
	check(n.state.animals.all(func(x): return not x.has("tint") and not x.has("brood_until")) and not seen.any(func(e): return e.kind in ["berried","molt"]) and seen.any(func(e): return e.kind in ["birth","dispersal"]),"Fish breed; no tint, brood or molt appears")
	# Legacy fields are still checked when present.
	old=legacy_predation_save()
	old.animals[0].brood_until="soon"
	check(not StreamWorld.validate(old),"Non-numeric brood_until rejected")
	old.animals[0].brood_until=-1.0
	check(not StreamWorld.validate(old),"Negative brood_until rejected")
	old.animals[0].brood_until=NAN
	check(not StreamWorld.validate(old),"Non-finite brood_until rejected")
	old.animals[0].erase("brood_until")
	old.animals[0].tint=1.5
	check(not StreamWorld.validate(old),"Tint above 1 rejected")
	old.animals[0].tint=-0.1
	check(not StreamWorld.validate(old),"Tint below 0 rejected")
	old.animals[0].tint="red"
	check(not StreamWorld.validate(old),"Non-numeric tint rejected")

# 2026-09-23 user decision: no marbled hatchetfish. Live hatchetfish in a loaded save leave
# once, exactly like the shrimp and crayfish; their history stays readable.
func hatchet_departure_checks() -> void:
	var w:=StreamWorld.new(42,1000)
	w.advance_offline(3600)
	var kept: Array=w.state.animals.map(func(x): return [x.id,x.name,x.parent,x.sex,x.species])
	var leaving: Array=[]
	for i in 3:
		var h: Dictionary=chromis(w)[0].duplicate(true)
		h.merge({"id":w.state.next_id,"species":"hatchet","name":["Marble","Mica","Dapple"][i],"age":60.0-i*25,"parent":leaving[0].id if i==2 else 0,"sex":["female","male","female"][i],"y":150.0,"ty":150.0,"activity":"Surface feeding","recent":[]},true)
		w.state.next_id+=1
		w.state.animals.append(h)
		leaving.append(h)
	w._event("birth",leaving[2],"A young marbled hatchetfish was born to Marble.",{"target":leaving[0].id})
	reset_material(w)
	var saved: Dictionary=w.export_state()
	var mass: float=0.0
	for x: Dictionary in leaving:
		mass+=x.body+x.energy
	check(StreamWorld.validate(saved),"Save with live hatchetfish validates")
	var r:=StreamWorld.new()
	check(r.restore(saved),"Save with live hatchetfish restores")
	var fresh: Array=StreamWorld.events_after(r.state.events,saved.next_event-1)
	check(r.counts().keys()==StreamWorld.ACTIVE_SPECIES and r.state.animals.all(func(x): return x.species!="hatchet"),"No hatchetfish remain after loading")
	check(r.state.totals.departure==saved.totals.departure+3 and fresh.size()==3 and fresh.all(func(e): return e.kind=="departure" and e.live==false) and ids(fresh)==ids(leaving),"Each hatchetfish leaves once as a departure event that does not play")
	check(r.state.animals.map(func(x): return [x.id,x.name,x.parent,x.sex,x.species])==kept,"Threadfin and eels keep their ids, names, lineage and sex")
	var records: Array=r.state.archive.slice(-3)
	check(records.map(func(x): return [x.id,x.name,x.parent,x.sex,x.species,x.cause])==leaving.map(func(x): return [x.id,x.name,x.parent,x.sex,"hatchet","departure"]),"Departed hatchetfish are archived with id, name, parent and sex")
	check(r.state.events.any(func(e): return e.kind=="birth" and e.id==leaving[2].id and e.target==leaving[0].id),"Past hatchetfish events stay in the journal")
	check(absf(r.state.ledger.out-saved.ledger.out-mass)<0.000001 and absf(r.residual())<0.00001 and StreamWorld.validate(r.export_state()),"Departing hatchetfish material leaves through the ledger")
	var again:=StreamWorld.new()
	check(again.restore(r.export_state()) and again.state.totals.departure==r.state.totals.departure and again.state.archive.size()==r.state.archive.size(),"Loading again records no second hatchetfish departure")
	offline(again,StreamWorld.DAY*3)
	check(again.state.animals.all(func(x): return x.species!="hatchet") and absf(again.residual())<0.00001,"Hatchetfish never return (no birth or arrival)")

func eels(w: StreamWorld) -> Array:
	return w.state.animals.filter(func(x): return x.species=="garden_eel")

func at_burrow(e: Dictionary) -> bool:
	return e.has("burrow_x") and e.x==e.burrow_x and e.y==e.burrow_y and absf(e.burrow_y-StreamWorld.floor_y(e.burrow_x))<0.0001 and e.get("vx",0.0)==0.0 and e.get("vy",0.0)==0.0

func apart(list: Array) -> bool:
	for i in list.size():
		for j in range(i+1,list.size()):
			if absf(list[i].burrow_x-list[j].burrow_x)<30:
				return false
	return true

# A garden eel as reef saves from 2026-09-23..25 carried it (the species left the cast on
# 2026-09-25), built from a firefish record so it has every field validate() requires.
func legacy_eel(w: StreamWorld, x: float, sex: String) -> Dictionary:
	var e: Dictionary=firefish(w)[0].duplicate(true)
	e.erase("hover_y")
	e.merge({"id":w.state.next_id,"species":"garden_eel","name":"Dune" if sex=="female" else "Sprig","sex":sex,"age":180.0,"lifespan":365.0,"body":0.9,"energy":3.0,"x":x,"y":StreamWorld.floor_y(x),"tx":x,"ty":StreamWorld.floor_y(x),"burrow_x":x,"burrow_y":StreamWorld.floor_y(x),"activity":"Swaying","extend":1.0,"recent":[]},true)
	w.state.next_id+=1
	w.state.animals.append(e)
	return e

# 2026-09-25 user decision: no garden eels. Live eels in a loaded save leave once, as recorded
# departures (like the threadfin, hatchetfish and shrimp before them); their history stays readable.
func eel_checks() -> void:
	var cfg: Dictionary=StreamWorld.SPECIES.get("garden_eel",{})
	check(cfg.get("label")=="Spotted garden eel" and cfg.get("initial")==0 and "garden_eel" not in StreamWorld.ACTIVE_SPECIES and not StreamWorld.CAP.has("garden_eel") and "garden_eel" not in StreamWorld.HOMES and "garden_eel" not in StreamWorld.REEF_CAST,"Garden eel is a legacy entry only: not active, no habitat, no opening")
	var fresh_world:=StreamWorld.new(42,1000)
	check(eels(fresh_world).is_empty() and not fresh_world.counts().has("garden_eel"),"A new world has no garden eels")
	var w:=StreamWorld.new(42,1000)
	w.advance_offline(3600)
	var kept: Array=w.state.animals.map(func(x): return [x.id,x.name,x.parent,x.sex,x.species])
	var mom: Dictionary=legacy_eel(w,650.0,"female")
	var dad: Dictionary=legacy_eel(w,684.0,"male")
	w._event("arrival",mom,"A spotted garden eel arrived from upstream.")
	w._event("birth",dad,"A young spotted garden eel was born to Dune.",{"target":mom.id})
	reset_material(w)
	var saved: Dictionary=w.export_state()
	saved.eel_colony=true
	var leaving: Array=[mom.duplicate(true),dad.duplicate(true)]
	var mass: float=0.0
	for x: Dictionary in leaving:
		mass+=x.body+x.energy
	check(StreamWorld.validate(saved),"Save with live garden eels validates")
	var r:=StreamWorld.new()
	check(r.restore(saved),"Save with live garden eels restores")
	var fresh: Array=StreamWorld.events_after(r.state.events,saved.next_event-1)
	check(eels(r).is_empty() and r.counts().keys()==StreamWorld.ACTIVE_SPECIES,"No garden eels remain after loading")
	check(r.state.totals.departure==saved.totals.departure+2 and fresh.size()==2 and fresh.all(func(e): return e.kind=="departure" and e.live==false) and ids(fresh)==ids(leaving) and fresh.all(func(e): return leaving.any(func(l): return l.id==e.id and l.burrow_x==e.x and l.burrow_y==e.y)),"Each eel leaves once, from its burrow, as a departure event that does not play")
	check(r.state.animals.map(func(x): return [x.id,x.name,x.parent,x.sex,x.species])==kept and r.state.totals.arrival==saved.totals.arrival,"The reef cast keeps its ids, names, lineage and sex; nothing arrives in the eels' place")
	var records: Array=r.state.archive.slice(-2)
	check(records.map(func(x): return [x.id,x.name,x.sex,x.species,x.cause,x.burrow_x,x.burrow_y])==leaving.map(func(x): return [x.id,x.name,x.sex,"garden_eel","departure",x.burrow_x,x.burrow_y]),"Departed eels are archived with id, name, sex and burrow")
	check(["arrival","birth"].all(func(k): return r.state.events.any(func(e): return e.kind==k and e.id in ids(leaving))),"Past eel events stay in the journal")
	check(absf(r.state.ledger.out-saved.ledger.out-mass)<0.000001 and absf(r.residual())<0.00001 and StreamWorld.validate(r.export_state()),"Departing eel material leaves through the ledger; the save validates")
	var again:=StreamWorld.new()
	check(again.restore(r.export_state()) and again.state.totals.departure==r.state.totals.departure and again.state.archive.size()==r.state.archive.size() and again.state.totals.arrival==r.state.totals.arrival,"Loading again records no second eel departure and no arrival")
	offline(again,StreamWorld.DAY*3)
	again.advance_live(600)
	check(eels(again).is_empty() and absf(again.residual())<0.00001 and StreamWorld.validate(again.export_state()),"Garden eels never return (no birth, arrival or rescue)")
	# Saves from before the eels no longer receive a pair.
	var old: Dictionary=fixture("v2-pre-eel.var")
	var up:=StreamWorld.new()
	var reef: int=StreamWorld.REEF_CAST.map(func(k): return StreamWorld.SPECIES[k].initial).reduce(func(x,y): return x+y)
	check(up.restore(old) and eels(up).is_empty() and up.state.totals.arrival==old.totals.arrival+reef,"A pre-eel save gets the reef cast and no garden eels")
	var v1w:=StreamWorld.new()
	check(v1w.restore(fixture("v1-world.var")) and eels(v1w).is_empty() and absf(v1w.residual())<0.00001,"A v1 save gets no garden eels either")
	# Validation still checks eel fields in older saves.
	var bad: Dictionary=saved.duplicate(true)
	bad.animals.filter(func(x): return x.species=="garden_eel")[0].erase("burrow_x")
	check(not StreamWorld.validate(bad),"Eel without a burrow rejected")
	bad=saved.duplicate(true)
	bad.animals.filter(func(x): return x.species=="garden_eel")[0].extend=1.5
	check(not StreamWorld.validate(bad),"Extend above 1 rejected")
	bad=saved.duplicate(true)
	bad.eel_colony="yes"
	check(not StreamWorld.validate(bad),"Non-boolean eel_colony rejected")

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
	check(absf(food_mass(full)-pinch)<0.000001 and chromis(full)[0].activity!="Feeding","A full fish ignores food")
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
	check(bare.state.food.is_empty() and absf(bare.residual())<0.00001,"Settled food becomes detritus after a while")
	# Offline catch-up: drifting food just settles and decays, nobody chases it.
	var off:=StreamWorld.new(9,1000)
	off.feed(640.0)
	off.advance_offline(120)
	check(off.state.food.all(func(f): return f.settled) and off.state.animals.all(func(x): return x.activity!="Feeding"),"Offline, drifting food settles without a chase")
	off.advance_offline(StreamWorld.DAY)
	check(off.state.food.is_empty() and absf(off.residual())<0.00001 and StreamWorld.validate(off.export_state()),"Offline food decays and the ledger balances")
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

# Tap the glass: a short dart away (burrow fish hide, firefish_checks); no ecology effect, nothing saved.
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
	var band: Array=StreamWorld.DEPTH.green_chromis
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

func blennies(w: StreamWorld) -> Array:
	return w.state.animals.filter(func(x): return x.species=="lawnmower_blenny")

func on_bed(a: Dictionary) -> bool:
	return absf(a.y-StreamWorld.floor_y(a.x))<0.0001 and a.x>=130 and a.x<=1150

# Keeps only the animals `keep` accepts, then rebalances the ledger.
func only(w: StreamWorld, keep: Callable) -> void:
	for x: Dictionary in w.state.animals.duplicate():
		if not keep.call(x):
			w.state.animals.erase(x)
	reset_material(w)

# 2026-09-24 user decision: a lawnmower blenny grazes biofilm on the bed and rocks,
# perching, grazing and hopping short distances; it never leaves the bottom.
func blenny_checks() -> void:
	var cfg: Dictionary=StreamWorld.SPECIES.get("lawnmower_blenny",{})
	check(cfg.get("label")=="Lawnmower blenny" and cfg.get("latin")=="Salarias fasciatus" and cfg.get("pool")=="biofilm" and StreamWorld.CAP.get("lawnmower_blenny")==3 and cfg.get("initial")==2,"Lawnmower blenny: biofilm grazer, habitat for three, opening pair")
	var w:=StreamWorld.new(42,1000)
	var pair: Array=blennies(w)
	check(pair.size()==2 and pair.all(on_bed) and pair.any(func(x): return x.sex=="female") and pair.any(func(x): return x.sex=="male"),"A new world opens with a blenny pair on the bed")
	w.state.light_hour=12.0
	var seen: Dictionary={}
	var bed: bool=true
	var step_ok: bool=true
	var low: float=INF
	var high: float=-INF
	var x0: float=pair[0].x
	for i in 9000:
		var before: Array=pair.map(func(x): return Vector2(x.x,x.y))
		w.advance_live(0.2)
		for k in pair.size():
			var b: Dictionary=pair[k]
			seen[b.activity]=true
			bed=bed and on_bed(b)
			step_ok=step_ok and absf(b.x-before[k].x)<=StreamWorld.BLENNY.hop_speed*0.2+0.001 and Vector2(b.x,b.y).distance_to(before[k]+Vector2(b.vx,b.vy)*0.2)<0.001
		low=minf(low,pair[0].x)
		high=maxf(high,pair[0].x)
	check(bed,"Blennies stay on the bed")
	check(["Perching","Grazing","Hopping"].all(func(k): return seen.has(k)) and seen.keys().all(func(k): return k in ["Perching","Grazing","Hopping"]),"By day blennies perch, graze and hop (%s)" % str(seen.keys()))
	check(step_ok,"Hops are short, smooth steps along the bed (vx/vy match the motion)")
	check(high-low>60 and high-low<1020,"A blenny works its way along the bottom (%.0f px)" % (high-low))
	w.state.light_hour=23.0
	w.advance_live(130)
	var night: Array=pair.map(func(x): return x.x)
	w.advance_live(60)
	check(pair.all(func(x): return x.activity=="Sleeping") and pair.map(func(x): return x.x)==night,"At night blennies sleep in place")
	check(absf(w.residual())<0.00001 and StreamWorld.validate(w.export_state()),"Blenny world conserves material and validates")
	# They graze biofilm, not microfauna.
	var grazed:=StreamWorld.new(8,1000)
	var bare:=StreamWorld.new(8,1000)
	only(grazed,func(x): return x.species=="lawnmower_blenny")
	only(bare,func(x): return false)
	for b: Dictionary in blennies(grazed):
		b.energy=1.0
	offline(grazed,StreamWorld.DAY*2)
	offline(bare,StreamWorld.DAY*2)
	check(blennies(grazed).all(func(x): return x.energy>1.0) and grazed.state.resources.biofilm<bare.state.resources.biofilm,"Hungry blennies feed on biofilm")
	# Young are born on the bed beside the mother; arrivals settle on the bed at the edge.
	var b:=StreamWorld.new(3,1000)
	var mom: Dictionary=blennies(b).filter(func(x): return x.sex=="female")[0]
	mom.energy=cfg.reserve
	var cursor: int=b.state.next_event-1
	b._breed(mom)
	var born: Array=StreamWorld.events_after(b.state.events,cursor).filter(func(e): return e.kind=="birth")
	check(born.size()==1 and on_bed(by_id(b,born[0].id)) and absf(by_id(b,born[0].id).x-mom.x)<=30.001,"A young blenny is born on the bed beside its mother")
	var came: Dictionary=b._arrive("lawnmower_blenny")
	check(on_bed(came) and came.x in [130.0,1150.0] and came.tx==came.x and came.ty==came.y,"An arriving blenny settles on the bed at the edge")
	# Settled food: a hungry blenny hops over and pecks it up.
	var f:=StreamWorld.new(42,1000)
	only(f,func(x): return x==blennies(f)[0])
	var bl: Dictionary=blennies(f)[0]
	bl.energy=1.0
	bl.x=500.0
	bl.y=StreamWorld.floor_y(500.0)
	bl.tx=bl.x
	bl.ty=bl.y
	reset_material(f)
	f.state.light_hour=12.0
	f.feed(560.0)
	var fed: bool=false
	for i in 900:
		f.advance_live(0.2)
		fed=fed or bl.activity=="Feeding"
	check(fed and food_mass(f)<StreamWorld.FOOD.particles*StreamWorld.FOOD.mass-0.000001 and bl.energy>1.0 and on_bed(bl) and absf(f.residual())<0.00001,"A blenny pecks up settled food")
	# Tap: it hops away along the bed, then settles; a lure does not interest it.
	var t:=StreamWorld.new(42,1000)
	t.state.light_hour=12.0
	var tb: Dictionary=blennies(t)[0]
	var tap:=Vector2(tb.x+40,tb.y-30)
	check(t.startle(tap.x,tap.y,1.0)>=1 and tb.activity=="Startled","A tap startles a nearby blenny")
	var start: float=absf(tb.x-tap.x)
	t.advance_live(2)
	check(absf(tb.x-tap.x)>start+20 and on_bed(tb),"It scoots away along the bed")
	t.advance_live(StreamWorld.STARTLE.seconds+1)
	check(tb.activity!="Startled","Then it settles again")
	t.set_lure(Vector2(tb.x,tb.y-40))
	var curious: bool=false
	for i in 600:
		t.advance_live(0.2)
		curious=curious or blennies(t).any(func(x): return x.activity=="Curious")
	check(not curious,"Blennies ignore the cursor lure")

func firefish(w: StreamWorld) -> Array:
	return w.state.animals.filter(func(x): return x.species=="purple_firefish")

# 2026-09-24 user decision: firefish hover a little above their own sand burrows (a patch
# of their own) and dart inside when startled, when a fish passes close, and at night.
func firefish_checks() -> void:
	var cfg: Dictionary=StreamWorld.SPECIES.get("purple_firefish",{})
	check(cfg.get("label")=="Purple firefish" and cfg.get("latin")=="Nemateleotris decora" and cfg.get("pool")=="microfauna" and StreamWorld.CAP.get("purple_firefish")==4 and cfg.get("initial")==2,"Purple firefish: microfauna, habitat for four, opening pair")
	# The red firefish (key "firefish", N. magnifica) was replaced before any user save held it; no legacy entry.
	check(not StreamWorld.SPECIES.has("firefish") and "firefish" not in StreamWorld.HOMES and StreamWorld.new(42,1000).spawn("firefish").is_empty(),"The red firefish key is gone entirely")
	var w:=StreamWorld.new(42,1000)
	var pair: Array=firefish(w)
	check(pair.size()==2 and pair.all(at_burrow) and apart(pair) and pair.any(func(x): return x.sex=="female") and pair.any(func(x): return x.sex=="male"),"A new world opens with a firefish pair, each in its own burrow")
	check(StreamWorld.FIRE_BURROWS.size()>=StreamWorld.CAP.purple_firefish and pair.all(func(x): return x.burrow_x in StreamWorld.FIRE_BURROWS),"The firefish patch has a burrow for every firefish place")
	check(pair.all(func(x): return x.hover_y>=StreamWorld.FIRE.hover[0] and x.hover_y<=StreamWorld.FIRE.hover[1]),"Each firefish has its own hover height above the burrow")
	only(w,func(x): return x.species=="purple_firefish" or x==chromis(w)[0])
	var fish: Dictionary=chromis(w)[0]
	var ff: Dictionary=pair[0]
	w.state.light_hour=12.0
	fish.x=1100.0
	fish.tx=1100.0
	w.advance_live(1)
	check(pair.all(func(x): return x.activity=="Hovering" and x.extend==1.0),"By day firefish hover above their burrows")
	fish.x=ff.burrow_x
	fish.y=StreamWorld.DEPTH[fish.species][1]
	fish.tx=fish.x
	fish.ty=fish.y
	fish.activity="Resting"
	fish.decision_at=w.state.elapsed+60
	w.advance_live(0.4)
	check(ff.activity=="Hiding" and ff.extend==0.0,"A fish passing close sends a firefish into its burrow")
	fish.x=1100.0
	fish.tx=1100.0
	w.advance_live(StreamWorld.FIRE.seconds+1)
	check(ff.activity=="Hovering" and ff.extend==1.0,"It comes back out a few seconds later")
	var b:=StreamWorld.new(42,1000)
	only(b,func(x): return x.species in ["purple_firefish","lawnmower_blenny"])
	b.state.light_hour=12.0
	var hop: Dictionary=blennies(b)[0]
	var bf: Dictionary=firefish(b)[0]
	for o: Dictionary in blennies(b):
		o.x=1100.0
		o.tx=1100.0
		o.y=StreamWorld.floor_y(1100.0)
		o.activity="Perching"
		o.decision_at=b.state.elapsed+600
	hop.x=bf.burrow_x-60
	hop.y=StreamWorld.floor_y(hop.x)
	hop.tx=bf.burrow_x+60
	hop.activity="Hopping"
	hop.decision_at=b.state.elapsed+600
	var hid: bool=false
	for i in 20:
		b.advance_live(0.2)
		hid=hid or bf.activity=="Hiding"
	check(hid,"A blenny hopping past makes a firefish duck")
	w.state.light_hour=23.0
	w.advance_live(1)
	check(pair.all(func(x): return x.activity=="Sleeping" and x.extend==0.0),"At night firefish sleep in their burrows")
	w.state.light_hour=6.0
	w.advance_live(3600*4)
	check(pair.all(at_burrow) and StreamWorld.validate(w.export_state()) and absf(w.residual())<0.00001,"Firefish never leave their burrows; the world validates and balances")
	# A tap darts them home; food drifting past a hovering firefish is snatched.
	var t:=StreamWorld.new(42,1000)
	only(t,func(x): return x.species=="purple_firefish")
	t.state.light_hour=12.0
	t.advance_live(1)
	var tf: Dictionary=firefish(t)[0]
	check(t.startle(tf.burrow_x,tf.burrow_y-30,1.0)>=1 and tf.activity=="Hiding" and tf.extend==0.0,"A tap near the burrow sends the firefish inside")
	t.advance_live(StreamWorld.STARTLE.eel_seconds+1)
	check(tf.activity=="Hovering","Then it hovers again")
	tf.energy=1.0
	reset_material(t)
	var before: float=tf.energy
	t.feed(tf.burrow_x)
	t.advance_live(80)
	check(tf.energy>before+StreamWorld.FOOD.mass*0.8-0.000001 and absf(t.residual())<0.00001,"A hovering firefish snatches food drifting past its burrow")
	t.set_lure(Vector2(tf.burrow_x,tf.burrow_y-60))
	var curious: bool=false
	for i in 300:
		t.advance_live(0.2)
		curious=curious or firefish(t).any(func(x): return x.activity=="Curious")
	check(not curious,"Firefish ignore the cursor lure")
	# Young dig beside the parent in the firefish patch; a full patch sends them downstream.
	var y:=StreamWorld.new(3,1000)
	var mom: Dictionary=firefish(y).filter(func(x): return x.sex=="female")[0]
	mom.energy=cfg.reserve
	reset_material(y)
	y._breed(mom)
	check(firefish(y).size()==3 and firefish(y).all(at_burrow) and apart(firefish(y)) and firefish(y).all(func(x): return x.burrow_x in StreamWorld.FIRE_BURROWS and x.hover_y>=StreamWorld.FIRE.hover[0]),"A young firefish digs its own burrow in the patch")
	mom.energy=cfg.reserve
	y._breed(mom)
	check(firefish(y).size()==StreamWorld.CAP.purple_firefish and firefish(y).all(at_burrow) and apart(firefish(y)),"The patch fills up to its cap, one burrow each")
	mom.energy=cfg.reserve
	reset_material(y)
	var dispersed: int=y.state.totals.dispersal
	y._breed(mom)
	check(y.state.totals.dispersal==dispersed+1 and firefish(y).size()==StreamWorld.CAP.purple_firefish and absf(y.residual())<0.00001,"A full patch sends young downstream")
	var r:=StreamWorld.new(11,1000)
	for x: Dictionary in firefish(r):
		r.state.animals.erase(x)
	reset_material(r)
	for i in 3:
		r.advance_offline(StreamWorld.MAX_AWAY)
	check(firefish(r).size()>0 and firefish(r).all(func(x): return at_burrow(x) and x.burrow_x in StreamWorld.FIRE_BURROWS),"Rescue arrival settles a firefish into a free burrow")
	var bad: Dictionary=StreamWorld.new(5).export_state()
	bad.animals.filter(func(x): return x.species=="purple_firefish")[0].erase("burrow_y")
	check(not StreamWorld.validate(bad),"Firefish without a burrow rejected")
	bad=StreamWorld.new(5).export_state()
	bad.animals.filter(func(x): return x.species=="purple_firefish")[0].hover_y=-3.0
	check(not StreamWorld.validate(bad),"Negative hover_y rejected")

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
	var band: Array=StreamWorld.DEPTH.green_chromis
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

func tangs(w: StreamWorld) -> Array:
	return w.state.animals.filter(func(x): return x.species=="yellow_tang")

func in_tang_band(a: Dictionary) -> bool:
	var band: Array=StreamWorld.DEPTH.yellow_tang
	return a.y>=band[0]-0.01 and a.y<=band[1]+0.01

# 2026-09-24 user decision: yellow tang, the largest fish of the pool and a biofilm grazer like the
# blenny; a small group cruising the upper midwater and reef face, pecking at rock surfaces.
func tang_checks() -> void:
	var cfg: Dictionary=StreamWorld.SPECIES.get("yellow_tang",{})
	check(cfg.get("label")=="Yellow tang" and cfg.get("latin")=="Zebrasoma flavescens" and cfg.get("pool")=="biofilm" and "yellow_tang" in StreamWorld.ACTIVE_SPECIES and "yellow_tang" in StreamWorld.REEF_CAST,"Yellow tang: biofilm grazer in the reef cast")
	var others: Array=StreamWorld.ACTIVE_SPECIES.filter(func(k): return k!="yellow_tang")
	check(others.all(func(k): return cfg.get("body",0.0)>StreamWorld.SPECIES[k].body),"Yellow tang is the largest fish of the pool")
	var ch: Dictionary=StreamWorld.SPECIES.green_chromis
	check(cfg.get("lifespan",0.0)>ch.lifespan and cfg.get("mature",0.0)>ch.mature and cfg.get("breed",1.0)<ch.breed and cfg.get("cooldown",0.0)>ch.cooldown,"Tangs live longer and breed more slowly than chromis")
	check(absf(cfg.get("cost",0.0)-0.8*cfg.get("bite",0.0)*0.5)<0.000001 and cfg.get("k_food")==10.0,"Tangs break even at food 10 like the rest of the cast")
	check(StreamWorld.CAP.get("yellow_tang",99)==2 and cfg.get("initial",0)==2,"Tangs stay a small group: an opening pair, habitat for two")
	var w:=StreamWorld.new(42,1000)
	var group: Array=tangs(w)
	check(group.size()==cfg.initial and group.all(in_tang_band) and group.any(func(x): return x.sex=="female") and group.any(func(x): return x.sex=="male"),"A new world opens with a tang pair in its band")
	check(group.all(func(x): return x.age>=cfg.mature),"The opening tangs are adults")
	w.state.light_hour=12.0
	var seen: Dictionary={}
	var band_ok: bool=true
	var contact_ok: bool=true
	var grazes: int=0
	var low: float=INF
	var high: float=-INF
	for i in 9000:
		w.advance_live(0.2)
		for t: Dictionary in group:
			seen[t.activity]=true
			band_ok=band_ok and in_tang_band(t)
			if t.activity=="Grazing":
				grazes+=1
				var spot: Array=[]
				for s: Array in StreamWorld.TANG.spots:
					if s[0]==t.get("contact_x") and s[1]==t.get("contact_y"):
						spot=s
				# Mouth on the rock: body centre `reach` px out on the open side, facing the rock.
				contact_ok=contact_ok and not spot.is_empty() and t.direction==-spot[2] and Vector2(t.x,t.y).distance_to(Vector2(spot[0]+spot[2]*StreamWorld.TANG.reach,spot[1]))<6.0
			else:
				contact_ok=contact_ok and not t.has("contact_x") and not t.has("contact_y")
		low=minf(low,group[0].x)
		high=maxf(high,group[0].x)
	check(band_ok,"Tangs stay in their band")
	check(seen.has("Cruising") and seen.has("Grazing") and seen.keys().all(func(k): return k in ["Cruising","Grazing","Resting"]),"By day tangs cruise and graze (%s)" % str(seen.keys()))
	check(grazes>0 and contact_ok,"A grazing tang holds its mouth to a rock spot (contact_x/contact_y), only while grazing")
	check(high-low>400,"A tang cruises across the pool (%.0f px)" % (high-low))
	check(absf(w.residual())<0.00001 and StreamWorld.validate(w.export_state()),"Tang world conserves material and validates")
	# Night: mostly resting.
	var n:=StreamWorld.new(42,1000)
	n.state.light_hour=1.0
	var resting: int=0
	for i in 1500:
		n.advance_live(0.2)
		resting+=tangs(n).filter(func(x): return x.activity=="Resting").size()
	check(resting>1500*tangs(n).size()*0.4,"At night tangs mostly rest")
	# They graze biofilm, like the blenny.
	var grazed:=StreamWorld.new(8,1000)
	var bare:=StreamWorld.new(8,1000)
	only(grazed,func(x): return x.species=="yellow_tang")
	only(bare,func(x): return false)
	for t: Dictionary in tangs(grazed):
		t.energy=1.0
	offline(grazed,StreamWorld.DAY*2)
	offline(bare,StreamWorld.DAY*2)
	check(tangs(grazed).all(func(x): return x.energy>1.0) and grazed.state.resources.biofilm<bare.state.resources.biofilm,"Hungry tangs feed on biofilm")
	# Feeding, a tap and the lure: like the other swimmers.
	var f:=StreamWorld.new(42,1000)
	only(f,func(x): return x==tangs(f)[0])
	var ft: Dictionary=tangs(f)[0]
	ft.energy=1.0
	reset_material(f)
	f.state.light_hour=12.0
	f.feed(ft.x)
	var chased: bool=false
	for i in 600:
		f.advance_live(0.2)
		chased=chased or ft.activity=="Feeding"
	check(chased and ft.energy>1.0 and food_mass(f)<StreamWorld.FOOD.particles*StreamWorld.FOOD.mass-0.000001 and in_tang_band(ft) and absf(f.residual())<0.00001,"A hungry tang chases drifting food and eats it")
	var t:=StreamWorld.new(42,1000)
	t.state.light_hour=12.0
	t.advance_live(5)
	var tt: Dictionary=tangs(t)[0]
	var x0: float=tt.x
	check(t.startle(tt.x+30,tt.y,1.0)>=1 and tt.activity=="Startled" and not tt.has("contact_x"),"A tap startles a tang")
	var fled: bool=true
	for i in 10:
		t.advance_live(0.2)
		fled=fled and in_tang_band(tt)
	check(fled and tt.x<x0-5,"It darts away from the tap inside its band")
	t.advance_live(StreamWorld.STARTLE.seconds+1)
	check(tt.activity!="Startled","Then it settles again")
	var l:=StreamWorld.new(42,1000)
	only(l,func(x): return x.species=="yellow_tang")
	l.state.light_hour=12.0
	var curious: bool=false
	for i in 900:
		var lt: Dictionary=tangs(l)[0]
		if i%100==0:
			l.set_lure(Vector2(lt.x+40+i*0.01,lt.y))
		l.advance_live(0.2)
		curious=curious or tangs(l).any(func(x): return x.activity=="Curious")
	check(curious,"The cursor lure draws a curious tang")
	# Young are born in the band beside the mother; arrivals come in at the edge in the band.
	var b:=StreamWorld.new(3,1000)
	var mom: Dictionary=tangs(b).filter(func(x): return x.sex=="female")[0]
	mom.energy=cfg.reserve
	reset_material(b)
	var dispersed: int=b.state.totals.dispersal
	b._breed(mom)
	check(b.state.totals.dispersal==dispersed+1 and tangs(b).size()==StreamWorld.CAP.yellow_tang and absf(b.residual())<0.00001,"With the pair filling the habitat, a young tang disperses")
	# Room for one: the male is gone.
	only(b,func(x): return x.species!="yellow_tang" or x==mom)
	mom.energy=cfg.reserve
	reset_material(b)
	var cursor: int=b.state.next_event-1
	b._breed(mom)
	var born: Array=StreamWorld.events_after(b.state.events,cursor).filter(func(e): return e.kind=="birth")
	check(born.size()==1 and in_tang_band(by_id(b,born[0].id)) and absf(by_id(b,born[0].id).x-mom.x)<=30.001 and absf(b.residual())<0.00001,"A young tang is born in the band beside its mother")
	var came: Dictionary=b._arrive("yellow_tang")
	check(in_tang_band(came) and came.x in [130.0,1150.0],"An arriving tang comes in at the edge, in its band")
	var bad: Dictionary=StreamWorld.new(5).export_state()
	bad.animals.filter(func(x): return x.species=="yellow_tang")[0].contact_x="rock"
	check(not StreamWorld.validate(bad),"Non-numeric contact_x rejected")

func fixture(name: String) -> Dictionary:
	var f:=FileAccess.open("res://tests/fixtures/"+name,FileAccess.READ)
	var v: Dictionary=f.get_var()
	f.close()
	return v

# Older saves (2026-09-24, Stillwater Reef): threadfin (and since 2026-09-25 garden eels) depart once
# like the hatchetfish and shrimp before them; the reef cast arrives once, not live.
func reef_cast_checks() -> void:
	for name: String in ["v2-threadfin-era.var","v2-hatchet-era.var","v2-pre-eel.var","v1-world.var"]:
		var old: Dictionary=fixture(name)
		check(StreamWorld.validate(old),name+" validates")
		var up:=StreamWorld.new()
		check(up.restore(old),name+" restores")
		var fresh: Array=StreamWorld.events_after(up.state.events,old.get("next_event",1)-1)
		var leavers: Array=old.animals.filter(func(x): return x.species not in StreamWorld.ACTIVE_SPECIES)
		var gone: Array=fresh.filter(func(e): return e.kind=="departure")
		check(leavers.size()>0 and ids(gone)==ids(leavers) and up.state.totals.departure==old.totals.departure+leavers.size() and gone.all(func(e): return e.live==false),name+": every threadfin (and older removed species) departs once")
		check(up.state.animals.all(func(x): return x.species in StreamWorld.ACTIVE_SPECIES),name+": no removed species remain")
		var came: Array=fresh.filter(func(e): return e.kind=="arrival" and by_id(up,e.id).species in StreamWorld.REEF_CAST)
		var arrived_ok: bool=came.all(func(e): return e.live==false)
		for species: String in StreamWorld.REEF_CAST:
			var kin: Array=up.state.animals.filter(func(x): return x.species==species)
			arrived_ok=arrived_ok and kin.size()==StreamWorld.SPECIES[species].initial and kin.any(func(x): return x.sex=="female") and kin.any(func(x): return x.sex=="male")
		check(arrived_ok and up.state.reef_cast==true,name+": the reef cast arrives once, not live")
		check(old.animals.filter(func(x): return x.species=="garden_eel").all(func(x): return by_id(up,x.id).is_empty() and up.state.archive.any(func(y): return y.id==x.id and y.cause=="departure" and y.burrow_x==x.burrow_x)),name+": resident garden eels depart once, archived with their burrows")
		check(absf(up.residual())<0.00001 and StreamWorld.validate(up.export_state()),name+": material balances and the upgraded save validates")
		var again:=StreamWorld.new()
		check(again.restore(up.export_state()) and again.state.totals.arrival==up.state.totals.arrival and again.state.totals.departure==up.state.totals.departure,name+": a second load adds and removes nothing")
		offline(again,StreamWorld.DAY*3)
		again.advance_live(600)
		check(StreamWorld.validate(again.export_state()) and absf(again.residual())<0.00001 and again.state.animals.all(func(x): return x.species in StreamWorld.ACTIVE_SPECIES),name+": the upgraded reef keeps running")
	var fed: Dictionary=fixture("v2-threadfin-era.var")
	var r:=StreamWorld.new()
	check(fed.food.size()>0 and r.restore(fed) and r.state.food.size()==fed.food.size() and r.state.animals.all(func(x): return not x.has("food_id") or x.species in StreamWorld.ACTIVE_SPECIES),"Food in flight in a threadfin-era save survives the upgrade")
	check(StreamWorld.new(42,1000).state.reef_cast==true,"A new world already has the reef cast")
	var bad: Dictionary=StreamWorld.new(5).export_state()
	bad.reef_cast="yes"
	check(not StreamWorld.validate(bad),"Non-boolean reef_cast rejected")
