extends "res://tests/test_natural_motion.gd"
var current_world: StreamWorld
var reported: Dictionary={}
func make(seed_value: int, scene_id: String) -> Variant:
	current_world=super.make(seed_value,scene_id)
	return current_world
func raw_q(p: Vector2, o: Dictionary) -> float:
	var q: float=super.raw_q(p,o)
	if q<1.0:
		for a: Dictionary in current_world.state.animals:
			if Vector2(a.x,a.y)==p:
				var key: String=str([current_world.state.scene,current_world.state.seed,a.id,o])
				if not reported.has(key):
					reported[key]=true
					print("INSIDE "+JSON.stringify({"seed":current_world.state.seed,"scene":current_world.state.scene,"time":current_world.state.elapsed,"fish":a,"obstacle":o}))
	return q
func _initialize() -> void:
	super._initialize()
