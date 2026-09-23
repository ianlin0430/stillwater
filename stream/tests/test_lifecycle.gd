extends SceneTree
# Lifecycle and time boundaries against the real StreamStore/StreamWorld paths.
# Every file this touches lives under user://lifecycle-test/; the real save is only hashed.
const Absence=preload("res://scripts/absence.gd")
const DIR: String="user://lifecycle-test/"
const REAL: Array[String]=["user://stream.world","user://stream.world.bak","user://preferences.cfg"]
var checks: int=0
var failures: Array[String]=[]

func check(value: bool, message: String) -> void:
	checks+=1
	if not value:
		failures.append(message)
		printerr("FAIL: "+message)

func digest(path: String) -> String:
	return "missing" if not FileAccess.file_exists(path) else StreamStore._digest(FileAccess.get_file_as_bytes(path))

func real_hashes() -> Dictionary:
	var out: Dictionary={}
	for path: String in REAL:
		out[path]=digest(path)
	return out

func ids(world: StreamWorld) -> Array:
	var out: Array=[]
	for a: Dictionary in world.state.animals:
		out.append([a.id,a.name,a.parent,a.species])
	return out

# Every survivor still carries the exact name, parent and species it had in `before`.
func lineage_ok(world: StreamWorld, before: Array) -> bool:
	var was: Dictionary={}
	for a: Array in before:
		was[a[0]]=a
	var survivors: int=0
	for a: Array in ids(world):
		if was.has(a[0]):
			survivors+=1
			if was[a[0]]!=a:
				return false
	return survivors>0

func clean() -> void:
	for f: String in DirAccess.get_files_at(DIR):
		DirAccess.remove_absolute(DIR+f)

func corrupt(path: String) -> void:
	var f:=FileAccess.open(path,FileAccess.WRITE)
	f.store_buffer("not a stillwater world".to_utf8_buffer())
	f.close()

