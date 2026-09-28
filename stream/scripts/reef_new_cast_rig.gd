extends ReefRig
# H3 stage routing accepts new species before backend S4 switches the population.
# Review pose controls are presentation inputs, not a proposed snapshot schema.
var clasp_target: float=0
var clasp_blend: float=0

func art_spec() -> Dictionary:
	return ReefFishArt.spec(species)

func art_texture() -> Texture2D:
	return ReefFishArt.texture_for(species)

func _ready() -> void:
	super._ready()
	if species=="seahorse":
		fish_material.set_shader_parameter("grip",ReefFishArt.anchor_offset(species,"grip"))

func animate(delta: float) -> void:
	if delta<=0: return
	super.animate(delta)
	if species=="seahorse":
		clasp_blend=lerpf(clasp_blend,clampf(clasp_target,0,1),1-exp(-delta*3))
		fish_material.set_shader_parameter("clasp",clasp_blend)

func mouth_position() -> Vector2:
	var mouth:=ReefFishArt.anchor_offset(species,"mouth")
	mouth.x*=facing
	return position+(visual_offset+mouth.rotated(visual_pitch))*body_scale
