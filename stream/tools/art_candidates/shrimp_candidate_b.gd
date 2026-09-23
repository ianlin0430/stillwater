extends SwimmerRig
# Opt-in art candidate. Production stage does not load this script.
var pigment: float=0.6
var maturity: float=1.0
var antenna_lag: float=1.0
var paddle_phase: float=0.0
var feed_phase: float=0.0
var step_group: int=0

func _update_feet(delta: float) -> void:
	if delta<=0: return
	if activity in ["Swimming","Settling","Retreating"]:
		reset_contact()
		return
	var stepping: bool=false
	var largest: float=0.0
	for i in 10:
		var desired:=position+Vector2((-12+(i%5)*8)*face_target,13+(i/5)*1.2)*body_scale
		largest=maxf(largest,feet[i].distance_to(desired))
		if foot_t[i]<1:
			foot_t[i]=minf(1,foot_t[i]+delta*3.5)
			var t: float=foot_t[i]
			feet[i]=foot_start[i].lerp(foot_end[i],t)+Vector2(0,-sin(t*PI)*5.5*body_scale)
			stepping=stepping or t<1
	if not stepping and largest>4*body_scale:
		for i in 10:
			if i%2!=step_group: continue
			foot_start[i]=feet[i]
			foot_end[i]=position+Vector2((-12+(i%5)*8+3)*face_target,13+(i/5)*1.2)*body_scale
			foot_t[i]=0
		step_group=1-step_group

func _limb(points: PackedVector2Array, color: Color, width: float=1.6) -> void:
	# A dark lower edge keeps pale limbs legible on sand; still nearest sampled.
	draw_polyline(points,Color(0.28,0.16,0.12,color.a*0.75),width+0.8,false)
	draw_polyline(points,color,width,false)

func apply_identity(a: Dictionary, elapsed: float) -> void:
	sex=a.get("sex","female")
	maturity=clampf(float(a.get("age",21))/21,0,1)
	pigment=clampf(float(a.get("tint",0.6)),0,1)
	berried=float(a.get("brood_until",0))>elapsed
	molting=float(a.get("molting_until",0))*86400>elapsed
func animate(delta: float) -> void:
	super.animate(delta)
	paddle_phase+=delta*TAU*(0.45+minf(motion,25)/25*1.65)
	feed_phase+=delta*TAU*1.2
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
		if i%5==4 and feeding>0.1: continue
		var hip:=Vector2((-6+(i%5)*5)*sx,5+(i/5))
		var foot: Vector2=(feet[i]-position)/body_scale
		if swimming: foot=hip+Vector2((-3+sin(paddle_phase+i)*5)*sx,8)
		var knee: Vector2=hip.lerp(foot,0.5)+Vector2(-3*sx,-1)
		_limb(PackedVector2Array([hip,knee,foot]),leg_color)
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
		draw_line(Vector2(0,-h+2),Vector2(0,4),Color(0.38,0.12,0.10,0.3+richness*0.45),1.4,false)
		var beat: float=sin(paddle_phase+i*1.05)
		var sweep: float=(1.5+clampf(motion/15,0,1)*3.5)*beat
		if i<5: _limb(PackedVector2Array([Vector2(-2,h-1),Vector2(-2+sweep*0.65,h+4),Vector2(-3+sweep,h+7-absf(beat)*2)]),leg_color,1.4)
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
	var outline:=body.duplicate()
	outline.append(body[0])
	draw_polyline(outline,Color(0.42,0.14,0.10,0.25+richness*0.45),1.3,false)
	draw_colored_polygon(PackedVector2Array([Vector2(-3,2),Vector2(13,1),Vector2(17,4),Vector2(7,belly-1),Vector2(-3,5)]),Color(1.0,0.72,0.49,0.25))
	draw_polyline(PackedVector2Array([Vector2(-5,-8),Vector2(1,-11),Vector2(12,-10),Vector2(19,-6)]),Color(0.96,0.66,0.44,0.65),1.5,false)
	draw_colored_polygon(PackedVector2Array([Vector2(12,-8),Vector2(29,-9),Vector2(29,-7),Vector2(21,-4)]),light)
	for i in 30:
		var p:=Vector2(-2+float((i*7)%21),-7+float((i*11)%12))
		if p.x>15 and p.y>2: continue
		draw_rect(Rect2(p,Vector2(1+int(i%3==0),1)),Color(0.64,0.10,0.08,richness*0.7))
	draw_circle(Vector2(20,-5),1.7,Color("352b23"))
	draw_rect(Rect2(20,-6,1,1),Color("f2cd99"))
	if feeding>0.1:
		for i in 2:
			var reach: float=(sin(feed_phase+i*PI)+1)*0.5
			var hand:=Vector2(27,14).lerp(Vector2(20,3),reach*feeding)
			_limb(PackedVector2Array([Vector2(13,4),Vector2(20,8+reach*2),hand]),light,1.7)
			draw_line(hand,hand+Vector2(2,-2),Color(0.97,0.81,0.57),1.5,false)
	draw_set_transform(Vector2.ZERO)
	for i in 4:
		var points:=PackedVector2Array()
		var length: float=76.0 if i<2 else 40.0
		for j in 17:
			var t: float=j/16.0
			var direction: float=lerpf(sx,antenna_lag,t*0.75)
			points.append(Vector2(20*sx+t*length*direction,-5-t*(19-i*7)+sin(phase*0.8+t*3+i)*t*4))
		draw_polyline(points,Color(0.95,0.72,0.51,0.85 if i<2 else 0.65),1,false)
