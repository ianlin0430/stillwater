class_name ReefRig
extends SwimmerRig
# GPU-articulated soft-pixel actor. Snapshot positions and ecology stay untouched.
const ATLAS: Texture2D=preload("res://assets/reef/fish-atlas-v1.png")
const EEL: Texture2D=preload("res://assets/reef/garden-eel-v1.png")
const REEF_SHADER: Shader=preload("res://scripts/reef_motion.gdshader")
const REEF_SPECIES: Array[String]=["garden_eel","lawnmower_blenny","purple_firefish","green_chromis","yellow_tang"]
const LOOK: Dictionary={
	"yellow_tang":{"region":Rect2(138,104,551,394),"width":122.0,"line":0.66},
	"purple_firefish":{"region":Rect2(802,82,670,404),"width":91.0,"line":0.65},
	"lawnmower_blenny":{"region":Rect2(64,621,673,285),"width":100.0,"line":0.47},
	"green_chromis":{"region":Rect2(856,609,584,336),"width":68.0,"line":0.49},
	"garden_eel":{"region":Rect2(411,100,275,1360),"width":25.0,"line":1.0}}
var actor: Dictionary={}
var extent: Vector2
var extension: float=1
var target_extension: float=1
var touch_remaining: float=0
var hop_phase: float=0
var hop_height: float=0
var visual_offset:=Vector2.ZERO
var visual_pitch: float=0
var contact_projection: float=1
var activity_age: float=0
var bite_timer: float=0
var body_visible: bool=true
var dying: bool=false
var first_actor: bool=true
var arrival_age: float=-1
var arrival_from:=Vector2.ZERO
var detached: bool=false
var selection_offset:=Vector2.ZERO
var drawn_selection: bool=false
var drawn_offset:=Vector2.ZERO
var drawn_shadow: bool=false
var pose_from: Dictionary={}
var pose_to: Dictionary={}
var pose: Dictionary={}
var pose_time: float=0.2
var tail_heading: float=0
var ray_flick: float=0
var ray_velocity: float=0
var last_flick: float=0
var hop_age: float=1
var hop_power: float=0
var last_thrust: float=0
var follow_offset:=Vector2.ZERO
var contact_offset:=Vector2.ZERO
var portal: BurrowPortal
var portal_fold: float=0
var last_hiding: bool=false

func _ready() -> void:
	texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	previous=position
	phase=individual_id*0.79
	water_phase=phase
	tail_facing=facing
	var cfg: Dictionary=LOOK[species]
	var rect: Rect2=cfg.region
	extent=Vector2(cfg.width,cfg.width*rect.size.y/rect.size.x)
	fish=Polygon2D.new()
	fish.texture=EEL if species=="garden_eel" else ATLAS
	var vertices:=PackedVector2Array()
	var uv:=PackedVector2Array()
	var quads: Array[PackedInt32Array]=[]
	var columns: int=8 if species=="garden_eel" else 32
	var rows: int=48 if species=="garden_eel" else 24
	var anchor:=Vector2(0.22 if species=="garden_eel" else 0.5,cfg.line)
	for x in columns+1:
		for y in rows+1:
			var at:=Vector2(float(x)/columns,float(y)/rows)
			vertices.append((at-anchor)*extent)
			uv.append(rect.position+at*rect.size)
	for x in columns:
		for y in rows:
			var i: int=x*(rows+1)+y
			quads.append(PackedInt32Array([i,i+rows+1,i+rows+2,i+1]))
	fish.polygon=vertices
	fish.uv=uv
	fish.polygons=quads
	fish_material=ShaderMaterial.new()
	fish_material.shader=REEF_SHADER
	fish_material.set_shader_parameter("extent",extent)
	fish_material.set_shader_parameter("body_line",cfg.line)
	fish_material.set_shader_parameter("eel",species=="garden_eel")
	fish_material.set_shader_parameter("fin_ray",1.0 if species=="purple_firefish" else 0.0)
	var fin_root: Vector2=Vector2(.73,.62) if species=="yellow_tang" else Vector2(.76,.58) if species=="green_chromis" else Vector2(.72,.69) if species=="purple_firefish" else Vector2(.70,.61)
	fish_material.set_shader_parameter("pectoral_root",fin_root)
	fish.material=fish_material
	add_child(fish)
	if species=="purple_firefish" and not detached:
		portal=BurrowPortal.new()
		add_child(portal)
		move_child(portal,0)

