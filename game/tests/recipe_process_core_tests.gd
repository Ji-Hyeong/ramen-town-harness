extends SceneTree
## 공법 카탈로그 focused 시험. 기존 게임 파일은 읽지 않고 helper만 preload한다.

const P := preload("res://scripts/domain/recipe_process.gd")

var checks := 0
var failures := 0


func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: ", label)


func _init() -> void:
	_test_catalog()
	_test_combos()
	_test_errors()
	_test_copies()
	print("recipe_process_core checks=%d failures=%d" % [checks, failures])
	quit(0 if failures == 0 else 1)


func _test_catalog() -> void:
	check(P.SLOTS == ["broth", "noodle"], "slots")
	check(P.AXES == ["rich", "salt", "aroma", "chew", "spice"], "axes")
	check(P.ids("broth") == ["standard", "gentle", "rolling"], "broth ids")
	check(P.ids("noodle") == ["standard", "moist", "rested"], "noodle ids")
	check(P.ids("x").is_empty(), "unknown slot ids")
	check(P.method("broth", "moist").is_empty() and P.method("x", "standard").is_empty(), "unknown method")
	var keys := P.method("broth", "gentle").keys()
	keys.sort()
	check(keys == ["axes", "cost", "desc", "id", "name", "rank", "seconds", "work_extra"], "method keys")
	for slot in P.SLOTS:
		for id in P.ids(slot):
			var m := P.method(slot, id)
			check(m["id"] == id and not String(m["name"]).is_empty() and not String(m["desc"]).is_empty(), "meta %s/%s" % [slot, id])
			check(m["axes"].size() == 5 and typeof(m["axes"]["rich"]) == TYPE_INT, "axes int %s/%s" % [slot, id])
	# 기본 공법은 효과 0, 이름은 고정.
	check(P.method("broth", "standard")["name"] == "기본 우림" and P.method("noodle", "standard")["name"] == "기본 반죽", "standard names")
	var e := P.effects()
	check(e["error"] == "" and e["cost"] == 0 and e["seconds"] == 0 and e["rank"] == 1 and e["work_seconds"] == 4.0, "default effects")
	for a in P.AXES:
		check(e["axes"][a] == 0, "default axis " + a)


func _test_combos() -> void:
	# [broth, noodle, rich, aroma, chew, cost, seconds, work, rank] — salt/spice는 항상 0.
	var rows := [
		["standard", "standard", 0, 0, 0, 0, 0, 4.0, 1],
		["standard", "moist", 0, 0, -2, 80, -8, 4.5, 1],
		["standard", "rested", 0, -1, 2, 140, 10, 6.0, 2],
		["gentle", "standard", -1, 2, 0, 180, 8, 5.0, 1],
		["gentle", "moist", -1, 2, -2, 260, 0, 5.5, 1],
		["gentle", "rested", -1, 1, 2, 320, 18, 7.0, 2],
		["rolling", "standard", 2, -1, 0, 300, 12, 5.5, 2],
		["rolling", "moist", 2, -1, -2, 380, 4, 6.0, 2],
		["rolling", "rested", 2, -2, 2, 440, 22, 7.5, 2],
	]
	for r in rows:
		var raw := {"noodle": r[1], "broth": r[0]} # 키 순서 무관
		var e := P.effects(raw)
		var tag := "%s+%s" % [r[0], r[1]]
		check(e["error"] == "", "ok " + tag)
		var ax: Dictionary = e["axes"]
		check(ax["rich"] == r[2] and ax["aroma"] == r[3] and ax["chew"] == r[4] and ax["salt"] == 0 and ax["spice"] == 0, "axes " + tag)
		check(e["cost"] == r[5] and e["seconds"] == r[6] and e["rank"] == r[8], "cost/sec/rank " + tag)
		check(is_equal_approx(e["work_seconds"], r[7]) and e["work_seconds"] >= 4.0 and e["work_seconds"] <= 7.5, "work " + tag)
		check(e == P.effects({"broth": r[0], "noodle": r[1]}), "order deterministic " + tag)
	check(P.summary({"broth": "gentle", "noodle": "rested"}) == "약불 우림 · 저가수 숙성", "summary")
	check(P.summary() == "기본 우림 · 기본 반죽", "summary default")
	check(P.selected({}, "noodle") == "standard" and P.selected({"broth": "rolling", "noodle": "moist"}, "broth") == "rolling", "selected")
	check(P.selected({}, "x") == "" and P.selected({"broth": "bad", "noodle": "moist"}, "broth") == "", "selected invalid")
	# 두 축 장단점: 약불은 향↑ 진함↓, 강불은 진함↑ 향↓, 고가수는 식감↓, 저가수는 식감↑ 향↓.
	check(P.method("broth", "gentle")["axes"]["aroma"] > 0 and P.method("broth", "gentle")["axes"]["rich"] < 0, "gentle tradeoff")
	check(P.method("broth", "rolling")["axes"]["rich"] > 0 and P.method("broth", "rolling")["axes"]["aroma"] < 0, "rolling tradeoff")
	check(P.method("noodle", "rested")["axes"]["chew"] > 0 and P.method("noodle", "rested")["axes"]["aroma"] < 0, "rested tradeoff")


func _test_errors() -> void:
	check(P.error({}) == "" and P.error({"broth": "standard", "noodle": "rested"}) == "", "valid")
	var bad: Array = [
		{"broth": "standard"}, {"noodle": "standard"},
		{"broth": "standard", "noodle": "standard", "extra": "x"},
		{"broth": "", "noodle": "standard"}, {"broth": "standard", "noodle": "gentle"},
		{"broth": "moist", "noodle": "standard"}, {"broth": 1, "noodle": "standard"},
		{"broth": true, "noodle": "standard"}, {"broth": null, "noodle": "standard"},
		{"broth": ["standard"], "noodle": "standard"}, {"broth": &"standard", "noodle": "standard"},
		{"broth": "standard", "other": "standard"}, null, 1, "standard", [], true,
	]
	for i in bad.size():
		check(P.error(bad[i]) != "", "bad error %d" % i)
		var e := P.effects(bad[i])
		check(e.size() == 1 and e.has("error") and e["error"] != "", "bad effects %d" % i)
	check(P.summary({"broth": "x", "noodle": "standard"}) == P.error({"broth": "x", "noodle": "standard"}), "summary error")


func _test_copies() -> void:
	var m := P.method("broth", "gentle")
	m["axes"]["rich"] = 99
	m["cost"] = 1
	check(P.method("broth", "gentle")["axes"]["rich"] == -1 and P.method("broth", "gentle")["cost"] == 180, "method copy")
	var ids := P.ids("broth")
	ids.append("x")
	check(P.ids("broth").size() == 3, "ids copy")
	var raw := {"broth": "rolling", "noodle": "rested"}
	var e := P.effects(raw)
	e["axes"]["rich"] = 99
	e["cost"] = 0
	check(P.effects(raw)["axes"]["rich"] == 2 and P.effects(raw)["cost"] == 440, "effects copy")
	check(raw == {"broth": "rolling", "noodle": "rested"}, "input unchanged")
