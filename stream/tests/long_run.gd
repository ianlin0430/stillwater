extends SceneTree
# Acceptance gate for ecology v2 (docs/plans/2026-09-22-self-sustaining-ecosystem.md).
const PLANT_POOLS: Array[String] = ["stem","floating","biofilm"]
const ACCEPTANCE = preload("res://tests/ecology_acceptance.gd")

func plant_max(world: StreamWorld, plant: String) -> float:
	return world.biofilm_max() if plant=="biofilm" else StreamWorld.PLANTS[plant].max

# Live mode steps the same hours through advance_live, so movement takes part
# instead of the offline approximation.
const BANDS: Dictionary = StreamWorld.DEPTH
# Population target band, changed with the cast (2026-09-23, shrimp then hatchetfish removed):
# the top is the combined habitat caps (8+4=12; was 16, 22 with shrimp), the bottom is the
# opening cast of 8 (the user's band 8-12). Same >= 80% share as before, so this follows the
# species change and is not a looser gate.
const POPULATION_BAND: Array[int] = [8,12]

func audit_depth(world: StreamWorld, depth: Dictionary) -> void:
	for a: Dictionary in world.state.animals:
		depth.checked+=1
		if a.species=="garden_eel":
			# On the bed, never swimming: exactly at its own burrow mouth.
			if a.x!=a.burrow_x or a.y!=a.burrow_y or absf(a.y-StreamWorld.floor_y(a.x))>0.0001:
				depth.violations+=1
		else:
			var band: Array=BANDS[a.species]
			if a.y<band[0] or a.y>band[1]:
				depth.violations+=1

func simulate(seed_value: int, days: int, mode: String = "offline") -> Dictionary:
	var start: int=Time.get_ticks_msec()
	var world:=StreamWorld.new(seed_value)
	var depth: Dictionary={"checked":0,"violations":0}
	var rows: Array=[]
	var peak: int=world.state.animals.size()
	var max_residual: float=0
	var invalid: int=0
	var in_band: int=0
	var present: Dictionary={}
	for species: String in StreamWorld.ACTIVE_SPECIES:
		present[species]=0
	var gap: Dictionary=present.duplicate()
	var longest_gap: Dictionary=present.duplicate()
	var plant_ok: Dictionary={"stem":0,"floating":0,"biofilm":0}
	var plant_low: Dictionary={"stem":INF,"floating":INF,"biofilm":INF}
	var first_old_age: int=-1
	var removed_species: bool=false
	for day in days:
		for hour in 24:
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
			peak=maxi(peak,world.state.animals.size())
		max_residual=maxf(max_residual,absf(world.residual()))
		if not StreamWorld.validate(world.export_state()):
			invalid+=1
		if world.state.animals.any(func(x): return x.species not in StreamWorld.ACTIVE_SPECIES):
			removed_species=true
		if first_old_age<0 and world.state.causes.get("old age",0)>0:
			first_old_age=day+1
		var n: int=world.state.animals.size()
		if n>=POPULATION_BAND[0] and n<=POPULATION_BAND[1]:
			in_band+=1
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
			rows.append(row)
			print("Seed %d day %d: %s pools %s" % [seed_value,day+1,JSON.stringify(c),JSON.stringify(world.state.resources)])
	var totals: Dictionary=world.state.totals
	var causes: Dictionary=world.state.causes
	var presence: Dictionary={}
	var absent_days: Dictionary={}
	for species: String in present:
		presence[species]=float(present[species])/days
		absent_days[species]=days-present[species]
	var plants: Dictionary={}
	for plant: String in PLANT_POOLS:
		plants[plant]={"days_above_5pct":float(plant_ok[plant])/days,"lowest_share":plant_low[plant]}
	return {"seed":seed_value,"mode":mode,"absent_days":absent_days,"depth":depth,"days":days,"births":totals.birth,"arrivals":totals.arrival,"old_age":causes.get("old age",0),"first_old_age_day":first_old_age,"starvation":causes.get("starvation",0),"predation":totals.predation,"departures":totals.departure,"dispersal":totals.dispersal,"population_band":POPULATION_BAND,"band_share":float(in_band)/days,"max_population":peak,"presence":presence,"longest_absence":longest_gap,"plants":plants,"max_material_residual":max_residual,"invalid_days":invalid,"removed_species_returned":removed_species,"causes":causes,"totals":totals,"monthly":rows,"seconds":(Time.get_ticks_msec()-start)/1000.0}

func judge(run: Dictionary) -> Dictionary:
	var ok: Dictionary={}
	ok.reproduction=ACCEPTANCE.reproduction_passes(run)
	ok.local_replacement=ACCEPTANCE.local_replacement_passes(run)
	ok.old_age=run.old_age>=5 and run.first_old_age_day>0 and run.first_old_age_day<=60
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
	var o: Dictionary={"mode":"offline","days":180,"seeds":[42,812,240921],"out":"six-month-runs.json","year":true}
	for arg: String in OS.get_cmdline_user_args():
		var parts: PackedStringArray=arg.lstrip("-").split("=")
		if parts.size()!=2:
			continue
		match parts[0]:
			"mode": o.mode=parts[1]
			"days": o.days=int(parts[1])
			"out": o.out=parts[1]
			"year": o.year=parts[1]=="true"
			"seeds":
				var seeds: Array[int]=[]
				for s: String in parts[1].split(","):
					seeds.append(int(s))
				o.seeds=seeds
	return o

func _initialize() -> void:
	var o: Dictionary=options()
	var report: Dictionary={"days_per_seed":o.days,"mode":o.mode,"runs":[],"failures":[]}
	if POPULATION_BAND[1]!=StreamWorld.habitat_cap():
		report.failures.append("POPULATION_BAND top %d is not the combined habitat caps %d" % [POPULATION_BAND[1],StreamWorld.habitat_cap()])
	for seed_value: int in o.seeds:
		var run: Dictionary=simulate(seed_value,o.days,o.mode)
		run.offspring_produced=ACCEPTANCE.offspring_produced(run)
		run.acceptance=judge(run)
		for key: String in run.acceptance:
			if not run.acceptance[key]:
				report.failures.append("Seed %d failed %s" % [seed_value,key])
		report.runs.append(run)
		print("SEED %d mode %s absent %s depth %s" % [seed_value,run.mode,JSON.stringify(run.absent_days),JSON.stringify(run.depth)])
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
