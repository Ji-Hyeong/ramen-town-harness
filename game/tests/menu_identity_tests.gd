extends RefCounted
## MenuIdentity(순수 투영)와 MenuIdentityCard(카드)의 시험. 사용: run(callback) — callback(통과: bool, 메시지: String).
## 기록과 영수증은 실제 공개 GameState 흐름(원재료 육수/면 개발 -> 유료 시식 -> 실제 영업)에서 만든다.
## 구성만 바꾸는 변형(이름/가격/토핑 순서/겹친 분량/공법/발견·채집 재료)은 실제 기록 복사본에 구성을 고치고
## 점수를 평가기로 다시 구해 만든다. 발견 상태가 필요한 채집 재료는 GameState 로 얻지 않고 카탈로그의 알려진 id 로만 확인한다.
## 이 모듈은 어떤 저장도 하지 않는다.

const State = preload("res://scripts/domain/game_state.gd")
const Identity = preload("res://scripts/ui/menu_identity.gd")
const Card = preload("res://scripts/ui/menu_identity_card.gd")
const Evaluator = preload("res://scripts/domain/recipe_evaluator.gd")
const Catalog = preload("res://scripts/domain/ingredient_catalog.gd")
const Customers = preload("res://scripts/domain/customer_catalog.gd")
const MenuSales = preload("res://scripts/domain/menu_sales.gd")
const Mock = preload("res://scripts/ui/mock_fidelity_art.gd")
const BowlArt = preload("res://scripts/ui/bowl_editor_art.gd")
const HarborTests =preload("res://tests/harbor_foraging_tests.gd")

var check: Callable
var _tree: SceneTree


func run(callback: Callable) -> void:
	check = callback
	_tree = Engine.get_main_loop() as SceneTree
	var light: Dictionary = _bowl(["kelp", "onion"], "gentle", "tare_shio", "oil_scallion", "cook_normal", ["topping_nori"],
		{"flour": "wheat", "water": "clear", "cut": "thin", "method": "standard"})
	var rich: Dictionary = _bowl(["pork_bone", "chicken_bone"], "standard", "tare_miso", "oil_garlic", "cook_firm", ["topping_chashu"],
		{"flour": "strong", "water": "alkaline", "cut": "thick", "method": "standard"})
	if light.is_empty() or rich.is_empty():
		return
	_headlines(light, rich)
	_invariance(rich["record"])
	_differences(rich["record"], light["record"])
	_real_farmed()
	_rejections(light["record"])
	_ties_and_copies(light["record"])
	_sales(light, rich)
	_card(light["record"], rich["record"])


# ---------- 도우미 ----------

## 실제 GameState 로 원재료 육수 -> 원재료 면 -> 그릇 -> 유료 시식을 거친 기록. 단계가 실패하면 {} 를 돌려준다.
func _bowl(broth: Array, method: String, tare: String, oil: String, cook: String, toppings: Array, formula: Dictionary) -> Dictionary:
	var st := State.new()
	var steps: Array = [
		st.set_broth_blend(broth, method), st.begin_broth(), st.advance_broth(20.0),
	]
	for step in steps:
		if not bool(step["ok"]):
			check.call(false, "real broth step: " + str(step.get("message", "")))
			return {}
	var used: Dictionary = st.use_broth(st.broth_review()["recipes"].size() - 1)
	for key in formula:
		st.set_noodle_formula(key, formula[key])
	var kneaded: Array = [st.begin_noodle(), st.advance_noodle(20.0), st.use_noodle(0),
		st.set_draft_choice("tare", tare), st.set_draft_choice("oil", oil), st.set_draft_choice("cook", cook),
		st.set_draft_toppings(toppings)]
	for step in kneaded:
		if not bool(step["ok"]):
			check.call(false, "real bowl step: " + str(step.get("message", "")))
			return {}
	var taste: Dictionary = st.taste()
	check.call(bool(used["ok"]) and bool(taste["ok"]), "real paid tasting succeeded")
	if not bool(taste["ok"]):
		return {}
	return {"state": st, "record": st.get_record(st.selected_record_id)}


func _scores_for(config: Dictionary) -> Dictionary:
	var scores: Dictionary = {}
	for c in Evaluator.evaluate(config)["customers"]:
		scores[str(c["id"])] = int(c["score"])
	return scores


## 실제 기록의 복사본에서 구성만 고치고 점수를 평가기로 다시 구한다.
func _variant(record: Dictionary, edit: Callable) -> Dictionary:
	var out: Dictionary = record.duplicate(true)
	edit.call(out["config"])
	out["scores"] = _scores_for(out["config"])
	return out


