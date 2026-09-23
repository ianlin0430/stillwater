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
	_fish_only()
	_life_effects()
	_events()
	_motion(false)
	_motion(true)
	_smoother()
	print(JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)

# Drives a real world and stage exactly as main.gd does, at 30 FPS, and measures rendered fish speed.
func _motion(jitter: bool) -> void:
	var world:=StreamWorld.new(42,1000)
	var stage:=StreamStage.new()
	root.add_child(stage)
	stage.apply_snapshot(world.snapshot())
	var applied: int=world.state.motion_ticks
	var noise:=RandomNumberGenerator.new()
	noise.seed=7
	var dt: float=1.0/30
	var frames: Array[float]=[]
	var rendered: Dictionary={}
	var truth: Dictionary={}
	for f in 300:
		if jitter: dt=noise.randf_range(0.7,1.3)/30
		world.advance_live(minf(dt,0.25))
		if world.state.motion_ticks!=applied:
			stage.apply_snapshot(world.snapshot())
			applied=world.state.motion_ticks
		stage.animate(minf(dt,0.1))
		frames.append(dt)
		for a: Dictionary in world.state.animals:
			if a.species=="shrimp" or not stage.rigs.has(a.id): continue
			if not rendered.has(a.id):
				rendered[a.id]=[]
				truth[a.id]=[]
			rendered[a.id].append(stage.rigs[a.id].position)
			truth[a.id].append(Vector2(a.get("vx",0.0),a.get("vy",0.0)))
	var low: float=INF
	var high: float=0
	var samples: int=0
	for id: int in rendered:
		var v: Array=truth[id]
		for f in range(12,v.size()):
			var steady: bool=v[f].length()>8
			for k in range(f-12,f+1):
				steady=steady and v[k].distance_to(v[f])<v[f].length()*0.03
			if not steady: continue
			var ratio: float=rendered[id][f].distance_to(rendered[id][f-1])/frames[f]/v[f].length()
			low=minf(low,ratio)
			high=maxf(high,ratio)
			samples+=1
	print("motion%s: %d cruising frames, rendered/true speed %.2f..%.2f" % [" (jittered frames)" if jitter else "",samples,low,high])
	check(samples>=60 and low>=0.75 and high<=1.25,"Cruising fish render within 25%% of true speed%s (%.2f..%.2f over %d frames)" % [" with jittered frames" if jitter else "",low,high,samples])
	var held: Dictionary={}
	for id: int in stage.rigs: held[id]=stage.rigs[id].position
	var moved: float=0
	for f in 90:
		if f==45: stage.apply_snapshot(world.snapshot())
		stage.animate(0)
		for id: int in held: moved=maxf(moved,stage.rigs[id].position.distance_to(held[id]))
	check(moved==0,"Paused stage renders no motion (max %.3f px)" % moved)
	stage.queue_free()

func _smoother() -> void:
	var m=preload("res://scripts/motion_smoother.gd").new()
	check(m.push(0.0,{1:Vector2(0,0)}),"First snapshot snaps")
	m.advance(1.0/30)
	m.push(0.2,{1:Vector2(10,0),2:Vector2(50,50)})
	m.advance(1.0/30)
	check(m.position(1)==Vector2(0,0) and m.position(2)==Vector2(50,50),"Interpolation starts one tick behind; new animals appear in place")
	m.advance(0.1)
	check(m.position(1).is_equal_approx(Vector2(5,0)),"Positions interpolate linearly on simulation time")
	m.advance(1.0)
	check(m.position(1)==Vector2(10,0),"Interpolation clamps at the latest snapshot without overshoot")
	m.push(0.4,{1:Vector2(90,0)},[1])
	check(m.position(1)==Vector2(90,0) and not m.from.has(2),"Relocation jumps directly; removed animals drop their history")
	check(m.push(9.0,{1:Vector2(20,20)}) and m.position(1)==Vector2(20,20),"A time jump (catch-up, reload) snaps to the latest position")

