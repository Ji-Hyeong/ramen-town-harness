extends SceneTree
## 대회 채점 시험(파일 쓰기/저장/서비스/UI 없음). 실행: godot --headless --path game --script res://tests/contest_scoring_tests.gd
## 모든 확인이 끝났고 실패가 없을 때만 종료 코드 0.

const Contest = preload("res://scripts/domain/ramen_contest.gd")
const Evaluator = preload("res://scripts/domain/recipe_evaluator.gd")
const Catalog = preload("res://scripts/domain/ingredient_catalog.gd")

const AXES: Array = ["rich", "salt", "aroma", "chew", "spice"]

## 대회별 기대 목표(정의와 별도로 시험에 고정해 둔 명세).
const EXPECTED_TARGETS: Dictionary = {
	"clear_bowl": {"rich": 2, "salt": 6, "aroma": 7, "chew": 5, "spice": 0},
	"deep_bowl": {"rich": 8, "salt": 4, "aroma": 5, "chew": 7, "spice": 0},
	"regional_bowl": {"rich": 3, "salt": 6, "aroma": 8, "chew": 5, "spice": 3},
}

var checks: int = 0
var failures: Array[String] = []


func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		print("FAIL: ", label)


## 금메달 증인. 프로필(손계산): clear {2,6,7,5,0} 궁합 +18, deep {8,4,5,7,0} 궁합 +15, regional {3,6,8,5,3} 궁합 +5.
## 각 증인은 자기 대회 목표와 간격 0(테마 100)이라 손님 평균이 50 이상이면 금메달(70+0.3*50=85)이다.
func witness(contest_id: String) -> Dictionary:
	match contest_id:
		"clear_bowl":
			return {"broth": "broth_dashi", "tare": "tare_shio", "oil": "oil_scallion", "noodle": "noodle_thin",
				"toppings": ["topping_nori"], "cook": "cook_firm", "price": 9000}
		"deep_bowl":
			return {"broth": "broth_tonkotsu", "tare": "tare_shio", "oil": "oil_garlic", "noodle": "noodle_thick",
				"toppings": ["topping_egg"], "cook": "cook_normal", "price": 9000}
	return {"broth": "broth_clam", "tare": "tare_plum", "oil": "oil_pepper", "noodle": "noodle_medium",
		"toppings": ["topping_mushroom"], "cook": "cook_normal", "price": 9000}


## 평가기 출력에서 수식을 시험 안에서 다시 계산한다(구현 코드를 호출하지 않는다).
func expected_score(contest_id: String, config: Dictionary) -> Dictionary:
	var ev: Dictionary = Evaluator.evaluate(config)
	var targets: Dictionary = EXPECTED_TARGETS[contest_id]
	var gaps: int = 0
	for axis in AXES:
		gaps += absi(int(ev["profile"][axis]) - int(targets[axis]))
	var theme: int = roundi(maxf(0.0, 100.0 - 12.0 * float(gaps) / 5.0))
	var sum: int = 0
	for c in ev["customers"]:
		sum += int(c["score"])
	var audience: int = roundi(float(sum) / 3.0)
	return {"theme": theme, "audience": audience, "score": roundi(0.7 * theme + 0.3 * audience)}


func _init() -> void:
	test_definitions()
	test_rejections()
	test_bands()
	test_formula_and_witnesses()
	test_equivalence_and_counting()
	test_regional_requirement()
	test_copy_safety()
	print("contest scoring checks=%d failures=%d" % [checks, failures.size()])
	quit(0 if checks > 0 and failures.is_empty() else 1)


func test_definitions() -> void:
	check(Contest.ids() == ["clear_bowl", "deep_bowl", "regional_bowl"], "ids order")
	var cat: Array = Contest.catalog()
	check(cat.size() == 3, "3 contests")
	var spec: Dictionary = {"clear_bowl": [1, 3, 2000, 3000], "deep_bowl": [2, 6, 4000, 5000], "regional_bowl": [3, 11, 6000, 8000]}
	for id in spec:
		var c: Dictionary = Contest.find(id)
		var s: Array = spec[id]
		check(int(c["rank"]) == s[0] and int(c["min_day"]) == s[1] and int(c["fee"]) == s[2] and int(c["article_cash"]) == s[3], id + " rank/day/fee/article")
		check(str(c["title"]) != "" and str(c["description"]) != "" and str(c["criteria"]) != "", id + " korean texts")
		check(str(c["article_text"]).count("%s") == 1 and str(c["article_title"]).count("%s") == 1, id + " recipe placeholder")
		check((str(c["article_title"]) % "라멘").find("%") == -1, id + " article title formats")
		check(c["targets"] == EXPECTED_TARGETS[id], id + " targets")
	check(Contest.find("nope").is_empty(), "unknown find empty")
	check(bool(Contest.find("regional_bowl")["requires_discovery"]) and not bool(Contest.find("clear_bowl")["requires_discovery"]), "only regional requires discovery")
	check(EXPECTED_TARGETS["clear_bowl"] != EXPECTED_TARGETS["deep_bowl"] and EXPECTED_TARGETS["deep_bowl"] != EXPECTED_TARGETS["regional_bowl"] and EXPECTED_TARGETS["clear_bowl"] != EXPECTED_TARGETS["regional_bowl"], "targets differ")


