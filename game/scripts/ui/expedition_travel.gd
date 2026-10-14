extends RefCounted
## 짧은 이동 연출 전용 시계. 저장/비용/사건 선택/보상은 전혀 소유하지 않는다.
## 재시작하면 연출만 다시 보여 주고 GameState의 이미 지불한 탐험 단계를 그대로 사용한다.
const Exploration = preload("res://scripts/domain/ingredient_exploration.gd")
const DURATION: float = 1.2
var _elapsed: float = DURATION
var _region: String = ""


func start(region: String) -> Dictionary:
	if Exploration.find_region(region).is_empty():
		return {"ok": false, "message": "이동할 지역이 올바르지 않아요."}
	_region = region
	_elapsed = 0.0
	return {"ok": true, "message": ""}


func advance(seconds: float) -> Dictionary:
	if not is_finite(seconds) or seconds < 0.0:
		return {"ok": false, "message": "이동 시간은 유한한 음이 아닌 값이어야 해요."}
	_elapsed = minf(DURATION, _elapsed + seconds)
	return {"ok": true, "message": ""}


func running() -> bool:
	return _elapsed < DURATION


func progress() -> float:
	return _elapsed / DURATION


func region() -> String:
	return _region


func stop() -> void:
	_elapsed = DURATION
