extends SceneTree
# Offline sizing probe: runs the real stream_world.gd with the cast constants
# (ACTIVE_SPECIES, CAP, SPECIES.initial, extra SPECIES entries) replaced from a JSON
# file, so caps and opening counts can be checked against the food pools before they
# are committed. Usage:
#   godot --headless --path . --script tools/cast_probe.gd -- --config=probe.json --seed=42 --days=180
# probe.json: {"name":"...","active":[...],"cap":{...},"initial":{...},"species":{key:{...}},"rescue_at":n,
#   "stream_in":{pool:rate,...},"opening_age":{"fish":[lo,hi],species:[lo,hi],...}}
# stream_in and opening_age replace the whole constant, so give every key the world reads.
# "floor":f (S2, 2026-09-28) instruments the world, changing nothing it does: it counts the
# animal-minutes in which energy ends a minute below f x reserve or metabolism went unpaid
# (floor_hits; since S4 the world has its own never-starve floor, StreamWorld.FLOOR) and the
# lowest energy/reserve per species (min_energy). --seeds=a,b,c runs several seeds in one process, one
# JSON line each; --mid=D adds the same measures taken after day D ("at_D").
# "scene":id and "decor":"default|min|max" (S5, 2026-09-29) start the world in that scene with that
# named decor (ReefScene.preset), to show the ecology does not depend on them.

func _initialize() -> void:
	var o: Dictionary={"config":"","seed":42,"seeds":"","days":180,"feed":"none","mid":0}
	for arg: String in OS.get_cmdline_user_args():
		var parts: PackedStringArray=arg.lstrip("-").split("=")
		if parts.size()==2:
			o[parts[0]]=parts[1]
	var cfg: Dictionary={}
	if o.config!="":
		cfg=JSON.parse_string(FileAccess.get_file_as_string(o.config))
	var world_script: GDScript=_world(cfg)
	var seeds: Array=[int(o.seed)] if o.seeds=="" else Array(o.seeds.split(",")).map(func(x): return int(x))
	for seed_value: int in seeds:
		var world: RefCounted=world_script.new(seed_value,0,cfg.get("scene","reef"))
		var decor: Dictionary=world.scene.preset(cfg.get("decor","default"))
		for slot: String in decor:
			world.set_decor(slot,decor[slot])
		print(JSON.stringify(run(world,int(o.days),cfg.get("name","current"),seed_value,int(o.mid))))
	quit()

func _world(cfg: Dictionary) -> GDScript:
	if cfg.is_empty():
		return load("res://scripts/stream_world.gd")
	var src: String=patched_source(cfg)
	var script: GDScript=null if src=="" else compile(src)
	if script==null:
		printerr("probe: patched world does not compile")
		quit(1)
	return script

# The world source with the cast constants replaced from cfg (static so tests can check it).
static func patched_source(cfg: Dictionary) -> String:
	var lines: PackedStringArray=FileAccess.get_file_as_string("res://scripts/stream_world.gd").split("\n")
	var out: PackedStringArray=[]
	for line: String in lines:
		if line.begins_with("class_name"):
			continue
		if line.begins_with("const ACTIVE_SPECIES") and cfg.has("active"):
			line="const ACTIVE_SPECIES: Array[String] = "+JSON.stringify(cfg.active)
		elif line.begins_with("const CAP:") and cfg.has("cap"):
			line="const CAP: Dictionary = "+JSON.stringify(cfg.cap)
		elif line.begins_with("const RESCUE_AT:") and cfg.has("rescue_at"):
			# Was a replace on "if c[species]<=2 and", which stopped matching once the rule became
			# the RESCUE_AT constant: the option silently did nothing until 2026-09-28 (S0).
			line="const RESCUE_AT: int = "+str(int(cfg.rescue_at))
		elif line.begins_with("const STREAM_IN:") and cfg.has("stream_in"):
			line="const STREAM_IN: Dictionary = "+JSON.stringify(cfg.stream_in)
		elif line.begins_with("const OPENING_AGE:") and cfg.has("opening_age"):
			line="const OPENING_AGE: Dictionary = "+JSON.stringify(cfg.opening_age)
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
	if cfg.has("floor"):
		src=_instrument(src,float(cfg.floor))
	for k: String in cfg.get("initial",{}):
		# SPECIES.initial of an existing entry, e.g. garden_eel.
		var rx:=RegEx.create_from_string('("'+k+'": \\{[^\\n]*?"initial":)\\d+')
		src=rx.sub(src,"${1}"+str(cfg.initial[k]))
	return src

