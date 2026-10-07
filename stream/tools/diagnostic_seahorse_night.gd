extends SceneTree
# Exact S7 shipwreck/seed3 trigger, isolated in memory. Temporary diagnosis;
# this entry point never replaces the original full eight-seed species gate.

class TracedWorld:
	extends StreamWorld
	var next_trace: float=INF
	func sample() -> Array:
		var rows: Array=[]
		for a: Dictionary in state.animals:
			if a.species!="seahorse": continue
			var p:=Vector2(a.x,a.y)
			var home:=_hitch_center(a)
			var nearby: Array=[]
			for o: Dictionary in state.animals:
				if o.id==a.id: continue
				var r: Vector2=(_body(a)+_body(o))*.5*1.5
				if absf(a.x-o.x)<r.x and absf(a.y-o.y)<r.y:
					nearby.append({"id":o.id,"species":o.species,"at":Vector2(o.x,o.y),"activity":o.activity,"body":_body(o)})
			rows.append({"id":a.id,"activity":a.activity,"at":p,"target":Vector2(a.tx,a.ty),"home":home,"gap":p.distance_to(home),"direction":a.direction,"hitch_facing":_hitch_facing(a),"decision_in":a.decision_at-state.elapsed,"path":a.get("hitch_path",[]),"nav":Vector2(a.get("nav_x",INF),a.get("nav_y",INF)),"avoid":Vector2(a.get("avoid_x",0.0),a.get("avoid_y",0.0)),"velocity":Vector2(a.get("vx",0.0),a.get("vy",0.0)),"direct_clear":_horse_segment_clear(a,p,home),"obstacle":_blocker(p,home,_radii_of(a),-1),"nearby":nearby})
		return rows
	func _move(delta: float) -> void:
		super._move(delta)
		if state.light_hour<7 and state.elapsed>=next_trace:
			next_trace=state.elapsed+15.0
			print("[DIAG-night-horse] "+JSON.stringify({"elapsed":state.elapsed,"horses":sample()}))

func _initialize() -> void:
	var w:=StreamWorld.new(3,1000,"shipwreck")
	var input_fixture: String=""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--fixture="): input_fixture=arg.trim_prefix("--fixture=")
	if input_fixture.is_empty():
		w.state.light_hour=12.0
		for i in 9000: w.advance_live(.2)
	else:
		var source:=FileAccess.open(input_fixture,FileAccess.READ)
		if source==null:
			printerr("ERROR: missing isolated night fixture")
			quit(2)
			return
		var original: Dictionary=source.get_var()
		source.close()
		if not w.restore(original) or var_to_bytes(w.export_state())!=var_to_bytes(original):
			printerr("ERROR: fixture does not restore byte-identically")
			quit(2)
			return
	var before: Dictionary=w.export_state()
	DirAccess.make_dir_recursive_absolute("res://artifacts/night-horse")
	var fixture:=FileAccess.open("res://artifacts/night-horse/before.var",FileAccess.WRITE)
	fixture.store_var(before)
	fixture.close()
	w.state.light_hour=0.0
	w.advance_live(120)
	var traced:=TracedWorld.new()
	var restored: bool=traced.restore(before)
	var exact_before: bool=restored and var_to_bytes(traced.export_state())==var_to_bytes(before)
	traced.state.light_hour=0.0
	traced.next_trace=traced.state.elapsed
	print("[DIAG-night-horse] before "+JSON.stringify(traced.sample()))
	traced.advance_live(120)
	print("[DIAG-night-horse] after "+JSON.stringify(traced.sample()))
	var failures: Array[String]=[]
	if not exact_before: failures.append("The diagnostic restores the exact original pre-night state")
	if var_to_bytes(w.export_state())!=var_to_bytes(traced.export_state()): failures.append("Tracing leaves the complete world byte-identical")
	if not w.state.animals.filter(func(a): return a.species=="seahorse").all(func(a): return a.activity=="Hitched"): failures.append("shipwreck/3: all horses hitch at night")
	print(JSON.stringify({"checks":3,"failures":failures,"baseline_horses":w.state.animals.filter(func(a): return a.species=="seahorse")}))
	quit(0 if failures.is_empty() else 1)
