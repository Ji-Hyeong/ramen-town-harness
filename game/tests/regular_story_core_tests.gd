extends SceneTree
## 순수 카탈로그의 모든 분기 경계와 잘못된 지표를 검증한다. 실제 재료 증인은 통합 시험에서 별도 계산한다.
const C = preload("res://scripts/domain/regular_story_catalog.gd")
var checks: int = 0
var failures: int = 0
func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: " + label)
func _initialize() -> void:
	var endings: Dictionary = {}
	for customer in C.ids():
		var story: Dictionary = C.story(customer)
		check(not str(story["opening"]).is_empty() and story["routes"].size() == 2, "세 단골의 시작과 두 선택")
		for route in story["routes"]:
			check(not endings.has(route["ending"]) and str(route["ending"]).length() > 25, "각 분기의 독자적인 결말")
			endings[route["ending"]] = true
			for index in 2:
				var def: Dictionary = C.chapter(customer, route["id"], index)
				check(str(def["dialogue"]).length() > 20 and str(def["success"]).length() > 20, "연결된 요청/완료 대사")
				var metrics: Dictionary = {"score":100,"price":7000,"prep":1,"cost":1,"profile":{"rich":9,"salt":4,"aroma":9,"chew":6,"spice":5}}
				if route["id"] == "light":
					metrics["profile"]["rich"] = 3
				check(C.assess(customer,route["id"],index,metrics)["all_met"], "모든12단계 유효 지표")
				for key in def["requirements"]:
					var edge: Dictionary = metrics.duplicate(true)
					var base: String = str(key).trim_suffix("_min").trim_suffix("_max")
					var target: Dictionary = edge if edge.has(base) else edge["profile"]
					target[base] = def["requirements"][key]
					check(C.assess(customer,route["id"],index,edge)["all_met"], "경계 포함")
					target[base] += -1 if str(key).ends_with("_min") else 1
					check(not C.assess(customer,route["id"],index,edge)["all_met"], "경계 바로 밖 거부")
				for bad in [true, 1.0, null, "1", -1, 1000000001]:
					var invalid: Dictionary = metrics.duplicate(true)
					invalid["score"] = bad
					check(C.assess(customer,route["id"],index,invalid)["error"] != "", "잘못된 점수 형식")
				var missing: Dictionary = metrics.duplicate(true)
				missing["profile"].erase("spice")
				check(C.assess(customer,route["id"],index,missing)["error"] != "", "누락된 축")
				missing = metrics.duplicate(true)
				missing["extra"] = 0
				check(C.assess(customer,route["id"],index,missing)["error"] != "", "예상치 못한 지표 키")
		story["routes"][0]["chapters"][0]["title"] = "변조"
		check(C.story(customer)["routes"][0]["chapters"][0]["title"] != "변조", "카탈로그 깊은 복사")
	check(C.route("unknown","unknown").is_empty() and C.chapter("dohyun","hearty",2).is_empty(), "미지/초과 단계 거부")
	print("regular_story_core checks=%d failures=%d" % [checks,failures])
	quit(0 if failures == 0 else 1)
