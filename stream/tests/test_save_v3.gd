extends SceneTree
# Save format v3 (docs/plans/2026-09-28-redesign-backend.md S3, §5.2): Stillwater Reef starts a
# new world in a new file. Stillwater Stream saves (world v1/v2, envelope "stillwater-stream-1")
# are never loaded, converted, rewritten or deleted, and finding one never piles up recovery worlds.
# Every file this touches lives under res://artifacts/save-v3-test/ (git-ignored), never user://.
const Absence=preload("res://scripts/absence.gd")
const DIR: String="res://artifacts/save-v3-test/"
const OLD_FORMAT: String="stillwater-stream-1"
var checks: int=0
var failures: Array[String]=[]

func check(value: bool, message: String) -> void:
	checks+=1
	if not value:
		failures.append(message)
		printerr("FAIL: "+message)

func fixture(name: String) -> Dictionary:
	var f:=FileAccess.open("res://tests/fixtures/"+name,FileAccess.READ)
	var v: Dictionary=f.get_var()
	f.close()
	return v

# A file exactly as Stillwater Stream's StreamStore wrote it (envelope, payload, SHA-256).
func write_old(path: String, saved: Dictionary) -> void:
	var bytes: PackedByteArray=var_to_bytes(saved)
	var f:=FileAccess.open(path,FileAccess.WRITE)
	f.store_var({"format":OLD_FORMAT,"payload":bytes,"hash":StreamStore._digest(bytes)})
	f.close()

func files(dir: String) -> Array:
	var out: Array=Array(DirAccess.get_files_at(dir))
	out.sort()
	return out

func ids(world: StreamWorld) -> Array:
	return world.state.animals.map(func(a: Dictionary) -> Array: return [a.id,a.name,a.parent,a.species])

func clean(dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	for f: String in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir+f)

func opening() -> Dictionary:
	var out: Dictionary={}
	for k: String in StreamWorld.ACTIVE_SPECIES:
		out[k]=StreamWorld.SPECIES[k].initial
	return out

# main.gd's startup: the path comes from preferences.cfg, and the path load_or_create returns is written back.
func launch(prefs: String, now: float) -> Dictionary:
	var settings:=ConfigFile.new()
	settings.load(prefs)
	var loaded: Dictionary=StreamStore.load_or_create(settings.get_value("world","path",StreamStore.DEFAULT_PATH),now)
	settings.set_value("world","path",loaded.path)
	settings.save(prefs)
	return loaded

