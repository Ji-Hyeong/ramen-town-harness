extends SceneTree
## 레시피 연구 지도/정체성 focused 시험. 순수 모듈만 preload하고 상태/UI/저장은 쓰지 않는다.

const D := preload("res://scripts/domain/recipe_discovery.gd")

const THEME_IDS: Array = ["bone_depth", "clear_light", "fire_oil", "noodle_chew", "topping_stack", "clam_mushroom", "citrus_light", "sesame_roast"]

var checks := 0
var failures := 0


func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: ", label)


func _init() -> void:
	_test_catalog()
	_test_witnesses()
	_test_matching_rules()
	_test_invalid()
	_test_describe()
	_test_pages()
	_test_invariance()
	print("recipe_discovery checks=%d failures=%d" % [checks, failures])
	quit(0 if failures == 0 else 1)


func _cfg(broth: String, tare: String, oil: String, noodle: String, toppings: Array, cook: String, price: int = 9000, process: Dictionary = {}) -> Dictionary:
	var c := {"broth": broth, "tare": tare, "oil": oil, "noodle": noodle, "toppings": toppings, "cook": cook, "price": price}
	if not process.is_empty():
		c["process"] = process
	return c


## 주제마다 그 주제에 맞는 실제 구성(증인).
func _witness(id: String) -> Dictionary:
	match id:
		"bone_depth":
			return _cfg("broth_tonkotsu", "tare_miso", "oil_garlic", "noodle_thick", ["topping_chashu"], "cook_normal")
		"clear_light":
			return _cfg("broth_chicken", "tare_shoyu", "oil_scallion", "noodle_thin", ["topping_nori"], "cook_firm")
		"fire_oil":
			return _cfg("broth_tonkotsu", "tare_miso", "oil_chili", "noodle_medium", ["topping_egg"], "cook_normal")
		"noodle_chew":
			return _cfg("broth_tonkotsu", "tare_shio", "oil_garlic", "noodle_thick", ["topping_egg"], "cook_firm")
		"topping_stack":
			return _cfg("broth_chicken", "tare_shoyu", "oil_scallion", "noodle_medium", ["topping_chashu", "topping_chashu"], "cook_normal")
		"clam_mushroom":
			return _cfg("broth_clam", "tare_shio", "oil_scallion", "noodle_thin", ["topping_mushroom"], "cook_normal")
		"citrus_light":
			return _cfg("broth_chicken", "tare_shoyu", "oil_scallion", "noodle_thin", ["topping_citrus_peel"], "cook_normal")
		"sesame_roast":
			return _cfg("broth_tonkotsu", "tare_shio", "oil_roasted_sesame", "noodle_thick", ["topping_egg"], "cook_normal")
	return {}


func _test_catalog() -> void:
	var cat := D.catalog()
	check(cat.size() == 8, "eight themes")
	var seen: Array = []
	for entry in cat:
		var e: Dictionary = entry
		for key in ["id", "title", "hint", "origin", "criteria"]:
			check(e.has(key), "theme key %s" % key)
		check(not str(e["title"]).is_empty() and not str(e["hint"]).is_empty() and not str(e["origin"]).is_empty(), "theme text %s" % e["id"])
		check(not seen.has(e["id"]), "unique id %s" % e["id"])
		seen.append(e["id"])
		check((e["criteria"] as Array).size() >= 1, "criteria %s" % e["id"])
		for c in e["criteria"]:
			check(not str((c as Dictionary)["hint"]).is_empty(), "criterion hint %s" % e["id"])
	check(seen == THEME_IDS, "catalog order")
	# 호출자가 복사본을 고쳐도 다음 호출은 원본 그대로.
	cat[0]["title"] = "변조"
	(cat[0]["criteria"] as Array).clear()
	var again := D.catalog()
	check(again[0]["title"] != "변조" and (again[0]["criteria"] as Array).size() >= 1, "catalog returns copies")