func _events() -> void:
	var world:=StreamWorld.new(42,1000)
	var untouched:=var_to_bytes(world.export_state())
	var stage:=StreamStage.new()
	root.add_child(stage)
	var initial: Dictionary=world.snapshot()
	stage.apply_snapshot(initial)
	check(stage.event_cursor==initial.next_event-1 and stage.deaths.is_empty(),"Initial snapshot establishes cursor without replay")
	var a: Dictionary=initial.animals.filter(func(v: Dictionary)->bool: return v.species=="threadfin")[0].duplicate(true)
	var next: Dictionary=initial.duplicate(true)
	next.animals=next.animals.filter(func(v: Dictionary)->bool: return v.id!=a.id)
	next.archive.append(a)
	var seq: int=next.next_event
	next.events.append({"seq":seq,"kind":"death","id":a.id,"cause":"old age","live":true,"x":a.x,"y":a.y,"time":0.2})
	next.next_event+=1
	next.elapsed=0.2
	stage.apply_snapshot(next)
	check(stage.rigs.has(a.id) and stage.deaths.has(a.id),"Live death retains archived appearance for fade-out")
	var start: Vector2=stage.rigs[a.id].position
	stage.animate(0.5)
	check(stage.rigs[a.id].modulate.a<1 and stage.rigs[a.id].position.y>start.y,"Death fades and sinks at event position")
	var age: float=stage.deaths[a.id].age
	stage.animate(0)
	check(stage.deaths[a.id].age==age,"Pause freezes event presentation")
	stage.apply_snapshot(next)
	check(stage.deaths[a.id].age==age,"Repeated snapshot cannot restart event")
	stage.animate(2)
	check(not stage.rigs.has(a.id) and stage.deaths.is_empty(),"Death rig expires after two seconds")
	stage.apply_snapshot(initial)
	check(stage.event_cursor==initial.next_event-1 and stage.deaths.is_empty(),"Cursor rollback clears presentation without replay")
	next.events[-1].live=false
	stage.apply_snapshot(next)
	check(not stage.rigs.has(a.id) and stage.deaths.is_empty(),"Offline death does not animate")
	stage.apply_snapshot(initial)
	next.events=[]
	stage.apply_snapshot(next)
	check(not stage.rigs.has(a.id),"Missing animal without event removes normally")
	stage.apply_snapshot(initial)
	stage.animate(0.1)
	var relocated: Dictionary=initial.duplicate(true)
	relocated.elapsed=0.2
	var moved: Dictionary=relocated.animals.filter(func(v: Dictionary)->bool: return v.id==a.id)[0]
	moved.relocated_at=0.2
	moved.x+=20
	moved.vx=30.0
	stage.habitat.impulses.clear()
	stage.apply_snapshot(relocated)
	stage.animate(0.1)
	check(stage.rigs[a.id].position==Vector2(moved.x,moved.y),"Relocated fish snaps to its new position")
	check(stage.habitat.wake_clock[a.id]>=stage.habitat.clock-0.1,"Relocation suppresses wake even for short jumps")
	var changed: Dictionary=next.duplicate(true)
	changed.seed=999
	changed.events=[{"seq":changed.next_event,"kind":"death","id":a.id,"cause":"old age","live":true,"x":a.x,"y":a.y}]
	changed.next_event+=1
	stage.apply_snapshot(changed)
	check(stage.deaths.is_empty(),"Changing seed resets cursor even when event numbers increase")
	stage.apply_snapshot(initial)
	stage.rigs[a.id].queue_free()
	stage.rigs.erase(a.id)
	next.events=[{"seq":seq,"kind":"death","id":a.id,"cause":"old age","live":true,"x":a.x,"y":a.y}]
	stage.apply_snapshot(next)
	check(stage.rigs.has(a.id) and stage.deaths[a.id].appearance.sex==a.sex,"Archive restores appearance when death actor was not previously rendered")
	for i in 40:
		var copy: Dictionary=a.duplicate(true)
		copy.id=100+i
		stage._begin_death({"id":copy.id}, {"archive":[copy]})
	check(stage.deaths.size()==24,"Retained death actors are bounded")
	stage.animate(2.1)
	check(stage.deaths.is_empty(),"All capped death actors expire")
	check(var_to_bytes(world.export_state())==untouched,"Event and relocation presentation leave world and both RNGs unchanged")
	stage.queue_free()

