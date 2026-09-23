extends SwimmerRig
# Opt-in art candidate. Production stage does not load this script.
var pigment: float=0.6
var maturity: float=1.0
var antenna_lag: float=1.0
func apply_identity(a: Dictionary, elapsed: float) -> void:
	sex=a.get("sex","female")
	maturity=clampf(float(a.get("age",21))/21,0,1)
	pigment=clampf(float(a.get("tint",0.6)),0,1)
	berried=float(a.get("brood_until",0))>elapsed
	molting=float(a.get("molting_until",0))*86400>elapsed
func animate(delta: float) -> void:
	super.animate(delta)
	antenna_lag=lerpf(antenna_lag,facing,1-exp(-delta*2.1))
func _draw_shrimp() -> void:
	var sx: float=facing
	var swimming: bool=activity in ["Swimming","Settling","Retreating"]
	var richness: float=(0.15+maturity*0.85)*(0.35+pigment*0.65)*(1.0 if sex=="female" else 0.65)
	if molting: richness*=0.4
	var red:=Color(0.93,0.25,0.18,0.23+richness*0.63)
	var light:=Color(1.0,0.65,0.44,0.3+richness*0.45)
	var leg_color:=Color(0.90,0.55,0.39,0.8)
	for i in 10:
		var hip:=Vector2((-6+(i%5)*5)*sx,5+(i/5))
		var foot: Vector2=(feet[i]-position)/body_scale
		if swimming: foot=hip+Vector2((-3+sin(phase*(4+motion*0.3)+i)*4)*sx,8)
		var knee: Vector2=hip.lerp(foot,0.5)+Vector2(-3*sx,-1)
		draw_polyline(PackedVector2Array([hip,knee,foot]),leg_color,1,false)
	var curl: float=-1.35*pow(sin(clampf(escape_age/0.65,0,1)*PI),2) if escape_age<0.65 else sin(phase*4)*0.05 if swimming else 0.0
	var joint:=Vector2(-4*sx,0)
	for i in 6:
		var turn: float=lerpf(sx,tail_facing,(i+1)/6.0)
		var angle: float=curl*(i+1)/6.0
		draw_set_transform(joint,angle*turn,Vector2(turn,1))
		var h: float=7-i*0.4
		var segment:=PackedVector2Array([Vector2(1,-h),Vector2(-5,-h+1),Vector2(-6,2),Vector2(-3,h-1),Vector2(1,h)])
		draw_colored_polygon(segment,red)
		draw_line(Vector2(0,-h),Vector2(-5,-h+1),light,1.3,false)
		draw_line(Vector2(0,-h+2),Vector2(0,4),Color(0.38,0.12,0.10,richness*0.6),1,false)
		var beat: float=sin(phase*(2.8+minf(motion,30)*0.35)+i*1.1)
		if i<5: draw_polyline(PackedVector2Array([Vector2(-2,h-1),Vector2(-3+beat*1.5,h+3),Vector2(-5+beat*2,h+4)]),leg_color,1,false)
		for dot in 5:
			var p:=Vector2(-1-float((i*13+dot*7)%4),-h+2+float((i*3+dot*11)%9))
			draw_rect(Rect2(p,Vector2(1,1)),Color(0.63,0.13,0.10,richness))
		joint+=Vector2(-5.3*turn,sin(angle)*-5.3)
	draw_set_transform(joint,curl*tail_facing,Vector2(tail_facing,1))
	for i in 3:
		var end:=Vector2(-10,(i-1)*5)
		draw_colored_polygon(PackedVector2Array([Vector2.ZERO,end+Vector2(0,-3),end+Vector2(-2,2),Vector2(-2,3)]),light)
		draw_line(Vector2.ZERO,end,red,1,false)
	draw_set_transform(Vector2.ZERO,0,Vector2(sx,1))
	var belly: float=9 if sex=="female" else 6
	var body:=PackedVector2Array([Vector2(-6,-8),Vector2(0,-12),Vector2(13,-11),Vector2(22,-5),Vector2(19,4),Vector2(8,belly),Vector2(-5,6)])
	draw_colored_polygon(body,red)
	draw_polyline(PackedVector2Array([Vector2(-5,-8),Vector2(1,-11),Vector2(12,-10),Vector2(19,-6)]),Color(0.96,0.66,0.44,0.65),1.5,false)
	draw_colored_polygon(PackedVector2Array([Vector2(12,-8),Vector2(29,-9),Vector2(29,-7),Vector2(21,-4)]),light)
	for i in 30:
		var p:=Vector2(-2+float((i*7)%21),-7+float((i*11)%12))
		if p.x>15 and p.y>2: continue
		draw_rect(Rect2(p,Vector2(1+int(i%3==0),1)),Color(0.64,0.10,0.08,richness*0.7))
	draw_circle(Vector2(20,-5),1.7,Color("352b23"))
	draw_rect(Rect2(20,-6,1,1),Color("f2cd99"))
	for i in 2:
		var reach: float=sin(phase*9+i*PI)*feeding
		draw_polyline(PackedVector2Array([Vector2(14,4),Vector2(19+reach*3,9),Vector2(23+reach*2,5)]),light,1,false)
	draw_set_transform(Vector2.ZERO)
	for i in 4:
		var points:=PackedVector2Array()
		var length: float=76.0 if i<2 else 40.0
		for j in 17:
			var t: float=j/16.0
			var direction: float=lerpf(sx,antenna_lag,t*0.75)
			points.append(Vector2(20*sx+t*length*direction,-5-t*(19-i*7)+sin(phase*0.8+t*3+i)*t*4))
		draw_polyline(points,Color(0.95,0.72,0.51,0.85 if i<2 else 0.65),1,false)
