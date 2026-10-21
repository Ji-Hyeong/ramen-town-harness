extends RefCounted
## 가게 성장: 등급 3단계, 유료 확장(조리대/직원 공간), 파생 용량. 데이터와 순수 계산만 있다.
## 상태 변경(승급/구매/고용)과 거래 규칙은 GameState가 한다. 화면은 이 파일의 review 결과를 보여 줄 뿐 판단하지 않는다.
##
## 가게 등급(연구 칭호 "견습 연구생…라멘 연구 박사"와는 별개의 축):
##   1단계 골목 가게(시작) → 2단계 동네 맛집 → 3단계 이름난 라멘집
## 승급은 "등급 심사 신청"이라는 명시적 행동으로만 일어나고, 금전 보상은 없다(조건만 본다). 조건은 지금 게임으로 달성 가능한 것뿐이다:
##   - 영업 마친 날 수 = 일차 - 1 (일차는 정산/영업 완료로만 오른다)
##   - 완료한 연구 의뢰 수 (연구 영수증 개수)
##   - GameState가 보존한 최고 시식 증빙을 재평가해 단골별 최고점 조건을 확인한다.
##   2단계: 영업 3일 + 연구 1건 + 단골 2명에게 75점 이상
##   3단계: 영업 10일 + 연구 4건 + 단골 3명 모두에게 80점 이상
## 증인(손으로 계산, 테스트가 평가기로 다시 확인): 연구 입문 증인 둘(도윤 입문 80점 이상, 하영 입문 80점 이상)이 2단계 점수 조건을
## 채우고, 여섯 연구 증인을 모두 시식하면 도윤 심화(88+)/하영 심화(90+)/마루 심화(84+)가 3단계 점수 조건(80 이상)을 채운다.
## 개정 기록을 지워도 최고 시식 증빙은 유지된다. 승급한 등급도 내려가지 않는다.

const Catalog = preload("res://scripts/domain/ingredient_catalog.gd")
const Customers = preload("res://scripts/domain/customer_catalog.gd")
const Check = preload("res://scripts/domain/data_check.gd")
const Evaluator = preload("res://scripts/domain/recipe_evaluator.gd")
const Staffing = preload("res://scripts/domain/shop_staffing.gd")

const RANK_MAX: int = 3
## 등록 메뉴 종류 용량. 개정 이력300개/동시 판매1~2종은 별개다.
const NOTEBOOK_BY_TIER: Array = [6, 12, 30]

const RANKS: Array = [
	{"rank": 1, "title": "골목 가게", "summary": "작은 골목에서 시작한 가게예요."},
	{"rank": 2, "title": "동네 맛집", "summary": "단골이 생겨 동네에 알려진 가게예요.",
		"days": 3, "research": 1, "score_min": 75, "score_customers": 2},
	{"rank": 3, "title": "이름난 라멘집", "summary": "세 단골이 모두 인정한 이름난 가게예요.",
		"days": 10, "research": 4, "score_min": 80, "score_customers": 3},
]

## 유료 확장. 두 줄(조리대 = 레시피 작업 공간, 직원 공간)에 각 2단계. 한 번만 살 수 있고 환불은 없다.
## min_rank: 이 등급 이상이어야 살 수 있음, requires: 먼저 사야 하는 같은 줄의 앞 단계.
## 토핑 슬롯은 등급만으로 열리고 조리대는 등록 메뉴 종류를, 직원 공간은 고용 가능한 총 직원 수를 올린다.
const FACILITIES: Array = [
	{"id": "bench_1", "track": "recipe", "tier": 1, "name": "조리대 확장 I", "price": 12000, "min_rank": 2, "requires": "",
		"desc": "메뉴를 12종까지 등록해요. 토핑 칸은 등급에 따라 자동으로 열려요. 같은 메뉴의 개정은 자리를 더 쓰지 않아요."},
	{"id": "bench_2", "track": "recipe", "tier": 2, "name": "조리대 확장 II", "price": 30000, "min_rank": 3, "requires": "bench_1",
		"desc": "메뉴를 30종까지 등록해요. 같은 토핑도 여러 칸에 담을 수 있어요. 실험 이력 보관함은 별도예요."},
	{"id": "staff_1", "track": "staff", "tier": 1, "name": "직원 공간 I", "price": 15000, "min_rank": 2, "requires": "",
		"desc": "휴게 공간을 만들어 직원을 3명까지 둘 수 있어요(자동 고용 없음)."},
	{"id": "staff_2", "track": "staff", "tier": 2, "name": "직원 공간 II", "price": 36000, "min_rank": 3, "requires": "staff_1",
		"desc": "직원을 4명까지 둘 수 있어요(자동 고용 없음)."},
]

