extends SceneTree
# Backend side of the snapshot/event contract (docs/BACKEND_SNAPSHOT_EVENTS.md).
var checks: int=0
var failures: Array[String]=[]

func check(value: bool, message: String) -> void:
	checks+=1
	if not value:
		failures.append(message)
		printerr("FAIL: "+message)

func state_bytes(w: StreamWorld) -> PackedByteArray:
	return var_to_bytes(w.export_state())

func find(events: Array, kind: String) -> Dictionary:
	for e: Dictionary in events:
		if e.kind==kind:
			return e
	return {}

func seqs_ok(events: Array, next_event: int) -> bool:
	var last: int=0
	for e: Dictionary in events:
		if not e.get("seq") is int or e.seq<=last or e.seq>=next_event:
			return false
		last=e.seq
	return true

# A save as written before event ids existed.
func strip(saved: Dictionary) -> Dictionary:
	var old: Dictionary=saved.duplicate(true)
	old.erase("next_event")
	var all: Array=old.events.duplicate()
	for a: Dictionary in old.animals+old.archive:
		a.erase("relocated_at")
		all.append_array(a.recent)
	for e: Dictionary in all:
		for key: String in ["seq","live","x","y","target","cause","until"]:
			e.erase(key)
	return old

func _initialize() -> void:
	# Event ids: monotonic, persisted, never reused.
	var w:=StreamWorld.new(42,1000)
	check(w.state.next_event==2 and w.state.events[0].seq==1 and w.state.events[0].live==false,"Opening event has id 1 and is not live")
	w.advance_live(120)
	check(seqs_ok(w.state.events,w.state.next_event),"Event ids increase and stay below next_event")
	# Velocity is per simulated second and consistent with position, except on relocation ticks.
	var consistent: bool=true
	var moved: bool=false
	for i in 300:
		var before: Dictionary={}
		for a: Dictionary in w.state.animals:
			before[a.id]=Vector2(a.x,a.y)
		w.advance_live(0.2)
		for a: Dictionary in w.state.animals:
			if not before.has(a.id) or a.get("relocated_at",-1.0)==w.state.elapsed:
				continue
			var step: Vector2=Vector2(a.x,a.y)-before[a.id]
			moved=moved or step.length()>0.5
			if step.distance_to(Vector2(a.vx,a.vy)*0.2)>StreamWorld.RELOCATION:
				consistent=false
	check(moved and consistent,"vx/vy match per-tick displacement unless relocated_at marks the tick")
	# A fish found far outside its layer (e.g. an edited save) snaps back into it: that is a relocation.
	var s: Dictionary=w.state.animals.filter(func(a): return a.species=="threadfin")[0]
	s.y=StreamWorld.DEPTH.threadfin[1]+80
	s.activity="Resting"
	s.decision_at=w.state.elapsed+100
	s.tx=s.x
	s.ty=s.y
	w.state.elapsed+=0.2
	w._move(0.2)
	check(s.relocated_at==w.state.elapsed and s.y==StreamWorld.DEPTH.threadfin[1],"An instantaneous snap records relocated_at")
	# Natural death: the event arrives in the same snapshot the animal disappears from.
	var cursor: int=w.state.next_event-1
	var old: Dictionary=w.state.animals.filter(func(a): return a.species=="threadfin")[2]
	old.age=old.lifespan
	w.advance_live(60)
	var snap: Dictionary=w.snapshot()
	var death: Dictionary=find(StreamWorld.events_after(snap.events,cursor),"death")
	check(death.get("id")==old.id and death.get("cause")=="old age" and death.get("live")==true and not death.has("target"),"Death event names actor, cause and is live, with no target")
	var record: Array=snap.archive.filter(func(a): return a.id==old.id)
	check(record.size()==1 and death.get("x")==record[0].x and death.get("y")==record[0].y,"Death event is placed where the animal was")
	check(snap.animals.all(func(a): return a.id!=old.id) and snap.archive.any(func(a): return a.id==old.id),"Same snapshot: gone from animals, kept in archive")
	# Birth, arrival and dispersal.
	cursor=w.state.next_event-1
	var mother: Dictionary=w.state.animals.filter(func(a): return a.species=="threadfin" and a.sex=="female")[0]
	mother.energy=100.0
	w._breed(mother)
	var born: Dictionary=find(StreamWorld.events_after(w.state.events,cursor),"birth")
	check(born.get("target")==mother.id and born.has("x"),"Birth event: child is actor, parent is target")
	while w.counts().threadfin<StreamWorld.CAP.threadfin:
		w.spawn("threadfin",30)
	cursor=w.state.next_event-1
	mother.energy=100.0
	w._breed(mother)
	var gone: Dictionary=find(StreamWorld.events_after(w.state.events,cursor),"dispersal")
	check(gone.get("id")==mother.id and gone.get("x")==mother.x,"Dispersal event is placed at the parent")
	cursor=w.state.next_event-1
	w._arrive("threadfin")
	var came: Dictionary=find(StreamWorld.events_after(w.state.events,cursor),"arrival")
	var newcomer: Array=w.state.animals.filter(func(a): return a.id==came.get("id"))
	check(newcomer.size()==1 and came.x==newcomer[0].x and came.y==newcomer[0].y,"Arrival event is placed at the newcomer")
	# Offline catch-up events are not live.
	cursor=w.state.next_event-1
	w.state.animals.filter(func(a): return a.species=="threadfin")[1].age=999.0
	w.advance_offline(120)
	var quiet: Array=StreamWorld.events_after(w.state.events,cursor)
	check(not quiet.is_empty() and quiet.all(func(e): return e.live==false),"Offline events are marked not live")
	# Ids survive save/load and continue.
	var path: String="user://qa-presentation.world"
	check(StreamStore.save(path,w)==OK,"Save with event ids")
	var back:=StreamWorld.new()
	check(back.restore(StreamStore.read(path)),"Restore with event ids")
	check(back.state.next_event==w.state.next_event,"next_event survives save/load")
	back._event("death",back.state.animals[0],"x")
	check(back.state.events.back().seq==w.state.next_event,"Next id after load is not reused")
	DirAccess.remove_absolute(path)
	DirAccess.remove_absolute(path+".bak")
	# Saves written before this change, and v1 saves, still load.
	var legacy: Dictionary=strip(w.export_state())
	check(StreamWorld.validate(legacy),"Pre-event-id save validates")
	var from_legacy:=StreamWorld.new()
	check(from_legacy.restore(legacy) and from_legacy.state.next_event==1,"Pre-event-id save restores and starts ids at 1")
	from_legacy.advance_offline(StreamWorld.DAY)
	check(StreamWorld.validate(from_legacy.export_state()),"Legacy world keeps validating after new events")
	var f:=FileAccess.open("res://tests/fixtures/v1-world.var",FileAccess.READ)
	var v1: Dictionary=f.get_var()
	f.close()
	var up:=StreamWorld.new()
	check(up.restore(v1) and seqs_ok(StreamWorld.events_after(up.state.events,0),up.state.next_event) and up.state.next_event>1,"v1 upgrade numbers its departure events")
	check(StreamWorld.validate(up.export_state()),"Upgraded v1 save validates")
	# Corrupt ids are rejected.
	var bad: Dictionary=w.export_state()
	bad.next_event="7"
	check(not StreamWorld.validate(bad),"Non-integer next_event rejected")
	bad=w.export_state()
	bad.events.back().seq=bad.next_event
	check(not StreamWorld.validate(bad),"Event id at or beyond next_event rejected")
	bad=w.export_state()
	bad.animals[0].relocated_at=NAN
	check(not StreamWorld.validate(bad),"Nonfinite relocated_at rejected")
	# Presentation reads never touch the world.
	var bytes: PackedByteArray=state_bytes(w)
	var rngs: Array=[w.rng.state,w.motion_rng.state]
	for i in 20:
		var view: Dictionary=w.snapshot()
		StreamWorld.events_after(view.events,0)
		view.animals.clear()
		view.events.clear()
	w.counts()
	w.natural_light()
	w.sub_light()
	w.biofilm_max()
	w.residual()
	for a: Dictionary in w.state.animals+w.state.archive:
		w.animal_scale(a)
		a.recent.slice(-2)
	check(state_bytes(w)==bytes and [w.rng.state,w.motion_rng.state]==rngs,"Snapshots and selection/scale/light reads do not change state or RNGs")
	print(JSON.stringify({"checks":checks,"failures":failures.size()}))
	quit(0 if failures.is_empty() else 1)
