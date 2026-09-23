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

# A save from before 2026-09-23: three juvenile shrimp were taken by fish.
func legacy_predation_save() -> Dictionary:
	var w:=StreamWorld.new(21,1000)
	w.advance_offline(3600)
	var fish: Dictionary=w.state.animals.filter(func(x): return x.species=="threadfin")[0]
	for i in 3:
		var young: Dictionary=w.spawn("shrimp",4)
		w._event("feeding",fish,fish.name+" caught a young shrimp.",{"target":young.id})
		w._remove(young,"predation")
		w.state.events[-1].target=fish.id
	w.state.totals.predation=3
	return w.export_state()

# Hungry fish directly above exposed shrimplets on a bare bed, the old worst case.
func no_predation() -> bool:
	for offline: bool in [false,true]:
		var w:=StreamWorld.new(42,1000)
		w.state.resources.stem=0.0
		for i in 2:
			var young: Dictionary=w.spawn("shrimp",3)
			young.x=900.0+i*40
			young.y=StreamWorld.floor_y(young.x)
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
	check(a.state.animals.size()==16,"16 initial fish, shrimp and garden eels")
	check(a.counts()=={"shrimp":6,"threadfin":4,"hatchet":4,"garden_eel":2},"Fish, shrimp and two garden eels")
	check(a.spawn("crayfish").is_empty(),"Removed species cannot spawn")
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
	for i in 4:
		a.spawn("shrimp",30)
	var mother: Dictionary=a.state.animals[0]
	mother.energy=StreamWorld.SPECIES.shrimp.reserve
	reset_material(a)
	a._breed(mother)
	check(a.state.totals.dispersal==2,"Young disperse when local habitat is occupied")
	check(absf(a.residual())<0.00001,"Offspring dispersal recorded in boundary ledger")
	# R7: the shrimp space cap is 8, so remove all four extra shrimp to open room for a brood of two.
	for i in 4:
		a._remove(a.state.animals[-1],"departure")
	mother.energy=StreamWorld.SPECIES.shrimp.reserve
	reset_material(a)
	a._breed(mother)
	check(a.state.totals.birth==2,"Vacant habitat admits offspring")
	check(a.state.animals[-1].parent==mother.id,"Newborn lineage retained")
	check(absf(a.residual())<0.00001,"Birth transfers parental material")
	a=StreamWorld.new(15)
	a.state.animals[0].next_molt=a.state.animals[0].age
	a.advance_offline(60)
	check(a.state.totals.molt==1,"Molting schedules protective shelter")
	# Existing stream saves retain fish/shrimp; removed crayfish get recorded departures.
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
	check(retained_ids==restored_ids,"Cast update preserves fish and shrimp identities")
	check(absf(b.residual())<0.00001,"Cast update accounts for departing material")
	c=StreamWorld.new()
	c.restore(b.export_state())
	check(c.state.totals.departure==1,"Cast update is idempotent")
	a=StreamWorld.new(9)
	var swimmer: Dictionary=a.state.animals[6]
	swimmer.activity="Swimming"
	swimmer.tx=swimmer.x+100
	swimmer.ty=swimmer.y
	swimmer.decision_at=1000
	var old_x: float=swimmer.x
	a.advance_live(0.2)
	check(swimmer.vx<=3.0001 and swimmer.x>old_x,"Fish accelerate gradually from rest")
	ecosystem_checks()
	brood_checks()
	tint_checks()
	eel_checks()
	var acceptance=preload("res://tests/ecology_acceptance.gd")
	check(acceptance.reproduction_passes({"births":17,"dispersal":14,"arrivals":7}),"Dispersed offspring count toward reproduction")
	check(not acceptance.reproduction_passes({"births":17,"dispersal":2,"arrivals":7}),"Nineteen offspring do not meet the twenty-offspring threshold")
	check(acceptance.reproduction_passes({"births":17,"dispersal":3,"arrivals":7}),"Twenty offspring meet the threshold exactly")
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
	for i in 2:
		w.spawn("shrimp",30)
	check(w.counts().shrimp==StreamWorld.CAP.shrimp,"Shrimp at space cap")
	var mom: Dictionary=w.state.animals[0]
	mom.energy=StreamWorld.SPECIES.shrimp.reserve
	reset_material(w)
	w._breed(mom)
	check(w.state.totals.dispersal==2 and w.state.totals.birth==0 and w.counts().shrimp==8,"Space cap sends offspring downstream")
	check(absf(w.residual())<0.00001,"Capped offspring leave through the ledger")
	# Offspring and arrivals are moved sideways after spawn placed them.
	var sunk: float=0.0
	var w2:=StreamWorld.new(9)
	for i in 300:
		var mother: Dictionary=w2.state.animals[0]
		mother.species="shrimp"
		mother.energy=StreamWorld.SPECIES.shrimp.reserve
		mother.x=float(130+(i*41)%1000)
		var placed: int=w2.state.animals.size()
		w2._breed(mother)
		w2._arrive("shrimp")
		for i2 in range(placed,w2.state.animals.size()):
			var a: Dictionary=w2.state.animals[i2]
			sunk=maxf(sunk,a.y-StreamWorld.floor_y(a.x))
		while w2.state.animals.size()>6:
			w2.state.animals.pop_back()
	check(sunk<=0.0001,"Relocated shrimp stay on the stream bed")
	# R8: individual lifespans vary by at most 15%.
	var spans_ok: bool=true
	var ages_ok: bool=true
	for s in 12:
		w=StreamWorld.new(1000+s)
		for i in 6:
			w.spawn(["shrimp","threadfin","hatchet"][i%3],1)
		for animal: Dictionary in w.state.animals:
			var base: float=StreamWorld.SPECIES[animal.species].lifespan
			spans_ok=spans_ok and animal.lifespan>=base*0.85 and animal.lifespan<=base*1.15
			if animal.age>1:
				var lo: float=25.0 if animal.species=="shrimp" else 100.0 if animal.species=="garden_eel" else 40.0
				var hi: float=100.0 if animal.species=="shrimp" else 220.0 if animal.species=="garden_eel" else 150.0
				ages_ok=ages_ok and animal.age>=lo and animal.age<=hi and animal.age<animal.lifespan
	check(spans_ok,"Lifespans within 0.85-1.15 of species lifespan")
	check(ages_ok,"Opening ages staggered within R11 ranges")
	check(StreamWorld.SPECIES.shrimp.lifespan==120.0 and StreamWorld.SPECIES.threadfin.lifespan==180.0 and StreamWorld.SPECIES.hatchet.lifespan==180.0,"Species lifespans 120/180/180")
	# R10: a nearly vanished species is rescued from upstream; adults never wander off.
	w=StreamWorld.new(11)
	for animal: Dictionary in w.state.animals.duplicate():
		if animal.species=="hatchet":
			w.state.animals.erase(animal)
	reset_material(w)
	w.advance_offline(StreamWorld.MAX_AWAY)
	w.advance_offline(StreamWorld.MAX_AWAY)
	w.advance_offline(StreamWorld.MAX_AWAY)
	check(w.counts().hatchet>0,"Rescue arrival restores a missing species")
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
	for animal: Dictionary in v1.animals:
		if animal.species!="crayfish":
			kept.append([animal.id,animal.name,animal.parent,animal.sex])
	var now_ids: Array=[]
	var lifespans_ok: bool=true
	for animal: Dictionary in up.state.animals.filter(func(x): return x.species!="garden_eel"):
		now_ids.append([animal.id,animal.name,animal.parent,animal.sex])
		lifespans_ok=lifespans_ok and animal.has("lifespan") and animal.lifespan>animal.age
	check(kept==now_ids,"Upgrade keeps ids, names and lineage")
	check(lifespans_ok,"Upgrade assigns lifespans")
	check(up.state.totals.departure==v1.totals.departure+1,"Upgrade records crayfish as departure")
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

