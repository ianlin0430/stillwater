extends SceneTree
const Seeds=preload("res://tests/seed_lists.gd")
var checks: int=0
var failures: Array[String]=[]
func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok: failures.append(message)
func _initialize() -> void:
	for scene_id: String in ReefScene.IDS:
		for seed_value: int in Seeds.motion():
			var w:=StreamWorld.new(seed_value,1000,scene_id)
			var shelters: Array=[]
			for slot: Dictionary in w.scene.slots():
				for h: Dictionary in w.scene.effects(slot.id,w.state.decor[scene_id][slot.id]).shelters:
					if "green_chromis_night" in h.use: shelters.append(h)
			check(not shelters.is_empty(),scene_id+": fixture has a night shelter")
			var h: Dictionary=shelters[0]
			var lead: Dictionary=w.state.animals.filter(func(a): return a.species=="green_chromis")[0]
			lead.x=h.x+40
			lead.y=h.y-140
			w.state.light_hour=0
			var rng_before: int=w.rng.state
			for i in 20:
				w._choose_activity(lead)
				if lead.activity=="Resting": break
			var tag: String=scene_id+"/"+str(seed_value)
			check(lead.activity=="Resting",tag+": a night rest is selected")
			check(Vector2(lead.tx-h.x,lead.ty-h.y).length()<=60.001,tag+": rest target <=60px from a nearby eligible shelter")
			check(w._aim(lead).distance_to(Vector2(h.x,h.y))<=60.001,tag+": actual navigable rest target stays beside the shelter")
			check(w.rng.state==rng_before,tag+": roost choice leaves ecology RNG untouched")
			w.advance_live(180)
			check(not lead.has("relocated_at"),tag+": roost approach has no position relocation")
			w.state.light_hour=12
			w.advance_live(180)
			check(not lead.has("relocated_at"),tag+": dawn return has no position relocation")
			check(lead.y<=w.scene.band("green_chromis").y+.001,tag+": school returns to daylight water layer")
	print(JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
