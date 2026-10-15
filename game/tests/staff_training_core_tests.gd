extends SceneTree
## 직원 육성 순수 규칙 시험. 기대값은 계약서의 숫자를 손으로 적은 것이다. 파일 저장 없음.

const ST = preload("res://scripts/domain/staff_training.gd")

var checks: int = 0
var failures: int = 0


func ok(cond: bool, label: String) -> void:
	checks += 1
	if not cond:
		failures += 1
		print("FAIL: ", label)


func E(b: int, w: int, l: int, lessons: Array = []) -> Dictionary:
	return {"bowls": b, "work_days": w, "last_work_day": l, "lessons": lessons}


func R(day: int, rank: int, b: int, w: int, style: String) -> Dictionary:
	return {"day": day, "rank": rank, "bowls": b, "work_days": w, "style": style}


func with(base: Dictionary, key: String, val: Variant) -> Dictionary:
	var d: Dictionary = base.duplicate(true)
	d[key] = val
	return d


func with_r(base: Dictionary, idx: int, key: String, val: Variant) -> Dictionary:
	var d: Dictionary = base.duplicate(true)
	d["lessons"][idx][key] = val
	return d


func rev(e: Dictionary, rank: int, wallet: int, day: int, style: String) -> Dictionary:
	return ST.review(e, rank, wallet, day, style)


func eligible(e: Dictionary, rank: int, wallet: int, day: int, style: String) -> bool:
	var r: Dictionary = rev(e, rank, wallet, day, style)
	return r["error"] == "" and r["eligible"]


func bad(raw: Variant, day: int, rank: int, label: String) -> void:
	var r: Dictionary = ST.parse(raw, day, rank)
	ok(r["error"] != "" and r["state"].is_empty(), "parse 거부: " + label)


