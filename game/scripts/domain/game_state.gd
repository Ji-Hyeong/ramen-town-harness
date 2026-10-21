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
const Training = preload("res://scripts/domain/staff_training.gd")
const Exploration = preload("res://scripts/domain/ingredient_exploration.gd")
const Foraging = preload("res://scripts/domain/market_foraging.gd")
const Contest = preload("res://scripts/domain/ramen_contest.gd")
const ContestProgress = preload("res://scripts/domain/contest_progress.gd")
const MenuSales = preload("res://scripts/domain/menu_sales.gd")
const MenuReport = preload("res://scripts/domain/menu_report.gd")
const ProcessRules = preload("res://scripts/domain/recipe_process.gd")
const StoryCatalog = preload("res://scripts/domain/regular_story_catalog.gd")
const Stories = preload("res://scripts/domain/regular_stories.gd")

## 스키마 v2: 최상위에 "research"(완료한 연구 의뢰 영수증 목록)가 추가됐다.
## v1 저장은 "research" 키가 없는 것이 정상이며, 불러올 때 빈 연구 진행(완료 없음)으로 이행한다(load_from_dict 참고).
## 스키마 v3: 최상위에 "growth"(가게 등급, 산 확장 id 목록, 고용한 직원 id 목록)가 추가되고, 모든 레시피 구성(기록/비교/초안)의
## 토핑이 "topping"(문자열) → "toppings"(카탈로그 순서의 배열)로 바뀐다. 용량(토핑 슬롯/노트/직원 수)은 저장하지 않고 이 값들에서 매번 계산한다.
## v1/v2 저장은 불러올 때 "등급 1단계, 확장/고용 없음"과 "토핑 하나짜리 배열"로 이행한다(자금/일차/기록/점수/보고/연구 영수증은 그대로).
## 다음 저장부터는 v3로 기록되고, 저장 서비스가 덮어쓰기 전에 기존 v1/v2 본 파일을 보존한다(save_service.gd 참고).
##
## 스키마 v4: 최상위에 "exploration"(발견한 재료 목록, 마지막 출발일, 누적 완료/포기 횟수, 진행 중 탐험, 최근 영수증 기록)이 추가된다.
## v1~v3 저장은 이 키가 없는 것이 정상이며(있으면 변조), 불러올 때 "발견 없음, 진행 중 탐험 없음"으로 이행한다. 이행은 자금/일차/기록/점수/연구/성장을
## 전혀 건드리지 않고 아무것도 새로 주지 않는다. 진행 중 탐험은 모든 만남 단계와 결과 단계에서 그대로 저장돼 다시 열어도 같은 만남이 이어진다
## (만남은 카탈로그와 경로로만 정해지므로 불러올 때 새로 뽑지 않는다). 저장 서비스가 v4 첫 저장 전에 v3 원본을 보존한다.
## v5에는 출품 영수증·최고 메달·잡지 영수증을 보존한다. v1~v4 이행은 보상 없이 빈 진행으로 시작한다.
## v6 육성은 고용 직원별 완료 주문 경험과 최대 두 훈련 영수증을 보존한다.
## v1~v5는 기존 값 모두 유지, 고용된 직원의 경험/훈련만 0부터 시작한다(소급 지급 없음).
## v7은 보이는 매장 증축과 명시적 판매 목록을 보존한다. v1~6에는 미확장/자동 선택만 추가한다.
## v8은 비기본 제조 공법만 config.process로 보존한다. 이전1~7의 기본 구성과 값은 변경하지 않는다.
## v9는 선택형 단골 사연/완료 영업 메뉴의 답례 영수증을 추가한다. 과거 진행을 소급 지급하지 않는다.
## v10 separates menu families from revision history and retains best-taste witnesses.
## v11 adds isolated market samples; v1..10 receive no samples or retroactive rewards.
## v12 allows repeated paid topping portions and rank-only 2/3/4 positions.
const SCHEMA_VERSION: int = 12
const EXPANSION_PRICE: int = 60000
const MIN_SCHEMA_VERSION: int = 1
const LEGACY_MAX_RECORDS: int = 30
const MAX_RECORDS: int = 300
const MAX_MENUS: int = 30
const START_WALLET: int = 30000
const MAX_WALLET: int = 1000000000
const MAX_DAY: int = 99999
const MAX_VERSION: int = 9999

const TOP_KEYS_V1: Array = ["schema_version", "day", "wallet", "next_record_id", "next_lineage_id",
	"records", "selected_record_id", "last_feedback_record_id", "draft", "last_report"]
const TOP_KEYS_V2: Array = ["schema_version", "day", "wallet", "next_record_id", "next_lineage_id",
	"records", "selected_record_id", "last_feedback_record_id", "draft", "last_report", "research"]
const TOP_KEYS_V3: Array = ["schema_version", "day", "wallet", "next_record_id", "next_lineage_id",
	"records", "selected_record_id", "last_feedback_record_id", "draft", "last_report", "research", "growth"]
const TOP_KEYS_V4: Array = ["schema_version", "day", "wallet", "next_record_id", "next_lineage_id",
	"records", "selected_record_id", "last_feedback_record_id", "draft", "last_report", "research", "growth", "exploration"]
const TOP_KEYS_V5: Array = TOP_KEYS_V4 + ["contests"]
const TOP_KEYS_V6: Array = TOP_KEYS_V5 + ["training"]
const TOP_KEYS_V7: Array = TOP_KEYS_V6 + ["shop"]
const TOP_KEYS_V9: Array = TOP_KEYS_V7 + ["stories"]
const TOP_KEYS_V10: Array = TOP_KEYS_V9 + ["taste_achievements"]
const TOP_KEYS: Array = TOP_KEYS_V10 + ["foraging"]
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
## At most one immutable best-score witness per customer; deleting notebook rows
## never erases earned promotion evidence. Existing saves seed only retained rows.
var _taste_achievements: Dictionary = _empty_taste_achievements()
## 완료한 연구 의뢰 영수증(완료 순서). 총점/칭호/해금은 여기서 계산한다. 항목 구조는 ramen_research.gd 참고.
var _research_done: Array = []
## 가게 성장 상태(저장). 등급 1~3, 산 확장 id(구매 순서), 고용한 직원 id(고용 순서). 용량은 여기서 파생한다.
var _rank: int = 1
var _facilities: Array = []
var _hired: Array = []
var _training: Dictionary = {}
var _expanded: bool = false
var _menu_ids: Array = []
## 재료 탐험 상태(저장). 발견한 재료(영구), 마지막 출발일(하루 1번 규칙), 누적 완료/포기 횟수, 진행 중 탐험, 최근 영수증. 구조는 ingredient_exploration.gd 참고.
## 이 값은 항상 Exploration 의 전이 함수가 돌려준 "새 딕셔너리"로 통째로 교체한다(부분 수정 없음). 외부에는 deep copy만 내보낸다.
var _exploration: Dictionary = Exploration.empty_state()
var _foraging: Dictionary = Foraging.empty_state()
var _contests: Dictionary = ContestProgress.empty_state()
var _stories: Array = []
## 진행 중인 영업 런타임. 저장하지 않는다(재시작하면 영업 전 상태로 돌아온다). 있는 동안은 레시피/초안/일차를 잠근다.
var _active_session: Session = null


func _init() -> void:
	draft_config = Catalog.default_config()
	draft_name = _suggest_name()


# ---------- 조회 (항상 deep copy) ----------

func record_count() -> int:
	return _records.size()


## A revision shares its menu family's slot, including legacy over-capacity saves.
func menu_count() -> int:
	var seen: Dictionary = {}
	for row in _records:
		seen[row["lineage_id"]] = true
	return seen.size()


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

## 공법은 재료와 독립인 레시피 선택이다. 두 기본 공법으로 돌아가면 새 키를 없애 과거 구성과 같게 만든다.
func set_draft_process(slot: String, id: String) -> Dictionary:
	if _busy():
		return _locked_fail()
	var definition: Dictionary = ProcessRules.method(slot, id)
	if definition.is_empty():
		return _fail("알 수 없는 제조 공법이에요.")
	if _rank < int(definition["rank"]):
		return _fail("이 공법은 가게 등급 %d부터 사용할 수 있어요." % definition["rank"])
	var selected: Dictionary = draft_config.get("process", {"broth": "standard", "noodle": "standard"}).duplicate(true)
	selected[slot] = id
	var next: Dictionary = draft_config.duplicate(true)
	next["process"] = selected
	draft_config = Catalog.normalize_config(next)
	return _ok("제조 공법을 바꿨어요. 시식하면 새 구성으로 기록돼요.")


static func _process_error(config: Dictionary, rank: int) -> String:
	var effects: Dictionary = ProcessRules.effects(config.get("process", {}))
	if str(effects["error"]) != "":
		return str(effects["error"])
	if rank < int(effects["rank"]):
		return "제조 공법에 필요한 가게 등급 %d가 없어요." % effects["rank"]
	return ""

