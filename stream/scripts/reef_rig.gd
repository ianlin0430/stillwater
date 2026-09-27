class_name ReefRig
extends SwimmerRig
# GPU-articulated soft-pixel actor. Snapshot positions and ecology stay untouched.
const ATLAS: Texture2D=preload("res://assets/reef/fish-atlas-low-pixel-v1.png")
const TURN_ATLAS: Texture2D=preload("res://assets/reef/fish-turns-low-pixel-v1.png")
const TURN_REGIONS={
 "yellow_tang":[Rect2(407,17,307,270),Rect2(878,16,260,263)],
 "purple_firefish":[Rect2(428,288,288,270),Rect2(910,288,201,271)],
 "lawnmower_blenny":[Rect2(429,568,295,199),Rect2(858,571,299,188)],
 "green_chromis":[Rect2(426,778,290,234),Rect2(885,778,244,231)]}
var turn_sprite: Sprite2D
var turn_view: int=0
const EEL: Texture2D=preload("res://assets/reef/garden-eel-v1.png")
const REEF_SHADER: Shader=preload("res://scripts/reef_motion.gdshader")
const REEF_SPECIES: Array[String]=["garden_eel","lawnmower_blenny","purple_firefish","green_chromis","yellow_tang"]
const LOOK: Dictionary={
	"yellow_tang":{"region":Rect2(134,104,537,413),"width":122.0,"line":0.62},
	"purple_firefish":{"region":Rect2(820,91,639,414),"width":91.0,"line":0.64},
	"lawnmower_blenny":{"region":Rect2(84,614,649,290),"width":100.0,"line":0.50},
	"green_chromis":{"region":Rect2(859,607,579,344),"width":68.0,"line":0.49},
	"garden_eel":{"region":Rect2(411,100,275,1360),"width":25.0,"line":1.0}}
# Preview may make discrete actions brisker without changing positions or cruising speed.
var action_tempo: float=1.0
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
var arrival_duration: float=1.6
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
var blenny_graze: float=0
var blenny_pitch: float=0
var pectoral_effort: float=0
var pectoral_phase: float=0
var sleep_blend: float=0
var breath_clock: float=0
var tail_drive: float=0
var shadow_alpha: float=0
var eye_clock: float=0
var target_body_scale: float=-1
var queued_hop: float=0
var landing: float=0
var tang_pitch: float=0
var brake: float=0
var previous_speed: float=0
var food_reach:=Vector2.ZERO
var last_thrust: float=0
var follow_offset:=Vector2.ZERO
var contact_offset:=Vector2.ZERO
var portal: BurrowPortal
var portal_fold: float=0
var last_hiding: bool=false
enum PortalMotion { IDLE, ENTERING, EMERGING }
var portal_motion: PortalMotion=PortalMotion.IDLE