const STATE_KEYS: Array = ["rank", "facilities", "staff"]


# ---------- 조회 ----------

static func rank_info(rank: int) -> Dictionary:
	for r in RANKS:
		var d: Dictionary = r
		if int(d["rank"]) == rank:
			return d
	return {}


static func rank_title(rank: int) -> String:
	var info: Dictionary = rank_info(rank)
	return str(info["title"]) if not info.is_empty() else ""


static func find_facility(id: String) -> Dictionary:
	for f in FACILITIES:
		var d: Dictionary = f
		if str(d["id"]) == id:
			return d
	return {}


static func facility_ids() -> Array[String]:
	var out: Array[String] = []
	for f in FACILITIES:
		out.append(str((f as Dictionary)["id"]))
	return out


## 해당 줄에서 가진 가장 높은 단계(없으면 0).
static func track_tier(facilities: Array, track: String) -> int:
	var best: int = 0
	for id in facilities:
		var f: Dictionary = find_facility(str(id))
		if not f.is_empty() and str(f["track"]) == track:
			best = maxi(best, int(f["tier"]))
	return best


# ---------- 파생 용량 (저장하지 않는다) ----------

## Rank alone unlocks paid portions: 2/3/4. Bench purchases still expand menu families.
static func topping_slots(rank: int, _facilities: Array) -> int:
	return mini(clampi(rank, 1, RANK_MAX) + 1, Catalog.MAX_TOPPINGS)


static func notebook_capacity(facilities: Array) -> int:
	return int(NOTEBOOK_BY_TIER[clampi(track_tier(facilities, "recipe"), 0, NOTEBOOK_BY_TIER.size() - 1)])


## 고용 가능한 총 직원 수(시작 직원 요리사+서버 포함): 2 → 3 → 4.
static func staff_capacity(facilities: Array) -> int:
	return Staffing.BASE_STAFF + track_tier(facilities, "staff")


## 지금 고용으로 더 채울 수 있는 자리 수.
static func free_staff_slots(facilities: Array, hired: Array) -> int:
	return maxi(0, staff_capacity(facilities) - Staffing.BASE_STAFF - hired.size())


## "토핑 슬롯 몇 개를 어떻게 더 열 수 있나" 안내(화면 문구). 슬롯이 이미 최대면 빈 글.
static func topping_unlock_hint(rank: int, facilities: Array) -> String:
	var slots: int = topping_slots(rank, facilities)
	if slots >= Catalog.MAX_TOPPINGS:
		return ""
	return "토핑 %d칸은 가게 등급 %d단계에서 자동으로 열려요." % [slots + 1, rank + 1]


static func _next_in_track(facilities: Array, track: String) -> Dictionary:
	var tier: int = track_tier(facilities, track)
	for f in FACILITIES:
		var d: Dictionary = f
		if str(d["track"]) == track and int(d["tier"]) == tier + 1:
			return d
	return {}


# ---------- 승급 심사 ----------

## 노트 기록을 평가기로 다시 계산한 단골별 최고점 {손님 id: 점수}. 기록이 없으면 0. 저장된 점수가 아니라 새 계산값을 쓴다.
static func best_scores(records: Array) -> Dictionary:
	var best: Dictionary = {}
	for id in Customers.ids():
		best[id] = 0
	for r in records:
		var rec: Dictionary = r
		var ev: Dictionary = Evaluator.evaluate(rec["config"])
		if str(ev["error"]) != "":
			continue
		for c in ev["customers"]:
			var cd: Dictionary = c
			best[str(cd["id"])] = maxi(int(best[str(cd["id"])]), int(cd["score"]))
	return best


