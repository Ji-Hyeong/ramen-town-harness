extends SceneTree
## The module has no filesystem access. Dynamic loading keeps parse failures
## from leaving a RefCounted test module idling as a supposed entry point.
var checks: int=0
var failures: Array[String]=[]
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	var script: GDScript=load("res://tests/sample_encounter_tests.gd")
	if script==null or not script.can_instantiate():
		printerr("FAIL: sample encounter test module cannot instantiate");quit(1);return
	script.new().run(_check)
	print("SAMPLE ENCOUNTERS checks=%d failures=%d" % [checks,failures.size()])
	for failure in failures:printerr("FAIL: "+failure)
	quit(0 if failures.is_empty() else 1)
func _check(ok: bool, text: String) -> void:
	checks+=1
	if not ok:failures.append(text)
