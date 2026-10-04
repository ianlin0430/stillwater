extends SceneTree
# Reproduce test_world's unchanged new_cast_checks home-distance gates on an archived backend.
# -- --source=/private/tmp/archived-stream-world.gd (no writes to the archived file).
func _initialize() -> void:
	var source: String=""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--source="): source=arg.trim_prefix("--source=")
	var script:=GDScript.new()
	script.source_code=FileAccess.get_file_as_string(source).replace("class_name StreamWorld","")
	if script.reload()!=OK:
		print(JSON.stringify({"failures":["Archived backend fails to compile"]}))
		quit()
		return
	var w: Variant=script.new(42,1000)
	w.state.light_hour=12.0
	var far: Dictionary={}
	for i in 9000:
		w.advance_live(0.2)
		for a: Dictionary in w.state.animals:
			if not a.has("home"): continue
			far[a.species]=maxf(far.get(a.species,0.0),Vector2(a.x-a.home_x,a.y-a.home_y).length())
	var failures: Array=[]
	for species: String in far:
		var limit: float=2.0*script.get_script_constant_map().HOME[species].radius
		if far[species]>limit: failures.append("%s %.6f > %.6f" % [species,far[species],limit])
	print(JSON.stringify({"checks":3,"failures":failures,"seed":42,"seconds":1800,"numbers":far,"source":source}))
	quit()
