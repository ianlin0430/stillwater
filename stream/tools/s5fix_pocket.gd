extends SceneTree
# S5-fix probe (scratch): obstacles of a scene/decor and the grid around a point.
# -- --scene=reef --preset=min --species=clownfish --x=500 --y=470
func arg(n: String, f: String) -> String:
	for s: String in OS.get_cmdline_user_args():
		if s.begins_with("--"+n+"="): return s.trim_prefix("--"+n+"=")
	return f
func _initialize() -> void:
	var w:=StreamWorld.new(7,1000,arg("scene","reef"))
	var d: Dictionary=w.scene.preset(arg("preset","min"))
	for slot in d: w.set_decor(slot,d[slot])
	for i in w._obstacles.size():
		var o=w._obstacles[i]
		print(i," ",[o.cx,o.cy,o.rx,o.ry])
	var sp:=arg("species","clownfish")
	var grid: Array=w._grid(sp+"/"+str(1.0),sp,1.0)
	var cx:=int(int(arg("x","500"))/10.0); var cy:=int(int(arg("y","470"))/10.0)
	for gy in range(maxi(0,cy-12),mini(72,cy+12)):
		var s:=""
		for gx in range(maxi(0,cx-25),mini(128,cx+25)):
			var l: int=grid[5][gy*128+gx]
			s+=("L" if l>=0 else str(grid[0][gy*128+gx]))
		print(gy*10," ",s)
	quit()
