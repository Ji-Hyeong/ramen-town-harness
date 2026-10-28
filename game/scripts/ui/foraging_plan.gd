extends RefCounted
## 재료 채집 목표의 읽기 전용 투영. RecipeDirections 를 현재 GameState 의 공개 조회로만 읽어
## "어떤 재료가, 어디서, 지금 가능한지"를 보여 준다. 새 저장/규칙/보상은 없고 상태를 절대 바꾸지 않는다.
##
## 재료마다 서로 다른 세 가지를 따로 센다:
##  - 공급처 발견: 지역 공급처 두 곳을 찾는 영구 해금(탐험). 두 곳을 모두 찾기 전에는 길이 "supplier".
##  - 연구 샘플: 채집으로 얻고 시식 때 소모되는 재고. 두 곳을 모두 찾은 뒤의 길은 "sample".
##  - 완성품: 개발실에서 이미 만든 육수/면(불변). 샘플 재고가 0이어도 그릇에 담을 수 있다.
## 출발 가능/이유/비용은 GameState 의 공개 review 를 그대로 옮긴다(여기서 새로 계산하거나 우회하지 않는다).

const Directions = preload("res://scripts/domain/recipe_directions.gd")
const Catalog = preload("res://scripts/domain/ingredient_catalog.gd")
const Exploration = preload("res://scripts/domain/ingredient_exploration.gd")
const Broth = preload("res://scripts/domain/broth_workshop.gd")
const Noodle = preload("res://scripts/domain/noodle_workshop.gd")
const Market = preload("res://scripts/domain/market_foraging.gd")
const Harbor = preload("res://scripts/domain/harbor_foraging.gd")
const Mountain = preload("res://scripts/domain/mountain_foraging.gd")

## describe 가 상태에서 읽는 공개 조회 전부. 하나라도 없으면 모양이 다른 입력으로 보고 오류를 돌려준다.
const REQUIRED_METHODS: Array = ["rank", "records", "is_discovered", "ingredient_unlocked", "sample_stock", "exploration_region",
	"foraging_review", "harbor_foraging_review", "mountain_foraging_review", "broth_review", "noodle_review",
	"service_active", "craft_active", "exploration_active"]
const SAMPLE_REVIEWS: Dictionary = {"market": "foraging_review", "harbor": "harbor_foraging_review", "mountain": "mountain_foraging_review"}
## 채집 샘플로 얻고 시식 때 소모되는 재료. 나머지는 공급처를 찾으면 영구히 열린다.
const FARMED: Array = ["oil_roasted_sesame", "topping_citrus_peel", "broth_roasted_sardine", "topping_scallop", "noodle_buckwheat", "topping_grilled_shiitake"]
const MODE_SUPPLIER: String = "supplier"
const MODE_SAMPLE: String = "sample"


## 방향 하나의 계획. 오류가 있으면 error 가 비어 있지 않고 나머지는 빈 값이다.
static func describe(state: Object, direction_id: String) -> Dictionary:
	var out: Dictionary = _empty(direction_id)
	var problem: String = _state_error(state)
	if problem != "":
		out["error"] = problem
		return out
	var definition: Dictionary = Directions.find(direction_id)
	if definition.is_empty():
		out["error"] = "알 수 없는 실험 방향이에요."
		return out
	out["title"] = str(definition["title"])
	out["category"] = str(definition.get("category","regional"))
	out["brief"] = str(definition["brief"])
	out["source"] = str(definition["source"])
	out["slot"] = str(definition["slot"])
	out["ingredient"] = str(definition["ingredient"])
	# 완료 표시는 노트에 남은 유료 시식 기록만 증명한다. 삭제된 기록은 완료로 세지 않는다.
	out["tested"] = Directions.tested_ids(state.call("records")).has(direction_id)
	var rows: Array = []
	var focus: String = ""
	for ingredient_id in definition["requires"]:
		var row: Dictionary = _row(state, definition, str(ingredient_id))
		if str(row["error"]) != "":
			out["error"] = str(row["error"])
			return out
		# 준비됨은 새 시식이 실제로 쓸 샘플이 있다는 뜻이다. 완성품이 있다는 사실과는 별개다.
		if focus == "" and not bool(row["sample_ready"]):
			focus = str(row["id"])
		rows.append(row)
	out["ingredients"] = rows
	out["focus"] = focus
	out["ready"] = focus == ""
	return out


