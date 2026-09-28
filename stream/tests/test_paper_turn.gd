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
		root.add_child(rig)
		var previous: float=1
		var largest_step: float=0
		var side_only: bool=true
		var accurate: bool=true
		for frame in 241:
			var heading: float=PI*frame/240.0
			rig.apply_actor({"heading":heading,"activity":"Cruising","extend":1.0,"pitch":.1})
			rig.animate(1.0/60)
			var signed_width: float=rig.fish_material.get_shader_parameter("facing")
			accurate=accurate and is_equal_approx(signed_width,cos(rig.pose.heading))
			largest_step=maxf(largest_step,absf(signed_width-previous))
			previous=signed_width
			side_only=side_only and rig.fish.visible and rig.fish.texture==ReefRig.ATLAS and rig.get_child_count()==1
		check(side_only,species+": one side mesh throughout the turn; no replacement sprite")
		check(accurate and largest_step<.014,species+": signed cosine projection is continuous through the flip")
		rig.free()
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
