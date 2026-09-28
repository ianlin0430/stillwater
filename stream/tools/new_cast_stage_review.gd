extends SceneTree
# H3 actual stage preview, scripted presentation snapshots until backend S4.
const Fixture=preload("res://tools/review_fixtures/cast_snapshot.gd")
const OUT="res://artifacts/new-cast-stage-review/"
func _initialize() -> void: call_deferred("run")
func run() -> void:
	if not "--qa" in OS.get_cmdline_user_args():
		printerr("This recorder requires -- --qa")
		quit(1)
		return
	Engine.max_fps=0
	DirAccess.make_dir_recursive_absolute(OUT+"frames")
	var view:=SubViewport.new()
	view.size=Vector2i(640,360)
	view.snap_2d_transforms_to_pixel=true
	view.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	view.canvas_transform=Transform2D(Vector2(.5,0),Vector2(0,.5),Vector2.ZERO)
	var stage:=StreamStage.new()
	stage.zoom=1.65
	stage.natural_light=1.0
	view.add_child(stage)
	var caption:=Label.new()
	caption.position=Vector2(310,18)
	caption.text="H3 / actual stage / 60 FPS / 1.65x\nScripted snapshots; backend S4 pending"
	caption.add_theme_font_size_override("font_size",18)
	view.add_child(caption)
	var snap:=Fixture.snapshot(ReefFishArt.SPECIES)
	var centers: Array[Vector2]=[Vector2(475,250),Vector2(790,305),Vector2(490,425),Vector2(790,475)]
	var flips: Dictionary={}
	for frame in 600:
		var t: float=frame/60.0
		if frame%12==0:
			snap.elapsed=t
			for index in snap.animals.size():
				var a: Dictionary=snap.animals[index]
				var phase: float=t*.65+index*.8
				var radius: float=22.0 if a.species=="seahorse" else 85.0
				a.x=centers[index].x+sin(phase)*radius
				a.y=centers[index].y+cos(phase)*12.0
				a.vx=cos(phase)*radius*.65
				a.vy=-sin(phase)*12*.65
				a.speed=Vector2(a.vx,a.vy).length()
				a.heading=atan2(a.vy,a.vx)
				a.direction=1.0 if a.vx>=0 else -1.0
				a.thrust=.32
			stage.apply_snapshot(snap)
		var before: Dictionary={}
		for id: int in stage.rigs: before[id]=stage.rigs[id].facing
		stage.animate(1.0/60)
		for id: int in stage.rigs:
			var rig: ReefRig=stage.rigs[id]
			if before[id]!=rig.facing:
				if not flips.has(rig.species): flips[rig.species]=[]
				flips[rig.species].append(frame)
		await process_frame
		RenderingServer.force_draw(false)
		var capture: Image=view.get_texture().get_image()
		capture.save_png(OUT+"frames/frame-%04d.png"%frame)
		if frame in [0,180,360,599]: capture.save_png(OUT+"still-%03d.png"%frame)
	FileAccess.open(OUT+"flips.json",FileAccess.WRITE).store_string(JSON.stringify(flips,"  "))
	print("Recorded 10 seconds at 60 FPS on StreamStage; four approved species, scripted snapshots, QA only")
	quit()
