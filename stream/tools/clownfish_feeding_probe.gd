extends SceneTree
# Replays the unchanged test_natural_motion feeding scenario; adds reporting only.
func _initialize() -> void:
	var source: String=FileAccess.get_file_as_string("res://tests/test_natural_motion.gd")
	source=source.replace("extends SceneTree","extends RefCounted\nvar feeding_trace: Array=[]")
	var first: int=source.find("func _initialize()")
	var last: int=source.find("func kinematics_checks()",first)
	source=source.substr(0,first)+source.substr(last)
	var marker: String="\t\t\tw.advance_live(0.2)\n\t\t\tfor sp: String in"
	var extra: String="\t\t\tw.advance_live(0.2)\n\t\t\tif i%10==0 and w.state.get(\"food\",[]).any(func(f): return absf(f.y-of(w,\"clownfish\")[0].home_y)<140.0):\n\t\t\t\tfeeding_trace.append({\"t\":w.state.elapsed,\"pinch\":k,\"clowns\":of(w,\"clownfish\").map(func(a): return {\"id\":a.id,\"p\":[a.x,a.y],\"target\":[a.tx,a.ty],\"activity\":a.activity,\"v\":[a.get(\"vx\"),a.get(\"vy\")],\"avoid\":[a.get(\"avoid_x\"),a.get(\"avoid_y\")],\"energy\":a.energy,\"home\":[a.home_x,a.home_y],\"food_id\":a.get(\"food_id\")}),\"food\":w.state.food.duplicate(true)})\n\t\t\tfor sp: String in"
	assert(source.contains(marker))
	source=source.replace(marker,extra)
	var script:=GDScript.new()
	script.source_code=source
	if script.reload()!=OK:
		print(JSON.stringify({"failures":["Reporting copy does not compile"]}))
		quit()
		return
	var probe: Variant=script.new()
	probe.feeding_checks()
	print(JSON.stringify({"checks":probe.checks,"failures":probe.failures,"numbers":probe.numbers,"trace":probe.feeding_trace}))
	quit()
