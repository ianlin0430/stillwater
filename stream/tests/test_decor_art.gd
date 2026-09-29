extends SceneTree
var checks: int=0
var failures: Array[String]=[]
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok: failures.append(message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var scene:=ReefScene.open("reef")
	var catalog:=ReefDecorView.catalog()
	check(catalog.keys().size()==scene.decor.keys().size(),"Every shared decor style has exactly one art entry")
	for style: String in scene.decor:
		check(catalog.has(style),style+": art exists")
		if not catalog.has(style): continue
		var cfg: Dictionary=catalog[style]
		var texture: Texture2D=load(cfg.texture)
		var source:=texture.get_image()
		check(source.get_pixel(0,0).a==0,style+": genuine transparent background")
		var r:=Rect2(cfg.region[0],cfg.region[1],cfg.region[2],cfg.region[3])
		check(Rect2(Vector2.ZERO,source.get_size()).encloses(r),style+": valid crop")
		var extent:=Vector2(cfg.size[0],cfg.size[1])
		for hitch: Array in scene.decor[style].get("hitches",[]):
			var at:=r.position+(Vector2(hitch[0],hitch[1])/extent+Vector2(.5,1))*r.size
			check(source.get_pixelv(Vector2i(at)).a>.86,style+": hitch rests on visible art")
		var view:=ReefDecorView.new()
		view.style=style
		view.definition=scene.decor[style]
		root.add_child(view)
		view.advance(.1)
		var t: float=view.clock
		view.advance(0)
		check(view.clock==t,style+": pause freezes decor")
		check(view.materials.size()==2,style+": rear art and foreground lip share same geometry")
		view.free()
	print(JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
