extends "res://tools/audit_staff_specialization.gd"
## Controlled counterfactuals fork ONE legitimately earned save, never injected
## state. Old audit helpers retain their historical behavior and output format.
const Directions = preload("res://scripts/domain/recipe_directions.gd")
const STUDY_DAYS: int = 21
const DISHES: Array = ["citrus_clear", "sesame_depth", "harbor_sea"]
const CASE_POLICIES: Array = ["small_none", "small_prep", "expanded_none", "expanded_prep", "expanded_floor", "expanded_both"]


func _initialize() -> void:
	var output: String = _new_output_from_args()
	if output == "":
		return
	var preparation: Dictionary = _prepare(output)
	var cases: Array = []
	if not preparation.is_empty():
		var sets: Array = [[DISHES[0]], [DISHES[1]], [DISHES[2]], [DISHES[0], DISHES[1]], [DISHES[0], DISHES[2]], [DISHES[1], DISHES[2]]]
		for menu_set in sets:
			for policy in CASE_POLICIES:
				# Two-menu sales require the real expansion; do not quietly replace
				# a requested pair with a single menu in an incompatible control.
				if menu_set.size() == 2 and str(policy).begins_with("small_"):
					continue
				var result: Dictionary = _run_case(menu_set, str(policy), output, preparation)
				if not result.is_empty():
					cases.append(result)
	_check(cases.size() == 30, "all thirty compatible cases finished")
	var report: Dictionary = {"format": 1, "kind": "menu_operations", "days_per_case": STUDY_DAYS,
		"scope": "Known recipes/research; legitimate12-day farming preparation, then30 controlled21-day branches. Fixed9500 prices and same calendar. No novice30-minute/fun/optimality/UI/iPhone claim. No balance changes or player saves.",
		"preparation": preparation, "cases": cases, "checks": checks + 3, "failures": failures}
	if not _write_new(output.path_join("report.json"), JSON.stringify(report, "\t", true) + "\n"):
		quit(2)
		return
	print("menu operations: cases=%d preparation_days=12 service_days=%d checks=%d failures=%d" % [cases.size(), cases.size() * STUDY_DAYS, checks, failures.size()])
	quit(0 if failures.is_empty() else 1)


func _prepare(output: String) -> Dictionary:
	var folder: String = output.path_join("preparation")
	if not _check(DirAccess.make_dir_absolute(folder) == OK, "new preparation folder"):
		return {}
	var state: State = State.new()
	var store: Save = Save.new(folder)
	var actions: Array = []
	var config: Dictionary = Catalog.normalize_config(Research.WITNESSES["hayoung_basic"])
	config["price"] = 8500
	var starter: int = _taste(state, config, "Audit starter", 0, actions)
	if starter == 0 or not _success(state.set_selling_menus([starter]), "starter sale"):
		return {}
	var revision: int = 0
	var rows: Array = []
	for day in range(1, 13):
		var before: int = State.START_WALLET if day == 1 else state.wallet
		if day <= Research.ids().size():
			var request: String = Research.ids()[day - 1]
			revision = _taste(state, Catalog.normalize_config(Research.WITNESSES[request]), "Audit research", revision, actions)
			var cash: int = int(Research.REWARD_CASH[Research.find(request)["tier"]])
			if revision == 0 or not _transaction(state, "research:" + request, "research", cash, func() -> Dictionary: return state.submit_research(request, revision), actions):
				return {}
		var review: Dictionary = state.promotion_review()
		if bool(review["eligible"]):
			var rank: int = int(review["next"])
			if not _transaction(state, "rank:%d" % rank, "promotion", 0, func() -> Dictionary: return state.apply_promotion(rank), actions):
				return {}
		if not _trip(state, day, actions):
			return {}
		var row: Dictionary = _day(state, store, before, actions)
		if row.is_empty():
			return {}
		rows.append(row)
		actions.clear()
		state = _reload(store, state)
	# A new recipe family for each dish, retaining the actual sample debit and
	# record. This is known-input benchmarking, not a recipe autofill game feature.
	var before_dishes: int = state.wallet
	var ids: Dictionary = {}
	for id in DISHES:
		config = _dish_config(str(id))
		var record: int = _taste(state, config, str(id), 0, actions)
		if record == 0 or not _check(bool(Directions.assess(str(id), config)["matched"]), "actual dish meets direction"):
			return {}
		ids[id] = record
	if not _success(store.save_state(state), "prepared source save"):
		return {}
	state = _reload(store, state)
	var baseline: String = output.path_join("baseline.json")
	if not _write_new(baseline, FileAccess.get_file_as_string(store.main_path())):
		return {}
	return {"days": rows, "before_dishes": before_dishes, "dish_actions": actions,
		"dish_ids": ids, "state": state.to_dict(), "baseline": "baseline.json",
		"baseline_sha256": FileAccess.get_sha256(baseline)}


