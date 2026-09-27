extends SceneTree
# Acceptance gate for ecology v2 (docs/plans/2026-09-22-self-sustaining-ecosystem.md).
const PLANT_POOLS: Array[String] = ["stem","floating","biofilm"]
const ACCEPTANCE = preload("res://tests/ecology_acceptance.gd")

func plant_max(world: StreamWorld, plant: String) -> float:
	return world.biofilm_max() if plant=="biofilm" else StreamWorld.PLANTS[plant].max

# Live mode steps the same hours through advance_live, so movement takes part
# instead of the offline approximation.
const BANDS: Dictionary = StreamWorld.DEPTH
# Population target band, derived from the cast (2026-09-25, four-species reef): the bottom is the
# opening cast (12), the top the combined habitat caps (17). Same >= 80% share as before.
var POPULATION_BAND: Array=ACCEPTANCE.population_band()

func audit_depth(world: StreamWorld, depth: Dictionary) -> void:
	for a: Dictionary in world.state.animals:
		depth.checked+=1
		if a.species in StreamWorld.HOMES:
			# Purple firefish never swim: exactly at their own burrow mouth.
			if a.x!=a.burrow_x or a.y!=a.burrow_y or absf(a.y-StreamWorld.floor_y(a.x))>0.0001:
				depth.violations+=1
		elif a.species=="lawnmower_blenny":
			# Perched, grazing or hopping, always on the bed.
			if absf(a.y-StreamWorld.floor_y(a.x))>0.0001:
				depth.violations+=1
		else:
			var band: Array=BANDS[a.species]
			if a.y<band[0] or a.y>band[1]:
				depth.violations+=1

# --feed=daily: a pinch at 08, 11, 14 and 17 h (sim time since start) at rotating x, which is
# the whole daily cap (StreamWorld.FOOD.daily); --feed=none (default) never calls feed().
const FEED_HOURS: Array[int] = [8,11,14,17]
const FEED_X: Array[float] = [300.0,640.0,980.0,660.0]

# Every running tally of a run, in one Dictionary so a chunked run carries it exactly from one
# invocation to the next (store_var/var_to_bytes; never JSON, which drops float precision).
func new_tally(world: StreamWorld) -> Dictionary:
	var present: Dictionary={}
	for species: String in StreamWorld.ACTIVE_SPECIES:
		present[species]=0
	return {"day":0,"seconds":0.0,"chunks":[],"depth":{"checked":0,"violations":0},"rows":[],"peak":world.state.animals.size(),"max_residual":0.0,"invalid":0,"in_band":0,"present":present,"gap":present.duplicate(),"longest_gap":present.duplicate(),"plant_ok":{"stem":0,"floating":0,"biofilm":0},"plant_low":{"stem":INF,"floating":INF,"biofilm":INF},"first_old_age":-1,"removed_species":false,"fed":{"pinches":0,"refused":0},"detritus_max":0.0}

func simulate(seed_value: int, days: int, mode: String = "offline", feed: String = "none") -> Dictionary:
	var start: int=Time.get_ticks_msec()
	var world:=StreamWorld.new(seed_value)
	var t: Dictionary=new_tally(world)
	run_days(world,t,seed_value,days,days,mode,feed)
	t.seconds=(Time.get_ticks_msec()-start)/1000.0
	return summarize(world,t,seed_value,days,mode,feed)

