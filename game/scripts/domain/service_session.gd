extends RefCounted
## 영업 한 번(점심 피크 40분 = 2400 게임초)을 1게임초 단위로 진행하는 결정적 운영 런타임.
##
## 손님 도착 → 줄 서기 → 빈 자리로 이동 → 주문 → 요리사 조리 → 서버 서빙 → 식사·반응 → 퇴장.
## 주문은 "식사가 끝나는 틱"에만 완료로 기록된다. 매출·재료비·판매 수량은 모두 이 완료 목록에서만 나온다.
## 수요/점수/준비 시간/가격은 시작 시점에 복사한 레시피 스냅샷(기록 deep copy)에서만 읽으며,
## 이후 노트가 바뀌어도 이 세션은 영향을 받지 않는다. 난수는 시드 고정 LCG뿐이라 같은 입력은 같은 하루가 된다.
##
## 이 클래스는 자금/일차를 건드리지 않는다. 정산은 GameState.settle_service()가 FINISHED 세션에 대해 한 번만 한다.
## 위치(픽셀)도 모른다: 화면은 entities()의 논리 상태(state, 진행률, 자리 번호, 줄 번호)로 위치를 계산한다.

const Customers = preload("res://scripts/domain/customer_catalog.gd")
const Evaluator = preload("res://scripts/domain/recipe_evaluator.gd")
const Sim = preload("res://scripts/domain/sales_simulator.gd")
const Staffing = preload("res://scripts/domain/shop_staffing.gd")
const MenuSales = preload("res://scripts/domain/menu_sales.gd")

# 세션 상태
const RUNNING: int = 0
const FINISHED: int = 1
const CANCELLED: int = 2
const STALLED: int = 3

# 손님 상태
const P_APPROACH: int = 0
const P_QUEUED: int = 1
const P_TO_SEAT: int = 2
const P_ORDERING: int = 3
const P_WAITING: int = 4
const P_EATING: int = 5
const P_LEAVING: int = 6
const P_BALK: int = 7
const P_GONE: int = 8

# 서버 상태
const S_IDLE: int = 0
const S_CARRY: int = 1
const S_RETURN: int = 2

# 시간 단위는 모두 게임초(틱). 화면 배속은 1초에 몇 틱을 진행할지로만 정해진다.
const SERVICE_SECONDS: int = Sim.SERVICE_SECONDS
const HARD_LIMIT: int = Sim.SERVICE_SECONDS * 2
# 도착은 문 닫기 전(2400)보다 일찍 끝나도록 2200 안에 분산한다. 남은 시간이 마지막 식사·퇴장 여유다.
const ARRIVAL_SPAN: int = 2200
const SEAT_COUNT: int = 8
# 자리 0~3: 카운터, 4~7: 테이블. 걷는 시간은 문→자리 경로 길이에 대략 비례한다.
const SEAT_WALK: Array[int] = [52, 56, 56, 52, 36, 38, 38, 36]
# 서버가 주방 앞에서 자리까지 가는 시간(돌아올 때는 SERVE_BACK_PERCENT %).
# 서버 왕복이 가장 빠른 레시피의 준비 시간(73초)보다 짧아야 서버가 용량의 병목이 되지 않는다.
const SEAT_SERVE: Array[int] = [10, 12, 12, 10, 24, 26, 26, 24]
const SERVE_BACK_PERCENT: int = 60
const APPROACH_GS: int = 40
const ORDER_GS: int = 12
const EAT_GS: int = 90
const LEAVE_GS: int = 48
const BALK_GS: int = 36
# 일어난 자리에 다음 손님이 바로 앉으면 겹쳐 보이므로 잠깐 비워 둔다.
const SEAT_CLEAR_GS: int = 8

const LOOK_DOHYUN: int = 0
const LOOK_HAYOUNG: int = 1
const LOOK_MARU: int = 2
const WALKIN_LOOKS: int = 7

const MAX_UNITS: int = 200


class Patron extends RefCounted:
	var id: int = 0
	var source: String = ""
	var will_order: bool = true
	var look: int = 0
	var arrive_t: int = 0
	var spawned: bool = false
	var state: int = 0
	var state_t: int = 0
	var seat: int = -1
	var queued_t: int = -1
	var seated_t: int = -1
	var waiting_t: int = -1
	var delivered_t: int = -1
	## 줄에서 기다린 시간 + 주문 후 음식을 기다린 시간(걷고 주문하는 시간은 제외). 인내심과 비교한다.
	var wait_total: int = 0
	var stars: int = 3
	var base_stars: int = 3
	var patience: int = 150
	var menu_index: int = 0


