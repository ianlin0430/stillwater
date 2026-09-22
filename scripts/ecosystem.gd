class_name Ecosystem
extends RefCounted

const VERSION: int = 1
const DT: float = 0.25
const WIDTH: float = 1536.0
const HEIGHT: float = 1024.0
const COLS: int = 24
const ROWS: int = 16
const CELL: float = 64.0
const CENTER: Vector2 = Vector2(800, 470)
const RADII: Vector2 = Vector2(540, 320)
const SPECIES: Dictionary = preload("res://data/species.json").data
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var state: Dictionary = {}
var bins: Dictionary = {}

func _init(world_seed: int = 240921) -> void:
	rng.seed = world_seed
	state = {"version": VERSION, "seed": world_seed, "tick": 0, "next_id": 1,
		"world_id": "wetland-%d" % world_seed, "parent": "", "branch_tick": 0,
		"cells": [], "animals": [], "events": [], "history": [], "commands": [],
		"deaths": {}, "totals": {"birth": 0, "death": 0, "arrival": 0, "departure": 0},
		"rain_scale": 1.0, "temperature": 12.0, "rain": 0.5, "light": 0.65,
		"level": 1.0, "imported": 0.0, "exported": 0.0, "initial_material": 0.0}
	for y in ROWS:
		for x in COLS:
			var p := Vector2((x + 0.5) * CELL, (y + 0.5) * CELL)
			var r: float = radius(p)
			state.cells.append({"x": p.x, "y": p.y, "r": r, "water": r < 1.0,
				"plant": rng.randf_range(5, 13), "trees": 12.0 if r > 1.25 else 0.0,
				"nutrient": 18.0, "detritus": 4.0, "moisture": 0.75,
				"oxygen": 9.0, "decomposition": 0.0})
	for species: String in SPECIES:
		for _n in int(SPECIES[species].initial):
			spawn(species, random_position(species, true), true)
	state.initial_material = material()
	_record("world", 0, "A new wetland begins", "")
	_sample()

static func radius(p: Vector2) -> float:
	return ((p - CENTER) / RADII).length()

func cell_index(p: Vector2) -> int:
	return clampi(int(p.y / CELL), 0, ROWS - 1) * COLS + clampi(int(p.x / CELL), 0, COLS - 1)

func aquatic(a: Dictionary) -> bool:
	return a.species == "fish" or (a.species in ["frog", "insect"] and a.age < float(SPECIES[a.species].mature))

func suitable(p: Vector2, species: String, juvenile: bool = false) -> bool:
	if p.x < 12 or p.x > WIDTH - 12 or p.y < 12 or p.y > HEIGHT - 12:
		return false
	var r: float = radius(p)
	var level: float = sqrt(maxf(0.05, state.level))
	if species == "fish" or (juvenile and species in ["frog", "insect"]):
		return r < level * 0.90
	if species == "rodent":
		return r > level * 1.04
	if species in ["frog", "heron"]:
		return r > level * 0.82 and r < level * 1.20
	return r > level * 0.5 and r < level * 1.3

func random_position(species: String, juvenile: bool = false) -> Vector2:
	for _i in 1000:
		var p := Vector2(rng.randf_range(16, WIDTH - 16), rng.randf_range(16, HEIGHT - 16))
		if suitable(p, species, juvenile):
			return p
	return CENTER

func spawn(species: String, p: Vector2, initial: bool = false, juvenile: bool = false) -> Dictionary:
	var cfg: Dictionary = SPECIES[species]
	var age: float = rng.randf_range(0, float(cfg.mature) * 3) if initial else (0.0 if juvenile else float(cfg.mature) + 1.0)
	if not suitable(p, species, age < float(cfg.mature)):
		p = random_position(species, age < float(cfg.mature))
	var mass: float = float(cfg.body) * (0.4 if age < float(cfg.mature) else 1.0)
	var a: Dictionary = {"id": state.next_id, "species": species, "x": p.x, "y": p.y,
		"px": p.x, "py": p.y, "age": age, "body": mass,
		"energy": float(cfg.reserve) * (0.25 if juvenile else 0.65), "activity": "Exploring",
		"alive": true, "cause": "", "born": state.tick, "last_breed": -10000,
		"heading": rng.randf_range(-PI, PI), "recent": [], "depth": rng.randf_range(0.15, 0.85)}
	state.next_id += 1
	state.animals.append(a)
	return a

