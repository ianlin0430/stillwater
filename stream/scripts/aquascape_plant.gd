class_name AquascapePlant
extends Node2D
# Native pixel geometry, rooted in place. Presentation only: local clocks, no RNG or saves.
var kind: String="ribbon"
var height: float=170
var phase: float=0
var wind_bend: float=0
var response: float=0
var response_velocity: float=0
var material_state: ShaderMaterial
var contact_strength: float=0
var plant_clock: float=0

func _ready() -> void:
 texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
 material_state=ShaderMaterial.new()
 material_state.shader=preload("res://scripts/aquascape_plant.gdshader")
 material_state.set_shader_parameter("height",height)
 material_state.set_shader_parameter("phase",phase)
 material=material_state
 queue_redraw()

func advance(delta: float, current: float, swimmers: Array) -> void:
 if delta<=0 or not is_visible_in_tree(): return
 plant_clock+=delta
 var desired: float=0
 var mid: Vector2=position-Vector2(0,height*.55)
 for swimmer: Dictionary in swimmers:
  var at: Vector2=swimmer.at
  var distance: float=at.distance_to(mid)
  if distance<85:
   var influence: float=pow(1-distance/85,2)
   var v: Vector2=swimmer.velocity
   desired+=clampf(v.x*.18+(mid.x-at.x)*.10,-12,12)*influence
 contact_strength=absf(desired)
 # Stable, softly damped return. Bounded substeps avoid spikes after a delayed frame.
 var remaining: float=minf(delta,.1)
 while remaining>0:
  var dt: float=minf(remaining,1.0/60)
  response_velocity+=(desired-response)*28*dt-response_velocity*8*dt
  response+=response_velocity*dt
  remaining-=dt
 wind_bend=lerpf(wind_bend,current*(21 if kind=="ribbon" else 10),1-exp(-delta*2))
 material_state.set_shader_parameter("clock",plant_clock)
 material_state.set_shader_parameter("bend",wind_bend+response)

func _draw() -> void:
 if kind=="red":
  for branch in 7:
   var base:=Vector2((branch-3)*5,0)
   var tip:=Vector2((branch-3)*12,-height*(.6+float(branch%3)*.18))
   _ribbon(base,tip,14,Color("795e77") if branch%2 else Color("a5788c"))
   for j in 4:
    var t: float=.28+j*.15
    var root: Vector2=base.lerp(tip,t)
    var direction: float=-1 if (j+branch)%2 else 1
    _ribbon(root,root+Vector2(direction*(14+j*2),-24),12,Color("be91a0"))
 else:
  var palette: Array[Color]=[Color("386f70"),Color("578c80"),Color("7aa58f"),Color("9ab7a0")]
  for blade in (7 if kind=="grass" else 6):
   var h: float=height*(.57+float((blade*3)%7)*.07)
   var lean: float=(blade-2.5)*(12 if kind=="ribbon" else 7)
   _ribbon(Vector2((blade-2.5)*4,0),Vector2(lean,-h),28 if kind=="ribbon" else 12,palette[blade%3])
   if kind=="ribbon":
    _ribbon(Vector2((blade-2.5)*4+2,-3),Vector2(lean+2,-h+8),6,palette[3]*Color(1,1,1,.65))

func _ribbon(base: Vector2, tip: Vector2, width: float, tint: Color) -> void:
 var points:=PackedVector2Array()
 var segments: int=mini(11,maxi(2,int(absf(tip.y-base.y)/4)))
 for side in 2:
  for k in segments+1:
   var t: float=float(k)/segments if side==0 else float(segments-k)/segments
   var centre: Vector2=base.lerp(tip,t)
   centre.x+=sin(t*4.5+phase)*width*.45*t
   var half_width: float=maxf(2,width*(1-t)*.55)
   points.append((centre+Vector2(half_width*(-1 if side==0 else 1),0)).snapped(Vector2(2,2)))
 # Shared tip duplicates must be removed before tessellation.
 var clean:=PackedVector2Array()
 for point: Vector2 in points:
  if clean.is_empty() or clean[-1]!=point: clean.append(point)
 if clean.size()>2 and clean[-1]==clean[0]: clean.remove_at(clean.size()-1)
 if clean.size()>=3: draw_colored_polygon(clean,tint)