func _test_witnesses() -> void:
	for id in THEME_IDS:
		var cfg := _witness(id)
		check(D.matched_ids(cfg).has(id), "witness matches %s" % id)
		var pages := D.pages([], cfg, ["broth_clam", "topping_mushroom", "oil_roasted_sesame", "topping_citrus_peel"])
		for p in pages:
			if p["id"] == id:
				check(p["ready"] and p["progress"] == p["total"] and (p["missing"] as Array).is_empty(), "witness ready %s" % id)
	# 다른 증인은 다른 주제를 대신 채우지 않는다.
	check(not D.matched_ids(_witness("fire_oil")).has("clear_light"), "fire_oil is not clear_light")
	check(not D.matched_ids(_witness("clear_light")).has("bone_depth"), "clear_light is not bone_depth")
	# 한 구성이 여러 주제에 속할 수 있다.
	var chewy := _cfg("broth_tonkotsu", "tare_miso", "oil_garlic", "noodle_thick", ["topping_chashu"], "cook_firm")
	var both := D.matched_ids(chewy)
	check(both.has("bone_depth") and both.has("noodle_chew"), "one recipe can match several themes")


func _test_matching_rules() -> void:
	# 부분 충족: 진국은 있지만 진함이 모자람.
	var near := _cfg("broth_tonkotsu", "tare_shio", "oil_scallion", "noodle_medium", ["topping_nori"], "cook_normal")
	check(not D.matched_ids(near).has("bone_depth"), "missing criterion does not match")
	var near_page := _page(D.pages([], near, []), "bone_depth")
	check(near_page["progress"] == 1 and near_page["total"] == 2 and (near_page["missing"] as Array).size() == 1 and not near_page["ready"], "partial progress and one missing hint")
	# 더 알맞은 구성도 통과: 기준만 맞으면 정확한 레시피가 아니어도 된다.
	var other := _cfg("broth_tonkotsu", "tare_shoyu", "oil_chili", "noodle_thin", ["topping_chashu", "topping_egg"], "cook_normal")
	check(D.matched_ids(other).has("bone_depth"), "alternative recipe also matches bone_depth")
	# 반복 분량: 한 분량은 안 되고 두 분량은 된다. 서로 다른 토핑 둘은 반복이 아니다.
	var once := _cfg("broth_chicken", "tare_shoyu", "oil_scallion", "noodle_medium", ["topping_chashu"], "cook_normal")
	var twice := _cfg("broth_chicken", "tare_shoyu", "oil_scallion", "noodle_medium", ["topping_chashu", "topping_chashu"], "cook_normal")
	var mixed := _cfg("broth_chicken", "tare_shoyu", "oil_scallion", "noodle_medium", ["topping_chashu", "topping_egg"], "cook_normal")
	check(not D.matched_ids(once).has("topping_stack"), "one portion is not stacked")
	check(D.matched_ids(twice).has("topping_stack"), "two portions stacked")
	check(not D.matched_ids(mixed).has("topping_stack"), "two different toppings are not a repeat")
	# 진국은 절임 무로 진함이 내려가도 맑은 주제(닭/다시/조개 육수 필요)에 들지 않는다.
	var heavy := _cfg("broth_tonkotsu", "tare_shio", "oil_scallion", "noodle_thin", ["topping_pickle"], "cook_normal")
	check(not D.matched_ids(heavy).has("clear_light"), "tonkotsu is not clear")
	# 순서: 토핑 선택 순서만 다른 구성은 같은 결과.
	var ab := _cfg("broth_chicken", "tare_shoyu", "oil_scallion", "noodle_medium", ["topping_chashu", "topping_chashu", "topping_egg"], "cook_normal")
	var ba := _cfg("broth_chicken", "tare_shoyu", "oil_scallion", "noodle_medium", ["topping_egg", "topping_chashu", "topping_chashu"], "cook_normal")
	check(D.matched_ids(ab) == D.matched_ids(ba) and D.matched_ids(ab).has("topping_stack"), "topping order is irrelevant")
	check(str(D.describe(ab)) == str(D.describe(ba)), "topping order gives identical description")
	# 가격: 최소/최대 가격 모두 같은 주제.
	for id in THEME_IDS:
		var w := _witness(id)
		var cheap := w.duplicate(true)
		cheap["price"] = 1000
		var dear := w.duplicate(true)
		dear["price"] = 30000
		check(D.matched_ids(cheap) == D.matched_ids(w) and D.matched_ids(dear) == D.matched_ids(w), "price independent %s" % id)
		check(D.describe(cheap)["title"] == D.describe(w)["title"], "price independent title %s" % id)
	# 공법: 같은 재료라도 강불 추출이 진함을 올려 진국 주제를 연다.
	var plain := _cfg("broth_tonkotsu", "tare_shio", "oil_scallion", "noodle_medium", ["topping_egg"], "cook_normal")
	var rolled := _cfg("broth_tonkotsu", "tare_shio", "oil_scallion", "noodle_medium", ["topping_egg"], "cook_normal", 9000, {"broth": "rolling", "noodle": "standard"})
	check(not D.matched_ids(plain).has("bone_depth") and D.matched_ids(rolled).has("bone_depth"), "process changes theme match")
	# 옛 모양(topping 하나)도 같은 결과.
	var legacy := {"broth": "broth_tonkotsu", "tare": "tare_miso", "oil": "oil_garlic", "noodle": "noodle_thick", "topping": "topping_chashu", "cook": "cook_normal", "price": 9000}
	check(D.matched_ids(legacy) == D.matched_ids(_witness("bone_depth")), "legacy shape matches the same themes")