func apply_actor(value: Dictionary, _pellets: Array=[]) -> void:
	pose_from=pose.duplicate()
	pose_to={"heading":float(value.get("heading",0 if value.get("direction",1)>0 else PI))}
	for key: String in ["pitch","speed","thrust","turn","roll"]:
		pose_to[key]=float(value.get(key,0))
	if first_actor:
		pose=pose_to.duplicate()
		pose_from=pose.duplicate()
		tail_heading=pose.heading
	pose_time=0
	var flick: float=float(value.get("flick",0))
	if flick>last_flick: ray_velocity=3.2
	last_flick=flick
	if species=="lawnmower_blenny" and pose_to.thrust>last_thrust+0.15:
		hop_age=0
		hop_power=clampf(pose_to.thrust,0,1)
	last_thrust=pose_to.thrust
	actor=value.duplicate(true)
	activity=actor.get("activity","Resting")
	target_extension=clampf(float(actor.get("extend",1)),0,1)
	if first_actor:
		extension=target_extension
		if species=="yellow_tang" and activity=="Grazing" and actor.has("contact_x"):
			var contact: Vector2=(Vector2(actor.contact_x,actor.contact_y)-position)/maxf(body_scale,.1)
			var angle: float=atan2(contact.y,absf(contact.x))*float(actor.get("direction",1))
			contact_offset=contact-Vector2(extent.x*.5*cos(pose.heading),0).rotated(angle)
		first_actor=false

func consume_food() -> void:
	bite_timer=0.35

func reset_contact() -> void:
	previous=position
	hop_height=0
	hop_phase=0
	motion=0

func touch(at: Vector2) -> void:
	if species=="garden_eel" and position.distance_to(at)<110:
		touch_remaining=3.5

func begin_arrival() -> void:
	if species not in ["garden_eel","purple_firefish"]: return
	arrival_age=0
	arrival_from=Vector2(-45 if position.x<640 else 1325,position.y-50)-position

func begin_death() -> void:
	dying=true
	target_extension=0

func mouth_position() -> Vector2:
	if species=="garden_eel": return position+Vector2(facing*10,-extent.y*extension)*body_scale
	return position+(visual_offset+Vector2(extent.x*0.5*facing*contact_projection,0).rotated(visual_pitch))*body_scale

func selection_position() -> Vector2:
	return position+selection_offset*body_scale

