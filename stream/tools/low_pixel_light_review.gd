extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
 var view:=SubViewport.new()
 view.size=Vector2i(1000,750)
 view.render_target_update_mode=SubViewport.UPDATE_ALWAYS
 root.add_child(view)
 for row in 3:
  var panel:=SubViewport.new()
  panel.size=Vector2i(1000,250)
  panel.render_target_update_mode=SubViewport.UPDATE_ALWAYS
  view.add_child(panel)
  var bg:=ColorRect.new()
  bg.size=Vector2(1000,250)
  bg.color=Color("28535b")
  panel.add_child(bg)
  var index:=0
  for species: String in ["yellow_tang","purple_firefish","lawnmower_blenny","green_chromis"]:
   var rig:=ReefRig.new()
   rig.species=species
   rig.detached=true
   rig.position=Vector2(140+index*245,160)
   rig.body_scale=1.65
   panel.add_child(rig)
   rig.apply_actor({"activity":"Perching","heading":0.,"extend":1.,"hover_y":0.})
   rig.animate(.1)
   index+=1
  var light:=CanvasModulate.new()
  light.color=Color.WHITE if row==0 else Color(.30,.44,.56) if row==1 else Color(.916,.915,.877)
  panel.add_child(light)
  var display:=TextureRect.new()
  display.position=Vector2(0,row*250)
  display.texture=panel.get_texture()
  display.size=Vector2(1000,250)
  view.add_child(display)
  var label:=Label.new()
  label.position=Vector2(20,row*250+15)
  label.text=["DAY / 1.65x","NIGHT / 1.65x","VIEWING LIGHT / 1.65x"][row]
  view.add_child(label)
 await process_frame
 RenderingServer.force_draw(false)
 view.get_texture().get_image().save_png("res://artifacts/new-model-motion-review/light-review.png")
 quit()
