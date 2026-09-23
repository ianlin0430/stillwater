extends SceneTree
const Candidate=preload("res://tools/art_candidates/shrimp_candidate_b.gd")
var checks: int=0
var failures: Array[String]=[]
func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok: failures.append(message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var w:=StreamWorld.new(42,1000)
	var bytes:=var_to_bytes(w.export_state())
	var rig=Candidate.new()
	rig.species="shrimp"
	rig.body_scale=0.75
	rig.scale=Vector2.ONE*0.75
	rig.position=Vector2(500,600)
	root.add_child(rig)
	rig.apply_identity(w.snapshot().animals[0],0)
	rig.activity="Exploring"
	var planted: int=0
	var slipping: int=0
	var active_max: int=0
	var lift: float=0
	for frame in 180:
		var prior: Array=rig.feet.duplicate()
		var prior_t: Array=rig.foot_t.duplicate()
		rig.position.x+=7.0/30
		rig.animate(1.0/30)
		var active: int=0
		for i in 10:
			if prior_t[i]==1 and rig.foot_t[i]==1:
				planted+=1
				if prior[i]!=rig.feet[i]: slipping+=1
			if rig.foot_t[i]<1:
				active+=1
				lift=maxf(lift,rig.foot_start[i].y-rig.feet[i].y)
		active_max=maxi(active_max,active)
	check(planted>300 and slipping==0,"Planted feet remain fixed in world coordinates")
	check(active_max<=5 and active_max>0,"Alternating half-groups swing while the other feet support")
	check(lift>3,"Walking lift spans several pixels at intended body scale")
	rig.activity="Resting"
	for frame in 120: rig.animate(1.0/30)
	var stopped:=var_to_bytes(rig.feet)
	for frame in 60: rig.animate(1.0/30)
	check(var_to_bytes(rig.feet)==stopped,"Resting feet stop after completing their step")
	var frozen: Array=[rig.phase,rig.paddle_phase,rig.feed_phase,rig.facing,rig.antenna_lag,var_to_bytes(rig.feet)]
	rig.animate(0)
	check(frozen==[rig.phase,rig.paddle_phase,rig.feed_phase,rig.facing,rig.antenna_lag,var_to_bytes(rig.feet)],"Pause freezes gait, paddles, feeding and antennae")
	rig.face_target=-1
	for frame in 10: rig.animate(1.0/30)
	check(rig.antenna_lag>rig.facing,"Antennae trail the turn instead of flipping instantly")
	var before: float=rig.paddle_phase
	rig.motion=25
	rig.animate(1.0/30)
	check(rig.paddle_phase>before and rig.paddle_phase-before<0.5,"Changing swim speed advances continuous paddle phase without a phase jump")
	check(var_to_bytes(w.export_state())==bytes,"Candidate identity and motion do not alter ecology or either RNG")
	print(JSON.stringify({"checks":checks,"failures":failures,"planted_foot_samples":planted,"slips":slipping,"foot_lift_world_pixels":lift}))
	quit(0 if failures.is_empty() else 1)
