extends RefCounted
## 재료 탐험: 지역 선택 -> 갈래 만남 2번 -> 재료 발견 -> 영수증 수령.
##
## 이 파일은 "카탈로그 + 순수 상태 전이"다. 자금/일차/등급/영업 잠금은 GameState가 쥐고, 여기서는 호출자가 넘긴 값(rank, day, wallet)으로
## 검증만 하고 "새 탐험 상태 딕셔너리"를 돌려준다(입력 상태는 절대 바꾸지 않는다). GameState는 반환값을 받아 자금 차감과 상태 교체를
## 한 호출 안에서 함께 하므로 한쪽만 반영되는 중간 상태가 없다.
##
## 규칙 요약 (모두 이 파일의 데이터/함수로 계산하고 UI는 그대로 보여 주기만 한다):
##  - 지역 3곳이 가게 등급 1/2/3으로 열린다. 출발 비용(fee)은 출발 때 한 번 내고, 선택지에 붙은 추가 비용은 그 선택을 누를 때 한 번 낸다.
##  - 영업 완료일마다 최대 1번 출발한다(일차 day 하나에 출발 하나, 지역 무관). 포기해도 그날 몫과 낸 비용은 돌아오지 않는다.
##  - 만남 2번: 첫 만남 선택이 두 번째 만남을 정한다(갈래). 두 번째 선택이 발견 재료를 정하고, 결과 단계(result)에서 멈춘다.
##  - 결과 단계에서만 collect()가 가능하고 collect()는 활성 탐험을 지우므로 같은 결과를 두 번 받을 수 없다(명시적 결과 경계).
##  - 보상은 "재료 영구 개방"뿐이다. 자금/등급/연구/남은 재고(소모품) 보상은 없다. 이미 발견한 재료로 이어지는 선택은 새 발견이 없다고 미리 표시한다.
##  - 한 지역의 재료를 모두 발견하면 그 지역은 더 출발할 수 없다(의미 없는 반복 비용을 받지 않는다).
##  - 영업/시식/성장 같은 다른 행동과의 잠금은 GameState가 건다(탐험 중에는 메뉴 편집/시식/영업/연구/성장이 거부된다).

const Catalog = preload("res://scripts/domain/ingredient_catalog.gd")
const Check = preload("res://scripts/domain/data_check.gd")
const Growth = preload("res://scripts/domain/shop_growth.gd")

## 활성 탐험의 단계. 경로(path) 길이는 단계와 항상 일치한다: choice_1 -> 0개, choice_2 -> 1개, result -> 2개.
const STAGE_FIRST: String = "choice_1"
const STAGE_SECOND: String = "choice_2"
const STAGE_RESULT: String = "result"
const STAGES: Array = ["choice_1", "choice_2", "result"]

const OUTCOME_FINISHED: String = "finished"
const OUTCOME_RETIRED: String = "retired"

## 저장하는 영수증(기록) 수의 상한. 더 오래된 것부터 잘려 나가고, 누적 횟수(completed/retired)와 발견 목록은 잘리지 않는다.
const MAX_HISTORY: int = 12

const STATE_KEYS: Array = ["discovered", "last_departure_day", "completed", "retired", "active", "history"]
const DISCOVERED_KEYS: Array = ["id", "region", "day"]
const ACTIVE_KEYS: Array = ["region", "day", "stage", "fee", "extra", "path"]
const RECEIPT_KEYS: Array = ["day", "region", "outcome", "fee", "extra", "path", "ingredient", "new"]

## 지역. min_rank = 갈 수 있는 가게 등급, fee = 출발 비용(원), start = 첫 만남 id, ingredients = 이 지역에서 발견하는 재료
## (ingredient_catalog.gd 의 DISCOVERY_ITEMS[*].region 과 일치해야 하며 시험이 확인한다).
const REGIONS: Array = [
	{"id": "market", "name": "새벽 장터", "min_rank": 1, "fee": 3000, "start": "market_gate",
		"summary": "가게 근처에서 새벽마다 서는 골목 장터예요. 절임과 과일 간이 모여요.",
		"ingredients": ["tare_plum", "topping_pickle"]},
	{"id": "harbor", "name": "아침 항구", "min_rank": 2, "fee": 6000, "start": "harbor_pier",
		"summary": "어선이 들어오는 작은 항구예요. 조개와 새우가 있어요.",
		"ingredients": ["broth_clam", "oil_shrimp"]},
	{"id": "mountain", "name": "산골 농가", "min_rank": 3, "fee": 10000, "start": "mountain_trail",
		"summary": "산초나무와 표고 농가가 있는 먼 산골이에요.",
		"ingredients": ["oil_pepper", "topping_mushroom"]},
]