# Steps days t.day ..< to_day (0-based), updating the tally t in place.
func run_days(world: StreamWorld, t: Dictionary, seed_value: int, days: int, to_day: int, mode: String, feed: String) -> void:
	var start: int=Time.get_ticks_msec()
	var depth: Dictionary=t.depth
	var present: Dictionary=t.present
	var gap: Dictionary=t.gap
	var longest_gap: Dictionary=t.longest_gap
	var plant_ok: Dictionary=t.plant_ok
	var plant_low: Dictionary=t.plant_low
	var fed: Dictionary=t.fed
	for day in range(t.day,to_day):
		for hour in 24:
			if feed=="daily" and hour in FEED_HOURS:
				if world.feed(FEED_X[FEED_HOURS.find(hour)]):
					fed.pinches+=1
				else:
					fed.refused+=1
			if mode=="offline":
				world.advance_offline(3600)
			else:
				if mode=="frames":
					# One hour at a 60 Hz frame delta, the way the running app steps.
					for f in 216000:
						world.advance_live(1.0/60.0)
				else:
					world.advance_live(3600.0)
				audit_depth(world,depth)
			t.peak=maxi(t.peak,world.state.animals.size())
		t.max_residual=maxf(t.max_residual,absf(world.residual()))
		t.detritus_max=maxf(t.detritus_max,world.state.resources.detritus)
		if not StreamWorld.validate(world.export_state()):
			t.invalid+=1
		if world.state.animals.any(func(x): return x.species not in StreamWorld.ACTIVE_SPECIES):
			t.removed_species=true
		if t.first_old_age<0 and world.state.causes.get("old age",0)>0:
			t.first_old_age=day+1
		var n: int=world.state.animals.size()
		if n>=POPULATION_BAND[0] and n<=POPULATION_BAND[1]:
			t.in_band+=1
		var c: Dictionary=world.counts()
		for species: String in present:
			if c[species]>0:
				present[species]+=1
				gap[species]=0
			else:
				gap[species]+=1
				longest_gap[species]=maxi(longest_gap[species],gap[species])
		for plant: String in PLANT_POOLS:
			var share: float=world.state.resources[plant]/plant_max(world,plant)
			plant_low[plant]=minf(plant_low[plant],share)
			if share>0.05:
				plant_ok[plant]+=1
		if (day+1)%30==0:
			var row: Dictionary=c.duplicate()
			row.day=day+1
			row.total=n
			row.resources=world.state.resources.duplicate()
			row.biofilm_max=world.biofilm_max()
			t.rows.append(row)
			print("Seed %d day %d: %s pools %s" % [seed_value,day+1,JSON.stringify(c),JSON.stringify(world.state.resources)])
		if mode!="offline":
			# Progress for the slow live runs (a CI log shows it as it goes).
			print("PROGRESS seed %d day %d/%d animals %d (%.0fs)" % [seed_value,day+1,days,n,(Time.get_ticks_msec()-start)/1000.0])
		t.day=day+1

func summarize(world: StreamWorld, t: Dictionary, seed_value: int, days: int, mode: String, feed: String) -> Dictionary:
	var present: Dictionary=t.present
	var totals: Dictionary=world.state.totals
	var causes: Dictionary=world.state.causes
	var presence: Dictionary={}
	var absent_days: Dictionary={}
	for species: String in present:
		presence[species]=float(present[species])/days
		absent_days[species]=days-present[species]
	var plants: Dictionary={}
	for plant: String in PLANT_POOLS:
		plants[plant]={"days_above_5pct":float(t.plant_ok[plant])/days,"lowest_share":t.plant_low[plant]}
	return {"seed":seed_value,"mode":mode,"feed":feed,"fed":t.fed,"detritus_max":t.detritus_max,"absent_days":absent_days,"depth":t.depth,"days":days,"births":totals.birth,"arrivals":totals.arrival,"old_age":causes.get("old age",0),"first_old_age_day":t.first_old_age,"starvation":causes.get("starvation",0),"predation":totals.predation,"departures":totals.departure,"dispersal":totals.dispersal,"population_band":POPULATION_BAND,"band_share":float(t.in_band)/days,"max_population":t.peak,"presence":presence,"longest_absence":t.longest_gap,"plants":plants,"max_material_residual":t.max_residual,"invalid_days":t.invalid,"removed_species_returned":t.removed_species,"causes":causes,"totals":totals,"monthly":t.rows,"seconds":t.seconds}

# A relative checkpoint path lives in res://artifacts/, like --out.
func checkpoint_path(path: String) -> String:
	return path if path.is_absolute_path() else "res://artifacts/"+path

