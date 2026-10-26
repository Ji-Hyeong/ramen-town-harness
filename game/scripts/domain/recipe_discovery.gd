extends RefCounted
## 레시피 연구 지도와 라멘 정체성 설명. 순수 계산이며 상태/저장 구조를 읽거나 쓰지 않는다.
##
## 정체성(describe):
##  - 제목은 실제 육수/타레/향미유/토핑 분량에서만 만든다. 가격, 사용자가 붙인 이름, 토핑을 고른 순서는 제목에 영향이 없다
##    (토핑은 카탈로그 정규 순서의 분량 표기 "차슈 ×2 + 반숙란"을 쓰므로 같은 분량이면 같은 제목, 분량이 다르면 다른 제목).
##  - 제안일 뿐이다. 사용자가 정한 이름은 건드리지 않고, 호출자도 이 제목을 저장하지 않는다.
##  - 태그는 평가기가 이미 계산하는 사실(맛 프로필, 궁합 합계, 공법, 재료비, 준비 시간)을 분류한 글이다. 점수 보너스를 새로 만들지 않는다.
##
## 연구 주제(catalog/matched_ids/pages):
##  - 주제 8개는 "연구 방향"이다. 각각 기준(criteria) 몇 개를 모두 만족하면 그 구성이 주제에 맞는다고 본다.
##    정확히 한 가지 레시피가 아니라 기준만 맞으면 되므로 여러 구성이 같은 주제에 속할 수 있고, 한 구성이 여러 주제에 속할 수도 있다.
##  - 기준 종류(kind):
##      has_any         ids 중 하나 이상을 min(기본 1)번 이상 고름. 토핑은 분량마다 1번으로 센다.
##      axis_min/max    평가기 build_profile()(공법 포함, 0~10 제한)의 axis 값이 value 이상/이하.
##      repeat_topping  같은 토핑 하나를 min번 이상(분량 반복) 고름.
##  - 가격과 이름은 어떤 기준에도 쓰이지 않는다. 검증을 통과하지 못한 구성(DataCheck.config_error)은 아무 주제에도 맞지 않는다.
##  - "시식함(tested)"은 호출자가 넘긴 현재 보관 기록에서만 계산한다. 기록이 삭제되면 시식함도 사라질 수 있고,
##    평생 수집 기록은 어디에도 저장하지 않는다. 초안(draft)은 ready 일 뿐 tested 가 아니다.

const Catalog = preload("res://scripts/domain/ingredient_catalog.gd")
const Check = preload("res://scripts/domain/data_check.gd")
const Evaluator = preload("res://scripts/domain/recipe_evaluator.gd")
const ProcessRules = preload("res://scripts/domain/recipe_process.gd")

## 태그 분류 기준(평가기 값의 구간 나누기일 뿐 점수와 무관).
const AXIS_HIGH: int = 7
const AXIS_LOW: int = 2
const COMPAT_GOOD: int = 3
const COST_HIGH: int = 2000
const COST_LOW: int = 1300
const PREP_LONG: int = 130
const PREP_SHORT: int = 80

const _BROTH_WORD: Dictionary = {
	"broth_tonkotsu": "돼지뼈", "broth_chicken": "맑은 닭", "broth_dashi": "해물 다시", "broth_clam": "조개",
}
const _TARE_WORD: Dictionary = {
	"tare_shoyu": "간장", "tare_shio": "소금", "tare_miso": "된장", "tare_plum": "매실",
}
const _OIL_WORD: Dictionary = {
	"oil_garlic": "마늘유", "oil_chili": "고추기름", "oil_scallion": "파기름",
	"oil_shrimp": "새우유", "oil_pepper": "초피유", "oil_roasted_sesame": "참깨유",
}

