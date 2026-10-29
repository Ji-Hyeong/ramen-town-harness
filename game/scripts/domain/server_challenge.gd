extends RefCounted
## One bounded base-server challenge, "두 메뉴의 점심". Only a validated actual
## two-menu settlement creates evidence; tasting, forecasts, analytical service,
## partial/canceled service and UI cannot. This module is pure: it never mutates
## GameState, grants cash/XP or applies the timing effect (the host does).
const Check = preload("res://scripts/domain/data_check.gd")
const Catalog = preload("res://scripts/domain/ingredient_catalog.gd")
const Exploration = preload("res://scripts/domain/ingredient_exploration.gd")
const Process = preload("res://scripts/domain/recipe_process.gd")
const Session = preload("res://scripts/domain/service_session.gd")

const MIN_RANK: int = 2
const MAX_UNITS: int = 1000
const MENU_MIN_UNITS: int = 3
const TOTAL_MIN_UNITS: int = 8
const MAX_AVG_WAIT: int = 150
const MAX_PRICE: int = 10000
const MAX_BASELINES: int = 2


static func empty_state() -> Dictionary:
	return {"start": {}, "attempt": {}, "completed_day": 0}


static func level(state: Dictionary) -> int:
	return 1 if int(state["completed_day"]) > 0 else 0


## Structural difference only: the price of `b` is ignored.
static func changed(a: Dictionary, b: Dictionary) -> bool:
	var copy: Dictionary = b.duplicate(true)
	copy["price"] = a["price"]
	return not Check.same_config(a, copy)


static func review(state: Dictionary) -> Dictionary:
	var start: Dictionary = state["start"]
	var attempt: Dictionary = state["attempt"]
	var started: bool = not start.is_empty()
	var has_attempt: bool = not attempt.is_empty()
	var menus: Array = attempt["menus"] if has_attempt else []
	var units: int = int(attempt.get("units", 0))
	var wait_total: int = int(attempt.get("wait_total", 0))
	var star_sum: int = int(attempt.get("star_sum", 0))
	var developed: bool = has_attempt and started and _developed(start, menus)
	var each_ok: bool = has_attempt and menus.size() == 2 and int(menus[0]["units"]) >= MENU_MIN_UNITS and int(menus[1]["units"]) >= MENU_MIN_UNITS
	var prices_ok: bool = has_attempt and menus.size() == 2 and int(menus[0]["config"]["price"]) <= MAX_PRICE and int(menus[1]["config"]["price"]) <= MAX_PRICE
	var rows: Array = [
		{"title":"수락 후 두 메뉴 모두 새 구성 시식", "value":"두 구성 변경 확인" if developed else ("영업 후 확인" if not has_attempt else "두 메뉴 모두 기존·서로와 구조가 달라야 해요"), "met":developed},
		{"title":"각 메뉴 3그릇 이상", "value":"%d / %d그릇" % [int(menus[0]["units"]), int(menus[1]["units"])] if has_attempt else "영업 후 확인", "met":each_ok},
		{"title":"한 영업에 8그릇 이상", "value":"%d그릇" % units if has_attempt else "영업 후 확인", "met":units >= TOTAL_MIN_UNITS},
		{"title":"평균 대기 150초 이하", "value":"%.1f초" % (float(wait_total) / units) if units > 0 else "완료 주문 필요", "met":units > 0 and wait_total <= MAX_AVG_WAIT * units},
		{"title":"평균 만족도 3.5점 이상", "value":"%.2f / 5" % (float(star_sum) / units) if units > 0 else "완료 주문 필요", "met":units > 0 and star_sum * 2 >= units * 7},
		{"title":"두 메뉴 가격 10,000원 이하", "value":"%s원 / %s원" % [str(menus[0]["config"]["price"]), str(menus[1]["config"]["price"])] if has_attempt else "영업 후 확인", "met":prices_ok},
	]
	var count: int = 0
	for row in rows:
		if row["met"]: count += 1
	var status: String = "mastered" if level(state) > 0 else ("ready" if count == rows.size() else ("active" if started else "open"))
	return {"status":status, "rows":rows, "met":count, "attempt":attempt.duplicate(true), "completed_day":int(state["completed_day"])}


