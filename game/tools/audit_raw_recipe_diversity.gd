extends SceneTree
## Raw starter recipe diversity audit: a PURE catalog/evaluator study.
## It is NOT a playthrough: no GameState instance, save, money, XP, rank, stock or
## discovery is created or changed, and nothing here was manufactured, selected or
## tasted by a player. It enumerates every theoretical rank-1 starter-accessible raw
## broth formula (1..3 portions x rank-1 methods) and every rank-1 starter noodle
## formula, builds three fixed valid full raw-component bowls for each candidate
## (the companion raw component stays fixed per context) and records the actual
## RecipeEvaluator numbers. Collisions are observed ONLY across those three contexts.
## Usage: godot --headless --path game --script res://tools/audit_raw_recipe_diversity.gd -- --audit-out=/abs/new/folder
## Exit: 0 complete success, 1 check/engine/write failure, 2 bad arguments/output path.
const State = preload("res://scripts/domain/game_state.gd")
const Catalog = preload("res://scripts/domain/ingredient_catalog.gd")
const Check = preload("res://scripts/domain/data_check.gd")
const Evaluator = preload("res://scripts/domain/recipe_evaluator.gd")
const Customers = preload("res://scripts/domain/customer_catalog.gd")
const Broth = preload("res://scripts/domain/broth_workshop.gd")
const Noodle = preload("res://scripts/domain/noodle_workshop.gd")
const Methods = preload("res://scripts/domain/recipe_process.gd")
const Growth = preload("res://scripts/domain/shop_growth.gd")

const FORMAT: int = 1
const ALGORITHM_VERSION: int = 1
const STARTER_RANK: int = 1
const MAX_PORTIONS: int = 3
const REPORT_FILE: String = "report.json"
## Explicit finite-loop caps: exceeding one is a reported failure, never a partial result.
const MAX_BROTH_MULTISETS: int = 120
const MAX_BROTH_CANDIDATES: int = 300
const MAX_NOODLE_CANDIDATES: int = 100
const MAX_RUNTIME_MS: int = 90000
const WATCHDOG_SECONDS: float = 120.0
const MAX_FAILURES: int = 60
const COLLISION_EXAMPLES: int = 10
const EXAMPLE_MEMBERS: int = 8

## Three fixed contexts. Tare/oil/toppings/cook vary; each context keeps ONE companion
## noodle (used with every broth candidate) and ONE companion broth (used with every
## noodle candidate). All are valid rank-1 starter choices; broth ingredients are canonical.
const CONTEXTS: Array = [
	{"id": "clear_light", "tare": "tare_shio", "oil": "oil_scallion", "toppings": ["topping_nori"], "cook": "cook_firm", "price": 9000,
		"companion_noodle": {"flour": "wheat", "water": "clear", "cut": "thin", "method": "standard"},
		"companion_broth": {"ingredients": ["ginger", "kelp"], "method": "standard"}},
	{"id": "rich_hearty", "tare": "tare_shoyu", "oil": "oil_garlic", "toppings": ["topping_egg", "topping_sprouts"], "cook": "cook_normal", "price": 9000,
		"companion_noodle": {"flour": "wheat", "water": "clear", "cut": "thick", "method": "standard"},
		"companion_broth": {"ingredients": ["garlic", "pork_bone"], "method": "standard"}},
	{"id": "spicy_soft", "tare": "tare_miso", "oil": "oil_chili", "toppings": ["topping_chashu"], "cook": "cook_soft", "price": 9000,
		"companion_noodle": {"flour": "strong", "water": "alkaline", "cut": "medium", "method": "standard"},
		"companion_broth": {"ingredients": ["chicken_bone", "onion"], "method": "gentle"}},
]

var checks: int = 0
var failures: Array[String] = []
var _started_ms: int = 0