func animate(delta: float) -> void:
	if delta<=0: return
	phase+=delta
	if activity!=last_activity:
		activity_age=0
		if activity in ["Hopping","Startled","Feeding"]: hop_phase=0
		last_activity=activity
	activity_age+=delta
	var velocity: Vector2=(position-previous)/delta
	previous=position
	motion=lerpf(motion,velocity.length(),1-exp(-delta*6))
	var sleeping: bool=activity in ["Sleeping","Resting","Perching"]
	if pose_to.is_empty():
		pose_to={"heading":0.0 if face_target>0 else PI,"pitch":0.0,"speed":0.0,"thrust":0.0,"turn":0.0,"roll":0.0}
		pose_from=pose_to.duplicate()
	pose_time=minf(.2,pose_time+delta)
	for key: String in pose_to:
		pose[key]=lerpf(float(pose_from[key]),float(pose_to[key]),pose_time/.2)
	effort=lerpf(effort,clampf(pose.thrust,0,1),1-exp(-delta/(0.14 if pose.thrust>effort else 0.24)))
	# Integrate propulsive effort, not a wall-clock swim loop. Coasting stops strokes.
	water_phase+=delta*TAU*effort*(2.6 if species=="green_chromis" else 1.8)
	facing=cos(pose.heading)
	var trailing: float=clampf(pose.heading-pose.turn*0.08,0,PI)
	tail_heading=lerpf(tail_heading,trailing,1-exp(-delta*8))
	tail_facing=cos(tail_heading)
	fin_spread=lerpf(fin_spread,0.82+effort*.28+(0.08 if activity=="Curious" else 0),1-exp(-delta*9))
	ray_velocity+=(-36*ray_flick-12*ray_velocity)*delta
	ray_flick+=ray_velocity*delta
	feeding=move_toward(feeding,1.0 if activity=="Grazing" else 0.0,delta*4)
	bite_timer=maxf(0,bite_timer-delta)
	touch_remaining=maxf(0,touch_remaining-delta)
	var goal: float=0.0 if dying or touch_remaining>0 else target_extension
	extension=move_toward(extension,goal,delta*(1.0/0.55 if species=="purple_firefish" and goal<extension else 6.0 if goal<extension else 1.0/1.3))
	visual_offset=Vector2.ZERO
	var desired_follow: Vector2=Vector2(clampf(-velocity.x*.035,-1.8,1.8),clampf(-velocity.y*.025,-1.2,1.2)) if species in ["green_chromis","yellow_tang"] and activity!="Grazing" else Vector2.ZERO
	follow_offset=follow_offset.lerp(desired_follow,1-exp(-delta*7))
	if activity!="Grazing": visual_offset=follow_offset
	visual_pitch=pose.pitch*(1 if facing>=0 else -1)
	contact_projection=1
	if species=="lawnmower_blenny":
		hop_age+=delta
		hop_height=pow(sin(clampf(hop_age/0.65,0,1)*PI),2)*hop_power*7.0 if pose.speed>1 and hop_age<0.65 else 0.0
		visual_offset.y=-extent.y*(1-float(LOOK[species].line))-hop_height
		if activity=="Grazing":
			visual_pitch=lerp_angle(visual_pitch,0.31*face_target,1-exp(-delta*7))
			visual_offset.y=-sin(absf(visual_pitch))*extent.x*0.5-0.5
	elif species=="purple_firefish":
		_firefish_pose(goal<extension or (goal==0 and extension==0))
		if portal!=null:
			var hiding: bool=goal==0
			if hiding!=last_hiding: portal.disturb()
			last_hiding=hiding
			portal.advance(delta)
	elif species=="yellow_tang" and activity=="Grazing" and actor.has("contact_x"):
		var contact: Vector2=(Vector2(actor.contact_x,actor.contact_y)-position)/maxf(body_scale,0.1)
		# Keep the silhouette intact; ease a visual mouth pivot toward the rock.
		contact_projection=1.0
		visual_pitch=atan2(contact.y,absf(contact.x))*face_target
		# Head direction is backend-owned at contact; prevent overshoot of the mouth.
		# Backend finishes the heading turn before grazing; no direction snap here.
	if species=="yellow_tang":
		var desired_contact:=Vector2.ZERO
		if activity=="Grazing" and actor.has("contact_x"):
			var contact: Vector2=(Vector2(actor.contact_x,actor.contact_y)-position)/maxf(body_scale,.1)
			desired_contact=contact-Vector2(extent.x*.5*facing,0).rotated(visual_pitch)
		contact_offset=contact_offset.lerp(desired_contact,1-exp(-delta*10))
		visual_offset+=contact_offset
	if arrival_age>=0:
		arrival_age+=delta
		if arrival_age<1.6:
			# Swim above the substrate before adopting the burrow's current sleep/hide state.
			# A nighttime arrival must not travel underground in its final hidden pose.
			extension=1
			visual_pitch=0
			facing=-signf(arrival_from.x)
			tail_facing=facing
			visual_offset=arrival_from*pow(1-arrival_age/1.6,2)
			visual_offset.y-=float(actor.get("hover_y",32))/maxf(body_scale,0.1)
		else: arrival_age=-1
	body_visible=not (species in ["garden_eel","purple_firefish"] and extension<=0.001 and arrival_age<0)
	fish.visible=body_visible
	selection_offset=Vector2(facing*6,-extent.y*extension*0.65) if species=="garden_eel" else visual_offset
	fish_material.set_shader_parameter("phase",water_phase)
	fish_material.set_shader_parameter("breath_phase",phase*TAU*(0.65 if sleeping else 1.1))
	fish_material.set_shader_parameter("effort",effort)
	fish_material.set_shader_parameter("tail_drive",clampf(pose.speed/45,0,1)*(0.2+effort*0.8))
	fish_material.set_shader_parameter("roll",pose.roll)
	fish_material.set_shader_parameter("ray_flick",ray_flick)
	fish_material.set_shader_parameter("eye_scan",0.0)
	fish_material.set_shader_parameter("facing",facing)
	fish_material.set_shader_parameter("tail_facing",tail_facing)
	fish_material.set_shader_parameter("projection",contact_projection)
	fish_material.set_shader_parameter("extension",extension)
	fish_material.set_shader_parameter("fin_open",fin_spread)
	fish_material.set_shader_parameter("sleep_amount",1.0 if sleeping else 0.0)
	fish_material.set_shader_parameter("pectoral_drive",0.0 if species=="lawnmower_blenny" and activity in ["Grazing","Perching","Sleeping"] else effort)
	fish_material.set_shader_parameter("bite",feeding*(0.5+sin(phase*9)*0.5)+sin(bite_timer/0.35*PI))
	fish_material.set_shader_parameter("pose_offset",visual_offset)
	fish_material.set_shader_parameter("pitch",visual_pitch)
	fish_material.set_shader_parameter("portal",species=="purple_firefish" and not detached and arrival_age<0)
	fish_material.set_shader_parameter("portal_fold",portal_fold)
	fish_material.set_shader_parameter("clip_sand",not detached and species in ["garden_eel","lawnmower_blenny"] and arrival_age<0)
	fish.modulate=Color(dim,dim,dim,1)
	var shadow: bool=species=="lawnmower_blenny" and hop_height<1 and activity in ["Perching","Grazing","Sleeping"]
	if selected!=drawn_selection or shadow!=drawn_shadow or (selected and selection_offset!=drawn_offset):
		drawn_selection=selected
		drawn_shadow=shadow
		drawn_offset=selection_offset
		queue_redraw()

