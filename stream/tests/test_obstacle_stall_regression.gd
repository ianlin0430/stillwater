extends SceneTree
var checks: int=0
var failures: Array=[]
func check(value: bool, message: String) -> void:
	checks+=1
	if not value: failures.append(message)
func _initialize() -> void:
	var results: Dictionary=preload("res://tests/obstacle_stall_fixture.gd").run(check)
	print(JSON.stringify({"checks":checks,"failures":failures,"numbers":results}))
	quit(0 if failures.is_empty() else 1)
