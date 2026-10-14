extends RefCounted
## 라멘 연구 의뢰: 단골 세 분이 각각 입문 1개 + 심화 1개, 모두 6개의 고정 의뢰. 분기 스토리가 아니라 짧은 의뢰 대사다.
## 이 파일은 데이터와 순수 계산(조건 판정, 해금, 보상, 칭호, 저장 검증)만 가진다. 상태 변경은 GameState.submit_research()가 한다.
##
## 조건 판정은 기존 평가기를 그대로 쓴다. 입력은 "시식 기록(record)"의 불변 구성/점수뿐이라 초안은 진행에 영향을 줄 수 없다.
##   score_min  : 해당 손님의 시식 점수(기록에 저장된 값, 평가기 결과와 같음)
##   price_min/max : 기록의 판매가       prep_max : 준비 시간 합(초)       cost_max : 그릇당 원가
##   axis_min/max  : 맛 프로필 축 값(0~10)
## 임계값은 손으로 따로 계산한 증인 조합(WITNESSES)으로 달성 가능함을 보였고, 테스트가 평가기로 다시 확인하고
## 전체 재료 조합(972가지) x 가격 표본을 훑어 단일 레시피가 여섯 의뢰를 모두 만족할 수 없음도 확인한다.
##
## 보상(고정): 입문 연구 점수 2 + 2,000원, 심화 연구 점수 5 + 5,000원. 여섯 개를 모두 마치면 점수 21, 자금 21,000원이 상한이다.
## 해금: 입문 의뢰 중 아무 2개를 완료하면 심화 의뢰 세 개가 열린다.

const Catalog = preload("res://scripts/domain/ingredient_catalog.gd")
const Customers = preload("res://scripts/domain/customer_catalog.gd")
const Check = preload("res://scripts/domain/data_check.gd")
const Evaluator = preload("res://scripts/domain/recipe_evaluator.gd")

const TIER_BASIC: String = "basic"
const TIER_ADVANCED: String = "advanced"
const UNLOCK_BASIC_COUNT: int = 2

const REWARD_POINTS: Dictionary = {"basic": 2, "advanced": 5}
const REWARD_CASH: Dictionary = {"basic": 2000, "advanced": 5000}

## 연구 칭호: 누적 점수가 min 이상인 가장 높은 단계. 점수는 완료 목록에서 매번 계산하며 저장하지 않는다.
const STAGES: Array = [
	{"min": 0, "title": "견습 연구생"},
	{"min": 4, "title": "라멘 연구원"},
	{"min": 9, "title": "선임 연구원"},
	{"min": 21, "title": "라멘 연구 박사"},
]

const ENTRY_KEYS: Array = ["request_id", "record_id", "recipe_name", "version", "day", "points", "cash"]

