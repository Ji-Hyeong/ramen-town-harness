extends RefCounted
## Counterfactual view data only. Canonical recipes and the existing evaluator
## are shared with real tasting; no stock, wallet, records or scores are edited.
const Catalog = preload("res://scripts/domain/ingredient_catalog.gd")
const Evaluator = preload("res://scripts/domain/recipe_evaluator.gd")
const Directions = preload("res://scripts/domain/recipe_directions.gd")
const Check = preload("res://scripts/domain/data_check.gd")
const Game = preload("res://scripts/domain/game_state.gd")


static func candidates(state: Game, id: String, selected: int = -1) -> Dictionary:
	var base: Dictionary=Catalog.normalize_config(state.draft_config)
	var item: Dictionary=Catalog.find(id)
	var error: String=Check.config_error(base)
	if item.is_empty() or error!="":
		return {"error":"실험할 재료와 올바른 초안이 필요해요." if error=="" else error,"rows":[]}
	if base.has(slot_key(id)+"_recipe"):
		return {"error":"이 재료는 개발실에서 원재료를 바꿔 실험해 주세요.","rows":[]}
	var rows: Array=[]
	var slot: String=id.get_slice("_",0)
	if slot=="topping":
		var portions: Array=Catalog.toppings_of(base)
		if selected>=0 and selected<portions.size():
			rows.append(_row(state,base,id,selected))
		elif portions.size()<state.topping_slots():
			rows.append(_row(state,base,id,-1))
		else:
			# No default replacement at capacity: expose each actual occupied slot.
			for index in portions.size():
				rows.append(_row(state,base,id,index))
	else:
		rows.append(_row(state,base,id,-1))
	return {"error":"","base":base,"rows":rows}


static func _row(state: Game, base: Dictionary, id: String, replacement: int) -> Dictionary:
	var next: Dictionary=base.duplicate(true)
	var slot: String=id.get_slice("_",0)
	var title: String="%s → %s" % [Catalog.find(str(base[slot]))["name"],Catalog.find(id)["name"]] if slot!="topping" else "한 분량 추가"
	if slot=="topping":
		var portions: Array=Catalog.toppings_of(base)
		if replacement>=0:
			title="%d번 %s 교체" % [replacement+1,Catalog.find(str(portions[replacement]))["name"]]
			portions[replacement]=id
		else:
			portions.append(id)
		next["toppings"]=Catalog.canonical_toppings(portions)
	else:
		next[slot]=id
	var before: Dictionary=Evaluator.build_profile(base)
	var after: Dictionary=Evaluator.build_profile(next)
	var changes: Array[String]=[]
	var axes: Array=[]
	for axis in Catalog.AXES:
		var delta: int=int(after[axis])-int(before[axis])
		axes.append({"id":axis,"name":Catalog.AXIS_NAMES[axis],"before":before[axis],"after":after[axis],"delta":delta})
		if delta!=0: changes.append("%s %+d" % [Catalog.AXIS_NAMES[axis],delta])
	var samples: Array=[]
	for ingredient in Catalog.item_ids(next):
		if not Catalog.is_farmed(ingredient): continue
		var exists: bool=false
		for sample in samples:
			if sample["id"]==ingredient:
				sample["needed"]+=1
				exists=true
		if not exists:
			samples.append({"id":ingredient,"needed":1,"stock":state.sample_stock(ingredient)})
	var directions: Array=[]
	for definition in Directions.catalog():
		if id in definition["requires"]:
			directions.append({"id":definition["id"],"title":definition["title"],"assessment":Directions.assess(str(definition["id"]),next)})
	var knowledge: Dictionary=state.recipe_knowledge(next)
	return {"config":next,"title":title,"replacement":replacement,"axes":axes,
		"flavor":" · ".join(changes) if not changes.is_empty() else "맛 축 변화 없음",
		"before_cost":Evaluator.unit_cost(base),"after_cost":Evaluator.unit_cost(next),
		"before_seconds":Evaluator.prep_seconds(base),"after_seconds":Evaluator.prep_seconds(next),
		"known":knowledge["known"],"compat":knowledge["compat"],"samples":samples,"directions":directions,
		"sample_error":state.sample_check(next)["error"],"changed":not Check.same_config(base,next)}


## Component IDs have stable slot prefixes, including sampled ingredients.
static func slot_key(id: String) -> String:
	return id.get_slice("_",0)
