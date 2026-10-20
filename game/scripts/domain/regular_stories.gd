extends RefCounted
## 선택과 영수증의 순서/메뉴/조건을 검증한다. 수락·답례의 실제 원자 거래는 GameState가 소유한다.
const Catalog = preload("res://scripts/domain/regular_story_catalog.gd")
const Check = preload("res://scripts/domain/data_check.gd")
const Ingredients = preload("res://scripts/domain/ingredient_catalog.gd")
const Evaluator = preload("res://scripts/domain/recipe_evaluator.gd")
const Exploration = preload("res://scripts/domain/ingredient_exploration.gd")
const ProcessRules = preload("res://scripts/domain/recipe_process.gd")
const REWARDS: Array[int] = [2000, 4000]
const RECEIPT_KEYS: Array = ["record_id", "name", "version", "tasted_day", "config", "service_day", "day", "units"]

static func find(arcs: Array, customer: String) -> Dictionary:
	for arc in arcs:
		if arc["customer"] == customer:
			return arc.duplicate(true)
	return {}

static func metrics(customer: String, config: Dictionary) -> Dictionary:
	var ev: Dictionary = Evaluator.evaluate(config)
	if str(ev["error"]) != "":
		return {}
	for row in ev["customers"]:
		if row["id"] == customer:
			return {"score":int(row["score"]), "price":int(config["price"]), "prep":int(ev["prep_seconds"]), "cost":int(ev["unit_cost"]), "profile":ev["profile"].duplicate(true)}
	return {}

## 복수 메뉴에서는 전체 손님 수가 아니라 정확히 해당 메뉴를 먹은 손님의 완료 수량을 읽는다.
static func served(report: Dictionary, record: Dictionary, customer: String) -> int:
	if report.is_empty():
		return 0
	if report.has("menus"):
		for row in report["menus"]:
			if row["record_id"] == record["record_id"] and row["recipe_name"] == record["name"] and row["version"] == record["version"] and Check.same_config(row["config"], record["config"]):
				return int(row["by_source"].get(customer, 0))
		return 0
	if report["recipe_name"] == record["name"] and report["version"] == record["version"] and int(record["tasted_day"]) <= int(report["day"]):
		return int(report["by_source"].get(customer, 0))
	return 0

static func check(arc: Dictionary, record: Dictionary, report: Dictionary) -> Dictionary:
	if arc.is_empty() or arc["receipts"].size() >= 2:
		return {"error":"먼저 이야기의 방향을 정하거나 진행 중인 이야기를 골라 주세요.", "all_met":false, "lines":[]}
	if record.is_empty():
		return {"error":"시식한 기록을 노트에서 골라 주세요.", "all_met":false, "lines":[]}
	var index: int = arc["receipts"].size()
	var result: Dictionary = Catalog.assess(arc["customer"], arc["route"], index, metrics(arc["customer"], record["config"]))
	if str(result["error"]) != "":
		return result
	var earliest: int = int(arc["opened_day"]) if index == 0 else int(arc["receipts"][0]["day"])
	var new_recipe: bool = index == 0 or (int(record["tasted_day"]) >= earliest and not Check.same_config(record["config"], arc["receipts"][0]["config"]))
	var units: int = served(report, record, arc["customer"])
	var fresh_service: bool = not report.is_empty() and int(report["day"]) >= earliest and units > 0
	result["lines"].append("%s %d일차 이후 해당 메뉴를 단골이 먹은 완료 영업 · 최근 %d그릇" % ["[달성]" if fresh_service else "[부족]", earliest, units])
	if index == 1:
		result["lines"].append("%s 첫 답례 이후 새로 시식한 다른 구성의 메뉴" % ("[달성]" if new_recipe else "[부족]"))
	result["all_met"] = bool(result["all_met"]) and fresh_service and new_recipe
	result["units"] = units
	return result