func _firefish_pose(entering: bool) -> void:
	var h: float=float(actor.get("hover_y",32))/maxf(body_scale,.1)
	var half: float=extent.x*.5
	var direction: float=1 if face_target>0 else -1
	var t: float=1-extension
	portal_fold=smoothstep(0,.4,t)
	if entering:
		var bend: float=smoothstep(0,.4,t)
		visual_pitch=lerpf(pose.pitch*direction,PI*.5*direction,bend)
		var head:=Vector2(direction*half*(1-bend),lerpf(-h,-3,bend))
		visual_offset=head-Vector2(direction*half,0).rotated(visual_pitch)
		if t>.4:
			visual_offset=Vector2(0,lerpf(-half-3,half+14,smoothstep(.4,1,t)))
	else:
		# Rotate inside the shelter, then emerge nose first. Finish the turn above its rim.
		var rise: float=smoothstep(0,.6,extension)
		visual_pitch=-PI*.5*direction
		visual_offset=Vector2(0,lerpf(half+14,-half-3,rise))
		if extension>.6:
			var level: float=smoothstep(.6,1,extension)
			visual_pitch=lerpf(-PI*.5*direction,pose.pitch*direction,level)
			visual_offset.y=lerpf(-half-3,-h,level)
	if extension>.999:
		visual_pitch=pose.pitch*direction
		visual_offset=Vector2(0,-h+sin(phase*1.1)*.7)

func _draw() -> void:
	if not detached and species=="garden_eel":
		var r: float=5 if species=="garden_eel" else 8
		draw_set_transform(Vector2(0,1),0,Vector2(1,0.35))
		draw_circle(Vector2.ZERO,r+2,Color("c4b58e"))
		draw_circle(Vector2.ZERO,r,Color("706655"))
		draw_circle(Vector2(0,-1),r-2,Color("4d5149"))
		draw_set_transform(Vector2.ZERO)
	if species=="lawnmower_blenny" and hop_height<1 and activity in ["Perching","Grazing","Sleeping"]:
		# Contact shadow is anchored to the substrate, not to the animated body.
		draw_set_transform(Vector2(-5,0),0,Vector2(1,0.17))
		draw_circle(Vector2.ZERO,extent.x*0.34,Color(0.20,0.22,0.19,0.18))
		draw_set_transform(Vector2.ZERO)
	if selected:
		draw_arc(selection_offset,24 if species=="garden_eel" else extent.x*0.6,0.12,PI-0.12,30,Color(0.76,0.88,0.82,0.75),1,false)