## 만남. step 1 선택은 next(두 번째 만남 id)로, step 2 선택은 ingredient(발견 재료 id)로 이어진다. cost = 그 선택을 누를 때 내는 추가 비용(원).
## 선택 id는 전체에서 유일하다. 지역마다 갈래 4가지(2x2) 경로가 있고, 각 지역의 재료 2개 모두 서로 다른 두 경로 이상으로 닿는다.
const EVENTS: Array = [
	{"id": "market_gate", "region": "market", "step": 1, "title": "장터 입구",
		"text": "새벽 장터가 막 문을 열었어요. 어디부터 둘러볼까요?",
		"choices": [
			{"id": "m_ask", "label": "노점 어르신께 묻는다", "cost": 0, "next": "market_alley",
				"desc": "비용 없음. 절임 골목으로 이어져요."},
			{"id": "m_browse", "label": "과일 수레를 둘러본다", "cost": 200, "next": "market_cart",
				"desc": "시식 값 200원. 과일 수레 쪽으로 이어져요."},
		]},
	{"id": "market_alley", "region": "market", "step": 2, "title": "절임 골목",
		"text": "어르신이 절임 항아리 사이에서 손짓해요.",
		"choices": [
			{"id": "m_buy_pickle", "label": "절임 한 통을 산다", "cost": 300, "ingredient": "topping_pickle",
				"desc": "값 300원을 내고 절임 무 만드는 법을 배워요."},
			{"id": "m_hear_recipe", "label": "간 맞추는 비법을 듣는다", "cost": 0, "ingredient": "tare_plum",
				"desc": "비용 없이 매실로 간을 맞추는 법을 들어요."},
		]},
	{"id": "market_cart", "region": "market", "step": 2, "title": "과일 수레",
		"text": "수레 주인이 시식을 권하며 웃어요.",
		"choices": [
			{"id": "m_buy_plum", "label": "매실 한 상자를 산다", "cost": 500, "ingredient": "tare_plum",
				"desc": "값 500원을 내고 매실 타레를 익혀요."},
			{"id": "m_taste_pickle", "label": "곁들인 무 절임을 얻어 맛본다", "cost": 0, "ingredient": "topping_pickle",
				"desc": "비용 없이 절임 무를 맛보고 배워요."},
		]},
	{"id": "harbor_pier", "region": "harbor", "step": 1, "title": "항구 부두",
		"text": "항구는 이미 분주해요. 먼저 어디로 갈까요?",
		"choices": [
			{"id": "h_auction", "label": "새벽 경매장에 간다", "cost": 500, "next": "harbor_auction",
				"desc": "입장료 500원. 경매장으로 이어져요."},
			{"id": "h_boat", "label": "돌아오는 어선을 맞는다", "cost": 0, "next": "harbor_boat",
				"desc": "비용 없음. 선착장 어부에게 이어져요."},
		]},
	{"id": "harbor_auction", "region": "harbor", "step": 2, "title": "새벽 경매장",
		"text": "경매사가 소리 높여 값을 불러요.",
		"choices": [
			{"id": "h_bid_clam", "label": "조개 바구니에 입찰한다", "cost": 800, "ingredient": "broth_clam",
				"desc": "낙찰가 800원. 조개 맑은탕을 끓이는 법을 익혀요."},
			{"id": "h_ask_shrimp", "label": "새우 손질 자투리를 부탁한다", "cost": 0, "ingredient": "oil_shrimp",
				"desc": "비용 없이 새우 머리로 기름 내는 법을 배워요."},
		]},
	{"id": "harbor_boat", "region": "harbor", "step": 2, "title": "선착장",
		"text": "어부가 그물을 털며 말을 걸어요.",
		"choices": [
			{"id": "h_share_soup", "label": "어부의 조개탕을 얻어먹는다", "cost": 0, "ingredient": "broth_clam",
				"desc": "비용 없이 조개 맑은탕의 비결을 배워요."},
			{"id": "h_rent_tools", "label": "손질 도구를 빌려 새우를 다룬다", "cost": 400, "ingredient": "oil_shrimp",
				"desc": "대여료 400원. 새우유 내는 법을 익혀요."},
		]},
	{"id": "mountain_trail", "region": "mountain", "step": 1, "title": "산길 갈림길",
		"text": "산길이 두 갈래로 나뉘어요.",
		"choices": [
			{"id": "t_grove", "label": "초피나무 숲길로 오른다", "cost": 0, "next": "mountain_grove",
				"desc": "비용 없음. 초피나무 숲으로 이어져요."},
			{"id": "t_farm", "label": "표고 농가 길로 내려간다", "cost": 400, "next": "mountain_farm",
				"desc": "길잡이 값 400원. 표고 농가로 이어져요."},
		]},
	{"id": "mountain_grove", "region": "mountain", "step": 2, "title": "초피나무 숲",
		"text": "숲에 얼얼한 향이 가득해요.",
		"choices": [
			{"id": "g_dry_pepper", "label": "초피 열매를 따서 말린다", "cost": 0, "ingredient": "oil_pepper",
				"desc": "비용 없이 초피유 내는 법을 익혀요."},
			{"id": "g_learn_mushroom", "label": "농가로 건너가 조림을 배운다", "cost": 600, "ingredient": "topping_mushroom",
				"desc": "수업료 600원. 표고 조림을 배워요."},
		]},
	{"id": "mountain_farm", "region": "mountain", "step": 2, "title": "표고 농가",
		"text": "농부가 화로 앞에서 조림을 저어요.",
		"choices": [
			{"id": "f_learn", "label": "조림 비법을 전수받는다", "cost": 1000, "ingredient": "topping_mushroom",
				"desc": "전수비 1000원. 표고 조림을 확실히 배워요."},
			{"id": "f_pepper", "label": "농가 옆 초피나무 열매를 얻는다", "cost": 0, "ingredient": "oil_pepper",
				"desc": "비용 없이 초피유 내는 법을 얻어요."},
		]},
]


