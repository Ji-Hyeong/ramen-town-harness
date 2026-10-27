extends SceneTree
## Isolated presentation facts: pure profile, actual-source differences, legacy
## material parameters and repeated portion preservation. No live saves, no game
## state. Color distances prove parameters differ, NOT readability at phone size;
## native captures decide that.

const Appearance = preload("res://scripts/ui/recipe_appearance.gd")
const View = preload("res://scripts/ui/layered_recipe_view.gd")
const Catalog = preload("res://scripts/domain/ingredient_catalog.gd")

var checks: int = 0
var failures: int = 0


func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: " + label)


func _cfg(ingredients: Array, method: String = "standard", extra: Dictionary = {}) -> Dictionary:
	var c: Dictionary = Catalog.default_config()
	c["broth_recipe"] = {"ingredients": ingredients, "method": method}
	for key in extra: c[key] = extra[key]
	return c


func _noodle(flour: String, water: String, cut: String, method: String = "standard", extra: Dictionary = {}) -> Dictionary:
	var c: Dictionary = Catalog.default_config()
	c["noodle_recipe"] = {"flour": flour, "water": water, "cut": cut, "method": method}
	for key in extra: c[key] = extra[key]
	return c


func _dist(a: Color, b: Color) -> float:
	return absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b)


func _init() -> void:
	# Defer so the SceneTree root exists and nodes get _ready before assertions.
	_run.call_deferred()


