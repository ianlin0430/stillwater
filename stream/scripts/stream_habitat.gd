class_name StreamHabitat
extends Node2D
# Read-only frontend. All coordinates are 1280x720 world coordinates.
# No StreamWorld methods, ecological RNG, save writes, or biological side effects.
const ROOTS: Array[Vector2]=[Vector2(70,620),Vector2(115,612),Vector2(175,614),Vector2(1090,615),Vector2(1150,610),Vector2(1200,620)]
var clock: float=0
var redraw_clock: float=0
var touch_clock: float=-10
var impulses: Array[Dictionary]=[]
var bends: Array[float]=[]
var brush: Vector2=Vector2(-999,-999)
var brush_strength: float=0
var resources: Dictionary={"stem":45.0,"floating":24.0,"biofilm":32.0,"microfauna":24.0,"detritus":8.0}
var desired_resources: Dictionary=resources.duplicate()
var animals: Array=[]
var previous: Dictionary={}
var wake_clock: Dictionary={}
var needs_initial_resources: bool=true
var snapshot_elapsed: float=-INF

func _ready() -> void:
	for i in ROOTS.size(): bends.append(0.0)

func apply_snapshot(value: Dictionary) -> void:
	animals=value.get("animals",[]).filter(func(a: Dictionary)->bool: return a.species in StreamStage.PRESENTED_SPECIES).duplicate(true)
	var at: float=value.get("elapsed",0.0)
	var discontinuity: bool=at<snapshot_elapsed or at-snapshot_elapsed>0.3
	for a: Dictionary in animals:
		if discontinuity or float(a.get("relocated_at",-1))>snapshot_elapsed:
			previous[a.id]=Vector2(a.x,a.y)
			wake_clock[a.id]=clock
	snapshot_elapsed=at
	var incoming: Dictionary=value.get("resources",{})
	for key: String in resources:
		if incoming.has(key) and (incoming[key] is float or incoming[key] is int) and is_finite(float(incoming[key])):
			desired_resources[key]=maxf(0,float(incoming[key]))
	if needs_initial_resources:
		resources=desired_resources.duplicate()
		needs_initial_resources=false
	var present: Dictionary={}
	for a: Dictionary in animals: present[a.id]=true
	for id: Variant in previous.keys():
		if not present.has(id):
			previous.erase(id)
			wake_clock.erase(id)

func touch(point: Vector2, strength: float=1.0) -> void:
	brush=point
	brush_strength=clampf(strength,0.0,1.0)
	if clock-touch_clock<0.12: return
	touch_clock=clock
	_add_impulse(Vector2(point.x,52) if point.y<100 else point,Vector2.ZERO,"surface" if point.y<100 else "water",1.0)

func _add_impulse(point: Vector2, velocity: Vector2, kind: String, strength: float) -> void:
	if impulses.size()>=24: impulses.pop_front()
	impulses.append({"point":point,"velocity":velocity,"kind":kind,"age":0.0,"strength":strength})

func describe(point: Vector2) -> String:
	if point.y<110: return "Drifting algae · drag to ripple the surface"
	for i in ROOTS.size():
		if point.distance_to(ROOTS[i]-Vector2(0,_height(i)*0.5))<65:
			return "Seagrass · brush past to bend the blades"
	if point.y>555: return "Sand and algae · reef floor"
	return "Drag through the water · click a creature to inspect"

func _height(i: int) -> float:
	return (65.0+float((i*37)%70)+(90.0 if i in [0,7] else 40.0 if i in [1,6] else 0.0))*clampf(sqrt(resources.stem/45.0),0.25,1.35)

func advance(delta: float) -> void:
	if delta<=0: return
	clock+=delta
	for key: String in resources:
		resources[key]=lerpf(resources[key],desired_resources[key],1.0-exp(-delta*1.8))
	brush_strength=maxf(0,brush_strength-delta*0.7)
	for i in ROOTS.size():
		var target: float=sin(clock*0.65+i*1.7)*3.0
		var mid: Vector2=ROOTS[i]-Vector2(0,_height(i)*0.5)
		if brush.distance_to(mid)<110:
			target+=clampf((brush.x-mid.x)*0.65,-38,38)*brush_strength
		for a: Dictionary in animals:
			var p:=Vector2(a.x,a.y)
			var distance: float=p.distance_to(mid)
			if distance<95:
				target+=float(a.get("vx",0.0))*0.65*(1.0-distance/95.0)
		bends[i]=lerpf(bends[i],clampf(target,-44,44),1.0-exp(-delta*3.5))
	for a: Dictionary in animals:
		var p:=Vector2(a.x,a.y)
		var v:=Vector2(a.get("vx",0.0),a.get("vy",0.0))
		if previous.has(a.id) and clock-float(wake_clock.get(a.id,-10.0))>0.7:
			if v.length()>7 and p.distance_to(previous[a.id])<80:
				_add_impulse(p-v.normalized()*22,v,"wake",clampf(v.length()/25,0.2,0.7))
				wake_clock[a.id]=clock
		previous[a.id]=p
	for impulse: Dictionary in impulses: impulse.age+=delta
	impulses=impulses.filter(func(v: Dictionary) -> bool: return v.age<2.1)
	redraw_clock+=delta
	if redraw_clock>=1.0/15.0:
		redraw_clock=0
		queue_redraw()

