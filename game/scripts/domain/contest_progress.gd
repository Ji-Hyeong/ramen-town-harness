extends RefCounted
const ProcessRules = preload("res://scripts/domain/recipe_process.gd")
## 콘테스트 거래와 영수증은 UI 시간과 분리한다. 모든 검증이 끝난 새 상태만 돌려주므로
## 잔액 부족/잘못된 입력/보상 상한에서 비용이나 진행 일부만 반영되지 않는다.
const Contest = preload("res://scripts/domain/ramen_contest.gd")
const Catalog = preload("res://scripts/domain/ingredient_catalog.gd")
const Check = preload("res://scripts/domain/data_check.gd")
const MAX_HISTORY: int = 12
const MAX_WALLET: int = 1000000000
const KEYS: Array = ["last_entry_day", "attempts", "bests", "history", "articles"]
const RECEIPT_KEYS: Array = ["contest_id", "record_id", "recipe_name", "version", "day", "config", "score", "band", "prior_band", "fee", "prize"]


static func empty_state() -> Dictionary:
	return {"last_entry_day": 0, "attempts": 0, "bests": [], "history": [], "articles": []}


static func best(state: Dictionary, id: String) -> Dictionary:
	for r in state["bests"]:
		if str(r["contest_id"]) == id:
			return r.duplicate(true)
	return {}


static func article(state: Dictionary, id: String) -> Dictionary:
	for a in state["articles"]:
		if str(a["contest_id"]) == id:
			return a.duplicate(true)
	return {}


static func enter(state: Dictionary, id: String, record: Dictionary, day: int, rank: int, wallet: int) -> Dictionary:
	var def: Dictionary = Contest.find(id)
	if def.is_empty():
		return _error("알 수 없는 콘테스트예요.")
	if rank < int(def["rank"]) or day < int(def["min_day"]):
		return _error("가게 등급 %d · %d일차부터 출품할 수 있어요." % [int(def["rank"]), int(def["min_day"])])
	if int(state["last_entry_day"]) == day:
		return _error("오늘은 이미 출품했어요. 영업을 마치면 다음 기회가 와요.")
	var previous: Dictionary = best(state, id)
	var prior: int = int(previous.get("band", 0))
	if prior == 3:
		return _error("이미 금상을 받았어요. 이 대회에는 다시 비용을 내지 않아요.")
	if record.is_empty():
		return _error("먼저 시식한 메뉴를 노트에서 선택하세요.")
	if wallet < int(def["fee"]):
		return _error("출품료 %d원이 필요해요." % int(def["fee"]))
	var result: Dictionary = Contest.evaluate(id, record["config"])
	if str(result["error"]) != "":
		return _error(str(result["error"]))
	var band: int = int(result["band"])
	# 상금은 새 메달까지의 누적 상한에서 이전 상금을 뺀 차액뿐이다. 같은 결과를 반복해도 0원.
	var prize: int = maxi(0, Contest.prize_for(band) - Contest.prize_for(prior))
	var cash: int = wallet - int(def["fee"]) + prize
	if cash > MAX_WALLET:
		return _error("상금을 받으면 자금 상한을 넘어요. 거래하지 않았어요.")
	var receipt: Dictionary = {"contest_id": id, "record_id": int(record["record_id"]), "recipe_name": str(record["name"]),
		"version": int(record["version"]), "day": day, "config": result["config"].duplicate(true),
		"score": int(result["score"]), "band": band, "prior_band": prior, "fee": int(def["fee"]), "prize": prize}
	var next: Dictionary = state.duplicate(true)
	next["last_entry_day"] = day
	next["attempts"] = int(next["attempts"]) + 1
	next["history"].append(receipt.duplicate(true))
	if next["history"].size() > MAX_HISTORY:
		next["history"].pop_front()
	if band > prior:
		var updated: Array = []
		for known in Contest.ids():
			var saved: Dictionary = receipt if known == id else best(next, known)
			if not saved.is_empty():
				updated.append(saved.duplicate(true))
		next["bests"] = updated
	return {"error": "", "state": next, "wallet": cash, "receipt": receipt.duplicate(true)}