const REQUESTS: Array = [
	{
		"id": "dohyun_basic", "customer": "dohyun", "tier": "basic",
		"title": "든든한 한 그릇",
		"dialogue": "야근 끝에 먹을 한 그릇이 필요해요. 진하고 든든한데, 재료비가 너무 올라가지 않는 메뉴를 만들어 줄래요?",
		"hint": "돼지뼈 진국에 굵은 꼬불면이 잘 어울려요. 차슈는 비싸니 김처럼 싼 토핑으로 원가를 아낄 수 있어요.",
		"conditions": [
			{"kind": "score_min", "customer": "dohyun", "value": 80},
			{"kind": "cost_max", "value": 2000},
		],
	},
	{
		"id": "hayoung_basic", "customer": "hayoung", "tier": "basic",
		"title": "점심시간 안에 한 그릇",
		"dialogue": "점심시간이 짧아서 금방 나오는 맑은 국물이 좋아요. 향은 풍부하고 간은 약하게요!",
		"hint": "해물 다시와 가는 직면, 소금 타레는 빠르고 향이 좋아요. 굵은 면은 삶는 데만 100초가 걸려요.",
		"conditions": [
			{"kind": "score_min", "customer": "hayoung", "value": 80},
			{"kind": "prep_max", "value": 100},
		],
	},
	{
		"id": "maru_basic", "customer": "maru", "tier": "basic",
		"title": "용돈으로 얼큰하게",
		"dialogue": "용돈이 빠듯해서 비싼 건 못 먹어요. 그래도 얼큰하고 짭짤해야 라멘 먹은 기분이 나죠!",
		"hint": "닭 육수에 된장 타레와 고추기름이 얼큰하게 어울려요. 판매가를 내리면 마루가 더 자주 와요.",
		"conditions": [
			{"kind": "score_min", "customer": "maru", "value": 75},
			{"kind": "price_max", "value": 8500},
		],
	},
	{
		"id": "dohyun_advanced", "customer": "dohyun", "tier": "advanced",
		"title": "야근 끝판왕 국물",
		"dialogue": "이번엔 진짜 진한 국물을 부탁해요. 단, 손님이 기다리다 지치지 않게 한 그릇이 3분 안에는 나와야 해요.",
		"hint": "굵은 면은 100초나 걸려요. 익힘을 '보통'으로 하고, 간장 타레·마늘유와 맞추면 진함과 궁합을 함께 잡을 수 있어요.",
		"conditions": [
			{"kind": "score_min", "customer": "dohyun", "value": 88},
			{"kind": "axis_min", "axis": "rich", "value": 8},
			{"kind": "prep_max", "value": 180},
		],
	},
	{
		"id": "hayoung_advanced", "customer": "hayoung", "tier": "advanced",
		"title": "수업 전 맑은 한 그릇",
		"dialogue": "오후 수업 전에 먹을 완벽한 맑은 국물을 찾고 있어요. 빨리 나오되 값은 제대로 받아야 가게가 오래 가죠.",
		"hint": "해물 다시 + 가는 직면 + 꼬들한 익힘은 궁합이 아주 좋아요. 파기름·소금 타레로 향을 살리고 가격은 8,500원 이상으로 받으세요.",
		"conditions": [
			{"kind": "score_min", "customer": "hayoung", "value": 90},
			{"kind": "prep_max", "value": 90},
			{"kind": "price_min", "value": 8500},
		],
	},
	{
		"id": "maru_advanced", "customer": "maru", "tier": "advanced",
		"title": "가성비 얼큰 한 그릇",
		"dialogue": "싸고 빠르고 얼큰한 한 그릇! 원가는 낮추고 값도 7,500원 이하로 묶어 줘야 대학원생 지갑이 버텨요.",
		"hint": "비싼 토핑은 빼고 가는 면 + 꼬들한 익힘으로 시간을 줄여요. 닭 육수·된장 타레·고추기름 조합이 출발점이에요.",
		"conditions": [
			{"kind": "score_min", "customer": "maru", "value": 84},
			{"kind": "prep_max", "value": 90},
			{"kind": "cost_max", "value": 1500},
			{"kind": "price_max", "value": 7500},
		],
	},
]

## 달성 가능성 증인(손으로 계산한 값은 문서에, 테스트가 평가기로 재확인): 요청 id -> 구성.
const WITNESSES: Dictionary = {
	"dohyun_basic": {"broth": "broth_tonkotsu", "tare": "tare_shoyu", "oil": "oil_garlic", "noodle": "noodle_thick", "topping": "topping_nori", "cook": "cook_normal", "price": 9500},
	"hayoung_basic": {"broth": "broth_dashi", "tare": "tare_shio", "oil": "oil_scallion", "noodle": "noodle_thin", "topping": "topping_nori", "cook": "cook_firm", "price": 9000},
	"maru_basic": {"broth": "broth_chicken", "tare": "tare_miso", "oil": "oil_chili", "noodle": "noodle_thin", "topping": "topping_nori", "cook": "cook_firm", "price": 8000},
	"dohyun_advanced": {"broth": "broth_tonkotsu", "tare": "tare_shoyu", "oil": "oil_garlic", "noodle": "noodle_thick", "topping": "topping_chashu", "cook": "cook_normal", "price": 11000},
	"hayoung_advanced": {"broth": "broth_dashi", "tare": "tare_shio", "oil": "oil_scallion", "noodle": "noodle_thin", "topping": "topping_egg", "cook": "cook_firm", "price": 9000},
	"maru_advanced": {"broth": "broth_chicken", "tare": "tare_miso", "oil": "oil_chili", "noodle": "noodle_thin", "topping": "topping_nori", "cook": "cook_firm", "price": 7500},
}


static func requests() -> Array:
	return REQUESTS


static func ids() -> Array[String]:
	var out: Array[String] = []
	for r in REQUESTS:
		var d: Dictionary = r
		out.append(str(d["id"]))
	return out


static func find(id: String) -> Dictionary:
	for r in REQUESTS:
		var d: Dictionary = r
		if str(d["id"]) == id:
			return d
	return {}


static func _won(n: int) -> String:
	var digits: String = str(absi(n))
	var out: String = ""
	var count: int = 0
	for i in range(digits.length() - 1, -1, -1):
		out = digits[i] + out
		count += 1
		if count % 3 == 0 and i > 0:
			out = "," + out
	return ("-" if n < 0 else "") + out + "원"


