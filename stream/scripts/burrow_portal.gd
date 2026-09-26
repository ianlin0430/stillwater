class_name BurrowPortal
extends Node2D
# Presentation-only shelter: rear wall, open throat, raised foreground lip.
const RADIUS: float=20.0
var front: Node2D
var sand_age: float=2.0
var last_bucket: int=-1
func _ready() -> void:
	texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	z_index=0
	front=Node2D.new()
	front.z_index=1
	front.draw.connect(_draw_front)
	add_child(front)
func disturb() -> void:
	sand_age=0
	front.queue_redraw()
func advance(delta: float) -> void:
	if delta<=0: return
	sand_age=minf(2,sand_age+delta)
	var bucket: int=int(sand_age*15)
	if bucket!=last_bucket and sand_age<1.1:
		front.queue_redraw()
	elif last_bucket<16 and bucket>=16: front.queue_redraw()
	last_bucket=bucket
func _draw() -> void:
	# Stepped outlines and offset bands make a hollow, not a detached drop shadow.
	draw_colored_polygon(PackedVector2Array([Vector2(-26,3),Vector2(-25,-4),Vector2(-20,-10),Vector2(-10,-14),Vector2(9,-14),Vector2(20,-10),Vector2(26,-3),Vector2(27,4)]),Color("b8a477"))
	draw_colored_polygon(PackedVector2Array([Vector2(-23,0),Vector2(-19,-8),Vector2(-9,-11),Vector2(9,-11),Vector2(19,-7),Vector2(23,0)]),Color("e5d5ab"))
	draw_colored_polygon(PackedVector2Array([Vector2(-20,1),Vector2(-17,-5),Vector2(-8,-8),Vector2(9,-8),Vector2(18,-4),Vector2(21,2)]),Color("655c46"))
	draw_colored_polygon(PackedVector2Array([Vector2(-17,1),Vector2(-12,-3),Vector2(-5,-5),Vector2(9,-4),Vector2(17,0),Vector2(18,4),Vector2(-17,4)]),Color("343b35"))
	for point: Vector2 in [Vector2(-18,-9),Vector2(-9,-13),Vector2(8,-12),Vector2(18,-8)]:
		draw_rect(Rect2(point,Vector2(4,2)),Color("f1e3bd"))
func _draw_front() -> void:
	# This lip is a real layer drawn above the fish; the throat shader clips only within it.
	front.draw_colored_polygon(PackedVector2Array([Vector2(-26,1),Vector2(-18,0),Vector2(-10,3),Vector2(9,3),Vector2(19,0),Vector2(27,1),Vector2(24,7),Vector2(11,10),Vector2(-12,9),Vector2(-24,6)]),Color("cbbb91"))
	front.draw_colored_polygon(PackedVector2Array([Vector2(-23,1),Vector2(-16,1),Vector2(-8,5),Vector2(8,5),Vector2(17,1),Vector2(23,1),Vector2(17,5),Vector2(8,8),Vector2(-9,7),Vector2(-19,4)]),Color("f0dfb1"))
	for point: Vector2 in [Vector2(-22,5),Vector2(-8,8),Vector2(13,6),Vector2(25,3)]:
		front.draw_rect(Rect2(point,Vector2(3,2)),Color("ac9c78"))
	if sand_age<1:
		for i in 7:
			var t: float=sand_age
			var side: float=-1 if i%2 else 1
			var p:=Vector2(side*(10+i*1.7+t*(6+i)),2-sin(t*PI)*(5+i*.7))
			front.draw_rect(Rect2(p.snapped(Vector2.ONE),Vector2(2,1)),Color(0.86,0.78,0.59,(1-t)*.65))
