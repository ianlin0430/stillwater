extends SceneTree
# Chunked long runs (tests/long_run.gd --from-day/--to-day/--checkpoint-*) must give exactly the run
# an unchunked invocation gives: (a) the long_run CLI itself, offline, whole vs three chunks through
# real checkpoint files; (b) the live world across StreamStore save/read/restore, food in the water.
const DIR: String = "res://artifacts/chunk-test/"
const DAYS: int = 36
var failures: Array[String]=[]
var checks: int=0

func check(value: bool, message: String) -> void:
	checks+=1
	if not value:
		failures.append(message)

func _initialize() -> void:
	var start: int=Time.get_ticks_msec()
	DirAccess.make_dir_recursive_absolute(DIR)
	for file: String in DirAccess.get_files_at(DIR):
		DirAccess.remove_absolute(DIR+file)
	chunked_cli()
	habitat_chunks()
	live_continuity()
	print(JSON.stringify({"checks":checks,"failures":failures,"seconds":(Time.get_ticks_msec()-start)/1000.0}))
	quit(0 if failures.is_empty() else 1)

# Execute the actual CLI code in this Godot process: no child process or default userdata
# logger. Argument parsing, checkpoint files, report generation, output and exit gates are
# unchanged; only the SceneTree/OS shell is replaced with a RefCounted capture adapter.
func long_run(args: Array) -> Array:
	var source: String=FileAccess.get_file_as_string("res://tests/long_run.gd")
	source=source.replace("extends SceneTree","extends RefCounted")
	source=source.replace("OS.get_cmdline_user_args()","_serial_args")
	source=source.replace("print(","_serial_print(").replace("quit(","_serial_quit(")
	source+="\nvar _serial_args: Array=[]\nvar _serial_output: Array[String]=[]\nvar _serial_code: int=0\nfunc _serial_print(value: Variant) -> void:\n\t_serial_output.append(str(value))\nfunc _serial_quit(code: int=0) -> void:\n\t_serial_code=code\n"
	var script:=GDScript.new()
	script.source_code=source
	if script.reload()!=OK:
		return [1,"CLI capture adapter failed to compile"]
	var run: Variant=script.new()
	run._serial_args=args
	run._initialize()
	return [run._serial_code,"\n".join(run._serial_output)]

func report(name: String) -> Dictionary:
	var parsed: Variant=JSON.parse_string(FileAccess.get_file_as_string(DIR+name))
	if not parsed is Dictionary:
		return {}
	for run: Dictionary in parsed.runs:
		run.erase("seconds")
		run.erase("chunks")
	return parsed

func tally(path: String) -> Dictionary:
	var f:=FileAccess.open(path+".tally",FileAccess.READ)
	var t: Variant=f.get_var(false) if f!=null else null
	if not t is Dictionary:
		return {}
	t.erase("seconds")
	t.erase("chunks")
	return t

