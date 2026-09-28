extends SceneTree
var OUT="res://artifacts/aquascape-preview/"
func _initialize() -> void: call_deferred("run")
func run() -> void:
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--output="): OUT=arg.trim_prefix("--output=").trim_suffix("/")+"/"
 Engine.max_fps=0
 var view:=SubViewport.new()
 view.size=Vector2i(1280,720)
 view.render_target_update_mode=SubViewport.UPDATE_ALWAYS
 root.add_child(view)
 var scene=load("res://tools/aquascape_preview.gd").new()
 scene.auto_advance=false
 view.add_child(scene)
 var count: int=720
 if "--still" in OS.get_cmdline_user_args(): count=1
 DirAccess.make_dir_recursive_absolute(OUT+"frames")
 var started: int=Time.get_ticks_msec()
 for frame in count:
  scene.advance(1./30)
  await process_frame
  RenderingServer.force_draw(false)
  var img: Image=view.get_texture().get_image()
  if frame==0 or frame==360: img.save_png(OUT+"preview-%02d.png"%(frame/30))
  img.save_jpg(OUT+"frames/frame-%04d.jpg"%frame,.93)
 FileAccess.open(OUT+"capture.json",FileAccess.WRITE).store_string(JSON.stringify({"frames":count,"fps":30,"resolution":[1280,720],"seconds":count/30.,"wall_seconds":(Time.get_ticks_msec()-started)/1000.,"fish_plant_contact_peak":scene.habitat.contact_peak,"contact_frames":scene.contact_samples,"route_source":"scripted preview; no StreamWorld or persistence"},"  "))
 print("CAPTURED "+str(count)+" frames")
 quit()
