class_name SwimmerRig
extends Node2D

const FISH: Texture2D = preload("res://assets/pixel/fish-atlas.png")
const SHRIMP: Texture2D = preload("res://assets/pixel/shrimp-atlas.png")
const FISH_MOTION: Shader = preload("res://scripts/fish_motion.gdshader")
static var shrimp_parts: Array[AtlasTexture] = []
static var abdomen_parts: Array[AtlasTexture] = []
var species: String = "threadfin"
var individual_id: int = 1
var sex: String = "male"
var activity: String = "Swimming"
var face_target: float = 1
var facing: float = 1
# Fish turns: the head leads and the tail follows, folding the body through a C-bend.
var tail_facing: float = 1
var phase: float = 0
var body_scale: float = 1
var dim: float = 1
var selected: bool = false
var berried: bool = false
var molting: bool = false
var exuvia: bool = false
var motion: float = 0
var previous: Vector2
var fish: Polygon2D
var fish_material: ShaderMaterial
var water_phase: float = 0
var effort: float = 0
var feeding: float = 0
var fin_spread: float = 1
var pitch: float = 0
var escape_age: float = 2
var last_activity: String = ""
var feet: Array[Vector2] = []
var foot_start: Array[Vector2] = []
var foot_end: Array[Vector2] = []
var foot_t: Array[float] = []

static func _region(region: Rect2) -> AtlasTexture:
	var tex:=AtlasTexture.new()
	tex.atlas=SHRIMP
	tex.region=region
	tex.filter_clip=true
	return tex

func _ready() -> void:
	texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	previous=position
	phase=individual_id*0.79
	water_phase=phase
	if shrimp_parts.is_empty():
		for region: Rect2 in [Rect2(61,197,440,223),Rect2(558,190,430,199),Rect2(1182,165,224,271),Rect2(142,716,286,107),Rect2(643,708,265,111),Rect2(1204,679,210,155)]:
			shrimp_parts.append(_region(region))
		for i in 6:
			abdomen_parts.append(_region(Rect2(558+(5-i)*430.0/6,190,430.0/6+1,199)))
	if species!="shrimp":
		_setup_fish()
	else:
		reset_contact()

func reset_contact() -> void:
	previous=position
	if species!="shrimp": return
	feet.clear()
	foot_start.clear()
	foot_end.clear()
	foot_t.clear()
	for i in 10:
		var foot: Vector2=position+Vector2((-12+(i%5)*8)*face_target,13+(i/5)*1.2)*body_scale
		feet.append(foot)
		foot_start.append(foot)
		foot_end.append(foot)
		foot_t.append(1.0)

func _setup_fish() -> void:
	fish=Polygon2D.new()
	fish.texture=FISH
	var region: Rect2
	if species=="threadfin":
		region=Rect2(48,140,711,308) if sex=="male" else Rect2(902,199,572,211)
	else:
		region=Rect2(95,614,613,278) if individual_id%2==0 else Rect2(883,619,570,272)
	var width: float=112 if species=="threadfin" else 97
	var height: float=width*region.size.y/region.size.x
	var vertices:=PackedVector2Array()
	var uvs:=PackedVector2Array()
	var strips: Array[PackedInt32Array]=[]
	# A static mesh; tail, fin and turning deformation runs in the vertex shader.
	for x in 13:
		for y in 7:
			var uv:=Vector2(x/12.0,y/6.0)
			vertices.append((uv-Vector2(0.5,0.5))*Vector2(width,height))
			uvs.append(region.position+uv*region.size)
	for x in 12:
		for y in 6:
			var i: int=x*7+y
			strips.append(PackedInt32Array([i,i+7,i+8,i+1]))
	fish.polygon=vertices
	fish.uv=uvs
	fish.polygons=strips
	fish_material=ShaderMaterial.new()
	fish_material.shader=FISH_MOTION
	fish_material.set_shader_parameter("body_width",width)
	fish_material.set_shader_parameter("body_height",height)
	fish_material.set_shader_parameter("soft_filaments",species=="threadfin" and sex=="male")
	fish.material=fish_material
	add_child(fish)