## 기존 목록 순서의 모든 방향. 잘못된 상태도 항목별 명시적 오류로 보고한다.
static func catalog(state: Object) -> Array:
	var out: Array = []
	for definition in Directions.catalog():
		out.append(describe(state, str(definition["id"])))
	return out


static func _empty(direction_id: String) -> Dictionary:
	return {"error": "", "id": direction_id, "title": "", "category":"regional", "brief": "", "source": "", "slot": "", "ingredient": "",
		"tested": false, "ready": false, "focus": "", "ingredients": []}


static func _state_error(state: Object) -> String:
	if state == null or not is_instance_valid(state):
		return "게임 상태가 필요해요."
	for method in REQUIRED_METHODS:
		if not state.has_method(method):
			return "올바른 게임 상태가 아니에요."
	return ""


static func _row(state: Object, definition: Dictionary, ingredient_id: String) -> Dictionary:
	var item: Dictionary = Catalog.find(ingredient_id)
	var region_id: String = str(item.get("region", "market"))
	var region: Dictionary = Exploration.find_region(region_id)
	var suppliers: Array = region["ingredients"]
	var found: int = 0
	for supplier in suppliers:
		if bool(state.call("is_discovered", str(supplier))):
			found += 1
	# 공급처를 모두 찾기 전에는 어느 재료든 길이 공급처 탐험이다(샘플 채집은 그 뒤에만 열린다).
	var mode: String = MODE_SAMPLE if found >= suppliers.size() else MODE_SUPPLIER
	var route: Dictionary = _route(state, mode, region_id)
	var slot: String = str(definition["slot"])
	var develops: bool = str(definition["ingredient"]) == ingredient_id and (slot == "broth" or slot == "noodle")
	var stock: int = int(state.call("sample_stock", ingredient_id))
	var archive: Dictionary = _prepared(state, slot, ingredient_id) if develops else {"count": 0, "error": ""}
	var prepared_count: int = int(archive["count"])
	var unlocked: bool = bool(state.call("ingredient_unlocked", ingredient_id))
	# 채집 재료의 unlocked 는 한 번 알고 나면 샘플을 다 써도 true 로 남는다. 새 시식이 실제로 쓰는 것은 재고뿐이다.
	var farmed: bool = FARMED.has(ingredient_id)
	var required: int = maxi(1, _draft_count(state, ingredient_id)) if farmed else 0
	var sample_ready: bool = stock >= required if farmed else unlocked
	var usable: bool = (stock >= 1 if farmed else unlocked) or prepared_count > 0
	var parts: Array[String] = []
	if mode == MODE_SUPPLIER:
		parts.append("공급처 %d/%d곳 발견" % [found, suppliers.size()])
	else:
		parts.append("연구 샘플 %d/%d개" % [stock, required])
	if prepared_count > 0:
		parts.append("완성품 %d개" % prepared_count)
	return {
		"error": str(archive["error"]),
		"farmed": farmed,
		"required_samples": required,
		"sample_ready": sample_ready,
		"id": ingredient_id,
		"name": str(item.get("short_name", item.get("name", ingredient_id))),
		"region": region_id,
		"region_name": str(region["name"]),
		"mode": mode,
		"primary": str(definition["ingredient"]) == ingredient_id,
		"develops": develops,
		"unlocked": unlocked,
		"stock": stock,
		"prepared": prepared_count > 0,
		"prepared_count": prepared_count,
		"usable": usable,
		"suppliers_found": found,
		"suppliers_total": suppliers.size(),
		"min_rank": int(region["min_rank"]),
		"source_title": str(route["title"]),
		"can_depart": bool(route["can_depart"]),
		"reason": str(route["reason"]),
		"fee": int(route["fee"]),
		"status": " · ".join(parts),
		# 완성품을 열어 보거나 담는 일과 새 시식은 별개다: 새 시식은 지금도 샘플 재고를 쓴다.
		"note": "새 시식에는 연구 샘플 %d개가 필요해요." % required if prepared_count > 0 and not sample_ready else "",
	}