func _draw() -> void:
	if bends.size()!=ROOTS.size(): return
	for i in ROOTS.size(): _plant(i)
	# Independent patches expose resource changes without replacing the painted distance.
	var moss_count: int=int(clampf(resources.biofilm/2.0,0,28))
	for i in moss_count:
		var x: float=(105 if i%2==0 else 1000)+float((i*59)%160)
		var y: float=(400 if i%2==0 else 550)+float((i*17)%65)
		draw_rect(Rect2(x,y,7+i%4*2,3+i%3*2),Color("7e8e45") if i%3 else Color("a0a45a"))
	for i in int(clampf(resources.detritus,0,18)):
		var p:=Vector2(165+float((i*137)%960),645+float((i*13)%29))
		for impulse: Dictionary in impulses:
			var distance: float=p.distance_to(impulse.point)
			if impulse.kind=="water" and distance<100:
				p+=Vector2(sin(impulse.age*4+i)*10,-sin(minf(impulse.age/2.1,1)*PI)*8)*(1-distance/100)*(1-impulse.age/2.1)
		draw_rect(Rect2(p,Vector2(3+i%3,2)),Color("96876b"))
	for i in int(clampf(resources.floating/2.0,0,18)):
		var p:=Vector2(100+float((i*151)%1070),49+sin(clock*0.6+i)*2)
		for impulse: Dictionary in impulses:
			if impulse.kind=="surface":
				p.y+=sin(impulse.age*9-absf(p.x-impulse.point.x)*0.025)*exp(-impulse.age*2)*maxf(0,1-absf(p.x-impulse.point.x)/260)*7
		var strand:=PackedVector2Array()
		for j in 7:
			strand.append(p+Vector2(j*3-9,sin(j*0.8+clock*0.6+i)*2+j*0.35))
		draw_polyline(strand,Color(0.50,0.57,0.35,0.55),2,false)
	for impulse: Dictionary in impulses: _ripple(impulse)

func _plant(i: int) -> void:
	var root: Vector2=ROOTS[i]
	var height: float=_height(i)*0.75
	for blade in 4:
		var points:=PackedVector2Array()
		var lean: float=(blade-1.5)*10+bends[i]
		for j in 9:
			var t: float=j/8.0
			points.append((root+Vector2(lean*t*t-2*(1-t),-height*t*(0.65+blade*0.10))))
		for j in range(7,-1,-1):
			var t: float=j/8.0
			points.append((root+Vector2(lean*t*t+2*(1-t),-height*t*(0.65+blade*0.10))))
		draw_colored_polygon(points,Color("668665") if blade%2 else Color("849a70"))

func _ripple(v: Dictionary) -> void:
	var t: float=v.age
	var opacity: float=(1-t/2.1)*float(v.strength)
	var p: Vector2=v.point
	if v.kind=="graze":
		for i in 3:
			draw_rect(Rect2(p+Vector2(sin(i*2+t)*5,-t*7-i*2),Vector2(2,2)),Color(0.68,0.68,0.43,opacity*0.5))
		return
	if v.kind=="wake":
		p-=Vector2(v.velocity)*t*0.2
		var normal: Vector2=Vector2(v.velocity).normalized().orthogonal()
		draw_line(p-normal*(3+t*8),p+normal*(3+t*8),Color(0.65,0.79,0.69,opacity*0.18),1.5)
		return
	var line:=PackedVector2Array()
	var radius: float=8+t*48
	for i in 33:
		var angle: float=TAU*float(i)/32
		line.append((p+Vector2(cos(angle)*radius,sin(angle)*radius*(0.18 if v.kind=="surface" else 0.42))).snapped(Vector2(2,2)))
	draw_polyline(line,Color(0.72,0.86,0.77,opacity*0.42),2,false)