func _ready() -> void:
	texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	previous=position
	phase=individual_id*0.79
	water_phase=phase
	pectoral_phase=phase*1.6
	tail_facing=facing
	var cfg: Dictionary=LOOK[species]
	var rect: Rect2=cfg.region
	extent=Vector2(cfg.width,cfg.width*rect.size.y/rect.size.x)
	fish=Polygon2D.new()
	fish.texture=EEL if species=="garden_eel" else ATLAS
	var vertices:=PackedVector2Array()
	var uv:=PackedVector2Array()
	var quads: Array[PackedInt32Array]=[]
	var columns: int=8 if species=="garden_eel" else 16
	var rows: int=48 if species=="garden_eel" else 12
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
	var fin_root: Vector2=Vector2(.66,.61) if species=="yellow_tang" else Vector2(.67,.60) if species=="green_chromis" else Vector2(.73,.68) if species=="purple_firefish" else Vector2(.70,.74)
	fish_material.set_shader_parameter("pectoral_root",fin_root)
	fish_material.set_shader_parameter("atlas_region",Vector4(rect.position.x,rect.position.y,rect.size.x,rect.size.y))
	fish_material.set_shader_parameter("eye_anchor",Vector2(.90,.35) if species=="lawnmower_blenny" else Vector2(.83,.46) if species=="yellow_tang" else Vector2(.92,.60) if species=="purple_firefish" else Vector2(.91,.46))
	fish_material.set_shader_parameter("blenny",species=="lawnmower_blenny")
	fish.material=fish_material
	add_child(fish)
	if species!="garden_eel":
		turn_sprite=Sprite2D.new()
		turn_sprite.texture=TURN_ATLAS
		turn_sprite.region_enabled=true
		var cutout:=Shader.new()
		cutout.code="shader_type canvas_item; void fragment(){vec4 t=texture(TEXTURE,UV);if(t.a<.86)discard;COLOR.a*=smoothstep(.86,.97,t.a)/max(t.a,.001);}"
		turn_sprite.material=ShaderMaterial.new()
		turn_sprite.material.shader=cutout
		turn_sprite.visible=false
		add_child(turn_sprite)
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
	if flick>last_flick: ray_velocity=6.0
	last_flick=flick
	if species=="lawnmower_blenny" and pose_to.thrust>last_thrust+0.15:
		if hop_age>=0.65:
			hop_age=0
			hop_power=clampf(pose_to.thrust,0,1)
		else: queued_hop=maxf(queued_hop,clampf(pose_to.thrust,0,1))
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

