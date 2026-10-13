extends RefCounted
## 게임 상태: 자금/일차, 레시피 노트(불변 스냅샷), 현재 선택/초안, 마지막 피드백과 영업 보고.
##
## 불변 기록 원칙: 시식하면 구성·가격·점수를 deep copy한 기록(record)을 노트에 추가한다.
## 기록은 이후 어떤 편집/선택에도 수정되지 않으며, 외부에는 항상 deep copy만 내보낸다.
## 개정 비교는 시식 시점에 "이전 버전의 구성/점수"를 기록 안에 복사해 두므로,
## 이전 기록이 나중에 삭제돼도 비교 결과는 변하지 않는다.

const Catalog = preload("res://scripts/domain/ingredient_catalog.gd")
const Customers = preload("res://scripts/domain/customer_catalog.gd")
const Check = preload("res://scripts/domain/data_check.gd")
const Evaluator = preload("res://scripts/domain/recipe_evaluator.gd")
const Sim = preload("res://scripts/domain/sales_simulator.gd")

const SCHEMA_VERSION: int = 1
const MAX_RECORDS: int = 30
const START_WALLET: int = 30000
const MAX_WALLET: int = 1000000000
const MAX_DAY: int = 99999
const MAX_VERSION: int = 9999

const TOP_KEYS: Array = ["schema_version", "day", "wallet", "next_record_id", "next_lineage_id",
	"records", "selected_record_id", "last_feedback_record_id", "draft", "last_report"]
const RECORD_KEYS: Array = ["record_id", "lineage_id", "name", "version", "tasted_day", "config", "scores", "comparison"]
const COMPARISON_KEYS: Array = ["prev_record_id", "prev_version", "prev_scores", "prev_config"]
const DRAFT_KEYS: Array = ["config", "name", "lineage_id"]
const REPORT_KEYS: Array = ["day", "recipe_name", "version", "price", "units", "revenue",
	"ingredient_cost", "overhead", "net", "wallet_after", "by_source"]

var day: int = 1
var wallet: int = START_WALLET
var next_record_id: int = 1
var next_lineage_id: int = 1
var selected_record_id: int = 0
var last_feedback_record_id: int = 0
var last_report: Dictionary = {}
var draft_config: Dictionary = {}
var draft_name: String = ""
var draft_lineage_id: int = 0
var _records: Array = []


func _init() -> void:
	draft_config = Catalog.default_config()
	draft_name = _suggest_name()


# ---------- 조회 (항상 deep copy) ----------

func record_count() -> int:
	return _records.size()


func records() -> Array:
	return _records.duplicate(true)


func get_record(id: int) -> Dictionary:
	var idx: int = _index_of(id)
	if idx < 0:
		return {}
	var r: Dictionary = _records[idx]
	return r.duplicate(true)


func _index_of(id: int) -> int:
	for i in _records.size():
		var r: Dictionary = _records[i]
		if int(r["record_id"]) == id:
			return i
	return -1


func _latest_in_lineage(lineage: int) -> Dictionary:
	var best: Dictionary = {}
	for r in _records:
		var d: Dictionary = r
		if int(d["lineage_id"]) == lineage and (best.is_empty() or int(d["version"]) > int(best["version"])):
			best = d
	return best


func _suggest_name() -> String:
	var n: int = 1
	while true:
		var candidate: String = "시제품 %d" % n
		var used: bool = false
		for r in _records:
			var d: Dictionary = r
			if str(d["name"]) == candidate:
				used = true
		if not used:
			return candidate
		n += 1
	return ""


# ---------- 초안 편집 ----------

func set_draft_choice(slot: String, id: String) -> Dictionary:
	if not Catalog.SLOTS.has(slot) or not Catalog.is_valid(slot, id):
		return _fail("알 수 없는 재료예요.")
	draft_config[slot] = id
	return _ok("")


func set_draft_price(price: int) -> Dictionary:
	if price < Catalog.PRICE_MIN or price > Catalog.PRICE_MAX or price % Catalog.PRICE_STEP != 0:
		return _fail("가격은 %d~%d원, %d원 단위로 정해요." % [Catalog.PRICE_MIN, Catalog.PRICE_MAX, Catalog.PRICE_STEP])
	draft_config["price"] = price
	return _ok("")


