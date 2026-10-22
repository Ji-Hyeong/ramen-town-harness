extends RefCounted
## Pure region-parametrized research sample ledger. Public game transactions own money and
## shared travel locks; every helper returns a copy and never mutates its input.
const Catalog = preload("res://scripts/domain/ingredient_catalog.gd")
const Check = preload("res://scripts/domain/data_check.gd")
const CAPACITY: int = 20
const MAX_HISTORY: int = 12
const KEYS: Array = ["stock", "obtained", "used", "first_day", "last_departure_day", "completed", "retired", "active", "history"]
const ACTIVE_KEYS: Array = ["day", "stage", "fee", "extra", "path"]
const RECEIPT_KEYS: Array = ["day", "outcome", "fee", "extra", "path", "ingredient", "amount"]


static func empty_state(spec: Dictionary) -> Dictionary:
	var out: Dictionary = {"last_departure_day": 0, "completed": 0, "retired": 0, "active": {}, "history": []}
	for key in ["stock", "obtained", "used", "first_day"]:
		out[key] = {spec["ids"][0]: 0, spec["ids"][1]: 0}
	return out


static func discoveries(spec: Dictionary, state: Dictionary) -> Array:
	var out: Array = []
	for id in spec["ids"]:
		if int(state["first_day"][id]) > 0:
			out.append({"id": id, "region": spec["region"], "day": int(state["first_day"][id])})
	return out


static func choices(spec: Dictionary, path: Array) -> Array:
	if path.is_empty():
		return spec["targets"].duplicate(true)
	if path.size() != 1:
		return []
	for i in spec["targets"].size():
		if path[0] == spec["targets"][i]["id"]:
			var rows: Array = spec["quantities"].duplicate(true)
			for row in rows:
				row["ingredient"] = spec["ids"][i]
			return rows
	return []


## Replay at most two known choices to validate both active and historical
## paths. Catalog facts, not saved fee/amount fields, determine every reward.
static func outcome(spec: Dictionary, path: Array) -> Dictionary:
	if path.size() > 2:
		return {}
	var prefix: Array = []
	var result: Dictionary = {"extra": 0, "ingredient": "", "amount": 0}
	for value in path:
		if typeof(value) != TYPE_STRING:
			return {}
		var selected: Dictionary = {}
		for choice in choices(spec, prefix):
			if choice["id"] == value:
				selected = choice
		if selected.is_empty():
			return {}
		result["extra"] += int(selected["cost"])
		if selected.has("ingredient"):
			result["ingredient"] = selected["ingredient"]
			result["amount"] = selected["amount"]
		prefix.append(value)
	return result


static func begin(spec: Dictionary, state: Dictionary, day: int, wallet: int) -> Dictionary:
	if not state["active"].is_empty():
		return {"error": "이미 채집 중이에요."}
	if int(state["last_departure_day"]) == day:
		return {"error": "오늘은 이미 출발했어요. 영업을 마친 뒤 다시 오세요."}
	if wallet < int(spec["fee"]):
		return {"error": "채집 출발비 %d원이 부족해요." % int(spec["fee"])}
	if int(state["stock"][spec["ids"][0]]) > CAPACITY - int(spec["min_amount"]) and int(state["stock"][spec["ids"][1]]) > CAPACITY - int(spec["min_amount"]):
		return {"error": "연구 재료 보관함이 가득 찼어요. 먼저 시제품에 사용하세요."}
	var ns: Dictionary = state.duplicate(true)
	ns["last_departure_day"] = day
	ns["active"] = {"day": day, "stage": "choice_1", "fee": int(spec["fee"]), "extra": 0, "path": []}
	return {"error": "", "state": ns}


static func choose(spec: Dictionary, state: Dictionary, id: String, wallet: int) -> Dictionary:
	var active: Dictionary = state["active"]
	if active.is_empty() or active["stage"] == "result":
		return {"error": "지금은 채집 선택을 할 수 없어요."}
	var selected: Dictionary = {}
	for row in choices(spec, active["path"]):
		if row["id"] == id:
			selected = row
	if selected.is_empty():
		return {"error": "지금 만남에 없는 채집 선택이에요."}
	if int(selected["cost"]) > wallet:
		return {"error": "추가 비용 %d원이 부족해요." % int(selected["cost"])}
	if active["path"].is_empty():
		var target: String = str(selected["ingredient_hint"])
		if int(state["stock"][target]) > CAPACITY - int(spec["min_amount"]):
			return {"error": "이 재료를 담을 공간이 없어요. 다른 재료를 고르거나 먼저 시제품에 사용하세요."}
	if selected.has("ingredient") and int(state["stock"][selected["ingredient"]]) + int(selected["amount"]) > CAPACITY:
		return {"error": "이 선택은 보관 한도 20개를 넘어요. 다른 수량을 고르거나 먼저 시제품에 사용하세요."}
	var ns: Dictionary = state.duplicate(true)
	ns["active"]["path"].append(id)
	ns["active"]["extra"] += int(selected["cost"])
	ns["active"]["stage"] = "choice_2" if active["stage"] == "choice_1" else "result"
	return {"error": "", "state": ns, "extra": int(selected["cost"])}