# ---------- 해금/보상/칭호 ----------

## completed: 완료한 요청 id 배열(완료 순서)
static func basic_done_count(completed: Array) -> int:
	var n: int = 0
	for c in completed:
		var req: Dictionary = find(str(c))
		if not req.is_empty() and str(req["tier"]) == TIER_BASIC:
			n += 1
	return n


static func is_unlocked(request_id: String, completed: Array) -> bool:
	var req: Dictionary = find(request_id)
	if req.is_empty():
		return false
	if str(req["tier"]) == TIER_BASIC:
		return true
	return basic_done_count(completed) >= UNLOCK_BASIC_COUNT


static func lock_reason(request_id: String, completed: Array) -> String:
	if is_unlocked(request_id, completed):
		return ""
	return "입문 연구를 %d개 완료하면 열려요 (지금 %d/%d)." % [UNLOCK_BASIC_COUNT, basic_done_count(completed), UNLOCK_BASIC_COUNT]


static func points_of(completed: Array) -> int:
	var total: int = 0
	for c in completed:
		var req: Dictionary = find(str(c))
		if not req.is_empty():
			total += int(REWARD_POINTS[str(req["tier"])])
	return total


## {"stage": 1부터 시작하는 단계, "stages": 전체 단계 수, "title": 칭호}
static func stage_for(points: int) -> Dictionary:
	var idx: int = 0
	for i in STAGES.size():
		var s: Dictionary = STAGES[i]
		if points >= int(s["min"]):
			idx = i
	var cur: Dictionary = STAGES[idx]
	return {"stage": idx + 1, "stages": STAGES.size(), "title": str(cur["title"])}


# ---------- 조건 판정 ----------

## 시식 기록의 구성과 점수에서 판정에 쓰는 값을 모은다(가격 제외 값은 구성에만 의존).
static func measures_for(config: Dictionary, scores: Dictionary) -> Dictionary:
	return {
		"scores": scores,
		"price": int(config["price"]),
		"prep": Evaluator.prep_seconds(config),
		"cost": Evaluator.unit_cost(config),
		"profile": Evaluator.build_profile(config),
	}


static func measured_value(cond: Dictionary, m: Dictionary) -> int:
	match str(cond["kind"]):
		"score_min":
			var sc: Dictionary = m["scores"]
			return int(sc[str(cond["customer"])])
		"price_min", "price_max":
			return int(m["price"])
		"prep_max":
			return int(m["prep"])
		"cost_max":
			return int(m["cost"])
		"axis_min", "axis_max":
			var pr: Dictionary = m["profile"]
			return int(pr[str(cond["axis"])])
	return 0


static func condition_met(cond: Dictionary, m: Dictionary) -> bool:
	var v: int = measured_value(cond, m)
	if str(cond["kind"]).ends_with("_min"):
		return v >= int(cond["value"])
	return v <= int(cond["value"])


static func request_met(req: Dictionary, m: Dictionary) -> bool:
	for c in req["conditions"]:
		var cd: Dictionary = c
		if not condition_met(cd, m):
			return false
	return true


## 화면용 판정: 조건마다 {"text","measured_text","met","hint"}. 미충족 조건에는 사람이 읽을 힌트가 붙는다.
## 반환: {"error": "", "conditions": Array, "all_met": bool}
static func check(request_id: String, config: Dictionary, scores: Dictionary) -> Dictionary:
	var req: Dictionary = find(request_id)
	if req.is_empty():
		return {"error": "알 수 없는 연구 의뢰예요.", "conditions": [], "all_met": false}
	var evaluation: Dictionary = Evaluator.evaluate(config)
	if str(evaluation["error"]) != "":
		return {"error": str(evaluation["error"]), "conditions": [], "all_met": false}
	# 점수는 항상 방금 평가기로 계산한 값을 쓴다. 넘겨받은(저장된) 점수가 계산값과 다르면 조작/손상이므로 판정하지 않고 거부한다.
	var fresh: Dictionary = {}
	var headlines: Dictionary = {}
	for c in evaluation["customers"]:
		var cd: Dictionary = c
		fresh[str(cd["id"])] = int(cd["score"])
		headlines[str(cd["id"])] = str(cd["headline"])
	for cid in fresh:
		if not scores.has(cid) or not Check.is_whole(scores[cid]) or int(scores[cid]) != int(fresh[cid]):
			return {"error": "기록의 점수가 구성의 평가 결과와 달라 심사할 수 없어요.", "conditions": [], "all_met": false}
	var m: Dictionary = measures_for(config, fresh)
	var out: Array = []
	var all_met: bool = true
	for c in req["conditions"]:
		var cond: Dictionary = c
		var met: bool = condition_met(cond, m)
		var v: int = measured_value(cond, m)
		if not met:
			all_met = false
		out.append({
			"text": condition_text(cond),
			"measured_text": _measured_text(cond, v),
			"met": met,
			"hint": "" if met else _unmet_hint(cond, v, headlines),
		})
	return {"error": "", "conditions": out, "all_met": all_met}


