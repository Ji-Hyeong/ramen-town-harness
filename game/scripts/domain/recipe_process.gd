extends RefCounted
## 제조 공법 카탈로그: 순수 데이터/계산만 다룬다.
## 다른 기존 파일을 preload하지 않아 의존성 순환이 없다. 클램프/평가/저장은 호출 측 몫이다.

const SLOTS: Array[String] = ["broth", "noodle"]
const AXES: Array[String] = ["rich", "salt", "aroma", "chew", "spice"]
## 시식 제조 연출의 기본 시간(초). 영업 조리 seconds와는 별개다.
const BASE_WORK_SECONDS := 4.0

const _ORDER := {
	"broth": ["standard", "gentle", "rolling"],
	"noodle": ["standard", "moist", "rested"],
}

const _DATA := {
	"broth": {
		"standard": {"id": "standard", "name": "기본 우림", "desc": "기본 방식. 맛, 비용, 준비시간에 변화가 없다.",
			"rank": 1, "cost": 0, "seconds": 0, "work_extra": 0.0,
			"axes": {"rich": 0, "salt": 0, "aroma": 0, "chew": 0, "spice": 0}},
		"gentle": {"id": "gentle", "name": "약불 우림", "desc": "섬세한 향이 살아나지만 진함이 줄고, 비용과 준비시간이 늘어난다.",
			"rank": 1, "cost": 180, "seconds": 8, "work_extra": 1.0,
			"axes": {"rich": -1, "salt": 0, "aroma": 2, "chew": 0, "spice": 0}},
		"rolling": {"id": "rolling", "name": "강불 추출", "desc": "진한 맛을 끌어내지만 향이 줄고, 비용과 준비시간이 크게 늘어난다.",
			"rank": 2, "cost": 300, "seconds": 12, "work_extra": 1.5,
			"axes": {"rich": 2, "salt": 0, "aroma": -1, "chew": 0, "spice": 0}},
	},
	"noodle": {
		"standard": {"id": "standard", "name": "기본 반죽", "desc": "기본 방식. 맛, 비용, 준비시간에 변화가 없다.",
			"rank": 1, "cost": 0, "seconds": 0, "work_extra": 0.0,
			"axes": {"rich": 0, "salt": 0, "aroma": 0, "chew": 0, "spice": 0}},
		"moist": {"id": "moist", "name": "고가수 반죽", "desc": "빠르게 조리되고 식감이 부드러워지며 쫄깃함이 줄어든다.",
			"rank": 1, "cost": 80, "seconds": -8, "work_extra": 0.5,
			"axes": {"rich": 0, "salt": 0, "aroma": 0, "chew": -2, "spice": 0}},
		"rested": {"id": "rested", "name": "저가수 숙성", "desc": "쫄깃함이 크게 늘지만 향이 줄고, 비용과 준비시간이 늘어난다.",
			"rank": 2, "cost": 140, "seconds": 10, "work_extra": 2.0,
			"axes": {"rich": 0, "salt": 0, "aroma": -1, "chew": 2, "spice": 0}},
	},
}


## 공법 한 개의 deep copy. 모르는 슬롯/id면 빈 Dictionary.
static func method(slot: String, id: String) -> Dictionary:
	if not _DATA.has(slot) or not _DATA[slot].has(id):
		return {}
	return (_DATA[slot][id] as Dictionary).duplicate(true)


## 슬롯의 공법 id 목록(새 배열). 모르는 슬롯은 빈 배열.
static func ids(slot: String) -> Array[String]:
	var out: Array[String] = []
	if _ORDER.has(slot):
		for id in _ORDER[slot]:
			out.append(String(id))
	return out


## 공법 사전 검증. 빈 사전은 기본값(두 standard)이라 유효하다.
## 비어있지 않으면 정확히 broth/noodle 두 키만, 각각 알려진 id 문자열이어야 한다.
static func error(raw: Variant) -> String:
	if typeof(raw) != TYPE_DICTIONARY:
		return "공법 설정은 Dictionary여야 합니다."
	var d: Dictionary = raw
	if d.is_empty():
		return ""
	if d.size() != SLOTS.size():
		return "공법 설정은 broth와 noodle 두 키만 가져야 합니다."
	for slot in SLOTS:
		if not d.has(slot):
			return "공법 설정에 %s 키가 없습니다." % slot
		if typeof(d[slot]) != TYPE_STRING:
			return "%s 공법 id는 문자열이어야 합니다." % slot
		if not ids(slot).has(d[slot]):
			return "알 수 없는 %s 공법입니다." % slot
	return ""


## 슬롯별 선택 id. 무효 사전/모르는 슬롯은 빈 문자열, 빈 사전은 standard.
static func selected(raw: Dictionary, slot: String) -> String:
	if error(raw) != "" or not SLOTS.has(slot):
		return ""
	return "standard" if raw.is_empty() else String(raw[slot])


## 선택된 공법들의 효과 합산. 입력은 바꾸지 않고 항상 새 Dictionary를 돌려준다.
## work_seconds는 시식 제조 연출 시간이며 영업 조리 seconds와 다르다.
static func effects(raw: Variant = {}) -> Dictionary:
	var err := error(raw)
	if err != "":
		return {"error": err}
	var d: Dictionary = raw
	var axes := {}
	for axis in AXES:
		axes[axis] = 0
	var cost := 0
	var seconds := 0
	var work := BASE_WORK_SECONDS
	var rank := 1
	for slot in SLOTS:
		var m := method(slot, selected(d, slot))
		for axis in AXES:
			axes[axis] += int(m["axes"][axis])
		cost += int(m["cost"])
		seconds += int(m["seconds"])
		work += float(m["work_extra"])
		rank = maxi(rank, int(m["rank"]))
	return {"error": "", "axes": axes, "cost": cost, "seconds": seconds, "work_seconds": work, "rank": rank}


## 두 공법 이름을 ' · '로 이은 요약(기본도 표시). 무효면 error 문장.
static func summary(raw: Dictionary = {}) -> String:
	var err := error(raw)
	if err != "":
		return err
	var names: Array[String] = []
	for slot in SLOTS:
		names.append(String(method(slot, selected(raw, slot))["name"]))
	return " · ".join(names)