# Young hatched from `parent`: births name it as target, dispersals as actor.
func young_of(events: Array, parent: int) -> Array:
	return events.filter(func(e): return e.kind=="birth" and e.get("target")==parent or e.kind=="dispersal" and e.id==parent)

func a_female(w: StreamWorld) -> Dictionary:
	var mom: Dictionary=w.state.animals.filter(func(x): return x.species=="shrimp" and x.sex=="female")[0]
	mom.age=maxf(mom.age,30.0)
	mom.lifespan=9999.0
	mom.energy=StreamWorld.SPECIES.shrimp.reserve
	return mom

func by_id(w: StreamWorld, id: int) -> Dictionary:
	for x: Dictionary in w.state.animals:
		if x.id==id:
			return x
	return {}

# 2026-09-23 user decision: a female shrimp carries her brood for BROOD_DAYS before it hatches.
func brood_checks() -> void:
	var w:=StreamWorld.new(3,1000)
	var mom: Dictionary=a_female(w)
	var cursor: int=w.state.next_event-1
	var offspring: int=w.state.totals.birth+w.state.totals.dispersal
	w._berry(mom)
	var fresh: Array=StreamWorld.events_after(w.state.events,cursor)
	var e: Dictionary=fresh[0] if fresh.size()==1 else {}
	check(StreamWorld.BROOD_DAYS==5.0 and absf(mom.get("brood_until",-1.0)-(w.state.elapsed+5.0*StreamWorld.DAY))<0.001,"Brood hatches five simulated days after she becomes berried")
	check(e.get("kind")=="berried" and e.get("id")==mom.id and e.get("x")==mom.x and e.get("y")==mom.y and e.has("live") and absf(e.get("until",0.0)-mom.get("brood_until",-1.0))<0.001,"Berried event names the female, her position and the hatch time")
	check(w.state.totals.birth+w.state.totals.dispersal==offspring and mom.last_breed==mom.age,"No young the moment she becomes berried; the cooldown starts")
	mom.last_breed=-100.0
	reset_material(w)
	var saved: Dictionary=w.export_state()
	check(StreamWorld.validate(saved),"Mid-brood save validates")
	var r:=StreamWorld.new()
	check(r.restore(saved) and by_id(r,mom.id).get("brood_until")==mom.get("brood_until"),"Mid-brood save restores the brood")
	offline(w,StreamWorld.DAY*4.9)
	offline(r,StreamWorld.DAY*4.9)
	var events: Array=StreamWorld.events_after(w.state.events,cursor)
	check(mom.has("brood_until") and young_of(events,mom.id).is_empty(),"Still berried before five days")
	check(events.filter(func(x): return x.kind=="berried" and x.id==mom.id).size()==1,"A berried female starts no second brood")
	mom.energy=StreamWorld.SPECIES.shrimp.reserve
	by_id(r,mom.id).energy=mom.energy
	reset_material(w)
	reset_material(r)
	var until: float=mom.get("brood_until",0.0)
	w.advance_offline(StreamWorld.DAY*0.2)
	r.advance_offline(StreamWorld.DAY*0.2)
	var hatched: Array=young_of(StreamWorld.events_after(w.state.events,cursor),mom.id)
	check(not mom.has("brood_until") and hatched.size()>=1 and hatched.all(func(x): return x.time>=until and x.time<until+60.001),"Brood hatches when the period ends, parent is the female")
	check(same(w,r),"A save written mid-brood hatches on time after restore")
	check(absf(w.residual())<0.00001 and StreamWorld.validate(w.export_state()),"Hatching conserves material and validates")
	# Offline catch-up across long absences hatches once.
	w=StreamWorld.new(3,1000)
	mom=a_female(w)
	cursor=w.state.next_event-1
	w._berry(mom)
	mom.last_breed=mom.age+100.0
	for i in 3:
		w.catch_up(1000+StreamWorld.MAX_AWAY*(i+1))
	hatched=young_of(StreamWorld.events_after(w.state.events,cursor),mom.id)
	check(hatched.size() in [1,2] and hatched.all(func(x): return x.time==hatched[0].time) and not mom.has("brood_until"),"72-hour catch-ups hatch the brood exactly once")
	# Died while berried: the brood is lost, no young.
	w=StreamWorld.new(3,1000)
	mom=a_female(w)
	cursor=w.state.next_event-1
	w._berry(mom)
	mom.age=mom.lifespan
	reset_material(w)
	w.advance_offline(60)
	offline(w,StreamWorld.DAY*6)
	events=StreamWorld.events_after(w.state.events,cursor)
	var death: Array=events.filter(func(x): return x.kind=="death" and x.id==mom.id)
	check(death.size()==1 and death[0].get("brood_lost")==true and young_of(events,mom.id).is_empty(),"A female dying while berried loses her brood; the death records it")
	check(w.state.archive.filter(func(x): return x.id==mom.id and not x.has("brood_until")).size()==1 and absf(w.residual())<0.00001,"Archived female carries no brood; material still balances")
	# The natural path: shrimp hatch five days after berried, fish breed as before.
	w=StreamWorld.new(42,1000)
	cursor=w.state.next_event-1
	var species: Dictionary={}
	var seen: Array=[]
	for day in 30:
		for x: Dictionary in w.state.animals:
			species[x.id]=x.species
		w.advance_offline(StreamWorld.DAY)
		seen.append_array(StreamWorld.events_after(w.state.events,cursor))
		cursor=w.state.next_event-1
	var berried: Array=seen.filter(func(x): return x.kind=="berried")
	var shrimp_young: int=0
	var timing_ok: bool=true
	for x: Dictionary in seen.filter(func(x): return x.kind in ["birth","dispersal"]):
		var parent: int=x.target if x.kind=="birth" else x.id
		if species.get(parent)=="shrimp":
			shrimp_young+=1
			timing_ok=timing_ok and berried.any(func(b): return b.id==parent and x.time>=b.until and x.time<b.until+60.001)
	check(berried.size()>0 and shrimp_young>0 and timing_ok,"Every shrimp birth follows its mother's berried period (%d broods, %d young)" % [berried.size(),shrimp_young])
	check(berried.all(func(b): return species.get(b.id)=="shrimp"),"Only shrimp become berried")
	var old: Dictionary=legacy_predation_save()
	old.animals[0].brood_until="soon"
	check(not StreamWorld.validate(old),"Non-numeric brood_until rejected")
	old.animals[0].brood_until=-1.0
	check(not StreamWorld.validate(old),"Negative brood_until rejected")
	old.animals[0].brood_until=NAN
	check(not StreamWorld.validate(old),"Non-finite brood_until rejected")

