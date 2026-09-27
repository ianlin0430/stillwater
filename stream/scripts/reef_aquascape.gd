class_name ReefAquascape
extends Node2D
const BACKGROUND=preload("res://assets/aquascape/shipwreck-background-v1.png")
var clock: float=0
var current: float=0
var plants: Array[AquascapePlant]=[]
var swimmers: Array=[]
var water_material: ShaderMaterial
var bubbles: Node2D
var contact_peak: float=0
# Positions correspond to the 1280x720 concept plate, not backend collision geometry.
const PLANTS=[
 [105,605,"ribbon",220,-3],[390,609,"ribbon",240,-3],
 [473,620,"red",112,-3],[1146,627,"ribbon",245,-3],
 [1220,644,"ribbon",207,4],[75,662,"grass",76,4],
 [395,658,"red",102,4],[505,675,"grass",66,4],
 [886,663,"grass",86,4],[978,646,"red",106,4],
 [1090,676,"grass",73,4]]

func _ready() -> void:
 texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
 var background:=Sprite2D.new()
 background.texture=BACKGROUND
 background.centered=false
 background.scale=Vector2(1280,720)/BACKGROUND.get_size()
 background.z_index=-20
 water_material=ShaderMaterial.new()
 water_material.shader=preload("res://scripts/aquascape_water.gdshader")
 background.material=water_material
 add_child(background)
 for i in PLANTS.size():
  var spec: Array=PLANTS[i]
  var plant:=AquascapePlant.new()
  plant.position=Vector2(spec[0],spec[1])
  plant.kind=spec[2]
  plant.height=spec[3]
  plant.z_index=spec[4]
  plant.phase=i*.83
  add_child(plant)
  plants.append(plant)
 # Texture-aligned foreground pieces put the ship and arch in front of passing fish.
 # The arch opening itself is deliberately absent from the occlusion polygons.
 _occluder(PackedVector2Array([Vector2(735,590),Vector2(802,532),Vector2(871,482),Vector2(930,434),Vector2(987,416),Vector2(1012,454),Vector2(998,503),Vector2(1019,562),Vector2(962,609),Vector2(842,609)]))
 _occluder(PackedVector2Array([Vector2(935,437),Vector2(968,392),Vector2(1016,368),Vector2(1070,369),Vector2(1116,409),Vector2(1145,455),Vector2(1116,472),Vector2(1085,435),Vector2(1056,430),Vector2(1030,449),Vector2(1007,480)]))
 _occluder(PackedVector2Array([Vector2(1124,467),Vector2(1152,446),Vector2(1173,492),Vector2(1163,550),Vector2(1104,582),Vector2(1106,545),Vector2(1128,513)]))
 _occluder(PackedVector2Array([Vector2(42,400),Vector2(119,361),Vector2(359,447),Vector2(386,496),Vector2(349,554),Vector2(156,512),Vector2(52,448)]))
 _occluder(PackedVector2Array([Vector2(342,494),Vector2(462,501),Vector2(428,561),Vector2(395,590),Vector2(350,555)]))
 bubbles=Node2D.new()
 bubbles.z_index=2
 bubbles.draw.connect(_draw_bubbles)
 add_child(bubbles)

func _occluder(points: PackedVector2Array) -> void:
 var layer:=Polygon2D.new()
 layer.polygon=points
 layer.texture=BACKGROUND
 var uv:=PackedVector2Array()
 for point: Vector2 in points: uv.append(point*BACKGROUND.get_size()/Vector2(1280,720))
 layer.uv=uv
 layer.z_index=3
 add_child(layer)

func set_swimmers(value: Array) -> void:
 swimmers=value.duplicate(true)

func advance(delta: float) -> void:
 if delta<=0 or not is_visible_in_tree(): return
 clock+=delta
 # A shared slow current with a travelling gust; neighbouring plants respond at different times.
 current=.55*sin(clock*.33)+.25*sin(clock*.71)+.45*pow(maxf(0,sin(clock*.21-.8)),4)
 water_material.set_shader_parameter("clock",clock)
 for i in plants.size():
  var delayed: float=current+sin(clock*.42-i*.36)*.18
  plants[i].advance(delta,delayed,swimmers)
  contact_peak=maxf(contact_peak,plants[i].contact_strength)
 bubbles.queue_redraw()

func bubble_position(index: int) -> Vector2:
 var duration: float=11+float(index%3)
 var t: float=fmod(clock+index*1.73,duration)/duration
 if index>=6: t=clampf(fmod(clock+(index-6)*.65,16)/6,0,1)
 var source:=Vector2(278,445) if index<6 else Vector2(421,537)
 return source+Vector2(sin(t*9+index)*5+current*t*13,-t*(source.y-39))

func _draw_bubbles() -> void:
 for i in 9:
  # The second source releases a small intermittent group from the hull.
  if i>=6 and fmod(clock+(i-6)*.65,16)>6: continue
  var at: Vector2=bubble_position(i).snapped(Vector2(2,2))
  var radius: float=2 if i%3 else 3
  var tint:=Color(.62,.87,.89,.44)
  bubbles.draw_line(at+Vector2(-radius,-1),at+Vector2(-radius,1),tint,1)
  bubbles.draw_line(at+Vector2(radius,-1),at+Vector2(radius,1),tint,1)
  bubbles.draw_line(at+Vector2(-1,-radius),at+Vector2(1,-radius),Color(.83,.97,.96,.67),1)
  bubbles.draw_line(at+Vector2(-1,radius),at+Vector2(1,radius),tint,1)
 # Quiet surface rings above the main stream, with coarse horizontal segments.
 for i in 2:
  var t: float=fmod(clock+i*1.6,3.2)/3.2
  var width: float=6+t*20
  bubbles.draw_line(Vector2(278-width,39),Vector2(278+width,39),Color(.72,.90,.94,(1-t)*.18),2)