## Free explicit acceptance with exactly two distinct actual selling records.
## The host separately requires expansion and two selling slots. Only {id, config}
## baselines are stored; later or older tastings never receive retroactive credit.
static func begin(state: Dictionary, records: Array, day: int, next_id: int, rank: int) -> Dictionary:
	if not _shape_ok(state): return _reject(state, "서빙 도전 상태가 올바르지 않아요.")
	if rank < MIN_RANK: return _reject(state, "등급 2부터 수락할 수 있어요.")
	if not state["start"].is_empty() or int(state["completed_day"]) > 0: return _reject(state, "이미 수락한 도전이에요. 다시 시작할 수 없어요.")
	if day < 1 or next_id < 1: return _reject(state, "도전 수락 시점이 올바르지 않아요.")
	var picked: Dictionary = _records(records, day, next_id)
	if str(picked["error"]) != "": return _reject(state, str(picked["error"]))
	var baselines: Array = []
	for r in picked["records"]:
		baselines.append({"record_id":int(r["record_id"]), "config":r["config"].duplicate(true)})
	var out: Dictionary = state.duplicate(true)
	out["start"] = {"day":day, "min_record_id":next_id, "baselines":baselines}
	return {"ok":true, "error":"", "state":out}


## Record one validated actual settlement. `records` are the service's selling
## records, `completed` its completed orders. Empty start or fewer than two menus
## is a known non-applicable event (state unchanged, applicable=false). A passing
## attempt is frozen; otherwise the latest failed attempt replaces the old one.
static func observe(state: Dictionary, records: Array, on_day: int, completed: Array) -> Dictionary:
	if not _shape_ok(state): return _reject(state, "서빙 도전 상태가 올바르지 않아요.")
	var same: Dictionary = {"ok":true, "error":"", "applicable":false, "state":state.duplicate(true)}
	if state["start"].is_empty() or records.size() < 2: return same
	if on_day < int(state["start"]["day"]): return _reject(state, "수락 전 영업은 도전에 쓸 수 없어요.")
	var picked: Dictionary = _records(records, on_day, 0x7fffffff)
	if str(picked["error"]) != "": return _reject(state, str(picked["error"]))
	var ids: Array = [int(picked["records"][0]["record_id"]), int(picked["records"][1]["record_id"])]
	var counts: Array = [0, 0]
	var wait_total: int = 0
	var star_sum: int = 0
	if completed.size() > MAX_UNITS: return _reject(state, "완료 주문 수가 한도를 넘었어요.")
	for order in completed:
		if typeof(order) != TYPE_DICTIONARY or not order.has("record_id") or not order.has("wait") or not order.has("stars"): return _reject(state, "완료 주문 형식이 올바르지 않아요.")
		if not Check.is_whole(order["record_id"]) or not Check.in_range(order["wait"], 0, Session.HARD_LIMIT) or not Check.in_range(order["stars"], 1, 5): return _reject(state, "완료 주문 값이 올바르지 않아요.")
		var index: int = ids.find(int(order["record_id"]))
		if index < 0: return _reject(state, "선택하지 않은 메뉴의 주문이 섞여 있어요.")
		counts[index] += 1
		wait_total += int(order["wait"])
		star_sum += int(order["stars"])
	if review(state)["status"] in ["ready", "mastered"]: return {"ok":true, "error":"", "applicable":true, "state":state.duplicate(true)}
	var menus: Array = []
	for i in 2:
		var r: Dictionary = picked["records"][i]
		menus.append({"record_id":ids[i], "name":str(r["name"]), "tasted_day":int(r["tasted_day"]), "config":r["config"].duplicate(true), "units":counts[i]})
	var out: Dictionary = state.duplicate(true)
	out["attempt"] = {"day":on_day, "menus":menus, "units":completed.size(), "wait_total":wait_total, "star_sum":star_sum}
	return {"ok":true, "error":"", "applicable":true, "state":out}


