extends RefCounted
## 초반 메뉴 개발 여정의 "지금 할 일" 투영. 읽기 전용 순수 뷰다.
##
## 게임 상태의 공개 조회(getter)만 호출하고 아무것도 바꾸지 않으며 파일도 쓰지 않는다. 진행 원장이 따로 없어서
## 화면을 다시 열거나 재시작해도 저장된 상태에서 같은 안내가 다시 계산된다.
## 여기서 만드는 모든 행동 이름은 "어디를 열지"일 뿐이다. 시작/결제/정산/레시피 적용은 하지 않는다.
## 손님 이야기가 수락됐다거나 손님이 방문했다거나 보상을 받았다는 표현은 쓰지 않는다: 카탈로그에 있는
## 손님의 실제 취향 값만 근거로 보여 준다.

const Catalog = preload("res://scripts/domain/ingredient_catalog.gd")
const Customers = preload("res://scripts/domain/customer_catalog.gd")
const Check = preload("res://scripts/domain/data_check.gd")
const Evaluator = preload("res://scripts/domain/recipe_evaluator.gd")
const Research = preload("res://scripts/domain/ramen_research.gd")

const ACTIONS: Array = ["broth", "noodle", "compose", "selling", "goals", "resume_exploration", "wait"]
const CHOICE_ACTIONS: Array = ["improve", "explore", "research"]
const MAX_ROWS: int = 4
const MAX_TASTE_ROWS: int = 2
const NAME_LIMIT: int = 14

## 투영이 읽는 공개 메서드. 하나라도 없는 객체(null, 엉뚱한 객체)는 "확인 중"으로 안전하게 처리한다.
const DESCRIBE_METHODS: Array = ["exploration_active", "service_active", "craft_active", "broth_ready",
	"noodle_ready", "record_count", "selling_records", "completed_service_days", "trial_cost"]
const CHOICE_METHODS: Array = ["completed_service_days", "get_record", "records", "exploration_progress",
	"research_completed_ids", "rank_title"]


## 홈 화면에 보여 줄 짧은 다음 행동 하나. 키: id, title, hint, action, customer, disabled.
## 우선순위: 진행 중 탐험 > 작업 중 > 원재료(육수/면) > 첫 시식 > 판매 메뉴 > 첫 영업 > 다음 목표.
## "selling" 은 기존 영업 화면을 여는 이름일 뿐 영업을 시작하지 않는다. 비싼 계산(전 기록 평가)은 하지 않고
## 개수/존재 여부만 읽으므로 자주 불러도 싸다.
static func describe(state: Object, busy: bool = false) -> Dictionary:
	if not _usable(state, DESCRIBE_METHODS):
		return _model("unavailable", "지금은 열 수 없어요", "게임 정보를 읽지 못했어요.", "wait", "", true)
	if state.exploration_active():
		# 탐험 화면을 여는 것은 안전하므로 호출자의 busy 표시가 있을 때만 꺼 둔다.
		return _model("expedition", "탐험 이어 하기", "진행 중인 탐험을 열어요.", "resume_exploration", "", busy)
	if busy or state.service_active() or state.craft_active():
		return _model("busy", "작업을 마치는 중이에요", "끝나면 다음 할 일을 알려 드려요.", "wait", "", true)
	var customer: Dictionary = _first_customer()
	var customer_id: String = str(customer.get("id", ""))
	var taste: String = _taste_line(customer)
	if not state.broth_ready():
		# Finished work is not a supplied bowl component until explicit use. A
		# resumed player should reach that product, not pay to brew it again.
		if state.has_method("broth_review") and not (state.broth_review()["recipes"] as Array).is_empty():
			return _model("broth_apply","개발한 육수 담기","우려 둔 육수를 골라 그릇에 담아요.","broth",customer_id,false)
		return _model("broth", "첫 육수 만들기", _join(taste, "육수부터 우려요."), "broth", customer_id, false)
	if not state.noodle_ready():
		if state.has_method("noodle_review") and not (state.noodle_review()["recipes"] as Array).is_empty():
			return _model("noodle_apply","개발한 면 담기","완성한 면을 골라 그릇에 담아요.","noodle",customer_id,false)
		return _model("noodle", "첫 면 만들기", _join(taste, "이어서 면을 뽑아요."), "noodle", customer_id, false)
	if state.record_count() == 0:
		var fee: String = "시식 재료비 %d원." % int(state.trial_cost())
		return _model("compose", "첫 라멘 시식하기", _join(taste, fee), "compose", customer_id, false)
	if _menu_count(state) == 0:
		return _model("pick_menu", "팔 메뉴 고르기", "영업에 낼 메뉴를 골라요.", "selling", "", false)
	if int(state.completed_service_days()) < 1:
		return _model("first_sale", "첫 영업 준비하기", "판매 메뉴와 가격을 확인해요.", "selling", "", false)
	return _model("goals", "다음 목표 고르기", "다듬기, 탐험, 연구 중에서 골라요.", "goals", "", false)


