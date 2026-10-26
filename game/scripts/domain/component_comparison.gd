extends RefCounted
## Read-only comparison of one finished broth/noodle against the one in the bowl.
## Nothing here is stored or scored by itself: every number comes from the same
## catalog products, process rules and Evaluator that tasting and service use.
## Inputs are never mutated; every returned value is a fresh deep copy.
const Catalog=preload("res://scripts/domain/ingredient_catalog.gd")
const Check=preload("res://scripts/domain/data_check.gd")
const Evaluator=preload("res://scripts/domain/recipe_evaluator.gd")
const Methods=preload("res://scripts/domain/recipe_process.gd")
const Broth=preload("res://scripts/domain/broth_workshop.gd")
const Noodle=preload("res://scripts/domain/noodle_workshop.gd")
const KINDS: Array[String]=["broth","noodle"]


static func valid_kind(kind: String) -> bool:
	return KINDS.has(kind)


static func label(kind: String) -> String:
	return "육수" if kind=="broth" else "면"


## Same validation the workshop edits use, plus the canonical form the workshop
## stores. Sample *stock* is deliberately not checked: an earned formula can be
## browsed and reloaded at zero stock, and only later production/tasting is gated.
static func recipe_error(kind: String, recipe: Variant, rank: int, discovered: Array) -> String:
	if not valid_kind(kind): return "비교할 항목은 육수와 면만 고를 수 있어요."
	var err: String=Broth.error(recipe,rank,discovered,true) if kind=="broth" else Noodle.error(recipe,rank,discovered,true)
	if err!="": return err
	if kind=="broth" and recipe!=Broth.canonical(recipe): return "육수 배합이 정렬되지 않았어요."
	return ""


## The config GameState.use_broth/use_noodle would build, without touching state.
## The recipe's own method is written into config.process exactly once; the
## product itself never contains method effects (Evaluator adds them from process).
static func apply_recipe(config: Dictionary, kind: String, recipe: Dictionary) -> Dictionary:
	var next: Dictionary=config.duplicate(true)
	next[kind]=Broth.base_id(recipe) if kind=="broth" else Noodle.base_id(recipe)
	next[kind+"_recipe"]=recipe.duplicate(true)
	var methods: Dictionary=next.get("process",{"broth":"standard","noodle":"standard"}).duplicate(true)
	methods[kind]=recipe["method"]
	next["process"]=methods
	return Catalog.normalize_config(next)


## One slot of a config as the evaluator sees it: product + this slot's method,
## each counted once. Axes stay signed (strong flour aroma -1); clamping to 0..10
## belongs to Evaluator.build_profile after every component is summed.
static func component(config: Dictionary, kind: String) -> Dictionary:
	if not valid_kind(kind) or not config.has(kind): return {}
	var item: Dictionary=Catalog.recipe_item(config,str(config[kind]))
	var process: Variant=config.get("process",{})
	if item.is_empty() or typeof(process)!=TYPE_DICTIONARY: return {}
	var method: Dictionary=Methods.method(kind,Methods.selected(process,kind))
	if method.is_empty(): return {}
	var axes: Dictionary={}
	for axis in Catalog.AXES: axes[axis]=int(item["axes"].get(axis,0))+int(method["axes"][axis])
	return {"name":str(item["name"]),"desc":str(item["desc"]),"axes":axes,
		"cost":int(item["cost"])+int(method["cost"]),"seconds":int(item["seconds"])+int(method["seconds"])}


static func _workshops_error(workshops: Variant) -> String:
	if typeof(workshops)!=TYPE_DICTIONARY: return "개발실 상태가 올바르지 않아요."
	for kind in KINDS:
		if not workshops.has(kind) or typeof(workshops[kind])!=TYPE_DICTIONARY: return "개발실 상태가 올바르지 않아요."
		var shop: Dictionary=workshops[kind]
		if typeof(shop.get("legacy"))!=TYPE_BOOL or typeof(shop.get("recipes"))!=TYPE_ARRAY: return "개발실 상태가 올바르지 않아요."
		for entry in shop["recipes"]:
			if typeof(entry)!=TYPE_DICTIONARY or not entry.has("recipe"): return "개발 기록이 올바르지 않아요."
	return ""