func animate(delta: float) -> void:
	if delta<=0: return
	phase+=delta
	var velocity: Vector2=(position-previous)/maxf(delta,0.001)
	var old_motion: float=motion
	motion=lerpf(motion,velocity.length(),minf(1,delta*6))
	previous=position
	if activity in ["Retreating","Startled"] and activity!=last_activity:
		escape_age=0
	escape_age+=delta
	last_activity=activity
	var turn_rate: float=2.8 if species!="shrimp" else 2.7
	facing=move_toward(facing,face_target,delta*turn_rate)
	if absf(facing-tail_facing)>=0.95 or facing==face_target:
		tail_facing=move_toward(tail_facing,facing,delta*turn_rate)
	feeding=move_toward(feeding,1.0 if activity in ["Grazing","Feeding","Surface feeding"] else 0.0,delta*3)
	if fish!=null:
		var braking: float=clampf((old_motion-motion)*4,0,1)
		var drive: float=1.0 if activity=="Startled" else clampf(motion/18.0,0,1)
		effort=lerpf(effort,drive,minf(1,delta*4))
		var frequency: float=(0.55+effort*1.9) if species=="threadfin" else (0.4+effort*1.5)
		water_phase+=delta*TAU*frequency
		var spread_target: float=1.18 if activity in ["Displaying","Curious"] else 1.0+braking*0.12-effort*0.08
		fin_spread=lerpf(fin_spread,spread_target,minf(1,delta*3))
		fish_material.set_shader_parameter("swim_phase",water_phase)
		fish_material.set_shader_parameter("feeding",feeding)
		fish_material.set_shader_parameter("amplitude",0.5+effort*3.4)
		fish_material.set_shader_parameter("fin_spread",fin_spread)
		fish_material.set_shader_parameter("fin_flutter",0.25+braking*0.75+feeding*0.3)
		fish_material.set_shader_parameter("head_facing",facing)
		fish_material.set_shader_parameter("tail_facing",tail_facing)
		pitch=lerp_angle(pitch,clampf(velocity.y*0.01,-0.2,0.2)*face_target,delta*3)
		fish.rotation=pitch
		fish.modulate=Color(dim,dim,dim,1)
	else:
		_update_feet(delta)
	queue_redraw()

func _update_feet(delta: float) -> void:
	var swimming: bool=activity in ["Swimming","Settling","Retreating"]
	for i in 10:
		var desired: Vector2=position+Vector2((-12+(i%5)*8)*face_target,13+(i/5)*1.2)*body_scale
		if swimming:
			feet[i]=desired
			foot_t[i]=1
		elif foot_t[i]<1:
			foot_t[i]=minf(1,foot_t[i]+delta*5)
			var t: float=foot_t[i]
			feet[i]=foot_start[i].lerp(foot_end[i],t)+Vector2(0,-sin(t*PI)*3*body_scale)
		elif feet[i].distance_to(desired)>4*body_scale:
			var neighbor: int=(i+1)%5+(5 if i>=5 else 0)
			if foot_t[neighbor]>=0.55:
				foot_start[i]=feet[i]
				foot_end[i]=desired+Vector2(face_target*2,0)*body_scale
				foot_t[i]=0

func _part(index: int, rect: Rect2, point: Vector2, angle: float=0, local_scale: Vector2=Vector2.ONE) -> void:
	draw_set_transform(point,angle,local_scale)
	draw_texture_rect(shrimp_parts[index],rect,false,Color(dim,dim,dim,1))

func _leg(a: Vector2,b: Vector2,width: float,tint: Color) -> void:
	draw_set_transform(a,a.angle_to_point(b))
	draw_texture_rect(shrimp_parts[3],Rect2(0,-width/2,a.distance_to(b)+1,width),false,tint)
	draw_set_transform(Vector2.ZERO)

func _draw() -> void:
	if exuvia:
		var shell:=PackedVector2Array([Vector2(23,-5),Vector2(12,-12),Vector2(-4,-10),Vector2(-33,-4),Vector2(-40,0),Vector2(-31,5),Vector2(-5,8),Vector2(14,5)])
		for i in shell.size(): shell[i].x*=facing
		draw_colored_polygon(shell,Color(0.83,0.84,0.64,0.16))
		shell.append(shell[0])
		draw_polyline(shell,Color(0.91,0.90,0.72,0.9),1.3,false)
		for i in 5:
			var x: float=-6-i*5
			draw_line(Vector2(x*facing,-7),Vector2((x-1)*facing,5),Color(0.91,0.90,0.72,0.7),1,false)
		for i in 4:
			draw_polyline(PackedVector2Array([Vector2((i*5-2)*facing,5),Vector2((i*6-7)*facing,10),Vector2((i*7-10)*facing,13)]),Color(0.91,0.90,0.72,0.7),1,false)
		return
	if species=="shrimp":
		_draw_shrimp()
		draw_set_transform(Vector2.ZERO)
		if molting:
			draw_line(Vector2(-28*tail_facing,-4),Vector2(12*facing,-6),Color(0.94,0.86,0.72,0.45),3,false)
		if berried:
			for i in 9:
				var egg:=Vector2((-19+(i%5)*4)*facing,8+(i/5)*3)
				draw_circle(egg,2.0,Color("a5a653"))
				draw_rect(Rect2(egg-Vector2(1,1),Vector2.ONE),Color("d5ce83"))
	if species=="threadfin" and sex=="male":
		_draw_threadfin_rays()
	if selected:
		draw_set_transform(Vector2.ZERO)
		draw_arc(Vector2.ZERO,52 if species!="shrimp" else 38,0.12,PI-0.12,30,Color(0.76,0.88,0.82,0.8),1,false)