## 출발 판단은 모두 공개 review 의 값이다. 탐험 길은 영업/제작 중 잠금이 review 에 없어 같은 거절 조건을 덧붙인다.
static func _route(state: Object, mode: String, region_id: String) -> Dictionary:
	if mode == MODE_SAMPLE:
		var review: Dictionary = state.call(str(SAMPLE_REVIEWS[region_id]))
		return {"title": _sample_name(region_id), "can_depart": bool(review["can_start"]),
			"reason": str(review["reason"]), "fee": int(review["fee"])}
	var view: Dictionary = state.call("exploration_region", region_id)
	var can_depart: bool = bool(view["can_start"])
	var reason: String = str(view["reason"])
	if can_depart and bool(state.call("service_active")):
		can_depart = false
		reason = "영업 중에는 출발할 수 없어요. 영업을 마친 뒤 오세요."
	elif can_depart and bool(state.call("craft_active")):
		can_depart = false
		reason = "육수나 면을 만드는 중이에요. 마친 뒤 출발하세요."
	elif can_depart and bool(state.call("exploration_active")):
		can_depart = false
		reason = "진행 중인 채집을 먼저 마치세요."
	return {"title": "%s 탐험" % str(view["name"]), "can_depart": can_depart, "reason": reason, "fee": int(view["fee"])}


static func _sample_name(region_id: String) -> String:
	var spec: Dictionary = Harbor.SPEC if region_id == "harbor" else (Mountain.SPEC if region_id == "mountain" else Market.SPEC)
	return str(spec["name"])


## 현재 초안이 이 재료를 담은 횟수(반복 토핑 포함). 초안을 읽을 수 없으면 0 이다.
static func _draft_count(state: Object, ingredient_id: String) -> int:
	var draft: Variant = state.get("draft_config")
	if typeof(draft) != TYPE_DICTIONARY:
		return 0
	for slot in Catalog.SLOTS:
		if slot != Catalog.TOPPING_SLOT and not (draft as Dictionary).has(slot):
			return 0
	return Catalog.item_ids(draft).count(ingredient_id)


## 이 재료가 주재료인 완성 육수/면의 수. 개발실이 이미 만든 불변 배합만 센다.
## 기록 구조가 올바르지 않거나 정규형이 아니면 조용히 건너뛰지 않고 오류를 돌려준다.
static func _prepared(state: Object, slot: String, ingredient_id: String) -> Dictionary:
	var review: Variant = state.call("broth_review") if slot == "broth" else state.call("noodle_review")
	if typeof(review) != TYPE_DICTIONARY or typeof((review as Dictionary).get("recipes")) != TYPE_ARRAY:
		return {"count": 0, "error": "개발한 %s 기록을 읽을 수 없어요." % ("육수" if slot == "broth" else "면")}
	var count: int = 0
	for entry in review["recipes"]:
		if typeof(entry) != TYPE_DICTIONARY or typeof(entry.get("recipe")) != TYPE_DICTIONARY:
			return {"count": 0, "error": "개발한 %s 기록 구조가 올바르지 않아요." % ("육수" if slot == "broth" else "면")}
		var recipe: Dictionary = entry["recipe"]
		var problem: String = Broth.error(recipe) if slot == "broth" else Noodle.error(recipe)
		if problem != "":
			return {"count": 0, "error": problem}
		var canonical: Dictionary = Broth.canonical(recipe) if slot == "broth" else Noodle.canonical(recipe)
		if canonical != recipe:
			return {"count": 0, "error": "개발한 %s 기록이 정규형이 아니에요." % ("육수" if slot == "broth" else "면")}
		var base: String = Broth.base_id(recipe) if slot == "broth" else Noodle.base_id(recipe)
		if base == ingredient_id:
			count += 1
	return {"count": count, "error": ""}
