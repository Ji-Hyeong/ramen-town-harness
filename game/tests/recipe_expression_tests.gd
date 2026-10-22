extends SceneTree
## Independent facts and pixel regression fixtures. Reading proposals must not
## mutate input or perform a paid tasting. This script never uses live saves.

const Experiments = preload("res://scripts/domain/recipe_experiments.gd")
const Catalog = preload("res://scripts/domain/ingredient_catalog.gd")
const Evaluator = preload("res://scripts/domain/recipe_evaluator.gd")
const ProcessRules = preload("res://scripts/domain/recipe_process.gd")
const Art = preload("res://scripts/ui/pixel_art.gd")

var checks: int = 0
var failures: int = 0


func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: " + label)


func _init() -> void:
	var available: Array[String] = []
	for slot in Catalog.SLOTS:
		for item in Catalog.all_items(slot): available.append(str(item["id"]))
	var baseline: Script
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--baseline-art="):
			baseline = load(arg.trim_prefix("--baseline-art="))
	var fixtures: Array = [Catalog.default_config()]
	# Cover each ingredient, repeat/mixed portions, every process and cook state.
	for slot in Catalog.SLOTS:
		for item in Catalog.all_items(slot):
			var c: Dictionary = Catalog.default_config()
			if slot == Catalog.TOPPING_SLOT: c["toppings"] = [item["id"]]
			else: c[slot] = item["id"]
			fixtures.append(c)
	for count in range(2, 5):
		var c: Dictionary = Catalog.default_config()
		c["toppings"] = []
		for i in count: c["toppings"].append("topping_chashu")
		fixtures.append(c)
	for broth in ProcessRules.ids("broth"):
		for noodle in ProcessRules.ids("noodle"):
			var c: Dictionary = Catalog.default_config()
			c["process"] = {"broth": broth, "noodle": noodle}
			fixtures.append(c)
	var base_pixels: PackedByteArray = Art.recipe_bowl_image(Catalog.default_config()).get_data()
	for i in fixtures.size():
		var cfg: Dictionary = fixtures[i]
		var original: String = JSON.stringify(cfg)
		var result: Dictionary = Experiments.clues(cfg, available, 3)
		check(result["error"] == "" and result["clues"].size() <= 3, "bounded valid alternatives")
		check(JSON.stringify(result) == JSON.stringify(Experiments.clues(cfg, available, 3)), "deterministic clues")
		var used: Dictionary = {}
		for clue in result["clues"]:
			var next: Dictionary = clue["config"]
			var key: String = JSON.stringify(next)
			check(not used.has(key), "distinct directions never duplicate a recipe")
			used[key] = true
			check(_edits(cfg, next) == 1, "exactly one choice changes")
			check(next["price"] == cfg["price"] and Catalog.toppings_of(cfg).size() == Catalog.toppings_of(next).size(), "no price or capacity trick")
			for axis in Catalog.AXES:
				check(clue["axis_delta"][axis] == Evaluator.build_profile(next)[axis] - Evaluator.build_profile(cfg)[axis], "actual evaluator delta " + axis)
			check(clue["cost_delta"] == Evaluator.unit_cost(next) - Evaluator.unit_cost(cfg), "actual cost")
			check(clue["seconds_delta"] == Evaluator.prep_seconds(next) - Evaluator.prep_seconds(cfg), "actual cooking time")
			check(Art.recipe_bowl_image(next).get_data() != Art.recipe_bowl_image(cfg).get_data(), "proposed change visibly distinguishes dish")
		var art: Image = Art.recipe_bowl_image(cfg)
		check(art.get_size() == Vector2i(48, 32), "detailed dish size")
		if i > 0 and _edits(Catalog.default_config(), cfg) > 0:
			check(base_pixels != art.get_data(), "ingredient/process/portion changes visible")
		var price_only: Dictionary = cfg.duplicate(true)
		price_only["price"] += 100
		check(Art.recipe_bowl_image(price_only).get_data() == art.get_data(), "price cannot recolor dish")
		var with_price: Array = Experiments.clues(price_only, available, 3)["clues"]
		check(with_price.size() == result["clues"].size(), "price cannot create another experiment")
		for j in with_price.size():
			check(with_price[j]["change"] == result["clues"][j]["change"], "price cannot pick another route")
		if baseline != null:
			check(baseline.bowl_image(cfg).get_data() == Art.bowl_image(cfg).get_data(), "shop sprite byte-identical to accepted main")
		check(JSON.stringify(cfg) == original, "all readers preserve input")
	var reversed: Dictionary = Catalog.default_config()
	reversed["toppings"] = ["topping_egg", "topping_chashu", "topping_chashu"]
	var ordered: Dictionary = reversed.duplicate(true)
	ordered["toppings"].reverse()
	check(Art.recipe_bowl_image(reversed).get_data() == Art.recipe_bowl_image(ordered).get_data(), "portion order does not invent an appearance")
	check(Experiments.clues(reversed, available, 3) == Experiments.clues(ordered, available, 3), "portion order does not invent clues")
	var low: Array = Experiments.clues(Catalog.default_config(), available, 1)["clues"]
	for clue in low:
		check(ProcessRules.effects(clue["config"].get("process", {}))["rank"] <= 1, "rank-gated processes excluded")
	var none: Array[String] = []
	for clue in Experiments.clues(Catalog.default_config(), none, 1)["clues"]:
		check(clue["config"].get("process", {}) != {}, "unavailable ingredient never proposed")
	check(Experiments.clues({}, available, 1)["error"] != "", "invalid config explicit error")
	check(Experiments.clues(Catalog.default_config(), available, 0)["error"] != "", "invalid rank explicit error")
	var exhausted: Dictionary = Catalog.default_config()
	exhausted["noodle"] = "noodle_thick"
	exhausted["cook"] = "cook_firm"
	exhausted["toppings"] = ["topping_sprouts", "topping_sprouts", "topping_sprouts", "topping_sprouts"]
	exhausted["process"] = {"broth": "standard", "noodle": "moist"}
	# Aroma is saturated, but the real evaluator still allows a texture/time
	# tradeoff. The first fixture incorrectly assumed sprouts added noodle chew.
	for clue in Experiments.clues(exhausted, none, 3)["clues"]:
		check(clue["direction"] != "aroma", "saturated aroma never fabricates another aroma gain")
		check(clue["direction"] == "chew" and clue["axis_delta"]["chew"] == 3 and clue["seconds_delta"] == 18, "retain genuine texture tradeoff instead of forcing empty advice")
	var legacy: Dictionary = Catalog.default_config()
	legacy["topping"] = legacy["toppings"][0]
	legacy.erase("toppings")
	check(Experiments.clues(legacy, available, 1) == Experiments.clues(Catalog.default_config(), available, 1), "legacy representation gives the same experiment")
	print("recipe_expression checks=%d failures=%d baseline=%s" % [checks, failures, baseline != null])
	quit(0 if failures == 0 else 1)


func _edits(a: Dictionary, b: Dictionary) -> int:
	var count: int = 0
	for slot in Catalog.SLOTS:
		if slot != Catalog.TOPPING_SLOT and a.get(slot) != b.get(slot): count += 1
	var old: Array = Catalog.toppings_of(a)
	var next: Array = Catalog.toppings_of(b)
	var matched: Array = next.duplicate()
	for id in old:
		if matched.has(id): matched.erase(id)
		else: count += 1
	count += maxi(0, next.size() - old.size())
	for slot in ProcessRules.SLOTS:
		if ProcessRules.selected(a.get("process", {}), slot) != ProcessRules.selected(b.get("process", {}), slot): count += 1
	return count