## Explicit one-time claim on a day after the passing service. No cash/XP.
static func claim(state: Dictionary, day: int) -> Dictionary:
	if not _shape_ok(state): return _reject(state, "서빙 도전 상태가 올바르지 않아요.")
	var status: String = str(review(state)["status"]) if not state["start"].is_empty() else "open"
	if status == "mastered": return _reject(state, "이미 숙련을 받았어요.")
	if status != "ready": return _reject(state, "아직 모든 조건을 채우지 못했어요.")
	if day <= int(state["attempt"]["day"]): return _reject(state, "영업을 마친 다음 날부터 받을 수 있어요.")
	var out: Dictionary = state.duplicate(true)
	out["completed_day"] = day
	return {"ok":true, "error":"", "state":out}


## Local consistency validation, not cryptographic anti-cheat. Validate every
## field before replacing live state; deleted notebook rows may keep valid proof.
## Returns {"ok","error","state"}; state is {} on error (never a silent default).
static func parse(raw: Variant, day: int, next_id: int, rank: int, slots: int, discovered: Array, records: Array) -> Dictionary:
	var fail: Dictionary = {"ok":false, "error":"서빙 도전 저장이 올바르지 않아요.", "state":{}}
	if typeof(raw) != TYPE_DICTIONARY or Check.keys_error(raw,["start","attempt","completed_day"],"서빙 도전") != "": return fail
	if typeof(raw["start"]) != TYPE_DICTIONARY or typeof(raw["attempt"]) != TYPE_DICTIONARY or not Check.in_range(raw["completed_day"],0,day): return fail
	var out: Dictionary = raw.duplicate(true)
	var start: Dictionary = out["start"]
	var attempt: Dictionary = out["attempt"]
	out["completed_day"] = int(out["completed_day"])
	if start.is_empty():
		if not attempt.is_empty() or out["completed_day"] != 0: return fail
		return {"ok":true, "error":"", "state":out}
	if rank < MIN_RANK: return fail
	if Check.keys_error(start,["day","min_record_id","baselines"],"도전 수락") != "" or not Check.in_range(start["day"],1,day) or not Check.in_range(start["min_record_id"],1,next_id): return fail
	if typeof(start["baselines"]) != TYPE_ARRAY or start["baselines"].size() != MAX_BASELINES: return fail
	start["day"] = int(start["day"])
	start["min_record_id"] = int(start["min_record_id"])
	var seen: Array = []
	for base in start["baselines"]:
		if typeof(base) != TYPE_DICTIONARY or Check.keys_error(base,["record_id","config"],"도전 기준") != "": return fail
		if not Check.in_range(base["record_id"],1,int(start["min_record_id"])-1) or seen.has(int(base["record_id"])): return fail
		if not _config(base,rank,slots,discovered): return fail
		base["record_id"] = int(base["record_id"])
		seen.append(base["record_id"])
		for record in records:
			# A retained baseline must already have been tasted when it was accepted.
			if int(record["record_id"]) == base["record_id"] and (not Check.same_config(record["config"],base["config"]) or int(record["tasted_day"]) > int(start["day"])): return fail
	if not attempt.is_empty():
		if Check.keys_error(attempt,["day","menus","units","wait_total","star_sum"],"도전 영업") != "": return fail
		if not Check.in_range(attempt["day"],int(start["day"]),day-1) or typeof(attempt["menus"]) != TYPE_ARRAY or attempt["menus"].size() != 2: return fail
		if not Check.in_range(attempt["units"],0,MAX_UNITS): return fail
		var unit_sum: int = 0
		var last_id: int = 0
		for menu in attempt["menus"]:
			if typeof(menu) != TYPE_DICTIONARY or Check.keys_error(menu,["record_id","name","tasted_day","config","units"],"도전 메뉴") != "": return fail
			if not Check.in_range(menu["record_id"],last_id+1,next_id-1) or not Check.in_range(menu["tasted_day"],1,int(attempt["day"])) or not Check.in_range(menu["units"],0,MAX_UNITS): return fail
			if typeof(menu["name"]) != TYPE_STRING or Check.name_error(menu["name"],false) != "" or menu["name"] != menu["name"].strip_edges(): return fail
			if not _config(menu,rank,slots,discovered): return fail
			for key in ["record_id","tasted_day","units"]: menu[key] = int(menu[key])
			last_id = menu["record_id"]
			unit_sum += menu["units"]
			for base in start["baselines"]:
				if int(base["record_id"]) == menu["record_id"] and not Check.same_config(base["config"],menu["config"]): return fail
			for record in records:
				if int(record["record_id"]) == menu["record_id"] and (record["name"] != menu["name"] or int(record["tasted_day"]) != menu["tasted_day"] or not Check.same_config(record["config"],menu["config"])): return fail
		if unit_sum != int(attempt["units"]): return fail
		var units: int = int(attempt["units"])
		if not Check.in_range(attempt["wait_total"],0,units*Session.HARD_LIMIT) or not Check.in_range(attempt["star_sum"],units,units*5): return fail
		for key in ["day","units","wait_total","star_sum"]: attempt[key] = int(attempt[key])
	if out["completed_day"] > 0 and (attempt.is_empty() or int(out["completed_day"]) <= int(attempt["day"]) or review(out)["met"] != 6): return fail
	return {"ok":true, "error":"", "state":out}