func set_draft_choice(slot: String, id: String) -> Dictionary:
	if _busy():
		return _locked_fail()
	if not Catalog.SLOTS.has(slot) or not Catalog.is_valid(slot, id):
		return _fail("알 수 없는 재료예요.")
	# 발견 전 재료는 알려진 id 여도 고를 수 없다(거부하면 초안은 그대로).
	if not Exploration.unlocked(id, _discovered_list()):
		return _fail(_lock_message(id))
	if slot == Catalog.TOPPING_SLOT:
		# 예전 호출 모양(토핑 하나 고르기) 호환: 토핑을 그 하나로 바꾼다. 여러 개는 set_draft_toppings/toggle_draft_topping 으로 고른다.
		draft_config["toppings"] = [id]
		return _ok("")
	draft_config[slot] = id
	return _ok("")


## 토핑 한 번에 지정(여러 개). 검증을 모두 마친 뒤에만 초안을 바꾼다: 최소 1개, 지금 열린 슬롯 수 이하, 모르는 id 없음. 중복은 별도 분량이다.
## 순서는 상관없다(카탈로그 순서로 정규화되므로 순서만 다른 지정은 같은 레시피다).
func set_draft_toppings(ids: Array) -> Dictionary:
	if _busy():
		return _locked_fail()
	for v in ids:
		if typeof(v) != TYPE_STRING or not Catalog.is_valid(Catalog.TOPPING_SLOT, str(v)):
			return _fail("알 수 없는 토핑이에요.")
		if not Exploration.unlocked(str(v), _discovered_list()):
			return _fail(_lock_message(str(v)))
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
	if _busy():
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
	if _busy():
		return _locked_fail()
	if price <Catalog.PRICE_MIN or price > Catalog.PRICE_MAX or price % Catalog.PRICE_STEP != 0:
		return _fail("가격은 %d~%d원, %d원 단위로 정해요." % [Catalog.PRICE_MIN, Catalog.PRICE_MAX, Catalog.PRICE_STEP])
	draft_config["price"] = price
	return _ok("")


## 이름은 입력 중에는 그대로 저장하고, 시식 때 검증한다. 개정 중에는 이름을 바꿀 수 없다.
func set_draft_name(text: String) -> Dictionary:
	if _busy():
		return _locked_fail()
	if draft_lineage_id != 0:
		return _fail("개정 중인 레시피는 이름을 바꿀 수 없어요.")
	draft_name = text
	return _ok("")


## 새 레시피 시작: 개정 연결과 선택을 풀고 구성은 그대로 둔다.
func start_new_recipe() -> void:
	if _busy():
		return
	draft_lineage_id = 0
	selected_record_id = 0
	draft_name = _suggest_name()


## 노트에서 선택: 구성/가격/익힘/이름을 복원하고 이후 시식은 같은 레시피의 새 버전이 된다.
func select_record(id: int) -> Dictionary:
	if _busy():
		return _locked_fail()
	var idx: int = _index_of(id)
	if idx < 0:
		return _fail("노트에 없는 기록이에요.")
	var r: Dictionary = _records[idx]
	var cfg: Dictionary = r["config"]
	var rec_lock: String = Exploration.locked_in(cfg, _discovered_list())
	if rec_lock != "":
		return _fail(_lock_message(rec_lock))
	draft_config = cfg.duplicate(true)
	draft_name = str(r["name"])
	draft_lineage_id = int(r["lineage_id"])
	selected_record_id = id
	last_feedback_record_id = id
	return _ok("")


func delete_record(id: int) -> Dictionary:
	if _busy():
		return _locked_fail()
	var idx: int = _index_of(id)
	if idx < 0:
		return _fail("노트에 없는 기록이에요.")
	if _menu_ids.has(id):
		return _fail("판매 중인 메뉴예요. [영업]에서 판매 목록에서 뺀 뒤 삭제하세요.")
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
	if _busy():
		return _locked_fail()
	var cfg_err: String = Check.config_error(draft_config)
	if cfg_err != "":
		return _fail(cfg_err)
	var method_error: String = _process_error(draft_config, _rank)
	if method_error != "":
		return _fail(method_error)
	# 초안이 발견 전 재료를 담고 있으면(변조된 외부 대입 등) 시식하지 않는다: 기록에는 발견한 재료만 들어간다.
	var draft_lock: String = Exploration.locked_in(draft_config, _discovered_list())
	if draft_lock != "":
		return _fail(_lock_message(draft_lock))
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
	# Capacity limits new families only. Revisions remain possible at/above the
	# facility limit; history has its own hard bound and is never silently pruned.
	if _records.size() >= MAX_RECORDS:
		return _fail("실험 이력 보관함이 가득 찼어요 (%d/%d). 필요 없는 개정 기록을 직접 정리한 뒤 시식하세요. 최고 시식 성적은 유지돼요." % [_records.size(), MAX_RECORDS])
	if base.is_empty() and menu_count() >= menu_capacity():
		return _fail("등록 메뉴가 가득 찼어요 (%d/%d종). 기존 메뉴를 개정하거나 조리대를 확장하세요. 종류를 줄이려면 해당 메뉴의 모든 개정본을 정리하세요." % [menu_count(), menu_capacity()])
	var version: int = 1
	if not base.is_empty():
		version = int(base["version"]) + 1
	if version > MAX_VERSION:
		return _fail("이 레시피는 더 이상 개정할 수 없어요.")
	var cost: int = trial_cost()
	if cost > wallet:
		return _fail("시제품 재료비(%d원)가 보유 자금보다 많아요." % cost)

	var evaluation: Dictionary = Evaluator.evaluate(draft_config)
	var samples: Dictionary = Foraging.use_samples(_foraging, draft_config)
	if str(samples["error"]) != "":
		return _fail(str(samples["error"]))
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
	_taste_achievements = _updated_taste_achievements(_taste_achievements, [record])
	wallet -= cost
	_foraging = samples["state"]
	draft_name = clean_name
	draft_lineage_id = lineage
	selected_record_id = int(record["record_id"])
	last_feedback_record_id = int(record["record_id"])
	var res: Dictionary = _ok("'%s v%d' 시식 완료 (재료비 %d원)" % [clean_name, version, cost])
	res["record_id"] = int(record["record_id"])
	return res


# ---------- 영업(하루) ----------

func forecast() -> Dictionary:
	var selling: Array = selling_records()
	if _expanded:
		return MenuSales.simulate(selling, day, current_staffing())
	var rec: Dictionary = {} if selling.is_empty() else selling[0]
	if rec.is_empty():
		return {"error": "노트에서 영업할 레시피를 먼저 선택하세요."}
	return Sim.simulate(rec["config"], rec["scores"], day, current_staffing())


## 영업 1회 = 정확히 1일. 시뮬레이션은 결정적이므로 forecast()와 결과가 같다.
## 즉시 정산하는 계산 경로이며 화면은 쓰지 않는다. 실제 플레이는 begin_service()/settle_service()를 거친다
## (회귀 테스트와 "런타임 결과 == 예측" 대조용으로만 남겨 둔다).
func serve() -> Dictionary:
	if _busy():
		return _locked_fail()
	if _expanded:
		var opened: Dictionary = begin_service()
		if not bool(opened["ok"]):
			return opened
		_active_session.run_to_end()
		var result: Dictionary = settle_service()
		if not bool(result["ok"]):
			cancel_service()
		return result
	var selling: Array = selling_records()
	var rec: Dictionary = {} if selling.is_empty() else selling[0]
	if rec.is_empty():
		return _fail("노트에서 영업할 레시피를 먼저 선택하세요.")
	var serve_lock: String = Exploration.locked_in(rec["config"], _discovered_list())
	if serve_lock != "":
		return _fail(_lock_message(serve_lock))
	var method_error: String = _process_error(rec["config"], _rank)
	if method_error != "":
		return _fail(method_error)
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
	var trained: Dictionary = _service_experience(int(sim["units"]))
	if str(trained["error"]) != "":
		return _fail(str(trained["error"]))
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
	_training = trained["state"]
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
	if exploration_active():
		return _trip_fail()
	var selling: Array = selling_records()
	var rec: Dictionary = {} if selling.is_empty() else selling[0]
	if rec.is_empty():
		return _fail("노트에서 영업할 레시피를 먼저 선택하세요.")
	for menu in selling:
		var method_error: String = _process_error(menu["config"], _rank)
		if method_error != "":
			return _fail(method_error)
		var rec_lock: String = Exploration.locked_in(menu["config"], _discovered_list())
		if rec_lock != "":
			return _fail(_lock_message(rec_lock))
	if day >= MAX_DAY:
		return _fail("더 이상 영업일을 늘릴 수 없어요.")
	# 직원/성장 스냅샷은 여기서 한 번만 복사한다. 이후 세션은 이 값만 쓴다(영업 중 고용/구매는 막혀 있다).
	var plan: Dictionary = Session.make_plan(rec, day, current_staffing(), growth_snapshot())
	if _expanded:
		plan = Session.make_menu_plan(selling, day, current_staffing(), growth_snapshot(), seat_count())
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
	if _expanded:
		return _settle_menu_session(s)
	var sm: Dictionary = s.summary()
	if str(sm["error"]) != "":
		return _fail(str(sm["error"]))
	if int(sm["day"]) != day:
		return _fail("영업일이 달라져 정산할 수 없어요.")
	var selling: Array = selling_records()
	var rec: Dictionary = {} if selling.is_empty() else selling[0]
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
	var trained: Dictionary = _service_experience(units)
	if str(trained["error"]) != "":
		return _fail(str(trained["error"]))
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
	_training = trained["state"]
	day += 1
	s.mark_settled()
	_active_session = null
	var res: Dictionary = _ok("%d일차 영업을 마쳤어요." % int(last_report["day"]))
	res["report"] = last_report.duplicate(true)
	res["turned_away"] = int(sm["turned_away"])
	res["avg_stars"] = float(sm["avg_stars"])
	return res


