class_name ReefFishArt
extends RefCounted
# Approved source art, ready for S4. This catalog does not register world species.
const ATLAS: Texture2D=preload("res://assets/reef/fish-atlas-redesign-v1.png")
const SPECIES: Array[String]=["green_chromis","clownfish","seahorse","royal_gramma"]
const LOOK: Dictionary={
	"clownfish":{"region":Rect2(650,198,476,303),"width":69.0,"line":.49,"mouth":Vector2(.986,.49),"eye":Vector2(.91,.38),"fin_root":Vector2(.60,.66)},
	"seahorse":{"region":Rect2(1234,134,253,420),"width":36.7,"line":.56,"mouth":Vector2(.972,.31),"eye":Vector2(.67,.19),"fin_root":Vector2(.10,.49),"grip":Vector2(.37,.91),"rows":24,"upright":true},
	"royal_gramma":{"region":Rect2(1620,235,465,249),"width":67.4,"line":.47,"mouth":Vector2(.985,.47),"eye":Vector2(.91,.38),"fin_root":Vector2(.67,.61)}}

static func spec(species: String) -> Dictionary:
	if species=="green_chromis":
		var result: Dictionary=ReefRig.LOOK[species].duplicate(true)
		result.merge({"mouth":Vector2(.99,.49),"eye":Vector2(.91,.46),"fin_root":Vector2(.67,.60)})
		return result
	return LOOK[species].duplicate(true)

static func texture_for(species: String) -> Texture2D:
	return ReefRig.ATLAS if species=="green_chromis" else ATLAS

static func extent_for(species: String) -> Vector2:
	var cfg:=spec(species)
	return Vector2(cfg.width,cfg.width*cfg.region.size.y/cfg.region.size.x)

static func anchor_offset(species: String, anchor: String) -> Vector2:
	var cfg:=spec(species)
	return (Vector2(cfg[anchor])-Vector2(.5,cfg.line))*extent_for(species)