func test_rejections() -> void:
	var good: Dictionary = witness("clear_bowl")
	check(str(Contest.evaluate("nope", good)["error"]) != "", "unknown contest rejected")
	check(str(Contest.evaluate("clear_bowl", {})["error"]) != "", "empty config rejected")
	var bad_price: Dictionary = good.duplicate(true)
	bad_price["price"] = 9050
	check(str(Contest.evaluate("clear_bowl", bad_price)["error"]) != "", "price step rejected")
	bad_price["price"] = 9000.0
	check(str(Contest.evaluate("clear_bowl", bad_price)["error"]) != "", "float price rejected")
	var bad_id: Dictionary = good.duplicate(true)
	bad_id["broth"] = "broth_nope"
	check(str(Contest.evaluate("clear_bowl", bad_id)["error"]) != "", "unknown ingredient rejected")
	var bad_top: Dictionary = good.duplicate(true)
	bad_top["toppings"] = ["topping_egg", "topping_egg"]
	check(str(Contest.evaluate("clear_bowl", bad_top)["error"]) != "", "duplicate topping rejected")
	var extra: Dictionary = good.duplicate(true)
	extra["score"] = 100
	check(str(Contest.evaluate("clear_bowl", extra)["error"]) != "", "extra key (injected score) rejected")
	check(Contest.evaluate("clear_bowl", bad_id).has("score") == false, "error result has no score")


func test_bands() -> void:
	var expect: Dictionary = {0: 0, 54: 0, 55: 1, 69: 1, 70: 2, 84: 2, 85: 3, 100: 3}
	for s in expect:
		check(Contest.band_for(s) == expect[s], "band_for(%d)" % s)
	check([Contest.prize_for(0), Contest.prize_for(1), Contest.prize_for(2), Contest.prize_for(3)] == [0, 4000, 10000, 18000], "prizes")
	check(Contest.prize_for(4) == 0 and Contest.prize_for(-1) == 0, "invalid band prize 0")
	check(Contest.band_name(0) != Contest.band_name(1) and Contest.band_name(2) != Contest.band_name(3) and Contest.band_name(1) != Contest.band_name(3), "band names distinct")
	check(Contest.band_name(9) == "", "invalid band name empty")


func test_formula_and_witnesses() -> void:
	for id in Contest.ids():
		var cfg: Dictionary = witness(id)
		var r: Dictionary = Contest.evaluate(id, cfg)
		check(str(r["error"]) == "", id + " witness valid: " + str(r["error"]))
		if str(r["error"]) != "":
			continue
		var e: Dictionary = expected_score(id, cfg)
		check(int(r["theme_score"]) == e["theme"] and int(r["audience_score"]) == e["audience"] and int(r["score"]) == e["score"], "%s formula %s vs %s" % [id, str(r), str(e)])
		check(int(r["theme_score"]) == 100, id + " witness matches target exactly")
		check(int(r["score"]) >= 85 and int(r["band"]) == 3, id + " gold witness score=%d" % int(r["score"]))
		check(int(r["band"]) == Contest.band_for(int(r["score"])), id + " band consistent")
		check(str(Contest.evaluate(id, cfg)) == str(r), id + " deterministic")
		check(r["feedback"].size() == 5, id + " 5 axis feedback")
		for f in r["feedback"]:
			check(int(f["gap"]) == absi(int(f["current"]) - int(f["target"])) and int(f["target"]) == int(EXPECTED_TARGETS[id][f["axis"]]) and str(f["hint"]) != "", id + " feedback " + str(f["axis"]))
		# 가격/입력의 점수는 영향이 없다: 가격만 다른 구성은 같은 점수.
		var cheap: Dictionary = cfg.duplicate(true)
		cheap["price"] = 5000
		check(int(Contest.evaluate(id, cheap)["score"]) == int(r["score"]), id + " price does not change score")
	# 서로 다른 우승 레시피: 각 증인은 자기 대회에서 다른 대회보다 테마 점수가 높다.
	for id in Contest.ids():
		for other in Contest.ids():
			if other == id:
				continue
			var own: Dictionary = Contest.evaluate(id, witness(id))
			var cross: Dictionary = Contest.evaluate(other, witness(id))
			if str(cross["error"]) != "":
				continue
			check(int(own["theme_score"]) > int(cross["theme_score"]), "%s witness fits %s better than %s" % [id, id, other])
	check(int(Contest.evaluate("deep_bowl", witness("clear_bowl"))["band"]) < 3, "clear witness is not gold in deep_bowl")
	check(int(Contest.evaluate("clear_bowl", witness("deep_bowl"))["band"]) < 3, "deep witness is not gold in clear_bowl")


