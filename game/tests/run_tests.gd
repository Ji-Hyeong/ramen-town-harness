extends SceneTree
## 헤드리스 테스트. 실패하면 종료 코드 1, 인자 오류는 2로 종료한다(assert에 의존하지 않음).
## 실행: Godot --headless --path game --script res://tests/run_tests.gd -- --test-data-dir=<쓰기 가능한 절대 경로>
## 저장 관련 테스트는 이 폴더 아래의 하위 폴더에서만 고정 이름 파일을 만들고 지운다. user:// 는 쓰지 않는다.

const Catalog = preload("res://scripts/domain/ingredient_catalog.gd")
const Customers = preload("res://scripts/domain/customer_catalog.gd")
const Check = preload("res://scripts/domain/data_check.gd")
const Evaluator = preload("res://scripts/domain/recipe_evaluator.gd")
const Sim = preload("res://scripts/domain/sales_simulator.gd")
const GameStateScript = preload("res://scripts/domain/game_state.gd")
const SaveServiceScript = preload("res://scripts/services/save_service.gd")
const LocationScript = preload("res://scripts/services/data_location.gd")

const ARG: String = "--test-data-dir="

var _failures: Array[String] = []
var _checks: int = 0
var _finished: bool = false
var _base_dir: String = ""


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	args.append_array(OS.get_cmdline_args())
	for a in args:
		if a.begins_with(ARG):
			_base_dir = a.substr(ARG.length())
	var absolute: bool = _base_dir.begins_with("/") or (_base_dir.length() > 2 and _base_dir[1] == ":")
	if _base_dir == "" or not absolute or _base_dir.begins_with("user://") or _base_dir.begins_with("res://"):
		printerr("FAIL: --test-data-dir=<절대 경로> 가 필요해요.")
		quit(2)
		return
	if not DirAccess.dir_exists_absolute(_base_dir):
		var mk: int = DirAccess.make_dir_recursive_absolute(_base_dir)
		if mk != OK:
			printerr("FAIL: 테스트 폴더를 만들 수 없어요: " + error_string(mk))
			quit(2)
			return

	var tests: Array[Callable] = [
		test_catalog_shape, test_customers_distinct, test_evaluation_deterministic,
		test_preferences_differ, test_no_universal_best, test_score_distribution, test_compatibility_matters,
		test_feedback_is_causal, test_price_affects_sales, test_prep_time_limits_sales,
		test_sales_input_validation, test_revision_and_immutability, test_duplicate_and_bounds,
		test_wallet_and_serve, test_invalid_inputs, test_save_roundtrip,
		test_missing_corrupt_future_saves, test_malformed_state_rejected, test_backup_strategy,
		test_data_location,
	]
	var ran: int = 0
	for t in tests:
		_finished = false
		var before: int = _failures.size()
		t.call()
		ran += 1
		if not _finished:
			# 함수 중간에서 런타임 오류로 중단되면 끝 표식에 도달하지 못한다.
			_failures.append("테스트가 끝까지 실행되지 않았어요: " + str(t.get_method()))
		var status: String = "ok" if _failures.size() == before else "FAIL"
		print("[%s] %s" % [status, str(t.get_method())])
	print("tests=%d checks=%d failures=%d" % [ran, _checks, _failures.size()])
	for f in _failures:
		printerr("FAIL: " + f)
	quit(0 if _failures.is_empty() and ran == tests.size() else 1)


# ---------- 보조 ----------

func _check(cond: bool, message: String) -> void:
	_checks += 1
	if not cond:
		_failures.append(message)


func _end() -> void:
	_finished = true


func _cfg(broth: String, tare: String, oil: String, noodle: String, topping: String, cook: String, price: int) -> Dictionary:
	return {"broth": broth, "tare": tare, "oil": oil, "noodle": noodle, "topping": topping, "cook": cook, "price": price}


func _rich_cfg(price: int = 9500) -> Dictionary:
	return _cfg("broth_tonkotsu", "tare_shoyu", "oil_garlic", "noodle_thick", "topping_chashu", "cook_firm", price)


func _light_cfg(price: int = 9000) -> Dictionary:
	return _cfg("broth_dashi", "tare_shio", "oil_scallion", "noodle_thin", "topping_egg", "cook_firm", price)


func _spicy_cfg(price: int = 7500) -> Dictionary:
	return _cfg("broth_chicken", "tare_miso", "oil_chili", "noodle_medium", "topping_chashu", "cook_normal", price)


func _scores_of(config: Dictionary) -> Dictionary:
	var ev: Dictionary = Evaluator.evaluate(config)
	var out: Dictionary = {}
	for c in ev["customers"]:
		var cd: Dictionary = c
		out[str(cd["id"])] = int(cd["score"])
	return out


func _customer(ev: Dictionary, id: String) -> Dictionary:
	for c in ev["customers"]:
		var cd: Dictionary = c
		if str(cd["id"]) == id:
			return cd
	return {}


func _state_with_wallet(amount: int) -> GameStateScript:
	var s: GameStateScript = GameStateScript.new()
	s.wallet = amount
	return s


func _apply_cfg(s: GameStateScript, config: Dictionary) -> void:
	for slot in Catalog.SLOTS:
		var r: Dictionary = s.set_draft_choice(slot, str(config[slot]))
		_check(bool(r["ok"]), "재료 선택 실패: " + str(config[slot]))
	var pr: Dictionary = s.set_draft_price(int(config["price"]))
	_check(bool(pr["ok"]), "가격 설정 실패: %d" % int(config["price"]))


func _case_dir(case_name: String) -> String:
	var path: String = _base_dir.path_join(case_name)
	if not DirAccess.dir_exists_absolute(path):
		DirAccess.make_dir_recursive_absolute(path)
	return path


func _cleanup_case(saver: SaveServiceScript, extra_files: Array[String] = []) -> void:
	saver.remove_known_files()
	for p in extra_files:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)
	# 비어 있을 때만 지워지므로 예상 밖 파일이 있으면 남는다(스캔/강제 삭제 없음).
	DirAccess.remove_absolute(saver.dir)


func _write_text(path: String, text: String) -> void:
	var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	_check(f != null, "픽스처 파일을 쓸 수 없어요: " + path)
	if f != null:
		f.store_string(text)
		f.close()


