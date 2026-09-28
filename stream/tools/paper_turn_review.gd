extends SceneTree
# Review only: old sprites are deliberately isolated from the production scene.
const BEFORE=preload("res://tools/review_fixtures/front_turn_rig.gd")
const OUT="res://artifacts/paper-turn-review/"
func _initialize() -> void: call_deferred("run")
func run() -> void:
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
		var species: String=["green_chromis","yellow_tang","purple_firefish","lawnmower_blenny"][row]
		for col in 2:
			var rig=BEFORE.new() if col==0 else ReefRig.new()
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
		label.text="BEFORE / FRONT POSES" if col==0 else "AFTER / SIDE ONLY"
		view.add_child(label)
	for frame in 480:
		var t: float=frame/60.0
		var heading: float=PI*smoothstep(1,3,t) if t<4 else PI*(1-smoothstep(5,7,t))
		for rig in rigs:
			if frame%12==0:
				rig.apply_actor({"heading":heading,"activity":"Cruising","speed":0.0,"thrust":0.0,"extend":1.0})
			rig.animate(1.0/60)
		await process_frame
		RenderingServer.force_draw(false)
		var capture: Image=view.get_texture().get_image()
		capture.save_png(OUT+"frames/frame-%04d.png"%frame)
		if frame in [0,120,240]: capture.save_png(OUT+"still-%03d.png"%frame)
	print("Recorded 8 seconds at 60 FPS, four current backend species at 1.65x; QA only")
	quit()