var day: int = 0
var record_id: int = 0
var recipe_name: String = ""
var version: int = 0
var config: Dictionary = {}
var scores: Dictionary = {}
var forecast: Dictionary = {}
## 영업 시작 시점의 직원 구성/성장 스냅샷(불변). 세션은 이 값만 읽는다: 조리 시간, 서빙 시간, 하루 운영비가 모두 여기서 나온다.
## 영업 중에는 고용/구매가 막혀 있고, 정산은 이 스냅샷으로 운영비를 계산하므로 도중에 달라질 수 없다.
var staffing: Dictionary = {}
var growth_snapshot: Dictionary = {}
var price: int = 0
var unit_cost: int = 0
## 영업 중 실제 한 그릇 조리 시간(보조 직원이 있으면 기준 시간에서 줄어든 값).
var prep: int = 1
## 확장 영업은 메뉴별 스냅샷/주문을 사용한다. 기본 한 메뉴 계획은 옛 경로와 출력까지 유지한다.
var menus: Array = []
var seat_count: int = SEAT_COUNT
var _multi: bool = false
var _chef_total: int = 1
const EXTRA_WALK: Array[int] = [78, 78, 82, 82]
const EXTRA_SERVE: Array[int] = [34, 36, 38, 40]
var state: int = RUNNING
var settled: bool = false
var time: int = 0
## 완료된 주문 목록(식사가 끝난 틱에만 추가). 정산 금액의 유일한 출처.
var completed: Array = []
var turned_away: int = 0
## 자리 사용 기록: {seat, patron, from, to}. to == -1 이면 아직 사용 중.
var seat_log: Array = []

var _patrons: Array = []
var _next_arrival: int = 0
var _queue: Array[int] = []
var _seat_owner: Array[int] = []
var _seat_free_at: Array[int] = []
var _cook_queue: Array[int] = []
var _chef_busy: bool = false
var _chef_order: int = -1
var _chef_left: int = 0
var _ready: Array[int] = []
var _server_state: int = S_IDLE
var _server_left: int = 0
var _server_total: int = 1
var _server_patron: int = -1
var _frac: float = 0.0
var _planned_orders: int = 0


## plan: make_plan()의 결과(검증 완료). 테스트는 plan["arrivals"]를 바꿔 특정 상황을 만들 수 있다.
func _init(plan: Dictionary) -> void:
	day = int(plan["day"])
	record_id = int(plan["record_id"])
	recipe_name = str(plan["recipe_name"])
	version = int(plan["version"])
	var cfg: Dictionary = plan["config"]
	config = cfg.duplicate(true)
	var sc: Dictionary = plan["scores"]
	scores = sc.duplicate(true)
	var fc: Dictionary = plan["forecast"]
	forecast = fc.duplicate(true)
	var plan_staffing: Dictionary = plan.get("staffing", {})
	staffing = plan_staffing.duplicate(true)
	var plan_growth: Dictionary = plan.get("growth", {})
	growth_snapshot = plan_growth.duplicate(true)
	price = int(config["price"])
	unit_cost = Evaluator.unit_cost(config)
	prep = Staffing.effective_prep(Evaluator.prep_seconds(config), staffing)
	_chef_total = prep
	_multi = plan.has("menus")
	if _multi:
		menus = plan["menus"].duplicate(true)
		seat_count = int(plan["seat_count"])
	for i in seat_count:
		_seat_owner.append(-1)
		_seat_free_at.append(0)

	var arrivals: Array = []
	var raw: Array = plan["arrivals"]
	for i in raw.size():
		var a: Dictionary = raw[i]
		arrivals.append({"t": int(a["t"]), "i": i, "source": str(a["source"]), "will_order": bool(a["will_order"]), "menu_index": int(a.get("menu_index", 0))})
	arrivals.sort_custom(_arrival_before)
	for k in arrivals.size():
		var a2: Dictionary = arrivals[k]
		var p: Patron = Patron.new()
		p.id = k
		p.source = str(a2["source"])
		p.menu_index = int(a2["menu_index"])
		p.will_order = bool(a2["will_order"])
		p.arrive_t = maxi(0, int(a2["t"]))
		var score: int = _menu_score(p.source, p.menu_index)
		p.base_stars = Evaluator.stars_for(score)
		p.stars = p.base_stars
		p.patience = _patience_of(p.source)
		p.look = _look_of(p.source, k)
		if p.will_order:
			_planned_orders += 1
		_patrons.append(p)


