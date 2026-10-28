extends RefCounted
## Pure projection tests using the real direction witnesses and evaluator.
const Focus = preload("res://scripts/ui/tasting_goal_focus.gd")
const Directions = preload("res://scripts/domain/recipe_directions.gd")
const Catalog = preload("res://scripts/domain/ingredient_catalog.gd")
const Witness = preload("res://tests/recipe_directions_tests.gd")


func _record(id: String, variant: int = 0) -> Dictionary:
	return {"record_id": 1, "config": Witness.witness(id, variant)}


func run(callback: Callable) -> void:
	for id in ["citrus_scallop", "sesame_buckwheat", "sardine_shiitake"]:
		var title: String = Directions.find(id)["title"]
		for variant in 2:
			var record: Dictionary = _record(id, variant)
			var fresh: Dictionary = Focus.project(record, id, [title])
			callback.call(fresh["status"] == Focus.MET and fresh["fresh"] and fresh["celebrate"], id + ": actual match is met")
			callback.call(fresh["badge"] == title + " · 목표 달성", id + ": fresh badge")
			callback.call(fresh["selected"]["matched"] and fresh["matches"][0]["id"] == id and fresh["matches"][0]["selected"], id + ": selected assessment and first")
			var kept: Dictionary = Focus.project(record, id, [])
			callback.call(kept["badge"] == title + " · 목표 충족" and not kept["fresh"], id + ": retained badge")
			var other: Dictionary = Focus.project(record, id, ["다른 제목"])
			callback.call(other["badge"] == title + " · 목표 충족", id + ": unrelated fresh title is ignored")

	# One recipe satisfying two directions: the chosen one leads, not the catalog-first.
	var citrus: Dictionary = _record("citrus_scallop")
	var older: Dictionary = Focus.project(citrus, "citrus_scallop", [])
	var older_ids: Array = []
	for entry in older["matches"]:
		older_ids.append(entry["id"])
	callback.call(older_ids.size() >= 2 and older_ids[0] == "citrus_scallop", "selected leads among multiple matches")
	var generic: Dictionary = Focus.project(citrus, "", [])
	callback.call(generic["status"] == Focus.NO_GOAL and generic["badge"] == "" and generic["matches"].size() == older_ids.size(), "no goal keeps generic matches without a badge")
	var flipped: Array = []
	for entry in generic["matches"]:
		flipped.append(entry["id"])
	callback.call(flipped.size() >= 2 and flipped[0] != "citrus_scallop", "catalog order retained without selection")
	var sesame: Dictionary = _record("sesame_buckwheat")
	var sesame_ids: Array = []
	for entry in Focus.project(sesame, "sesame_buckwheat", [])["matches"]:
		sesame_ids.append(entry["id"])
	callback.call(sesame_ids.size() >= 2 and sesame_ids[0] == "sesame_buckwheat", "sesame buckwheat also leads")

	# Unmet selected goal, even though another direction matches and a fake fresh title is supplied.
	var unmet: Dictionary = Focus.project(citrus, "sesame_buckwheat", ["참깨 메밀 진국"])
	callback.call(unmet["status"] == Focus.UNMET and not unmet["celebrate"] and not unmet["fresh"], "unmet is neutral despite fake fresh title")
	callback.call(unmet["badge"] == "참깨 메밀 진국 · 더 실험", "unmet badge")
	callback.call(not unmet["selected"]["matched"] and unmet["selected"]["checks"].size() > 0, "unmet exposes actual checks")
	callback.call(unmet["matches"].size() >= 2 and not unmet["matches"][0]["selected"], "other achieved directions remain visible")
	var unrelated: Dictionary = Focus.project(_record("harbor_sea"), "citrus_scallop", ["유자 가리비탕"])
	callback.call(unrelated["status"] == Focus.UNMET, "an older matching record elsewhere does not matter")

	# Empty and invalid input.
	callback.call(Focus.project({}, "citrus_scallop", [])["status"] == Focus.UNAVAILABLE, "empty record unavailable")
	callback.call(Focus.project({}, "", [])["status"] == Focus.UNAVAILABLE, "empty record and goal unavailable")
	var bad_id: Dictionary = Focus.project(citrus, "not_a_goal", ["x"])
	callback.call(bad_id["status"] == Focus.ERROR and bad_id["error"] != "" and bad_id["badge"] == "" and bad_id["matches"].is_empty(), "unknown id explicit error")
	var broken: Dictionary = Focus.project({"record_id": 2, "config": {"broth": "nope"}}, "citrus_scallop", [])
	callback.call(broken["status"] == Focus.ERROR and broken["error"] != "" and not broken["celebrate"], "malformed config explicit error")
	callback.call(Focus.project({"record_id": 2}, "", [])["status"] == Focus.ERROR, "missing config explicit error")
	callback.call(Focus.project({"record_id": 2, "config": "text"}, "citrus_scallop", [])["status"] == Focus.ERROR, "non-dictionary config explicit error")

	# Copies and immutability.
	var record: Dictionary = _record("citrus_scallop")
	var record_json: String = JSON.stringify(record)
	var fresh_titles: Array = ["유자 가리비탕"]
	var catalog_json: String = JSON.stringify(Directions.catalog())
	var view: Dictionary = Focus.project(record, "citrus_scallop", fresh_titles)
	view["selected"]["checks"].clear()
	view["matches"][0]["assessment"]["profile"]["rich"] = 99
	view["matches"].clear()
	record["config"]["toppings"].append("topping_nori")
	var again: Dictionary = Focus.project(_record("citrus_scallop"), "citrus_scallop", fresh_titles)
	callback.call(again["selected"]["checks"].size() > 0 and again["matches"].size() > 0 and again["matches"][0]["assessment"]["profile"]["rich"] != 99, "returned copies are independent")
	var untouched: Dictionary = _record("citrus_scallop")
	var before: String = JSON.stringify(untouched)
	Focus.project(untouched, "citrus_scallop", fresh_titles)
	callback.call(JSON.stringify(untouched) == before and JSON.stringify(fresh_titles) == '["유자 가리비탕"]', "inputs are not mutated")
	callback.call(record_json != "" and JSON.stringify(Directions.catalog()) == catalog_json, "catalog is not mutated")