## Explicit known benchmark inputs match the three accepted workbench examples.
## Do not import the visual test fixture: it preloads textures and makes this
## headless domain diagnostic depend on a particular editor's graphics cache.
func _dish_config(id: String) -> Dictionary:
	var config: Dictionary = Catalog.normalize_config(Catalog.default_config())
	var inputs: Dictionary = {
		"citrus_clear": {"broth": "broth_chicken", "tare": "tare_shio", "oil": "oil_scallion", "noodle": "noodle_thin", "toppings": ["topping_citrus_peel", "topping_sprouts"]},
		"sesame_depth": {"broth": "broth_tonkotsu", "tare": "tare_shoyu", "oil": "oil_roasted_sesame", "noodle": "noodle_thick", "toppings": ["topping_chashu", "topping_nori"]},
		"harbor_sea": {"broth": "broth_roasted_sardine", "tare": "tare_shio", "oil": "oil_scallion", "noodle": "noodle_medium", "toppings": ["topping_scallop", "topping_nori"]},
	}
	config.merge(inputs[id], true)
	config["price"] = 9500
	return config


## One actual departure per earned day. Public APIs enforce rank/supplier gates
## and the shared travel calendar, including paid quantity decisions.
func _trip(state: State, day: int, actions: Array) -> bool:
	if day < 4 or day > 11:
		return true
	var route: Array = {
		4: ["harbor", "h_boat", "h_share_soup"], 5: ["harbor", "h_boat", "h_rent_tools"],
		6: ["market", "m_ask", "m_hear_recipe"], 7: ["market", "m_ask", "m_buy_pickle"],
		8: ["market_sample", "sesame_stall", "take_three"], 9: ["market_sample", "citrus_cart", "take_three"],
		10: ["harbor_sample", "sardine_boat", "clean_three"], 11: ["harbor_sample", "scallop_diver", "clean_three"],
	}[day]
	var kind: String = str(route[0])
	var start: Callable
	var fee: int
	if kind == "market_sample":
		fee = 1000
		start = state.start_foraging
	elif kind == "harbor_sample":
		fee = 1200
		start = state.start_harbor_foraging
	else:
		fee = 3000 if kind == "market" else 6000
		start = func() -> Dictionary: return state.start_expedition(kind)
	if not _transaction(state, "trip:" + kind, "travel", -fee, start, actions):
		return false
	for choice in route.slice(1):
		var cost: int = {"h_rent_tools": 400, "m_buy_pickle": 300, "take_three": 300, "clean_three": 600}.get(choice, 0)
		if not _transaction(state, "choice:" + str(choice), "travel", -cost, func() -> Dictionary: return state.advance_expedition(str(choice)), actions):
			return false
	return _transaction(state, "claim:" + kind, "travel", 0, state.finish_expedition, actions)


func _run_case(menu_set: Array, policy: String, output: String, preparation: Dictionary) -> Dictionary:
	var label: String = "+".join(menu_set) + "__" + policy
	var folder: String = output.path_join(label)
	if not _check(DirAccess.make_dir_absolute(folder) == OK, "new controlled branch"):
		return {}
	var store: Save = Save.new(folder)
	if not _write_new(store.main_path(), FileAccess.get_file_as_string(output.path_join("baseline.json"))):
		return {}
	var state: State = State.new()
	if not _check(store.load_into(state)["status"] == "ok" and state.to_dict() == preparation["state"], "branch starts from same legitimate disk state"):
		return {}
	var ids: Array = []
	for id in menu_set:
		ids.append(preparation["dish_ids"][id])
	var rows: Array = []
	for index in STUDY_DAYS:
		var before: int = state.wallet
		var actions: Array = []
		if not _buy(state, policy, actions) or not _success(state.set_selling_menus(ids), "legal active menu selection"):
			return {}
		var row: Dictionary = _day(state, store, before, actions)
		if row.is_empty():
			return {}
		rows.append(row)
		state = _reload(store, state)
	return {"id": label, "menu_set": menu_set, "policy": policy, "days": rows, "final_state": state.to_dict()}