func _test_invalid() -> void:
	var good := _witness("bone_depth")
	var bad_list: Array = []
	var unknown := good.duplicate(true)
	unknown["broth"] = "broth_unknown"
	bad_list.append(unknown)
	var bad_price := good.duplicate(true)
	bad_price["price"] = 950
	bad_list.append(bad_price)
	var empty_toppings := good.duplicate(true)
	empty_toppings["toppings"] = []
	bad_list.append(empty_toppings)
	var many := good.duplicate(true)
	many["toppings"] = ["topping_egg", "topping_egg", "topping_egg", "topping_egg", "topping_egg"]
	bad_list.append(many)
	var not_array := good.duplicate(true)
	not_array["toppings"] = "topping_egg"
	bad_list.append(not_array)
	var named := good.duplicate(true)
	named["name"] = "내 라멘"
	bad_list.append(named)
	var bad_process := good.duplicate(true)
	bad_process["process"] = {"broth": "nope", "noodle": "standard"}
	bad_list.append(bad_process)
	bad_list.append({})
	for bad in bad_list:
		check(D.matched_ids(bad).is_empty(), "invalid matches nothing")
		var d := D.describe(bad)
		check(str(d["error"]) != "" and d["title"] == "" and d["subtitle"] == "" and (d["tags"] as Array).is_empty(), "invalid describe is an explicit error")
	var page := _page(D.pages([], unknown, []), "bone_depth")
	check(page["progress"] == 0 and not page["ready"] and (page["missing"] as Array).size() == page["total"], "invalid draft: nothing satisfied")
	var ok := D.describe(good)
	check(str(ok["error"]) == "" and str(ok["title"]) != "", "valid describe has no error")


