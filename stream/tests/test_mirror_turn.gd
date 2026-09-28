extends SceneTree
var failures: Array[String]=[]
var checks: int=0
func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok: failures.append(message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	for species: String in StreamStage.PRESENTED_SPECIES:
		var rig:=ReefRig.new()
		rig.species=species
		rig.detached=true
		rig.position=Vector2(350.25,260.75)
		root.add_child(rig)
		var previous: float=1
		var changes: int=0
		var side_only: bool=true
		var full_width: bool=true
		var confirmed: bool=true
		for frame in 241:
			var heading: float=PI*frame/240.0
			rig.apply_actor({"heading":heading,"activity":"Cruising","extend":1.0})
			rig.animate(1.0/60)
			var orientation: float=rig.fish_material.get_shader_parameter("facing")
			full_width=full_width and absf(orientation)==1 and rig.tail_facing==orientation
			if orientation!=previous:
				changes+=1
				confirmed=confirmed and cos(rig.pose.heading)*previous < -rig.MIRROR_THRESHOLD
			previous=orientation
			side_only=side_only and rig.fish.visible and rig.fish.texture==ReefRig.ATLAS and rig.get_child_count()==1
		check(side_only and full_width,species+": only full-width left/right side drawings, body and tail together")
		check(changes==1 and confirmed and rig.facing==-1,species+": slow turn flips exactly once beyond threshold")
		check(rig.position==Vector2(350.25,260.75),species+": flip never moves the actor pivot")
		for frame in 120:
			rig.apply_actor({"heading":PI*.5+sin(frame*2.3)*.12,"activity":"Cruising","extend":1.0})
			rig.animate(1.0/60)
			if rig.facing!=previous: changes+=1
			previous=rig.facing
		check(changes==1,species+": heading jitter around 90 degrees cannot flip back")
		rig.apply_actor({"heading":0.0,"activity":"Cruising","extend":1.0})
		rig.animate(.3)
		check(rig.facing==1,species+": confirmed return heading mirrors right")
		rig.apply_actor({"heading":PI,"activity":"Cruising","extend":1.0})
		rig.animate(.1)
		var hold: float=rig.mirror_hold
		rig.animate(0)
		check(rig.mirror_hold==hold and rig.facing==1,species+": pause freezes mirror lockout")
		rig.animate(.1)
		check(rig.facing==1,species+": opposite heading cannot reverse within 0.25 seconds")
		rig.animate(.06)
		check(rig.facing==-1,species+": confirmed opposite heading flips after cooldown")
		rig.free()
	# A new left-facing actor never flashes a right-facing first frame.
	var left:=ReefRig.new()
	left.species="green_chromis"
	root.add_child(left)
	left.apply_actor({"heading":PI,"activity":"Cruising"})
	left.animate(1.0/60)
	check(left.facing==-1 and left.fish_material.get_shader_parameter("facing")==-1.0,"First snapshot initializes the correct side")
	left.free()
	# Equal elapsed time at both supported foreground rates.
	var results: Array=[]
	for fps in [30,60]:
		var rig:=ReefRig.new()
		rig.species="green_chromis"
		root.add_child(rig)
		rig.apply_actor({"activity":"Cruising","heading":0.0,"thrust":.5,"speed":20.0})
		for frame in fps*2: rig.animate(1.0/fps)
		rig.apply_actor({"activity":"Cruising","heading":PI,"thrust":.5,"speed":20.0})
		for frame in fps: rig.animate(1.0/fps)
		results.append([rig.facing,rig.breath_clock,rig.water_phase,rig.effort])
		rig.free()
	check(absf(results[0][0]-results[1][0])<.0001,"30/60 FPS complete the same turn in real time")
	check(absf(results[0][1]-results[1][1])<.0001 and absf(results[0][2]-results[1][2])<.08 and absf(results[0][3]-results[1][3])<.0001,"Breath and swim clocks use delta at 60 FPS")
	var display:=PixelDisplay.new()
	for available: Vector2 in [Vector2(900,500),Vector2(1200,660),Vector2(1280,720),Vector2(1441,901),Vector2(2560,1440)]:
		display.size=available
		var rect:=PixelDisplay.fitted_rect(available)
		var multiple: float=rect.size.x/640
		check(multiple==floorf(multiple) and rect.size.y==multiple*360 and rect.position==rect.position.floor(),"Integer scale and origin at "+str(available))
		check(display.world_point(rect.position).is_equal_approx(Vector2.ZERO) and display.world_point(rect.end).is_equal_approx(Vector2(1280,720)),"Input matches letterboxed image at "+str(available))
	display.free()
	print(JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
