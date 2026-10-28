extends RefCounted
## 시식한 라멘의 요리 정체성(describe)과 같은 메뉴의 실제 판매 투영(sales). 순수 계산이며 상태/저장 구조를 읽거나 쓰지 않는다.
##
## 원칙:
##  - 정체성은 "설명"일 뿐이다. 고유한 발견 레시피, 업적, 점수 보너스, 숨은 품질 등급이 아니다. 어떤 구성은 특징이 뚜렷하지
##    않을 수 있고, 그때는 솔직하게 "무난한 한 그릇"이라고 말한다. 새 점수/수식을 만들지 않고 RecipeDiscovery 의 구간(AXIS_HIGH 등)과
##    태그, RecipeEvaluator 의 프로필/원가/준비 시간/점수를 그대로 다시 쓴다.
##  - describe 는 불변 시식 기록(record_id/version/name/config/scores)에서만 읽는다. 현재 편집 중인 초안은 받지도 않는다.
##    가격과 이름, 토핑을 고른 순서는 요리의 성격을 바꾸지 않는다(구성을 정규화한 뒤 계산). 같은 토핑을 겹쳐 올린 분량,
##    원재료 육수/면 배합, 공법은 프로필과 원가에 들어가므로 성격을 바꿀 수 있다.
##  - 기록의 scores 필드는 믿지 않고 평가기 결과와 맞는지 확인한다. 맞지 않으면 명시적으로 거부한다.
##  - describe 의 customers 는 "시식 취향 점수가 가장 높은 손님"이다. 실제 구매/판매 반응이 아니다.
##  - sales 는 이미 끝난 영업의 메뉴별 영수증 한 행만 읽는다. 판매 그릇 수와 손님별 수는 실제 완료 주문이고,
##    메뉴 마진은 매출 - 재료비이다(하루 운영비를 뺀 순이익이 아니다). 평균 대기는 wait_total 이 있고 판매가 있을 때만 계산한다.
##    영수증이 보존하지 않는 값(손님별 별점, 만족도, 이탈 이유)은 만들지 않는다.
##  - 예전 영수증은 config 가 없거나 비어 있을 수 있다. 그때는 현재 초안이나 이름에서 되살리지 않고 "정체성 없음"으로 돌려준다.
##  - 돌려주는 가변 데이터(배열/사전)는 모두 새 복사본이다.

const Catalog = preload("res://scripts/domain/ingredient_catalog.gd")
const Check = preload("res://scripts/domain/data_check.gd")
const Customers = preload("res://scripts/domain/customer_catalog.gd")
const Evaluator = preload("res://scripts/domain/recipe_evaluator.gd")
const Discovery = preload("res://scripts/domain/recipe_discovery.gd")
const Sim = preload("res://scripts/domain/sales_simulator.gd")

const MAX_FEATURES: int = 2
const MAX_MATERIALS: int = 3
## 매운 한 그릇으로 보는 매운맛 값. RecipeDiscovery 의 "얼큰한 기름" 주제 기준(매운맛 5 이상)과 같다.
const SPICY_AXIS: int = 5
## 가볍다고 보는 진함 상한. RecipeDiscovery 의 "맑고 향긋한 한 그릇" 주제 기준(진함 5 이하)과 같다.
const LIGHT_RICH_MAX: int = 5

const HEAD_SPICY: String = "얼큰한 한 그릇"
const HEAD_RICH: String = "진하고 든든한 한 그릇"
const HEAD_NOODLE: String = "면이 돋보이는 한 그릇"
const HEAD_LIGHT: String = "맑고 향긋한 한 그릇"
const HEAD_PLAIN: String = "무난한 한 그릇"
const NO_RECIPE_NOTE: String = "이전 영수증에는 그릇 구성이 남아 있지 않아요."

