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
	var snap:=Fixture.snapshot(StreamStage.PRESENTED_SPECIES)
	snap.animals.append(Fixture.actor("unknown_future_fish",999,Vector2(300,300)))
	var original:=var_to_bytes(snap)
	stage.apply_snapshot(snap)
	stage.animate(.1)
	check(stage.rigs.size()==7 and stage.visible_ids().size()==7,"Both casts coexist during H3")
	check(not stage.rigs.has(999) and StreamStage.create_rig("unknown_future_fish")==null,"Unknown species never creates a rig")
	check(stage.habitat.animals.size()==7,"Unknown species excluded from wakes and plants")
	for a: Dictionary in snap.animals:
		if a.id==999: continue
		var rig: ReefRig=stage.rigs[a.id]
		check(rig.get_script()==(StreamStage.NEW_CAST_RIG if a.species in ReefFishArt.LOOK else ReefRig),a.species+": correct rig route")
		check(rig.fish.texture==rig.art_texture() and rig.body_visible,a.species+": correct visible source")
		check(stage.pick(rig.selection_position())==a.id,a.species+": selectable on stage")
		if a.species in ReefFishArt.LOOK:
			check(rig.extent.is_equal_approx(ReefFishArt.extent_for(a.species)),a.species+": body size matches backend handoff")
			stage.events_layer.accept({"kind":"arrival","id":a.id},snap)
			stage.animate(.5)
			check(rig.modulate.a>0 and rig.modulate.a<1,a.species+": arrival fades in")
			stage.events_layer.accept({"kind":"dispersal","id":a.id},snap)
			var ghost: ReefRig=stage.events_layer.ghosts[-1].rig
			check(ghost.get_script()==StreamStage.NEW_CAST_RIG and ghost.fish.texture==rig.fish.texture,a.species+": dispersal uses same new artwork")
	check(var_to_bytes(snap)==original,"Stage, arrival and dispersal preserve supplied snapshot")
	stage.events_layer.accept({"kind":"dispersal","id":999},snap)
	check(stage.events_layer.ghosts.size()==3,"Unknown event cannot create a ghost")
	# Archive-only deaths must route through the same factory even without a live rig.
	for species: String in ReefFishArt.LOOK:
		var a:=Fixture.actor(species,100+stage.deaths.size(),Vector2(640,350))
		stage._begin_death({"id":a.id},{"archive":[a]})
		check(stage.rigs[a.id].get_script()==StreamStage.NEW_CAST_RIG and stage.deaths.has(a.id),species+": archive creates correct death rig")
	stage.animate(2.1)
	check(stage.deaths.is_empty(),"New-cast death rigs expire")
	# A migrated ID cannot retain the previous species' mesh.
	var changed:=Fixture.snapshot(["clownfish"])
	changed.elapsed=.2
	stage.apply_snapshot(changed)
	check(stage.rigs[1].species=="clownfish" and stage.rigs.size()==1,"Same ID with a different species replaces its rig")
	changed.animals[0].activity="Sheltering"
	changed.animals[0].erase("shelter")
	stage.apply_snapshot(changed)
	check(is_finite(stage.rigs[1].modulate.a),"Sheltering without legacy shelter coordinate is safe")
	changed.scene="shipwreck"
	stage.apply_snapshot(changed)
	check(stage.scene.id()=="shipwreck" and stage.events_layer.scene==stage.scene,"Stage selects scene data and shares it with arrival effects")
	# Legacy arrival floor follows the chosen scene, never static StreamWorld terrain.
	var grounded:=Fixture.snapshot(["lawnmower_blenny"])
	grounded.scene="shipwreck"
	grounded.elapsed=.4
	stage.apply_snapshot(grounded)
	stage.events_layer.accept({"kind":"arrival","id":1},grounded)
	stage.animate(.5)
	var bottom: ReefRig=stage.rigs[1]
	check(is_equal_approx(bottom.position.y,stage.scene.floor_y(bottom.position.x)),"Ground arrival samples the active scene bed")
	changed.scene="missing_scene"
	stage.apply_snapshot(changed)
	check(stage.scene.id()=="reef","Unknown scene uses a safe reef fallback")
	# Actual inspector and pointer handlers, without main's save/load lifecycle.
	var app=load("res://scripts/main.gd").new()
	app.world=StreamWorld.new(42,1000)
	app.stage=stage
	app.notes=RichTextLabel.new()
	for species: String in ["clownfish","seahorse","royal_gramma","unknown_future_fish"]:
		var a:=Fixture.actor(species,99,Vector2(640,350))
		app.world.state.animals=[a]
		app.world.state.archive=[]
		app.selected=99
		app._refresh_info()
		check(StreamStage.species_label(species) in app.notes.text,species+": inspector tolerates absent backend metadata")
	var motion:=InputEventMouseMotion.new()
	app._world_pointer(motion,Vector2(640,350))
	check(app.pointer==Vector2(640,350),"Pointer inside water is accepted through world floor API")
	app._world_pointer(motion,Vector2(640,app.world.floor_y(640)+1))
	check(app.pointer==Vector2(-1,-1),"Pointer below active world floor is rejected")
	app.notes.free()
	app.free()
	stage.free()
	print(JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