func _life_effects() -> void:
	var world:=StreamWorld.new(42,1000)
	var bytes:=var_to_bytes(world.export_state())
	var stage:=StreamStage.new()
	root.add_child(stage)
	var snap:=world.snapshot()
	stage.apply_snapshot(snap)
	var actor: Dictionary=snap.animals.filter(func(v: Dictionary)->bool: return v.species=="threadfin")[0]
	var fx=stage.events_layer
	for kind: String in ["birth","arrival"]:
		fx.accept({"kind":kind,"id":actor.id},snap)
		stage.animate(0)
		check(stage.rigs[actor.id].modulate.a==0,"New "+kind+" begins transparent")
		stage.animate(0.5)
		check(stage.rigs[actor.id].modulate.a>0 and stage.rigs[actor.id].modulate.a<1,"Mid "+kind+" fades in")
		var age: float=fx.fades[actor.id].age
		var pos: Vector2=stage.rigs[actor.id].position
		stage.animate(0)
		check(fx.fades[actor.id].age==age and stage.rigs[actor.id].position==pos,"Pause freezes "+kind)
		stage.animate(2)
		check(not fx.fades.has(actor.id) and stage.rigs[actor.id].modulate.a==1,"Completed "+kind+" returns to normal")
	fx.accept({"kind":"dispersal","id":actor.id},snap)
	stage.animate(1)
	check(fx.ghosts.size()==1 and fx.ghosts[0].rig.position.x>actor.x,"Dispersing youngster drifts downstream")
	stage.animate(3)
	check(fx.ghosts.is_empty(),"Dispersal expires at four seconds")
	# The current fish-only brief retires shell and brood presentation tests.
	fx.accept({"kind":"molt","id":actor.id,"until":10.0},snap)
	fx.accept({"kind":"berried","id":actor.id,"until":10.0},snap)
	check(fx.ghosts.is_empty() and fx.fades.is_empty(),"Fish never produce molt or egg overlays")
	for i in 50: fx.accept({"kind":"dispersal","id":actor.id},snap)
	check(fx.ghosts.size()==24,"Transient life effects have a hard cap")
	fx.clear()
	check(fx.ghosts.is_empty() and fx.fades.is_empty(),"World reset clears all transients")
	check(var_to_bytes(world.export_state())==bytes,"Life effects do not modify simulation or RNG")
	stage.queue_free()

func _fish_only() -> void:
	var world:=StreamWorld.new(42,1000)
	var unchanged:=var_to_bytes(world.export_state())
	var snap:=world.snapshot()
	# Include an explicit legacy shrimp so this stays useful after backend removal.
	var legacy: Dictionary=snap.animals[0].duplicate(true)
	legacy.id=999
	legacy.species="shrimp"
	legacy.activity="Grazing"
	legacy.brood_until=1000.0
	legacy.molting_until=1.0
	snap.animals.append(legacy)
	var stage:=StreamStage.new()
	root.add_child(stage)
	stage.apply_snapshot(snap)
	check(not stage.rigs.has(999),"Legacy shrimp does not get a rendered rig")
	check(not 999 in stage.visible_ids(),"Keyboard selection and visible count exclude shrimp")
	check(stage.habitat.animals.all(func(a: Dictionary)->bool: return a.species!="shrimp"),"Hidden shrimp cannot bend plants or produce wakes")
	check(stage.visible_ids().size()==snap.animals.filter(func(a: Dictionary)->bool: return a.species in StreamStage.PRESENTED_SPECIES).size(),"Visible count matches actual supported fish")
	for kind: String in ["birth","arrival","dispersal","molt","berried"]:
		stage.events_layer.accept({"kind":kind,"id":999,"until":1000.0},snap)
	check(stage.events_layer.ghosts.is_empty() and stage.events_layer.fades.is_empty(),"Legacy shrimp events create no transient silhouettes or overlays")
	snap.archive.append(legacy)
	stage._begin_death({"id":999,"cause":"old age"},snap)
	check(not stage.rigs.has(999) and stage.deaths.is_empty(),"Archived shrimp cannot reappear during a death event")
	stage.animate(1)
	check(var_to_bytes(world.export_state())==unchanged,"Fish-only presentation preserves saves and ecology for backend migration")
	stage.queue_free()