## 첫 영업을 마친 뒤의 세 갈래 선택(improve, explore, research 순). 아직 영업을 마치지 않았거나 입력이 이상하면 빈 배열.
## 문구는 실제 저장 값(시식 점수, 발견 수, 연구 완료 수)만 인용하며 미래 점수/이익 예측은 하지 않는다.
static func choices(state: Object) -> Array:
	if not _usable(state, CHOICE_METHODS):
		return []
	if int(state.completed_service_days()) < 1:
		return []
	return [_improve_choice(state), _explore_choice(state), _research_choice(state)]


## 시식으로 남은 개정 기록과 그 안에 불변 복사된 직전 구성(comparison.prev_config)의 비교.
## 반환: {error, available, rows}. 첫 버전(비교 없음)은 error "" / available false / rows [] 이고 가짜 기준값을 만들지 않는다.
## 행: {label, before, after, unit}. 재료비·준비 시간은 항상, 맛 축은 값이 달라진 것 중 변화가 큰 최대 2개.
## 이전 기록이 나중에 지워져도 기록 안의 복사본만 쓰므로 결과가 변하지 않는다. 입력은 수정하지 않는다.
static func comparison(record: Dictionary) -> Dictionary:
	var out: Dictionary = {"error": "", "available": false, "rows": []}
	if typeof(record.get("config")) != TYPE_DICTIONARY or typeof(record.get("scores")) != TYPE_DICTIONARY \
			or typeof(record.get("comparison")) != TYPE_DICTIONARY \
			or typeof(record.get("record_id")) != TYPE_INT or int(record["record_id"]) <= 0 \
			or typeof(record.get("version")) != TYPE_INT or int(record["version"]) < 1:
		out["error"] = "시식 기록이 아니에요."
		return out
	var link: Dictionary = record["comparison"]
	if link.is_empty():
		return out
	if typeof(link.get("prev_config")) != TYPE_DICTIONARY or typeof(link.get("prev_version")) != TYPE_INT \
			or int(link["prev_version"]) < 1 or int(link["prev_version"]) >= int(record["version"]):
		out["error"] = "이전 시식 기록을 확인할 수 없어요."
		return out
	var current: Dictionary = record["config"]
	var previous: Dictionary = link["prev_config"]
	# 평가기는 검증된 구성만 받는다. 검증을 통과해야 비용/시간/맛 계산이 안전하다.
	if Check.config_error(current) != "" or Check.config_error(previous) != "":
		out["error"] = "시식 기록의 구성을 확인할 수 없어요."
		return out
	var rows: Array = []
	rows.append(_row("재료비", Evaluator.unit_cost(previous), Evaluator.unit_cost(current), "원"))
	rows.append(_row("준비 시간", Evaluator.prep_seconds(previous), Evaluator.prep_seconds(current), "초"))
	var before: Dictionary = Evaluator.build_profile(previous)
	var after: Dictionary = Evaluator.build_profile(current)
	var changed: Array = []
	for i in Catalog.AXES.size():
		var axis: String = Catalog.AXES[i]
		var delta: int = absi(int(after[axis]) - int(before[axis]))
		if delta > 0:
			changed.append({"axis": axis, "delta": delta, "order": i})
	# sort_custom 은 안정 정렬이 아니므로 축 순서를 명시적 동률 규칙으로 쓴다.
	changed.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a["delta"] != b["delta"]:
			return a["delta"] > b["delta"]
		return a["order"] < b["order"])
	for i in mini(MAX_TASTE_ROWS, changed.size()):
		var axis: String = changed[i]["axis"]
		rows.append(_row(str(Catalog.AXIS_NAMES[axis]), int(before[axis]), int(after[axis]), "/10"))
	out["rows"] = rows.slice(0, MAX_ROWS)
	out["available"] = true
	return out


# ---------- 내부 ----------

static func _usable(state: Object, names: Array) -> bool:
	if state == null or not is_instance_valid(state):
		return false
	for method_name in names:
		if not state.has_method(method_name):
			return false
	return true