# ---------- 데이터/평가 ----------

func test_catalog_shape() -> void:
	var minimum: Dictionary = {"broth": 3, "tare": 3, "oil": 2, "noodle": 3, "topping": 4, "cook": 3}
	var seen: Dictionary = {}
	for slot in Catalog.SLOTS:
		var list: Array = Catalog.items(slot)
		_check(list.size() >= int(minimum[slot]), "%s 선택지가 부족해요" % slot)
		for item in list:
			var d: Dictionary = item
			var id: String = str(d["id"])
			_check(not seen.has(id), "재료 id 중복: " + id)
			seen[id] = true
			_check(id.begins_with(slot + "_"), "id 접두사 불일치: " + id)
			_check(int(d["cost"]) >= 0 and int(d["seconds"]) >= 0, "음수 비용/시간: " + id)
			_check(str(d["desc"]) != "" and str(d["name"]) != "", "설명/이름 누락: " + id)
	_check(Check.config_error(Catalog.default_config()) == "", "기본 구성이 유효하지 않아요")
	_end()


func test_customers_distinct() -> void:
	_check(Customers.all().size() == 3, "단골은 3명이어야 해요")
	var names: Dictionary = {}
	var targets: Dictionary = {}
	for c in Customers.all():
		var d: Dictionary = c
		names[str(d["name"])] = true
		targets[str(d["targets"])] = true
		_check(str(d["persona"]) != "", "성격 설명 누락")
	_check(names.size() == 3, "손님 이름이 서로 달라야 해요")
	_check(targets.size() == 3, "손님 취향이 서로 달라야 해요")
	_end()


func test_evaluation_deterministic() -> void:
	var a: Dictionary = Evaluator.evaluate(_rich_cfg())
	var b: Dictionary = Evaluator.evaluate(_rich_cfg())
	_check(str(a) == str(b), "같은 입력은 같은 평가여야 해요")
	for c in a["customers"]:
		var cd: Dictionary = c
		_check(int(cd["score"]) >= 0 and int(cd["score"]) <= 100, "점수 범위 오류")
		_check(int(cd["stars"]) >= 1 and int(cd["stars"]) <= 5, "별 범위 오류")
		_check(str(cd["headline"]) != "" and not (cd["reasons"] as Array).is_empty(), "피드백 누락")
	var bad: Dictionary = Evaluator.evaluate(_cfg("broth_x", "tare_shoyu", "oil_garlic", "noodle_thin", "topping_egg", "cook_firm", 9000))
	_check(str(bad["error"]) != "", "잘못된 재료 평가는 오류여야 해요")
	_end()


func test_preferences_differ() -> void:
	var rich_eval: Dictionary = Evaluator.evaluate(_rich_cfg())
	var light_eval: Dictionary = Evaluator.evaluate(_light_cfg())
	var d_rich: int = int(_customer(rich_eval, "dohyun")["score"])
	var d_light: int = int(_customer(light_eval, "dohyun")["score"])
	var h_rich: int = int(_customer(rich_eval, "hayoung")["score"])
	var h_light: int = int(_customer(light_eval, "hayoung")["score"])
	_check(d_rich > d_light, "도윤은 진한 레시피를 더 좋아해야 해요 (%d vs %d)" % [d_rich, d_light])
	_check(h_light > h_rich, "하영은 담백한 레시피를 더 좋아해야 해요 (%d vs %d)" % [h_light, h_rich])
	var spicy_eval: Dictionary = Evaluator.evaluate(_spicy_cfg())
	var m_spicy: int = int(_customer(spicy_eval, "maru")["score"])
	var h_spicy: int = int(_customer(spicy_eval, "hayoung")["score"])
	_check(m_spicy > h_spicy, "매운 레시피는 마루가 하영보다 높게 평가해야 해요 (%d vs %d)" % [m_spicy, h_spicy])
	_end()


## 972개 모든 조합을 훑어, 손님마다 최고 레시피가 다르고 한 사람의 최고가 다른 사람에겐 최고가 아님을 확인한다.
func test_no_universal_best() -> void:
	var best_score: Dictionary = {}
	var best_key: Dictionary = {}
	var all_scores: Dictionary = {}
	for b in Catalog.items("broth"):
		for t in Catalog.items("tare"):
			for o in Catalog.items("oil"):
				for n in Catalog.items("noodle"):
					for p in Catalog.items("topping"):
						for k in Catalog.items("cook"):
							var bd: Dictionary = b
							var td: Dictionary = t
							var od: Dictionary = o
							var nd: Dictionary = n
							var pd: Dictionary = p
							var kd: Dictionary = k
							var cfg: Dictionary = _cfg(str(bd["id"]), str(td["id"]), str(od["id"]), str(nd["id"]), str(pd["id"]), str(kd["id"]), 9000)
							var key: String = "%s|%s|%s|%s|%s|%s" % [bd["id"], td["id"], od["id"], nd["id"], pd["id"], kd["id"]]
							var sc: Dictionary = _scores_of(cfg)
							all_scores[key] = sc
							for id in sc:
								if not best_score.has(id) or int(sc[id]) > int(best_score[id]):
									best_score[id] = int(sc[id])
									best_key[id] = key
	_check(all_scores.size() == 972, "조합 수가 972개여야 해요: %d" % all_scores.size())
	var distinct: Dictionary = {}
	for id in best_key:
		distinct[str(best_key[id])] = true
	_check(distinct.size() == 3, "세 손님의 최고 레시피가 모두 달라야 해요")
	for id in best_key:
		var champion: Dictionary = all_scores[str(best_key[id])]
		var worst_gap: int = 0
		for other in champion:
			worst_gap = maxi(worst_gap, int(best_score[other]) - int(champion[other]))
		_check(worst_gap >= 8, "%s의 최고 레시피가 다른 손님에게도 사실상 최고예요 (격차 %d)" % [str(id), worst_gap])
	_end()