func _initialize() -> void:
	_started_ms = Time.get_ticks_msec()
	create_timer(WATCHDOG_SECONDS).timeout.connect(func() -> void:
		printerr("AUDIT WATCHDOG: audit did not finish in time")
		quit(1))
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() != 1 or not args[0].begins_with("--audit-out="):
		printerr("Usage: --audit-out=<new canonical absolute folder> (exactly one argument, no others).")
		quit(2)
		return
	var output: String = args[0].substr(12)
	var problem: String = _output_error(output)
	if problem != "":
		printerr("--audit-out rejected: " + problem + " Nothing was written.")
		quit(2)
		return
	var report: Dictionary = _build_report()
	if report.is_empty() or not failures.is_empty():
		printerr("raw recipe diversity audit FAILED: checks=%d failures=%d. Nothing was written." % [checks, failures.size()])
		quit(1)
		return
	# Re-validate right before the first write: the path must still be new and canonical.
	problem = _output_error(output)
	if problem != "":
		printerr("--audit-out rejected before writing: " + problem + " Nothing was written.")
		quit(2)
		return
	if DirAccess.make_dir_absolute(output) != OK:
		printerr("Cannot create the new audit folder. Nothing was written.")
		quit(1)
		return
	var text: String = JSON.stringify(report, "\t", true) + "\n"
	if not _write_new(output, output.path_join(REPORT_FILE), text):
		printerr("raw recipe diversity audit FAILED while writing: checks=%d failures=%d" % [checks, failures.size()])
		quit(1)
		return
	print("raw recipe diversity audit: broth_candidates=%d noodle_candidates=%d checks=%d failures=%d report_sha256=%s" % [
		int(report["enumeration"]["broth"]["candidates"]), int(report["enumeration"]["noodle"]["candidates"]), checks, failures.size(), text.sha256_text()])
	quit(0 if failures.is_empty() else 1)


## Every pre-write rejection lives here and performs no filesystem mutation.
## Returns "" when the output is a new, normalized, absolute path under a real parent chain.
func _output_error(output: String) -> String:
	if output == "":
		return "The path is empty."
	if not output.begins_with("/") or output.contains("://"):
		return "The path must be an absolute filesystem path (not relative, user:// or res://)."
	if output != output.simplify_path() or output.ends_with("/") or output == "/" or output.get_file() == "":
		return "The path must be normalized without trailing slash, '.' or '..'."
	var live: String = OS.get_user_data_dir()
	if output == live or output.begins_with(live + "/"):
		return "The live user data folder is never an acceptable target."
	# A symlinked or unreadable component could alias another place past the lexical test.
	var walked: String = "/"
	for part in output.get_base_dir().split("/", false):
		var walker: DirAccess = DirAccess.open(walked)
		if walker == null or walker.is_link(part):
			return "The parent chain has a missing, unreadable or symlinked component (%s); pass the canonical absolute path." % walked.path_join(part)
		walked = walked.path_join(part)
	var parent: DirAccess = DirAccess.open(output.get_base_dir())
	if parent == null:
		return "The parent folder must already exist."
	var leaf: String = output.get_file()
	if parent.file_exists(leaf) or parent.dir_exists(leaf) or parent.is_link(leaf) or FileAccess.file_exists(output) or DirAccess.dir_exists_absolute(output):
		return "The output path already exists (file, folder, symlink or broken link); it is never overwritten."
	return ""


func _check(condition: bool, message: String) -> bool:
	checks += 1
	if not condition:
		failures.append(message)
		printerr("AUDIT FAILURE: " + message)
	return condition


func _within_bounds() -> bool:
	return _check(Time.get_ticks_msec() - _started_ms < MAX_RUNTIME_MS and failures.size() <= MAX_FAILURES, "audit stayed inside its runtime and failure bounds")