## 이름은 입력 중에는 그대로 저장하고, 시식 때 검증한다. 개정 중에는 이름을 바꿀 수 없다.
func set_draft_name(text: String) -> Dictionary:
	if draft_lineage_id != 0:
		return _fail("개정 중인 레시피는 이름을 바꿀 수 없어요.")
	draft_name = text
	return _ok("")


## 새 레시피 시작: 개정 연결과 선택을 풀고 구성은 그대로 둔다.
func start_new_recipe() -> void:
	draft_lineage_id = 0
	selected_record_id = 0
	draft_name = _suggest_name()


## 노트에서 선택: 구성/가격/익힘/이름을 복원하고 이후 시식은 같은 레시피의 새 버전이 된다.
func select_record(id: int) -> Dictionary:
	var idx: int = _index_of(id)
	if idx < 0:
		return _fail("노트에 없는 기록이에요.")
	var r: Dictionary = _records[idx]
	var cfg: Dictionary = r["config"]
	draft_config = cfg.duplicate(true)
	draft_name = str(r["name"])
	draft_lineage_id = int(r["lineage_id"])
	selected_record_id = id
	last_feedback_record_id = id
	return _ok("")


func delete_record(id: int) -> Dictionary:
	var idx: int = _index_of(id)
	if idx < 0:
		return _fail("노트에 없는 기록이에요.")
	var removed: Dictionary = _records[idx]
	var lineage: int = int(removed["lineage_id"])
	_records.remove_at(idx)
	if selected_record_id == id:
		selected_record_id = 0
	if last_feedback_record_id == id:
		last_feedback_record_id = 0
	if draft_lineage_id == lineage and _latest_in_lineage(lineage).is_empty():
		draft_lineage_id = 0
	return _ok("기록을 삭제했어요.")


# ---------- 시식 ----------

func trial_cost() -> int:
	return Evaluator.unit_cost(draft_config)


func taste() -> Dictionary:
	var cfg_err: String = Check.config_error(draft_config)
	if cfg_err != "":
		return _fail(cfg_err)
	var clean_name: String = draft_name.strip_edges()
	var name_err: String = Check.name_error(clean_name, false)
	if name_err != "":
		return _fail(name_err)

	var base: Dictionary = {}
	if draft_lineage_id != 0:
		base = _latest_in_lineage(draft_lineage_id)
	if not base.is_empty() and str(base["name"]) != clean_name:
		return _fail("개정 중에는 이름이 같아야 해요.")
	if base.is_empty():
		for r in _records:
			var rd: Dictionary = r
			if str(rd["name"]) == clean_name:
				return _fail("같은 이름의 레시피가 이미 있어요. 노트에서 불러와 개정하거나 다른 이름을 쓰세요.")
	# 우발적 중복 방지: 이름과 무관하게 같은 구성·가격·익힘이면 새 기록을 만들지 않는다.
	for r in _records:
		var rd2: Dictionary = r
		var existing_cfg: Dictionary = rd2["config"]
		if Check.same_config(existing_cfg, draft_config):
			return _fail("이미 같은 구성이 '%s v%d'로 기록돼 있어요. 재료나 가격을 바꿔 보세요." % [str(rd2["name"]), int(rd2["version"])])
	if _records.size() >= MAX_RECORDS:
		return _fail("노트가 가득 찼어요 (%d개). 기록을 삭제한 뒤 시식하세요." % MAX_RECORDS)
	var version: int = 1
	if not base.is_empty():
		version = int(base["version"]) + 1
	if version > MAX_VERSION:
		return _fail("이 레시피는 더 이상 개정할 수 없어요.")
	var cost: int = trial_cost()
	if cost > wallet:
		return _fail("시제품 재료비(%d원)가 보유 자금보다 많아요." % cost)

	var evaluation: Dictionary = Evaluator.evaluate(draft_config)
	var scores: Dictionary = {}
	for c in evaluation["customers"]:
		var cd: Dictionary = c
		scores[str(cd["id"])] = int(cd["score"])

	var lineage: int = draft_lineage_id
	if lineage == 0:
		lineage = next_lineage_id
		next_lineage_id += 1
	var comparison: Dictionary = {}
	if not base.is_empty():
		var prev_scores: Dictionary = base["scores"]
		var prev_cfg: Dictionary = base["config"]
		comparison = {
			"prev_record_id": int(base["record_id"]),
			"prev_version": int(base["version"]),
			"prev_scores": prev_scores.duplicate(true),
			"prev_config": prev_cfg.duplicate(true),
		}
	var record: Dictionary = {
		"record_id": next_record_id,
		"lineage_id": lineage,
		"name": clean_name,
		"version": version,
		"tasted_day": day,
		"config": draft_config.duplicate(true),
		"scores": scores,
		"comparison": comparison,
	}
	next_record_id += 1
	_records.append(record)
	wallet -= cost
	draft_name = clean_name
	draft_lineage_id = lineage
	selected_record_id = int(record["record_id"])
	last_feedback_record_id = int(record["record_id"])
	var res: Dictionary = _ok("'%s v%d' 시식 완료 (재료비 %d원)" % [clean_name, version, cost])
	res["record_id"] = int(record["record_id"])
	return res


