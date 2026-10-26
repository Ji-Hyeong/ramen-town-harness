extends RefCounted
## 가게 직원. 시작 직원은 요리사와 서버 둘(고정)이고, 선택으로 보조 직원 둘(조리 보조, 홀 보조)을 한 명씩만 고용할 수 있다.
## 이 파일은 데이터와 순수 계산뿐이다. 고용(자금 차감/목록 변경)은 GameState.hire_staff()가 한다.
##
## 보조 직원은 맛 점수를 올리지 않는다. 영업의 "시간"만 바꾼다:
##  - 조리 보조: 한 그릇 조리 시간이 PREP_PERCENT %(올림)로 줄어든다 → 더 많이 만들 수 있고 기다림에 지친 이탈이 줄어든다.
##  - 홀 보조: 서버의 서빙 왕복 시간이 SERVE_PERCENT %(올림, 최소 1초)로 줄어든다 → 음식이 손님 앞에 더 빨리 닿고 서버가 더 빨리 돌아온다.
## 대가: 고용비(한 번)와 하루 운영비(영업을 끝까지 마쳐 정산될 때마다 정확히 한 번, 영업 운영비 3,000원에 더해짐).
##
## 스냅샷 규칙: 영업을 시작하는 순간 snapshot()으로 직원 구성을 복사해 세션이 그것만 쓴다.
## 영업 중에는 고용이 막혀 있고, 정산은 세션의 스냅샷으로 운영비를 계산하므로 도중에 값이 달라질 수 없다.

const BASE_STAFF: int = 2
const PREP_PERCENT: int = 80
const SERVE_PERCENT: int = 70
const Training = preload("res://scripts/domain/staff_training.gd")
const Check = preload("res://scripts/domain/data_check.gd")

const STAFF: Array = [
	{
		"id": "prep_assistant", "role": "prep", "role_name": "조리 보조", "name": "시온",
		"hire_price": 8000, "wage": 600, "look": 12,
		"desc": "주방에서 고명을 썰고 면을 건져 줘요. 한 그릇 조리 시간이 20% 줄어요(올림).",
	},
	{
		"id": "floor_assistant", "role": "floor", "role_name": "홀 보조", "name": "다온",
		"hire_price": 7000, "wage": 500, "look": 13,
		"desc": "쟁반을 들고 홀을 도와요. 서버의 서빙 왕복 시간이 30% 줄어요(올림, 최소 1초).",
	},
]

const SNAPSHOT_KEYS: Array = ["hired", "prep_percent", "serve_percent", "wage"]


static func all() -> Array:
	return STAFF


static func ids() -> Array[String]:
	var out: Array[String] = []
	for s in STAFF:
		out.append(str((s as Dictionary)["id"]))
	return out


static func find(id: String) -> Dictionary:
	for s in STAFF:
		var d: Dictionary = s
		if str(d["id"]) == id:
			return d
	return {}


## 고용 목록(고용 순서)에서 영업 스냅샷을 만든다. 순서와 무관하게 카탈로그 순서로 정렬해 같은 구성은 같은 스냅샷이 된다.
## 알 수 없는 id는 무시하지 않고 호출자(GameState)가 이미 검증한 목록만 받는다.
static func snapshot(hired: Array, training: Dictionary = {}, chef_level: int = 0) -> Dictionary:
	var ordered: Array = []
	var wage: int = 0
	var prep_pct: int = 100
	var serve_pct: int = 100
	var qualifications: Array = []
	for s in STAFF:
		var d: Dictionary = s
		if hired.has(str(d["id"])):
			var lv: int = 0
			var style: String = ""
			if training.has(str(d["id"])):
				var entry: Dictionary = training[str(d["id"])]
				lv = Training.level(entry)
				if lv > 0:
					style = str(entry["lessons"][lv - 1]["style"])
					qualifications.append({"id": str(d["id"]), "level": lv, "style": style})
			var fx: Dictionary = Training.effect(lv, style)
			ordered.append(str(d["id"]))
			wage += int(d["wage"]) + int(fx["wage_delta"])
			if str(d["role"]) == "prep":
				prep_pct = PREP_PERCENT - int(fx["percent_discount"])
			elif str(d["role"]) == "floor":
				serve_pct = SERVE_PERCENT - int(fx["percent_discount"])
	var out: Dictionary = {"hired": ordered, "prep_percent": prep_pct, "serve_percent": serve_pct, "wage": wage}
	# 훈련 전에는 예전 스냅샷의 키/값을 그대로 유지한다. 자격이 있을 때만 효과의 근거를 추가한다.
	if not qualifications.is_empty():
		out["training"] = qualifications
	if chef_level == 1:
		out["chef"] = 1
	return out


