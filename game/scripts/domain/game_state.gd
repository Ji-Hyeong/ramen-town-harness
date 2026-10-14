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
const Session = preload("res://scripts/domain/service_session.gd")

const Research = preload("res://scripts/domain/ramen_research.gd")
const Growth = preload("res://scripts/domain/shop_growth.gd")
const Staffing = preload("res://scripts/domain/shop_staffing.gd")

## 스키마 v2: 최상위에 "research"(완료한 연구 의뢰 영수증 목록)가 추가됐다.
## v1 저장은 "research" 키가 없는 것이 정상이며, 불러올 때 빈 연구 진행(완료 없음)으로 이행한다(load_from_dict 참고).
## 스키마 v3: 최상위에 "growth"(가게 등급, 산 확장 id 목록, 고용한 직원 id 목록)가 추가되고, 모든 레시피 구성(기록/비교/초안)의
## 토핑이 "topping"(문자열) → "toppings"(카탈로그 순서의 배열)로 바뀐다. 용량(토핑 슬롯/노트/직원 수)은 저장하지 않고 이 값들에서 매번 계산한다.
## v1/v2 저장은 불러올 때 "등급 1단계, 확장/고용 없음"과 "토핑 하나짜리 배열"로 이행한다(자금/일차/기록/점수/보고/연구 영수증은 그대로).
## 다음 저장부터는 v3로 기록되고, 저장 서비스가 덮어쓰기 전에 기존 v1/v2 본 파일을 보존한다(save_service.gd 참고).
const SCHEMA_VERSION: int = 3
const MIN_SCHEMA_VERSION: int = 1
const MAX_RECORDS: int = 30
const START_WALLET: int = 30000
const MAX_WALLET: int = 1000000000
const MAX_DAY: int = 99999
const MAX_VERSION: int = 9999

const TOP_KEYS_V1: Array = ["schema_version", "day", "wallet", "next_record_id", "next_lineage_id",
	"records", "selected_record_id", "last_feedback_record_id", "draft", "last_report"]
const TOP_KEYS_V2: Array = ["schema_version", "day", "wallet", "next_record_id", "next_lineage_id",
	"records", "selected_record_id", "last_feedback_record_id", "draft", "last_report", "research"]
const TOP_KEYS: Array = ["schema_version", "day", "wallet", "next_record_id", "next_lineage_id",
	"records", "selected_record_id", "last_feedback_record_id", "draft", "last_report", "research", "growth"]
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
## 완료한 연구 의뢰 영수증(완료 순서). 총점/칭호/해금은 여기서 계산한다. 항목 구조는 ramen_research.gd 참고.
var _research_done: Array = []
## 가게 성장 상태(저장). 등급 1~3, 산 확장 id(구매 순서), 고용한 직원 id(고용 순서). 용량은 여기서 파생한다.
var _rank: int = 1
var _facilities: Array = []
var _hired: Array = []
## 진행 중인 영업 런타임. 저장하지 않는다(재시작하면 영업 전 상태로 돌아온다). 있는 동안은 레시피/초안/일차를 잠근다.
var _active_session: Session = null


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
	if service_active():
		return _locked_fail()
	if not Catalog.SLOTS.has(slot) or not Catalog.is_valid(slot, id):
		return _fail("알 수 없는 재료예요.")
	if slot == Catalog.TOPPING_SLOT:
		# 예전 호출 모양(토핑 하나 고르기) 호환: 토핑을 그 하나로 바꾼다. 여러 개는 set_draft_toppings/toggle_draft_topping 으로 고른다.
		draft_config["toppings"] = [id]
		return _ok("")
	draft_config[slot] = id
	return _ok("")


