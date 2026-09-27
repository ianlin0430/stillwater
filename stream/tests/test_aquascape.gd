extends SceneTree
var checks: int=0
var failures: Array[String]=[]
func check(ok: bool, message: String) -> void:
 checks+=1
 if not ok: failures.append(message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
 var scene=load("res://tools/aquascape_preview.gd").new()
 scene.auto_advance=false
 root.add_child(scene)
 for i in 60: scene.advance(1./30)
 var habitat: ReefAquascape=scene.habitat
 var frozen: Array=[scene.clock,habitat.clock,habitat.bubble_position(0),habitat.plants[0].plant_clock,habitat.plants[0].wind_bend,scene.rigs[0].position,scene.rigs[0].pectoral_phase]
 scene.advance(0)
 check(frozen==[scene.clock,habitat.clock,habitat.bubble_position(0),habitat.plants[0].plant_clock,habitat.plants[0].wind_bend,scene.rigs[0].position,scene.rigs[0].pectoral_phase],"delta=0 freezes fish, plants, water, and bubbles")
 scene.paused=true
 scene.advance(1)
 check(scene.clock==frozen[0],"Pause freezes preview clock")
 scene.paused=false
 scene.hide()
 scene.advance(1)
 check(scene.clock==frozen[0],"Hidden preview stops updates")
 scene.show()
 var plant: AquascapePlant=habitat.plants[0]
 var root_at: Vector2=plant.position
 var swimmers: Array=[{"at":plant.position-Vector2(8,plant.height*.55),"velocity":Vector2(35,0)}]
 var original: PackedByteArray=var_to_bytes(swimmers)
 for i in 30: plant.advance(1./30,.5,swimmers)
 check(plant.response>1,"Passing fish bends the nearby plant")
 check(plant.position==root_at,"Plant root never drifts from the substrate")
 check(var_to_bytes(swimmers)==original,"Plant reaction cannot mutate fish input")
 var response: float=plant.response
 plant.advance(0,0,[])
 check(plant.response==response,"Pause also freezes interaction spring")
 for i in 150: plant.advance(1./30,0,[])
 check(absf(plant.response)<.01 and absf(plant.response_velocity)<.01,"Plant gently settles after fish passes")
 var left_at: Vector2=scene._path(9,11.999)
 var right_at: Vector2=scene._path(9,12.001)
 check(left_at.distance_to(right_at)<.1,"Blenny return leg does not teleport")
 var worst: float=0
 var before: Array=[]
 for rig: ReefRig in scene.rigs: before.append(rig.position)
 for i in 720:
  scene.advance(1./30)
  for j in scene.rigs.size():
   worst=maxf(worst,scene.rigs[j].position.distance_to(before[j]))
   before[j]=scene.rigs[j].position
 check(worst<4,"Presentation paths remain continuous at state boundaries")
 check(habitat.contact_peak>.05,"Recorded paths produce actual nearby fish/plant interaction")
 check(habitat.plants.size()==11,"All three plant types have layered clusters")
 scene.free()
 print(JSON.stringify({"checks":checks,"failures":failures,"max_position_step":worst}))
 quit(0 if failures.is_empty() else 1)
