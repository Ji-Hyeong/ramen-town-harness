extends RefCounted
## 하루 영업 시뮬레이션(결정적). 한 번 호출 = 영업 하루.
##
## 수요 = 방문 의향 × 요일 배율 × 맛 계수 × 가격 계수 × 인내심 계수.
##  - 맛 계수: 시식 점수 30점 이하는 0, 100점이면 1 (선형).
##  - 가격 계수: 기대 가격 이하면 최대 1.25배까지 가산, 초과하면 가격 민감도만큼 감소, 상한 초과 시 0.
##  - 인내심 계수: 준비 시간이 손님의 인내심을 넘으면 최대 60%까지 이탈.
## 판매량 = min(수요, 점심 피크 동안 만들 수 있는 그릇 수). 비싼 메뉴가 자동으로 이기지 않는다.

const Customers = preload("res://scripts/domain/customer_catalog.gd")
const Check = preload("res://scripts/domain/data_check.gd")
const Evaluator = preload("res://scripts/domain/recipe_evaluator.gd")
const Staffing = preload("res://scripts/domain/shop_staffing.gd")

const SERVICE_SECONDS: int = 2400
const OVERHEAD: int = 3000
const WALKIN_ID: String = "walkin"
const WALKIN_BASE: int = 5
const WALKIN_FAIR: int = 9000
const WALKIN_MAX: int = 14000
const WALKIN_SENS: float = 1.3
const WALKIN_PATIENCE: int = 150
# 요일 배율(일차 % 7). 하루가 지날 때마다 다음 값이 적용된다.
const DAY_MULT: Array[float] = [1.0, 0.9, 1.0, 1.1, 1.2, 1.3, 0.8]


static func taste_factor(score: int) -> float:
	return clampf(float(score - 30) / 70.0, 0.0, 1.0)


static func price_factor(price: int, fair: int, max_price: int, sens: float) -> float:
	if price > max_price:
		return 0.0
	var ratio: float = float(price) / float(fair)
	if ratio <= 1.0:
		return minf(1.25, 1.0 + (1.0 - ratio) * 0.5)
	return maxf(0.0, 1.0 - (ratio - 1.0) * sens)


static func patience_factor(prep: int, patience: int) -> float:
	if prep <= patience:
		return 1.0
	return 1.0 - clampf(float(prep - patience) / 200.0, 0.0, 0.6)


static func day_multiplier(day: int) -> float:
	return DAY_MULT[day % DAY_MULT.size()]


static func _demand(base: int, mult: float, score: int, price: int, fair: int, max_price: int, sens: float, prep: int, patience: int) -> int:
	var d: float = float(base) * mult * taste_factor(score) * price_factor(price, fair, max_price, sens) * patience_factor(prep, patience)
	return maxi(0, roundi(d))


## 그날의 총 운영비 = 기본 운영비 + 고용한 보조 직원의 하루 운영비(스냅샷 값). 보조 직원이 없으면 기준과 정확히 같다.
static func overhead_for(staffing: Dictionary) -> int:
	return OVERHEAD + Staffing.daily_wage(staffing)


## config: 검증된 레시피 구성, scores: {손님id: 0~100 점수}, day: 1 이상.
## staffing: ShopStaffing.snapshot()(영업 시작 시점의 직원 구성). 빈 딕셔너리 = 보조 직원 없음 = 기준 계산과 동일.
##   조리 보조는 실제 조리 시간(→ 수용량·이탈)을, 모든 보조는 운영비를 바꾼다. 맛 점수/수요 취향에는 손대지 않는다.
## 반환: {"error", "units", "revenue", "ingredient_cost", "overhead", "net", "demand", "capacity", "by_source"}
static func simulate(config: Dictionary, scores: Dictionary, day: int, staffing: Dictionary = {}) -> Dictionary:
	var err: String = Check.config_error(config)
	if err != "":
		return {"error": err}
	if day < 1:
		return {"error": "영업일은 1 이상이어야 해요."}
	var staff_err: String = Staffing.snapshot_error(staffing)
	if staff_err != "":
		return {"error": staff_err}
	var ids: Array[String] = Customers.ids()
	var score_sum: int = 0
	for id in ids:
		if not scores.has(id) or not Check.in_range(scores[id], 0, 100):
			return {"error": "손님 점수가 올바르지 않아요 (%s)." % id}
		score_sum += int(scores[id])
	if scores.size() != ids.size():
		return {"error": "알 수 없는 손님 점수가 있어요."}

	var price: int = int(config["price"])
	var cost: int = Evaluator.unit_cost(config)
	var prep: int = Staffing.effective_prep(Evaluator.prep_seconds(config), staffing)
	var overhead: int = overhead_for(staffing)
	var mult: float = day_multiplier(day)

	var order: Array[String] = []
	var demands: Dictionary = {}
	for c in Customers.all():
		var customer: Dictionary = c
		var id: String = str(customer["id"])
		order.append(id)
		demands[id] = _demand(int(customer["base_visits"]), mult, int(scores[id]), price,
			int(customer["fair_price"]), int(customer["max_price"]), float(customer["price_sens"]),
			prep, int(customer["patience_seconds"]))
	# 처음 보는 손님은 세 단골의 평균 평가를 따른다.
	var avg_score: int = roundi(float(score_sum) / float(ids.size()))
	order.append(WALKIN_ID)
	demands[WALKIN_ID] = _demand(WALKIN_BASE, mult, avg_score, price, WALKIN_FAIR, WALKIN_MAX,
		WALKIN_SENS, prep, WALKIN_PATIENCE)

	var total_demand: int = 0
	for id in order:
		total_demand += int(demands[id])
	var capacity: int = SERVICE_SECONDS / prep
	var served: int = mini(total_demand, capacity)

	# 용량 부족 시 수요 비율대로 내림 배분하고, 남은 그릇은 순서대로 한 그릇씩 채운다.
	var by_source: Dictionary = {}
	var allocated: int = 0
	for id in order:
		var share: int = 0
		if total_demand > 0:
			share = floori(float(int(demands[id])) * float(served) / float(total_demand))
		by_source[id] = share
		allocated += share
	var guard: int = 0
	while allocated < served and guard < 1000:
		for id in order:
			if allocated < served and int(by_source[id]) < int(demands[id]):
				by_source[id] = int(by_source[id]) + 1
				allocated += 1
		guard += 1

	var revenue: int = served * price
	var ingredient_cost: int = served * cost
	return {
		"error": "",
		"units": served,
		"revenue": revenue,
		"ingredient_cost": ingredient_cost,
		"overhead": overhead,
		"net": revenue - ingredient_cost - overhead,
		"demand": total_demand,
		"capacity": capacity,
		"by_source": by_source,
	}