func _init() -> void:
	# 기본값과 효과 표
	ok(str(ST.empty()) == str(E(0, 0, 0)) and ST.level(ST.empty()) == 0, "empty/level")
	var fx: Array = [[0, "", 0, 0, "입문"], [1, "basic", 10, 150, "숙련"], [2, "speed", 25, 400, "속도 전문"], [2, "economy", 15, -100, "절약 전문"]]
	for f in fx:
		var e: Dictionary = ST.effect(f[0], f[1])
		ok(e["percent_discount"] == f[2] and e["wage_delta"] == f[3] and e["title"] == f[4], "효과 %s" % f[4])
	for f in [[1, "speed"], [0, "basic"], [3, ""], [2, "basic"], [-1, ""]]:
		ok(ST.effect(f[0], f[1])["error"] != "", "효과 오류 %s" % str(f))
	# accrue: 정산, 0그릇, 중복일, 범위, 한도, 사본
	var a: Dictionary = E(10, 1, 1)
	var r: Dictionary = ST.accrue(a, 3, 20)
	ok(r["error"] == "" and str(r["state"]) == str(E(30, 2, 3)) and str(a) == str(E(10, 1, 1)), "accrue 정산/원본 불변")
	r["state"]["bowls"] = 0
	ok(a["bowls"] == 10, "accrue 사본")
	ok(str(ST.accrue(a, 5, 0)["state"]) == str(a), "0그릇은 경험 변화 없음")
	for c in [[1, 5], [0, 5], [99999, 5], [3, 2401], [3, -1]]:
		ok(ST.accrue(a, c[0], c[1])["error"] != "", "accrue 거부 %s" % str(c))
	ok(ST.accrue(a, 99998, 2400)["error"] == "" and ST.accrue(E(0, 0, 0), 1, 2400)["state"]["bowls"] == 2400, "accrue 경계 허용")
	ok(ST.accrue(E(239995200, 99997, 99997), 99998, 1)["error"] != "", "그릇 한도")
	ok(ST.accrue(E(99998, 99998, 5), 6, 1)["error"] != "", "실무일 한도")
	# review 경계
	ok(eligible(E(40, 2, 1), 2, 4000, 2, "basic"), "1단계 경계 허용")
	ok(not eligible(E(39, 2, 1), 2, 4000, 2, "basic"), "그릇 39")
	ok(not eligible(E(40, 1, 1), 2, 4000, 2, "basic"), "실무 1일")
	ok(not eligible(E(40, 2, 1), 1, 4000, 2, "basic"), "등급 1")
	ok(not eligible(E(40, 2, 1), 2, 3999, 2, "basic"), "자금 3999")
	ok(not eligible(E(40, 2, 2), 2, 4000, 2, "basic"), "영업한 날")
	ok(eligible(E(40, 2, 2), 2, 4000, 3, "basic"), "다음 날 허용")
	var rv: Dictionary = rev(E(0, 0, 0), 1, 0, 1, "basic")
	ok(rv["error"] == "" and not rv["eligible"] and rv["cost"] == 4000 and rv["min_bowls"] == 40 and rv["min_work_days"] == 2 and rv["min_rank"] == 2 and rv["next_level"] == 1 and rv["reason"] != "", "1단계 요구 조건 보고")
	ok(not eligible(E(40, 2, 1), 2, 4000, 2, "speed") and rev(E(40, 2, 1), 2, 4000, 2, "speed")["error"] == "", "1단계에서 speed 불가")
	var base: Dictionary = E(40, 2, 1)
	ok(rev(base, 2, 4000, 2, "gold")["error"] != "" and rev(base, 0, 4000, 2, "basic")["error"] != "", "알 수 없는 방식/등급 오류")
	ok(rev(base, 2, -1, 2, "basic")["error"] != "" and rev(base, 2, 4000, 0, "basic")["error"] != "", "자금/날짜 오류")
	ok(rev(with(base, "bowls", 40.0), 2, 4000, 2, "basic")["error"] != "" and str(base) == str(E(40, 2, 1)), "entry 타입 오류/조회 불변")
	# 실제 흐름: 2일 40그릇 → 훈련1 → 3일 120그릇 → 두 전문 분기
	var s: Dictionary = E(0, 0, 0)
	s = ST.accrue(ST.accrue(s, 1, 20)["state"], 2, 20)["state"]
	ok(str(s) == str(E(40, 2, 2)), "2일 40그릇")
	var t: Dictionary = ST.train(s, 2, 5000, 3, "basic")
	ok(t["error"] == "" and t["cost"] == 4000 and str(t["receipt"]) == str(R(3, 2, 40, 2, "basic")), "훈련1 영수증/비용")
	s = t["state"]
	ok(ST.level(s) == 1 and s["bowls"] == 40 and str(ST.accrue(s, 4, 0)["state"]) == str(s), "경험 비소비")
	ok(ST.train(s, 3, 99999, 3, "speed")["error"] != "" and ST.train(s, 3, 99999, 3, "basic")["error"] != "", "같은 날/잘못된 방식 훈련 거부")
	for d in [4, 5, 6]:
		s = ST.accrue(s, d, 40)["state"]
	ok(str(s["lessons"]) == str([R(3, 2, 40, 2, "basic")]) and s["bowls"] == 160 and s["work_days"] == 5 and s["last_work_day"] == 6, "3일 120그릇")
	var before: String = str(s)
	var lesson1: Array = [R(3, 2, 40, 2, "basic")]
	ok(not eligible(E(159, 5, 6, lesson1), 3, 12000, 7, "speed") and not eligible(E(160, 4, 6, lesson1), 3, 12000, 7, "speed"), "2단계 그릇/실무 경계")
	ok(not eligible(s, 3, 12000, 6, "speed"), "영업한 날 거부")
	ok(not eligible(s, 2, 12000, 7, "speed") and not eligible(s, 3, 11999, 7, "economy") and not eligible(s, 3, 12000, 7, "basic"), "2단계 등급/자금/방식 거부")
	ok(ST.train(s, 2, 12000, 7, "speed")["error"] != "" and str(s) == before, "거부는 원본을 바꾸지 않음")
	var sp: Dictionary = ST.train(s, 3, 12000, 7, "speed")
	var ec: Dictionary = ST.train(s, 3, 20000, 7, "economy")
	ok(sp["cost"] == 12000 and str(sp["receipt"]) == str(R(7, 3, 160, 5, "speed")) and ec["state"]["lessons"][1]["style"] == "economy" and str(s) == before, "두 전문 분기")
	ok(ST.level(sp["state"]) == 2 and rev(sp["state"], 3, 99999, 9, "economy")["eligible"] == false and ST.train(ec["state"], 3, 99999, 9, "speed")["error"] != "", "레벨2 최대")
	# JSON roundtrip + float 정수 허용
	var full: Dictionary = sp["state"]
	var back: Variant = JSON.parse_string(JSON.stringify(full))
	var p: Dictionary = ST.parse(back, 9, 3)
	ok(p["error"] == "" and str(p["state"]) == str(full) and typeof(p["state"]["bowls"]) == TYPE_INT and typeof(p["state"]["lessons"][1]["day"]) == TYPE_INT, "JSON 왕복/int 정규화")
	ok(ST.parse(ST.empty(), 1, 1)["error"] == "" and ST.parse(E(80, 3, 4, [R(3, 2, 40, 2, "basic")]), 5, 2)["error"] == "", "빈 상태/영업 이어진 기록")
	ok(ST.parse(E(40, 2, 2, [R(3, 2, 40, 2, "basic")]), 3, 2)["error"] == "", "훈련 뒤 영업 없음")
	# 잘못된 입력
	for raw in [null, [], "x", 5, true]:
		bad(raw, 9, 3, "비정형 %s" % str(raw))
	bad(full, 0, 3, "현재 날짜 0")
	bad(full, 9, 0, "현재 등급 0")
	bad(full, 9, 2, "등급이 현재보다 높음")
	bad(full, 6, 3, "현재 날짜가 마지막 영업일보다 이름")
	var extra: Dictionary = full.duplicate(true)
	extra["x"] = 1
	bad(extra, 9, 3, "미지의 키")
	var missing: Dictionary = full.duplicate(true)
	missing.erase("last_work_day")
	bad(missing, 9, 3, "키 누락")
	for c in [["bowls", true], ["bowls", 160.5], ["bowls", "160"], ["bowls", -1], ["bowls", 12001], ["bowls", 100], ["work_days", 8], ["work_days", 0],
			["work_days", 4.5], ["last_work_day", 9], ["last_work_day", 4], ["lessons", "x"], ["lessons", [full["lessons"][0], full["lessons"][1], full["lessons"][1]]]]:
		bad(with(full, c[0], c[1]), 9, 3, "상위 %s=%s" % [c[0], str(c[1])])
	bad(E(1, 0, 0), 9, 3, "실무 0일에 그릇")
	bad(E(0, 0, 1), 9, 3, "실무 0일에 마지막 영업일")
	var ex_r: Dictionary = full.duplicate(true)
	ex_r["lessons"][0]["z"] = 1
	bad(ex_r, 9, 3, "영수증 미지의 키")
	for c in [[0, "style", "speed"], [1, "style", "basic"], [1, "style", "fast"], [1, "style", 5], [0, "rank", 1], [1, "rank", 2], [0, "day", true],
			[1, "day", 3], [0, "day", 10], [0, "bowls", 39], [0, "work_days", 1], [0, "day", 2], [0, "bowls", 40.5], [1, "bowls", 159], [1, "work_days", 6]]:
		bad(with_r(full, c[0], c[1], c[2]), 9, 3, "영수증%d %s=%s" % [c[0], c[1], str(c[2])])
	var same: Dictionary = with_r(with_r(full, 0, "bowls", 160), 0, "work_days", 5)
	bad(same, 9, 3, "두 영수증 경험 증가 없음")
	bad(E(40, 2, 3, [R(3, 2, 40, 2, "basic")]), 4, 2, "영업 이어졌는데 영수증 경험이 현재와 같음")
	bad(E(41, 2, 2, [R(3, 2, 40, 2, "basic")]), 4, 2, "훈련 뒤 영업 없는데 경험이 다름")
	bad(full, 9, 4, "존재하지 않는 가게 등급")
	ok(rev(base, 4, 4000, 2, "basic")["error"] != "", "훈련 조회도 등급 상한 확인")
	bad(E(80, 5, 4, [R(4, 2, 40, 2, "basic")]), 5, 2, "훈련 뒤 하루에 실무3일 끼워 넣기")
	ok(ST.parse(E(160, 5, 5, [R(6, 3, 160, 5, "basic"), R(7, 3, 160, 5, "speed")]), 7, 3)["error"] == "", "판매0 영업 뒤 같은 경험의 두 훈련 허용")
	print("checks=%d failures=%d" % [checks, failures])
	quit(0 if checks > 0 and failures == 0 else 1)