func _test_describe() -> void:
	var base := _witness("bone_depth")
	var title := str(D.describe(base)["title"])
	check(title.contains("돼지뼈") and title.contains("된장") and title.contains("마늘유") and title.contains("차슈"), "title reflects broth/tare/oil/topping")
	var variants: Array = []
	for key in ["broth", "tare", "oil"]:
		var v := base.duplicate(true)
		v[key] = {"broth": "broth_chicken", "tare": "tare_shio", "oil": "oil_chili"}[key]
		variants.append(v)
	var topped := base.duplicate(true)
	topped["toppings"] = ["topping_chashu", "topping_chashu"]
	variants.append(topped)
	var other_topping := base.duplicate(true)
	other_topping["toppings"] = ["topping_egg"]
	variants.append(other_topping)
	var titles: Array = [title]
	for v in variants:
		var t := str(D.describe(v)["title"])
		check(not titles.has(t), "distinct identity per changed ingredient: " + t)
		titles.append(t)
	check(str(D.describe(topped)["title"]).contains("×2"), "repeated portion shown in title")
	# 면/익힘은 제목이 아닌 부제에만 반영.
	var noodle_changed := base.duplicate(true)
	noodle_changed["noodle"] = "noodle_thin"
	check(D.describe(noodle_changed)["title"] == title and D.describe(noodle_changed)["subtitle"] != D.describe(base)["subtitle"], "noodle changes subtitle only")
	# 태그는 평가기 사실에서만: 같은 구성이면 항상 같고, 사실에 맞다.
	var tags: Array = D.describe(base)["tags"]
	check(tags.has("진함 높음") and tags.has("원가 높음") and tags.has("준비 오래 걸림") and tags.has("궁합 좋음"), "tags follow evaluated facts")
	check(D.describe(base)["tags"] == D.describe(base.duplicate(true))["tags"], "tags are deterministic")
	var rolled := _cfg("broth_tonkotsu", "tare_shio", "oil_scallion", "noodle_medium", ["topping_egg"], "cook_normal", 9000, {"broth": "rolling", "noodle": "rested"})
	check((D.describe(rolled)["tags"] as Array).has("강불 추출") and (D.describe(rolled)["tags"] as Array).has("저가수 숙성"), "process methods become tags")
	check(not (D.describe(base)["tags"] as Array).has("강불 추출"), "default process adds no tag")
	var clash := _cfg("broth_chicken", "tare_shio", "oil_garlic", "noodle_thick", ["topping_egg"], "cook_normal")
	check((D.describe(clash)["tags"] as Array).has("궁합 아쉬움"), "bad pairing tagged")
	var quick := _witness("clear_light")
	check((D.describe(quick)["tags"] as Array).has("빠른 준비") and (D.describe(quick)["tags"] as Array).has("알뜰한 원가"), "quick and cheap tagged")