func shop_expanded() -> bool:
	return _expanded


func seat_count() -> int:
	return 12 if _expanded else 8


func selling_capacity() -> int:
	return 2 if _expanded else 1


func pinned_menu_ids() -> Array:
	return _menu_ids.duplicate()


## 빈 판매 목록은 예전처럼 선택된 시식 기록을 사용한다. 고정 목록은 초안/시식 대상과 별개다.
func selling_records() -> Array:
	var ids: Array = _menu_ids if not _menu_ids.is_empty() else ([selected_record_id] if selected_record_id != 0 else [])
	var out: Array = []
	for id in ids:
		out.append(get_record(int(id)))
	return out


func set_selling_menus(ids: Array) -> Dictionary:
	if _busy():
		return _locked_fail()
	if ids.size() > selling_capacity():
		return _fail("지금은 메뉴 %d종까지 판매해요. 매장을 증축하면 두 메뉴를 함께 팔 수 있어요." % selling_capacity())
	var seen: Dictionary = {}
	for id in ids:
		if typeof(id) != TYPE_INT or seen.has(id) or get_record(int(id)).is_empty():
			return _fail("판매 메뉴는 노트의 서로 다른 시식 기록이어야 해요.")
		seen[id] = true
	_menu_ids = ids.duplicate()
	return _ok("선택한 시식 기록을 자동으로 판매해요." if ids.is_empty() else "%d종의 판매 메뉴를 고정했어요. 개발·시식 대상과 따로 유지돼요." % ids.size())


func expansion_review() -> Dictionary:
	var reason: String = ""
	if _expanded:
		reason = "이미 증축했어요."
	elif _rank < 2:
		reason = "가게 등급 2부터 증축할 수 있어요."
	elif wallet < EXPANSION_PRICE:
		reason = "증축비 %s가 필요해요." % Growth._won(EXPANSION_PRICE)
	return {"owned": _expanded, "can_buy": reason == "", "reason": reason, "price": EXPANSION_PRICE}


func expand_shop() -> Dictionary:
	if _busy():
		return _locked_fail()
	var review: Dictionary = expansion_review()
	if not bool(review["can_buy"]):
		return _fail(str(review["reason"]))
	wallet -= EXPANSION_PRICE
	_expanded = true
	return _ok("매장을 넓혔어요. 8석→12석 · 판매 메뉴 1종→2종. 기존 메뉴는 유지돼요. 증축비는 돌려받지 못해요.")


func _settle_menu_session(s: Session) -> Dictionary:
	var sm: Dictionary = s.summary()
	if str(sm["error"]) != "":
		return _fail(str(sm["error"]))
	if int(sm["day"]) != day or s.seat_count != seat_count() or MenuReport._json(sm["staffing"]) != MenuReport._json(current_staffing()):
		return _fail("영업일/좌석/직원 구성이 시작 때와 달라 정산할 수 없어요.")
	var today: Array = selling_records()
	if not sm.has("menus") or sm["menus"].size() != today.size():
		return _fail("판매 메뉴 수가 영업 중 바뀌었어요.")
	for i in today.size():
		if int(sm["menus"][i]["record_id"]) != int(today[i]["record_id"]):
			return _fail("영업한 판매 메뉴가 달라졌어요.")
	var after: int = wallet + int(sm["revenue"]) - int(sm["ingredient_cost"]) - int(sm["overhead"])
	if day >= MAX_DAY or after < 0 or after > MAX_WALLET:
		return _fail("영업일 또는 자금 한도를 벗어나 정산할 수 없어요.")
	var report: Dictionary = {"day": day, "recipe_name": "오늘의 메뉴", "version": 1, "price": 0,
		"units": sm["units"], "revenue": sm["revenue"], "ingredient_cost": sm["ingredient_cost"], "overhead": sm["overhead"],
		"net": after - wallet, "wallet_after": after, "by_source": sm["by_source"].duplicate(true),
		"menus": sm["menus"].duplicate(true), "seat_count": seat_count(), "staffing": sm["staffing"].duplicate(true)}
	var retained: Dictionary = {}
	for record in _records:
		retained[int(record["record_id"])] = record
	var parsed: Dictionary = MenuReport.parse(report, day + 1, next_record_id, retained, _discovered_list(), topping_slots(), _rank)
	if str(parsed["error"]) != "":
		return _fail(str(parsed["error"]))
	var trained: Dictionary = _service_experience(int(sm["units"]))
	if str(trained["error"]) != "":
		return _fail(str(trained["error"]))
	# 검사 뒤에만 비용/경험/일차/불변 보고를 함께 반영한다. 공통 운영비는 이 한 번뿐이다.
	wallet = after
	_training = trained["state"]
	last_report = parsed["report"]
	day += 1
	s.mark_settled()
	_active_session = null
	var result: Dictionary = _ok("%d일차 메뉴 영업을 마쳤어요." % int(last_report["day"]))
	result["report"] = last_report.duplicate(true)
	result["turned_away"] = sm["turned_away"]
	result["avg_stars"] = sm["avg_stars"]
	return result


## 영업 중이거나 탐험 중이면 레시피/일차/성장/연구를 건드리는 행동은 도메인이 거부한다(화면 잠금과 별개의 마지막 방어선).
## 두 잠금은 서로 배타적이다: 영업 중에는 탐험을 시작/진행할 수 없고, 탐험 중에는 영업을 시작할 수 없다.
func _busy() -> bool:
	return service_active() or exploration_active()


func _locked_fail() -> Dictionary:
	if service_active():
		return {"ok": false, "message": "영업 중에는 레시피와 일차를 바꿀 수 없어요. 영업을 끝내거나 중단한 뒤 다시 해 보세요."}
	return _trip_fail()


static func _trip_fail() -> Dictionary:
	return {"ok": false, "message": "탐험 중에는 레시피, 영업, 연구, 성장을 할 수 없어요. 탐험 결과를 받거나 포기한 뒤 다시 해 보세요. (저장은 할 수 있어요.)"}


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
	if exploration_active():
		return _trip_fail()
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


# ---------- 단골 사연 (선택/실제 대접/명시적 답례) ----------
func story_arcs() -> Array:
	return _stories.duplicate(true)


func story_arc(customer: String) -> Dictionary:
	return Stories.find(_stories, customer)


func start_story(customer: String, route: String) -> Dictionary:
	if _busy():
		return _locked_fail()
	if day < 2:
		return _fail("첫 영업을 마친 뒤 단골의 이야기를 들을 수 있어요.")
	if StoryCatalog.route(customer, route).is_empty():
		return _fail("알 수 없는 단골이나 이야기 방향이에요.")
	if not story_arc(customer).is_empty():
		return _fail("이미 선택한 이야기예요. 이번 사연의 방향은 바꿀 수 없어요.")
	_stories.append({"customer":customer, "route":route, "opened_day":day, "receipts":[]})
	return _ok(StoryCatalog.route(customer, route)["reply"])


func story_check(customer: String, record_id: int) -> Dictionary:
	return Stories.check(story_arc(customer), get_record(record_id), last_report)


## 조건/최근 실제 완료 영업/자금 상한을 모두 확인한 뒤 이야기와 지갑을 함께 바꾼다.
func complete_story(customer: String, record_id: int) -> Dictionary:
	if _busy():
		return _locked_fail()
	var arc: Dictionary = story_arc(customer)
	var checked: Dictionary = story_check(customer, record_id)
	if str(checked["error"]) != "":
		return _fail(str(checked["error"]))
	if not bool(checked["all_met"]):
		return _fail("메뉴 조건과 새 영업을 확인해 주세요. 시식만으로는 이야기를 마칠 수 없어요.")
	var index: int = arc["receipts"].size()
	var reward: int = Stories.REWARDS[index]
	if wallet > MAX_WALLET - reward:
		return _fail("보유 자금 한도에 도달해 답례를 받을 수 없어요.")
	var rec: Dictionary = get_record(record_id)
	var entry: Dictionary = {"service_day":int(last_report["day"]), "day":day, "units":int(checked["units"])}
	for key in ["record_id", "name", "version", "tasted_day", "config"]:
		entry[key] = rec[key]
	arc["receipts"].append(entry.duplicate(true))
	for i in _stories.size():
		if _stories[i]["customer"] == customer:
			_stories[i] = arc
	wallet += reward
	var result: Dictionary = _ok(StoryCatalog.chapter(customer, arc["route"], index)["success"] + " 답례 +%d원 (한 번만)" % reward)
	result["cash"] = reward
	return result


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


