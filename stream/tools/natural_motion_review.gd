extends SceneTree
# Matching backend snapshots and camera for both versions; only rigs differ.
const OUT="res://artifacts/natural-motion-review/"
var before_script: Script
func _initialize() -> void: call_deferred("run")
func run() -> void:
	Engine.max_fps=30
	before_script=load(OUT+"before_rig.gd")
	if before_script==null:
		printerr("Missing archived before rig; see review README")
		quit(1)
		return
	for species: String in ["green_chromis","yellow_tang","purple_firefish","lawnmower_blenny"]:
		await record_species(species)
	quit()
func record_species(species: String) -> void:
	var w:=StreamWorld.new(42,1000)
	var start: float=choose_start(species)
	w.advance_live(start)
	var subject: Dictionary=w.state.animals.filter(func(a): return a.species==species)[0]
	var id: int=subject.id
	var panels: Array=[]
	var rigs: Array=[]
	var container:=SubViewport.new()
	container.size=Vector2i(960,1080)
	container.disable_3d=true
	container.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(container)
	for side in 2:
		var panel:=SubViewport.new()
		panel.size=Vector2i(960,540)
		panel.disable_3d=true
		panel.render_target_update_mode=SubViewport.UPDATE_ALWAYS
		container.add_child(panel)
		panels.append(panel)
		var bg:=Sprite2D.new()
		bg.texture=preload("res://assets/reef/background-v1.png")
		bg.centered=false
		bg.scale=Vector2(1280,720)/bg.texture.get_size()
		panel.add_child(bg)
		var rig=before_script.new() if side==0 else ReefRig.new()
		rig.species=species
		rig.individual_id=id
		rig.position=Vector2(subject.x,subject.y)
		rig.facing=subject.direction
		rig.face_target=subject.direction
		panel.add_child(rig)
		rig.apply_actor(subject)
		rigs.append(rig)
		var display:=TextureRect.new()
		display.texture=panel.get_texture()
		display.position=Vector2(0,side*540)
		display.size=Vector2(960,540)
		display.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
		container.add_child(display)
		var label:=Label.new()
		label.position=Vector2(18,side*540+12)
		label.text=("BEFORE" if side==0 else "AFTER")+" · "+species+" · 1.65x · same simulation"
		label.add_theme_font_size_override("font_size",18)
		container.add_child(label)
	var output: String=OUT+species+"/"
	DirAccess.make_dir_recursive_absolute(output)
	var samples: Array=[]
	var prev: Vector2=Vector2(subject.x,subject.y)
	var next: Vector2=prev
	var tick_age: float=0
	var camera: Vector2=prev-Vector2(0,30)
	var shown: int=-1
	for frame in 360:
		if frame==240 and species=="purple_firefish": w.startle(subject.x,subject.y)
		w.advance_live(1.0/30)
		if shown!=w.state.motion_ticks:
			shown=w.state.motion_ticks
			prev=next
			next=Vector2(subject.x,subject.y)
			tick_age=0
			for rig in rigs:
				rig.face_target=subject.direction
				rig.apply_actor(subject)
			var row: Dictionary={"t":w.state.elapsed}
			for k: String in ["heading","thrust","speed","pitch","turn","roll","flick","activity"]: row[k]=subject.get(k,0)
			samples.append(row)
		tick_age+=1.0/30
		var at: Vector2=prev.lerp(next,minf(1,tick_age/.2))
		camera=camera.lerp(at-Vector2(0,30),.025).clamp(Vector2(388,243),Vector2(892,526))
		for side in 2:
			var scale_factor: float=.75*1.65
			panels[side].canvas_transform=Transform2D(Vector2(scale_factor,0),Vector2(0,scale_factor),Vector2(480,300)-camera*scale_factor)
			rigs[side].position=at
			rigs[side].animate(1.0/30)
		await process_frame
		RenderingServer.force_draw(false)
		container.get_texture().get_image().save_jpg(output+"frame-%04d.jpg"%frame,.9)
	FileAccess.open(output+"trace.json",FileAccess.WRITE).store_string(JSON.stringify({"seed":42,"start":start,"seconds":12,"tap_at":start+8 if species=="purple_firefish" else -1,"samples":samples},"  "))
	container.free()
	print("Recorded comparison: "+species)

func choose_start(species: String) -> float:
	var probe:=StreamWorld.new(42,1000)
	var a: Dictionary=probe.state.animals.filter(func(v): return v.species==species)[0]
	var rows: Array=[]
	for i in 600:
		probe.advance_live(.2)
		rows.append(a.duplicate(true))
	var best_score: float=-1
	var best: int=0
	for start in range(25,540,5):
		var score: float=0
		for j in range(start,start+40):
			var row: Dictionary=rows[j]
			match species:
				"yellow_tang": score+=absf(row.get("turn",0))*0.3+row.get("roll",0)*2
				"lawnmower_blenny": score+=row.get("thrust",0)*3+absf(row.get("turn",0))*.2
				"purple_firefish": score+=row.get("flick",0)*5+float(row.activity=="Hovering")*.01
				_: score+=absf(row.get("turn",0))*.1+row.get("thrust",0)*.1
		if score>best_score:
			best_score=score
			best=start
	return best*.2
