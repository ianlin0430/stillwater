extends SceneTree
# Scene data files (data/scenes/*.json, data/decor.json) and their loader scripts/reef_scene.gd
# (docs/plans/2026-09-28-redesign-backend.md §2, slice S1). The world reads them since S4.
const SCENES: Array[String] = ["reef","shipwreck"]
const SPECIES: Array[String] = ["green_chromis","clownfish","seahorse","royal_gramma"]
# Upper ends of the caps the S2 probe may choose (plan §4.2 coarse screen: clown 2–3,
# seahorse 2–4, gramma 2–3). Once StreamWorld.CAP holds a species, the larger of the two counts.
const PROBE_CAP_MAX: Dictionary = {"clownfish":3,"seahorse":4,"royal_gramma":3}
var checks: int=0
var failures: Array[String]=[]

func check(value: bool, message: String) -> void:
	checks+=1
	if not value:
		failures.append(message)
		printerr("FAIL: "+message)

func cap(species: String) -> int:
	return maxi(int(StreamWorld.CAP.get(species,0)),int(PROBE_CAP_MAX[species]))

func inside(p: Vector2, o: Dictionary) -> bool:
	var dx: float=(p.x-o.cx)/o.rx
	var dy: float=(p.y-o.cy)/o.ry
	return dx*dx+dy*dy<1.0

func in_band(scene: RefCounted, species: String, p: Vector2) -> bool:
	var b: Vector2=scene.band(species)
	return p.y>=b.x and p.y<=b.y and p.y<scene.floor_y(p.x)

# Every obstacle any combination can place, except the styles of `skip_slot` (a slot holds one style).
func obstacles(scene: RefCounted, skip_slot: String="") -> Array:
	var out: Array=scene.terrain_obstacles()
	for slot: Dictionary in scene.slots():
		if slot.id==skip_slot:
			continue
		for style: String in slot.styles:
			out.append_array(scene.effects(slot.id,style).obstacles)
	return out

func clear_of(p: Vector2, obs: Array) -> bool:
	for o: Dictionary in obs:
		if inside(p,o):
			return false
	return true

func _initialize() -> void:
	var RS: GDScript=load("res://scripts/reef_scene.gd")
	check(RS!=null,"scripts/reef_scene.gd loads")
	if RS==null:
		finish()
		return
	check(RS.ids()==SCENES,"ReefScene.ids() lists reef and shipwreck")
	var reef: RefCounted=RS.open("reef")
	check(reef!=null,"reef scene opens")
	if reef!=null:
		# Since S4 the world reads its terrain from the scene (the reef by default): the bed (static
		# floor_y for the frontend, bed_y of a world) and every species' depth band.
		var w:=StreamWorld.new(42,1000)
		var worst: float=0.0
		for i in 129:
			worst=maxf(worst,absf(reef.floor_y(i*10.0)-StreamWorld.floor_y(i*10.0))+absf(reef.floor_y(i*10.0)-w.bed_y(i*10.0)))
		check(w.state.scene=="reef" and worst==0.0,"A new world is in the reef scene and its bed is the reef bed")
		check(SPECIES.all(func(k: String) -> bool: return reef.band(k)==Vector2(w.band(k)[0],w.band(k)[1])),"The world's depth bands are the reef scene's")
		check(reef.bounds().surface_y==StreamWorld.FOOD.surface,"reef surface equals FOOD.surface")
	check(RS.open("nowhere")==null,"an unknown scene id opens nothing")
	for id: String in SCENES:
		scene_checks(RS,id)
	finish()

