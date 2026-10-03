extends SceneTree
const Fixture=preload("res://tools/review_fixtures/cast_snapshot.gd")
var checks: int=0
var failures: Array[String]=[]
func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok: failures.append(message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var stage:=StreamStage.new()
	root.add_child(stage)
	var snap:=Fixture.snapshot(ReefFishArt.SPECIES)
	for id: String in ReefScene.ids():
		snap.scene=id
		var original:=var_to_bytes(snap)
		stage.apply_snapshot(snap)
		check(stage.background.texture.resource_path==stage.scene.background(),id+": actual stage uses shared v2 background")
		check(stage.background.material==stage.water_material,id+": same animated lighting shader")
		check(stage.habitat.painted_ground,id+": no legacy ground art over scene")
		check(stage.scene_view.decorations.size()==3,id+": all default occupied slots render")
		for decor: ReefDecorView in stage.scene_view.decorations:
			check(decor.position==stage.scene.slot(stage.scene.slots().filter(func(s): return s.default==decor.style)[0].id).anchor,id+": decor uses shared anchor")
			check(ReefDecorView.catalog()[decor.style].texture.ends_with("-v2.png"),id+": decor uses v2 art")
		var decor: ReefDecorView=stage.scene_view.decorations[0]
		stage.animate(.1)
		check(decor.clock>.0,id+": live stage advances decor")
		var frozen: float=decor.clock
		stage.animate(0)
		check(decor.clock==frozen,id+": pause freezes decor")
		stage.apply_snapshot(snap)
		check(stage.scene_view.decorations[0]==decor,id+": repeated snapshots preserve animation instance")
		check(var_to_bytes(snap)==original,id+": input remains read only")
	# Per-scene choices, optional clearing and mandatory-slot fallback.
	snap.decor={"reef":{"anemone":"anemone_pink","s1":"","s2":"table_coral"},"shipwreck":{"hitch_plant":"seagrass_tall"}}
	for id: String in ["reef","shipwreck","reef"]:
		snap.scene=id
		stage.apply_snapshot(snap)
		check(stage.scene_view.styles.anemone=="anemone_pink",id+": selected anemone")
		check(stage.scene_view.styles.hitch_plant=="seagrass_tall",id+": per-scene plant choice")
		check(stage.scene_view.styles.s1==("" if id=="reef" else "wreck_bow"),id+": optional slot clearing survives switching")
	snap.decor.reef.anemone=""
	snap.decor.reef.hitch_plant="unknown"
	stage.apply_snapshot(snap)
	check(stage.scene_view.styles.anemone=="anemone_green" and stage.scene_view.styles.hitch_plant=="seagrass_tall","Invalid mandatory choices safely use defaults")
	var ship:=ReefScene.open("shipwreck")
	for rock: Vector2 in ship.rock_spots():
		check(rock.x>=ship.bounds().roam_x[0] and rock.x<=ship.bounds().roam_x[1],"Shipwreck rock fallback is reachable horizontally")
	stage.free()
	print(JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