static func claim_article(state: Dictionary, id: String, day: int, wallet: int) -> Dictionary:
	var def: Dictionary = Contest.find(id)
	if def.is_empty():
		return _error("알 수 없는 잡지 소개예요.")
	var entry: Dictionary = best(state, id)
	if entry.is_empty() or int(entry["band"]) < 2:
		return _error("은상 이상을 받으면 잡지의 소개 제안이 와요.")
	if not article(state, id).is_empty():
		return _error("이미 잡지에 실린 메뉴예요. 협조비는 한 번만 받아요.")
	var cash: int = int(def["article_cash"])
	if wallet + cash > MAX_WALLET:
		return _error("협조비를 받으면 자금 상한을 넘어요. 진행하지 않았어요.")
	var receipt: Dictionary = {"contest_id": id, "day": day, "cash": cash, "entry": entry.duplicate(true)}
	var next: Dictionary = state.duplicate(true)
	next["articles"].append(receipt.duplicate(true))
	return {"error": "", "state": next, "wallet": wallet + cash, "receipt": receipt}


## 원래 메뉴를 지워도 출품/잡지 기록은 남는다. 영수증 자체의 구성과 점수를 재계산하고,
## 노트에 남은 메뉴는 이름/버전/구성이 동일한지도 검증한다. 발견 재료는 출품일 전에 얻어야 한다.
static func _parse_receipt(raw: Variant, day: int, rank: int, next_id: int, records: Dictionary, discoveries: Array, slots: int) -> Dictionary:
	if typeof(raw) != TYPE_DICTIONARY:
		return _error("출품 영수증 구조가 올바르지 않아요.")
	var r: Dictionary = raw
	var err: String = Check.keys_error(r, RECEIPT_KEYS, "출품 기록")
	if err != "":
		return _error(err)
	if typeof(r["contest_id"]) != TYPE_STRING:
		return _error("대회 이름 형식이 올바르지 않아요.")
	var def: Dictionary = Contest.find(str(r["contest_id"]))
	if def.is_empty() or rank < int(def["rank"]):
		return _error("출품 대회/등급이 올바르지 않아요.")
	if not Check.in_range(r["day"], int(def["min_day"]), day) or not Check.in_range(r["record_id"], 1, next_id - 1) or not Check.in_range(r["version"], 1, 9999):
		return _error("출품 날짜/메뉴 번호가 올바르지 않아요.")
	if typeof(r["recipe_name"]) != TYPE_STRING or Check.name_error(str(r["recipe_name"]), false) != "":
		return _error("출품 메뉴 이름이 올바르지 않아요.")
	var parsed: Dictionary = Check.parse_config(r["config"], "출품 구성")
	if str(parsed["error"]) != "":
		return _error(str(parsed["error"]))
	var config: Dictionary = parsed["config"]
	if int(ProcessRules.effects(config.get("process", {}))["rank"]) > rank:
		return _error("출품 공법에 필요한 가게 등급이 없어요.")
	if Catalog.toppings_of(config).size() > slots:
		return _error("출품 토핑 수가 열린 슬롯을 넘어요.")
	for ingredient in Catalog.item_ids(config):
		if not Catalog.discovery_ids().has(ingredient):
			continue
		var found: bool = false
		for discovery in discoveries:
			if str(discovery["id"]) == ingredient and int(discovery["day"]) <= int(r["day"]):
				found = true
		if not found:
			return _error("출품 전에 발견하지 않은 재료가 있어요.")
	var evaluated: Dictionary = Contest.evaluate(str(r["contest_id"]), config)
	if str(evaluated["error"]) != "":
		return _error(str(evaluated["error"]))
	if not Check.in_range(r["score"], 0, 100) or int(r["score"]) != int(evaluated["score"]) or not Check.in_range(r["band"], 0, 3) or int(r["band"]) != int(evaluated["band"]):
		return _error("출품 점수/메달이 실제 평가와 달라요.")
	if not Check.in_range(r["prior_band"], 0, 2) or not Check.is_whole(r["fee"]) or int(r["fee"]) != int(def["fee"]):
		return _error("이전 메달/출품료가 올바르지 않아요.")
	var prize: int = maxi(0, Contest.prize_for(int(r["band"])) - Contest.prize_for(int(r["prior_band"])))
	if not Check.is_whole(r["prize"]) or int(r["prize"]) != prize:
		return _error("출품 상금 차액이 올바르지 않아요.")
	var normalized: Dictionary = r.duplicate(true)
	for key in ["record_id", "version", "day", "score", "band", "prior_band", "fee", "prize"]:
		normalized[key] = int(r[key])
	normalized["config"] = config
	if records.has(int(r["record_id"])):
		var rec: Dictionary = records[int(r["record_id"])]
		if rec["name"] != r["recipe_name"] or int(rec["version"]) != int(r["version"]) or int(rec["tasted_day"]) > int(r["day"]) or not Check.same_config(rec["config"], config):
			return _error("출품 기록이 노트 메뉴와 달라요.")
	return {"error": "", "receipt": normalized}