## RecipeDiscovery.describe 태그 중 "요리의 성격"이 아닌 것(궁합 평가, 원가, 준비 시간). 특징 칸에는 쓰지 않는다.
const _TAGS_NOT_CHARACTER: Array[String] = [
	"궁합 좋음", "궁합 아쉬움", "원가 높음", "알뜰한 원가", "준비 오래 걸림", "빠른 준비",
]


## 시식 기록 한 건의 정체성. 실패하면 error 에 짧은 이유가 있고 available=false 이다.
## record 는 실제 기록 모양(양의 정수 record_id/version, 이름, 정규 구성, 평가기와 일치하는 scores)이어야 한다.
## 초안(draft)처럼 record_id 가 없는 입력은 시식으로 받지 않는다.
static func describe(record: Dictionary) -> Dictionary:
	var out: Dictionary = _blank("tasting")
	var shape: String = _record_shape_error(record)
	if shape != "":
		out["error"] = shape
		return out
	var config: Dictionary = Catalog.normalize_config(record["config"])
	var evaluation: Dictionary = Evaluator.evaluate(config)
	if str(evaluation["error"]) != "":
		out["error"] = "시식 기록의 그릇 구성을 확인해 주세요."
		return out
	var scores_error: String = _scores_error(record["scores"], evaluation)
	if scores_error != "":
		out["error"] = scores_error
		return out
	out["record_id"] = int(record["record_id"])
	out["recipe_name"] = str(record["name"])
	out["version"] = int(record["version"])
	_fill_identity(out, config)
	out["customers"] = _best_tasters(evaluation)
	return out


## 메뉴별 완료 영수증 한 행의 판매 투영. identity 칸은 config 가 있을 때만 채운다.
static func sales(row: Dictionary) -> Dictionary:
	var out: Dictionary = _blank("sales")
	out["units"] = 0
	out["margin"] = 0
	out["has_wait"] = false
	out["average_wait"] = 0.0
	out["price"] = 0
	out["revenue"] = 0
	out["ingredient_cost"] = 0
	out["note"] = ""
	var problem: String = _row_error(row)
	if problem != "":
		out["error"] = problem
		return out
	var units: int = int(row["units"])
	var revenue: int = int(row["revenue"])
	var cost: int = int(row["ingredient_cost"])
	out["record_id"] = int(row.get("record_id", 0))
	out["recipe_name"] = str(row["recipe_name"])
	out["version"] = int(row["version"])
	out["units"] = units
	out["price"] = int(row["price"])
	out["revenue"] = revenue
	out["ingredient_cost"] = cost
	# 메뉴 마진은 매출에서 이 메뉴의 재료비만 뺀 값이다. 하루 운영비는 영업 전체에서 한 번 차감되므로 여기에 넣지 않는다.
	out["margin"] = revenue - cost
	if row.has("wait_total") and units > 0:
		out["has_wait"] = true
		out["average_wait"] = float(int(row["wait_total"])) / float(units)
	out["customers"] = _top_buyers(row["by_source"])
	var raw_config: Variant = row.get("config", {})
	var config_dict: Dictionary = raw_config if typeof(raw_config) == TYPE_DICTIONARY else {}
	if config_dict.is_empty():
		out["note"] = NO_RECIPE_NOTE
		return out
	_fill_identity(out, Catalog.normalize_config(config_dict))
	return out


# ---------- 내부 ----------

static func _blank(kind: String) -> Dictionary:
	var features: Array[String] = []
	var materials: Array[String] = []
	var customers: Array = []
	return {
		"error": "", "kind": kind, "available": false, "headline": "",
		"features": features, "materials": materials, "config": {},
		"record_id": 0, "recipe_name": "", "version": 0,
		"unit_cost": 0, "prep_seconds": 0, "customers": customers,
	}


## 검증을 통과한 정규 구성에서 정체성 칸을 채운다. 가격/이름은 계산에 쓰지 않는다.
static func _fill_identity(out: Dictionary, config: Dictionary) -> void:
	var profile: Dictionary = Evaluator.build_profile(config)
	out["available"] = true
	out["headline"] = _headline(config, profile)
	out["features"] = _features(config, profile)
	out["materials"] = _materials(config)
	out["config"] = config
	out["unit_cost"] = Evaluator.unit_cost(config)
	out["prep_seconds"] = Evaluator.prep_seconds(config)


