extends SceneTree
# Scene data files (data/scenes/*.json, data/decor.json) and their loader scripts/reef_scene.gd
# (docs/plans/2026-09-28-redesign-backend.md §2, slice S1). The world does not read them yet.
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
		# The first reef bed samples today's StreamWorld.floor_y, so nothing moves when the world switches to it.
		var worst: float=0.0
		for i in 129:
			worst=maxf(worst,absf(reef.floor_y(i*10.0)-StreamWorld.floor_y(i*10.0)))
		check(worst<1.0,"reef floor_y within 1 px of StreamWorld.floor_y every 10 px (worst %.3f)" % worst)
		check(reef.band("green_chromis")==Vector2(StreamWorld.DEPTH.green_chromis[0],StreamWorld.DEPTH.green_chromis[1]),"reef chromis band equals today's DEPTH")
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
	# Exits sit off screen, one each side.
	var ex: Array=s.exits()
	check(ex.size()>=2 and ex.any(func(p): return p.x<0.0) and ex.any(func(p): return p.x>1280.0),id+": exits on both sides, off screen")

func finish() -> void:
	print(JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