# ---------- 영업(하루) ----------

func forecast() -> Dictionary:
	var rec: Dictionary = get_record(selected_record_id)
	if rec.is_empty():
		return {"error": "노트에서 영업할 레시피를 먼저 선택하세요."}
	return Sim.simulate(rec["config"], rec["scores"], day)


## 영업 1회 = 정확히 1일. 시뮬레이션은 결정적이므로 forecast()와 결과가 같다.
func serve() -> Dictionary:
	var rec: Dictionary = get_record(selected_record_id)
	if rec.is_empty():
		return _fail("노트에서 영업할 레시피를 먼저 선택하세요.")
	if day >= MAX_DAY:
		return _fail("더 이상 영업일을 늘릴 수 없어요.")
	var sim: Dictionary = Sim.simulate(rec["config"], rec["scores"], day)
	if str(sim["error"]) != "":
		return _fail(str(sim["error"]))
	var after: int = wallet + int(sim["net"])
	if after < 0:
		return _fail("자금이 부족해서 오늘은 영업을 열 수 없어요.")
	if after > MAX_WALLET:
		return _fail("보유 자금 한도에 도달했어요.")
	var cfg: Dictionary = rec["config"]
	last_report = {
		"day": day,
		"recipe_name": str(rec["name"]),
		"version": int(rec["version"]),
		"price": int(cfg["price"]),
		"units": int(sim["units"]),
		"revenue": int(sim["revenue"]),
		"ingredient_cost": int(sim["ingredient_cost"]),
		"overhead": int(sim["overhead"]),
		"net": int(sim["net"]),
		"wallet_after": after,
		"by_source": (sim["by_source"] as Dictionary).duplicate(true),
	}
	wallet = after
	day += 1
	var res: Dictionary = _ok("%d일차 영업을 마쳤어요." % int(last_report["day"]))
	res["report"] = last_report.duplicate(true)
	return res


# ---------- 저장 직렬화 ----------

func to_dict() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"day": day,
		"wallet": wallet,
		"next_record_id": next_record_id,
		"next_lineage_id": next_lineage_id,
		"records": _records.duplicate(true),
		"selected_record_id": selected_record_id,
		"last_feedback_record_id": last_feedback_record_id,
		"draft": {
			"config": draft_config.duplicate(true),
			"name": draft_name,
			"lineage_id": draft_lineage_id,
		},
		"last_report": last_report.duplicate(true),
	}


