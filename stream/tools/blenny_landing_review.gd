extends SceneTree
# Deterministic presentation-only turn probe. No ecological world or persistence.
const BEFORE=preload("res://artifacts/blenny-landing-review/before_rig.gd")
const OUTPUT="res://artifacts/blenny-landing-review/"
func _initialize() -> void: call_deferred("run")
func run() -> void:
 Engine.max_fps=30
 DirAccess.make_dir_recursive_absolute(OUTPUT)
 var viewport:=SubViewport.new()
 viewport.size=Vector2i(960,720)
 viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
 viewport.transparent_bg=false
 root.add_child(viewport)
 var background:=ColorRect.new()
 background.size=Vector2(960,720)
 background.color=Color("23535b")
 viewport.add_child(background)
 var rigs: Array=[]
 for row in 2:
  for col in 2:
   var rig=BEFORE.new() if row==0 else ReefRig.new()
   rig.species="lawnmower_blenny"
   rig.position=Vector2(270+col*440,200+row*330)
   rig.scale=Vector2.ONE*(1.65 if col else 1.0)
   viewport.add_child(rig)
   rigs.append(rig)
   var label:=Label.new()
   label.position=Vector2(100+col*440,40+row*330)
   label.text=("BEFORE" if row==0 else "CONTINUOUS LANDING")+ (" · 1.65x" if col else " · 1x")
   viewport.add_child(label)
 for frame in 90:
  var t: float=frame/30.0
  var thrust: float=0.0
  var speed: float=0.0
  if frame>=15 and frame<23: thrust=0.5; speed=30.0
  if frame==23: thrust=1.0; speed=30.0
  var actor: Dictionary={"heading":0.0,"direction":1,"activity":"Hopping" if speed>0 else "Perching","speed":speed,"thrust":thrust}
  for rig in rigs:
   rig.face_target=actor.direction
   rig.apply_actor(actor)
   rig.animate(1.0/30)
  await process_frame
  RenderingServer.force_draw(false)
  viewport.get_texture().get_image().save_png(OUTPUT+"frame-%04d.png"%frame)
 print("Recorded 90 frames: mid-air thrust increase then immediate stop; no saves")
 quit()
