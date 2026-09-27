extends Node2D
# Standalone art/motion study. Scripted presentation paths, never StreamWorld or persistence.
const Aquascape=preload("res://scripts/reef_aquascape.gd")
var habitat: ReefAquascape
var rigs: Array[ReefRig]=[]
var clock: float=0
var paused: bool=false
var auto_advance: bool=true
var previous_positions: Array[Vector2]=[]
var previous_headings: Array[float]=[]
var frames: int=0
var contact_samples: int=0

func _ready() -> void:
 if auto_advance:
  Engine.max_fps=30
  get_window().size=Vector2i(1280,720)
  get_window().content_scale_size=Vector2i(1280,720)
 habitat=Aquascape.new()
 add_child(habitat)
 for i in 11:
  var rig:=ReefRig.new()
  rig.species="green_chromis" if i<7 or i==10 else "yellow_tang" if i==7 else "purple_firefish" if i==8 else "lawnmower_blenny"
  rig.individual_id=i+1
  rig.position=_path(i,0)
  rig.z_index=0
  rig.action_tempo=1.25
  if i==9: rig.body_scale=.83
  add_child(rig)
  rigs.append(rig)
  previous_positions.append(rig.position)
  previous_headings.append(0)
  _pose(i,0,0)

func _process(delta: float) -> void:
 if auto_advance and get_window().mode!=Window.MODE_MINIMIZED: advance(minf(delta,.05))

func _unhandled_key_input(event: InputEvent) -> void:
 if event is InputEventKey and event.pressed:
  if event.keycode==KEY_SPACE: paused=not paused
  elif event.keycode==KEY_ESCAPE: get_tree().quit()

func advance(delta: float) -> void:
 if delta<=0 or paused or not is_visible_in_tree(): return
 clock+=delta
 var swimmers: Array=[]
 for i in rigs.size():
  _pose(i,clock,delta)
  swimmers.append({"at":rigs[i].selection_position(),"velocity":(rigs[i].position-previous_positions[i])/maxf(delta,.001)})
  previous_positions[i]=rigs[i].position
 habitat.set_swimmers(swimmers)
 habitat.advance(delta)
 if habitat.plants.any(func(plant: AquascapePlant)->bool: return plant.contact_strength>.05): contact_samples+=1
 frames+=1

func _path(i: int, t: float) -> Vector2:
 if i==10: return Vector2(230+155*cos(t*.17+1.1),375+65*sin(t*.17+1.1))
 if i<6:
  var a: float=t*.105+2.25-i*.018
  var centre:=Vector2(660+250*cos(a),293+sin(a*1.4)*49)
  return centre+Vector2((i%3-1)*64,(i/3.0-.85)*29+sin(t*.48+i)*3)
 if i==6:
  # A small individual travels through the arch opening, behind its stone rim.
  return Vector2(1060+132*cos(t*.145+2.8),503+sin(t*.145+2.8)*20)
 if i==7:
  return Vector2(654+302*cos(t*.072+.5),355+sin(t*.072+.5)*64)
 if i==8: return Vector2(677,655)
 # Three substrate hops then a quiet graze; no horizontal sliding during the rests.
 var cycle: float=fmod(t,12)
 var reverse: bool=fmod(t,24)>=12
 var x: float=608 if reverse else 548
 var way: float=-1 if reverse else 1
 if cycle<3:
  var hop: float=floor(cycle)
  x+=way*(hop*20+20*smoothstep(0,.52,fmod(cycle,1)))
 else: x=548 if reverse else 608
 return Vector2(x,652)

func _pose(i: int, t: float, delta: float) -> void:
 var rig: ReefRig=rigs[i]
 var at: Vector2=_path(i,t)
 var velocity: Vector2=(_path(i,t+.04)-at)/.04
 var heading: float=atan2(absf(velocity.y),velocity.x) if velocity.length()>.1 else previous_headings[i]
 var actor: Dictionary={"activity":"Schooling" if i<7 else "Cruising","heading":heading,"direction":1 if cos(heading)>=0 else -1,"pitch":clampf(atan2(velocity.y,absf(velocity.x)),-.35,.35),"speed":velocity.length(),"thrust":.28+.22*maxf(0,sin(t*3+i*.3)),"turn":(heading-previous_headings[i])/maxf(delta,.033),"roll":0.,"extend":1.,"hover_y":58.,"vx":velocity.x,"vy":velocity.y}
 if i==8:
  actor.activity="Hovering"
  actor.heading=0.
  actor.direction=1
  actor.pitch=sin(t*.7)*.04
  actor.thrust=.15
  actor.flick=1. if fmod(t,11)<.2 else 0.
  # One brisk retreat, then emergence; other actors retain their tranquil cruise.
  if t>=14 and t<16: actor.activity="Hiding"; actor.extend=0.
 elif i==9:
  var cycle: float=fmod(t,12)
  actor.activity="Hopping" if cycle<3 else "Grazing" if cycle<8 else "Perching"
  var turn_time: float=fmod(t,24)
  actor.heading=PI*smoothstep(11.45,11.95,turn_time)*(1-smoothstep(23.45,23.95,turn_time))
  actor.direction=1 if cos(actor.heading)>=0 else -1
  actor.pitch=0.
  actor.thrust=.85 if cycle<3 and fmod(cycle,1)<.18 else 0.
 rig.position=at
 rig.face_target=actor.direction
 # Each new pose starts at the last rendered pose: animation is independent of snapshot timing.
 rig.apply_actor(actor)
 rig.animate(delta if delta>0 else .001)
 previous_headings[i]=heading
