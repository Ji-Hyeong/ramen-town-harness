extends RefCounted
## 직원 한 명의 육성 규칙(순수 계산). 직원 id/고용/자금 차감/저장/시계는 호출자(GameState)의 책임이다.
## 경험은 실제로 완료된 영업 그릇만 쌓이고, 훈련은 경험을 소비하지 않는다(선택은 영구, 환불 없음).
## 효과: 할인(percent_discount)은 기본 80%(조리)/70%(홀)에서 빼고, wage_delta는 기본 운영비 600/500에 더한다.
## entry = {bowls, work_days, last_work_day, lessons:[{day, rank, bowls, work_days, style}]}

const Check = preload("res://scripts/domain/data_check.gd")

const MAX_DAY: int = 99999
const MAX_DAILY_BOWLS: int = 2400
const MAX_BOWLS: int = 239995200  # 99998 * 2400
const MAX_LEVEL: int = 2
const CTX: String = "직원 육성"
const ENTRY_KEYS: Array = ["bowls", "work_days", "last_work_day", "lessons"]
const RECEIPT_KEYS: Array = ["day", "rank", "bowls", "work_days", "style"]
## 다음 단계(인덱스 0 = 1단계로 가는 훈련) 조건/비용.
const NEED_BOWLS: Array = [40, 160]
const NEED_DAYS: Array = [2, 5]
const NEED_RANK: Array = [2, 3]
const COST: Array = [4000, 12000]
const STAGE_STYLES: Array = [["basic"], ["speed", "economy"]]
const EFFECTS: Dictionary = {
	"0:": [0, 0, "입문"],
	"1:basic": [10, 150, "숙련"],
	"2:speed": [25, 400, "속도 전문"],
	"2:economy": [15, -100, "절약 전문"],
}


static func empty() -> Dictionary:
	return {"bowls": 0, "work_days": 0, "last_work_day": 0, "lessons": []}


static func level(entry: Dictionary) -> int:
	return entry["lessons"].size()


static func effect(lv: int, style: String) -> Dictionary:
	var key: String = "%d:%s" % [lv, style]
	if not EFFECTS.has(key):
		return {"error": "알 수 없는 육성 단계/방식이에요 (%s)." % key}
	var e: Array = EFFECTS[key]
	return {"percent_discount": e[0], "wage_delta": e[1], "title": e[2]}


## 완료된 영업 하루의 그릇 수를 더한다. 0그릇이면 경험 변화 없음(영업 일수도 늘지 않는다).
static func accrue(entry: Dictionary, day: int, units: int) -> Dictionary:
	var err: String = _entry_error(entry)
	if err == "":
		if day < 1 or day > MAX_DAY - 1:
			err = "영업 날짜가 올바르지 않아요."
		elif units < 0 or units > MAX_DAILY_BOWLS:
			err = "하루 그릇 수가 올바르지 않아요."
		elif day <= entry["last_work_day"]:
			err = "이미 경험을 정산한 날이에요."
		elif units > 0 and (entry["bowls"] + units > MAX_BOWLS or entry["work_days"] + 1 > MAX_DAY - 1):
			err = "경험 한도를 넘어요."
	if err != "":
		return {"error": err, "state": {}}
	var s: Dictionary = _clone(entry)
	if units > 0:
		s["bowls"] += units
		s["work_days"] += 1
		s["last_work_day"] = day
	return {"error": "", "state": s}