static func finish(spec: Dictionary, state: Dictionary, retire: bool = false) -> Dictionary:
	var active: Dictionary = state["active"]
	if active.is_empty() or (retire and active["stage"] == "result") or (not retire and active["stage"] != "result"):
		return {"error": "지금은 결과를 받거나 포기할 수 없어요."}
	var reward: Dictionary = outcome(spec, active["path"])
	var id: String = "" if retire else str(reward["ingredient"])
	var amount: int = 0 if retire else int(reward["amount"])
	if not retire and int(state["stock"][id]) + amount > CAPACITY:
		return {"error": "연구 재료 보관 한도를 넘어서 받을 수 없어요."}
	var ns: Dictionary = state.duplicate(true)
	if not retire:
		ns["stock"][id] += amount
		ns["obtained"][id] += amount
		if int(ns["first_day"][id]) == 0:
			ns["first_day"][id] = int(active["day"])
	ns["retired" if retire else "completed"] += 1
	var receipt: Dictionary = {"day": active["day"], "outcome": "retired" if retire else "finished", "fee": int(spec["fee"]),
		"extra": active["extra"], "path": active["path"].duplicate(), "ingredient": id, "amount": amount}
	ns["history"].append(receipt)
	if ns["history"].size() > MAX_HISTORY:
		ns["history"].pop_front()
	ns["active"] = {}
	return {"error": "", "state": ns, "receipt": receipt.duplicate(true)}


## Called only after all recipe/name/capacity/money checks. Cancelling a visual
## preparation never calls this; one completed trial consumes each sample once.
static func use_samples(spec: Dictionary, state: Dictionary, config: Dictionary) -> Dictionary:
	var ns: Dictionary = state.duplicate(true)
	for id in Catalog.item_ids(config):
		if not spec["ids"].has(id):
			continue
		if int(ns["stock"][id]) < 1:
			return {"error": "%s 연구 재료가 부족해요. 탐색 탭의 %s에서 구하세요. 기존 메뉴 판매는 계속할 수 있어요." % [Catalog.find(id)["name"], spec["name"]]}
		ns["stock"][id] -= 1
		ns["used"][id] += 1
	return {"error": "", "state": ns}


static func active_view(spec: Dictionary, state: Dictionary, wallet: int) -> Dictionary:
	if state["active"].is_empty():
		return {}
	var active: Dictionary = state["active"]
	var view: Dictionary = active.duplicate(true)
	view["region"] = spec["region"]
	view["region_name"] = spec["name"]
	view["can_retire"] = active["stage"] != "result"
	if active["stage"] == "result":
		var reward: Dictionary = outcome(spec, active["path"])
		view["result"] = {"message": "%s 연구 재료 %d개를 찾았어요! 결과를 받아야 보관함에 들어와요." % [Catalog.find(reward["ingredient"])["name"], reward["amount"]]}
	else:
		var rows: Array = choices(spec, active["path"]).duplicate(true)
		for choice in rows:
			choice["affordable"] = int(choice["cost"]) <= wallet
			var target: String = str(choice.get("ingredient", choice.get("ingredient_hint", "")))
			var amount: int = int(choice.get("amount", spec["min_amount"]))
			choice["capacity_blocked"] = int(state["stock"][target]) + amount > CAPACITY
			if bool(choice["capacity_blocked"]):
				choice["affordable"] = false
				choice["desc"] += " 보관 한도 20개를 넘어요."
		view["event"] = {"step": active["path"].size() + 1, "title": str(spec["event_title"]) if active["path"].is_empty() else str(spec["quantity_title"]),
			"text": "시제품에 쓸 재료를 고르세요. 등록한 메뉴의 판매 재료는 영업 원가로 공급돼요.", "choices": rows}
	return view


static func _fail(spec: Dictionary) -> Dictionary:
	return {"error": "%s의 재고·횟수·경로·날짜 또는 영수증이 올바르지 않아요." % spec["name"]}


