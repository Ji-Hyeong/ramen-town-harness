extends RefCounted
## One bounded base-chef challenge. Only GameState's validated runtime settlement
## creates evidence; UI, forecasts, tasting and analytical service cannot do so.
const Check = preload("res://scripts/domain/data_check.gd")
const Catalog = preload("res://scripts/domain/ingredient_catalog.gd")
const Eval = preload("res://scripts/domain/recipe_evaluator.gd")
const Exploration = preload("res://scripts/domain/ingredient_exploration.gd")
const Process = preload("res://scripts/domain/recipe_process.gd")
const Session = preload("res://scripts/domain/service_session.gd")


static func empty_state() -> Dictionary:
	return {"start": {}, "attempt": {}, "completed_day": 0}


static func level(state: Dictionary) -> int:
	return 1 if int(state["completed_day"]) > 0 else 0


static func changed(a: Dictionary, b: Dictionary) -> bool:
	var copy: Dictionary = b.duplicate(true)
	copy["price"] = a["price"]
	return not Check.same_config(a, copy)


static func review(state: Dictionary) -> Dictionary:
	var started: bool = not state["start"].is_empty()
	var attempt: Dictionary = state["attempt"]
	var has_attempt: bool = not attempt.is_empty()
	var developed: bool = has_attempt and int(attempt["record_id"]) >= int(state["start"]["min_record_id"]) and int(attempt["tasted_day"]) >= int(state["start"]["day"]) and changed(state["start"]["config"], attempt["config"])
	var units: int = int(attempt.get("units", 0))
	var rows: Array = [
		{"title":"수락 후 새 구성 시식", "value":"구성 변경 확인" if developed else "재료·토핑·공법을 바꿔 시식", "met":developed},
		{"title":"기본 조리 100초 이하", "value":"%d초" % Eval.prep_seconds(attempt["config"]) if has_attempt else "영업 후 확인", "met":has_attempt and Eval.prep_seconds(attempt["config"]) <= 100},
		{"title":"가격 9,500원 이하", "value":"%s원" % str(attempt["config"]["price"]) if has_attempt else "영업 후 확인", "met":has_attempt and int(attempt["config"]["price"]) <= 9500},
		{"title":"한 영업에 5그릇 이상", "value":"%d그릇" % units if has_attempt else "영업 후 확인", "met":units >= 5},
		{"title":"평균 대기 120초 이하", "value":"%.1f초" % (float(attempt["wait_total"]) / units) if units > 0 else "완료 주문 필요", "met":units > 0 and float(attempt["wait_total"]) / units <= 120.0},
		{"title":"평균 만족도 3점 이상", "value":"%.1f / 5" % (float(attempt["star_sum"]) / units) if units > 0 else "완료 주문 필요", "met":units > 0 and int(attempt["star_sum"]) >= units * 3},
	]
	var count: int = 0
	for row in rows:
		if row["met"]: count += 1
	var status: String = "mastered" if level(state) > 0 else ("ready" if count == rows.size() else ("active" if started else "open"))
	return {"status":status, "rows":rows, "met":count, "attempt":attempt.duplicate(true), "completed_day":int(state["completed_day"])}


static func observe(state: Dictionary, record: Dictionary, on_day: int, completed: Array) -> Dictionary:
	# Preserve the first passing receipt, even if its notebook row is deleted or
	# another menu subsequently fails. Bounded storage never grows per day.
	if state["start"].is_empty() or review(state)["status"] in ["ready", "mastered"]: return state.duplicate(true)
	var wait_total: int = 0
	var star_sum: int = 0
	for order in completed:
		wait_total += int(order["wait"])
		star_sum += int(order["stars"])
	var out: Dictionary = state.duplicate(true)
	out["attempt"] = {"day":on_day, "record_id":int(record["record_id"]), "tasted_day":int(record["tasted_day"]), "name":str(record["name"]), "config":record["config"].duplicate(true), "units":completed.size(), "wait_total":wait_total, "star_sum":star_sum}
	return out


## Local consistency validation, not cryptographic anti-cheat. Validate every
## field before replacing live state, including evidence for deleted recipes.
static func parse(raw: Variant, day: int, next_id: int, rank: int, slots: int, discovered: Array, records: Array) -> Dictionary:
	var fail: Dictionary = {"error":"요리사 도전 저장이 올바르지 않아요.", "state":{}}
	if typeof(raw) != TYPE_DICTIONARY or Check.keys_error(raw,["start","attempt","completed_day"],"요리사 도전") != "": return fail
	if typeof(raw["start"]) != TYPE_DICTIONARY or typeof(raw["attempt"]) != TYPE_DICTIONARY or not Check.in_range(raw["completed_day"],0,day): return fail
	var out: Dictionary = raw.duplicate(true)
	var start: Dictionary = out["start"]
	var attempt: Dictionary = out["attempt"]
	out["completed_day"] = int(out["completed_day"])
	if start.is_empty():
		if not attempt.is_empty() or out["completed_day"] != 0: return fail
		return {"error":"", "state":out}
	if Check.keys_error(start,["day","min_record_id","config"],"도전 수락") != "" or not Check.in_range(start["day"],1,day) or not Check.in_range(start["min_record_id"],1,next_id): return fail
	if not _config(start,rank,slots,discovered): return fail
	start["day"] = int(start["day"])
	start["min_record_id"] = int(start["min_record_id"])
	if not attempt.is_empty():
		if Check.keys_error(attempt,["day","record_id","tasted_day","name","config","units","wait_total","star_sum"],"도전 영업") != "": return fail
		if not Check.in_range(attempt["day"],int(start["day"]),day-1) or not Check.in_range(attempt["record_id"],1,next_id-1) or not Check.in_range(attempt["tasted_day"],1,int(attempt["day"])): return fail
		if typeof(attempt["name"]) != TYPE_STRING or Check.name_error(attempt["name"],false) != "" or attempt["name"] != attempt["name"].strip_edges(): return fail
		if not Check.in_range(attempt["units"],0,1000) or not Check.in_range(attempt["wait_total"],0,int(attempt["units"])*Session.HARD_LIMIT) or not Check.in_range(attempt["star_sum"],int(attempt["units"]),int(attempt["units"])*5): return fail
		if not _config(attempt,rank,slots,discovered): return fail
		for key in ["day","record_id","tasted_day","units","wait_total","star_sum"]: attempt[key] = int(attempt[key])
		for record in records:
			if int(record["record_id"]) == int(attempt["record_id"]) and (record["name"] != attempt["name"] or int(record["tasted_day"]) != int(attempt["tasted_day"]) or not Check.same_config(record["config"],attempt["config"])): return fail
	if out["completed_day"] > 0 and (attempt.is_empty() or int(out["completed_day"]) <= int(attempt["day"]) or review(out)["met"] != 6): return fail
	return {"error":"", "state":out}


static func _config(container: Dictionary, rank: int, slots: int, discovered: Array) -> bool:
	var parsed: Dictionary = Check.parse_config(container["config"],"도전 구성",false)
	if str(parsed["error"]) != "": return false
	var config: Dictionary = parsed["config"]
	if Catalog.toppings_of(config).size() > slots or Exploration.locked_in(config,discovered) != "": return false
	if int(Process.effects(config.get("process",{}))["rank"]) > rank: return false
	container["config"] = config
	return true
