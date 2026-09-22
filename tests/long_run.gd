extends SceneTree
func _initialize() -> void:
	var report: Dictionary = {"model": "Stillwater 1", "years_per_seed": 10, "runs": []}
	var any_failure: bool = false
	var seeds: Array = [42, 812, 240921]
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if not args.is_empty():
		seeds = [int(args[0])]
	for seed_value in seeds:
		var start: int = Time.get_ticks_msec()
		var sim := Ecosystem.new(seed_value)
		var years: Array = []
		var max_residual: float = 0
		var max_population: int = 0
		for year in 10:
			for month in 12:
				sim.step(120 if month < 11 else 140)
				max_residual = maxf(max_residual, absf(sim.residual()))
				var count: int = 0
				for value: int in sim.counts().values():
					count += value
				max_population = maxi(max_population, count)
				if not Ecosystem.validate(sim.export_state()):
					any_failure = true
			var row: Dictionary = sim.counts()
			row.year = year + 1
			row.level = sim.state.level
			row.deaths = sim.state.deaths.duplicate()
			years.append(row)
			print("seed %d year %d: %s" % [seed_value, year + 1, JSON.stringify(row)])
		var run: Dictionary = {"seed": seed_value, "annual": years, "max_population_sampled": max_population, "max_material_residual": max_residual, "events": sim.state.totals, "seconds": (Time.get_ticks_msec() - start) / 1000.0}
		report.runs.append(run)
		if max_residual > 0.00001:
			any_failure = true
		var f := FileAccess.open("res://artifacts/ten-year-%d.json" % seed_value, FileAccess.WRITE)
		f.store_string(JSON.stringify(report, "  "))
	quit(1 if any_failure else 0)
