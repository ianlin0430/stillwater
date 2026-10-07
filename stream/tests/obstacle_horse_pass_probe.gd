extends "res://scripts/stream_world.gd"
# Disposable cloud comparison; production remains unchanged.
func _avoid(a: Dictionary, p: Vector2, desired: Vector2, speed: float) -> Vector2:
	_dodge=0.0
	# A resting chromis stays put; the others go around it.
	if a.activity=="Resting" and a.species=="green_chromis":
		if state.light_hour<7 or state.light_hour>19: return desired
		# Swimming traffic goes around a resting school, but an attached home
		# resident cannot yield. A daytime breathing slot must stay clear of it;
		# settled night targets remain fixed and never yield to passing traffic.
		var clear: bool=true
		for o: Dictionary in _not_chromis:
			if not _fixed_home_pose(o): continue
			var r: Vector2=(_bodies[a.id]+_bodies[o.id])*.5*SEPARATE.margin*1.17
			var rel: Vector2=(p-Vector2(o.x,o.y)).abs()/r
			if maxf(rel.x,rel.y)<1.0: clear=false
		if clear: return desired
	var own: Vector2=_bodies[a.id]
	var v:=Vector2(a.get("vx",0.0),a.get("vy",0.0))
	var push:=Vector2.ZERO
	var local: bool=a.activity=="Feeding" or a.has("home_x") and Vector2(a.tx-a.home_x,a.ty-a.home_y).length_squared()<=HOME[a.species].radius*HOME[a.species].radius and p.distance_to(Vector2(a.home_x,a.home_y))<HOME[a.species].radius+own.x
	if a.species=="seahorse" and a.activity in ["Returning","Drifting"]: local=false
	var own_crossing: bool=a.species=="seahorse" and a.activity!="Resting" and absf(a.ty-a.y)>absf(a.tx-a.x) and Vector2(a.tx-a.x,a.ty-a.y).length_squared()>1600.0
	var margin: float=SEPARATE.margin
	var look: float=SEPARATE.look
	var gain: float=SEPARATE.gain
	# For a chromis no other chromis counts (the school spaces itself).
	for o: Dictionary in (_not_chromis if a.species=="green_chromis" else state.animals):
		# Clownfish sharing their anemone nestle together (plan §3.1); they do not push each other out.
		if o.id==a.id or a.species=="clownfish" and o.species=="clownfish" and o.home==a.home:
			continue
		var mixed: bool=o.species!=a.species
		# (S5-fix: two seahorses keep only SEPARATE.perch apart, enough that their bodies never
		# overlap by a fifth: hitch points on one plant lie closer than the general spacing, and a
		# seahorse kept off its own hitch by its neighbour hovered above it for minutes.)
		var horse_pair: bool=a.species=="seahorse" and o.species=="seahorse"
		var landing: bool=a.species=="seahorse" and a.activity in ["Returning","Drifting"] and (horse_pair or p.distance_to(_hitch_center(a))<30.0)
		# Fixed neighbouring perches have authored spacing; do not hold an arriving
		# horse outside its safe landing solely to preserve open-water spacing.
		var spacing: float=.83 if landing else SEPARATE.perch if horse_pair else margin*(1.17 if mixed else SEPARATE.same)
		var r: Vector2=(own+_bodies[o.id])*0.5*spacing
		var rel: Vector2=p-Vector2(o.x,o.y)
		var relv: Vector2=v-Vector2(o.get("vx",0.0),o.get("vy",0.0))
		var t: float=clampf(-rel.dot(relv)/maxf(relv.length_squared(),0.0001),0.0,look)
		var ahead: Vector2=rel+relv*t
		var now: float=Vector2(rel.x/r.x,rel.y/r.y).length()
		var q: float=minf(now,Vector2(ahead.x/r.x,ahead.y/r.y).length())
		# Only a daytime resting school slot needs the extra clearance from a
		# resident that cannot yield. Travelling fish retain smooth elliptical
		# steering: a box-axis normal changes abruptly at its corners, causing
		# route stalls, extra facing reversals and kinks (cloud37561022526).
		var fixed_home: bool=a.species=="green_chromis" and a.activity=="Resting" and _fixed_home_pose(o)
		if landing or horse_pair or fixed_home:
			# Attached residents and horse trips use actual body boxes at corners.
			now=maxf(absf(rel.x/r.x),absf(rel.y/r.y))
			q=minf(now,maxf(absf(ahead.x/r.x),absf(ahead.y/r.y)))
		if q>=1.0:
			continue
		var schooling: bool=a.species=="green_chromis"
		var yields: float=(1.0 if a.id>o.id else 0.0) if schooling==(o.species=="green_chromis") else (1.0 if schooling else 0.0)
		# A slow vertical crossing has priority over fast horizontal traffic. Otherwise
		# successive clownfish excursions starve a seahorse of any gap to descend.
		var other_crossing: bool=o.species=="seahorse" and absf(o.ty-o.y)>absf(o.tx-o.x) and Vector2(o.tx-o.x,o.ty-o.y).length_squared()>1600.0 and o.activity!="Resting"
		if own_crossing and o.species!="seahorse":
			yields=0.0
		elif other_crossing and a.species!="seahorse":
			yields=1.0
		if a.has("nav_wait") and not o.has("nav_wait"):
			yields=1.0
		elif o.has("nav_wait") and not a.has("nav_wait"):
			yields=0.0
		var travelling: bool=Vector2(o.tx-o.x,o.ty-o.y).length_squared()>1600.0 and o.activity!="Resting"
		if local:
			yields=1.0 if a.id>o.id else 0.0
		if not local and yields==0.0 and travelling and now>=0.8:
			continue
		# Dodge up or down, away from the other (the upper fish rises; ids break a tie).
		var up: float=signf(rel.y) if absf(rel.y)>1.0 else (1.0 if a.id>o.id else -1.0)
		# A pass must fit the actual water, including the bed at the other body.
		# Always passing on the current side traps a lower fish against the sand.
		var low: float=minf(_bands[a.species][1],bed_y(o.x)-own.y*.5)
		var forced_side: bool=false
		if up>0.0 and o.y+r.y>low:
			up=-1.0
			forced_side=true
		elif up<0.0 and o.y-r.y<_bands[a.species][0]:
			up=1.0
			forced_side=true
		var side: float=signf(rel.x) if absf(rel.x)>1.0 else 0.0
		var vertical: bool=not local and absf(desired.y)>absf(desired.x)
		var dodge: Vector2=Vector2(side if side!=0.0 else (1.0 if a.id>o.id else -1.0),up*0.25) if vertical else Vector2(side*0.5,up)
		push+=dodge.normalized()*speed*gain*(1.0-q)
		_dodge=maxf(_dodge,1.0-q)
		# The younger id holds back as a meeting nears; inside the other's space nobody presses on
		# toward it. What it held back it swims along the other's edge instead, on its dodging side
		# (or, passing above or below, on toward where it was going): it goes round, it does not
		# wait (S5-fix; holding back alone left two fish face to face for minutes).
		# (S5-fix: a swimming chromis gives way to the slower fish, not they to the school: shoved
		# down by a passing school, a clownfish ended up under a ledge and turned round and back.)
		# (A fish waiting at a passage gives way to everyone; one coming out does not wait for it.)
		var holding: float=SEPARATE.close
		if a.has("nav_wait") and not o.has("nav_wait"):
			yields=1.0
		elif o.has("nav_wait") and not a.has("nav_wait"):
			yields=0.0
			holding=0.85
		if now<holding or yields>0.0:
			var n: Vector2=Vector2(rel.x/(r.x*r.x),rel.y/(r.y*r.y)).normalized()
			if landing or fixed_home:
				n=Vector2(signf(rel.x),0) if absf(rel.x/r.x)>absf(rel.y/r.y) else Vector2(0,signf(rel.y))
			var toward: float=-desired.dot(n)
			if toward>0.0:
				var k: float=1.0 if now<holding else yields*clampf((1.0-q)*3.0,0.0,1.0)
				var along:=Vector2(-n.y,n.x)
				# (Meeting above or below, it slides off to the side it is already on, ids breaking a
				# tie; never back the way it is heading: that would turn it round.)
				var aside: float=side if side!=0.0 else (1.0 if a.id>o.id else -1.0)
				# A travelling fish passes on the tangent that continues its journey.
				# Always retreating above a body below it creates a permanent descent queue.
				if horse_pair and absf(along.y)>.1:
					# Opposing horses need distinct passing sides. Following each
					# destination can send both upward while canceling all headway.
					if signf(along.y)!=up: along=-along
				elif Vector2(a.tx-a.x,a.ty-a.y).length_squared()>1600.0:
					if along.dot(desired)<0.0 or absf(along.dot(desired))<.01 and absf(along.y)>.1 and signf(along.y)!=up:
						along=-along
					if forced_side and absf(along.y)>.1 and signf(along.y)!=up:
						along=-along
				elif absf(along.y)>0.3 and signf(along.y)!=up or absf(along.y)<=0.3 and signf(along.x)!=aside:
					along=-along
				if along.x*desired.x<0.0 and absf(desired.x)>0.45*desired.length():
					along.x=0.0
				desired+=(n if local else n+along)*toward*k
	return desired+push