## 읽기 전용 심사표. rank: 현재 등급, 나머지는 상태에서 읽은 사실.
## 반환: {"rank","title","top","next","next_title","summary","conditions":[{"id","text","measured_text","met"}],"eligible"}
static func promotion_review(rank: int, completed_days: int, research_count: int, best: Dictionary) -> Dictionary:
	var info: Dictionary = rank_info(rank)
	var out: Dictionary = {
		"rank": rank, "title": str(info.get("title", "")), "top": rank >= RANK_MAX,
		"next": 0, "next_title": "", "summary": str(info.get("summary", "")), "conditions": [], "eligible": false,
	}
	if rank >= RANK_MAX or info.is_empty():
		return out
	var nxt: Dictionary = rank_info(rank + 1)
	out["next"] = rank + 1
	out["next_title"] = str(nxt["title"])
	var days: int = int(nxt["days"])
	var research: int = int(nxt["research"])
	var min_score: int = int(nxt["score_min"])
	var need_customers: int = int(nxt["score_customers"])
	var have_customers: int = 0
	for id in best:
		if int(best[id]) >= min_score:
			have_customers += 1
	var conds: Array = [
		{"id": "days", "text": "영업을 %d일 마침" % days, "measured_text": "지금 %d일" % completed_days, "met": completed_days >= days},
		{"id": "research", "text": "연구 의뢰 %d건 완료" % research, "measured_text": "지금 %d건" % research_count, "met": research_count >= research},
		{"id": "scores", "text": "최고 시식 성적으로 단골 %d명 이상에게 %d점 이상 받음(기록을 지워도 유지돼요)" % [need_customers, min_score], "measured_text": "지금 %d명" % have_customers, "met": have_customers >= need_customers},
	]
	var all_met: bool = true
	for c in conds:
		if not bool((c as Dictionary)["met"]):
			all_met = false
	out["conditions"] = conds
	out["eligible"] = all_met
	return out


# ---------- 확장 심사 ----------

## 읽기 전용: 한 시설의 지금 상태. 구매 가능 여부와 사람이 읽을 이유를 함께 준다.
## 반환: {"id","name","price","desc","owned","can_buy","reason","effect_text","price_text"}
static func facility_review(id: String, rank: int, facilities: Array, wallet: int) -> Dictionary:
	var f: Dictionary = find_facility(id)
	if f.is_empty():
		return {}
	var price: int = int(f["price"])
	var owned: bool = facilities.has(id)
	var reason: String = ""
	if owned:
		reason = "이미 설치했어요."
	elif rank < int(f["min_rank"]):
		reason = "가게 등급 %d단계(%s)부터 살 수 있어요." % [int(f["min_rank"]), rank_title(int(f["min_rank"]))]
	elif str(f["requires"]) != "" and not facilities.has(str(f["requires"])):
		reason = "먼저 「%s」이(가) 필요해요." % str(find_facility(str(f["requires"]))["name"])
	elif wallet < price:
		reason = "자금이 %s 모자라요." % _won(price - wallet)
	var after: Array = facilities.duplicate()
	if not owned:
		after.append(id)
	var effect: String = ""
	if str(f["track"]) == "recipe":
		effect = "등록 메뉴 %d→%d종 · 토핑 칸은 등급으로 해금" % [notebook_capacity(facilities), notebook_capacity(after)]
	else:
		effect = "직원 %d→%d명까지(자동 고용 없음)" % [staff_capacity(facilities), staff_capacity(after)]
	return {
		"id": id, "name": str(f["name"]), "price": price, "desc": str(f["desc"]), "owned": owned,
		"can_buy": reason == "", "reason": reason, "effect_text": effect, "price_text": _won(price),
	}


## 읽기 전용: 한 직원의 고용 상태.
## 반환: {"id","name","role_name","hire_price","wage","desc","hired","can_hire","reason"}
static func staff_review(id: String, facilities: Array, hired: Array, wallet: int) -> Dictionary:
	var s: Dictionary = Staffing.find(id)
	if s.is_empty():
		return {}
	var price: int = int(s["hire_price"])
	var is_hired: bool = hired.has(id)
	var reason: String = ""
	if is_hired:
		reason = "이미 함께 일하고 있어요."
	elif free_staff_slots(facilities, hired) <= 0:
		var nxt: Dictionary = _next_in_track(facilities, "staff")
		if nxt.is_empty():
			reason = "직원 자리가 모두 찼어요."
		else:
			reason = "직원 자리가 없어요. 「%s」(%s)로 늘려요." % [str(nxt["name"]), _won(int(nxt["price"]))]
	elif wallet < price:
		reason = "자금이 %s 모자라요." % _won(price - wallet)
	return {
		"id": id, "name": str(s["name"]), "role_name": str(s["role_name"]), "hire_price": price, "wage": int(s["wage"]),
		"desc": str(s["desc"]), "hired": is_hired, "can_hire": reason == "", "reason": reason,
	}


