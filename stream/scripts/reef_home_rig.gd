extends "res://scripts/reef_new_cast_rig.gd"
# Species home poses consume the production snapshot without modifying the world.
const H5_SHADER=preload("res://scripts/reef_home_motion.gdshader")
var nestle: float=0
var den_extension: float=1
var lean: float=0
var held_offset:=Vector2.ZERO
var initialized: bool=false

func _ready() -> void:
	super._ready()
	var parameters: Dictionary={}
	for uniform: Dictionary in fish_material.shader.get_shader_uniform_list():
		parameters[uniform.name]=fish_material.get_shader_parameter(uniform.name)
	fish_material.shader=H5_SHADER
	for key: String in parameters: fish_material.set_shader_parameter(key,parameters[key])

func apply_actor(value: Dictionary, pellets: Array=[]) -> void:
	super.apply_actor(value,pellets)
	if not initialized:
		nestle=clampf(float(value.get("nestle",0)),0,1)
		den_extension=clampf(float(value.get("extend",1)),0,1)
		lean=clampf(float(value.get("lean",0)),-.35,.35)
		clasp_blend=1.0 if value.has("hitch_x") and value.has("hitch_y") else 0.0
		initialized=true

func animate(delta: float) -> void:
	if delta<=0: return
	var held: bool=species=="seahorse" and actor.has("hitch_x") and actor.has("hitch_y") and activity in ["Hitched","Feeding","Startled"]
	clasp_target=1.0 if held else 0.0
	super.animate(delta)
	if species=="clownfish":
		nestle=move_toward(nestle,clampf(float(actor.get("nestle",0)),0,1),delta*(1.6 if activity=="Sheltering" else .8))
		var home:=Vector2(actor.get("home_x",position.x),actor.get("home_y",position.y))
		visual_offset+=(home-position).limit_length(12)*nestle/maxf(body_scale,.1)+Vector2(0,22*nestle)
		if activity in ["Nestling","Sheltering","Sleeping"]:
			visual_pitch+=sin(phase*2.1)*.11*(1-nestle*.85)
			visual_offset.x+=sin(phase*1.3)*2.0*(1-nestle*.7)
	elif species=="seahorse":
		lean=lerp_angle(lean,clampf(float(actor.get("lean",0)),-.35,.35),1-exp(-delta*5))
		var grip: Vector2=ReefFishArt.anchor_offset(species,"grip")*Vector2(facing,1)
		if held:
			var hitch:=Vector2(actor.hitch_x,actor.hitch_y)
			held_offset=(hitch-position)/maxf(body_scale,.1)-grip
		else: held_offset=held_offset.lerp(Vector2.ZERO,1-exp(-delta*5))
		visual_offset=held_offset
		visual_pitch=lean
	elif species=="royal_gramma":
		den_extension=move_toward(den_extension,clampf(float(actor.get("extend",1)),0,1),delta/0.8)
		var has_den: bool=actor.has("den_x") and actor.has("den_y")
		var rock_home: bool=actor.get("home",{}).get("kind","")=="rock"
		fish_material.set_shader_parameter("den_clip",has_den and not rock_home and den_extension<.999)
		if has_den:
			var den:=Vector2(actor.den_x,actor.den_y)
			var side: float=-1.0 if float(actor.get("den_side",1))<0 else 1.0
			var inside:=den-Vector2(side*extent.x*.85*body_scale,0)
			visual_offset=(inside-position)*(1-smoothstep(0,1,den_extension))/maxf(body_scale,.1) if not rock_home else Vector2.ZERO
			fish_material.set_shader_parameter("den_point",(den-position)/maxf(body_scale,.1)-Vector2(side*8,0))
			fish_material.set_shader_parameter("den_side",side)
			body_visible=den_extension>0 if not rock_home else true
	fish_material.set_shader_parameter("pose_offset",visual_offset)
	fish_material.set_shader_parameter("pitch",visual_pitch)

func tail_contact() -> Vector2:
	# Shader rotates about this fixed, mirrored point when clasp==1.
	var grip:=ReefFishArt.anchor_offset("seahorse","grip")*Vector2(facing,1)
	return position+(visual_offset+grip)*body_scale