## 전체를 먼저 임시 변수에 검증한 뒤 한 번에 반영한다. 하나라도 틀리면 상태는 그대로이고
## 오류 메시지를 돌려준다(일부만 받아들이는 손실 로드는 하지 않는다). 성공이면 "".
func load_from_dict(raw: Variant) -> String:
	if typeof(raw) != TYPE_DICTIONARY:
		return "저장 구조가 올바르지 않아요."
	var d: Dictionary = raw
	var key_err: String = Check.keys_error(d, TOP_KEYS, "저장")
	if key_err != "":
		return key_err
	if not Check.in_range(d["schema_version"], SCHEMA_VERSION, SCHEMA_VERSION):
		return "지원하지 않는 저장 버전이에요."
	if not Check.in_range(d["day"], 1, MAX_DAY):
		return "일차 값이 범위를 벗어났어요."
	if not Check.in_range(d["wallet"], 0, MAX_WALLET):
		return "자금 값이 범위를 벗어났어요."
	if not Check.in_range(d["next_record_id"], 1, 1000000000) or not Check.in_range(d["next_lineage_id"], 1, 1000000000):
		return "일련번호가 범위를 벗어났어요."
	if typeof(d["records"]) != TYPE_ARRAY:
		return "기록 목록 구조가 올바르지 않아요."
	var raw_records: Array = d["records"]
	if raw_records.size() > MAX_RECORDS:
		return "기록 수가 한도(%d)를 넘었어요." % MAX_RECORDS
	var n_record: int = int(d["next_record_id"])
	var n_lineage: int = int(d["next_lineage_id"])

	var parsed: Array = []
	var seen_ids: Dictionary = {}
	var lineage_names: Dictionary = {}
	var seen_versions: Dictionary = {}
	for i in raw_records.size():
		var pr: Dictionary = _parse_record(raw_records[i], i, n_record, n_lineage, int(d["day"]))
		if str(pr["error"]) != "":
			return str(pr["error"])
		var rec: Dictionary = pr["record"]
		var rid: int = int(rec["record_id"])
		if seen_ids.has(rid):
			return "기록 번호가 중복됐어요."
		seen_ids[rid] = true
		var lin: int = int(rec["lineage_id"])
		if lineage_names.has(lin) and str(lineage_names[lin]) != str(rec["name"]):
			return "같은 레시피의 이름이 서로 달라요."
		lineage_names[lin] = str(rec["name"])
		var vkey: String = "%d:%d" % [lin, int(rec["version"])]
		if seen_versions.has(vkey):
			return "같은 레시피의 버전이 중복됐어요."
		seen_versions[vkey] = true
		parsed.append(rec)

	var sel_ok: bool = Check.in_range(d["selected_record_id"], 0, 1000000000)
	var fb_ok: bool = Check.in_range(d["last_feedback_record_id"], 0, 1000000000)
	if not sel_ok or not fb_ok:
		return "선택/피드백 번호가 올바르지 않아요."
	var sel: int = int(d["selected_record_id"])
	var fb: int = int(d["last_feedback_record_id"])
	if sel != 0 and not seen_ids.has(sel):
		return "선택된 기록이 노트에 없어요."
	if fb != 0 and not seen_ids.has(fb):
		return "마지막 피드백 기록이 노트에 없어요."

	if typeof(d["draft"]) != TYPE_DICTIONARY:
		return "초안 구조가 올바르지 않아요."
	var draft: Dictionary = d["draft"]
	var draft_key_err: String = Check.keys_error(draft, DRAFT_KEYS, "초안")
	if draft_key_err != "":
		return draft_key_err
	var dcfg: Dictionary = Check.parse_config(draft["config"], "초안")
	if str(dcfg["error"]) != "":
		return str(dcfg["error"])
	if typeof(draft["name"]) != TYPE_STRING:
		return "초안 이름 형식이 올바르지 않아요."
	var dname: String = draft["name"]
	var dname_err: String = Check.name_error(dname, true)
	if dname_err != "":
		return "초안: " + dname_err
	if not Check.in_range(draft["lineage_id"], 0, n_lineage - 1):
		return "초안의 레시피 번호가 올바르지 않아요."
	var dlin: int = int(draft["lineage_id"])
	if dlin != 0:
		if not lineage_names.has(dlin):
			return "초안이 노트에 없는 레시피를 가리켜요."
		if str(lineage_names[dlin]) != dname:
			return "초안 이름이 레시피 이름과 달라요."

	var rep_result: Dictionary = _parse_report(d["last_report"], int(d["day"]), seen_ids)
	if str(rep_result["error"]) != "":
		return str(rep_result["error"])

	# 모든 검증 통과 후 반영
	day = int(d["day"])
	wallet = int(d["wallet"])
	next_record_id = n_record
	next_lineage_id = n_lineage
	_records = parsed
	selected_record_id = sel
	last_feedback_record_id = fb
	draft_config = dcfg["config"]
	draft_name = dname
	draft_lineage_id = dlin
	last_report = rep_result["report"]
	return ""