## 지금 열린 토핑 분량: 등급1/2/3에서2/3/4칸. 조리대와는 독립이다.
func topping_slots() -> int:
	return Growth.topping_slots(_rank, _facilities)


## Legacy API/saved service snapshot field: now denotes registered menu families.
## Preserve its numeric values so historical service reports remain unchanged.
func record_capacity() -> int:
	return menu_capacity()


func menu_capacity() -> int:
	return mini(Growth.notebook_capacity(_facilities), MAX_MENUS)


func record_history_capacity() -> int:
	return MAX_RECORDS


func best_taste_records() -> Dictionary:
	return _taste_achievements.duplicate(true)


## 고용 가능한 총 직원 수(요리사+서버 포함)와 남은 고용 자리.
func staff_capacity() -> int:
	return Growth.staff_capacity(_facilities)


func free_staff_slots() -> int:
	return Growth.free_staff_slots(_facilities, _hired)


## 현재 고용 목록에서 만든 직원 구성(영업 시작 때 이 값이 세션으로 복사된다). 아무도 고용하지 않으면 기준과 같은 값(100%, 운영비 0).
func current_staffing() -> Dictionary:
	return Staffing.snapshot(_hired, _training)


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
	var witnesses: Array = []
	for row in _taste_achievements.values():
		if not row.is_empty():
			witnesses.append(row)
	var best: Dictionary = Growth.best_scores(witnesses)
	return Growth.promotion_review(_rank, completed_service_days(), _research_done.size(), best)


## 등급 심사 신청(명시적 행동). 다음 단계 하나만 신청할 수 있다. 보상은 없고 등급만 오른다.
## 거부(상태 불변): 영업 중, 알 수 없는 등급, 이미 최고 등급, 다음 단계가 아님, 조건 부족.
func apply_promotion(target_rank: int) -> Dictionary:
	if service_active():
		return _fail("영업 중에는 등급 심사를 신청할 수 없어요. 영업을 끝내거나 중단한 뒤 다시 해 보세요.")
	if exploration_active():
		return _trip_fail()
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
	if exploration_active():
		return _trip_fail()
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


## Read-only conditional comparison, not a hiring transaction or permission.
## Keep the sale records/day/other employees fixed. Space and money locks still
## belong to staff_review()/hire_staff(); no fabricated state is saved or loaded.
func hiring_preview(id: String) -> Dictionary:
	var definition: Dictionary = Staffing.find(id)
	if definition.is_empty():
		return {"error": "비교할 직원을 찾을 수 없어요."}
	if _hired.has(id):
		return {"error": "이미 함께 일하고 있어요. 지금 효과는 직원 육성에서 확인하세요."}
	var selling: Array = selling_records()
	if selling.is_empty():
		return {"error": "판매할 시식 기록을 고르면 고용 전후를 비교해요."}
	var before: Dictionary = MenuSales.simulate(selling, day, current_staffing())
	if str(before["error"]) != "":
		return {"error": str(before["error"])}
	var candidates: Array = _hired.duplicate()
	candidates.append(id)
	var qualifications: Dictionary = _training.duplicate(true)
	qualifications[id] = Training.empty()
	var after: Dictionary = MenuSales.simulate(selling, day, Staffing.snapshot(candidates, qualifications))
	if str(after["error"]) != "":
		return {"error": str(after["error"])}
	# Return fresh forecasts so editing a view model cannot mutate game records,
	# qualifications, pinned menus, the current session, or persisted receipts.
	return {"error": "", "before": before, "after": after,
		"hire_price": int(definition["hire_price"]),
		"delta_units": int(after["units"]) - int(before["units"]),
		"delta_net": int(after["net"]) - int(before["net"])}


## 보조 직원 고용(명시적 행동). 직원 공간 확장은 자동 고용을 하지 않는다. 고용비는 지금 한 번, 하루 운영비는 영업 정산마다 한 번씩 든다.
## 거부(상태 불변): 영업 중, 알 수 없음, 이미 고용, 자리 없음, 자금 부족. 해고는 없다.
func hire_staff(id: String) -> Dictionary:
	if service_active():
		return _fail("영업 중에는 직원을 고용할 수 없어요. 영업을 끝내거나 중단한 뒤 다시 해 보세요.")
	if exploration_active():
		return _trip_fail()
	var rv: Dictionary = staff_review(id)
	if rv.is_empty():
		return _fail("알 수 없는 직원이에요.")
	if not bool(rv["can_hire"]):
		return _fail(str(rv["reason"]))
	var price: int = int(rv["hire_price"])
	wallet -= price
	_hired.append(id)
	_training[id] = Training.empty()
	return _ok("%s %s을(를) 고용했어요 (고용비 %s, 하루 운영비 %s)." % [str(rv["role_name"]), str(rv["name"]), Growth._won(price), Growth._won(int(rv["wage"]))])


## 영업/경험/자금은 같은 정산에서만 바뀐다. 모든 직원의 경험을 먼저 계산하여 일부만 반영되는 일을 막는다.
func _service_experience(units: int) -> Dictionary:
	var next: Dictionary = _training.duplicate(true)
	for id in _hired:
		var result: Dictionary = Training.accrue(_training[id], day, units)
		if str(result["error"]) != "":
			return {"error": str(result["error"])}
		next[id] = result["state"]
	return {"error": "", "state": next}


func staff_training() -> Dictionary:
	return _training.duplicate(true)


func training_review(id: String, style: String) -> Dictionary:
	if not _hired.has(id):
		return {"error": "먼저 이 직원을 고용해 주세요.", "eligible": false}
	return Training.review(_training[id], _rank, wallet, day, style)


## 확정 시 비용/자격을 함께 반영하고 이후 화면의 연습 연출은 아무 보상도 만들지 않는다.
func train_staff(id: String, style: String) -> Dictionary:
	if _busy():
		return _locked_fail()
	if not _hired.has(id):
		return _fail("먼저 이 직원을 고용해 주세요.")
	var result: Dictionary = Training.train(_training[id], _rank, wallet, day, style)
	if str(result["error"]) != "":
		return _fail(str(result["error"]))
	wallet -= int(result["cost"])
	_training[id] = result["state"]
	var receipt: Dictionary = result["receipt"]
	var fx: Dictionary = Training.effect(Training.level(_training[id]), str(receipt["style"]))
	var out: Dictionary = _ok("%s의 「%s」 훈련을 마쳤어요. 훈련비 %s. 경험은 유지되고 전문화는 바꿀 수 없어요." % [Staffing.find(id)["name"], fx["title"], Growth._won(int(result["cost"]))])
	out["receipt"] = receipt.duplicate(true)
	return out


# ---------- 재료 탐험 (지역 선택 -> 갈래 만남 2번 -> 결과 수령/포기) ----------
##
## 거래 규칙 (모두 ingredient_exploration.gd 의 순수 전이 + 여기서의 자금 처리):
##  - start/advance/finish/retire 는 영업 중이면 즉시 거부한다(화면의 시식 중 잠금과 별개). 반대로 탐험 중에는 메뉴 편집/시식/영업/연구/성장이 거부된다.
##  - 모든 검증(등급, 자금, 하루 1번, 지역 완료 여부, 선택 유효성, 추가 비용)을 끝낸 뒤에만 상태와 자금을 함께 바꾼다. 실패하면 둘 다 그대로다.
##  - 출발 비용은 start 에서 정확히 한 번, 선택의 추가 비용은 그 선택에서 정확히 한 번 빠진다. 포기해도 환불은 없다.
##  - 보상(재료 영구 개방)은 finish 에서 정확히 한 번만 생긴다: 결과 단계에서만 가능하고 성공하면 진행 중 탐험이 사라져 같은 호출을 되풀이해도 거부된다.
##    저장/불러오기/화면 갱신/탭 전환은 진행도, 자금, 보상을 바꾸지 않는다. 탐험은 일차를 올리지 않는다(일차는 영업 정산만 올린다).
##  - 자금/등급/연구 보상과 소모품 재고는 없다. 재료 발견은 "레시피 개발에 쓸 수 있는 선택지의 영구 해금"일 뿐이다.

func exploration_active() -> bool:
	return not (_exploration["active"] as Dictionary).is_empty() or not (_foraging["active"] as Dictionary).is_empty()


func _discovered_list() -> Array:
	var ids: Array = Exploration.discovered_ids(_exploration)
	for row in Foraging.discoveries(_foraging):
		ids.append(row["id"])
	return ids


## 발견한 재료 id(발견 순서). 항상 사본.
func discovered_ingredients() -> Array:
	var out: Array = []
	for id in _discovered_list():
		out.append(str(id))
	return out