static func _axis_name(cond: Dictionary) -> String:
	return str(Catalog.AXIS_NAMES[str(cond["axis"])])


static func _customer_name(cond: Dictionary) -> String:
	var c: Dictionary = Customers.find(str(cond["customer"]))
	return str(c["name"])


static func condition_text(cond: Dictionary) -> String:
	var value: int = int(cond["value"])
	match str(cond["kind"]):
		"score_min":
			return "%s 점수 %d점 이상" % [_customer_name(cond), value]
		"price_min":
			return "판매가 %s 이상" % _won(value)
		"price_max":
			return "판매가 %s 이하" % _won(value)
		"prep_max":
			return "준비 시간 %d초 이하" % value
		"cost_max":
			return "그릇당 원가 %s 이하" % _won(value)
		"axis_min":
			return "%s %d 이상" % [_axis_name(cond), value]
		"axis_max":
			return "%s %d 이하" % [_axis_name(cond), value]
	return ""


static func _measured_text(cond: Dictionary, v: int) -> String:
	match str(cond["kind"]):
		"score_min":
			return "%d점" % v
		"price_min", "price_max", "cost_max":
			return _won(v)
		"prep_max":
			return "%d초" % v
	return str(v)


static func _unmet_hint(cond: Dictionary, v: int, headlines: Dictionary) -> String:
	var value: int = int(cond["value"])
	match str(cond["kind"]):
		"score_min":
			var who: String = str(cond["customer"])
			return "%s 님 반응은 '%s'예요. %d점이 더 필요해요. 재료와 궁합을 바꿔 다시 시식해 보세요." % [_customer_name(cond), str(headlines.get(who, "")), value - v]
		"price_min":
			return "판매가를 %s 올려야 해요. 비싸게 팔수록 손님은 줄어드니 맛으로 받쳐 주세요." % _won(value - v)
		"price_max":
			return "판매가를 %s 내려야 해요. 싸게 팔면 마진은 줄지만 손님이 늘어요." % _won(v - value)
		"prep_max":
			return "준비가 %d초 길어요. 굵은 면이나 푹 익힘, 돼지뼈 진국이 시간을 많이 써요." % (v - value)
		"cost_max":
			return "원가가 %s 높아요. 차슈나 돼지뼈 진국처럼 비싼 재료를 바꿔 보세요." % _won(v - value)
		"axis_min":
			return "%s이(가) %d 모자라요. 그 맛을 더하는 재료를 골라 보세요." % [_axis_name(cond), value - v]
		"axis_max":
			return "%s이(가) %d 넘쳐요. 그 맛을 덜어내는 재료를 골라 보세요." % [_axis_name(cond), v - value]
	return ""


# ---------- 저장 구조 ----------

## 저장되는 연구 진행은 완료 항목 목록뿐이다(총점/칭호/해금 상태는 이 목록에서 계산하므로 저장하지 않는다).
## 항목은 제출 영수증이다: 어떤 기록(record_id/이름/버전)으로 몇 일차에 얼마를 받았는지.
## 그 기록이 나중에 노트에서 삭제돼도 영수증은 유효하다(기록 번호는 "한 번 발급된 번호" 범위만 확인).
static func make_entry(request_id: String, record: Dictionary, day: int) -> Dictionary:
	var req: Dictionary = find(request_id)
	var tier: String = str(req["tier"])
	return {
		"request_id": request_id,
		"record_id": int(record["record_id"]),
		"recipe_name": str(record["name"]),
		"version": int(record["version"]),
		"day": day,
		"points": int(REWARD_POINTS[tier]),
		"cash": int(REWARD_CASH[tier]),
	}