# ---------- 카탈로그 조회 ----------

static func region_ids() -> Array[String]:
	var out: Array[String] = []
	for r in REGIONS:
		out.append(str((r as Dictionary)["id"]))
	return out


static func find_region(id: String) -> Dictionary:
	for r in REGIONS:
		var d: Dictionary = r
		if str(d["id"]) == id:
			return d
	return {}


static func find_event(id: String) -> Dictionary:
	for e in EVENTS:
		var d: Dictionary = e
		if str(d["id"]) == id:
			return d
	return {}


static func find_choice(event: Dictionary, choice_id: String) -> Dictionary:
	if event.is_empty():
		return {}
	for c in event["choices"]:
		var d: Dictionary = c
		if str(d["id"]) == choice_id:
			return d
	return {}


## 발견 재료가 속한 지역 id(발견 재료가 아니면 "").
static func region_of(ingredient_id: String) -> String:
	for r in REGIONS:
		var d: Dictionary = r
		if (d["ingredients"] as Array).has(ingredient_id):
			return str(d["id"])
	return ""


static func ingredient_name(id: String) -> String:
	var item: Dictionary = Catalog.find(id)
	return str(item["name"]) if not item.is_empty() else id


## 경로(선택 id 목록, 0~2개)가 지역의 갈래를 정확히 따르는지. 길이 0은 항상 유효하다.
static func path_valid(region_id: String, path: Array) -> bool:
	var reg: Dictionary = find_region(region_id)
	if reg.is_empty() or path.size() > 2:
		return false
	var ev: Dictionary = find_event(str(reg["start"]))
	for i in path.size():
		if typeof(path[i]) != TYPE_STRING:
			return false
		var ch: Dictionary = find_choice(ev, str(path[i]))
		if ch.is_empty():
			return false
		if i == 0:
			ev = find_event(str(ch["next"]))
	return true


## 경로에 든 추가 비용 합계(유효한 경로만 의미가 있다).
static func path_cost(region_id: String, path: Array) -> int:
	var reg: Dictionary = find_region(region_id)
	if reg.is_empty():
		return 0
	var ev: Dictionary = find_event(str(reg["start"]))
	var total: int = 0
	for i in path.size():
		var ch: Dictionary = find_choice(ev, str(path[i]))
		if ch.is_empty():
			return total
		total += int(ch["cost"])
		if i == 0:
			ev = find_event(str(ch["next"]))
	return total


## 완성된 경로(2개)가 이어지는 발견 재료 id. 경로가 완성되지 않았거나 틀리면 "".
static func ingredient_for(region_id: String, path: Array) -> String:
	if path.size() != 2 or not path_valid(region_id, path):
		return ""
	var reg: Dictionary = find_region(region_id)
	var ev1: Dictionary = find_event(str(reg["start"]))
	var c1: Dictionary = find_choice(ev1, str(path[0]))
	var ev2: Dictionary = find_event(str(c1["next"]))
	var c2: Dictionary = find_choice(ev2, str(path[1]))
	return str(c2["ingredient"])


## 지금 단계에서 보여 줄 만남(결과 단계면 {}).
static func current_event(active: Dictionary) -> Dictionary:
	if active.is_empty():
		return {}
	var reg: Dictionary = find_region(str(active["region"]))
	if reg.is_empty():
		return {}
	var stage: String = str(active["stage"])
	if stage == STAGE_FIRST:
		return find_event(str(reg["start"]))
	if stage == STAGE_SECOND:
		var path: Array = active["path"]
		var c1: Dictionary = find_choice(find_event(str(reg["start"])), str(path[0]))
		return find_event(str(c1["next"]))
	return {}


# ---------- 상태 ----------

static func empty_state() -> Dictionary:
	return {
		"discovered": [],
		"last_departure_day": 0,
		"completed": 0,
		"retired": 0,
		"active": {},
		"history": [],
	}


static func discovered_ids(state: Dictionary) -> Array[String]:
	var out: Array[String] = []
	for e in state["discovered"]:
		out.append(str((e as Dictionary)["id"]))
	return out


## 구성이 아직 발견하지 못한 재료를 쓰면 그 첫 id, 아니면 "". 구성 모양은 호출자가 먼저 검증해야 한다(Check.config_error).
static func locked_in(config: Dictionary, discovered: Array) -> String:
	for id in Catalog.item_ids(config):
		if Catalog.is_discovery(id) and not discovered.has(id):
			return id
	return ""


## 재료 하나가 지금 쓸 수 있는지: 예전 재료는 언제나, 발견 재료는 발견한 뒤에만.
static func unlocked(id: String, discovered: Array) -> bool:
	return not Catalog.is_discovery(id) or discovered.has(id)