## 발견 기록 [{id, region, day}] (발견 순서). 항상 deep copy.
func discovery_records() -> Array:
	return (_exploration["discovered"] as Array).duplicate(true) + Foraging.discoveries(_foraging)


func is_discovered(id: String) -> bool:
	return _discovered_list().has(id)


## 예전 재료는 항상 true, 발견 재료는 발견한 뒤에만 true. 모르는 id 는 false.
func ingredient_unlocked(id: String) -> bool:
	return not Catalog.find(id).is_empty() and Exploration.unlocked(id, _discovered_list())


## 잠긴 재료의 획득 안내({"locked": true, region, region_name, min_rank, fee, hint}). 열린 재료는 {"locked": false}. 모르는 id 는 {}.
func ingredient_lock_info(id: String) -> Dictionary:
	return Exploration.lock_info(id, _discovered_list())


## 지금 고를 수 있는 재료(예전 재료 + 발견한 재료, 카탈로그 순서). 항목은 deep copy.
func available_items(slot: String) -> Array:
	var out: Array = []
	var got: Array = _discovered_list()
	for item in Catalog.all_items(slot):
		var d: Dictionary = item
		if Exploration.unlocked(str(d["id"]), got):
			out.append(d.duplicate(true))
	return out


## 아직 잠긴 재료. 각 항목은 재료 데이터 사본에 "lock"(획득 안내)을 붙인다.
func locked_items(slot: String) -> Array:
	var out: Array = []
	var got: Array = _discovered_list()
	for item in Catalog.discovery_items(slot) + Catalog.farmed_items(slot):
		var d: Dictionary = item
		if not got.has(str(d["id"])):
			var c: Dictionary = d.duplicate(true)
			c["lock"] = Exploration.lock_info(str(d["id"]), got)
			out.append(c)
	return out


## {"obtained": 발견 수, "total": 6, "regions": [{id, obtained, total}]}
func exploration_progress() -> Dictionary:
	return Exploration.progress(_exploration)


## 지역별 계산된 상태 3개(카탈로그 순서): 이름/설명/등급/출발 비용/재료(발견 여부)/진행도/status/can_start/reason.
func exploration_regions() -> Array:
	var out: Array = []
	for id in Exploration.region_ids():
		out.append(exploration_region(id))
	return out


func exploration_region(region_id: String) -> Dictionary:
	var view: Dictionary = Exploration.region_review(_exploration, region_id, _rank, day, wallet)
	if not view.is_empty() and (not _foraging["active"].is_empty() or (int(_foraging["last_departure_day"]) == day and view["can_start"])):
		view["can_start"] = false
		view["status"] = "active_other" if not _foraging["active"].is_empty() else "used_today"
		view["reason"] = "장터 채집을 마치세요." if not _foraging["active"].is_empty() else "오늘 채집으로 출발 기회를 썼어요. 영업을 마친 뒤 다시 오세요."
	return view


## 진행 중 탐험의 보기(단계, 지금 만남과 선택지, 또는 결과). 없으면 {}. 읽기 전용 사본.
func expedition() -> Dictionary:
	if not _foraging["active"].is_empty():
		return Foraging.active_view(_foraging, wallet)
	return Exploration.active_view(_exploration, wallet)


## 최근 탐험 영수증(오래된 것부터, 최대 Exploration.MAX_HISTORY개). 항상 deep copy.
func exploration_history() -> Array:
	return (_exploration["history"] as Array).duplicate(true)


## 오늘(현재 일차) 이미 출발했는지. 출발 후 포기/완료해도 영업을 마쳐 일차가 오를 때까지 참이다.
func departed_today() -> bool:
	return int(_exploration["last_departure_day"]) == day or int(_foraging["last_departure_day"]) == day


func foraging_state() -> Dictionary:
	return _foraging.duplicate(true)


## The old supplier discovery stays intact. Repeat sampling opens only after
## BOTH original market suppliers are found, with one shared trip per game day.
func foraging_review() -> Dictionary:
	var unlocked: bool = true
	for id in Exploration.find_region("market")["ingredients"]:
		unlocked = unlocked and Exploration.discovered_ids(_exploration).has(id)
	var reason: String = ""
	if not unlocked:
		reason = "새벽 장터의 기존 공급처 두 곳을 먼저 발견하세요."
	elif _busy():
		reason = "진행 중인 영업이나 탐색을 먼저 마치세요."
	elif departed_today():
		reason = "오늘은 이미 출발했어요. 영업을 마친 뒤 다시 오세요."
	elif wallet < Foraging.FEE:
		reason = "출발 비용 1,000원이 부족해요."
	elif int(_foraging["stock"][Foraging.IDS[0]]) > Foraging.CAPACITY - 2 and int(_foraging["stock"][Foraging.IDS[1]]) > Foraging.CAPACITY - 2:
		reason = "연구 재료 보관함이 가득 찼어요. 먼저 시제품에 사용하세요."
	return {"can_start": reason == "", "reason": reason, "unlocked": unlocked, "fee": Foraging.FEE, "state": _foraging.duplicate(true)}


func start_foraging() -> Dictionary:
	var view: Dictionary = foraging_review()
	if not bool(view["can_start"]):
		return _fail(str(view["reason"]))
	var result: Dictionary = Foraging.begin(_foraging, day, wallet)
	if str(result["error"]) != "":
		return _fail(str(result["error"]))
	wallet -= Foraging.FEE
	_foraging = result["state"]
	return _ok("연구 재료를 찾으러 장터에 출발했어요. 1,000원을 냈고 오늘 출발 기회를 사용했어요.")


func exploration_stats() -> Dictionary:
	return {
		"completed": int(_exploration["completed"]),
		"retired": int(_exploration["retired"]),
		"last_departure_day": int(_exploration["last_departure_day"]),
		"departed_today": departed_today(),
		"active": exploration_active(),
	}


func _lock_message(id: String) -> String:
	var info: Dictionary = Exploration.lock_info(id, _discovered_list())
	if info.is_empty() or not bool(info["locked"]):
		return "알 수 없는 재료예요."
	return "아직 발견하지 못한 재료예요. " + str(info["hint"])


static func _service_blocks_trip() -> Dictionary:
	return {"ok": false, "message": "영업 중에는 탐험을 진행할 수 없어요. 영업을 끝내거나 중단한 뒤 다시 해 보세요."}


## 출발. 거부(상태/자금 불변): 영업 중, 알 수 없는 지역, 이미 탐험 중, 등급 부족, 지역 완료, 오늘 이미 출발, 출발 비용 부족.
func start_expedition(region_id: String) -> Dictionary:
	if service_active():
		return _service_blocks_trip()
	if not _foraging["active"].is_empty() or int(_foraging["last_departure_day"]) == day:
		return _fail("오늘의 장터 채집을 진행했어요. 영업을 마친 뒤 다시 출발하세요.")
	var r: Dictionary = Exploration.begin(_exploration, region_id, _rank, day, wallet)
	if str(r["error"]) != "":
		return _fail(str(r["error"]))
	var fee: int = int(r["fee"])
	# --- 여기부터는 실패 지점이 없다 (begin 이 자금 >= 출발 비용을 이미 보장) ---
	wallet -= fee
	_exploration = r["state"]
	var reg: Dictionary = Exploration.find_region(region_id)
	var res: Dictionary = _ok("「%s」로 출발했어요. 출발 비용 %s을 냈어요. 오늘은 더 출발할 수 없어요." % [str(reg["name"]), Growth._won(fee)])
	res["fee"] = fee
	return res


## 선택 하나. 추가 비용이 있으면 이 호출에서 한 번 낸다. 거부(상태/자금 불변): 영업 중, 탐험 없음, 결과 단계, 없는 선택, 추가 비용 부족.
func advance_expedition(choice_id: String) -> Dictionary:
	if service_active():
		return _service_blocks_trip()
	if not _foraging["active"].is_empty():
		var result: Dictionary = Foraging.choose(_foraging, choice_id, wallet)
		if str(result["error"]) != "":
			return _fail(str(result["error"]))
		wallet -= int(result["extra"])
		_foraging = result["state"]
		return _ok("채집 선택을 마쳤어요. 결과를 받아야 연구 재료가 들어와요." if _foraging["active"]["stage"] == "result" else "장터에 도착했어요. 연구용 분량을 고르세요.")
	var r: Dictionary = Exploration.choose(_exploration, choice_id, wallet)
	if str(r["error"]) != "":
		return _fail(str(r["error"]))
	var extra: int = int(r["extra"])
	# --- 여기부터는 실패 지점이 없다 (choose 가 추가 비용 <= 자금을 이미 보장) ---
	wallet -= extra
	_exploration = r["state"]
	var stage: String = str((_exploration["active"] as Dictionary)["stage"])
	var choice: Dictionary = r["choice"]
	var text: String = "「%s」을(를) 골랐어요." % str(choice["label"])
	if extra > 0:
		text += " 추가 비용 %s을 냈어요." % Growth._won(extra)
	if stage == Exploration.STAGE_RESULT:
		text += " 결과가 나왔어요. 결과를 받으면 재료가 열려요."
	var res: Dictionary = _ok(text)
	res["extra"] = extra
	res["stage"] = stage
	return res