func _all_configs() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for b in Catalog.items("broth"):
		for t in Catalog.items("tare"):
			for o in Catalog.items("oil"):
				for n in Catalog.items("noodle"):
					for p in Catalog.items("topping"):
						for k in Catalog.items("cook"):
							var bd: Dictionary = b
							var td: Dictionary = t
							var od: Dictionary = o
							var nd: Dictionary = n
							var pd: Dictionary = p
							var kd: Dictionary = k
							out.append(_cfg(str(bd["id"]), str(td["id"]), str(od["id"]), str(nd["id"]), str(pd["id"]), str(kd["id"]), 9000))
	return out


## 점수 분포: 100점 포화/동점 몰림이 없고 별 등급이 고르게 나뉘어야 한다.
func test_score_distribution() -> void:
	var stats: Dictionary = {}
	for id in Customers.ids():
		stats[id] = {"buckets": [0, 0, 0, 0, 0, 0, 0, 0, 0, 0], "stars": {}, "top": 0, "max": -1, "high": 0, "perfect": 0}
	for cfg in _all_configs():
		var sc: Dictionary = _scores_of(cfg)
		for id in sc:
			var st: Dictionary = stats[id]
			var v: int = int(sc[id])
			var buckets: Array = st["buckets"]
			buckets[mini(v / 10, 9)] = int(buckets[mini(v / 10, 9)]) + 1
			var stars: Dictionary = st["stars"]
			var s: int = Evaluator.stars_for(v)
			stars[s] = int(stars.get(s, 0)) + 1
			if v > int(st["max"]):
				st["max"] = v
				st["top"] = 1
			elif v == int(st["max"]):
				st["top"] = int(st["top"]) + 1
			if v >= 95:
				st["high"] = int(st["high"]) + 1
			if v == 100:
				st["perfect"] = int(st["perfect"]) + 1
	for id in stats:
		var st2: Dictionary = stats[id]
		print("dist %s buckets(0-9..90-100)=%s stars=%s max=%d top_ties=%d >=95:%d" % [str(id), str(st2["buckets"]), str(st2["stars"]), int(st2["max"]), int(st2["top"]), int(st2["high"])])
		_check((st2["stars"] as Dictionary).size() >= 4, "%s: 별 등급이 4단계 이상 나와야 해요" % str(id))
		_check(int(st2["perfect"]) <= 6, "%s: 100점 포화 조합이 너무 많아요: %d" % [str(id), int(st2["perfect"])])
		_check(int(st2["high"]) <= 48, "%s: 95점 이상이 5%%를 넘어요: %d" % [str(id), int(st2["high"])])
		_check(int(st2["top"]) <= 4, "%s: 최고점 동점이 너무 많아요: %d" % [str(id), int(st2["top"])])
		_check(int(st2["max"]) >= 80, "%s: 만족시킬 수 있는 레시피가 있어야 해요: %d" % [str(id), int(st2["max"])])
	# 궁합 가산이 큰 취향 불일치를 지우면 안 된다: 손님별로 각 축을 취향에서 가장 먼 극단(0 또는 10)으로 둔
	# 프로필은 현실적인 최대 궁합(+12)을 받아도 55점 미만이어야 한다.
	for c in Customers.all():
		var customer: Dictionary = c
		var targets: Dictionary = customer["targets"]
		var off: Dictionary = {}
		for axis in Catalog.AXES:
			off[axis] = 0 if int(targets[axis]) >= 5 else Evaluator.PROFILE_MAX
		var s_off: int = Evaluator.score_for(off, 12, customer)
		_check(s_off < 55, "%s: 큰 불일치를 궁합이 구제하면 안 돼요 (%d)" % [str(customer["name"]), s_off])
	_end()


func test_compatibility_matters() -> void:
	# 같은 맛 프로필이라도 궁합 합계가 다르면 점수가 달라진다(손님 모두 동일 방향).
	var profile: Dictionary = Evaluator.build_profile(_rich_cfg())
	for c in Customers.all():
		var customer: Dictionary = c
		var good: int = Evaluator.score_for(profile, 12, customer)
		var bad: int = Evaluator.score_for(profile, -12, customer)
		_check(good > bad, "%s: 궁합이 좋을수록 점수가 높아야 해요" % str(customer["name"]))
	# 민감도 차이: 궁합에 예민한 하영은 마루보다 궁합 변화 폭이 커야 한다.
	var hay: Dictionary = Customers.find("hayoung")
	var maru: Dictionary = Customers.find("maru")
	var hay_span: int = Evaluator.score_for(profile, 12, hay) - Evaluator.score_for(profile, -12, hay)
	var maru_span: int = Evaluator.score_for(profile, 12, maru) - Evaluator.score_for(profile, -12, maru)
	_check(hay_span > maru_span, "궁합 민감도 차이가 반영돼야 해요 (%d vs %d)" % [hay_span, maru_span])
	# 실제 재료 쌍: 해물 다시 + 가는 면은 좋고, 굵은 꼬불면은 나쁘다.
	var thin: Dictionary = Evaluator.evaluate(_cfg("broth_dashi", "tare_shio", "oil_scallion", "noodle_thin", "topping_egg", "cook_firm", 9000))
	var thick: Dictionary = Evaluator.evaluate(_cfg("broth_dashi", "tare_shio", "oil_scallion", "noodle_thick", "topping_egg", "cook_firm", 9000))
	_check(int(thin["compat_total"]) > int(thick["compat_total"]), "면 궁합이 합계에 반영돼야 해요")
	_check(int(_customer(thin, "hayoung")["score"]) > int(_customer(thick, "hayoung")["score"]), "다시+굵은 면은 하영에게 불리해야 해요")
	# 익힘: 가는 면 + 푹 익힘은 페널티.
	var soft: Dictionary = Evaluator.evaluate(_cfg("broth_dashi", "tare_shio", "oil_scallion", "noodle_thin", "topping_egg", "cook_soft", 9000))
	_check(int(soft["compat_total"]) < int(thin["compat_total"]), "가는 면 푹 익힘은 궁합이 나빠야 해요")
	# 궁합 합계는 상한으로 제한된다.
	_check(absi(int(thin["compat_total"])) <= Evaluator.COMPAT_CAP, "궁합 합계 상한 초과")
	_end()


