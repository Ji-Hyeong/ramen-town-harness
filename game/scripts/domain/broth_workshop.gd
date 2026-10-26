extends RefCounted
## Raw ingredients are saved, never a trusted cached score or product value.
## Rebuild every broth from this catalog so records, service and previews agree.
const Methods = preload("res://scripts/domain/recipe_process.gd")
const MAX_RECIPES := 60
const DATA: Array = [
	{"id":"pork_bone","name":"돼지뼈","category":"뼈","icon":"broth_tonkotsu","cost":480,"seconds":24,"base":true,"axes":{"rich":5,"aroma":0}},
	{"id":"chicken_bone","name":"닭뼈","category":"뼈","icon":"broth_chicken","cost":330,"seconds":16,"base":true,"axes":{"rich":2,"aroma":1}},
	{"id":"kelp","name":"다시마","category":"해산물","icon":"topping_nori","cost":160,"seconds":8,"base":true,"axes":{"salt":1,"aroma":2}},
	{"id":"onion","name":"양파","category":"향채","icon":"topping_sprouts","cost":80,"seconds":4,"base":false,"axes":{"rich":1,"aroma":1}},
	{"id":"ginger","name":"생강","category":"향채","icon":"oil_scallion","cost":90,"seconds":5,"base":false,"axes":{"rich":-1,"aroma":2,"spice":1}},
	{"id":"garlic","name":"마늘","category":"향채","icon":"oil_garlic","cost":120,"seconds":6,"base":false,"axes":{"rich":1,"aroma":2,"spice":1}},
	{"id":"clam","name":"바지락","category":"해산물","icon":"broth_clam","cost":300,"seconds":14,"base":true,"source":"broth_clam","source_name":"항구 · 조개 공급처","axes":{"rich":1,"salt":1,"aroma":3}},
	{"id":"shiitake","name":"말린 표고","category":"향채","icon":"topping_mushroom","cost":150,"seconds":9,"base":false,"source":"topping_mushroom","source_name":"산골 · 표고 공급처","axes":{"rich":1,"aroma":3}},
	{"id":"sardine","name":"구운 정어리","category":"해산물","icon":"broth_roasted_sardine","cost":250,"seconds":18,"base":true,"source":"broth_roasted_sardine","source_name":"아침 항구 · 정어리 채집","axes":{"rich":1,"salt":2,"aroma":4}},
]
const AXES: Array[String] = ["rich","salt","aroma","chew","spice"]

static func material(id: String) -> Dictionary:
	for row in DATA:
		if row["id"] == id: return row.duplicate(true)
	return {}

static func capacity(rank: int) -> int:
	return 2 + clampi(rank,1,3)

## Historical supplier IDs remain stable for saved recipes and sample ledgers.
## New UI handoffs resolve them to raw materials instead of a premade swap.
static func material_for_broth(id: String) -> Dictionary:
	var mapping: Dictionary={"broth_tonkotsu":"pork_bone","broth_chicken":"chicken_bone","broth_dashi":"kelp","broth_clam":"clam","broth_roasted_sardine":"sardine"}
	return material(str(mapping.get(id,"")))

static func empty_state(legacy: bool = false) -> Dictionary:
	return {"ingredients":[],"method":"standard","recipes":[],"legacy":legacy}

static func canonical(raw: Dictionary) -> Dictionary:
	var ids: Array = raw["ingredients"].duplicate()
	ids.sort()
	return {"ingredients":ids,"method":raw["method"]}

static func error(raw: Variant, rank: int = 3, discovered: Array = [], check_source: bool = false, allow_empty: bool = false) -> String:
	if typeof(raw) != TYPE_DICTIONARY or raw.size()!=2 or not raw.has("ingredients") or not raw.has("method"):
		return "육수 배합 구조가 올바르지 않아요."
	if typeof(raw["ingredients"])!=TYPE_ARRAY or typeof(raw["method"])!=TYPE_STRING:
		return "육수 원재료와 우림 방식을 확인해 주세요."
	var method: Dictionary=Methods.method("broth",raw["method"])
	if method.is_empty() or rank<int(method["rank"]): return "이 우림 방식에 필요한 랭크가 없어요."
	var ids: Array=raw["ingredients"]
	if ids.size()>capacity(rank): return "육수 배합은 지금 %d칸까지예요." % capacity(rank)
	var has_base: bool=false
	for id in ids:
		if typeof(id)!=TYPE_STRING: return "육수 원재료 번호가 올바르지 않아요."
		var row: Dictionary=material(id)
		if row.is_empty(): return "알 수 없는 육수 원재료예요."
		if check_source and row.has("source") and not discovered.has(row["source"]):
			return "%s에서 %s 공급처를 먼저 찾아 주세요." % [row["source_name"],row["name"]]
		has_base=has_base or bool(row["base"])
	# One sardine research sample represents one portion. It is still consumed
	# by the existing successful-ramen-tasting ledger, never a second hidden fee.
	if ids.count("sardine")>1: return "정어리 연구 샘플은 육수 한 배합에 한 분량만 써요."
	if not allow_empty and not has_base: return "돼지뼈·닭뼈·해산물 중 주재료를 하나 이상 넣어 주세요."
	return ""

