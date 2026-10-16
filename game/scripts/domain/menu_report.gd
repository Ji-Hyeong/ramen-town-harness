extends RefCounted
## 확장 영업 보고의 자급식 영수증 검사. 삭제된 노트 기록도 당시 구성/가격/자격으로 재검증한다.
## 공통 운영비는 한 번, 메뉴 이익은 재료비만 차감한 공헌이익이다. 대기 합계는 실제 완료 주문만 포함한다.
const Check = preload("res://scripts/domain/data_check.gd")
const Catalog = preload("res://scripts/domain/ingredient_catalog.gd")
const Customers = preload("res://scripts/domain/customer_catalog.gd")
const Staffing = preload("res://scripts/domain/shop_staffing.gd")
const MenuSales = preload("res://scripts/domain/menu_sales.gd")
const Exploration = preload("res://scripts/domain/ingredient_exploration.gd")
const ProcessRules = preload("res://scripts/domain/recipe_process.gd")

const KEYS: Array = ["day", "recipe_name", "version", "price", "units", "revenue", "ingredient_cost", "overhead", "net", "wallet_after", "by_source", "menus", "seat_count", "staffing"]
const ROW_KEYS: Array = ["record_id", "recipe_name", "version", "config", "scores", "prep", "price", "unit_cost", "demand", "units", "revenue", "ingredient_cost", "margin", "by_source", "wait_total"]


## JSON의 정수 float만 확인해 int로 바꾼다. bool/소수/문자열을 정수로 위장하지 않는다.
static func normalize(value: Variant) -> Variant:
	if typeof(value) == TYPE_FLOAT and Check.is_whole(value):
		return int(value)
	if typeof(value) == TYPE_DICTIONARY:
		var d: Dictionary = {}
		for k in value:
			d[k] = normalize(value[k])
		return d
	if typeof(value) == TYPE_ARRAY:
		var a: Array = []
		for x in value:
			a.append(normalize(x))
		return a
	return value


static func parse(raw: Variant, current_day: int, next_id: int, retained: Dictionary, discovered: Array, slots: int, rank: int = 3) -> Dictionary:
	if typeof(raw) != TYPE_DICTIONARY:
		return _fail("구조가 올바르지 않아요.")
	var d: Dictionary = normalize(raw)
	var key_error: String = Check.keys_error(d, KEYS, "메뉴 영업 보고")
	if key_error != "":
		return _fail(key_error)
	if not Check.in_range(d["day"], 1, current_day - 1) or d["recipe_name"] != "오늘의 메뉴" or typeof(d["recipe_name"]) != TYPE_STRING:
		return _fail("영업일/제목이 올바르지 않아요.")
	if typeof(d["price"]) != TYPE_INT or int(d["price"]) != 0 or typeof(d["version"]) != TYPE_INT or int(d["version"]) != 1:
		return _fail("공통 가격/버전은 메뉴별 보고로 확인해야 해요.")
	if typeof(d["seat_count"]) != TYPE_INT or int(d["seat_count"]) != 12:
		return _fail("확장 영업은 12석이어야 해요.")
	if typeof(d["staffing"]) != TYPE_DICTIONARY:
		return _fail("직원 구성 형식이 올바르지 않아요.")
	var staff_error: String = Staffing.snapshot_error(d["staffing"])
	if staff_error != "":
		return _fail(staff_error)
	for k in ["units", "revenue", "ingredient_cost", "overhead", "wallet_after"]:
		if not Check.in_range(d[k], 0, 1000000000):
			return _fail("%s 값이 범위를 벗어나요." % k)
	if not Check.in_range(d["net"], -1000000000, 1000000000):
		return _fail("순이익 범위가 올바르지 않아요.")
	if typeof(d["menus"]) != TYPE_ARRAY or d["menus"].size() < 1 or d["menus"].size() > 2:
		return _fail("메뉴 목록이 올바르지 않아요.")
	var records: Array = []
	for raw_row in d["menus"]:
		if typeof(raw_row) != TYPE_DICTIONARY:
			return _fail("메뉴 행 형식이 올바르지 않아요.")
		var row: Dictionary = raw_row
		key_error = Check.keys_error(row, ROW_KEYS, "메뉴 보고")
		if key_error != "":
			return _fail(key_error)
		if not Check.in_range(row["record_id"], 1, next_id - 1) or typeof(row["recipe_name"]) != TYPE_STRING or not Check.in_range(row["version"], 1, 9999):
			return _fail("메뉴 기록 번호/이름/버전이 올바르지 않아요.")
		var config: Dictionary = Check.parse_config(row["config"], "메뉴 보고 구성")
		if str(config["error"]) != "":
			return _fail(str(config["error"]))
		row["config"] = config["config"]
		if int(ProcessRules.effects(row["config"].get("process", {}))["rank"]) > rank:
			return _fail("메뉴 공법에 필요한 가게 등급이 없어요.")
		if Catalog.toppings_of(row["config"]).size() > slots or Exploration.locked_in(row["config"], discovered) != "":
			return _fail("아직 열리지 않은 구성의 메뉴가 있어요.")
		if not Check.in_range(row["units"], 0, 200) or not Check.in_range(row["wait_total"], 0, int(row["units"]) * 4800):
			return _fail("완료 주문/대기 시간이 올바르지 않아요.")
		var id: int = int(row["record_id"])
		if retained.has(id):
			var rec: Dictionary = retained[id]
			if rec["name"] != row["recipe_name"] or rec["version"] != row["version"] or not Check.same_config(rec["config"], row["config"]) or int(rec["tasted_day"]) > int(d["day"]):
				return _fail("남아 있는 시식 기록과 영업 메뉴가 달라요.")
		records.append({"record_id": id, "name": row["recipe_name"], "version": row["version"], "config": row["config"]})
	var expected: Dictionary = MenuSales.simulate(records, int(d["day"]), d["staffing"])
	if str(expected["error"]) != "":
		return _fail(str(expected["error"]))
	for k in ["units", "revenue", "ingredient_cost", "overhead", "net", "by_source"]:
		if _json(d[k]) != _json(expected[k]):
			return _fail("영업 합계가 실제 메뉴 계산과 달라요 (%s)." % k)
	for i in d["menus"].size():
		var actual: Dictionary = d["menus"][i].duplicate(true)
		actual.erase("wait_total")
		if _json(actual) != _json(expected["menus"][i]):
			return _fail("메뉴별 주문/금액/맛/시간이 다시 계산한 결과와 달라요.")
	return {"error": "", "report": d}


static func _json(v: Variant) -> String:
	return JSON.stringify(normalize(v), "", true)


static func _fail(message: String) -> Dictionary:
	return {"error": "메뉴 영업 보고: " + message}
