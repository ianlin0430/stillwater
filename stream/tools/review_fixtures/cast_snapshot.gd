extends RefCounted
# Presentation fixtures only. Never insert these actors into a StreamWorld.
const LEGACY: Array[String]=["purple_firefish","lawnmower_blenny","yellow_tang","green_chromis"]
static func actor(species: String, id: int, at: Vector2) -> Dictionary:
	return {"id":id,"species":species,"name":species.replace("_"," ").capitalize(),"age":10000.0,
		"sex":"female","parent":0,"recent":[],"x":at.x,"y":at.y,"direction":1.0,
		"heading":0.0,"pitch":0.0,"turn":0.0,"vx":12.0,"vy":0.0,"speed":12.0,"thrust":.3,
		"activity":"Cruising","extend":1.0,"hover_y":32.0,"shelter":at.x}
static func snapshot(species_list: Array[String]) -> Dictionary:
	var animals: Array=[]
	for index in species_list.size():
		var a:=actor(species_list[index],index+1,Vector2(250+index*180,360))
		if a.species=="purple_firefish":
			a.y=600.0
			a.activity="Hovering"
		elif a.species=="lawnmower_blenny":
			a.y=600.0
			a.activity="Perching"
		animals.append(a)
	return {"seed":-28,"scene":"reef","elapsed":0.0,"next_event":1,"animals":animals,
		"archive":[],"events":[],"food":[],"resources":{}}
