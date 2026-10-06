extends "res://tests/test_natural_motion.gd"
func _initialize() -> void:
	kinematics_checks()
	separation_checks()
	feeding_checks()
	print(JSON.stringify({"checks":checks,"failures":failures,"numbers":numbers}))
	quit()
