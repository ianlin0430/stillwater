extends SceneTree
# Actual app/stage screenshots. QA world stays untouched; only the rendered copy is a fixture.
const Fixture=preload("res://tools/review_fixtures/cast_snapshot.gd")
const OUT="res://artifacts/production-scene-review/"
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
	app.set_process(false)
	DisplayServer.window_set_size(Vector2i(1440,900))
	DisplayServer.window_move_to_foreground()
	var snap:=Fixture.snapshot(ReefFishArt.SPECIES)
	for id: String in ReefScene.ids():
		snap.scene=id
		var scene:=ReefScene.open(id)
		var points: Array[Vector2]=[]
		# Art review positions only, not claims about backend home assignment/behaviour.
		var anemone: Dictionary=scene.effects("anemone",scene.default_decor().anemone).anemone
		points=[Vector2(600,270),Vector2(anemone.cx,anemone.cy-12),scene.effects("hitch_plant",scene.default_decor().hitch_plant).hitches[0]-Vector2(0,30),scene.rock_spots()[0]-Vector2(22,0)]
		for i in snap.animals.size():
			snap.animals[i].x=points[i].x
			snap.animals[i].y=points[i].y
		app.stage.apply_snapshot(snap)
		app.stage.natural_light=1
		app.climate.text="QA · "+id+" · 4 fish in view"
		app.status.text="Production stage · approved four-fish art fixture · backend S4 pending"
		for frame in 20:
			app.stage.animate(1.0/60)
			await process_frame
		RenderingServer.force_draw(false)
		root.get_texture().get_image().save_png(OUT+id+"-app.png")
		app.viewport.get_texture().get_image().save_png(OUT+id+"-stage.png")
	print("Actual QA app captured both production scenes; four-fish presentation fixture, no world changes")
	quit()
