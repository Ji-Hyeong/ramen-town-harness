extends RefCounted
## 완성 그릇 비교의 한 줄 결과 요약. 순수 표시 투영이라 상태·저장·경제·평가를 바꾸지 않는다.
## 맛 판정(같음/달라짐)은 두 그릇을 모두 아는 레시피일 때만 내놓는다. 하나라도 모르면
## 점수·궁합·동일 여부를 결과 어디에도(숨은 필드 포함) 싣지 않고, 공개된 원가/준비 차이만 돌려준다.
## 알고 있는지는 호출자가 state.recipe_known으로 따로 구해 넘긴다. 이 비교는 지식을 주지 않는다.
const Catalog=preload("res://scripts/domain/ingredient_catalog.gd")
const DataCheck=preload("res://scripts/domain/data_check.gd")
const Evaluator=preload("res://scripts/domain/recipe_evaluator.gd")
const Customers=preload("res://scripts/domain/customer_catalog.gd")

const TITLE_NEUTRAL: String="담은 뒤 맛 비교"
const TITLE_UNAVAILABLE: String="비교할 수 없어요"
const TITLE_CHANGED: String="맛이 달라졌어요"
const TITLE_SAME_PLAIN: String="맛·원가·준비 그대로"
const TITLE_SAME_BURDEN: String="맛 같고 부담 늘어요"
const TITLE_SAME_SAVING: String="맛 같고 부담 줄어요"
const TITLE_SAME_TRADEOFF: String="맛 같고 원가·시간 교환"
const REASON_SCOPE: String="이 그릇 기준 같은 맛"
const MAX_REASON_AXES: int=3

## 결과 모양(항상 같은 키):
##  error: ""이면 성공, 아니면 사용자용 짧은 문구(평가 세부는 담지 않는다).
##  state: "error" | "neutral"(하나라도 모름) | "same" | "changed".
##  kind: state가 same이면 "plain"|"burden"|"saving"|"tradeoff", 그 밖에는 "".
##  title / reason: 화면용 짧은 문구. reason은 접힌 상세용이며 비어 있을 수 있다.
##  has_economy: 원가·준비 차이를 믿을 수 있으면 true. cost_delta / prep_delta(후보-현재), economy_text.
##  taste: "same" | "changed" | "" — 둘 다 알 때만 채운다.
static func project(before: Dictionary, after: Dictionary, before_known: bool, after_known: bool) -> Dictionary:
	var a: Dictionary=_normalize(before)
	var b: Dictionary=_normalize(after)
	if a.has("error") or b.has("error"):
		return _result("error", "", TITLE_UNAVAILABLE, "", null, null, "")
	var cost: int=int(b["cost"])-int(a["cost"])
	var prep: int=int(b["prep"])-int(a["prep"])
	if not (before_known and after_known):
		return _result("neutral", "", TITLE_NEUTRAL, "", cost, prep, "")
	if not _same_taste(a, b):
		return _result("changed", "", TITLE_CHANGED, _changed_reason(a, b), cost, prep, "changed")
	var kind: String="plain"
	var title: String=TITLE_SAME_PLAIN
	if cost>0 and prep<0 or cost<0 and prep>0:
		kind="tradeoff"
		title=TITLE_SAME_TRADEOFF
	elif cost>0 or prep>0:
		kind="burden"
		title=TITLE_SAME_BURDEN
	elif cost<0 or prep<0:
		kind="saving"
		title=TITLE_SAME_SAVING
	return _result("same", kind, title, REASON_SCOPE, cost, prep, "same")

static func _result(state: String, kind: String, title: String, reason: String, cost: Variant, prep: Variant, taste: String) -> Dictionary:
	var ok: bool=state!="error"
	var has_economy: bool=ok and typeof(cost)==TYPE_INT and typeof(prep)==TYPE_INT
	var economy: String=""
	if has_economy: economy="원가 %s · 준비 %s" % [_signed(int(cost), "원"), _signed(int(prep), "초")]
	return {"error":"" if ok else "두 그릇의 시식 결과를 확인해 주세요.","state":state,"kind":kind,"title":title,"reason":reason,
		"has_economy":has_economy,"cost_delta":int(cost) if has_economy else 0,"prep_delta":int(prep) if has_economy else 0,
		"economy_text":economy,"taste":taste}