## 제목: 연구 주제가 쓰는 같은 기준으로 매운/진한/면/맑은 성격 중 하나를 고른다. 어느 것도 아니면 무난한 한 그릇.
## 우선순위는 매운맛 > 진함 > 면 > 맑음이며 점수와는 무관하다.
static func _headline(config: Dictionary, profile: Dictionary) -> String:
	var themes: Array[String] = Discovery.matched_ids(config)
	if themes.has("fire_oil"):
		return HEAD_SPICY
	if themes.has("bone_depth") or themes.has("sesame_roast"):
		return HEAD_RICH
	if themes.has("noodle_chew"):
		return HEAD_NOODLE
	if themes.has("clear_light") or themes.has("citrus_light"):
		return HEAD_LIGHT
	# 주제의 재료 조건은 못 채웠어도 맛 값이 뚜렷하면 같은 구간으로 분류한다.
	if int(profile["spice"]) >= SPICY_AXIS:
		return HEAD_SPICY
	if int(profile["rich"]) >= Discovery.AXIS_HIGH:
		return HEAD_RICH
	if int(profile["chew"]) >= Discovery.AXIS_HIGH:
		return HEAD_NOODLE
	if int(profile["aroma"]) >= Discovery.AXIS_HIGH and int(profile["rich"]) <= LIGHT_RICH_MAX:
		return HEAD_LIGHT
	return HEAD_PLAIN


## 특징 최대 2개. 겹쳐 올린 분량 > 높은 맛(값이 큰 순) > 공법 이름 > 낮은 맛 순서로 고른다.
## 높음/낮음 판정과 공법 이름은 RecipeDiscovery.describe 태그에서 그대로 가져온다(구간을 다시 만들지 않는다).
static func _features(config: Dictionary, profile: Dictionary) -> Array[String]:
	var tags: Array = Discovery.describe(config)["tags"]
	var picks: Array[String] = []
	var portion: String = _repeated_portion(config)
	if portion != "":
		picks.append(portion)
	var highs: Array = []
	var lows: Array[String] = []
	var axis_texts: Array[String] = []
	for i in Catalog.AXES.size():
		var axis: String = Catalog.AXES[i]
		var label: String = str(Catalog.AXIS_NAMES[axis])
		var high: String = label + " 높음"
		var low: String = label + " 낮음"
		axis_texts.append(high)
		axis_texts.append(low)
		if tags.has(high):
			highs.append({"value": int(profile[axis]), "index": i, "text": high})
		if tags.has(low):
			lows.append(low)
	highs.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a["value"]) != int(b["value"]):
			return int(a["value"]) > int(b["value"])
		return int(a["index"]) < int(b["index"]))
	for h in highs:
		picks.append(str((h as Dictionary)["text"]))
	for tag in tags:
		var text: String = str(tag)
		if not axis_texts.has(text) and not _TAGS_NOT_CHARACTER.has(text):
			picks.append(text)
	picks.append_array(lows)
	var out: Array[String] = []
	for pick in picks:
		if out.size() < MAX_FEATURES and not out.has(pick):
			out.append(pick)
	return out


## 같은 토핑을 2분량 이상 올렸다면 가장 많이 올린 토핑("차슈 ×2 듬뿍"). 동률이면 카탈로그 순서가 앞선 쪽. 없으면 "".
static func _repeated_portion(config: Dictionary) -> String:
	var ids: Array = Catalog.canonical_toppings(Catalog.toppings_of(config))
	var best_id: String = ""
	var best_count: int = 1
	for value in ids:
		var id: String = str(value)
		var count: int = ids.count(id)
		if count > best_count:
			best_id = id
			best_count = count
	if best_id == "":
		return ""
	var item: Dictionary = Catalog.find(best_id)
	return "%s ×%d 듬뿍" % [str(item["name"]) if not item.is_empty() else best_id, best_count]