func test_feedback_is_causal() -> void:
	var light: Dictionary = Evaluator.evaluate(_light_cfg())
	var dohyun: Dictionary = _customer(light, "dohyun")
	var joined: String = "\n".join(dohyun["reasons"] as Array)
	_check(str(dohyun["headline"]).find("가벼워요") >= 0, "진한 맛을 원하는 손님이 가벼운 국물을 지적해야 해요: " + str(dohyun["headline"]))
	_check(joined.find("진함") >= 0, "피드백이 진함 수치를 언급해야 해요")
	var rich: Dictionary = Evaluator.evaluate(_rich_cfg())
	var hay: Dictionary = _customer(rich, "hayoung")
	var hay_text: String = str(hay["headline"]) + "\n" + "\n".join(hay["reasons"] as Array)
	_check(hay_text.find("무겁") >= 0 or hay_text.find("강해요") >= 0 or hay_text.find("짜요") >= 0, "담백한 취향 손님이 진한 레시피를 지적해야 해요: " + hay_text)
	_check(str(_customer(rich, "dohyun")["headline"]) != str(hay["headline"]), "손님별 피드백이 달라야 해요")
	# 나쁜 궁합은 이유 문장에 그대로 나타난다.
	var clash: Dictionary = Evaluator.evaluate(_cfg("broth_dashi", "tare_miso", "oil_garlic", "noodle_thick", "topping_chashu", "cook_soft", 9000))
	var clash_text: String = "\n".join(_customer(clash, "hayoung")["reasons"] as Array)
	_check(clash_text.find("조합 아쉬움") >= 0, "나쁜 궁합이 피드백에 나와야 해요: " + clash_text)
	var great: Dictionary = Evaluator.evaluate(_cfg("broth_tonkotsu", "tare_shio", "oil_garlic", "noodle_thick", "topping_sprouts", "cook_firm", 9000))
	var great_text: String = "\n".join(_customer(great, "dohyun")["reasons"] as Array)
	_check(great_text.find("조합 호평") >= 0, "좋은 궁합이 피드백에 나와야 해요: " + great_text)
	# 가격 문장은 손님 기준마다 다르다.
	var pricey: Dictionary = Evaluator.evaluate(_rich_cfg(12000))
	_check(str(_customer(pricey, "maru")["value_note"]).find("넘어요") >= 0, "마루는 12,000원을 감당 상한 초과로 말해야 해요")
	_check(str(_customer(pricey, "dohyun")["value_note"]).find("비싸게") >= 0, "도윤은 12,000원을 비싸게 느껴야 해요")
	_end()


# ---------- 판매 ----------

func test_price_affects_sales() -> void:
	var recipes: Array[Dictionary] = [_rich_cfg(), _light_cfg(), _spicy_cfg()]
	var low_units: int = 0
	var high_units: int = 0
	for r in recipes:
		var scores: Dictionary = _scores_of(r)
		var low: Dictionary = r.duplicate(true)
		low["price"] = 6000
		var high: Dictionary = r.duplicate(true)
		high["price"] = 13000
		var extreme: Dictionary = r.duplicate(true)
		extreme["price"] = 20000
		var u_low: Dictionary = Sim.simulate(low, scores, 5)
		var u_high: Dictionary = Sim.simulate(high, scores, 5)
		var u_ext: Dictionary = Sim.simulate(extreme, scores, 5)
		_check(str(u_low["error"]) == "" and str(u_high["error"]) == "" and str(u_ext["error"]) == "", "시뮬레이션 오류")
		low_units += int(u_low["units"])
		high_units += int(u_high["units"])
		_check(int(u_ext["units"]) == 0, "모든 손님의 상한을 넘는 가격은 판매 0이어야 해요")
		_check(int(u_ext["net"]) == -Sim.OVERHEAD, "판매 0이면 운영비만큼 손실이어야 해요")
		_check(int(u_low["units"]) >= int(u_high["units"]), "싼 가격이 더 많이 팔려야 해요")
	_check(low_units > high_units, "가격이 오르면 수요가 줄어야 해요 (%d vs %d)" % [low_units, high_units])
	# 가격 스윕: 매출 최대 가격이 최고가가 아니다(비싼 메뉴가 자동으로 이기지 않는다).
	var scores2: Dictionary = _scores_of(_rich_cfg())
	var best_revenue: int = -1
	var best_price: int = 0
	var p: int = Catalog.PRICE_MIN
	while p <= Catalog.PRICE_MAX:
		var c: Dictionary = _rich_cfg(p)
		var res: Dictionary = Sim.simulate(c, scores2, 5)
		if int(res["revenue"]) > best_revenue:
			best_revenue = int(res["revenue"])
			best_price = p
		p += 500
	_check(best_price < 20000 and best_price > Catalog.PRICE_MIN, "매출 최대 가격이 양 극단이 아니어야 해요: %d" % best_price)
	# 결과 식: 매출/원가/순이익
	var sample: Dictionary = Sim.simulate(_rich_cfg(), scores2, 5)
	_check(int(sample["revenue"]) == int(sample["units"]) * 9500, "매출 = 판매량 × 가격")
	_check(int(sample["ingredient_cost"]) == int(sample["units"]) * Evaluator.unit_cost(_rich_cfg()), "재료비 = 판매량 × 원가")
	_check(int(sample["net"]) == int(sample["revenue"]) - int(sample["ingredient_cost"]) - int(sample["overhead"]), "순이익 계산")
	var sum_sources: int = 0
	for k in sample["by_source"]:
		sum_sources += int((sample["by_source"] as Dictionary)[k])
	_check(sum_sources == int(sample["units"]), "손님별 판매 합 = 총 판매")
	_check(str(Sim.simulate(_rich_cfg(), scores2, 5)) == str(sample), "시뮬레이션은 결정적이어야 해요")
	_end()


func test_prep_time_limits_sales() -> void:
	var fast: Dictionary = _cfg("broth_chicken", "tare_shio", "oil_scallion", "noodle_thin", "topping_nori", "cook_firm", 9000)
	var slow: Dictionary = _cfg("broth_tonkotsu", "tare_shoyu", "oil_garlic", "noodle_thick", "topping_chashu", "cook_soft", 9000)
	_check(Evaluator.prep_seconds(fast) < Evaluator.prep_seconds(slow), "준비 시간 비교")
	var scores: Dictionary = {"dohyun": 100, "hayoung": 100, "maru": 100}
	var f: Dictionary = Sim.simulate(fast, scores, 5)
	var s: Dictionary = Sim.simulate(slow, scores, 5)
	_check(int(f["capacity"]) > int(s["capacity"]), "준비가 빠를수록 소화 가능한 그릇이 많아야 해요")
	_check(int(s["units"]) <= int(s["capacity"]), "판매량은 용량을 넘을 수 없어요")
	_check(int(f["units"]) <= int(f["capacity"]), "판매량은 용량을 넘을 수 없어요")
	_end()