## 토핑 한 번에 지정(여러 개). 검증을 모두 마친 뒤에만 초안을 바꾼다: 최소 1개, 지금 열린 슬롯 수 이하, 중복/모르는 id 없음.
## 순서는 상관없다(카탈로그 순서로 정규화되므로 순서만 다른 지정은 같은 레시피다).
func set_draft_toppings(ids: Array) -> Dictionary:
	if service_active():
		return _locked_fail()
	var seen: Dictionary = {}
	for v in ids:
		if typeof(v) != TYPE_STRING or not Catalog.is_valid(Catalog.TOPPING_SLOT, str(v)):
			return _fail("알 수 없는 토핑이에요.")
		if seen.has(str(v)):
			return _fail("같은 토핑을 두 번 고를 수 없어요.")
		seen[str(v)] = true
	if ids.is_empty():
		return _fail("토핑은 최소 1개를 골라야 해요.")
	var slots: int = topping_slots()
	if ids.size() > slots:
		var hint: String = Growth.topping_unlock_hint(_rank, _facilities)
		return _fail("토핑은 지금 %d개까지 올릴 수 있어요. %s" % [slots, hint])
	draft_config["toppings"] = Catalog.canonical_toppings(ids)
	return _ok("")


## 토핑 하나를 넣거나 뺀다(이미 있으면 빼고, 없으면 넣는다). 마지막 하나는 뺄 수 없고, 열린 슬롯 수를 넘겨 넣을 수 없다.
func toggle_draft_topping(id: String) -> Dictionary:
	if service_active():
		return _locked_fail()
	if not Catalog.is_valid(Catalog.TOPPING_SLOT, id):
		return _fail("알 수 없는 토핑이에요.")
	var current: Array = Catalog.toppings_of(draft_config)
	if current.has(id):
		if current.size() <= 1:
			return _fail("토핑은 최소 1개가 필요해요. 다른 토핑을 먼저 고르세요.")
		current.erase(id)
		return set_draft_toppings(current)
	current.append(id)
	return set_draft_toppings(current)


func set_draft_price(price: int) -> Dictionary:
	if service_active():
		return _locked_fail()
	if price <Catalog.PRICE_MIN or price > Catalog.PRICE_MAX or price % Catalog.PRICE_STEP != 0:
		return _fail("가격은 %d~%d원, %d원 단위로 정해요." % [Catalog.PRICE_MIN, Catalog.PRICE_MAX, Catalog.PRICE_STEP])
	draft_config["price"] = price
	return _ok("")


## 이름은 입력 중에는 그대로 저장하고, 시식 때 검증한다. 개정 중에는 이름을 바꿀 수 없다.
func set_draft_name(text: String) -> Dictionary:
	if service_active():
		return _locked_fail()
	if draft_lineage_id != 0:
		return _fail("개정 중인 레시피는 이름을 바꿀 수 없어요.")
	draft_name = text
	return _ok("")


## 새 레시피 시작: 개정 연결과 선택을 풀고 구성은 그대로 둔다.
func start_new_recipe() -> void:
	if service_active():
		return
	draft_lineage_id = 0
	selected_record_id = 0
	draft_name = _suggest_name()


## 노트에서 선택: 구성/가격/익힘/이름을 복원하고 이후 시식은 같은 레시피의 새 버전이 된다.
func select_record(id: int) -> Dictionary:
	if service_active():
		return _locked_fail()
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
	if service_active():
		return _locked_fail()
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
	if service_active():
		return _locked_fail()
	var cfg_err: String = Check.config_error(draft_config)
	if cfg_err != "":
		return _fail(cfg_err)
	if Catalog.toppings_of(draft_config).size() > topping_slots():
		return _fail("토핑이 지금 열린 슬롯(%d개)보다 많아요." % topping_slots())
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
	# 노트 용량은 조리대 확장에서 파생한다(6→12→30, 절대 상한 MAX_RECORDS). 예전 저장이 용량보다 많이 가지고 있으면(grandfather)
	# 기록은 모두 남지만 새 기록은 개수가 용량 아래로 내려갈 때까지 만들 수 없다.
	if _records.size() >= record_capacity():
		return _fail("노트가 가득 찼어요 (%d/%d). 기록을 삭제하거나 조리대를 확장한 뒤 시식하세요." % [_records.size(), record_capacity()])
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
	return Sim.simulate(rec["config"], rec["scores"], day, current_staffing())


