extends RefCounted

# Counts offspring individuals, not breeding attempts or broods. Keep retained
# births separate so downstream dispersal cannot hide dependence on immigration.
static func offspring_produced(run: Dictionary) -> int:
	return int(run.births)+int(run.dispersal)

static func reproduction_passes(run: Dictionary) -> bool:
	return offspring_produced(run)>=20

static func local_replacement_passes(run: Dictionary) -> bool:
	return run.births>run.arrivals
