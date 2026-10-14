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
const SessionScript = preload("res://scripts/domain/service_session.gd")
const LayoutScript = preload("res://scripts/ui/shop_layout.gd")
const ArtScript = preload("res://scripts/ui/pixel_art.gd")
const PainterScript = preload("res://scripts/ui/shop_painter.gd")
const SceneScript = preload("res://scripts/ui/shop_scene.gd")
const Research = preload("res://scripts/domain/ramen_research.gd")
const WorkScript = preload("res://scripts/ui/tasting_work.gd")
const WorkViewScript = preload("res://scripts/ui/tasting_work_view.gd")
const Growth = preload("res://scripts/domain/shop_growth.gd")
const Staffing = preload("res://scripts/domain/shop_staffing.gd")
const ShopViewScript = preload("res://scripts/ui/shop_view.gd")

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
		test_service_plan_deterministic, test_service_lifecycle_order, test_service_queue_and_seat_reuse,
		test_service_money_matches_runtime, test_service_quality_changes_arrivals_and_reactions,
		test_service_recipe_locking, test_service_cancel_and_reload, test_service_settlement_guards,
		test_service_determinism_and_chunking, test_shop_layout_and_art,
		test_research_catalog_and_feasibility, test_research_sweep_no_single_recipe,
		test_research_unlock_and_one_time_rewards, test_research_check_values,
		test_research_rejections_do_not_mutate, test_research_service_lock, test_research_overflow,
		test_research_persistence_after_delete, test_research_v1_migration, test_research_malformed_progress,
		test_research_rejects_fabricated_scores, test_research_load_rejects_unmet_retained_record,
		test_tasting_work_state, test_tasting_work_phases_and_motion, test_portraits_and_glyph_free_art,
		# --- 가게 성장(등급/확장/다중 토핑/직원/노트 용량/스키마 v3) 도메인 시험 ---
		# 화면(UI)/장면 그림/QA 캡처 쪽 성장 시험은 다음 단계(main.gd, 픽셀 아트, qa_capture.gd)에서 추가한다: 아직 없으므로 "보류"이며 삭제/생략이 아니다.
		test_topping_canonical_and_legacy, test_topping_validation, test_topping_slots_and_draft_limits,
		test_topping_tradeoff, test_rank_promotion, test_facility_purchase, test_staff_hiring,
		test_staff_support_effects, test_staff_settlement_and_snapshot, test_record_capacity_and_grandfather,
		test_schema_migration_v1_v2, test_growth_load_rejections, test_no_phantom_rewards_and_bounds,
		# --- 성장 UI 단계: 다중 토핑 그릇 그림, 보조 직원 초상/스프라이트, 직원 자리/장면. 화면(main.gd) 핸들러 흐름은 qa_capture.gd(--layout-only 포함)가 밟는다. ---
		test_growth_bowl_and_portrait_art, test_staff_layout_and_scene,
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
	# 적응: 노트 용량이 조리대 확장에서 파생되므로(기본 6) 30개 상한 시험은 실제 도메인 연산으로 만든 완전 성장 상태(용량 30)에서 한다.
	# 이미 증인 기록 6개가 있으므로 개수 기준은 "처음 개수 + 새로 만든 개수"로 바꿨고, 검사하는 규칙(중복/가격 개정/30개 상한/삭제 후 재시식)은 그대로다.
	var s: GameStateScript = _grown_state()
	var base_count: int = s.record_count()
	var w_start: int = s.wallet
	_apply_cfg(s, _rich_cfg())
	s.set_draft_name("중복 검사")
	var first_try: Dictionary = s.taste()
	_check(bool(first_try["ok"]), "첫 시식: " + str(first_try["message"]))
	var first_id: int = int(first_try["record_id"])
	var dup: Dictionary = s.taste()
	_check(not bool(dup["ok"]) and s.record_count() == base_count + 1, "같은 구성으로 연속 시식하면 새 기록이 생기면 안 돼요")
	_check(s.wallet == w_start - Evaluator.unit_cost(_rich_cfg()), "중복 거부 시 자금이 차감되면 안 돼요")
	s.start_new_recipe()
	s.set_draft_name("다른 이름 같은 구성")
	_check(not bool(s.taste()["ok"]) and s.record_count() == base_count + 1, "이름만 달라도 같은 구성은 거부")
	# 가격을 올려가며 개정해 30개를 채운다.
	s.select_record(first_id)
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
	var last_id: int = int((s.records().back() as Dictionary)["record_id"])
	_check(bool(s.delete_record(last_id)["ok"]), "삭제")
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
			# v2는 이제 정상 버전이므로 아직 존재하지 않는 다음 버전으로 바꿔 거부를 확인한다.
			d["schema_version"] = GameStateScript.SCHEMA_VERSION + 1
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


# ---------- 실시간 영업 런타임 ----------
# 아래 시험은 시간을 게임초 틱으로 직접 진행하므로 실제 시간·렌더러·난수에 의존하지 않는다.

# ---------- 라멘 연구 ----------

## 새 레시피로 시식하고 기록 번호를 돌려준다(이름은 의뢰 id로 구분).
func _taste_as(s: GameStateScript, config: Dictionary, recipe_name: String) -> int:
	s.start_new_recipe()
	_apply_cfg(s, config)
	s.set_draft_name(recipe_name)
	var r: Dictionary = s.taste()
	_check(bool(r["ok"]), "연구 시험용 시식 실패(%s): %s" % [recipe_name, str(r["message"])])
	return int(r.get("record_id", 0))


## 여섯 증인 조합을 모두 시식해 {의뢰 id: 기록 번호}를 만든다.
func _record_all_witnesses(s: GameStateScript) -> Dictionary:
	var ids: Dictionary = {}
	for rid in Research.ids():
		ids[rid] = _taste_as(s, Research.WITNESSES[rid], "시험 " + rid)
	return ids


func _research_state() -> GameStateScript:
	return _state_with_wallet(100000)


func test_research_catalog_and_feasibility() -> void:
	var reqs: Array = Research.requests()
	_check(reqs.size() == 6 and Research.ids().size() == 6, "의뢰는 정확히 6개")
	var seen_ids: Dictionary = {}
	var per_customer: Dictionary = {}
	var basic: int = 0
	var points_total: int = 0
	var cash_total: int = 0
	for r in reqs:
		var req: Dictionary = r
		var id: String = str(req["id"])
		_check(not seen_ids.has(id), "의뢰 id 중복: " + id)
		seen_ids[id] = true
		_check(not Customers.find(str(req["customer"])).is_empty(), "알 수 없는 손님: " + id)
		var tier: String = str(req["tier"])
		_check(tier == Research.TIER_BASIC or tier == Research.TIER_ADVANCED, "단계 값: " + id)
		var key: String = "%s:%s" % [str(req["customer"]), tier]
		per_customer[key] = int(per_customer.get(key, 0)) + 1
		if tier == Research.TIER_BASIC:
			basic += 1
		points_total += int(Research.REWARD_POINTS[tier])
		cash_total += int(Research.REWARD_CASH[tier])
		var conds: Array = req["conditions"]
		_check(conds.size() >= 2, "조건은 점수 + 하나 이상의 절충: " + id)
		if tier == Research.TIER_ADVANCED:
			_check(conds.size() >= 3, "심화는 제약이 둘 이상(점수 제외): " + id)
		var has_score: bool = false
		for c in conds:
			var cd: Dictionary = c
			_check(Research.condition_text(cd) != "", "조건 문구 없음: " + id)
			if str(cd["kind"]) == "score_min":
				has_score = true
				_check(str(cd["customer"]) == str(req["customer"]), "점수 조건은 의뢰한 손님 기준: " + id)
		_check(has_score, "손님별 점수 조건 필요: " + id)
		_check(str(req["dialogue"]) != "" and str(req["hint"]) != "" and str(req["title"]) != "", "대사/힌트/제목: " + id)
		for field in ["title", "dialogue", "hint"]:
			var txt: String = str(req[field])
			_check(txt.find("broth_") < 0 and txt.find("noodle_") < 0 and txt.find("dohyun") < 0, "게임 문구에 내부 id가 보이면 안 돼요: " + id)
	_check(basic == 3, "입문 3개")
	for cid in Customers.ids():
		_check(int(per_customer.get("%s:basic" % cid, 0)) == 1 and int(per_customer.get("%s:advanced" % cid, 0)) == 1, "손님마다 입문 1 + 심화 1: " + cid)
	_check(points_total == 21 and cash_total == 21000, "보상 총량은 유한해요(점수 21, 21,000원): %d/%d" % [points_total, cash_total])
	var last_stage: Dictionary = Research.stage_for(points_total)
	_check(int(last_stage["stage"]) == int(last_stage["stages"]), "모두 완료하면 마지막 칭호 단계")
	_check(str(Research.stage_for(0)["title"]) != str(last_stage["title"]), "칭호는 단계에 따라 달라져요")

	# 증인 조합: 평가기로 직접 다시 계산해 모든 조건을 만족하는지 본다(숫자를 지어내지 않음).
	var witness_configs: Array = []
	for r in reqs:
		var req2: Dictionary = r
		var id2: String = str(req2["id"])
		_check(Research.WITNESSES.has(id2), "증인 조합 없음: " + id2)
		var cfg: Dictionary = Research.WITNESSES[id2]
		_check(Check.config_error(cfg) == "", "증인 구성이 유효해야 해요: " + id2)
		var m: Dictionary = Research.measures_for(cfg, _scores_of(cfg))
		_check(Research.request_met(req2, m), "증인 조합이 조건을 만족해야 해요: %s (점수 %s, 준비 %d초, 원가 %d원, 가격 %d원)" % [id2, str(m["scores"]), int(m["prep"]), int(m["cost"]), int(m["price"])])
		for prev in witness_configs:
			_check(not Check.same_config(prev, cfg), "증인 조합은 서로 달라야 해요(시식 중복 규칙): " + id2)
		witness_configs.append(cfg)
	_end()


## 재료 972가지 x 가격 표본(500원 단위)을 훑어 각 의뢰의 달성 가능성과 "한 레시피가 여섯을 모두 만족하지 못함"을 확인한다.
func test_research_sweep_no_single_recipe() -> void:
	var reqs: Array = Research.requests()
	var satisfying: Dictionary = {}
	var max_together: int = 0
	var all_six: int = 0
	var prices: Array[int] = []
	for p in range(Catalog.PRICE_MIN, Catalog.PRICE_MAX + 1, 500):
		prices.append(p)
	for c in _all_configs():
		var cfg: Dictionary = c
		var m: Dictionary = Research.measures_for(cfg, _scores_of(cfg))
		for price in prices:
			m["price"] = price
			var together: int = 0
			for r in reqs:
				var req: Dictionary = r
				if Research.request_met(req, m):
					together += 1
					var rid: String = str(req["id"])
					satisfying[rid] = int(satisfying.get(rid, 0)) + 1
			max_together = maxi(max_together, together)
			if together == reqs.size():
				all_six += 1
	for rid2 in Research.ids():
		_check(int(satisfying.get(rid2, 0)) >= 1, "전체 재료 훑기에서 달성 조합이 있어야 해요: " + rid2)
	_check(all_six == 0 and max_together < reqs.size(), "한 레시피가 여섯 의뢰를 모두 만족하면 안 돼요 (최대 동시 %d)" % max_together)
	# 입문과 심화는 서로 다른 절충을 요구한다: 어떤 한 조합도 심화 세 개를 동시에 만족하지 못한다.
	var adv_all: int = 0
	for c2 in _all_configs():
		var cfg2: Dictionary = c2
		var m2: Dictionary = Research.measures_for(cfg2, _scores_of(cfg2))
		for price2 in prices:
			m2["price"] = price2
			var n_adv: int = 0
			for r2 in reqs:
				var rq: Dictionary = r2
				if str(rq["tier"]) == Research.TIER_ADVANCED and Research.request_met(rq, m2):
					n_adv += 1
			if n_adv == 3:
				adv_all += 1
	_check(adv_all == 0, "심화 세 개를 한 레시피가 동시에 만족하면 안 돼요")
	_end()


func test_research_unlock_and_one_time_rewards() -> void:
	var s: GameStateScript = _research_state()
	var rec: Dictionary = _record_all_witnesses(s)
	_check(s.research_points() == 0 and s.research_completed_ids().is_empty(), "처음엔 연구 완료가 없어요")
	_check(str(s.research_stage()["title"]) == str(Research.STAGES[0]["title"]), "처음 칭호")
	for rid in ["dohyun_basic", "hayoung_basic", "maru_basic"]:
		_check(s.research_status(rid) == "open", "입문은 처음부터 열림: " + rid)
	for rid2 in ["dohyun_advanced", "hayoung_advanced", "maru_advanced"]:
		_check(s.research_status(rid2) == "locked" and s.research_lock_reason(rid2).find("2") >= 0, "심화는 잠김 + 이유: " + rid2)
		var locked: Dictionary = s.submit_research(rid2, int(rec[rid2]))
		_check(not bool(locked["ok"]), "잠긴 심화는 제출할 수 없어요: " + rid2)
	_check(s.research_points() == 0, "시식/조회만으로 점수가 생기면 안 돼요")

	var w0: int = s.wallet
	var r1: Dictionary = s.submit_research("dohyun_basic", int(rec["dohyun_basic"]))
	_check(bool(r1["ok"]), "도윤 입문 제출: " + str(r1["message"]))
	_check(s.wallet == w0 + Research.REWARD_CASH["basic"] and s.research_points() == 2, "입문 보상: 자금 +2,000 / 점수 2")
	_check(s.research_status("dohyun_basic") == "done", "완료 표시")
	_check(s.research_status("dohyun_advanced") == "locked", "입문 1개로는 심화가 열리지 않아요")
	var snap: String = _json(s)
	var again: Dictionary = s.submit_research("dohyun_basic", int(rec["dohyun_basic"]))
	_check(not bool(again["ok"]) and _json(s) == snap, "같은 의뢰 재제출은 거부되고 아무것도 바뀌지 않아요")
	var other: Dictionary = s.submit_research("dohyun_basic", int(rec["hayoung_basic"]))
	_check(not bool(other["ok"]) and _json(s) == snap, "다른 기록으로도 같은 의뢰는 다시 받을 수 없어요")

	# 시식/선택/삭제/새 레시피는 연구 점수와 자금(시식비 제외)을 바꾸지 않는다.
	var w1: int = s.wallet
	s.select_record(int(rec["maru_basic"]))
	s.start_new_recipe()
	_check(s.research_points() == 2 and s.wallet == w1, "선택/새 레시피는 연구에 영향이 없어요")

	var w2: int = s.wallet
	var r2: Dictionary = s.submit_research("hayoung_basic", int(rec["hayoung_basic"]))
	_check(bool(r2["ok"]) and s.wallet == w2 + 2000 and s.research_points() == 4, "두 번째 입문: 점수 4")
	_check(str(s.research_stage()["title"]) == str(Research.STAGES[1]["title"]), "칭호가 올라가요")
	for rid3 in ["dohyun_advanced", "hayoung_advanced", "maru_advanced"]:
		_check(s.research_status(rid3) == "open", "입문 2개 완료 후 심화 해금: " + rid3)
	_check(not s.research_complete(), "아직 과정 전체 완료가 아니에요")

	var w3: int = s.wallet
	var r3: Dictionary = s.submit_research("maru_advanced", int(rec["maru_advanced"]))
	_check(bool(r3["ok"]) and s.wallet == w3 + 5000 and s.research_points() == 9, "심화 보상: 자금 +5,000 / 점수 +5")
	for rid4 in ["maru_basic", "dohyun_advanced", "hayoung_advanced"]:
		var rr: Dictionary = s.submit_research(rid4, int(rec[rid4]))
		_check(bool(rr["ok"]), "나머지 제출: %s %s" % [rid4, str(rr["message"])])
	_check(s.research_complete() and s.research_points() == 21, "여섯 개 모두 완료하면 점수 21에서 끝나요")
	_check(str(s.research_stage()["title"]) == str(Research.STAGES[Research.STAGES.size() - 1]["title"]), "마지막 칭호")
	_check(s.wallet == w0 + 21000, "여섯 보상의 자금 합은 정확히 21,000원: %d" % (s.wallet - w0))
	var end_snap: String = _json(s)
	for rid5 in Research.ids():
		_check(not bool(s.submit_research(rid5, int(rec[rid5]))["ok"]), "완료 후에는 무엇도 더 받을 수 없어요: " + rid5)
	_check(_json(s) == end_snap, "완료 후 제출 시도는 상태를 바꾸지 않아요")
	_end()


func test_research_check_values() -> void:
	var s: GameStateScript = _research_state()
	var rid: int = _taste_as(s, Research.WITNESSES["maru_advanced"], "측정 시험")
	var rec: Dictionary = s.get_record(rid)
	var chk: Dictionary = s.research_check("maru_advanced", rid)
	_check(bool(chk["all_met"]) and (chk["conditions"] as Array).size() == 4, "증인 기록은 조건 4개를 모두 달성")
	var first: Dictionary = (chk["conditions"] as Array)[0]
	_check(str(first["measured_text"]) == "%d점" % int((rec["scores"] as Dictionary)["maru"]), "측정값은 기록에 저장된 점수 그대로예요")
	for c in chk["conditions"]:
		var cd: Dictionary = c
		_check(bool(cd["met"]) and str(cd["hint"]) == "", "달성한 조건에는 힌트가 없어요")
	# 기본 초안(원가 2,200원)은 도윤 입문의 원가 조건을 넘는다 → 측정값과 사람이 읽을 힌트가 있어야 한다.
	var weak: int = _taste_as(s, _cfg("broth_tonkotsu", "tare_shoyu", "oil_garlic", "noodle_thin", "topping_chashu", "cook_firm", 9000), "원가 시험")
	var wchk: Dictionary = s.research_check("dohyun_basic", weak)
	var cost_cond: Dictionary = (wchk["conditions"] as Array)[1]
	_check(not bool(cost_cond["met"]) and str(cost_cond["measured_text"]) == "2,200원", "원가 측정값 표시: " + str(cost_cond["measured_text"]))
	_check(str(cost_cond["hint"]).find("200원") >= 0, "미충족 힌트는 부족분을 알려요: " + str(cost_cond["hint"]))
	_check(not bool(wchk["all_met"]), "원가 초과 기록은 달성이 아니에요")
	_check(s.research_check("dohyun_basic", 9999).is_empty(), "없는 기록은 판정하지 않아요")
	_end()


func test_research_rejections_do_not_mutate() -> void:
	var s: GameStateScript = _research_state()
	var rec: Dictionary = _record_all_witnesses(s)
	# 적응: 기본 노트 용량이 6이라 일곱 번째 기록(미달 시험)을 위해 이 시험이 쓰지 않는 증인 기록(마루 입문) 하나를 먼저 지운다.
	# 아래 거부 사례는 도윤 입문/하영 심화 기록과 미달 기록만 사용하므로 검사 내용은 그대로다.
	_check(bool(s.delete_record(int(rec["maru_basic"]))["ok"]), "시험 준비: 쓰지 않는 기록 삭제")
	var weak: int = _taste_as(s, _cfg("broth_tonkotsu", "tare_shoyu", "oil_garlic", "noodle_thin", "topping_chashu", "cook_firm", 9000), "미달 시험")
	var snap: String = _json(s)
	var cases: Array = [
		["미충족", "dohyun_basic", weak],
		["알 수 없는 의뢰", "nope", int(rec["dohyun_basic"])],
		["빈 의뢰", "", int(rec["dohyun_basic"])],
		["기록 없음(0)", "dohyun_basic", 0],
		["없는 기록", "dohyun_basic", 9999],
		["음수 기록", "dohyun_basic", -3],
		["잠긴 심화", "hayoung_advanced", int(rec["hayoung_advanced"])],
	]
	for c in cases:
		var arr: Array = c
		var res: Dictionary = s.submit_research(str(arr[1]), int(arr[2]))
		_check(not bool(res["ok"]) and str(res["message"]) != "", "거부돼야 해요: " + str(arr[0]))
		_check(_json(s) == snap, "거부는 상태를 바꾸면 안 돼요: " + str(arr[0]))
	# 시식하지 않은 초안은 기록이 아니므로 어떤 번호로도 제출할 수 없다: 초안만 바꿔도 진행은 그대로.
	_apply_cfg(s, Research.WITNESSES["hayoung_basic"])
	_check(not bool(s.submit_research("hayoung_basic", 0)["ok"]), "초안만으로는 진행할 수 없어요")
	_check(s.research_points() == 0, "초안은 점수를 만들지 않아요")
	_end()


func test_research_service_lock() -> void:
	var s: GameStateScript = _research_state()
	var rec: Dictionary = _record_all_witnesses(s)
	s.select_record(int(rec["dohyun_basic"]))
	var begin: Dictionary = s.begin_service()
	_check(bool(begin["ok"]), "영업 시작: " + str(begin["message"]))
	var snap: String = _json(s)
	var res: Dictionary = s.submit_research("dohyun_basic", int(rec["dohyun_basic"]))
	_check(not bool(res["ok"]) and s.research_points() == 0, "영업 중에는 연구를 제출할 수 없어요")
	_check(_json(s) == snap and s.service_active(), "영업 중 제출 시도는 상태/세션을 건드리지 않아요")
	s.cancel_service()
	var ok: Dictionary = s.submit_research("dohyun_basic", int(rec["dohyun_basic"]))
	_check(bool(ok["ok"]) and s.research_points() == 2, "영업을 끝낸 뒤에는 제출할 수 있어요")
	_end()


func test_research_overflow() -> void:
	var s: GameStateScript = _research_state()
	var rec: Dictionary = _record_all_witnesses(s)
	s.wallet = GameStateScript.MAX_WALLET - 1000
	var snap: String = _json(s)
	var res: Dictionary = s.submit_research("dohyun_basic", int(rec["dohyun_basic"]))
	_check(not bool(res["ok"]) and _json(s) == snap, "보상이 자금 한도를 넘으면 거부되고 아무것도 바뀌지 않아요")
	_check(s.research_status("dohyun_basic") == "open", "거부된 의뢰는 여전히 열려 있어요")
	s.wallet = GameStateScript.MAX_WALLET - 2000
	var edge: Dictionary = s.submit_research("dohyun_basic", int(rec["dohyun_basic"]))
	_check(bool(edge["ok"]) and s.wallet == GameStateScript.MAX_WALLET, "정확히 한도까지는 받을 수 있어요")
	_end()


func test_research_persistence_after_delete() -> void:
	var dir: String = _case_dir("research_roundtrip")
	var saver: SaveServiceScript = SaveServiceScript.new(dir)
	saver.remove_known_files()
	var s: GameStateScript = _research_state()
	var rec: Dictionary = _record_all_witnesses(s)
	_check(bool(s.submit_research("dohyun_basic", int(rec["dohyun_basic"]))["ok"]), "첫 제출")
	_check(bool(s.submit_research("hayoung_basic", int(rec["hayoung_basic"]))["ok"]), "둘째 제출")
	# 제출한 기록을 노트에서 삭제해도 완료는 남는다.
	_check(bool(s.delete_record(int(rec["dohyun_basic"]))["ok"]), "제출한 기록 삭제")
	_check(s.research_status("dohyun_basic") == "done" and s.research_points() == 4, "기록을 지워도 완료/점수가 유지돼요")
	_check(bool(saver.save_state(s)["ok"]), "저장")
	var loaded: GameStateScript = GameStateScript.new()
	var lr: Dictionary = saver.load_into(loaded)
	_check(str(lr["status"]) == "ok", "불러오기: " + str(lr["message"]))
	_check(_json(loaded) == _json(s), "연구 진행이 저장/불러오기 왕복에서 동일해야 해요")
	_check(loaded.research_status("dohyun_basic") == "done" and loaded.research_points() == 4 and loaded.wallet == s.wallet, "불러온 뒤 완료/점수/자금")
	_check(loaded.get_record(int(rec["dohyun_basic"])).is_empty(), "삭제된 기록은 노트에 없어요")
	var snap: String = _json(loaded)
	_check(not bool(loaded.submit_research("dohyun_basic", int(rec["maru_basic"]))["ok"]) and _json(loaded) == snap, "불러온 뒤 같은 의뢰의 보상을 또 받을 수 없어요")
	_check(not bool(loaded.submit_research("hayoung_basic", int(rec["hayoung_basic"]))["ok"]) and _json(loaded) == snap, "남아 있는 기록으로도 재수령 불가")
	# 해금도 파생값이라 불러온 뒤에도 유지되며 다음 보상은 정상 지급된다.
	var w: int = loaded.wallet
	_check(bool(loaded.submit_research("maru_advanced", int(rec["maru_advanced"]))["ok"]) and loaded.wallet == w + 5000, "불러온 뒤 해금된 심화 제출")
	_cleanup_case(saver)
	_end()


