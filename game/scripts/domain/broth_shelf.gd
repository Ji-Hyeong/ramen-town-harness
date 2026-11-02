extends RefCounted
## Working notes and completed ownership are separate. Archival never removes
## a formula, changes its index or invalidates an immutable historical menu.
const Check=preload("res://scripts/domain/data_check.gd")
const ACTIVE_LIMIT: int=60
const OWNED_LIMIT: int=300

static func empty_state() -> Dictionary:
	return {"archived":[]}

static func key(recipe: Dictionary) -> String:
	return JSON.stringify(recipe,"",true).sha256_text()

static func archived(state: Dictionary,recipe: Dictionary) -> bool:
	return state["archived"].has(key(recipe))

static func active_count(state: Dictionary,recipes: Array) -> int:
	return recipes.size()-state["archived"].size()

static func parse(raw: Variant,recipes: Array) -> Dictionary:
	var bad: Dictionary={"ok":false,"message":"육수 보관함 저장이 올바르지 않아요.","state":{}}
	if typeof(raw)!=TYPE_DICTIONARY or Check.keys_error(raw,["archived"],"육수 보관함")!="" or typeof(raw["archived"])!=TYPE_ARRAY or recipes.size()>OWNED_LIMIT:return bad
	var owned: Dictionary={}
	for row in recipes:owned[key(row["recipe"])]=true
	var seen: Dictionary={}
	for id in raw["archived"]:
		if typeof(id)!=TYPE_STRING or not owned.has(id) or seen.has(id):return bad
		seen[id]=true
	var ordered: Array=[]
	for row in recipes:
		var id: String=key(row["recipe"])
		if seen.has(id):ordered.append(id)
	if ordered!=raw["archived"] or recipes.size()-ordered.size()>ACTIVE_LIMIT:return bad
	return {"ok":true,"message":"","state":{"archived":ordered}}

static func change(state: Dictionary,recipes: Array,index: int,to_archive: bool) -> Dictionary:
	if index<0 or index>=recipes.size():return {"ok":false,"message":"보관할 육수를 다시 골라 주세요."}
	var id: String=key(recipes[index]["recipe"])
	if state["archived"].has(id)==to_archive:return {"ok":false,"message":"이미 보관한 육수예요." if to_archive else "이미 작업 노트에 있어요."}
	if not to_archive and active_count(state,recipes)>=ACTIVE_LIMIT:return {"ok":false,"message":"작업 노트가 가득 찼어요. 육수 하나를 보관한 뒤 꺼내 주세요."}
	var selected: Array=state["archived"].duplicate()
	if to_archive:selected.append(id)
	else:selected.erase(id)
	# Canonical order follows immutable ownership, never the current UI page.
	var ordered: Array=[]
	for row in recipes:
		var owned_id: String=key(row["recipe"])
		if selected.has(owned_id):ordered.append(owned_id)
	return {"ok":true,"message":"육수를 보관했어요. 메뉴와 배합은 그대로예요." if to_archive else "육수를 작업 노트로 꺼냈어요.","state":{"archived":ordered}}