func _premade(broth: String, tare: String, oil: String, noodle: String, cook: String, toppings: Array, process: Dictionary = {}) -> Dictionary:
	var config: Dictionary = {"broth": broth, "tare": tare, "oil": oil, "noodle": noodle, "toppings": toppings, "cook": cook, "price": 9000}
	if not process.is_empty():
		config["process"] = process
	return {"record_id": 7, "lineage_id": 1, "name": "시험 그릇", "version": 1, "tasted_day": 1,
		"config": config, "scores": _scores_for(config), "comparison": {}}


func _find(node: Node, node_name: String) -> Node:
	return node.find_child(node_name, true, false)


func _texts(node: Node) -> Array[String]:
	var out: Array[String] = []
	for child in node.get_children():
		if child is Label and (child as Label).visible:
			out.append((child as Label).text)
		out.append_array(_texts(child))
	return out


func _joined(node: Node) -> String:
	return "".join(PackedStringArray(_texts(node)))


func _best_score(record: Dictionary) -> int:
	var best: int = -1
	for id in record["scores"]:
		best = maxi(best, int(record["scores"][id]))
	return best


# ---------- 제목/특징/재료 ----------

func _headlines(light: Dictionary, rich: Dictionary) -> void:
	var rec_l: Dictionary = light["record"]
	var rec_r: Dictionary = rich["record"]
	var before: String = JSON.stringify([rec_l, rec_r])
	var l: Dictionary = Identity.describe(rec_l)
	var r: Dictionary = Identity.describe(rec_r)
	check.call(JSON.stringify([rec_l, rec_r]) == before, "describe never mutates the saved record")
	check.call(l["error"] == "" and l["kind"] == "tasting" and l["available"] and r["available"], "real records describe")
	check.call(l["headline"] == Identity.HEAD_LIGHT, "light raw-broth bowl is the light/aromatic heading")
	check.call(r["headline"] == Identity.HEAD_RICH, "rich raw-broth bowl is the rich heading")
	check.call(l["headline"] != r["headline"], "different dishes get different headings")
	check.call(l["features"].size() <= 2 and r["features"].size() <= 2, "at most two features")
	check.call(l["features"].has("향 높음") and r["features"].has("진함 높음"), "features come from the actual taste profile")
	check.call(l["materials"].size() <= 3 and l["materials"].size() >= 2 and r["materials"].size() <= 3, "at most three materials")
	check.call(l["recipe_name"] == rec_l["name"] and l["record_id"] == rec_l["record_id"] and l["version"] == rec_l["version"], "authored name, id and version are carried untouched")
	check.call(l["unit_cost"] == Evaluator.unit_cost(rec_l["config"]) and l["prep_seconds"] == Evaluator.prep_seconds(rec_l["config"]), "cost and prep come from the evaluator")
	for id in l["materials"] + r["materials"]:
		check.call(not Catalog.find(id).is_empty(), "material is a real catalog id: " + id)
	# 가장 높은 시식 점수의 손님만, 평가기의 같은 값으로.
	for pair in [[rec_l, l], [rec_r, r]]:
		var top: int = _best_score(pair[0])
		var ok: bool = not pair[1]["customers"].is_empty()
		for c in pair[1]["customers"]:
			ok = ok and int(c["score"]) == top and int(pair[0]["scores"][c["id"]]) == top and not c.has("units")
		check.call(ok, "customers are exactly the best tasted preference")
	# 구성별 기준 구간(손으로 계산한 카탈로그 값).
	var cases: Array = [
		[_premade("broth_dashi", "tare_shio", "oil_scallion", "noodle_thin", "cook_normal", ["topping_nori"]), Identity.HEAD_LIGHT],
		[_premade("broth_tonkotsu", "tare_miso", "oil_garlic", "noodle_thick", "cook_firm", ["topping_chashu"]), Identity.HEAD_RICH],
		[_premade("broth_chicken", "tare_miso", "oil_chili", "noodle_medium", "cook_normal", ["topping_egg"]), Identity.HEAD_SPICY],
		[_premade("broth_chicken", "tare_shio", "oil_scallion", "noodle_thick", "cook_firm", ["topping_egg"]), Identity.HEAD_NOODLE],
		[_premade("broth_chicken", "tare_shio", "oil_scallion", "noodle_medium", "cook_normal", ["topping_egg"]), Identity.HEAD_PLAIN],
	]
	for c in cases:
		var d: Dictionary = Identity.describe(c[0])
		check.call(d["headline"] == c[1], "heading for " + str(c[1]))
	var plain: Dictionary = Identity.describe(cases[4][0])
	check.call(plain["available"] and plain["features"].is_empty(), "a plain bowl claims no feature")