## 잠긴 재료를 어떻게 얻는지 안내(지역/등급/출발 비용). 예전 재료는 {"locked": false}.
static func lock_info(id: String, discovered: Array) -> Dictionary:
	var item: Dictionary = Catalog.find(id)
	if item.is_empty():
		return {}
	if unlocked(id, discovered):
		return {"locked": false, "id": id}
	var reg: Dictionary = find_region(region_of(id))
	return {
		"locked": true,
		"id": id,
		"region": str(reg["id"]),
		"region_name": str(reg["name"]),
		"min_rank": int(reg["min_rank"]),
		"fee": int(reg["fee"]),
		"hint": "「%s」 탐험(가게 등급 %d단계부터, 출발 비용 %s)에서 만남의 선택으로 발견할 수 있어요." % [str(reg["name"]), int(reg["min_rank"]), Growth._won(int(reg["fee"]))],
	}


static func progress(state: Dictionary) -> Dictionary:
	var ids: Array[String] = discovered_ids(state)
	var regions: Array = []
	var total: int = 0
	var obtained: int = 0
	for r in REGIONS:
		var d: Dictionary = r
		var have: int = 0
		for iid in d["ingredients"]:
			if ids.has(str(iid)):
				have += 1
		regions.append({"id": str(d["id"]), "obtained": have, "total": (d["ingredients"] as Array).size()})
		total += (d["ingredients"] as Array).size()
		obtained += have
	return {"obtained": obtained, "total": total, "regions": regions}


## 지역 한 곳의 계산된 상태(읽기 전용). status: available | active_here | active_other | locked_rank | complete | used_today | no_funds
## 우선순위는 이 순서의 역순이 아니라 아래 코드의 검사 순서를 따른다. can_start 는 status == available 일 때만 참이다.
static func region_review(state: Dictionary, region_id: String, rank: int, day: int, wallet: int) -> Dictionary:
	var reg: Dictionary = find_region(region_id)
	if reg.is_empty():
		return {}
	var ids: Array[String] = discovered_ids(state)
	var ing_views: Array = []
	var have: int = 0
	for iid in reg["ingredients"]:
		var item: Dictionary = Catalog.find(str(iid))
		var got: bool = ids.has(str(iid))
		if got:
			have += 1
		ing_views.append({"id": str(iid), "name": str(item["name"]), "slot": str(iid).split("_")[0],
			"desc": str(item["desc"]), "cost": int(item["cost"]), "seconds": int(item["seconds"]),
			"axes_text": Catalog.axes_text(item), "discovered": got})
	var total: int = (reg["ingredients"] as Array).size()
	var fee: int = int(reg["fee"])
	var min_rank: int = int(reg["min_rank"])
	var active: Dictionary = state["active"]
	var status: String = "available"
	var reason: String = ""
	if not active.is_empty():
		if str(active["region"]) == region_id:
			status = "active_here"
			reason = "이 지역을 탐험하는 중이에요. 결과를 받거나 포기해야 해요."
		else:
			status = "active_other"
			reason = "다른 지역 탐험이 진행 중이에요. 먼저 마치거나 포기하세요."
	elif rank < min_rank:
		status = "locked_rank"
		reason = "가게 등급 %d단계 「%s」부터 갈 수 있어요." % [min_rank, Growth.rank_title(min_rank)]
	elif have >= total:
		status = "complete"
		reason = "이 지역의 재료를 모두 발견했어요. 다시 가도 얻을 게 없어서 출발 비용을 받지 않아요."
	elif int(state["last_departure_day"]) == day:
		status = "used_today"
		reason = "탐험 출발은 영업을 마친 하루에 한 번뿐이에요. 오늘은 이미 출발했어요. 영업을 마치고 다음 날 다시 오세요."
	elif wallet < fee:
		status = "no_funds"
		reason = "출발 비용 %s이 필요한데 자금이 모자라요." % Growth._won(fee)
	return {
		"id": region_id, "name": str(reg["name"]), "summary": str(reg["summary"]),
		"min_rank": min_rank, "rank_title": Growth.rank_title(min_rank), "fee": fee,
		"ingredients": ing_views, "obtained": have, "total": total, "complete": have >= total,
		"status": status, "can_start": status == "available", "reason": reason,
		"rank_locked": rank < min_rank,
	}


# ---------- 상태 전이 (입력 상태는 바꾸지 않고 새 상태를 돌려준다) ----------

## 출발. 반환: {"error": String, "state": Dictionary, "fee": int}. 실패하면 error 만 채워진다.
## 이 호출이 일차 day 의 출발권을 쓴다(last_departure_day = day). 출발 비용 차감은 호출자(GameState)가 같은 호출 안에서 한다.
static func begin(state: Dictionary, region_id: String, rank: int, day: int, wallet: int) -> Dictionary:
	var rv: Dictionary = region_review(state, region_id, rank, day, wallet)
	if rv.is_empty():
		return {"error": "알 수 없는 지역이에요."}
	if not bool(rv["can_start"]):
		return {"error": str(rv["reason"])}
	var ns: Dictionary = state.duplicate(true)
	ns["last_departure_day"] = day
	ns["active"] = {"region": region_id, "day": day, "stage": STAGE_FIRST, "fee": int(rv["fee"]), "extra": 0, "path": []}
	return {"error": "", "state": ns, "fee": int(rv["fee"])}