## 결과 수령(보상 지급). 결과 단계에서만 가능하고 성공하면 탐험이 끝나 되풀이해도 보상이 없다. 재료는 영구 개방된다.
func finish_expedition() -> Dictionary:
	if service_active():
		return _service_blocks_trip()
	if not _foraging["active"].is_empty():
		return _finish_foraging(false)
	var r: Dictionary = Exploration.collect(_exploration)
	if str(r["error"]) != "":
		return _fail(str(r["error"]))
	# --- 여기부터는 실패 지점이 없다 ---
	_exploration = r["state"]
	var iid: String = str(r["ingredient"])
	var is_new: bool = bool(r["new"])
	var text: String = ""
	if is_new:
		text = "새 재료 「%s」를 발견했어요! 이제 레시피에 영구히 쓸 수 있어요." % Exploration.ingredient_name(iid)
	else:
		text = "「%s」는 이미 아는 재료라 새 발견은 없었어요." % Exploration.ingredient_name(iid)
	var res: Dictionary = _ok(text)
	res["ingredient"] = iid
	res["new"] = is_new
	res["receipt"] = (r["receipt"] as Dictionary).duplicate(true)
	return res


## 포기. 만남 단계에서만 가능하다. 낸 비용과 오늘의 출발권은 돌아오지 않고 보상은 없다.
func retire_expedition() -> Dictionary:
	if service_active():
		return _service_blocks_trip()
	if not _foraging["active"].is_empty():
		return _finish_foraging(true)
	var r: Dictionary = Exploration.retire(_exploration)
	if str(r["error"]) != "":
		return _fail(str(r["error"]))
	_exploration = r["state"]
	var res: Dictionary = _ok("탐험을 포기했어요. 낸 비용은 돌아오지 않고 오늘은 다시 출발할 수 없어요.")
	res["receipt"] = (r["receipt"] as Dictionary).duplicate(true)
	return res


func _finish_foraging(retire: bool) -> Dictionary:
	var result: Dictionary = Foraging.finish(_foraging, retire)
	if str(result["error"]) != "":
		return _fail(str(result["error"]))
	_foraging = result["state"]
	if retire:
		return _ok("채집을 포기했어요. 비용과 오늘 출발 기회는 돌아오지 않아요.")
	var receipt: Dictionary = result["receipt"]
	var response: Dictionary = _ok("%s 연구 재료 %d개를 받았어요. 시제품 완성마다 1개를 쓰며 등록 메뉴 판매는 영업 원가로 공급돼요." % [Catalog.find(receipt["ingredient"])["name"], receipt["amount"]])
	response["receipt"] = receipt.duplicate(true)
	return response


# ---------- 저장 직렬화 ----------

func contest_progress() -> Dictionary:
	return _contests.duplicate(true)


func contest_best(id: String) -> Dictionary:
	return ContestProgress.best(_contests, id)


func contest_reviews() -> Array:
	var out: Array = []
	for def in Contest.catalog():
		var d: Dictionary = def
		var id: String = str(d["id"])
		var best: Dictionary = contest_best(id)
		var selected: Dictionary = get_record(selected_record_id)
		var reason: String = ""
		if _busy():
			reason = "영업·탐색을 마친 뒤 출품할 수 있어요."
		elif _rank < int(d["rank"]) or day < int(d["min_day"]):
			reason = "가게 등급 %d · %d일차부터 열려요." % [int(d["rank"]), int(d["min_day"])]
		elif int(best.get("band", 0)) == 3:
			reason = "금메달 획득 완료 · 재출품료를 받지 않아요."
		elif int(_contests["last_entry_day"]) == day:
			reason = "오늘 출품 완료 · 영업 후 다시 도전해요."
		elif wallet < int(d["fee"]):
			reason = "출품료가 부족해요."
		elif selected.is_empty():
			reason = "시식한 메뉴를 노트에서 선택하세요."
		else:
			var judged: Dictionary = Contest.evaluate(id, selected["config"])
			reason = str(judged["error"])
		d["best"] = best
		d["reason"] = reason
		d["can_enter"] = reason == ""
		d["article"] = ContestProgress.article(_contests, id)
		d["article_pending"] = int(best.get("band", 0)) >= 2 and d["article"].is_empty()
		out.append(d)
	return out


## 영수증과 잔액을 한 번에 반영한다. 심사 애니메이션의 프레임/재시작은 이 거래를 다시 실행하지 않는다.
func enter_contest(id: String, record_id: int) -> Dictionary:
	if _busy():
		return _locked_fail()
	var result: Dictionary = ContestProgress.enter(_contests, id, get_record(record_id), day, _rank, wallet)
	if str(result["error"]) != "":
		return _fail(str(result["error"]))
	_contests = result["state"]
	wallet = int(result["wallet"])
	var res: Dictionary = _ok("출품 기록과 비용·상금을 반영했어요.")
	res["receipt"] = result["receipt"].duplicate(true)
	return res


