extends SceneTree
# Self-test of tools/cast_probe.gd (S0): every option the probe advertises must reach the
# patched world source, and the patched world must still compile and run. Also pins the
# wide seed lists (tests/seed_lists.gd).
const Probe=preload("res://tools/cast_probe.gd")
const Seeds=preload("res://tests/seed_lists.gd")
var checks: int=0
var failures: Array[String]=[]

func check(value: bool, message: String) -> void:
	checks+=1
	if not value:
		failures.append(message)
		printerr("FAIL: "+message)

func _initialize() -> void:
	var cfg: Dictionary={"name":"probe-self-test","rescue_at":0,
		"stream_in":{"nutrients":0.7,"microfauna":0.85},
		"opening_age":{"fish":[40.0,150.0],"yellow_tang":[130.0,260.0],"green_chromis":[35.0,90.0]}}
	var src: String=Probe.patched_source(cfg)
	check(src.contains("const RESCUE_AT: int = 0"),"rescue_at=0 reaches the patched source as RESCUE_AT: int = 0")
	check(not src.contains("const RESCUE_AT: int = 1"),"the original RESCUE_AT line is replaced, not duplicated")
	check(src.contains('const STREAM_IN: Dictionary = {"microfauna":0.85,"nutrients":0.7}') or src.contains('const STREAM_IN: Dictionary = {"nutrients":0.7,"microfauna":0.85}'),"stream_in reaches the patched source")
	check(src.contains('"green_chromis":[35.0,90.0]') or src.contains('"green_chromis":[35,90]'),"opening_age reaches the patched source")
	var script: GDScript=Probe.compile(src)
	check(script!=null,"patched world compiles")
	if script!=null:
		check(script.RESCUE_AT==0,"compiled RESCUE_AT is 0")
		check(is_equal_approx(float(script.STREAM_IN.microfauna),0.85),"compiled STREAM_IN.microfauna is 0.85")
		check(script.OPENING_AGE.has("green_chromis"),"compiled OPENING_AGE has the new entry")
		var world: RefCounted=script.new(42)
		var result: Dictionary=Probe.run(world,1,"probe-self-test",42)
		check(result.get("seed",-1)==42 and result.has("end"),"patched world runs one day through Probe.run")
	# floor (S2): measurement only. A floor above every animal's energy counts every animal-minute;
	# the patched world otherwise runs exactly like the unpatched one (same seed, same counts).
	var floored: String=Probe.patched_source({"floor":1.01})
	check(floored.contains("probe_floor_hits[a.species]") and floored.contains("if probe_left<1.01"),"floor instrumentation reaches the patched source")
	var fscript: GDScript=Probe.compile(floored)
	check(fscript!=null,"instrumented world compiles")
	if fscript!=null:
		var fr: Dictionary=Probe.run(fscript.new(42),2,"floor-self-test",42,1)
		var plain: Dictionary=Probe.run(load("res://scripts/stream_world.gd").new(42),2,"plain",42)
		var hits: int=0
		for sp: String in fr.get("floor_hits",{}):
			hits+=int(fr.floor_hits[sp])
		check(hits>=12*2*1440,"floor 1.01 counts every animal-minute (%d)"%hits)
		check(fr.get("min_energy",{}).size()>0,"min_energy is reported")
		check(fr.sizes_by_day==plain.sizes_by_day and fr.end==plain.end and fr.microfauna_min_mean==plain.microfauna_min_mean,"instrumented world runs like the plain one")
		check(fr.has("at_1") and fr.at_1.days==1 and fr.days==2,"--mid adds the day-1 measures")
		check(not plain.has("floor_hits"),"no floor option, no floor_hits")
	# Unpatched source is the real world file, byte for byte (no config, no change).
	check(Probe.patched_source({})==FileAccess.get_file_as_string("res://scripts/stream_world.gd").replace("class_name StreamWorld\n",""),"an empty config only drops class_name")
	# Wide seed list: fixed contents, 32 distinct seeds, motion list is its first eight.
	check(Seeds.WIDE.size()==32,"WIDE has 32 seeds")
	var uniq: Dictionary={}
	for s: int in Seeds.WIDE:
		uniq[s]=true
	check(uniq.size()==32,"WIDE seeds are distinct")
	check(Seeds.WIDE.slice(0,3)==[42,812,240921] and Seeds.WIDE[-1]==999983,"WIDE keeps the planned order")
	check(Seeds.motion()==[42,812,240921,1,2,3,5,7],"motion() is the first eight of WIDE")
	print(JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
