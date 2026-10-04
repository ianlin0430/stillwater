extends SceneTree
# S6 interaction/save contracts; no ecology or motion criteria are changed here.
var checks: int = 0
var failures: Array[String] = []
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message)
func fish(w: StreamWorld) -> Dictionary:
	return w.state.animals.filter(func(a): return a.species=="clownfish")[0]
func _initialize() -> void:
	for scene_id: String in ["reef","shipwreck"]:
		var w := StreamWorld.new(812,1000,scene_id)
		var a: Dictionary = fish(w)
		w.state.animals=[a]
		w.state.ledger.initial=w.material()
		w.advance_live(120.0)
		check(a.has("nestle") and a.nestle>=0.0 and a.nestle<=1.0,scene_id+": nestle target exists and is bounded")
		for activity: String in ["Nestling","Foraging","Feeding","Sheltering","Sleeping"]:
			w.state.light_hour = 1.0 if activity=="Sleeping" else 12.0
			if activity=="Sheltering": w.startle(a.x,a.y)
			elif activity=="Sleeping": w.advance_live(0.2)
			elif activity=="Feeding":
				a.energy=1.0
				w.feed(a.home_x)
				for i in 300:
					w.advance_live(0.2)
					if a.activity=="Feeding": break
			else:
				if w.state.has("food"): w.state.food.clear()
				for i in 3000:
					w.advance_live(0.2)
					if a.activity==activity: break
			check(a.activity==activity,scene_id+": reaches "+activity)
			var back := StreamWorld.new()
			check(back.restore(w.export_state()),scene_id+": restores "+activity)
			var identical: bool=true
			for i in 50:
				w.advance_live(0.2)
				back.advance_live(0.2)
				identical=identical and var_to_bytes(w.export_state())==var_to_bytes(back.export_state())
			check(identical,scene_id+": byte-identical continuation from "+activity)
		var bad: Dictionary=w.export_state()
		for value: float in [-0.01,1.01,NAN,INF]:
			bad.animals.filter(func(x): return x.id==a.id)[0].nestle=value
			check(not StreamWorld.validate(bad),scene_id+": rejects invalid nestle "+str(value))
		var old: Dictionary=w.export_state()
		for x: Dictionary in old.animals: x.erase("nestle")
		var legacy := StreamWorld.new()
		check(legacy.restore(old),scene_id+": pre-S6 v3 saves remain readable")
		w.state.light_hour=12.0
		w.set_lure(Vector2(a.x,a.y))
		w.advance_live(0.2)
		check(a.activity=="Sheltering" and a.nestle==1.0,scene_id+": nearby cursor shelters")
		w.clear_lure()
		w.advance_live(StreamWorld.STARTLE.hide_seconds+0.2)
		check(a.activity!="Sheltering",scene_id+": shelter expires")
		w.state.light_hour=1.0
		w.advance_live(180)
		var at:=Vector2(a.x,a.y)
		w.advance_live(10)
		check(a.activity=="Sleeping" and a.nestle==1.0 and at.distance_to(Vector2(a.x,a.y))<2.0,scene_id+": sleeps nearly still inside home")
		var rng_before: Array=[w.rng.state,w.motion_rng.state]
		at=Vector2(a.x,a.y)
		check(w.set_decor(a.home.slot,"anemone_pink"),scene_id+": changes anemone style")
		var e: Dictionary=w.scene.effects(a.home.slot,"anemone_pink").anemone
		check(a.home_x==e.cx and a.home_y==e.cy and Vector2(a.x,a.y)==at and [w.rng.state,w.motion_rng.state]==rng_before,scene_id+": rehome updates coordinates without moving or drawing RNG")
	print(JSON.stringify({"checks":checks,"failures":failures}))
	quit()