func _parse_record(raw: Variant, index: int, n_record: int, n_lineage: int, current_day: int) -> Dictionary:
	var ctx: String = "기록 %d" % (index + 1)
	if typeof(raw) != TYPE_DICTIONARY:
		return {"error": ctx + ": 구조가 올바르지 않아요."}
	var d: Dictionary = raw
	var key_err: String = Check.keys_error(d, RECORD_KEYS, ctx)
	if key_err != "":
		return {"error": key_err}
	if not Check.in_range(d["record_id"], 1, n_record - 1):
		return {"error": ctx + ": 기록 번호가 올바르지 않아요."}
	if not Check.in_range(d["lineage_id"], 1, n_lineage - 1):
		return {"error": ctx + ": 레시피 번호가 올바르지 않아요."}
	if not Check.in_range(d["version"], 1, MAX_VERSION):
		return {"error": ctx + ": 버전이 올바르지 않아요."}
	if not Check.in_range(d["tasted_day"], 1, current_day):
		return {"error": ctx + ": 시식일이 올바르지 않아요."}
	if typeof(d["name"]) != TYPE_STRING:
		return {"error": ctx + ": 이름 형식이 올바르지 않아요."}
	var rname: String = d["name"]
	var name_err: String = Check.name_error(rname, false)
	if name_err != "" or rname != rname.strip_edges():
		return {"error": ctx + ": 이름이 올바르지 않아요."}
	var cfg_res: Dictionary = Check.parse_config(d["config"], ctx)
	if str(cfg_res["error"]) != "":
		return {"error": str(cfg_res["error"])}
	var scores_res: Dictionary = _parse_scores(d["scores"], ctx)
	if str(scores_res["error"]) != "":
		return {"error": str(scores_res["error"])}
	var config: Dictionary = cfg_res["config"]
	var scores: Dictionary = scores_res["scores"]
	# 점수는 결정적 평가 결과여야 한다. 저장된 값이 구성과 맞지 않으면 변조/손상으로 본다.
	var evaluation: Dictionary = Evaluator.evaluate(config)
	for c in evaluation["customers"]:
		var cd: Dictionary = c
		if int(scores[str(cd["id"])]) != int(cd["score"]):
			return {"error": ctx + ": 점수가 구성과 일치하지 않아요."}
	var comparison: Dictionary = {}
	if typeof(d["comparison"]) != TYPE_DICTIONARY:
		return {"error": ctx + ": 비교 구조가 올바르지 않아요."}
	var raw_cmp: Dictionary = d["comparison"]
	if not raw_cmp.is_empty():
		var cmp_err: String = Check.keys_error(raw_cmp, COMPARISON_KEYS, ctx + " 비교")
		if cmp_err != "":
			return {"error": cmp_err}
		if not Check.in_range(raw_cmp["prev_record_id"], 1, n_record - 1):
			return {"error": ctx + ": 이전 기록 번호가 올바르지 않아요."}
		if not Check.in_range(raw_cmp["prev_version"], 1, int(d["version"]) - 1):
			return {"error": ctx + ": 이전 버전이 올바르지 않아요."}
		var prev_scores_res: Dictionary = _parse_scores(raw_cmp["prev_scores"], ctx + " 비교")
		if str(prev_scores_res["error"]) != "":
			return {"error": str(prev_scores_res["error"])}
		var prev_cfg_res: Dictionary = Check.parse_config(raw_cmp["prev_config"], ctx + " 비교")
		if str(prev_cfg_res["error"]) != "":
			return {"error": str(prev_cfg_res["error"])}
		comparison = {
			"prev_record_id": int(raw_cmp["prev_record_id"]),
			"prev_version": int(raw_cmp["prev_version"]),
			"prev_scores": prev_scores_res["scores"],
			"prev_config": prev_cfg_res["config"],
		}
	var record: Dictionary = {
		"record_id": int(d["record_id"]),
		"lineage_id": int(d["lineage_id"]),
		"name": rname,
		"version": int(d["version"]),
		"tasted_day": int(d["tasted_day"]),
		"config": config,
		"scores": scores,
		"comparison": comparison,
	}
	return {"error": "", "record": record}