func claim_magazine(id: String) -> Dictionary:
	if _busy():
		return _locked_fail()
	var result: Dictionary = ContestProgress.claim_article(_contests, id, day, wallet)
	if str(result["error"]) != "":
		return _fail(str(result["error"]))
	_contests = result["state"]
	wallet = int(result["wallet"])
	var res: Dictionary = _ok("잡지 소개와 협조비를 반영했어요.")
	res["receipt"] = result["receipt"].duplicate(true)
	return res

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
		# 진행 중 탐험은 어느 단계에서든 그대로 저장한다(경로와 이미 낸 비용 포함). 영수증은 최대 MAX_HISTORY개.
		"exploration": _exploration.duplicate(true),
		"contests": _contests.duplicate(true),
		"training": _training.duplicate(true),
		"shop": {"expanded": _expanded, "menu_ids": _menu_ids.duplicate()},
		"stories": {"arcs":_stories.duplicate(true)},
		"taste_achievements": _taste_achievements.duplicate(true),
		"foraging": _foraging.duplicate(true),
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
	var expected_keys: Array = TOP_KEYS_V1
	if version == 2:
		expected_keys = TOP_KEYS_V2
	elif version == 3:
		expected_keys = TOP_KEYS_V3
	elif version == 4:
		expected_keys = TOP_KEYS_V4
	elif version == 5:
		expected_keys = TOP_KEYS_V5
	elif version == 6:
		expected_keys = TOP_KEYS_V6
	elif version == 7 or version == 8:
		expected_keys = TOP_KEYS_V7
	elif version == 9:
		expected_keys = TOP_KEYS_V9
	elif version == 10:
		expected_keys = TOP_KEYS_V10
	elif version >= 11:
		expected_keys = TOP_KEYS
	var key_err: String = Check.keys_error(d, expected_keys, "저장")
	if key_err != "":
		return key_err
	if version < 8 and _has_process(d):
		return "이전 저장 버전에는 제조 공법을 기록할 수 없어요."
	if version < 12 and _has_portion_config(d):
		return "이전 저장 버전에는 중복 토핑이나 토핑 4칸을 기록할 수 없어요."
	if version < 11 and _has_farmed_config(d):
		return "이전 저장 버전에는 장터 연구 재료를 기록할 수 없어요."
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
	var history_limit: int = LEGACY_MAX_RECORDS if version < 10 else MAX_RECORDS
	if raw_records.size() > history_limit:
		return "기록 수가 한도(%d)를 넘었어요." % history_limit
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

	if lineage_names.size() > MAX_MENUS:
		return "등록 메뉴 종류가 절대 한도(%d)를 넘었어요." % MAX_MENUS
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

	var new_report: bool = typeof(d["last_report"]) == TYPE_DICTIONARY and d["last_report"].has("menus")
	if new_report and version < 7:
		return "이전 버전에 메뉴별 영업 보고가 들어 있어요."
	var rep_result: Dictionary = {"error": "", "report": {}} if new_report else _parse_report(d["last_report"], int(d["day"]), seen_ids)
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
	var training_parsed: Dictionary = {}
	if version >= 6:
		if typeof(d["training"]) != TYPE_DICTIONARY:
			return "직원 육성 구조가 올바르지 않아요."
		var training_keys: String = Check.keys_error(d["training"], growth_staff, "고용 직원 육성")
		if training_keys != "":
			return training_keys
	for id in growth_staff:
		if version < 6:
			training_parsed[id] = Training.empty()
		else:
			var tr: Dictionary = Training.parse(d["training"][id], int(d["day"]), growth_rank)
			if str(tr["error"]) != "":
				return str(tr["error"])
			training_parsed[id] = tr["state"]
	# 재료 탐험 상태. v1~v3에는 없었으므로 "발견 없음, 진행 중 탐험 없음, 출발 기록 없음"으로 이행한다(자금/재료/등급을 새로 주지 않는다).
	# v4는 현재 등급/일차와 모순되는 발견·출발·경로·비용을 모두 거부한다(Exploration.parse_state). 진행 중 탐험은 단계 그대로 복원된다.
	var exploration_parsed: Dictionary = Exploration.empty_state()
	if version >= 4:
		var ex: Dictionary = Exploration.parse_state(d["exploration"], growth_rank, int(d["day"]))
		if str(ex["error"]) != "":
			return str(ex["error"])
		exploration_parsed = ex["state"]
	# 어떤 구성(기록/비교의 이전 구성/초안)도 발견하지 못한 재료를 쓸 수 없다. 예전 저장(v1~v3)은 발견이 비어 있으므로
	# 발견 재료 id 가 들어 있으면 거부된다. 이 검사가 선택/시식으로 막은 경로의 마지막 방어선이다(불러오기로 잠긴 재료가 들어오지 않는다).
	var discovered_now: Array = Exploration.discovered_ids(exploration_parsed)
	var foraging_parsed: Dictionary = Foraging.empty_state()
	if version >= 11:
		var harvested: Dictionary = Foraging.parse(d["foraging"], int(d["day"]), n_record, Catalog.MAX_TOPPINGS if version >= 12 else 1)
		if str(harvested["error"]) != "":
			return str(harvested["error"])
		foraging_parsed = harvested["state"]
		var cross_error: String = _foraging_cross_error(foraging_parsed, exploration_parsed, parsed)
		if cross_error != "":
			return cross_error
	for row in Foraging.discoveries(foraging_parsed):
		discovered_now.append(row["id"])
	for pe0 in parsed:
		var pcfg: Dictionary = (pe0 as Dictionary)["config"]
		var process_error: String = _process_error(pcfg, growth_rank)
		if process_error != "":
			return process_error
		var previous: Dictionary = (pe0 as Dictionary)["comparison"]
		if not previous.is_empty() and _process_error(previous["prev_config"], growth_rank) != "":
			return "비교 기록의 제조 공법에 필요한 등급이 없어요."
		if Exploration.locked_in(pcfg, discovered_now) != "":
			return "기록에 아직 발견하지 못한 재료가 있어요."
		var pcmp: Dictionary = (pe0 as Dictionary)["comparison"]
		if not pcmp.is_empty() and Exploration.locked_in(pcmp["prev_config"], discovered_now) != "":
			return "비교 기록에 아직 발견하지 못한 재료가 있어요."
	if Exploration.locked_in(dcfg["config"], discovered_now) != "":
		return "초안에 아직 발견하지 못한 재료가 있어요."
	if _process_error(dcfg["config"], growth_rank) != "":
		return "초안의 제조 공법에 필요한 등급이 없어요."
	# 어떤 구성(기록/비교의 이전 구성/초안)도 이 상태의 토핑 슬롯 수를 넘을 수 없다(슬롯은 줄지 않으므로 정상 저장은 항상 통과).
	# Preserve legacy families above the facility limit; only a new family is gated.
	var slot_limit: int = Growth.topping_slots(growth_rank, growth_facilities)
	if version < 12:
		# Validate the old rules before granting newly opened positions.
		slot_limit = mini(growth_rank, 1 + Growth.track_tier(growth_facilities, "recipe"))
	for pe2 in parsed:
		var rec_cfg2: Dictionary = (pe2 as Dictionary)["config"]
		if Catalog.toppings_of(rec_cfg2).size() > slot_limit:
			return "기록의 토핑 수가 열린 슬롯 수를 넘었어요."
		var cmp2: Dictionary = (pe2 as Dictionary)["comparison"]
		if not cmp2.is_empty() and Catalog.toppings_of(cmp2["prev_config"]).size() > slot_limit:
			return "비교 기록의 토핑 수가 열린 슬롯 수를 넘었어요."
	if Catalog.toppings_of(dcfg["config"]).size() > slot_limit:
		return "초안의 토핑 수가 열린 슬롯 수를 넘었어요."

	# 기존 구성을 포함한 출품/잡지 기록도 임시로 완전히 검증한다. 이행은 상금을 주지 않는다.
	var contests_parsed: Dictionary = ContestProgress.empty_state()
	if version >= 5:
		var contest_records: Dictionary = {}
		for pe in parsed:
			contest_records[int(pe["record_id"])] = pe
		var contest_result: Dictionary = ContestProgress.parse(d["contests"], int(d["day"]), growth_rank,
			n_record, contest_records, exploration_parsed["discovered"] + Foraging.discoveries(foraging_parsed), slot_limit)
		if str(contest_result["error"]) != "":
			return str(contest_result["error"])
		contests_parsed = contest_result["state"]
	var expanded: bool = false
	var menu_ids: Array = []
	if version >= 7:
		if typeof(d["shop"]) != TYPE_DICTIONARY or Check.keys_error(d["shop"], ["expanded", "menu_ids"], "매장") != "":
			return "매장 상태 구조가 올바르지 않아요."
		if typeof(d["shop"]["expanded"]) != TYPE_BOOL or typeof(d["shop"]["menu_ids"]) != TYPE_ARRAY:
			return "매장 확장/판매 목록 형식이 올바르지 않아요."
		expanded = d["shop"]["expanded"]
		if expanded and growth_rank < 2:
			return "증축에 필요한 가게 등급이 없어요."
		var used: Dictionary = {}
		if d["shop"]["menu_ids"].size() > (2 if expanded else 1):
			return "판매 메뉴 수가 열린 칸을 넘었어요."
		for id in d["shop"]["menu_ids"]:
			if not Check.in_range(id, 1, n_record - 1) or not seen_ids.has(int(id)) or used.has(int(id)):
				return "판매 목록의 기록 번호가 올바르지 않아요."
			menu_ids.append(int(id))
			used[int(id)] = true
	if new_report:
		if not expanded:
			return "증축하지 않은 매장의 확장 영업 보고예요."
		var retained: Dictionary = {}
		for record in parsed:
			retained[int(record["record_id"])] = record
		rep_result = MenuReport.parse(d["last_report"], int(d["day"]), n_record, retained, discovered_now, slot_limit, growth_rank)
		if str(rep_result["error"]) != "":
			return str(rep_result["error"])
		var staff_error: String = _report_staff_error(rep_result["report"]["staffing"], growth_staff, training_parsed, int(rep_result["report"]["day"]))
		if staff_error != "":
			return staff_error
	var stories_parsed: Array = []
	if version >= 9:
		var retained: Dictionary = {}
		for record in parsed:
			retained[int(record["record_id"])] = record
		var story_result: Dictionary = Stories.parse(d["stories"], int(d["day"]), n_record, retained, growth_rank, slot_limit, discovered_now, rep_result["report"])
		if str(story_result["error"]) != "":
			return str(story_result["error"])
		stories_parsed = story_result["arcs"]
	var achievements: Dictionary = _updated_taste_achievements(_empty_taste_achievements(), parsed)
	if version >= 10:
		var achieved: Dictionary = _parse_taste_achievements(d["taste_achievements"], parsed, int(d["day"]), n_record, n_lineage, growth_rank, slot_limit, discovered_now)
		if str(achieved["error"]) != "":
			return str(achieved["error"])
		achievements = achieved["records"]
	var sample_witness_error: String = _sample_witness_error(d, foraging_parsed)
	if sample_witness_error != "":
		return sample_witness_error
	# 모든 검증 통과 후 반영
	_taste_achievements = achievements
	_stories = stories_parsed
	_expanded = expanded
	_menu_ids = menu_ids
	_rank = growth_rank
	_facilities = growth_facilities
	_hired = growth_staff
	_training = training_parsed
	_exploration = exploration_parsed
	_foraging = foraging_parsed
	_contests = contests_parsed
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


## Validate historical schemas recursively, including deleted-record witnesses.
static func _has_portion_config(raw: Variant) -> bool:
	if typeof(raw) == TYPE_DICTIONARY:
		if raw.has("toppings") and typeof(raw["toppings"]) == TYPE_ARRAY:
			var ids: Array = raw["toppings"]
			var unique: Array = []
			for id in ids:
				if unique.has(id):
					return true
				unique.append(id)
			if ids.size() > 3:
				return true
		for value in raw.values():
			if _has_portion_config(value):
				return true
	elif typeof(raw) == TYPE_ARRAY:
		for value in raw:
			if _has_portion_config(value):
				return true
	return false


## Old versions must not gain new ingredient access through a forged config.
static func _has_farmed_config(raw: Variant) -> bool:
	if typeof(raw) == TYPE_DICTIONARY:
		for key in raw:
			if Catalog.SLOTS.has(key) and typeof(raw[key]) == TYPE_STRING and Catalog.is_farmed(raw[key]):
				return true
			if key == "toppings" and typeof(raw[key]) == TYPE_ARRAY:
				for id in raw[key]:
					if typeof(id) == TYPE_STRING and Catalog.is_farmed(id):
						return true
			if _has_farmed_config(raw[key]):
				return true
	elif typeof(raw) == TYPE_ARRAY:
		for value in raw:
			if _has_farmed_config(value):
				return true
	return false