## 훈련 가능 여부를 조회한다(상태 불변). 잘못된 입력은 error, 조건 부족은 error=""+eligible=false.
static func review(entry: Dictionary, rank: int, wallet: int, day: int, style: String) -> Dictionary:
	var out: Dictionary = {"error": "", "eligible": false, "reason": "", "next_level": 0, "style": style,
		"cost": 0, "min_bowls": 0, "min_work_days": 0, "min_rank": 0, "effect": {}}
	var err: String = _entry_error(entry)
	if err == "":
		if not ["basic", "speed", "economy"].has(style):
			err = "알 수 없는 육성 방식이에요."
		elif rank < 1 or rank > 3 or wallet < 0 or wallet > 1000000000 or day < 1 or day > MAX_DAY:
			err = "등급/자금/날짜 값이 올바르지 않아요."
	if err != "":
		out["error"] = err
		return out
	var lv: int = level(entry)
	if lv >= MAX_LEVEL:
		out["next_level"] = lv
		out["reason"] = "이미 최고 단계예요."
		out["effect"] = effect(lv, entry["lessons"][lv - 1]["style"])
		return out
	out["next_level"] = lv + 1
	out["cost"] = COST[lv]
	out["min_bowls"] = NEED_BOWLS[lv]
	out["min_work_days"] = NEED_DAYS[lv]
	out["min_rank"] = NEED_RANK[lv]
	var why: PackedStringArray = []
	if STAGE_STYLES[lv].has(style):
		out["effect"] = effect(lv + 1, style)
	else:
		why.append("이 단계에서는 고를 수 없는 방식이에요.")
	if entry["bowls"] < NEED_BOWLS[lv]:
		why.append("경험 그릇이 %d개 필요해요 (현재 %d)." % [NEED_BOWLS[lv], entry["bowls"]])
	if entry["work_days"] < NEED_DAYS[lv]:
		why.append("실무 %d일이 필요해요 (현재 %d)." % [NEED_DAYS[lv], entry["work_days"]])
	if rank < NEED_RANK[lv]:
		why.append("가게 등급 %d 이상이 필요해요." % NEED_RANK[lv])
	if wallet < COST[lv]:
		why.append("훈련비 %d원이 필요해요." % COST[lv])
	if lv > 0 and entry["lessons"][lv - 1]["day"] >= day:
		why.append("같은 직원은 하루에 한 번만 훈련해요.")
	if entry["last_work_day"] >= day:
		why.append("영업을 마친 날에는 훈련할 수 없어요.")
	out["reason"] = "; ".join(why)
	out["eligible"] = why.is_empty()
	return out


## review가 가능하다고 한 경우에만 영수증을 더한 새 상태를 돌려준다. 자금 차감은 호출자가 cost로 처리한다.
static func train(entry: Dictionary, rank: int, wallet: int, day: int, style: String) -> Dictionary:
	var r: Dictionary = review(entry, rank, wallet, day, style)
	var err: String = r["error"]
	if err == "" and not r["eligible"]:
		err = r["reason"]
	if err != "":
		return {"error": err, "state": {}, "cost": 0, "receipt": {}}
	var s: Dictionary = _clone(entry)
	var receipt: Dictionary = {"day": day, "rank": rank, "bowls": s["bowls"], "work_days": s["work_days"], "style": style}
	s["lessons"].append(receipt.duplicate())
	return {"error": "", "state": s, "cost": r["cost"], "receipt": receipt}


## 외부(저장 파일 등)에서 온 값을 정규화(float→int)하고 모순을 거부한다.
## 고용일은 저장하지 않으므로 이 검사는 내부 일관성만 보며 위변조를 암호학적으로 증명하지 않는다.
static func parse(raw: Variant, current_day: int, current_rank: int) -> Dictionary:
	if current_day < 1 or current_day > MAX_DAY or current_rank < 1 or current_rank > 3:
		return _fail("현재 날짜/등급이 올바르지 않아요.")
	if typeof(raw) != TYPE_DICTIONARY:
		return _fail("구조가 올바르지 않아요.")
	var d: Dictionary = raw
	var err: String = Check.keys_error(d, ENTRY_KEYS, CTX)
	if err != "":
		return _fail(err)
	for k in ["bowls", "work_days", "last_work_day"]:
		if not Check.is_whole(d[k]):
			return _fail("%s 값이 정수가 아니에요." % k)
	var cur: Dictionary = {"bowls": int(d["bowls"]), "work_days": int(d["work_days"]), "last_work_day": int(d["last_work_day"]), "lessons": []}
	var wd: int = cur["work_days"]
	var last: int = cur["last_work_day"]
	var bowls: int = cur["bowls"]
	if wd < 0 or wd > current_day - 1 or last < 0 or last > current_day - 1 or bowls < 0 or bowls > wd * MAX_DAILY_BOWLS:
		return _fail("경험 값이 범위를 벗어나요.")
	if wd == 0 and (bowls != 0 or last != 0):
		return _fail("실무 0일인데 경험이 남아 있어요.")
	if wd > 0 and (bowls < wd or last < wd):
		return _fail("실무 일수와 그릇/마지막 영업일이 맞지 않아요.")
	if typeof(d["lessons"]) != TYPE_ARRAY or d["lessons"].size() > MAX_LEVEL:
		return _fail("훈련 기록 구조가 올바르지 않아요.")
	for i in d["lessons"].size():
		var res: Dictionary = _parse_receipt(d["lessons"][i], i, cur, current_day, current_rank)
		if res["error"] != "":
			return _fail(res["error"])
		cur["lessons"].append(res["receipt"])
	return {"error": "", "state": cur}


