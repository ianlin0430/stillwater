extends "res://tests/test_natural_motion.gd"
# Diagnostic entry point: invokes the unchanged complete night-rest gate.
# This does not replace the complete natural-motion acceptance suite.
func _initialize() -> void:
	night_rest_checks()
	print(JSON.stringify({"checks":checks,"failures":failures,"numbers":numbers}))
	quit(0 if failures.is_empty() else 1)