static func _signed(value: int, unit: String) -> String:
	return "0%s" % unit if value==0 else "%+d%s" % [value, unit]

## 맛 비교에 쓰는 값만 정수로 뽑은 사본. 잘못된 평가는 {"error":..}만 돌려주며 입력은 읽기만 한다.
static func _normalize(evaluation: Dictionary) -> Dictionary:
	var bad:={"error":"bad"}
	if str(evaluation.get("error", "x"))!="" or typeof(evaluation.get("error"))!=TYPE_STRING: return bad
	var profile_value: Variant=evaluation.get("profile")
	if typeof(profile_value)!=TYPE_DICTIONARY: return bad
	var source: Dictionary=profile_value
	var profile:={}
	for axis in Catalog.AXES:
		# 평가기가 실제로 내놓는 범위(0..PROFILE_MAX) 밖의 값은 불가능한 평가다.
		if not source.has(axis) or not DataCheck.in_range(source[axis], 0, Evaluator.PROFILE_MAX): return bad
		profile[axis]=int(source[axis])
	if source.size()!=Catalog.AXES.size(): return bad
	if not DataCheck.in_range(evaluation.get("compat_total"), -Evaluator.COMPAT_CAP, Evaluator.COMPAT_CAP): return bad
	if not DataCheck.in_range(evaluation.get("unit_cost"), 0, 1000000000): return bad
	if not DataCheck.in_range(evaluation.get("prep_seconds"), 0, 1000000): return bad
	if not DataCheck.in_range(evaluation.get("average_score"), 0, 100): return bad
	var rows_value: Variant=evaluation.get("customers")
	if typeof(rows_value)!=TYPE_ARRAY or (rows_value as Array).is_empty(): return bad
	var scores:={}
	var sum:=0
	for row in rows_value:
		if typeof(row)!=TYPE_DICTIONARY: return bad
		var entry: Dictionary=row
		var id: Variant=entry.get("id")
		if typeof(id)!=TYPE_STRING or str(id)=="" or scores.has(id): return bad
		if not DataCheck.in_range(entry.get("score"), 0, 100): return bad
		scores[id]=int(entry["score"])
		sum+=int(entry["score"])
	# 손님 id 집합은 실제 손님 목록과 정확히 같아야 한다(빠짐/모르는 id/추가 모두 오류).
	var expected: Array[String]=Customers.ids()
	if scores.size()!=expected.size(): return bad
	for expected_id in expected:
		if not scores.has(expected_id): return bad
	# 평균은 손님 점수의 반올림 평균이어야 한다. 어긋난 평가는 믿지 않는다.
	if roundi(float(sum)/float(scores.size()))!=int(evaluation["average_score"]): return bad
	return {"profile":profile,"compat":int(evaluation["compat_total"]),"cost":int(evaluation["unit_cost"]),
		"prep":int(evaluation["prep_seconds"]),"average":int(evaluation["average_score"]),"scores":scores}

## 다섯 축, 궁합 합, 같은 손님 id 집합과 각 점수, 평균이 모두 같아야 같은 맛이다(평균만으로는 안 된다).
## 손님 순서는 딕셔너리 비교라 상관없다. 가격·원가·준비·이름은 맛이 아니다.
static func _same_taste(a: Dictionary, b: Dictionary) -> bool:
	return a["profile"]==b["profile"] and int(a["compat"])==int(b["compat"]) and int(a["average"])==int(b["average"]) and a["scores"]==b["scores"]

## 바뀐 축 이름(좋고 나쁨 없이). 축은 같은데 궁합/손님 반응만 다르면 그렇게 적는다.
static func _changed_reason(a: Dictionary, b: Dictionary) -> String:
	var names: Array[String]=[]
	for axis in Catalog.AXES:
		if int(a["profile"][axis])!=int(b["profile"][axis]): names.append(str(Catalog.AXIS_NAMES[axis]))
	if names.is_empty(): return "손님 반응이 달라요"
	var shown: Array[String]=names.slice(0, MAX_REASON_AXES)
	var text: String=" · ".join(shown)
	return text+(" 외" if names.size()>MAX_REASON_AXES else "")+" 달라짐"
