extends SceneTree
const RIG=preload("res://scripts/reef_new_cast_rig.gd")
const OUT="res://artifacts/new-cast-art-review/"
func _initialize() -> void: call_deferred("run")
func run() -> void:
	if not "--qa" in OS.get_cmdline_user_args():
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(OUT)
	var view:=SubViewport.new()
	view.size=Vector2i(640,360)
	view.snap_2d_transforms_to_pixel=true
	view.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	view.canvas_transform=Transform2D(Vector2(.5,0),Vector2(0,.5),Vector2.ZERO)
	var rigs: Array=[]
	for row in 2:
		var bg:=ColorRect.new()
		bg.position=Vector2(0,row*360)
		bg.size=Vector2(1280,360)
		bg.color=Color("183f44") if row==0 else Color("e5ddc7")
		view.add_child(bg)
		var heading:=Label.new()
		heading.text="PRODUCTION SIDE ART / 1.65x" if row==0 else "DIRECT MIRROR / LIGHT BACKGROUND"
		heading.position=Vector2(30,18+row*360)
		heading.modulate=Color.WHITE if row==0 else Color("183f44")
		view.add_child(heading)
		for col in 4:
			var species: String=ReefFishArt.SPECIES[col]
			var rig=RIG.new()
			rig.species=species
			rig.body_scale=1.65
			rig.position=Vector2(168+col*312,180+row*360)
			view.add_child(rig)
			rig.apply_actor({"heading":0.0 if row==0 else PI,"activity":"Cruising"})
			rig.animate(1.0/60)
			rigs.append(rig)
			var label:=Label.new()
			label.position=Vector2(40+col*312,270+row*360)
			label.size.x=260
			label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
			label.text=species
			label.modulate=Color.WHITE if row==0 else Color("183f44")
			view.add_child(label)
	await capture(view,"production-cast")
	var overlay:=Node2D.new()
	view.add_child(overlay)
	overlay.draw.connect(func() -> void:
		for rig: ReefRig in rigs:
			overlay.draw_circle(rig.position,3,Color("28ceeb"))
			overlay.draw_circle(rig.mouth_position(),3,Color("ef8865"))
			if rig.species=="seahorse":
				var grip:=ReefFishArt.anchor_offset(rig.species,"grip")
				grip.x*=rig.facing
				overlay.draw_circle(rig.position+grip*rig.body_scale,3,Color("82be6e")))
	await capture(view,"anchors")
	print("Saved production cast and mirrored anchor review; no world or persistence")
	quit()
func capture(view: SubViewport, name: String) -> void:
	await process_frame
	RenderingServer.force_draw(false)
	var image: Image=view.get_texture().get_image()
	image.resize(1280,720,Image.INTERPOLATE_NEAREST)
	image.save_png(OUT+name+".png")
