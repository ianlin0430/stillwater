extends SceneTree
var checks: int = 0
var failures: Array[String] = []
var results: Dictionary = {}

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		printerr("FAIL: " + message)

func equal_world(a: Ecosystem, b: Ecosystem) -> bool:
	return var_to_bytes(a.export_state()) == var_to_bytes(b.export_state())

func fixture() -> Ecosystem:
	var s := Ecosystem.new(812)
	s.state.animals.clear()
	s.state.initial_material = s.material()
	return s

func reset_ledger(s: Ecosystem) -> void:
	s.state.initial_material = s.material()
	s.state.imported = 0.0
	s.state.exported = 0.0

func _initialize() -> void:
	var started: int = Time.get_ticks_msec()
	var a := Ecosystem.new(123)
	var b := Ecosystem.new(123)
	a.step(200)
	for _i in 40:
		b.step(5)
	check(equal_world(a, b), "Seed and batching determinism")
	check(absf(a.residual()) < 0.000001, "200-step material balance")
	var snap: Dictionary = a.snapshot()
	snap.animals.clear()
	snap.cells[0].plant = 0
	check(equal_world(a, b), "Snapshot mutation cannot affect simulation")
	var err: Error = SaveStore.save_world("user://test.world", a)
	check(err == OK, "Atomic save succeeds")
	var loaded: Dictionary = SaveStore.load_world("user://test.world")
	var restored := Ecosystem.new(99)
	check(restored.restore(loaded.state), "Verified save loads")
	check(equal_world(a, restored), "Save state byte-exact restoration")
	a.step(150)
	restored.step(150)
	check(equal_world(a, restored), "RNG continuation exact after resume")
	check(SaveStore.save_world("user://test.world", a) == OK, "Save rotates backup")
	var corrupt := FileAccess.open("user://test.world", FileAccess.WRITE)
	corrupt.store_var({"format": "wrong"})
	corrupt.close()
	loaded = SaveStore.load_world("user://test.world")
	check(loaded.get("backup", false), "Corrupt primary recovers backup")
	check(int(loaded.state.tick) == 200, "Backup contains previous verified save")
	check(SaveStore.fresh_path_if_unreadable("user://test.world") == "user://test.world", "Recoverable backup retains save destination")
	var damaged_path: String = "user://test-incompatible.world"
	var damaged := FileAccess.open(damaged_path, FileAccess.WRITE)
	damaged.store_var({"format": "future-version"})
	damaged.close()
	var original_bytes: PackedByteArray = FileAccess.get_file_as_bytes(damaged_path)
	var safe_path: String = SaveStore.fresh_path_if_unreadable(damaged_path)
	check(safe_path != damaged_path, "Unreadable save gets a separate destination")
	check(SaveStore.save_world(safe_path, a) == OK, "Recovery world can be saved")
	check(FileAccess.get_file_as_bytes(damaged_path) == original_bytes, "Saving recovery preserves incompatible original")
	check(SaveStore.fresh_path_if_unreadable(damaged_path) != safe_path, "Recovery names do not overwrite existing worlds")
	DirAccess.remove_absolute(safe_path)
	DirAccess.remove_absolute(damaged_path)
	var wrong: Dictionary = a.export_state()
	wrong.version = 100
	check(not restored.restore(wrong), "Reject incompatible version")
	wrong = a.export_state()
	wrong.animals.append(wrong.animals[0].duplicate(true))
	check(not restored.restore(wrong), "Reject duplicate IDs")
	check(not a.intervene({"kind": "rain", "value": 0}), "Parent world refuses experiment mutation")
	var parent: PackedByteArray = var_to_bytes(a.export_state())
	restored.branch("test-branch")
	check(restored.intervene({"kind": "rain", "value": 0}), "Branched rainfall intervention")
	check(restored.intervene({"kind": "nutrients", "value": 100}), "Nutrient import intervention")
	check(restored.intervene({"kind": "population", "species": "fish", "value": 10}), "Population import intervention")
	check(restored.intervene({"kind": "population", "species": "fish", "value": -5}), "Population export intervention")
	check(absf(restored.residual()) < 0.000001, "Interventions preserve boundary balance")
	check(var_to_bytes(a.export_state()) == parent, "Branch edits preserve parent")
	check(restored.state.commands.size() == 4, "Commands record all interventions")
	check(not restored.intervene({"kind": "rain", "value": NAN}), "Nonfinite intervention refuses")
	var s: Ecosystem = fixture()
	var animal: Dictionary = s.spawn("fish", Ecosystem.CENTER)
	animal.energy = 0
	reset_ledger(s)
	s.step()
	check(not animal.alive and animal.cause == "starvation", "Starvation has explicit cause")
	check(absf(s.residual()) < 0.000001, "Death recycles entire body")
	s = fixture()
	animal = s.spawn("fish", Ecosystem.CENTER)
	s.state.level = 0.13
	reset_ledger(s)
	s.step()
	check(not animal.alive and animal.cause == "habitat drying", "Lake drying kills aquatic organisms")
	s = fixture()
	animal = s.spawn("fish", Ecosystem.CENTER)
	reset_ledger(s)
	for _i in 600:
		for cell: Dictionary in s.state.cells:
			cell.oxygen = 0
		s.step()
		if not animal.alive:
			break
	check(not animal.alive and animal.cause == "low oxygen", "Hypoxia can kill fish")
	s = fixture()
	animal = s.spawn("frog", Ecosystem.CENTER, false, true)
	animal.age = float(Ecosystem.SPECIES.frog.mature) - Ecosystem.DT
	s.step()
	check(not s.aquatic(animal), "Tadpole matures to amphibious frog")
	check(s.state.events[-1].kind == "maturity", "Maturity event recorded")
	s = fixture()
	animal = s.spawn("rodent", Vector2(100, 100))
	animal.energy = Ecosystem.SPECIES.rodent.reserve
	reset_ledger(s)
	s._reproduce(animal)
	check(s.state.totals.birth > 0, "Reproduction creates tracked offspring")
	check(absf(s.residual()) < 0.000001, "Birth transfers parent material without creation")
	s = fixture()
	var predator: Dictionary = s.spawn("heron", Vector2(800, 190))
	predator.energy = 0.1
	animal = s.spawn("frog", Vector2(801, 190))
	reset_ledger(s)
	s.kill(animal, "predation", predator)
	var first: float = predator.energy
	s.kill(animal, "predation", predator)
	check(predator.energy == first, "A dead prey cannot feed twice")
	check(absf(s.residual()) < 0.000001, "Predation reconciles reserve and waste")
	s = fixture()
	var initial_plant: float = s.state.cells[0].plant
	s.step(20)
	check(s.state.cells[0].plant != initial_plant, "Seasonal producers change")
	check(absf(s.residual()) < 0.000001, "Producer/decomposer/runoff conserve material")
	s = fixture()
	s.step(1200)
	check(s.state.totals.arrival > 0, "Empty world recolonizes via scheduled immigration")
	check(s.counts().fish == 0, "Extinct isolated lake fish never silently respawn")
	check(absf(s.residual()) < 0.000001, "Migration ledger reconciles")
	# Same commands and seed give the same future, independent of inspection frequency.
	a = Ecosystem.new(42)
	b = Ecosystem.new(42)
	a.branch("x")
	b.branch("x")
	for sim: Ecosystem in [a, b]:
		sim.intervene({"kind": "rain", "value": 0.2})
		sim.intervene({"kind": "population", "species": "frog", "value": 5})
	for _i in 100:
		a.step()
		a.snapshot()
	b.step(100)
	check(equal_world(a, b), "Commands replay identically and observation is inert")
	results = {"checks": checks, "failures": failures, "seconds": (Time.get_ticks_msec() - started) / 1000.0}
	var f := FileAccess.open("res://artifacts/tests.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(results, "  "))
	print(JSON.stringify(results))
	quit(0 if failures.is_empty() else 1)
