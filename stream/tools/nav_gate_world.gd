extends "res://tests/test_world.gd"
var measured: Array[String]=[]
func check(value: bool, message: String) -> void:
	super.check(value,message)
	if "stays near its home" in message or "Then it swims home" in message:
		measured.append(message)
# Includes the original seed-42 9000-tick home-distance scenario and its assertions.
func _initialize() -> void:
	new_cast_checks()
	print(JSON.stringify({"checks":checks,"failures":failures,"measurements":measured,"scope":"original new_cast_checks, including all home-distance assertions"}))
	quit(0 if failures.is_empty() else 1)