## 선택된 레시피 기록(불변 스냅샷)과 영업일에서 하루 계획을 만든다.
## 도착 수 = Sim의 판매 가능 수량(units), 못 파는 수요(demand - units)는 줄이 길어 돌아가는 손님으로 따로 보인다.
## staffing/growth: 시작 시점의 직원 구성(ShopStaffing.snapshot)과 성장 요약. 빈 값 = 보조 직원 없음(기준과 동일).
static func make_plan(record: Dictionary, on_day: int, staffing: Dictionary = {}, growth: Dictionary = {}) -> Dictionary:
	if record.is_empty():
		return {"error": "레시피 기록이 없어요."}
	var cfg: Dictionary = record["config"]
	var sc: Dictionary = record["scores"]
	var fc: Dictionary = Sim.simulate(cfg, sc, on_day, staffing)
	if str(fc["error"]) != "":
		return {"error": str(fc["error"])}
	var units: int = int(fc["units"])
	var lost: int = maxi(0, int(fc["demand"]) - units)
	if units > MAX_UNITS or lost > MAX_UNITS:
		return {"error": "하루 손님 수가 범위를 벗어났어요."}
	var by_source: Dictionary = fc["by_source"]
	var ids: Array[String] = Customers.ids()
	ids.append(Sim.WALKIN_ID)
	var seq: Array[String] = []
	for id in ids:
		for n in int(by_source[id]):
			seq.append(id)
	# 같은 날·같은 레시피는 항상 같은 순서/도착 시각이 되도록 시드를 고정한다.
	var s: int = (on_day * 1000003 + int(record["record_id"]) * 7919 + units * 31) & 0x7fffffff
	for i in range(seq.size() - 1, 0, -1):
		s = _lcg(s)
		var j: int = (s >> 8) % (i + 1)
		var tmp: String = seq[i]
		seq[i] = seq[j]
		seq[j] = tmp
	var arrivals: Array = []
	for k in units:
		var u: float = (float(k) + 0.5) / float(units)
		# 점심 피크: 가운데 구간의 도착 간격이 좁아지도록 시간축을 살짝 휜다(단조 증가).
		var t: int = int(float(ARRIVAL_SPAN) * (u + 0.1 * sin(TAU * u)))
		s = _lcg(s)
		t += int((s >> 8) % 25) - 12
		arrivals.append({"t": maxi(t, 5), "source": seq[k], "will_order": true})
	for j2 in lost:
		var t2: int = 600 + int(1600.0 * (float(j2) + 0.5) / float(lost))
		arrivals.append({"t": t2, "source": Sim.WALKIN_ID, "will_order": false})
	var cfg_copy: Dictionary = cfg.duplicate(true)
	var sc_copy: Dictionary = sc.duplicate(true)
	return {
		"error": "",
		"day": on_day,
		"record_id": int(record["record_id"]),
		"recipe_name": str(record["name"]),
		"version": int(record["version"]),
		"config": cfg_copy,
		"scores": sc_copy,
		"forecast": fc.duplicate(true),
		"staffing": staffing.duplicate(true),
		"growth": growth.duplicate(true),
		"arrivals": arrivals,
	}


## 같은 시각 도착은 입력 순서를 유지한다(sort_custom은 안정 정렬이 아니므로 순번으로 비교).
static func _arrival_before(x: Dictionary, y: Dictionary) -> bool:
	if int(x["t"]) != int(y["t"]):
		return int(x["t"]) < int(y["t"])
	return int(x["i"]) < int(y["i"])