func untinted(w: StreamWorld) -> PackedByteArray:
	var s: Dictionary=w.export_state()
	for x: Dictionary in s.animals+s.archive:
		x.erase("tint")
	return var_to_bytes(s)

# Individual colour: appearance only, never drawn from rng/motion_rng.
func tint_checks() -> void:
	var w:=StreamWorld.new(240921,1000)
	var tints: Array=w.state.animals.filter(func(x): return x.species=="shrimp").map(func(x): return x.get("tint",-1.0))
	check(tints.size()==6 and tints.all(func(t): return t>=0.0 and t<=1.0) and tints.max()-tints.min()>=0.15,"Opening shrimp get varied tints %s" % str(tints))
	check(w.state.animals.all(func(x): return x.species=="shrimp" or not x.has("tint")),"Only shrimp carry a tint")
	check(StreamWorld.new(240921,1000).state.animals.filter(func(x): return x.species=="shrimp").map(func(x): return x.tint)==tints,"Tints are deterministic per seed")
	var rs: String=str(w.rng.state)
	var ms: String=str(w.motion_rng.state)
	for i in 50:
		w._tint({"id":i+1,"parent":w.state.animals[0].id})
	check(str(w.rng.state)==rs and str(w.motion_rng.state)==ms,"Tint draws on neither rng nor motion_rng")
	var mom: Dictionary=a_female(w)
	var before: int=w.state.animals.size()
	w._breed(mom)
	var kids: Array=w.state.animals.slice(before)
	check(kids.size()>0 and kids.all(func(k): return absf(k.tint-mom.tint)<=0.0801 and k.tint>=0.0 and k.tint<=1.0),"Offspring tint stays near the mother's")
	var a:=StreamWorld.new(42,1000)
	var b:=StreamWorld.new(42,1000)
	for x: Dictionary in b.state.animals:
		if x.has("tint"):
			x.tint=0.0
	for x: StreamWorld in [a,b]:
		x.advance_live(600)
		offline(x,StreamWorld.DAY*12)
		x.advance_live(600)
	check(a.state.totals.birth+a.state.totals.dispersal>0 and untinted(a)==untinted(b),"Tint never changes ecology or motion (export identical apart from tint)")
	# Older saves have no tint: one is assigned on load, the same every time.
	var old: Dictionary=legacy_predation_save()
	for x: Dictionary in old.animals+old.archive:
		x.erase("tint")
		x.erase("brood_until")
	check(StreamWorld.validate(old),"Save without tint or brood validates")
	var o1:=StreamWorld.new()
	var o2:=StreamWorld.new()
	o1.restore(old)
	o2.restore(old)
	check(o1.state.animals.all(func(x): return x.species!="shrimp" or x.get("tint",-1.0)>=0.0 and x.tint<=1.0) and same(o1,o2),"Loading assigns every shrimp a deterministic tint")
	offline(o1,StreamWorld.DAY*6)
	check(StreamWorld.validate(o1.export_state()) and o1.state.totals.predation==3,"Old save keeps running after tint is assigned")
	var f:=FileAccess.open("res://tests/fixtures/v1-world.var",FileAccess.READ)
	var v1: Dictionary=f.get_var()
	f.close()
	var up:=StreamWorld.new()
	check(up.restore(v1) and up.state.animals.all(func(x): return x.species!="shrimp" or x.has("tint")),"v1 save gets tints on load")
	old.animals[0].tint=1.5
	check(not StreamWorld.validate(old),"Tint above 1 rejected")
	old.animals[0].tint=-0.1
	check(not StreamWorld.validate(old),"Tint below 0 rejected")
	old.animals[0].tint="red"
	check(not StreamWorld.validate(old),"Non-numeric tint rejected")

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

