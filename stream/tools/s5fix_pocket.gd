extends SceneTree
func _initialize() -> void:
	for pr in ["min","max"]:
		var w:=StreamWorld.new(2,1000,"shipwreck")
		var d: Dictionary=w.scene.preset(pr)
		for slot in d: w.set_decor(slot,d[slot])
		for sp in ["clownfish","seahorse"]:
			var grid: Array=w._grid(sp+"/"+str(1.0),sp,1.0)
			print(pr," ",sp," bed at 200/400: ",w.bed_y(200)," ",w.bed_y(400))
			for gy in range(50,68):
				var s:=""
				for gx in range(0,64):
					s+=str(grid[0][gy*128+gx])
				print(gy*10," ",s)
	quit()
