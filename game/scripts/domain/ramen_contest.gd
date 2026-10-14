extends RefCounted
## 라멘 대회 카탈로그와 채점. UI/저장소/상태에 의존하지 않는 순수 계산이다(무작위 없음, 입력에만 의존).
## 순위(rank)/발견 재료 보유/기록 존재/날짜/지갑 검사는 상태(GameState)와 UI의 몫이고, 여기서는 "이 구성이 대회에서 몇 점인가"만 정한다.
##
## 점수 수식(0~100 정수):
##   1) 레시피 프로필은 평가기(Evaluator)가 구성으로부터 새로 계산한다. 전달/저장된 점수는 절대 믿지 않는다.
##   2) 테마 적합 theme = clamp(100 - THEME_K * (다섯 축 |프로필 - 대회 목표|의 평균), 0, 100)을 반올림한 정수.
##   3) 손님 평가 audience = 평가기가 돌려준 단골 3명의 실제 점수 평균을 반올림한 정수.
##   4) score = round(0.7 * theme + 0.3 * audience).   (THEME_WEIGHT_PERCENT = 70)
## 가격/현금/직원/등급은 점수에 들어가지 않는다. 대회마다 목표 프로필이 달라 한 레시피가 모든 대회에서 금메달일 수 없다.

const Catalog = preload("res://scripts/domain/ingredient_catalog.gd")
const Evaluator = preload("res://scripts/domain/recipe_evaluator.gd")
const Check = preload("res://scripts/domain/data_check.gd")

const THEME_K: float = 12.0
const THEME_WEIGHT_PERCENT: int = 70

## 메달 등급: 0=수상 없음 1=동 2=은 3=금. min_score 이상이면 그 등급, prize는 대회당 "누적 최대" 상금(상태는 개선분만 지급).
const BANDS: Dictionary = {
	0: {"name": "수상 없음", "min_score": 0, "prize": 0},
	1: {"name": "동메달", "min_score": 55, "prize": 4000},
	2: {"name": "은메달", "min_score": 70, "prize": 10000},
	3: {"name": "금메달", "min_score": 85, "prize": 18000},
}

## targets는 대회가 원하는 5축 프로필(0~10). 세 대회의 목표가 서로 달라야 하며, 각각 현재 재료만으로 금메달이 가능하다.
## requires_discovery: 구성에 발견 재료가 하나 이상 있어야 채점한다(없으면 점수 0이 아니라 평가 오류).
const CONTESTS: Array = [
	{
		"id": "clear_bowl", "rank": 1, "min_day": 3, "fee": 2000, "article_cash": 3000,
		"title": "맑은 한 그릇 대회",
		"description": "군더더기 없이 맑고 향 좋은 국물을 겨루는 동네 대회예요.",
		"criteria": "가벼운 국물, 또렷한 향, 매운맛 없음.",
		"targets": {"rich": 2, "salt": 6, "aroma": 7, "chew": 5, "spice": 0},
		"requires_discovery": false,
		"article_title": "맑은 국물의 새 얼굴, '%s'",
		"article_text": "'%s'이(가) 맑은 한 그릇 대회에서 눈길을 끌었다. 가벼운 국물과 또렷한 향이 심사위원의 입맛을 사로잡았다는 평이다.",
	},
	{
		"id": "deep_bowl", "rank": 2, "min_day": 6, "fee": 4000, "article_cash": 5000,
		"title": "진한 한 그릇 대회",
		"description": "오래 우린 진한 국물과 씹는 맛을 겨루는 대회예요.",
		"criteria": "묵직한 국물, 보통 간, 쫄깃하고 굵은 면.",
		"targets": {"rich": 8, "salt": 4, "aroma": 5, "chew": 7, "spice": 0},
		"requires_discovery": false,
		"article_title": "진국의 힘, '%s'",
		"article_text": "'%s'이(가) 진한 한 그릇 대회에서 묵직한 국물로 화제가 됐다. 굵은 면에 감겨 오르는 국물이 인상적이라는 평이다.",
	},
	{
		"id": "regional_bowl", "rank": 3, "min_day": 11, "fee": 6000, "article_cash": 8000,
		"title": "지역 식재료 대회",
		"description": "탐험으로 찾은 지역 식재료를 살린 한 그릇을 겨루는 대회예요.",
		"criteria": "발견 재료 1개 이상, 향 풍부, 은은한 매운맛, 가벼운 국물.",
		"targets": {"rich": 3, "salt": 6, "aroma": 8, "chew": 5, "spice": 3},
		"requires_discovery": true,
		"article_title": "지역의 맛을 담다, '%s'",
		"article_text": "'%s'이(가) 지역 식재료 대회에서 각지의 재료를 한 그릇에 담아내 호평을 받았다. 향과 얼얼한 끝맛이 돋보였다는 평이다.",
	},
]


