extends RefCounted
const Actor=preload("res://tools/review_fixtures/cast_snapshot.gd")
const SPECIES: Array[String]=["clownfish","seahorse","royal_gramma"]
const STYLES: Array[String]=["anemone_green","seagrass_tall","cave_rock"]
static func actor_at(species: String, t: float, decor: Dictionary) -> Dictionary:
	var a:=Actor.actor(species,SPECIES.find(species)+1,Vector2.ZERO)
	a.thrust=.18
	if species=="clownfish":
		var c: Dictionary=decor.anemone
		var hidden: bool=t>=4 and t<8
		var moving: float=1-smoothstep(4,5,t) if t<8 else smoothstep(8,9,t)
		a.home={"kind":"anemone","slot":"anemone","i":0}
		a.home_x=c.cx
		a.home_y=c.cy
		a.x=c.cx+sin(t*1.3)*8*moving
		a.y=c.cy+sin(t*.7)*2*moving
		a.activity="Sheltering" if hidden else "Nestling"
		a.nestle=1.0 if hidden else .18
		a.heading=0.0 if t<8 else PI
	elif species=="seahorse":
		var start:=Vector2(decor.hitches[2][0],decor.hitches[2][1])
		var end:=Vector2(decor.hitches[3][0],decor.hitches[3][1])
		var grip:=ReefFishArt.anchor_offset(species,"grip")
		var u: float=clampf((t-2)/11.0,0,1)
		var drifting: bool=t>=2 and t<13
		var tail:=start.lerp(end,smoothstep(0,1,u))
		var velocity: Vector2=(end-start)*6*u*(1-u)/11.0 if drifting else Vector2.ZERO
		a.x=tail.x-grip.x
		a.y=tail.y-grip.y
		a.home={"kind":"hitch","slot":"hitch_plant","i":3 if t>=13 else 2}
		a.home_x=end.x if t>=13 else start.x
		a.home_y=end.y if t>=13 else start.y
		a.activity="Drifting" if drifting else "Hitched"
		a.lean=sin(t*1.2)*(.025 if drifting else .12)
		a.vx=velocity.x
		a.vy=velocity.y
		a.speed=velocity.length()
		a.thrust=.45 if drifting else .12
		if not drifting:
			a.hitch_x=tail.x
			a.hitch_y=tail.y
	else:
		var den: Dictionary=decor.shelters[0]
		var hidden: bool=(t>=3 and t<6) or (t>=10 and t<13)
		a.home={"kind":"shelter","slot":"s1","i":0}
		a.home_x=den.x
		a.home_y=den.y
		a.den_x=den.x
		a.den_y=den.y
		a.den_side=den.side
		a.x=den.x+den.side*(42+sin(t*.9)*4)
		a.y=den.y+sin(t*1.1)*3
		a.extend=0.0 if hidden else 1.0
		a.activity="Hiding" if hidden else "Hovering"
		a.heading=PI if t<6 or hidden else 0.0
	a.direction=-1.0 if cos(a.heading)<0 else 1.0
	return a