static func _shape_ok(state: Dictionary) -> bool:
	return Check.keys_error(state,["start","attempt","completed_day"],"서빙 도전") == "" and typeof(state["start"]) == TYPE_DICTIONARY and typeof(state["attempt"]) == TYPE_DICTIONARY and typeof(state["completed_day"]) == TYPE_INT


static func _reject(state: Dictionary, message: String) -> Dictionary:
	return {"ok":false, "error":message, "applicable":false, "state":state.duplicate(true)}


## Condition 1: both menus are new since acceptance and structurally distinct from
## every baseline and from each other (price ignored).
static func _developed(start: Dictionary, menus: Array) -> bool:
	if menus.size() != 2 or start.get("baselines", []).size() != MAX_BASELINES: return false
	for menu in menus:
		if int(menu["record_id"]) < int(start["min_record_id"]) or int(menu["tasted_day"]) < int(start["day"]): return false
		for base in start["baselines"]:
			if not changed(base["config"], menu["config"]): return false
	return changed(menus[0]["config"], menus[1]["config"])


## Validate exactly two distinct runtime records; returns them sorted by record_id
## with normalized deep-copied configs.
static func _records(records: Array, day: int, next_id: int) -> Dictionary:
	var fail: String = "서로 다른 판매 메뉴 2개가 필요해요."
	if records.size() != 2: return {"error":fail, "records":[]}
	var out: Array = []
	for record in records:
		if typeof(record) != TYPE_DICTIONARY or not record.has("record_id") or not record.has("name") or not record.has("tasted_day") or not record.has("config"): return {"error":fail, "records":[]}
		if not Check.in_range(record["record_id"],1,next_id-1) or not Check.in_range(record["tasted_day"],1,day): return {"error":fail, "records":[]}
		if typeof(record["name"]) != TYPE_STRING or Check.name_error(record["name"],false) != "": return {"error":fail, "records":[]}
		var parsed: Dictionary = Check.parse_config(record["config"],"판매 구성",false)
		if str(parsed["error"]) != "": return {"error":str(parsed["error"]), "records":[]}
		out.append({"record_id":int(record["record_id"]), "name":str(record["name"]), "tasted_day":int(record["tasted_day"]), "config":parsed["config"]})
	if out[0]["record_id"] == out[1]["record_id"]: return {"error":fail, "records":[]}
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["record_id"]) < int(b["record_id"]))
	return {"error":"", "records":out}


static func _config(container: Dictionary, rank: int, slots: int, discovered: Array) -> bool:
	var parsed: Dictionary = Check.parse_config(container["config"],"도전 구성",false)
	if str(parsed["error"]) != "": return false
	var config: Dictionary = parsed["config"]
	if Catalog.toppings_of(config).size() > slots or Exploration.locked_in(config,discovered) != "": return false
	if int(Process.effects(config.get("process",{}))["rank"]) > rank: return false
	container["config"] = config
	return true
