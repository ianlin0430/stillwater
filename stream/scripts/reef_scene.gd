class_name ReefScene
extends RefCounted
# One scene's terrain, slots and decor effects, read from data/scenes/<id>.json and
# data/decor.json (docs/plans/2026-09-28-redesign-backend.md §2). Pure data: no drawing, no RNG.
# World coordinates are 1280x720, the same as the snapshot. Decor effects in decor.json are
# relative to the slot anchor; effects() returns them in world coordinates.
# Backend and frontend both read scenes through this class rather than parsing the files.

const SCENE_DIR: String = "res://data/scenes/"
const DECOR_PATH: String = "res://data/decor.json"
const IDS: Array[String] = ["reef","shipwreck"]
const KINDS: Array[String] = ["anemone","hitch","shelter","obstacle"]
const REQUIRED: Array[String] = ["anemone","hitch"]

var data: Dictionary = {}
var decor: Dictionary = {}

static func ids() -> Array[String]:
	return IDS

# The scene with this id, or null for an unknown id or a file that does not parse.
static func open(scene_id: String) -> ReefScene:
	if not IDS.has(scene_id):
		return null
	var scene_data: Variant=_read(SCENE_DIR+scene_id+".json")
	var decor_data: Variant=_read(DECOR_PATH)
	if not scene_data is Dictionary or not decor_data is Dictionary:
		return null
	var s:=ReefScene.new()
	s.data=scene_data
	s.decor=decor_data
	return s

