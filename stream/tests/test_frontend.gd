extends SceneTree
var checks: int=0
var failures: Array[String]=[]
func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok: failures.append(message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var world:=StreamWorld.new(42,1000)
	var before: PackedByteArray=var_to_bytes(world.export_state())
	var stage:=StreamStage.new()
	root.add_child(stage)
	stage.apply_snapshot(world.snapshot())
	stage.animate(0.1)
	var h=stage.habitat
	var root_point: Vector2=h.ROOTS[0]-Vector2(-30,h._height(0)*0.5)
	stage.interact(root_point)
	stage.animate(0.2)
	check(absf(h.bends[0])>2,"Dragging plants produces a local bend")
	check(h.impulses.size()>0,"Water interaction produces visible impulses")
	var frozen: float=h.clock
	stage.animate(0)
	check(h.clock==frozen,"Pause freezes environmental animation")
	for i in 300:
		stage.interact(Vector2(500+i%20,60))
		stage.animate(1.0/30)
	check(h.impulses.size()<=24,"Repeated interaction remains bounded")
	check(var_to_bytes(world.export_state())==before,"Frontend input does not alter world, events, clocks or random state")
	var low: Dictionary=world.snapshot()
	low.resources.stem=0.0
	low.resources.floating=0.0
	low.resources.biofilm=0.0
	h.apply_snapshot(low)
	for i in 180: stage.animate(1.0/30)
	check(h.resources.stem<0.01 and h.resources.floating<0.01,"Resource depletion updates living foreground")
	check(var_to_bytes(world.export_state())==before,"Resource presentation leaves the actual model unchanged")
	stage.zoom=1.65
	stage.center=Vector2(680,380)
	stage.animate(0.2)
	var at:=Vector2(350,210)
	stage.interact(stage.position+at*stage.zoom)
	check(h.brush.distance_to(at)<0.001,"Pointer maps correctly through pan and zoom")
	stage.interaction_enabled=false
	stage.interact(Vector2.ZERO)
	check(h.brush.distance_to(at)<0.001,"Disabled interaction does not produce input effects")
	for i in 120: stage.animate(1.0/30)
	check(h.impulses.is_empty(),"Interaction effects expire")
	print(JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
