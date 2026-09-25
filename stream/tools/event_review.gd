extends SceneTree
# Natural seeded history only: hourly offline search, then public live replay of the event tick.
const OUT="res://artifacts/event-review-reef/"
const KINDS=["birth","death","arrival","dispersal"]
var view: SubViewport
var stage: StreamStage
var records: Array=[]
func _initialize() -> void: call_deferred("run")
func run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	if "--discover" in OS.get_cmdline_user_args():
		discover()
		return
	Engine.max_fps=30
	view=SubViewport.new()
	view.size=Vector2i(960,540)
	view.disable_3d=true
	view.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	view.canvas_transform=Transform2D(Vector2(.75,0),Vector2(0,.75),Vector2.ZERO)
	var display:=TextureRect.new()
	display.texture=view.get_texture()
	display.size=Vector2(1280,720)
	root.add_child(display)
	for kind: String in KINDS:
		var path: String=OUT+kind+"-checkpoint.bin"
		if not FileAccess.file_exists(path):
			printerr("Missing natural checkpoint: "+kind)
			quit(1)
			return
		var w:=StreamWorld.new(42,1000)
		if not w.restore(bytes_to_var(FileAccess.get_file_as_bytes(path))):
			quit(2)
			return
		# Inspect a clone to frame the event before it occurs. No actor/RNG editing.
		var probe:=StreamWorld.new(42,1000)
		probe.restore(w.export_state())
		var cursor: int=w.state.next_event-1
		probe.advance_live(.2)
		var found: Array=StreamWorld.events_after(probe.state.events,cursor).filter(func(e): return e.kind==kind and e.live)
		if found.is_empty():
			printerr("Live replay did not reproduce "+kind)
			quit(3)
			return
		var event: Dictionary=found[0]
		stage=StreamStage.new()
		view.add_child(stage)
		stage.natural_light=1
		stage.selected=event.id
		stage.zoom=1.65
		stage.center=Vector2(event.x,event.y-35)
		stage.apply_snapshot(w.snapshot())
		stage.animate(.001)
		await shot(kind+"-before")
		w.advance_live(.2)
		stage.apply_snapshot(w.snapshot())
		for frame in 18:
			advance_frame(w)
		await shot(kind+"-during")
		for frame in 126:
			advance_frame(w)
		await shot(kind+"-after")
		records.append({"kind":kind,"seed":42,"event":event,"finish_elapsed":w.state.elapsed,"state_valid":StreamWorld.validate(w.export_state())})
		stage.free()
	FileAccess.open(OUT+"events.json",FileAccess.WRITE).store_string(JSON.stringify(records,"  "))
	print("Captured four natural reef events; no synthetic events or edited ecological fixtures")
	quit()
func advance_frame(w: StreamWorld) -> void:
	w.advance_live(1.0/30)
	stage.apply_snapshot(w.snapshot())
	stage.animate(1.0/30)
func shot(name: String) -> void:
	await process_frame
	RenderingServer.force_draw(false)
	view.get_texture().get_image().save_png(OUT+name+".png")
func discover() -> void:
	var start: int=Time.get_ticks_msec()
	var w:=StreamWorld.new(42,1000)
	var obtained: Dictionary={}
	for hour in 24*120:
		if Time.get_ticks_msec()-start>12000: break
		var previous: Dictionary=w.export_state()
		var cursor: int=w.state.next_event-1
		w.advance_offline(3600)
		for e: Dictionary in StreamWorld.events_after(w.state.events,cursor):
			if e.kind not in KINDS or obtained.has(e.kind): continue
			var actor: Dictionary={}
			for a: Dictionary in w.state.animals+w.state.archive:
				if a.id==e.id: actor=a
			if actor.is_empty() or actor.species not in StreamStage.PRESENTED_SPECIES: continue
			var replay:=StreamWorld.new(42,1000)
			replay.restore(previous)
			replay.advance_offline(e.time-previous.elapsed-.2)
			var checkpoint: Dictionary=replay.export_state()
			var seq: int=replay.state.next_event-1
			replay.advance_live(.2)
			var matches: Array=StreamWorld.events_after(replay.state.events,seq).filter(func(v): return v.kind==e.kind and v.live)
			if matches.is_empty(): continue
			FileAccess.open(OUT+e.kind+"-checkpoint.bin",FileAccess.WRITE).store_buffer(var_to_bytes(checkpoint))
			obtained[e.kind]={"day":e.time/86400,"seq":matches[0].seq,"id":matches[0].id}
		if obtained.size()==KINDS.size(): break
	print(JSON.stringify({"found":obtained,"wall_ms":Time.get_ticks_msec()-start,"searched_days":w.state.elapsed/86400}))
	quit(0 if obtained.size()==KINDS.size() else 1)