## 선택 하나. 반환: {"error", "state", "extra": 이번에 내는 추가 비용, "choice": 선택 데이터 사본}.
## 모르는 선택 id, 현재 만남에 없는 선택, 결과 단계, 추가 비용 부족은 모두 거부(상태 불변)한다.
static func choose(state: Dictionary, choice_id: String, wallet: int) -> Dictionary:
	var active: Dictionary = state["active"]
	if active.is_empty():
		return {"error": "진행 중인 탐험이 없어요."}
	if str(active["stage"]) == STAGE_RESULT:
		return {"error": "이미 결과가 나왔어요. 결과를 받으세요."}
	var ev: Dictionary = current_event(active)
	var ch: Dictionary = find_choice(ev, choice_id)
	if ch.is_empty():
		return {"error": "지금 만남에 없는 선택이에요."}
	var cost: int = int(ch["cost"])
	if cost > wallet:
		return {"error": "추가 비용 %s이 필요한데 자금이 모자라요." % Growth._won(cost)}
	var ns: Dictionary = state.duplicate(true)
	var na: Dictionary = ns["active"]
	(na["path"] as Array).append(choice_id)
	na["extra"] = int(na["extra"]) + cost
	na["stage"] = STAGE_SECOND if int(ev["step"]) == 1 else STAGE_RESULT
	return {"error": "", "state": ns, "extra": cost, "choice": ch.duplicate(true)}


## 결과 수령(보상 지급). 결과 단계에서만 가능하고 활성 탐험을 지우므로 두 번 받을 수 없다.
## 반환: {"error", "state", "receipt", "ingredient": id, "new": bool}.
static func collect(state: Dictionary) -> Dictionary:
	var active: Dictionary = state["active"]
	if active.is_empty():
		return {"error": "받을 결과가 없어요."}
	if str(active["stage"]) != STAGE_RESULT:
		return {"error": "아직 결과가 나오지 않았어요. 만남을 끝까지 진행하세요."}
	var iid: String = ingredient_for(str(active["region"]), active["path"])
	if iid == "":
		return {"error": "탐험 기록이 올바르지 않아 결과를 받을 수 없어요."}
	var ns: Dictionary = state.duplicate(true)
	var is_new: bool = not discovered_ids(state).has(iid)
	if is_new:
		(ns["discovered"] as Array).append({"id": iid, "region": str(active["region"]), "day": int(active["day"])})
	var receipt: Dictionary = {
		"day": int(active["day"]), "region": str(active["region"]), "outcome": OUTCOME_FINISHED,
		"fee": int(active["fee"]), "extra": int(active["extra"]), "path": (active["path"] as Array).duplicate(),
		"ingredient": iid, "new": is_new,
	}
	_push_history(ns, receipt)
	ns["completed"] = int(ns["completed"]) + 1
	ns["active"] = {}
	return {"error": "", "state": ns, "receipt": receipt.duplicate(true), "ingredient": iid, "new": is_new}


## 포기. 결과 전(만남 단계)에만 가능하다. 낸 비용과 그날의 출발권은 돌아오지 않고 보상은 없다.
static func retire(state: Dictionary) -> Dictionary:
	var active: Dictionary = state["active"]
	if active.is_empty():
		return {"error": "진행 중인 탐험이 없어요."}
	if str(active["stage"]) == STAGE_RESULT:
		return {"error": "결과가 나왔어요. 포기하지 말고 결과를 받으세요."}
	var ns: Dictionary = state.duplicate(true)
	var receipt: Dictionary = {
		"day": int(active["day"]), "region": str(active["region"]), "outcome": OUTCOME_RETIRED,
		"fee": int(active["fee"]), "extra": int(active["extra"]), "path": (active["path"] as Array).duplicate(),
		"ingredient": "", "new": false,
	}
	_push_history(ns, receipt)
	ns["retired"] = int(ns["retired"]) + 1
	ns["active"] = {}
	return {"error": "", "state": ns, "receipt": receipt.duplicate(true)}


static func _push_history(ns: Dictionary, receipt: Dictionary) -> void:
	var hist: Array = ns["history"]
	hist.append(receipt)
	while hist.size() > MAX_HISTORY:
		hist.remove_at(0)