func test_sales_input_validation() -> void:
	var scores: Dictionary = {"dohyun": 80, "hayoung": 80, "maru": 80}
	_check(str(Sim.simulate(_rich_cfg(), scores, 0)["error"]) != "", "0일차는 거부")
	_check(str(Sim.simulate(_rich_cfg(), scores, -3)["error"]) != "", "음수 일차는 거부")
	for bad_price in [0, -1000, 999, 950, 30100]:
		var cfg: Dictionary = _rich_cfg()
		cfg["price"] = bad_price
		_check(str(Sim.simulate(cfg, scores, 1)["error"]) != "", "잘못된 가격 거부: %d" % bad_price)
	_check(str(Sim.simulate(_rich_cfg(), {"dohyun": 80, "hayoung": 80}, 1)["error"]) != "", "점수 누락 거부")
	_check(str(Sim.simulate(_rich_cfg(), {"dohyun": 80, "hayoung": 80, "maru": 101}, 1)["error"]) != "", "점수 범위 초과 거부")
	_check(str(Sim.simulate(_rich_cfg(), {"dohyun": 80, "hayoung": 80, "maru": -1}, 1)["error"]) != "", "음수 점수 거부")
	_check(str(Sim.simulate(_rich_cfg(), {"dohyun": 80, "hayoung": 80, "maru": 80, "x": 1}, 1)["error"]) != "", "알 수 없는 손님 거부")
	for day in range(1, 15):
		var res: Dictionary = Sim.simulate(_rich_cfg(), scores, day)
		_check(int(res["units"]) >= 0 and int(res["revenue"]) >= 0 and int(res["ingredient_cost"]) >= 0, "음수 수량 금지 (일차 %d)" % day)
	_end()


# ---------- 상태/개정 ----------

func test_revision_and_immutability() -> void:
	var s: GameStateScript = _state_with_wallet(100000)
	_apply_cfg(s, _rich_cfg())
	s.set_draft_name("  새벽 돈코츠  ")
	var r1: Dictionary = s.taste()
	_check(bool(r1["ok"]), "첫 시식 성공: " + str(r1["message"]))
	_check(s.record_count() == 1, "기록 1개")
	var first: Dictionary = s.get_record(int(r1["record_id"]))
	_check(str(first["name"]) == "새벽 돈코츠", "이름은 앞뒤 공백이 정리돼야 해요")
	_check(int(first["version"]) == 1 and (first["comparison"] as Dictionary).is_empty(), "첫 버전은 비교 없음")
	_check(s.wallet == 100000 - Evaluator.unit_cost(_rich_cfg()), "시제품 재료비가 차감돼야 해요")

	# 반환값을 마음대로 바꿔도 내부 기록은 변하지 않는다.
	var copy_list: Array = s.records()
	var tampered: Dictionary = copy_list[0]
	var tampered_cfg: Dictionary = tampered["config"]
	tampered["name"] = "변조"
	tampered_cfg["price"] = 1
	_check(str(s.get_record(1)["name"]) == "새벽 돈코츠", "records() 변경이 내부에 영향을 주면 안 돼요")

	# 개정: 면을 바꾸면 v2 + 이전 버전과의 비교
	s.set_draft_choice("noodle", "noodle_thin")
	var r2: Dictionary = s.taste()
	_check(bool(r2["ok"]), "개정 시식 성공: " + str(r2["message"]))
	var second: Dictionary = s.get_record(int(r2["record_id"]))
	_check(int(second["version"]) == 2 and int(second["lineage_id"]) == int(first["lineage_id"]), "같은 레시피의 v2여야 해요")
	var cmp: Dictionary = second["comparison"]
	_check(int(cmp["prev_version"]) == 1 and str(cmp["prev_scores"]) == str(first["scores"]), "비교에 이전 점수가 들어 있어야 해요")
	_check(str((cmp["prev_config"] as Dictionary)["noodle"]) == "noodle_thick", "비교에 이전 구성이 들어 있어야 해요")
	# 이전 기록은 그대로
	_check(str(s.get_record(1)) == str(first), "v1 기록이 v2 시식 후에도 같아야 해요")

	# 선택하면 구성/가격/익힘이 복원되고, 이후 편집은 기록을 바꾸지 않는다.
	var sel: Dictionary = s.select_record(1)
	_check(bool(sel["ok"]), "선택 성공")
	_check(Check.same_config(s.draft_config, first["config"]), "선택 시 구성·가격·익힘 복원")
	_check(s.selected_record_id == 1 and s.draft_name == "새벽 돈코츠", "선택/이름 복원")
	s.set_draft_choice("topping", "topping_nori")
	s.set_draft_price(11000)
	_check(str(s.get_record(1)) == str(first), "선택 후 편집이 기록을 바꾸면 안 돼요")
	var r3: Dictionary = s.taste()
	_check(bool(r3["ok"]), "선택 후 시식 성공: " + str(r3["message"]))
	var third: Dictionary = s.get_record(int(r3["record_id"]))
	_check(int(third["version"]) == 3 and int((third["comparison"] as Dictionary)["prev_version"]) == 2, "v3는 v2와 비교")
	_check(str(s.get_record(1)) == str(first) and str(s.get_record(2)) == str(second), "이전 기록 불변")
	# 개정 중에는 이름 변경 불가
	var rename: Dictionary = s.set_draft_name("다른 이름")
	_check(not bool(rename["ok"]) and s.draft_name == "새벽 돈코츠", "개정 중 이름 변경 거부")
	# 새 레시피 시작
	s.start_new_recipe()
	_check(s.draft_lineage_id == 0 and s.selected_record_id == 0, "새 레시피는 연결/선택을 푼다")
	s.set_draft_name("새벽 돈코츠")
	s.set_draft_choice("tare", "tare_miso")
	var dup_name: Dictionary = s.taste()
	_check(not bool(dup_name["ok"]), "다른 레시피가 같은 이름을 쓰면 거부")
	# 삭제는 해당 기록만 지운다.
	var del: Dictionary = s.delete_record(2)
	_check(bool(del["ok"]) and s.record_count() == 2 and s.get_record(2).is_empty(), "삭제")
	_check(str(s.get_record(1)) == str(first), "삭제가 다른 기록을 바꾸지 않아요")
	_end()


