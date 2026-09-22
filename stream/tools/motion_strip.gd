extends Control
# Diagnostic: follows one swimmer through a scripted sequence at true pixel scale.
# With --out=DIR, every third drawn frame inside five sequence windows is saved for tiling.

var viewport: SubViewport
var stage: Node2D
var rig: SwimmerRig
var clock: float=0
var species: String="threadfin"
var out_dir: String=""
var frame: int=0

func _ready() -> void:
	Engine.max_fps=30
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--species="):
			species=arg.trim_prefix("--species=")
		elif arg.begins_with("--out="):
			out_dir=arg.trim_prefix("--out=")
	viewport=SubViewport.new()
	viewport.size=Vector2i(160,90)
	viewport.disable_3d=true
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	stage=Node2D.new()
	stage.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	viewport.add_child(stage)
	var bg:=Sprite2D.new()
	bg.texture=load("res://assets/pixel/stream-fish-shrimp.png")
	bg.centered=false
	bg.scale=Vector2(1280.0/bg.texture.get_width(),720.0/bg.texture.get_height())
	stage.add_child(bg)
	rig=SwimmerRig.new()
	rig.species=species
	rig.individual_id=1
	rig.body_scale=0.75 if species=="shrimp" else 1.0
	rig.scale=Vector2.ONE*rig.body_scale
	rig.position=Vector2(560,585 if species=="shrimp" else 300)
	stage.add_child(rig)
	var display:=TextureRect.new()
	display.texture=viewport.get_texture()
	display.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	display.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	display.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	display.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(display)
	# Advance only after a frame is actually drawn: occluded macOS windows skip drawing.
	RenderingServer.frame_post_draw.connect(_on_drawn)

func _on_drawn() -> void:
	if not out_dir.is_empty():
		for start: float in [1.0,3.1,4.6,7.6,9.0]:
			var n: int=frame-int(start*30)
			if n>=0 and n<18 and n%3==0:
				viewport.get_texture().get_image().save_png("%s/%s-%02d.png" % [out_dir,str(start),n/3])
	_step(1.0/30)

func _step(delta: float) -> void:
	clock+=delta
	var shrimp: bool=species=="shrimp"
	var speed: float=6.0 if shrimp else 17.0
	if clock<3:
		rig.activity="Exploring" if shrimp else "Swimming"
		rig.face_target=1
		rig.position.x+=speed*delta
	elif clock<4.5:
		rig.activity="Grazing" if shrimp else "Resting"
		rig.position.x+=speed*maxf(0,1-(clock-3))*delta
	elif clock<7.5:
		rig.activity="Exploring" if shrimp else "Swimming"
		rig.face_target=-1
		rig.position.x-=speed*delta
	elif clock<9:
		rig.activity="Grazing" if shrimp else "Displaying"
	elif clock<10.5:
		rig.activity="Retreating" if shrimp else "Swimming"
		if shrimp:
			rig.position.x+=90*exp(-(clock-9)*3)*delta
		else:
			rig.position.x-=speed*2.2*delta
	else:
		get_tree().quit()
	rig.animate(delta)
	# Camera follows at world scale 0.5, matching the app's 640x360 pixel view.
	viewport.canvas_transform=Transform2D(Vector2(0.5,0),Vector2(0,0.5),Vector2(80,45)-rig.position*0.5)
	frame+=1
