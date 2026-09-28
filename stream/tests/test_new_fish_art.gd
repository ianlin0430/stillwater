extends SceneTree
const RIG=preload("res://scripts/reef_new_cast_rig.gd")
var checks: int=0
var failures: Array[String]=[]
func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok: failures.append(message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var source:=ReefFishArt.ATLAS.get_image()
	check(source.get_size()==Vector2i(2149,732) and source.get_pixel(0,0).a==0 and source.get_pixel(1000,650).a==0,"Transparent source preserves canvas and removes board labels")
	for species: String in ReefFishArt.SPECIES:
		var cfg:=ReefFishArt.spec(species)
		var texture:=ReefFishArt.texture_for(species)
		check(Rect2(Vector2.ZERO,texture.get_size()).encloses(cfg.region),species+": crop is inside its source")
		if species!="green_chromis":
			var atlas: AtlasTexture=load("res://assets/reef/"+species+"-side-v1.tres")
			check(atlas.atlas==texture and atlas.region==cfg.region and atlas.filter_clip,species+": reusable atlas resource matches catalog")
			check(species in StreamStage.PRESENTED_SPECIES,species+": stage accepts new cast during H3 migration")
		else:
			check(texture==ReefRig.ATLAS and cfg.region==ReefRig.LOOK[species].region,"Approved chromis source and region remain unchanged")
		for anchor: String in ["mouth","eye","fin_root"]:
			var point: Vector2=cfg.region.position+Vector2(cfg[anchor])*cfg.region.size
			check(texture.get_image().get_pixelv(Vector2i(point)).a>.86,species+": "+anchor+" is on visible artwork")
		var rig=RIG.new()
		rig.species=species
		rig.position=Vector2(100,100)
		root.add_child(rig)
		var initial_actor: Dictionary={"heading":0.0,"activity":"Cruising","thrust":.2,"speed":12.0}
		var original: PackedByteArray=var_to_bytes(initial_actor)
		rig.apply_actor(initial_actor)
		rig.animate(.2)
		var mouth_right: Vector2=rig.mouth_position()-rig.position
		var old_side: float=1
		var flips: int=0
		var always_full: bool=true
		for frame in 240:
			if frame%12==0: rig.apply_actor({"heading":PI*frame/228.0,"activity":"Cruising","thrust":.2,"speed":12.0})
			rig.animate(1.0/60)
			if rig.facing!=old_side: flips+=1
			old_side=rig.facing
			always_full=always_full and absf(rig.facing)==1
		var mouth_left: Vector2=rig.mouth_position()-rig.position
		check(flips==1 and always_full and rig.position==Vector2(100,100),species+": one direct mirror with fixed pivot and full width")
		check(mouth_left.is_equal_approx(Vector2(-mouth_right.x,mouth_right.y)),species+": mouth anchor mirrors around body pivot")
		check(var_to_bytes(initial_actor)==original,"Presentation never writes back into supplied actor data")
		if species=="seahorse":
			rig.clasp_target=1
			rig.animate(.1)
			var held: float=rig.clasp_blend
			rig.animate(0)
			check(held>0 and held<1 and rig.clasp_blend==held and rig.fish_material.get_shader_parameter("upright"),"Seahorse uses upright motion, eased clasp and pause")
		rig.free()
	print(JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
