extends RefCounted
## Which complete recipes the player has really tried. Pure helpers: no UI, no GameState access.
##
## A recipe's identity is the SHA-256 of a canonical description: every slot, topping portions (catalog
## order), both process methods (the default spelled out) and both raw component formulas. Price, name and
## presentation order are NOT part of it, so repricing never "re-discovers" a recipe. Only the hash is
## persisted: it keeps each experiment ~70 bytes, so there is no gameplay ceiling on explored recipes.
## A hash grants nothing (no money, items or unlocks), so loading only checks its format and uniqueness;
## real configs are always fully validated BEFORE a key is generated from them.
## Compatibility notes come from the existing evaluator; this module never invents rules.
const Catalog = preload("res://scripts/domain/ingredient_catalog.gd")
const Check = preload("res://scripts/domain/data_check.gd")
const Evaluator = preload("res://scripts/domain/recipe_evaluator.gd")
const ProcessRules = preload("res://scripts/domain/recipe_process.gd")

const STATE_KEYS: Array = ["keys"]
const HEX: String = "0123456789abcdef"


static func empty_state() -> Dictionary:
	return {"keys": []}


## Canonical valid config (placeholder price), or {} when malformed. Always a fresh copy.
static func entry(config: Dictionary) -> Dictionary:
	var probe: Dictionary = config.duplicate(true)
	if not probe.has("price"):
		probe["price"] = Catalog.DEFAULT_PRICE
	if Check.config_error(probe) != "":
		return {}
	var out: Dictionary = Catalog.normalize_config(probe)
	out["price"] = Catalog.DEFAULT_PRICE
	return out


## Stable identity ("" for malformed input). Built field by field and serialised with sorted keys, so
## dictionary order and price never matter.
static func config_key(config: Dictionary) -> String:
	var canon: Dictionary = entry(config)
	if canon.is_empty():
		return ""
	var process: Dictionary = canon.get("process", {})
	var identity: Dictionary = {
		"broth": str(canon["broth"]), "tare": str(canon["tare"]), "oil": str(canon["oil"]),
		"noodle": str(canon["noodle"]), "cook": str(canon["cook"]),
		"toppings": canon["toppings"],
		"methods": {"broth": ProcessRules.selected(process, "broth"), "noodle": ProcessRules.selected(process, "noodle")},
		"broth_recipe": canon.get("broth_recipe", {}),
		"noodle_recipe": canon.get("noodle_recipe", {}),
	}
	return JSON.stringify(identity, "", true).sha256_text()


static func _index_of(keys: Array) -> Dictionary:
	var index: Dictionary = {}
	for key in keys:
		index[key] = true
	return index


## Add one recipe. Returns {"state","index","added"}; inputs are never mutated. Only malformed configs
## and already-known recipes add nothing; there is deliberately no size limit here (SaveService guards bytes).
static func with_recipe(state: Dictionary, index: Dictionary, config: Dictionary) -> Dictionary:
	var key: String = config_key(config)
	if key == "" or index.has(key):
		return {"state": state.duplicate(true), "index": index.duplicate(), "added": false}
	var next: Dictionary = state.duplicate(true)
	next["keys"].append(key)
	var next_index: Dictionary = index.duplicate()
	next_index[key] = true
	return {"state": next, "index": next_index, "added": true}


## Seed from configs that were really tasted (retained rows, comparison predecessors, best-taste witnesses).
static func seed(configs: Array) -> Dictionary:
	var keys: Array = []
	var index: Dictionary = {}
	for cfg in configs:
		if typeof(cfg) != TYPE_DICTIONARY:
			continue
		var key: String = config_key(cfg)
		if key != "" and not index.has(key):
			keys.append(key)
			index[key] = true
	return {"state": {"keys": keys}, "index": index}


## Strict, all-or-nothing parse of a saved state: {"error","state","index"}.
static func parse_state(raw: Variant) -> Dictionary:
	var bad: Dictionary = {"error": "레시피 지식 구조가 올바르지 않아요.", "state": empty_state(), "index": {}}
	if typeof(raw) != TYPE_DICTIONARY or Check.keys_error(raw, STATE_KEYS, "레시피 지식") != "":
		return bad
	if typeof(raw["keys"]) != TYPE_ARRAY:
		return bad
	var keys: Array = []
	var index: Dictionary = {}
	for item in raw["keys"]:
		if typeof(item) != TYPE_STRING or item.length() != 64 or index.has(item):
			bad["error"] = "레시피 지식 항목이 올바르지 않거나 중복됐어요."
			return bad
		for c in item:
			if not HEX.contains(c):
				bad["error"] = "레시피 지식 항목이 올바르지 않거나 중복됐어요."
				return bad
		index[item] = true
		keys.append(item)
	return {"error": "", "state": {"keys": keys}, "index": index}


## Public view for one config. Unknown (or malformed) results carry no compatibility data at
## all; known results list exactly what the evaluator applies (empty = neutral, no rules).
static func view(index: Dictionary, config: Dictionary) -> Dictionary:
	var key: String = config_key(config)
	if key == "" or not index.has(key):
		return {"known": false, "compat": []}
	var compat: Array = []
	for row in Evaluator.applied_compat(entry(config)):
		compat.append({"score": int(row["score"]), "note": str(row["note"])})
	return {"known": true, "compat": compat}
