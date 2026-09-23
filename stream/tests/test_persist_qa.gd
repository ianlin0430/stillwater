extends SceneTree
const PersistQA=preload("res://scripts/persist_qa.gd")
var checks: int=0
var failures: Array[String]=[]

func check(value: bool, message: String) -> void:
	checks+=1
	if not value:
		failures.append(message)
		printerr("FAIL: "+message)

func _initialize() -> void:
	for good: String in ["run1","a_b-C9","20260923-120000_window_close"]:
		check(PersistQA.valid_run_id(good),"Accepts run id "+good)
	for bad: String in ["","../x","a/b","a b","x.y","..","é"]:
		check(not PersistQA.valid_run_id(bad),"Rejects run id '"+bad+"'")
	var dir: String=PersistQA.dir_for("unit-test")
	check(dir.begins_with("user://persistence-qa/"),"Test dir lives under persistence-qa")
	check(ProjectSettings.globalize_path(dir+"stream.world")!=ProjectSettings.globalize_path(StreamStore.DEFAULT_PATH),"Test world never equals the real world path")
	check(ProjectSettings.globalize_path(dir+"preferences.cfg")!=ProjectSettings.globalize_path("user://preferences.cfg"),"Test preferences never equal the real preferences")
	check(DirAccess.make_dir_recursive_absolute(dir)==OK,"Test dir can be created")
	for f: String in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir+f)
	check(PersistQA.next_launch(dir)==1,"First launch is 1")
	var w:=StreamWorld.new(7,1000)
	w.advance_live(60)
	check(StreamStore.save(dir+"stream.world",w)==OK,"Save to test dir")
	var disk: Dictionary=StreamStore.read(dir+"stream.world")
	check(PersistQA.digest(disk)==PersistQA.digest(w.export_state()),"Digest of saved state equals digest after read")
	check(PersistQA.digest({})=="","Empty state has empty digest")
	var s: Dictionary=PersistQA.summary(w.export_state())
	check(s==PersistQA.summary(disk),"Summary equal after save+read")
	check(s.animals.size()==16 and s.animals[0].keys()==["id","name","parent","species"],"Summary lists alive animals with id/name/parent/species")
	check(s.rng==str(w.rng.state) and s.motion_rng==str(w.motion_rng.state) and s.seed==7,"Summary carries both RNG states and seed")
	check(s.events==w.state.events.size() and s.last_event==w.state.events.back(),"Summary carries event count and last event")
	check(s.wall_checkpoint==w.state.wall_checkpoint and s.elapsed==w.state.elapsed and s.resources==w.state.resources,"Summary carries checkpoint, elapsed, resources")
	check(PersistQA.summary({})=={},"Empty summary for missing save")
	var gone: Dictionary=w.state.animals[2]
	w._remove(gone,"old age")
	check(PersistQA.lost(s,w.export_state())==[{"id":gone.id,"cause":"old age"}],"Lost animals report their cause")
	PersistQA.write(dir+"launch-1.json",{"x":1})
	check(PersistQA.next_launch(dir)==2,"Launch counter increments")
	check(JSON.parse_string(FileAccess.get_file_as_string(dir+"launch-1.json"))=={"x":1.0},"Report JSON is written")
	for f: String in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir+f)
	DirAccess.remove_absolute(dir)
	print(JSON.stringify({"checks":checks,"failures":failures.size()}))
	quit(0 if failures.is_empty() else 1)