func test_research_v1_migration() -> void:
	var dir: String = _case_dir("research_v1")
	var saver: SaveServiceScript = SaveServiceScript.new(dir)
	saver.remove_known_files()
	var src: GameStateScript = _populated_state()
	# 적응: to_dict()는 이제 v3(toppings 배열 + growth)라서, 진짜 v1 파일 모양(topping 문자열, research/growth 없음)을 _as_legacy()로 만든다.
	var v1: Dictionary = _as_legacy(src.to_dict(), 1)
	var v1_text: String = JSON.stringify(v1, "\t", true)
	_write_text(saver.main_path(), v1_text)
	var loaded: GameStateScript = GameStateScript.new()
	var lr: Dictionary = saver.load_into(loaded)
	_check(str(lr["status"]) == "ok", "v1 저장은 이행해 읽어야 해요: " + str(lr["message"]))
	_check(loaded.day == src.day and loaded.wallet == src.wallet and loaded.record_count() == src.record_count(), "v1 이행: 일차/자금/기록 보존")
	_check(str(loaded.records()) == str(src.records()) and loaded.selected_record_id == src.selected_record_id, "v1 이행: 레시피 개정/노트/선택 보존")
	_check(str(loaded.last_report) == str(src.last_report) and loaded.draft_name == src.draft_name, "v1 이행: 보고/초안 보존")
	_check(loaded.research_completed_ids().is_empty() and loaded.research_points() == 0, "v1 이행: 연구 진행은 비어 있음")
	_check(FileAccess.get_file_as_string(saver.main_path()) == v1_text, "불러오기만으로 v1 파일을 바꾸면 안 돼요")
	_check(bool(saver.save_state(loaded)["ok"]), "이행 후 저장")
	_check(FileAccess.get_file_as_string(saver.bak_path()) == v1_text, "첫 v2 저장 때 기존 v1 파일이 백업에 보존돼요")
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(saver.main_path()))
	_check(typeof(parsed) == TYPE_DICTIONARY and int((parsed as Dictionary)["schema_version"]) == GameStateScript.SCHEMA_VERSION and (parsed as Dictionary).has("research") and (parsed as Dictionary).has("growth"), "새 저장은 v3 + research + growth")
	# v1 이행 뒤 연구가 정상 동작한다.
	var rid: int = _taste_as(loaded, Research.WITNESSES["hayoung_basic"], "이행 시험")
	_check(bool(loaded.submit_research("hayoung_basic", rid)["ok"]), "이행한 저장에서 연구 제출")
	# 구조 검사: v1에 research가 있거나 v2에 없으면 변조로 거부한다.
	var bad_v1: Dictionary = JSON.parse_string(v1_text)
	bad_v1["research"] = {"completed": []}
	var probe1: GameStateScript = GameStateScript.new()
	_check(probe1.load_from_dict(bad_v1) != "", "research가 있는 v1은 거부")
	var bad_v2: Dictionary = _as_legacy(_populated_state().to_dict(), 2)
	bad_v2.erase("research")
	var probe2: GameStateScript = GameStateScript.new()
	_check(probe2.load_from_dict(bad_v2) != "", "research가 없는 v2는 거부")
	_cleanup_case(saver)
	_end()


func test_research_malformed_progress() -> void:
	var s: GameStateScript = _research_state()
	var rec: Dictionary = _record_all_witnesses(s)
	for rid in ["dohyun_basic", "hayoung_basic", "maru_advanced"]:
		_check(bool(s.submit_research(rid, int(rec[rid]))["ok"]), "픽스처 제출: " + rid)
	var parsed: Variant = JSON.parse_string(JSON.stringify(s.to_dict()))
	_check(typeof(parsed) == TYPE_DICTIONARY, "왕복 파싱")
	var base: Dictionary = parsed
	var ok_probe: GameStateScript = GameStateScript.new()
	_check(ok_probe.load_from_dict(base) == "" and ok_probe.research_points() == 9, "정상 연구 진행은 float 숫자여도 받아들여요")
	var labels: Array[String] = [
		"알 수 없는 의뢰", "중복 의뢰", "해금 전 심화", "점수 변조", "금액 변조", "기록 번호 범위", "노트 기록과 불일치",
		"미래 완료일", "키 누락", "추가 키", "research 구조", "completed 구조", "항목 7개", "버전 범위", "문자열 점수", "의뢰 id 형식",
	]
	for label in labels:
		var copy: Dictionary = base.duplicate(true)
		var research: Dictionary = {}
		if copy["research"] is Dictionary:
			research = copy["research"]
		var items: Array = research["completed"]
		var e0: Dictionary = items[0]
		var e1: Dictionary = items[1]
		match label:
			"알 수 없는 의뢰":
				e0["request_id"] = "nope_basic"
			"중복 의뢰":
				e1["request_id"] = e0["request_id"]
			"해금 전 심화":
				items.reverse()
			"점수 변조":
				e0["points"] = int(e0["points"]) + 1
			"금액 변조":
				e0["cash"] = 99999
			"기록 번호 범위":
				e0["record_id"] = 99999
			"노트 기록과 불일치":
				e0["recipe_name"] = "다른 이름"
			"미래 완료일":
				e0["day"] = int(copy["day"]) + 5
			"키 누락":
				e0.erase("cash")
			"추가 키":
				e0["bonus"] = 1
			"research 구조":
				copy["research"] = []
			"completed 구조":
				research["completed"] = "x"
			"항목 7개":
				while items.size() < 7:
					items.append(e0.duplicate(true))
			"버전 범위":
				e0["version"] = 0
			"문자열 점수":
				e0["points"] = "2"
			"의뢰 id 형식":
				e0["request_id"] = 5
			_:
				_failures.append("알 수 없는 변조 이름: " + label)
		var target: GameStateScript = GameStateScript.new()
		var snapshot: String = _json(target)
		var err: String = target.load_from_dict(copy)
		_check(err != "", "연구 진행 거부돼야 해요: " + label)
		_check(_json(target) == snapshot, "거부된 연구 진행 로드는 상태를 바꾸면 안 돼요: " + label)
	_end()


## 구성에 비해 위조된(범위 안) 점수로는 조건을 통과할 수 없다: 평가기의 새 계산값과 다르면 판정 자체를 거부한다.
func test_research_rejects_fabricated_scores() -> void:
	var cfg: Dictionary = _cfg("broth_tonkotsu", "tare_shoyu", "oil_garlic", "noodle_thin", "topping_chashu", "cook_firm", 7500)
	var real: Dictionary = _scores_of(cfg)
	var honest: Dictionary = Research.check("maru_basic", cfg, real)
	_check(str(honest["error"]) == "" and not bool(honest["all_met"]), "정상 점수로는 이 구성이 마루 입문을 못 채워요")
	var fake: Dictionary = real.duplicate(true)
	fake["maru"] = 99
	var forged: Dictionary = Research.check("maru_basic", cfg, fake)
	_check(str(forged["error"]) != "" and not bool(forged["all_met"]), "위조 점수는 오류로 거부돼야 해요")
	var missing: Dictionary = real.duplicate(true)
	missing.erase("maru")
	_check(str(Research.check("maru_basic", cfg, missing)["error"]) != "", "점수 누락도 거부")
	# 정상 증인 구성은 진짜 점수로 여전히 통과한다.
	var w: Dictionary = Research.WITNESSES["maru_basic"]
	_check(bool(Research.check("maru_basic", w, _scores_of(w))["all_met"]), "증인은 정상 점수로 통과")
	_end()


## 노트에 남은 기록이 조건을 못 채우는데 형식만 맞는 완료 영수증은 불러오기에서 거부된다. 삭제된 기록의 완료는 그대로 유효하다.
func test_research_load_rejects_unmet_retained_record() -> void:
	var s: GameStateScript = _research_state()
	var bad_id: int = _taste_as(s, _cfg("broth_tonkotsu", "tare_shoyu", "oil_garlic", "noodle_thin", "topping_chashu", "cook_firm", 7500), "미달 기록")
	var good_id: int = _taste_as(s, Research.WITNESSES["maru_basic"], "달성 기록")
	_check(not bool(s.submit_research("maru_basic", bad_id)["ok"]), "미달 기록은 정상 경로에서도 거부")
	var base: Dictionary = JSON.parse_string(JSON.stringify(s.to_dict()))
	var forged: Dictionary = base.duplicate(true)
	var items: Array = (forged["research"] as Dictionary)["completed"]
	items.append(JSON.parse_string(JSON.stringify(Research.make_entry("maru_basic", s.get_record(bad_id), s.day))))
	var target: GameStateScript = GameStateScript.new()
	var snapshot: String = _json(target)
	_check(target.load_from_dict(forged) != "", "남은 미달 기록에 묶인 완료는 거부")
	_check(_json(target) == snapshot, "거부된 로드는 상태를 전혀 바꾸지 않아요")
	# 정상 완료 → 저장 구조 왕복 → 기록 삭제 후에도 유효.
	_check(bool(s.submit_research("maru_basic", good_id)["ok"]), "정상 제출")
	var ok_dict: Dictionary = JSON.parse_string(JSON.stringify(s.to_dict()))
	var loaded: GameStateScript = GameStateScript.new()
	_check(loaded.load_from_dict(ok_dict) == "" and loaded.research_status("maru_basic") == "done", "정상 완료는 불러와져요")
	_check(bool(s.delete_record(good_id)["ok"]), "달성 기록 삭제")
	var after_delete: Dictionary = JSON.parse_string(JSON.stringify(s.to_dict()))
	var reloaded: GameStateScript = GameStateScript.new()
	_check(reloaded.load_from_dict(after_delete) == "" and reloaded.research_status("maru_basic") == "done" and reloaded.research_points() == 2, "삭제된 기록의 완료는 유효")
	_end()


## 준비 시간 73초(가장 빠른 축)인 레시피: 서버/자리 병목 없이 요리사 속도만 보게 하는 기준.
# ---------- 시식 준비 작업 / 초상 / 글자 없는 장면 ----------

func test_tasting_work_state() -> void:
	var w: WorkScript = WorkScript.new()
	_check(WorkScript.DURATION >= 3.0 and WorkScript.DURATION <= 5.0, "준비 시간은 3~5초")
	_check(not w.is_running() and not w.advance(1.0) and w.progress() == 0.0, "시작 전 진행은 무시")
	var snap: Dictionary = {"config": _rich_cfg(), "name": "원본", "lineage_id": 0}
	_check(w.start(snap), "시작")
	_check(w.is_running() and w.progress() == 0.0, "시작 직후 진행률 0")
	# 시작 스냅샷은 호출자 사본과 분리된다(바깥 딕셔너리를 바꿔도, 꺼낸 사본을 바꿔도 안 변함).
	(snap["config"] as Dictionary)["price"] = 1
	snap["name"] = "바뀜"
	_check(int((w.snapshot()["config"] as Dictionary)["price"]) == 9500 and str(w.snapshot()["name"]) == "원본", "시작 뒤 원본 변경이 스냅샷에 영향 없음")
	var copy: Dictionary = w.snapshot()
	(copy["config"] as Dictionary)["price"] = 2
	copy["name"] = "사본변경"
	_check(int((w.snapshot()["config"] as Dictionary)["price"]) == 9500 and str(w.snapshot()["name"]) == "원본", "snapshot() 사본의 중첩 변경이 내부 스냅샷에 영향 없음")
	# 중복 시작 거부: 진행/스냅샷이 그대로
	_check(w.advance(1.0) == false and absf(w.progress() - 0.25) < 0.0001, "1초 진행 = 25%")
	_check(not w.start({"config": _light_cfg(), "name": "다른", "lineage_id": 0}), "작업 중 중복 시작 거부")
	_check(absf(w.progress() - 0.25) < 0.0001 and str(w.snapshot()["name"]) == "원본", "중복 시작이 진행/스냅샷을 바꾸지 않음")
	# 비정상 시간: NaN/무한대/음수/0 은 진행도 완료도 만들지 않는다.
	for bad in [NAN, INF, -INF, -1.0, 0.0]:
		_check(w.advance(float(bad)) == false and w.is_running() and absf(w.progress() - 0.25) < 0.0001, "비정상 시간 무시: " + str(bad))
	# 완료는 정확히 한 번
	var done_count: int = 0
	for i in 20:
		if w.advance(0.5):
			done_count += 1
	_check(done_count == 1, "완료 신호는 정확히 한 번: %d" % done_count)
	_check(not w.is_running() and w.advance(5.0) == false, "완료 뒤 추가 진행은 무시")
	var taken: Dictionary = w.take_snapshot()
	_check(str(taken["name"]) == "원본" and w.take_snapshot().is_empty(), "스냅샷은 한 번만 꺼낼 수 있어요")
	# 큰 값 한 번에 완료
	_check(w.start(snap) and w.advance(100.0) and not w.is_running(), "완료 뒤 다시 시작 가능, 큰 시간은 한 번에 완료")
	# 취소: 완료 신호 없음, 상태 초기화
	var c: WorkScript = WorkScript.new()
	c.start(snap)
	c.advance(1.0)
	c.cancel()
	_check(not c.is_running() and c.progress() == 0.0 and c.snapshot().is_empty(), "취소하면 초기화")
	_check(c.advance(100.0) == false and c.take_snapshot().is_empty(), "취소 뒤 진행/완료 없음")
	c.cancel()
	_check(not c.is_running(), "취소 반복은 무해")
	_end()


func test_tasting_work_phases_and_motion() -> void:
	var ends: Array = []
	for ph in WorkScript.PHASES:
		ends.append(float((ph as Dictionary)["end"]))
	_check(WorkScript.PHASES.size() == 3 and float(ends[2]) == 1.0 and float(ends[0]) < float(ends[1]) and float(ends[1]) < float(ends[2]), "세 단계, 경계는 증가하고 마지막은 1.0")
	_check(WorkScript.phase_for(0.0) == 0 and WorkScript.phase_for(0.44) == 0 and WorkScript.phase_for(0.45) == 1 and WorkScript.phase_for(0.79) == 1 and WorkScript.phase_for(0.8) == 2 and WorkScript.phase_for(1.0) == 2, "진행률별 단계")
	var w: WorkScript = WorkScript.new()
	w.start({"config": _rich_cfg()})
	var seen: Array[int] = []
	for i in 16:
		w.advance(0.25)
		var ph: int = w.phase_index()
		if seen.is_empty() or seen[seen.size() - 1] != ph:
			seen.append(ph)
	_check(str(seen) == "[0, 1, 2]","단계가 국물→면→시식 순서로 한 번씩: " + str(seen))
	# 연출 계산: 결정적이고, 진행/시간에 따라 실제로 달라진다.
	var a: Dictionary = WorkViewScript.frame_params(0.3, 0.1)
	_check(a == WorkViewScript.frame_params(0.3, 0.1), "같은 입력은 같은 연출 값")
	var prev_level: float = -1.0
	for i in 10:
		var lv: float = float(WorkViewScript.frame_params(float(i) * 0.05, 0.0)["level"])
		_check(lv >= prev_level, "국물 높이는 줄지 않아요")
		prev_level = lv
	_check(float(WorkViewScript.frame_params(0.0, 0.0)["level"]) == 0.0 and float(WorkViewScript.frame_params(0.45, 0.0)["level"]) == 1.0, "국물은 빈 솥에서 가득까지")
	_check(float(WorkViewScript.frame_params(0.2, 0.0)["depth"]) == 0.0 and float(WorkViewScript.frame_params(0.625, 0.0)["depth"]) > 0.5 and float(WorkViewScript.frame_params(0.9, 0.0)["depth"]) == 0.0, "면 건지개는 면 단계에서만 잠겨요")
	_check(float(WorkViewScript.frame_params(0.7, 0.0)["transfer"]) == 0.0 and float(WorkViewScript.frame_params(0.9, 0.0)["transfer"]) > 0.0, "면 옮기기는 시식 단계에서만")
	_check(float(WorkViewScript.frame_params(0.9, 0.0)["bowl_alpha"]) > float(WorkViewScript.frame_params(0.5, 0.0)["bowl_alpha"]), "그릇은 시식 단계에서 또렷해져요")
	_check(int(WorkViewScript.frame_params(0.3, 0.0)["flame"]) != int(WorkViewScript.frame_params(0.3, 0.13)["flame"]), "불꽃이 시간에 따라 일렁여요")
	var view: WorkViewScript = WorkViewScript.new()
	view.set_state(0.3, _rich_cfg())
	var sig_a: String = view.signature()
	view.set_state(0.6, _rich_cfg())
	_check(sig_a != view.signature(), "진행이 달라지면 연출 서명이 달라져요")
	view.free()
	_end()


func _diff_pixels(a: Image, b: Image) -> int:
	var n: int = 0
	for y in a.get_height():
		for x in a.get_width():
			if a.get_pixel(x, y) != b.get_pixel(x, y):
				n += 1
	return n


func test_portraits_and_glyph_free_art() -> void:
	var ids: Array = ArtScript.portrait_ids()
	_check(str(ids) == str(Customers.ids()), "초상은 단골 세 분과 같은 id: " + str(ids))
	var imgs: Array[Image] = []
	for id in ids:
		var img: Image = ArtScript.portrait_image(str(id))
		_check(img.get_width() == 24 and img.get_height() == 24, "초상 크기 24x24: " + str(id))
		var colors: Dictionary = {}
		for y in 24:
			for x in 24:
				colors[img.get_pixel(x, y).to_html()] = true
		_check(colors.size() >= 8, "초상 색 수 %d: %s" % [colors.size(), str(id)])
		# 이미지는 RGBA8 이라 get_pixel 이 8비트로 양자화된 값을 돌려준다(부동소수 INK 와 직접 비교하면 어긋남).
		# 기대값도 같은 RGBA8 1x1 이미지에 넣었다 읽어 같은 표현으로 비교한다.
		var ink_probe: Image = ArtScript.new_image(1, 1)
		ink_probe.set_pixel(0, 0, ArtScript.INK)
		var ink8: Color = ink_probe.get_pixel(0, 0)
		_check(img.get_pixel(0, 0) == ink8 and img.get_pixel(23, 0) == ink8 and img.get_pixel(0, 23) == ink8 and img.get_pixel(23, 23) == ink8, "초상 테두리(RGBA8 INK): " + str(id))
		imgs.append(img)
	for i in imgs.size():
		for j in range(i + 1, imgs.size()):
			_check(_diff_pixels(imgs[i], imgs[j]) >= 150, "초상 %s/%s 가 충분히 달라요: %d픽셀" % [str(ids[i]), str(ids[j]), _diff_pixels(imgs[i], imgs[j])])
	_check(ArtScript.portrait_image("nobody").get_pixel(12, 12) != ArtScript.SKIN, "알 수 없는 id 는 얼굴 없는 빈 틀")
	_check(ArtScript.open_lamp_image(true).get_data() != ArtScript.open_lamp_image(false).get_data(), "영업 등 켜짐/꺼짐이 달라요")
	var lamp: Image = ArtScript.open_lamp_image(true)
	_check(lamp.get_width() == 11 and lamp.get_height() == 8, "영업 등 크기")
	# 장면 코드에는 글자 그리기가 없다(간판/대기 인원/영업 등 모두 도트).
	for path in ["res://scripts/ui/shop_view.gd", "res://scripts/ui/shop_painter.gd", "res://scripts/ui/shop_scene.gd", "res://scripts/ui/tasting_work_view.gd"]:
		if not FileAccess.file_exists(path):
			continue
		var f: FileAccess = FileAccess.open(path, FileAccess.READ)
		_check(f != null, "코드 파일을 읽을 수 있어요: " + path)
		if f == null:
			continue
		var src: String = f.get_as_text()
		_check(src.find("draw_string") < 0 and src.find("draw_multiline_string") < 0 and src.find("GowunDodum") < 0, "장면 그리기 코드에 글자 그리기가 없어야 해요: " + path)
	# 간판이 있는 세로/가로 배경 모두 여전히 그려지고 불투명하다.
	for variant in [LayoutScript.PORTRAIT, LayoutScript.LANDSCAPE]:
		var bg: Image = PainterScript.paint(LayoutScript.make(variant))
		_check(bg.get_pixel(bg.get_width() / 2, bg.get_height() / 2).a == 1.0, variant + ": 간판 문양을 넣은 배경이 그려져요")
	_end()


func _fast_cfg(price: int = 9000) -> Dictionary:
	return _cfg("broth_chicken", "tare_shio", "oil_scallion", "noodle_thin", "topping_nori", "cook_firm", price)


func _state_with_recipe(config: Dictionary, wallet: int = 100000) -> GameStateScript:
	var s: GameStateScript = _state_with_wallet(wallet)
	_apply_cfg(s, config)
	s.set_draft_name("영업 시험")
	var r: Dictionary = s.taste()
	_check(bool(r["ok"]), "시험용 시식 실패: " + str(r["message"]))
	return s


func _arrival(t: int, source: String = "walkin") -> Dictionary:
	return {"t": t, "source": source, "will_order": true}


func _plan_with(rec: Dictionary, day: int, arrivals: Array) -> Dictionary:
	var plan: Dictionary = SessionScript.make_plan(rec, day)
	_check(str(plan["error"]) == "", "계획 생성 실패: " + str(plan["error"]))
	plan["arrivals"] = arrivals
	return plan


func _json(s: GameStateScript) -> String:
	return JSON.stringify(s.to_dict(), "\t", true)


func test_service_plan_deterministic() -> void:
	var s: GameStateScript = _state_with_recipe(_rich_cfg())
	var rec: Dictionary = s.get_record(s.selected_record_id)
	for day in [1, 3, 6]:
		var a: Dictionary = SessionScript.make_plan(rec, day)
		var b: Dictionary = SessionScript.make_plan(rec, day)
		_check(str(a["error"]) == "" and str(a) == str(b), "같은 레시피·같은 날의 계획은 같아야 해요 (%d일차)" % day)
		var fc: Dictionary = a["forecast"]
		var by_source: Dictionary = fc["by_source"]
		var counts: Dictionary = {}
		var orders: int = 0
		var lost: int = 0
		var in_window: bool = true
		for x in a["arrivals"]:
			var ar: Dictionary = x
			if int(ar["t"]) < 5 or int(ar["t"]) > SessionScript.ARRIVAL_SPAN + 12:
				in_window = false
			if bool(ar["will_order"]):
				orders += 1
				counts[str(ar["source"])] = int(counts.get(str(ar["source"]), 0)) + 1
			else:
				lost += 1
		_check(in_window, "도착 시각이 영업 시간 안이어야 해요 (%d일차)" % day)
		_check(orders == int(fc["units"]), "주문 손님 수 = 영업 시뮬레이션 판매량 (%d일차)" % day)
		_check(lost == int(fc["demand"]) - int(fc["units"]), "돌아가는 손님 수 = 수요 - 판매량 (%d일차)" % day)
		for id in by_source:
			_check(int(counts.get(id, 0)) == int(by_source[id]), "손님별 도착 수가 시뮬레이션과 같아야 해요: " + str(id))
	# 스냅샷: 계획 이후 레시피/상태를 바꿔도 이미 만든 계획의 구성은 변하지 않는다.
	var plan: Dictionary = SessionScript.make_plan(rec, 1)
	var frozen: String = str(plan["config"])
	s.set_draft_price(12000)
	_check(str(plan["config"]) == frozen and int((plan["config"] as Dictionary)["price"]) == 9500, "계획은 레시피 스냅샷을 복사해 가져야 해요")
	_end()


