extends RefCounted
## Counterfactual clues, not recipe transactions or a score optimizer. Each
## candidate changes one choice of an actually tasted recipe; evaluator values
## are reused verbatim. The caller owns real stock/busy checks and navigation.

const Catalog = preload("res://scripts/domain/ingredient_catalog.gd")
const Check = preload("res://scripts/domain/data_check.gd")
const Evaluator = preload("res://scripts/domain/recipe_evaluator.gd")
const ProcessRules = preload("res://scripts/domain/recipe_process.gd")


static func clues(config: Dictionary, available: Array[String], rank: int) -> Dictionary:
	var err: String = Check.config_error(config)
	if err != "":
		return {"error": err, "clues": []}
	if rank < 1 or rank > 3:
		return {"error": "실험 단서의 가게 등급이 올바르지 않아요.", "clues": []}
	var base: Dictionary = config.duplicate(true)
	base.erase("topping")
	base["toppings"] = Catalog.canonical_toppings(Catalog.toppings_of(config))
	var candidates: Array = []
	for slot in Catalog.SLOTS:
		for item in Catalog.all_items(slot):
			var id: String = str(item["id"])
			if not available.has(id):
				continue
			if slot == Catalog.TOPPING_SLOT:
				for i in (base["toppings"] as Array).size():
					if base["toppings"][i] == id:
						continue
					var next: Dictionary = base.duplicate(true)
					next["toppings"][i] = id
					_add(candidates, base, next, slot, "%s 1분량 → %s" % [Catalog.find(str(base["toppings"][i]))["name"], item["name"]])
			elif str(base[slot]) != id:
				var next: Dictionary = base.duplicate(true)
				next[slot] = id
				_add(candidates, base, next, slot, "%s → %s" % [Catalog.find(str(base[slot]))["name"], item["name"]])
	for slot in ProcessRules.SLOTS:
		var process: Dictionary = base.get("process", {})
		for id in ProcessRules.ids(slot):
			var method: Dictionary = ProcessRules.method(slot, id)
			if int(method["rank"]) > rank or ProcessRules.selected(process, slot) == id:
				continue
			var next: Dictionary = base.duplicate(true)
			next["process"] = {"broth": ProcessRules.selected(process, "broth"), "noodle": ProcessRules.selected(process, "noodle")}
			next["process"][slot] = id
			_add(candidates, base, next, slot, "%s → %s" % [ProcessRules.method(slot, ProcessRules.selected(process, slot))["name"], method["name"]])
	var picked: Array = []
	var used: Dictionary = {}
	# Different directions expose tradeoffs. No score/ranking over customers and
	# no claim that a faster or more aromatic dish is better for every purpose.
	for direction in ["aroma", "chew", "speed"]:
		var best: Dictionary = {}
		var gain: int = 0
		for candidate in candidates:
			var key: String = JSON.stringify(candidate["config"])
			var value: int = -int(candidate["seconds_delta"]) if direction == "speed" else int(candidate["axis_delta"][direction])
			if not used.has(key) and value > gain:
				gain = value
				best = candidate
		if not best.is_empty():
			var clue: Dictionary = best.duplicate(true)
			clue["direction"] = direction
			clue["title"] = {"aroma": "향을 살리는 실험", "chew": "씹는 맛의 실험", "speed": "더 빠른 한 그릇"}[direction]
			picked.append(clue)
			used[JSON.stringify(best["config"])] = true
	return {"error": "", "clues": picked}


static func _add(out: Array, base: Dictionary, next: Dictionary, slot: String, change: String) -> void:
	var before: Dictionary = Evaluator.build_profile(base)
	var after: Dictionary = Evaluator.build_profile(next)
	var delta: Dictionary = {}
	var words: Array[String] = []
	for axis in Catalog.AXES:
		delta[axis] = int(after[axis]) - int(before[axis])
		if delta[axis] != 0:
			words.append("%s %+d" % [Catalog.AXIS_NAMES[axis], delta[axis]])
	out.append({"config": next, "slot": slot, "change": change, "axis_delta": delta,
		"flavor_text": " · ".join(words) if not words.is_empty() else "맛 축 변화 없음",
		"cost_delta": Evaluator.unit_cost(next) - Evaluator.unit_cost(base),
		"seconds_delta": Evaluator.prep_seconds(next) - Evaluator.prep_seconds(base)})