func _initialize() -> void:
	preload("res://tests/test_store_truncated.gd").framing_checks(check)
	# --- The format ---
	check(StreamWorld.VERSION==3,"World format is version 3")
	check(StreamStore.DEFAULT_PATH=="user://reef.world","The save lives in user://reef.world")
	check(load("res://scripts/stream_store.gd").get_script_constant_map().get("FORMAT")=="stillwater-reef-3","The envelope is stillwater-reef-3")
	var w:=StreamWorld.new(42,1000)
	check(w.state.version==3 and StreamWorld.validate(w.export_state()),"A new world is v3 and validates")
	check(not w.state.has("reef_cast") and not w.state.has("eel_colony"),"A new world carries no upgrade flags")
	check(not w.state.totals.has("molt") and not w.state.totals.has("predation"),"A new world carries no molt/predation totals")
	check(w.state.animals.all(func(a: Dictionary) -> bool: return not a.has("next_molt") and not a.has("molting_until") and not a.has("shelter")),"Animals carry no shrimp-era fields")
	check(StreamWorld.ACTIVE_SPECIES.all(func(k: String) -> bool: return StreamWorld.SPECIES.has(k)) and StreamWorld.SPECIES.size()==StreamWorld.ACTIVE_SPECIES.size(),"SPECIES holds only the active cast (no legacy entries)")
	check(not "REEF_CAST" in StreamWorld.new().get_script().get_script_constant_map(),"REEF_CAST is gone")
	check(not w.has_method("_upgrade_v1"),"_upgrade_v1 is gone")
	# --- validate / restore accept only v3 ---
	for version: int in [1,2,4]:
		var other: Dictionary=w.export_state()
		other.version=version
		check(not StreamWorld.validate(other),"A v%d-labelled copy of a v3 world is rejected" % version)
	var v2: Dictionary=fixture("v2-pre-eel.var")
	var v1: Dictionary=fixture("v1-world.var")
	check(v2.version==2 and v1.version==1,"Fixtures are genuine v2 and v1 saves")
	check(not StreamWorld.validate(v2) and not StreamWorld.validate(v1),"Genuine v1 and v2 saves are rejected")
	var r:=StreamWorld.new(7,1000)
	var before: PackedByteArray=var_to_bytes(r.export_state())
	check(not r.restore(v2) and not r.restore(v1),"restore refuses v1 and v2 saves")
	check(var_to_bytes(r.export_state())==before,"A refused restore leaves the world untouched")
	var missing: Dictionary=w.export_state()
	missing.erase("next_event")
	check(not StreamWorld.validate(missing),"next_event is required (no pre-event-id saves)")
	# --- Store round trip in the new envelope ---
	clean(DIR)
	var path: String=DIR+"reef.world"
	check(StreamStore.save(path,w)==OK,"Save succeeds")
	var f:=FileAccess.open(path,FileAccess.READ)
	var envelope: Variant=f.get_var(false)
	f.close()
	check(envelope is Dictionary and envelope.format=="stillwater-reef-3","The file is written in the new envelope")
	var back:=StreamWorld.new()
	check(back.restore(StreamStore.read(path)) and var_to_bytes(back.export_state())==var_to_bytes(w.export_state()),"Round trip through the new envelope")
	# --- An old Stillwater Stream save next to where preferences point ---
	clean(DIR)
	var old_path: String=DIR+"stream.world"
	write_old(old_path,v2)
	write_old(old_path+".bak",v1)
	var old_bytes: PackedByteArray=FileAccess.get_file_as_bytes(old_path)
	var old_bak: PackedByteArray=FileAccess.get_file_as_bytes(old_path+".bak")
	check(StreamStore.read(old_path).is_empty(),"An old-format file is never read as a world")
	var first: Dictionary=StreamStore.load_or_create(old_path,2000)
	check(first.error==OK and first.path==DIR+"reef.world","An old save at the given path starts a new world in reef.world beside it")
	check(first.get("legacy",false) and not first.preserved and not first.backup,"Reported as legacy, not as an unreadable world or a backup recovery")
	check(first.world.counts()==opening() and first.world.state.version==3 and first.away.seconds==0.0,"The new world is fresh, with the opening cast")
	check(FileAccess.get_file_as_bytes(old_path)==old_bytes and FileAccess.get_file_as_bytes(old_path+".bak")==old_bak,"The old save and its backup keep their exact bytes")
	check(files(DIR)==["reef.world","stream.world","stream.world.bak"],"No recovery world is created "+str(files(DIR)))
	# The same old path again (a launcher that never updated its preferences): same world, still nothing new.
	var again: Dictionary=StreamStore.load_or_create(old_path,2600)
	check(again.path==first.path and ids(again.world)==ids(first.world) and again.away.seconds==600.0,"Reopening through the old path continues the same new world")
	check(FileAccess.get_file_as_bytes(old_path)==old_bytes and FileAccess.get_file_as_bytes(old_path+".bak")==old_bak,"Still byte-identical after a second launch")
	check(files(DIR).all(func(n: String) -> bool: return not n.contains("recovery")) and files(DIR).size()==4,"Still no recovery worlds, only reef.world and its backup added "+str(files(DIR)))
	# --- main.gd's real flow: preferences.cfg still names the old file ---
	clean(DIR)
	write_old(old_path,v2)
	old_bytes=FileAccess.get_file_as_bytes(old_path)
	var prefs: String=DIR+"preferences.cfg"
	var settings:=ConfigFile.new()
	settings.set_value("world","path",old_path)
	settings.save(prefs)
	var launches: Array=[]
	for i in 3:
		launches.append(launch(prefs,3000.0+i*60))
	settings=ConfigFile.new()
	settings.load(prefs)
	check(settings.get_value("world","path")==DIR+"reef.world","After one launch the preferences name reef.world")
	check(launches.all(func(l: Dictionary) -> bool: return l.error==OK and l.path==DIR+"reef.world" and not l.preserved),"Every launch uses reef.world")
	check(ids(launches[1].world)==ids(launches[0].world) and ids(launches[2].world)==ids(launches[0].world),"Three launches continue one world, not three new ones")
	check(files(DIR).all(func(n: String) -> bool: return not n.contains("recovery")),"Three launches create no recovery worlds "+str(files(DIR)))
	check(FileAccess.get_file_as_bytes(old_path)==old_bytes,"The old save is untouched after three launches")
	# --- Only an old backup left ---
	clean(DIR)
	write_old(old_path+".bak",v2)
	old_bak=FileAccess.get_file_as_bytes(old_path+".bak")
	var bak_only: Dictionary=StreamStore.load_or_create(old_path,4000)
	check(bak_only.path==DIR+"reef.world" and bak_only.get("legacy",false) and not bak_only.backup and not bak_only.preserved,"An old backup alone also starts reef.world")
	check(FileAccess.get_file_as_bytes(old_path+".bak")==old_bak and not FileAccess.file_exists(old_path),"The old backup is untouched and nothing is written at the old path")
	# --- No file at all: a new world where asked ---
	clean(DIR)
	var fresh: Dictionary=StreamStore.load_or_create(DIR+"reef.world",5000)
	check(fresh.error==OK and fresh.path==DIR+"reef.world" and not fresh.get("legacy",false) and not fresh.preserved,"No file: a new world at the requested path")
	# --- An unreadable file that is not an old save keeps the existing recovery behaviour ---
	clean(DIR)
	f=FileAccess.open(path,FileAccess.WRITE)
	f.store_buffer("not a stillwater world".to_utf8_buffer())
	f.close()
	var junk: PackedByteArray=FileAccess.get_file_as_bytes(path)
	var lost: Dictionary=StreamStore.load_or_create(path,6000)
	check(lost.preserved and not lost.get("legacy",false) and lost.path.contains("-recovery-") and FileAccess.get_file_as_bytes(path)==junk,"A damaged reef.world is preserved and a recovery world started")
	# --- Absence summary wording ---
	var report: Dictionary={"seconds":7200.0,"events":{},"capped":false}
	check(Absence.text(report)=="While you were away: 2.0 hours of reef life","Absence summary speaks of reef life")
	clean(DIR)
	DirAccess.remove_absolute(DIR)
	print(JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
