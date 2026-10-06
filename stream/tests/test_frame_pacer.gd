extends SceneTree
var checks: int=0
var failures: Array[String]=[]
func _initialize() -> void:
	for draw: bool in [false,true]:
		for minimized: bool in [false,true]:
			for focused: bool in [false,true]:
				checks+=1
				var expected: int=0 if not draw or minimized else 60 if focused else 30
				if FramePacer.mode(draw,minimized,focused)!=expected: failures.append(str([draw,minimized,focused]))
	var cases: Array=[
		["foreground",{"visible_seconds":1800,"focused_seconds":1800,"hidden_seconds":0,"drawn_frames":100800},true],
		["foreground",{"visible_seconds":1800,"focused_seconds":1799,"hidden_seconds":0,"drawn_frames":100800},false],
		["foreground",{"visible_seconds":1800,"focused_seconds":1800,"hidden_seconds":0,"drawn_frames":100799},false],
		["background",{"visible_seconds":1810,"focused_seconds":10,"mode_drawn_frames":{"30":50400}},true],
		["background",{"visible_seconds":1810,"focused_seconds":11,"mode_drawn_frames":{"30":50400}},false],
		["background",{"visible_seconds":1800,"focused_seconds":0,"mode_drawn_frames":{"60":108000}},false],
		["hidden",{"hidden_seconds":1800,"mode_drawn_frames":{"0":0}},true],
		["hidden",{"hidden_seconds":1800,"mode_drawn_frames":{"0":1}},false],
		["hidden",{"hidden_seconds":1799,"mode_drawn_frames":{"0":0}},false],
		["hidden",{"hidden_seconds":1800},false]]
	for fixture: Array in cases:
		checks+=1
		if FramePacer.acceptance(fixture[1])[fixture[0]+"_30_minute_eligible"]!=fixture[2]: failures.append(str(fixture))
	print(JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