## 영업 1회 = 정확히 1일. 시뮬레이션은 결정적이므로 forecast()와 결과가 같다.
## 즉시 정산하는 계산 경로이며 화면은 쓰지 않는다. 실제 플레이는 begin_service()/settle_service()를 거친다
## (회귀 테스트와 "런타임 결과 == 예측" 대조용으로만 남겨 둔다).
func serve() -> Dictionary:
	if service_active():
		return _locked_fail()
	var rec: Dictionary = get_record(selected_record_id)
	if rec.is_empty():
		return _fail("노트에서 영업할 레시피를 먼저 선택하세요.")
	if day >= MAX_DAY:
		return _fail("더 이상 영업일을 늘릴 수 없어요.")
	var sim: Dictionary = Sim.simulate(rec["config"], rec["scores"], day, current_staffing())
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


# ---------- 실시간 영업 (런타임 세션) ----------
##
## 거래 규칙: begin_service()는 자금·일차·기록을 전혀 바꾸지 않는다. 세션이 FINISHED가 되어 settle_service()가
## 성공할 때만 자금/일차/보고가 한 번에 바뀐다. 중단·재시작한 세션은 아무 흔적도 남기지 않는다(부분 정산 없음).
## 세션이 살아 있는 동안 레시피 편집/선택/삭제/시식/즉시 영업은 막혀, 시작할 때 복사한 스냅샷과 어긋날 수 없다.

func service_active() -> bool:
	return _active_session != null


func active_session() -> Session:
	return _active_session


func begin_service() -> Dictionary:
	if _active_session != null:
		return _fail("이미 영업 중이에요.")
	var rec: Dictionary = get_record(selected_record_id)
	if rec.is_empty():
		return _fail("노트에서 영업할 레시피를 먼저 선택하세요.")
	if day >= MAX_DAY:
		return _fail("더 이상 영업일을 늘릴 수 없어요.")
	# 직원/성장 스냅샷은 여기서 한 번만 복사한다. 이후 세션은 이 값만 쓴다(영업 중 고용/구매는 막혀 있다).
	var plan: Dictionary = Session.make_plan(rec, day, current_staffing(), growth_snapshot())
	if str(plan["error"]) != "":
		return _fail(str(plan["error"]))
	var fc: Dictionary = plan["forecast"]
	var after: int = wallet + int(fc["net"])
	if after < 0:
		return _fail("자금이 부족해서 오늘은 영업을 열 수 없어요.")
	if after > MAX_WALLET:
		return _fail("보유 자금 한도에 도달했어요.")
	_active_session = Session.new(plan)
	return _ok("영업을 시작했어요. 끝까지 진행해야 정산되고, 중간에 닫으면 저장되지 않아요.")


## 영업 중단/폐기. 자금·일차·기록은 이미 아무것도 바뀌지 않았으므로 되돌릴 것이 없다.
func cancel_service() -> void:
	if _active_session != null:
		_active_session.cancel()
		_active_session = null


