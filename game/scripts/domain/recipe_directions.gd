extends RefCounted
## Ingredient-led experiments, projected from real recipes. These are
## open constraints, never saved recipes, permanent unlocks or score bonuses.
## Retained paid tasting records alone witness completion; deleting a witness
## can remove that status, just as it does in the existing research map.

const Catalog = preload("res://scripts/domain/ingredient_catalog.gd")
const Check = preload("res://scripts/domain/data_check.gd")
const Evaluator = preload("res://scripts/domain/recipe_evaluator.gd")

const DATA: Array = [
	{"id": "citrus_clear", "title": "유자 맑은탕", "ingredient": "topping_citrus_peel", "slot": "topping",
		"brief": "유자 향은 선명하게, 국물은 가볍게. 빠른 점심 메뉴를 실험해 보세요.",
		"source": "새벽 장터 · 유자 수레", "requires": ["topping_citrus_peel"],
		"limits": [{"axis": "rich", "max": 5}, {"axis": "aroma", "min": 6}]},
	{"id": "sesame_depth", "title": "참깨 진국", "ingredient": "oil_roasted_sesame", "slot": "oil",
		"brief": "볶은 참깨 향에 묵직한 국물. 원가와 준비 시간도 함께 살펴보세요.",
		"source": "새벽 장터 · 볶음 양념 노점", "requires": ["oil_roasted_sesame"],
		"limits": [{"axis": "rich", "min": 8}, {"axis": "aroma", "min": 6}]},
	{"id": "harbor_sea", "title": "정어리 가리비탕", "ingredient": "broth_roasted_sardine", "slot": "broth",
		"brief": "정어리 육수에 가리비를 더해 바다의 맛을. 타레로 짠맛을 다듬어 보세요.",
		"source": "아침 항구 · 어획물 채집", "requires": ["broth_roasted_sardine", "topping_scallop"],
		"limits": [{"axis": "salt", "max": 7}]},
	{"id":"mountain_clear","title":"산향 메밀탕","ingredient":"noodle_buckwheat","slot":"noodle",
		"brief":"산메밀의 향을 가벼운 국물에. 익힘과 반죽으로 식감을 다듬어 보세요.",
		"source":"산골 농가 · 제분소","requires":["noodle_buckwheat"],
		"limits":[{"axis":"rich","max":5},{"axis":"aroma","min":6},{"axis":"chew","min":6}]},
	{"id":"shiitake_depth","title":"산표고 진국","ingredient":"topping_grilled_shiitake","slot":"topping",
		"brief":"직화 산표고의 향과 진한 국물의 균형. 고명을 겹치면 시간과 원가도 늘어요.",
		"source":"산골 농가 · 산표고 화덕","requires":["topping_grilled_shiitake"],
		"limits":[{"axis":"rich","min":7},{"axis":"aroma","min":7}]},
]


## Definitions are copied so a UI cannot accidentally edit future experiments.
static func catalog() -> Array:
	return DATA.duplicate(true)


static func find(id: String) -> Dictionary:
	for item in DATA:
		if item["id"] == id:
			return item.duplicate(true)
	return {}


## Reuse the evaluator, including cooking method effects and saturation. No
## inferred customer score or guaranteed sales effect is added to these facts.
static func assess(id: String, config: Dictionary) -> Dictionary:
	var definition: Dictionary = find(id)
	var err: String = Check.config_error(config)
	if definition.is_empty() or err != "":
		return {"error": "알려진 실험 방향과 올바른 재료 구성이 필요해요." if err == "" else err, "matched": false, "checks": []}
	var selected: Array[String] = Catalog.toppings_of(config)
	for slot in Catalog.SLOTS:
		if slot != Catalog.TOPPING_SLOT:
			selected.append(str(config[slot]))
	var checks: Array = []
	for ingredient in definition["requires"]:
		checks.append({"text": str(Catalog.find(ingredient)["name"]), "met": selected.has(ingredient)})
	var profile: Dictionary = Evaluator.build_profile(config)
	for limit in definition["limits"]:
		var minimum: bool = limit.has("min")
		var threshold: int = int(limit["min"] if minimum else limit["max"])
		var value: int = int(profile[limit["axis"]])
		checks.append({"text": "%s %d %s · 지금 %d" % [Catalog.AXIS_NAMES[limit["axis"]], threshold, "이상" if minimum else "이하", value], "met": value >= threshold if minimum else value <= threshold})
	var met: bool = true
	for item in checks:
		met = met and bool(item["met"])
	return {"error": "", "matched": met, "checks": checks, "profile": profile,
		"cost": Evaluator.unit_cost(config), "seconds": Evaluator.prep_seconds(config)}


## A view over immutable notebook witnesses, not a second collection ledger.
static func tested_ids(records: Array) -> Array[String]:
	var ids: Array[String] = []
	for definition in DATA:
		for record in records:
			if bool(assess(str(definition["id"]), record["config"])["matched"]):
				ids.append(str(definition["id"]))
				break
	return ids
