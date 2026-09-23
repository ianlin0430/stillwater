extends SceneTree
# Prepared ecological fixtures, real advance_live events; never synthetic UI events.
const OUT="res://artifacts/event-review/"
var view: SubViewport
var stage: StreamStage
var records: Array=[]
func _initialize() -> void: call_deferred("run")
func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	view.get_texture().get_image().save_png(OUT+name+".png")
func run() -> void:
	Engine.max_fps=30
	DirAccess.make_dir_recursive_absolute(OUT)
	view=SubViewport.new()
	view.size=Vector2i(640,360)
	view.disable_3d=true
	view.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	view.canvas_transform=Transform2D(Vector2(0.5,0),Vector2(0,0.5),Vector2.ZERO)
	var display:=TextureRect.new()
	display.texture=view.get_texture()
	display.size=Vector2(1280,720)
	root.add_child(display)
	for kind: String in ["birth","death","arrival","dispersal","molt","berried"]:
		var w:=StreamWorld.new(42,1000)
		w.advance_live(59.8)
		var mom: Dictionary=w.state.animals[0]
		for a: Dictionary in w.state.animals:
			a.last_breed=a.age
			a.next_molt=INF
			a.molting_until=0.0
			a.lifespan=1000.0
		mom.sex="female"
		mom.energy=3.0
		if kind in ["birth","dispersal"]: mom.brood_until=60.0
		if kind=="dispersal":
			while w.counts().shrimp<StreamWorld.CAP.shrimp: w.spawn("shrimp",0)
		if kind=="death":
			mom.lifespan=mom.age
			mom.brood_until=99999.0
		if kind=="molt": mom.next_molt=mom.age
		if kind=="berried":
			mom.last_breed=-100
			# Select a reproducible RNG state where the next ecology decision succeeds.
			seek_draw(w,0.00001)
		if kind=="arrival":
			for a: Dictionary in w.state.animals.duplicate():
				if a.species=="hatchet": w._remove(a,"departure")
			w.state.ecology_ticks=59
			seek_draw(w,0.01)
		stage=StreamStage.new()
		view.add_child(stage)
		stage.apply_snapshot(w.snapshot())
		stage.zoom=1.65
		stage.center=Vector2(mom.x,mom.y-50)
		stage.animate(0)
		await shot(kind+"-before")
		var cursor: int=w.state.next_event-1
		w.advance_live(0.2)
		var actual: Array=StreamWorld.events_after(w.state.events,cursor).filter(func(e): return e.kind==kind and e.live)
		if actual.is_empty():
			printerr("Missing real event: "+kind)
			quit(1)
			return
		var event: Dictionary=actual[0]
		stage.center=Vector2(event.x,event.y-50)
		stage.apply_snapshot(w.snapshot())
		for frame in 33:
			w.advance_live(1.0/30)
			stage.apply_snapshot(w.snapshot())
			stage.animate(1.0/30)
		await shot(kind+"-during")
		if kind in ["molt","berried"]:
			var remaining: float=event.until-w.state.elapsed+60
			while remaining>0:
				var batch: float=minf(remaining,StreamWorld.MAX_AWAY)
				w.advance_offline(batch)
				remaining-=batch
			stage.apply_snapshot(w.snapshot())
		for frame in 123:
			w.advance_live(1.0/30)
			stage.apply_snapshot(w.snapshot())
			stage.animate(1.0/30)
		await shot(kind+"-after")
		records.append({"kind":kind,"seed":42,"event":event,"finish_elapsed":w.state.elapsed})
		stage.free()
	var file:=FileAccess.open(OUT+"events.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(records,"\t"))
	print("Captured six real simulation event scenarios")
	quit()
func seek_draw(w: StreamWorld, threshold: float) -> void:
	for i in 1000000:
		var saved: int=w.rng.state
		if w.rng.randf()<threshold:
			w.rng.state=saved
			return
	push_error("Could not prepare deterministic decision")
