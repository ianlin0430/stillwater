extends SceneTree
const Seeds=preload("res://tests/seed_lists.gd")
var checks: int=0
var failures: Array[String]=[]
var numbers: Dictionary={}
func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok: failures.append(message)
func _initialize() -> void:
	var seeds: Array=Seeds.motion()
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--seeds="): seeds=Array(arg.trim_prefix("--seeds=").split(",")).map(func(s): return int(s))
	for scene_id: String in ReefScene.IDS:
		for preset: String in ["min","max"]:
			for seed_value: int in seeds:
				var w:=StreamWorld.new(seed_value,1000,scene_id)
				for slot: String in w.scene.preset(preset): w.set_decor(slot,w.scene.preset(preset)[slot])
				w.spawn("royal_gramma",90)
				w.state.ledger.initial=w.material()-w.state.ledger["in"]+w.state.ledger.out
				var fish: Array=w.state.animals.filter(func(a): return a.species=="royal_gramma")
				var tag: String=scene_id+"/"+preset+"/"+str(seed_value)
				check(w._homes.royal_gramma.size()>=StreamWorld.CAP.royal_gramma,tag+": homes fit species cap")
				check(preset!="min" or fish.all(func(a): return a.home.kind=="rock"),tag+": without decor all homes are rocks")
				w.state.light_hour=12
				w.advance_live(120)
				var farthest: float=0.0
				var unique: bool=true
				for i in 1500:
					w.advance_live(.2)
					var keys: Array=[]
					for a: Dictionary in fish:
						if a.activity=="Hovering": farthest=maxf(farthest,Vector2(a.x-a.home_x,a.y-a.home_y).length())
						var key: String=StreamWorld._home_key(a.home)
						unique=unique and not key in keys
						keys.append(key)
				check(farthest<=50.001,tag+": daytime hover <=50px ("+str(farthest)+")")
				check(unique,tag+": one gramma per home")
				w.state.light_hour=0
				w.advance_live(120)
				check(fish.all(func(a): return a.activity=="Sleeping"),tag+": all sleep at night")
				check(fish.all(func(a): return a.extend<=.001 if a.home.kind=="shelter" else a.extend==1.0),tag+": cave residents hide; rock residents remain visible")
				w.state.light_hour=12
				w.advance_live(60)
				for a: Dictionary in fish: w.startle(a.x,a.y)
				w.advance_live(2)
				check(fish.all(func(a): return a.activity=="Sheltering" and (a.extend<=.001 if a.home.kind=="shelter" else a.extend==1.0)),tag+": tap retreats without hiding at a nonexistent cave")
				numbers[tag]=farthest
	print(JSON.stringify({"checks":checks,"failures":failures,"numbers":numbers}))
	quit(0 if failures.is_empty() else 1)