func _record(kind: String, id: int, detail: String, species: String) -> void:
	var e: Dictionary = {"tick": state.tick, "kind": kind, "id": id, "detail": detail, "species": species}
	state.events.append(e)
	if state.events.size() > 500:
		state.events.pop_front()
	if state.totals.has(kind):
		state.totals[kind] += 1

func note(a: Dictionary, detail: String) -> void:
	a.recent.append({"tick": state.tick, "detail": detail})
	if a.recent.size() > 5:
		a.recent.pop_front()

func kill(a: Dictionary, cause: String, predator: Dictionary = {}) -> void:
	if not a.alive:
		return
	a.alive = false
	a.cause = cause
	a.activity = "Died: " + cause
	a.died = state.tick
	var mass: float = a.body + a.energy
	var c: Dictionary = state.cells[cell_index(Vector2(a.x, a.y))]
	if not predator.is_empty():
		var capacity: float = maxf(0, float(SPECIES[predator.species].reserve) - predator.energy)
		var absorbed: float = minf(mass * 0.72, capacity)
		predator.energy += absorbed
		c.detritus += mass - absorbed
		predator.activity = "Feeding"
		note(predator, "Caught %s #%d" % [SPECIES[a.species].label, a.id])
	else:
		c.detritus += mass
	a.body = 0.0
	a.energy = 0.0
	state.deaths[cause] = state.deaths.get(cause, 0) + 1
	note(a, "Died from " + cause)
	_record("death", a.id, "%s #%d · %s" % [SPECIES[a.species].label, a.id, cause], a.species)

func _build_bins() -> void:
	bins.clear()
	for a: Dictionary in state.animals:
		if not a.alive:
			continue
		var key: int = cell_index(Vector2(a.x, a.y))
		if not bins.has(key):
			bins[key] = []
		bins[key].append(a)

func nearby(a: Dictionary, distance: float) -> Array:
	var p := Vector2(a.x, a.y)
	var reach: int = ceili(distance / CELL)
	var cx: int = int(p.x / CELL)
	var cy: int = int(p.y / CELL)
	var result: Array = []
	for y in range(maxi(0, cy - reach), mini(ROWS, cy + reach + 1)):
		for x in range(maxi(0, cx - reach), mini(COLS, cx + reach + 1)):
			for b: Dictionary in bins.get(y * COLS + x, []):
				if b.alive and b.id != a.id and p.distance_squared_to(Vector2(b.x, b.y)) <= distance * distance:
					result.append(b)
	return result

func step(count: int = 1) -> void:
	for _step in count:
		state.tick += 1
		_environment()
		_build_bins()
		# New offspring are appended after this fixed actor set, and act next step.
		var actors: Array = state.animals.duplicate()
		for a: Dictionary in actors:
			if a.alive:
				_animal(a)
		if state.tick % 40 == 0:
			_migration()
		if state.tick % 20 == 0:
			_sample()
		# Keep recent dead individuals inspectable; retain cumulative cause counts forever.
		if state.tick % 80 == 0:
			state.animals = state.animals.filter(func(a: Dictionary) -> bool: return a.alive or state.tick - a.get("died", state.tick) < 80)

func _environment() -> void:
	var day: float = fmod(state.tick * DT, 365.0)
	var warmth: float = sin(TAU * (day - 15.0) / 365.0)
	if state.tick % 4 == 1:
		state.rain = clampf((0.5 + rng.randf_range(-0.4, 0.4) - warmth * 0.14) * state.rain_scale, 0, 2)
	state.temperature = 11.0 + 13.0 * warmth
	state.light = 0.58 + 0.30 * warmth
	state.level = clampf(state.level + (state.rain * 0.002 - 0.00075 - maxf(0, warmth) * 0.0003) * DT, 0.12, 1.2)
	for c: Dictionary in state.cells:
		c.water = c.r < sqrt(state.level)
		c.moisture = clampf(c.moisture + (state.rain * 0.025 - 0.012 - warmth * 0.005) * DT, 0, 1)
		if c.water:
			c.moisture = 1.0
		var activity: float = clampf((state.temperature + 5) / 25.0, 0.05, 1.4) * c.moisture
		var recycled: float = minf(c.detritus, c.detritus * 0.025 * activity * DT)
		c.detritus -= recycled
		c.nutrient += recycled
		c.decomposition = recycled
		var capacity: float = 22.0 if c.water else 30.0
		var growth: float = minf(c.nutrient, maxf(0, capacity - c.plant) * 0.032 * state.light * activity * DT)
		c.plant += growth
		c.nutrient -= growth
		var litter: float = c.plant * (0.003 + maxf(0, -warmth) * 0.009) * DT
		c.plant -= litter
		c.detritus += litter
		if c.trees > 0 or c.r > 1.25:
			var wood_growth: float = minf(c.nutrient, maxf(0, 20 - c.trees) * 0.003 * activity * DT)
			var leaves: float = c.trees * (0.0005 + (0.003 if day > 185 and day < 275 else 0.0)) * DT
			c.trees += wood_growth - leaves
			c.nutrient -= wood_growth
			c.detritus += leaves
		if c.water:
			var equilibrium: float = 12.0 - state.temperature * 0.18
			c.oxygen = clampf(c.oxygen + (equilibrium - c.oxygen) * 0.08 * DT + growth * 0.15 - recycled * 0.6, 0, 15)
	# Local runoff transfers, rather than duplicates, dissolved material.
	if state.tick % 4 == 0:
		for i in state.cells.size():
			var c: Dictionary = state.cells[i]
			if not c.water and c.r < 1.4:
				var p := Vector2(c.x, c.y).move_toward(CENTER, CELL)
				var destination: Dictionary = state.cells[cell_index(p)]
				var flux: float = minf(c.nutrient, c.nutrient * state.rain * 0.008)
				c.nutrient -= flux
				destination.nutrient += flux