func _invariance(rich_record: Dictionary) -> void:
	var base: Dictionary = Identity.describe(rich_record)
	var renamed: Dictionary = _variant(rich_record, func(c: Dictionary) -> void: c["price"] = 14000)
	renamed["name"] = "완전히 다른 이름"
	var d: Dictionary = Identity.describe(renamed)
	for key in ["headline", "features", "materials", "unit_cost", "prep_seconds", "customers"]:
		check.call(d[key] == base[key], "price/name change keeps " + key)
	check.call(d["recipe_name"] == "완전히 다른 이름" and d["config"]["price"] == 14000, "the authored name and price are carried as given")
	# 토핑을 고른 순서만 다르면 요리의 성격은 같다.
	var two_a: Dictionary = _variant(rich_record, func(c: Dictionary) -> void: c["toppings"] = ["topping_chashu", "topping_egg"])
	var two_b: Dictionary = _variant(rich_record, func(c: Dictionary) -> void: c["toppings"] = ["topping_egg", "topping_chashu"])
	check.call(Identity.describe(two_a) == Identity.describe(two_b), "topping order never changes the identity")


func _differences(rich_record: Dictionary, light_record: Dictionary) -> void:
	var base: Dictionary = Identity.describe(rich_record)
	var twice: Dictionary = Identity.describe(_variant(rich_record, func(c: Dictionary) -> void: c["toppings"] = ["topping_chashu", "topping_chashu"]))
	check.call(twice["available"] and twice["features"][0] == "차슈 ×2 듬뿍" and twice["materials"][2] == "topping_chashu", "a repeated portion is a visible feature")
	check.call(twice["unit_cost"] == base["unit_cost"] + 700 and twice["prep_seconds"] == base["prep_seconds"] + 15, "a repeated portion costs and takes time")
	# 원재료 면 배합이 다르면 다른 면 그림과 다른 성격.
	var thin: Dictionary = _bowl(["chicken_bone", "onion"], "standard", "tare_shio", "oil_scallion", "cook_normal", ["topping_egg"],
		{"flour": "wheat", "water": "clear", "cut": "thin", "method": "standard"})
	if not thin.is_empty():
		var t: Dictionary = Identity.describe(thin["record"])
		check.call(t["materials"][1] == "noodle_thin" and base["materials"][1] == "noodle_thick", "raw noodle formulas show different noodle art")
		check.call(t["config"] != base["config"] and t["unit_cost"] != base["unit_cost"], "raw formula changes the cost and config")
	# 공법이 다르면 특징이 달라진다(premade 구성 + 약불 우림).
	var plain: Dictionary = Identity.describe(_premade("broth_dashi", "tare_shio", "oil_scallion", "noodle_thin", "cook_normal", ["topping_nori"]))
	var gentle: Dictionary = Identity.describe(_premade("broth_dashi", "tare_shio", "oil_scallion", "noodle_thin", "cook_normal", ["topping_nori"], {"broth": "gentle", "noodle": "standard"}))
	check.call(gentle["available"] and gentle["features"].has("약불 우림") and plain["features"] != gentle["features"], "a method changes the features")
	check.call(gentle["unit_cost"] == plain["unit_cost"] + 180, "a method changes the cost")
	# 채집 재료(알려진 카탈로그 id)는 재료 그림으로 눈에 띈다.
	var farmed: Dictionary = Identity.describe(_variant(light_record, func(c: Dictionary) -> void:
		c["oil"] = "oil_roasted_sesame"
		c["toppings"] = ["topping_citrus_peel"]))
	check.call(farmed["available"] and farmed["materials"][2] == "topping_citrus_peel", "a farmed ingredient is the featured material")


# ---------- 실제 채집 재료 ----------

