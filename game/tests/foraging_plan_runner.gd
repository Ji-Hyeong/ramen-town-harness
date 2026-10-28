extends SceneTree
## Pure projection/board tests have no filesystem writes. Keep an actual
## SceneTree entry so a RefCounted test module cannot leave the engine idle.
var checks: int=0
var failures: Array[String]=[]

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	# Dynamic load keeps the runner executable even if the owned test module has
	# a parse error. A failed instantiate must exit1, never idle until terminated.
	var script: GDScript=load("res://tests/foraging_plan_tests.gd")
	if script==null or not script.can_instantiate():
		printerr("FAIL: foraging test module cannot be instantiated")
		quit(1)
		return
	create_timer(30.0).timeout.connect(func(): printerr("FAIL: foraging tests timed out"); quit(1))
	script.new().run(_check)
	print("FORAGING PLAN checks=%d failures=%d" % [checks,failures.size()])
	for failure in failures: printerr("FAIL: "+failure)
	quit(0 if failures.is_empty() else 1)

func _check(ok: bool, message: String) -> void:
	checks+=1
	if not ok: failures.append(message)