func test_service_lifecycle_order() -> void:
	var s: GameStateScript = _state_with_recipe(_fast_cfg())
	var rec: Dictionary = s.get_record(s.selected_record_id)
	var sess: SessionScript = SessionScript.new(_plan_with(rec, 1, [_arrival(10)]))
	var seen: Array[int] = []
	var invariant_ok: bool = true
	var guard: int = 0
	while sess.state == SessionScript.RUNNING and guard < 5000:
		sess.tick()
		guard += 1
		var p: SessionScript.Patron = sess._patrons[0]
		if p.spawned and (seen.is_empty() or seen[seen.size() - 1] != p.state):
			seen.append(p.state)
		# 완료 주문 수는 식사를 마친(퇴장 중이거나 떠난) 손님 수와 늘 같다: 식사 전에는 한 건도 완료되지 않는다.
		var finished_orders: int = 1 if (p.state == SessionScript.P_LEAVING or p.state == SessionScript.P_GONE) else 0
		if sess.completed.size() != finished_orders:
			invariant_ok = false
	_check(invariant_ok, "주문은 식사가 끝난 틱에만 완료로 기록돼야 해요")
	_check(sess.state == SessionScript.FINISHED, "하루가 끝나야 해요")
	# 주문 → 조리 → 서빙 → 식사 → 퇴장 순서(줄 서기와 자리 배정이 같은 틱이라 TO_SEAT 로 바로 이어진다)
	var expected: Array[int] = [SessionScript.P_APPROACH, SessionScript.P_TO_SEAT, SessionScript.P_ORDERING,
		SessionScript.P_WAITING, SessionScript.P_EATING, SessionScript.P_LEAVING, SessionScript.P_GONE]
	_check(seen == expected, "손님 상태 순서가 맞아야 해요: " + str(seen))
	_check(sess.completed.size() == 1, "손님 1명 = 완료 주문 1건")
	var done: Dictionary = sess.completed[0]
	# 도착 10 + 접근 40(첫 틱 포함 -1) + 자리까지 걷기 + 주문 + 조리(준비 시간) + 서빙 + 식사. 대기·병목이 없으니 정확히 일치한다.
	var expected_done: int = 10 + (SessionScript.APPROACH_GS - 1) + SessionScript.SEAT_WALK[0] + SessionScript.ORDER_GS + sess.prep + SessionScript.SEAT_SERVE[0] + SessionScript.EAT_GS
	_check(int(done["done_t"]) == expected_done, "완료 시각이 걷기+주문+조리+서빙+식사 합과 같아야 해요: %d vs %d" % [int(done["done_t"]), expected_done])
	_check(int(done["seat"]) == 0 and int(done["price"]) == 9000, "빈 자리 중 가장 앞 번호에 앉고 가격은 스냅샷 값이어야 해요")
	var sm: Dictionary = sess.summary()
	_check(int(sm["units"]) == 1 and int(sm["revenue"]) == 9000 and int(sm["finished_at"]) >= SessionScript.SERVICE_SECONDS, "요약은 완료 주문에서만 나와요")
	_end()


func test_service_queue_and_seat_reuse() -> void:
	var s: GameStateScript = _state_with_recipe(_fast_cfg())
	var rec: Dictionary = s.get_record(s.selected_record_id)
	var arrivals: Array = []
	for i in 24:
		arrivals.append(_arrival(5 + i * 2))
	var sess: SessionScript = SessionScript.new(_plan_with(rec, 1, arrivals))
	var max_queue: int = 0
	var max_seated: int = 0
	var guard: int = 0
	while sess.state == SessionScript.RUNNING and guard < SessionScript.HARD_LIMIT + 10:
		sess.tick()
		guard += 1
		var st: Dictionary = sess.stats()
		max_queue = maxi(max_queue, int(st["queue"]))
		max_seated = maxi(max_seated, int(st["seated"]))
	_check(sess.state == SessionScript.FINISHED, "24명이 몰려도 하루는 끝나야 해요")
	_check(sess.completed.size() == 24, "24명 모두 식사를 마쳐야 해요: %d" % sess.completed.size())
	_check(max_queue > 0, "자리(8)보다 손님이 많으면 줄이 생겨야 해요")
	_check(max_seated == SessionScript.SEAT_COUNT, "동시에 앉은 손님은 자리 수와 같아질 수 있고 넘지 않아요: %d" % max_seated)
	_check(sess.seat_log.size() == 24, "자리 사용 기록은 손님 수와 같아야 해요")
	var per_seat: Dictionary = {}
	var order_ok: bool = true
	var last_patron: int = -1
	for e in sess.seat_log:
		var d: Dictionary = e
		if int(d["patron"]) < last_patron:
			order_ok = false
		last_patron = int(d["patron"])
		var list: Array = per_seat.get(int(d["seat"]), [])
		list.append(d)
		per_seat[int(d["seat"])] = list
	_check(order_ok, "줄은 선착순으로 자리를 받아야 해요")
	var reused: bool = false
	var no_overlap: bool = true
	for seat in per_seat:
		var uses: Array = per_seat[seat]
		if uses.size() >= 2:
			reused = true
		for k in range(1, uses.size()):
			var prev: Dictionary = uses[k - 1]
			var cur: Dictionary = uses[k]
			if int(prev["to"]) < 0 or int(cur["from"]) < int(prev["to"]) + SessionScript.SEAT_CLEAR_GS:
				no_overlap = false
		var tail: Dictionary = uses[uses.size() - 1]
		if int(tail["to"]) < 0:
			no_overlap = false
	_check(reused, "한 자리를 여러 손님이 이어서 써야 해요")
	_check(no_overlap, "한 자리에 두 손님이 겹치거나 비우지 않고 앉으면 안 돼요")
	_end()


func test_service_money_matches_runtime() -> void:
	var configs: Array[Dictionary] = [_rich_cfg(), _light_cfg(), _spicy_cfg(), _fast_cfg(8000), _rich_cfg(30000)]
	for cfg in configs:
		var s: GameStateScript = _state_with_recipe(cfg, 200000)
		for step in 4:
			var day_before: int = s.day
			var wallet_before: int = s.wallet
			var fc: Dictionary = s.forecast()
			var started: Dictionary = s.begin_service()
			_check(bool(started["ok"]), "영업 시작: " + str(started["message"]))
			if not bool(started["ok"]):
				break
			_check(s.day == day_before and s.wallet == wallet_before, "시작은 자금/일차를 바꾸면 안 돼요")
			var sess: SessionScript = s.active_session()
			_check(sess.run_to_end(), "하루는 끝나야 해요")
			# 끝났어도 정산 전에는 자금/일차가 그대로(미정산 매출만 있음)
			_check(s.wallet == wallet_before and s.day == day_before, "정산 전에는 자금/일차 불변")
			var price: int = int((sess.config as Dictionary)["price"])
			_check(sess.pending_revenue() == sess.completed.size() * price, "미정산 매출 = 완료 주문 x 가격")
			var sm: Dictionary = sess.summary()
			var finished_at: int = int(sm["finished_at"])
			# 정상 배속(초당 36게임초)에서 90초 이내, 점심 피크(2400)보다는 짧을 수 없다.
			_check(finished_at >= SessionScript.SERVICE_SECONDS and finished_at <= 3240, "하루 길이가 범위를 벗어났어요: %d" % finished_at)
			var res: Dictionary = s.settle_service()
			_check(bool(res["ok"]), "정산: " + str(res["message"]))
			var rep: Dictionary = s.last_report
			_check(int(rep["units"]) == sess.completed.size() and int(rep["units"]) == int(fc["units"]), "보고 판매량 = 완료 주문 수 = 예상 판매량")
			var revenue_sum: int = 0
			var cost_sum: int = 0
			for c in sess.completed:
				var cd: Dictionary = c
				revenue_sum += int(cd["price"])
				cost_sum += int(cd["unit_cost"])
			_check(int(rep["revenue"]) == revenue_sum and int(rep["ingredient_cost"]) == cost_sum, "보고 매출/재료비 = 완료 주문 합")
			_check(int(rep["net"]) == revenue_sum - cost_sum - Sim.OVERHEAD, "순이익 식")
			_check(int(rep["net"]) == int(fc["net"]), "런타임 결과가 도메인 예측과 같아야 해요")
			_check(s.wallet == wallet_before + int(rep["net"]) and int(rep["wallet_after"]) == s.wallet, "자금 = 이전 + 순이익")
			_check(s.day == day_before + 1 and int(rep["day"]) == day_before, "영업 1회 = 정확히 1일")
			var by_source: Dictionary = rep["by_source"]
			var fc_by: Dictionary = fc["by_source"]
			var sum_src: int = 0
			for k in by_source:
				sum_src += int(by_source[k])
				_check(int(by_source[k]) == int(fc_by[k]), "손님별 판매 = 예측: " + str(k))
			_check(sum_src == int(rep["units"]), "손님별 합 = 총 판매")
			_check(not s.service_active() and sess.settled, "정산 후 세션은 닫혀야 해요")
			# 저장 검증을 그대로 통과한다(보고서 식 검증 포함)
			var parsed: Variant = JSON.parse_string(JSON.stringify(s.to_dict()))
			var loaded: GameStateScript = GameStateScript.new()
			_check(loaded.load_from_dict(parsed) == "", "정산 후 상태는 저장 검증을 통과해야 해요")
	_end()


func test_service_quality_changes_arrivals_and_reactions() -> void:
	# 같은 요리를 싸게/비싸게 팔면 도착하는 손님 수가 달라진다(수요가 레시피 스냅샷에서 온다).
	var cheap: GameStateScript = _state_with_recipe(_rich_cfg(8000))
	var pricey: GameStateScript = _state_with_recipe(_rich_cfg(12000))
	var plan_cheap: Dictionary = SessionScript.make_plan(cheap.get_record(cheap.selected_record_id), 2)
	var plan_pricey: Dictionary = SessionScript.make_plan(pricey.get_record(pricey.selected_record_id), 2)
	var n_cheap: int = 0
	var n_pricey: int = 0
	for x in plan_cheap["arrivals"]:
		if bool((x as Dictionary)["will_order"]):
			n_cheap += 1
	for y in plan_pricey["arrivals"]:
		if bool((y as Dictionary)["will_order"]):
			n_pricey += 1
	_check(n_cheap > n_pricey, "싼 가격이 더 많은 손님을 부르고 화면에도 그만큼 도착해야 해요 (%d vs %d)" % [n_cheap, n_pricey])

	# 맛 점수가 높으면 만족 반응(하트), 낮으면 불만 반응(화남)이 식사 장면에서 실제로 나온다.
	var base: GameStateScript = _state_with_recipe(_fast_cfg())
	var rec: Dictionary = base.get_record(base.selected_record_id)
	var bubbles_good: Dictionary = {}
	var bubbles_bad: Dictionary = {}
	var stars_good: Array[int] = []
	var stars_bad: Array[int] = []
	for variant in 2:
		var plan: Dictionary = _plan_with(rec, 1, [_arrival(10), _arrival(400)])
		var level: int = 100 if variant == 0 else 10
		plan["scores"] = {"dohyun": level, "hayoung": level, "maru": level}
		var sess: SessionScript = SessionScript.new(plan)
		var guard: int = 0
		while sess.state == SessionScript.RUNNING and guard < SessionScript.HARD_LIMIT + 10:
			sess.tick()
			guard += 1
			for pe in sess.entities()["patrons"]:
				var pd: Dictionary = pe
				var kind: String = str(pd["bubble"])
				if kind != "":
					if variant == 0:
						bubbles_good[kind] = true
					else:
						bubbles_bad[kind] = true
		for c in sess.completed:
			var cd: Dictionary = c
			if variant == 0:
				stars_good.append(int(cd["stars"]))
			else:
				stars_bad.append(int(cd["stars"]))
	_check(bubbles_good.has("heart") and not bubbles_good.has("angry"), "좋은 메뉴는 하트 반응: " + str(bubbles_good.keys()))
	_check(bubbles_bad.has("angry") and not bubbles_bad.has("heart"), "나쁜 메뉴는 불만 반응: " + str(bubbles_bad.keys()))
	_check(str(stars_good) == "[5, 5]" and str(stars_bad) == "[1, 1]","완료 주문의 만족도는 점수에서 나와요: %s / %s" % [str(stars_good), str(stars_bad)])

	# 한꺼번에 몰리면 오래 기다린 손님의 만족도가 한 단계 떨어진다.
	var crowd_plan: Dictionary = _plan_with(rec, 1, [_arrival(5), _arrival(5), _arrival(5), _arrival(5), _arrival(5), _arrival(5)])
	crowd_plan["scores"] = {"dohyun": 100, "hayoung": 100, "maru": 100}
	var crowd: SessionScript = SessionScript.new(crowd_plan)
	_check(crowd.run_to_end(), "몰린 손님도 끝나야 해요")
	var five: int = 0
	var four: int = 0
	var waits_ok: bool = true
	for c2 in crowd.completed:
		var cd2: Dictionary = c2
		if int(cd2["stars"]) == 5:
			five += 1
		elif int(cd2["stars"]) == 4:
			four += 1
		if int(cd2["wait"]) <= 0:
			waits_ok = false
	_check(five >= 1 and four >= 1 and five + four == 6, "앞 손님은 만족, 오래 기다린 손님은 한 단계 낮아야 해요 (%d/%d)" % [five, four])
	_check(waits_ok, "대기 시간이 기록돼야 해요")
	_end()


func test_service_recipe_locking() -> void:
	var s: GameStateScript = _state_with_recipe(_light_cfg())
	var first_id: int = s.selected_record_id
	# 두 번째 기록을 만들어 두고 첫 번째를 선택해 영업한다.
	s.set_draft_choice("noodle", "noodle_medium")
	var second: Dictionary = s.taste()
	_check(bool(second["ok"]), "두 번째 레시피 시식: " + str(second["message"]))
	_check(bool(s.select_record(first_id)["ok"]), "첫 번째 선택")
	var before: String = _json(s)
	var started: Dictionary = s.begin_service()
	_check(bool(started["ok"]), "영업 시작: " + str(started["message"]))
	_check(_json(s) == before, "영업 시작은 저장될 상태를 바꾸지 않아요")
	var sess: SessionScript = s.active_session()
	var captured: String = str(sess.config)
	_check(int(sess.record_id) == first_id, "세션은 선택된 레시피를 캡처해요")
	_check(s.service_active(), "영업 중")

	var attempts: Array[Dictionary] = [
		s.set_draft_choice("broth", "broth_tonkotsu"),
		s.set_draft_price(12000),
		s.set_draft_name("바꾼 이름"),
		s.select_record(int(second["record_id"])),
		s.delete_record(first_id),
		s.taste(),
		s.serve(),
		s.begin_service(),
	]
	for i in attempts.size():
		_check(not bool(attempts[i]["ok"]), "영업 중 변경은 거부돼야 해요 (#%d)" % i)
	s.start_new_recipe()
	_check(s.selected_record_id == first_id and s.draft_lineage_id != 0, "영업 중 새 레시피 시작도 무시돼요")
	_check(s.load_from_dict(s.to_dict()) != "", "영업 중 불러오기 거부")
	_check(_json(s) == before, "거부된 시도는 상태를 전혀 바꾸지 않아요")
	_check(str(sess.config) == captured, "캡처된 레시피는 바뀌지 않아요")

	# 반환된 기록 복사본을 바꿔도 세션의 스냅샷은 그대로
	var tampered: Dictionary = s.get_record(first_id)
	(tampered["config"] as Dictionary)["price"] = 1
	_check(str(sess.config) == captured and int(sess.price) == 9000, "스냅샷은 외부 변경에서 분리돼요")

	# 중단하면 잠금이 풀리고 새 세션은 바뀐 레시피를 캡처한다.
	s.cancel_service()
	_check(not s.service_active(), "중단 후 잠금 해제")
	_check(bool(s.set_draft_price(12000)["ok"]), "중단 후에는 편집 가능")
	_check(bool(s.select_record(int(second["record_id"]))["ok"]), "중단 후에는 선택 가능")
	_check(bool(s.begin_service()["ok"]), "다시 시작")
	_check(int(s.active_session().record_id) == int(second["record_id"]) and str(s.active_session().config) != captured, "새 세션은 새로 선택한 레시피를 캡처해요")
	_end()


func test_service_cancel_and_reload() -> void:
	var dir: String = _case_dir("service_cancel")
	var saver: SaveServiceScript = SaveServiceScript.new(dir)
	saver.remove_known_files()
	var s: GameStateScript = _state_with_recipe(_light_cfg())
	var baseline: String = _json(s)
	var fc: Dictionary = s.forecast()
	_check(int(fc["units"]) > 0, "전제: 이 레시피는 손님이 있어야 해요")
	_check(bool(s.begin_service()["ok"]), "영업 시작")
	var sess: SessionScript = s.active_session()
	sess.advance(1500.0)
	_check(sess.is_running() and sess.completed.size() > 0 and sess.pending_revenue() > 0, "전제: 영업 중간에 일부 주문이 이미 완료돼 있어야 해요")
	_check(_json(s) == baseline, "진행 중 미정산 매출이 있어도 저장될 상태는 영업 전과 같아요")
	# 도중 저장(앱 종료/일시정지)에는 영업 전 상태가 저장된다.
	_check(bool(saver.save_state(s)["ok"]), "도중 저장")
	var early: Dictionary = s.settle_service()
	_check(not bool(early["ok"]) and _json(s) == baseline and s.service_active(), "끝나지 않은 영업은 정산 거부(부분 정산 없음)")
	s.cancel_service()
	_check(not s.service_active() and sess.state == SessionScript.CANCELLED, "중단")
	_check(str(sess.summary()["error"]) != "", "중단된 세션은 정산 입력을 만들지 못해요")
	_check(not bool(s.settle_service()["ok"]) and _json(s) == baseline, "중단 뒤 정산 불가, 상태 불변")
	# 재시작: 저장 파일을 새 상태로 불러오면 영업 전 상태이고 진행 중 세션은 없다.
	var loaded: GameStateScript = GameStateScript.new()
	var lr: Dictionary = saver.load_into(loaded)
	_check(str(lr["status"]) == "ok", "재불러오기: " + str(lr["message"]))
	_check(not loaded.service_active() and loaded.day == 1 and loaded.wallet == s.wallet, "재시작하면 영업 전 일차/자금")
	_check(_json(loaded) == baseline, "재시작 상태 = 영업 전 상태")
	_check(loaded.last_report.is_empty(), "저장된 보고는 없어요(영업을 끝내지 않았으므로)")
	# 다시 시작하면 처음부터(이전 진행 이어받지 않음)
	_check(bool(loaded.begin_service()["ok"]), "다시 시작")
	var again: SessionScript = loaded.active_session()
	_check(again != sess and again.time == 0 and again.completed.is_empty(), "새 세션은 처음부터 시작해요")
	_cleanup_case(saver)
	_end()


func test_service_settlement_guards() -> void:
	var s: GameStateScript = _state_with_recipe(_light_cfg())
	_check(not bool(s.settle_service()["ok"]), "세션이 없으면 정산 불가")
	_check(bool(s.begin_service()["ok"]), "영업 시작")
	var sess: SessionScript = s.active_session()
	var day0: int = s.day
	var snap_start: String = _json(s)
	_check(not bool(s.settle_service()["ok"]) and _json(s) == snap_start, "시작 직후 정산 거부")
	sess.advance(400.0)
	_check(not bool(s.settle_service()["ok"]) and _json(s) == snap_start, "진행 중 정산 거부")
	_check(sess.run_to_end(), "끝까지 진행")
	var snap: String = _json(s)
	_check(sess.completed.size() > 0, "전제: 완료 주문이 있어야 해요")

	# (a) 일차 불일치
	s.day += 1
	_check(not bool(s.settle_service()["ok"]), "일차가 달라지면 정산 거부")
	s.day -= 1
	_check(_json(s) == snap, "(a) 거부 후 상태 불변")
	# (b) 선택 레시피 불일치
	var sel: int = s.selected_record_id
	s.selected_record_id = 0
	_check(not bool(s.settle_service()["ok"]), "선택 레시피가 달라지면 정산 거부")
	s.selected_record_id = sel
	_check(_json(s) == snap, "(b) 거부 후 상태 불변")
	# (c) 부풀린 완료 목록(주문 하나 더)
	sess.completed.append((sess.completed[0] as Dictionary).duplicate(true))
	_check(not bool(s.settle_service()["ok"]), "도메인 한도를 넘는 완료 목록은 정산 거부")
	sess.completed.pop_back()
	_check(_json(s) == snap, "(c) 거부 후 상태 불변")
	# (d) 금액 변조
	var original_price: int = int((sess.completed[0] as Dictionary)["price"])
	(sess.completed[0] as Dictionary)["price"] = 1
	_check(not bool(s.settle_service()["ok"]), "스냅샷 가격과 다른 금액은 정산 거부")
	(sess.completed[0] as Dictionary)["price"] = original_price
	_check(_json(s) == snap, "(d) 거부 후 상태 불변")
	# (e) 자금이 모자라 정산 후 음수가 되는 경우(순이익이 음수일 때만 해당)
	var net: int = int(Sim.simulate(sess.config, sess.scores, day0)["net"])
	if net < 0:
		var saved_wallet: int = s.wallet
		s.wallet = maxi(0, -net - 1)
		_check(not bool(s.settle_service()["ok"]), "자금이 모자라면 정산 거부")
		s.wallet = saved_wallet
		_check(_json(s) == snap, "(e) 거부 후 상태 불변")

	# 정상 정산 1회
	var wallet0: int = s.wallet
	var ok: Dictionary = s.settle_service()
	_check(bool(ok["ok"]), "정상 정산: " + str(ok["message"]))
	var after: String = _json(s)
	_check(s.day == day0 + 1 and s.wallet != wallet0 or net == 0, "정산 후 하루가 지나고 자금이 바뀌어요")
	_check(sess.settled and not s.service_active(), "세션은 정산됨으로 표시되고 닫혀요")
	# 반복 정산은 구조적으로 불가능하다(세션이 없고, 일차가 이미 올랐다).
	var dup: Dictionary = s.settle_service()
	_check(not bool(dup["ok"]) and _json(s) == after, "두 번째 정산은 거부되고 아무것도 바뀌지 않아요")
	_check(s.day == day0 + 1, "일차가 두 번 오르지 않아요")
	_end()


