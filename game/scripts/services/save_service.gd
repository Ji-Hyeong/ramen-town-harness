extends RefCounted
## 로컬 저장 서비스. 지정된 폴더 안의 고정된 파일 세 개(본 파일/임시/백업)만 다룬다.
##
## 쓰기 전략: 임시 파일에 쓰고 다시 읽어 내용을 확인한 뒤, 기존 본 파일을 백업으로 복사하고
## 임시 파일을 본 파일로 rename 한다. 중간에 실패해도 직전 본 파일/백업은 보존된다.
## 읽기: 파일이 없으면 정상 첫 실행("missing"). 파싱/구조/범위 오류는 "corrupt",
## 알 수 없는 스키마 버전은 "unsupported"로 보고하고 파일은 건드리지 않는다.
## 손상 파일을 치우려면 호출자가 명시적으로 archive_corrupt()를 불러야 한다(자동 덮어쓰기 없음).

const GameStateScript = preload("res://scripts/domain/game_state.gd")
const Check = preload("res://scripts/domain/data_check.gd")

const SAVE_FILE: String = "ramen_lab_save.json"
const TMP_FILE: String = "ramen_lab_save.json.tmp"
const BAK_FILE: String = "ramen_lab_save.json.bak"
const CORRUPT_PREFIX: String = "ramen_lab_save.corrupt-"
const MAX_BYTES: int = 2097152

var dir: String = ""


func _init(data_dir: String = "") -> void:
	dir = data_dir


func main_path() -> String:
	return dir.path_join(SAVE_FILE)


func tmp_path() -> String:
	return dir.path_join(TMP_FILE)


func bak_path() -> String:
	return dir.path_join(BAK_FILE)


func has_save() -> bool:
	return dir != "" and FileAccess.file_exists(main_path())


## 상태를 읽어 state에 반영한다. 반환: {"status": ok|missing|corrupt|unsupported|io_error, "message": String}
func load_into(state: GameStateScript) -> Dictionary:
	if dir == "":
		return _status("io_error", "저장 위치가 지정되지 않았어요.")
	var path: String = main_path()
	if not FileAccess.file_exists(path):
		return _status("missing", "저장 파일이 없어 새로 시작했어요.")
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return _status("io_error", "저장 파일을 열 수 없어요 (%s)." % error_string(FileAccess.get_open_error()))
	var length: int = file.get_length()
	if length > MAX_BYTES:
		file.close()
		return _status("corrupt", "저장 파일이 너무 커서 읽지 않았어요.")
	var text: String = file.get_as_text()
	file.close()
	var json: JSON = JSON.new()
	var parse_err: int = json.parse(text)
	if parse_err != OK:
		return _status("corrupt", "저장 파일을 해석할 수 없어요 (줄 %d)." % json.get_error_line())
	var raw: Variant = json.data
	if typeof(raw) != TYPE_DICTIONARY:
		return _status("corrupt", "저장 파일 구조가 올바르지 않아요.")
	var d: Dictionary = raw
	if not d.has("schema_version") or not Check.is_whole(d["schema_version"]):
		return _status("corrupt", "저장 버전 정보가 없거나 올바르지 않아요.")
	var version: int = int(d["schema_version"])
	if version != GameStateScript.SCHEMA_VERSION:
		if version > GameStateScript.SCHEMA_VERSION:
			return _status("unsupported", "더 새로운 버전에서 만든 저장이에요 (v%d). 이 버전에서는 열 수 없어요." % version)
		return _status("unsupported", "지원하지 않는 예전 저장 버전이에요 (v%d)." % version)
	var err: String = state.load_from_dict(d)
	if err != "":
		return _status("corrupt", "저장 내용이 올바르지 않아요: " + err)
	return _status("ok", "저장을 불러왔어요.")


## 반환: {"ok": bool, "message": String}
func save_state(state: GameStateScript) -> Dictionary:
	if dir == "":
		return {"ok": false, "message": "저장 위치가 지정되지 않았어요."}
	var text: String = JSON.stringify(state.to_dict(), "\t", true)
	var tmp: String = tmp_path()
	var file: FileAccess = FileAccess.open(tmp, FileAccess.WRITE)
	if file == null:
		return {"ok": false, "message": "임시 저장 파일을 만들 수 없어요 (%s)." % error_string(FileAccess.get_open_error())}
	file.store_string(text)
	var write_err: int = file.get_error()
	file.close()
	if write_err != OK:
		DirAccess.remove_absolute(tmp)
		return {"ok": false, "message": "저장 중 쓰기 오류가 났어요 (%s)." % error_string(write_err)}
	if FileAccess.get_file_as_string(tmp) != text:
		DirAccess.remove_absolute(tmp)
		return {"ok": false, "message": "저장 내용 확인에 실패했어요. 기존 저장은 그대로예요."}
	var main: String = main_path()
	if FileAccess.file_exists(main):
		var bak: String = bak_path()
		if FileAccess.file_exists(bak):
			var rm_err: int = DirAccess.remove_absolute(bak)
			if rm_err != OK:
				return {"ok": false, "message": "이전 백업을 정리하지 못했어요 (%s)." % error_string(rm_err)}
		var copy_err: int = DirAccess.copy_absolute(main, bak)
		if copy_err != OK:
			return {"ok": false, "message": "백업을 만들지 못했어요 (%s). 기존 저장은 그대로예요." % error_string(copy_err)}
	var rename_err: int = DirAccess.rename_absolute(tmp, main)
	if rename_err != OK:
		return {"ok": false, "message": "저장 파일을 교체하지 못했어요 (%s). 백업은 보존돼 있어요." % error_string(rename_err)}
	return {"ok": true, "message": "저장했어요."}


## 손상/미지원 저장을 지우지 않고 옆으로 치운다. 반환: {"ok", "message", "path"}
func archive_corrupt() -> Dictionary:
	if dir == "" or not FileAccess.file_exists(main_path()):
		return {"ok": false, "message": "치울 저장 파일이 없어요.", "path": ""}
	for n in range(1, 100):
		var target: String = dir.path_join("%s%d.json" % [CORRUPT_PREFIX, n])
		if FileAccess.file_exists(target):
			continue
		var err: int = DirAccess.rename_absolute(main_path(), target)
		if err != OK:
			return {"ok": false, "message": "파일을 옮기지 못했어요 (%s)." % error_string(err), "path": ""}
		return {"ok": true, "message": "손상된 저장을 따로 보관했어요.", "path": target}
	return {"ok": false, "message": "보관 공간이 가득 찼어요. 직접 정리해 주세요.", "path": ""}


## 테스트용: 이 서비스가 만드는 고정 이름 파일만 지운다(폴더 스캔 없음).
func remove_known_files() -> void:
	for p in [main_path(), tmp_path(), bak_path()]:
		if FileAccess.file_exists(str(p)):
			DirAccess.remove_absolute(str(p))


static func _status(status: String, message: String) -> Dictionary:
	return {"status": status, "message": message}