func _animal(a: Dictionary) -> void:
	var cfg: Dictionary = SPECIES[a.species]
	var p := Vector2(a.x, a.y)
	var c: Dictionary = state.cells[cell_index(p)]
	var was_juvenile: bool = a.age < float(cfg.mature)
	if not (a.species == "insect" and was_juvenile and state.temperature < 4):
		a.age += DT
	a.px = a.x
	a.py = a.y
	if was_juvenile and a.age >= float(cfg.mature):
		note(a, "Metamorphosis / maturity reached")
		_record("maturity", a.id, "%s #%d reached maturity" % [cfg.label, a.id], a.species)
	var seasonal: float = clampf((state.temperature + 8) / 25.0, 0.18, 1.25)
	var cost: float = minf(a.energy, float(cfg.metabolism) * DT * (1.0 if a.species in ["rodent", "heron"] else seasonal))
	a.energy -= cost
	c.nutrient += cost * 0.75
	c.detritus += cost * 0.25
	if aquatic(a) and c.water:
		c.oxygen = maxf(0, c.oxygen - float(cfg.metabolism) * 0.06 * DT)
	if a.energy <= 0.00001:
		kill(a, "starvation")
		return
	if a.age > float(cfg.lifespan):
		kill(a, "old age")
		return
	if aquatic(a) and (not c.water or state.level < 0.2):
		kill(a, "habitat drying")
		return
	if aquatic(a) and c.oxygen < 1.8 and rng.randf() < 0.06 * DT:
		kill(a, "low oxygen")
		return
	var growth: float = minf(maxf(0, float(cfg.body) - a.body), minf(a.energy * 0.03, 0.015 * DT))
	a.body += growth
	a.energy -= growth
	var neighbors: Array = nearby(a, float(cfg.sense))
	var target: Vector2 = p + Vector2.from_angle(a.heading + rng.randf_range(-0.8, 0.8)) * float(cfg.move)
	a.activity = "Exploring"
	var threat: Dictionary = {}
	var prey: Dictionary = {}
	var prey_dist: float = INF
	var mates: int = 0
	for b: Dictionary in neighbors:
		if b.species == a.species and b.age >= float(cfg.mature):
			mates += 1
		if a.species in SPECIES[b.species].diet and b.age >= float(SPECIES[b.species].mature):
			threat = b
		if b.species in cfg.diet and (a.age >= float(cfg.mature)):
			# Adult frogs catch emerged midges; aquatic predators can catch larvae.
			if a.species == "frog" and aquatic(b):
				continue
			var d: float = p.distance_squared_to(Vector2(b.x, b.y))
			if a.species == "fish" and not aquatic(b):
				continue
			if d < prey_dist:
				prey = b
				prey_dist = d
	if not threat.is_empty():
		target = p + (p - Vector2(threat.x, threat.y)).normalized() * float(cfg.move) * 1.5
		a.activity = "Hiding / fleeing"
	elif a.energy < float(cfg.reserve) * 0.88:
		if not prey.is_empty():
			target = Vector2(prey.x, prey.y)
			a.activity = "Pursuing prey"
			if prey_dist < 30 * 30 and rng.randf() < (0.07 if a.species == "fish" else 0.30):
				kill(prey, "predation", a)
		else:
			var edible: bool = a.species in ["insect", "rodent", "fish"] or (a.species == "frog" and aquatic(a))
			if edible:
				var pool: String = "detritus" if a.species == "insect" and aquatic(a) else "plant"
				var bite: float = minf(c[pool], minf(float(cfg.bite) * DT, (float(cfg.reserve) - a.energy) / 0.75))
				c[pool] -= bite
				a.energy += bite * 0.75
				c.nutrient += bite * 0.25
				a.activity = "Grazing" if pool == "plant" else "Feeding on detritus"
				# Search nearby habitat for richer patches when local food is exhausted.
				if c[pool] < float(cfg.bite):
					var best: float = c[pool]
					for direction in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
						var candidate: Vector2 = p + direction * CELL
						var nc: Dictionary = state.cells[cell_index(candidate)]
						if suitable(candidate, a.species, aquatic(a)) and nc[pool] > best:
							best = nc[pool]
							target = candidate
	elif state.temperature < 4 and a.species in ["frog", "insect"]:
		a.activity = "Sheltering"
		target = p
	var next: Vector2 = p.move_toward(target, float(cfg.move))
	if not suitable(next, a.species, aquatic(a)):
		var level: float = sqrt(state.level)
		var away: Vector2 = ((p - CENTER) / RADII).normalized()
		if a.species == "rodent":
			next = p.move_toward(CENTER + away * RADII * level * 1.25, float(cfg.move))
		elif a.species in ["frog", "heron"] and not aquatic(a):
			next = p.move_toward(CENTER + away * RADII * level, float(cfg.move))
		else:
			next = p.move_toward(CENTER, float(cfg.move))
	next = next.clamp(Vector2(14, 14), Vector2(WIDTH - 14, HEIGHT - 14))
	if next.distance_squared_to(p) > 0.01:
		a.heading = p.angle_to_point(next)
	a.x = next.x
	a.y = next.y
	var season_day: float = fmod(state.tick * DT, 365.0)
	if mates > 0 and mates < (30 if a.species == "insect" else 12) and a.age >= float(cfg.mature) and a.energy > float(cfg.reserve) * 0.72 and season_day < (255 if a.species == "insect" else 185) and state.temperature > 7 and state.tick - a.last_breed > 80:
		if rng.randf() < float(cfg.breed) * DT:
			_reproduce(a)