func test_service_determinism_and_chunking() -> void:
	var s: GameStateScript = _state_with_recipe(_spicy_cfg())
	var rec: Dictionary = s.get_record(s.selected_record_id)
	var plan: Dictionary = SessionScript.make_plan(rec, 4)
	var a: SessionScript = SessionScript.new(plan)
	var b: SessionScript = SessionScript.new(plan)
	_check(a.run_to_end() and b.run_to_end(), "두 세션 모두 끝나야 해요")
	_check(str(a.completed) == str(b.completed) and str(a.seat_log) == str(b.seat_log), "같은 계획은 같은 하루를 만들어요")
	# 프레임 길이와 무관: 0.37게임초씩 쪼개 진행해도 같은 결과
	var c: SessionScript = SessionScript.new(plan)
	var guard: int = 0
	while c.state == SessionScript.RUNNING and guard < 20000:
		c.advance(0.37)
		guard += 1
	_check(c.state == SessionScript.FINISHED, "쪼개 진행해도 끝나야 해요")
	_check(str(c.completed) == str(a.completed), "프레임 길이는 결과에 영향이 없어야 해요")
	# 화면이 읽는 스냅샷은 진행 상태를 바꾸지 않는다.
	var d: SessionScript = SessionScript.new(plan)
	for i in 500:
		d.entities()
		d.stats()
		d.tick()
	var e: SessionScript = SessionScript.new(plan)
	for i in 500:
		e.tick()
	_check(str(d.completed) == str(e.completed) and d.time == e.time and str(d.stats()) == str(e.stats()), "읽기 전용 조회는 시뮬레이션을 바꾸지 않아요")
	_end()


## 걷는 점이 선분 a-b 를 따라가며 쓸고 가는 바닥 영역(사람 몸 반경 0.25칸). 격자 좌표에서 가구 발자국과 비교한다.
func _grid_sweep(a: Vector2, b: Vector2) -> Rect2:
	var lo: Vector2 = Vector2(minf(a.x, b.x), minf(a.y, b.y))
	var hi: Vector2 = Vector2(maxf(a.x, b.x), maxf(a.y, b.y))
	return Rect2(lo, hi - lo).grow(0.25)


## 발자국과 겹치는지(경계만 닿는 것은 겹침이 아님).
func _hits(sweep: Rect2, rect: Rect2) -> bool:
	return sweep.intersects(rect, false)


## 격자 경로(grid)와 화면 경로(screen)가 같은 투영으로 이어졌는지.
func _check_projected(layout: Dictionary, grid: Array, screen: Array, tag: String) -> void:
	_check(grid.size() == screen.size(), tag + ": 격자/화면 경로 길이")
	for i in mini(grid.size(), screen.size()):
		_check((screen[i] as Vector2) == LayoutScript.proj(layout, grid[i]), tag + ": 화면 경로가 격자 투영과 달라요 #%d" % i)


## 좌석·그릇·카운터·서버·가구의 물리 관계를 격자(논리 바닥)와 투영(화면) 양쪽에서 확인한다. 상수 복사가 아니라 관계로 본다.
func _check_service_geometry(variant: String, layout: Dictionary) -> void:
	var counters: Array = layout["counters"]
	var tables: Array = layout["tables"]
	var seats: Array = layout["seats"]
	var kitchen: Rect2 = layout["kitchen"]
	for i in seats.size():
		var sd: Dictionary = seats[i]
		var g: Vector2 = sd["grid"]
		var bowl_g: Vector2 = sd["bowl_grid"]
		var bowl_h: float = float(sd["bowl_h"])
		var pos: Vector2 = sd["pos"]
		var serve_g: Array = sd["serve_grid"]
		var serve_end: Vector2 = serve_g[serve_g.size() - 1]
		var tag: String = "%s 자리 %d" % [variant, i]
		_check(pos == LayoutScript.proj(layout, g), tag + ": 발 위치는 격자 투영이어야 해요")
		_check_projected(layout, sd["path_grid"], sd["path"], tag + " 손님 경로")
		_check_projected(layout, sd["serve_grid"], sd["serve_path"], tag + " 서빙 경로")
		# 그릇 그림(12x7)의 접지점(아래 가운데)이 상판 위 격자점의 투영과 같다.
		var bowl_screen: Vector2 = sd["bowl"]
		_check(bowl_screen + Vector2(6.0, 6.0) == LayoutScript.proj(layout, bowl_g, bowl_h), tag + ": 그릇은 상판 높이에서 투영돼야 해요")
		if str(sd["kind"]) == "counter":
			var c: Rect2 = (counters[0] as Dictionary)["rect"]
			_check(is_equal_approx(bowl_h, float((counters[0] as Dictionary)["h"])), tag + ": 그릇 높이가 카운터 높이와 같아야 해요")
			# 그릇은 카운터 윗면 안, 손님은 카운터 앞(큰 gy)에서 0.4~1.0칸 떨어져 주방(작은 gy)을 향해 앉는다.
			_check(c.grow(-0.05).has_point(bowl_g), tag + ": 그릇이 카운터 윗면 위에 있어야 해요")
			_check(g.y - c.end.y >= 0.4 and g.y - c.end.y <= 1.0, tag + ": 손님이 카운터 앞에 붙어 앉아야 해요 (%.2f)" % (g.y - c.end.y))
			_check(absf(bowl_g.x - g.x) <= 0.05, tag + ": 그릇이 손님 정면에 있어야 해요")
			_check(bool(sd["back"]), tag + ": 카운터 손님은 등을 보이고 앉아요")
			# 서버는 카운터 뒤쪽 주방 바닥에서 그릇 정면으로 다가간다.
			_check(kitchen.has_point(serve_end) and serve_end.y < c.position.y - 0.25 and absf(serve_end.x - bowl_g.x) <= 0.1, tag + ": 서버 도착점이 카운터 안쪽 그릇 정면이어야 해요 %s" % str(serve_end))
			# 화면 관계: 앉은 머리 윗점(발-18)과 그릇 아랫면이 이웃해 그릇이 머리 위로 보인다(간격 0~6px).
			var head_top: float = pos.y - 18.0
			var gap: float = head_top - (bowl_screen.y + 7.0)
			_check(gap >= -2.0 and gap <= 6.0, tag + ": 그릇과 손님 머리 간격이 어긋나요 (%.0f)" % gap)
			# 깊이: 그릇은 앉은 손님과 같은 열의 카운터 조각 모두보다 늦게 그려진다.
			_check(float(sd["bowl_depth"]) > g.x + g.y, tag + ": 카운터 그릇 깊이는 손님보다 뒤(큼)여야 해요")
		else:
			var tbl: Dictionary = tables[int(sd["table"])]
			var trect: Rect2 = tbl["rect"]
			var tc: Vector2 = trect.get_center()
			_check(is_equal_approx(bowl_h, float(tbl["h"])), tag + ": 그릇 높이가 테이블 높이와 같아야 해요")
			_check(trect.has_point(bowl_g), tag + ": 그릇이 테이블 위에 놓여야 해요")
			# 손님은 테이블 양끝(gy 쪽) 1.5칸, 서버는 옆 통로에서 1.6칸 안으로 닿는다.
			_check(absf(g.x - tc.x) <= 0.05 and absf(absf(g.y - tc.y) - 1.5) <= 0.05, tag + ": 테이블 끝에 앉아야 해요")
			_check(serve_end.distance_to(g) <= 1.6, tag + ": 서버가 테이블 손님에게 닿을 수 있어야 해요 %s" % str(serve_end))
			_check(bool(sd["back"]) == (g.y > tc.y), tag + ": 앞쪽(gy 큰) 손님만 등을 보여요")
			# 그릇은 자기 손님 쪽 절반 상판에 있다.
			_check((bowl_g.y - tc.y) * (g.y - tc.y) > 0.0, tag + ": 그릇이 손님 쪽 상판에 있어야 해요")
			var bd: float = float(sd["bowl_depth"])
			_check(bd > tc.x + trect.end.y - 0.01 and bd < tc.x + tc.y + 1.5, tag + ": 테이블 그릇 깊이는 테이블 앞 가장자리와 앞쪽 손님 사이여야 해요")
		# 문에서 자리까지 가는 경로(마지막 구간 제외)는 어떤 단단한 가구 발자국도 가로지르지 않는다.
		var path_g: Array = sd["path_grid"]
		for k in range(1, path_g.size()):
			var sweep: Rect2 = _grid_sweep(path_g[k - 1], path_g[k])
			for f in layout["furniture"]:
				var fd: Dictionary = f
				if not bool(fd["solid"]):
					continue
				for fr in fd["rects"]:
					_check(not _hits(sweep, fr), "%s: 경로 %d 구간이 %s 에 걸려요" % [tag, k, str(fd["id"])])
		for k in range(1, serve_g.size()):
			var sweep2: Rect2 = _grid_sweep(serve_g[k - 1], serve_g[k])
			for f2 in layout["furniture"]:
				var fd2: Dictionary = f2
				if not bool(fd2["solid"]):
					continue
				for fr2 in fd2["rects"]:
					_check(not _hits(sweep2, fr2), "%s: 서빙 구간 %d 가 %s 에 걸려요" % [tag, k, str(fd2["id"])])
	# 줄/등장/퇴장 길(인도)에도 소품이 없다: 줄 칸, 문 앞, 스폰과 퇴장 사이 직선.
	var lane: Array = [layout["spawn_grid"], layout["exit_grid"]]
	for qg in layout["queue_grid"]:
		lane.append(qg)
	lane.append(Vector2(LayoutScript.DOOR_X, LayoutScript.LANE_Y))
	for pt in lane:
		var cell: Rect2 = Rect2((pt as Vector2) - Vector2(0.05, 0.05), Vector2(0.1, 0.1)).grow(0.25)
		for f3 in layout["furniture"]:
			var fd3: Dictionary = f3
			if not bool(fd3["solid"]):
				continue
			for fr3 in fd3["rects"]:
				_check(not _hits(cell, fr3), "%s: 줄/통행 점 %s 가 %s 에 걸려요" % [variant, str(pt), str(fd3["id"])])
	var lane_sweep: Rect2 = _grid_sweep(layout["spawn_grid"], layout["exit_grid"])
	for f4 in layout["furniture"]:
		var fd4: Dictionary = f4
		if not bool(fd4["solid"]):
			continue
		for fr4 in fd4["rects"]:
			_check(not _hits(lane_sweep, fr4), "%s: 인도 통행로가 %s 에 막혀요" % [variant, str(fd4["id"])])
	# 굳은 가구끼리 겹치지 않고(발자국), 모두 장면 안에 걸친다(화면 투영 기준 일부라도 보여야 함).
	var solids: Array = []
	for f5 in layout["furniture"]:
		var fd5: Dictionary = f5
		if bool(fd5["solid"]):
			solids.append(fd5)
	for a in solids.size():
		for b in range(a + 1, solids.size()):
			var fa: Dictionary = solids[a]
			var fb: Dictionary = solids[b]
			_check(not (fa["rect"] as Rect2).intersects(fb["rect"], false), "%s: 가구 발자국이 겹쳐요 %s / %s" % [variant, str(fa["id"]), str(fb["id"])])


## 접두사 조각 전체의 가로 범위가 [lo, hi](투영된 모서리 x) 와 2px 안에서 일치하고 장면 안(>=0)에 머무는지.
func _check_slice_extent(its: Array, variant: String, prefix: String, lo_raw: float, hi_raw: float, world_w: int) -> void:
	# 그림은 장면 이미지 크기로 잘리므로(예: 세로 파사드 왼쪽 모서리는 x=-5.6 이라 이미지 밖) 기대 범위도 이미지 범위와 교집합으로 비교한다.
	var lo: float = maxf(lo_raw, 0.0)
	var hi: float = minf(hi_raw, float(world_w))
	var min_x: float = 1.0e9
	var max_x: float = -1.0e9
	var count: int = 0
	for it in its:
		var d: Dictionary = it
		if not str(d["id"]).begins_with(prefix):
			continue
		var p: Vector2 = d["pos"]
		min_x = minf(min_x, p.x)
		max_x = maxf(max_x, p.x + float((d["img"] as Image).get_width()))
		count += 1
	_check(count >= 6, "%s: %s 조각이 너무 적어요 (%d)" % [variant, prefix, count])
	_check(min_x >= lo - 6.0 and min_x <= lo + 2.0, "%s: %s 조각 왼쪽 끝 %.0f, 기대 %.0f" % [variant, prefix, min_x, lo])
	_check(max_x >= hi - 2.0 and max_x <= hi + 8.0, "%s: %s 조각 오른쪽 끝 %.0f, 기대 %.0f" % [variant, prefix, max_x, hi])


## id 접두사가 맞고 화면 열 x 를 덮는 가구 조각 하나(없으면 빈 Dictionary).
func _slice_at(its: Array, prefix: String, col_x: float) -> Dictionary:
	for it in its:
		var d: Dictionary = it
		if not str(d["id"]).begins_with(prefix):
			continue
		var p: Vector2 = d["pos"]
		var w: int = (d["img"] as Image).get_width()
		if col_x >= p.x and col_x < p.x + float(w):
			return d
	return {}


## 투영/깊이/화면 배치: 모서리가 정수 격자에 맞고, 가구 조각의 깊이가 사람과 같은 눈금에서 맞게 가려지는지 본다.
func _check_projection_and_depth(variant: String, layout: Dictionary) -> void:
	var world: Vector2i = layout["size"]
	var bounds: Rect2 = Rect2(Vector2.ZERO, Vector2(world)).grow(1.0)
	# 투영: 2:1 마름모. +gx 는 (+8,+4), +gy 는 (-8,+4), 높이 h 는 y 를 h 만큼 올린다.
	var o: Vector2 = LayoutScript.proj(layout, Vector2.ZERO)
	_check(LayoutScript.proj(layout, Vector2(1.0, 0.0)) - o == Vector2(8.0, 4.0), variant + ": +gx 투영")
	_check(LayoutScript.proj(layout, Vector2(0.0, 1.0)) - o == Vector2(-8.0, 4.0), variant + ": +gy 투영")
	_check(LayoutScript.proj(layout, Vector2(2.0, 3.0), 10.0) == LayoutScript.proj(layout, Vector2(2.0, 3.0)) + Vector2(0.0, -10.0), variant + ": 높이는 세로로만 올라가요")
	var probe: Vector2 = LayoutScript.proj(layout, Vector2(5.5, 6.25))
	_check(absf(LayoutScript.depth_of_screen(layout, probe) - 11.75) <= 0.13, variant + ": 화면 y 에서 구한 깊이는 gx+gy 와 같아요")
	# 방 네 모서리와 벽 윗점이 장면 안에 있다(앞 모서리는 화면 아래쪽으로 잘리지 않음).
	var room: Rect2 = layout["room"]
	for corner in [room.position, Vector2(room.end.x, room.position.y), Vector2(room.position.x, room.end.y), room.end]:
		_check(bounds.has_point(LayoutScript.proj(layout, corner)), "%s: 방 모서리 %s 가 장면 밖" % [variant, str(corner)])
	_check(bounds.has_point(LayoutScript.proj(layout, room.position, LayoutScript.WALL_H)), variant + ": 벽 윗점이 장면 밖")
	# 가구/소품 항목: 크기와 깊이 순서
	var its: Array = PainterScript.items(layout)
	_check(its.size() >= 40, "%s: 가구 항목이 너무 적어요 (%d)" % [variant, its.size()])
	var shown: int = 0
	for it in its:
		var d: Dictionary = it
		var img: Image = d["img"]
		var p: Vector2 = d["pos"]
		if Rect2(p, Vector2(img.get_size())).intersects(Rect2(Vector2.ZERO, Vector2(world))):
			shown += 1
	_check(shown >= 35, "%s: 화면에 걸치는 가구 항목 수 %d" % [variant, shown])
	# 카운터 조각은 가로로 이어지고, 같은 열의 깊이는 오른쪽(화면 오른쪽 아래)으로 갈수록 커진다.
	var counter_depths: Array = []
	for it2 in its:
		var d2: Dictionary = it2
		if str(d2["id"]).begins_with("counter@"):
			counter_depths.append([(d2["pos"] as Vector2).x, float(d2["depth"])])
	_check(counter_depths.size() >= 8, variant + ": 카운터가 조각나야 해요")
	counter_depths.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
	for k in range(1, counter_depths.size()):
		_check(float((counter_depths[k] as Array)[1]) >= float((counter_depths[k - 1] as Array)[1]), variant + ": 카운터 조각 깊이 순서")
	# 서버(카운터 뒤, 발 gy 2.35)는 같은 열 카운터 조각보다 먼저, 앉은 손님(gy 4.5)은 나중에 그려진다.
	var seats: Array = layout["seats"]
	for i in 4:
		var sd: Dictionary = seats[i]
		var sg: Vector2 = sd["grid"]
		var behind: Vector2 = Vector2(sg.x, LayoutScript.SERVE_Y)
		var back_slice: Dictionary = _slice_at(its, "counter@", LayoutScript.proj(layout, behind).x)
		var front_slice: Dictionary = _slice_at(its, "counter@", LayoutScript.proj(layout, sg).x)
		_check(not back_slice.is_empty() and not front_slice.is_empty(), "%s 자리 %d: 서버/손님 열의 카운터 조각 없음" % [variant, i])
		if not back_slice.is_empty():
			_check(float(back_slice["depth"]) > behind.x + behind.y, "%s 자리 %d: 카운터 조각이 뒤쪽 서버보다 늦게 그려져야 해요" % [variant, i])
		if not front_slice.is_empty():
			_check(float(front_slice["depth"]) < sg.x + sg.y, "%s 자리 %d: 앞쪽 손님이 카운터 조각보다 늦게 그려져야 해요" % [variant, i])
	# 문 열림: 파사드 낮은 벽 조각은 문틈 열(문 가운데 gx)에 그려지지 않는다.
	var door_col: float = LayoutScript.proj(layout, Vector2(LayoutScript.DOOR_X, LayoutScript.FACADE.end.y), 5.0).x
	for it4 in its:
		var d4: Dictionary = it4
		if str(d4["id"]).begins_with("facade:low@"):
			var q: Vector2 = d4["pos"]
			var im: Image = d4["img"]
			if door_col >= q.x and door_col < q.x + float(im.get_width()):
				# 같은 열에 낮은 벽(높이 11 이하)이 문 높이 5 위치를 칠하고 있으면 문이 막힌 것이다.
				var lx: int = int(door_col - q.x)
				var ly: int = int(LayoutScript.proj(layout, Vector2(LayoutScript.DOOR_X, LayoutScript.FACADE.end.y), 5.0).y - q.y)
				if ly >= 0 and ly < im.get_height():
					_check(im.get_pixel(lx, ly).a < 0.5, variant + ": 문틈이 벽으로 막혔어요")
	# 앉은 손님/스툴: 같은 깊이 근처에서 스툴이 사람보다 먼저(작은 깊이)
	for i2 in seats.size():
		var sg2: Vector2 = (seats[i2] as Dictionary)["grid"]
		for it5 in its:
			var d5: Dictionary = it5
			if str(d5["id"]) == "seat%d" % i2:
				_check(float(d5["depth"]) < sg2.x + sg2.y, "%s: 좌석 %d 의 스툴/의자는 앉은 사람보다 먼저 그려져야 해요" % [variant, i2])
	# 사람 스프라이트 위치: 발바닥이 투영된 발 위치와 일치한다(앉은 사람 이미지는 14x18, 맨 아래 줄이 발).
	var ent: Dictionary = {"patrons": [{"id": 1, "state": SessionScript.P_ORDERING, "p": 0.0, "look": 3, "slot": 0, "seat": 0, "bubble": ""}], "chef_cooking": false}
	var scene: Dictionary = SceneScript.build(layout, ent, {}, 0.0, {}, {})
	var sat_found: bool = false
	for it6 in scene["items"]:
		var d6: Dictionary = it6
		if str(d6["key"]).begins_with("p|3|sit"):
			sat_found = true
			var feet: Vector2 = (d6["pos"] as Vector2) + Vector2(7.0, 18.0)
			_check(feet == ((seats[0] as Dictionary)["pos"] as Vector2), variant + ": 앉은 손님 발이 좌석 투영과 달라요")
			_check(absf(float(d6["depth"]) - LayoutScript.depth_of_screen(layout, feet)) < 0.001, variant + ": 사람 깊이는 발 y 에서 나와야 해요")
	_check(sat_found, variant + ": 주문 중 손님이 앉은 모습이어야 해요")
	# 조각의 전역 좌표 보존: 카운터/파사드 조각 묶음의 가로 범위가 실제 투영된 가구 모서리와 맞아야 한다(x=0 으로 뭉치지 않음).
	var counter_rect: Rect2 = (layout["counters"] as Array)[0]["rect"]
	_check_slice_extent(its, variant, "counter@", LayoutScript.proj(layout, Vector2(counter_rect.position.x, counter_rect.end.y)).x, LayoutScript.proj(layout, Vector2(counter_rect.end.x, counter_rect.position.y)).x, world.x)
	_check_slice_extent(its, variant, "facade:low@", LayoutScript.proj(layout, Vector2(LayoutScript.FACADE.position.x, LayoutScript.FACADE.end.y)).x, LayoutScript.proj(layout, Vector2(LayoutScript.FACADE.end.x, LayoutScript.FACADE.position.y)).x, world.x)
	# 퇴장: 실제 Scene.build 가 주는 P_LEAVING 위치를 진행률대로 훑어 바닥 격자로 되돌려 본다. 문을 나선 뒤 인도(gy>=ROOM_D)를 벗어나지 않고
	# 방/벽 쪽으로 다시 들어가지 않으며 어떤 단단한 가구에도 겹치지 않아야 한다.
	var o2: Vector2 = layout["origin"]
	for si in seats.size():
		var outside: bool = false
		for step in 81:
			var lent: Dictionary = {"patrons": [{"id": 7, "state": SessionScript.P_LEAVING, "p": float(step) / 80.0, "look": 3, "slot": 0, "seat": si, "bubble": ""}]}
			var lscene: Dictionary = SceneScript.build(layout, lent, {}, 0.0, {}, {})
			var feet2: Vector2 = Vector2.ZERO
			for lit in lscene["items"]:
				var ld: Dictionary = lit
				if str(ld["key"]).begins_with("p|3|"):
					feet2 = (ld["pos"] as Vector2) + Vector2(7.0, 18.0)
			var u2: float = (feet2.x - o2.x) / LayoutScript.HALF_W
			var v2: float = (feet2.y - o2.y) / LayoutScript.HALF_H
			var gp: Vector2 = Vector2((u2 + v2) * 0.5, (v2 - u2) * 0.5)
			var tagp: String = "%s 퇴장 자리 %d 진행 %d: %s" % [variant, si, step, str(gp)]
			if gp.y > LayoutScript.DOOR_OUT.y - 0.05:
				outside = true
			if outside:
				_check(gp.y >= LayoutScript.DOOR_OUT.y - 0.05, tagp + " 문 밖에서 다시 들어왔어요")
			else:
				_check(gp.x > 0.0 and gp.x < LayoutScript.ROOM_W and gp.y > 0.0, tagp + " 방 밖(벽)으로 나갔어요")
			for f6 in layout["furniture"]:
				var fd6: Dictionary = f6
				if not bool(fd6["solid"]):
					continue
				for fr6 in fd6["rects"]:
					_check(not (fr6 as Rect2).grow(-0.0).has_point(gp), tagp + " 가구 %s 와 겹쳐요" % str(fd6["id"]))
		_check(outside, "%s 퇴장 자리 %d: 끝까지 문 밖 인도에 도착해야 해요" % [variant, si])
	# 닫힌 가게/손님이 없는 장면에는 직원 둘(요리사, 서버)만 있다: 꾸며 낸 손님 없음.
	var empty_scene: Dictionary = SceneScript.build(layout, {}, {}, 0.0, {}, {})
	_check((empty_scene["items"] as Array).size() == 2 and (empty_scene["bubbles"] as Array).is_empty(), variant + ": 손님이 없으면 직원만 그려져요")
	var cpu: Image = SceneScript.compose_for(layout, null)
	_check(cpu.get_width() == world.x and cpu.get_height() == world.y, variant + ": CPU 합성 이미지 크기")
	# 바닥이 한 가지 색의 넓은 띠로 비지 않는다: 방 안쪽 표본 픽셀이 여러 색으로 채워진다(타일 선/널/가구/깔개).
	var colors: Dictionary = {}
	var room_a: Vector2 = LayoutScript.proj(layout, Vector2(1.0, 4.5))
	var room_b: Vector2 = LayoutScript.proj(layout, Vector2(11.0, 8.0))
	for sy in range(int(room_a.y) - 10, int(room_b.y) + 1, 2):
		for sx in range(int(minf(room_a.x, room_b.x)), int(maxf(room_a.x, room_b.x)), 2):
			colors[cpu.get_pixel(clampi(sx, 0, world.x - 1), clampi(sy, 0, world.y - 1)).to_html()] = true
	_check(colors.size() >= 25, "%s: 방 안쪽 색이 너무 단조로워요 (%d색)" % [variant, colors.size()])