## 두 메뉴의 방문/조리 예산은 helper가 한 번 계산한다. 도착·조리·서빙·식사는 같은 런타임을 공유한다.
static func make_menu_plan(records: Array, on_day: int, staffing: Dictionary, growth: Dictionary, seats: int = 12) -> Dictionary:
	if seats != 8 and seats != 12:
		return {"error": "좌석은 8석 또는 12석이어야 해요."}
	var fc: Dictionary = MenuSales.simulate(records, on_day, staffing)
	if str(fc["error"]) != "":
		return fc
	var plan: Dictionary = make_plan(records[0], on_day, staffing, growth)
	if str(plan["error"]) != "":
		return plan
	plan["forecast"] = fc.duplicate(true)
	plan["menus"] = fc["menus"].duplicate(true)
	plan["seat_count"] = seats
	var order: Array = []
	for i in records.size():
		order.append(i)
	order.sort_custom(func(a: int, b: int) -> bool: return int(records[a]["record_id"]) < int(records[b]["record_id"]))
	var groups: Array = Customers.ids()
	groups.append(Sim.WALKIN_ID)
	var seq: Array = []
	var seed_value: int = on_day * 1000003 + int(fc["units"]) * 31
	for index in order:
		var row: Dictionary = fc["menus"][index]
		seed_value += int(row["record_id"]) * 7919
		for source in groups:
			for n in int(row["by_source"][source]):
				seq.append({"source": str(source), "menu_index": int(index)})
	seed_value &= 0x7fffffff
	for i in range(seq.size() - 1, 0, -1):
		seed_value = _lcg(seed_value)
		var j: int = (seed_value >> 8) % (i + 1)
		var tmp: Dictionary = seq[i]
		seq[i] = seq[j]
		seq[j] = tmp
	var arrivals: Array = []
	for i in seq.size():
		var u: float = (float(i) + 0.5) / float(seq.size())
		seed_value = _lcg(seed_value)
		var t: int = int(float(ARRIVAL_SPAN) * (u + 0.1 * sin(TAU * u))) + int((seed_value >> 8) % 25) - 12
		arrivals.append({"t": maxi(5, t), "source": seq[i]["source"], "menu_index": seq[i]["menu_index"], "will_order": true})
	var lost: int = int(fc["demand"]) - int(fc["units"])
	for i in lost:
		arrivals.append({"t": 600 + int(1600.0 * (float(i) + 0.5) / float(lost)), "source": Sim.WALKIN_ID, "menu_index": 0, "will_order": false})
	plan["arrivals"] = arrivals
	return plan


func _menu_score(source: String, index: int) -> int:
	if not _multi:
		return _score_of(source)
	var sc: Dictionary = menus[index]["scores"]
	if sc.has(source):
		return int(sc[source])
	var total: int = 0
	for id in Customers.ids():
		total += int(sc[id])
	return roundi(float(total) / float(Customers.ids().size()))


func _walk_seconds(seat: int) -> int:
	return SEAT_WALK[seat] if seat < SEAT_COUNT else EXTRA_WALK[seat - SEAT_COUNT]


func _serve_seconds(seat: int) -> int:
	return SEAT_SERVE[seat] if seat < SEAT_COUNT else EXTRA_SERVE[seat - SEAT_COUNT]


static func _lcg(seed_value: int) -> int:
	return (seed_value * 1103515245 + 12345) & 0x7fffffff


func _score_of(source: String) -> int:
	if scores.has(source):
		return int(scores[source])
	var sum: int = 0
	for id in Customers.ids():
		sum += int(scores[id])
	return roundi(float(sum) / float(Customers.ids().size()))


func _patience_of(source: String) -> int:
	var c: Dictionary = Customers.find(source)
	if c.is_empty():
		return Sim.WALKIN_PATIENCE
	return int(c["patience_seconds"])


func _look_of(source: String, index: int) -> int:
	match source:
		"dohyun":
			return LOOK_DOHYUN
		"hayoung":
			return LOOK_HAYOUNG
		"maru":
			return LOOK_MARU
	return 3 + (index % WALKIN_LOOKS)


# ---------- 진행 ----------

func planned_orders() -> int:
	return _planned_orders


func is_finished() -> bool:
	return state == FINISHED


func is_running() -> bool:
	return state == RUNNING


## 화면 프레임에서 호출: 게임초를 누적해 정수 틱만 진행한다(프레임 길이와 무관하게 같은 결과).
func advance(game_seconds: float) -> void:
	if state != RUNNING or game_seconds <= 0.0:
		return
	_frac += game_seconds
	while _frac >= 1.0 and state == RUNNING:
		tick()
		_frac -= 1.0