## Builds the whole report in memory. {} (with failures recorded) on any failure.
func _build_report() -> Dictionary:
	_check_contexts()
	var methods_broth: Array = _rank1_methods("broth")
	var methods_noodle: Array = _rank1_methods("noodle")
	if not _check(methods_broth.size() >= 1 and methods_noodle.size() >= 1, "rank-1 methods exist for both slots") or not failures.is_empty():
		return {}
	_check(Broth.capacity(STARTER_RANK) == MAX_PORTIONS, "rank-1 broth capacity equals the enumerated 3 portions")
	_check(Growth.topping_slots(STARTER_RANK, []) >= 2, "rank 1 opens at least the two topping portions used by the contexts")

	var broth: Dictionary = _enumerate_broth(methods_broth)
	var noodle: Dictionary = _enumerate_noodle(methods_noodle)
	if broth.is_empty() or noodle.is_empty() or not failures.is_empty():
		return {}

	var broth_candidates: Array = _evaluate_family("broth", broth["formulas"])
	var noodle_candidates: Array = _evaluate_family("noodle", noodle["formulas"])
	if broth_candidates.is_empty() or noodle_candidates.is_empty() or not failures.is_empty():
		return {}
	var broth_analysis: Dictionary = _analyze(broth_candidates)
	var noodle_analysis: Dictionary = _analyze(noodle_candidates)
	_check(broth_candidates.size() == int(broth["valid_multisets"]) * methods_broth.size(), "broth candidates = valid multisets x rank-1 methods")
	_check(noodle_candidates.size() == int(noodle["expected"]), "noodle candidates = product of starter field options")
	if not failures.is_empty():
		return {}

	var enumeration_broth: Dictionary = broth["summary"].duplicate(true)
	enumeration_broth["candidates"] = broth_candidates.size()
	var enumeration_noodle: Dictionary = noodle["summary"].duplicate(true)
	enumeration_noodle["candidates"] = noodle_candidates.size()
	return {
		"format": FORMAT, "kind": "raw_recipe_diversity", "algorithm_version": ALGORITHM_VERSION,
		"game_schema_version": State.SCHEMA_VERSION, "starter_rank": STARTER_RANK,
		"scope": "Pure catalog/evaluator study of THEORETICAL rank-1 starter raw broth and noodle formulas. Not a playthrough: no GameState, save, money, XP, rank, stock or discovery is used, and no candidate was manufactured, selected or tasted by a player. It says nothing about player discovery, campaign volume or fun.",
		"limitations": [
			"Collisions are observed across exactly three fixed contexts and three catalog customers; they do not prove equality for other toppings, tares, oils, cook levels or customers.",
			"Broth candidates keep the context's companion noodle fixed; noodle candidates keep the context's companion broth fixed. Families are never compared with each other.",
			"Numeric outcomes only: names, recipe text, headlines and formula IDs are excluded from the signature. Price is fixed and does not enter any score.",
			"Theoretical counts say how many distinct formulas exist, not how many a player would find, afford or want to use."],
		"inputs": _inputs(broth, noodle, methods_broth, methods_noodle),
		"enumeration": {"broth": enumeration_broth, "noodle": enumeration_noodle},
		"metrics": {"numeric_order": _metric_names(), "taste_signature_order": _taste_metric_names(),
			"signature_rule": "full = every numeric metric of all three contexts in context order; taste = the same without unit_cost and prep_seconds"},
		"contexts": _contexts_copy(),
		"broth": {"candidates": broth_candidates, "analysis": broth_analysis},
		"noodle": {"candidates": noodle_candidates, "analysis": noodle_analysis},
		"checks_before_write": checks, "failures": failures.duplicate(),
	}


func _contexts_copy() -> Array:
	return CONTEXTS.duplicate(true)


## Fixed contexts must themselves be valid starter choices before anything is evaluated.
func _check_contexts() -> void:
	var ids: Dictionary = {}
	for ctx in _contexts_copy():
		var label: String = str(ctx["id"])
		_check(not ids.has(label), "context id is unique: " + label)
		ids[label] = true
		_check(_starter_item("tare", str(ctx["tare"])), "context tare is a starter item: " + label)
		_check(_starter_item("oil", str(ctx["oil"])), "context oil is a starter item: " + label)
		_check(_starter_item("cook", str(ctx["cook"])), "context cook is a starter item: " + label)
		var toppings: Array = ctx["toppings"]
		_check(toppings.size() >= 1 and toppings.size() <= Growth.topping_slots(STARTER_RANK, []), "context topping count fits rank 1: " + label)
		for topping in toppings:
			_check(_starter_item("topping", str(topping)), "context topping is a starter item: " + label)
		_check(str(Catalog.canonical_toppings(toppings)) == str(toppings), "context toppings are canonical: " + label)
		var companion_broth: Dictionary = ctx["companion_broth"]
		_check(Broth.error(companion_broth, STARTER_RANK, [], true) == "" and Broth.canonical(companion_broth) == companion_broth, "companion broth is a valid canonical rank-1 starter formula: " + label)
		var companion_noodle: Dictionary = ctx["companion_noodle"]
		_check(Noodle.error(companion_noodle, STARTER_RANK, [], true) == "" and Noodle.canonical(companion_noodle) == companion_noodle, "companion noodle is a valid canonical rank-1 starter formula: " + label)
		_check(int(ctx["price"]) >= Catalog.PRICE_MIN and int(ctx["price"]) <= Catalog.PRICE_MAX and int(ctx["price"]) % Catalog.PRICE_STEP == 0, "context price is a legal price: " + label)
	_check(ids.size() == 3, "exactly three contexts")