const _THEMES: Array = [
	{"id": "bone_depth", "title": "진국의 깊이", "origin": "시작 재료: 돼지뼈 진국",
		"hint": "돼지뼈 진국에 진함을 겹겹이 쌓아 보세요.",
		"criteria": [
			{"kind": "has_any", "ids": ["broth_tonkotsu"], "min": 1, "hint": "육수: 돼지뼈 진국"},
			{"kind": "axis_min", "axis": "rich", "value": 8, "hint": "진함 8 이상 (된장 타레, 차슈, 강불 추출이 도움)"},
		]},
	{"id": "clear_light", "title": "맑고 향긋한 한 그릇", "origin": "시작 재료: 닭 육수·해물 다시",
		"hint": "맑은 육수로 가볍게, 향은 짙게 맞춰 보세요.",
		"criteria": [
			{"kind": "has_any", "ids": ["broth_chicken", "broth_dashi", "broth_clam", "broth_roasted_sardine"], "min": 1, "hint": "육수: 맑은 닭, 해물 다시, 조개, 구운 정어리 중 하나"},
			{"kind": "axis_max", "axis": "rich", "value": 5, "hint": "진함 5 이하 (국물을 가볍게)"},
			{"kind": "axis_min", "axis": "aroma", "value": 6, "hint": "향 6 이상 (파기름, 간장 타레, 김이 도움)"},
		]},
	{"id": "fire_oil", "title": "얼큰한 기름", "origin": "시작 재료: 고추기름 / 산골 농가: 초피유",
		"hint": "매운 기름으로 확실한 얼큰함을 만들어 보세요.",
		"criteria": [
			{"kind": "has_any", "ids": ["oil_chili", "oil_pepper"], "min": 1, "hint": "향미유: 고추기름 또는 초피유"},
			{"kind": "axis_min", "axis": "spice", "value": 5, "hint": "매운맛 5 이상"},
		]},
	{"id": "noodle_chew", "title": "면의 힘", "origin": "시작 재료: 중간 물결면·굵은 꼬불면",
		"hint": "면과 익힘으로 씹는 맛을 끌어올려 보세요.",
		"criteria": [
			{"kind": "has_any", "ids": ["noodle_medium", "noodle_thick"], "min": 1, "hint": "면: 중간 물결면 또는 굵은 꼬불면"},
			{"kind": "axis_min", "axis": "chew", "value": 8, "hint": "면 식감 8 이상 (꼬들하게, 저가수 숙성이 도움)"},
		]},
	{"id": "topping_stack", "title": "토핑 겹쌓기", "origin": "시작 재료: 같은 토핑을 한 번 더",
		"hint": "마음에 드는 토핑을 한 그릇에 두 번 올려 보세요.",
		"criteria": [
			{"kind": "repeat_topping", "min": 2, "hint": "같은 토핑을 2분량 이상"},
		]},
	{"id": "clam_mushroom", "title": "바다와 산 사이", "origin": "아침 항구: 조개 맑은탕 + 산골 농가: 표고 조림",
		"hint": "항구의 조개 국물에 산골 표고를 올려 보세요.",
		"criteria": [
			{"kind": "has_any", "ids": ["broth_clam"], "min": 1, "hint": "육수: 조개 맑은탕 (아침 항구)"},
			{"kind": "has_any", "ids": ["topping_mushroom"], "min": 1, "hint": "토핑: 표고 조림 (산골 농가)"},
		]},
	{"id": "citrus_light", "title": "유자 향 가벼움", "origin": "새벽 장터 채집: 유자 껍질",
		"hint": "유자 껍질로 국물은 가볍게, 향은 산뜻하게.",
		"criteria": [
			{"kind": "has_any", "ids": ["topping_citrus_peel"], "min": 1, "hint": "토핑: 유자 껍질 (새벽 장터 채집)"},
			{"kind": "axis_max", "axis": "rich", "value": 5, "hint": "진함 5 이하"},
			{"kind": "axis_min", "axis": "aroma", "value": 5, "hint": "향 5 이상"},
		]},
	{"id": "sesame_roast", "title": "고소한 참깨 한 방울", "origin": "새벽 장터 채집: 볶은 참깨유",
		"hint": "볶은 참깨유로 고소하고 진한 국물을 만들어 보세요.",
		"criteria": [
			{"kind": "has_any", "ids": ["oil_roasted_sesame"], "min": 1, "hint": "향미유: 볶은 참깨유 (새벽 장터 채집)"},
			{"kind": "axis_min", "axis": "rich", "value": 6, "hint": "진함 6 이상 (돼지뼈 진국, 된장 타레가 도움)"},
		]},
]