func _draw_threadfin_rays() -> void:
	# Attach to the same deformed spine as the fish mesh; no extra ecological state.
	for side in [-1,1]:
		for ray in 2:
			var points:=PackedVector2Array()
			for i in 17:
				var t: float=float(i)/16.0
				var x: float=17.0-t*(57+ray*7)
				var tail: float=clampf(0.5-x/112.0,0,1)
				var y: float=side*(7.0+sin(t*PI*0.72)*(8+ray*4)*fin_spread)
				y+=sin(water_phase-tail*4.8)*(0.5+effort*3.4)*tail*tail
				y+=sin(tail*PI)*(facing-tail_facing)*48.5*0.18
				y+=sin(water_phase*0.65+t*4+side)*t*1.1
				points.append(Vector2(x*lerpf(facing,tail_facing,tail),y).rotated(pitch))
			draw_polyline(points,Color(0.22*dim,0.30*dim,0.27*dim,0.65),1.8,false)

func _draw_shrimp() -> void:
	if shrimp_parts.is_empty():
		return
	var sx: float=facing
	var swimming: bool=activity in ["Swimming","Settling","Retreating"]
	var flick: float=pow(sin(clampf(escape_age/0.65,0,1)*PI),2.0) if escape_age<0.65 else 0.0
	var curl: float=-1.35*flick+(sin(phase*9)*0.10 if swimming else 0.01*sin(phase*1.4))
	# Grounded alternating feet stop cycling while the animal rests or grazes.
	for side in 2:
		var tint:=Color(dim,dim,dim,1).darkened(0.25 if side==0 else 0)
		for j in 5:
			var i: int=side*5+j
			var root:=Vector2((-6+j*5)*sx,5+side)
			var foot: Vector2=(feet[i]-position)/body_scale
			if swimming:
				foot=root+Vector2((-3+sin(phase*11+j*1.3)*4)*sx,8)
			var knee: Vector2=root.lerp(foot,0.5)+Vector2((j-2)*sx,-2)
			_leg(root,knee,2.0,tint)
			_leg(knee,foot,1.5,tint)
	# Six linked abdominal pieces keep the tail connected during the escape curl.
	# During a turn each segment projects with a facing between head and tail, folding the body.
	var joint:=Vector2(-4,0)
	var px: float=-4*sx
	for i in 6:
		var angle: float=curl*(i+1)/6.0
		var si: float=lerpf(facing,tail_facing,(i+1)/6.0)
		draw_set_transform(Vector2(px,joint.y),angle*si,Vector2(si,1))
		draw_texture_rect(abdomen_parts[i],Rect2(-6.3,-8,7,16),false,Color(dim,dim,dim,1))
		if swimming:
			_part(4,Rect2(-4,0,8,4),Vector2(px,joint.y+7),sin(phase*12+i)*0.45,Vector2(si,1))
		var step: Vector2=Vector2(-5.3,0).rotated(angle)
		px+=step.x*si
		joint+=step
	_part(2,Rect2(-11,-5,12,12),Vector2(px,joint.y),curl*tail_facing,Vector2(tail_facing,1))
	_part(0,Rect2(-13,-13,33,22),Vector2(5*sx,0),0,Vector2(sx,1))
	for i in 2:
		var probe: float=sin(phase*10+i*PI)*feeding
		_part(5,Rect2(0,-1.2,10,2.4),Vector2(15*sx,5+i*2),(0.55+probe*0.3)*sx,Vector2(sx,1))
	draw_set_transform(Vector2.ZERO)
	if feeding>0.05:
		for i in 3:
			draw_line(Vector2(19*sx,3+i),Vector2((22+sin(phase*14+i)*feeding)*sx,6+i),Color("efb090"),1,false)
	for i in 2:
		var antenna:=PackedVector2Array()
		for j in 10:
			var t: float=j/9.0
			antenna.append(Vector2((20+t*(38-i*8))*sx,-5-t*(14-feeding*9)+sin(t*2+phase*(0.7+i*0.16)+i*2)*t*5))
		draw_polyline(antenna,Color(0.85*dim,0.58*dim,0.42*dim,0.9),1.1,false)