## 끝난 세션의 완료 주문으로 하루를 정산한다. 검증을 모두 마친 뒤에만 상태를 바꾸므로 실패하면 아무 변화가 없다.
## 성공하면 세션이 비워지고 일차가 올라가 같은 세션/같은 날의 두 번째 정산은 구조적으로 불가능하다.
func settle_service() -> Dictionary:
	var s: Session = _active_session
	if s == null:
		return _fail("정산할 영업이 없어요.")
	if s.settled:
		return _fail("이미 정산된 영업이에요.")
	if not s.is_finished():
		return _fail("영업이 아직 끝나지 않았어요. 끝나지 않은 영업은 정산되지 않아요.")
	var sm: Dictionary = s.summary()
	if str(sm["error"]) != "":
		return _fail(str(sm["error"]))
	if int(sm["day"]) != day:
		return _fail("영업일이 달라져 정산할 수 없어요.")
	var rec: Dictionary = get_record(selected_record_id)
	if rec.is_empty() or int(rec["record_id"]) != int(sm["record_id"]):
		return _fail("영업한 레시피와 선택된 레시피가 달라 정산할 수 없어요.")
	var rec_cfg: Dictionary = rec["config"]
	var sm_cfg: Dictionary = sm["config"]
	if not Check.same_config(rec_cfg, sm_cfg):
		return _fail("영업한 레시피 구성이 바뀌어 정산할 수 없어요.")
	# 직원 구성은 세션이 시작 때 복사한 스냅샷이 기준이다. 지금 고용 목록과 다르면(영업 중에는 바뀔 수 없으므로 변조/오류) 정산하지 않는다.
	var sm_staffing: Dictionary = sm["staffing"]
	if str(sm_staffing) != str(current_staffing()):
		return _fail("영업 중 직원 구성이 달라져 정산할 수 없어요.")
	# 도메인 계산이 허용하는 범위를 넘는 판매는 정산하지 않는다(런타임이 수요·용량 한도를 넘길 수 없음을 재확인).
	var fc: Dictionary = Sim.simulate(rec_cfg, rec["scores"], day, sm_staffing)
	if str(fc["error"]) != "":
		return _fail(str(fc["error"]))
	# 운영비(기본 + 보조 직원 하루 운영비)는 이 정산에서 정확히 한 번만 빠진다. 세션 요약의 운영비가 스냅샷 계산과 다르면 거부한다.
	if int(sm["overhead"]) != int(fc["overhead"]):
		return _fail("운영비가 직원 구성과 맞지 않아 정산할 수 없어요.")
	var units: int = int(sm["units"])
	if units > int(fc["units"]):
		return _fail("완료 주문이 영업 한도를 넘어 정산할 수 없어요.")
	var src_sm: Dictionary = sm["by_source"]
	var src_fc: Dictionary = fc["by_source"]
	var src_sum: int = 0
	for k in src_sm:
		if int(src_sm[k]) > int(src_fc[k]):
			return _fail("손님별 완료 주문이 영업 한도를 넘어 정산할 수 없어요.")
		src_sum += int(src_sm[k])
	var price: int = int(rec_cfg["price"])
	if src_sum != units or int(sm["revenue"]) != units * price or int(sm["ingredient_cost"]) != units * Evaluator.unit_cost(rec_cfg):
		return _fail("완료 주문 합계가 맞지 않아 정산할 수 없어요.")
	if day >= MAX_DAY:
		return _fail("더 이상 영업일을 늘릴 수 없어요.")
	var net: int = int(sm["revenue"]) - int(sm["ingredient_cost"]) - int(sm["overhead"])
	var after: int = wallet + net
	if after < 0:
		return _fail("자금이 부족해서 정산할 수 없어요.")
	if after > MAX_WALLET:
		return _fail("보유 자금 한도에 도달했어요.")
	# --- 여기부터는 실패 지점이 없다 ---
	last_report = {
		"day": day,
		"recipe_name": str(rec["name"]),
		"version": int(rec["version"]),
		"price": price,
		"units": units,
		"revenue": int(sm["revenue"]),
		"ingredient_cost": int(sm["ingredient_cost"]),
		"overhead": int(sm["overhead"]),
		"net": net,
		"wallet_after": after,
		"by_source": src_sm.duplicate(true),
	}
	wallet = after
	day += 1
	s.mark_settled()
	_active_session = null
	var res: Dictionary = _ok("%d일차 영업을 마쳤어요." % int(last_report["day"]))
	res["report"] = last_report.duplicate(true)
	res["turned_away"] = int(sm["turned_away"])
	res["avg_stars"] = float(sm["avg_stars"])
	return res


static func _locked_fail() -> Dictionary:
	return {"ok": false, "message": "영업 중에는 레시피와 일차를 바꿀 수 없어요. 영업을 끝내거나 중단한 뒤 다시 해 보세요."}


# ---------- 라멘 연구 ----------
##
## 제출 규칙: 연구는 "시식으로 노트에 남은 불변 기록"만 심사한다. 초안은 심사 대상이 아니다.
## 보상(점수는 완료 목록에서 계산, 자금은 지갑에 즉시 가산)은 submit_research() 성공 시 정확히 한 번만 생긴다.
## 다른 어떤 경로(불러오기, 시식, 기록 선택/삭제, 탭 열기)도 연구 진행과 자금을 바꾸지 않는다.

func research_completed_ids() -> Array:
	var out: Array = []
	for e in _research_done:
		var d: Dictionary = e
		out.append(str(d["request_id"]))
	return out


