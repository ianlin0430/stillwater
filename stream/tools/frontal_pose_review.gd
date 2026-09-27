extends SceneTree
# Approval board only: no simulation, persistence, or production asset replacement.
const FRONT=preload("res://tools/art_candidates/reef-front-v1.png")
const RECTS=[Rect2(273,56,313,455),Rect2(974,55,294,457),Rect2(198,593,468,329),Rect2(935,559,370,402)]
const SPECIES=["yellow_tang","purple_firefish","lawnmower_blenny","green_chromis"]
func _initialize() -> void: call_deferred("run")
func run() -> void:
 var view:=SubViewport.new()
 view.size=Vector2i(1000,720)
 view.render_target_update_mode=SubViewport.UPDATE_ALWAYS
 root.add_child(view)
 var bg:=ColorRect.new()
 bg.size=Vector2(1000,720)
 bg.color=Color("23535b")
 view.add_child(bg)
 var shader:=Shader.new()
 shader.code="shader_type canvas_item; void fragment(){ vec4 t=texture(TEXTURE,UV); if(t.a<.86) discard; COLOR=vec4(t.rgb,smoothstep(.86,.97,t.a)); }"
 for i in 4:
  var cfg: Dictionary=ReefRig.LOOK[SPECIES[i]]
  var height: float=cfg.width*cfg.region.size.y/cfg.region.size.x
  var label:=Label.new()
  label.position=Vector2(20,55+i*160)
  label.text=SPECIES[i]
  view.add_child(label)
  for col in 4:
   var sprite:=Sprite2D.new()
   var front: bool=col%2==1
   sprite.texture=FRONT if front else ReefRig.ATLAS
   sprite.region_enabled=true
   sprite.region_rect=RECTS[i] if front else cfg.region
   sprite.position=Vector2(265+col*195,110+i*160)
   sprite.scale=Vector2.ONE*height/sprite.region_rect.size.y*(1.65 if col>=2 else 1.0)
   sprite.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
   sprite.material=ShaderMaterial.new()
   sprite.material.shader=shader
   view.add_child(sprite)
 for i in 4:
  var label:=Label.new()
  label.position=Vector2(215+i*195,10)
  label.text=["Approved · 1x","Draft front · 1x","Approved · 1.65x","Draft front · 1.65x"][i]
  label.add_theme_font_size_override("font_size",14)
  view.add_child(label)
 await process_frame
 RenderingServer.force_draw(false)
 view.get_texture().get_image().save_png("res://artifacts/frontal-pose-review/actual-size.png")
 quit()
