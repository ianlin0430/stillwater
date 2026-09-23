extends SceneTree
const Candidate=preload("res://tools/art_candidates/shrimp_candidate.gd")
const OUT="res://artifacts/shrimp-review/"
var view: SubViewport
var canvas: Node2D
var old: SwimmerRig
var fresh: SwimmerRig
var title: Label
func _initialize() -> void: call_deferred("run")
func capture(name: String) -> void:
	await RenderingServer.frame_post_draw
	view.get_texture().get_image().save_png(OUT+name+".png")
func run() -> void:
	Engine.max_fps=30
	DirAccess.make_dir_recursive_absolute(OUT+"frames")
	view=SubViewport.new()
	view.size=Vector2i(640,360)
	view.disable_3d=true
	root.add_child(view)
	view.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	view.canvas_transform=Transform2D(Vector2(0.5,0),Vector2(0,0.5),Vector2.ZERO)
	canvas=Node2D.new()
	view.add_child(canvas)
	var bg:=Sprite2D.new()
	bg.texture=load("res://assets/pixel/stream-fish-shrimp.png")
	bg.centered=false
	bg.scale=Vector2(1280.0/bg.texture.get_width(),720.0/bg.texture.get_height())
	canvas.add_child(bg)
	old=SwimmerRig.new()
	fresh=Candidate.new()
	for rig: SwimmerRig in [old,fresh]:
		rig.species="shrimp"
		rig.position=Vector2(485 if rig==old else 775,601)
		rig.body_scale=0.75
		rig.scale=Vector2.ONE*rig.body_scale
		canvas.add_child(rig)
	var display:=TextureRect.new()
	display.texture=view.get_texture()
	display.size=Vector2(1280,720)
	root.add_child(display)
	title=Label.new()
	title.position=Vector2(30,70)
	var plate:=StyleBoxFlat.new()
	plate.bg_color=Color(0.06,0.14,0.13,0.9)
	plate.content_margin_left=10
	plate.content_margin_right=10
	title.add_theme_stylebox_override("normal",plate)
	title.add_theme_font_size_override("font_size",25)
	view.add_child(title)
	var cases: Array=[
		{"name":"female","sex":"female","age":40,"tint":0.6},
		{"name":"male","sex":"male","age":40,"tint":0.6},
		{"name":"newborn","sex":"female","age":0,"tint":0.6},
		{"name":"juvenile","sex":"female","age":10.5,"tint":0.6},
		{"name":"berried","sex":"female","age":40,"tint":0.6,"brood_until":432000},
		{"name":"molting","sex":"female","age":40,"tint":0.6,"molting_until":1},
		{"name":"tint-low","sex":"female","age":40,"tint":0.1},
		{"name":"tint-mid","sex":"female","age":40,"tint":0.6},
		{"name":"tint-high","sex":"female","age":40,"tint":1.0}]
	var shell:=SwimmerRig.new()
	shell.species="shrimp"
	shell.exuvia=true
	shell.body_scale=0.75
	shell.scale=Vector2.ONE*0.75
	shell.position=Vector2(710,651)
	shell.modulate.a=0.5
	canvas.add_child(shell)
	for a: Dictionary in cases:
		fresh.apply_identity(a,0)
		old.sex=a.sex
		old.berried=fresh.berried
		old.molting=fresh.molting
		shell.visible=fresh.molting
		for rig: SwimmerRig in [old,fresh]:
			rig.body_scale=0.48 if a.age<21 else 0.75
			rig.scale=Vector2.ONE*rig.body_scale
			rig.position.y=660-12*rig.body_scale
			rig.reset_contact()
			rig.activity="Grazing"
			rig.animate(0.1)
		for zoom: float in [1.0,1.65]:
			canvas.scale=Vector2.ONE*zoom
			canvas.position=Vector2.ZERO if zoom==1 else Vector2(640,360)-Vector2(640,500)*zoom
			title.text="%s  |  %s  |  LEFT: current   RIGHT: candidate" % [a.name,"normal" if zoom==1 else "1.65x"]
			await capture(a.name+("-normal" if zoom==1 else "-close"))
	shell.hide()
	old.hide()
	fresh.hide()
	var tint_rigs: Array=[]
	for i in 3:
		var sample=Candidate.new()
		sample.species="shrimp"
		sample.position=Vector2(410+i*220,651)
		sample.body_scale=0.75
		sample.scale=Vector2.ONE*0.75
		canvas.add_child(sample)
		sample.apply_identity({"sex":"female","age":40,"tint":[0.1,0.6,1.0][i]},0)
		sample.animate(0.1)
		tint_rigs.append(sample)
	title.text="Candidate pigment  |  low 0.1 / middle 0.6 / high 1.0  |  1.65x"
	await capture("tints-close")
	for sample: Node in tint_rigs: sample.free()
	old.show()
	fresh.show()
	fresh.apply_identity(cases[0],0)
	old.berried=false
	old.molting=false
	for frame in 240:
		var section: int=frame/60
		title.text=["Walking","Swimming","Grazing","Turning"][section]+" | current / candidate | scripted rig study"
		for rig: SwimmerRig in [old,fresh]:
			rig.activity=["Exploring","Swimming","Grazing","Exploring"][section]
			rig.face_target=-1 if section==3 else 1
			rig.position.x+=([7,17,0,-7][section])/30.0
			rig.animate(1.0/30)
		await capture("frames/%04d" % frame)
	quit()