## 공개 항구 채집 거래(기존 시험의 ready 도구)로 얻은 정어리 연구 샘플 1개를 실제 원재료 육수/면으로 만들어 유료 시식한다.
## 발견/등급/재고를 직접 넣지 않는다. 시식이 샘플을 정확히 1개 쓰는지도 확인한다.
func _real_farmed() -> void:
	var harbor := HarborTests.new()
	harbor.check = check
	var st = harbor.ready()
	if not st.harbor_foraging_review()["can_start"]:
		check.call(false, "harbor fixture reached the sampling unlock")
		return
	var sardine: String = "broth_roasted_sardine"
	var stock_before: int = st.sample_stock(sardine)
	var used_before: int = int(st.harbor_foraging_state()["used"].get(sardine, 0))
	st.start_new_recipe()
	harbor.collect(st, "sardine_boat", "take_one")
	check.call(st.sample_stock(sardine) == stock_before + 1, "the sardine sample was really claimed")
	var steps: Array = [st.set_broth_blend(["sardine"], "standard"), st.begin_broth(), st.advance_broth(20.0)]
	for step in steps:
		if not bool(step["ok"]):
			check.call(false, "raw sardine broth: " + str(step.get("message", "")))
			return
	var used_broth: Dictionary = st.use_broth(st.broth_review()["recipes"].size() - 1)
	for pair in [["flour", "wheat"], ["water", "clear"], ["cut", "thin"], ["method", "standard"]]:
		st.set_noodle_formula(pair[0], pair[1])
	var more: Array = [used_broth, st.begin_noodle(), st.advance_noodle(20.0), st.use_noodle(st.noodle_review()["recipes"].size() - 1),
		st.set_draft_toppings(["topping_nori"]), st.set_draft_name("정어리 시험")]
	for step in more:
		if not bool(step["ok"]):
			check.call(false, "raw sardine bowl: " + str(step.get("message", "")))
			return
	var paid: Dictionary = st.taste()
	check.call(bool(paid["ok"]), "sardine paid tasting: " + str(paid.get("message", "")))
	if not bool(paid["ok"]):
		return
	check.call(st.sample_stock(sardine) == stock_before and int(st.harbor_foraging_state()["used"][sardine]) == used_before + 1, "tasting consumed exactly one sample")
	var record: Dictionary = st.get_record(st.selected_record_id)
	var d: Dictionary = Identity.describe(record)
	check.call(d["error"] == "" and d["available"] and d["materials"][0] == sardine and d["config"]["broth_recipe"]["ingredients"] == ["sardine"], "the farmed raw broth is the canonical identity")
	check.call(d["unit_cost"] == Evaluator.unit_cost(record["config"]) and d["features"].size() <= 2 and not d["customers"].is_empty(), "farmed record uses evaluator facts")
	# 현재 초안을 고쳐도 시식 기록의 정체성은 그대로다.
	st.set_draft_price(int(st.draft_config["price"]) + 100)
	check.call(Identity.describe(st.get_record(record["record_id"])) == d, "editing the draft never changes the tasted identity")


# ---------- 거절 ----------

func _rejections(record: Dictionary) -> void:
	var bad: Array = []
	bad.append({})
	bad.append(record["config"].duplicate(true))
	for key in ["record_id", "version", "name", "config", "scores"]:
		var missing: Dictionary = record.duplicate(true)
		missing.erase(key)
		bad.append(missing)
	for value in [0, -1, 1.5, "1", true, 2.0]:
		var r: Dictionary = record.duplicate(true)
		r["record_id"] = value
		bad.append(r)
	for value in [0, "1", 1.0]:
		var v: Dictionary = record.duplicate(true)
		v["version"] = value
		bad.append(v)
	for value in ["", "가".repeat(21), 5]:
		var n: Dictionary = record.duplicate(true)
		n["name"] = value
		bad.append(n)
	for value in [{}, [], {"broth": "nothing"}]:
		var c: Dictionary = record.duplicate(true)
		c["config"] = value
		bad.append(c)
	var pricey: Dictionary = record.duplicate(true)
	pricey["config"]["price"] = 950
	bad.append(pricey)
	var no_scores: Dictionary = record.duplicate(true)
	no_scores["scores"] = {}
	bad.append(no_scores)
	var wrong: Dictionary = record.duplicate(true)
	wrong["scores"]["dohyun"] = int(wrong["scores"]["dohyun"]) + 1
	bad.append(wrong)
	var typed: Dictionary = record.duplicate(true)
	typed["scores"]["dohyun"] = str(typed["scores"]["dohyun"])
	bad.append(typed)
	var extra: Dictionary = record.duplicate(true)
	extra["scores"]["stranger"] = 50
	bad.append(extra)
	var fractional: Dictionary = record.duplicate(true)
	fractional["scores"]["maru"] = float(fractional["scores"]["maru"]) + 0.5
	bad.append(fractional)
	for item in bad:
		var d: Dictionary = Identity.describe(item)
		check.call(str(d["error"]) != "" and d["available"] == false and d["headline"] == "" and d["customers"].is_empty() and d["config"].is_empty(), "malformed tasting rejected: " + JSON.stringify(item).left(60))
	# 점수가 맞는 정수형 소수는 JSON 에서 온 값으로 받아 준다.
	var floaty: Dictionary = record.duplicate(true)
	for id in floaty["scores"]:
		floaty["scores"][id] = float(floaty["scores"][id])
	check.call(Identity.describe(floaty)["error"] == "", "whole-number scores from JSON are accepted")


# ---------- 동점/복사본 ----------