func _reproduce(a: Dictionary) -> void:
	var cfg: Dictionary = SPECIES[a.species]
	var p := Vector2(a.x, a.y)
	if a.species in ["frog", "insect"]:
		p = CENTER + ((p - CENTER) / RADII).normalized() * RADII * sqrt(state.level) * 0.78
	for _n in int(cfg.litter):
		var cost: float = float(cfg.body) * 0.4 + float(cfg.reserve) * 0.25
		if a.energy < cost + float(cfg.reserve) * 0.15:
			break
		a.energy -= cost
		var baby: Dictionary = spawn(a.species, p, false, true)
		baby.parent = a.id
		_record("birth", baby.id, "%s #%d born to #%d" % [cfg.label, baby.id, a.id], a.species)
		note(baby, "Born to #%d" % a.id)
	a.last_breed = state.tick
	a.activity = "Breeding"
	note(a, "Reproduced; invested reserves in offspring")

func _migration() -> void:
	var day: float = fmod(state.tick * DT, 365.0)
	for species: String in ["insect", "frog", "rodent", "heron"]:
		var probability: float = 0.85 if species == "insect" else 0.35
		if day > 260:
			probability *= 0.12
		if rng.randf() < probability:
			var p: Vector2 = random_position(species)
			if species == "rodent":
				p.x = 18 if rng.randf() < 0.5 else WIDTH - 18
			var c: Dictionary = state.cells[cell_index(p)]
			if c.moisture > 0.12 and state.temperature > 0:
				var a: Dictionary = spawn(species, p)
				state.imported += a.body + a.energy
				_record("arrival", a.id, "%s #%d arrived from surrounding habitat" % [SPECIES[species].label, a.id], species)
	for a: Dictionary in state.animals:
		if a.alive and a.species == "heron" and (day > 265 or a.energy < 1.5) and rng.randf() < 0.22:
			state.exported += a.body + a.energy
			a.body = 0.0
			a.energy = 0.0
			a.alive = false
			a.cause = "departed"
			a.activity = "Migrated away"
			a.died = state.tick
			_record("departure", a.id, "Grey heron #%d departed" % a.id, a.species)

