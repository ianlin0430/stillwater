extends Node2D
# Read-only food and input feedback. Coordinates come from the backend snapshot.
const MAX_FOOD: int=40
const MAX_RINGS: int=12
const FEED_RECT:=Rect2(24,18,104,38)
const TAP_RECT:=Rect2(140,18,104,38)
var food: Array[Dictionary]=[]
var rings: Array[Dictionary]=[]
var elapsed: float=0
var last_activities: Dictionary={}
var hud: Node2D
var hud_clock: float=0
var full_until: float=-1
var hovered: String=""
var normal_style: StyleBoxFlat
var hover_style: StyleBoxFlat

func _ready() -> void:
	normal_style=_panel(Color(0.06,0.16,0.18,0.64))
	hover_style=_panel(Color(0.06,0.16,0.18,0.82))
	hud=Node2D.new()
	hud.z_index=20
	hud.draw.connect(_draw_hud)
	add_child(hud)

func apply_snapshot(value: Dictionary, reset: bool=false) -> void:
	elapsed=float(value.get("elapsed",0))
	food.clear()
	for pellet: Dictionary in value.get("food",[]):
		if food.size()>=MAX_FOOD: break
		if not is_finite(float(pellet.get("x",NAN))) or not is_finite(float(pellet.get("y",NAN))): continue
		food.append(pellet.duplicate(true))
	if reset:
		rings.clear()
		last_activities.clear()
	var current: Dictionary={}
	var startled: bool=false
	for a: Dictionary in value.get("animals",[]):
		current[a.id]=a.activity
		if not reset and a.activity=="Startled" and last_activities.get(a.id,"")!="Startled" and not startled:
			pulse(Vector2(a.x,a.y),"tap")
			startled=true
	last_activities=current
	queue_redraw()

func accept(event: Dictionary) -> void:
	if event.get("live",false) and event.kind=="fed":
		pulse(Vector2(event.get("x",640),event.get("y",56)),"food")

func pulse(at: Vector2, kind: String) -> void:
	if rings.size()>=MAX_RINGS: rings.pop_front()
	rings.append({"at":at,"kind":kind,"age":0.0})
	queue_redraw()

func advance(delta: float, camera: Transform2D) -> void:
	# Cancel only the scene camera; the viewport's pixel scale remains in effect.
	if hud!=null: hud.transform=camera.affine_inverse()
	if delta<=0: return
	var full_was_visible: bool=hud_clock<full_until
	hud_clock+=delta
	var had_rings: bool=not rings.is_empty()
	for ring: Dictionary in rings: ring.age+=delta
	rings=rings.filter(func(r: Dictionary)->bool: return r.age<0.8)
	if had_rings: queue_redraw()
	if hud!=null and full_was_visible!=(hud_clock<full_until): hud.queue_redraw()

static func action_at(point: Vector2) -> String:
	if FEED_RECT.has_point(point): return "feed"
	if TAP_RECT.has_point(point): return "tap"
	return ""

func show_full() -> void:
	full_until=hud_clock+3
	if hud!=null: hud.queue_redraw()

func set_hover(point: Vector2) -> void:
	var next: String=action_at(point)
	if next!=hovered:
		hovered=next
		if hud!=null: hud.queue_redraw()

func _draw() -> void:
	for pellet: Dictionary in food:
		var age: float=maxf(0,elapsed-float(pellet.get("settled_at",elapsed))) if pellet.get("settled",false) else 0.0
		var tint:=Color("d9b980").lerp(Color("736b57"),clampf(age/900.0,0,1))
		var at:=Vector2(pellet.x,pellet.y)
		draw_rect(Rect2(at-Vector2(2,2),Vector2(4,4)),Color("514a39"))
		draw_rect(Rect2(at-Vector2.ONE,Vector2(2,2)),tint)
	for ring: Dictionary in rings:
		var progress: float=ring.age/0.8
		var radius: float=5+progress*(35 if ring.kind=="tap" else 20)
		var tint:=Color(0.77,0.88,0.86,(1-progress)*0.4)
		if ring.kind=="tap": draw_arc(ring.at,radius,0,TAU,32,tint,1,false)
		else:
			var points:=PackedVector2Array()
			for i in 25:
				var angle: float=TAU*i/24.0
				points.append(ring.at+Vector2(cos(angle)*radius,sin(angle)*radius*0.25))
			draw_polyline(points,tint,1,false)

func _draw_hud() -> void:
	for action: String in ["feed","tap"]:
		var rect: Rect2=FEED_RECT if action=="feed" else TAP_RECT
		hud.draw_style_box(hover_style if hovered==action else normal_style,rect)
		var label: String="Feed" if action=="feed" else "Tap"
		if action=="feed" and hud_clock<full_until: label="Full today"
		hud.draw_string(ThemeDB.fallback_font,rect.position+Vector2(12,25),label,HORIZONTAL_ALIGNMENT_LEFT,-1,19,Color("c6dcd8"))

func _panel(tint: Color) -> StyleBoxFlat:
	var style:=StyleBoxFlat.new()
	style.bg_color=tint
	style.set_corner_radius_all(8)
	return style
