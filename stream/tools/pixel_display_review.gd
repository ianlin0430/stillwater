extends SceneTree
# Exercise the actual app UI using the isolated QA lifecycle only.
const OUT="res://artifacts/pixel-display-review/"
func _initialize() -> void: call_deferred("run")
func run() -> void:
	if not "--qa" in OS.get_cmdline_user_args():
		printerr("This recorder requires -- --qa")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(OUT)
	var app=load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	app.qa_duration=0
	app.viewing_light=true
	DisplayServer.window_move_to_foreground()
	var results: Array=[]
	for dimensions: Vector2i in [Vector2i(900,620),Vector2i(1200,750),Vector2i(1440,900)]:
		DisplayServer.window_set_size(dimensions)
		await settle()
		app.stage.animate(1.0/60)
		RenderingServer.force_draw(false)
		var rect: Rect2=PixelDisplay.fitted_rect(app.display.size)
		results.append({"window":str(dimensions),"content":str(rect),"multiple":rect.size.x/640})
		root.get_texture().get_image().save_png(OUT+"window-%d.png"%dimensions.x)
	var event:=InputEventKey.new()
	event.keycode=KEY_F11
	event.pressed=true
	app._input(event)
	await settle()
	var full: bool=DisplayServer.window_get_mode()==DisplayServer.WINDOW_MODE_FULLSCREEN
	RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png(OUT+"fullscreen.png")
	app._input(event)
	await settle()
	var restored: bool=DisplayServer.window_get_mode()==DisplayServer.WINDOW_MODE_WINDOWED
	FileAccess.open(OUT+"result.json",FileAccess.WRITE).store_string(JSON.stringify({"sizes":results,"fullscreen":full,"restored":restored,"snap_transforms":app.viewport.snap_2d_transforms_to_pixel,"viewport":str(app.viewport.size)},"  "))
	print("Pixel display review: "+str(results)+" fullscreen="+str(full)+" restored="+str(restored))
	quit(0 if full and restored else 1)
func settle() -> void:
	for frame in 12: await process_frame