func chunked_cli() -> void:
	# Fed daily so the feeding tally and food particles cross the chunk boundaries; 36 days so a
	# monthly row (day 30) falls inside the last chunk.
	var base: Array=["--mode=offline","--days=%d" % DAYS,"--seeds=812","--year=false","--feed=daily"]
	var whole: Array=long_run(base+["--out=chunk-test/whole.json"])
	var single: Array=long_run(base+["--out=chunk-test/single.json","--checkpoint-out=chunk-test/single.world"])
	var third: int=DAYS/3
	var one: Array=long_run(base+["--out=chunk-test/chunked.json","--to-day=%d" % third,"--checkpoint-out=chunk-test/c1.world"])
	var two: Array=long_run(base+["--out=chunk-test/chunked.json","--from-day=%d" % third,"--to-day=%d" % (2*third),"--checkpoint-in=chunk-test/c1.world","--checkpoint-out=chunk-test/c2.world"])
	check(one[0]==0 and "CHUNK seed 812 days 0-12 of 36 saved" in one[1],"Chunk 1 saves its checkpoint and exits 0: "+one[1].right(300))
	check(two[0]==0 and "RESUME seed 812 from day 12" in two[1] and not FileAccess.file_exists(DIR+"chunked.json"),"Chunk 2 resumes, saves and writes no report yet: "+two[1].right(300))
	var three: Array=long_run(base+["--out=chunk-test/chunked.json","--from-day=%d" % (2*third),"--checkpoint-in=chunk-test/c2.world","--checkpoint-out=chunk-test/c3.world"])
	check("ACCEPTANCE" in whole[1] and "ACCEPTANCE" in three[1] and whole[0]==three[0] and single[0]==whole[0],"The final chunk judges like the unchunked run (exit %d vs %d)" % [three[0],whole[0]])
	var r_whole: Dictionary=report("whole.json")
	check(not r_whole.is_empty() and r_whole.runs.size()==1,"The unchunked run writes its report")
	check(var_to_bytes(report("chunked.json"))==var_to_bytes(r_whole),"Three chunks report exactly what the unchunked run reports (timing aside)")
	check(var_to_bytes(report("single.json"))==var_to_bytes(r_whole),"One 0-%d chunk reports exactly what the unchunked run reports" % DAYS)
	var chunks: Variant=JSON.parse_string(FileAccess.get_file_as_string(DIR+"chunked.json")).runs[0].get("chunks")
	check(chunks is Array and chunks.map(func(c): return [int(c.from_day),int(c.to_day)])==[[0,12],[12,24],[24,36]],"The chunked report lists its chunks: "+str(chunks))
	var w_single: Dictionary=StreamStore.read(DIR+"single.world")
	check(not w_single.is_empty() and var_to_bytes(StreamStore.read(DIR+"c3.world"))==var_to_bytes(w_single),"The world after three chunks is byte-identical to the world after one")
	check(not tally(DIR+"single.world").is_empty() and var_to_bytes(tally(DIR+"c3.world"))==var_to_bytes(tally(DIR+"single.world")),"Every accumulator after three chunks is byte-identical (timing aside)")
	# Hosted acceptance now uses ten bounded chunks. Exercise uneven integer
	# day boundaries too, retaining exact food, monthly rows, RNG and tallies.
	var prior: String=""
	var ten_ok: bool=true
	var bounds: Array=[]
	for i in 10:
		var start_day: int=DAYS*i/10
		var end_day: int=DAYS*(i+1)/10
		var checkpoint: String="chunk-test/ten%d.world" % i
		var args: Array=base+["--out=chunk-test/ten.json","--from-day=%d" % start_day,"--to-day=%d" % end_day,"--checkpoint-out="+checkpoint]
		if not prior.is_empty(): args.append("--checkpoint-in="+prior)
		var part: Array=long_run(args)
		ten_ok=ten_ok and part[0]==(whole[0] if i==9 else 0)
		bounds.append([start_day,end_day])
		prior=checkpoint
	check(ten_ok,"Ten chunks complete every interval and judge only the last one")
	check(var_to_bytes(report("ten.json"))==var_to_bytes(r_whole),"Ten chunks preserve the complete report exactly (timing aside)")
	check(var_to_bytes(StreamStore.read(DIR+"ten9.world"))==var_to_bytes(w_single),"Ten chunks preserve the exact final world")
	check(var_to_bytes(tally(DIR+"ten9.world"))==var_to_bytes(tally(DIR+"single.world")),"Ten chunks preserve every exact accumulator (timing aside)")
	var ten_chunks: Array=JSON.parse_string(FileAccess.get_file_as_string(DIR+"ten.json")).runs[0].chunks
	check(ten_chunks.map(func(c): return [int(c.from_day),int(c.to_day)])==bounds,"Ten chunks report all exact boundaries")
	var wrong: Array=long_run(base+["--out=chunk-test/wrong.json","--from-day=%d" % third,"--checkpoint-in=chunk-test/c2.world"])
	check(wrong[0]==1 and "CHUNK ERROR" in wrong[1] and not FileAccess.file_exists(DIR+"wrong.json"),"Resuming from a checkpoint of another day fails loudly")
	var two_seeds: Array=long_run(["--mode=offline","--days=6","--seeds=42,812","--to-day=2","--checkpoint-out=chunk-test/x.world"])
	check(two_seeds[0]==1 and "CHUNK ERROR" in two_seeds[1],"A chunked run refuses more than one seed")