static func _sample_witness_error(raw: Dictionary, farm: Dictionary) -> String:
	var used_by_record: Dictionary = {}
	var error: String = _gather_sample_witnesses(raw, farm, used_by_record)
	if error != "":
		return error
	var counts: Dictionary = {Foraging.IDS[0]: 0, Foraging.IDS[1]: 0}
	for quantities in used_by_record.values():
		for id in Foraging.IDS:
			counts[id] += int(quantities.get(id, 0))
	for id in Foraging.IDS:
		if counts[id] > int(farm["used"][id]):
			return "남아 있는 메뉴/과거 증빙보다 연구 재료 소비가 적어요."
	return ""


## A deleted notebook row can survive as a best-taste, comparison or story
## witness. Count each immutable record ID once, not once per reference.
static func _gather_sample_witnesses(raw: Variant, farm: Dictionary, by_record: Dictionary) -> String:
	if typeof(raw) == TYPE_DICTIONARY:
		var pairs: Array = [["record_id", "config"], ["prev_record_id", "prev_config"]]
		for pair in pairs:
			if not raw.has(pair[0]) or not raw.has(pair[1]) or typeof(raw[pair[1]]) != TYPE_DICTIONARY:
				continue
			var ids: Array = []
			for id in Catalog.item_ids(raw[pair[1]]):
				if Foraging.IDS.has(id):
					ids.append(id)
					if raw.has("tasted_day") and int(raw["tasted_day"]) < int(farm["first_day"][id]):
						return "연구 재료를 처음 얻기 전의 시식 증빙이에요."
			if not ids.is_empty():
				var key: int = int(raw[pair[0]])
				if not by_record.has(key):
					by_record[key] = {}
				# Keep maximum portions per immutable recipe, not reference count.
				for id in Foraging.IDS:
					by_record[key][id] = maxi(int(by_record[key].get(id, 0)), ids.count(id))
		for value in raw.values():
			var error: String = _gather_sample_witnesses(value, farm, by_record)
			if error != "":
				return error
	elif typeof(raw) == TYPE_ARRAY:
		for value in raw:
			var error: String = _gather_sample_witnesses(value, farm, by_record)
			if error != "":
				return error
	return ""


## Cross-module calendar and retained trial witnesses prevent granting samples
## or spending the shared trip twice through otherwise valid isolated states.
static func _foraging_cross_error(farm: Dictionary, exploration: Dictionary, records: Array) -> String:
	var error: String = "장터 채집과 공급처 탐색/시식 기록의 날짜·소비가 맞지 않아요."
	var trips: int = int(farm["completed"]) + int(farm["retired"]) + (0 if farm["active"].is_empty() else 1)
	if trips > 0:
		var prerequisite_day: int = 0
		var suppliers: Array = []
		for row in exploration["discovered"]:
			if Exploration.find_region("market")["ingredients"].has(row["id"]):
				suppliers.append(row["id"])
				prerequisite_day = maxi(prerequisite_day, int(row["day"]))
		if suppliers.size() != 2 or int(farm["last_departure_day"]) <= prerequisite_day:
			return error
		for id in Foraging.IDS:
			if int(farm["first_day"][id]) > 0 and int(farm["first_day"][id]) <= prerequisite_day:
				return error
		for row in farm["history"]:
			if int(row["day"]) <= prerequisite_day:
				return error
	if not farm["active"].is_empty() and not exploration["active"].is_empty():
		return error
	if farm["last_departure_day"] > 0 and farm["last_departure_day"] == exploration["last_departure_day"]:
		return error
	var old_trips: int = int(exploration["completed"]) + int(exploration["retired"]) + (0 if exploration["active"].is_empty() else 1)
	if old_trips + trips > maxi(int(exploration["last_departure_day"]), int(farm["last_departure_day"])):
		return error
	for old in exploration["history"]:
		for fresh in farm["history"]:
			if old["day"] == fresh["day"]:
				return error
	var retained: Dictionary = {Foraging.IDS[0]: 0, Foraging.IDS[1]: 0}
	for record in records:
		for id in Catalog.item_ids(record["config"]):
			if not Foraging.IDS.has(id):
				continue
			if int(farm["first_day"][id]) == 0 or int(record["tasted_day"]) < int(farm["first_day"][id]):
				return error
			retained[id] += 1
	for id in Foraging.IDS:
		if retained[id] > int(farm["used"][id]):
			return error
	return ""


## 구버전의 어느 스냅샷에도 새 공법이 섞이지 않도록 노트/비교/출품/삭제된 보고까지 확인한다.
static func _has_process(raw: Variant) -> bool:
	if typeof(raw) == TYPE_DICTIONARY:
		if raw.has("process"):
			return true
		for value in raw.values():
			if _has_process(value):
				return true
	elif typeof(raw) == TYPE_ARRAY:
		for value in raw:
			if _has_process(value):
				return true
	return false


## 보고일 뒤에 훈련을 받았더라도 당시 자격을 소급하지 않는다. 과거에 없었던 고용/자격을 주장하면 거부한다.
static func _report_staff_error(staff: Dictionary, hired: Array, training: Dictionary, on_day: int) -> String:
	var historical: Dictionary = {}
	for id in staff.get("hired", []):
		if not hired.has(id):
			return "영업 보고에 고용한 적 없는 직원이 있어요."
		var e: Dictionary = Training.empty()
		for lesson in training[id]["lessons"]:
			if int(lesson["day"]) <= on_day:
				e["lessons"].append(lesson.duplicate(true))
		historical[id] = e
	if MenuReport._json(Staffing.snapshot(staff.get("hired", []), historical)) != MenuReport._json(staff):
		return "영업 보고의 자격이 당시 훈련과 달라요."
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


static func _empty_taste_achievements() -> Dictionary:
	var out: Dictionary = {}
	for id in Customers.ids():
		out[id] = {}
	return out


static func _updated_taste_achievements(previous: Dictionary, records_to_add: Array) -> Dictionary:
	var out: Dictionary = previous.duplicate(true)
	for row in records_to_add:
		for id in Customers.ids():
			if out[id].is_empty() or int(row["scores"][id]) > int(out[id]["scores"][id]):
				out[id] = row.duplicate(true)
	return out


## Reuse the normal record parser, then validate historical unlocks and agreement
## with retained rows. Scores alone are never accepted as promotion evidence.
func _parse_taste_achievements(raw: Variant, retained: Array, current_day: int, n_record: int, n_lineage: int, current_rank: int, slots: int, discovered: Array) -> Dictionary:
	if typeof(raw) != TYPE_DICTIONARY or Check.keys_error(raw, Customers.ids(), "최고 시식 성적") != "":
		return {"error": "최고 시식 성적의 항목이 올바르지 않아요."}
	var out: Dictionary = {}
	var witnesses_by_id: Dictionary = {}
	var names: Dictionary = {}
	for row in retained:
		witnesses_by_id[row["record_id"]] = row
		names[row["lineage_id"]] = row["name"]
	var filled: int = 0
	for id in Customers.ids():
		if typeof(raw[id]) != TYPE_DICTIONARY:
			return {"error": "최고 시식 증빙의 구조가 올바르지 않아요."}
		if raw[id].is_empty():
			out[id] = {}
			continue
		var checked: Dictionary = _parse_record(raw[id], 0, n_record, n_lineage, current_day)
		if str(checked["error"]) != "":
			return {"error": "최고 시식 증빙: " + str(checked["error"])}
		var row: Dictionary = checked["record"]
		var configs: Array = [row["config"]]
		if not row["comparison"].is_empty():
			configs.append(row["comparison"]["prev_config"])
		for cfg in configs:
			if _process_error(cfg, current_rank) != "" or Exploration.locked_in(cfg, discovered) != "" or Catalog.toppings_of(cfg).size() > slots:
				return {"error": "최고 시식 증빙에 아직 열리지 않은 구성이 있어요."}
		if witnesses_by_id.has(row["record_id"]) and JSON.stringify(witnesses_by_id[row["record_id"]], "", true) != JSON.stringify(row, "", true):
			return {"error": "최고 시식 증빙이 같은 번호의 기록과 달라요."}
		if names.has(row["lineage_id"]) and names[row["lineage_id"]] != row["name"]:
			return {"error": "최고 시식 증빙의 메뉴 이름이 달라요."}
		witnesses_by_id[row["record_id"]] = row
		names[row["lineage_id"]] = row["name"]
		out[id] = row
		filled += 1
	if filled != 0 and filled != Customers.ids().size():
		return {"error": "최고 시식 성적이 일부만 남아 있어요."}
	# Every retained or historical witness is also a real tasting for the other
	# customers. A deliberately lowered/missing best score must not hide it.
	for row in witnesses_by_id.values():
		for id in Customers.ids():
			if out[id].is_empty() or int(out[id]["scores"][id]) < int(row["scores"][id]):
				return {"error": "이미 받은 최고 시식 성적이 빠져 있어요."}
	return {"error": "", "records": out}


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