# One chunk (--from-day/--to-day) of one seed's run. The world goes through StreamStore (exact binary
# export_state, rng and motion_rng included) and the tally through store_var into <checkpoint>.tally.
# Returns {"error": ...}, {"saved": path} after an intermediate chunk, or the finished run.
func simulate_chunk(seed_value: int, o: Dictionary) -> Dictionary:
	var start: int=Time.get_ticks_msec()
	var world:=StreamWorld.new(seed_value)
	var t: Dictionary
	if o.from_day==0:
		t=new_tally(world)
		t.merge({"seed":seed_value,"mode":o.mode,"feed":o.feed,"days":o.days})
	else:
		var source: String=checkpoint_path(o.checkpoint_in)
		var saved: Dictionary=StreamStore.read(source)
		var f:=FileAccess.open(source+".tally",FileAccess.READ)
		var tally: Variant=f.get_var(false) if f!=null else null
		if saved.is_empty() or not tally is Dictionary:
			return {"error":"cannot read checkpoint "+source+" (+.tally)"}
		t=tally
		var wanted: Array=[seed_value,o.mode,o.feed,o.days,o.from_day]
		var found: Array=[t.get("seed"),t.get("mode"),t.get("feed"),t.get("days"),t.get("day")]
		if found!=wanted:
			return {"error":"checkpoint %s holds seed/mode/feed/days/day %s, this chunk wants %s" % [source,str(found),str(wanted)]}
		if not world.restore(saved):
			return {"error":"cannot restore the world from "+source}
		print("RESUME seed %d from day %d (%s)" % [seed_value,o.from_day,source])
	run_days(world,t,seed_value,o.days,o.to_day,o.mode,o.feed)
	var seconds: float=(Time.get_ticks_msec()-start)/1000.0
	t.seconds+=seconds
	t.chunks.append({"from_day":o.from_day,"to_day":o.to_day,"seconds":seconds})
	if o.checkpoint_out!="":
		var error: String=save_checkpoint(checkpoint_path(o.checkpoint_out),world,t)
		if error!="":
			return {"error":error}
	if o.to_day<o.days:
		return {"saved":checkpoint_path(o.checkpoint_out)}
	var run: Dictionary=summarize(world,t,seed_value,o.days,o.mode,o.feed)
	run.chunks=t.chunks
	return run

# Writes the checkpoint pair and reads both back byte for byte. Returns "" or the error.
func save_checkpoint(path: String, world: StreamWorld, t: Dictionary) -> String:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var err: Error=StreamStore.save(path,world)
	if err!=OK:
		return "cannot save checkpoint %s: %s" % [path,error_string(err)]
	var f:=FileAccess.open(path+".tally",FileAccess.WRITE)
	if f==null:
		return "cannot write %s.tally: %s" % [path,error_string(FileAccess.get_open_error())]
	f.store_var(t)
	f.close()
	var back:=FileAccess.open(path+".tally",FileAccess.READ)
	var tally: Variant=back.get_var(false) if back!=null else null
	if var_to_bytes(StreamStore.read(path))!=var_to_bytes(world.export_state()) or var_to_bytes(tally)!=var_to_bytes(t):
		return "checkpoint %s does not read back exactly" % path
	return ""

func judge(run: Dictionary) -> Dictionary:
	var ok: Dictionary={}
	ok.reproduction=ACCEPTANCE.reproduction_passes(run)
	ok.local_replacement=ACCEPTANCE.local_replacement_passes(run)
	ok.old_age=ACCEPTANCE.old_age_passes(run)
	ok.starvation=run.starvation<run.old_age
	# Predation was removed on 2026-09-23: no animal eats another.
	ok.predation=run.predation==0 and not run.causes.has("predation")
	ok.population=run.band_share>=0.8 and run.max_population<=POPULATION_BAND[1]
	ok.presence=run.presence.values().all(func(v): return v>=0.95) and run.longest_absence.values().all(func(v): return v<=30)
	ok.no_departures=run.departures==0
	ok.conservation=run.max_material_residual<0.00001
	ok.plants=run.plants.values().all(func(p): return p.days_above_5pct>=0.95)
	ok.valid=run.invalid_days==0 and not run.removed_species_returned
	ok.depth_bands=run.depth.violations==0
	return ok

func options() -> Dictionary:
	# --mode=live --days=180 --seeds=42,812 --out=live-runs.json for the live batches;
	# no arguments keeps the original offline acceptance gate.
	# Chunked (one seed): --from-day=N --to-day=M --checkpoint-in=<path> --checkpoint-out=<path>; days
	# N..M of a --days run. Only the chunk that reaches --days judges and writes --out.
	var o: Dictionary={"mode":"offline","days":180,"seeds":[42,812,240921],"out":"six-month-runs.json","year":true,"feed":"none","from_day":0,"to_day":-1,"checkpoint_in":"","checkpoint_out":""}
	for arg: String in OS.get_cmdline_user_args():
		var parts: PackedStringArray=arg.lstrip("-").split("=")
		if parts.size()!=2:
			continue
		match parts[0]:
			"mode": o.mode=parts[1]
			"days": o.days=int(parts[1])
			"out": o.out=parts[1]
			"feed": o.feed=parts[1]
			"year": o.year=parts[1]=="true"
			"from-day": o.from_day=int(parts[1])
			"to-day": o.to_day=int(parts[1])
			"checkpoint-in": o.checkpoint_in=parts[1]
			"checkpoint-out": o.checkpoint_out=parts[1]
			"seeds":
				var seeds: Array[int]=[]
				for s: String in parts[1].split(","):
					seeds.append(int(s))
				o.seeds=seeds
	if o.to_day<0:
		o.to_day=o.days
	o.chunked=o.from_day!=0 or o.to_day!=o.days or o.checkpoint_in!="" or o.checkpoint_out!=""
	return o

