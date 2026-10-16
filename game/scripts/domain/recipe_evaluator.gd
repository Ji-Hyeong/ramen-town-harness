extends RefCounted
## 레시피 평가기. UI와 저장소에 의존하지 않는 순수 계산이며 결과는 입력에만 의존한다(무작위 없음).
##
## 맛 점수 수식(손님마다 취향/가중치가 달라 모든 손님에게 최고인 레시피는 없다):
##   1) profile[축] = 선택 재료들의 기여 합 (0~10으로 제한)
##   2) 축별 간격 gap = |profile - 취향|  (허용 오차 없음: 1만 빗나가도 점수에 반영)
##   3) base = max(0, 100 - GAP_K * Σ(weight*gap) / Σ(weight))      // 가중 평균 간격 기반 취향 점수
##   4) ratio = 손님 민감도 * compat_total / COMPAT_CAP                // 궁합 비율(대략 -1.3~+1.3)
##   5) ratio >= 0 이면 score = base + (100 - base) * min(COMPAT_GAIN_POS * ratio, 1)  // 남은 여유분의 일부만 가산
##      ratio <  0 이면 score = base * (1 + max(COMPAT_GAIN_NEG * ratio, -1))          // 기존 점수에 비례해 감산
## 가산 계수(0.3)가 감산 계수(0.5)보다 작아, 좋은 궁합은 보너스에 그치고 나쁜 궁합은 확실히 벌점이 된다.
## 궁합 가산은 "100점까지 남은 폭"의 비율이라 취향이 크게 빗나간 레시피를 구제하지 못하고,
## 100점으로 포화되지도 않는다. 반대로 나쁜 궁합은 취향이 잘 맞아도 점수를 크게 깎는다.
## 피드백은 간격이 NOTICE_GAP 이상인 축만 지적하고(작은 차이는 "맞아요"), 정렬은 점수와 같은 가중 간격이다.

const Catalog = preload("res://scripts/domain/ingredient_catalog.gd")
const Customers = preload("res://scripts/domain/customer_catalog.gd")
const Check = preload("res://scripts/domain/data_check.gd")
const ProcessRules = preload("res://scripts/domain/recipe_process.gd")

const PROFILE_MAX: int = 10
const GAP_K: float = 14.0
const COMPAT_GAIN_POS: float = 0.3
const COMPAT_GAIN_NEG: float = 0.5
const COMPAT_CAP: int = 20
const NOTICE_GAP: int = 2
## COMPAT 앞쪽 몫(탐험 도입 전부터 있던 규칙)의 개수. 그 뒤 규칙은 모두 발견 재료를 포함해야 한다.
const LEGACY_COMPAT_COUNT: int = 33

const DIR_TEXT: Dictionary = {
	"rich": ["국물이 가벼워요", "국물이 너무 무겁고 느끼해요"],
	"salt": ["간이 싱거워요", "간이 너무 짜요"],
	"aroma": ["향이 밋밋해요", "향이 너무 강해요"],
	"chew": ["면 식감이 너무 약해요", "면이 너무 질겨요"],
	"spice": ["매운맛이 아쉬워요", "너무 매워요"],
}