static func _parse_receipt(raw: Variant, i: int, cur: Dictionary, current_day: int, current_rank: int) -> Dictionary:
	var ctx: String = "%s 훈련 기록 %d" % [CTX, i + 1]
	if typeof(raw) != TYPE_DICTIONARY:
		return {"error": ctx + ": 구조가 올바르지 않아요."}
	var r: Dictionary = raw
	var err: String = Check.keys_error(r, RECEIPT_KEYS, ctx)
	if err != "":
		return {"error": err}
	for k in ["day", "rank", "bowls", "work_days"]:
		if not Check.is_whole(r[k]):
			return {"error": "%s: %s 값이 정수가 아니에요." % [ctx, k]}
	if typeof(r["style"]) != TYPE_STRING or not STAGE_STYLES[i].has(r["style"]):
		return {"error": ctx + ": 방식이 단계와 맞지 않아요."}
	var rc: Dictionary = {"day": int(r["day"]), "rank": int(r["rank"]), "bowls": int(r["bowls"]), "work_days": int(r["work_days"]), "style": str(r["style"])}
	var b: int = rc["bowls"]
	var w: int = rc["work_days"]
	var bad: bool = rc["day"] > current_day or rc["rank"] < NEED_RANK[i] or rc["rank"] > current_rank
	bad = bad or b < NEED_BOWLS[i] or w < NEED_DAYS[i] or rc["day"] < w + 1
	bad = bad or w > cur["work_days"] or b > cur["bowls"] or b < w or b > w * MAX_DAILY_BOWLS
	if cur["last_work_day"] < rc["day"]:
		bad = bad or b != cur["bowls"] or w != cur["work_days"]  # 훈련 뒤 영업이 없으면 경험이 같아야 한다.
	else:
		bad = bad or w >= cur["work_days"] or b >= cur["bowls"]  # 훈련 뒤 영업했다면 경험이 늘어야 한다.
		# 하루 한 번만 정산되므로 훈련 뒤 남은 날짜보다 많은 실무를 끼워 넣을 수 없다.
		var available_days: int = int(cur["last_work_day"]) - int(rc["day"]) + 1
		bad = bad or int(cur["work_days"]) - w > available_days or int(cur["bowls"]) - b > available_days * MAX_DAILY_BOWLS
	if i > 0:
		var p: Dictionary = cur["lessons"][i - 1]
		# 판매0으로 마감한 날은 일차만 늘고 경험은 그대로다. 훈련을 미뤘다면 같은 경험으로 다음 날 전문화할 수 있다.
		bad = bad or rc["day"] <= p["day"] or rc["rank"] < p["rank"] or w < p["work_days"] or b < p["bowls"]
		bad = bad or w - int(p["work_days"]) > int(rc["day"]) - int(p["day"]) or b - int(p["bowls"]) > (int(rc["day"]) - int(p["day"])) * MAX_DAILY_BOWLS
	if bad:
		return {"error": ctx + ": 값이 서로 맞지 않아요."}
	return {"error": "", "receipt": rc}


static func _fail(msg: String) -> Dictionary:
	return {"error": CTX + ": " + msg, "state": {}}


## 내부 정상 entry의 모양 검사(parse보다 엄격하지 않음: 정수 타입과 키만 본다).
static func _entry_error(e: Dictionary) -> String:
	var err: String = Check.keys_error(e, ENTRY_KEYS, CTX)
	if err != "":
		return err
	for k in ["bowls", "work_days", "last_work_day"]:
		if typeof(e[k]) != TYPE_INT or e[k] < 0:
			return "%s: %s 값이 올바르지 않아요." % [CTX, k]
	if typeof(e["lessons"]) != TYPE_ARRAY or e["lessons"].size() > MAX_LEVEL:
		return CTX + ": 훈련 기록 구조가 올바르지 않아요."
	for r in e["lessons"]:
		if typeof(r) != TYPE_DICTIONARY:
			return CTX + ": 훈련 기록 구조가 올바르지 않아요."
		err = Check.keys_error(r, RECEIPT_KEYS, CTX)
		if err != "":
			return err
		for k in ["day", "rank", "bowls", "work_days"]:
			if typeof(r[k]) != TYPE_INT:
				return "%s: 훈련 기록 %s 값이 올바르지 않아요." % [CTX, k]
		if typeof(r["style"]) != TYPE_STRING:
			return CTX + ": 훈련 기록 방식이 올바르지 않아요."
	return ""


static func _clone(e: Dictionary) -> Dictionary:
	var lessons: Array = []
	for r in e["lessons"]:
		lessons.append({"day": int(r["day"]), "rank": int(r["rank"]), "bowls": int(r["bowls"]), "work_days": int(r["work_days"]), "style": str(r["style"])})
	return {"bowls": int(e["bowls"]), "work_days": int(e["work_days"]), "last_work_day": int(e["last_work_day"]), "lessons": lessons}
