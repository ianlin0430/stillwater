extends SceneTree
var checks: int=0
var failures: Array[String]=[]
func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok: failures.append(message)
func _initialize() -> void:
	var w:=StreamWorld.new(42,1000)
	w.advance_live(1.4)
	var ids: Array=w.state.animals.map(func(a): return [a.id,a.age,a.energy,a.parent])
	var ecology: int=w.rng.state
	var motion: int=w.motion_rng.state
	var original: Dictionary=w.state.decor.reef.duplicate()
	check(not w.set_scene("unknown"),"Unknown scene rejected")
	check(w.set_scene("shipwreck"),"Move to shipwreck")
	check(w.state.scene=="shipwreck" and w.scene.id()=="shipwreck","Scene and terrain agree")
	check(ids==w.state.animals.map(func(a): return [a.id,a.age,a.energy,a.parent]),"Identities and ecology preserved")
	check(w.rng.state==ecology and w.motion_rng.state==motion,"Neither RNG advances on relocation")
	check(w.state.animals.all(func(a): return a.relocated_at==w.state.elapsed),"Every relocation is explicit")
	check(w.state.animals.all(func(a): return a.y>=w.band(a.species)[0] and a.y<=w.band(a.species)[1] and a.y<=w.bed_y(a.x)-StreamWorld.BODY[a.species][1]*w.animal_scale(a)*.5+0.001),"Every fish inside new habitat")
	check(w.state.animals.all(func(a): return w._obstacles.all(func(o): return Vector2((a.x-o.cx)/o.rx,(a.y-o.cy)/o.ry).length_squared()>=1)),"No fish relocated inside an obstacle")
	check(StreamWorld.validate(w.export_state()),"Relocated world validates")
	var restored:=StreamWorld.new()
	check(restored.restore(w.export_state()),"Relocated world restores")
	check(restored.scene.id()=="shipwreck","Restored scene agrees")
	check(w.set_scene("reef") and w.state.decor.reef==original,"Scene choices survive round trip")
	print(JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