func test_duplicate_and_bounds() -> void:
	var s: GameStateScript = _state_with_wallet(900000)
	_apply_cfg(s, _rich_cfg())
	s.set_draft_name("중복 검사")
	_check(bool(s.taste()["ok"]), "첫 시식")
	var dup: Dictionary = s.taste()
	_check(not bool(dup["ok"]) and s.record_count() == 1, "같은 구성으로 연속 시식하면 새 기록이 생기면 안 돼요")
	_check(s.wallet == 900000 - Evaluator.unit_cost(_rich_cfg()), "중복 거부 시 자금이 차감되면 안 돼요")
	s.start_new_recipe()
	s.set_draft_name("다른 이름 같은 구성")
	_check(not bool(s.taste()["ok"]) and s.record_count() == 1, "이름만 달라도 같은 구성은 거부")
	# 가격을 올려가며 개정해 30개를 채운다.
	s.select_record(1)
	var price: int = 9500
	var guard: int = 0
	while s.record_count() < GameStateScript.MAX_RECORDS and guard < 100:
		price += 100
		s.set_draft_price(price)
		var r: Dictionary = s.taste()
		_check(bool(r["ok"]), "개정 시식 %d: %s" % [s.record_count(), str(r["message"])])
		guard += 1
	_check(s.record_count() == GameStateScript.MAX_RECORDS, "기록이 30개까지 쌓여야 해요: %d" % s.record_count())
	var wallet_before: int = s.wallet
	s.set_draft_price(price + 100)
	var over: Dictionary = s.taste()
	_check(not bool(over["ok"]) and s.record_count() == GameStateScript.MAX_RECORDS, "30개를 넘기면 거부")
	_check(s.wallet == wallet_before, "거부 시 자금 불변")
	# 삭제 후에는 다시 시식 가능
	_check(bool(s.delete_record(30)["ok"]), "삭제")
	_check(bool(s.taste()["ok"]) and s.record_count() == GameStateScript.MAX_RECORDS, "삭제 후 시식 가능")
	_end()


func test_wallet_and_serve() -> void:
	var s: GameStateScript = _state_with_wallet(0)
	_check(not bool(s.taste()["ok"]) and s.record_count() == 0, "자금이 부족하면 시식 거부")
	var empty_serve: Dictionary = s.serve()
	_check(not bool(empty_serve["ok"]) and s.day == 1, "선택 없이 영업 불가, 일차 불변")

	s.wallet = 50000
	_apply_cfg(s, _rich_cfg())
	_check(bool(s.taste()["ok"]), "시식")
	var forecast: Dictionary = s.forecast()
	_check(str(forecast["error"]) == "", "예측 가능")
	var wallet_before: int = s.wallet
	var day_before: int = s.day
	var res: Dictionary = s.serve()
	_check(bool(res["ok"]), "영업 성공: " + str(res["message"]))
	_check(s.day == day_before + 1, "영업 1회는 정확히 1일이어야 해요")
	_check(s.wallet == wallet_before + int(forecast["net"]), "자금 = 이전 + 순이익(예측과 동일)")
	var rep: Dictionary = s.last_report
	_check(int(rep["units"]) == int(forecast["units"]) and int(rep["day"]) == day_before, "보고서가 예측/일차와 일치")
	_check(int(rep["wallet_after"]) == s.wallet, "보고서의 영업 후 자금")
	_check(int(rep["units"]) >= 0 and int(rep["revenue"]) >= 0 and int(rep["ingredient_cost"]) >= 0, "음수 금지")

	# 손실이 자금을 넘으면 영업 거부(자금은 음수가 되지 않는다).
	var t: GameStateScript = _state_with_wallet(50000)
	_apply_cfg(t, _rich_cfg(1000))
	_check(bool(t.taste()["ok"]), "저가 시식")
	t.wallet = 0
	var broke: Dictionary = t.serve()
	_check(not bool(broke["ok"]) and t.wallet == 0 and t.day == 1, "자금 부족 영업 거부, 상태 불변")
	_end()


func test_invalid_inputs() -> void:
	var s: GameStateScript = GameStateScript.new()
	var before: String = str(s.draft_config)
	_check(not bool(s.set_draft_choice("broth", "broth_nope")["ok"]), "없는 재료 id 거부")
	_check(not bool(s.set_draft_choice("broth", "noodle_thin")["ok"]), "다른 슬롯의 재료 거부")
	_check(not bool(s.set_draft_choice("sauce", "tare_shoyu")["ok"]), "없는 슬롯 거부")
	_check(not bool(s.set_draft_choice("broth", "")["ok"]), "빈 id 거부")
	for bad in [0, -500, 999, 1050, 30100, 100000]:
		_check(not bool(s.set_draft_price(bad)["ok"]), "잘못된 가격 거부: %d" % bad)
	_check(str(s.draft_config) == before, "거부된 입력은 초안을 바꾸면 안 돼요")
	for good in [Catalog.PRICE_MIN, Catalog.PRICE_MAX, 9900]:
		_check(bool(s.set_draft_price(good)["ok"]), "유효 가격 허용: %d" % good)
	s.set_draft_name("   ")
	_check(not bool(s.taste()["ok"]), "공백 이름은 시식 거부")
	s.set_draft_name("가".repeat(Check.NAME_MAX + 1))
	_check(not bool(s.taste()["ok"]), "너무 긴 이름 거부")
	s.set_draft_name("줄바꿈\n이름")
	_check(not bool(s.taste()["ok"]), "제어문자 이름 거부")
	_check(s.record_count() == 0, "거부된 시식은 기록을 만들지 않아요")
	_check(not bool(s.select_record(99)["ok"]) and not bool(s.delete_record(99)["ok"]), "없는 기록 선택/삭제 거부")
	_end()


