extends ReefRig
# Review-only analytical curved body over the approved side-view fins.
const BODY=preload("res://tools/art_candidates/tang_volume_body.gdshader")
var shell: Polygon2D
var shell_material: ShaderMaterial
func _ready() -> void:
 super._ready()
 shell=Polygon2D.new()
 var lo=Vector2(-extent.x*.5,-extent.y*.66)
 shell.polygon=PackedVector2Array([lo,lo+Vector2(extent.x,0),lo+extent,lo+Vector2(0,extent.y)])
 shell.texture=ATLAS
 shell_material=ShaderMaterial.new()
 shell_material.shader=BODY
 shell.material=shell_material
 add_child(shell)
func animate(delta: float) -> void:
 super.animate(delta)
 for key: String in ["extent","body_line","facing","pitch","pose_offset","roll"]:
  shell_material.set_shader_parameter(key,fish_material.get_shader_parameter(key))
 shell.modulate=fish.modulate
 shell.visible=fish.visible
