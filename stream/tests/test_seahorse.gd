extends SceneTree
# S7 gates from the redesign plan: every horse spends >=80% of daylight hitched;
# night horses all hitch, contact points remain their actual homes, no shared hitch.
const Seeds=preload("res://tests/seed_lists.gd")
const NightFixture=preload("res://tests/seahorse_night_fixture.gd")
var checks: int=0
var failures: Array[String]=[]
var numbers: Dictionary={}
func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok: failures.append(message)
func _initialize() -> void:
	NightFixture.run(check)
	geometry_checks()
	var selected: Array=Seeds.motion()
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--seeds="): selected=Array(arg.trim_prefix("--seeds=").split(",")).map(func(s): return int(s))
	for scene_id: String in ReefScene.IDS:
		var trips: int=0
		for seed_value: int in selected:
			var w:=StreamWorld.new(seed_value,1000,scene_id)
			w.state.light_hour=12.0
			var horses: Array=w.state.animals.filter(func(a): return a.species=="seahorse")
			var held: Dictionary={}
			var last_home: Dictionary={}
			for a: Dictionary in horses: last_home[a.id]=StreamWorld._home_key(a.home)
			var contacts_ok: bool=true
			var homes_unique: bool=true
			for i in 9000:
				w.advance_live(.2)
				var keys: Array=[]
				for a: Dictionary in horses:
					if a.activity=="Hitched": held[a.id]=held.get(a.id,0)+1
					if a.has("hitch_x"):
						contacts_ok=contacts_ok and Vector2(a.hitch_x-a.home_x,a.hitch_y-a.home_y).length()<.001 and Vector2(a.x,a.y).distance_to(w._hitch_center(a))<=2.001 and a.y<a.home_y
					var key: String=StreamWorld._home_key(a.home)
					if key!=last_home[a.id]:
						trips+=1
						last_home[a.id]=key
					homes_unique=homes_unique and not key in keys
					keys.append(key)
			var tag: String=scene_id+"/"+str(seed_value)
			var shares: Array=horses.map(func(a): return float(held.get(a.id,0))/9000)
			check(shares.all(func(r): return r>=.8),tag+": daylight hitch >=80% "+str(shares))
			check(contacts_ok,tag+": tail contacts match home")
			check(homes_unique,tag+": each horse keeps its own hitch")
			w.state.light_hour=0.0
			w.advance_live(120)
			check(horses.all(func(a): return a.activity=="Hitched"),tag+": all horses hitch at night")
			numbers[tag]=shares
		var minutes_per_trip: float=float(selected.size()*2*30)/maxi(trips,1)
		check(trips>0 and minutes_per_trip<=8.0,scene_id+": daylight excursions average <=8min ("+str(minutes_per_trip)+")")
		numbers[scene_id+"/excursions"]={"trips":trips,"mean_minutes":minutes_per_trip}
	print(JSON.stringify({"checks":checks,"failures":failures,"numbers":numbers}))
	quit(0 if failures.is_empty() else 1)

func geometry_checks() -> void:
	for scene_id: String in ReefScene.IDS:
		var scene:=ReefScene.open(scene_id)
		var plant: Dictionary=scene.slots().filter(func(s): return s.required=="hitch")[0]
		for style: String in plant.styles:
			var w:=StreamWorld.new(42,1000,scene_id)
			while w.counts().seahorse<StreamWorld.CAP.seahorse: w.spawn("seahorse",90)
			w.set_decor(plant.id,style)
			w.state.ledger.initial=w.material()-w.state.ledger["in"]+w.state.ledger.out
			w.state.light_hour=0
			var horses: Array=w.state.animals.filter(func(a): return a.species=="seahorse")
			w.advance_live(30)
			check(horses.all(func(a): return a.has("hitch_x")),scene_id+"/"+style+": four horses reattach within 30 seconds")
			var overlap: float=0.0
			for i in horses.size():
				for j in range(i+1,horses.size()):
					var a: Dictionary=horses[i]
					var b: Dictionary=horses[j]
					var r: Vector2=(w._body(a)+w._body(b))*.5
					overlap=maxf(overlap,minf(1-absf(a.x-b.x)/r.x,1-absf(a.y-b.y)/r.y))
			check(overlap<=.2,scene_id+"/"+style+": full-cap bodies overlap <=20% ("+str(overlap)+")")
			var saved: Dictionary=w.export_state()
			check(StreamWorld.validate(saved),scene_id+"/"+style+": route state validates")
			var restored:=StreamWorld.new()
			check(restored.restore(saved),scene_id+"/"+style+": route state restores")
			w.advance_live(10)
			restored.advance_live(10)
			check(var_to_bytes(w.export_state())==var_to_bytes(restored.export_state()),scene_id+"/"+style+": continued route/hold deterministic")
