extends SceneTree
const RIG=preload("res://tools/review_fixtures/h5_fish_rig.gd")
const Fixture=preload("res://tools/review_fixtures/h5_snapshots.gd")
const Smoother=preload("res://scripts/motion_smoother.gd")
const OUT="res://artifacts/h5-motion-review/"
func _initialize() -> void: call_deferred("run")
func run() -> void:
	if not "--qa" in OS.get_cmdline_user_args():
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
	var bg:=ColorRect.new()
	bg.size=Vector2(1280,720)
	bg.color=Color("173b40")
	view.add_child(bg)
	var title:=Label.new()
	title.text="H5 DRAFT / 1.65x / 60 FPS / fixture only"
	title.position=Vector2(24,20)
	title.add_theme_font_size_override("font_size",24)
	view.add_child(title)
	var data:=ReefScene.open("reef")
	var rigs: Array=[]
	var decorations: Array=[]
	var labels: Array=[]
	var smoothers: Array=[]
	for index in 3:
		var group:=Node2D.new()
		group.position=Vector2(170+index*426,530)
		group.scale=Vector2.ONE*1.65
		view.add_child(group)
		var decor:=ReefDecorView.new()
		decor.style=Fixture.STYLES[index]
		decor.definition=data.decor[decor.style]
		group.add_child(decor)
		decorations.append(decor)
		var rig=RIG.new()
		rig.species=Fixture.SPECIES[index]
		rig.individual_id=index+1
		rig.z_index=1
		group.add_child(rig)
		rigs.append(rig)
		smoothers.append(Smoother.new())
		var label:=Label.new()
		label.position=Vector2(24+index*426,586)
		label.add_theme_font_size_override("font_size",22)
		view.add_child(label)
		labels.append(label)
	var trace: Array=[]
	var max_hitch_error: float=0
	for frame in 960:
		var t: float=frame/60.0
		for index in 3:
			var rig: ReefRig=rigs[index]
			var smooth=smoothers[index]
			if frame%12==0:
				var actor:=Fixture.actor_at(rig.species,t,decorations[index].definition)
				rig.apply_actor(actor)
				smooth.push(t,{rig.individual_id:Vector2(actor.x,actor.y)})
				trace.append({"t":t,"actor":actor})
				labels[index].text=rig.species+"\n"+actor.activity
			decorations[index].advance(1.0/60)
			smooth.advance(1.0/60)
			rig.position=smooth.position(rig.individual_id)
			rig.animate(1.0/60)
			if rig.species=="seahorse" and rig.actor.has("hitch_x"):
				max_hitch_error=maxf(max_hitch_error,rig.tail_contact().distance_to(Vector2(rig.actor.hitch_x,rig.actor.hitch_y)))
		await process_frame
		RenderingServer.force_draw(false)
		var capture:=view.get_texture().get_image()
		capture.save_png(OUT+"frames/frame-%04d.png"%frame)
		if frame in [0,180,288,420,720,900]:
			capture.resize(1280,720,Image.INTERPOLATE_NEAREST)
			capture.save_png(OUT+"still-%03d.png"%frame)
	FileAccess.open(OUT+"fixture-trace.json",FileAccess.WRITE).store_string(JSON.stringify(trace))
	FileAccess.open(OUT+"checks.json",FileAccess.WRITE).store_string(JSON.stringify({"max_hitch_error":max_hitch_error,"fps":60,"frames":960}))
	print("H5 fixture rendered, max tail-contact error: ",max_hitch_error)
	quit()