# ---------- 저장 ----------

func _populated_state() -> GameStateScript:
	var s: GameStateScript = _state_with_wallet(100000)
	_apply_cfg(s, _rich_cfg())
	s.set_draft_name("저장 시험")
	s.taste()
	s.set_draft_choice("noodle", "noodle_medium")
	s.taste()
	s.serve()
	s.set_draft_price(10300)
	return s


func test_save_roundtrip() -> void:
	var dir: String = _case_dir("roundtrip")
	var saver: SaveServiceScript = SaveServiceScript.new(dir)
	saver.remove_known_files()
	var s: GameStateScript = _populated_state()
	var res: Dictionary = saver.save_state(s)
	_check(bool(res["ok"]), "저장 성공: " + str(res["message"]))
	_check(saver.has_save(), "저장 파일 존재")
	_check(not FileAccess.file_exists(saver.tmp_path()), "임시 파일이 남으면 안 돼요")
	var loaded: GameStateScript = GameStateScript.new()
	var lr: Dictionary = saver.load_into(loaded)
	_check(str(lr["status"]) == "ok", "불러오기 성공: " + str(lr["message"]))
	_check(JSON.stringify(loaded.to_dict(), "\t", true) == JSON.stringify(s.to_dict(), "\t", true), "저장/불러오기 왕복이 동일해야 해요")
	_check(loaded.day == s.day and loaded.wallet == s.wallet and loaded.record_count() == 2, "일차/자금/기록 복원")
	_check(loaded.selected_record_id == s.selected_record_id and int(loaded.draft_config["price"]) == 10300, "선택/초안 복원")
	_check(not loaded.last_report.is_empty() and str(loaded.last_report) == str(s.last_report), "마지막 영업 보고 복원")
	_check(loaded.last_feedback_record_id == s.last_feedback_record_id, "마지막 피드백 복원")
	_check(str(loaded.get_record(2)["comparison"]) == str(s.get_record(2)["comparison"]), "비교 정보 복원")
	_cleanup_case(saver)
	_end()


func test_missing_corrupt_future_saves() -> void:
	var dir: String = _case_dir("variants")
	var saver: SaveServiceScript = SaveServiceScript.new(dir)
	saver.remove_known_files()
	var fresh: GameStateScript = GameStateScript.new()
	var baseline: String = JSON.stringify(fresh.to_dict(), "\t", true)

	var missing: Dictionary = saver.load_into(fresh)
	_check(str(missing["status"]) == "missing", "저장이 없으면 정상 첫 실행(missing)")

	var archived: Array[String] = []
	var garbage_cases: Array[String] = ["이건 JSON이 아님{{", "[1,2,3]", "", "{\"schema_version\": \"1\"}", "{\"day\": 3}"]
	for garbage in garbage_cases:
		_write_text(saver.main_path(), garbage)
		var probe: GameStateScript = GameStateScript.new()
		var r: Dictionary = saver.load_into(probe)
		_check(str(r["status"]) == "corrupt", "손상 저장은 corrupt: " + garbage)
		_check(FileAccess.get_file_as_string(saver.main_path()) == garbage, "손상 파일은 로드 시도로 바뀌면 안 돼요")
		_check(JSON.stringify(probe.to_dict(), "\t", true) == baseline, "손상 로드는 상태를 바꾸면 안 돼요")

	# 미래 버전: 구조가 유효해도 거부하고 파일을 보존한다.
	var future: Dictionary = _populated_state().to_dict()
	future["schema_version"] = GameStateScript.SCHEMA_VERSION + 1
	var future_text: String = JSON.stringify(future, "\t", true)
	_write_text(saver.main_path(), future_text)
	var fr: Dictionary = saver.load_into(GameStateScript.new())
	_check(str(fr["status"]) == "unsupported", "미래 버전은 unsupported")
	_check(FileAccess.get_file_as_string(saver.main_path()) == future_text, "미지원 저장은 보존돼야 해요")
	var old: Dictionary = future.duplicate(true)
	old["schema_version"] = 0
	_write_text(saver.main_path(), JSON.stringify(old, "\t", true))
	_check(str(saver.load_into(GameStateScript.new())["status"]) == "unsupported", "구버전도 unsupported")

	# 손상 파일을 치우는 것은 명시적 동작이며 내용은 보관된다.
	_write_text(saver.main_path(), "깨진 파일")
	var arch: Dictionary = saver.archive_corrupt()
	_check(bool(arch["ok"]) and not FileAccess.file_exists(saver.main_path()), "손상 파일 보관")
	var arch_path: String = str(arch["path"])
	archived.append(arch_path)
	_check(FileAccess.get_file_as_string(arch_path) == "깨진 파일", "보관된 파일 내용 보존")
	_cleanup_case(saver, archived)
	_end()


func test_malformed_state_rejected() -> void:
	var good: Dictionary = _populated_state().to_dict()
	# JSON 왕복을 거쳐 실제 로드 경로(숫자가 float로 오는 상황)와 같게 만든다.
	var parsed: Variant = JSON.parse_string(JSON.stringify(good))
	_check(typeof(parsed) == TYPE_DICTIONARY, "왕복 파싱")
	var base: Dictionary = parsed
	var probe: GameStateScript = GameStateScript.new()
	_check(probe.load_from_dict(base) == "", "정상 데이터는 float 숫자여도 받아들여야 해요")

	var labels: Array[String] = [
		"알 수 없는 재료", "다른 슬롯 재료", "음수 가격", "가격 단위 오류", "소수 가격", "bool 가격",
		"문자열 가격", "음수 자금", "소수 자금", "0일차", "과도한 일차", "누락 키", "추가 키",
		"점수 변조", "점수 범위 초과", "없는 선택 기록", "없는 피드백 기록", "기록 번호 중복",
		"버전 중복", "기록 구조 오류", "records가 배열 아님", "기록 31개", "초안 재료 오류",
		"초안 이름 제어문자", "초안 레시피 번호", "보고 합계 불일치", "보고 순이익 불일치",
		"비교 이전 버전 오류", "스키마 버전",
	]
	for label in labels:
		var copy: Dictionary = base.duplicate(true)
		_mutate(label, copy)
		var target: GameStateScript = GameStateScript.new()
		var snapshot: String = JSON.stringify(target.to_dict(), "\t", true)
		var err: String = target.load_from_dict(copy)
		_check(err != "", "거부돼야 해요: " + str(label))
		_check(JSON.stringify(target.to_dict(), "\t", true) == snapshot, "거부된 로드는 상태를 바꾸면 안 돼요: " + str(label))
	_end()


