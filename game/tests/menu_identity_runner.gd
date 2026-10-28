extends SceneTree
## Keep the entry executable on an owned-module parse failure; an invalid test
## module must exit1 instead of leaving a headless engine idle.
var checks: int=0
var failures: Array[String]=[]

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var module: GDScript=load("res://tests/menu_identity_tests.gd")
	if module==null or not module.can_instantiate():
		printerr("FAIL: menu identity test module cannot instantiate")
		quit(1)
		return
	create_timer(30.0).timeout.connect(func(): printerr("FAIL: identity tests timed out"); quit(1))
	module.new().run(_check)
	print("MENU IDENTITY PURE checks=%d failures=%d" % [checks,failures.size()])
	for failure in failures: printerr("FAIL: "+failure)
	quit(0 if failures.is_empty() else 1)

func _check(ok: bool, message: String) -> void:
	checks+=1
	if not ok: failures.append(message)
