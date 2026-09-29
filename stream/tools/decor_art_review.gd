extends SceneTree
const OUT="res://artifacts/decor-review/"
func _initialize() -> void: call_deferred("run")
func run() -> void:
	if not "--qa" in OS.get_cmdline_user_args():
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(OUT)
	var scene:=ReefScene.open("reef")
	var ids: Array=ReefDecorView.catalog().keys()
	for page in 2:
		for guides: bool in [false,true]:
			var view:=SubViewport.new()
			view.size=Vector2i(768,480)
			view.snap_2d_transforms_to_pixel=true
			view.render_target_update_mode=SubViewport.UPDATE_ALWAYS
			root.add_child(view)
			view.canvas_transform=Transform2D(Vector2(.5,0),Vector2(0,.5),Vector2.ZERO)
			var bg:=ColorRect.new()
			bg.size=Vector2(1536,960)
			bg.color=Color("173b40")
			view.add_child(bg)
			var title:=Label.new()
			title.text="DECOR / 1.65x / "+("ANCHOR CHECK" if guides else "PRODUCTION ART")
			title.position=Vector2(28,14)
			title.add_theme_font_size_override("font_size",24)
			view.add_child(title)
			for index in 6:
				var id: String=ids[page*6+index]
				var col: int=index%3
				var row: int=index/3
				var decor:=ReefDecorView.new()
				decor.style=id
				decor.definition=scene.decor[id]
				decor.position=Vector2(256+col*512,424+row*452)
				decor.scale=Vector2.ONE*1.65
				decor.guides=guides
				view.add_child(decor)
				var label:=Label.new()
				label.text=id+" / "+scene.decor[id].kind
				label.position=Vector2(40+col*512,444+row*452)
				label.add_theme_font_size_override("font_size",22)
				view.add_child(label)
			await process_frame
			await process_frame
			RenderingServer.force_draw(false)
			var capture:=view.get_texture().get_image()
			capture.resize(1536,960,Image.INTERPOLATE_NEAREST)
			capture.save_png(OUT+("anchors-" if guides else "styles-")+str(page+1)+".png")
			view.free()
	print("Decor boards saved at 1.65x")
	quit()