static func _model(id: String, title: String, hint: String, action: String, customer: String, disabled: bool) -> Dictionary:
	return {"id": id, "title": title, "hint": hint, "action": action, "customer": customer, "disabled": disabled}


static func _join(first: String, second: String) -> String:
	return second if first == "" else first + " " + second


static func _short(text: String) -> String:
	return text if text.length() <= NAME_LIMIT else text.substr(0, NAME_LIMIT - 1) + "…"


## 선택된 판매 목록에 실제로 남아 있는 기록 수. 빈 딕셔너리(삭제된 기록)는 세지 않는다.
static func _menu_count(state: Object) -> int:
	var count: int = 0
	for row in state.selling_records():
		if typeof(row) == TYPE_DICTIONARY and not (row as Dictionary).is_empty():
			count += 1
	return count


## 첫 요리의 동기가 되는 기존 단골(카탈로그 첫 손님). 임의/확률이 없어 매번 같다.
static func _first_customer() -> Dictionary:
	var all: Array = Customers.all()
	return {} if all.is_empty() else all[0]


## 카탈로그에 적힌 손님 취향 요약(persona 의 마지막 " · " 뒤 구절). 숫자 목표는 보이지 않는다.
static func _taste_line(customer: Dictionary) -> String:
	if customer.is_empty():
		return ""
	var parts: PackedStringArray = str(customer.get("persona", "")).split(" · ")
	var taste: String = parts[parts.size() - 1].strip_edges()
	if parts.size() < 2 or taste == "":
		return ""
	return "%s 님은 %s예요." % [str(customer["name"]), taste]


static func _row(label: String, before: int, after: int, unit: String) -> Dictionary:
	return {"label": label, "before": before, "after": after, "unit": unit}


## 방금 시식한 기록(없으면 선택된 기록, 그것도 없으면 가장 최근 기록). 영업한 메뉴와 연결하지 않는다:
## 지난 영업 보고에는 어떤 기록이었는지 보장이 없어 "팔린 메뉴"라고 단정하지 않기 위해서다.
static func _observed_record(state: Object) -> Dictionary:
	for key in ["last_feedback_record_id", "selected_record_id"]:
		var id: Variant = state.get(key)
		if typeof(id) == TYPE_INT and int(id) > 0:
			var found: Dictionary = state.get_record(int(id))
			if not found.is_empty():
				return found
	var all: Array = state.records()
	return {} if all.is_empty() else all[all.size() - 1]


static func _improve_choice(state: Object) -> Dictionary:
	var record: Dictionary = _observed_record(state)
	var scores: Variant = record.get("scores")
	if record.is_empty() or typeof(scores) != TYPE_DICTIONARY:
		return {"title": "맛본 메뉴 다듬기", "hint": "남은 시식 기록이 없어요.", "action": "improve", "customer": ""}
	# 저장된 실제 시식 점수에서 가장 낮았던 손님. 동률이면 카탈로그에서 앞선 손님.
	var weakest: Dictionary = {}
	var low: int = 1 << 30
	for customer in Customers.all():
		var id: String = str(customer["id"])
		if scores.has(id) and typeof(scores[id]) == TYPE_INT and int(scores[id]) < low:
			low = int(scores[id])
			weakest = customer
	var label: String = "'%s v%d'" % [_short(str(record.get("name", ""))), int(record.get("version", 1))]
	if weakest.is_empty():
		return {"title": "맛본 메뉴 다듬기", "hint": "%s 시식 기록." % label, "action": "improve", "customer": ""}
	return {"title": "맛본 메뉴 다듬기",
		"hint": "%s 시식, %s 님 %d점." % [label, str(weakest["name"]), low],
		"action": "improve", "customer": str(weakest["id"])}


static func _explore_choice(state: Object) -> Dictionary:
	var progress: Variant = state.exploration_progress()
	var obtained: int = 0
	var total: int = 0
	if typeof(progress) == TYPE_DICTIONARY:
		obtained = int(progress.get("obtained", 0))
		total = int(progress.get("total", 0))
	return {"title": "재료 탐험", "hint": "발견한 재료 %d/%d종" % [obtained, total],
		"action": "explore", "customer": ""}


static func _research_choice(state: Object) -> Dictionary:
	var done: int = (state.research_completed_ids() as Array).size()
	return {"title": "연구·성장", "hint": "연구 의뢰 %d/%d 완료 · 가게 등급 %s" % [done, Research.REQUESTS.size(), str(state.rank_title())],
		"action": "research", "customer": ""}
