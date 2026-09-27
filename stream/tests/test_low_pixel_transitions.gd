extends SceneTree
var checks:=0
var failures: Array[String]=[]
func check(ok: bool, label: String) -> void:
 checks+=1
 if not ok: failures.append(label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
 for species: String in ["yellow_tang","green_chromis","lawnmower_blenny","purple_firefish"]:
  var rig=load("res://artifacts/new-model-motion-review/before_rig.gd").new() if "--before" in OS.get_cmdline_user_args() else ReefRig.new()
  rig.species=species
  root.add_child(rig)
  rig.apply_actor({"activity":"Cruising","heading":0.,"speed":40.,"thrust":1.,"extend":1.})
  for i in 30: rig.animate(1./30)
  rig.apply_actor({"activity":"Resting","heading":0.,"speed":0.,"thrust":0.,"extend":1.})
  var old_tail: float=rig.fish_material.get_shader_parameter("tail_drive")
  rig.animate(1./30)
  check(float(rig.fish_material.get_shader_parameter("sleep_amount"))<.5,species+" sleep eases")
  if species=="green_chromis": check(float(rig.fish_material.get_shader_parameter("tail_drive"))>old_tail*.5,"Resting tail decays smoothly")
  check(rig.get("breath_clock")!=null,"Breathing has continuous phase")
  check(rig.get("target_body_scale")!=null,"Growth has an independent target")
  if rig.get("target_body_scale")!=null:
   rig.set("target_body_scale",.5)
   rig.animate(1./30)
   check(rig.body_scale>.9,"Growth does not snap")
  var held: Array=[rig.body_scale,rig.get("sleep_blend"),rig.get("shadow_alpha"),rig.get("eye_clock"),rig.effort]
  rig.animate(0)
  check(held==[rig.body_scale,rig.get("sleep_blend"),rig.get("shadow_alpha"),rig.get("eye_clock"),rig.effort],species+" pause freezes growth sleep shadow eye effort")
  rig.apply_actor({"activity":"Cruising","heading":0.,"speed":40.,"thrust":1.,"extend":1.,"vx":20.,"vy":0.})
  for i in 30: rig.animate(1./30)
  rig.begin_death()
  for i in 60: rig.animate(1./30)
  check(rig.effort<.002 and rig.pectoral_effort<.002 and float(rig.fish_material.get_shader_parameter("tail_drive"))<.002,species+" death stops propulsion")
  rig.free()
 var fire=load("res://artifacts/new-model-motion-review/before_rig.gd").new() if "--before" in OS.get_cmdline_user_args() else ReefRig.new()
 fire.species="purple_firefish"
 root.add_child(fire)
 fire.body_scale=.5
 fire.scale=Vector2.ONE*.5
 fire.apply_actor({"activity":"Hovering","heading":0.,"extend":1.,"hover_y":45.})
 fire.animate(1./30)
 check(is_equal_approx(fire.portal.scale.x*fire.body_scale,1.),"Juvenile portal retains adult world radius")
 fire.apply_actor({"activity":"Hiding","heading":0.,"extend":0.,"hover_y":45.})
 for i in 4: fire.animate(1./30)
 check(absf(fire.visual_pitch)<.8,"Burrow turn does not snap nose-down in 0.13 seconds")
 fire.apply_actor({"activity":"Hovering","heading":0.,"extend":1.,"hover_y":45.,"flick":1.})
 var rebound:=false
 for i in 90:
  fire.animate(1./30)
  rebound=rebound or fire.ray_flick<-.005
 check(rebound,"Dorsal spring rebounds after its peak")
 fire.free()
 var tang=load("res://artifacts/new-model-motion-review/before_rig.gd").new() if "--before" in OS.get_cmdline_user_args() else ReefRig.new()
 tang.species="yellow_tang"
 root.add_child(tang)
 tang.apply_actor({"activity":"Cruising","heading":0.,"pitch":0.,"speed":20.,"thrust":.5})
 for i in 30: tang.animate(1./30)
 tang.apply_actor({"activity":"Grazing","heading":0.,"pitch":0.,"contact_x":61.,"contact_y":6.,"roll":0.})
 tang.animate(1./30)
 check(tang.visual_pitch>0 and tang.visual_pitch<.05,"Tang contact pitch eases on first grazing frame")
 tang.free()
 var stage:=StreamStage.new()
 root.add_child(stage)
 var world:=StreamWorld.new(42,1000)
 stage.apply_snapshot(world.snapshot())
 stage.hide()
 var held_clock: float=stage.water_clock
 stage.animate(1)
 check(stage.water_clock==held_clock,"Hidden stage stops all animation clocks")
 stage.free()
 print(JSON.stringify({"checks":checks,"failures":failures}))
 quit(0 if failures.is_empty() else 1)