func test_equivalence_and_counting() -> void:
	var canonical: Dictionary = witness("clear_bowl")
	var legacy: Dictionary = canonical.duplicate(true)
	legacy.erase("toppings")
	legacy["topping"] = "topping_nori"
	var a: Dictionary = Contest.evaluate("clear_bowl", canonical)
	var b: Dictionary = Contest.evaluate("clear_bowl", legacy)
	check(str(b["error"]) == "" and str(a) == str(b), "legacy single topping equals canonical")
	check(b["config"].has("toppings") and not b["config"].has("topping"), "result config is canonical")
	# 토핑 2개: 반숙란(rich+1)이 정확히 한 번 더해진다. 순서가 달라도 같은 구성.
	var multi: Dictionary = canonical.duplicate(true)
	multi["toppings"] = ["topping_nori", "topping_egg"]
	var m: Dictionary = Contest.evaluate("clear_bowl", multi)
	check(str(m["error"]) == "", "multi topping valid")
	check(int(m["profile"]["rich"]) == int(a["profile"]["rich"]) + 1 and int(m["profile"]["salt"]) == int(a["profile"]["salt"]), "second topping counted once")
	check(m["config"]["toppings"] == ["topping_egg", "topping_nori"], "toppings canonical order")
	check(int(m["theme_score"]) < int(a["theme_score"]), "extra rich moves away from clear target")
	var e: Dictionary = expected_score("clear_bowl", multi)
	check(int(m["score"]) == e["score"], "multi topping score formula")
	# 발견 재료가 프로필에 실제로 반영된다: 초피유(spice 3)가 증인의 spice 3의 유일한 근원.
	var r: Dictionary = Contest.evaluate("regional_bowl", witness("regional_bowl"))
	check(int(r["profile"]["spice"]) == 3 and int(r["profile"]["aroma"]) == 8, "discovery contributions counted")


func test_regional_requirement() -> void:
	var legacy_only: Dictionary = witness("deep_bowl")
	var r: Dictionary = Contest.evaluate("regional_bowl", legacy_only)
	check(str(r["error"]) != "" and not r.has("score"), "regional rejects config without discovery")
	# 발견 재료가 토핑에만 있어도 인정된다(슬롯 무관).
	var topping_only: Dictionary = witness("deep_bowl")
	topping_only["toppings"] = ["topping_pickle"]
	check(str(Contest.evaluate("regional_bowl", topping_only)["error"]) == "", "discovery topping accepted")
	# 같은 구성은 발견 요구가 없는 대회에서는 채점된다.
	check(str(Contest.evaluate("deep_bowl", legacy_only)["error"]) == "", "non-regional unaffected")


func test_copy_safety() -> void:
	var before: String = str(Contest.catalog())
	var cat: Array = Contest.catalog()
	cat[0]["title"] = "변조"
	cat[0]["targets"]["rich"] = 99
	cat.clear()
	var found: Dictionary = Contest.find("deep_bowl")
	found["targets"]["salt"] = 99
	found["fee"] = 1
	check(str(Contest.catalog()) == before, "catalog mutation does not leak")
	var cfg: Dictionary = witness("clear_bowl")
	var cfg_before: String = str(cfg)
	var r: Dictionary = Contest.evaluate("clear_bowl", cfg)
	r["config"]["price"] = 1000
	r["config"]["toppings"].append("topping_egg")
	r["feedback"][0]["gap"] = 99
	r["profile"]["rich"] = 99
	check(str(cfg) == cfg_before, "input config untouched")
	check(int(Contest.evaluate("clear_bowl", cfg)["profile"]["rich"]) == 2 and int(Contest.evaluate("clear_bowl", cfg)["feedback"][0]["gap"]) == 0, "result mutation does not leak")
	check(str(Contest.catalog()) == before, "catalog intact after evaluate")