# "" when the chunk options make sense, else why not.
func chunk_error(o: Dictionary) -> String:
	if o.seeds.size()!=1:
		return "a chunked run takes exactly one --seeds"
	if o.feed not in ["none","daily"]:
		return "unknown --feed="+o.feed
	if o.from_day<0 or o.from_day>=o.to_day or o.to_day>o.days:
		return "need 0 <= --from-day < --to-day <= --days, got %d, %d, %d" % [o.from_day,o.to_day,o.days]
	if o.from_day>0 and o.checkpoint_in=="":
		return "--from-day > 0 needs --checkpoint-in"
	if o.to_day<o.days and o.checkpoint_out=="":
		return "--to-day < --days needs --checkpoint-out"
	return ""

func _initialize() -> void:
	var o: Dictionary=options()
	var report: Dictionary={"days_per_seed":o.days,"mode":o.mode,"feed":o.feed,"runs":[],"failures":[]}
	if o.feed not in ["none","daily"]:
		report.failures.append("Unknown --feed="+o.feed)
	if POPULATION_BAND[1]!=StreamWorld.habitat_cap():
		report.failures.append("POPULATION_BAND top %d is not the combined habitat caps %d" % [POPULATION_BAND[1],StreamWorld.habitat_cap()])
	if o.chunked and chunk_error(o)!="":
		print("CHUNK ERROR "+chunk_error(o))
		quit(1)
		return
	for seed_value: int in o.seeds:
		var run: Dictionary
		if o.chunked:
			run=simulate_chunk(seed_value,o)
			if run.has("error"):
				print("CHUNK ERROR "+run.error)
				quit(1)
				return
			if run.has("saved"):
				print("CHUNK seed %d days %d-%d of %d saved to %s" % [seed_value,o.from_day,o.to_day,o.days,run.saved])
				quit(0)
				return
		else:
			run=simulate(seed_value,o.days,o.mode,o.feed)
		run.offspring_produced=ACCEPTANCE.offspring_produced(run)
		run.acceptance=judge(run)
		for key: String in run.acceptance:
			if not run.acceptance[key]:
				report.failures.append("Seed %d failed %s" % [seed_value,key])
		report.runs.append(run)
		print("SEED %d mode %s feed %s fed %s detritus_max %.2f absent %s depth %s" % [seed_value,run.mode,run.feed,JSON.stringify(run.fed),run.detritus_max,JSON.stringify(run.absent_days),JSON.stringify(run.depth)])
		print("SEED %d births %d arrivals %d old_age %d first_old_age_day %d starvation %d predation %d band %.3f max %d presence %s plants %s residual %s dispersal %d departures %d (%.1fs)" % [seed_value,run.births,run.arrivals,run.old_age,run.first_old_age_day,run.starvation,run.predation,run.band_share,run.max_population,JSON.stringify(run.presence),JSON.stringify(run.plants),String.num_scientific(run.max_material_residual),run.dispersal,run.departures,run.seconds])
	if not o.year:
		write_report(report,o.out)
		return
	var year: Dictionary=simulate(240921,365)
	var last: Dictionary=year.monthly[-1]
	year.acceptance={"species_persist":year.longest_absence.values().all(func(v): return v<=30) and StreamWorld.ACTIVE_SPECIES.all(func(k): return last[k]>0),"conservation":year.max_material_residual<0.00001,"valid":year.invalid_days==0}
	for key: String in year.acceptance:
		if not year.acceptance[key]:
			report.failures.append("365-day run failed "+key)
	report.stability_365=year
	print("YEAR births %d arrivals %d old_age %d starvation %d predation %d band %.3f max %d presence %s longest_absence %s residual %s (%.1fs)" % [year.births,year.arrivals,year.old_age,year.starvation,year.predation,year.band_share,year.max_population,JSON.stringify(year.presence),JSON.stringify(year.longest_absence),String.num_scientific(year.max_material_residual),year.seconds])
	write_report(report,o.out)

func write_report(report: Dictionary, out: String) -> void:
	var f:=FileAccess.open("res://artifacts/"+out,FileAccess.WRITE)
	f.store_string(JSON.stringify(report,"  "))
	f.close()
	print("ACCEPTANCE "+("PASS" if report.failures.is_empty() else "FAIL "+JSON.stringify(report.failures)))
	quit(0 if report.failures.is_empty() else 1)