func run_to_end(max_ticks: int = HARD_LIMIT + 10) -> bool:
	var n: int = 0
	while state == RUNNING and n < max_ticks:
		tick()
		n += 1
	return state == FINISHED


func cancel() -> void:
	if state == RUNNING:
		state = CANCELLED


func mark_settled() -> void:
	settled = true


func tick() -> void:
	if state != RUNNING:
		return
	time += 1
	_spawn_arrivals()
	for p in _patrons:
		var pt: Patron = p
		if pt.spawned and pt.state != P_GONE:
			_update_patron(pt)
	_assign_seats()
	_update_chef()
	_update_server()
	_check_finished()


func _spawn_arrivals() -> void:
	while _next_arrival < _patrons.size():
		var pt: Patron = _patrons[_next_arrival]
		if pt.arrive_t > time:
			break
		pt.spawned = true
		pt.state = P_APPROACH
		pt.state_t = 0
		_next_arrival += 1


func _update_patron(pt: Patron) -> void:
	pt.state_t += 1
	match pt.state:
		P_APPROACH:
			if pt.state_t >= APPROACH_GS:
				pt.state_t = 0
				if pt.will_order:
					pt.state = P_QUEUED
					pt.queued_t = time
					_queue.append(pt.id)
				else:
					pt.state = P_BALK
		P_BALK:
			if pt.state_t >= BALK_GS:
				pt.state = P_GONE
				turned_away += 1
		P_TO_SEAT:
			if pt.state_t >= _walk_seconds(pt.seat):
				pt.state = P_ORDERING
				pt.state_t = 0
		P_ORDERING:
			if pt.state_t >= ORDER_GS:
				pt.state = P_WAITING
				pt.state_t = 0
				pt.waiting_t = time
				_cook_queue.append(pt.id)
		P_EATING:
			if pt.state_t >= EAT_GS:
				_complete_order(pt)
		P_LEAVING:
			if pt.state_t >= LEAVE_GS:
				pt.state = P_GONE


## 식사 종료 틱: 여기서만 주문이 완료로 기록되고 자리가 비워진다.
func _complete_order(pt: Patron) -> void:
	completed.append({
		"order_id": completed.size() + 1,
		"patron": pt.id,
		"source": pt.source,
		"seat": pt.seat,
		"price": int(menus[pt.menu_index]["price"]) if _multi else price,
		"unit_cost": int(menus[pt.menu_index]["unit_cost"]) if _multi else unit_cost,
		"stars": pt.stars,
		"wait": pt.wait_total,
		"done_t": time,
	})
	if _multi:
		completed[-1]["menu_index"] = pt.menu_index
		completed[-1]["record_id"] = int(menus[pt.menu_index]["record_id"])
	for i in range(seat_log.size() - 1, -1, -1):
		var entry: Dictionary = seat_log[i]
		if int(entry["patron"]) == pt.id and int(entry["to"]) == -1:
			entry["to"] = time
			break
	_seat_owner[pt.seat] = -1
	_seat_free_at[pt.seat] = time + SEAT_CLEAR_GS
	pt.state = P_LEAVING
	pt.state_t = 0


func _assign_seats() -> void:
	while not _queue.is_empty():
		var free: int = -1
		for i in seat_count:
			if _seat_owner[i] == -1 and time >= _seat_free_at[i]:
				free = i
				break
		if free < 0:
			return
		var pid: int = _queue.pop_front()
		var pt: Patron = _patrons[pid]
		pt.state = P_TO_SEAT
		pt.state_t = 0
		pt.seat = free
		pt.seated_t = time
		_seat_owner[free] = pid
		seat_log.append({"seat": free, "patron": pid, "from": time, "to": -1})


func _update_chef() -> void:
	if _chef_busy:
		_chef_left -= 1
		if _chef_left <= 0:
			_ready.append(_chef_order)
			_chef_busy = false
			_chef_order = -1
	if not _chef_busy and not _cook_queue.is_empty():
		_chef_order = _cook_queue.pop_front()
		_chef_busy = true
		var patron: Patron = _patrons[_chef_order]
		_chef_total = int(menus[patron.menu_index]["prep"]) if _multi else prep
		_chef_left = _chef_total