func consume_food(event: Dictionary={}) -> void:
	bite_timer=0.35
	if species=="purple_firefish" and event.has("food_x"):
		food_reach=(Vector2(event.food_x,event.food_y)-mouth_position())/maxf(body_scale,.1)
		food_reach=food_reach.limit_length(24)

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
	arrival_duration=clampf(arrival_from.length()/180.0,2.5,5.0)

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
	if target_body_scale<0: target_body_scale=body_scale
	body_scale=move_toward(body_scale,target_body_scale,delta*.16)
	scale=Vector2.ONE*body_scale
	phase+=delta
	eye_clock+=delta
	sleep_blend=lerpf(sleep_blend,1.0 if activity in ["Sleeping","Resting","Perching"] else 0.0,1-exp(-delta*4))
	breath_clock+=delta*TAU*lerpf(1.1,.65,sleep_blend)
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
	pose_time=minf(.2,pose_time+delta*action_tempo)
	for key: String in pose_to:
		pose[key]=lerpf(float(pose_from[key]),float(pose_to[key]),pose_time/.2)
	effort=lerpf(effort,(0.0 if dying else clampf(pose.thrust,0,1)),1-exp(-delta/(0.14 if pose.thrust>effort else 0.24)))
	# Integrate propulsive effort, not a wall-clock swim loop. Coasting stops strokes.
	water_phase+=delta*TAU*effort*(2.6 if species=="green_chromis" else 1.8)
	var pectoral_goal: float=effort
	if species=="green_chromis" and activity=="Resting":
		pectoral_goal=clampf(Vector2(float(actor.get("vx",0)),float(actor.get("vy",0))).length()/12.0,0,1)*0.22 # Only gentle spacing recovery, never yielding to tang.
	elif species=="lawnmower_blenny" and activity in ["Grazing","Perching","Sleeping"]:
		pectoral_goal=0
	if dying: pectoral_goal=0
	pectoral_effort=lerpf(pectoral_effort,pectoral_goal,1-exp(-delta*8))
	pectoral_phase+=delta*TAU*pectoral_effort*(4.16 if species=="green_chromis" else 2.88)
	facing=cos(pose.heading)
	var trailing: float=clampf(pose.heading-pose.turn*0.08,0,PI)
	tail_heading=lerpf(tail_heading,trailing,1-exp(-delta*8))
	tail_facing=cos(tail_heading)
	brake=lerpf(brake,clampf((previous_speed-float(pose.speed))/maxf(delta,.001)/35,0,1) if not dying else 0.0,1-exp(-delta*5))
	previous_speed=pose.speed
	fin_spread=lerpf(fin_spread,1.0+effort*.10+brake*.16+(0.08 if activity=="Curious" else 0),1-exp(-delta*6))
	ray_velocity+=(-36*ray_flick-8*ray_velocity)*delta
	ray_flick+=ray_velocity*delta
	feeding=move_toward(feeding,1.0 if activity=="Grazing" else 0.0,delta*4)
	bite_timer=maxf(0,bite_timer-delta)
	touch_remaining=maxf(0,touch_remaining-delta)
	var goal: float=0.0 if dying or touch_remaining>0 else target_extension
	if species=="purple_firefish":
		# Finish the visible arc before consuming the latest ecological request.
		# Opposite requests otherwise switch nose-down to nose-up in a single frame.
		if portal_motion==PortalMotion.IDLE:
			if goal<extension: portal_motion=PortalMotion.ENTERING
			elif goal>extension: portal_motion=PortalMotion.EMERGING
		if portal_motion!=PortalMotion.IDLE:
			goal=0.0 if portal_motion==PortalMotion.ENTERING else 1.0
	extension=move_toward(extension,goal,delta*action_tempo*(1.0/(.95 if activity=="Sleeping" else .68) if species=="purple_firefish" and goal<extension else 6.0 if goal<extension else 1.0/1.3))
	visual_offset=Vector2.ZERO
	var desired_follow: Vector2=Vector2(clampf(-velocity.x*.035,-1.8,1.8),clampf(-velocity.y*.025,-1.2,1.2)) if species in ["green_chromis","yellow_tang"] and activity!="Grazing" else Vector2.ZERO
	follow_offset=follow_offset.lerp(desired_follow,1-exp(-delta*7))
	if activity!="Grazing": visual_offset=follow_offset
	visual_pitch=pose.pitch*(1 if facing>=0 else -1)
	contact_projection=1
	if species=="lawnmower_blenny":
		var old_hop_age: float=hop_age
		hop_age+=delta*action_tempo
		if old_hop_age<.65 and hop_age>=.65: landing=1
		landing=move_toward(landing,0,delta*5)
		if hop_age>=.78 and queued_hop>0 and not dying:
			hop_age=0
			hop_power=queued_hop
			queued_hop=0
		# Once airborne, finish the bounded landing arc even if thrust/speed changes.
		hop_height=pow(sin(clampf(hop_age/0.65,0,1)*PI),2)*hop_power*7.0 if hop_age<0.65 else 0.0
		var grazing_goal: float=maxf(1.0 if activity=="Grazing" else 0.0,sin(bite_timer/.35*PI)) if hop_age>=0.65 else 0.0
		blenny_graze=lerpf(blenny_graze,grazing_goal,1-exp(-delta*8))
		# Retain easing state across frames; interpolating from pose.pitch anew never settles.
		blenny_pitch=lerp_angle(blenny_pitch,lerpf(visual_pitch,0.31*face_target,blenny_graze),1-exp(-delta*7))
		visual_pitch=blenny_pitch
		var perch_y: float=-extent.y*(1-float(LOOK[species].line))
		var grazing_y: float=-sin(absf(visual_pitch))*extent.x*0.5-3.0
		visual_offset.y=lerpf(perch_y,grazing_y,blenny_graze)-hop_height-landing*1.2
	elif species=="purple_firefish":
		_firefish_pose(portal_motion==PortalMotion.ENTERING or (goal==0 and extension==0))
		if portal!=null:
			var hiding: bool=goal==0
			if hiding!=last_hiding: portal.disturb()
			last_hiding=hiding
			portal.scale=Vector2.ONE/maxf(body_scale,.1)
			portal.advance(delta)
		if is_equal_approx(extension,goal): portal_motion=PortalMotion.IDLE
	elif species=="yellow_tang" and activity=="Grazing" and actor.has("contact_x"):
		var contact: Vector2=(Vector2(actor.contact_x,actor.contact_y)-position)/maxf(body_scale,0.1)
		# Keep the silhouette intact; ease a visual mouth pivot toward the rock.
		contact_projection=1.0
		visual_pitch=atan2(contact.y,absf(contact.x))*face_target+sin(pose.roll*3)*.06*face_target
		# Head direction is backend-owned at contact; prevent overshoot of the mouth.
		# Backend finishes the heading turn before grazing; no direction snap here.
	if species=="yellow_tang":
		tang_pitch=lerp_angle(tang_pitch,visual_pitch,1-exp(-delta*7))
		visual_pitch=tang_pitch
		var desired_contact:=Vector2.ZERO
		if activity=="Grazing" and actor.has("contact_x"):
			var contact: Vector2=(Vector2(actor.contact_x,actor.contact_y)-position)/maxf(body_scale,.1)
			desired_contact=contact-Vector2(extent.x*.5*facing,0).rotated(visual_pitch)
		contact_offset=contact_offset.lerp(desired_contact,1-exp(-delta*10))
		visual_offset+=contact_offset
	if arrival_age>=0:
		arrival_age+=delta
		if arrival_age<arrival_duration:
			# Swim above the substrate before adopting the burrow's current sleep/hide state.
			# A nighttime arrival must not travel underground in its final hidden pose.
			extension=1
			visual_pitch=0
			facing=-signf(arrival_from.x)
			tail_facing=facing
			visual_offset=arrival_from*pow(1-arrival_age/arrival_duration,2)
			visual_offset.y-=float(actor.get("hover_y",32))/maxf(body_scale,0.1)
		else: arrival_age=-1
	body_visible=not (species in ["garden_eel","purple_firefish"] and extension<=0.001 and arrival_age<0)
	fish.visible=body_visible
	if turn_sprite!=null:
		# Exclusive registered poses: never crossfade two sets of eyes.
		var angle_width: float=absf(facing)
		if angle_width>.84: turn_view=0
		elif angle_width<.27: turn_view=2
		elif angle_width<.78 and angle_width>.33: turn_view=1
		turn_sprite.visible=body_visible and turn_view>0
		if turn_sprite.visible:
			fish.visible=false
			var region: Rect2=TURN_REGIONS[species][turn_view-1]
			turn_sprite.region_rect=region
			var h: float=extent.y/region.size.y
			turn_sprite.scale=Vector2(h*(1.0 if facing>=0 else -1.0),h)
			turn_sprite.rotation=visual_pitch
			turn_sprite.position=visual_offset+Vector2(0,extent.y*(.5-float(LOOK[species].line)))
			turn_sprite.modulate=Color(dim,dim,dim,1)

	selection_offset=Vector2(facing*6,-extent.y*extension*0.65) if species=="garden_eel" else visual_offset
	fish_material.set_shader_parameter("phase",water_phase)
	fish_material.set_shader_parameter("breath_phase",breath_clock)
	fish_material.set_shader_parameter("effort",effort)
	tail_drive=lerpf(tail_drive,0.0 if dying or (species=="green_chromis" and activity=="Resting") else clampf(pose.speed/45,0,1)*(0.2+effort*0.8),1-exp(-delta*6))
	fish_material.set_shader_parameter("tail_drive",tail_drive)
	fish_material.set_shader_parameter("roll",pose.roll)
	fish_material.set_shader_parameter("ray_flick",ray_flick)
	fish_material.set_shader_parameter("eye_scan",1.0 if species=="lawnmower_blenny" and fmod(eye_clock+individual_id,9.0)>7.5 and sleep_blend>.4 else 0.0)
	fish_material.set_shader_parameter("facing",facing)
	fish_material.set_shader_parameter("tail_facing",tail_facing)
	fish_material.set_shader_parameter("projection",contact_projection)
	fish_material.set_shader_parameter("extension",extension)
	fish_material.set_shader_parameter("fin_open",fin_spread)
	fish_material.set_shader_parameter("sleep_amount",sleep_blend)
	fish_material.set_shader_parameter("pectoral_drive",pectoral_effort)
	fish_material.set_shader_parameter("pectoral_phase",pectoral_phase)
	fish_material.set_shader_parameter("curious",1.0 if activity=="Curious" else 0.0)
	fish_material.set_shader_parameter("bite",feeding*(clampf(absf(pose.roll)*3,0,1) if species=="yellow_tang" else (0.5+sin(phase*5)*0.5))+sin(bite_timer/0.35*PI))
	fish_material.set_shader_parameter("pose_offset",visual_offset)
	fish_material.set_shader_parameter("pitch",visual_pitch)
	fish_material.set_shader_parameter("portal",species=="purple_firefish" and not detached and arrival_age<0)
	fish_material.set_shader_parameter("portal_fold",portal_fold)
	fish_material.set_shader_parameter("portal_radius",21/maxf(body_scale,.1))
	fish_material.set_shader_parameter("grounded_graze",blenny_graze if species=="lawnmower_blenny" else 0.0)
	fish_material.set_shader_parameter("clip_sand",not detached and species in ["garden_eel","lawnmower_blenny"] and arrival_age<0)
	fish.modulate=Color(dim,dim,dim,1)
	var shadow: bool=species=="lawnmower_blenny" and hop_height<1 and activity in ["Perching","Grazing","Sleeping"]
	var old_shadow: float=shadow_alpha
	shadow_alpha=lerpf(shadow_alpha,.18 if shadow else 0.0,1-exp(-delta*8))
	if absf(old_shadow-shadow_alpha)>.0001 or selected!=drawn_selection or shadow!=drawn_shadow or (selected and selection_offset!=drawn_offset):
		drawn_selection=selected
		drawn_shadow=shadow
		drawn_offset=selection_offset
		queue_redraw()