## 외부(저장 파일)에서 온 진행을 모두 검증한다. 하나라도 어긋나면 에러 문자열만 돌려주고 호출자는 아무것도 반영하지 않는다.
## record_by_id: 현재 노트에 남아 있는 기록(id -> record). 기록이 남아 있으면 영수증과 일치해야 하고, 없으면 확인하지 않는다.
## 반환: {"error": String, "completed": Array(정규화된 항목, 완료 순서)}
static func parse_progress(raw: Variant, current_day: int, next_record_id: int, record_by_id: Dictionary) -> Dictionary:
	if typeof(raw) != TYPE_DICTIONARY:
		return {"error": "연구 진행 구조가 올바르지 않아요."}
	var d: Dictionary = raw
	var key_err: String = Check.keys_error(d, ["completed"], "연구 진행")
	if key_err != "":
		return {"error": key_err}
	if typeof(d["completed"]) != TYPE_ARRAY:
		return {"error": "연구 완료 목록 구조가 올바르지 않아요."}
	var items: Array = d["completed"]
	if items.size() > REQUESTS.size():
		return {"error": "연구 완료 수가 의뢰 수를 넘었어요."}
	var out: Array = []
	var done_ids: Array = []
	var last_day: int = 1
	for i in items.size():
		var ctx: String = "연구 완료 %d" % (i + 1)
		if typeof(items[i]) != TYPE_DICTIONARY:
			return {"error": ctx + ": 구조가 올바르지 않아요."}
		var e: Dictionary = items[i]
		var e_err: String = Check.keys_error(e, ENTRY_KEYS, ctx)
		if e_err != "":
			return {"error": e_err}
		if typeof(e["request_id"]) != TYPE_STRING or find(str(e["request_id"])).is_empty():
			return {"error": ctx + ": 알 수 없는 의뢰예요."}
		var rid: String = str(e["request_id"])
		if done_ids.has(rid):
			return {"error": ctx + ": 같은 의뢰가 중복 완료돼 있어요."}
		# 해금 순서: 심화 의뢰는 그 앞에 입문 완료가 이미 2개 이상 있어야 한다(완료 순서가 곧 해금 순서).
		if not is_unlocked(rid, done_ids):
			return {"error": ctx + ": 해금되기 전에 완료된 의뢰예요."}
		var req: Dictionary = find(rid)
		var tier: String = str(req["tier"])
		if not Check.in_range(e["points"], 0, 1000) or int(e["points"]) != int(REWARD_POINTS[tier]):
			return {"error": ctx + ": 보상 점수가 의뢰와 맞지 않아요."}
		if not Check.in_range(e["cash"], 0, 1000000000) or int(e["cash"]) != int(REWARD_CASH[tier]):
			return {"error": ctx + ": 보상 금액이 의뢰와 맞지 않아요."}
		# 기록 번호는 이미 발급된 범위(1 ~ next_record_id-1)면 충분하다. 삭제된 기록도 정상이다.
		if not Check.in_range(e["record_id"], 1, next_record_id - 1):
			return {"error": ctx + ": 기록 번호가 올바르지 않아요."}
		if not Check.in_range(e["version"], 1, 9999):
			return {"error": ctx + ": 버전이 올바르지 않아요."}
		if not Check.in_range(e["day"], 1, current_day) or int(e["day"]) < last_day:
			return {"error": ctx + ": 완료일이 올바르지 않아요."}
		if typeof(e["recipe_name"]) != TYPE_STRING:
			return {"error": ctx + ": 레시피 이름 형식이 올바르지 않아요."}
		var rname: String = e["recipe_name"]
		if Check.name_error(rname, false) != "" or rname != rname.strip_edges():
			return {"error": ctx + ": 레시피 이름이 올바르지 않아요."}
		var rec_id: int = int(e["record_id"])
		if record_by_id.has(rec_id):
			var rec: Dictionary = record_by_id[rec_id]
			if str(rec["name"]) != rname or int(rec["version"]) != int(e["version"]) or int(e["day"]) < int(rec["tasted_day"]):
				return {"error": ctx + ": 노트의 기록과 제출 내용이 달라요."}
			# 기록이 남아 있으면 실제로 그 의뢰 조건을 만족해야 한다(평가기를 다시 돌린 값 기준). 삭제된 기록은 확인할 수 없으므로 영수증만 본다.
			var verdict: Dictionary = check(rid, rec["config"], rec["scores"])
			if str(verdict["error"]) != "" or not bool(verdict["all_met"]):
				return {"error": ctx + ": 노트에 남은 기록이 이 의뢰 조건을 만족하지 않아요."}
		last_day = int(e["day"])
		done_ids.append(rid)
		out.append({
			"request_id": rid,
			"record_id": rec_id,
			"recipe_name": rname,
			"version": int(e["version"]),
			"day": int(e["day"]),
			"points": int(e["points"]),
			"cash": int(e["cash"]),
		})
	return {"error": "", "completed": out}