func counts() -> Dictionary:
	var result: Dictionary = {}
	for key: String in SPECIES:
		result[key] = 0
	for a: Dictionary in state.animals:
		if a.alive:
			result[a.species] += 1
	return result

func _sample() -> void:
	var entry: Dictionary = counts()
	entry.tick = state.tick
	entry.temperature = state.temperature
	entry.level = state.level
	state.history.append(entry)
	if state.history.size() > 3000:
		state.history.pop_front()

func material() -> float:
	var total: float = 0.0
	for c: Dictionary in state.cells:
		total += c.plant + c.trees + c.detritus + c.nutrient
	for a: Dictionary in state.animals:
		total += a.body + a.energy
	return total

func residual() -> float:
	return material() - (state.initial_material + state.imported - state.exported)

func snapshot() -> Dictionary:
	return state.duplicate(true)

func export_state() -> Dictionary:
	var result: Dictionary = snapshot()
	result.rng_state = str(rng.state)
	return result

func restore(saved: Dictionary) -> bool:
	if not validate(saved):
		return false
	state = saved.duplicate(true)
	rng.seed = int(state.seed)
	rng.state = int(state.rng_state)
	state.erase("rng_state")
	_build_bins()
	return true

static func validate(saved: Dictionary) -> bool:
	if saved.get("version", -1) != VERSION:
		return false
	for key in ["seed", "tick", "next_id", "world_id", "parent", "branch_tick", "cells", "animals", "events", "history", "commands", "deaths", "totals", "rain_scale", "temperature", "rain", "light", "level", "imported", "exported", "initial_material", "rng_state"]:
		if not saved.has(key):
			return false
	if not saved.cells is Array or saved.cells.size() != COLS * ROWS or not saved.animals is Array:
		return false
	var ids: Dictionary = {}
	for c: Variant in saved.cells:
		if not c is Dictionary:
			return false
		for key in ["x", "y", "r", "plant", "trees", "nutrient", "detritus", "moisture", "oxygen", "decomposition"]:
			if not c.has(key) or not (c[key] is float or c[key] is int) or not is_finite(float(c[key])) or c[key] < 0:
				return false
	for a: Variant in saved.animals:
		if not a is Dictionary:
			return false
		for key in ["id", "species", "x", "y", "px", "py", "age", "body", "energy", "activity", "alive", "cause", "born", "last_breed", "heading", "recent", "depth"]:
			if not a.has(key):
				return false
		if not SPECIES.has(a.species) or ids.has(a.id):
			return false
		ids[a.id] = true
		for key in ["x", "y", "age", "body", "energy"]:
			if not is_finite(float(a[key])) or a[key] < 0:
				return false
	return true

func branch(name: String) -> void:
	state.parent = state.world_id
	state.branch_tick = state.tick
	state.world_id = name
	_record("branch", 0, "Experiment branched from " + state.parent, "")

func intervene(command: Dictionary) -> bool:
	if state.parent == "":
		return false
	var kind: String = command.get("kind", "")
	if kind == "rain":
		var value: float = float(command.get("value", -1))
		if not is_finite(value) or value < 0 or value > 3:
			return false
		state.rain_scale = value
	elif kind == "nutrients":
		var amount: float = float(command.get("value", -1))
		if not is_finite(amount) or amount < 0 or amount > 1000:
			return false
		var wet: Array = state.cells.filter(func(c: Dictionary) -> bool: return c.water)
		for c: Dictionary in wet:
			c.nutrient += amount / wet.size()
		if not wet.is_empty():
			state.imported += amount
	elif kind == "population":
		var species: String = command.get("species", "")
		var amount: int = int(command.get("value", 0))
		if not SPECIES.has(species) or amount < -100 or amount > 100:
			return false
		if amount > 0:
			for _i in amount:
				var a: Dictionary = spawn(species, random_position(species))
				state.imported += a.body + a.energy
		else:
			for a: Dictionary in state.animals:
				if amount >= 0:
					break
				if a.alive and a.species == species:
					state.exported += a.body + a.energy
					a.body = 0.0
					a.energy = 0.0
					a.alive = false
					a.died = state.tick
					a.cause = "experiment removal"
					a.activity = "Removed by experiment"
					amount += 1
	else:
		return false
	var recorded: Dictionary = command.duplicate(true)
	recorded.tick = state.tick
	state.commands.append(recorded)
	_record("intervention", 0, JSON.stringify(command), command.get("species", ""))
	return true
