extends RefCounted
## Read-only view of one paid tasting against the chosen culinary goal. Only the
## actual retained record's config decides success; fresh titles merely choose
## between "달성" and "충족" wording once the goal is really met. Nothing is saved,
## credited or unlocked here.

const Directions = preload("res://scripts/domain/recipe_directions.gd")
const Check = preload("res://scripts/domain/data_check.gd")

const UNAVAILABLE := "unavailable"
const NO_GOAL := "no_goal"
const ERROR := "error"
const MET := "met"
const UNMET := "unmet"


## Keys: status (unavailable|no_goal|error|met|unmet), error, selected_id, title,
## badge ("" unless met/unmet), celebrate (true only for met), fresh (new match),
## selected (selected assessment copy or {}), matches (every matching direction,
## selected first, then catalog order: {id, title, selected, assessment}).
## fresh_titles is the title list main supplies for this same feedback record.
static func project(record: Dictionary, selected_id: String, fresh_titles: Array = []) -> Dictionary:
	var result := {"status": UNAVAILABLE, "error": "", "selected_id": selected_id, "title": "",
		"badge": "", "celebrate": false, "fresh": false, "selected": {}, "matches": []}
	if record.is_empty():
		return result
	var definition: Dictionary = {}
	if selected_id != "":
		definition = Directions.find(selected_id)
		if definition.is_empty():
			return _fail(result, "알려진 실험 목표가 아니에요.")
	var config = record.get("config")
	if not config is Dictionary or Check.config_error(config) != "":
		return _fail(result, "시식 기록의 재료 구성을 확인할 수 없어요.")
	var matches: Array = []
	for item in Directions.catalog():
		var id: String = str(item["id"])
		var assessment: Dictionary = Directions.assess(id, config)
		if assessment["error"] != "":
			return _fail(result, str(assessment["error"]))
		if not bool(assessment["matched"]):
			continue
		var entry := {"id": id, "title": str(item["title"]), "selected": id == selected_id, "assessment": assessment}
		if id == selected_id:
			matches.push_front(entry)
		else:
			matches.append(entry)
	result["matches"] = matches
	if selected_id == "":
		result["status"] = NO_GOAL
		return result
	var title: String = str(definition["title"])
	var selected: Dictionary = Directions.assess(selected_id, config)
	var met: bool = bool(selected["matched"])
	result["title"] = title
	result["selected"] = selected
	result["status"] = MET if met else UNMET
	result["celebrate"] = met
	result["fresh"] = met and fresh_titles.has(title)
	if not met:
		result["badge"] = title + " · 더 실험"
	elif bool(result["fresh"]):
		result["badge"] = title + " · 목표 달성"
	else:
		result["badge"] = title + " · 목표 충족"
	return result.duplicate(true)


static func _fail(result: Dictionary, message: String) -> Dictionary:
	result["status"] = ERROR
	result["error"] = message
	result["matches"] = []
	return result
