extends SceneTree
var checks: int=0
var failures: Array[String]=[]
func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok: failures.append(message)
func _initialize() -> void:
	var current:=StreamWorld.new(42,1000,"shipwreck")
	var saved: Dictionary=current.export_state()
	var horse: Dictionary=saved.animals.filter(func(a): return a.species=="seahorse" and a.home.i==3)[0]
	horse.home_x=726.0
	horse.hitch_x=726.0
	horse.x=726.0+4.771
	horse.tx=horse.x
	var old: Dictionary=saved.duplicate(true)
	var restored:=StreamWorld.new()
	check(restored.restore(saved),"Existing v3 contact layout restores")
	var after: Dictionary=restored.export_state()
	var actor: Dictionary=after.animals.filter(func(a): return a.id==horse.id)[0]
	check(actor.home_x==690.0 and actor.home_y==570.0,"Changed kelp contact migrates by its stable home key")
	check(actor.x==horse.x and actor.y==horse.y,"Anchor migration moves no fish immediately")
	check(after.rng==old.rng and after.motion_rng==old.motion_rng,"Anchor migration draws neither RNG")
	check([after.resources,after.ledger,after.totals,after.causes]==[old.resources,old.ledger,old.totals,old.causes],"Migration changes no ecological state")
	check(var_to_bytes(saved)==var_to_bytes(old),"Restore does not modify its input save")
	restored.state.light_hour=0
	restored.advance_live(30)
	check(restored.state.animals.filter(func(a): return a.id==horse.id)[0].has("hitch_x"),"Migrated horse swims back and reattaches within30s")
	var same: Dictionary=restored.export_state()
	var duplicate:=StreamWorld.new()
	check(duplicate.restore(same) and var_to_bytes(duplicate.export_state())==var_to_bytes(same),"Current-layout save restores byte-for-byte")
	var roost:=StreamWorld.new(42,1000)
	roost.state.light_hour=0
	roost.advance_live(180)
	roost.state.light_hour=12
	var dawn: Dictionary=roost.export_state()
	var copy:=StreamWorld.new()
	check(copy.restore(dawn) and var_to_bytes(copy.export_state())==var_to_bytes(dawn),"Dawn snapshot restores without eager state mutation")
	roost.advance_live(180)
	copy.advance_live(180)
	check(var_to_bytes(copy.export_state())==var_to_bytes(roost.export_state()),"Dawn layer and wakeup continue deterministically after restore")
	var shared: Dictionary=StreamWorld.new(42,1000,"shipwreck").export_state()
	var grammas: Array=shared.animals.filter(func(a): return a.species=="royal_gramma")
	grammas[1].home=grammas[0].home.duplicate()
	grammas[1].home_x=grammas[0].home_x
	grammas[1].home_y=grammas[0].home_y
	var repaired:=StreamWorld.new()
	check(repaired.restore(shared),"Legacy v3 shared home restores")
	var residents: Array=repaired.state.animals.filter(func(a): return a.species=="royal_gramma")
	check(StreamWorld._home_key(residents[0].home)!=StreamWorld._home_key(residents[1].home),"Legacy duplicate cave occupancy migrates to distinct available homes")
	check(residents[1].x==grammas[1].x and residents[1].y==grammas[1].y,"Duplicate-home repair does not teleport")
	print(JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