func _run() -> void:
	await process_frame
	_profile_facts()
	_invalid_inputs()
	_view_facts()
	print("recipe_appearance_tests: %d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)


func _profile_facts() -> void:
	var legacy: Dictionary = Catalog.default_config()
	var legacy_look: Dictionary = Appearance.profile(legacy)
	check(legacy_look["error"] == "" and not legacy_look["crafted"] and not legacy_look["noodle_crafted"], "legacy config is inert and valid")

	var seafood: Dictionary = _cfg(["kelp", "clam"])
	var before: String = JSON.stringify(seafood)
	var first: Dictionary = Appearance.profile(seafood)
	check(first["error"] == "" and first["crafted"], "valid raw broth is crafted with empty error")
	check(JSON.stringify(first) == JSON.stringify(Appearance.profile(seafood)), "deterministic")
	check(JSON.stringify(seafood) == before, "input is not mutated")

	var kelp: Color = Appearance.profile(_cfg(["kelp"]))["broth_color"]
	var chicken: Color = Appearance.profile(_cfg(["chicken_bone"]))["broth_color"]
	var bone: Color = Appearance.profile(_cfg(["pork_bone"]))["broth_color"]
	var chili: Dictionary = Appearance.profile(_cfg(["chicken_bone"], "standard", {"oil": "oil_chili", "tare": "tare_shoyu"}))
	var herb: Dictionary = Appearance.profile(_cfg(["kelp", "ginger"], "standard", {"oil": "oil_scallion"}))
	var colors: Array = [kelp, chicken, bone, chili["broth_color"], herb["broth_color"]]
	for i in colors.size():
		for j in range(i + 1, colors.size()):
			# Kelp with scallion oil keeps a similar broth body. Its real surface
			# oil is green, so a base-color-only distance would reject that identity.
			var surface: bool=i==0 and j==4 and _dist(herb["oil_color"],Appearance.profile(_cfg(["kelp"]))["oil_color"])>0.3
			check(_dist(colors[i], colors[j]) > 0.12 or surface, "source parameters %d/%d differ" % [i, j])
	check(Appearance.profile(_cfg(["pork_bone"]))["milk"] > Appearance.profile(_cfg(["chicken_bone"]))["milk"], "bone is creamier than chicken")
	check(chili["oil_amount"] > 0.0 and chili["oil_color"].r > 0.8, "chili oil is red and present")
	check(herb["oil_color"].g > herb["oil_color"].r, "scallion oil reads green")

	check(_dist(bone, Appearance.profile(_cfg(["pork_bone", "shiitake"]))["broth_color"]) > 0.02, "same base id, different raw composition")
	check(Appearance.profile(_cfg(["pork_bone"], "gentle"))["milk"] < Appearance.profile(_cfg(["pork_bone"], "rolling"))["milk"], "method changes emulsion")
	check(Appearance.profile(_cfg(["pork_bone", "pork_bone"]))["broth_strength"] > Appearance.profile(_cfg(["pork_bone"]))["broth_strength"], "quantity modulates")
	check(Appearance.profile(_cfg(["pork_bone", "pork_bone", "pork_bone", "pork_bone", "garlic"]))["broth_strength"] <= 0.86, "strength is bounded")

	var wheat: Dictionary = Appearance.profile(_noodle("wheat", "clear", "thin"))
	check(wheat["error"] == "" and wheat["noodle_crafted"] and not wheat["crafted"], "noodle-only is noodle_crafted, not soup crafted")
	check(wheat["broth_strength"] == 0.0 and wheat["oil_amount"] == 0.0, "noodle-only leaves soup/oil expression to the legacy path")
	check(_dist(wheat["noodle_color"], Appearance.profile(_noodle("buckwheat", "clear", "thin"))["noodle_color"]) > 0.2, "buckwheat differs from wheat")
	check(_dist(wheat["noodle_color"], Appearance.profile(_noodle("wheat", "alkaline", "thin"))["noodle_color"]) > 0.03, "alkaline water differs")
	check(_dist(wheat["noodle_color"], Appearance.profile(_noodle("wheat", "clear", "thin", "rested"))["noodle_color"]) > 0.03, "noodle method differs")
	check(Appearance.profile(_noodle("wheat", "clear", "thick"))["cut"] == "thick", "cut is reported")
	var broth_only: Dictionary = Appearance.profile(_cfg(["pork_bone"]))
	check(not broth_only["noodle_crafted"] and broth_only["noodle_strength"] == 0.0, "broth-only keeps original noodle pixels")


func _invalid_inputs() -> void:
	var bad: Array = [
		_cfg(["nope"]),
		_cfg([]),
		_cfg(["pork_bone"], "unknown_method"),
		_cfg(["onion"]),
		_noodle("rice", "clear", "thin"),
		_noodle("wheat", "clear", "thin", "unknown_method"),
	]
	var malformed: Dictionary = Catalog.default_config()
	malformed["broth_recipe"] = 5
	bad.append(malformed)
	var missing: Dictionary = Catalog.default_config()
	missing["noodle_recipe"] = {"flour": "wheat"}
	bad.append(missing)
	for i in bad.size():
		var before: String = JSON.stringify(bad[i])
		var look: Dictionary = Appearance.profile(bad[i])
		check(look["error"] != "", "invalid input %d reports an error" % i)
		check(not look["crafted"] and not look["noodle_crafted"] and look["broth_strength"] == 0.0 and look["noodle_strength"] == 0.0, "invalid input %d is inert, not success-shaped" % i)
		check(JSON.stringify(bad[i]) == before, "invalid input %d is not mutated" % i)


func _material(view: Control) -> ShaderMaterial:
	return view.get_node("LayeredBowlBase").material as ShaderMaterial


func _param(material: ShaderMaterial, name: String, fallback: Variant) -> Variant:
	var value: Variant = material.get_shader_parameter(name)
	return fallback if value == null else value


func _view_facts() -> void:
	var view: Control = View.new()
	view.size = Vector2(300, 200)
	root.add_child(view)

	# All-legacy: appearance branch off and the historical shift is exactly kept.
	var legacy: Dictionary = Catalog.default_config()
	legacy["broth"] = "broth_chicken"
	legacy["oil"] = "oil_chili"
	view.set_config(legacy)
	var legacy_shift := Vector3(0.0, -0.08, -0.15) + Vector3(0.06, -0.04, -0.06)
	check(float(_param(_material(view), "appearance", 0.0)) == 0.0, "legacy view leaves appearance off")
	check((_param(_material(view), "broth_shift", Vector3.ZERO) as Vector3).is_equal_approx(legacy_shift), "legacy soup shift preserved")
	check(view.appearance_error == "", "legacy view has no appearance error")

	# Historical broth + raw noodle: same soup shift, plus the noodle expression.
	var mixed: Dictionary = _noodle("buckwheat", "clear", "thin", "standard", {"broth": "broth_chicken", "oil": "oil_chili", "noodle": "noodle_buckwheat"})
	view.set_config(mixed)
	var mat: ShaderMaterial = _material(view)
	check(float(_param(mat, "appearance", 0.0)) == 1.0, "raw noodle enables expression")
	check((_param(mat, "broth_shift", Vector3.ZERO) as Vector3).is_equal_approx(legacy_shift), "mixed bowl keeps the historical soup shift")
	check(float(_param(mat, "broth_strength", 0.0)) == 0.0 and float(_param(mat, "oil_amount", 0.0)) == 0.0, "mixed bowl adds no soup recolor or droplets")
	check(float(_param(mat, "noodle_strength", 0.0)) > 0.0, "mixed bowl expresses the raw noodle")

	# Raw broth only: soup expression on, noodle untouched, legacy shift replaced.
	var broth_only: Dictionary = _cfg(["pork_bone"], "standard", {"oil": "oil_chili"})
	view.set_config(broth_only)
	mat = _material(view)
	check(float(_param(mat, "appearance", 0.0)) == 1.0 and float(_param(mat, "broth_strength", 0.0)) > 0.0, "raw broth enables soup expression")
	check((_param(mat, "broth_shift", Vector3.ZERO) as Vector3).is_zero_approx(), "raw broth replaces the legacy shift")
	check(float(_param(mat, "noodle_strength", 0.0)) == 0.0, "raw broth leaves noodle pixels as the original")

	# Repeated portions are separate nodes and survive a crafted config.
	var repeated: Dictionary = _cfg(["pork_bone"], "standard", {"toppings": ["topping_chashu", "topping_chashu", "topping_egg"]})
	view.set_config(repeated)
	var portions: int = 0
	for child in view.get_children():
		if child.name.begins_with("Portion_"): portions += 1
	check(portions == Catalog.toppings_of(repeated).size() and portions == 3, "repeated topping count preserved")

	view.free()
