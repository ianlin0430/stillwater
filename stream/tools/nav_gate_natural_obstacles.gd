extends "res://tests/test_natural_motion.gd"
# The original eight-seed obstacle matrix and assertions, without other suites.
func _initialize() -> void:
	obstacle_checks()
	print(JSON.stringify({"checks":checks,"failures":failures,"numbers":numbers}))
	quit(0 if failures.is_empty() else 1)