## 진행 중 탐험의 화면용 보기(읽기 전용 사본). 탐험이 없으면 {}.
## 만남 단계: event(제목/본문/선택지 — 비용, 지금 감당 가능한지, 두 번째 만남이면 얻는 재료와 이미 발견했는지). 결과 단계: result.
static func active_view(state: Dictionary, wallet: int) -> Dictionary:
	var active: Dictionary = state["active"]
	if active.is_empty():
		return {}
	var reg: Dictionary = find_region(str(active["region"]))
	var ids: Array[String] = discovered_ids(state)
	var view: Dictionary = {
		"region": str(active["region"]), "region_name": str(reg["name"]), "stage": str(active["stage"]),
		"day": int(active["day"]), "fee": int(active["fee"]), "extra": int(active["extra"]),
		"path": (active["path"] as Array).duplicate(), "can_retire": str(active["stage"]) != STAGE_RESULT,
		"event": {}, "result": {},
	}
	var ev: Dictionary = current_event(active)
	if not ev.is_empty():
		var chs: Array = []
		for c in ev["choices"]:
			var cd: Dictionary = c
			var entry: Dictionary = {"id": str(cd["id"]), "label": str(cd["label"]), "desc": str(cd["desc"]),
				"cost": int(cd["cost"]), "affordable": int(cd["cost"]) <= wallet}
			if cd.has("ingredient"):
				var iid: String = str(cd["ingredient"])
				entry["ingredient_id"] = iid
				entry["ingredient_name"] = ingredient_name(iid)
				entry["known"] = ids.has(iid)
			else:
				var nxt: Dictionary = find_event(str(cd["next"]))
				entry["leads_to"] = str(nxt["title"])
			chs.append(entry)
		view["event"] = {"id": str(ev["id"]), "step": int(ev["step"]), "title": str(ev["title"]), "text": str(ev["text"]), "choices": chs}
	else:
		var rid: String = ingredient_for(str(active["region"]), active["path"])
		var got: bool = ids.has(rid)
		view["result"] = {"ingredient_id": rid, "ingredient_name": ingredient_name(rid), "new": not got,
			"message": ("새 재료 「%s」를 발견했어요. 받으면 레시피에 쓸 수 있어요." % ingredient_name(rid)) if not got
				else ("「%s」는 이미 아는 재료예요. 새 발견은 없어요." % ingredient_name(rid))}
	return view


# ---------- 저장 구조 검증 ----------

