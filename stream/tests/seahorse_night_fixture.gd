extends RefCounted
# Captured from the unchanged S7 shipwreck/seed3 day-to-night trigger.
# Below40px on a vertical hitch leg, ordinary forward headway used to make
# horse9 oscillate sideways and miss the original120-second attachment gate.
# This exact state prevents a changed daytime RNG order from avoiding the bug.
const FIXTURE="res://tests/fixtures/shipwreck-night-hitch-seed3.var"

static func run(check: Callable) -> void:
	var file:=FileAccess.open(FIXTURE,FileAccess.READ)
	check.call(file!=null,"Night-hitch regression fixture exists")
	if file==null: return
	var before: Dictionary=file.get_var()
	file.close()
	var w:=StreamWorld.new()
	var restored: bool=StreamWorld.validate(before) and w.restore(before) and var_to_bytes(w.export_state())==var_to_bytes(before)
	check.call(restored,"Night-hitch regression restores the exact pre-night world")
	if not restored: return
	w.state.light_hour=0.0
	w.advance_live(120)
	var horses: Array=w.state.animals.filter(func(a): return a.species=="seahorse")
	check.call(horses.size()==2 and horses.all(func(a): return a.activity=="Hitched"),"Exact shipwreck/3 regression: all horses hitch within the original120-second night gate")
	check.call(horses.all(func(a): return a.has("hitch_x") and Vector2(a.hitch_x-a.home_x,a.hitch_y-a.home_y).length()<.001 and Vector2(a.x,a.y).distance_to(w._hitch_center(a))<=2.001 and not a.has("relocated_at")),"Night-hitch regression keeps actual tail contacts without relocation")