func _parse_scores(raw: Variant, ctx: String) -> Dictionary:
	if typeof(raw) != TYPE_DICTIONARY:
		return {"error": ctx + ": 점수 구조가 올바르지 않아요."}
	var d: Dictionary = raw
	var ids: Array[String] = Customers.ids()
	var key_err: String = Check.keys_error(d, ids, ctx + " 점수")
	if key_err != "":
		return {"error": key_err}
	var out: Dictionary = {}
	for id in ids:
		if not Check.in_range(d[id], 0, 100):
			return {"error": ctx + ": 점수가 0~100 범위를 벗어났어요."}
		out[id] = int(d[id])
	return {"error": "", "scores": out}


func _parse_report(raw: Variant, current_day: int, record_ids: Dictionary) -> Dictionary:
	if typeof(raw) != TYPE_DICTIONARY:
		return {"error": "영업 보고 구조가 올바르지 않아요."}
	var d: Dictionary = raw
	if d.is_empty():
		return {"error": "", "report": {}}
	var key_err: String = Check.keys_error(d, REPORT_KEYS, "영업 보고")
	if key_err != "":
		return {"error": key_err}
	if not Check.in_range(d["day"], 1, current_day - 1):
		return {"error": "영업 보고의 일차가 올바르지 않아요."}
	if typeof(d["recipe_name"]) != TYPE_STRING or Check.name_error(str(d["recipe_name"]), false) != "":
		return {"error": "영업 보고의 레시피 이름이 올바르지 않아요."}
	if not Check.in_range(d["version"], 1, MAX_VERSION):
		return {"error": "영업 보고의 버전이 올바르지 않아요."}
	if not Check.in_range(d["price"], Catalog.PRICE_MIN, Catalog.PRICE_MAX):
		return {"error": "영업 보고의 가격이 올바르지 않아요."}
	for k in ["units", "revenue", "ingredient_cost", "overhead", "wallet_after"]:
		if not Check.in_range(d[k], 0, MAX_WALLET):
			return {"error": "영업 보고의 %s 값이 올바르지 않아요." % str(k)}
	if not Check.in_range(d["net"], -MAX_WALLET, MAX_WALLET):
		return {"error": "영업 보고의 순이익이 올바르지 않아요."}
	var units: int = int(d["units"])
	if int(d["revenue"]) != units * int(d["price"]):
		return {"error": "영업 보고의 매출이 판매량과 맞지 않아요."}
	if int(d["net"]) != int(d["revenue"]) - int(d["ingredient_cost"]) - int(d["overhead"]):
		return {"error": "영업 보고의 순이익 계산이 맞지 않아요."}
	if typeof(d["by_source"]) != TYPE_DICTIONARY:
		return {"error": "영업 보고의 판매 내역 구조가 올바르지 않아요."}
	var src: Dictionary = d["by_source"]
	var src_keys: Array = Customers.ids()
	src_keys.append(Sim.WALKIN_ID)
	var src_err: String = Check.keys_error(src, src_keys, "판매 내역")
	if src_err != "":
		return {"error": src_err}
	var total: int = 0
	var by_source: Dictionary = {}
	for k in src_keys:
		if not Check.in_range(src[k], 0, MAX_WALLET):
			return {"error": "판매 내역 수량이 올바르지 않아요."}
		by_source[k] = int(src[k])
		total += int(src[k])
	if total != units:
		return {"error": "판매 내역 합계가 판매량과 맞지 않아요."}
	var report: Dictionary = {
		"day": int(d["day"]),
		"recipe_name": str(d["recipe_name"]),
		"version": int(d["version"]),
		"price": int(d["price"]),
		"units": units,
		"revenue": int(d["revenue"]),
		"ingredient_cost": int(d["ingredient_cost"]),
		"overhead": int(d["overhead"]),
		"net": int(d["net"]),
		"wallet_after": int(d["wallet_after"]),
		"by_source": by_source,
	}
	return {"error": "", "report": report}


static func _ok(message: String) -> Dictionary:
	return {"ok": true, "message": message}


static func _fail(message: String) -> Dictionary:
	return {"ok": false, "message": message}