## 정의의 깊은 복사본(수정해도 CONTESTS는 변하지 않는다).
static func catalog() -> Array:
	return CONTESTS.duplicate(true)


static func ids() -> Array[String]:
	var out: Array[String] = []
	for c in CONTESTS:
		out.append(str((c as Dictionary)["id"]))
	return out


## 없는 id는 빈 딕셔너리.
static func find(id: String) -> Dictionary:
	for c in CONTESTS:
		var d: Dictionary = c
		if str(d["id"]) == id:
			return d.duplicate(true)
	return {}


static func band_for(score: int) -> int:
	for band in [3, 2, 1]:
		if score >= int((BANDS[band] as Dictionary)["min_score"]):
			return band
	return 0


## 범위 밖 등급은 빈 문자열/0원(호출자의 잘못된 값이 지급으로 이어지지 않게).
static func band_name(band: int) -> String:
	if not BANDS.has(band):
		return ""
	return str((BANDS[band] as Dictionary)["name"])


static func prize_for(band: int) -> int:
	if not BANDS.has(band):
		return 0
	return int((BANDS[band] as Dictionary)["prize"])


## 채점. 실패하면 {"error": 비어 있지 않은 메시지}만, 성공하면
## {error:"", score, band, theme_score, audience_score, profile(레시피의 실제 5축), feedback(축별), config(정규화 깊은 복사)}.
static func evaluate(id: String, config: Dictionary) -> Dictionary:
	var contest: Dictionary = find(id)
	if contest.is_empty():
		return {"error": "알 수 없는 대회입니다 (%s)." % id}
	var err: String = Check.config_error(config)
	if err != "":
		return {"error": err}
	if bool(contest["requires_discovery"]):
		var found: bool = false
		var discovery: Array[String] = Catalog.discovery_ids()
		for item_id in Catalog.item_ids(config):
			if discovery.has(item_id):
				found = true
		if not found:
			return {"error": "이 대회에는 탐험으로 발견한 재료가 하나 이상 필요해요."}
	var evaluated: Dictionary = Evaluator.evaluate(config)
	if str(evaluated["error"]) != "":
		return {"error": str(evaluated["error"])}

	var profile: Dictionary = evaluated["profile"]
	var targets: Dictionary = contest["targets"]
	var feedback: Array = []
	var gap_sum: int = 0
	for axis in Catalog.AXES:
		var cur: int = int(profile[axis])
		var want: int = int(targets[axis])
		var gap: int = absi(cur - want)
		gap_sum += gap
		feedback.append({"axis": axis, "current": cur, "target": want, "gap": gap, "hint": _hint(axis, cur, want)})
	var theme: int = roundi(clampf(100.0 - THEME_K * float(gap_sum) / float(Catalog.AXES.size()), 0.0, 100.0))

	var customers: Array = evaluated["customers"]
	var score_sum: int = 0
	for c in customers:
		score_sum += int((c as Dictionary)["score"])
	var audience: int = roundi(float(score_sum) / float(customers.size()))

	var score: int = clampi(roundi(float(THEME_WEIGHT_PERCENT) * float(theme) / 100.0 + float(100 - THEME_WEIGHT_PERCENT) * float(audience) / 100.0), 0, 100)
	return {
		"error": "",
		"score": score,
		"band": band_for(score),
		"theme_score": theme,
		"audience_score": audience,
		"profile": profile.duplicate(true),
		"feedback": feedback,
		"config": Catalog.normalize_config(config).duplicate(true),
	}


static func _hint(axis: String, cur: int, want: int) -> String:
	var name: String = str(Catalog.AXIS_NAMES[axis])
	if cur == want:
		return "%s이(가) 대회 기준과 딱 맞아요." % name
	if cur < want:
		return "%s을(를) %d만큼 더 올려 보세요." % [name, want - cur]
	return "%s을(를) %d만큼 낮춰 보세요." % [name, cur - want]
