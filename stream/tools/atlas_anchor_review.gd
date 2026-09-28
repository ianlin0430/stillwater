extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
 var view:=SubViewport.new()
 view.size=Vector2i(1536,1024)
 view.render_target_update_mode=SubViewport.UPDATE_ALWAYS
 root.add_child(view)
 var sprite:=Sprite2D.new()
 sprite.texture=ReefRig.ATLAS
 sprite.centered=false
 view.add_child(sprite)
 var overlay:=Node2D.new()
 view.add_child(overlay)
 overlay.draw.connect(func():
  for species: String in ["yellow_tang","purple_firefish","lawnmower_blenny","green_chromis"]:
   var rect: Rect2=ReefRig.LOOK[species].region
   var anchors: Array=[Vector2(.66,.61),Vector2(.83,.46),Vector2(.96,.62)]
   if species=="purple_firefish": anchors=[Vector2(.73,.68),Vector2(.92,.60),Vector2(.99,.65)]
   elif species=="lawnmower_blenny": anchors=[Vector2(.70,.74),Vector2(.90,.35),Vector2(.99,.50)]
   elif species=="green_chromis": anchors=[Vector2(.67,.60),Vector2(.91,.46),Vector2(.99,.54)]
   var line: float=ReefRig.LOOK[species].line
   var gill:=Rect2(rect.position+Vector2(anchors[0].x+.02,line-.10)*rect.size,Vector2(.14,.20)*rect.size)
   overlay.draw_rect(gill,Color(1,.7,.2,.7),false,2)
   overlay.draw_string(ThemeDB.fallback_font,gill.position+Vector2(0,-8),"gill patch",HORIZONTAL_ALIGNMENT_LEFT,-1,16)
   for edge in [-.32,-.08,.08,.32]:
    var y: float=rect.position.y+(line+edge)*rect.size.y
    if y>=rect.position.y and y<=rect.end.y:
     overlay.draw_line(Vector2(rect.position.x,y),Vector2(rect.end.x,y),Color(.8,.5,1,.55),2)
   if species=="purple_firefish":
    var ray:=Rect2(rect.position+Vector2(.35,.05)*rect.size,Vector2(.35,.46)*rect.size)
    overlay.draw_rect(ray,Color.MAGENTA,false,3)
    overlay.draw_string(ThemeDB.fallback_font,ray.position+Vector2(0,-8),"dorsal ray falloff",HORIZONTAL_ALIGNMENT_LEFT,-1,16)
   overlay.draw_rect(rect,Color.WHITE,false,2)
   for i in 3:
    var at: Vector2=rect.position+anchors[i]*rect.size
    overlay.draw_circle(at,5,[Color.CYAN,Color.RED,Color.GREEN][i])
    overlay.draw_string(ThemeDB.fallback_font,at+Vector2(7,-8),["fin root","eye","mouth"][i],HORIZONTAL_ALIGNMENT_LEFT,-1,18)
 )
 await process_frame
 RenderingServer.force_draw(false)
 view.get_texture().get_image().save_png("res://artifacts/new-model-motion-review/atlas-anchors.png")
 quit()
