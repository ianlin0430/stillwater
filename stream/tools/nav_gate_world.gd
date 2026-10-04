extends "res://tests/test_world.gd"
# Includes the original seed-42 9000-tick home-distance scenario and its assertions.
func _initialize() -> void:
	new_cast_checks()
	print(JSON.stringify({"checks":checks,"failures":failures,"scope":"original new_cast_checks, including all home-distance assertions"}))
	quit(0 if failures.is_empty() else 1)
