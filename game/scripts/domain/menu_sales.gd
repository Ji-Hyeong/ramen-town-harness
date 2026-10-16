extends RefCounted
## 두 메뉴가 같은 손님과 같은 주방을 나눠 쓰는 하루 영업 계산(결정적, 순수 함수).
##
## 1개 메뉴: 기존 Sim.simulate 결과와 모든 필드가 같고 menus 한 행만 더한다.
## 2개 메뉴:
##  - 손님 그룹(단골 3명 + walkin)마다 방문 수는 max(수요A, 수요B) 한 번만이다(손님을 두 배로 만들지 않는다).
##  - 그 방문을 두 메뉴의 수요 비율로 나눈다(내림 + 최대 나머지, 동률이면 더 작은 record_id).
##  - 주방 2400초는 하나다. record_id 오름차순 × 손님 순서의 (메뉴, 그룹) 칸에 라운드마다 한 그릇씩 시간을 쓰며 배분한다.
## 도착 시각/난수/좌석/세션/돈/저장은 다루지 않는다. 모든 계산은 정수이고 입력은 바꾸지 않는다.

const Sim = preload("res://scripts/domain/sales_simulator.gd")
const Customers = preload("res://scripts/domain/customer_catalog.gd")
const Catalog = preload("res://scripts/domain/ingredient_catalog.gd")
const Check = preload("res://scripts/domain/data_check.gd")
const Evaluator = preload("res://scripts/domain/recipe_evaluator.gd")
const Staffing = preload("res://scripts/domain/shop_staffing.gd")

const MAX_DAY: int = 99999
const MAX_MENUS: int = 2
const MAX_UNITS: int = 200
const MAX_VERSION: int = 9999


## records: 길이 1~2의 {record_id, name, version, config, ...}. 점수는 입력을 믿지 않고 실제 평가로 다시 구한다.
## 반환: Sim.simulate 필드(error, units, revenue, ingredient_cost, overhead, net, demand, capacity, by_source) + "menus".
## menus 행: {record_id, recipe_name, version, config, scores, prep, price, unit_cost, demand, units, revenue,
##   ingredient_cost, margin(공통 운영비 전), by_source}. 행 순서는 입력 순서. 실패는 {"error": 비어 있지 않은 문장}.
static func simulate(records: Array, day: int, staffing: Dictionary = {}) -> Dictionary:
	if records.size() < 1 or records.size() > MAX_MENUS:
		return {"error": "판매 메뉴는 1~%d개여야 해요." % MAX_MENUS}
	if day < 1 or day > MAX_DAY:
		return {"error": "영업일은 1~%d 사이여야 해요." % MAX_DAY}
	var staff: Dictionary = staffing.duplicate(true)
	var staff_err: String = Staffing.snapshot_error(staff)
	if staff_err != "":
		return {"error": staff_err}
	var menus: Array = []
	var seen: Dictionary = {}
	for raw in records:
		var menu: Dictionary = _prepare(raw, staff)
		if str(menu["error"]) != "":
			return {"error": str(menu["error"])}
		if seen.has(menu["record_id"]):
			return {"error": "같은 시식 기록이 두 번 들어 있어요."}
		seen[menu["record_id"]] = true
		menus.append(menu)
	if menus.size() == 1:
		return _single(menus[0], day, staff)
	return _pair(menus, day, staff)


