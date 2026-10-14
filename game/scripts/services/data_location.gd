extends RefCounted
## 저장 위치 결정. 기본은 user://, 개발/QA는 --dev-data-dir=<절대경로> 로 명시한다.
## 잘못된 개발 경로는 user:// 로 조용히 대체하지 않고 오류를 돌려준다(실제 저장 보호).

const DEV_ARG: String = "--dev-data-dir="


## 반환: {"ok": bool, "dir": String, "is_dev": bool, "error": String}
static func resolve(args: PackedStringArray) -> Dictionary:
	var found: Array[String] = []
	for a in args:
		if a.begins_with(DEV_ARG):
			found.append(a.substr(DEV_ARG.length()))
	if found.is_empty():
		return {"ok": true, "dir": "user://", "is_dev": false, "error": ""}
	if found.size() > 1:
		return _bad("--dev-data-dir 가 여러 번 지정됐어요.")
	var path: String = found[0]
	if path.begins_with("res://") or path.begins_with("user://"):
		return _bad("--dev-data-dir 는 절대 경로여야 해요.")
	var absolute: bool = path.begins_with("/") or (path.length() > 2 and path[1] == ":")
	if not absolute:
		return _bad("--dev-data-dir 는 절대 경로여야 해요.")
	if path.contains("/../") or path.ends_with("/..") or path.contains("\\..\\"):
		return _bad("--dev-data-dir 에 '..' 를 쓸 수 없어요.")
	if not DirAccess.dir_exists_absolute(path):
		var err: int = DirAccess.make_dir_recursive_absolute(path)
		if err != OK:
			return _bad("개발용 저장 폴더를 만들 수 없어요 (%s)." % error_string(err))
	return {"ok": true, "dir": path, "is_dev": true, "error": ""}


static func from_process() -> Dictionary:
	var all_args: PackedStringArray = OS.get_cmdline_args()
	all_args.append_array(OS.get_cmdline_user_args())
	# 같은 인자가 두 목록에 모두 보이면 중복 지정으로 오인하지 않도록 한 번만 센다.
	var unique: PackedStringArray = PackedStringArray()
	for a in all_args:
		if not unique.has(a):
			unique.append(a)
	return resolve(unique)


static func _bad(message: String) -> Dictionary:
	return {"ok": false, "dir": "", "is_dev": false, "error": message}