func scene_checks(RS: GDScript, id: String) -> void:
	var s: RefCounted=RS.open(id)
	check(s!=null,id+": opens")
	if s==null:
		return
	var errors: Array=s.validate()
	check(errors.is_empty(),id+": validate() is clean "+str(errors))
	check(s.id()==id,id+": id field matches the file")
	check(ResourceLoader.exists(s.background()),id+": background exists "+s.background())
	# Bed: strictly increasing x covering 0–1280.
	var bed: Array=s.bed()
	var increasing: bool=bed.size()>=2
	for i in range(1,bed.size()):
		increasing=increasing and bed[i].x>bed[i-1].x
	check(increasing and bed[0].x<=0.0 and bed[-1].x>=1280.0,id+": bed x strictly increases and covers 0–1280")
	for sp: String in SPECIES:
		var b: Vector2=s.band(sp)
		check(b.x>s.bounds().surface_y and b.x<b.y,id+": band of "+sp+" is below the surface and not empty")
	# Required slots: exactly one anemone, at least one hitch; every style really provides it.
	var anemones: int=0
	var hitches: int=0
	var slot_ids: Dictionary={}
	for slot: Dictionary in s.slots():
		check(not slot_ids.has(slot.id),id+": slot id "+slot.id+" is unique")
		slot_ids[slot.id]=true
		check(absf(slot.anchor.y-s.floor_y(slot.anchor.x))<=20.0,id+": slot "+slot.id+" anchor sits on the bed")
		if slot.required=="anemone":
			anemones+=1
			for style: String in slot.styles:
				var a: Dictionary=s.effects(slot.id,style).anemone
				check(not a.is_empty() and int(a.capacity)>=cap("clownfish"),id+": anemone "+style+" holds the clownfish cap %d" % cap("clownfish"))
		elif slot.required=="hitch":
			hitches+=1
			for style: String in slot.styles:
				check(s.effects(slot.id,style).hitches.size()>=cap("seahorse"),id+": hitch plant "+style+" has hitches for the seahorse cap %d" % cap("seahorse"))
	check(anemones==1,id+": exactly one required anemone slot")
	check(hitches>=1,id+": at least one required hitch slot")
	check(s.rock_spots().size()>=cap("royal_gramma"),id+": rock spots cover the royal gramma cap %d" % cap("royal_gramma"))
	# Every home point is in its species' band, above the bed and outside every obstacle of any combination.
	for slot: Dictionary in s.slots():
		var obs: Array=obstacles(s,slot.id)
		for style: String in slot.styles:
			var e: Dictionary=s.effects(slot.id,style)
			var own: Array=obs+e.obstacles
			var tag: String=id+": "+slot.id+"/"+style+" "
			if not e.anemone.is_empty():
				var c: Vector2=Vector2(e.anemone.cx,e.anemone.cy)
				check(in_band(s,"clownfish",c) and clear_of(c,own),tag+"anemone centre in clownfish band and clear of obstacles")
			for h: Vector2 in e.hitches:
				check(in_band(s,"seahorse",h) and clear_of(h,own),tag+"hitch %s in seahorse band and clear of obstacles" % h)
			for sh: Dictionary in e.shelters:
				var p: Vector2=Vector2(sh.x,sh.y)
				check(absi(int(sh.side))==1,tag+"shelter side is ±1")
				if sh.use.has("royal_gramma"):
					check(in_band(s,"royal_gramma",p) and clear_of(p,own),tag+"shelter %s in gramma band and clear of obstacles" % p)
				else:
					check(p.y<s.floor_y(p.x) and clear_of(p,own),tag+"shelter %s above bed and clear of obstacles" % p)
	var all_obs: Array=obstacles(s)
	for r: Vector2 in s.rock_spots():
		check(in_band(s,"royal_gramma",r) and clear_of(r,all_obs),id+": rock spot %s in gramma band and clear of every obstacle" % r)
	# Each band keeps a horizontal channel across roam_x that no combination can close.
	var roam: Array=s.bounds().roam_x
	for sp: String in SPECIES:
		var b: Vector2=s.band(sp)
		var open: bool=false
		var y: float=b.x
		while y<=b.y and not open:
			var clear: bool=true
			var x: float=roam[0]
			while x<=roam[1] and clear:
				clear=y<s.floor_y(x) and clear_of(Vector2(x,y),all_obs)
				x+=4.0
			open=clear
			y+=2.0
		check(open,id+": band of "+sp+" keeps an open horizontal channel with every obstacle placed")
	decor_api_checks(s,id)
	# Exits sit off screen, one each side.
	var ex: Array=s.exits()
	check(ex.size()>=2 and ex.any(func(p): return p.x<0.0) and ex.any(func(p): return p.x>1280.0),id+": exits on both sides, off screen")

# S5 query API (plan §3.2, §6.4): which styles a slot allows, the obstacles of a decor, and the
# named decor sets the tests and long runs use: "default", "min" (required slots only) and "max"
# (every slot filled with its style of the largest obstacle area).
func area(s: RefCounted, slot_id: String, style: String) -> float:
	var total: float=0.0
	for o: Dictionary in s.effects(slot_id,style).obstacles:
		total+=PI*o.rx*o.ry
	return total

func decor_api_checks(s: RefCounted, id: String) -> void:
	if not s.has_method("preset"):
		check(false,id+": ReefScene.preset, allows and obstacles exist (S5)")
		return
	check(s.preset("default")==s.default_decor(),id+": the default preset is the slots' defaults")
	var lo: Dictionary=s.preset("min")
	var hi: Dictionary=s.preset("max")
	for slot: Dictionary in s.slots():
		check(s.allows(slot.id,"")==(slot.required==""),id+": slot "+slot.id+" may be emptied only when not required")
		check(slot.styles.all(func(st): return s.allows(slot.id,st)) and not s.allows(slot.id,"no_such_style") and not s.allows("no_such_slot",slot.styles[0]),id+": slot "+slot.id+" allows exactly its styles")
		check(lo[slot.id]==(slot.default if slot.required!="" else ""),id+": min keeps "+slot.id+" only if required")
		var best: float=0.0
		for st: String in slot.styles:
			best=maxf(best,area(s,slot.id,st))
		check(s.allows(slot.id,hi[slot.id]) and hi[slot.id]!="" and area(s,slot.id,hi[slot.id])==best,id+": max fills "+slot.id+" with its largest obstacle ("+hi[slot.id]+")")
	check(lo.size()==s.slots().size() and hi.size()==s.slots().size() and s.preset("nothing").is_empty(),id+": presets name every slot; an unknown preset is empty")
	var want: Array=s.terrain_obstacles()
	for slot: Dictionary in s.slots():
		want.append_array(s.effects(slot.id,hi[slot.id]).obstacles)
	check(s.obstacles(hi)==want and s.obstacles(lo)==s.terrain_obstacles(),id+": obstacles() is the terrain plus each slot's decor")

func finish() -> void:
	print(JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