## 스냅샷이 카탈로그에서 파생한 값과 정확히 같은지 확인한다(빈 딕셔너리 = 보조 직원 없음 = 기준). 맞으면 "".
static func snapshot_error(staffing: Dictionary) -> String:
	if staffing.is_empty():
		return ""
	var key_err: String = _keys(staffing)
	if key_err != "":
		return key_err
	if typeof(staffing["hired"]) != TYPE_ARRAY:
		return "직원 구성 구조가 올바르지 않아요."
	var seen: Dictionary = {}
	for h in (staffing["hired"] as Array):
		if typeof(h) != TYPE_STRING or find(str(h)).is_empty():
			return "알 수 없는 직원이에요."
		if seen.has(str(h)):
			return "같은 직원이 두 번 들어 있어요."
		seen[str(h)] = true
	var entries: Dictionary = {}
	if staffing.has("training"):
		if typeof(staffing["training"]) != TYPE_ARRAY or staffing["training"].is_empty() or staffing["training"].size() > 2:
			return "직원 자격 구조가 올바르지 않아요."
		for value in staffing["training"]:
			if typeof(value) != TYPE_DICTIONARY:
				return "직원 자격 구조가 올바르지 않아요."
			var q: Dictionary = value
			if Check.keys_error(q, ["id", "level", "style"], "직원 자격") != "":
				return "직원 자격 항목이 올바르지 않아요."
			if typeof(q["id"]) != TYPE_STRING or not seen.has(q["id"]) or entries.has(q["id"]) or not Check.in_range(q["level"], 1, 2) or typeof(q["style"]) != TYPE_STRING:
				return "직원 자격 값이 올바르지 않아요."
			var fx: Dictionary = Training.effect(int(q["level"]), str(q["style"]))
			if fx.has("error"):
				return str(fx["error"])
			# 자격만으로 효과를 재계산한다. 영업 스냅샷에 경험/훈련 거래 기록을 중복 저장하지 않는다.
			var lessons: Array = []
			for i in int(q["level"]):
				lessons.append({"style": "basic" if i == 0 else str(q["style"])})
			entries[str(q["id"])] = {"lessons": lessons}
	for k in ["prep_percent", "serve_percent", "wage"]:
		if not Check.in_range(staffing[k], 0, 1000000):
			return "직원 효과는 유효한 정수여야 해요."
	if staffing.has("chef") and not Check.in_range(staffing["chef"],1,1):
		return "요리사 자격이 올바르지 않아요."
	var expected: Dictionary = snapshot(staffing["hired"] as Array, entries, int(staffing.get("chef",0)))
	if JSON.stringify(expected, "", true) != JSON.stringify(staffing, "", true):
		return "직원 구성 값이 직원 목록과 맞지 않아요."
	return ""


static func _keys(d: Dictionary) -> String:
	for k in SNAPSHOT_KEYS:
		if not d.has(k):
			return "직원 구성: 항목 누락 (%s)" % str(k)
	for k in d.keys():
		if not SNAPSHOT_KEYS.has(k) and k not in ["training","chef"]:
			return "직원 구성: 알 수 없는 항목 (%s)" % str(k)
	return ""


static func _pct(staffing: Dictionary, key: String) -> int:
	if staffing.is_empty():
		return 100
	return int(staffing[key])


## 영업 중 한 그릇 조리 시간(초). 보조가 없으면(퍼센트 100) 기준 시간과 정확히 같다.
static func effective_prep(base_prep: int, staffing: Dictionary) -> int:
	var pct: int = _pct(staffing, "prep_percent")
	var after_assistant: int = maxi(1, (base_prep * pct + 99) / 100)
	# Mastery is applied after the assistant's independently rounded effect.
	# Snapshots without mastery retain every historical timing/economic value.
	return maxi(1, (after_assistant * 95 + 99) / 100) if int(staffing.get("chef",0)) == 1 else after_assistant


## 서버가 음식을 들고 자리까지 가는 시간(초).
static func effective_carry(base_seconds: int, staffing: Dictionary) -> int:
	var pct: int = _pct(staffing, "serve_percent")
	return maxi(1, (base_seconds * pct + 99) / 100)


## 서버가 빈손으로 주방 앞에 돌아오는 시간(초). 기준 돌아오는 시간 = 기준 서빙 시간 x back_percent / 100(최소 1초).
static func effective_return(base_seconds: int, back_percent: int, staffing: Dictionary) -> int:
	var base_back: int = maxi(1, base_seconds * back_percent / 100)
	var pct: int = _pct(staffing, "serve_percent")
	return maxi(1, (base_back * pct + 99) / 100)


## 하루 보조 직원 운영비 합(원). 정산 때 영업 운영비에 더해진다.
static func daily_wage(staffing: Dictionary) -> int:
	if staffing.is_empty():
		return 0
	return int(staffing["wage"])