func _ties_and_copies(record: Dictionary) -> void:
	# 모든 시작 조합에서 손님은 항상 같은 최고 점수만, 카탈로그 순서로 나온다.
	var order: Array[String] = Customers.ids()
	var bad: int = 0
	var ties: int = 0
	var seen: int = 0
	for broth in ["broth_tonkotsu", "broth_chicken", "broth_dashi"]:
		for tare in ["tare_shoyu", "tare_shio", "tare_miso"]:
			for oil in ["oil_garlic", "oil_chili", "oil_scallion"]:
				for noodle in ["noodle_thin", "noodle_medium", "noodle_thick"]:
					for cook in ["cook_firm", "cook_normal", "cook_soft"]:
						var record_in: Dictionary = _premade(broth, tare, oil, noodle, cook, ["topping_egg"])
						var d: Dictionary = Identity.describe(record_in)
						seen += 1
						var rows: Array = d["customers"]
						# 평가기가 직접 내놓은 점수에서 같은 최고점 손님 전부(카탈로그 순서)를 따로 구해 정확히 비교한다.
						var top: int = -1
						for id in order:
							top = maxi(top, int(record_in["scores"][id]))
						var expected_ids: Array[String] = []
						for id in order:
							if int(record_in["scores"][id]) == top:
								expected_ids.append(id)
						var got_ids: Array[String] = []
						for c in rows:
							got_ids.append(str(c["id"]))
						var ok: bool = got_ids == expected_ids and not rows.is_empty()
						for c in rows:
							ok = ok and int(c["score"]) == top
						if rows.size() > 1:
							ties += 1
						if not ok:
							bad += 1
	check.call(seen == 243 and bad == 0, "every combination lists all equal top scorers in catalog order")
	# 동점 처리: 사용하는 쪽이 같은 규칙을 다시 쓰므로 영수증 쪽 동점도 따로 확인한다(아래 _sales).
	var d1: Dictionary = Identity.describe(record)
	d1["config"]["price"] = 1
	d1["features"].append("x")
	d1["materials"].clear()
	d1["customers"].clear()
	var d2: Dictionary = Identity.describe(record)
	check.call(d2["config"]["price"] == record["config"]["price"] and d2["features"].size() <= 2 and d2["materials"].size() >= 2 and not d2["customers"].is_empty(), "returned data is a defensive copy")
	# ties 는 통계용일 뿐이다(어떤 조합이 동점인지는 평가기의 몫이고, 동점이면 위 검사가 모두 나열하는지 확인한다).
	ties += 0


# ---------- 판매 ----------

func _real_row(st: State, record: Dictionary) -> Dictionary:
	var sale: Dictionary = st.serve()
	check.call(bool(sale["ok"]), "real sale completed")
	var row: Dictionary = st.last_report.duplicate(true)
	row["margin"] = int(row["revenue"]) - int(row["ingredient_cost"])
	row["config"] = record["config"].duplicate(true)
	return row


func _row(units: int, by_source: Dictionary, config: Dictionary = {}, wait_total: Variant = null) -> Dictionary:
	var price: int = int(config["price"]) if not config.is_empty() else 9000
	var unit_cost: int = Evaluator.unit_cost(config) if not config.is_empty() else 700
	var row: Dictionary = {"record_id": 3, "recipe_name": "시험 메뉴", "version": 2, "price": price, "units": units,
		"revenue": units * price, "ingredient_cost": units * unit_cost, "margin": units * (price - unit_cost),
		"by_source": by_source, "config": config}
	if wait_total != null:
		row["wait_total"] = wait_total
	return row


