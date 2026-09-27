extends SceneTree
const OUT="res://artifacts/new-model-motion-review/"
var before_script: Script=load(OUT+"before_rig.gd")
func _initialize() -> void: call_deferred("run")
func run() -> void:
 Engine.max_fps=0
 for species: String in ["lawnmower_blenny","purple_firefish","green_chromis","yellow_tang"]:
  if not OS.get_cmdline_user_args().is_empty() and species!=OS.get_cmdline_user_args()[0]: continue
  await record(species)
 quit()
func record(species: String) -> void:
 var view:=SubViewport.new()
 view.size=Vector2i(900,640)
 view.render_target_update_mode=SubViewport.UPDATE_ALWAYS
 root.add_child(view)
 var rigs: Array=[]
 var groups: Array=[]
 var panels: Array=[]
 var labels: Array=[]
 var event_layers: Array=[]
 for side in 2:
  var panel:=SubViewport.new()
  panel.size=Vector2i(900,320)
  panel.render_target_update_mode=SubViewport.UPDATE_ALWAYS
  view.add_child(panel)
  panels.append(panel)
  var bg:=ColorRect.new()
  bg.size=Vector2(1400,900)
  bg.color=Color("224f56")
  panel.add_child(bg)
  var sand:=ColorRect.new()
  sand.position=Vector2(0,StreamWorld.floor_y(640) if species=="lawnmower_blenny" else 550)
  sand.size=Vector2(1400,300)
  sand.color=Color("bdaf8b")
  panel.add_child(sand)
  var rig=before_script.new() if side==0 else ReefRig.new()
  rig.species=species
  rig.individual_id=4
  rig.position=Vector2(640,550 if species in ["lawnmower_blenny","purple_firefish"] else 320)
  panel.add_child(rig)
  rigs.append(rig)
  var events=load(OUT+"before_events.gd").new() if side==0 else load("res://scripts/stream_events.gd").new()
  panel.add_child(events)
  event_layers.append(events)
  var others: Array=[]
  if species in ["yellow_tang","green_chromis"]:
   for k in (1 if species=="yellow_tang" else 3):
    var extra=before_script.new() if side==0 else ReefRig.new()
    extra.species="green_chromis"
    extra.individual_id=10+k
    panel.add_child(extra)
    others.append(extra)
  groups.append(others)
  var display:=TextureRect.new()
  display.texture=panel.get_texture()
  display.position=Vector2(0,side*320)
  display.size=Vector2(900,320)
  view.add_child(display)
  var label:=Label.new()
  label.position=Vector2(16,side*320+10)
  label.add_theme_font_size_override("font_size",17)
  view.add_child(label)
  labels.append(label)
 var w:=StreamWorld.new(42,1000)
 var c: Dictionary=w.state.animals.filter(func(a):return a.species=="green_chromis")[0]
 var tang: Dictionary=w.state.animals.filter(func(a):return a.species=="yellow_tang")[0]
 w.state.animals=[c,tang]
 w.state.ecology_remainder=-1e9
 w.state.light_hour=1.
 c.merge({"x":640.,"y":320.,"tx":640.,"ty":320.,"vx":0.,"vy":0.,"activity":"Resting","decision_at":1e9,"heading":PI,"direction":-1.,"speed":0.,"thrust":0.,"pitch":0.,"turn":0.},true)
 tang.merge({"x":380.,"y":320.,"tx":1060.,"ty":320.,"vx":20.,"vy":0.,"activity":"Cruising","decision_at":1e9,"heading":0.,"direction":1.,"speed":20.,"thrust":.3,"pitch":0.,"turn":0.},true)
 var duration: int=38 if species=="yellow_tang" else 22
 var path: String=OUT+species+"/"
 DirAccess.make_dir_recursive_absolute(path)
 var trace: Array=[]
 for frame in duration*30:
  var t: float=frame/30.
  var row: Dictionary={"activity":"Cruising","heading":0.,"direction":1.,"speed":20.,"thrust":.5,"pitch":0.,"turn":0.,"roll":0.,"extend":1.,"hover_y":45.,"flick":0.,"vx":0.,"vy":0.}
  var at:=Vector2(640,320)
  var chapter: String=""
  var bite: bool=false
  match species:
   "lawnmower_blenny":
    at=Vector2(640,550)
    if t<5:
     chapter="Complete hops + queued stronger thrust"
     row.activity="Hopping"
     row.thrust=1. if fmod(t,.9)<.2 else 0.
     at.x+=t*12
    elif t<9: chapter="Graze / lift head"; row.activity="Grazing"; row.thrust=0.; row.speed=0.
    elif t<12: chapter="Food peck / quiet eye glance"; row.activity="Perching"; row.thrust=0.; row.speed=0.; bite=frame==300
    elif t<16:
     chapter="Arrival: actual event presentation along substrate"
     row.activity="Hopping"
     row.thrust=1. if fmod(t-12,.9)<.2 else 0.
     at.x=640
    else:
     chapter="Perch turn / sleep transition / contact shadow"
     row.activity="Perching" if t<18 else "Sleeping"; row.thrust=0.; row.speed=0.
     row.heading=PI*smoothstep(16,18,t); row.turn=PI/2 if t<18 else 0.
   "purple_firefish":
    at=Vector2(640,550)
    row.activity="Hovering"; row.thrust=.15; row.speed=0.; row.pitch=sin(t)*.045
    if t<3: chapter="Hover / dorsal spring"; row.flick=1. if t>=1 and t<1.2 else 0.
    elif t<5: chapter="Startle: accelerate into burrow"; row.activity="Hiding"; row.extend=0.; row.thrust=1. if t<3.2 else 0.
    elif t<8: chapter="Head-first emergence"
    elif t<10: chapter="Night entry: calmer option"; row.activity="Sleeping"; row.extend=0.; row.thrust=1. if t<8.2 else 0.
    elif t<10.6: chapter="Emergence begins"
    elif t<14: chapter="Interrupted emergence: finish, then re-enter"; row.activity="Hiding"; row.extend=0.
    elif t<18: chapter="Return / reach toward food"; bite=frame==495
    else: chapter="Juvenile growth / adult-size portal"
   "green_chromis":
    chapter="School: push and coast / head-led turn"
    row.activity="Schooling"; row.heading=PI*smoothstep(2,5,t); row.turn=PI/3 if t>2 and t<5 else 0.; row.thrust=1. if fmod(t,1.4)<.4 else 0.
    if t>=7 and t<11: chapter="Rest: tail eases out, no side-slip"; row.activity="Resting"; row.speed=0.; row.thrust=0.
    elif t>=11 and t<16: chapter="Startle dispersal then gentle regroup"; row.activity="Startled"; row.thrust=1. if t<12 else .15; row.speed=50. if t<12 else 15.
    elif t>=16 and t<19: chapter="Curious / food bite"; row.activity="Curious"; row.thrust=.1; bite=frame==525
    elif t>=19: chapter="Death: propulsion fades with body"; row.thrust=1.; row.speed=40.
   "yellow_tang":
    if t<26:
     chapter="Actual backend: tang arcs around resting chromis"
     w.advance_live(1./30)
     row=tang.duplicate(true)
     at=Vector2(tang.x,tang.y)
    elif t<30:
     chapter="Decelerate / open braking fins (controlled pose)"
     row.speed=20*(1-smoothstep(26,30,t)); row.thrust=.15
     at=Vector2(640+(t-26)*5,320)
    elif t<34:
     chapter="Profile grazing: roll, nod and bite share rhythm"
     row.activity="Grazing"; row.speed=0.; row.thrust=0.; row.roll=(.5+.5*sin((t-30)*TAU/1.6))*.22
     row.contact_x=701.; row.contact_y=323.
    else:
     chapter="Wide turn: side / intermediate / front"
     row.heading=PI*smoothstep(34,38,t); row.turn=PI/4
  row.direction=1. if cos(row.heading)>=0 else -1.
  for side in 2:
   var rig=rigs[side]
   rig.modulate.a=1.0
   rig.position=at
   rig.face_target=row.direction
   if frame%6==0: rig.apply_actor(row)
   if bite:
    if side==0: rig.consume_food()
    else: rig.consume_food({"food_x":690.,"food_y":495.})
   if species=="purple_firefish" and frame==540:
    rig.body_scale=.5
    rig.scale=Vector2.ONE*.5
    if side==1: rig.target_body_scale=1.
   if species=="green_chromis" and frame==570: rig.begin_death()
   if species=="lawnmower_blenny":
    rig.position.y=StreamWorld.floor_y(rig.position.x)
    if frame==360: event_layers[side].fades[4]={"age":0.,"duration":2.,"kind":"arrival","side":-1.}
    if event_layers[side].fades.has(4): event_layers[side].advance(1./30,0.,{4:rig})
   rig.animate(1./30)
   if species=="green_chromis" and t>=19: rig.modulate.a=maxf(0,1-(t-19)/2)
   for k in groups[side].size():
    var extra=groups[side][k]
    extra.visible=not (species=="yellow_tang" and t>=26)
    extra.position=Vector2(c.x,c.y) if species=="yellow_tang" else at+Vector2(-85-k*70,35 if k%2 else -35)
    var other: Dictionary=c.duplicate(true) if species=="yellow_tang" else row.duplicate(true)
    if species=="green_chromis" and t>=11 and t<16:
     extra.position+=Vector2((k-1)*35,-25 if k%2 else 25)*sin((t-11)/5*PI)
    extra.face_target=other.direction
    if frame%6==0: extra.apply_actor(other)
    extra.animate(1./30)
   var camera:=Vector2(640,515 if species in ["purple_firefish","lawnmower_blenny"] else 340)
   if species=="lawnmower_blenny": camera.y=StreamWorld.floor_y(640)-35
   if species=="yellow_tang" and t<26: camera.x=(at.x+640)/2
   panels[side].canvas_transform=Transform2D(Vector2(1.65,0),Vector2(0,1.65),Vector2(450,180)-camera*1.65)
   labels[side].text=("BEFORE" if side==0 else "AFTER")+"  |  "+species+"  |  1.65x\n"+chapter
  if frame%6==0: trace.append({"t":t,"chapter":chapter,"actor":row,"x":at.x,"y":at.y})
  await process_frame
  RenderingServer.force_draw(false)
  view.get_texture().get_image().save_jpg(path+"frame-%04d.jpg"%frame,.92)
 FileAccess.open(path+"trace.json",FileAccess.WRITE).store_string(JSON.stringify(trace))
 view.free()
 print("RECORDED "+species)
