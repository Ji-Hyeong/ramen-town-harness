extends RefCounted
## 순수 투영 시험. 양성 사례는 실제 Evaluator 결과를 쓰고, 같은 맛의 원가/준비 변형과
## 잘못된 입력은 그 사본을 명시적으로 고쳐 만든다(진짜 비용 차이 상황은 Codex 통합 시험 몫).
const Summary=preload("res://scripts/ui/recipe_change_summary.gd")
const Catalog=preload("res://scripts/domain/ingredient_catalog.gd")
const Evaluator=preload("res://scripts/domain/recipe_evaluator.gd")

static func _real(broth: String="") -> Dictionary:
	var config: Dictionary=Catalog.default_config()
	if broth!="": config["broth"]=broth
	return Evaluator.evaluate(config)

## 실제 평가의 깊은 사본에서 원가/준비만 바꾼 같은 맛 변형.
static func _econ(base: Dictionary, cost: int, prep: int) -> Dictionary:
	var copy: Dictionary=base.duplicate(true)
	copy["unit_cost"]=int(base["unit_cost"])+cost
	copy["prep_seconds"]=int(base["prep_seconds"])+prep
	return copy

## 손님 두 명의 점수를 +1/-1로 옮겨 평균은 그대로 둔 변형.
static func _shifted(base: Dictionary) -> Dictionary:
	var copy: Dictionary=base.duplicate(true)
	var s0: int=int(copy["customers"][0]["score"])
	var s1: int=int(copy["customers"][1]["score"])
	# 0..100 안에서 합이 보존되는 방향을 고른다.
	var step: int=1 if s0<100 and s1>0 else -1
	copy["customers"][0]["score"]=s0+step
	copy["customers"][1]["score"]=s1-step
	return copy

## 합법 범위(0..PROFILE_MAX) 안에서 한 칸만 옮긴 값.
static func _nudge(value: int) -> int:
	return value+1 if value<Evaluator.PROFILE_MAX else value-1

static func _find_other_broth(base: Dictionary) -> Dictionary:
	for item in Catalog.all_items("broth"):
		var other: Dictionary=_real(str(item["id"]))
		if other["error"]=="" and other["profile"]!=base["profile"]: return other
	return {}