static func parse(raw: Variant, day: int, rank: int, next_id: int, records: Dictionary, discoveries: Array, slots: int) -> Dictionary:
	if typeof(raw) != TYPE_DICTIONARY:
		return _error("콘테스트 저장 구조가 올바르지 않아요.")
	var state: Dictionary = raw
	var err: String = Check.keys_error(state, KEYS, "콘테스트")
	if err != "":
		return _error(err)
	if not Check.in_range(state["last_entry_day"], 0, day) or not Check.in_range(state["attempts"], 0, maxi(0, int(state["last_entry_day"]) - 2)):
		return _error("출품 일차/횟수가 올바르지 않아요.")
	for key in ["history", "bests", "articles"]:
		if typeof(state[key]) != TYPE_ARRAY:
			return _error("콘테스트 목록 구조가 올바르지 않아요.")
	var attempts: int = int(state["attempts"])
	if state["history"].size() != mini(MAX_HISTORY, attempts) or state["bests"].size() > mini(3, attempts) or state["articles"].size() > 3:
		return _error("콘테스트 기록 개수가 올바르지 않아요.")
	if attempts == 0:
		if int(state["last_entry_day"]) != 0 or not state["bests"].is_empty() or not state["articles"].is_empty():
			return _error("출품 없이 보상 기록이 있어요.")
		return {"error": "", "state": empty_state()}
	var out: Dictionary = empty_state()
	out["last_entry_day"] = int(state["last_entry_day"])
	out["attempts"] = attempts
	var by_best: Dictionary = {}
	for raw_best in state["bests"]:
		var b: Dictionary = _parse_receipt(raw_best, day, rank, next_id, records, discoveries, slots)
		if str(b["error"]) != "":
			return b
		var r: Dictionary = b["receipt"]
		var id: String = str(r["contest_id"])
		if by_best.has(id) or int(r["band"]) <= int(r["prior_band"]) or int(r["prize"]) <= 0 or int(r["day"]) > int(state["last_entry_day"]):
			return _error("최고 메달 기록이 중복되거나 모순돼요.")
		by_best[id] = r
		out["bests"].append(r)
	var previous_day: int = 0
	var known_bands: Dictionary = {}
	var improved: Dictionary = {}
	for raw_receipt in state["history"]:
		var p: Dictionary = _parse_receipt(raw_receipt, day, rank, next_id, records, discoveries, slots)
		if str(p["error"]) != "":
			return p
		var r: Dictionary = p["receipt"]
		var id: String = str(r["contest_id"])
		var prior: int = int(r["prior_band"])
		if int(r["day"]) <= previous_day or int(r["day"]) > int(state["last_entry_day"]):
			return _error("출품 기록은 하루 한 번, 날짜 순서여야 해요.")
		if not known_bands.has(id):
			known_bands[id] = 0 if attempts <= MAX_HISTORY else prior
		if int(known_bands[id]) != prior:
			return _error("이전 메달과 상금 이력이 어긋나요.")
		known_bands[id] = maxi(prior, int(r["band"]))
		if int(r["band"]) > prior:
			improved[id] = r
		previous_day = int(r["day"])
		out["history"].append(r)
	if previous_day != int(state["last_entry_day"]):
		return _error("마지막 출품일과 영수증이 달라요.")
	for id in known_bands:
		if int(known_bands[id]) > 0 and (not by_best.has(id) or int(by_best[id]["band"]) != int(known_bands[id])):
			return _error("최근 메달과 최고 기록이 어긋나요.")
	for id in by_best:
		var b: Dictionary = by_best[id]
		# 최근 창 안에 개선이 있으면 날짜를 옛날로 바꿔도 그 개선 영수증이 최고 기록이어야 한다.
		if improved.has(id):
			if JSON.stringify(improved[id], "", true) != JSON.stringify(b, "", true):
				return _error("최고 메달 영수증이 실제 출품 이력에 없어요.")
		elif int(b["day"]) >= int(out["history"][0]["day"]):
			return _error("최고 메달 날짜에 해당하는 개선 이력이 없어요.")
	var article_ids: Array = []
	for raw_article in state["articles"]:
		if typeof(raw_article) != TYPE_DICTIONARY:
			return _error("잡지 영수증 구조가 올바르지 않아요.")
		var a: Dictionary = raw_article
		if Check.keys_error(a, ["contest_id", "day", "cash", "entry"], "잡지") != "" or typeof(a["contest_id"]) != TYPE_STRING:
			return _error("잡지 항목이 올바르지 않아요.")
		var id: String = str(a["contest_id"])
		var def: Dictionary = Contest.find(id)
		if def.is_empty() or article_ids.has(id) or not by_best.has(id) or int(by_best[id]["band"]) < 2:
			return _error("잡지 제안/중복 기록이 올바르지 않아요.")
		var ep: Dictionary = _parse_receipt(a["entry"], day, rank, next_id, records, discoveries, slots)
		if str(ep["error"]) != "":
			return ep
		var entry: Dictionary = ep["receipt"]
		if str(entry["contest_id"]) != id or int(entry["band"]) < 2 or int(entry["band"]) > int(by_best[id]["band"]) or not Check.in_range(a["day"], int(entry["day"]), day) or not Check.is_whole(a["cash"]) or int(a["cash"]) != int(def["article_cash"]):
			return _error("잡지 날짜/메뉴/협조비가 올바르지 않아요.")
		# 같은 메달의 최고 기록은 교체하지 않으므로, 해당 메달이면 영수증도 완전히 같아야 한다.
		if int(entry["band"]) == int(by_best[id]["band"]) and JSON.stringify(entry, "", true) != JSON.stringify(by_best[id], "", true):
			return _error("잡지에 소개한 메뉴와 수상 기록이 달라요.")
		if int(entry["band"]) <= int(entry["prior_band"]) or int(entry["prize"]) <= 0:
			return _error("잡지에 소개한 출품은 실제 메달 개선 기록이어야 해요.")
		if int(entry["band"]) < int(by_best[id]["band"]):
			# 과거 은상 소개는 보존하지만, 금상 이후 수락했다면 새 최고 메뉴가 소개돼야 한다.
			var latest: Dictionary = by_best[id]
			if int(latest["prior_band"]) != int(entry["band"]) or int(a["day"]) >= int(latest["day"]) or int(entry["day"]) >= int(latest["day"]):
				return _error("잡지 수락 시점의 최고 메달과 소개 메뉴가 어긋나요.")
		if int(entry["day"]) >= int(out["history"][0]["day"]):
			var source_found: bool = false
			for source in out["history"]:
				if JSON.stringify(source, "", true) == JSON.stringify(entry, "", true):
					source_found = true
			if not source_found:
				return _error("잡지 메뉴가 실제 출품 영수증과 달라요.")
		article_ids.append(id)
		out["articles"].append({"contest_id": id, "day": int(a["day"]), "cash": int(a["cash"]), "entry": entry})
	return {"error": "", "state": out}


static func _error(message: String) -> Dictionary:
	return {"error": message}