static func _read(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	return JSON.parse_string(FileAccess.get_file_as_string(path))

func id() -> String:
	return data.get("id","")

func background() -> String:
	return data.get("background","")

# {"swim_x":[lo,hi],"roam_x":[lo,hi],"feed_x":[lo,hi],"surface_y":y}
func bounds() -> Dictionary:
	return data.get("bounds",{})

func bed() -> Array[Vector2]:
	var out: Array[Vector2]=[]
	for p: Array in data.get("bed",[]):
		out.append(Vector2(p[0],p[1]))
	return out

# Bed height at x: the bed polyline, linearly interpolated, held flat past its ends.
func floor_y(x: float) -> float:
	var points: Array=data.bed
	if x<=points[0][0]:
		return points[0][1]
	for i in range(1,points.size()):
		if x<=points[i][0]:
			var a: Array=points[i-1]
			var b: Array=points[i]
			return lerpf(a[1],b[1],(x-a[0])/(b[0]-a[0]))
	return points[-1][1]

# Depth band of a species as Vector2(top, bottom); Vector2.ZERO if the scene has none.
func band(species: String) -> Vector2:
	var b: Array=data.get("bands",{}).get(species,[])
	return Vector2(b[0],b[1]) if b.size()==2 else Vector2.ZERO

func exits() -> Array[Vector2]:
	var out: Array[Vector2]=[]
	for p: Array in data.get("exits",[]):
		out.append(Vector2(p[0],p[1]))
	return out

func terrain_obstacles() -> Array:
	return data.get("terrain_obstacles",[]).duplicate(true)

# Royal gramma fallback homes when no cave is free; {"x","y","side"} each.
func rock_spots() -> Array[Vector2]:
	var out: Array[Vector2]=[]
	for p: Dictionary in data.get("rock_spots",[]):
		out.append(Vector2(p.x,p.y))
	return out

# Slots with anchors as Vector2: {"id","anchor","required","styles","default"}.
func slots() -> Array[Dictionary]:
	var out: Array[Dictionary]=[]
	for slot: Dictionary in data.get("slots",[]):
		var s: Dictionary=slot.duplicate(true)
		s.anchor=Vector2(slot.anchor[0],slot.anchor[1])
		s.required=slot.required if slot.required is String else ""
		out.append(s)
	return out

func slot(slot_id: String) -> Dictionary:
	for s: Dictionary in slots():
		if s.id==slot_id:
			return s
	return {}

# The effects of `style` placed in `slot_id`, in world coordinates. An empty style ("") or
# an unknown slot/style gives no effects. Keys: kind, obstacles [{cx,cy,rx,ry}],
# anemone {cx,cy,rx,ry,capacity} or {}, hitches [Vector2], shelters [{x,y,side,use}], fade_spots [Vector2].
func effects(slot_id: String, style: String) -> Dictionary:
	var out: Dictionary={"kind":"","obstacles":[],"anemone":{},"hitches":[],"shelters":[],"fade_spots":[]}
	var s: Dictionary=slot(slot_id)
	if s.is_empty() or style=="" or not decor.has(style):
		return out
	var at: Vector2=s.anchor
	var d: Dictionary=decor[style]
	out.kind=d.get("kind","")
	for o: Dictionary in d.get("obstacles",[]):
		out.obstacles.append({"cx":at.x+o.cx,"cy":at.y+o.cy,"rx":o.rx,"ry":o.ry})
	var a: Dictionary=d.get("anemone",{})
	if not a.is_empty():
		out.anemone={"cx":at.x+a.cx,"cy":at.y+a.cy,"rx":a.rx,"ry":a.ry,"capacity":int(a.capacity)}
	for h: Array in d.get("hitches",[]):
		out.hitches.append(at+Vector2(h[0],h[1]))
	for sh: Dictionary in d.get("shelters",[]):
		out.shelters.append({"x":at.x+sh.x,"y":at.y+sh.y,"side":int(sh.side),"use":sh.get("use",[]).duplicate()})
	for f: Array in d.get("fade_spots",[]):
		out.fade_spots.append(at+Vector2(f[0],f[1]))
	return out

# Default style of every slot: {slot_id: style or ""}.
func default_decor() -> Dictionary:
	var out: Dictionary={}
	for s: Dictionary in slots():
		out[s.id]=s.default
	return out

# True when `style` may go in `slot_id`: one of the slot's styles, or "" (empty) for a slot that is
# not required. The anemone and the hitch plant change style but are never cleared (S5).
func allows(slot_id: String, style: String) -> bool:
	var s: Dictionary=slot(slot_id)
	if s.is_empty():
		return false
	return s.styles.has(style) if style!="" else s.required==""

# True when `decor` names exactly this scene's slots, each with a style it allows.
func valid_decor(decor: Variant) -> bool:
	if not decor is Dictionary or decor.size()!=data.get("slots",[]).size():
		return false
	for s: Dictionary in slots():
		if not decor.get(s.id) is String or not allows(s.id,decor[s.id]):
			return false
	return true

# Every obstacle with this decor ({slot_id: style}), world coordinates: the terrain's, then each
# slot's in scene order.
func obstacles(decor: Dictionary) -> Array:
	var out: Array=terrain_obstacles()
	for s: Dictionary in slots():
		out.append_array(effects(s.id,decor.get(s.id,"")).obstacles)
	return out

# A named decor, {slot_id: style or ""}: "default" (each slot's default), "min" (the required
# slots at their default, the others empty) or "max" (every slot holding its style of the largest
# obstacle area, the earlier listed on a tie; a required slot whose styles have none keeps its
# default). The extremes going around obstacles is tested on (plan §6.4). {} for another name.
func preset(name: String) -> Dictionary:
	var out: Dictionary={}
	for s: Dictionary in slots():
		match name:
			"default":
				out[s.id]=s.default
			"min":
				out[s.id]=s.default if s.required!="" else ""
			"max":
				var best: String=s.default
				var most: float=-1.0
				for style: String in s.styles:
					var area: float=0.0
					for o: Dictionary in effects(s.id,style).obstacles:
						area+=PI*o.rx*o.ry
					if area>most and (area>0.0 or s.required==""):
						best=style
						most=area
				out[s.id]=best
			_:
				return {}
	return out

# Structure errors (empty when the scene and the decor it uses are well formed).
# Geometry against the species caps is checked by tests/test_scene_data.gd.
func validate() -> Array[String]:
	var e: Array[String]=[]
	for key: String in ["id","version","background","bounds","bed","bands","exits","terrain_obstacles","rock_spots","slots"]:
		if not data.has(key):
			e.append("missing "+key)
	if not e.is_empty():
		return e
	if not data.id is String or not IDS.has(data.id):
		e.append("id")
	if not _num(data.version):
		e.append("version")
	var b: Variant=data.bounds
	if not b is Dictionary or not _pair(b.get("swim_x")) or not _pair(b.get("roam_x")) or not _pair(b.get("feed_x")) or not _num(b.get("surface_y")):
		e.append("bounds")
	if not data.bed is Array or data.bed.size()<2 or not data.bed.all(func(p): return _pair(p)):
		e.append("bed")
	if not data.bands is Dictionary or not data.bands.values().all(func(p): return _pair(p)):
		e.append("bands")
	if not data.exits is Array or not data.exits.all(func(p): return _pair(p)):
		e.append("exits")
	if not data.terrain_obstacles is Array or not data.terrain_obstacles.all(func(o): return _ellipse(o)):
		e.append("terrain_obstacles")
	if not data.rock_spots is Array or not data.rock_spots.all(func(p): return p is Dictionary and _num(p.get("x")) and _num(p.get("y")) and _num(p.get("side"))):
		e.append("rock_spots")
	if not data.slots is Array:
		e.append("slots")
		return e
	for s: Variant in data.slots:
		if not s is Dictionary or not s.get("id") is String or not _pair(s.get("anchor")) or not s.get("styles") is Array or s.styles.is_empty() or not s.get("default") is String:
			e.append("slot shape "+str(s))
			continue
		var req: Variant=s.get("required")
		if req!=null and not (req is String and REQUIRED.has(req)):
			e.append("slot %s required" % s.id)
		if s.default!="" and not s.styles.has(s.default):
			e.append("slot %s default not in styles" % s.id)
		if req!=null and s.default=="":
			e.append("required slot %s cannot default to empty" % s.id)
		for style: Variant in s.styles:
			if not style is String or not decor.has(style):
				e.append("slot %s unknown style %s" % [s.id,style])
				continue
			e.append_array(_decor_errors(style))
			if req!=null and decor[style].get("kind")!=req:
				e.append("slot %s style %s is not a %s" % [s.id,style,req])
	return e

func _decor_errors(style: String) -> Array[String]:
	var e: Array[String]=[]
	var d: Variant=decor[style]
	if not d is Dictionary or not KINDS.has(d.get("kind")):
		return ["decor %s kind" % style]
	if not d.get("obstacles",[]).all(func(o): return _ellipse(o)):
		e.append("decor %s obstacles" % style)
	var a: Variant=d.get("anemone",{})
	if not a is Dictionary or (not a.is_empty() and not (_ellipse(a) and _num(a.get("capacity")))):
		e.append("decor %s anemone" % style)
	if d.kind=="anemone" and a.is_empty():
		e.append("decor %s is an anemone without one" % style)
	if not d.get("hitches",[]).all(func(p): return _pair(p)):
		e.append("decor %s hitches" % style)
	if d.kind=="hitch" and d.get("hitches",[]).is_empty():
		e.append("decor %s is a hitch without hitches" % style)
	if not d.get("shelters",[]).all(func(p): return p is Dictionary and _num(p.get("x")) and _num(p.get("y")) and _num(p.get("side")) and p.get("use") is Array):
		e.append("decor %s shelters" % style)
	if not d.get("fade_spots",[]).all(func(p): return _pair(p)):
		e.append("decor %s fade_spots" % style)
	return e

static func _num(v: Variant) -> bool:
	return (v is float or v is int) and is_finite(float(v))

static func _pair(v: Variant) -> bool:
	return v is Array and v.size()==2 and _num(v[0]) and _num(v[1])

static func _ellipse(o: Variant) -> bool:
	return o is Dictionary and _num(o.get("cx")) and _num(o.get("cy")) and _num(o.get("rx")) and _num(o.get("ry")) and o.rx>0 and o.ry>0