## 저장의 탐험 상태를 전부 검증한다(카탈로그 기반 엄격 검증). 하나라도 틀리면 error 만 돌려주고 호출자는 아무것도 반영하지 않는다.
## 반환: {"error": String, "state": Dictionary(정규화: 정수, 새 컨테이너)}
## 검사: 키 정확히 일치 / 정수 범위 / 발견 재료 id·지역 일치·중복 없음·날짜 순서 / 등급 요건(발견·영수증·활성 모두 현재 등급 이하) /
##       출발 횟수(completed+retired+활성)가 일차를 넘지 않음(하루 1번 규칙) / last_departure_day 와 활성·영수증 날짜의 일관성 /
##       경로가 지역 갈래를 정확히 따르고 비용(fee, extra)이 카탈로그와 일치 / 영수증 결과(재료, new)와 발견 목록의 일치 /
##       기록 길이 == min(MAX_HISTORY, completed+retired) 이고 잘리지 않았다면 종류별 개수가 누적 횟수와 같음.
static func parse_state(raw: Variant, rank: int, day: int) -> Dictionary:
	if typeof(raw) != TYPE_DICTIONARY:
		return {"error": "탐험 상태 구조가 올바르지 않아요."}
	var d: Dictionary = raw
	var key_err: String = Check.keys_error(d, STATE_KEYS, "탐험 상태")
	if key_err != "":
		return {"error": key_err}
	if not Check.in_range(d["last_departure_day"], 0, day):
		return {"error": "탐험 마지막 출발일이 범위를 벗어났어요."}
	if not Check.in_range(d["completed"], 0, day) or not Check.in_range(d["retired"], 0, day):
		return {"error": "탐험 누적 횟수가 범위를 벗어났어요."}
	var last_dep: int = int(d["last_departure_day"])
	var completed: int = int(d["completed"])
	var retired: int = int(d["retired"])

	# 발견 목록
	if typeof(d["discovered"]) != TYPE_ARRAY:
		return {"error": "발견 목록 구조가 올바르지 않아요."}
	var raw_disc: Array = d["discovered"]
	if raw_disc.size() > Catalog.discovery_ids().size():
		return {"error": "발견 목록이 카탈로그보다 길어요."}
	var discovered: Array = []
	var seen_ids: Dictionary = {}
	var prev_day: int = 0
	for v in raw_disc:
		if typeof(v) != TYPE_DICTIONARY:
			return {"error": "발견 항목 구조가 올바르지 않아요."}
		var e: Dictionary = v
		var e_err: String = Check.keys_error(e, DISCOVERED_KEYS, "발견 항목")
		if e_err != "":
			return {"error": e_err}
		if typeof(e["id"]) != TYPE_STRING or typeof(e["region"]) != TYPE_STRING:
			return {"error": "발견 항목 형식이 올바르지 않아요."}
		var iid: String = e["id"]
		if not Catalog.is_discovery(iid):
			return {"error": "알 수 없는 발견 재료예요."}
		if seen_ids.has(iid):
			return {"error": "같은 재료가 두 번 발견돼 있어요."}
		seen_ids[iid] = true
		if region_of(iid) != str(e["region"]):
			return {"error": "발견 재료의 지역이 맞지 않아요."}
		if int((find_region(str(e["region"])))["min_rank"]) > rank:
			return {"error": "가게 등급이 모자란데 그 지역 재료가 발견돼 있어요."}
		if not Check.in_range(e["day"], 1, day):
			return {"error": "발견일이 범위를 벗어났어요."}
		# 발견은 서로 다른 출발에서만 생기고 하루 한 번이라 날짜는 엄격히 늘어난다.
		if int(e["day"]) <= prev_day:
			return {"error": "발견일 순서가 올바르지 않아요."}
		prev_day = int(e["day"])
		discovered.append({"id": iid, "region": str(e["region"]), "day": int(e["day"])})
	if discovered.size() > completed:
		return {"error": "완료한 탐험보다 발견이 많아요."}

	# 활성 탐험
	if typeof(d["active"]) != TYPE_DICTIONARY:
		return {"error": "진행 중 탐험 구조가 올바르지 않아요."}
	var raw_active: Dictionary = d["active"]
	var active: Dictionary = {}
	if not raw_active.is_empty():
		var a_err: String = Check.keys_error(raw_active, ACTIVE_KEYS, "진행 중 탐험")
		if a_err != "":
			return {"error": a_err}
		var pa: Dictionary = _parse_trip(raw_active, rank, day, "진행 중 탐험")
		if str(pa["error"]) != "":
			return {"error": str(pa["error"])}
		active = pa["trip"]
		if not STAGES.has(str(raw_active["stage"])) or typeof(raw_active["stage"]) != TYPE_STRING:
			return {"error": "진행 중 탐험 단계가 올바르지 않아요."}
		active["stage"] = str(raw_active["stage"])
		var want_len: int = STAGES.find(active["stage"])
		if (active["path"] as Array).size() != want_len:
			return {"error": "진행 중 탐험의 단계와 경로 길이가 맞지 않아요."}
		if int(active["day"]) != last_dep:
			return {"error": "진행 중 탐험의 출발일과 마지막 출발일이 달라요."}
		# 탐험 중에는 영업/일차 진행이 모두 잠겨 있으므로 진행 중 탐험은 반드시 "오늘" 출발한 것이다(어제 출발한 활성 탐험은 도달 불가).
		if int(active["day"]) != day:
			return {"error": "진행 중 탐험의 출발일이 현재 일차와 달라요."}
		# 완전히 발견한 지역은 출발할 수 없으므로 그 지역의 활성 탐험도 있을 수 없다(과거의 완료 영수증은 그대로 유효).
		var reg_def: Dictionary = find_region(str(active["region"]))
		var have_n: int = 0
		for rid_a in reg_def["ingredients"]:
			if seen_ids.has(str(rid_a)):
				have_n += 1
		if have_n >= (reg_def["ingredients"] as Array).size():
			return {"error": "이미 모두 발견한 지역의 탐험이 진행 중으로 저장돼 있어요."}
	var departures: int = completed + retired + (0 if active.is_empty() else 1)
	# 출발은 하루 한 번이고 모든 출발일은 last_departure_day 이하이므로 누적 출발 횟수도 그 값을 넘을 수 없다
	# (기록이 12개로 잘려도 누적 횟수는 남아 있어 이 상한이 계속 적용된다. 출발 사이의 빈 날은 정상이라 등호를 요구하지 않는다).
	if departures > last_dep:
		return {"error": "출발 횟수가 하루 한 번 규칙(마지막 출발일)을 넘었어요."}
	if (last_dep == 0) != (departures == 0):
		return {"error": "마지막 출발일과 출발 횟수가 맞지 않아요."}

	# 영수증(기록)
	if typeof(d["history"]) != TYPE_ARRAY:
		return {"error": "탐험 기록 구조가 올바르지 않아요."}
	var raw_hist: Array = d["history"]
	var finished_count: int = 0
	var retired_count: int = 0
	var history: Array = []
	var prev_receipt_day: int = 0
	var past: int = completed + retired
	if raw_hist.size() != mini(MAX_HISTORY, past):
		return {"error": "탐험 기록 개수가 누적 횟수와 맞지 않아요."}
	for v2 in raw_hist:
		var pr: Dictionary = _parse_receipt(v2, rank, day)
		if str(pr["error"]) != "":
			return {"error": str(pr["error"])}
		var r: Dictionary = pr["receipt"]
		if int(r["day"]) <= prev_receipt_day:
			return {"error": "탐험 기록 날짜 순서가 올바르지 않아요."}
		prev_receipt_day = int(r["day"])
		if int(r["day"]) > last_dep or (not active.is_empty() and int(r["day"]) >= int(active["day"])):
			return {"error": "탐험 기록이 마지막 출발일보다 늦어요."}
		if str(r["outcome"]) == OUTCOME_FINISHED:
			finished_count += 1
		else:
			retired_count += 1
		history.append(r)
	if active.is_empty() and not history.is_empty() and int((history[history.size() - 1] as Dictionary)["day"]) != last_dep:
		return {"error": "마지막 탐험 기록과 마지막 출발일이 달라요."}
	if past <= MAX_HISTORY:
		if finished_count != completed or retired_count != retired:
			return {"error": "탐험 기록의 종류별 개수가 누적 횟수와 맞지 않아요."}
	elif finished_count > completed or retired_count > retired:
		return {"error": "탐험 기록이 누적 횟수보다 많아요."}

	# 영수증 <-> 발견 목록의 일치. 기록이 남아 있는 구간(가장 오래된 영수증 이후)의 발견은 반드시 "새 발견" 영수증이 있어야 하고,
	# 영수증의 새 발견은 같은 날짜로 발견 목록에 있어야 하며, "이미 앎" 영수증의 재료는 더 이른 날짜에 발견돼 있어야 한다.
	var by_id: Dictionary = {}
	for e2 in discovered:
		by_id[str((e2 as Dictionary)["id"])] = e2
	for r2 in history:
		var rd: Dictionary = r2
		if str(rd["outcome"]) != OUTCOME_FINISHED:
			continue
		var rid: String = str(rd["ingredient"])
		if not by_id.has(rid):
			return {"error": "탐험 결과의 재료가 발견 목록에 없어요."}
		var disc_day: int = int((by_id[rid] as Dictionary)["day"])
		if bool(rd["new"]) and disc_day != int(rd["day"]):
			return {"error": "새 발견 기록과 발견일이 달라요."}
		if not bool(rd["new"]) and disc_day >= int(rd["day"]):
			return {"error": "이미 아는 재료라는 기록이 발견일과 맞지 않아요."}
	if not history.is_empty():
		var oldest: int = int((history[0] as Dictionary)["day"])
		for e3 in discovered:
			var ed: Dictionary = e3
			if int(ed["day"]) < oldest:
				continue
			var matched: bool = false
			for r3 in history:
				var rd3: Dictionary = r3
				if str(rd3["outcome"]) == OUTCOME_FINISHED and bool(rd3["new"]) and str(rd3["ingredient"]) == str(ed["id"]) and int(rd3["day"]) == int(ed["day"]):
					matched = true
			if not matched:
				return {"error": "발견에 해당하는 탐험 기록이 없어요."}
	return {"error": "", "state": {
		"discovered": discovered, "last_departure_day": last_dep, "completed": completed, "retired": retired,
		"active": active, "history": history,
	}}