func _buy(state: State, policy: String, actions: Array) -> bool:
	if policy.begins_with("expanded_") and not state.shop_expanded():
		if not _transaction(state, "expand", "facility", -State.EXPANSION_PRICE, state.expand_shop, actions):
			return false
	var staff: Array = []
	if policy.ends_with("prep") or policy.ends_with("both"):
		staff.append("prep_assistant")
	if policy.ends_with("floor") or policy.ends_with("both"):
		staff.append("floor_assistant")
	for index in staff.size():
		var facility: String = "staff_%d" % (index + 1)
		if not state.facilities_owned().has(facility):
			var price: int = int(state.facility_review(facility)["price"])
			if not _transaction(state, "facility:" + facility, "facility", -price, func() -> Dictionary: return state.purchase_facility(facility), actions):
				return false
		var id: String = str(staff[index])
		if not state.hired_staff().has(id):
			var price: int = int(state.staff_review(id)["hire_price"])
			if not _transaction(state, "hire:" + id, "hire", -price, func() -> Dictionary: return state.hire_staff(id), actions):
				return false
		var style: String = "basic" if state.staff_training()[id]["lessons"].is_empty() else "speed"
		var view: Dictionary = state.training_review(id, style)
		if bool(view["eligible"]) and not _transaction(state, "train:" + id + ":" + style, "training", -int(view["cost"]), func() -> Dictionary: return state.train_staff(id, style), actions):
			return false
	return true


## Observe actual completed orders before settlement clears the session. Every
## report is reconciled independently against these per-order witnesses later.
func _day(state: State, store: Save, before: int, actions: Array) -> Dictionary:
	var ready: Dictionary = state.to_dict()
	var prior: String = FileAccess.get_file_as_string(store.main_path()) if store.has_save() else ""
	if not _success(state.begin_service(), "begin actual service"):
		return {}
	var session: RefCounted = state.active_session()
	if not _check(session.run_to_end(), "finish actual runtime"):
		return {}
	var runtime: Dictionary = session.summary()
	var orders: Array = session.get("completed").duplicate(true)
	var metrics: Dictionary = _runtime_metrics(session, runtime)
	metrics.erase("orders")  # Keep the existing observer's independent totals, not a second order list.
	var result: Dictionary = state.settle_service()
	if not _success(result, "settle once"):
		return {}
	_check(state.wallet == int(ready["wallet"]) + int(result["report"]["net"]), "service wallet equation")
	_check(state.day == int(ready["day"]) + 1, "one real calendar day")
	_check(state.foraging_state() == ready["foraging"] and state.harbor_foraging_state() == ready["harbor_foraging"], "ordinary sales never consume research samples")
	if not _success(store.save_state(state), "daily save"):
		return {}
	if prior != "":
		_check(FileAccess.get_file_as_string(store.bak_path()) == prior, "exact previous snapshot backup")
	var filename: String = "day-%02d.json" % int(ready["day"])
	if not _write_new(store.dir.path_join(filename), FileAccess.get_file_as_string(store.main_path())):
		return {}
	return {"day": ready["day"], "wallet_before": before, "actions": actions.duplicate(true), "ready": ready,
		"orders": orders, "runtime_metrics": metrics, "turned_away": runtime["turned_away"], "service": result["report"],
		"snapshot": filename, "save_sha256": FileAccess.get_sha256(store.main_path())}


func _reload(store: Save, expected: State) -> State:
	var state: State = State.new()
	_check(store.load_into(state)["status"] == "ok" and _json(state) == _json(expected), "full daily disk state equality")
	var before: String = _json(state)
	_check(not bool(state.settle_service()["ok"]) and _json(state) == before, "reload cannot settle again")
	return state
