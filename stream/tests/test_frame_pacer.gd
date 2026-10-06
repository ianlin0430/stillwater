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
	print(JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