func _firefish_pose(entering: bool) -> void:
	var h: float=float(actor.get("hover_y",32))/maxf(body_scale,.1)
	var half: float=extent.x*.5
	var direction: float=1 if face_target>0 else -1
	var t: float=1-extension
	portal_fold=smoothstep(0,.60,t)
	if entering:
		var bend: float=smoothstep(0,.60,t)
		visual_pitch=lerpf(pose.pitch*direction,PI*.5*direction,bend)
		var head:=Vector2(direction*half*(1-bend),lerpf(-h,-3,bend))
		visual_offset=head-Vector2(direction*half,0).rotated(visual_pitch)
		if t>.60:
			visual_offset=Vector2(0,lerpf(-half-3,half+14,smoothstep(.60,1,t)))
	else:
		# Rotate inside the shelter, then emerge nose first. Finish the turn above its rim.
		var rise: float=smoothstep(0,.6,extension)
		visual_pitch=-PI*.5*direction
		visual_offset=Vector2(0,lerpf(half+14,-half-3,rise))
		if extension>.6:
			var level: float=smoothstep(.6,1,extension)
			visual_pitch=lerpf(-PI*.5*direction,pose.pitch*direction,level)
			visual_offset.y=lerpf(-half-3,-h,level)
	var hover_weight: float=smoothstep(.82,1,extension)
	visual_offset+=Vector2(sin(phase*.7)*1.5,sin(phase*1.1)*1.8)*hover_weight
	visual_offset+=food_reach*sin(bite_timer/.35*PI)*hover_weight

func _draw() -> void:
	if not detached and species=="garden_eel":
		var r: float=5 if species=="garden_eel" else 8
		draw_set_transform(Vector2(0,1),0,Vector2(1,0.35))
		draw_circle(Vector2.ZERO,r+2,Color("c4b58e"))
		draw_circle(Vector2.ZERO,r,Color("706655"))
		draw_circle(Vector2(0,-1),r-2,Color("4d5149"))
		draw_set_transform(Vector2.ZERO)
	if species=="lawnmower_blenny" and shadow_alpha>.001:
		# Contact shadow is anchored to the substrate, not to the animated body.
		draw_rect(Rect2(-35,-2,60,4),Color(.20,.22,.19,shadow_alpha))
		draw_rect(Rect2(-29,-4,48,8),Color(.20,.22,.19,shadow_alpha*.5))
		draw_set_transform(Vector2.ZERO)
	if selected:
		draw_arc(selection_offset,24 if species=="garden_eel" else extent.x*0.6,0.12,PI-0.12,30,Color(0.76,0.88,0.82,0.75),1,false)
