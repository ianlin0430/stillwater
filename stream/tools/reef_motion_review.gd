extends Control
# Real seeded world, actual user APIs, no user saves. Recording is not a benchmark.
var world: StreamWorld
var stage: StreamStage
var viewport: SubViewport
var time: float=0
var shown_tick: int=-1
var frame: int=0
var captured_time: float=-1
var record: bool=false
var duration: float=14
var acted: Dictionary={}
var output: String
var evidence: Array=[]
var caption: Label
var paused: bool=false
var benchmark: bool=false
var render_frames: int=0
var started_ms: int=0

func _ready() -> void:
	started_ms=Time.get_ticks_msec()
	Engine.max_fps=30
	DisplayServer.window_set_title("Stillwater Reef · animation preview · no saves")
	output=ProjectSettings.globalize_path("res://artifacts/reef-motion-refined/")
	DirAccess.make_dir_recursive_absolute(output)
	for arg in OS.get_cmdline_user_args():
		if arg=="--record": record=true
		if arg=="--benchmark": benchmark=true
		if arg.begins_with("--duration="): duration=float(arg.trim_prefix("--duration="))
	if benchmark: DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP,true)
	viewport=SubViewport.new()
	viewport.size=Vector2i(960,540)
	viewport.disable_3d=true
	add_child(viewport)
	viewport.canvas_transform=Transform2D(Vector2(0.75,0),Vector2(0,0.75),Vector2.ZERO)
	stage=StreamStage.new()
	viewport.add_child(stage)
	stage.natural_light=1
	world=StreamWorld.new(42,1000)
	world.state.light_hour=12
	stage.apply_snapshot(world.snapshot())
	var display:=TextureRect.new()
	display.texture=viewport.get_texture()
	display.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	display.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	display.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	display.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(display)
	caption=Label.new()
	caption.position=Vector2(24,60)
	caption.add_theme_font_size_override("font_size",15)
	caption.text="Live seeded reef · F feed · T tap · R ripple · Z zoom · Space pause · Esc close"
	add_child(caption)
	RenderingServer.frame_post_draw.connect(capture)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_ESCAPE: get_tree().quit()
			KEY_SPACE: paused=not paused
			KEY_Z:
				stage.zoom=1.65 if stage.zoom==1 else 1
				stage.center=Vector2(600,465)
			KEY_F:
				if not paused: world.feed(450)
			KEY_T:
				if not paused:
					world.startle(580,510)
					stage.tap_feedback(stage.position+Vector2(580,510)*stage.zoom)
			KEY_R:
				if not paused: stage.interact(stage.position+Vector2(660,580)*stage.zoom)

func _process(delta: float) -> void:
	if record: delta=1.0/30
	if paused:
		stage.animate(0)
		return
	time+=delta
	if record:
		if time>1 and not acted.has("feed"):
			acted.feed=true
			world.feed(450)
		if time>3 and not acted.has("tap"):
			acted.tap=true
			world.startle(580,510)
			stage.tap_feedback(stage.position+Vector2(580,510)*stage.zoom)
		if time>6 and not acted.has("zoom"):
			acted.zoom=true
			stage.zoom=1.65
			stage.center=Vector2(600,465)
	world.advance_live(minf(delta,0.1))
	if shown_tick!=world.state.motion_ticks:
		stage.apply_snapshot(world.snapshot())
		shown_tick=world.state.motion_ticks
	stage.animate(minf(delta,0.1))
	if record or benchmark: RenderingServer.force_draw(false)
	if duration>0 and time>=duration:
		if benchmark:
			var report:=FileAccess.open(output+"render-benchmark.json",FileAccess.WRITE)
			report.store_string(JSON.stringify({"wall_seconds":(Time.get_ticks_msec()-started_ms)/1000.0,"render_frames":render_frames,"resolution":[960,540]},"  "))
		var file:=FileAccess.open(output+("events.json" if record else "live-events.json"),FileAccess.WRITE)
		file.store_string(JSON.stringify({"seed":42,"biological_hour":12,"scripted_input_seconds":{"feed":1,"tap":3,"zoom":6},"samples":evidence},"  "))
		get_tree().quit()

func capture() -> void:
	render_frames+=1
	if not record or time==captured_time: return
	captured_time=time
	var image: Image=viewport.get_texture().get_image()
	image.save_jpg(output+"frame-%05d.jpg" % frame,0.9)
	if frame%30==0:
		image.save_png(output+"second-%02d.png" % (frame/30))
		var actors: Array=[]
		for id: int in stage.rigs:
			var rig: ReefRig=stage.rigs[id]
			actors.append({"id":id,"species":rig.species,"activity":rig.activity,"extend":rig.extension,"body_visible":rig.body_visible,"position":[rig.position.x,rig.position.y],"visual_offset":[rig.visual_offset.x,rig.visual_offset.y]})
		evidence.append({"time":time,"actors":actors})
	frame+=1
