extends SceneTree
# Reporting-only copy of the exact test_obstacles.run, with per-id centre-entry evidence.
# No test file or gate is modified; only run(false) is needed for centre counts.
func _initialize() -> void:
	var source: String=FileAccess.get_file_as_string("res://tests/test_obstacles.gd")
	source=source.replace("extends SceneTree","extends RefCounted")
	var first: int=source.find("func _initialize()")
	var last: int=source.find("func seed_list()",first)
	source=source.substr(0,first)+source.substr(last)
	source=source.replace('"inside":0,"soft":0.0', '"inside":0,"per_id":{},"samples":[],"soft":0.0')
	var marker: String="\t\t\t\t\tr.inside+=1"
	var extra: String="\n\t\t\t\t\tvar key: String=str(a.id)+\"/\"+str(oi)\n\t\t\t\t\tvar row: Dictionary=r.per_id.get(key,{\"species\":a.species,\"count\":0,\"activities\":{},\"first_t\":t,\"last_t\":t})\n\t\t\t\t\trow.count+=1\n\t\t\t\t\trow.activities[a.activity]=row.activities.get(a.activity,0)+1\n\t\t\t\t\trow.last_t=t\n\t\t\t\t\tr.per_id[key]=row\n\t\t\t\t\tif row.count<=3 or row.count%50==0:\n\t\t\t\t\t\tr.samples.append({\"t\":t,\"id\":a.id,\"activity\":a.activity,\"p\":[a.x,a.y],\"previous\":str(prev.get(a.id,{}).get(\"p\",Vector2.INF)),\"target\":[a.tx,a.ty],\"home\":[a.get(\"home_x\"),a.get(\"home_y\")],\"obstacle\":o,\"q\":raw_q(p,o),\"velocity\":[a.vx,a.vy]})"
	source=source.replace(marker,marker+extra)
	var script:=GDScript.new()
	script.source_code=source
	if script.reload()!=OK:
		print(JSON.stringify({"failures":["Reporting copy does not compile"]}))
		quit()
		return
	var probe: Variant=script.new()
	var selected: Array=[23,240921,2,29,37,17]
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--seeds="): selected=Array(arg.trim_prefix("--seeds=").split(",")).map(func(s): return int(s))
	var rows: Dictionary={}
	var total: int=0
	for seed_value: int in selected:
		var r: Dictionary=probe.run(seed_value,"reef","max",false)
		total+=r.inside
		rows[str(seed_value)]={"inside":r.inside,"per_id":r.per_id,"samples":r.samples}
		print("CENTRES seed %d: %d %s" % [seed_value,r.inside,JSON.stringify(r.per_id)])
	print(JSON.stringify({"failures":[] if total==0 else ["Centre-inside %d ticks" % total],"numbers":rows}))
	quit()
