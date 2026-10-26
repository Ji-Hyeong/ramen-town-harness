extends RefCounted
## A formula stores player choices only. Product values are derived on demand,
## keeping previews, immutable menu witnesses and actual service in agreement.
const Methods=preload("res://scripts/domain/recipe_process.gd")
const MAX_RECIPES:=60
const FIELDS: Array[String]=["flour","water","cut","method"]
const FLOURS: Array=[
	{"id":"wheat","name":"중력 밀가루","cost":230,"chew":0,"aroma":0,"desc":"가벼운 식감의 기본 가루. 비용이 적고 향이 담백해요."},
	{"id":"strong","name":"강력 밀가루","cost":320,"chew":1,"aroma":-1,"desc":"식감 +1 · 향 -1. 탄력이 있지만 가격도 올라가요."},
	{"id":"buckwheat","name":"산메밀 배합분","cost":480,"chew":0,"aroma":2,"source":"noodle_buckwheat","desc":"향 +2. 산골에서 채집한 메밀을 밀가루와 섞은 가루예요."},
]
const WATERS: Array=[
	{"id":"clear","name":"맑은 배합수","cost":0,"chew":0,"desc":"담백한 기본 배합수. 추가 비용이 없어요."},
	{"id":"alkaline","name":"간수 배합수","cost":60,"chew":1,"desc":"식감 +1 · 한 그릇 +60원. 탄력을 더해요."},
]
const CUTS: Array=[
	{"id":"thin","name":"가는 직면","cost":0,"seconds":40,"chew":3},
	{"id":"medium","name":"중간 물결면","cost":50,"seconds":70,"chew":5},
	{"id":"thick","name":"굵은 꼬불면","cost":150,"seconds":100,"chew":7},
]

static func options(field: String) -> Array:
	return FLOURS.duplicate(true) if field=="flour" else (WATERS.duplicate(true) if field=="water" else CUTS.duplicate(true))

static func option(field: String, id: String) -> Dictionary:
	for row in options(field):
		if row["id"]==id: return row
	return {}

static func empty_state(legacy: bool=false) -> Dictionary:
	return {"formula":{"flour":"wheat","water":"clear","cut":"thin","method":"standard"},"recipes":[],"legacy":legacy}

static func canonical(raw: Dictionary) -> Dictionary:
	var out: Dictionary={}
	for key in FIELDS: out[key]=raw[key]
	return out

static func error(raw: Variant, rank: int=3, discovered: Array=[], check_source: bool=false) -> String:
	if typeof(raw)!=TYPE_DICTIONARY or raw.size()!=FIELDS.size(): return "제면 배합 구조가 올바르지 않아요."
	for field in FIELDS:
		if not raw.has(field) or typeof(raw[field])!=TYPE_STRING: return "제면 재료와 방식을 확인해 주세요."
		if field!="method" and option(field,raw[field]).is_empty(): return "알 수 없는 제면 재료예요."
	var method: Dictionary=Methods.method("noodle",raw["method"])
	if method.is_empty() or int(method["rank"])>rank: return "이 반죽·숙성 방식에 필요한 랭크가 없어요."
	if raw["flour"]=="buckwheat" and check_source and (rank<3 or not discovered.has("noodle_buckwheat")):
		return "랭크3 산골에서 메밀 연구 샘플을 먼저 구해 주세요."
	return ""

static func base_id(raw: Dictionary) -> String:
	return "noodle_buckwheat" if raw["flour"]=="buckwheat" else "noodle_"+str(raw["cut"])

static func product(raw: Dictionary) -> Dictionary:
	var flour: Dictionary=option("flour",raw["flour"])
	var water: Dictionary=option("water",raw["water"])
	var cut: Dictionary=option("cut",raw["cut"])
	return {"id":base_id(raw),"name":("산메밀 " if raw["flour"]=="buckwheat" else ("탄력 " if raw["flour"]=="strong" else "자가제 "))+str(cut["name"]),
		"cost":int(flour["cost"])+int(water["cost"])+int(cut["cost"]),"seconds":int(cut["seconds"]),
		"axes":{"chew":int(cut["chew"])+int(flour["chew"])+int(water["chew"]),"aroma":int(flour["aroma"])},
		"desc":str(flour["name"])+" · "+str(water["name"])+" · "+str(Methods.method("noodle",raw["method"])["name"])}

static func contains(recipes: Array, recipe: Dictionary) -> bool:
	for row in recipes:
		if row["recipe"]==canonical(recipe): return true
	return false

## Persist no elapsed time or cached stats. Dates accept JSON whole numbers,
## but unknown fields, unearned sources and duplicate completed formulas fail.
static func state_error(raw: Variant, rank: int, discovered: Array, day: int) -> String:
	if typeof(raw)!=TYPE_DICTIONARY or raw.size()!=3: return "제면 개발실 저장 구조가 올바르지 않아요."
	for key in ["formula","recipes","legacy"]:
		if not raw.has(key): return "제면 개발실 항목이 빠졌어요."
	if typeof(raw["legacy"])!=TYPE_BOOL or typeof(raw["recipes"])!=TYPE_ARRAY or raw["recipes"].size()>MAX_RECIPES: return "제면 기록 구조가 올바르지 않아요."
	var err: String=error(raw["formula"],rank,discovered,true)
	if err!="": return err
	var seen: Array=[]
	for entry in raw["recipes"]:
		if typeof(entry)!=TYPE_DICTIONARY or entry.size()!=2 or not entry.has("recipe") or not entry.has("day"): return "완성 면 기록이 올바르지 않아요."
		if typeof(entry["day"]) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(entry["day"])) or float(entry["day"])!=floorf(float(entry["day"])) or entry["day"]<1 or entry["day"]>day: return "제면 개발일이 올바르지 않아요."
		err=error(entry["recipe"],rank,discovered,true)
		if err!="": return err
		if seen.has(entry["recipe"]): return "제면 개발 기록이 중복됐어요."
		seen.append(entry["recipe"])
	return ""