func habitat_chunks() -> void:
	for scene_id: String in ReefScene.IDS:
		for decor: String in ["min","max"]:
			var tag: String=scene_id+"-"+decor
			var prefix: String="chunk-test/"+tag
			var base: Array=["--mode=offline","--days=6","--seeds=42","--year=false","--feed=daily","--scene="+scene_id,"--decor="+decor]
			var whole: Array=long_run(base+["--out="+prefix+"-whole.json","--checkpoint-out="+prefix+"-whole.world"])
			var first: Array=long_run(base+["--to-day=3","--checkpoint-out="+prefix+"-first.world"])
			check(first[0]==0,tag+": first habitat chunk saves")
			var second: Array=long_run(base+["--from-day=3","--checkpoint-in="+prefix+"-first.world","--out="+prefix+"-split.json","--checkpoint-out="+prefix+"-split.world"])
			check(whole[0]==second[0] and "ACCEPTANCE" in second[1],tag+": same final acceptance verdict")
			check(var_to_bytes(report(tag+"-whole.json"))==var_to_bytes(report(tag+"-split.json")),tag+": whole and split reports match")
			check(var_to_bytes(StreamStore.read(DIR+tag+"-whole.world"))==var_to_bytes(StreamStore.read(DIR+tag+"-split.world")),tag+": whole and split worlds match")
			check(var_to_bytes(tally(DIR+tag+"-whole.world"))==var_to_bytes(tally(DIR+tag+"-split.world")),tag+": whole and split accumulators match")
			var wrong: Array=long_run(base+["--from-day=3","--checkpoint-in="+prefix+"-first.world","--decor="+("max" if decor=="min" else "min"),"--out="+prefix+"-wrong.json"])
			check(wrong[0]==1 and "CHUNK ERROR" in wrong[1],tag+": mismatched habitat resume rejected")

func first_difference(a: Variant, b: Variant, path: String) -> String:
	if typeof(a)!=typeof(b):
		return "%s: type %d vs %d" % [path,typeof(a),typeof(b)]
	if a is Dictionary:
		for key: Variant in a.keys()+b.keys():
			if not a.has(key) or not b.has(key):
				return "%s.%s: only on one side" % [path,key]
			var d: String=first_difference(a[key],b[key],"%s.%s" % [path,key])
			if d!="":
				return d
		if a.keys()!=b.keys():
			return path+": key order differs"
		return ""
	if a is Array:
		if a.size()!=b.size():
			return "%s: size %d vs %d" % [path,a.size(),b.size()]
		for i in a.size():
			var d: String=first_difference(a[i],b[i],"%s[%d]" % [path,i])
			if d!="":
				return d
		return ""
	return "" if var_to_bytes(a)==var_to_bytes(b) else "%s: %s vs %s" % [path,var_to_str(a),var_to_str(b)]

func same_state(a: StreamWorld, b: StreamWorld, label: String) -> void:
	var sa: Dictionary=a.export_state()
	var sb: Dictionary=b.export_state()
	check(var_to_bytes(sa)==var_to_bytes(sb),"%s: export_state identical (first difference: %s)" % [label,first_difference(sa,sb,"state")])

func live_continuity() -> void:
	var path: String=DIR+"live.world"
	var a:=StreamWorld.new(812)
	# The app steps advance_live every frame; long_run steps it an hour at a time.
	a.advance_live(1800.0)
	check(a.feed(640.0),"A pinch of food drops before the split")
	a.advance_live(4.0)
	for i in 25:
		a.advance_live(1.0/60.0)
	check(not a.state.get("food",[]).is_empty(),"Food particles are in the water at the split")
	check(a.state.motion_remainder>0.0,"The split falls between two 0.2 s motion ticks")
	check(StreamStore.save(path,a)==OK,"The live world saves")
	var b:=StreamWorld.new(812)
	check(b.restore(StreamStore.read(path)),"A fresh world restores the save")
	same_state(a,b,"Right after restore")
	for world: StreamWorld in [a,b]:
		for i in 600:
			world.advance_live(1.0/60.0)
		world.feed(300.0)
		world.advance_live(3600.0)
		for i in 900:
			world.advance_live(1.0/30.0)
	check(a.state.motion_ticks>=27000,"Over 1.5 simulated hours of live ticks ran (%d)" % a.state.motion_ticks)
	same_state(a,b,"After another hour live")
