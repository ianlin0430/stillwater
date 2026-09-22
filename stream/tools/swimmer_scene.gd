extends Control

var viewport: SubViewport
var stage: Node2D
var rigs: Array[SwimmerRig]=[]
var caption: Label
var clock: float=0
var captures: Dictionary={}
var recorded_frames: int=0
var frames_dir: String=""

func _ready() -> void:
	Engine.max_fps=30
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--frames="):
			frames_dir=arg.trim_prefix("--frames=")
	RenderingServer.frame_post_draw.connect(_on_drawn)
	viewport=SubViewport.new()
	viewport.size=Vector2i(640,360)
	viewport.disable_3d=true
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	viewport.canvas_transform=Transform2D(Vector2(0.5,0),Vector2(0,0.5),Vector2.ZERO)
	stage=Node2D.new()
	stage.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	viewport.add_child(stage)
	var bg:=Sprite2D.new()
	bg.texture=load("res://assets/pixel/stream-fish-shrimp.png")
	bg.centered=false
	bg.scale=Vector2(1280.0/bg.texture.get_width(),720.0/bg.texture.get_height())
	stage.add_child(bg)
	for i in 3:
		var rig:=SwimmerRig.new()
		rig.species=["threadfin","hatchet","shrimp"][i]
		rig.individual_id=i+1
		rig.position=Vector2(500,[320,220,585][i])
		rig.body_scale=0.75 if i==2 else 1.0
		rig.scale=Vector2.ONE*rig.body_scale
		stage.add_child(rig)
		rigs.append(rig)
	var display:=TextureRect.new()
	display.texture=viewport.get_texture()
	display.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	display.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	display.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	display.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(display)
	caption=Label.new()
	caption.position=Vector2(24,15)
	caption.add_theme_font_size_override("font_size",16)
	add_child(caption)

func _on_drawn() -> void:
	if not frames_dir.is_empty():
		viewport.get_texture().get_image().save_png("%s/%05d.png" % [frames_dir,recorded_frames])
	recorded_frames+=1
	_step(1.0/30.0)

func _step(delta: float) -> void:
	clock+=delta
	var pose: int=int(clock/3)%6
	var t: float=fmod(clock,3)
	var close_up: bool=clock>=18
	stage.scale=Vector2.ONE*(1.65 if close_up else 1)
	stage.position=Vector2(640,360)-Vector2(600,385)*1.65 if close_up else Vector2.ZERO
	var names: Array[String]=["Cruising / walking","Braking / grazing","Turning","Fins / feeding","Resting","Swimming / tail escape"]
	caption.text="Soft Pixel · "+("1.65× inspection" if close_up else "Normal view")+" · "+names[pose]
	for i in 3:
		var rig: SwimmerRig=rigs[i]
		var shrimp: bool=i==2
		var speed: float=6.0 if shrimp else 17.0
		match pose:
			0:
				rig.activity="Exploring" if shrimp else "Swimming"
				rig.face_target=1
				rig.position.x+=speed*delta
			1:
				rig.activity="Grazing" if shrimp else "Resting"
				rig.position.x+=speed*maxf(0,1-t)*delta
			2:
				rig.activity="Exploring" if shrimp else "Swimming"
				rig.face_target=-1
				rig.position.x-=speed*delta
			3:
				rig.activity="Grazing" if shrimp else "Displaying" if i==0 else "Surface feeding"
			4:
				rig.activity="Resting"
			5:
				if shrimp:
					rig.activity="Swimming" if t<1.5 else "Retreating"
					rig.position.x+=(-12 if t<1.5 else 90*exp(-(t-1.5)*3))*delta
					rig.position.y-=delta*6 if t<1.5 else 0
				else:
					rig.activity="Swimming"
					rig.position.x-=speed*delta
		rig.animate(delta)
	var key: String=str(pose)+("-close" if close_up else "-normal")
	if t>2 and not captures.has(key):
		captures[key]=true
		_capture.call_deferred(key)
	if clock>36:
		get_tree().quit()

func _capture(key: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://artifacts/pixel/swimmers-"+key+".png")