func research_receipts() -> Array:
	return _research_done.duplicate(true)


func research_points() -> int:
	return Research.points_of(research_completed_ids())


func research_stage() -> Dictionary:
	return Research.stage_for(research_points())


func research_complete() -> bool:
	return _research_done.size() >= Research.REQUESTS.size()


## "done" | "open" | "locked" | "unknown"
func research_status(request_id: String) -> String:
	if Research.find(request_id).is_empty():
		return "unknown"
	var done: Array = research_completed_ids()
	if done.has(request_id):
		return "done"
	return "open" if Research.is_unlocked(request_id, done) else "locked"


func research_lock_reason(request_id: String) -> String:
	return Research.lock_reason(request_id, research_completed_ids())


## 노트에 남은 기록 하나를 의뢰 조건에 대 본 결과(읽기 전용). 기록이 없으면 빈 딕셔너리.
func research_check(request_id: String, record_id: int) -> Dictionary:
	var rec: Dictionary = get_record(record_id)
	if rec.is_empty():
		return {}
	return Research.check(request_id, rec["config"], rec["scores"])


## 연구 제출(명시적 행동). 모든 검증을 먼저 끝내고, 실패하면 아무것도 바꾸지 않는다.
## 성공하면 영수증 추가와 자금 가산이 같은 호출 안에서 함께 일어나 한쪽만 반영되는 상태가 없다.
## 이미 완료한 의뢰는 거부되므로 같은 의뢰의 보상은 구조적으로 두 번 받을 수 없다(저장/불러오기 후에도 같다).
func submit_research(request_id: String, record_id: int) -> Dictionary:
	if service_active():
		return _fail("영업 중에는 연구를 제출할 수 없어요. 영업을 끝내거나 중단한 뒤 다시 해 보세요.")
	var req: Dictionary = Research.find(request_id)
	if req.is_empty():
		return _fail("알 수 없는 연구 의뢰예요.")
	var done: Array = research_completed_ids()
	if done.has(request_id):
		return _fail("이미 완료한 연구예요. 보상은 한 번만 받을 수 있어요.")
	if not Research.is_unlocked(request_id, done):
		return _fail("아직 잠겨 있어요. " + Research.lock_reason(request_id, done))
	if _research_done.size() >= Research.REQUESTS.size():
		return _fail("이번 연구 과정은 모두 마쳤어요.")
	var rec: Dictionary = get_record(record_id)
	if rec.is_empty():
		return _fail("제출할 시식 기록이 없어요. 시식을 마친 레시피를 노트에서 불러오세요. 시식하지 않은 초안은 제출할 수 없어요.")
	var chk: Dictionary = Research.check(request_id, rec["config"], rec["scores"])
	if str(chk["error"]) != "":
		return _fail(str(chk["error"]))
	if not bool(chk["all_met"]):
		return _fail("'%s v%d'은(는) 아직 조건을 모두 채우지 못했어요. 힌트를 보고 고쳐서 다시 시식하세요." % [str(rec["name"]), int(rec["version"])])
	var entry: Dictionary = Research.make_entry(request_id, rec, day)
	var after: int = wallet + int(entry["cash"])
	if after > MAX_WALLET:
		return _fail("보유 자금 한도에 도달해 보상을 받을 수 없어요.")
	# --- 여기부터는 실패 지점이 없다 ---
	_research_done.append(entry)
	wallet = after
	var res: Dictionary = _ok("'%s v%d'으로 「%s」 연구를 마쳤어요. 연구 점수 +%d, 자금 +%d원" % [str(rec["name"]), int(rec["version"]), str(req["title"]), int(entry["points"]), int(entry["cash"])])
	res["points"] = int(entry["points"])
	res["cash"] = int(entry["cash"])
	return res