# =====================================================================================================
# 가게 성장 도메인 시험 (등급 / 유료 확장 / 다중 토핑 / 보조 직원 / 노트 용량 / 스키마 v3 이행)
# 모두 실제 도메인 연산(시식 → 연구 제출 → 영업 → 승급 → 구매 → 고용)으로 상태를 만든다. 디버그 해금은 없다.
# 승급 조건의 점수는 연구 증인 조합(WITNESSES)을 평가기로 다시 계산한 값이다(손으로 지어낸 점수 없음).
# 화면(UI)/장면 그림/QA 캡처 쪽 성장 시험은 다음 단계(main.gd, 픽셀 아트, qa_capture.gd)에서 추가한다(아직 없음 = 보류, 삭제 아님).
# =====================================================================================================

## 구성 하나를 v1/v2 저장의 모양("topping" 문자열 하나)으로 되돌린다. 토핑이 하나인 구성만 쓴다.
func _to_legacy_cfg(cfg: Variant) -> Dictionary:
	var c: Dictionary = (cfg as Dictionary).duplicate(true)
	var tops: Array = c["toppings"]
	c.erase("toppings")
	c["topping"] = str(tops[0])
	return c


## v3 저장 딕셔너리를 진짜 v1/v2(또는 토핑만 옛 모양인 가짜 v3) 파일 모양으로 바꾼다(JSON 왕복으로 숫자도 float 로).
## 토핑이 모두 하나인 상태에서만 쓴다.
func _as_legacy(src: Dictionary, version: int) -> Dictionary:
	var d: Dictionary = JSON.parse_string(JSON.stringify(src))
	d["schema_version"] = version
	d.erase("growth")
	if version == 1:
		d.erase("research")
	for r in d["records"]:
		var rec: Dictionary = r
		rec["config"] = _to_legacy_cfg(rec["config"])
		var cmp: Dictionary = rec["comparison"]
		if not cmp.is_empty():
			cmp["prev_config"] = _to_legacy_cfg(cmp["prev_config"])
	var draft: Dictionary = d["draft"]
	draft["config"] = _to_legacy_cfg(draft["config"])
	return d


## 증인 여섯 개를 시식하고 연구 여섯 개를 제출한 뒤 영업(즉시 정산 경로)으로 일수를 채우고, target_rank 까지 승급한다.
## target_rank 1 은 "승급 조건은 모두 채웠지만 신청하지 않은" 상태(영업 3일)다. 확장 구매/고용은 하지 않는다.
func _ranked_state(target_rank: int) -> GameStateScript:
	var s: GameStateScript = _state_with_wallet(900000)
	var rec: Dictionary = _record_all_witnesses(s)
	for rid in Research.ids():
		var r: Dictionary = s.submit_research(rid, int(rec[rid]))
		_check(bool(r["ok"]), "성장 시험 준비: 연구 제출 " + rid + " " + str(r["message"]))
	_check(bool(s.select_record(int(rec["hayoung_basic"]))["ok"]), "성장 시험 준비: 영업 메뉴 선택")
	var goal_day: int = 11 if target_rank >= 3 else 4
	var guard: int = 0
	while s.day < goal_day and guard < 40:
		var sr: Dictionary = s.serve()
		_check(bool(sr["ok"]), "성장 시험 준비: 영업 " + str(sr["message"]))
		guard += 1
	for rk in range(2, target_rank + 1):
		var pr: Dictionary = s.apply_promotion(rk)
		_check(bool(pr["ok"]), "성장 시험 준비: 승급 %d %s" % [rk, str(pr["message"])])
	return s


## level 2: 등급 2 + 조리대 I + 직원 공간 I. level 3: 등급 3 + 확장 네 개 모두. 고용은 하지 않는다.
func _grown_state(level: int = 3) -> GameStateScript:
	var s: GameStateScript = _ranked_state(3 if level >= 3 else 2)
	var ids: Array[String] = ["bench_1", "staff_1"]
	if level >= 3:
		ids.append_array(["bench_2", "staff_2"])
	for id in ids:
		var r: Dictionary = s.purchase_facility(id)
		_check(bool(r["ok"]), "성장 시험 준비: 확장 구매 %s %s" % [id, str(r["message"])])
	return s


func _sum_waits(sess: SessionScript) -> int:
	var total: int = 0
	for c in sess.completed:
		total += int((c as Dictionary)["wait"])
	return total


# ---------- 토핑 ----------

## 토핑이 하나인 옛 구성은 정규 구성과 점수/원가/시간이 정확히 같고, 예전 공식(슬롯마다 재료 하나씩 더함)과도 같다.
func test_topping_canonical_and_legacy() -> void:
	var all: Array[Dictionary] = _all_configs()
	_check(all.size() == 972, "옛 구성 전수 972개")
	var compared: int = 0
	for i in range(0, all.size(), 7):
		var legacy: Dictionary = all[i]
		var canon: Dictionary = Catalog.normalize_config(legacy)
		_check(canon.has("toppings") and not canon.has("topping") and (canon["toppings"] as Array).size() == 1, "정규 구성은 toppings 배열 하나")
		_check(Check.config_error(legacy) == "" and Check.config_error(canon) == "", "옛/정규 구성 모두 유효")
		_check(str(Evaluator.evaluate(legacy)) == str(Evaluator.evaluate(canon)), "옛/정규 평가 결과(점수·피드백·궁합)가 같아야 해요: " + str(legacy))
		var cost: int = 0
		var secs: int = 0
		for slot in Catalog.SLOTS:
			var item: Dictionary = Catalog.find(str(legacy[slot]))
			cost += int(item["cost"])
			secs += int(item["seconds"])
		_check(Evaluator.unit_cost(canon) == cost and Evaluator.unit_cost(legacy) == cost, "원가는 예전 공식(여섯 재료 합)과 같아야 해요")
		_check(Evaluator.prep_seconds(canon) == secs and Evaluator.prep_seconds(legacy) == secs, "준비 시간은 예전 공식과 같아야 해요")
		_check(Check.same_config(legacy, canon), "옛/정규 구성은 같은 구성")
		compared += 1
	_check(compared >= 100, "표본 수 %d" % compared)
	var def: Dictionary = Catalog.default_config()
	_check(Check.config_error(def) == "" and Catalog.toppings_of(def).size() == 1 and def.has("toppings"), "기본 구성은 정규, 토핑 1개")
	_check(str(Catalog.toppings_of({"topping": "topping_egg"})) == str(["topping_egg"]), "옛 모양 토핑 추출")
	_check(Catalog.toppings_of({"toppings": ["topping_egg", "topping_nori"]}).size() == 2, "정규 모양 토핑 추출")
	_end()


func test_topping_validation() -> void:
	var base: Dictionary = Catalog.normalize_config(_rich_cfg())
	var bad: Dictionary = {}
	var c1: Dictionary = base.duplicate(true)
	c1["toppings"] = []
	bad["비어 있음"] = c1
	var c2: Dictionary = base.duplicate(true)
	c2["toppings"] = ["topping_egg", "topping_egg"]
	bad["중복"] = c2
	var c3: Dictionary = base.duplicate(true)
	c3["toppings"] = ["topping_chashu", "topping_egg", "topping_sprouts", "topping_nori"]
	bad["절대 상한 초과"] = c3
	var c4: Dictionary = base.duplicate(true)
	c4["toppings"] = ["topping_unknown"]
	bad["알 수 없는 id"] = c4
	var c5: Dictionary = base.duplicate(true)
	c5["toppings"] = "topping_egg"
	bad["배열 아님"] = c5
	var c6: Dictionary = base.duplicate(true)
	c6["toppings"] = [5]
	bad["문자열 아님"] = c6
	var c7: Dictionary = base.duplicate(true)
	c7["topping"] = "topping_egg"
	bad["옛 키와 정규 키 동시"] = c7
	var c8: Dictionary = base.duplicate(true)
	c8["toppings"] = ["broth_dashi"]
	bad["다른 슬롯 재료"] = c8
	var c9: Dictionary = _rich_cfg()
	c9["topping"] = "topping_unknown"
	bad["옛 구성의 알 수 없는 토핑"] = c9
	for label in bad:
		var cfg: Dictionary = bad[label]
		_check(Check.config_error(cfg) != "", "구성 오류여야 해요: " + str(label))
		_check(str(Evaluator.evaluate(cfg)["error"]) != "", "평가도 거부: " + str(label))
		_check(str(Sim.simulate(cfg, {"dohyun": 80, "hayoung": 80, "maru": 80}, 1)["error"]) != "", "시뮬레이션도 거부: " + str(label))
	# 순서만 다른 토핑 목록은 같은 레시피다: 유효하고, 같은 구성으로 비교되며, 평가가 같고, 정규화하면 카탈로그 순서가 된다.
	var a: Dictionary = base.duplicate(true)
	a["toppings"] = ["topping_chashu", "topping_nori"]
	var b: Dictionary = base.duplicate(true)
	b["toppings"] = ["topping_nori", "topping_chashu"]
	_check(Check.config_error(a) == "" and Check.config_error(b) == "", "순서가 달라도 유효")
	_check(Check.same_config(a, b) and Check.same_config(b, a), "순서만 다른 구성은 같은 구성")
	_check(str(Evaluator.evaluate(a)) == str(Evaluator.evaluate(b)), "순서만 다르면 평가가 같아야 해요")
	_check(str(Catalog.normalize_config(b)["toppings"]) == str(["topping_chashu", "topping_nori"]), "정규화는 카탈로그 순서")
	var other: Dictionary = base.duplicate(true)
	other["toppings"] = ["topping_chashu", "topping_egg"]
	_check(not Check.same_config(a, other), "토핑 집합이 다르면 다른 구성")
	# 토핑마다 정확히 한 번 반영: 토핑을 하나 더하면 원가/시간은 그 토핑의 값만큼 늘어난다.
	var egg: Dictionary = Catalog.find("topping_egg")
	var with_egg: Dictionary = base.duplicate(true)
	with_egg["toppings"] = Catalog.canonical_toppings(["topping_chashu", "topping_egg"])
	var just_chashu: Dictionary = base.duplicate(true)
	just_chashu["toppings"] = ["topping_chashu"]
	_check(Evaluator.unit_cost(with_egg) == Evaluator.unit_cost(just_chashu) + int(egg["cost"]), "토핑 원가는 한 번씩")
	_check(Evaluator.prep_seconds(with_egg) == Evaluator.prep_seconds(just_chashu) + int(egg["seconds"]), "토핑 시간은 한 번씩")
	# 저장 구성 파서: v3 는 정렬된 정규 배열만, v1/v2 는 옛 모양만.
	_check(str(Check.parse_config(a, "t")["error"]) == "", "정렬된 정규 구성 허용")
	_check(str(Check.parse_config(b, "t")["error"]) != "", "섞인 토핑 순서는 저장 구성에서 거부")
	_check(str(Check.parse_config(c2, "t")["error"]) != "" and str(Check.parse_config(c3, "t")["error"]) != "" and str(Check.parse_config(c4, "t")["error"]) != "", "중복/초과/미지 거부")
	var parsed_legacy: Dictionary = Check.parse_config(_rich_cfg(), "t", true)
	_check(str(parsed_legacy["error"]) == "" and str((parsed_legacy["config"] as Dictionary)["toppings"]) == str(["topping_chashu"]), "옛 구성은 정규 하나짜리 배열로 읽혀요")
	_check(str(Check.parse_config(base, "t", true)["error"]) != "" and str(Check.parse_config(_rich_cfg(), "t", false)["error"]) != "", "모양과 스키마 버전이 어긋나면 거부")
	_end()


func test_topping_slots_and_draft_limits() -> void:
	# 슬롯 = min(등급, 1 + 조리대 단계): 둘 다 있어야 열린다.
	_check(Growth.topping_slots(1, []) == 1 and Growth.topping_slots(3, []) == 1, "조리대 없이는 등급이 높아도 1개")
	_check(Growth.topping_slots(1, ["bench_1"]) == 1, "등급 1은 조리대가 있어도 1개(등급이 한도)")
	_check(Growth.topping_slots(2, ["bench_1"]) == 2 and Growth.topping_slots(3, ["bench_1"]) == 2, "조리대 I = 2개")
	_check(Growth.topping_slots(3, ["bench_1", "bench_2"]) == 3 and Growth.topping_slots(2, ["bench_1", "bench_2"]) == 2, "조리대 II + 등급 3 = 3개")
	var s: GameStateScript = _state_with_wallet(100000)
	_check(s.topping_slots() == 1, "처음에는 토핑 1개")
	var before: String = _json(s)
	_check(not bool(s.set_draft_toppings(["topping_egg", "topping_nori"])["ok"]) and _json(s) == before, "슬롯을 넘는 지정은 거부, 초안 불변")
	var over: Dictionary = s.set_draft_toppings(["topping_egg", "topping_nori"])
	_check(str(over["message"]).find("열려요") >= 0, "해금 방법을 알려요: " + str(over["message"]))
	_check(not bool(s.toggle_draft_topping("topping_egg")["ok"]) and _json(s) == before, "슬롯이 꽉 차면 추가 거부")
	_check(not bool(s.toggle_draft_topping(str(Catalog.toppings_of(s.draft_config)[0]))["ok"]) and _json(s) == before, "마지막 토핑은 뺄 수 없어요")
	var bad_lists: Array = [[], ["topping_nope"], ["topping_egg", "topping_egg"], ["broth_dashi"]]
	for bl in bad_lists:
		_check(not bool(s.set_draft_toppings(bl)["ok"]) and _json(s) == before, "잘못된 토핑 지정 거부: " + str(bl))
	_check(not bool(s.toggle_draft_topping("topping_nope")["ok"]) and _json(s) == before, "알 수 없는 토글 거부")
	# 옛 호출 모양(토핑 하나 고르기)은 그 하나로 바꾼다.
	_check(bool(s.set_draft_choice("topping", "topping_nori")["ok"]) and str(s.draft_config["toppings"]) == str(["topping_nori"]), "예전 단일 선택 호환")
	_check(bool(s.set_draft_toppings(["topping_egg"])["ok"]) and str(s.draft_config["toppings"]) == str(["topping_egg"]), "하나 지정")
	# 슬롯을 우회해 초안을 망가뜨려도(변조) 시식은 거부한다.
	var tampered: GameStateScript = _state_with_wallet(100000)
	tampered.draft_config["toppings"] = ["topping_chashu", "topping_egg"]
	var t_before: String = _json(tampered)
	_check(not bool(tampered.taste()["ok"]) and _json(tampered) == t_before and tampered.record_count() == 0, "열린 슬롯보다 많은 토핑은 시식 거부, 자금 불변")

	# 완전 성장 상태: 3개까지, 순서/중복/기록/불러오기.
	var g: GameStateScript = _grown_state(3)
	_check(g.topping_slots() == 3, "등급 3 + 조리대 II = 3개")
	g.start_new_recipe()
	g.set_draft_name("세 토핑 시험")
	_check(bool(g.set_draft_toppings(["topping_nori", "topping_chashu", "topping_egg"])["ok"]), "토핑 3개 지정")
	_check(str(g.draft_config["toppings"]) == str(["topping_chashu", "topping_egg", "topping_nori"]), "초안 토핑은 카탈로그 순서로 정규화")
	var g_before: String = _json(g)
	_check(not bool(g.set_draft_toppings(["topping_chashu", "topping_egg", "topping_sprouts", "topping_nori"])["ok"]) and _json(g) == g_before, "4개는 거부")
	_check(not bool(g.toggle_draft_topping("topping_sprouts")["ok"]) and _json(g) == g_before, "꽉 찬 슬롯에 추가 거부")
	_check(bool(g.toggle_draft_topping("topping_egg")["ok"]) and Catalog.toppings_of(g.draft_config).size() == 2, "토글로 빼기")
	_check(bool(g.toggle_draft_topping("topping_sprouts")["ok"]) and Catalog.toppings_of(g.draft_config).size() == 3, "토글로 다른 토핑 넣기")
	var cost: int = Evaluator.unit_cost(g.draft_config)
	var wallet0: int = g.wallet
	var r: Dictionary = g.taste()
	_check(bool(r["ok"]), "세 토핑 시식: " + str(r["message"]))
	var rec: Dictionary = g.get_record(int(r["record_id"]))
	_check(Catalog.toppings_of(rec["config"]).size() == 3 and g.wallet == wallet0 - cost, "기록에 토핑 3개, 재료비는 세 토핑 모두 반영")
	_check(str(rec["scores"]) == str(_scores_of(rec["config"])), "기록 점수는 세 토핑 평가 결과")
	# 같은 토핑을 다른 순서로 넣어도 새 기록이 생기지 않는다(새 레시피 이름이라 "중복 구성" 규칙이 직접 걸린다).
	g.start_new_recipe()
	var count: int = g.record_count()
	var w1: int = g.wallet
	var reordered: Array = []
	for t in Catalog.toppings_of(g.draft_config):
		reordered.append(t)
	reordered.reverse()
	g.draft_config["toppings"] = reordered
	var dup: Dictionary = g.taste()
	_check(not bool(dup["ok"]) and g.record_count() == count and g.wallet == w1, "토핑 순서만 바꿔서는 새 기록을 만들 수 없어요: " + str(dup["message"]))
	g.select_record(int(r["record_id"]))
	_check(str(g.draft_config["toppings"]) == str((rec["config"] as Dictionary)["toppings"]), "불러온 레시피의 토핑이 기록과 같아요")
	# 개정 비교에도 토핑이 모두 들어간다.
	_check(bool(g.set_draft_toppings(["topping_chashu", "topping_egg"])["ok"]), "개정: 토핑 2개로")
	var rev: Dictionary = g.taste()
	_check(bool(rev["ok"]), "개정 시식: " + str(rev["message"]))
	var cmp: Dictionary = g.get_record(int(rev["record_id"]))["comparison"]
	_check(Catalog.toppings_of(cmp["prev_config"]).size() == 3, "개정 비교의 이전 구성에 토핑 3개")
	# 저장 왕복: 세 토핑이 그대로.
	var round_dict: Dictionary = JSON.parse_string(JSON.stringify(g.to_dict()))
	var loaded: GameStateScript = GameStateScript.new()
	_check(loaded.load_from_dict(round_dict) == "" and _json(loaded) == _json(g), "다중 토핑 저장/불러오기 왕복")
	# 영업 중에는 토핑 편집도 잠긴다.
	g.select_record(int(rev["record_id"]))
	_check(bool(g.begin_service()["ok"]), "영업 시작")
	var lock_before: String = _json(g)
	_check(not bool(g.set_draft_toppings(["topping_egg"])["ok"]) and not bool(g.toggle_draft_topping("topping_egg")["ok"]) and _json(g) == lock_before, "영업 중 토핑 편집 거부")
	g.cancel_service()
	_end()


## 토핑을 더하면 원가와 준비 시간이 늘고(수용량이 줄고), 모든 손님이 좋아하게 되지는 않는다.
func test_topping_tradeoff() -> void:
	var light: Dictionary = Catalog.normalize_config(_light_cfg())
	var plus: Dictionary = light.duplicate(true)
	plus["toppings"] = Catalog.canonical_toppings(["topping_egg", "topping_chashu"])
	var chashu: Dictionary = Catalog.find("topping_chashu")
	_check(Evaluator.unit_cost(plus) == Evaluator.unit_cost(light) + int(chashu["cost"]), "차슈를 더하면 원가가 차슈만큼 늘어요")
	_check(Evaluator.prep_seconds(plus) == Evaluator.prep_seconds(light) + int(chashu["seconds"]), "차슈를 더하면 준비 시간이 차슈만큼 늘어요")
	var s0: Dictionary = _scores_of(light)
	var s1: Dictionary = _scores_of(plus)
	_check(int(s1["hayoung"]) < int(s0["hayoung"]), "담백파 하영은 차슈를 더하면 점수가 내려가요 (%d → %d)" % [int(s0["hayoung"]), int(s1["hayoung"])])
	_check(int(s1["dohyun"]) > int(s0["dohyun"]), "진한 맛을 원하는 도윤은 점수가 올라가요 (%d → %d)" % [int(s0["dohyun"]), int(s1["dohyun"])])
	var f0: Dictionary = Sim.simulate(light, s0, 5)
	var f1: Dictionary = Sim.simulate(plus, s1, 5)
	_check(int(f1["capacity"]) < int(f0["capacity"]), "준비가 느려져 하루에 만들 수 있는 그릇이 줄어요 (%d → %d)" % [int(f0["capacity"]), int(f1["capacity"])])
	# 전수: 어떤 구성이든 토핑을 하나 더하면 원가/시간이 반드시 늘고, 점수가 내려가는 손님이 생기는 경우와 엇갈리는 경우가 존재한다.
	var worse_somewhere: int = 0
	var better_somewhere: int = 0
	var mixed: int = 0
	var total: int = 0
	for cfg in _all_configs():
		var one: Dictionary = Catalog.normalize_config(cfg)
		var base_scores: Dictionary = _scores_of(one)
		var first_top: String = str(Catalog.toppings_of(one)[0])
		for t in Catalog.items("topping"):
			var tid: String = str((t as Dictionary)["id"])
			if tid == first_top:
				continue
			var two: Dictionary = one.duplicate(true)
			two["toppings"] = Catalog.canonical_toppings([first_top, tid])
			total += 1
			_check(Evaluator.unit_cost(two) > Evaluator.unit_cost(one) and Evaluator.prep_seconds(two) > Evaluator.prep_seconds(one), "토핑을 더하면 원가와 시간이 늘어야 해요")
			var after: Dictionary = _scores_of(two)
			var down: bool = false
			var up: bool = false
			for id in after:
				if int(after[id]) < int(base_scores[id]):
					down = true
				elif int(after[id]) > int(base_scores[id]):
					up = true
			if down:
				worse_somewhere += 1
			if up:
				better_somewhere += 1
			if up and down:
				mixed += 1
	_check(total == 972 * 3, "전수 조합 수 %d" % total)
	_check(worse_somewhere > 0 and better_somewhere > 0 and mixed > 0, "토핑 추가가 모두에게 좋지도 모두에게 나쁘지도 않아요 (나쁨 %d, 좋음 %d, 엇갈림 %d)" % [worse_somewhere, better_somewhere, mixed])
	_check(worse_somewhere < total, "토핑을 더해도 점수가 안 내려가는 경우도 있어요")
	_end()


# ---------- 등급 ----------