## A slot is "prepared" only by a really finished formula in this workshop, or by
## a historical catalog product in a save that predates the workshops. A new
## player's default catalog id is never a finished before-component.
static func prepared(config: Dictionary, kind: String, workshops: Dictionary, rank: int, discovered: Array) -> bool:
	var shop: Dictionary=workshops[kind]
	if not config.has(kind+"_recipe"): return bool(shop["legacy"])
	var recipe: Variant=config[kind+"_recipe"]
	if recipe_error(kind,recipe,rank,discovered)!="": return false
	for row in shop["recipes"]:
		if row["recipe"]==recipe: return true
	return false


static func _empty(kind: String, ok: bool, message: String) -> Dictionary:
	return {"ok":ok,"message":message,"kind":kind,"recipe":{},"current_component":{},"selected_component":{},
		"current_ramen":{},"candidate_ramen":{},"applied":false}


static func _failure(kind: String, message: String) -> Dictionary:
	return _empty(kind if valid_kind(kind) else "",false,message)


## `config` is the bowl; `workshops` is {"broth":{recipes,legacy,...},"noodle":{...}}.
## Whole-ramen evaluations exist only when BOTH bowl components are genuinely
## finished, so a partially prepared bowl never shows a phantom "before" score.
static func compare(kind: String, index: int, config: Dictionary, workshops: Dictionary, rank: int, discovered: Array) -> Dictionary:
	if not valid_kind(kind): return _failure(kind,"비교할 항목은 육수와 면만 고를 수 있어요.")
	var err: String=_workshops_error(workshops)
	if err!="": return _failure(kind,err)
	var recipes: Array=workshops[kind]["recipes"]
	if index<0 or index>=recipes.size(): return _failure(kind,"비교할 개발한 %s를 골라 주세요." % label(kind))
	var recipe: Dictionary=recipes[index]["recipe"] if typeof(recipes[index]["recipe"])==TYPE_DICTIONARY else {}
	err=recipe_error(kind,recipe,rank,discovered)
	if err!="": return _failure(kind,err)
	err=Check.config_error(config)
	if err!="": return _failure(kind,err)
	var candidate: Dictionary=apply_recipe(config,kind,recipe)
	err=Check.config_error(candidate)
	if err!="": return _failure(kind,err)
	var out: Dictionary=_empty(kind,true,"")
	out["recipe"]=recipe.duplicate(true)
	out["selected_component"]=component(candidate,kind)
	if out["selected_component"].is_empty(): return _failure(kind,"고른 %s의 구성을 계산할 수 없어요." % label(kind))
	var here: bool=prepared(config,kind,workshops,rank,discovered)
	out["applied"]=here and config.has(kind+"_recipe") and config[kind+"_recipe"]==recipe
	if here: out["current_component"]=component(config,kind)
	var both: bool=here
	for other in KINDS:
		both=both and prepared(config,other,workshops,rank,discovered)
	if not both:
		out["message"]="그릇에 담긴 완성 육수와 면이 모두 있어야 라멘 점수를 비교할 수 있어요."
		return out
	if int(Methods.effects(config.get("process",{}))["rank"])>rank: return _failure(kind,"제조 공법에 필요한 가게 등급이 없어요.")
	var current: Dictionary=Evaluator.evaluate(config)
	var changed: Dictionary=Evaluator.evaluate(candidate)
	if str(current["error"])!="" or str(changed["error"])!="": return _failure(kind,str(current["error"])+str(changed["error"]))
	out["current_ramen"]=current.duplicate(true)
	out["candidate_ramen"]=changed.duplicate(true)
	return out