## 활성 탐험/영수증이 공유하는 부분(지역, 날짜, 비용, 경로)을 검증한다. 반환: {"error", "trip": {region, day, fee, extra, path}}
static func _parse_trip(d: Dictionary, rank: int, day: int, ctx: String) -> Dictionary:
	if typeof(d["region"]) != TYPE_STRING:
		return {"error": ctx + ": 지역 형식이 올바르지 않아요."}
	var reg: Dictionary = find_region(str(d["region"]))
	if reg.is_empty():
		return {"error": ctx + ": 알 수 없는 지역이에요."}
	if int(reg["min_rank"]) > rank:
		return {"error": ctx + ": 가게 등급이 모자란 지역이에요."}
	if not Check.in_range(d["day"], 1, day):
		return {"error": ctx + ": 출발일이 범위를 벗어났어요."}
	if typeof(d["path"]) != TYPE_ARRAY:
		return {"error": ctx + ": 경로 구조가 올바르지 않아요."}
	var path: Array = []
	for p in (d["path"] as Array):
		if typeof(p) != TYPE_STRING:
			return {"error": ctx + ": 경로 형식이 올바르지 않아요."}
		path.append(str(p))
	if not path_valid(str(d["region"]), path):
		return {"error": ctx + ": 경로가 지역의 갈래와 맞지 않아요."}
	if not Check.in_range(d["fee"], 0, 1000000000) or int(d["fee"]) != int(reg["fee"]):
		return {"error": ctx + ": 출발 비용이 지역 정가와 달라요."}
	if not Check.in_range(d["extra"], 0, 1000000000) or int(d["extra"]) != path_cost(str(d["region"]), path):
		return {"error": ctx + ": 추가 비용이 선택 경로와 달라요."}
	return {"error": "", "trip": {"region": str(d["region"]), "day": int(d["day"]), "fee": int(d["fee"]), "extra": int(d["extra"]), "path": path}}


static func _parse_receipt(raw: Variant, rank: int, day: int) -> Dictionary:
	if typeof(raw) != TYPE_DICTIONARY:
		return {"error": "탐험 기록 항목 구조가 올바르지 않아요."}
	var d: Dictionary = raw
	var key_err: String = Check.keys_error(d, RECEIPT_KEYS, "탐험 기록")
	if key_err != "":
		return {"error": key_err}
	var pt: Dictionary = _parse_trip(d, rank, day, "탐험 기록")
	if str(pt["error"]) != "":
		return {"error": str(pt["error"])}
	var trip: Dictionary = pt["trip"]
	if typeof(d["outcome"]) != TYPE_STRING or typeof(d["ingredient"]) != TYPE_STRING or typeof(d["new"]) != TYPE_BOOL:
		return {"error": "탐험 기록 형식이 올바르지 않아요."}
	var outcome: String = d["outcome"]
	var path: Array = trip["path"]
	if outcome == OUTCOME_FINISHED:
		var want: String = ingredient_for(str(trip["region"]), path)
		if want == "" or str(d["ingredient"]) != want:
			return {"error": "탐험 기록의 재료가 경로의 결과와 달라요."}
	elif outcome == OUTCOME_RETIRED:
		if path.size() > 1 or str(d["ingredient"]) != "" or bool(d["new"]):
			return {"error": "포기 기록에 보상이 들어 있어요."}
	else:
		return {"error": "알 수 없는 탐험 결과예요."}
	return {"error": "", "receipt": {
		"day": int(trip["day"]), "region": str(trip["region"]), "outcome": outcome, "fee": int(trip["fee"]),
		"extra": int(trip["extra"]), "path": path, "ingredient": str(d["ingredient"]), "new": bool(d["new"]),
	}}