func _sales(light: Dictionary, rich: Dictionary) -> void:
	var st: State = light["state"]
	var rec: Dictionary = light["record"]
	var row: Dictionary = _real_row(st, rec)
	var before: String = JSON.stringify(row)
	var s: Dictionary = Identity.sales(row)
	check.call(JSON.stringify(row) == before, "sales never mutates the row")
	check.call(s["error"] == "" and s["kind"] == "sales" and s["available"], "real receipt projects")
	check.call(s["units"] == int(row["units"]) and s["margin"] == int(row["revenue"]) - int(row["ingredient_cost"]), "units and margin are the real receipt values")
	check.call(s["ingredient_cost"] == s["units"] * Evaluator.unit_cost(rec["config"]), "ingredient cost is exactly units x real unit cost")
	check.call(not s["has_wait"] and s["average_wait"] == 0.0, "a real single-menu receipt has no wait, so none is shown")
	var tasted: Dictionary = Identity.describe(rec)
	for key in ["headline", "features", "materials", "unit_cost", "prep_seconds"]:
		check.call(s[key] == tasted[key], "sales identity matches the tasted identity: " + key)
	var total: int = 0
	for id in row["by_source"]:
		total += int(row["by_source"][id])
	check.call(total == s["units"], "customer counts add up to units")
	for c in s["customers"]:
		check.call(int(row["by_source"][c["id"]]) == c["units"] and c["units"] > 0 and not c.has("score"), "buyers are actual orders, not scores")
	# 실제 두 메뉴 영수증.
	var second: Dictionary = rich["record"].duplicate(true)
	second["record_id"] = int(rec["record_id"]) + 1
	var two: Dictionary = MenuSales.simulate([rec, second], 1, st.current_staffing())
	check.call(str(two["error"]) == "" and two["menus"].size() == 2, "real two-menu receipt")
	if str(two["error"]) == "":
		for menu in two["menus"]:
			var m: Dictionary = Identity.sales(menu)
			check.call(m["error"] == "" and m["available"] and m["units"] == int(menu["units"]) and m["margin"] == int(menu["margin"]), "each menu row projects by itself")
	var config: Dictionary = rec["config"]
	# 동점/단독/일반 손님.
	var tie: Dictionary = Identity.sales(_row(5, {"dohyun": 2, "hayoung": 2, "maru": 0, "walkin": 1}, config))
	check.call(tie["error"] == "" and tie["customers"].size() == 2 and tie["customers"][0]["id"] == "dohyun" and tie["customers"][1]["id"] == "hayoung" and tie["customers"][0]["units"] == 2, "ties list every top buyer in catalog order")
	var walk: Dictionary = Identity.sales(_row(3, {"walkin": 3}, config))
	check.call(walk["customers"].size() == 1 and walk["customers"][0]["name"] == "일반 손님", "walk-in buyers are named plainly")
	var none: Dictionary = Identity.sales(_row(0, {"dohyun": 0, "hayoung": 0, "maru": 0, "walkin": 0}, config, 0))
	check.call(none["error"] == "" and none["customers"].is_empty() and none["units"] == 0 and none["margin"] == 0 and not none["has_wait"], "no completed orders: no invented buyer, margin or wait")
	# 대기.
	var waited: Dictionary = Identity.sales(_row(5, {"dohyun": 5}, config, 600))
	check.call(waited["has_wait"] and is_equal_approx(waited["average_wait"], 120.0), "average wait needs wait_total and units")
	check.call(not Identity.sales(_row(5, {"dohyun": 5}, config))["has_wait"], "absent wait_total shows no wait")
	# 예전 영수증: 구성 없음/빈 구성.
	for legacy in [_row(2, {"maru": 2}), _row(2, {"maru": 2}, {})]:
		var old: Dictionary = Identity.sales(legacy)
		check.call(old["error"] == "" and old["available"] == false and old["headline"] == "" and old["materials"].is_empty() and old["config"].is_empty() and str(old["note"]) != "" and old["units"] == 2 and old["recipe_name"] == "시험 메뉴", "unknown config stays unavailable, row name is not turned into a recipe")
	var missing: Dictionary = _row(2, {"maru": 2})
	missing.erase("config")
	check.call(Identity.sales(missing)["available"] == false and Identity.sales(missing)["error"] == "", "absent config key is a valid unavailable identity")
	# 거절: 개수/비용/종류.
	var rejects: Array = []
	rejects.append(_row(5, {"dohyun": 2, "maru": 2}, config))
	rejects.append(_row(2, {"stranger": 2}, config))
	rejects.append(_row(2, {"maru": -2, "dohyun": 4}, config))
	for value in ["700", 700.5, -700, true]:
		var r: Dictionary = _row(2, {"maru": 2}, config)
		r["ingredient_cost"] = value
		rejects.append(r)
	var unrelated: Dictionary = _row(2, {"maru": 2}, config)
	unrelated["ingredient_cost"] = int(unrelated["ingredient_cost"]) + 100
	rejects.append(unrelated)
	var bad_margin: Dictionary = _row(2, {"maru": 2}, config)
	bad_margin["margin"] = int(bad_margin["margin"]) + 1
	rejects.append(bad_margin)
	var bad_price: Dictionary = _row(2, {"maru": 2}, config)
	bad_price["price"] = int(bad_price["price"]) + 100
	bad_price["revenue"] = int(bad_price["price"]) * 2
	rejects.append(bad_price)
	var bad_revenue: Dictionary = _row(2, {"maru": 2}, config)
	bad_revenue["revenue"] = int(bad_revenue["revenue"]) + 1
	rejects.append(bad_revenue)
	# 올바른 영수증을 먼저 만든 뒤 구성만 망가뜨린다(도우미가 나쁜 구성을 대신 고치지 않는다).
	var bad_config: Dictionary = _row(2, {"maru": 2})
	bad_config["config"] = {"broth": "nothing"}
	rejects.append(bad_config)
	rejects.append(_row(2, {"maru": 2}, config, "x"))
	rejects.append(_row(0, {"maru": 0}, config, 5))
	var free_cost: Dictionary = _row(0, {"maru": 0})
	free_cost["ingredient_cost"] = 300
	rejects.append(free_cost)
	var no_cost: Dictionary = _row(2, {"maru": 2})
	no_cost.erase("by_source")
	rejects.append(no_cost)
	rejects.append({})
	for item in rejects:
		var bad: Dictionary = Identity.sales(item)
		check.call(str(bad["error"]) != "" and bad["available"] == false and bad["units"] == 0 and bad["customers"].is_empty(), "malformed receipt rejected: " + JSON.stringify(item).left(70))
	# 복사본.
	var copy: Dictionary = Identity.sales(_row(2, {"maru": 2}, config))
	copy["customers"].clear()
	copy["config"]["price"] = 1
	copy["features"].append("x")
	var again: Dictionary = Identity.sales(_row(2, {"maru": 2}, config))
	check.call(again["customers"].size() == 1 and again["config"]["price"] == config["price"] and again["features"].size() <= 2, "sales returns defensive copies")