## 남아 있는 기록은 바이트 모양 대신 정규 값으로 비교한다. 삭제된 과거 메뉴도 스냅샷을 자체 검증해 보존한다.
static func parse(raw: Variant, day: int, next_id: int, retained: Dictionary, rank: int, slots: int, discovered: Array, report: Dictionary) -> Dictionary:
	if typeof(raw) != TYPE_DICTIONARY or Check.keys_error(raw, ["arcs"], "단골 이야기") != "" or typeof(raw["arcs"]) != TYPE_ARRAY or raw["arcs"].size() > 3:
		return _fail("이야기 목록 형식이 올바르지 않아요.")
	var arcs: Array = []
	var seen: Dictionary = {}
	for value in raw["arcs"]:
		if typeof(value) != TYPE_DICTIONARY or Check.keys_error(value, ["customer", "route", "opened_day", "receipts"], "단골 사연") != "":
			return _fail("사연 형식이 올바르지 않아요.")
		var a: Dictionary = value.duplicate(true)
		if typeof(a["customer"]) != TYPE_STRING or typeof(a["route"]) != TYPE_STRING or Catalog.route(a["customer"], a["route"]).is_empty() or seen.has(a["customer"]):
			return _fail("모르는 단골/방향이거나 중복된 사연이에요.")
		if not Check.in_range(a["opened_day"], 2, day) or typeof(a["receipts"]) != TYPE_ARRAY or a["receipts"].size() > 2:
			return _fail("사연 시작일/장 순서가 올바르지 않아요.")
		a["opened_day"] = int(a["opened_day"])
		var parsed: Array = []
		for entry in a["receipts"]:
			if typeof(entry) != TYPE_DICTIONARY or Check.keys_error(entry, RECEIPT_KEYS, "단골 답례") != "":
				return _fail("답례 형식이 올바르지 않아요.")
			var e: Dictionary = entry.duplicate(true)
			var earliest: int = a["opened_day"] if parsed.is_empty() else int(parsed[0]["day"])
			if not Check.in_range(e["record_id"], 1, next_id - 1) or not Check.in_range(e["version"], 1, 9999) or typeof(e["name"]) != TYPE_STRING or Check.name_error(e["name"], false) != "":
				return _fail("답례 메뉴 이름/번호가 올바르지 않아요.")
			if not Check.in_range(e["service_day"], earliest, day - 1) or not Check.in_range(e["day"], int(e["service_day"]) + 1, day) or not Check.in_range(e["tasted_day"], 1 if parsed.is_empty() else earliest, int(e["service_day"])) or not Check.in_range(e["units"], 1, 200):
				return _fail("답례/시식/영업 날짜나 완료 수량이 올바르지 않아요.")
			for key in ["record_id", "version", "service_day", "day", "tasted_day", "units"]:
				e[key] = int(e[key])
			# 일차는 완료 영업에서만 늘어난다. 답례는 그 최근 보고를 쓰므로 항상 바로 다음 일차다.
			# 과거 메뉴를 삭제해도 보고 자체를 없애는 정상 경로는 없으므로 고아 영수증도 거부한다.
			if e["day"] != e["service_day"] + 1 or report.is_empty() or int(report["day"]) < e["service_day"]:
				return _fail("답례 날짜와 남아 있는 최근 영업의 순서가 달라요.")
			var config: Dictionary = Check.parse_config(e["config"], "단골 메뉴")
			if str(config["error"]) != "":
				return _fail(str(config["error"]))
			e["config"] = config["config"]
			if Ingredients.toppings_of(e["config"]).size() > slots or Exploration.locked_in(e["config"], discovered) != "" or int(ProcessRules.effects(e["config"].get("process", {}))["rank"]) > rank:
				return _fail("아직 열리지 않은 단골 메뉴 구성이에요.")
			if not parsed.is_empty() and Check.same_config(parsed[0]["config"], e["config"]):
				return _fail("다음 장에는 새 메뉴 구성이 필요해요.")
			var checked: Dictionary = Catalog.assess(a["customer"], a["route"], parsed.size(), metrics(a["customer"], e["config"]))
			if str(checked["error"]) != "" or not bool(checked["all_met"]):
				return _fail("답례 메뉴가 해당 장의 조건을 만족하지 않아요.")
			if retained.has(e["record_id"]):
				var rec: Dictionary = retained[e["record_id"]]
				for key in ["record_id", "name", "version", "tasted_day"]:
					if rec[key] != e[key]:
						return _fail("남아 있는 기록과 답례 메뉴가 달라요.")
				if not Check.same_config(rec["config"], e["config"]):
					return _fail("남아 있는 기록과 답례 구성이 달라요.")
			if not report.is_empty() and int(report["day"]) == e["service_day"] and served(report, e, a["customer"]) != e["units"]:
				return _fail("최근 영업의 실제 단골 완료 수량과 달라요.")
			parsed.append(e)
		a["receipts"] = parsed
		seen[a["customer"]] = true
		arcs.append(a)
	return {"error":"", "arcs":arcs}

static func _fail(message: String) -> Dictionary:
	return {"error":"단골 이야기: " + message, "arcs":[]}
