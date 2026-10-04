extends "res://tests/test_natural_motion.gd"
# Fast subset; inherited methods and every assertion are unchanged.
func seeds(_fallback: Array) -> Array:
	return [42,11]
func night_pass(species: String, dy: float) -> Dictionary:
	var result: Dictionary=super.night_pass(species,dy)
	print("NIGHT_PASS "+JSON.stringify({"species":species,"dy":dy,"result":result}))
	return result
func _initialize() -> void:
	var rows: Dictionary={}
	for method: String in ["band_edge_checks","separation_checks","feeding_checks","night_rest_checks","obstacle_checks"]:
		var first: int=failures.size()
		var start: int=Time.get_ticks_msec()
		call(method)
		rows[method]={"failures":failures.slice(first),"ms":Time.get_ticks_msec()-start}
		print("PART "+method+" "+JSON.stringify(rows[method]))
	print(JSON.stringify({"checks":checks,"failures":failures,"numbers":numbers,"parts":rows,"subset_seeds":[42,11]}))
	quit(0 if failures.is_empty() else 1)