## 입력 한 건을 검증하고 실제 평가로 점수/원가/준비 시간을 구한다. 입력 객체는 복사만 한다.
static func _prepare(raw: Variant, staff: Dictionary) -> Dictionary:
	if typeof(raw) != TYPE_DICTIONARY:
		return {"error": "시식 기록 구조가 올바르지 않아요."}
	var d: Dictionary = raw
	for key in ["record_id", "name", "version", "config"]:
		if not d.has(key):
			return {"error": "시식 기록: 항목 누락 (%s)" % key}
	if typeof(d["record_id"]) != TYPE_INT or int(d["record_id"]) < 1:
		return {"error": "시식 기록 번호는 1 이상의 정수여야 해요."}
	if typeof(d["name"]) != TYPE_STRING:
		return {"error": "레시피 이름 형식이 올바르지 않아요."}
	var name_err: String = Check.name_error(str(d["name"]), false)
	if name_err != "":
		return {"error": name_err}
	if typeof(d["version"]) != TYPE_INT or not Check.in_range(d["version"], 1, MAX_VERSION):
		return {"error": "레시피 버전은 1~%d 정수여야 해요." % MAX_VERSION}
	if typeof(d["config"]) != TYPE_DICTIONARY:
		return {"error": "레시피 구성 구조가 올바르지 않아요."}
	var raw_config: Dictionary = d["config"]
	var config_err: String = Check.config_error(raw_config)
	if config_err != "":
		return {"error": config_err}
	var config: Dictionary = Catalog.normalize_config(raw_config)
	var ev: Dictionary = Evaluator.evaluate(config)
	if str(ev["error"]) != "":
		return {"error": str(ev["error"])}
	var scores: Dictionary = {}
	for c in (ev["customers"] as Array):
		scores[str((c as Dictionary)["id"])] = int((c as Dictionary)["score"])
	return {
		"error": "",
		"record_id": int(d["record_id"]),
		"recipe_name": str(d["name"]),
		"version": int(d["version"]),
		"config": config,
		"scores": scores,
		"prep": Staffing.effective_prep(Evaluator.prep_seconds(config), staff),
		"price": int(config["price"]),
		"unit_cost": Evaluator.unit_cost(config),
	}


static func _group_ids() -> Array[String]:
	var out: Array[String] = Customers.ids()
	out.append(Sim.WALKIN_ID)
	return out


## 한 메뉴의 손님 그룹별 개별 수요(기존 Sim._demand 공식 그대로). walkin 점수는 해당 메뉴 단골 평균이다.
static func _group_demands(menu: Dictionary, mult: float) -> Dictionary:
	var scores: Dictionary = menu["scores"]
	var price: int = int(menu["price"])
	var prep: int = int(menu["prep"])
	var out: Dictionary = {}
	var score_sum: int = 0
	for c in Customers.all():
		var customer: Dictionary = c
		var id: String = str(customer["id"])
		score_sum += int(scores[id])
		out[id] = Sim._demand(int(customer["base_visits"]), mult, int(scores[id]), price,
			int(customer["fair_price"]), int(customer["max_price"]), float(customer["price_sens"]),
			prep, int(customer["patience_seconds"]))
	var avg_score: int = roundi(float(score_sum) / float(Customers.ids().size()))
	out[Sim.WALKIN_ID] = Sim._demand(Sim.WALKIN_BASE, mult, avg_score, price, Sim.WALKIN_FAIR, Sim.WALKIN_MAX,
		Sim.WALKIN_SENS, prep, Sim.WALKIN_PATIENCE)
	return out


static func _row(menu: Dictionary, demand: int, units: int, by_source: Dictionary) -> Dictionary:
	var revenue: int = units * int(menu["price"])
	var cost: int = units * int(menu["unit_cost"])
	return {
		"record_id": int(menu["record_id"]),
		"recipe_name": str(menu["recipe_name"]),
		"version": int(menu["version"]),
		"config": (menu["config"] as Dictionary).duplicate(true),
		"scores": (menu["scores"] as Dictionary).duplicate(true),
		"prep": int(menu["prep"]),
		"price": int(menu["price"]),
		"unit_cost": int(menu["unit_cost"]),
		"demand": demand,
		"units": units,
		"revenue": revenue,
		"ingredient_cost": cost,
		"margin": revenue - cost,
		"by_source": by_source.duplicate(true),
	}