func run(check: Callable) -> void:
	var base: Dictionary=_real()
	check.call(base["error"]=="" and base["customers"].size()>=2, "fixture is a valid real evaluation")
	var snapshot: String=JSON.stringify(base)

	# 알고 있는 두 쪽: 같은 맛은 경제 변화로만 갈린다.
	var plain: Dictionary=Summary.project(base, base.duplicate(true), true, true)
	check.call(plain["error"]=="" and plain["state"]=="same" and plain["kind"]=="plain" and plain["taste"]=="same", "identical known bowls read as unchanged")
	check.call(plain["cost_delta"]==0 and plain["prep_delta"]==0 and plain["has_economy"], "unchanged economics are zero deltas")
	var burden: Dictionary=Summary.project(base, _econ(base, 480, 24), true, true)
	check.call(burden["kind"]=="burden" and burden["taste"]=="same" and burden["cost_delta"]==480 and burden["prep_delta"]==24, "same taste with more cost and prep is a burden")
	check.call(burden["economy_text"]=="원가 +480원 · 준비 +24초", "signed actual deltas are shown")
	check.call(Summary.project(base, _econ(base, 480, 0), true, true)["kind"]=="burden", "cost-only increase is a burden")
	check.call(Summary.project(base, _econ(base, 0, 5), true, true)["kind"]=="burden", "prep-only increase is a burden")
	var saving: Dictionary=Summary.project(base, _econ(base, -1, -3), true, true)
	check.call(saving["kind"]=="saving" and saving["cost_delta"]==-1 and saving["prep_delta"]==-3, "same taste with lower cost and prep is a saving")
	check.call(Summary.project(base, _econ(base, -1, 0), true, true)["kind"]=="saving", "cost-only decrease is a saving")
	check.call(Summary.project(base, _econ(base, 10, -2), true, true)["kind"]=="tradeoff", "cost up, time down is a tradeoff")
	check.call(Summary.project(base, _econ(base, -10, 2), true, true)["kind"]=="tradeoff", "cost down, time up is a tradeoff")
	check.call(Summary.project(base, _econ(base, 10, -2), true, true)["title"]!=burden["title"], "tradeoff copy differs from burden")
	for kind_result in [plain, burden, saving]:
		check.call(str(kind_result["title"]).length()<=20, "titles stay short")

	# 달라진 맛: 방향 없는 문구, 평균이 같아도 구분한다.
	var other: Dictionary=_find_other_broth(base)
	check.call(not other.is_empty(), "a genuinely different real broth exists")
	if not other.is_empty():
		var changed: Dictionary=Summary.project(base, other, true, true)
		check.call(changed["state"]=="changed" and changed["taste"]=="changed" and changed["title"]=="맛이 달라졌어요", "different profile reads as changed")
		check.call(changed["reason"]!="" and changed["cost_delta"]==int(other["unit_cost"])-int(base["unit_cost"]), "changed carries actual deltas")
		check.call(str(changed["title"]).find("좋")==-1 and str(changed["title"]).find("나빠")==-1, "changed copy is not a quality verdict")
		var one_axis: Dictionary=base.duplicate(true)
		one_axis["profile"]["rich"]=_nudge(int(one_axis["profile"]["rich"]))
		check.call(Summary.project(base, one_axis, true, true)["state"]=="changed", "one axis change is changed")
	for axis in Catalog.AXES:
		var moved: Dictionary=base.duplicate(true)
		moved["profile"][axis]=_nudge(int(moved["profile"][axis]))
		var r: Dictionary=Summary.project(base, moved, true, true)
		check.call(r["state"]=="changed" and r["reason"].find(str(Catalog.AXIS_NAMES[axis]))!=-1, "axis %s change is detected and named" % axis)
	var compat: Dictionary=base.duplicate(true)
	var compat_now: int=int(compat["compat_total"])
	compat["compat_total"]=compat_now+1 if compat_now<Evaluator.COMPAT_CAP else compat_now-1
	check.call(Summary.project(base, compat, true, true)["state"]=="changed", "compat change alone is changed")
	var shifted: Dictionary=_shifted(base)
	check.call(shifted["average_score"]==base["average_score"], "shifted fixture keeps the same average")
	var per: Dictionary=Summary.project(base, shifted, true, true)
	check.call(per["state"]=="changed" and per["reason"]=="손님 반응이 달라요", "per-customer change is changed even with equal average")
	var avg_only: Dictionary=base.duplicate(true)
	avg_only["average_score"]=clampi(int(avg_only["average_score"])+1, 0, 100)
	check.call(Summary.project(base, avg_only, true, true)["state"]=="error", "average inconsistent with scores is unavailable")
	var shuffled: Dictionary=base.duplicate(true)
	shuffled["customers"].reverse()
	check.call(Summary.project(base, shuffled, true, true)["state"]=="same", "customer order does not matter")
	var missing_one: Dictionary=base.duplicate(true)
	missing_one["customers"].pop_back()
	check.call(Summary.project(base, missing_one, true, true)["state"]=="error", "a missing real customer is unavailable")
	check.call(Summary.project(missing_one, base, true, true)["state"]=="error", "a missing real customer in the current bowl is unavailable")
	check.call(Summary.project(missing_one, missing_one, true, true)["state"]=="error", "identical incomplete sets are still unavailable")
	var renamed: Dictionary=base.duplicate(true)
	renamed["customers"][0]["id"]="someone_else"
	check.call(Summary.project(base, renamed, true, true)["state"]=="error", "an unknown customer id is unavailable")
	check.call(Summary.project(renamed, renamed, true, true)["state"]=="error", "identical unknown ids are still unavailable")
	var extra: Dictionary=base.duplicate(true)
	extra["customers"].append({"id":"someone_else","score":50})
	check.call(Summary.project(base, extra, true, true)["state"]=="error", "an extra customer is unavailable")
	check.call(Summary.project(base, extra, false, false)["state"]=="error", "bad customer sets are errors for unknown bowls too")
	var float_ok: Dictionary=base.duplicate(true)
	float_ok["unit_cost"]=float(base["unit_cost"])
	check.call(Summary.project(base, float_ok, true, true)["state"]=="same", "whole floats from JSON are accepted")

	# 모름: 중립 문구와 공개 경제 차이만. 맛 정보는 어디에도 없다.
	var leak_pairs: Array=[[false, false], [true, false], [false, true]]
	var variants: Array=[base.duplicate(true), _econ(base, 480, 24), shifted, other if not other.is_empty() else base.duplicate(true)]
	var seen: Dictionary={}
	for pair in leak_pairs:
		for variant in variants:
			var n: Dictionary=Summary.project(base, variant, pair[0], pair[1])
			check.call(n["state"]=="neutral" and n["title"]=="담은 뒤 맛 비교" and n["taste"]=="" and n["kind"]=="" and n["reason"]=="", "unknown pair %s is neutral" % str(pair))
			check.call(n["cost_delta"]==int(variant["unit_cost"])-int(base["unit_cost"]) and n["has_economy"], "unknown keeps public economy deltas")
			seen[JSON.stringify(n)]=true
			var cost_only: Dictionary=Summary.project(base, _econ(variant, 0, 0), pair[0], pair[1])
			check.call(JSON.stringify(cost_only)==JSON.stringify(n), "unknown output is independent of taste data")
	# 같은 경제 차이를 가진 같은 맛/다른 맛은 모르는 상태에서 서로 구분되지 않아야 한다.
	var same_econ: Dictionary=Summary.project(base, _econ(base, 5, 1), false, true)
	var diff_taste: Dictionary=_econ(shifted, 5, 1)
	check.call(JSON.stringify(same_econ)==JSON.stringify(Summary.project(base, diff_taste, true, false)), "unknown cannot distinguish same from changed taste")
	var blob: String=JSON.stringify(Summary.project(base, shifted, false, false))
	for word in ["score", "compat", "profile", "same", "changed", "average", "customer", "같은 맛"]:
		check.call(blob.find(word)==-1, "unknown result has no '%s' leak" % word)

	# 잘못된 입력: 항상 명시적 오류이고 성공 분류가 아니다. 내용은 새지 않는다.
	var broken: Array=[]
	broken.append({})
	broken.append({"error":"bad config"})
	var d: Dictionary
	d=base.duplicate(true); d.erase("profile"); broken.append(d)
	d=base.duplicate(true); d["profile"].erase("spice"); broken.append(d)
	d=base.duplicate(true); d["profile"]["extra"]=1; broken.append(d)
	d=base.duplicate(true); d["profile"]["rich"]=true; broken.append(d)
	d=base.duplicate(true); d["profile"]["rich"]=1.5; broken.append(d)
	d=base.duplicate(true); d["profile"]["rich"]=-1; broken.append(d)
	d=base.duplicate(true); d["profile"]["spice"]=Evaluator.PROFILE_MAX+1; broken.append(d)
	d=base.duplicate(true); d["compat_total"]=Evaluator.COMPAT_CAP+1; broken.append(d)
	d=base.duplicate(true); d["compat_total"]=-Evaluator.COMPAT_CAP-1; broken.append(d)
	d=base.duplicate(true); d["customers"].pop_back(); broken.append(d)
	d=base.duplicate(true); d["customers"][0]["id"]="someone_else"; broken.append(d)
	d=base.duplicate(true); d["customers"].append({"id":"someone_else","score":50}); broken.append(d)
	d=base.duplicate(true); d["profile"]["rich"]="3"; broken.append(d)
	d=base.duplicate(true); d["compat_total"]=true; broken.append(d)
	d=base.duplicate(true); d["compat_total"]=0.5; broken.append(d)
	d=base.duplicate(true); d["unit_cost"]=-1; broken.append(d)
	d=base.duplicate(true); d["unit_cost"]=true; broken.append(d)
	d=base.duplicate(true); d["unit_cost"]=12.5; broken.append(d)
	d=base.duplicate(true); d["unit_cost"]=INF; broken.append(d)
	d=base.duplicate(true); d["unit_cost"]=NAN; broken.append(d)
	d=base.duplicate(true); d.erase("unit_cost"); broken.append(d)
	d=base.duplicate(true); d["prep_seconds"]=-5; broken.append(d)
	d=base.duplicate(true); d["prep_seconds"]=false; broken.append(d)
	d=base.duplicate(true); d.erase("prep_seconds"); broken.append(d)
	d=base.duplicate(true); d["average_score"]=101; broken.append(d)
	d=base.duplicate(true); d["average_score"]=true; broken.append(d)
	d=base.duplicate(true); d.erase("average_score"); broken.append(d)
	d=base.duplicate(true); d["customers"]=[]; broken.append(d)
	d=base.duplicate(true); d["customers"]="none"; broken.append(d)
	d=base.duplicate(true); d.erase("customers"); broken.append(d)
	d=base.duplicate(true); d["customers"][1]["id"]=d["customers"][0]["id"]; broken.append(d)
	d=base.duplicate(true); d["customers"][0].erase("id"); broken.append(d)
	d=base.duplicate(true); d["customers"][0]["id"]=""; broken.append(d)
	d=base.duplicate(true); d["customers"][0]["score"]=true; broken.append(d)
	d=base.duplicate(true); d["customers"][0]["score"]=50.5; broken.append(d)
	d=base.duplicate(true); d["customers"][0]["score"]=-1; broken.append(d)
	d=base.duplicate(true); d["customers"][0]["score"]=101; broken.append(d)
	d=base.duplicate(true); d["customers"][0].erase("score"); broken.append(d)
	d=base.duplicate(true); d["customers"][0]=5; broken.append(d)
	for item in broken:
		# JSON은 NaN/INF를 null로 바꿔 변형을 놓칠 수 있어 비유한 값도 구분하는 var_to_str로 스냅샷한다.
		var before_snapshot: String=var_to_str(item)
		for flags in [[true, true], [false, false], [true, false]]:
			var bad_after: Dictionary=Summary.project(base, item, flags[0], flags[1])
			var bad_before: Dictionary=Summary.project(item, base, flags[0], flags[1])
			check.call(bad_after["state"]=="error" and bad_after["error"]!="" and bad_after["taste"]=="" and bad_after["title"]=="비교할 수 없어요", "malformed candidate is an explicit error")
			check.call(bad_before["state"]=="error" and not bad_before["has_economy"], "malformed current is an explicit error")
		check.call(var_to_str(item)==before_snapshot, "malformed input is not mutated")
	check.call(Summary.project({}, {}, true, true)["state"]=="error", "empty inputs are an error")

	# 읽기 전용, 깊은 사본 출력.
	check.call(JSON.stringify(base)==snapshot, "inputs are never mutated")
	var result: Dictionary=Summary.project(base, shifted, true, true)
	result["title"]="changed by caller"
	result["reason"]="x"
	check.call(Summary.project(base, shifted, true, true)["title"]=="맛이 달라졌어요", "results are fresh each call")
	check.call(JSON.stringify(base)==snapshot, "result edits cannot reach inputs")
