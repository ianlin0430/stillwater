extends RefCounted
# Renders animals one motion tick behind the simulation, interpolating the last two
# snapshots on simulation time. No extrapolation, so turns never overshoot.

const TICK: float=0.2
var from: Dictionary={}
var to: Dictionary={}
var elapsed: float=-INF
# Simulation seconds rendered past `from`; 0..TICK.
var since: float=0.0
var hold: bool=false

# `lead` is the simulation time already run past `at` this frame (the snapshot's
# motion_remainder); the next advance() is taken to be this same frame and skipped.
# Returns true when every animal was snapped (first snapshot, reload, catch-up, time jump).
func push(at: float, positions: Dictionary, jumps: Array=[], lead: float=0.0) -> bool:
	var step: float=at-elapsed
	var same: bool=absf(step)<0.0001
	var snap: bool=not same and (step<0 or step>TICK*1.5)
	var start: Dictionary={}
	for id: int in positions:
		start[id]=positions[id] if snap or id in jumps or not to.has(id) else from[id] if same else to[id]
	from=start
	to=positions
	if not same:
		since=clampf(lead,0,TICK)
		hold=true
		elapsed=at
	return snap

func advance(delta: float) -> void:
	if hold:
		hold=false
		return
	since=minf(since+delta,TICK)

func position(id: int) -> Vector2:
	return from[id].lerp(to[id],since/TICK)
