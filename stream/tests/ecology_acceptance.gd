extends RefCounted
# Long-run gates for the reef cast (2026-09-24; re-derived the same day for the five-species cast
# with the yellow tang and purple firefish), computed from the configured species and written
# down in docs/ecology.md "Acceptance gates" before any live run was judged.

# Counts offspring individuals, not breeding attempts or broods. Keep retained
# births separate so downstream dispersal cannot hide dependence on immigration.
static func offspring_produced(run: Dictionary) -> int:
	return int(run.births)+int(run.dispersal)

static func _openers(species: String) -> Array:
	var span: Array=StreamWorld.OPENING_AGE.get(species,StreamWorld.OPENING_AGE.fish)
	var n: int=int(StreamWorld.SPECIES[species].initial)
	var lows: Array=[]
	for i in n:
		lows.append(span[0]+(span[1]-span[0])*i/n)
	return lows

# Openers whose life must end within `days` under every draw: the youngest possible age in
# their stratum plus `days` exceeds the longest possible lifespan (1.15 x species lifespan).
static func certain_old_age(days: int) -> int:
	var n: int=0
	for species: String in StreamWorld.ACTIVE_SPECIES:
		for low: float in _openers(species):
			if low+days>StreamWorld.SPECIES[species].lifespan*1.15:
				n+=1
	return n

# Latest day by which the oldest opener of some species must have died of old age.
static func first_old_age_bound() -> int:
	var bound: float=INF
	for species: String in StreamWorld.ACTIVE_SPECIES:
		var lows: Array=_openers(species)
		if not lows.is_empty():
			bound=minf(bound,StreamWorld.SPECIES[species].lifespan*1.15-lows[-1])
	return int(ceil(bound))

# Local young enough to fill the places open at the start and to replace every opener
# that must die of old age.
static func offspring_needed(days: int) -> int:
	return certain_old_age(days)+StreamWorld.habitat_cap()-population_band()[0]

# From the opening cast up to the combined habitat caps.
static func population_band() -> Array:
	var opening: int=0
	for species: String in StreamWorld.ACTIVE_SPECIES:
		opening+=int(StreamWorld.SPECIES[species].initial)
	return [opening,StreamWorld.habitat_cap()]

static func reproduction_passes(run: Dictionary) -> bool:
	return offspring_produced(run)>=offspring_needed(int(run.days))

static func local_replacement_passes(run: Dictionary) -> bool:
	return run.births>run.arrivals

static func old_age_passes(run: Dictionary) -> bool:
	return run.old_age>=certain_old_age(int(run.days)) and run.first_old_age_day>0 and run.first_old_age_day<=first_old_age_bound()
