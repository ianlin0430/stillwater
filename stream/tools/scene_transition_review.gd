extends SceneTree
# Deterministic visual-only transition; never instantiates StreamWorld or persistence.
const OUT="res://artifacts/scene-transition-review/"
const RIG=preload("res://scripts/reef_new_cast_rig.gd")
const Actor=preload("res://tools/review_fixtures/cast_snapshot.gd")
func _initialize() -> void: call_deferred("run")
func run() -> void:
	if not "--qa" in OS.get_cmdline_user_args():
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(OUT+"frames")
	Engine.max_fps=0
	var view:=SubViewport.new()
	view.size=Vector2i(640,360)
	view.snap_2d_transforms_to_pixel=true
	view.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	view.canvas_transform=Transform2D(Vector2(.5,0),Vector2(0,.5),Vector2.ZERO)
	var world_view:=Node2D.new()
	world_view.scale=Vector2.ONE*1.65
	world_view.position=Vector2(640,360)-Vector2(640,450)*1.65
	view.add_child(world_view)
	var scene: Node2D=load("res://scenes/reef_visual.tscn").instantiate()
	world_view.add_child(scene)
	var actors:=Node2D.new()
	world_view.add_child(actors)
	var rigs: Array=[]
	for i in 4:
		var rig=RIG.new()
		rig.species=ReefFishArt.SPECIES[i]
		rig.individual_id=i+1
		actors.add_child(rig)
		rigs.append(rig)
	var veil:=ColorRect.new()
	veil.size=Vector2(1280,720)
	veil.color=Color.BLACK
	veil.z_index=100
	view.add_child(veil)
	var title:=Label.new()
	title.text="REEF > SHIPWRECK > REEF / 1.65x / 60 FPS / visual review only"
	title.position=Vector2(22,18)
	title.add_theme_font_size_override("font_size",20)
	title.z_index=101
	view.add_child(title)
	for frame in 600:
		var t: float=frame/60.0
		# Fade out 0.75 s, swap while fully covered, fade in 0.75 s.
		var distance: float=minf(absf(t-3.0),absf(t-7.0))
		veil.color.a=1.0-smoothstep(0,.75,distance)
		if frame in [180,420]:
			assert(is_equal_approx(veil.color.a,1.0),"Scene change must be fully covered")
			scene.free()
			scene=load("res://scenes/"+("shipwreck" if frame==180 else "reef")+"_visual.tscn").instantiate()
			world_view.add_child(scene)
			world_view.move_child(scene,0)
			assert(actors.get_child_count()==4,"Scene change must preserve all four fish")
		for i in rigs.size():
			var rig: ReefRig=rigs[i]
			var at:=Vector2(400+i*154+sin(t*.6+i)*18,280+i*36+sin(t*.8+i)*3)
			var actor:=Actor.actor(rig.species,i+1,at)
			actor.heading=0.0 if t<5 else PI
			actor.activity="Drifting" if rig.species=="seahorse" else "Cruising"
			rig.position=at
			rig.apply_actor(actor)
			rig.animate(1.0/60)
		scene.advance(1.0/60)
		await process_frame
		RenderingServer.force_draw(false)
		var capture:=view.get_texture().get_image()
		capture.save_png(OUT+"frames/frame-%04d.png"%frame)
		if frame in [0,180,240,420,480]:
			capture.resize(1280,720,Image.INTERPOLATE_NEAREST)
			capture.save_png(OUT+"still-%03d.png"%frame)
	print("600 frames: scene swaps only at opaque fade; same four rig instances retained")
	quit()
