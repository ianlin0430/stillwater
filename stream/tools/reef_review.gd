extends SceneTree
# Short, save-free rendering review. --interactions exercises real backend APIs.
var viewport: SubViewport
var root_view: Control
var stage: Node2D
var world: StreamWorld
var clock: float=0
var frame: int=0
var captured: Dictionary={}
var output: String
var interactions: bool=false

func _initialize() -> void: call_deferred("run")
func run() -> void:
	Engine.max_fps=30
	interactions="--interactions" in OS.get_cmdline_user_args()
	output=ProjectSettings.globalize_path("res://artifacts/reef-review/")
	root_view=Control.new()
	root.add_child(root_view)
	viewport=SubViewport.new()
	viewport.size=Vector2i(640,360)
	viewport.disable_3d=true
	root_view.add_child(viewport)
	viewport.canvas_transform=Transform2D(Vector2(0.5,0),Vector2(0,0.5),Vector2.ZERO)
	if interactions:
		stage=StreamStage.new()
		viewport.add_child(stage)
		world=StreamWorld.new(42,1000)
		stage.apply_snapshot(world.snapshot())
	else:
		stage=Node2D.new()
		viewport.add_child(stage)
		var sprite:=Sprite2D.new()
		var image:=Image.load_from_file(output+"reef-background-v1.png")
		if image==null:
			push_error("Missing preview asset: "+output+"reef-background-v1.png")
			quit(1)
			return
		sprite.texture=ImageTexture.create_from_image(image)
		sprite.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
		sprite.centered=false
		sprite.scale=Vector2(1280.0/image.get_width(),720.0/image.get_height())
		stage.add_child(sprite)
	var display:=TextureRect.new()
	display.texture=viewport.get_texture()
	display.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	display.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	display.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	display.size=Vector2(1280,720)
	root_view.add_child(display)
	RenderingServer.frame_post_draw.connect(drawn)

func _process(delta: float) -> bool:
	if viewport==null: return false
	clock+=delta
	if interactions:
		if clock>1 and not captured.has("feed"):
			captured.feed=true
			world.feed(640)
		if clock>4 and not captured.has("tap"):
			captured.tap=true
			world.startle(640,360,1)
			stage.tap_feedback(Vector2(640,360))
		world.advance_live(delta)
		stage.apply_snapshot(world.snapshot())
		stage.animate(delta)
	else:
		if clock>3:
			stage.scale=Vector2.ONE*1.65
			stage.position=Vector2(640,360)-Vector2(680,440)*1.65
	if clock>6: quit()
	return false

func drawn() -> void:
	frame+=1
	var key: String=""
	if interactions:
		if clock>1.15 and clock<3: key="feeding"
		elif clock>4.1: key="tap"
	else: key="background-close" if clock>3.3 else "background-normal" if clock>1 else ""
	if not key.is_empty() and not captured.has("image-"+key):
		captured["image-"+key]=true
		viewport.get_texture().get_image().save_png(output+key+".png")
