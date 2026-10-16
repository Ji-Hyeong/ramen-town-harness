extends SceneTree
## 두 메뉴 하루 영업 계산(menu_sales.gd) 순수 시험. 파일/저장/세션/UI 없음.
## 기대값은 이 파일 안의 독립 기준 구현(ref_*)과 손계산 수식으로 구하고, 평가기 점수 구조만 실제 Evaluator를 쓴다.

const MS = preload("res://scripts/domain/menu_sales.gd")
const Sim = preload("res://scripts/domain/sales_simulator.gd")
const Customers = preload("res://scripts/domain/customer_catalog.gd")
const Evaluator = preload("res://scripts/domain/recipe_evaluator.gd")
const Staffing = preload("res://scripts/domain/shop_staffing.gd")

const MULT: Array = [1.0, 0.9, 1.0, 1.1, 1.2, 1.3, 0.8]
const GROUPS: Array = ["dohyun", "hayoung", "maru", "walkin"]

var checks: int = 0
var failures: int = 0


func ok(cond: bool, label: String) -> void:
	checks += 1
	if not cond:
		failures += 1
		print("FAIL: ", label)


func cfg(broth: String, tare: String, oil: String, noodle: String, tops: Array, cook: String, price: int) -> Dictionary:
	return {"broth": broth, "tare": tare, "oil": oil, "noodle": noodle, "toppings": tops, "cook": cook, "price": price}


func rec(id: int, config: Dictionary, name: String = "메뉴") -> Dictionary:
	return {"record_id": id, "name": name, "version": 1, "config": config.duplicate(true), "scores": {"dohyun": 100, "hayoung": 100, "maru": 100}}


func with_price(c: Dictionary, price: int) -> Dictionary:
	var d: Dictionary = c.duplicate(true)
	d["price"] = price
	return d