func _initialize() -> void:
	var real_before: Dictionary=real_hashes()
	DirAccess.make_dir_recursive_absolute(DIR)
	clean()
	var path: String=DIR+"stream.world"
	check(ProjectSettings.globalize_path(path)!=ProjectSettings.globalize_path(StreamStore.DEFAULT_PATH),"Test world is never the real world")

	# --- Absence accumulation: one summary for the whole hidden period ---
	var w:=StreamWorld.new(42,1000.0)
	var twin:=StreamWorld.new(42,1000.0)
	var since: float=1000.0
	var absence: Dictionary=Absence.fresh(since)
	check(absence.seconds==0.0 and absence.simulated==0.0 and absence.advances==0 and not absence.capped,"A fresh absence starts empty")
	# main.gd's hidden loop: a 60s advance per minute, then the leftover on resume.
	for i in 605:
		var now: float=since+i+1
		if now-since-absence.simulated>=60:
			Absence.advance(absence,w,now)
	Absence.advance(absence,w,since+605)
	check(absence.advances==11,"Ten 60s advances plus the resume leftover")
	check(absence.seconds==605.0,"Summary covers the whole absence, not the last fragment")
	check(absence.simulated==605.0,"Simulated wall time equals the absence")
	check(w.state.elapsed==605.0,"Absence advances the world exactly once (no double advance)")
	check(not absence.capped,"A short absence is not capped")
	var once: Dictionary=twin.advance_offline(605.0)
	check(var_to_bytes(w.export_state())==var_to_bytes(twin.export_state()),"Accumulated absence equals one advance of the same span")
	check(absence.events==once.events,"Accumulated event counts equal the single-advance counts")
	check(Absence.text(absence).begins_with("While you were away"),"An accumulated absence produces a summary")
	# Pre-fix behaviour only reported the resume leftover, which was below the 120s floor.
	check(Absence.text(Absence.advance(Absence.fresh(0.0),StreamWorld.new(42,1000.0),5.0)).is_empty(),"A five second absence still shows nothing")

	# Paused, backwards clock and repeated calls never advance twice.
	var p:=StreamWorld.new(42,1000.0)
	var idle: Dictionary=Absence.fresh(0.0)
	Absence.advance(idle,p,120.0)
	check(p.state.elapsed==120.0 and idle.seconds==120.0,"First absence advance applies the pending span")
	Absence.advance(idle,p,120.0)
	check(p.state.elapsed==120.0 and idle.advances==1,"Repeating the same instant advances nothing")
	Absence.advance(idle,p,60.0)
	check(p.state.elapsed==120.0 and idle.advances==1,"A backwards clock during an absence advances nothing")
	Absence.advance(idle,p,180.0)
	check(p.state.elapsed==180.0 and idle.seconds==180.0,"Only the new span is applied after a backwards clock")
	var capped: Dictionary=Absence.fresh(0.0)
	Absence.advance(capped,StreamWorld.new(42,1000.0),StreamWorld.MAX_AWAY+StreamWorld.DAY)
	check(capped.capped and capped.seconds==StreamWorld.MAX_AWAY,"An over-long absence caps and reports it")
	Absence.advance(capped,StreamWorld.new(42,1000.0),StreamWorld.MAX_AWAY+StreamWorld.DAY+60)
	check(capped.capped,"The capped flag survives later advances")
	check(Absence.text(capped).ends_with("limited to three days"),"A capped summary says so")

	# --- Time boundaries through load_or_create ---
	var base:=StreamWorld.new(1931,1000.0)
	base.advance_live(120)
	base.state.wall_checkpoint=1000.0
	check(StreamStore.save(path,base)==OK,"Seed save written")
	var seed_ids: Array=ids(base)
	var seed_elapsed: float=base.state.elapsed
	var seed_bytes: PackedByteArray=FileAccess.get_file_as_bytes(path)
	for span: float in [300.0,StreamWorld.MAX_AWAY,StreamWorld.DAY*18]:
		clean()
		FileAccess.open(path,FileAccess.WRITE).store_buffer(seed_bytes)
		var now: float=1000.0+span
		var loaded: Dictionary=StreamStore.load_or_create(path,now)
		var expected: float=minf(span,StreamWorld.MAX_AWAY)
		check(loaded.away.seconds==expected,"Absence of %ds catches up %ds" % [span,expected])
		check(loaded.away.capped==(span>StreamWorld.MAX_AWAY),"Cap flag matches for %ds" % span)
		check(absf(loaded.world.state.elapsed-seed_elapsed-expected)<0.000001,"Elapsed advances by the catch-up span for %ds" % span)
		check(loaded.world.state.wall_checkpoint==now,"Checkpoint commits to now for %ds" % span)
		check(StreamStore.read(path).wall_checkpoint==now,"Committed checkpoint is on disk for %ds" % span)
		check(not loaded.backup and not loaded.preserved and loaded.error==OK,"Primary load for %ds" % span)
		check(lineage_ok(loaded.world,seed_ids),"Survivors keep name/parent/species for %ds" % span)

	# Negative elapsed: the clock moved backwards.
	clean()
	FileAccess.open(path,FileAccess.WRITE).store_buffer(seed_bytes)
	var back: Dictionary=StreamStore.load_or_create(path,1000.0-3600.0)
	check(back.away.seconds==0.0 and not back.away.capped,"A backwards clock catches nothing up")
	check(back.world.state.elapsed==seed_elapsed,"A backwards clock does not advance the world")
	check(back.world.state.wall_checkpoint==1000.0,"A backwards clock never moves the checkpoint back")
	check(StreamWorld.validate(back.world.export_state()) and ids(back.world)==seed_ids,"A backwards clock leaves the world intact")

	# --- Corrupted primary recovers from the backup ---
	clean()
	FileAccess.open(path,FileAccess.WRITE).store_buffer(seed_bytes)
	FileAccess.open(path+".bak",FileAccess.WRITE).store_buffer(seed_bytes)
	corrupt(path)
	var recovered: Dictionary=StreamStore.load_or_create(path,1000.0+600.0)
	check(recovered.backup and not recovered.preserved and recovered.error==OK,"Corrupt primary recovers from the backup")
	check(recovered.path==path,"Recovery writes back to the primary path")
	check(recovered.away.seconds==600.0,"Backup recovery still catches up")
	check(lineage_ok(recovered.world,seed_ids),"Backup recovery preserves identity and lineage")
	check(StreamStore.read(path).wall_checkpoint==1600.0,"Backup recovery commits a readable primary")

	# --- Corrupted primary AND backup: nothing is destroyed ---
	clean()
	FileAccess.open(path,FileAccess.WRITE).store_buffer(seed_bytes)
	FileAccess.open(path+".bak",FileAccess.WRITE).store_buffer(seed_bytes)
	corrupt(path)
	corrupt(path+".bak")
	var primary_hash: String=digest(path)
	var backup_hash: String=digest(path+".bak")
	var lost: Dictionary=StreamStore.load_or_create(path,1000.0+600.0)
	check(lost.preserved and not lost.backup,"Both files unreadable is reported as preserved")
	check(lost.path!=path and lost.path.contains("-recovery-"),"A separate recovery world is created")
	check(digest(path)==primary_hash and digest(path+".bak")==backup_hash,"The user's unreadable files are left byte-identical")
	check(lost.error==OK and FileAccess.file_exists(lost.path),"The recovery world is saved")
	check(lost.away.seconds==0.0 and lost.world.state.animals.size()==16,"The recovery world starts fresh, not caught up")

	# --- Interrupted before the catch-up commit, and a relaunch right after it ---
	clean()
	FileAccess.open(path,FileAccess.WRITE).store_buffer(seed_bytes)
	var crashed:=StreamWorld.new()
	crashed.restore(StreamStore.read(path))
	crashed.catch_up(1000.0+3600.0)
	check(FileAccess.get_file_as_bytes(path)==seed_bytes,"An interruption before the commit leaves the old save untouched")
	var replay: Dictionary=StreamStore.load_or_create(path,1000.0+3600.0)
	check(replay.away.seconds==3600.0,"The replay catches up the full hour from the old save")
	check(var_to_bytes(replay.world.export_state())==var_to_bytes(crashed.export_state()),"The replay reproduces the interrupted catch-up exactly")
	var committed: String=digest(path)
	var again: Dictionary=StreamStore.load_or_create(path,1000.0+3600.0)
	check(again.away.seconds==0.0,"A relaunch right after the commit advances nothing")
	check(again.world.state.elapsed==replay.world.state.elapsed,"A relaunch right after the commit keeps elapsed")
	check(again.world.state.wall_checkpoint==1000.0+3600.0,"A relaunch right after the commit keeps the checkpoint")
	check(digest(path)==committed,"A relaunch right after the commit rewrites the same bytes")
	check(ids(again.world)==ids(replay.world),"Identity and lineage survive the whole sequence")

	clean()
	DirAccess.remove_absolute(DIR)
	check(real_before==real_hashes(),"The real stream.world/.bak/preferences.cfg are unchanged")
	print(JSON.stringify({"checks":checks,"failures":failures.size(),"real_hashes":real_hashes()}))
	quit(0 if failures.is_empty() else 1)
