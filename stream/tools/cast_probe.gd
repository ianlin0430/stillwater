extends SceneTree
# Offline sizing probe: runs the real stream_world.gd with the cast constants
# (ACTIVE_SPECIES, CAP, SPECIES.initial, extra SPECIES entries) replaced from a JSON
# file, so caps and opening counts can be checked against the food pools before they
# are committed. Usage:
#   godot --headless --path . --script tools/cast_probe.gd -- --config=probe.json --seed=42 --days=180
# probe.json: {"name":"...","active":[...],"cap":{...},"initial":{...},"species":{key:{...}},"rescue_at":n}

func _initialize() -> void:
	var o: Dictionary={"config":"","seed":42,"days":180,"feed":"none"}
	for arg: String in OS.get_cmdline_user_args():
		var parts: PackedStringArray=arg.lstrip("-").split("=")
		if parts.size()==2:
			o[parts[0]]=parts[1]
	var cfg: Dictionary={}
	if o.config!="":
		cfg=JSON.parse_string(FileAccess.get_file_as_string(o.config))
	var world: RefCounted=_world(cfg).new(int(o.seed))
	print(JSON.stringify(run(world,int(o.days),cfg.get("name","current"),int(o.seed))))
	quit()

func _world(cfg: Dictionary) -> GDScript:
	if cfg.is_empty():
		return load("res://scripts/stream_world.gd")
	var lines: PackedStringArray=FileAccess.get_file_as_string("res://scripts/stream_world.gd").split("\n")
	var out: PackedStringArray=[]
	for line: String in lines:
		if line.begins_with("class_name"):
			continue
		if line.begins_with("const ACTIVE_SPECIES") and cfg.has("active"):
			line="const ACTIVE_SPECIES: Array[String] = "+JSON.stringify(cfg.active)
		elif line.begins_with("const CAP:") and cfg.has("cap"):
			line="const CAP: Dictionary = "+JSON.stringify(cfg.cap)
		elif line.contains("if c[species]<=2 and") and cfg.has("rescue_at"):
			line=line.replace("<=2","<="+str(int(cfg.rescue_at)))
		elif line.begins_with("const NAMES:") and cfg.has("active"):
			var names: Dictionary={}
			for k: String in cfg.active:
				names[k]=[]
			line="const NAMES: Dictionary = "+JSON.stringify(names)
		out.append(line)
		if line.begins_with("const SPECIES: Dictionary = {"):
			for k: String in cfg.get("species",{}):
				out.append("\t"+JSON.stringify(k)+": "+JSON.stringify(cfg.species[k])+",")
	var src: String="\n".join(out)
	for k: String in cfg.get("initial",{}):
		# SPECIES.initial of an existing entry, e.g. garden_eel.
		var rx:=RegEx.create_from_string('("'+k+'": \\{[^\\n]*?"initial":)\\d+')
		src=rx.sub(src,"${1}"+str(cfg.initial[k]))
	var script:=GDScript.new()
	script.source_code=src
	var err: Error=script.reload()
	if err!=OK:
		printerr("probe: patched world does not compile ",err)
		quit(1)
	return script

func run(world: RefCounted, days: int, name: String, seed_value: int) -> Dictionary:
	var start: int=Time.get_ticks_msec()
	var species_of: Dictionary={}
	var starve: Dictionary={}
	var old: Dictionary={}
	var births: Dictionary={}
	var disp: Dictionary={}
	var cursor: int=world.state.next_event-1
	var pools: Dictionary={"microfauna":[INF,0.0],"biofilm":[INF,0.0]}
	var sizes: Array=[]
	var first_old: int=-1
	var end_counts: Dictionary={}
	for day in days:
		for hour in 24:
			for a: Dictionary in world.state.animals:
				species_of[a.id]=a.species
			world.advance_offline(3600)
			for a: Dictionary in world.state.animals:
				species_of[a.id]=a.species
			for e: Dictionary in world.state.events:
				if e.get("seq",0)<=cursor:
					continue
				var sp: String=species_of.get(e.id,"?")
				match e.kind:
					"death":
						var bucket: Dictionary=starve if e.cause=="starvation" else old
						bucket[sp]=bucket.get(sp,0)+1
					"birth":
						births[sp]=births.get(sp,0)+1
					"dispersal":
						disp[sp]=disp.get(sp,0)+1
			cursor=world.state.next_event-1
			for p: String in pools:
				pools[p][0]=minf(pools[p][0],world.state.resources[p])
				pools[p][1]+=world.state.resources[p]/(24.0*days)
		sizes.append(world.state.animals.size())
		if first_old<0 and world.state.causes.get("old age",0)>0:
			first_old=day+1
	end_counts=world.counts()
	var t: Dictionary=world.state.totals
	return {"name":name,"seed":seed_value,"starvation":starve,"old_age":old,"births":births,"dispersal":disp,"arrivals":t.arrival,"first_old_age_day":first_old,"size_min":sizes.min(),"size_max":sizes.max(),"size_mean":sizes.reduce(func(a,b): return a+b)/float(sizes.size()),"sizes_by_day":sizes,"end":end_counts,"microfauna_min_mean":pools.microfauna,"biofilm_min_mean":pools.biofilm,"residual":world.residual(),"seconds":(Time.get_ticks_msec()-start)/1000.0}
