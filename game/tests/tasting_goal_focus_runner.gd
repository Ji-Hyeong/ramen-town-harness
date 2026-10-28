extends SceneTree
## A parse failure must exit instead of leaving a file-only delegate's tests idle.
var checks: int=0
var failures: Array[String]=[]
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	var script: GDScript=load("res://tests/tasting_goal_focus_tests.gd")
	if script==null or not script.can_instantiate():
		printerr("FAIL: goal-focus test module cannot instantiate");quit(1);return
	script.new().run(_check)
	print("TASTING GOAL FOCUS checks=%d failures=%d" % [checks,failures.size()])
	for failure in failures:printerr("FAIL: "+failure)
	quit(0 if failures.is_empty() else 1)
func _check(ok: bool,message: String) -> void:
	checks+=1
	if not ok:failures.append(message)