func _update_server() -> void:
	match _server_state:
		S_IDLE:
			if not _ready.is_empty():
				_server_patron = _ready.pop_front()
				var pt: Patron = _patrons[_server_patron]
				# 홀 보조가 있으면 서빙 시간이 줄어든다(스냅샷 값). 없으면 SEAT_SERVE 그대로.
				_server_total = Staffing.effective_carry(_serve_seconds(pt.seat), staffing)
				_server_left = _server_total
				_server_state = S_CARRY
		S_CARRY:
			_server_left -= 1
			if _server_left <= 0:
				var pt2: Patron = _patrons[_server_patron]
				pt2.state = P_EATING
				pt2.state_t = 0
				pt2.delivered_t = time
				# 기다린 시간이 손님의 인내심을 넘으면 만족도가 한 단계 내려간다(수요 식과 같은 인내심 기준).
				pt2.wait_total = (pt2.seated_t - pt2.queued_t) + (time - pt2.waiting_t)
				if pt2.wait_total > pt2.patience:
					pt2.stars = maxi(1, pt2.base_stars - 1)
				_server_total = Staffing.effective_return(_serve_seconds(pt2.seat), SERVE_BACK_PERCENT, staffing)
				_server_left = _server_total
				_server_state = S_RETURN
		S_RETURN:
			_server_left -= 1
			if _server_left <= 0:
				_server_state = S_IDLE
				_server_patron = -1


func _check_finished() -> void:
	if time >= SERVICE_SECONDS and _next_arrival >= _patrons.size():
		var all_gone: bool = true
		for p in _patrons:
			var pt: Patron = p
			if pt.state != P_GONE:
				all_gone = false
				break
		if all_gone:
			state = FINISHED
			return
	if time >= HARD_LIMIT:
		# 정상 입력에서는 도달하지 않는 안전장치. 정산 불가 상태로 두어 돈이 움직이지 않게 한다.
		state = STALLED


# ---------- 조회 ----------

func pending_revenue() -> int:
	var sum: int = 0
	for c in completed:
		var d: Dictionary = c
		sum += int(d["price"])
	return sum


func stats() -> Dictionary:
	var seated: int = 0
	for i in seat_count:
		if _seat_owner[i] != -1:
			seated += 1
	return {
		"state": state,
		"time": time,
		"queue": _queue.size(),
		"cook_backlog": _cook_queue.size(),
		"cooking": _chef_busy,
		"ready": _ready.size(),
		"serving": _server_state != S_IDLE,
		"seated": seated,
		"completed": completed.size(),
		"planned": _planned_orders,
		"pending_revenue": pending_revenue(),
		"turned_away": turned_away,
	}


## 정산 입력. FINISHED 가 아니면 error만 있다(중단·미완료·정지 세션은 금액을 만들지 못한다).
func summary() -> Dictionary:
	if state != FINISHED:
		return {"error": "끝나지 않은 영업은 정산할 수 없어요."}
	var by_source: Dictionary = {}
	for id in Customers.ids():
		by_source[id] = 0
	by_source[Sim.WALKIN_ID] = 0
	var revenue: int = 0
	var cost: int = 0
	var star_sum: int = 0
	for c in completed:
		var d: Dictionary = c
		by_source[str(d["source"])] = int(by_source[str(d["source"])]) + 1
		revenue += int(d["price"])
		cost += int(d["unit_cost"])
		star_sum += int(d["stars"])
	var count: int = completed.size()
	var avg: float = 0.0
	if count > 0:
		avg = float(star_sum) / float(count)
	var result: Dictionary = {
		"error": "",
		"day": day,
		"record_id": record_id,
		"recipe_name": recipe_name,
		"version": version,
		"config": config.duplicate(true),
		"price": price,
		"units": count,
		"revenue": revenue,
		"ingredient_cost": cost,
		# 운영비 = 기본 + 스냅샷의 보조 직원 하루 운영비. 정산(GameState.settle_service)이 이 값을 정확히 한 번 반영한다.
		"overhead": Sim.overhead_for(staffing),
		"staffing": staffing.duplicate(true),
		"by_source": by_source,
		"turned_away": turned_away,
		"avg_stars": avg,
		"finished_at": time,
	}
	if _multi:
		var rows: Array = menus.duplicate(true)
		for row in rows:
			for key in ["units", "revenue", "ingredient_cost", "margin"]:
				row[key] = 0
			row["wait_total"] = 0
			for key in row["by_source"]:
				row["by_source"][key] = 0
		for order in completed:
			var row: Dictionary = rows[int(order["menu_index"])]
			row["units"] += 1
			row["revenue"] += int(order["price"])
			row["ingredient_cost"] += int(order["unit_cost"])
			row["margin"] += int(order["price"]) - int(order["unit_cost"])
			row["wait_total"] += int(order["wait"])
			row["by_source"][order["source"]] += 1
		result["menus"] = rows
		result["seat_count"] = seat_count
	return result


