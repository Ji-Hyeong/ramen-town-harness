extends RefCounted
## 단골 손님 데이터. 취향(targets)은 맛 축별 이상값, weights는 그 축이 빗나갈 때의 민감도다.
## compat_sens: 재료 궁합에 얼마나 민감한가(점수 반영 배율).
## fair_price/max_price/price_sens: 가격 기대치(원), 감당 상한, 비싸질 때 수요가 줄어드는 속도.
## patience_seconds: 이보다 준비 시간이 길면 방문을 포기하는 손님이 늘어난다.
## base_visits: 평일 기준 하루 방문 의향 인원.

const CUSTOMERS: Array = [
	{
		"id": "dohyun", "name": "한도윤",
		"persona": "야근 뒤 늦은 점심을 먹는 개발자 · 진하고 든든한 국물파",
		"targets": {"rich": 9, "salt": 6, "aroma": 5, "chew": 7, "spice": 2},
		"weights": {"rich": 1.6, "salt": 1.0, "aroma": 0.8, "chew": 1.2, "spice": 0.4},
		"why": {
			"rich": "야근 뒤에는 속이 꽉 차는 진한 국물이 필요해요",
			"salt": "간이 센 편이 든든하게 느껴져요",
			"aroma": "향은 은은하게 받쳐주는 정도가 좋아요",
			"chew": "씹는 맛이 살아 있는 굵은 면을 좋아해요",
			"spice": "매운맛은 살짝 포인트만 있으면 돼요",
		},
		"compat_sens": 1.0,
		"fair_price": 9500, "max_price": 13500, "price_sens": 1.2,
		"patience_seconds": 180, "base_visits": 4,
	},
	{
		"id": "hayoung", "name": "서하영",
		"persona": "점심시간이 짧은 초등학교 교사 · 담백하고 향이 좋은 맑은 국물파",
		"targets": {"rich": 3, "salt": 4, "aroma": 7, "chew": 4, "spice": 0},
		"weights": {"rich": 1.0, "salt": 1.5, "aroma": 1.6, "chew": 0.8, "spice": 1.2},
		"why": {
			"rich": "오후 수업 전에는 부담스럽지 않은 가벼운 국물이 좋아요",
			"salt": "간이 세면 오후 내내 목이 말라서 약한 간을 선호해요",
			"aroma": "향이 풍부해야 맑은 국물에서도 풍미를 느껴요",
			"chew": "빨리 먹기 좋은 가는 면이 편해요",
			"spice": "매운 음식은 잘 못 먹어요",
		},
		"compat_sens": 1.3,
		"fair_price": 9000, "max_price": 12500, "price_sens": 1.0,
		"patience_seconds": 150, "base_visits": 3,
	},
	{
		"id": "maru", "name": "윤마루",
		"persona": "용돈이 빠듯한 대학원생 · 얼큰하고 짭짤한 국물파, 빠른 서빙이 중요",
		"targets": {"rich": 6, "salt": 7, "aroma": 4, "chew": 6, "spice": 6},
		"weights": {"rich": 0.8, "salt": 1.0, "aroma": 0.6, "chew": 1.0, "spice": 1.8},
		"why": {
			"rich": "너무 느끼한 건 금방 질리고 적당히 든든하면 돼요",
			"salt": "짭짤해야 한 끼가 된 느낌이 들어요",
			"aroma": "향보다는 맛의 힘이 중요해요",
			"chew": "적당히 쫄깃한 면이면 만족해요",
			"spice": "얼큰함이 없으면 라멘 먹은 기분이 안 나요",
		},
		"compat_sens": 0.8,
		"fair_price": 7500, "max_price": 10000, "price_sens": 2.2,
		"patience_seconds": 110, "base_visits": 5,
	},
]


static func all() -> Array:
	return CUSTOMERS


static func ids() -> Array[String]:
	var out: Array[String] = []
	for c in CUSTOMERS:
		var d: Dictionary = c
		out.append(str(d["id"]))
	return out


static func find(id: String) -> Dictionary:
	for c in CUSTOMERS:
		var d: Dictionary = c
		if str(d["id"]) == id:
			return d
	return {}