## A starter item is in the original ITEMS table (not discovery, not farmed).
func _starter_item(slot: String, id: String) -> bool:
	for item in Catalog.items(slot):
		if str((item as Dictionary)["id"]) == id:
			return not Catalog.is_discovery(id) and not Catalog.is_farmed(id)
	return false


func _rank1_methods(slot: String) -> Array:
	var out: Array = []
	for id in Methods.ids(slot):
		var method: Dictionary = Methods.method(slot, id)
		if int(method["rank"]) <= STARTER_RANK:
			out.append(str(id))
	return out


# ---------- enumeration ----------

func _multichoose(n: int, k: int) -> int:
	# C(n + k - 1, k) with exact integer steps.
	var result: int = 1
	for i in range(1, k + 1):
		result = result * (n - 1 + i) / i
	return result


func _enumerate_broth(methods: Array) -> Dictionary:
	var rows: Array = Broth.DATA.duplicate(true)
	var starter_ids: Array[String] = []
	var excluded: Array = []
	var base_ids: Array[String] = []
	var material_ids: Array = []
	for row in rows:
		var id: String = str(row["id"])
		material_ids.append(id)
		if row.has("source"):
			excluded.append({"id": id, "source": str(row["source"])})
			_check(Broth.error({"ingredients": [id, "kelp"], "method": "standard"}, STARTER_RANK, [], true) != "", "supplier-gated broth ingredient is rejected without discovery: " + id)
		else:
			starter_ids.append(id)
			if bool(row["base"]):
				base_ids.append(id)
	if not _check(starter_ids.size() >= 1 and not base_ids.is_empty(), "starter broth ingredients and bases exist"):
		return {}
	var raw_sets: Array = []
	for size in range(1, MAX_PORTIONS + 1):
		if not _combine(starter_ids, size, 0, [], raw_sets):
			return {}
	var seen: Dictionary = {}
	var valid: Array = []
	var rejected: Array = []
	var per_size: Dictionary = {}
	var valid_per_size: Dictionary = {}
	for picked in raw_sets:
		var canon: Array = Broth.canonical({"ingredients": picked, "method": "standard"})["ingredients"]
		var key: String = "+".join(PackedStringArray(canon))
		_check(not seen.has(key), "canonical broth multiset is unique: " + key)
		seen[key] = true
		per_size[str(canon.size())] = int(per_size.get(str(canon.size()), 0)) + 1
		var has_base: bool = false
		for id in canon:
			has_base = has_base or base_ids.has(id)
		var error: String = Broth.error({"ingredients": canon, "method": "standard"}, STARTER_RANK, [], true)
		_check((error == "") == has_base, "validator agrees with the main-ingredient rule: " + key)
		if error == "":
			valid.append(canon)
			valid_per_size[str(canon.size())] = int(valid_per_size.get(str(canon.size()), 0)) + 1
		else:
			rejected.append(key)
	var expected: int = 0
	for size in range(1, MAX_PORTIONS + 1):
		expected += _multichoose(starter_ids.size(), size)
		_check(int(per_size.get(str(size), 0)) == _multichoose(starter_ids.size(), size), "every size-%d multiset was enumerated exactly once" % size)
	_check(raw_sets.size() == expected and seen.size() == expected, "multiset total matches the multichoose count")
	var formulas: Array = []
	for method in methods:
		for canon in valid:
			var formula: Dictionary = {"ingredients": (canon as Array).duplicate(), "method": str(method)}
			_check(Broth.error(formula, STARTER_RANK, [], true) == "", "enumerated broth formula is valid at rank 1")
			formulas.append(formula)
			if not _check(formulas.size() <= MAX_BROTH_CANDIDATES, "broth candidate cap not exceeded"):
				return {}
	return {"formulas": formulas, "valid_multisets": valid.size(), "summary": {
		"material_ids": material_ids, "starter_ingredient_ids": starter_ids, "base_ingredient_ids": base_ids, "excluded_supplier_gated": excluded,
		"max_portions": MAX_PORTIONS, "rank1_method_ids": methods.duplicate(),
		"multisets_enumerated": raw_sets.size(), "multisets_expected_multichoose": expected, "multisets_by_size": per_size,
		"valid_multisets": valid.size(), "valid_multisets_by_size": valid_per_size,
		"rejected_without_main_ingredient": rejected, "rejected_count": rejected.size()}}