## 정상 저장 딕셔너리(JSON 왕복본: 기록 2개, 비교 포함)를 한 가지 방식으로 망가뜨린다.
func _mutate(label: String, d: Dictionary) -> void:
	var records: Array = d["records"]
	var rec0: Dictionary = records[0]
	var rec1: Dictionary = records[1]
	var cfg0: Dictionary = rec0["config"]
	var scores0: Dictionary = rec0["scores"]
	var draft: Dictionary = d["draft"]
	var report: Dictionary = d["last_report"]
	match label:
		"알 수 없는 재료":
			cfg0["broth"] = "broth_nope"
		"다른 슬롯 재료":
			cfg0["tare"] = "broth_dashi"
		"음수 가격":
			cfg0["price"] = -100
		"가격 단위 오류":
			cfg0["price"] = 9050
		"소수 가격":
			cfg0["price"] = 9000.5
		"bool 가격":
			cfg0["price"] = true
		"문자열 가격":
			cfg0["price"] = "9000"
		"음수 자금":
			d["wallet"] = -1
		"소수 자금":
			d["wallet"] = 10.5
		"0일차":
			d["day"] = 0
		"과도한 일차":
			d["day"] = 10000000
		"누락 키":
			d.erase("wallet")
		"추가 키":
			d["bonus"] = 1
		"점수 변조":
			scores0["dohyun"] = (int(scores0["dohyun"]) + 37) % 101
		"점수 범위 초과":
			scores0["maru"] = 101
		"없는 선택 기록":
			d["selected_record_id"] = 999
		"없는 피드백 기록":
			d["last_feedback_record_id"] = 999
		"기록 번호 중복":
			rec1["record_id"] = rec0["record_id"]
		"버전 중복":
			rec1["version"] = 1
		"기록 구조 오류":
			records[0] = "x"
		"records가 배열 아님":
			d["records"] = {}
		"기록 31개":
			_inflate_records(d)
		"초안 재료 오류":
			(draft["config"] as Dictionary)["oil"] = "oil_nope"
		"초안 이름 제어문자":
			draft["name"] = "a\nb"
		"초안 레시피 번호":
			draft["lineage_id"] = 77
		"보고 합계 불일치":
			report["units"] = int(report["units"]) + 1
		"보고 순이익 불일치":
			report["net"] = int(report["net"]) + 1
		"비교 이전 버전 오류":
			(rec1["comparison"] as Dictionary)["prev_version"] = 5
		"스키마 버전":
			d["schema_version"] = 2
		_:
			_failures.append("알 수 없는 변조 이름: " + label)


func _inflate_records(d: Dictionary) -> void:
	var records: Array = d["records"]
	var template: Dictionary = (records[0] as Dictionary).duplicate(true)
	while records.size() < GameStateScript.MAX_RECORDS + 1:
		var extra: Dictionary = template.duplicate(true)
		extra["record_id"] = 100 + records.size()
		extra["version"] = 100 + records.size()
		extra["comparison"] = {}
		records.append(extra)
	d["next_record_id"] = 1000


func test_backup_strategy() -> void:
	var dir: String = _case_dir("backup")
	var saver: SaveServiceScript = SaveServiceScript.new(dir)
	saver.remove_known_files()
	var s: GameStateScript = GameStateScript.new()
	_check(bool(saver.save_state(s)["ok"]), "첫 저장")
	_check(not FileAccess.file_exists(saver.bak_path()), "첫 저장에는 백업이 없어요")
	var first_text: String = FileAccess.get_file_as_string(saver.main_path())
	s.wallet = 12345
	_check(bool(saver.save_state(s)["ok"]), "두 번째 저장")
	_check(FileAccess.file_exists(saver.bak_path()), "두 번째 저장부터 백업이 있어야 해요")
	_check(FileAccess.get_file_as_string(saver.bak_path()) == first_text, "백업은 직전 저장이어야 해요")
	_check(not FileAccess.file_exists(saver.tmp_path()), "임시 파일 정리")
	var unwritable: SaveServiceScript = SaveServiceScript.new(dir.path_join("없는폴더"))
	_check(not bool(unwritable.save_state(s)["ok"]), "쓸 수 없는 위치는 저장 실패를 알려야 해요")
	var nowhere: SaveServiceScript = SaveServiceScript.new("")
	_check(str(nowhere.load_into(GameStateScript.new())["status"]) == "io_error", "위치 없음은 io_error")
	_cleanup_case(saver)
	_end()


func test_data_location() -> void:
	var none: Dictionary = LocationScript.resolve(PackedStringArray(["--foo"]))
	_check(bool(none["ok"]) and not bool(none["is_dev"]) and str(none["dir"]) == "user://", "기본은 user://")
	var dir: String = _case_dir("location")
	var dev: Dictionary = LocationScript.resolve(PackedStringArray(["--dev-data-dir=" + dir]))
	_check(bool(dev["ok"]) and bool(dev["is_dev"]) and str(dev["dir"]) == dir, "개발용 경로 허용")
	for bad in ["--dev-data-dir=relative/path", "--dev-data-dir=", "--dev-data-dir=user://x", "--dev-data-dir=res://x", "--dev-data-dir=/tmp/../etc"]:
		var r: Dictionary = LocationScript.resolve(PackedStringArray([bad]))
		_check(not bool(r["ok"]) and str(r["error"]) != "", "잘못된 개발 경로 거부: " + bad)
	var twice: Dictionary = LocationScript.resolve(PackedStringArray(["--dev-data-dir=" + dir, "--dev-data-dir=" + dir + "/x"]))
	_check(not bool(twice["ok"]), "중복 지정 거부")
	DirAccess.remove_absolute(dir)
	_end()
