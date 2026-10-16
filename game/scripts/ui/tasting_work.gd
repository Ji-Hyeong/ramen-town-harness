extends RefCounted
## 시식 준비 작업(국물 → 면 → 시식)의 진행 상태만 가진다. 돈/기록/평가 규칙은 전혀 모른다(그건 GameState.taste() 몫).
## 화면 시간(_process 의 delta)으로 advance() 를 부르면 실제로 4초쯤 걸리고, 검사(QA/테스트)는 격리된 인스턴스에서
## advance() 를 직접 불러 앞당긴다. 실제 게임에는 시간을 건너뛰는 설정/명령이 없다(개발용 저장 위치를 쓴 게임도 같다).
##
## 상태 전이: IDLE --start--> RUNNING --advance(충분히)--> (완료: advance 가 true 를 딱 한 번 돌려주고 IDLE 로 돌아감)
##                           RUNNING --cancel--> IDLE
## 완료/취소 어느 쪽이든 IDLE 로 돌아오므로 같은 작업에 대한 두 번째 완료/취소는 구조적으로 불가능하다.
## "작업 중"인 동안에만 스냅샷(시작 때 복사한 초안)이 남고, 끝나면 비운다. 저장 파일에는 어떤 형태로도 들어가지 않는다.

const DURATION: float = 4.0
const ProcessRules = preload("res://scripts/domain/recipe_process.gd")
## 단계 경계(전체 진행률 0~1 기준): 국물 0~0.45, 면 0.45~0.8, 시식 0.8~1.0.
const PHASES: Array = [
	{"id": "broth", "name": "국물 우리기", "end": 0.45},
	{"id": "noodle", "name": "면 삶기", "end": 0.80},
	{"id": "taste", "name": "시식 준비", "end": 1.00},
]

var _running: bool = false
var _elapsed: float = 0.0
var _snapshot: Dictionary = {}
var _duration: float = DURATION


func is_running() -> bool:
	return _running


## 시작: 이미 작업 중이면 거부(false)해서 중복 시작이 첫 작업을 덮어쓰거나 시간을 되돌리지 못한다.
## snapshot 은 호출자가 시작 시점의 초안(구성/이름/계통)을 복사해 넘긴 것이다. 여기서 다시 깊은 복사한다.
func start(snapshot: Dictionary) -> bool:
	if _running:
		return false
	var config: Dictionary = snapshot.get("config", {})
	var effects: Dictionary = ProcessRules.effects(config.get("process", {}))
	if str(effects["error"]) != "":
		return false
	_duration = float(effects["work_seconds"])
	_snapshot = snapshot.duplicate(true)
	_elapsed = 0.0
	_running = true
	return true


## 시간을 진행한다. 이번 호출로 처음 100%에 닿았을 때만 true(= 완료 신호, 호출자가 정확히 한 번 정산에 해당하는 일을 한다).
## 작업 중이 아니면 아무 것도 하지 않고 false. 음수/비정상 값은 0으로 취급한다.
func advance(seconds: float) -> bool:
	if not _running:
		return false
	if not is_finite(seconds) or seconds <= 0.0:
		return false
	_elapsed = minf(_duration, _elapsed + seconds)
	if _elapsed >= _duration:
		_running = false
		return true
	return false


## 취소/폐기. 완료 신호를 내지 않는다. 스냅샷은 버린다.
func cancel() -> void:
	_running = false
	_elapsed = 0.0
	_snapshot = {}


## 완료 직후 호출자가 스냅샷을 가져간 뒤 비운다(완료 신호 후에도 스냅샷은 한 번 읽을 수 있다).
func take_snapshot() -> Dictionary:
	var s: Dictionary = _snapshot
	_snapshot = {}
	_elapsed = 0.0
	return s


## 시작 때 복사한 초안의 깊은 복사본. 호출자가 안쪽(config 등)을 바꿔도 작업의 원본 스냅샷은 변하지 않는다.
func snapshot() -> Dictionary:
	return _snapshot.duplicate(true)


func progress() -> float:
	return clampf(_elapsed / _duration, 0.0, 1.0)


## 제조를 포함한 이번 시제품 연출 시간. 기본 공법은 기존4초이며 영업 조리시간과 다르다.
func duration() -> float:
	return _duration


func elapsed() -> float:
	return _elapsed


## 0 = 국물, 1 = 면, 2 = 시식. 진행률 기준(경계 값은 다음 단계).
static func phase_for(progress_value: float) -> int:
	for i in PHASES.size():
		if progress_value < float((PHASES[i] as Dictionary)["end"]):
			return i
	return PHASES.size() - 1


func phase_index() -> int:
	return phase_for(progress())


static func phase_name(index: int) -> String:
	return str((PHASES[clampi(index, 0, PHASES.size() - 1)] as Dictionary)["name"])
