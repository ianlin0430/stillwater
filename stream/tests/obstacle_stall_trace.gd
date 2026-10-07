extends "res://scripts/stream_world.gd"
# Temporary diagnostic: isolate each neighbor's contribution without changing
# the final production call. _avoid has only the transient _dodge side effect.
var trace_start: float=0.0
var trace_end: float=0.0

func _avoid(a: Dictionary, p: Vector2, desired: Vector2, speed: float) -> Vector2:
	if a.species=="seahorse" and state.elapsed>=trace_start and state.elapsed<=trace_end and int(round(state.elapsed*5.0))%25==0:
		var animals: Array=state.animals
		var contributions: Array=[]
		for other: Dictionary in animals:
			if other.id==a.id: continue
			state.animals=[a,other]
			var change: Vector2=super._avoid(a,p,desired,speed)-desired
			if change.length()>.01:
				contributions.append({"id":other.id,"species":other.species,"at":Vector2(other.x,other.y),"change":change})
		state.animals=animals
		print("[DIAG-neighbor] "+JSON.stringify({"t":state.elapsed,"id":a.id,"at":p,"desired":desired,"contributions":contributions}))
	return super._avoid(a,p,desired,speed)