## Non-decreasing index combinations with repetition (repeated portions preserved).
func _combine(ids: Array, size: int, start: int, current: Array, out: Array) -> bool:
	if current.size() == size:
		out.append(current.duplicate())
		return _check(out.size() <= MAX_BROTH_MULTISETS, "broth multiset cap not exceeded") and _within_bounds()
	for i in range(start, ids.size()):
		current.append(ids[i])
		var ok: bool = _combine(ids, size, i, current, out)
		current.pop_back()
		if not ok:
			return false
	return true


func _enumerate_noodle(methods: Array) -> Dictionary:
	var options: Dictionary = {}
	var excluded: Array = []
	var expected: int = 1
	for field in ["flour", "water", "cut"]:
		var ids: Array[String] = []
		for row in Noodle.options(field):
			if row.has("source"):
				excluded.append({"field": field, "id": str(row["id"]), "source": str(row["source"])})
				_check(Noodle.error({"flour": str(row["id"]), "water": "clear", "cut": "thin", "method": "standard"}, STARTER_RANK, [], true) != "" if field == "flour" else true, "supplier-gated noodle flour is rejected at rank 1: " + str(row["id"]))
			else:
				ids.append(str(row["id"]))
		options[field] = ids
		expected *= ids.size()
	options["method"] = methods.duplicate()
	expected *= methods.size()
	var formulas: Array = []
	var seen: Dictionary = {}
	for flour in options["flour"]:
		for water in options["water"]:
			for cut in options["cut"]:
				for method in methods:
					var formula: Dictionary = {"flour": flour, "water": water, "cut": cut, "method": str(method)}
					var key: String = "%s/%s/%s/%s" % [flour, water, cut, method]
					_check(not seen.has(key), "canonical noodle formula is unique: " + key)
					seen[key] = true
					_check(Noodle.error(formula, STARTER_RANK, [], true) == "" and Noodle.canonical(formula) == formula, "enumerated noodle formula is valid at rank 1: " + key)
					formulas.append(formula)
					if not _check(formulas.size() <= MAX_NOODLE_CANDIDATES, "noodle candidate cap not exceeded") or not _within_bounds():
						return {}
	return {"formulas": formulas, "expected": expected, "summary": {
		"flour_ids": options["flour"], "water_ids": options["water"], "cut_ids": options["cut"], "method_ids": methods.duplicate(),
		"excluded_supplier_gated": excluded, "formulas_enumerated": formulas.size(), "formulas_expected_product": expected}}


