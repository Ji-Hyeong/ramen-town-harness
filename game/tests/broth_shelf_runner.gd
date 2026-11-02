extends SceneTree
const Tests=preload("res://tests/broth_shelf_tests.gd")
var checks: int=0
var failures: Array[String]=[]
func _initialize() -> void:
	var folder: String=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--test-data-dir="):folder=arg.trim_prefix("--test-data-dir=")
	if not folder.is_absolute_path() or DirAccess.dir_exists_absolute(folder) or FileAccess.file_exists(folder):printerr("New absolute isolated --test-data-dir required");quit(2);return
	var tests:=Tests.new();tests.run(_check,folder)
	_check(tests.finished,"actual path and every boundary completes")
	print("BROTH SHELF checks=%d failures=%d services=%d" % [checks,failures.size(),tests.services])
	for failure in failures:printerr("FAIL: "+failure)
	quit(0 if failures.is_empty() else 1)
func _check(value: bool,message: String) -> void:
	checks+=1
	if not value:failures.append(message)