## 지금까지 기다린 시간(줄 + 음식). 아직 줄/주문 대기 단계가 아니면 0.
func _waited(pt: Patron) -> int:
	if pt.state == P_QUEUED:
		return time - pt.queued_t
	if pt.state == P_WAITING:
		return (pt.seated_t - pt.queued_t) + (time - pt.waiting_t)
	return 0


func _duration_of(pt: Patron) -> int:
	match pt.state:
		P_APPROACH:
			return APPROACH_GS
		P_TO_SEAT:
			return _walk_seconds(maxi(0, pt.seat))
		P_ORDERING:
			return ORDER_GS
		P_EATING:
			return EAT_GS
		P_LEAVING:
			return LEAVE_GS
		P_BALK:
			return BALK_GS
	return 1


static func reaction_kind(stars: int) -> String:
	match stars:
		5:
			return "heart"
		4:
			return "note"
		3:
			return "smile"
		2:
			return "meh"
	return "angry"


## 화면 전용 읽기 스냅샷. 위치는 담지 않고 상태·진행률·자리/줄 번호만 담는다.
func entities() -> Dictionary:
	var slot_of: Dictionary = {}
	for qi in _queue.size():
		slot_of[int(_queue[qi])] = qi
	var slot_counter: int = _queue.size()
	var list: Array = []
	for p in _patrons:
		var pt: Patron = p
		if not pt.spawned or pt.state == P_GONE:
			continue
		var slot: int = -1
		if slot_of.has(pt.id):
			slot = int(slot_of[pt.id])
		elif pt.state == P_APPROACH or pt.state == P_BALK:
			slot = slot_counter
			if pt.will_order and pt.state == P_APPROACH:
				slot_counter += 1
		var prog: float = clampf(float(pt.state_t) / float(_duration_of(pt)), 0.0, 1.0)
		var bubble: String = ""
		match pt.state:
			P_ORDERING:
				bubble = "order"
			P_QUEUED:
				if _waited(pt) > pt.patience:
					bubble = "impatient"
			P_WAITING:
				bubble = "impatient" if _waited(pt) > pt.patience else "wait"
			P_EATING:
				if prog >= 0.55:
					bubble = reaction_kind(pt.stars)
			P_LEAVING:
				if prog < 0.7:
					bubble = reaction_kind(pt.stars)
			P_BALK:
				bubble = "meh"
		list.append({
			"id": pt.id,
			"state": pt.state,
			"p": prog,
			"seat": pt.seat,
			"slot": slot,
			"look": pt.look,
			"source": pt.source,
			"bubble": bubble,
			"balk": not pt.will_order,
		})
		if _multi:
			list[-1]["config"] = menus[pt.menu_index]["config"].duplicate(true)
			list[-1]["record_id"] = menus[pt.menu_index]["record_id"]
	var chef_p: float = 0.0
	if _chef_busy:
		chef_p = 1.0 - float(_chef_left) / float(_chef_total)
	var server_p: float = 0.0
	var server_seat: int = -1
	if _server_state != S_IDLE:
		server_p = 1.0 - float(_server_left) / float(maxi(1, _server_total))
		var sp: Patron = _patrons[_server_patron]
		server_seat = sp.seat
	var result: Dictionary = {
		"time": time,
		"patrons": list,
		"chef_cooking": _chef_busy,
		"chef_p": chef_p,
		"ready": _ready.size(),
		"server_state": _server_state,
		"server_p": server_p,
		"server_seat": server_seat,
	}
	if _multi:
		var configs: Array = []
		for id in _ready:
			configs.append(menus[(_patrons[id] as Patron).menu_index]["config"].duplicate(true))
		result["ready_configs"] = configs
		if _server_state != S_IDLE:
			result["server_config"] = menus[(_patrons[_server_patron] as Patron).menu_index]["config"].duplicate(true)
	return result
