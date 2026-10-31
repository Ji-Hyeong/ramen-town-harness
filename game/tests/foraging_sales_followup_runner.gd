extends SceneTree
## An invalid/failed module must exit, not leave an idle test process alive.
var checks: int=0
var failures: Array[String]=[]
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	var suite: GDScript=load("res://tests/foraging_sales_followup_tests.gd")
	if suite==null or not suite.can_instantiate():printerr("Cannot instantiate follow-up tests");quit(1);return
	suite.new().run(_check)
	print("FORAGING SALES FOLLOWUP checks=%d failures=%d" % [checks,failures.size()])
	for failure in failures:printerr("FAIL: "+failure)
	quit(0 if failures.is_empty() else 1)
func _check(ok: bool,message: String) -> void:
	checks+=1
	if not ok:failures.append(message)
