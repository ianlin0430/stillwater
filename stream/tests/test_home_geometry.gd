extends SceneTree
var checks: int=0
var failures: Array[String]=[]
func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok: failures.append(message)
func _initialize() -> void:
	for scene_id: String in ReefScene.IDS:
		for preset: String in ["min","max"]:
			var w:=StreamWorld.new(42,1000,scene_id)
			for slot: String in w.scene.preset(preset): w.set_decor(slot,w.scene.preset(preset)[slot])
			w.state.light_hour=0
			var inside: int=0
			var below: int=0
			for i in 300:
				w.advance_live(.2)
				for a: Dictionary in w.state.animals:
					if w._obstacles.any(func(o): return Vector2((a.x-o.cx)/o.rx,(a.y-o.cy)/o.ry).length_squared()<1.0): inside+=1
					if a.y>w.bed_y(a.x)-StreamWorld.BODY[a.species][1]*w.animal_scale(a)*.5+.001:
						below+=1
			check(inside==0,scene_id+"/"+preset+": centres never inside obstacles ("+str(inside)+")")
			check(below==0,scene_id+"/"+preset+": bodies above bed ("+str(below)+")")
	print(JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