# 재료 쌍 궁합. score>0 은 상승효과, <0 은 충돌. 두 재료가 모두 선택됐을 때 적용된다.
const COMPAT: Array = [
	{"a": "broth_tonkotsu", "b": "noodle_thick", "score": 6, "note": "진한 돼지뼈 국물이 굵은 꼬불면에 잘 달라붙어요"},
	{"a": "broth_tonkotsu", "b": "noodle_thin", "score": 3, "note": "가는 면이 진한 국물과 빠르게 어우러져요"},
	{"a": "broth_chicken", "b": "noodle_thick", "score": -6, "note": "맑은 닭 육수가 굵은 면의 존재감에 눌려요"},
	{"a": "broth_chicken", "b": "noodle_medium", "score": 3, "note": "맑은 닭 육수에 중간 면의 균형이 좋아요"},
	{"a": "broth_dashi", "b": "noodle_thick", "score": -5, "note": "해물 다시의 섬세한 향이 굵은 면에 가려져요"},
	{"a": "broth_dashi", "b": "noodle_thin", "score": 5, "note": "가는 면이 해물 다시의 향을 잘 살려요"},
	{"a": "broth_tonkotsu", "b": "tare_shio", "score": 5, "note": "소금 타레가 돼지뼈 국물의 느끼함을 정리해요"},
	{"a": "broth_tonkotsu", "b": "tare_miso", "score": -4, "note": "돼지뼈 국물에 된장 타레는 묵직함이 겹쳐 텁텁해요"},
	{"a": "broth_tonkotsu", "b": "tare_shoyu", "score": 2, "note": "돼지뼈 국물에 간장 타레는 무난하게 받쳐줘요"},
	{"a": "broth_chicken", "b": "tare_shoyu", "score": 5, "note": "닭 육수와 간장 타레는 정석적인 조합이에요"},
	{"a": "broth_chicken", "b": "tare_miso", "score": 3, "note": "닭 육수가 된장의 구수함을 부드럽게 받아줘요"},
	{"a": "broth_dashi", "b": "tare_shio", "score": 4, "note": "소금 타레가 해물 다시의 맑은 맛을 그대로 살려요"},
	{"a": "broth_dashi", "b": "tare_miso", "score": -5, "note": "된장 향이 해물 다시의 향과 부딪혀요"},
	{"a": "tare_shoyu", "b": "oil_garlic", "score": 4, "note": "간장 타레와 마늘유는 고소한 향이 잘 이어져요"},
	{"a": "tare_miso", "b": "oil_chili", "score": 5, "note": "된장 타레와 고추기름이 얼큰하게 어우러져요"},
	{"a": "tare_shio", "b": "oil_chili", "score": -3, "note": "소금 타레의 맑은 맛이 고추기름에 묻혀요"},
	{"a": "tare_shio", "b": "oil_scallion", "score": 4, "note": "소금 타레와 파기름이 깔끔하게 어울려요"},
	{"a": "tare_shoyu", "b": "oil_scallion", "score": 2, "note": "간장 타레에 파기름이 달큰함을 더해요"},
	{"a": "tare_miso", "b": "oil_garlic", "score": -3, "note": "된장과 마늘유의 향이 겹쳐 텁텁해져요"},
	{"a": "broth_dashi", "b": "oil_garlic", "score": -4, "note": "마늘유가 해물 다시의 은은한 향을 덮어요"},
	{"a": "broth_tonkotsu", "b": "oil_garlic", "score": 4, "note": "마늘유가 진한 돼지뼈 국물에 힘을 보태요"},
	{"a": "broth_chicken", "b": "oil_scallion", "score": 4, "note": "파기름이 맑은 닭 육수의 단맛을 끌어올려요"},
	{"a": "broth_dashi", "b": "oil_scallion", "score": 3, "note": "파기름이 해물 다시를 해치지 않고 향을 보태요"},
	{"a": "broth_tonkotsu", "b": "oil_chili", "score": 2, "note": "고추기름이 돼지뼈 국물의 느끼함을 잡아줘요"},
	{"a": "noodle_thin", "b": "cook_soft", "score": -6, "note": "가는 면을 푹 익히면 국물에 퍼져버려요"},
	{"a": "noodle_thin", "b": "cook_firm", "score": 4, "note": "가는 면은 꼬들하게 삶아야 제맛이에요"},
	{"a": "noodle_thick", "b": "cook_firm", "score": 3, "note": "굵은 면을 꼬들하게 삶아 씹는 맛이 살아나요"},
	{"a": "noodle_thick", "b": "cook_soft", "score": -2, "note": "굵은 면을 푹 익히면 쫄깃함이 사라져요"},
	{"a": "noodle_medium", "b": "cook_normal", "score": 2, "note": "중간 면은 보통 익힘이 가장 안정적이에요"},
	{"a": "broth_tonkotsu", "b": "topping_sprouts", "score": 3, "note": "숙주의 아삭함이 돼지뼈 국물의 느끼함을 잡아요"},
	{"a": "broth_dashi", "b": "topping_chashu", "score": -2, "note": "차슈의 기름기가 맑은 해물 다시 위에서 겉돌아요"},
	{"a": "tare_miso", "b": "topping_egg", "score": 2, "note": "반숙란의 부드러움이 된장 타레의 구수함과 어울려요"},
	{"a": "broth_dashi", "b": "topping_nori", "score": 2, "note": "김의 바다 향이 해물 다시와 이어져요"},
	# --- 탐험 발견 재료 전용 규칙(위 33개 뒤에만 덧붙인다: LEGACY_COMPAT_COUNT). 모든 규칙이 발견 재료 id를 하나 이상 포함하므로
	# 예전 재료만 쓴 구성은 이 규칙에 절대 걸리지 않아 예전 평가 결과가 그대로다(시험이 이 불변식을 확인한다). ---
	{"a": "broth_clam", "b": "tare_shio", "score": 4, "note": "소금 타레가 조개 국물의 맑은 감칠맛을 그대로 살려요"},
	{"a": "broth_clam", "b": "tare_miso", "score": -4, "note": "된장 향이 조개 국물의 섬세함을 덮어요"},
	{"a": "broth_clam", "b": "noodle_thin", "score": 3, "note": "가는 면이 조개 국물을 가볍게 머금어요"},
	{"a": "broth_clam", "b": "noodle_thick", "score": -4, "note": "굵은 면이 조개 국물의 맛을 눌러요"},
	{"a": "tare_plum", "b": "broth_chicken", "score": 4, "note": "닭 육수에 매실의 산뜻함이 잘 어울려요"},
	{"a": "tare_plum", "b": "broth_tonkotsu", "score": -3, "note": "진한 돼지뼈 국물에는 매실 간이 힘을 못 써요"},
	{"a": "tare_plum", "b": "oil_chili", "score": -2, "note": "고추기름의 매운맛이 매실의 산뜻함을 가려요"},
	{"a": "oil_shrimp", "b": "broth_dashi", "score": 3, "note": "새우유가 해물 다시의 바다 향에 깊이를 더해요"},
	{"a": "oil_shrimp", "b": "broth_tonkotsu", "score": -3, "note": "새우유와 돼지뼈 국물은 둘 다 무거워 느끼해져요"},
	{"a": "oil_pepper", "b": "broth_tonkotsu", "score": 4, "note": "초피의 얼얼함이 돼지뼈 국물의 느끼함을 잡아요"},
	{"a": "oil_pepper", "b": "tare_miso", "score": 3, "note": "된장 타레와 초피유가 산골풍으로 어우러져요"},
	{"a": "oil_pepper", "b": "broth_dashi", "score": -4, "note": "초피의 강한 향이 해물 다시를 압도해요"},
	{"a": "topping_pickle", "b": "broth_tonkotsu", "score": 3, "note": "절임 무의 아삭함이 진한 국물의 느끼함을 씻어요"},
	{"a": "topping_pickle", "b": "topping_chashu", "score": 2, "note": "절임 무가 차슈의 기름기를 정리해요"},
	{"a": "topping_pickle", "b": "broth_dashi", "score": -2, "note": "절임의 신맛이 맑은 해물 다시의 섬세함을 가려요"},
	{"a": "topping_mushroom", "b": "tare_miso", "score": 3, "note": "표고 조림이 된장 타레의 구수함과 이어져요"},
	{"a": "topping_mushroom", "b": "broth_clam", "score": 3, "note": "표고의 감칠맛이 조개 국물과 겹쳐 깊어져요"},
	{"a": "topping_mushroom", "b": "topping_sprouts", "score": -2, "note": "표고 조림과 숙주는 식감이 따로 놀아요"},
]


