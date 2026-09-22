extends Node2D
# Presentation only: fixed deterministic specks; never touches ecological RNG.
var clock: float=0
var redraw_clock: float=0
func advance(delta: float) -> void:
	clock+=delta
	redraw_clock+=delta
	if redraw_clock>=0.1:
		redraw_clock=0
		queue_redraw()
func _draw() -> void:
	for i in 14:
		var x: float=90+fmod(i*83.7+clock*(1.1+float(i%3)*0.3),1100)
		var y: float=105+fmod(i*67.3,400)+sin(clock*0.19+i*2.1)*5
		var alpha: float=0.07+0.04*sin(clock*0.3+i)
		draw_rect(Rect2(Vector2(x,y).snapped(Vector2(2,2)),Vector2(2,2)),Color(0.83,0.87,0.67,alpha))
