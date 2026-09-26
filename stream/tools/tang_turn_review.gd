extends SceneTree
# Deterministic presentation-only turn probe. No ecological world or persistence.
const CANDIDATE=preload("res://tools/art_candidates/tang_volume_candidate.gd")
const OUTPUT="res://artifacts/tang-volume-review/"
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
   var rig=ReefRig.new() if row==0 else CANDIDATE.new()
   rig.species="yellow_tang"
   rig.position=Vector2(270+col*440,200+row*330)
   rig.scale=Vector2.ONE*(1.65 if col else 1.0)
   viewport.add_child(rig)
   rigs.append(rig)
   var label:=Label.new()
   label.position=Vector2(100+col*440,40+row*330)
   label.text=("CURRENT" if row==0 else "VOLUME PROTOTYPE")+ (" · 1.65x" if col else " · 1x")
   viewport.add_child(label)
 for frame in 240:
  var t: float=frame/30.0
  var heading: float=PI*smoothstep(1,3,t) if t<4 else PI*(1-smoothstep(5,7,t))
  var actor: Dictionary={"heading":heading,"direction":1 if cos(heading)>=0 else -1,"activity":"Cruising","speed":0.0,"thrust":0.0,"turn":0.0}
  for rig in rigs:
   rig.face_target=actor.direction
   rig.apply_actor(actor)
   rig.animate(1.0/30)
  await process_frame
  RenderingServer.force_draw(false)
  viewport.get_texture().get_image().save_png(OUTPUT+"frame-%04d.png"%frame)
 print("Recorded 240 frames: stationary turn isolates silhouette, no simulation or saves")
 quit()