func test_rank_promotion() -> void:
	var titles: Array[String] = []
	for rk in Growth.RANKS:
		titles.append(str((rk as Dictionary)["title"]))
	_check(Growth.RANKS.size() == 3 and Growth.RANK_MAX == 3, "등급은 정확히 3단계")
	for st in Research.STAGES:
		_check(not titles.has(str((st as Dictionary)["title"])), "가게 등급 이름은 연구 칭호와 달라야 해요")
	var s: GameStateScript = _state_with_wallet(300000)
	var rv0: Dictionary = s.promotion_review()
	_check(s.rank() == 1 and not bool(rv0["top"]) and int(rv0["next"]) == 2 and (rv0["conditions"] as Array).size() == 3 and not bool(rv0["eligible"]), "처음: 1단계, 다음 2단계, 조건 3개, 신청 불가")
	var before: String = _json(s)
	for target in [-1, 0, 1, 3, 4, 99]:
		_check(not bool(s.apply_promotion(target)["ok"]) and _json(s) == before, "거부된 승급은 상태를 바꾸지 않아요: %d" % target)
	_check(not bool(s.apply_promotion(2)["ok"]) and _json(s) == before, "조건이 모자란 신청 거부")
	# 시식/연구/영업 어느 것도 저절로 승급시키지 않는다.
	var rec: Dictionary = _record_all_witnesses(s)
	_check(s.rank() == 1 and not bool(s.promotion_review()["eligible"]), "시식만으로는 승급/신청 가능이 아니에요")
	_check(bool(s.submit_research("dohyun_basic", int(rec["dohyun_basic"]))["ok"]), "연구 1건")
	var conds1: Array = s.promotion_review()["conditions"]
	_check(not bool((conds1[0] as Dictionary)["met"]) and bool((conds1[1] as Dictionary)["met"]) and bool((conds1[2] as Dictionary)["met"]), "영업 일수는 부족, 연구와 점수는 달성")
	_check(not bool(s.apply_promotion(2)["ok"]) and s.rank() == 1, "일수가 모자라면 신청 거부")
	s.select_record(int(rec["hayoung_basic"]))
	for i in 3:
		_check(bool(s.serve()["ok"]), "영업 %d일" % (i + 1))
	_check(s.rank() == 1, "조건을 채워도 신청 전에는 1단계")
	var rv2: Dictionary = s.promotion_review()
	_check(bool(rv2["eligible"]), "세 조건을 모두 채우면 신청 가능")
	for c in rv2["conditions"]:
		var cd: Dictionary = c
		_check(bool(cd["met"]) and str(cd["measured_text"]) != "" and str(cd["text"]) != "", "조건 문구/측정값")
	# 영업 중에는 신청할 수 없다.
	_check(bool(s.begin_service()["ok"]), "영업 시작")
	var busy_before: String = _json(s)
	_check(not bool(s.apply_promotion(2)["ok"]) and _json(s) == busy_before, "영업 중 승급 신청 거부")
	s.cancel_service()
	# 한 단계씩만, 보상 없이.
	var snap: String = _json(s)
	_check(not bool(s.apply_promotion(3)["ok"]) and _json(s) == snap, "단계를 건너뛰는 신청 거부")
	var wallet_before: int = s.wallet
	_check(bool(s.apply_promotion(2)["ok"]) and s.rank() == 2 and s.rank_title() == "동네 맛집", "2단계 승급")
	_check(s.wallet == wallet_before, "승급은 자금을 주지 않아요")
	_check(not bool(s.apply_promotion(2)["ok"]), "같은 승급을 두 번 할 수 없어요")
	var rv3: Dictionary = s.promotion_review()
	_check(int(rv3["next"]) == 3 and not bool(rv3["eligible"]), "3단계 조건은 아직 부족")
	_check(not bool(s.apply_promotion(3)["ok"]), "조건이 모자란 3단계 신청 거부")
	# 3단계: 연구 4건 + 영업 10일 + 세 단골 모두 80점 이상.
	for rid in ["hayoung_basic", "maru_basic", "dohyun_advanced"]:
		_check(bool(s.submit_research(rid, int(rec[rid]))["ok"]), "연구 제출 " + rid)
	_check(not bool(s.promotion_review()["eligible"]), "연구 4건이어도 영업 일수가 부족")
	while s.day < 11:
		_check(bool(s.serve()["ok"]), "영업 계속")
	_check(bool(s.promotion_review()["eligible"]), "일수/연구/점수를 채우면 3단계 신청 가능(증인 여섯 기록)")
	# 노트에서 기록을 모두 지우면 점수 조건이 다시 부족해지고, 증인을 다시 시식하면 채워진다(심사는 신청 순간의 기록만 본다).
	for r2 in s.records():
		s.delete_record(int((r2 as Dictionary)["record_id"]))
	var empty_review: Dictionary = s.promotion_review()
	_check(not bool(empty_review["eligible"]) and not bool(((empty_review["conditions"] as Array)[2] as Dictionary)["met"]), "기록이 없으면 점수 조건 부족")
	_check(not bool(s.apply_promotion(3)["ok"]) and s.rank() == 2, "기록이 없으면 신청 거부")
	for wid in ["dohyun_advanced", "hayoung_advanced", "maru_advanced"]:
		_taste_as(s, Research.WITNESSES[wid], "재심사 " + wid)
	var best: Dictionary = Growth.best_scores(s.records())
	for cid in Customers.ids():
		_check(int(best[cid]) >= 80, "증인 기록의 평가기 점수가 80 이상: %s %d" % [cid, int(best[cid])])
	_check(bool(s.apply_promotion(3)["ok"]) and s.rank() == 3 and s.rank_title() == "이름난 라멘집", "3단계 승급")
	var top: Dictionary = s.promotion_review()
	_check(bool(top["top"]) and int(top["next"]) == 0, "최고 등급 표시")
	var top_snap: String = _json(s)
	for target2 in [2, 3, 4]:
		_check(not bool(s.apply_promotion(target2)["ok"]) and _json(s) == top_snap, "최고 등급 이후 신청 거부: %d" % target2)
	_end()


# ---------- 유료 확장 ----------

func test_facility_purchase() -> void:
	_check(Growth.FACILITIES.size() == 4, "확장은 유한한 네 개")
	var seen: Dictionary = {}
	for f in Growth.FACILITIES:
		var fd: Dictionary = f
		_check(not seen.has(str(fd["id"])) and int(fd["price"]) > 0, "확장 id 유일/가격 양수")
		seen[str(fd["id"])] = true
		_check(str(fd["track"]) == "recipe" or str(fd["track"]) == "staff", "확장 줄")
	var s: GameStateScript = _state_with_wallet(100000)
	var before: String = _json(s)
	for id in ["bench_1", "bench_2", "staff_1", "staff_2", "", "nope"]:
		var res: Dictionary = s.purchase_facility(id)
		_check(not bool(res["ok"]) and str(res["message"]) != "" and _json(s) == before, "1단계에서는 구매 불가/불변: " + id)
	_check(str(s.facility_review("bench_1")["reason"]).find("등급") >= 0, "등급 부족 이유")
	_check(str(s.facility_review("bench_1")["effect_text"]).find("→") >= 0, "현재→새 용량 표시")

	var r2: GameStateScript = _ranked_state(2)
	var w: int = r2.wallet
	var snap: String = _json(r2)
	_check(not bool(r2.purchase_facility("bench_2")["ok"]) and not bool(r2.purchase_facility("staff_2")["ok"]) and _json(r2) == snap, "앞 단계/등급 없이 II단계 구매 불가")
	_check(r2.record_capacity() == 6 and r2.topping_slots() == 1 and r2.staff_capacity() == 2, "승급만으로는 용량이 늘지 않아요")
	# 구매 전 심사표의 효과 문구와 성공 메시지가 같아야 한다(구매 뒤 용량으로 다시 계산해 "2→2"가 되면 안 된다).
	var expect_text: String = str(r2.facility_review("bench_1")["effect_text"])
	_check(expect_text == "토핑 슬롯 1→2 · 노트 6→12", "구매 전 효과 문구: " + expect_text)
	var buy: Dictionary = r2.purchase_facility("bench_1")
	_check(bool(buy["ok"]), "조리대 I 구매: " + str(buy["message"]))
	_check(str(buy["message"]).find(expect_text) >= 0 and str(buy["message"]).find("2→2") < 0 and str(buy["message"]).find("12→12") < 0, "성공 메시지가 구매 전→후 변화를 그대로 알려요: " + str(buy["message"]))
	_check(r2.wallet == w - 12000 and r2.facilities_owned() == ["bench_1"], "정확히 12,000원 한 번 차감")
	_check(r2.topping_slots() == 2 and r2.record_capacity() == 12 and r2.staff_capacity() == 2, "조리대 I: 토핑 2, 노트 12, 직원 수는 그대로")
	var after_buy: String = _json(r2)
	_check(not bool(r2.purchase_facility("bench_1")["ok"]) and _json(r2) == after_buy, "같은 확장 재구매 불가, 자금 불변")
	_check(bool(r2.facility_review("bench_1")["owned"]) and not bool(r2.facility_review("bench_1")["can_buy"]), "보유 표시")
	# 직원 공간 확장의 성공 메시지도 구매 전→후(직원 2→3명)를 말한다. 자금이 모자라면 거부, 정확히 같으면 0원이 되고 음수는 없다.
	r2.wallet = 14999
	var poor: String = _json(r2)
	_check(not bool(r2.purchase_facility("staff_1")["ok"]) and _json(r2) == poor, "자금 1원 부족 거부")
	r2.wallet = 15000
	var staff_text: String = str(r2.facility_review("staff_1")["effect_text"])
	_check(staff_text.find("2→3") >= 0, "직원 공간 효과 문구: " + staff_text)
	var staff_buy: Dictionary = r2.purchase_facility("staff_1")
	_check(bool(staff_buy["ok"]) and r2.wallet == 0 and r2.staff_capacity() == 3, "정확한 자금으로 구매하면 0원, 음수 없음")
	_check(str(staff_buy["message"]).find(staff_text) >= 0 and str(staff_buy["message"]).find("3→3") < 0, "직원 공간 성공 메시지: " + str(staff_buy["message"]))
	# 영업 중에는 구매 불가.
	r2.wallet = 500000
	_check(bool(r2.begin_service()["ok"]), "영업 시작")
	var busy: String = _json(r2)
	_check(not bool(r2.purchase_facility("bench_2")["ok"]) and _json(r2) == busy, "영업 중 구매 거부")
	r2.cancel_service()
	_check(not bool(r2.purchase_facility("bench_2")["ok"]), "등급 2에서는 조리대 II 불가(등급 3 필요)")
	# 등급 3: 조리대 II 는 조리대 I 이 있어야 한다.
	var r3: GameStateScript = _ranked_state(3)
	var r3_snap: String = _json(r3)
	_check(not bool(r3.purchase_facility("bench_2")["ok"]) and not bool(r3.purchase_facility("staff_2")["ok"]) and _json(r3) == r3_snap, "앞 단계 없이 II 단계 거부")
	_check(str(r3.facility_review("bench_2")["reason"]).find("먼저") >= 0, "앞 단계 이유")
	var w3: int = r3.wallet
	_check(bool(r3.purchase_facility("bench_1")["ok"]), "조리대 I")
	var bench2: Dictionary = r3.purchase_facility("bench_2")
	_check(bool(bench2["ok"]) and str(bench2["message"]).find("토핑 슬롯 2→3 · 노트 12→30") >= 0, "조리대 II 성공 메시지: " + str(bench2["message"]))
	_check(r3.wallet == w3 - 12000 - 30000 and r3.topping_slots() == 3 and r3.record_capacity() == 30, "조리대 II: 토핑 3, 노트 30, 총 42,000원")
	# 자금 상한 근처에서도 정확히 차감.
	r3.wallet = GameStateScript.MAX_WALLET
	_check(bool(r3.purchase_facility("staff_1")["ok"]) and r3.wallet == GameStateScript.MAX_WALLET - 15000, "자금 상한에서도 정확히 차감")
	# 불러오기는 확장을 새로 주지 않는다.
	var loaded: GameStateScript = GameStateScript.new()
	_check(loaded.load_from_dict(JSON.parse_string(JSON.stringify(r3.to_dict()))) == "" and loaded.facilities_owned() == r3.facilities_owned() and loaded.wallet == r3.wallet, "저장/불러오기는 자금·확장을 그대로 유지")
	_end()


# ---------- 직원 ----------

func test_staff_hiring() -> void:
	_check(Staffing.STAFF.size() == 2 and Staffing.BASE_STAFF == 2, "기본 직원 2 + 보조 둘")
	var roles: Dictionary = {}
	for stf in Staffing.STAFF:
		var sd: Dictionary = stf
		roles[str(sd["role"])] = true
		_check(int(sd["hire_price"]) > 0 and int(sd["wage"]) > 0 and str(sd["name"]) != "" and str(sd["desc"]) != "", "고용비/운영비/이름 공개: " + str(sd["id"]))
	_check(roles.has("prep") and roles.has("floor") and roles.size() == 2, "조리 보조와 홀 보조")
	var s: GameStateScript = _state_with_wallet(100000)
	var before: String = _json(s)
	_check(s.staff_capacity() == 2 and s.free_staff_slots() == 0, "시작 직원 2명, 빈 자리 없음")
	_check(not bool(s.hire_staff("prep_assistant")["ok"]) and _json(s) == before, "직원 공간 없이는 고용 불가")
	_check(not bool(s.hire_staff("nope")["ok"]) and not bool(s.hire_staff("")["ok"]) and _json(s) == before, "알 수 없는 직원 거부")

	var g: GameStateScript = _grown_state(2)
	_check(g.staff_capacity() == 3 and g.free_staff_slots() == 1 and g.hired_staff().is_empty(), "직원 공간 확장은 자동 고용을 하지 않아요")
	var w: int = g.wallet
	var hire: Dictionary = g.hire_staff("prep_assistant")
	_check(bool(hire["ok"]), "조리 보조 고용: " + str(hire["message"]))
	_check(g.wallet == w - 8000 and g.hired_staff() == ["prep_assistant"] and g.free_staff_slots() == 0, "고용비 8,000원 한 번 차감")
	var after: String = _json(g)
	_check(not bool(g.hire_staff("prep_assistant")["ok"]) and _json(g) == after, "같은 직원 재고용 불가")
	_check(not bool(g.hire_staff("floor_assistant")["ok"]) and _json(g) == after, "자리가 없으면 다른 직원도 불가")
	_check(str(g.staff_review("floor_assistant")["reason"]).find("직원 공간") >= 0, "자리 부족 이유")
	# 자금 경계.
	var p: GameStateScript = _grown_state(2)
	p.wallet = 7999
	var p_snap: String = _json(p)
	_check(not bool(p.hire_staff("prep_assistant")["ok"]) and _json(p) == p_snap, "자금 1원 부족 거부")
	p.wallet = 8000
	_check(bool(p.hire_staff("prep_assistant")["ok"]) and p.wallet == 0, "정확한 자금으로 고용하면 0원")
	# 영업 중 고용 불가.
	var b: GameStateScript = _grown_state(2)
	b.wallet = 500000
	_check(bool(b.begin_service()["ok"]), "영업 시작")
	var b_snap: String = _json(b)
	_check(not bool(b.hire_staff("prep_assistant")["ok"]) and _json(b) == b_snap, "영업 중 고용 거부")
	b.cancel_service()
	# 둘 모두: 직원 공간 II 가 있어야 한다.
	var f: GameStateScript = _grown_state(3)
	_check(f.staff_capacity() == 4 and f.free_staff_slots() == 2 and f.hired_staff().is_empty(), "공간 II = 4명, 자동 고용 없음")
	var fw: int = f.wallet
	_check(bool(f.hire_staff("floor_assistant")["ok"]) and bool(f.hire_staff("prep_assistant")["ok"]), "둘 다 고용")
	_check(f.wallet == fw - 7000 - 8000 and f.free_staff_slots() == 0, "고용비 합 15,000원")
	var snap: Dictionary = f.current_staffing()
	_check(str(snap["hired"]) == str(["prep_assistant", "floor_assistant"]) and int(snap["wage"]) == 1100 and int(snap["prep_percent"]) == 80 and int(snap["serve_percent"]) == 70, "스냅샷은 카탈로그 순서, 운영비 합 1,100원")
	var none: Dictionary = Staffing.snapshot([])
	_check(int(none["wage"]) == 0 and int(none["prep_percent"]) == 100 and int(none["serve_percent"]) == 100, "고용 없음 = 기준 스냅샷")
	_check(Staffing.snapshot_error(snap) == "" and Staffing.snapshot_error({}) == "" and Staffing.snapshot_error(none) == "", "스냅샷 검증")
	var forged: Dictionary = snap.duplicate(true)
	forged["wage"] = 0
	_check(Staffing.snapshot_error(forged) != "", "변조된 스냅샷 거부")
	_end()


## 보조 직원의 효과: 점수가 아니라 시간/운영비. 기준(직원 없음)은 예전과 정확히 같다.
func test_staff_support_effects() -> void:
	var none: Dictionary = Staffing.snapshot([])
	var prep_only: Dictionary = Staffing.snapshot(["prep_assistant"])
	var floor_only: Dictionary = Staffing.snapshot(["floor_assistant"])
	var both: Dictionary = Staffing.snapshot(["prep_assistant", "floor_assistant"])
	for base_prep in range(1, 301):
		_check(Staffing.effective_prep(base_prep, {}) == base_prep and Staffing.effective_prep(base_prep, none) == base_prep, "직원 없음: 조리 시간 그대로")
		var eff: int = Staffing.effective_prep(base_prep, prep_only)
		_check(eff >= 1 and eff <= base_prep, "조리 보조는 시간을 늘리지 않아요")
		_check(Staffing.effective_prep(base_prep, floor_only) == base_prep, "홀 보조는 조리 시간을 건드리지 않아요")
	_check(Staffing.effective_prep(73, prep_only) == 59, "73초 → 59초(80% 올림)")
	for seat in SessionScript.SEAT_COUNT:
		var base_serve: int = SessionScript.SEAT_SERVE[seat]
		var base_back: int = maxi(1, base_serve * SessionScript.SERVE_BACK_PERCENT / 100)
		_check(Staffing.effective_carry(base_serve, {}) == base_serve and Staffing.effective_carry(base_serve, none) == base_serve, "직원 없음: 서빙 그대로")
		_check(Staffing.effective_return(base_serve, SessionScript.SERVE_BACK_PERCENT, none) == base_back, "직원 없음: 돌아오는 시간이 예전 공식과 같아요")
		_check(Staffing.effective_carry(base_serve, floor_only) < base_serve and Staffing.effective_return(base_serve, SessionScript.SERVE_BACK_PERCENT, floor_only) <= base_back, "홀 보조: 서빙/복귀가 빨라져요")
		_check(Staffing.effective_carry(base_serve, prep_only) == base_serve, "조리 보조는 서빙을 건드리지 않아요")
	# 판매 시뮬레이션: 기준 동일, 조리 보조는 수용량, 모두 운영비.
	var cfg: Dictionary = _fast_cfg()
	var scores: Dictionary = {"dohyun": 100, "hayoung": 100, "maru": 100}
	var base_sim: Dictionary = Sim.simulate(cfg, scores, 5)
	_check(str(Sim.simulate(cfg, scores, 5, none)) == str(base_sim), "직원 없음 스냅샷은 기준 시뮬레이션과 같아요")
	_check(int(base_sim["overhead"]) == Sim.OVERHEAD, "기준 운영비")
	var fast_sim: Dictionary = Sim.simulate(cfg, scores, 5, prep_only)
	_check(int(fast_sim["capacity"]) > int(base_sim["capacity"]) and int(fast_sim["overhead"]) == Sim.OVERHEAD + 600, "조리 보조: 수용량 증가, 운영비 +600")
	var floor_sim: Dictionary = Sim.simulate(cfg, scores, 5, floor_only)
	_check(int(floor_sim["capacity"]) == int(base_sim["capacity"]) and int(floor_sim["units"]) == int(base_sim["units"]) and int(floor_sim["overhead"]) == Sim.OVERHEAD + 500, "홀 보조: 수용량/판매는 같고 운영비 +500")
	_check(int(Sim.simulate(cfg, scores, 5, both)["overhead"]) == Sim.OVERHEAD + 1100, "둘 다: 운영비 +1,100")
	_check(int(fast_sim["net"]) == int(fast_sim["revenue"]) - int(fast_sim["ingredient_cost"]) - int(fast_sim["overhead"]), "순이익 식에 운영비 반영")
	_check(str(Sim.simulate(cfg, scores, 5, {"hired": [], "prep_percent": 50, "serve_percent": 100, "wage": 0})["error"]) != "", "임의로 만든 스냅샷 값은 거부")
	# 세션 타이밍: 한 손님의 완료 시각이 (접근 + 걷기 + 주문 + 조리 + 서빙 + 식사) 합과 정확히 같다.
	var st: GameStateScript = _state_with_recipe(_fast_cfg())
	var rec: Dictionary = st.get_record(st.selected_record_id)
	var kinds: Array = [["없음", none], ["조리 보조", prep_only], ["홀 보조", floor_only], ["둘 다", both]]
	var done_times: Dictionary = {}
	for k in kinds:
		var label: String = str((k as Array)[0])
		var snap: Dictionary = (k as Array)[1]
		var plan: Dictionary = SessionScript.make_plan(rec, 1, snap)
		_check(str(plan["error"]) == "", "계획 생성 " + label)
		plan["arrivals"] = [_arrival(10)]
		var sess: SessionScript = SessionScript.new(plan)
		_check(sess.run_to_end(), "하루 종료 " + label)
		var eff_prep: int = Staffing.effective_prep(Evaluator.prep_seconds(rec["config"]), snap)
		var expected: int = 10 + (SessionScript.APPROACH_GS - 1) + SessionScript.SEAT_WALK[0] + SessionScript.ORDER_GS + eff_prep + Staffing.effective_carry(SessionScript.SEAT_SERVE[0], snap) + SessionScript.EAT_GS
		var done: Dictionary = sess.completed[0]
		_check(int(done["done_t"]) == expected, "%s: 완료 시각 %d, 기대 %d" % [label, int(done["done_t"]), expected])
		done_times[label] = int(done["done_t"])
		_check(sess.prep == eff_prep, label + ": 세션 조리 시간")
		_check(int(sess.summary()["overhead"]) == Sim.OVERHEAD + int(snap["wage"]), label + ": 요약 운영비")
	_check(int(done_times["조리 보조"]) < int(done_times["없음"]) and int(done_times["홀 보조"]) < int(done_times["없음"]) and int(done_times["둘 다"]) < int(done_times["조리 보조"]), "보조가 있으면 첫 그릇이 더 빨리 나와요")
	# 몰리는 날: 기다린 시간의 합이 줄어든다(점수는 그대로 100).
	var crowd: Array = []
	for i in 6:
		crowd.append(_arrival(5))
	var waits: Dictionary = {}
	for k2 in kinds:
		var label2: String = str((k2 as Array)[0])
		var plan2: Dictionary = SessionScript.make_plan(rec, 1, (k2 as Array)[1])
		plan2["arrivals"] = crowd.duplicate(true)
		plan2["scores"] = scores
		var s2: SessionScript = SessionScript.new(plan2)
		_check(s2.run_to_end() and s2.completed.size() == 6, "몰린 날 종료 " + label2)
		waits[label2] = _sum_waits(s2)
	_check(int(waits["홀 보조"]) < int(waits["없음"]), "홀 보조: 총 대기 시간이 줄어요 (%d → %d)" % [int(waits["없음"]), int(waits["홀 보조"])])
	_check(int(waits["조리 보조"]) < int(waits["없음"]), "조리 보조: 총 대기 시간이 줄어요 (%d → %d)" % [int(waits["없음"]), int(waits["조리 보조"])])
	_end()