# Measurement only: two probe variables and one counting line after the minute's metabolism,
# intake and growth (S4: after the hunger line; the world pays metabolism only down to its floor
# and `unpaid` is what it could not pay). Returns "" (so compile fails loudly) if the world
# source no longer has the anchors.
static func _instrument(src: String, floor_share: float) -> String:
	var state_line: String="var state: Dictionary\n"
	var check_line: String="\t\ta.hunger=clampf(1-a.energy/cfg.reserve,0,1)\n"
	if src.count(state_line)!=1 or src.count(check_line)!=1 or not src.contains("var unpaid: float"):
		printerr("probe: floor instrumentation anchors not found in stream_world.gd")
		return ""
	src=src.replace(state_line,state_line+"var probe_floor_hits: Dictionary = {}\nvar probe_min_energy: Dictionary = {}\n")
	var count: String="\t\tvar probe_left: float = a.energy/cfg.reserve\n"
	count+="\t\tprobe_min_energy[a.species]=minf(probe_min_energy.get(a.species,INF),probe_left)\n"
	count+="\t\tif probe_left<"+str(floor_share)+" or unpaid>0.0:\n"
	count+="\t\t\tprobe_floor_hits[a.species]=probe_floor_hits.get(a.species,0)+1\n"
	return src.replace(check_line,check_line+count)

static func compile(src: String) -> GDScript:
	var script:=GDScript.new()
	script.source_code=src
	if script.reload()!=OK:
		return null
	return script

static func run(world: RefCounted, days: int, name: String, seed_value: int, mid: int = 0) -> Dictionary:
	var start: int=Time.get_ticks_msec()
	var species_of: Dictionary={}
	var starve: Dictionary={}
	var old: Dictionary={}
	var births: Dictionary={}
	var disp: Dictionary={}
	var cursor: int=world.state.next_event-1
	var pools: Dictionary={"microfauna":[INF,0.0],"biofilm":[INF,0.0]}
	var sizes: Array=[]
	var daily: Array=[]
	var first_old: int=-1
	var result: Dictionary={}
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
				pools[p][1]+=world.state.resources[p]
		sizes.append(world.state.animals.size())
		daily.append(world.counts())
		if first_old<0 and world.state.causes.get("old age",0)>0:
			first_old=day+1
		if mid>0 and day+1==mid and mid<days:
			result["at_"+str(mid)]=_summary(world,name,seed_value,starve,old,births,disp,first_old,sizes,daily,pools)
	result.merge(_summary(world,name,seed_value,starve,old,births,disp,first_old,sizes,daily,pools))
	result.seconds=(Time.get_ticks_msec()-start)/1000.0
	return result

static func _summary(world: RefCounted, name: String, seed_value: int, starve: Dictionary, old: Dictionary, births: Dictionary, disp: Dictionary, first_old: int, sizes: Array, daily: Array, pools: Dictionary) -> Dictionary:
	var hours: float=24.0*sizes.size()
	var t: Dictionary=world.state.totals
	# Per species: fewest alive at a daily sample, days absent, longest run of absent days.
	var presence: Dictionary={}
	for sp: String in daily[-1]:
		var low: int=1<<30
		var absent: int=0
		var run_len: int=0
		var longest: int=0
		for c: Dictionary in daily:
			low=mini(low,int(c.get(sp,0)))
			if int(c.get(sp,0))==0:
				absent+=1
				run_len+=1
				longest=maxi(longest,run_len)
			else:
				run_len=0
		presence[sp]={"min":low,"absent_days":absent,"longest_absence":longest}
	var out: Dictionary={"name":name,"seed":seed_value,"days":sizes.size(),"starvation":starve.duplicate(),"old_age":old.duplicate(),"births":births.duplicate(),"dispersal":disp.duplicate(),"arrivals":t.arrival,"first_old_age_day":first_old,"size_min":sizes.min(),"size_max":sizes.max(),"size_mean":sizes.reduce(func(a,b): return a+b)/float(sizes.size()),"sizes_by_day":sizes.duplicate(),"end":world.counts(),"presence":presence,"microfauna_min_mean":[pools.microfauna[0],pools.microfauna[1]/hours],"biofilm_min_mean":[pools.biofilm[0],pools.biofilm[1]/hours],"residual":world.residual()}
	if "probe_floor_hits" in world:
		out.floor_hits=world.probe_floor_hits.duplicate()
		out.min_energy=world.probe_min_energy.duplicate()
	return out
