extends SceneTree
const RIG=preload("res://scripts/reef_new_cast_rig.gd")
const OUT="res://artifacts/unified-style-review/"
func _initialize() -> void: call_deferred("run")

func label(parent: Node, text: String, at: Vector2, size: int=24) -> void:
	var l:=Label.new()
	l.text=text
	l.position=at
	l.add_theme_font_size_override("font_size",size)
	parent.add_child(l)

func run() -> void:
	if not "--qa" in OS.get_cmdline_user_args():
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(OUT)
	var view:=SubViewport.new()
	view.size=Vector2i(1280,960)
	view.snap_2d_transforms_to_pixel=true
	view.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	view.canvas_transform=Transform2D(Vector2(.5,0),Vector2(0,.5),Vector2.ZERO)
	var bg:=ColorRect.new()
	bg.color=Color("153b50")
	bg.size=Vector2(2560,1920)
	view.add_child(bg)
	label(view,"STILLWATER REEF / UNIFIED STYLE / 2026-09-29 / FOR APPROVAL",Vector2(24,16),30)
	for index in 2:
		var scene:=ReefSceneView.new()
		scene.scene_id="reef" if index==0 else "shipwreck"
		scene.position=Vector2(20+index*1280,94)
		scene.scale=Vector2.ONE*(1240.0/1280)
		view.add_child(scene)
		label(view,scene.scene_id+" / default decor",Vector2(20+index*1280,60))
	label(view,"12 DECOR STYLES / 1.65x",Vector2(24,808))
	label(view,"APPROVED FISH / 1.65x",Vector2(2040,808))
	var data:=ReefScene.open("reef")
	var ids: Array=ReefDecorView.catalog().keys()
	for i in ids.size():
		var decor:=ReefDecorView.new()
		decor.style=ids[i]
		decor.definition=data.decor[decor.style]
		decor.position=Vector2(250+(i%4)*500,1160+(i/4)*350)
		decor.scale=Vector2.ONE*1.65
		view.add_child(decor)
		label(view,decor.style,Vector2(50+(i%4)*500,1178+(i/4)*350),22)
	for i in 4:
		var rig=RIG.new()
		rig.species=ReefFishArt.SPECIES[i]
		rig.body_scale=1.65
		rig.position=Vector2(2280,970+i*250)
		view.add_child(rig)
		rig.apply_actor({"heading":0.0,"activity":"Cruising"})
		rig.animate(1.0/60)
		label(view,rig.species,Vector2(2140,1040+i*250),22)
	await process_frame
	await process_frame
	RenderingServer.force_draw(false)
	var capture:=view.get_texture().get_image()
	capture.resize(2560,1920,Image.INTERPOLATE_NEAREST)
	capture.save_png(OUT+"overview.png")
	view.free()
	for id: String in ["reef","shipwreck"]:
		var closeup:=SubViewport.new()
		closeup.size=Vector2i(640,360)
		closeup.snap_2d_transforms_to_pixel=true
		closeup.render_target_update_mode=SubViewport.UPDATE_ALWAYS
		root.add_child(closeup)
		# 1.65x world crop, nearest 2x presentation, no generated image alteration.
		closeup.canvas_transform=Transform2D(Vector2(.825,0),Vector2(0,.825),Vector2(320,180)-Vector2(670,456)*.825)
		var scene:=ReefSceneView.new()
		scene.scene_id=id
		closeup.add_child(scene)
		await process_frame
		await process_frame
		RenderingServer.force_draw(false)
		capture=closeup.get_texture().get_image()
		capture.resize(1280,720,Image.INTERPOLATE_NEAREST)
		capture.save_png(OUT+id+"-165.png")
		closeup.free()
	print("Unified overview and 1.65x scene crops saved")
	quit()