## 그림으로 보여 줄 실제 카탈로그 재료 id 최대 3개: 육수, 면, 그리고 가장 눈에 띄는 한 가지.
## 한 가지는 겹쳐 올린 토핑 > 발견/채집 재료(토핑, 향미유, 타레 순) > 첫 토핑 순서로 고른다.
static func _materials(config: Dictionary) -> Array[String]:
	var out: Array[String] = [str(config["broth"]), str(config["noodle"])]
	var toppings: Array = Catalog.canonical_toppings(Catalog.toppings_of(config))
	var third: String = ""
	var best_count: int = 1
	for value in toppings:
		var id: String = str(value)
		if toppings.count(id) > best_count:
			third = id
			best_count = toppings.count(id)
	if third == "":
		var pool: Array[String] = []
		for value in toppings:
			pool.append(str(value))
		pool.append(str(config["oil"]))
		pool.append(str(config["tare"]))
		for id in pool:
			if Catalog.is_discovery(id) or Catalog.is_farmed(id):
				third = id
				break
	if third == "" and not toppings.is_empty():
		third = str(toppings[0])
	if third != "" and out.size() < MAX_MATERIALS:
		out.append(third)
	return out


## 시식 취향 점수가 가장 높은 손님 모두(동점이면 전부, 카탈로그 순서). 점수는 평가기 결과이다.
static func _best_tasters(evaluation: Dictionary) -> Array:
	var rows: Array = evaluation["customers"]
	var top: int = -1
	for row in rows:
		top = maxi(top, int((row as Dictionary)["score"]))
	var out: Array = []
	for row in rows:
		var d: Dictionary = row
		if int(d["score"]) == top:
			out.append({"id": str(d["id"]), "name": str(d["name"]), "score": int(d["score"])})
	return out


## 실제 영업의 주문 출처 id: 단골 카탈로그 순서 뒤에 이름 없는 일반 손님(walkin). 실제 영수증 by_source 의 키는 이 집합뿐이다.
static func _source_ids() -> Array[String]:
	var ids: Array[String] = Customers.ids()
	ids.append(Sim.WALKIN_ID)
	return ids


## 실제 완료 주문이 가장 많은 손님 모두(양수일 때만, 동점이면 단골 카탈로그 순서 뒤 일반 손님). 판매가 없으면 빈 목록.
## 일반 손님은 초상 없이 "일반 손님"으로만 말한다(단골로 꾸미지 않는다).
static func _top_buyers(by_source: Dictionary) -> Array:
	var top: int = 0
	for id in _source_ids():
		top = maxi(top, int(by_source.get(id, 0)))
	var out: Array = []
	if top <= 0:
		return out
	for id in _source_ids():
		if int(by_source.get(id, 0)) == top:
			var customer: Dictionary = Customers.find(id)
			out.append({"id": id, "name": str(customer["name"]) if not customer.is_empty() else "일반 손님", "units": top})
	return out


static func _record_shape_error(record: Dictionary) -> String:
	for key in ["record_id", "version", "name", "config", "scores"]:
		if not record.has(key):
			return "시식 기록이 아니에요. (%s 없음)" % key
	if typeof(record["record_id"]) != TYPE_INT or int(record["record_id"]) <= 0:
		return "시식 기록 번호가 올바르지 않아요."
	if typeof(record["version"]) != TYPE_INT or int(record["version"]) <= 0:
		return "시식 기록 버전이 올바르지 않아요."
	if typeof(record["name"]) != TYPE_STRING or Check.name_error(str(record["name"]), false) != "":
		return "시식 기록 이름이 올바르지 않아요."
	if typeof(record["config"]) != TYPE_DICTIONARY or Check.config_error(record["config"]) != "":
		return "시식 기록의 그릇 구성을 확인해 주세요."
	if typeof(record["scores"]) != TYPE_DICTIONARY:
		return "시식 기록의 점수 구조가 올바르지 않아요."
	return ""