# ---------- 저장 구조 ----------

## 외부(저장 파일)의 성장 상태를 모두 검증한다. 하나라도 어긋나면 에러만 돌려주고 호출자는 아무것도 반영하지 않는다.
## 반환: {"error": String, "rank": int, "facilities": Array, "staff": Array}
## 검사: 키 정확히 일치, 정수/열거 범위, 시설/직원 id 존재·중복 없음, 시설 구매 순서(앞 단계가 먼저) 와 등급 요건,
##       고용 수 <= 직원 공간이 허용하는 수, 등급이 요구하는 영업 일수/연구 완료 수(파생 사실과 모순되는 승급 거부).
static func parse_state(raw: Variant, completed_days: int, research_count: int) -> Dictionary:
	if typeof(raw) != TYPE_DICTIONARY:
		return {"error": "성장 상태 구조가 올바르지 않아요."}
	var d: Dictionary = raw
	var key_err: String = Check.keys_error(d, STATE_KEYS, "성장 상태")
	if key_err != "":
		return {"error": key_err}
	if not Check.in_range(d["rank"], 1, RANK_MAX):
		return {"error": "가게 등급이 범위를 벗어났어요."}
	var rank: int = int(d["rank"])
	for r in range(2, rank + 1):
		var need: Dictionary = rank_info(r)
		if completed_days < int(need["days"]) or research_count < int(need["research"]):
			return {"error": "가게 등급 %d단계의 승급 조건(영업 %d일, 연구 %d건)과 저장된 진행이 맞지 않아요." % [r, int(need["days"]), int(need["research"])]}
	if typeof(d["facilities"]) != TYPE_ARRAY or typeof(d["staff"]) != TYPE_ARRAY:
		return {"error": "성장 목록 구조가 올바르지 않아요."}
	var raw_f: Array = d["facilities"]
	if raw_f.size() > FACILITIES.size():
		return {"error": "확장 수가 카탈로그를 넘었어요."}
	var facilities: Array = []
	for v in raw_f:
		if typeof(v) != TYPE_STRING:
			return {"error": "확장 id 형식이 올바르지 않아요."}
		var id: String = v
		var f: Dictionary = find_facility(id)
		if f.is_empty():
			return {"error": "알 수 없는 확장이에요."}
		if facilities.has(id):
			return {"error": "같은 확장이 두 번 들어 있어요."}
		if rank < int(f["min_rank"]):
			return {"error": "가게 등급이 모자란데 확장이 있어요."}
		if str(f["requires"]) != "" and not facilities.has(str(f["requires"])):
			return {"error": "앞 단계 없이 확장이 있어요."}
		facilities.append(id)
	var raw_s: Array = d["staff"]
	if raw_s.size() > Staffing.STAFF.size():
		return {"error": "직원 수가 카탈로그를 넘었어요."}
	var staff: Array = []
	for v2 in raw_s:
		if typeof(v2) != TYPE_STRING:
			return {"error": "직원 id 형식이 올바르지 않아요."}
		var sid: String = v2
		if Staffing.find(sid).is_empty():
			return {"error": "알 수 없는 직원이에요."}
		if staff.has(sid):
			return {"error": "같은 직원이 두 번 들어 있어요."}
		staff.append(sid)
	if staff.size() > staff_capacity(facilities) - Staffing.BASE_STAFF:
		return {"error": "직원 공간보다 많은 직원이 있어요."}
	return {"error": "", "rank": rank, "facilities": facilities, "staff": staff}


static func _won(n: int) -> String:
	var digits: String = str(absi(n))
	var out: String = ""
	var count: int = 0
	for i in range(digits.length() - 1, -1, -1):
		out = digits[i] + out
		count += 1
		if count % 3 == 0 and i > 0:
			out = "," + out
	return ("-" if n < 0 else "") + out + "원"