func _inputs(broth: Dictionary, noodle: Dictionary, methods_broth: Array, methods_noodle: Array) -> Dictionary:
	var method_rows: Dictionary = {"broth": [], "noodle": []}
	for slot in ["broth", "noodle"]:
		for id in Methods.ids(slot):
			var method: Dictionary = Methods.method(slot, id)
			method_rows[slot].append({"id": str(id), "rank": int(method["rank"]), "cost": int(method["cost"]), "seconds": int(method["seconds"]), "axes": method["axes"]})
	var materials: Array = []
	for row in Broth.DATA:
		materials.append({"id": str(row["id"]), "base": bool(row["base"]), "cost": int(row["cost"]), "seconds": int(row["seconds"]),
			"axes": (row["axes"] as Dictionary).duplicate(true), "supplier_gated": row.has("source")})
	var noodle_options: Dictionary = {}
	for field in ["flour", "water", "cut"]:
		noodle_options[field] = []
		for row in Noodle.options(field):
			noodle_options[field].append(_pick(row, ["id", "cost", "chew", "aroma", "seconds", "source"]))
	return {"broth_materials": materials, "broth_methods": method_rows["broth"], "noodle_methods": method_rows["noodle"],
		"rank1_broth_method_ids": methods_broth.duplicate(), "rank1_noodle_method_ids": methods_noodle.duplicate(),
		"noodle_options": noodle_options, "starter_noodle_field_ids": {"flour": noodle["summary"]["flour_ids"], "water": noodle["summary"]["water_ids"], "cut": noodle["summary"]["cut_ids"]},
		"starter_broth_ingredient_ids": broth["summary"]["starter_ingredient_ids"],
		"customer_ids": Customers.ids(), "topping_slots_at_rank1": Growth.topping_slots(STARTER_RANK, []),
		"starter_slot_items": {"tare": _ids_of(Catalog.items("tare")), "oil": _ids_of(Catalog.items("oil")), "topping": _ids_of(Catalog.items("topping")), "cook": _ids_of(Catalog.items("cook"))}}


func _pick(row: Dictionary, keys: Array) -> Dictionary:
	var out: Dictionary = {}
	for key in keys:
		if row.has(key):
			out[key] = row[key]
	return out


func _ids_of(rows: Array) -> Array:
	var out: Array = []
	for row in rows:
		out.append(str((row as Dictionary)["id"]))
	return out


# ---------- evaluation ----------

func _metric_names() -> Array:
	var names: Array = []
	for axis in Catalog.AXES:
		names.append("profile_" + axis)
	names.append("compat_total")
	for id in Customers.ids():
		names.append("score_" + id)
	names.append("average_score")
	names.append("unit_cost")
	names.append("prep_seconds")
	return names


func _taste_metric_names() -> Array:
	var names: Array = _metric_names()
	names.erase("unit_cost")
	names.erase("prep_seconds")
	return names


func _evaluate_family(family: String, formulas: Array) -> Array:
	var out: Array = []
	var keys: Dictionary = {}
	for formula in formulas:
		if not _within_bounds():
			return []
		var key: String = _formula_key(family, formula)
		_check(not keys.has(key), "candidate key is unique: " + key)
		keys[key] = true
		var configs: Dictionary = {}
		var outcomes: Dictionary = {}
		for ctx in _contexts_copy():
			var broth_recipe: Dictionary = (formula as Dictionary).duplicate(true) if family == "broth" else (ctx["companion_broth"] as Dictionary).duplicate(true)
			var noodle_recipe: Dictionary = (formula as Dictionary).duplicate(true) if family == "noodle" else (ctx["companion_noodle"] as Dictionary).duplicate(true)
			var config: Dictionary = _bowl(ctx, broth_recipe, noodle_recipe)
			var metrics: Dictionary = _evaluate_config(config, "%s/%s/%s" % [family, key, ctx["id"]])
			if metrics.is_empty():
				return []
			configs[str(ctx["id"])] = config
			outcomes[str(ctx["id"])] = metrics
		out.append({"index": out.size(), "key": key, "formula": (formula as Dictionary).duplicate(true), "configs": configs, "outcomes": outcomes})
	return out


func _formula_key(family: String, formula: Dictionary) -> String:
	if family == "broth":
		return "%s|%s" % [formula["method"], "+".join(PackedStringArray(formula["ingredients"]))]
	return "%s/%s/%s/%s" % [formula["flour"], formula["water"], formula["cut"], formula["method"]]


## The same fields the production workshop handoff writes (use_broth/use_noodle), built
## with the pure helpers only. Default (all-standard) methods carry no "process" key.
func _bowl(ctx: Dictionary, broth_recipe: Dictionary, noodle_recipe: Dictionary) -> Dictionary:
	var config: Dictionary = {
		"broth": Broth.base_id(broth_recipe), "tare": str(ctx["tare"]), "oil": str(ctx["oil"]), "noodle": Noodle.base_id(noodle_recipe),
		"toppings": (ctx["toppings"] as Array).duplicate(), "cook": str(ctx["cook"]), "price": int(ctx["price"]),
		"process": {"broth": str(broth_recipe["method"]), "noodle": str(noodle_recipe["method"])},
		"broth_recipe": Broth.canonical(broth_recipe), "noodle_recipe": Noodle.canonical(noodle_recipe)}
	return Catalog.normalize_config(config)


