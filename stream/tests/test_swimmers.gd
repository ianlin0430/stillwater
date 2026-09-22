extends SceneTree
var failures: Array[String]=[]
var checks: int=0

func check(value: bool,message: String) -> void:
	checks+=1
	if not value:
		failures.append(message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var fish:=SwimmerRig.new()
	root.add_child(fish)
	var mesh: PackedVector2Array=fish.fish.polygon.duplicate()
	for i in 180:
		fish.position.x+=17.0/30
		fish.animate(1.0/30)
	var swimming_amplitude: float=fish.fish_material.get_shader_parameter("amplitude")
	for i in 180:
		fish.activity="Resting"
		fish.animate(1.0/30)
	check(fish.fish_material.get_shader_parameter("amplitude")<swimming_amplitude*0.4,"Resting tail effort falls after braking")
	check(mesh==fish.fish.polygon,"Fish animation preserves a cached static mesh")
	fish.face_target=-1
	var head_before: float=fish.facing
	var tail_before: float=fish.tail_facing
	var c_bend: bool=false
	var flat: bool=false
	for i in 90:
		fish.animate(1.0/30)
		check(absf(fish.facing-head_before)<0.12 and absf(fish.tail_facing-tail_before)<0.12,"Turn projection is continuous")
		# Head leads and the tail follows: the body folds instead of flattening like a card.
		c_bend=c_bend or (fish.facing<-0.3 and fish.tail_facing>0.3)
		flat=flat or (absf(fish.facing)<0.3 and absf(fish.tail_facing)<0.3)
		head_before=fish.facing
		tail_before=fish.tail_facing
	check(fish.fish.scale.x==1.0,"Fish mesh is never mirrored by node scale")
	check(c_bend,"Turn passes through a C-bend with head leading")
	check(not flat,"Turn never collapses the whole body edge-on")
	check(fish.facing==-1 and fish.tail_facing==-1,"Turn completes head and tail")
	var shrimp:=SwimmerRig.new()
	shrimp.species="shrimp"
	root.add_child(shrimp)
	for i in 180:
		shrimp.position.x+=6.0/30
		shrimp.animate(1.0/30)
	for i in 90:
		shrimp.activity="Grazing"
		shrimp.animate(1.0/30)
	var planted: Array[Vector2]=shrimp.feet.duplicate()
	for i in 90:
		shrimp.animate(1.0/30)
	check(planted==shrimp.feet,"Grazing feet stay planted")
	check(shrimp.feeding>0.99,"Mouthpart motion blends into grazing")
	shrimp.activity="Resting"
	for i in 60:
		shrimp.animate(1.0/30)
	check(shrimp.feeding==0,"Rest stops feeding motion")
	shrimp.activity="Retreating"
	shrimp.animate(1.0/30)
	check(shrimp.escape_age<0.04,"Retreat starts a discrete tail impulse")
	for i in 60:
		shrimp.animate(1.0/30)
	check(shrimp.escape_age>0.65,"Tail escape does not loop continuously")
	shrimp.activity="Exploring"
	shrimp.face_target=-1
	var shrimp_bend: bool=false
	var shrimp_flat: bool=false
	for i in 90:
		shrimp.animate(1.0/30)
		shrimp_bend=shrimp_bend or (shrimp.facing<-0.3 and shrimp.tail_facing>0.3)
		shrimp_flat=shrimp_flat or (absf(shrimp.facing)<0.3 and absf(shrimp.tail_facing)<0.3)
	check(shrimp_bend and not shrimp_flat,"Shrimp turns head-first with the abdomen following")
	check(shrimp.tail_facing==-1,"Shrimp turn completes")
	print(JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