## Shape and conservation are checked before GameState commits any field.
## This is local save validation, not cryptographic authentication of history.
static func parse(spec: Dictionary, raw: Variant, day: int, next_record: int, max_uses_per_recipe: int = 1) -> Dictionary:
	if typeof(raw) != TYPE_DICTIONARY or Check.keys_error(raw, KEYS, "장터 채집") != "":
		return _fail(spec)
	var ns: Dictionary = raw.duplicate(true)
	for group in ["stock", "obtained", "used", "first_day"]:
		if typeof(ns[group]) != TYPE_DICTIONARY or Check.keys_error(ns[group], spec["ids"], "연구 재료") != "":
			return _fail(spec)
		for id in spec["ids"]:
			if not Check.in_range(ns[group][id], 0, 300000):
				return _fail(spec)
			ns[group][id] = int(ns[group][id])
	for key in ["completed", "retired", "last_departure_day"]:
		if not Check.in_range(ns[key], 0, day):
			return _fail(spec)
		ns[key] = int(ns[key])
	if typeof(ns["history"]) != TYPE_ARRAY or typeof(ns["active"]) != TYPE_DICTIONARY:
		return _fail(spec)
	var total: int = ns["completed"] + ns["retired"]
	var active: Dictionary = ns["active"]
	if total + (0 if active.is_empty() else 1) > ns["last_departure_day"] or ns["history"].size() != mini(total, MAX_HISTORY):
		return _fail(spec)
	if (total == 0 and active.is_empty()) != (ns["last_departure_day"] == 0):
		return _fail(spec)
	var acquired: int = 0
	for id in spec["ids"]:
		if ns["stock"][id] > CAPACITY or ns["stock"][id] != ns["obtained"][id] - ns["used"][id] or ns["used"][id] > (next_record - 1) * max_uses_per_recipe:
			return _fail(spec)
		if (ns["obtained"][id] > 0) != (ns["first_day"][id] > 0) or ns["first_day"][id] > ns["last_departure_day"]:
			return _fail(spec)
		acquired += int(ns["obtained"][id])
	if acquired < int(spec["min_amount"]) * ns["completed"] or acquired > int(spec["max_amount"]) * ns["completed"]:
		return _fail(spec)
	var last: int = 0
	var counts: Dictionary = {"finished": 0, "retired": 0}
	var received: Dictionary = {spec["ids"][0]: 0, spec["ids"][1]: 0}
	for raw_receipt in ns["history"]:
		if typeof(raw_receipt) != TYPE_DICTIONARY or Check.keys_error(raw_receipt, RECEIPT_KEYS, "채집 영수증") != "":
			return _fail(spec)
		var receipt: Dictionary = raw_receipt
		if not Check.in_range(receipt["day"], last + 1, day) or typeof(receipt["outcome"]) != TYPE_STRING or not counts.has(receipt["outcome"]) or typeof(receipt["path"]) != TYPE_ARRAY:
			return _fail(spec)
		var reward: Dictionary = outcome(spec, receipt["path"])
		var finished: bool = receipt["outcome"] == "finished"
		if reward.is_empty() or receipt["path"].size() > (2 if finished else 1) or (finished and receipt["path"].size() != 2):
			return _fail(spec)
		if not Check.is_whole(receipt["fee"]) or int(receipt["fee"]) != int(spec["fee"]) or not Check.is_whole(receipt["extra"]) or int(receipt["extra"]) != int(reward["extra"]):
			return _fail(spec)
		if typeof(receipt["ingredient"]) != TYPE_STRING or not Check.is_whole(receipt["amount"]) or int(receipt["amount"]) != (int(reward["amount"]) if finished else 0) or receipt["ingredient"] != (reward["ingredient"] if finished else ""):
			return _fail(spec)
		for key in ["day", "fee", "extra", "amount"]:
			receipt[key] = int(receipt[key])
		last = int(receipt["day"])
		counts[receipt["outcome"]] += 1
		if finished:
			received[receipt["ingredient"]] += int(receipt["amount"])
			if ns["first_day"][receipt["ingredient"]] > last:
				return _fail(spec)
	if counts["finished"] > ns["completed"] or counts["retired"] > ns["retired"]:
		return _fail(spec)
	for id in spec["ids"]:
		if received[id] > ns["obtained"][id] or (total <= MAX_HISTORY and received[id] != ns["obtained"][id]):
			return _fail(spec)
		if ns["first_day"][id] > 0 and not ns["history"].is_empty() and ns["first_day"][id] >= int(ns["history"][0]["day"]):
			var witnessed: bool = false
			for receipt in ns["history"]:
				witnessed = witnessed or (receipt["ingredient"] == id and receipt["day"] == ns["first_day"][id])
			if not witnessed:
				return _fail(spec)
	if active.is_empty():
		if last != ns["last_departure_day"]:
			return _fail(spec)
	else:
		if Check.keys_error(active, ACTIVE_KEYS, "진행 중 채집") != "" or typeof(active["path"]) != TYPE_ARRAY or not Check.is_whole(active["day"]) or int(active["day"]) != day or day != ns["last_departure_day"] or day <= last:
			return _fail(spec)
		var reward: Dictionary = outcome(spec, active["path"])
		var stage: String = ["choice_1", "choice_2", "result"][mini(active["path"].size(), 2)]
		if reward.is_empty() or typeof(active["stage"]) != TYPE_STRING or active["stage"] != stage or not Check.is_whole(active["fee"]) or int(active["fee"]) != int(spec["fee"]) or not Check.is_whole(active["extra"]) or int(active["extra"]) != reward["extra"]:
			return _fail(spec)
		if stage == "result" and ns["stock"][reward["ingredient"]] + reward["amount"] > CAPACITY:
			return _fail(spec)
		for key in ["day", "fee", "extra"]:
			active[key] = int(active[key])
	return {"error": "", "state": ns}