## 정산: 운영비는 끝까지 마친 영업에서 정확히 한 번. 시작만 하고 중단하면 아무 변화/청구가 없다. 스냅샷은 영업 중 바뀌지 않는다.
func test_staff_settlement_and_snapshot() -> void:
	var g: GameStateScript = _grown_state(3)
	g.select_record(int((g.records()[0] as Dictionary)["record_id"]))
	g.wallet = 500000
	var rec: Dictionary = g.get_record(g.selected_record_id)
	var base_fc: Dictionary = g.forecast()
	_check(str(base_fc) == str(Sim.simulate(rec["config"], rec["scores"], g.day)), "고용 전 예측은 기준 계산과 같아요")
	_check(int(base_fc["overhead"]) == Sim.OVERHEAD, "고용 전 운영비 3,000원")
	_check(bool(g.hire_staff("prep_assistant")["ok"]) and bool(g.hire_staff("floor_assistant")["ok"]), "둘 고용")
	var fc: Dictionary = g.forecast()
	_check(int(fc["overhead"]) == Sim.OVERHEAD + 1100 and int(fc["capacity"]) >= int(base_fc["capacity"]), "고용 후 예측: 운영비 +1,100")
	var w0: int = g.wallet
	var day0: int = g.day
	var before_start: String = _json(g)
	_check(bool(g.begin_service()["ok"]), "영업 시작")
	_check(g.wallet == w0 and g.day == day0 and _json(g) == before_start, "영업 시작은 자금/일차/저장 상태를 바꾸지 않아요(운영비 선청구 없음)")
	var sess: SessionScript = g.active_session()
	_check(str(sess.staffing) == str(g.current_staffing()) and int(sess.growth_snapshot["rank"]) == 3 and int(sess.growth_snapshot["topping_slots"]) == 3, "세션은 직원/성장 스냅샷을 복사해 가져요")
	_check(sess.prep == Staffing.effective_prep(Evaluator.prep_seconds(rec["config"]), sess.staffing), "세션 조리 시간은 스냅샷 값")
	_check(sess.run_to_end(), "하루 종료")
	_check(g.wallet == w0, "끝나도 정산 전에는 자금 불변")
	var res: Dictionary = g.settle_service()
	_check(bool(res["ok"]), "정산: " + str(res["message"]))
	var rep: Dictionary = g.last_report
	_check(int(rep["overhead"]) == Sim.OVERHEAD + 1100, "보고 운영비 = 기본 + 보조 운영비")
	_check(int(rep["net"]) == int(rep["revenue"]) - int(rep["ingredient_cost"]) - Sim.OVERHEAD - 1100, "순이익 식")
	_check(g.wallet == w0 + int(rep["net"]) and int(rep["wallet_after"]) == g.wallet, "자금은 순이익만큼 정확히 한 번 바뀌어요(운영비 이중 청구 없음)")
	_check(int(rep["net"]) == int(fc["net"]), "정산 결과 = 고용 후 예측")
	var after: String = _json(g)
	_check(not bool(g.settle_service()["ok"]) and _json(g) == after and g.day == day0 + 1, "두 번째 정산 불가")
	var reloaded: GameStateScript = GameStateScript.new()
	_check(reloaded.load_from_dict(JSON.parse_string(JSON.stringify(g.to_dict()))) == "" and _json(reloaded) == after, "운영비가 든 보고도 저장 검증을 통과")
	# 영업 중 고용/구매/승급은 막히고 세션 스냅샷은 그대로(고용 전 스냅샷).
	var h: GameStateScript = _grown_state(3)
	h.select_record(int((h.records()[0] as Dictionary)["record_id"]))
	h.wallet = 500000
	_check(bool(h.begin_service()["ok"]), "고용 전 영업 시작")
	var hs: SessionScript = h.active_session()
	var frozen: String = str(hs.staffing)
	var h_snap: String = _json(h)
	_check(not bool(h.hire_staff("prep_assistant")["ok"]) and not bool(h.purchase_facility("bench_1")["ok"]) and not bool(h.apply_promotion(3)["ok"]), "영업 중 성장 행동 모두 거부")
	_check(_json(h) == h_snap and str(hs.staffing) == frozen and int(hs.staffing["wage"]) == 0, "스냅샷은 영업 중에 바뀌지 않아요")
	h.cancel_service()
	_check(bool(h.hire_staff("prep_assistant")["ok"]), "중단 뒤에는 고용 가능")
	_check(str(hs.staffing) == frozen, "이미 닫힌 세션의 스냅샷도 그대로")
	# 시작 후 중단: 자금/일차/운영비 변화 없음.
	var c: GameStateScript = _grown_state(3)
	c.select_record(int((c.records()[0] as Dictionary)["record_id"]))
	c.wallet = 500000
	_check(bool(c.hire_staff("floor_assistant")["ok"]), "홀 보조 고용")
	var c_before: String = _json(c)
	_check(bool(c.begin_service()["ok"]), "영업 시작")
	c.active_session().advance(1200.0)
	_check(c.active_session().completed.size() > 0, "전제: 일부 주문 완료")
	c.cancel_service()
	_check(_json(c) == c_before and c.wallet == 500000 - 7000, "시작 후 중단은 아무것도 청구/지급하지 않아요")
	# 정산 직전 고용 목록/스냅샷이 어긋나면 거부(변조 방어).
	var t: GameStateScript = _grown_state(3)
	t.select_record(int((t.records()[0] as Dictionary)["record_id"]))
	t.wallet = 500000
	_check(bool(t.hire_staff("prep_assistant")["ok"]), "변조 시험 준비: 고용")
	_check(bool(t.begin_service()["ok"]) and t.active_session().run_to_end(), "변조 시험 준비: 영업")
	var t_snap: String = _json(t)
	t._hired.clear()
	_check(not bool(t.settle_service()["ok"]), "직원 구성이 달라지면 정산 거부")
	t._hired.append("prep_assistant")
	_check(_json(t) == t_snap, "거부 후 상태 불변")
	t.active_session().staffing["wage"] = 0
	_check(not bool(t.settle_service()["ok"]) and _json(t) == t_snap, "스냅샷 운영비가 변조되면 정산 거부")
	_end()


# ---------- 노트 용량 / grandfather ----------

func test_record_capacity_and_grandfather() -> void:
	var s: GameStateScript = _state_with_wallet(500000)
	_check(s.record_capacity() == 6, "기본 노트 용량 6")
	s.set_draft_name("용량 시험")
	for i in 6:
		s.set_draft_price(9000 + 100 * i)
		_check(bool(s.taste()["ok"]), "개정 시식 %d" % i)
	_check(s.record_count() == 6, "6개")
	var w: int = s.wallet
	s.set_draft_price(9700)
	var full: String = _json(s)
	var over: Dictionary = s.taste()
	_check(not bool(over["ok"]) and str(over["message"]).find("6") >= 0 and _json(s) == full and s.wallet == w, "7번째는 거부, 자금/기록 불변")
	_check(_grown_state(2).record_capacity() == 12 and _grown_state(3).record_capacity() == 30, "용량 12 / 30")
	_check(GameStateScript.MAX_RECORDS == 30 and Growth.notebook_capacity(["bench_1", "bench_2"]) == 30, "절대 상한 30")

	# grandfather: 예전 저장이 새 기본 용량(6)보다 많은 기록(8개)을 가졌다. 모두 보존되고 불러와지며, 새 시식만 막힌다.
	var g: GameStateScript = _grown_state(3)
	g.start_new_recipe()
	_apply_cfg(g, _rich_cfg())
	g.set_draft_name("과거 레시피")
	for i in 2:
		g.set_draft_price(9500 + 100 * i)
		_check(bool(g.taste()["ok"]), "과거 기록 추가 %d" % i)
	_check(g.record_count() == 8, "전제: 기록 8개")
	var src_records: String = str(g.records())
	var legacy: Dictionary = _as_legacy(g.to_dict(), 2)
	var keep: GameStateScript = GameStateScript.new()
	_check(keep.load_from_dict(legacy) == "", "용량보다 많은 예전 저장도 불러와져요")
	_check(keep.record_count() == 8 and str(keep.records()) == src_records, "기록/계통/개정/비교가 모두 그대로")
	_check(keep.selected_record_id == g.selected_record_id and keep.wallet == g.wallet and keep.day == g.day and keep.research_points() == 21, "선택/자금/일차/연구 점수 보존")
	_check(keep.rank() == 1 and keep.facilities_owned().is_empty() and keep.hired_staff().is_empty(), "예전 저장은 등급 1, 확장/직원 없음(공짜 성장 없음)")
	_check(keep.record_capacity() == 6 and keep.topping_slots() == 1, "용량은 파생: 6, 토핑 1")
	# 중복 구성 규칙에 걸리지 않도록 가격을 새로 정한 뒤 용량 규칙만 확인한다.
	keep.set_draft_price(21000)
	var k_snap: String = _json(keep)
	var blocked: Dictionary = keep.taste()
	_check(not bool(blocked["ok"]) and str(blocked["message"]).find("8/6") >= 0 and keep.record_count() == 8 and _json(keep) == k_snap, "초과 보관 중에는 새 시식 거부, 상태 불변: " + str(blocked["message"]))
	# v3 로 저장했다 다시 불러와도 8개를 유지한다.
	var rt: GameStateScript = GameStateScript.new()
	_check(rt.load_from_dict(JSON.parse_string(JSON.stringify(keep.to_dict()))) == "" and rt.record_count() == 8, "v3 로 저장해도 8개 유지")
	_check(bool(keep.select_record(int((keep.records()[7] as Dictionary)["record_id"]))["ok"]) and bool(keep.begin_service()["ok"]), "초과 보관 상태에서도 선택/영업은 정상")
	keep.cancel_service()
	# 삭제로 개수가 용량 아래(5개)로 내려가야 다시 시식할 수 있다.
	for i in 3:
		_check(bool(keep.delete_record(int((keep.records()[0] as Dictionary)["record_id"]))["ok"]), "삭제 %d" % i)
	_check(keep.record_count() == 5, "5개")
	keep.start_new_recipe()
	keep.set_draft_name("새 시제품")
	keep.set_draft_price(17000)
	var fresh: Dictionary = keep.taste()
	_check(bool(fresh["ok"]) and keep.record_count() == 6, "용량 아래로 내려오면 시식 가능: " + str(fresh["message"]))
	_end()


# ---------- 스키마 이행 / 거부 ----------

func test_schema_migration_v1_v2() -> void:
	for version in [1, 2]:
		var dir: String = _case_dir("migrate_v%d" % version)
		var saver: SaveServiceScript = SaveServiceScript.new(dir)
		saver.remove_known_files()
		var src: GameStateScript = _populated_state()
		if version == 2:
			# v2 는 실제 연구 영수증 하나를 가진다.
			var rid: int = _taste_as(src, Research.WITNESSES["hayoung_basic"], "이행 연구")
			_check(bool(src.submit_research("hayoung_basic", rid)["ok"]), "v2 픽스처: 연구 제출")
		var legacy_text: String = JSON.stringify(_as_legacy(src.to_dict(), version), "\t", true)
		_write_text(saver.main_path(), legacy_text)
		var loaded: GameStateScript = GameStateScript.new()
		var lr: Dictionary = saver.load_into(loaded)
		_check(str(lr["status"]) == "ok", "v%d 불러오기: %s" % [version, str(lr["message"])])
		_check(loaded.day == src.day and loaded.wallet == src.wallet and loaded.next_record_id == src.next_record_id and loaded.next_lineage_id == src.next_lineage_id, "v%d: 일차/자금/일련번호" % version)
		_check(str(loaded.records()) == str(src.records()), "v%d: 기록(구성·점수·비교)이 의미상 같아요" % version)
		for rr in loaded.records():
			var rd: Dictionary = rr
			_check(str(rd["scores"]) == str(_scores_of(rd["config"])) and (rd["config"] as Dictionary).has("toppings") and not (rd["config"] as Dictionary).has("topping"), "v%d: 점수는 그대로, 토핑은 정규 배열" % version)
		_check(loaded.selected_record_id == src.selected_record_id and loaded.last_feedback_record_id == src.last_feedback_record_id and str(loaded.last_report) == str(src.last_report), "v%d: 선택/피드백/마지막 영업 보고" % version)
		_check(loaded.draft_name == src.draft_name and str(loaded.draft_config) == str(src.draft_config), "v%d: 초안" % version)
		_check(str(loaded.research_receipts()) == (str(src.research_receipts()) if version == 2 else "[]"), "v%d: 연구 영수증" % version)
		_check(loaded.rank() == 1 and loaded.facilities_owned().is_empty() and loaded.hired_staff().is_empty(), "v%d: 등급/확장/직원은 기본(불러오기로 생기는 것 없음)" % version)
		_check(FileAccess.get_file_as_string(saver.main_path()) == legacy_text, "v%d: 불러오기만으로 파일을 바꾸지 않아요" % version)
		_check(not FileAccess.file_exists(saver.legacy_bak_path(version)), "v%d: 불러오기만으로 보관본을 만들지 않아요" % version)
		# 첫 v3 저장: 원본이 .bak 와 버전별 보관본에 모두 남는다.
		_check(bool(saver.save_state(loaded)["ok"]), "v%d: 이행 후 저장" % version)
		_check(FileAccess.get_file_as_string(saver.bak_path()) == legacy_text and FileAccess.get_file_as_string(saver.legacy_bak_path(version)) == legacy_text, "v%d: 원본이 백업과 이행 보관본에 보존" % version)
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(saver.main_path()))
		_check(typeof(parsed) == TYPE_DICTIONARY and int((parsed as Dictionary)["schema_version"]) == 3 and (parsed as Dictionary).has("growth"), "v%d: 새 파일은 v3" % version)
		# 두 번째 저장은 일반 .bak 만 갱신하고 이행 보관본(원본)은 다시 만들지도 덮어쓰지도 않는다.
		loaded.wallet += 1
		_check(bool(saver.save_state(loaded)["ok"]), "v%d: 두 번째 저장" % version)
		_check(FileAccess.get_file_as_string(saver.legacy_bak_path(version)) == legacy_text, "v%d: 이행 보관본은 다시 덮어쓰지 않아요" % version)
		_check(FileAccess.get_file_as_string(saver.bak_path()) != legacy_text, "v%d: 일반 백업은 직전 v3 저장" % version)
		var again: GameStateScript = GameStateScript.new()
		_check(str(saver.load_into(again)["status"]) == "ok" and _json(again) == _json(loaded), "v%d: v3 왕복" % version)
		_cleanup_case(saver)
	# 모양과 버전이 어긋난 파일은 거부(옛 토핑 키를 v3 가 쓰거나, 새 키를 v2 가 쓰기).
	var v3: Dictionary = JSON.parse_string(JSON.stringify(_populated_state().to_dict()))
	var v2_with_growth: Dictionary = _as_legacy(_populated_state().to_dict(), 2)
	v2_with_growth["growth"] = v3["growth"]
	_check(GameStateScript.new().load_from_dict(v2_with_growth) != "", "growth 가 있는 v2 거부")
	var v2_new_cfg: Dictionary = JSON.parse_string(JSON.stringify(_populated_state().to_dict()))
	v2_new_cfg["schema_version"] = 2
	v2_new_cfg.erase("growth")
	_check(GameStateScript.new().load_from_dict(v2_new_cfg) != "", "toppings 배열을 쓴 v2 거부")
	var v3_old_cfg: Dictionary = _as_legacy(_populated_state().to_dict(), 3)
	v3_old_cfg["growth"] = v3["growth"]
	_check(GameStateScript.new().load_from_dict(v3_old_cfg) != "", "topping 문자열을 쓴 v3 거부")
	_end()


func test_growth_load_rejections() -> void:
	# 풍부한 v3 기준 상태: 등급 3, 확장 4개, 보조 직원 1명, 토핑 2·3개짜리 기록과 개정 비교.
	var g: GameStateScript = _grown_state(3)
	_check(bool(g.hire_staff("prep_assistant")["ok"]), "기준 상태: 고용")
	g.start_new_recipe()
	_apply_cfg(g, _rich_cfg())
	g.set_draft_name("다중 토핑")
	_check(bool(g.set_draft_toppings(["topping_chashu", "topping_egg", "topping_nori"])["ok"]), "기준 상태: 토핑 3개")
	var first: Dictionary = g.taste()
	_check(bool(first["ok"]), "기준 상태: 시식 " + str(first["message"]))
	_check(bool(g.set_draft_toppings(["topping_chashu", "topping_egg"])["ok"]), "기준 상태: 토핑 2개")
	_check(bool(g.taste()["ok"]), "기준 상태: 개정 시식")
	var base: Dictionary = JSON.parse_string(JSON.stringify(g.to_dict()))
	var ok_probe: GameStateScript = GameStateScript.new()
	_check(ok_probe.load_from_dict(base) == "" and _json(ok_probe) == _json(g), "정상 v3 는 float 숫자여도 불러와져요")
	var labels: Array[String] = [
		"토핑 순서 섞임", "토핑 중복", "토핑 4개", "알 수 없는 토핑", "토핑 비어 있음", "옛 topping 키", "toppings 문자열", "비교 구성 순서 섞임",
		"초안 토핑 순서 섞임", "슬롯 초과(등급 1)", "슬롯 초과(조리대 I 만)", "growth 누락", "growth 추가 키", "growth 구조", "등급 4", "등급 0",
		"등급 문자열", "등급 소수", "알 수 없는 확장", "확장 중복", "확장 순서(II 먼저)", "확장 id 형식", "알 수 없는 직원", "직원 중복",
		"직원 공간 초과", "직원 id 형식", "facilities 구조", "staff 구조", "연구 없이 승급", "확장 등급 부족",
	]
	for label in labels:
		var copy: Dictionary = base.duplicate(true)
		var crecords: Array = copy["records"]
		var clast: Dictionary = crecords[crecords.size() - 1]
		var cgrowth: Dictionary = {}
		if copy.has("growth") and copy["growth"] is Dictionary:
			cgrowth = copy["growth"]
		match label:
			"토핑 순서 섞임":
				(clast["config"] as Dictionary)["toppings"] = ["topping_egg", "topping_chashu"]
			"토핑 중복":
				(clast["config"] as Dictionary)["toppings"] = ["topping_egg", "topping_egg"]
			"토핑 4개":
				(clast["config"] as Dictionary)["toppings"] = ["topping_chashu", "topping_egg", "topping_sprouts", "topping_nori"]
			"알 수 없는 토핑":
				(clast["config"] as Dictionary)["toppings"] = ["topping_unknown"]
			"토핑 비어 있음":
				(clast["config"] as Dictionary)["toppings"] = []
			"옛 topping 키":
				(clast["config"] as Dictionary)["topping"] = "topping_egg"
			"toppings 문자열":
				(clast["config"] as Dictionary)["toppings"] = "topping_egg"
			"비교 구성 순서 섞임":
				((clast["comparison"] as Dictionary)["prev_config"] as Dictionary)["toppings"] = ["topping_nori", "topping_egg", "topping_chashu"]
			"초안 토핑 순서 섞임":
				((copy["draft"] as Dictionary)["config"] as Dictionary)["toppings"] = ["topping_egg", "topping_chashu"]
			"슬롯 초과(등급 1)":
				cgrowth["rank"] = 1
				cgrowth["facilities"] = []
				cgrowth["staff"] = []
			"슬롯 초과(조리대 I 만)":
				cgrowth["facilities"] = ["bench_1", "staff_1", "staff_2"]
			"growth 누락":
				copy.erase("growth")
			"growth 추가 키":
				cgrowth["bonus"] = 1
			"growth 구조":
				copy["growth"] = []
			"등급 4":
				cgrowth["rank"] = 4
			"등급 0":
				cgrowth["rank"] = 0
			"등급 문자열":
				cgrowth["rank"] = "3"
			"등급 소수":
				cgrowth["rank"] = 2.5
			"알 수 없는 확장":
				cgrowth["facilities"] = ["bench_1", "bench_9"]
			"확장 중복":
				cgrowth["facilities"] = ["bench_1", "bench_1", "bench_2", "staff_1", "staff_2"]
			"확장 순서(II 먼저)":
				cgrowth["facilities"] = ["bench_2", "bench_1", "staff_1", "staff_2"]
			"확장 id 형식":
				cgrowth["facilities"] = [5]
			"알 수 없는 직원":
				cgrowth["staff"] = ["boss"]
			"직원 중복":
				cgrowth["staff"] = ["prep_assistant", "prep_assistant"]
			"직원 공간 초과":
				cgrowth["facilities"] = ["bench_1", "bench_2"]
				cgrowth["staff"] = ["prep_assistant"]
			"직원 id 형식":
				cgrowth["staff"] = [1]
			"facilities 구조":
				cgrowth["facilities"] = "bench_1"
			"staff 구조":
				cgrowth["staff"] = {}
			"연구 없이 승급":
				(copy["research"] as Dictionary)["completed"] = []
			"확장 등급 부족":
				cgrowth["rank"] = 1
				cgrowth["facilities"] = ["bench_1"]
				cgrowth["staff"] = []
			_:
				_failures.append("알 수 없는 변조 이름: " + label)
		var target: GameStateScript = GameStateScript.new()
		target.wallet = 12345
		var snapshot: String = _json(target)
		var err: String = target.load_from_dict(copy)
		_check(err != "", "거부돼야 해요: " + label)
		_check(_json(target) == snapshot and target.rank() == 1 and target.facilities_owned().is_empty() and target.hired_staff().is_empty(), "거부된 로드는 상태를 바꾸면 안 돼요: " + label)
	# 새 게임(일차 1)에 승급/구매/고용이 있는 저장은 파생 사실과 모순이라 거부.
	var fresh: Dictionary = JSON.parse_string(JSON.stringify(GameStateScript.new().to_dict()))
	var fakes: Array = [{"rank": 2, "facilities": [], "staff": []}, {"rank": 1, "facilities": ["bench_1"], "staff": []}, {"rank": 1, "facilities": [], "staff": ["floor_assistant"]}]
	for fake in fakes:
		var fcopy: Dictionary = fresh.duplicate(true)
		fcopy["growth"] = fake
		var tgt: GameStateScript = GameStateScript.new()
		_check(tgt.load_from_dict(fcopy) != "" and tgt.rank() == 1, "일차 1에서 가짜 성장 상태 거부: " + str(fake))
	# 저장 서비스: 변조된 v3 파일은 corrupt 로 보고하고 파일/상태를 건드리지 않는다.
	var dir: String = _case_dir("growth_corrupt")
	var saver: SaveServiceScript = SaveServiceScript.new(dir)
	saver.remove_known_files()
	var bad: Dictionary = base.duplicate(true)
	(bad["growth"] as Dictionary)["rank"] = 4
	var bad_text: String = JSON.stringify(bad, "\t", true)
	_write_text(saver.main_path(), bad_text)
	var probe: GameStateScript = GameStateScript.new()
	var snap0: String = _json(probe)
	var lr: Dictionary = saver.load_into(probe)
	_check(str(lr["status"]) == "corrupt" and FileAccess.get_file_as_string(saver.main_path()) == bad_text and _json(probe) == snap0, "변조된 v3 파일: corrupt, 파일/상태 불변")
	var future: Dictionary = base.duplicate(true)
	future["schema_version"] = GameStateScript.SCHEMA_VERSION + 1
	var future_text: String = JSON.stringify(future, "\t", true)
	_write_text(saver.main_path(), future_text)
	_check(str(saver.load_into(GameStateScript.new())["status"]) == "unsupported" and FileAccess.get_file_as_string(saver.main_path()) == future_text, "미래 버전은 unsupported 로 보존")
	_cleanup_case(saver)
	_end()