static func base_id(raw: Dictionary) -> String:
	var ids: Array=raw["ingredients"]
	if ids.has("sardine"): return "broth_roasted_sardine"
	if ids.has("pork_bone") and ids.count("pork_bone")>=ids.count("chicken_bone"): return "broth_tonkotsu"
	if ids.has("chicken_bone"): return "broth_chicken"
	if ids.has("clam"): return "broth_clam"
	return "broth_dashi"

static func product(raw: Dictionary) -> Dictionary:
	var axes: Dictionary={"rich":0,"salt":0,"aroma":0,"chew":0,"spice":0}
	var cost: int=0
	var seconds: int=0
	var names: Array[String]=[]
	for id in raw["ingredients"]:
		var row: Dictionary=material(id)
		cost+=int(row["cost"])
		seconds+=int(row["seconds"])
		for axis in row["axes"]: axes[axis]+=int(row["axes"][axis])
		if not names.has(str(row["name"])): names.append(str(row["name"]))
	# Different ingredient families create explainable combinations with costs:
	# all-bone batches are richer but take longer; kelp preserves a clear base.
	var combo: String=""
	if raw["ingredients"].has("pork_bone") and raw["ingredients"].has("chicken_bone"):
		axes["rich"]+=1; seconds+=4; combo="뼈의 겹맛 · 진함 +1 / 준비 +4초"
	elif raw["ingredients"].has("kelp") and raw["ingredients"].has("shiitake"):
		axes["aroma"]+=1; cost+=40; combo="바다와 숲 · 향 +1 / 한 그릇 +40원"
	for axis in AXES: axes[axis]=clampi(int(axes[axis]),0,10)
	var primary: String="돼지뼈" if base_id(raw)=="broth_tonkotsu" else ("닭" if base_id(raw)=="broth_chicken" else ("조개" if base_id(raw)=="broth_clam" else ("정어리" if base_id(raw)=="broth_roasted_sardine" else "다시마")))
	var title: String=primary+(" 겹맛탕" if raw["ingredients"].has("pork_bone") and raw["ingredients"].has("chicken_bone") else (" 향채탕" if raw["ingredients"].has("ginger") or raw["ingredients"].has("garlic") else " 우림탕"))
	return {"id":base_id(raw),"name":title,"cost":cost,"seconds":seconds,"axes":axes,"combo":combo,
		"desc":ingredients_text(raw)+" / "+str(Methods.method("broth",raw["method"])["name"])}

## Quantities remain visible even when the product has a short display name.
static func ingredients_text(raw: Dictionary) -> String:
	var parts: Array[String]=[]
	var seen: Array=[]
	for id in raw["ingredients"]:
		if seen.has(id): continue
		seen.append(id)
		var count: int=raw["ingredients"].count(id)
		parts.append(str(material(id)["name"])+(" ×%d" % count if count>1 else ""))
	return " + ".join(parts)


static func contains(recipes: Array, recipe: Dictionary) -> bool:
	for row in recipes:
		if row["recipe"] == canonical(recipe): return true
	return false

## Validate the persisted workshop and cross-check saved recipes at the current
## rank/supplier state. The UI never saves cached product stats or elapsed work.
static func state_error(raw: Variant, rank: int, discovered: Array, day: int) -> String:
	if typeof(raw)!=TYPE_DICTIONARY or raw.size()!=4:
		return "육수 개발실 저장 구조가 올바르지 않아요."
	for key in ["ingredients","method","recipes","legacy"]:
		if not raw.has(key): return "육수 개발실 항목이 빠졌어요."
	if typeof(raw["legacy"])!=TYPE_BOOL or typeof(raw["recipes"])!=TYPE_ARRAY or raw["recipes"].size()>MAX_RECIPES:
		return "육수 개발 기록 구조가 올바르지 않아요."
	var draft: Dictionary={"ingredients":raw["ingredients"],"method":raw["method"]}
	var err: String=error(draft,rank,discovered,true,true)
	if err!="": return err
	var seen: Array=[]
	for entry in raw["recipes"]:
		if typeof(entry)!=TYPE_DICTIONARY or entry.size()!=2 or not entry.has("recipe") or not entry.has("day"):
			return "완성 육수 기록이 올바르지 않아요."
		if typeof(entry["day"]) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(entry["day"])) or float(entry["day"])!=floorf(float(entry["day"])) or entry["day"]<1 or entry["day"]>day:
			return "육수 개발일이 올바르지 않아요."
		err=error(entry["recipe"],rank,discovered,true)
		if err!="": return err
		if entry["recipe"]!=canonical(entry["recipe"]) or seen.has(entry["recipe"]): return "육수 개발 기록이 중복되거나 정렬되지 않았어요."
		seen.append(entry["recipe"])
	return ""
