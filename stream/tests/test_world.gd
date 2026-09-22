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

func _initialize() -> void:
	var start: int=Time.get_ticks_msec()
	var a:=StreamWorld.new(42,1000)
	var b:=StreamWorld.new(42,1000)
	check(a.state.animals.size()==14,"14 initial fish and shrimp")
	check(a.counts()=={"shrimp":6,"threadfin":4,"hatchet":4},"Fish and shrimp only")
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
	var predator: Dictionary=a.state.animals[6]
	var prey: Dictionary=a.state.animals[0]
	a._remove(prey,"predation",predator)
	var energy: float=predator.energy
	a._remove(prey,"predation",predator)
	check(predator.energy==energy,"Predation never consumes an individual twice")
	check(absf(a.residual())<0.00001,"Predation transfers food and waste")
	check(a.state.archive[-1].cause=="predation","Cause of death remains inspectable")
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
	# R9: nursery, hiding, molting and stem cover protect shrimplets.
	w=StreamWorld.new(4)
	var young: Dictionary=w.spawn("shrimp",2)
	w.state.resources.stem=0.0
	young.x=640.0
	check(w.exposure(young,false)==0.0,"Nursery protects shrimplets")
	young.x=300.0
	check(w.exposure(young,false)==1.0,"Open bed without stems is exposed")
	w.state.resources.stem=StreamWorld.PLANTS.stem.max
	check(absf(w.exposure(young,false)-0.4)<0.0001,"Dense stems give 60% cover")
	young.activity="Sheltering"
	check(w.exposure(young,false)==0.0,"Hiding shrimplets are safe")
	young.activity="Grazing"
	young.molting_until=w.state.elapsed/StreamWorld.DAY+1
	check(w.exposure(young,false)==0.0,"Molting shrimplets are safe")
	young.molting_until=-1.0
	young.age=StreamWorld.SPECIES.shrimp.mature
	check(w.exposure(young,true)==0.0,"Adults are never prey")
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
				var lo: float=25.0 if animal.species=="shrimp" else 40.0
				var hi: float=100.0 if animal.species=="shrimp" else 150.0
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
	for animal: Dictionary in up.state.animals:
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
