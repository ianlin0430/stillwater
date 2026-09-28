extends SceneTree
# Approved new cast, review only; backend S4 integration is still pending.
const NEW_RIG=preload("res://scripts/reef_new_cast_rig.gd")
const OUT="res://artifacts/new-cast-turn-review/"
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
	var bg:=ColorRect.new()
	bg.size=Vector2(1280,720)
	bg.color=Color("183f44")
	view.add_child(bg)
	var rigs: Array=[]
	for row in 4:
		var species: String=ReefFishArt.SPECIES[row]
		for col in 2:
			var rig=NEW_RIG.new()
			rig.species=species
			rig.detached=true
			rig.body_scale=1.65
			rig.position=Vector2(330+col*640,142+row*164)
			view.add_child(rig)
			rigs.append(rig)
			var label:=Label.new()
			label.position=Vector2(24+col*640,56+row*164)
			label.text=species+" / 1.65x"
			label.add_theme_font_size_override("font_size",20)
			view.add_child(label)
	for col in 2:
		var label:=Label.new()
		label.position=Vector2(24+col*640,8)
		label.text="DIRECT MIRROR / SWIMMING" if col==0 else "HEADING JITTER / HOLD SIDE"
		view.add_child(label)
	var flips: Dictionary={}
	for frame in 480:
		var t: float=frame/60.0
		var heading: float=PI*smoothstep(1,3,t) if t<4 else PI*(1-smoothstep(5,7,t))
		var jitter: float=0.0 if t<1 else PI*.5+sin(t*47)*.12 if t<4 or t>=5 else PI
		for index in rigs.size():
			var rig: ReefRig=rigs[index]
			var previous: float=rig.facing
			if frame%12==0:
				var target: float=heading if index%2==0 else jitter
				rig.face_target=1 if cos(target)>=0 else -1
				rig.apply_actor({"heading":target,"activity":"Cruising","speed":24.0,"thrust":.35,"extend":1.0})
			rig.animate(1.0/60)
			if rig.facing!=previous:
				var key: String=rig.species+("_turn" if index%2==0 else "_jitter")
				if not flips.has(key): flips[key]=[]
				flips[key].append(frame)
		await process_frame
		RenderingServer.force_draw(false)
		var capture: Image=view.get_texture().get_image()
		capture.save_png(OUT+"frames/frame-%04d.png"%frame)
		if frame in [0,120,240]: capture.save_png(OUT+"still-%03d.png"%frame)
	FileAccess.open(OUT+"flips.json",FileAccess.WRITE).store_string(JSON.stringify(flips,"  "))
	print("Recorded 8 seconds at 60 FPS, four approved new species at 1.65x; QA only")
	quit()