static func stars_for(score: int) -> int:
	if score >= 85:
		return 5
	if score >= 70:
		return 4
	if score >= 55:
		return 3
	if score >= 40:
		return 2
	return 1


static func build_profile(config: Dictionary) -> Dictionary:
	var profile: Dictionary = {}
	for axis in Catalog.AXES:
		profile[axis] = 0
	# 토핑을 포함한 모든 선택 재료를 Catalog.item_ids() 하나로 훑는다(토핑마다 정확히 한 번 반영, 하나뿐인 옛 구성은 예전과 같은 합).
	for id in Catalog.item_ids(config):
		var item: Dictionary = Catalog.find(id)
		var axes: Dictionary = item["axes"]
		for axis in axes:
			profile[axis] = int(profile[axis]) + int(axes[axis])
	if config.has("process"):
		# 재료 합계에 공법 차이를 한 번 더한 뒤 0~10 범위로 제한한다. 기본 구성은 예전 계산을 유지한다.
		var effects: Dictionary = ProcessRules.effects(config["process"])
		for axis in Catalog.AXES:
			profile[axis] += int(effects["axes"][axis])
	for axis in Catalog.AXES:
		profile[axis] = clampi(int(profile[axis]), 0, PROFILE_MAX)
	return profile


static func unit_cost(config: Dictionary) -> int:
	var total: int = 0
	for id in Catalog.item_ids(config):
		var item: Dictionary = Catalog.find(id)
		total += int(item["cost"])
	if config.has("process"):
		total += int(ProcessRules.effects(config["process"])["cost"])
	return total


