extends SceneTree
## A failing assertion always produces a nonzero exit; this runner writes no
## save and is separate from the real paid-transaction scene acceptance.
const Tests = preload("res://tests/recipe_directions_tests.gd")
var checks: int = 0
var failures: Array[String] = []


func _initialize() -> void:
	Tests.new().run(_check)
	print("Recipe directions checks=%d failures=%d" % [checks, failures.size()])
	for failure in failures:
		printerr("FAIL: " + failure)
	quit(0 if failures.is_empty() else 1)


func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