## 저장된 점수가 평가기가 지금 같은 구성에서 내는 점수와 정확히 같아야 한다(손님 수와 id 포함).
static func _scores_error(scores: Dictionary, evaluation: Dictionary) -> String:
	var rows: Array = evaluation["customers"]
	if scores.size() != rows.size():
		return "시식 기록의 점수가 손님과 맞지 않아요."
	for row in rows:
		var d: Dictionary = row
		var id: String = str(d["id"])
		if not scores.has(id) or not Check.is_whole(scores[id]) or int(scores[id]) != int(d["score"]):
			return "시식 기록의 점수가 평가와 맞지 않아요."
	return ""


static func _row_error(row: Dictionary) -> String:
	for key in ["recipe_name", "version", "price", "units", "revenue", "ingredient_cost", "by_source"]:
		if not row.has(key):
			return "영수증 항목이 없어요. (%s)" % key
	if typeof(row["recipe_name"]) != TYPE_STRING:
		return "영수증 메뉴 이름이 올바르지 않아요."
	for key in ["version", "price", "units", "revenue", "ingredient_cost"]:
		if not _count(row[key]):
			return "영수증 숫자가 올바르지 않아요. (%s)" % key
	if row.has("record_id") and not _count(row["record_id"]):
		return "영수증 메뉴 번호가 올바르지 않아요."
	if row.has("wait_total") and not _count(row["wait_total"]):
		return "영수증 대기 시간 합계가 올바르지 않아요."
	if int(row["revenue"]) != int(row["units"]) * int(row["price"]):
		return "영수증 매출이 판매 그릇 수와 맞지 않아요."
	if row.has("margin") and (not Check.is_whole(row["margin"]) or int(row["margin"]) != int(row["revenue"]) - int(row["ingredient_cost"])):
		return "영수증 마진이 매출과 재료비 차이와 맞지 않아요."
	if typeof(row["by_source"]) != TYPE_DICTIONARY:
		return "영수증 손님별 주문 구조가 올바르지 않아요."
	var by_source: Dictionary = row["by_source"]
	var total: int = 0
	for id in by_source:
		if typeof(id) != TYPE_STRING or not _source_ids().has(str(id)) or not _count(by_source[id]):
			return "영수증 손님별 주문이 올바르지 않아요."
		total += int(by_source[id])
	if total != int(row["units"]):
		return "영수증 손님별 주문 합이 판매 그릇 수와 달라요."
	if row.has("config"):
		if typeof(row["config"]) != TYPE_DICTIONARY:
			return "영수증 그릇 구성 구조가 올바르지 않아요."
		var config: Dictionary = row["config"]
		if not config.is_empty():
			if Check.config_error(config) != "":
				return "영수증의 그릇 구성을 확인해 주세요."
			# 실제 영수증은 판매가와 재료비가 구성에서 그대로 나온다. 어긋나면 되살린 정체성을 믿을 수 없다.
			if int(row["price"]) != int(config["price"]):
				return "영수증 판매가가 그릇 구성과 달라요."
			if int(row["ingredient_cost"]) != int(row["units"]) * Evaluator.unit_cost(config):
				return "영수증 재료비가 그릇 구성과 맞지 않아요."
	# 구성을 몰라도 판매가 없으면 재료비와 대기 시간도 0이어야 한다.
	if int(row["units"]) == 0:
		if int(row["ingredient_cost"]) != 0:
			return "판매가 없는 영수증에 재료비가 있어요."
		if row.has("wait_total") and int(row["wait_total"]) != 0:
			return "판매가 없는 영수증에 대기 시간이 있어요."
	return ""


## 0 이상의 정수(JSON 에서 온 정수형 소수 포함). 문자열/불리언/소수/음수는 거부한다.
static func _count(value: Variant) -> bool:
	return Check.is_whole(value) and int(value) >= 0