## 연구 주제 목록(호출마다 새 깊은 복사본이라 호출자가 고쳐도 원본은 그대로).
## 각 항목: id, title, hint, origin, criteria([{kind, ..., hint}]).
static func catalog() -> Array:
	var out: Array = []
	for theme in _THEMES:
		out.append((theme as Dictionary).duplicate(true))
	return out


## 구성이 맞는 연구 주제 id(카탈로그 순서). 잘못된 구성은 빈 목록. 가격/이름/토핑 순서와 무관.
static func matched_ids(config: Dictionary) -> Array[String]:
	var out: Array[String] = []
	if Check.config_error(config) != "":
		return out
	var facts: Dictionary = _facts(config)
	for theme in _THEMES:
		var t: Dictionary = theme
		if _states(t, facts).count(false) == 0:
			out.append(str(t["id"]))
	return out


## 라멘 정체성 제안. 실패하면 {error: 메시지, title: "", subtitle: "", tags: []}.
## 사용자가 정한 이름은 입력으로 읽지 않으며(구성에는 이름이 없다) 결과를 어디에도 저장하지 않는다.
static func describe(config: Dictionary) -> Dictionary:
	var err: String = Check.config_error(config)
	if err != "":
		return {"error": err, "title": "", "subtitle": "", "tags": []}
	var broth: String = Catalog.broth_name(config) if config.has("broth_recipe") else _word(_BROTH_WORD, str(config["broth"]))
	var tare: String = _word(_TARE_WORD, str(config["tare"]))
	var oil: String = _word(_OIL_WORD, str(config["oil"]))
	var title: String = "%s %s타레 %s 라멘 · %s" % [broth, tare, oil, Catalog.topping_names(config)]
	var process: Dictionary = {}
	if config.has("process"):
		process = config["process"]
	var noodle: Dictionary = Catalog.find(str(config["noodle"]))
	var cook: Dictionary = Catalog.find(str(config["cook"]))
	var subtitle: String = "%s · %s · %s" % [str(noodle["name"]), str(cook["name"]), ProcessRules.summary(process)]
	var tags: Array[String] = []
	var facts: Dictionary = _facts(config)
	var profile: Dictionary = facts["profile"]
	for axis in Catalog.AXES:
		var value: int = int(profile[axis])
		var name: String = str(Catalog.AXIS_NAMES[axis])
		if value >= AXIS_HIGH:
			tags.append("%s 높음" % name)
		elif value <= AXIS_LOW and axis != "spice" and axis != "salt":
			# 매운맛/염도는 0~2가 보통이라 "낮음"으로 특징 짓지 않는다.
			tags.append("%s 낮음" % name)
	for slot in ProcessRules.SLOTS:
		var picked: String = ProcessRules.selected(process, slot)
		if picked != "standard":
			tags.append(str(ProcessRules.method(slot, picked)["name"]))
	var compat: int = int(facts["compat"])
	if compat >= COMPAT_GOOD:
		tags.append("궁합 좋음")
	elif compat <= -COMPAT_GOOD:
		tags.append("궁합 아쉬움")
	var cost: int = int(facts["cost"])
	if cost >= COST_HIGH:
		tags.append("원가 높음")
	elif cost <= COST_LOW:
		tags.append("알뜰한 원가")
	var prep: int = int(facts["prep"])
	if prep >= PREP_LONG:
		tags.append("준비 오래 걸림")
	elif prep <= PREP_SHORT:
		tags.append("빠른 준비")
	return {"error": "", "title": title, "subtitle": subtitle, "tags": tags}