## 재료별 준비 시간의 합(보조 직원이 없을 때의 기준 시간). 영업 중 실제 조리 시간은 ShopStaffing.effective_prep()가 이 값에서 계산한다.
static func prep_seconds(config: Dictionary) -> int:
	var total: int = 0
	for id in Catalog.item_ids(config):
		var item: Dictionary = Catalog.find(id)
		total += int(item["seconds"])
	if config.has("process"):
		total += int(ProcessRules.effects(config["process"])["seconds"])
	return total


## 선택된 재료 쌍에 해당하는 궁합 규칙 목록: [{"score": int, "note": String}]
static func applied_compat(config: Dictionary) -> Array:
	var ids: Array[String] = Catalog.item_ids(config)
	var applied: Array = []
	for rule in COMPAT:
		var r: Dictionary = rule
		if ids.has(str(r["a"])) and ids.has(str(r["b"])):
			applied.append({"score": int(r["score"]), "note": str(r["note"])})
	return applied


static func compat_total(applied: Array) -> int:
	var total: int = 0
	for a in applied:
		var d: Dictionary = a
		total += int(d["score"])
	return clampi(total, -COMPAT_CAP, COMPAT_CAP)


static func score_for(profile: Dictionary, compat_sum: int, customer: Dictionary) -> int:
	var targets: Dictionary = customer["targets"]
	var weights: Dictionary = customer["weights"]
	var weighted: float = 0.0
	var weight_sum: float = 0.0
	for axis in Catalog.AXES:
		var gap: int = absi(int(profile[axis]) - int(targets[axis]))
		var w: float = float(weights[axis])
		weighted += w * float(gap)
		weight_sum += w
	var base: float = maxf(0.0, 100.0 - GAP_K * weighted / weight_sum)
	var ratio: float = float(customer["compat_sens"]) * float(compat_sum) / float(COMPAT_CAP)
	var score: float = base
	if ratio >= 0.0:
		score = base + (100.0 - base) * minf(COMPAT_GAIN_POS * ratio, 1.0)
	else:
		score = base * (1.0 + maxf(COMPAT_GAIN_NEG * ratio, -1.0))
	return clampi(roundi(score), 0, 100)


## 전체 평가. 잘못된 구성이면 {"error": 메시지} 만 돌려준다.
static func evaluate(config: Dictionary) -> Dictionary:
	var err: String = Check.config_error(config)
	if err != "":
		return {"error": err}
	var profile: Dictionary = build_profile(config)
	var applied: Array = applied_compat(config)
	var total: int = compat_total(applied)
	var customers: Array = []
	var score_sum: int = 0
	for c in Customers.all():
		var customer: Dictionary = c
		var score: int = score_for(profile, total, customer)
		score_sum += score
		var fb: Dictionary = _feedback(customer, profile, applied, config, score)
		customers.append({
			"id": str(customer["id"]),
			"name": str(customer["name"]),
			"persona": str(customer["persona"]),
			"score": score,
			"stars": stars_for(score),
			"headline": str(fb["headline"]),
			"reasons": fb["reasons"],
			"value_note": str(fb["value_note"]),
		})
	return {
		"error": "",
		"profile": profile,
		"compat_total": total,
		"compat_applied": applied,
		"unit_cost": unit_cost(config),
		"prep_seconds": prep_seconds(config),
		"customers": customers,
		"average_score": roundi(float(score_sum) / float(customers.size())),
	}