# ---------- 가게 성장 (등급 / 유료 확장 / 직원 고용) ----------
##
## 거래 규칙: 승급/구매/고용은 명시적 호출로만 일어나고, 영업 중에는 도메인이 거부한다(화면 잠금과 별개).
## 모든 검증을 끝낸 뒤에만 상태를 바꾸므로 실패하면 자금/등급/목록이 그대로다. 성공하면 자금 차감(승급은 없음)과 목록 변경이
## 같은 호출 안에서 한 번에 일어나고, 같은 시설/직원은 구조적으로 두 번 살 수 없어 이중 청구가 없다. 불러오기/시식/화면 갱신은 어떤 것도 바꾸지 않는다.

func rank() -> int:
	return _rank


func rank_title() -> String:
	return Growth.rank_title(_rank)


func completed_service_days() -> int:
	return day - 1


func facilities_owned() -> Array:
	return _facilities.duplicate()


func hired_staff() -> Array:
	return _hired.duplicate()


## 지금 열린 토핑 슬롯 수(등급과 조리대 확장 중 작은 쪽).
func topping_slots() -> int:
	return Growth.topping_slots(_rank, _facilities)


## 노트(메뉴 개정 기록) 용량. 기록 하나가 한 칸을 쓰는 "개정 기록"이고 동시에 파는 메뉴 칸이 아니다(영업 메뉴는 선택한 기록 하나).
func record_capacity() -> int:
	return mini(Growth.notebook_capacity(_facilities), MAX_RECORDS)


## 고용 가능한 총 직원 수(요리사+서버 포함)와 남은 고용 자리.
func staff_capacity() -> int:
	return Growth.staff_capacity(_facilities)


func free_staff_slots() -> int:
	return Growth.free_staff_slots(_facilities, _hired)


## 현재 고용 목록에서 만든 직원 구성(영업 시작 때 이 값이 세션으로 복사된다). 아무도 고용하지 않으면 기준과 같은 값(100%, 운영비 0).
func current_staffing() -> Dictionary:
	return Staffing.snapshot(_hired)


## 영업 시작 시점에 세션에 복사해 두는 성장 요약(표시/검증용). 정산 금액에는 직원 구성만 쓰인다.
func growth_snapshot() -> Dictionary:
	return {
		"rank": _rank,
		"topping_slots": topping_slots(),
		"record_capacity": record_capacity(),
		"staff_capacity": staff_capacity(),
	}


## 등급 심사표(읽기 전용). 화면은 이 결과를 그대로 보여 준다: 현재/다음 등급, 조건별 달성 여부와 지금 값, 신청 가능 여부.
func promotion_review() -> Dictionary:
	var best: Dictionary = Growth.best_scores(_records)
	return Growth.promotion_review(_rank, completed_service_days(), _research_done.size(), best)


## 등급 심사 신청(명시적 행동). 다음 단계 하나만 신청할 수 있다. 보상은 없고 등급만 오른다.
## 거부(상태 불변): 영업 중, 알 수 없는 등급, 이미 최고 등급, 다음 단계가 아님, 조건 부족.
func apply_promotion(target_rank: int) -> Dictionary:
	if service_active():
		return _fail("영업 중에는 등급 심사를 신청할 수 없어요. 영업을 끝내거나 중단한 뒤 다시 해 보세요.")
	if target_rank < 2 or target_rank > Growth.RANK_MAX:
		return _fail("알 수 없는 등급이에요.")
	if _rank >= Growth.RANK_MAX:
		return _fail("이미 가장 높은 등급이에요.")
	if target_rank != _rank + 1:
		return _fail("다음 등급(%d단계)만 신청할 수 있어요." % (_rank + 1))
	var review: Dictionary = promotion_review()
	if not bool(review["eligible"]):
		return _fail("아직 「%s」 심사 조건을 모두 채우지 못했어요." % str(review["next_title"]))
	# --- 여기부터는 실패 지점이 없다 ---
	_rank = target_rank
	return _ok("가게가 「%s」(등급 %d단계)로 올랐어요. 토핑 슬롯과 확장은 따로 사야 열려요." % [Growth.rank_title(_rank), _rank])


func facility_review(id: String) -> Dictionary:
	return Growth.facility_review(id, _rank, _facilities, wallet)


func facility_reviews() -> Array:
	var out: Array = []
	for id in Growth.facility_ids():
		out.append(facility_review(id))
	return out