## 읽기/불러오기/시식/화면 갱신에 해당하는 호출은 등급·자금·직원을 만들지 않는다. 경계값에서도 자금은 음수/초과가 되지 않는다.
func test_no_phantom_rewards_and_bounds() -> void:
	var s: GameStateScript = _ranked_state(1)
	_check(s.rank() == 1 and bool(s.promotion_review()["eligible"]), "조건을 채웠어도 신청 전에는 1단계")
	var before: String = _json(s)
	s.promotion_review()
	s.facility_reviews()
	s.staff_reviews()
	s.current_staffing()
	s.growth_snapshot()
	s.forecast()
	s.records()
	_check(_json(s) == before, "읽기 전용 호출은 상태를 바꾸지 않아요")
	var loaded: GameStateScript = GameStateScript.new()
	_check(loaded.load_from_dict(JSON.parse_string(JSON.stringify(s.to_dict()))) == "" and loaded.rank() == 1 and loaded.wallet == s.wallet and loaded.hired_staff().is_empty() and loaded.facilities_owned().is_empty(), "불러오기는 등급/자금/직원을 만들지 않아요")
	_check(bool(loaded.promotion_review()["eligible"]) and loaded.rank() == 1, "불러온 뒤에도 신청 전에는 1단계")
	# 시식/영업 어느 것도 등급을 올리지 않는다(노트가 가득이라 증인 기록 하나를 지워 자리를 만든 뒤 실제로 시식한다).
	_check(bool(s.delete_record(int((s.records()[0] as Dictionary)["record_id"]))["ok"]), "시험 준비: 기록 하나 삭제")
	s.start_new_recipe()
	_apply_cfg(s, _rich_cfg(10100))
	s.set_draft_name("승급 없음 시험")
	_check(bool(s.taste()["ok"]), "시식")
	_check(bool(s.serve()["ok"]), "영업")
	_check(s.rank() == 1, "시식/영업이 승급시키지 않아요")
	# 자금 경계.
	var z: GameStateScript = _ranked_state(2)
	z.wallet = 0
	var z_snap: String = _json(z)
	_check(not bool(z.purchase_facility("bench_1")["ok"]) and _json(z) == z_snap and z.wallet == 0, "자금 0원: 구매 거부, 음수 없음")
	z.wallet = GameStateScript.MAX_WALLET
	_check(not bool(z.apply_promotion(3)["ok"]) and z.wallet == GameStateScript.MAX_WALLET, "조건 부족 승급은 자금과 무관하게 거부")
	_check(bool(z.purchase_facility("bench_1")["ok"]) and z.wallet == GameStateScript.MAX_WALLET - 12000, "자금 상한에서 구매하면 정확히 차감")
	_check(bool(z.purchase_facility("staff_1")["ok"]) and bool(z.hire_staff("floor_assistant")["ok"]) and z.wallet == GameStateScript.MAX_WALLET - 12000 - 15000 - 7000, "연속 거래 합계가 정확")
	# 자금이 상한이면 이익이 나는 영업은 기존 규칙대로 시작되지 않고(운영비가 있어도 상한 검사 그대로), 시작되면 순이익이 0 이하다.
	z.select_record(int((z.records()[0] as Dictionary)["record_id"]))
	z.wallet = GameStateScript.MAX_WALLET
	var top_snap: String = _json(z)
	var begin: Dictionary = z.begin_service()
	if bool(begin["ok"]):
		var fc_net: int = int(z.forecast()["net"])
		z.cancel_service()
		_check(fc_net <= 0, "자금이 상한이면 순이익이 양수인 영업은 시작되지 않아요")
	else:
		_check(_json(z) == top_snap, "거부된 시작은 상태를 바꾸지 않아요")
	_end()


# ---------- 성장 UI 단계: 그림/장면 ----------

func _close(a: Color, b: Color) -> bool:
	return absf(a.r - b.r) < 0.01 and absf(a.g - b.g) < 0.01 and absf(a.b - b.b) < 0.01 and absf(a.a - b.a) < 0.01


## 점 p 에서 선분 a-b 까지의 거리(격자 칸).
func _dist_to_segment(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab: Vector2 = b - a
	var len2: float = ab.length_squared()
	if len2 <= 0.0:
		return p.distance_to(a)
	var t: float = clampf((p - a).dot(ab) / len2, 0.0, 1.0)
	return p.distance_to(a + ab * t)


func test_growth_bowl_and_portrait_art() -> void:
	# 토핑 하나: 옛 모양/정규 모양이 같은 그림이고, 예전 고정 위치에 그려진다(단일 토핑의 모습이 바뀌지 않는다).
	for tid in ["topping_chashu", "topping_egg", "topping_sprouts", "topping_nori"]:
		var legacy: Dictionary = _cfg("broth_dashi", "tare_shio", "oil_scallion", "noodle_thin", tid, "cook_firm", 9000)
		var canon: Dictionary = Catalog.normalize_config(legacy)
		_check(ArtScript.bowl_image(legacy).get_data() == ArtScript.bowl_image(canon).get_data(), "옛/정규 단일 토핑 그릇이 같아야 해요: " + tid)
	var one: Image = ArtScript.bowl_image(_rich_cfg())
	_check(_close(one.get_pixel(2, 1), Color(0.80, 0.54, 0.44)) and _close(one.get_pixel(3, 2), Color(0.80, 0.54, 0.44)), "단일 차슈는 예전 위치(2,1)/(3,2)")
	var nori1: Image = ArtScript.bowl_image(_cfg("broth_dashi", "tare_shio", "oil_scallion", "noodle_thin", "topping_nori", "cook_firm", 9000))
	_check(_close(nori1.get_pixel(8, 0), Color(0.12, 0.20, 0.16)) and _close(nori1.get_pixel(9, 1), Color(0.12, 0.20, 0.16)), "단일 김은 예전 위치(8,0)")
	# 여러 토핑: 모두 그려지고 서로 구별되며 순서와 무관하다.
	var base: Dictionary = Catalog.normalize_config(_light_cfg())
	var two: Dictionary = base.duplicate(true)
	two["toppings"] = ["topping_egg", "topping_nori"]
	var two_rev: Dictionary = base.duplicate(true)
	two_rev["toppings"] = ["topping_nori", "topping_egg"]
	var three: Dictionary = base.duplicate(true)
	three["toppings"] = ["topping_chashu", "topping_egg", "topping_nori"]
	var img2: Image = ArtScript.bowl_image(two)
	var img3: Image = ArtScript.bowl_image(three)
	_check(img2.get_data() == ArtScript.bowl_image(two_rev).get_data(), "토핑 순서가 달라도 같은 그릇")
	_check(img2.get_width() == 12 and img2.get_height() == 7 and img3.get_width() == 12 and img3.get_height() == 7, "그릇 크기(12x7)는 그대로")
	_check(_close(img2.get_pixel(2, 1), WHITE_COLOR()) and _close(img2.get_pixel(8, 0), Color(0.12, 0.20, 0.16)), "둘: 반숙란 왼쪽, 김 오른쪽")
	_check(_close(img3.get_pixel(2, 1), Color(0.80, 0.54, 0.44)) and _close(img3.get_pixel(5, 1), WHITE_COLOR()) and _close(img3.get_pixel(8, 0), Color(0.12, 0.20, 0.16)), "셋: 차슈/반숙란/김이 왼쪽/가운데/오른쪽")
	var only_egg: Dictionary = base.duplicate(true)
	only_egg["toppings"] = ["topping_egg"]
	_check(img2.get_data() != ArtScript.bowl_image(only_egg).get_data() and img3.get_data() != img2.get_data(), "토핑 수/종류가 다르면 그릇이 달라요")
	var swapped: Dictionary = base.duplicate(true)
	swapped["toppings"] = ["topping_sprouts", "topping_nori"]
	_check(ArtScript.bowl_image(swapped).get_data() != img2.get_data(), "토핑 종류가 다르면 그릇이 달라요")
	# 보조 직원 외형/초상.
	_check(ArtScript.LOOK_PREP_ASSISTANT == 12 and ArtScript.LOOK_FLOOR_ASSISTANT == 13 and ArtScript.look_count() >= 14, "보조 직원 외형 번호")
	var stand_sigs: Dictionary = {}
	for look in ArtScript.look_count():
		for pose in ["stand", "walk", "sit", "carry", "cook"]:
			for back in [false, true]:
				var im: Image = ArtScript.person_image(look, pose, 1, back)
				_check(im.get_width() == 14 and im.get_height() == 18, "사람 스프라이트 크기 %d %s" % [look, pose])
		stand_sigs[str(look)] = ArtScript.person_image(look, "stand", 0, false).get_data()
	for staff_look in [12, 13]:
		for other in 12:
			_check(stand_sigs[str(staff_look)] != stand_sigs[str(other)], "보조 직원 외형 %d 이 기존 외형 %d 와 달라야 해요" % [staff_look, other])
	_check(stand_sigs["12"] != stand_sigs["13"], "두 보조 직원 외형이 서로 달라요")
	_check(ArtScript.person_image(12, "cook", 0, true).get_data() != ArtScript.person_image(12, "cook", 1, true).get_data(), "조리 보조 동작 프레임")
	_check(ArtScript.person_image(13, "carry", 0, false).get_data() != ArtScript.person_image(13, "stand", 0, false).get_data(), "홀 보조 쟁반 자세")
	var st: GameStateScript = _state_with_recipe(_fast_cfg())
	var sess: SessionScript = SessionScript.new(SessionScript.make_plan(st.get_record(st.selected_record_id), 1))
	for i in 120:
		var lk: int = sess._look_of(Sim.WALKIN_ID, i)
		_check(lk >= 3 and lk <= 9, "처음 온 손님이 직원 외형(12/13)을 쓰면 안 돼요: %d" % lk)
	# 초상.
	var p0: Image = ArtScript.staff_portrait_image("prep_assistant")
	var p1: Image = ArtScript.staff_portrait_image("floor_assistant")
	_check(p0.get_width() == 24 and p0.get_height() == 24 and p1.get_width() == 24 and p1.get_height() == 24, "직원 초상 24x24")
	_check(p0.get_data() != p1.get_data(), "두 직원 초상이 달라요")
	for cid in ArtScript.portrait_ids():
		var cp: Image = ArtScript.portrait_image(str(cid))
		_check(cp.get_data() != p0.get_data() and cp.get_data() != p1.get_data(), "직원 초상이 단골 초상과 달라요: " + str(cid))
	for pimg in [p0, p1]:
		var im2: Image = pimg
		for corner in [Vector2i(0, 0), Vector2i(23, 0), Vector2i(0, 23), Vector2i(23, 23)]:
			_check(_close(im2.get_pixelv(corner), ArtScript.INK), "직원 초상 테두리")
		_check(im2.get_pixel(12, 8).a == 1.0, "초상에 투명한 구멍 없음")
	var unknown: Image = ArtScript.staff_portrait_image("nobody")
	_check(_close(unknown.get_pixel(12, 12), Color(0.80, 0.78, 0.72)) and _close(unknown.get_pixel(0, 0), ArtScript.INK), "알 수 없는 직원은 빈 틀")
	_end()


func WHITE_COLOR() -> Color:
	return ArtScript.WHITE


func test_staff_layout_and_scene() -> void:
	for variant in [LayoutScript.PORTRAIT, LayoutScript.LANDSCAPE]:
		var layout: Dictionary = LayoutScript.make(variant)
		var world: Vector2i = layout["size"]
		var spots: Dictionary = layout["staff_spots"]
		_check(spots.size() == 2 and spots.has("prep_assistant") and spots.has("floor_assistant"), variant + ": 직원 자리 둘")
		var room: Rect2 = layout["room"]
		for sid in spots:
			var sp: Dictionary = spots[sid]
			var g: Vector2 = sp["grid"]
			var tag: String = "%s %s" % [variant, str(sid)]
			_check((sp["pos"] as Vector2) == LayoutScript.proj(layout, g), tag + ": 발 위치는 격자 투영")
			_check(room.grow(-0.4).has_point(g), tag + ": 벽에서 떨어진 방 안")
			var foot: Vector2 = sp["pos"]
			var sprite_rect: Rect2 = Rect2(foot - Vector2(7.0, 18.0), Vector2(14.0, 18.0))
			_check(Rect2(Vector2.ZERO, Vector2(world)).encloses(sprite_rect), tag + ": 스프라이트가 장면 안")
			var body: Rect2 = Rect2(g - Vector2(0.25, 0.25), Vector2(0.5, 0.5))
			for f in layout["furniture"]:
				var fd: Dictionary = f
				if not bool(fd["solid"]):
					continue
				for fr in fd["rects"]:
					_check(not _hits(body, fr), "%s: 단단한 가구 %s 와 겹쳐요" % [tag, str(fd["id"])])
			# 손님 경로/서빙 경로/퇴장 경로와 0.45칸 이상 떨어져 있다(몸 반경 0.25 두 개 + 여유).
			var routes: Array = [layout["leave_grid"]]
			for sd in layout["seats"]:
				routes.append((sd as Dictionary)["path_grid"])
				routes.append((sd as Dictionary)["serve_grid"])
			for route in routes:
				var pts: Array = route
				for k in range(1, pts.size()):
					_check(_dist_to_segment(g, pts[k - 1], pts[k]) >= 0.45, "%s: 걷는 경로와 너무 가까워요 (%.2f)" % [tag, _dist_to_segment(g, pts[k - 1], pts[k])])
			for qg in layout["queue_grid"]:
				_check(g.distance_to(qg) >= 1.0, tag + ": 줄 칸과 겹쳐요")
			_check(g.distance_to(layout["chef_grid"]) >= 1.2 and g.distance_to(layout["pass_grid"]) >= 1.2, tag + ": 요리사/서버 자리와 겹치지 않아요")
		# 장면 항목: 직원이 없으면 둘, 고용하면 그 수만큼 늘고 깊이는 발 위치에서 나온다. 알 수 없는 id 는 무시한다.
		_check((SceneScript.build(layout, {}, {}, 0.0, {}, {}, [])["items"] as Array).size() == 2, variant + ": 직원 없으면 요리사/서버뿐")
		_check((SceneScript.build(layout, {}, {}, 0.0, {}, {}, ["prep_assistant"])["items"] as Array).size() == 3, variant + ": 조리 보조 1명 추가")
		_check((SceneScript.build(layout, {}, {}, 0.0, {}, {}, ["nobody"])["items"] as Array).size() == 2, variant + ": 알 수 없는 직원 무시")
		var both: Dictionary = SceneScript.build(layout, {}, {}, 0.0, {}, {}, ["prep_assistant", "floor_assistant"])
		_check((both["items"] as Array).size() == 4, variant + ": 보조 둘 추가")
		for it in both["items"]:
			var d: Dictionary = it
			if str(d["key"]).begins_with("staff|"):
				var sid2: String = str(d["key"]).split("|")[1]
				var feet: Vector2 = (d["pos"] as Vector2) + Vector2(7.0, 18.0)
				_check(feet == ((spots[sid2] as Dictionary)["pos"] as Vector2), variant + ": 직원 발이 자리 투영과 같아요")
				_check(absf(float(d["depth"]) - LayoutScript.depth_of_screen(layout, feet)) < 0.001, variant + ": 직원 깊이는 발 y 에서")
		# 지원 모션: 조리 보조는 요리사가 조리할 때, 홀 보조는 서버가 서빙할 때만 일을 한다.
		var idle_prep: Dictionary = SceneScript.build(layout, {"chef_cooking": false}, {}, 0.0, {}, {}, ["prep_assistant"])
		var cook_prep: Dictionary = SceneScript.build(layout, {"chef_cooking": true}, {}, 0.0, {}, {}, ["prep_assistant"])
		var idle_keys: String = str(_staff_keys(idle_prep))
		var cook_keys: String = str(_staff_keys(cook_prep))
		_check(idle_keys.find("|stand|") >= 0 and cook_keys.find("|cook|") >= 0, variant + ": 조리 보조 동작 " + idle_keys + " / " + cook_keys)
		var busy_floor: Dictionary = SceneScript.build(layout, {"server_state": SessionScript.S_CARRY, "server_seat": 0, "server_p": 0.5}, {}, 0.0, {}, {}, ["floor_assistant"])
		var calm_floor: Dictionary = SceneScript.build(layout, {}, {}, 0.0, {}, {}, ["floor_assistant"])
		_check(str(_staff_keys(busy_floor)).find("|carry|") >= 0 and str(_staff_keys(calm_floor)).find("|stand|") >= 0, variant + ": 홀 보조 동작")
		# CPU 합성: 직원이 있으면 장면이 달라진다.
		_check(SceneScript.compose_for(layout, null, 0.0, []).get_data() != SceneScript.compose_for(layout, null, 0.0, ["prep_assistant", "floor_assistant"]).get_data(), variant + ": 고용하면 장면에 보여요")
	# 영업 중에는 세션의 불변 직원 스냅샷을 그리고, 영업 전에는 실제 고용 목록을 그린다.
	var st: GameStateScript = _state_with_recipe(_fast_cfg())
	var rec: Dictionary = st.get_record(st.selected_record_id)
	var snap: Dictionary = Staffing.snapshot(["floor_assistant"])
	var sess: SessionScript = SessionScript.new(SessionScript.make_plan(rec, 1, snap))
	var view: ShopViewScript = ShopViewScript.new()
	view.set_idle_staff(["prep_assistant"])
	_check(view.visible_staff() == ["prep_assistant"], "영업 전에는 고용 목록")
	view.set_session(sess)
	_check(view.visible_staff() == ["floor_assistant"], "영업 중에는 세션 스냅샷(고용 목록이 바뀌어도 영업 중 장면은 그대로)")
	view.set_idle_staff(["prep_assistant", "floor_assistant"])
	_check(view.visible_staff() == ["floor_assistant"], "영업 중 고용 목록 갱신이 장면을 바꾸지 않아요")
	view.set_session(null)
	_check(view.visible_staff().size() == 2, "영업이 끝나면 다시 고용 목록")
	view.free()
	_end()


func _staff_keys(scene: Dictionary) -> Array:
	var out: Array = []
	for it in scene["items"]:
		var d: Dictionary = it
		if str(d["key"]).begins_with("staff|"):
			out.append(str(d["key"]))
	return out


func test_shop_layout_and_art() -> void:
	_check(LayoutScript.variant_for(390.0, 844.0) == LayoutScript.PORTRAIT, "세로 화면은 세로 배치")
	_check(LayoutScript.variant_for(1280.0, 800.0) == LayoutScript.LANDSCAPE, "데스크톱은 가로 배치")
	_check(LayoutScript.SEAT_COUNT == SessionScript.SEAT_COUNT, "배치와 런타임의 자리 수가 같아야 해요")
	for variant in [LayoutScript.PORTRAIT, LayoutScript.LANDSCAPE]:
		var layout: Dictionary = LayoutScript.make(variant)
		var world: Vector2i = layout["size"]
		var bounds: Rect2 = Rect2(Vector2.ZERO, Vector2(world))
		var seats: Array = layout["seats"]
		_check(seats.size() == SessionScript.SEAT_COUNT, variant + ": 자리 수")
		var seen: Dictionary = {}
		for i in seats.size():
			var sd: Dictionary = seats[i]
			var pos: Vector2 = sd["pos"]
			_check(not seen.has(str(pos)), "%s: 자리 좌표 중복 %d" % [variant, i])
			seen[str(pos)] = true
			_check(bounds.has_point(pos), "%s: 자리 %d가 장면 밖" % [variant, i])
			var path: Array = sd["path"]
			var serve: Array = sd["serve_path"]
			_check((path[path.size() - 1] as Vector2) == pos and (path[0] as Vector2) == (layout["door_in"] as Vector2), "%s: 자리 %d 경로가 문 안쪽에서 자리까지 이어져야 해요" % [variant, i])
			_check((serve[0] as Vector2) == (layout["pass_pos"] as Vector2), "%s: 서빙 경로는 주방 앞에서 시작" % variant)
			var path_inside: bool = true
			for pt in path:
				if not bounds.has_point(pt):
					path_inside = false
			for pt2 in serve:
				if not bounds.has_point(pt2):
					path_inside = false
			_check(path_inside, "%s: 자리 %d 경로가 장면 안" % [variant, i])
			_check(str(sd["kind"]) == ("counter" if i < 4 else "table"), "%s: 자리 종류 구성" % variant)
		for q in layout["queue_slots"]:
			# 발바닥 y 가 장면 맨 아래 줄과 같을 수 있어 경계 1px 여유를 둔다(Rect2.has_point 는 끝 경계를 제외).
			_check(bounds.grow(1.0).has_point(q), "%s: 줄 칸이 장면 안" % variant)
		_check((layout["queue_slots"] as Array).size() >= 8, "%s: 줄 칸 수" % variant)
		_check_service_geometry(variant, layout)
		_check_projection_and_depth(variant, layout)
		# 캔버스: 의도한 크기(세로 176x264 배율 2, 가로 320x152 배율 4)
		_check(world == (Vector2i(176, 264) if variant == LayoutScript.PORTRAIT else Vector2i(320, 152)), variant + ": 캔버스 크기")
		# 정적 배경: 크기가 맞고 모든 픽셀이 채워진다(투명 구멍 없음)
		var bg: Image = PainterScript.paint(layout)
		_check(bg.get_width() == world.x and bg.get_height() == world.y, "%s: 배경 크기" % variant)
		var opaque: bool = true
		for y in range(0, world.y, 7):
			for x in range(0, world.x, 5):
				if bg.get_pixel(x, y).a < 1.0:
					opaque = false
		_check(opaque, "%s: 배경에 투명한 구멍이 없어야 해요" % variant)
		# 길 따라 걷기: 시작/끝점과 중간값
		var route: Array = (seats[0] as Dictionary)["path"]
		_check(LayoutScript.along(route, 0.0) == (route[0] as Vector2) and LayoutScript.along(route, 1.0) == (route[route.size() - 1] as Vector2), "%s: 경로 양끝" % variant)
	# 스프라이트: 크기와 외형 다양성
	var signatures: Dictionary = {}
	for look in ArtScript.look_count():
		for pose in ["stand", "walk", "sit", "carry", "cook"]:
			var img: Image = ArtScript.person_image(look, pose, 0, false)
			_check(img.get_width() == 14 and img.get_height() == 18, "사람 스프라이트 크기")
		var front: Image = ArtScript.person_image(look, "stand", 0, false)
		signatures[str(front.get_data().hex_encode())] = true
	_check(signatures.size() == ArtScript.look_count(), "사람 외형이 서로 달라야 해요")
	var walk0: Image = ArtScript.person_image(0, "walk", 0, false)
	var walk1: Image = ArtScript.person_image(0, "walk", 1, false)
	_check(walk0.get_data() != walk1.get_data(), "걷기 프레임이 달라야 해요")
	var back: Image = ArtScript.person_image(0, "sit", 0, true)
	_check(back.get_data() != ArtScript.person_image(0, "sit", 0, false).get_data(), "뒷모습이 앞모습과 달라야 해요")
	for kind in ["heart", "note", "smile", "meh", "angry", "order", "wait", "impatient", "coin"]:
		var b: Image = ArtScript.bubble_image(kind)
		_check(b.get_width() == 13 and b.get_height() == 11, "말풍선 크기: " + kind)
	_check(ArtScript.bubble_image("heart").get_data() != ArtScript.bubble_image("angry").get_data(), "반응 아이콘이 달라야 해요")
	# 그릇/아이콘은 재료에 따라 달라진다(메뉴가 장면에 보인다)
	var bowl_a: Image = ArtScript.bowl_image(_rich_cfg())
	var bowl_b: Image = ArtScript.bowl_image(_light_cfg())
	_check(bowl_a.get_width() == 12 and bowl_a.get_height() == 7 and bowl_a.get_data() != bowl_b.get_data(), "메뉴가 다르면 그릇 그림이 달라야 해요")
	for slot in Catalog.SLOTS:
		for item in Catalog.items(slot):
			var icon: Image = ArtScript.icon_image(str((item as Dictionary)["id"]))
			var drawn: bool = false
			for y in icon.get_height():
				for x in icon.get_width():
					if icon.get_pixel(x, y).a > 0.0:
						drawn = true
			_check(drawn, "재료 아이콘이 비어 있어요: " + str((item as Dictionary)["id"]))
	_end()
