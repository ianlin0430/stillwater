extends SceneTree
# S6 gates, fixed before implementation/measurement (plan §7 S6): daytime 30 minutes,
# each clownfish inside its anemone ellipse >= 0.6, farthest from its centre <= 120 px;
# a glass tap returns it inside within 3 s. Both scenes, all eight motion seeds.
const Seeds = preload("res://tests/seed_lists.gd")
var checks: int = 0
var failures: Array[String] = []
var numbers: Dictionary = {}
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message)
func ellipse(w: StreamWorld, a: Dictionary) -> Dictionary:
	return w.scene.effects(a.home.slot, w.state.decor[w.state.scene][a.home.slot]).anemone
func inside(w: StreamWorld, a: Dictionary) -> bool:
	var e: Dictionary = ellipse(w, a)
	return Vector2((a.x-e.cx)/e.rx, (a.y-e.cy)/e.ry).length_squared() <= 1.0
func _initialize() -> void:
	var selected: Array = Seeds.motion()
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--seeds="): selected = Array(arg.trim_prefix("--seeds=").split(",")).map(func(s): return int(s))
	for scene_id: String in ["reef", "shipwreck"]:
		for seed_value: int in selected:
			var w := StreamWorld.new(seed_value, 1000, scene_id)
			w.state.light_hour = 12.0
			var rows: Dictionary = {}
			var far_states: Dictionary = {}
			for a: Dictionary in w.state.animals:
				if a.species == "clownfish": rows[a.id] = {"inside":0, "ticks":0, "farthest":0.0}
			for i in 9000:
				w.advance_live(0.2)
				for a: Dictionary in w.state.animals:
					if not rows.has(a.id): continue
					var r: Dictionary = rows[a.id]
					r.ticks += 1
					if inside(w, a): r.inside += 1
					var distance: float = Vector2(a.x-a.home_x, a.y-a.home_y).length()
					if distance > r.farthest:
						r.farthest = distance
						far_states[a.id] = w.export_state()
			for id: int in rows:
				var r: Dictionary = rows[id]
				var tag: String = "%s/%d/%d" % [scene_id, seed_value, id]
				r.ratio = float(r.inside)/r.ticks
				check(r.ratio >= 0.6, tag+": inside ratio >= 0.6 (%.6f)" % r.ratio)
				check(r.farthest <= 120.0, tag+": farthest <= 120 px (%.6f)" % r.farthest)
				var tapped := StreamWorld.new()
				check(tapped.restore(far_states[id]), tag+": farthest state restores")
				var fish: Dictionary = tapped.state.animals.filter(func(a): return a.id == id)[0]
				tapped.startle(fish.x, fish.y)
				var returned: float = 0.0 if inside(tapped, fish) else -1.0
				for i in 15:
					tapped.advance_live(0.2)
					if returned < 0.0 and inside(tapped, fish): returned = (i+1)*0.2
				r.tap_return_s = returned
				check(returned >= 0.0 and returned <= 3.0, tag+": tap returns inside within 3 s (%.1f)" % returned)
				numbers[tag] = r
	print(JSON.stringify({"checks":checks, "failures":failures, "numbers":numbers}))
	quit()