## 연구 지도 한 장씩(카탈로그 순서). 카탈로그 항목에 아래 필드를 더한다.
##  - tested: records 중 하나라도 그 구성이 주제에 맞음(보관 중인 실제 시식 기록 기준; 중복 기록은 한 번으로 침).
##    모양이 틀린 기록(Dictionary 아님/config 없음/잘못된 구성)은 건너뛴다.
##  - ready: 초안이 지금 주제에 맞음(시식 전이므로 tested 와 별개).
##  - progress/total: 초안이 만족하는 기준 수/전체 기준 수. 잘못된 초안은 progress 0.
##  - missing: 초안이 못 채운 기준의 사람용 힌트. 잘못된 초안이면 모든 기준.
##  - unavailable: 아직 쓸 수 없어 못 채우는 재료 id. 시작 재료는 항상 쓸 수 있다고 보고, 탐험 발견 재료와 새벽 장터 채집 재료는 available 에 있어야 한다.
##    has_any 기준의 후보 중 하나라도 쓸 수 있으면 그 기준은 막히지 않은 것이다.
## 입력(records/draft/available)은 바꾸지 않는다.
static func pages(records: Array, draft: Dictionary, available: Array[String]) -> Array:
	var tested: Dictionary = {}
	for record in records:
		if typeof(record) != TYPE_DICTIONARY:
			continue
		var rd: Dictionary = record
		if not rd.has("config") or typeof(rd["config"]) != TYPE_DICTIONARY:
			continue
		for id in matched_ids(rd["config"]):
			tested[id] = true
	var draft_valid: bool = Check.config_error(draft) == ""
	var draft_facts: Dictionary = _facts(draft) if draft_valid else {}
	var out: Array = []
	for theme in _THEMES:
		var t: Dictionary = theme
		var page: Dictionary = (t as Dictionary).duplicate(true)
		var criteria: Array = t["criteria"]
		var states: Array = _states(t, draft_facts) if draft_valid else []
		var missing: Array[String] = []
		var progress: int = 0
		for i in criteria.size():
			if draft_valid and bool(states[i]):
				progress += 1
			else:
				missing.append(str((criteria[i] as Dictionary)["hint"]))
		page["tested"] = tested.has(str(t["id"]))
		page["ready"] = draft_valid and progress == criteria.size()
		page["progress"] = progress
		page["total"] = criteria.size()
		page["missing"] = missing
		page["unavailable"] = _unavailable(criteria, available)
		out.append(page)
	return out


# ---------- 내부 ----------

## 검증을 통과한 구성에서 기준이 읽는 사실을 한 번에 모은다(평가기 재사용, 축 계산을 복사하지 않는다).
static func _facts(config: Dictionary) -> Dictionary:
	var applied: Array = Evaluator.applied_compat(config)
	return {
		"profile": Evaluator.build_profile(config),
		"ids": Catalog.item_ids(config),
		"toppings": Catalog.toppings_of(config),
		"compat": Evaluator.compat_total(applied),
		"cost": Evaluator.unit_cost(config),
		"prep": Evaluator.prep_seconds(config),
	}


## 주제의 기준별 충족 여부(기준 순서). facts 가 비어 있으면(잘못된 구성) 호출하지 않는다.
static func _states(theme: Dictionary, facts: Dictionary) -> Array:
	var out: Array = []
	for criterion in (theme["criteria"] as Array):
		out.append(_met(criterion, facts))
	return out


static func _met(criterion: Dictionary, facts: Dictionary) -> bool:
	var profile: Dictionary = facts["profile"]
	match str(criterion["kind"]):
		"has_any":
			var ids: Array = facts["ids"]
			var count: int = 0
			for id in ids:
				if (criterion["ids"] as Array).has(id):
					count += 1
			return count >= int(criterion.get("min", 1))
		"axis_min":
			return int(profile[str(criterion["axis"])]) >= int(criterion["value"])
		"axis_max":
			return int(profile[str(criterion["axis"])]) <= int(criterion["value"])
		"repeat_topping":
			var toppings: Array = facts["toppings"]
			for id in toppings:
				if toppings.count(id) >= int(criterion["min"]):
					return true
			return false
	# 알 수 없는 기준 종류는 데이터 오류이므로 충족으로 치지 않는다.
	return false


static func _unavailable(criteria: Array, available: Array[String]) -> Array[String]:
	var out: Array[String] = []
	for c in criteria:
		var criterion: Dictionary = c
		if str(criterion["kind"]) != "has_any":
			continue
		var reachable: bool = false
		for id in (criterion["ids"] as Array):
			var key: String = str(id)
			if not (Catalog.is_discovery(key) or Catalog.is_farmed(key)) or available.has(key):
				reachable = true
		if reachable:
			continue
		for id in (criterion["ids"] as Array):
			var key: String = str(id)
			if not out.has(key):
				out.append(key)
	return out


static func _word(table: Dictionary, id: String) -> String:
	if table.has(id):
		return str(table[id])
	var item: Dictionary = Catalog.find(id)
	return str(item["name"]) if not item.is_empty() else id