# ---- 독립 기준 구현 ----
func ref_scores(c: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for x in Evaluator.evaluate(c)["customers"]:
		out[x["id"]] = x["score"]
	return out


func ref_prep(c: Dictionary, staff: Dictionary) -> int:
	var pct: int = 100 if staff.is_empty() else int(staff["prep_percent"])
	return maxi(1, (Evaluator.prep_seconds(c) * pct + 99) / 100)


func ref_d(base: int, mult: float, score: int, price: int, fair: int, mx: int, sens: float, prep: int, pat: int) -> int:
	var taste: float = clampf(float(score - 30) / 70.0, 0.0, 1.0)
	var pf: float = 0.0
	if price <= mx:
		var ratio: float = float(price) / float(fair)
		pf = minf(1.25, 1.0 + (1.0 - ratio) * 0.5) if ratio <= 1.0 else maxf(0.0, 1.0 - (ratio - 1.0) * sens)
	var pa: float = 1.0 if prep <= pat else 1.0 - clampf(float(prep - pat) / 200.0, 0.0, 0.6)
	return maxi(0, roundi(float(base) * mult * taste * pf * pa))


func ref_demands(c: Dictionary, day: int, staff: Dictionary) -> Dictionary:
	var sc: Dictionary = ref_scores(c)
	var prep: int = ref_prep(c, staff)
	var out: Dictionary = {}
	var sum: int = 0
	for x in Customers.all():
		sum += int(sc[x["id"]])
		out[x["id"]] = ref_d(x["base_visits"], MULT[day % 7], sc[x["id"]], c["price"], x["fair_price"], x["max_price"], x["price_sens"], prep, x["patience_seconds"])
	out["walkin"] = ref_d(5, MULT[day % 7], roundi(sum / 3.0), c["price"], 9000, 14000, 1.3, prep, 150)
	return out


## recs: 정확히 2개. 반환 {demand, units, by_source, per(id → {demand, units, prep})}.
func ref_pair(recs: Array, day: int, staff: Dictionary) -> Dictionary:
	var rs: Array = recs.duplicate()
	rs.sort_custom(func(a, b): return a["record_id"] < b["record_id"])
	var dem: Array = [ref_demands(rs[0]["config"], day, staff), ref_demands(rs[1]["config"], day, staff)]
	var per: Dictionary = {}
	var cells: Array = []
	var total: int = 0
	for i in 2:
		per[rs[i]["record_id"]] = {"demand": 0, "units": 0, "prep": ref_prep(rs[i]["config"], staff)}
	for g in GROUPS:
		var da: int = dem[0][g]
		var db: int = dem[1][g]
		var v: int = maxi(da, db)
		total += v
		var share: Array = [0, 0]
		if da + db > 0:
			share = [(v * da) / (da + db), (v * db) / (da + db)]
			if share[0] + share[1] < v:
				share[0 if (v * da) % (da + db) >= (v * db) % (da + db) else 1] += 1
		for i in 2:
			per[rs[i]["record_id"]]["demand"] += share[i]
			cells.append({"id": rs[i]["record_id"], "g": g, "left": share[i]})
	var budget: int = 2400
	var by_source: Dictionary = {"dohyun": 0, "hayoung": 0, "maru": 0, "walkin": 0}
	var moved: bool = true
	while moved:
		moved = false
		for cell in cells:
			var p: int = per[cell["id"]]["prep"]
			if cell["left"] > 0 and p <= budget:
				cell["left"] -= 1
				budget -= p
				per[cell["id"]]["units"] += 1
				by_source[cell["g"]] += 1
				moved = true
	return {"demand": total, "units": per[rs[0]["record_id"]]["units"] + per[rs[1]["record_id"]]["units"], "by_source": by_source, "per": per}


func row_of(res: Dictionary, id: int) -> Dictionary:
	for r in res["menus"]:
		if r["record_id"] == id:
			return r
	return {}


func staffs() -> Array:
	var tr: Dictionary = {
		"prep_assistant": {"lessons": [{"style": "basic"}, {"style": "speed"}]},
		"floor_assistant": {"lessons": [{"style": "basic"}]},
	}
	return [{}, Staffing.snapshot(["prep_assistant"]), Staffing.snapshot(["floor_assistant"]),
		Staffing.snapshot(["prep_assistant", "floor_assistant"]), Staffing.snapshot(["prep_assistant", "floor_assistant"], tr)]


func fails(records: Array, day: int, staff: Dictionary, label: String) -> void:
	var before: String = str([records, day, staff])
	var res: Dictionary = MS.simulate(records, day, staff)
	ok(res.has("error") and typeof(res["error"]) == TYPE_STRING and res["error"] != "", label + " → 오류")
	ok(str([records, day, staff]) == before, label + " → 입력 불변")


func _init() -> void:
	var rich: Dictionary = cfg("broth_tonkotsu", "tare_miso", "oil_chili", "noodle_thick", ["topping_chashu", "topping_egg"], "cook_normal", 9500)
	var light: Dictionary = cfg("broth_chicken", "tare_shio", "oil_scallion", "noodle_thin", ["topping_sprouts"], "cook_firm", 8000)
	var spicy: Dictionary = cfg("broth_dashi", "tare_shoyu", "oil_chili", "noodle_medium", ["topping_egg", "topping_nori"], "cook_firm", 7500)
	var multi: Dictionary = cfg("broth_tonkotsu", "tare_shoyu", "oil_garlic", "noodle_medium", ["topping_chashu", "topping_egg", "topping_nori"], "cook_normal", 9000)
	var staff_list: Array = staffs()
	for s in staff_list:
		ok(Staffing.snapshot_error(s) == "", "시험용 직원 스냅샷이 유효")

	# 실제 평가기 구조: 손님 3명 id/score(0~100 정수)
	var ev: Dictionary = Evaluator.evaluate(rich)
	ok(ev["error"] == "" and ev["customers"].size() == 3 and ref_scores(rich).size() == 3, "평가기 손님 점수 구조")

	# 1. 메뉴 1개 = 기존 Sim 과 전 필드 동일(점수는 입력 100점을 무시하고 실제 평가 사용)
	for c in [rich, with_price(light, 12000)]:
		for day in [1, 5, 6, 99999]:
			for s in staff_list:
				var one: Dictionary = MS.simulate([rec(7, c)], day, s)
				var sim: Dictionary = Sim.simulate(c, ref_scores(c), day, s)
				var same: bool = one["error"] == ""
				for k in sim.keys():
					same = same and str(one.get(k)) == str(sim[k])
				ok(same and one["menus"].size() == 1, "1메뉴가 Sim과 동일 day=%d price=%d" % [day, c["price"]])
				var r: Dictionary = one["menus"][0]
				ok(r["record_id"] == 7 and r["units"] == sim["units"] and r["demand"] == sim["demand"] and r["margin"] == sim["revenue"] - sim["ingredient_cost"]
					and r["price"] == c["price"] and typeof(r["price"]) == TYPE_INT and r["prep"] == ref_prep(c, s) and str(r["scores"]) == str(ref_scores(c)), "1메뉴 행")

	# 2~5. 메뉴 2개: 기준 구현과 일치, 공유 손님, 주방 시간, 금액
	var bound_seen: bool = false
	var shared_seen: bool = false
	for pair in [[rich, multi], [light, spicy], [rich, light], [spicy, multi]]:
		for day in [1, 5, 6, 12]:
			for s in staff_list:
				var recs: Array = [rec(9, pair[0], "가"), rec(4, pair[1], "나")]
				var res: Dictionary = MS.simulate(recs, day, s)
				var ref: Dictionary = ref_pair(recs, day, s)
				var tag: String = "day=%d 직원%d" % [day, staff_list.find(s)]
				ok(res["error"] == "" and res["menus"].size() == 2 and res["menus"][0]["record_id"] == 9 and res["menus"][1]["record_id"] == 4, "행 순서=입력 순서 " + tag)
				ok(res["demand"] == ref["demand"] and res["units"] == ref["units"] and str(res["by_source"]) == str(ref["by_source"]), "총계가 기준과 같음 " + tag)
				var time_used: int = 0
				var rev: int = 0
				var cost: int = 0
				var margin: int = 0
				for id in [9, 4]:
					var r: Dictionary = row_of(res, id)
					ok(r["demand"] == ref["per"][id]["demand"] and r["units"] == ref["per"][id]["units"], "메뉴별 수요/판매 %d %s" % [id, tag])
					time_used += r["units"] * r["prep"]
					rev += r["units"] * r["price"]
					cost += r["units"] * r["unit_cost"]
					margin += r["margin"]
					ok(r["margin"] == r["revenue"] - r["ingredient_cost"] and r["revenue"] == r["units"] * r["price"], "행 금액")
				ok(time_used <= 2400, "주방 총 조리시간 ≤ 2400 " + tag)
				ok(res["revenue"] == rev and res["ingredient_cost"] == cost and res["overhead"] == 3000 + (0 if s.is_empty() else s["wage"]), "요금/원가/운영비 1회 " + tag)
				ok(res["net"] == margin - res["overhead"] and res["net"] == rev - cost - res["overhead"], "net=마진합-운영비 " + tag)
				var min_prep: int = mini(ref_prep(pair[0], s), ref_prep(pair[1], s))
				ok(res["capacity"] == 2400 / min_prep and res["units"] <= res["capacity"], "capacity=2400/최소 준비 " + tag)
				# 그룹 방문은 max 한 번: 독립 수요 합이 아니다
				var da: Dictionary = ref_demands(pair[0], day, s)
				var db: Dictionary = ref_demands(pair[1], day, s)
				var mx: int = 0
				var indep: int = 0
				for g in GROUPS:
					mx += maxi(da[g], db[g])
					indep += da[g] + db[g]
					ok(res["by_source"][g] <= maxi(da[g], db[g]), "그룹 %s 판매 ≤ max 수요 %s" % [g, tag])
				ok(res["demand"] == mx and mx <= indep, "demand=그룹별 max 합 " + tag)
				shared_seen = shared_seen or mx < indep
				bound_seen = bound_seen or (res["units"] < res["demand"] and res["demand"] > 0)
				var by_sum: int = 0
				for v in res["by_source"].values():
					by_sum += v
				ok(by_sum == res["units"], "by_source 합=units " + tag)
				# 순서 뒤바꿈: 행은 입력 순서, 값은 id별로 같음
				var rev_res: Dictionary = MS.simulate([recs[1], recs[0]], day, s)
				ok(rev_res["menus"][0]["record_id"] == 4 and str(row_of(rev_res, 9)) == str(row_of(res, 9)) and str(row_of(rev_res, 4)) == str(row_of(res, 4))
					and rev_res["net"] == res["net"] and str(rev_res["by_source"]) == str(res["by_source"]), "입력 순서 독립 " + tag)
				ok(str(MS.simulate(recs, day, s)) == str(res), "동일 입력 결정성 " + tag)
	ok(shared_seen, "손님을 공유해 독립 합보다 작은 사례가 있음")
	# 실제 도달 가능한 병목 증인: 10*78 + 9*186 = 2454초라 19그릇 전체는 만들 수 없다.
	var slow: Dictionary = cfg("broth_tonkotsu", "tare_shoyu", "oil_chili", "noodle_thick", ["topping_chashu", "topping_egg", "topping_nori"], "cook_normal", 5000)
	var quick: Dictionary = cfg("broth_dashi", "tare_shio", "oil_scallion", "noodle_thin", ["topping_nori"], "cook_firm", 5000)
	var bottleneck: Dictionary = MS.simulate([rec(1, quick), rec(2, slow)], 5)
	ok(bottleneck["demand"] == 19 and bottleneck["units"] == 18 and row_of(bottleneck, 1)["units"] == 10 and row_of(bottleneck, 2)["units"] == 8, "공유 주방의 독립 손계산 병목 증인")
	bound_seen = bound_seen or (bottleneck["units"] < bottleneck["demand"])
	ok(bound_seen, "주방 시간이 판매를 제한하는 사례가 있음")

	# 6. 고가 메뉴 수요 0 / 모든 메뉴 수요 0
	var pricey: Dictionary = with_price(rich, 30000)
	var res6: Dictionary = MS.simulate([rec(1, pricey), rec(2, light)], 3, {})
	ok(row_of(res6, 1)["demand"] == 0 and row_of(res6, 1)["units"] == 0 and row_of(res6, 2)["units"] == res6["units"] and res6["units"] > 0, "고가 메뉴 수요 0")
	var res0: Dictionary = MS.simulate([rec(1, pricey), rec(2, with_price(light, 30000))], 3, staff_list[3])
	ok(res0["error"] == "" and res0["units"] == 0 and res0["demand"] == 0 and res0["revenue"] == 0 and res0["net"] == -res0["overhead"], "모든 메뉴 수요 0")
	ok(res0["menus"][0]["margin"] == 0 and res0["capacity"] > 0, "수요 0 행/용량")

	# 7. 같은 손님 그룹이 취향/가격에 따라 다른 메뉴를 고르는 증인(기준 구현으로 후보 조합 탐색 후 실제 helper로 확인)
	var cands: Array = [rich, light, spicy, multi, with_price(spicy, 6000), with_price(rich, 12500)]
	var found: bool = false
	for i in cands.size():
		for j in range(i + 1, cands.size()):
			var ri: Array = [rec(1, cands[i]), rec(2, cands[j])]
			var d1: Dictionary = ref_demands(cands[i], 1, {})
			var d2: Dictionary = ref_demands(cands[j], 1, {})
			var g_a: String = ""
			var g_b: String = ""
			for g in GROUPS:
				if d1[g] > d2[g]:
					g_a = g
				elif d2[g] > d1[g]:
					g_b = g
			if not found and g_a != "" and g_b != "":
				var rr: Dictionary = MS.simulate(ri, 1, {})
				var sa: int = row_of(rr, 1)["by_source"][g_a]
				var sb: int = row_of(rr, 2)["by_source"][g_a]
				var ta: int = row_of(rr, 1)["by_source"][g_b]
				var tb: int = row_of(rr, 2)["by_source"][g_b]
				found = rr["error"] == "" and row_of(rr, 1)["demand"] > 0 and row_of(rr, 2)["demand"] > 0 and (sa + sb) > 0 and (ta + tb) > 0 and sa > sb and tb > ta
	ok(found, "한 그룹은 A, 다른 그룹은 B를 더 많이 고르는 증인")

	# 8. 다중 토핑 + 육성 스냅샷
	var tr_staff: Dictionary = staff_list[4]
	ok(tr_staff.has("training") and tr_staff["prep_percent"] < 80, "육성 스냅샷이 조리 시간을 더 줄임")
	var mt: Dictionary = MS.simulate([rec(3, multi), rec(5, rich)], 5, tr_staff)
	ok(mt["error"] == "" and row_of(mt, 3)["prep"] == ref_prep(multi, tr_staff) and row_of(mt, 3)["config"]["toppings"].size() == 3, "다중 토핑 + 육성 준비 시간")
	ok(mt["overhead"] == 3000 + tr_staff["wage"], "육성 일당 반영")
	# 옛 모양(topping 하나)도 정규 구성으로 받아 같은 결과
	var legacy: Dictionary = {"broth": "broth_chicken", "tare": "tare_shio", "oil": "oil_scallion", "noodle": "noodle_thin", "topping": "topping_sprouts", "cook": "cook_firm", "price": 8000}
	ok(str(MS.simulate([rec(1, legacy)], 2, {})["menus"][0]["config"]) == str(light), "옛 구성 정규화")

	# 9. 오류: 입력 불변 + 비어 있지 않은 error
	var good: Array = [rec(1, light)]
	fails([], 1, {}, "0개")
	fails([rec(1, light), rec(2, rich), rec(3, spicy)], 1, {}, "3개")
	fails([rec(1, light), rec(1, rich)], 1, {}, "id 중복")
	fails(good, 0, {}, "day 0")
	fails(good, 100000, {}, "day 초과")
	fails(good, 1, {"hired": []}, "직원 스냅샷 오류")
	fails([5], 1, {}, "레코드 타입")
	var mutants: Array = []
	for pair in [["record_id", 0], ["record_id", -3], ["record_id", "1"], ["record_id", 1.0], ["name", ""], ["name", "가".repeat(21)],
			["name", "a\nb"], ["name", 5], ["version", 0], ["version", 10000], ["version", "1"], ["config", 3], ["config", {}]]:
		var m: Dictionary = rec(1, light)
		m[pair[0]] = pair[1]
		mutants.append([m, str(pair)])
	var m2: Dictionary = rec(1, light)
	m2.erase("version")
	mutants.append([m2, "version 누락"])
	var float_price: Dictionary = light.duplicate(true)
	float_price["price"] = 9000.0  # 정수가 아닌 가격 형식(typed 인자의 암묵 변환을 피해 직접 대입)
	for bad in [with_price(light, 9050), with_price(light, 500), with_price(light, 31000), float_price]:
		mutants.append([rec(1, bad), "가격 %s" % str(bad["price"])])
	var unk: Dictionary = light.duplicate(true)
	unk["broth"] = "broth_nope"
	mutants.append([rec(1, unk), "알 수 없는 재료"])
	var top4: Dictionary = light.duplicate(true)
	top4["toppings"] = ["topping_chashu", "topping_egg", "topping_sprouts", "topping_nori"]
	mutants.append([rec(1, top4), "토핑 4개"])
	var dup_top: Dictionary = light.duplicate(true)
	dup_top["toppings"] = ["topping_egg", "topping_egg"]
	mutants.append([rec(1, dup_top), "토핑 중복"])
	for mu in mutants:
		fails([mu[0]], 1, {}, str(mu[1]))
		fails([rec(2, rich), mu[0]], 1, {}, str(mu[1]) + " (2메뉴)")

	# 10. 사본 안전: 입력 불변, 결과를 바꿔도 다음 호출에 영향 없음
	var recs10: Array = [rec(2, rich), rec(1, multi)]
	var snap: String = str(recs10)
	var r1: Dictionary = MS.simulate(recs10, 4, staff_list[1])
	ok(str(recs10) == snap, "호출 후 입력 불변")
	var ref_txt: String = str(r1)
	r1["menus"][0]["config"]["toppings"].append("x")
	r1["menus"][0]["scores"]["dohyun"] = -1
	r1["menus"][1]["by_source"]["maru"] = 999
	r1["by_source"]["maru"] = 999
	ok(str(MS.simulate(recs10, 4, staff_list[1])) == ref_txt and str(recs10) == snap, "결과 변경이 입력/다음 결과에 영향 없음")
	var one10: Dictionary = MS.simulate([rec(1, rich)], 4, {})
	one10["menus"][0]["by_source"]["maru"] = 999
	ok(one10["by_source"]["maru"] != 999, "1메뉴 by_source 행 사본")

	print("menu_sales_core_tests checks=%d failures=%d" % [checks, failures])
	quit(0 if failures == 0 else 1)
