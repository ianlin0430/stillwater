extends RefCounted
# Helpers for the isolated --persist-qa=<run_id> mode. Normal startup never uses them.
const ROOT: String="user://persistence-qa/"

static func valid_run_id(run_id: String) -> bool:
	return RegEx.create_from_string("^[A-Za-z0-9_-]+$").search(run_id)!=null

static func dir_for(run_id: String) -> String:
	return ROOT+run_id+"/"

static func digest(saved: Dictionary) -> String:
	return "" if saved.is_empty() else StreamStore._digest(var_to_bytes(saved))

static func summary(saved: Dictionary) -> Dictionary:
	if saved.is_empty():
		return {}
	var animals: Array=[]
	for a: Dictionary in saved.animals:
		animals.append({"id":a.id,"name":a.name,"parent":a.parent,"species":a.species})
	return {"animals":animals,"resources":saved.resources,"events":saved.events.size(),"last_event":saved.events.back() if not saved.events.is_empty() else {},"totals":saved.totals,"seed":saved.seed,"rng":saved.rng,"motion_rng":saved.motion_rng,"wall_checkpoint":saved.wall_checkpoint,"elapsed":saved.elapsed}

# Animals alive in `before` (a summary) that are gone from `saved`, with their archived cause.
static func lost(before: Dictionary, saved: Dictionary) -> Array:
	var alive: Array=saved.animals.map(func(a: Dictionary) -> int: return a.id)
	var out: Array=[]
	for a: Dictionary in before.get("animals",[]):
		if a.id not in alive:
			var cause: String="unknown"
			for gone: Dictionary in saved.archive:
				if gone.id==a.id:
					cause=gone.get("cause","unknown")
			out.append({"id":a.id,"cause":cause})
	return out

static func next_launch(dir: String) -> int:
	var n: int=1
	while FileAccess.file_exists(dir+"launch-%d.json" % n):
		n+=1
	return n

static func write(path: String, data: Dictionary) -> void:
	var f:=FileAccess.open(path,FileAccess.WRITE)
	if f!=null:
		f.store_string(JSON.stringify(data,"  ",true,true))