## 인과 피드백: 가장 크게 어긋난 축(가중 간격 순)과 가장 영향 큰 궁합 규칙을 문장으로 풀어쓴다.
static func _feedback(customer: Dictionary, profile: Dictionary, applied: Array, config: Dictionary, score: int) -> Dictionary:
	var targets: Dictionary = customer["targets"]
	var weights: Dictionary = customer["weights"]
	var why: Dictionary = customer["why"]
	# [가중 간격, 축] 목록을 가중 간격 내림차순으로 정렬한다(동률은 축 순서 유지).
	var gaps: Array = []
	for axis in Catalog.AXES:
		var gap: int = absi(int(profile[axis]) - int(targets[axis]))
		if gap >= NOTICE_GAP:
			gaps.append({"axis": axis, "value": float(weights[axis]) * float(gap)})
	gaps.sort_custom(func(x: Dictionary, y: Dictionary) -> bool: return float(x["value"]) > float(y["value"]))

	var reasons: Array[String] = []
	var headline: String = ""
	var count: int = mini(2, gaps.size())
	for i in count:
		var g: Dictionary = gaps[i]
		var axis: String = str(g["axis"])
		var cur: int = int(profile[axis])
		var want: int = int(targets[axis])
		var dirs: Array = DIR_TEXT[axis]
		var text: String = str(dirs[0]) if cur < want else str(dirs[1])
		var line: String = "%s (%s %d, 취향 %d): %s." % [text, str(Catalog.AXIS_NAMES[axis]), cur, want, str(why[axis])]
		if i == 0:
			headline = text
		reasons.append(line)
	if gaps.is_empty():
		# 모두 허용 오차 이내: 가중치가 가장 큰 축을 칭찬한다.
		var best_axis: String = ""
		var best_w: float = -1.0
		for axis in Catalog.AXES:
			if float(weights[axis]) > best_w:
				best_w = float(weights[axis])
				best_axis = axis
		headline = "취향과 딱 맞아요"
		reasons.append("%s %d는 제 취향(%d)과 맞아요: %s." % [str(Catalog.AXIS_NAMES[best_axis]), int(profile[best_axis]), int(targets[best_axis]), str(why[best_axis])])
	elif gaps.size() < Catalog.AXES.size():
		# 맞는 축 중 가중치가 큰 축을 하나 짚어준다.
		var fit_axis: String = ""
		var fit_w: float = -1.0
		for axis in Catalog.AXES:
			var matched: bool = true
			for g in gaps:
				var gd: Dictionary = g
				if str(gd["axis"]) == axis:
					matched = false
			if matched and float(weights[axis]) > fit_w:
				fit_w = float(weights[axis])
				fit_axis = axis
		if fit_axis != "":
			reasons.append("%s %d는 취향(%d)에 맞아요." % [str(Catalog.AXIS_NAMES[fit_axis]), int(profile[fit_axis]), int(targets[fit_axis])])

	# 궁합: 가장 나쁜 규칙과 가장 좋은 규칙을 각각 한 줄씩.
	var worst: Dictionary = {}
	var best: Dictionary = {}
	for a in applied:
		var ad: Dictionary = a
		if int(ad["score"]) <= -3 and (worst.is_empty() or int(ad["score"]) < int(worst["score"])):
			worst = ad
		if int(ad["score"]) >= 3 and (best.is_empty() or int(ad["score"]) > int(best["score"])):
			best = ad
	if not worst.is_empty():
		var tail: String = " 조합에 예민해서 점수에 크게 반영했어요." if float(customer["compat_sens"]) >= 1.2 else ""
		reasons.append("조합 아쉬움: %s.%s" % [str(worst["note"]), tail])
	if not best.is_empty():
		reasons.append("조합 호평: %s." % str(best["note"]))

	return {"headline": headline, "reasons": reasons, "value_note": _value_note(customer, int(config["price"]))}


static func _value_note(customer: Dictionary, price: int) -> String:
	var fair: int = int(customer["fair_price"])
	var max_price: int = int(customer["max_price"])
	if price > max_price:
		return "%d원은 제가 낼 수 있는 선(%d원)을 넘어요." % [price, max_price]
	if price > fair:
		return "%d원은 기대 가격(%d원)보다 조금 비싸게 느껴져요." % [price, fair]
	if price * 100 <= fair * 85:
		return "%d원이면 부담 없이 자주 올 수 있어요." % price
	return "%d원은 적당한 가격이에요." % price