## 메뉴 하나는 기존 단일 시뮬레이터에 그대로 맡기고 menus 한 행만 더한다.
static func _single(menu: Dictionary, day: int, staff: Dictionary) -> Dictionary:
	var res: Dictionary = Sim.simulate((menu["config"] as Dictionary).duplicate(true), (menu["scores"] as Dictionary).duplicate(true), day, staff)
	if str(res["error"]) != "":
		return {"error": str(res["error"])}
	res["menus"] = [_row(menu, int(res["demand"]), int(res["units"]), res["by_source"])]
	return res


static func _pair(menus: Array, day: int, staff: Dictionary) -> Dictionary:
	# 모든 계산은 record_id 오름차순(a < b)으로 하고 마지막에 입력 순서로 행을 돌려준다 → 입력 순서와 무관한 결과.
	var sorted: Array = menus.duplicate()
	sorted.sort_custom(func(x: Dictionary, y: Dictionary) -> bool: return int(x["record_id"]) < int(y["record_id"]))
	var groups: Array[String] = _group_ids()
	var mult: float = Sim.day_multiplier(day)
	var own: Array = [_group_demands(sorted[0], mult), _group_demands(sorted[1], mult)]

	# 그룹 방문 수 = max(두 수요). 비율 배분: 내림 + 남은 한 명은 나머지가 큰 쪽(동률이면 작은 id = a).
	var remain: Array = [{}, {}]
	var menu_demand: Array = [0, 0]
	var total_demand: int = 0
	for g in groups:
		var da: int = int(own[0][g])
		var db: int = int(own[1][g])
		var visits: int = maxi(da, db)
		var sum: int = da + db
		var a: int = 0
		var b: int = 0
		if sum > 0:
			a = visits * da / sum
			b = visits * db / sum
			if a + b < visits:
				if (visits * da) % sum >= (visits * db) % sum:
					a += 1
				else:
					b += 1
		remain[0][g] = a
		remain[1][g] = b
		menu_demand[0] += a
		menu_demand[1] += b
		total_demand += visits
	if total_demand > MAX_UNITS:
		return {"error": "하루 수요가 %d그릇을 넘어요." % MAX_UNITS}

	# 공유 주방: 라운드마다 (메뉴, 그룹) 칸에 한 그릇씩. 시간이 모자란 칸은 건너뛰고(더 빠른 메뉴는 계속 가능) 한 바퀴 동안 아무도 못 만들면 끝.
	var made: Array = [{}, {}]
	for i in 2:
		for g in groups:
			made[i][g] = 0
	var budget: int = Sim.SERVICE_SECONDS
	var progressed: bool = true
	while progressed:
		progressed = false
		for i in 2:
			var prep: int = int(sorted[i]["prep"])
			for g in groups:
				if int(remain[i][g]) > int(made[i][g]) and prep <= budget:
					made[i][g] = int(made[i][g]) + 1
					budget -= prep
					progressed = true

	var by_id: Dictionary = {}
	var by_source: Dictionary = {}
	for g in groups:
		by_source[g] = 0
	var units: int = 0
	var revenue: int = 0
	var cost: int = 0
	var margin_sum: int = 0
	for i in 2:
		var u: int = 0
		for g in groups:
			u += int(made[i][g])
			by_source[g] = int(by_source[g]) + int(made[i][g])
		var row: Dictionary = _row(sorted[i], int(menu_demand[i]), u, made[i])
		by_id[int(row["record_id"])] = row
		units += u
		revenue += int(row["revenue"])
		cost += int(row["ingredient_cost"])
		margin_sum += int(row["margin"])
	if units > MAX_UNITS:
		return {"error": "하루 판매가 %d그릇을 넘어요." % MAX_UNITS}
	var rows: Array = []
	for m in menus:
		rows.append(by_id[int(m["record_id"])])
	var overhead: int = Sim.overhead_for(staff)
	return {
		"error": "",
		"units": units,
		"revenue": revenue,
		"ingredient_cost": cost,
		"overhead": overhead,
		"net": margin_sum - overhead,
		"demand": total_demand,
		"capacity": Sim.SERVICE_SECONDS / mini(int(sorted[0]["prep"]), int(sorted[1]["prep"])),
		"by_source": by_source,
		"menus": rows,
	}
