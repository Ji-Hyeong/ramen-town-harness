extends SceneTree
## Focused runner uses the same shared checks as the full suite.
const Tests = preload("res://tests/harbor_foraging_tests.gd")
var checks: int = 0
var failures: Array[String] = []


func _initialize() -> void:
	var folder: String = ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--test-data-dir="):
			folder = arg.substr(16)
	if not folder.is_absolute_path() or DirAccess.dir_exists_absolute(folder) or FileAccess.file_exists(folder):
		printerr("Use a new absolute --test-data-dir.")
		quit(2)
		return
	Tests.new().run(_check, folder)
	print("Harbor checks=%d failures=%d" % [checks, failures.size()])
	for failure in failures:
		printerr("FAIL: " + failure)
	quit(0 if failures.is_empty() else 1)


func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