func _test_pages() -> void:
	var witness := _witness("bone_depth")
	# 초안만으로는 tested 가 아니다.
	var drafted := _page(D.pages([], witness, []), "bone_depth")
	check(drafted["ready"] and not drafted["tested"], "draft is ready but not tested")
	# 보관 기록이 있으면 tested, 초안이 달라도 유지된다.
	var rec := {"record_id": "r1", "config": witness}
	var other_draft := _cfg("broth_chicken", "tare_shoyu", "oil_scallion", "noodle_thin", ["topping_nori"], "cook_firm")
	var tasted := _page(D.pages([rec], other_draft, []), "bone_depth")
	check(tasted["tested"] and not tasted["ready"], "record tested, other draft not ready")
	# 같은 기록 여러 개도 한 번(불리언).
	var dup := _page(D.pages([rec, rec.duplicate(true), rec.duplicate(true)], other_draft, []), "bone_depth")
	check(dup["tested"] == true and typeof(dup["tested"]) == TYPE_BOOL, "duplicate records are not double counted")
	# 삭제: 기록이 없어지면 tested 도 사라진다.
	# 남는 기록은 매운 기름이지만 돼지뼈 진국이 아닌 구성(fire_oil 증인은 bone_depth 도 맞으므로 쓰지 않는다).
	var spicy_clear := _cfg("broth_chicken", "tare_shoyu", "oil_chili", "noodle_thin", ["topping_nori"], "cook_firm")
	check(D.matched_ids(spicy_clear).has("fire_oil") and not D.matched_ids(spicy_clear).has("bone_depth"), "fixture is fire_oil without bone_depth")
	var other_rec := {"record_id": "r2", "config": spicy_clear}
	var kept := D.pages([rec, other_rec], other_draft, [])
	var deleted := D.pages([other_rec], other_draft, [])
	check(_page(kept, "bone_depth")["tested"] and not _page(deleted, "bone_depth")["tested"], "deleting a record removes tested status")
	check(_page(deleted, "fire_oil")["tested"], "other records keep their themes")
	# 겹침: 같은 주제에 맞는 기록이 둘이면 하나를 지워도 시식함이 남는다.
	var second_bone := {"record_id": "r3", "config": _cfg("broth_tonkotsu", "tare_shoyu", "oil_chili", "noodle_thin", ["topping_chashu", "topping_egg"], "cook_normal")}
	check(D.matched_ids(second_bone["config"]).has("bone_depth"), "second fixture matches bone_depth")
	check(_page(D.pages([rec, second_bone], other_draft, []), "bone_depth")["tested"], "two matching records tested")
	check(_page(D.pages([second_bone], other_draft, []), "bone_depth")["tested"], "deleting one of two matching records keeps tested")
	check(_page(D.pages([rec], other_draft, []), "bone_depth")["tested"], "deleting the other matching record keeps tested too")
	# 가격/이름만 다른 기록은 같은 주제, 잘못된 기록/모양 틀린 기록은 무시.
	var junk: Array = [5, "x", {}, {"config": 3}, {"config": {"broth": "broth_unknown"}}, {"record_id": "z", "config": _witness("topping_stack")}]
	var junk_pages := D.pages(junk, other_draft, [])
	var tested_ids: Array = []
	for p in junk_pages:
		if p["tested"]:
			tested_ids.append(p["id"])
	check(tested_ids.has("topping_stack") and not tested_ids.has("bone_depth"), "malformed records are skipped")
	# 가격 높은 기록도 같은 연구 성과이며 가격만으로는 만들어지지 않는다.
	var dear_rec := {"config": _cfg("broth_chicken", "tare_shoyu", "oil_scallion", "noodle_medium", ["topping_egg"], "cook_normal", 30000)}
	check(not _page(D.pages([dear_rec], other_draft, []), "bone_depth")["tested"], "high price alone does not create success")
	# 가용성.
	var none := D.pages([], witness, [])
	check(str(_page(none, "clam_mushroom")["unavailable"]) == str(["broth_clam", "topping_mushroom"]), "undiscovered ids listed")
	check(str(_page(D.pages([], witness, ["broth_clam"]), "clam_mushroom")["unavailable"]) == str(["topping_mushroom"]), "only still-unavailable ids listed")
	check(_page(D.pages([], witness, ["broth_clam", "topping_mushroom"]), "clam_mushroom")["unavailable"].is_empty(), "all available")
	check(str(_page(none, "citrus_light")["unavailable"]) == str(["topping_citrus_peel"]), "farmed citrus unavailable until available")
	check(str(_page(none, "sesame_roast")["unavailable"]) == str(["oil_roasted_sesame"]), "farmed sesame unavailable until available")
	for id in ["bone_depth", "clear_light", "fire_oil", "noodle_chew", "topping_stack"]:
		check(_page(none, id)["unavailable"].is_empty(), "basic route never blocked: " + id)
	# 시작 재료 후보가 하나라도 있으면 발견 재료가 없어도 막히지 않는다(clear_light 의 조개).
	check(_page(none, "clear_light")["unavailable"].is_empty(), "alternative starter ingredient keeps route open")
	# 사용 가능해도 초안이 안 맞으면 missing 이 남고, 막힘과 별개다.
	var no_clam := _page(D.pages([], witness, ["broth_clam", "topping_mushroom"]), "clam_mushroom")
	check(no_clam["progress"] == 0 and (no_clam["missing"] as Array).size() == 2 and not no_clam["ready"], "available but unsatisfied draft keeps hints")
	# 페이지는 카탈로그의 필드를 그대로 이어받는다.
	for p in none:
		for key in ["id", "title", "hint", "origin", "criteria", "tested", "ready", "progress", "total", "missing", "unavailable"]:
			check((p as Dictionary).has(key), "page key %s" % key)
	check(none.size() == 8, "one page per theme")


func _test_invariance() -> void:
	var witness := _witness("sesame_roast")
	var records: Array = [{"record_id": "a", "config": _witness("bone_depth")}, {"record_id": "b", "config": witness}, 7]
	var draft := _witness("topping_stack")
	var available: Array[String] = ["broth_clam"]
	var before := JSON.stringify([records, draft, available, D.catalog()])
	D.pages(records, draft, available)
	D.matched_ids(witness)
	D.describe(draft)
	D.matched_ids({})
	D.describe({})
	check(JSON.stringify([records, draft, available, D.catalog()]) == before, "inputs and catalog are not mutated")
	check(str(D.pages(records, draft, available)) == str(D.pages(records, draft, available)), "pages are deterministic")


func _page(pages: Array, id: String) -> Dictionary:
	for p in pages:
		if (p as Dictionary)["id"] == id:
			return p
	return {}