## Validates every precondition, then returns the flat numeric metrics ({} on failure).
func _evaluate_config(config: Dictionary, label: String) -> Dictionary:
	var parsed: Dictionary = Check.parse_config(config, label)
	if not _check(str(parsed["error"]) == "", "parse_config accepts " + label + ": " + str(parsed["error"])):
		return {}
	var canonical: Dictionary = parsed["config"]
	if not _check(JSON.stringify(canonical, "", true) == JSON.stringify(config, "", true) and Check.same_config(canonical, config), "config is already canonical: " + label):
		return {}
	var broth_recipe: Dictionary = config["broth_recipe"]
	var noodle_recipe: Dictionary = config["noodle_recipe"]
	var ok: bool = _check(Broth.error(broth_recipe, STARTER_RANK, [], true) == "", "broth is rank-1 starter accessible: " + label)
	ok = _check(Noodle.error(noodle_recipe, STARTER_RANK, [], true) == "", "noodle is rank-1 starter accessible: " + label) and ok
	ok = _check((config["toppings"] as Array).size() <= Growth.topping_slots(STARTER_RANK, []), "toppings fit rank 1: " + label) and ok
	ok = _check(_starter_item("tare", str(config["tare"])) and _starter_item("oil", str(config["oil"])) and _starter_item("cook", str(config["cook"])), "tare/oil/cook are starter items: " + label) and ok
	for topping in config["toppings"]:
		ok = _check(_starter_item("topping", str(topping)), "topping is a starter item: " + label) and ok
	ok = _check(config["broth"] == Broth.product(broth_recipe)["id"] and config["noodle"] == Noodle.product(noodle_recipe)["id"], "manufactured broth/noodle IDs match their formulas: " + label) and ok
	var effects: Dictionary = Methods.effects(config.get("process", {}))
	ok = _check(str(effects["error"]) == "" and int(effects["rank"]) <= STARTER_RANK, "methods are rank-1: " + label) and ok
	ok = _check(config.has("process") == (broth_recipe["method"] != "standard" or noodle_recipe["method"] != "standard"), "process key present exactly for non-default methods: " + label) and ok
	if not ok:
		return {}
	var result: Dictionary = Evaluator.evaluate(config)
	if not _check(str(result["error"]) == "", "evaluator accepts " + label + ": " + str(result["error"])):
		return {}
	# Independent recomputation of cost and prep from the catalogs.
	var broth_product: Dictionary = Broth.product(broth_recipe)
	var noodle_product: Dictionary = Noodle.product(noodle_recipe)
	var broth_method: Dictionary = Methods.method("broth", str(broth_recipe["method"]))
	var noodle_method: Dictionary = Methods.method("noodle", str(noodle_recipe["method"]))
	var cost: int = int(broth_product["cost"]) + int(noodle_product["cost"]) + int(broth_method["cost"]) + int(noodle_method["cost"])
	var seconds: int = int(broth_product["seconds"]) + int(noodle_product["seconds"]) + int(broth_method["seconds"]) + int(noodle_method["seconds"])
	var plain_ids: Array = [config["tare"], config["oil"], config["cook"]]
	plain_ids.append_array(config["toppings"])
	for id in plain_ids:
		var item: Dictionary = Catalog.find(str(id))
		cost += int(item["cost"])
		seconds += int(item["seconds"])
	if not _check(int(result["unit_cost"]) == cost and int(result["prep_seconds"]) == seconds, "evaluator cost/prep equals independent catalog recomputation: " + label):
		return {}
	var customers: Array = result["customers"]
	if not _check(customers.size() == Customers.ids().size(), "one score per catalog customer: " + label):
		return {}
	var metrics: Dictionary = {}
	for axis in Catalog.AXES:
		metrics["profile_" + axis] = int(result["profile"][axis])
	metrics["compat_total"] = int(result["compat_total"])
	for customer in customers:
		metrics["score_" + str(customer["id"])] = int(customer["score"])
	metrics["average_score"] = int(result["average_score"])
	metrics["unit_cost"] = int(result["unit_cost"])
	metrics["prep_seconds"] = int(result["prep_seconds"])
	for name in _metric_names():
		if not _check(metrics.has(name), "metric present: %s %s" % [name, label]):
			return {}
	return metrics


