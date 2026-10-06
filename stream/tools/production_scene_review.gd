extends SceneTree
# Current production-stage review using real QA worlds, not hand-positioned art actors.
# Preflight: --headless --script tools/production_scene_review.gd -- --qa --validate-only
# Native capture requires separately authorized visible-window control.
const OUT: String="res://artifacts/completion/visual-review-current/"
var checks: int=0
var failures: Array[String]=[]
var cases: Array[Dictionary]=[]

func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok: failures.append(label)

func _initialize() -> void: call_deferred("run")

func make_world(scene_id: String, preset: String, hour: float) -> StreamWorld:
	var world:=StreamWorld.new(240921,1000,scene_id)
	var decor: Dictionary=world.scene.preset(preset)
	for slot: String in decor: world.set_decor(slot,decor[slot])
	world.state.light_hour=hour
	world.advance_live(180)
	return world

func describe(world: StreamWorld, preset: String, phase: String) -> Dictionary:
	var actors: Array=[]
	for a: Dictionary in world.state.animals:
		actors.append({"id":a.id,"species":a.species,"activity":a.activity,"position":[a.x,a.y],"home":a.get("home",{}),"hitch": [a.hitch_x,a.hitch_y] if a.has("hitch_x") else [],"extend":a.get("extend",1.0)})
	return {"scene":world.state.scene,"preset":preset,"phase":phase,"seed":world.state.seed,"elapsed":world.state.elapsed,"counts":world.counts(),"decor":world.state.decor[world.state.scene].duplicate(),"actors":actors}

func run() -> void:
	if not "--qa" in OS.get_cmdline_user_args():
		printerr("This review requires -- --qa")
		quit(1)
		return
	var validate_only: bool="--validate-only" in OS.get_cmdline_user_args()
	if not validate_only and DisplayServer.get_name()=="headless":
		printerr("Native capture requires a drawable window; use --validate-only for headless preflight")
		quit(1)
		return
	var app=null
	if not validate_only:
		DirAccess.make_dir_recursive_absolute(OUT)
		app=load("res://scenes/main.tscn").instantiate()
		root.add_child(app)
		app.qa_duration=0
		app.set_process(false)
		DisplayServer.window_set_size(Vector2i(1440,900))
	for scene_id: String in ReefScene.IDS:
		for preset: String in ["min","max"]:
			for phase: String in ["day","night"]:
				var world:=make_world(scene_id,preset,12.0 if phase=="day" else 23.0)
				var tag: String=scene_id+"-"+preset+"-"+phase
				check(StreamWorld.validate(world.export_state()),"Valid real QA world: "+tag)
				check(world.counts()=={"green_chromis":6,"clownfish":2,"seahorse":2,"royal_gramma":2},"Current12-fish cast: "+tag)
				check(world.scene.slots().size()>=4 and world.scene.slots().size()<=6,"Fixed slot count: "+tag)
				var entry: Dictionary=describe(world,preset,phase)
				if not validate_only:
					app.world=world
					app.viewing_light=false
					app.stage.zoom=1
					app.stage.center=Vector2(640,360)
					app.scene_picker.selected=ReefScene.IDS.find(scene_id)
					app._refresh()
					app._rebuild_decor_bar()
					app.stage.natural_light=1.0 if phase=="day" else 0.0
					app.climate.text="QA · "+scene_id+" · "+phase+" · 12 fish"
					app.status.text="Real simulated world · "+preset+" decor · isolated QA"
					for frame in 20:
						app.stage.animate(1.0/60)
						await process_frame
					RenderingServer.force_draw(false)
					var image: Image=root.get_texture().get_image()
					check(image!=null and not image.is_empty(),"Actual native image: "+tag)
					if image!=null and not image.is_empty():
						check(image.save_png(OUT+tag+"-app.png")==OK,"Saved native image: "+tag)
						var stage_image: Image=app.viewport.get_texture().get_image()
						check(stage_image!=null and not stage_image.is_empty(),"Actual native stage image: "+tag)
						if stage_image!=null and not stage_image.is_empty():
							check(stage_image.save_png(OUT+tag+"-stage.png")==OK,"Saved640x360 stage: "+tag)
						entry.app_image=tag+"-app.png"
						entry.stage_image=tag+"-stage.png"
				cases.append(entry)
	var result: Dictionary={"checks":checks,"failures":failures,"cases":cases,"native_images_verified":not validate_only and failures.is_empty(),"scope":"Current production rendering of controlled real-world snapshots; native interaction/lifecycle/performance remain separate"}
	if not validate_only:
		var file:=FileAccess.open(OUT+"manifest.json",FileAccess.WRITE)
		if file!=null: file.store_string(JSON.stringify(result,"  "))
	print(JSON.stringify(result))
	quit(0 if failures.is_empty() else 1)