## 유료 확장 구매(명시적 행동). 자금 차감과 목록 추가가 한 번에 일어난다. 거부(상태 불변): 영업 중, 알 수 없음, 이미 보유,
## 등급 부족, 앞 단계 없음, 자금 부족(자금은 음수가 되지 않는다). 환불은 없다.
func purchase_facility(id: String) -> Dictionary:
	if service_active():
		return _fail("영업 중에는 확장을 살 수 없어요. 영업을 끝내거나 중단한 뒤 다시 해 보세요.")
	var rv: Dictionary = facility_review(id)
	if rv.is_empty():
		return _fail("알 수 없는 확장이에요.")
	if not bool(rv["can_buy"]):
		return _fail(str(rv["reason"]))
	var price: int = int(rv["price"])
	# 효과 문구("현재→새 용량")는 반드시 구매 전에 계산한 심사표(rv)에서 가져온다. 구매 뒤에 다시 계산하면 이미 새 용량이라
	# "2→2"처럼 거짓 문구가 된다(실제 용량은 정확했고 메시지만 틀렸던 결함).
	var effect_text: String = str(rv["effect_text"])
	# --- 여기부터는 실패 지점이 없다 (can_buy 가 자금 >= 가격을 이미 보장) ---
	wallet -= price
	_facilities.append(id)
	return _ok("「%s」을(를) 설치했어요 (%s). %s" % [str(rv["name"]), Growth._won(price), effect_text])


func staff_review(id: String) -> Dictionary:
	return Growth.staff_review(id, _facilities, _hired, wallet)


func staff_reviews() -> Array:
	var out: Array = []
	for id in Staffing.ids():
		out.append(staff_review(id))
	return out


## 보조 직원 고용(명시적 행동). 직원 공간 확장은 자동 고용을 하지 않는다. 고용비는 지금 한 번, 하루 운영비는 영업 정산마다 한 번씩 든다.
## 거부(상태 불변): 영업 중, 알 수 없음, 이미 고용, 자리 없음, 자금 부족. 해고는 없다.
func hire_staff(id: String) -> Dictionary:
	if service_active():
		return _fail("영업 중에는 직원을 고용할 수 없어요. 영업을 끝내거나 중단한 뒤 다시 해 보세요.")
	var rv: Dictionary = staff_review(id)
	if rv.is_empty():
		return _fail("알 수 없는 직원이에요.")
	if not bool(rv["can_hire"]):
		return _fail(str(rv["reason"]))
	var price: int = int(rv["hire_price"])
	wallet -= price
	_hired.append(id)
	return _ok("%s %s을(를) 고용했어요 (고용비 %s, 하루 운영비 %s)." % [str(rv["role_name"]), str(rv["name"]), Growth._won(price), Growth._won(int(rv["wage"]))])


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
		"research": {"completed": _research_done.duplicate(true)},
		"growth": {"rank": _rank, "facilities": _facilities.duplicate(), "staff": _hired.duplicate()},
	}