# 2026-09-23 user decision: spotted garden eels, fixed burrows on the sand bed.
func eel_checks() -> void:
	var cfg: Dictionary=StreamWorld.SPECIES.get("garden_eel",{})
	check(cfg.get("label")=="Spotted garden eel" and cfg.get("latin")=="Heteroconger hassi" and cfg.get("lifespan")==365.0 and cfg.get("mature")==90.0 and cfg.get("pool")=="microfauna" and StreamWorld.CAP.get("garden_eel")==4,"Garden eel: one-year life, 90-day maturity, microfauna, habitat for four")
	var w:=StreamWorld.new(42,1000)
	var pair: Array=eels(w)
	check(pair.size()==2 and pair.any(func(x): return x.sex=="female") and pair.any(func(x): return x.sex=="male") and pair.all(func(x): return x.age>=cfg.mature),"A new world opens with a mature pair of garden eels")
	check(pair.all(at_burrow) and pair.all(func(x): return x.burrow_x>=560 and x.burrow_x<=760) and apart(pair),"Each eel sits in its own burrow in the middle of the sand bed")
	# Day: out and swaying. A fish just above: retracted for a few seconds.
	for f: Dictionary in w.state.animals.duplicate():
		if f.species in ["threadfin","hatchet"] and f!=w.state.animals.filter(func(x): return x.species=="threadfin")[0]:
			w.state.animals.erase(f)
	reset_material(w)
	var fish: Dictionary=w.state.animals.filter(func(x): return x.species=="threadfin")[0]
	var eel: Dictionary=eels(w)[0]
	w.state.light_hour=12.0
	fish.x=100.0
	fish.tx=100.0
	w.advance_live(1)
	check(pair.all(func(x): return x.activity=="Swaying" and x.extend==1.0),"By day eels stand out of the sand, swaying")
	fish.x=eel.burrow_x
	fish.y=StreamWorld.DEPTH.threadfin[1]
	fish.tx=fish.x
	fish.ty=fish.y
	fish.activity="Resting"
	fish.decision_at=w.state.elapsed+60
	w.advance_live(0.4)
	check(eel.activity=="Retracted" and eel.extend==0.0,"A fish passing just above the burrow makes the eel retract")
	fish.x=100.0
	fish.tx=100.0
	w.advance_live(2)
	check(eel.activity=="Retracted","It stays down for a few seconds")
	w.advance_live(4)
	check(eel.activity=="Swaying" and eel.extend==1.0,"Then it comes back out")
	w.state.light_hour=23.0
	w.advance_live(1)
	check(pair.all(func(x): return x.activity=="Sleeping" and x.extend==0.0),"At night every eel sleeps inside its burrow")
	w.state.light_hour=6.0
	w.advance_live(3600*4)
	check(pair.all(at_burrow),"Eels never leave their burrows")
	check(absf(w.residual())<0.00001 and StreamWorld.validate(w.export_state()),"Eel world conserves material and validates")
	# Young dig a new burrow beside the colony; a full colony sends them downstream.
	w=StreamWorld.new(3,1000)
	var mom: Dictionary=eels(w).filter(func(x): return x.sex=="female")[0]
	mom.energy=cfg.reserve
	reset_material(w)
	var births: int=w.state.totals.birth
	w._breed(mom)
	mom.energy=cfg.reserve
	w._breed(mom)
	var colony: Array=eels(w)
	check(w.state.totals.birth-births==2 and colony.size()==4 and colony.all(at_burrow) and apart(colony),"Newborn eels dig their own burrows without overlapping")
	check(colony.all(func(x): return absf(x.burrow_x-mom.burrow_x)<=110),"New burrows stay near the colony")
	var w2:=StreamWorld.new(3,1000)
	var mom2: Dictionary=eels(w2).filter(func(x): return x.sex=="female")[0]
	mom2.energy=cfg.reserve
	w2._breed(mom2)
	mom2.energy=cfg.reserve
	w2._breed(mom2)
	check(eels(w2).map(func(x): return x.burrow_x)==colony.map(func(x): return x.burrow_x),"Burrow placement is deterministic")
	var dispersed: int=w.state.totals.dispersal
	mom.energy=cfg.reserve
	reset_material(w)
	w._breed(mom)
	check(w.state.totals.dispersal>dispersed and eels(w).size()==4 and absf(w.residual())<0.00001,"A full colony sends young downstream")
	# Rescue brings eels back like other species.
	w=StreamWorld.new(11,1000)
	for e: Dictionary in eels(w):
		w.state.animals.erase(e)
	reset_material(w)
	for i in 3:
		w.advance_offline(StreamWorld.MAX_AWAY)
	check(eels(w).size()>0 and eels(w).all(at_burrow) and apart(eels(w)),"Rescue arrival settles an eel into a free burrow")
	# A world whose eels died out does not get a free pair on load.
	w=StreamWorld.new(12,1000)
	for e: Dictionary in eels(w):
		w._remove(e,"old age")
	var r:=StreamWorld.new()
	check(r.restore(w.export_state()) and eels(r).is_empty(),"Loading never replaces eels that lived and died here")
	# Saves from before the eels: a pair arrives on load (live=false), once.
	var f:=FileAccess.open("res://tests/fixtures/v2-pre-eel.var",FileAccess.READ)
	var old: Dictionary=f.get_var()
	f.close()
	check(old.version==2 and old.animals.all(func(x): return x.species!="garden_eel") and StreamWorld.validate(old),"Pre-eel v2 save validates")
	var up:=StreamWorld.new()
	var arrivals: int=old.totals.arrival
	check(up.restore(old),"Pre-eel v2 save restores")
	var came: Array=eels(up)
	var fresh: Array=StreamWorld.events_after(up.state.events,old.next_event-1)
	check(came.size()==2 and came.any(func(x): return x.sex=="female") and came.any(func(x): return x.sex=="male") and came.all(at_burrow) and apart(came),"Two garden eels arrive in their own burrows")
	check(up.state.totals.arrival==arrivals+2 and fresh.size()==2 and fresh.all(func(e): return e.kind=="arrival" and e.live==false and e.x==by_id(up,e.id).burrow_x),"They arrive as two arrival events that do not play")
	check(old.animals.map(func(x): return x.id)==up.state.animals.filter(func(x): return x.species!="garden_eel").map(func(x): return x.id),"Everyone else is untouched")
	check(absf(up.residual())<0.00001 and StreamWorld.validate(up.export_state()),"Arrivals are accounted for and the save validates")
	var again:=StreamWorld.new()
	check(again.restore(up.export_state()) and eels(again).size()==2 and again.state.totals.arrival==arrivals+2,"A second load adds no more eels")
	offline(again,StreamWorld.DAY*3)
	again.advance_live(600)
	check(StreamWorld.validate(again.export_state()) and absf(again.residual())<0.00001 and eels(again).all(at_burrow),"Upgraded save keeps running")
	f=FileAccess.open("res://tests/fixtures/v1-world.var",FileAccess.READ)
	var v1: Dictionary=f.get_var()
	f.close()
	var v1w:=StreamWorld.new()
	check(v1w.restore(v1) and eels(v1w).size()==2 and absf(v1w.residual())<0.00001,"v1 save also gets two eels")
	# Validation.
	var bad: Dictionary=StreamWorld.new(5).export_state()
	var e0: Dictionary=bad.animals.filter(func(x): return x.species=="garden_eel")[0]
	e0.erase("burrow_x")
	check(not StreamWorld.validate(bad),"Eel without a burrow rejected")
	bad=StreamWorld.new(5).export_state()
	bad.animals.filter(func(x): return x.species=="garden_eel")[0].extend=1.5
	check(not StreamWorld.validate(bad),"Extend above 1 rejected")