# ---------- analysis ----------

func _signature(candidate: Dictionary, names: Array) -> String:
	var parts: Array[String] = []
	for ctx in CONTEXTS:
		for name in names:
			parts.append(str(int(candidate["outcomes"][ctx["id"]][name])))
	return ",".join(PackedStringArray(parts))


func _analyze(candidates: Array) -> Dictionary:
	var analysis: Dictionary = {"candidate_count": candidates.size()}
	for kind in ["full", "taste"]:
		var names: Array = _metric_names() if kind == "full" else _taste_metric_names()
		var groups: Dictionary = {}
		var order: Array = []
		for candidate in candidates:
			var signature: String = _signature(candidate, names)
			if not groups.has(signature):
				groups[signature] = []
				order.append(signature)
			(groups[signature] as Array).append(int(candidate["index"]))
			if not candidate.has("signature_group"):
				candidate["signature_group"] = {}
			candidate["signature_group"][kind] = order.find(signature)
		var histogram: Dictionary = {}
		var collisions: Array = []
		var in_collision: int = 0
		var largest: int = 0
		var total: int = 0
		for index in order.size():
			var members: Array = groups[order[index]]
			total += members.size()
			largest = maxi(largest, members.size())
			histogram[str(members.size())] = int(histogram.get(str(members.size()), 0)) + 1
			if members.size() > 1:
				in_collision += members.size()
				var shown: Array = []
				for member in members.slice(0, EXAMPLE_MEMBERS):
					shown.append(str(candidates[int(member)]["key"]))
				collisions.append({"group": index, "size": members.size(), "member_indexes": members.slice(0, EXAMPLE_MEMBERS), "members": shown, "members_omitted": maxi(0, members.size() - EXAMPLE_MEMBERS)})
		collisions.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			if int(a["size"]) != int(b["size"]):
				return int(a["size"]) > int(b["size"])
			return int(a["group"]) < int(b["group"]))
		_check(total == candidates.size(), "signature groups partition all candidates (%s)" % kind)
		analysis[kind] = {"unique_signatures": order.size(), "collision_groups": collisions.size(), "candidates_in_collision_groups": in_collision,
			"largest_group_size": largest, "group_size_histogram": histogram,
			"representative_collisions": collisions.slice(0, COLLISION_EXAMPLES), "signature_metric_order": names.duplicate()}
	_check(int(analysis["full"]["unique_signatures"]) >= int(analysis["taste"]["unique_signatures"]), "full signature refines the taste signature")
	var ranges: Dictionary = {}
	for ctx in CONTEXTS:
		var per_metric: Dictionary = {}
		for name in _metric_names():
			var low: int = 0
			var high: int = 0
			var distinct: Dictionary = {}
			var first: bool = true
			for candidate in candidates:
				var value: int = int(candidate["outcomes"][ctx["id"]][name])
				distinct[value] = true
				low = value if first else mini(low, value)
				high = value if first else maxi(high, value)
				first = false
			per_metric[name] = {"min": low, "max": high, "distinct_values": distinct.size()}
		ranges[str(ctx["id"])] = per_metric
	analysis["metric_ranges"] = ranges
	return analysis


# ---------- output ----------

## Create-only write confined to the new audit folder, verified by reading it back.
func _write_new(root: String, path: String, content: String) -> bool:
	if not _check(path.begins_with(root + "/"), "write stays inside audit folder"):
		return false
	if not _check(not FileAccess.file_exists(path), "preserve existing output"):
		return false
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if not _check(file != null, "open output"):
		return false
	file.store_string(content)
	var error: Error = file.get_error()
	file.close()
	if not _check(error == OK, "write output"):
		return false
	return _check(FileAccess.get_file_as_string(path) == content, "report reads back identical")