## 전체를 먼저 임시 변수에 검증한 뒤 한 번에 반영한다. 하나라도 틀리면 상태는 그대로이고
## 오류 메시지를 돌려준다(일부만 받아들이는 손실 로드는 하지 않는다). 성공이면 "".
func load_from_dict(raw: Variant) -> String:
	if service_active():
		return "영업 중에는 불러올 수 없어요."
	if typeof(raw) != TYPE_DICTIONARY:
		return "저장 구조가 올바르지 않아요."
	var d: Dictionary = raw
	# 버전을 먼저 읽어 그 버전의 정확한 키 집합을 요구한다. v1은 "research"가 없어야 정상이고(있으면 변조),
	# v2는 반드시 있어야 한다. 알 수 없는 버전은 키 검사 전에 거부한다.
	if not d.has("schema_version") or not Check.in_range(d["schema_version"], MIN_SCHEMA_VERSION, SCHEMA_VERSION):
		return "지원하지 않는 저장 버전이에요."
	var version: int = int(d["schema_version"])
	var expected_keys: Array = TOP_KEYS_V1 if version == 1 else (TOP_KEYS_V2 if version == 2 else TOP_KEYS)
	var key_err: String = Check.keys_error(d, expected_keys, "저장")
	if key_err != "":
		return key_err
	# v1/v2 저장의 레시피 구성은 "topping" 문자열 하나다(정규 모양으로 읽어 들인다). v3는 "toppings" 배열만 허용한다.
	var legacy_cfg: bool = version < 3
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
		var pr: Dictionary = _parse_record(raw_records[i], i, n_record, n_lineage, int(d["day"]), legacy_cfg)
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
	var dcfg: Dictionary = Check.parse_config(draft["config"], "초안", legacy_cfg)
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

	# 연구 진행. v1 → v2 이행: v1에는 연구가 없었으므로 완료 없음(빈 목록)으로 시작한다. 자금/일차/기록/노트는 그대로 읽는다.
	# v2는 기록 목록 검증 뒤에 검사해, 노트에 남은 기록과 영수증이 어긋나는지도 함께 본다.
	var research_parsed: Array = []
	if version >= 2:
		var by_id: Dictionary = {}
		for pe in parsed:
			var pd: Dictionary = pe
			by_id[int(pd["record_id"])] = pd
		var research_result: Dictionary = Research.parse_progress(d["research"], int(d["day"]), n_record, by_id)
		if str(research_result["error"]) != "":
			return str(research_result["error"])
		research_parsed = research_result["completed"]

	# 성장 상태. v1/v2에는 없었으므로 "등급 1단계, 확장/고용 없음"으로 이행한다(자금/등급/직원을 새로 주지 않는다).
	# v3는 파생 사실(영업 일수/연구 영수증 수)과 모순되는 승급·구매·고용을 거부한다.
	var growth_rank: int = 1
	var growth_facilities: Array = []
	var growth_staff: Array = []
	if version >= 3:
		var gr: Dictionary = Growth.parse_state(d["growth"], int(d["day"]) - 1, research_parsed.size())
		if str(gr["error"]) != "":
			return str(gr["error"])
		growth_rank = int(gr["rank"])
		growth_facilities = gr["facilities"]
		growth_staff = gr["staff"]
	# 어떤 구성(기록/비교의 이전 구성/초안)도 이 상태의 토핑 슬롯 수를 넘을 수 없다(슬롯은 줄지 않으므로 정상 저장은 항상 통과).
	# 기록 개수가 노트 용량을 넘는 예전 저장은 거부하지 않는다(grandfather: 모두 보존, 새 시식만 용량 아래로 내려갈 때까지 불가).
	var slot_limit: int = Growth.topping_slots(growth_rank, growth_facilities)
	for pe2 in parsed:
		var rec_cfg2: Dictionary = (pe2 as Dictionary)["config"]
		if Catalog.toppings_of(rec_cfg2).size() > slot_limit:
			return "기록의 토핑 수가 열린 슬롯 수를 넘었어요."
		var cmp2: Dictionary = (pe2 as Dictionary)["comparison"]
		if not cmp2.is_empty() and Catalog.toppings_of(cmp2["prev_config"]).size() > slot_limit:
			return "비교 기록의 토핑 수가 열린 슬롯 수를 넘었어요."
	if Catalog.toppings_of(dcfg["config"]).size() > slot_limit:
		return "초안의 토핑 수가 열린 슬롯 수를 넘었어요."

	# 모든 검증 통과 후 반영
	_rank = growth_rank
	_facilities = growth_facilities
	_hired = growth_staff
	_research_done = research_parsed
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


## legacy_cfg: v1/v2 저장의 구성("topping" 하나)을 읽는지. 읽은 결과는 항상 정규 구성이고, 점수 검증은 정규 구성의 평가 결과와 비교한다
## (토핑 하나짜리는 예전과 같은 점수라서 저장된 점수가 그대로 유효하다).
func _parse_record(raw: Variant, index: int, n_record: int, n_lineage: int, current_day: int, legacy_cfg: bool = false) -> Dictionary:
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
	var cfg_res: Dictionary = Check.parse_config(d["config"], ctx, legacy_cfg)
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
		var prev_cfg_res: Dictionary = Check.parse_config(raw_cmp["prev_config"], ctx + " 비교", legacy_cfg)
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