# ---------- 카드 ----------

func _mount(card: Card) -> void:
	if _tree != null:
		_tree.root.add_child(card)


func _unmount(card: Card) -> void:
	if card.is_inside_tree():
		card.get_parent().remove_child(card)
	card.free()


func _card(light_record: Dictionary, rich_record: Dictionary) -> void:
	var tasting: Dictionary = Identity.describe(light_record)
	var card := Card.new()
	# 화면 밖이면 연출은 아무것도 하지 않는다.
	card.present(tasting)
	card.play_reveal()
	check.call(card.reveal_count() == 0, "reveal does nothing while detached")
	_mount(card)
	check.call(card.reveal_count() == 0 and not card.reveal_active(), "present() never starts the reveal")
	var open: Button = _find(card, "MenuIdentityOpen") as Button
	var title: Label = _find(card, "MenuIdentityTitle") as Label
	check.call(open != null and title != null and title.text == tasting["headline"], "open button and title exist")
	if open == null or title == null:
		_unmount(card)
		return
	check.call(open.custom_minimum_size.y >= 44.0 and not open.disabled, "whole-card target is large and enabled")
	check.call(open.mouse_filter != Control.MOUSE_FILTER_IGNORE and title.mouse_filter == Control.MOUSE_FILTER_IGNORE, "children never steal input from the target")
	var margin: MarginContainer = open.get_parent().get_child(1) as MarginContainer
	check.call(margin != null and margin.get_theme_constant("margin_left") >= 16 and margin.get_theme_constant("margin_top") >= 8, "explicit frame padding")
	check.call(title.get_theme_font_size("font_size") == 16, "title is 16px")
	var art: Node = _find(card, "MenuIdentityArt")
	var pictures: int = 0
	for p in art.get_children():
		pictures += 1 if (p as TextureRect).texture != null and (p as TextureRect).custom_minimum_size == Vector2(32, 32) else 0
	check.call(pictures == tasting["materials"].size(), "every material has its real 32px picture")
	check.call(_find(card, "MenuIdentityPortraits").get_child_count() == tasting["customers"].size(), "best-taste customers show their portraits")
	var mode: String = (_find(card, "MenuIdentityMode") as Label).text
	var line: String = (_find(card, "MenuIdentityCustomer") as Label).text
	check.call(mode == "시식 점수" and not _joined(card).contains("구매 아님"), "tasting caption, no warning text")
	# 면 그림: 일반 밀 면은 원본 면 다발, 메밀면은 기존 원본 음식 그림을 그대로 쓴다.
	for noodle in ["noodle_thin", "noodle_medium", "noodle_thick"]:
		check.call(Card._food(noodle) == Mock.texture("noodles"), "ordinary noodle art is the original bundle: " + noodle)
	check.call(Card._food("noodle_buckwheat") == BowlArt.food("noodle_buckwheat") and Card._food("noodle_buckwheat") != Mock.texture("noodles"), "buckwheat keeps its own original food art")
	var first: Dictionary = tasting["customers"][0]
	var expected: String = ("%s · 공동%d점" if tasting["customers"].size() > 1 else "%s · %d점")
	var names: Array[String] = []
	for c in tasting["customers"]:
		names.append(str(c["name"]))
	check.call(line == expected % ["·".join(PackedStringArray(names)), int(first["score"])], "tasting line: " + line)
	# 눌림/드래그 취소.
	var events: Array = []
	card.details_requested.connect(func() -> void: events.append("details"))
	var ink: Color = title.get_theme_color("font_color")
	open.button_down.emit()
	check.call(title.get_theme_color("font_color") == Color.WHITE and (_find(card, "MenuIdentityChevron") as TextureRect).modulate == Color.WHITE, "pressed turns title and chevron white")
	open.button_up.emit()
	check.call(title.get_theme_color("font_color") == ink and events.is_empty(), "drag cancel restores colors and sends nothing")
	open.pressed.emit()
	check.call(events == ["details"], "a deliberate press asks for details once")
	# shown_model 은 복사본.
	var shown: Dictionary = card.shown_model()
	shown["headline"] = "바뀜"
	check.call(card.shown_model() == tasting, "shown_model is a defensive copy")
	# 같은 모델을 다시 줘도 연출이 없다. 연출은 명시 호출뿐.
	card.present(tasting)
	check.call(card.reveal_count() == 0, "re-present does not replay")
	card.play_reveal()
	check.call(card.reveal_count() == 1 and card.reveal_active(), "explicit reveal plays once")
	card.present(Identity.describe(rich_record))
	check.call(not card.reveal_active() and card.reveal_count() == 1 and (_find(card, "MenuIdentityContent") as Control).modulate.a == 1.0, "changing the model ends the reveal in the resting state and never replays")
	# 동점/0점 문구.
	var tie: Dictionary = tasting.duplicate(true)
	tie["customers"] = [{"id": "dohyun", "name": "한도윤", "score": 87}, {"id": "hayoung", "name": "서하영", "score": 87}]
	card.present(tie)
	check.call((_find(card, "MenuIdentityCustomer") as Label).text == "한도윤·서하영 · 공동87점", "tied tasting line")
	var zero: Dictionary = tasting.duplicate(true)
	zero["customers"] = [{"id": "maru", "name": "윤마루", "score": 0}]
	card.present(zero)
	check.call((_find(card, "MenuIdentityCustomer") as Label).text == "윤마루 · 0점", "zero score is stated plainly")
	# 손님 줄이 없거나 모양이 틀린 사용 가능 시식 모델은 오류로 막는다.
	for broken in [[], "none", [5], [{"id": "dohyun"}], [{"id": "dohyun", "name": "한도윤", "score": "9"}]]:
		var m: Dictionary = tasting.duplicate(true)
		m["customers"] = broken
		card.present(m)
		var note: Label = _find(card, "MenuIdentityNotice") as Label
		check.call(note.visible and note.text != "" and open.disabled, "bad tasting customers show a model error: " + str(broken))
	var no_rows: Dictionary = tasting.duplicate(true)
	no_rows.erase("customers")
	card.present(no_rows)
	check.call(open.disabled and (_find(card, "MenuIdentityNotice") as Label).visible, "absent customers show a model error")
	# 잘못된 입력.
	for bad in [Identity.describe({}), {"kind": "other"}, {}]:
		card.present(bad)
		var note2: Label = _find(card, "MenuIdentityNotice") as Label
		events.clear()
		open.pressed.emit()
		var before_count: int = card.reveal_count()
		card.play_reveal()
		check.call(note2.visible and note2.text != "" and open.disabled and events.is_empty() and card.reveal_count() == before_count, "invalid model: visible note, locked, no reveal")
	# 판매 카드.
	var config: Dictionary = light_record["config"]
	var sold: Dictionary = Identity.sales(_row(5, {"dohyun": 4, "hayoung": 1}, config, 600))
	card.present(sold)
	check.call((_find(card, "MenuIdentityMode") as Label).text == "많이 주문한 손님" and (_find(card, "MenuIdentityCustomer") as Label).text == "한도윤 · 4그릇", "sales caption and line")
	var stats: String = (_find(card, "MenuIdentityStats") as Label).text
	check.call(stats.contains("판매 5그릇") and stats.contains("재료비를 뺀 금액") and stats.contains("평균 대기 120초"), "sales stats: " + stats)
	check.call(not open.disabled, "known receipt can open details")
	card.present(Identity.sales(_row(5, {"dohyun": 2, "hayoung": 2, "walkin": 1}, config)))
	check.call((_find(card, "MenuIdentityCustomer") as Label).text == "한도윤·서하영 · 각2그릇" and not (_find(card, "MenuIdentityStats") as Label).text.contains("대기"), "tied sales line, no invented wait")
	card.present(Identity.sales(_row(0, {"maru": 0}, config)))
	var empty_text: String = _joined(card)
	check.call(empty_text.contains("판매 0그릇") and empty_text.contains("완료된 주문이 없어요.") and not empty_text.contains("만족"), "zero units: no buyer, satisfaction or wait")
	card.present(Identity.sales(_row(2, {"maru": 2})))
	check.call(open.disabled and (_find(card, "MenuIdentityNotice") as Label).visible and _joined(card).contains("판매 2그릇"), "legacy receipt is legible and its detail is locked")
	_unmount(card)
