extends SceneTree
## Continuous campaign diagnostic, using only public gameplay transactions.
## Output is always a new directory; no existing or player save is ever loaded.
## Known research witnesses remove recipe-search skill from this bounded audit.
const State = preload("res://scripts/domain/game_state.gd")
const Save = preload("res://scripts/services/save_service.gd")
const Catalog = preload("res://scripts/domain/ingredient_catalog.gd")
const Research = preload("res://scripts/domain/ramen_research.gd")
const DAYS: int = 14
const POLICIES: Array = ["none", "bench", "seats", "prep", "floor", "all"]
var checks: int = 0
var failures: Array[String] = []


func _initialize() -> void:
	var output: String = ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out-dir="):
			output = arg.substr(10)
	# Refuse before mkdir/write, including a file or dangling link at the target.
	if not output.is_absolute_path() or output != output.simplify_path() or output.ends_with("/"):
		printerr("--out-dir must be a new absolute, normalized directory path.")
		quit(2)
		return
	var parent: DirAccess = DirAccess.open(output.get_base_dir())
	if parent == null or parent.file_exists(output.get_file()) or parent.dir_exists(output.get_file()) or parent.is_link(output.get_file()):
		printerr("Output parent must exist and output must not exist; existing paths are preserved.")
		quit(2)
		return
	if DirAccess.make_dir_absolute(output) != OK:
		printerr("Cannot create new audit directory.")
		quit(2)
		return
	var campaigns: Array = []
	for menu in ["fast", "slow"]:
		for policy in POLICIES:
			var result: Dictionary = _campaign(str(menu), str(policy), output)
			if not result.is_empty():
				campaigns.append(result)
	_check(campaigns.size() == 12, "all twelve campaigns completed")
	var report: Dictionary = {"format": 1, "days_per_campaign": DAYS,
		"scope": "Two fixed single-menu strategies; six investment policies. Known research witnesses, no exploration/contests/stories/rewards outside research, no two-menu or multi-topping optimization, no UI/real-time play/fun/iPhone claim. No state injection.",
		"campaigns": campaigns, "checks": checks + 3, "failures": failures}
	if not _write_new(output.path_join("report.json"), JSON.stringify(report, "\t", true) + "\n"):
		quit(2)
		return
	print("campaign audit: campaigns=%d runtime_days=%d checks=%d failures=%d" % [campaigns.size(), campaigns.size() * DAYS, checks, failures.size()])
	quit(0 if failures.is_empty() else 1)


func _campaign(menu: String, policy: String, output: String) -> Dictionary:
	var label: String = menu + "_" + policy
	var folder: String = output.path_join(label)
	if not _check(DirAccess.make_dir_absolute(folder) == OK, label + ": create isolated save directory"):
		return {}
	var store: Save = Save.new(folder)
	var state: State = State.new()
	var events: Array = []
	var cfg: Dictionary = Catalog.normalize_config(Research.WITNESSES["hayoung_basic" if menu == "fast" else "dohyun_advanced"])
	# Different price from the witnesses avoids global duplicate-taste rejection.
	# Both menus are legal at rank1, have one topping and standard methods.
	cfg["price"] = 8500 if menu == "fast" else 10000
	var sale_id: int = _taste(state, cfg, "Audit sale", 0, events)
	if sale_id == 0 or not _success(state.set_selling_menus([sale_id]), label + ": pin sale"):
		return {}
	var prior_save: String = ""
	var rows: Array = []
	var research_id: int = 0
	for expected_day in range(1, DAYS + 1):
		if not _check(state.day == expected_day, label + ": calendar before service"):
			return {}
		var before: int = State.START_WALLET if expected_day == 1 else state.wallet
		# Exactly one known research per day; later recipes revise one research
		# family, so the audit neither bypasses capacity nor needs record deletion.
		if expected_day <= Research.ids().size():
			var request: String = Research.ids()[expected_day - 1]
			research_id = _taste(state, Catalog.normalize_config(Research.WITNESSES[request]), "Audit research", research_id, events)
			if research_id == 0:
				return {}
			var tier: String = Research.find(request)["tier"]
			if not _transaction(state, "research:" + request, "research", int(Research.REWARD_CASH[tier]), func() -> Dictionary: return state.submit_research(request, research_id), events):
				return {}
		var review: Dictionary = state.promotion_review()
		if bool(review["eligible"]):
			var target: int = int(review["next"])
			if not _transaction(state, "rank:%d" % target, "promotion", 0, func() -> Dictionary: return state.apply_promotion(target), events):
				return {}
		# Capture affordability/locks before buying, rather than infer eligibility
		# from an inflated wallet or force a purchase on a chosen calendar date.
		var gates: Dictionary = {"promotion": state.promotion_review(), "expansion": state.expansion_review(),
			"facilities": state.facility_reviews(), "staff": state.staff_reviews()}
		if not _invest(state, policy, events):
			return {}
		var ready: Dictionary = {"wallet": state.wallet, "rank": state.rank(), "facilities": state.facilities_owned(),
			"hired": state.hired_staff(), "expanded": state.shop_expanded(), "training": state.staff_training(),
			"staffing": state.current_staffing(), "seats": state.seat_count()}
		if not _success(state.begin_service(), label + ": begin service"):
			return {}
		if not _check(state.active_session().run_to_end(), label + ": actual runtime finished"):
			return {}
		var runtime: Dictionary = state.active_session().summary()
		var settled: Dictionary = state.settle_service()
		if not _success(settled, label + ": settle actual orders"):
			return {}
		var report: Dictionary = settled["report"]
		if not _check(state.day == expected_day + 1 and int(report["day"]) == expected_day and not state.service_active(), label + ": one settlement advances one day"):
			return {}
		if not _check(state.wallet == int(ready["wallet"]) + int(report["net"]) and int(report["net"]) == int(runtime["revenue"]) - int(runtime["ingredient_cost"]) - int(runtime["overhead"]), label + ": actual-order wallet ledger"):
			return {}
		# Each day crosses the real disk boundary and resumes with a NEW state.
		var serialized: String = _json(state)
		if not _success(store.save_state(state), label + ": write isolated save"):
			return {}
		if expected_day > 1 and not _check(FileAccess.get_file_as_string(store.bak_path()) == prior_save, label + ": exact previous-day backup"):
			return {}
		prior_save = FileAccess.get_file_as_string(store.main_path())
		var reloaded: State = State.new()
		var loaded: Dictionary = store.load_into(reloaded)
		if not _check(str(loaded["status"]) == "ok" and _json(reloaded) == serialized, label + ": all-value disk roundtrip: " + str(loaded["message"])):
			return {}
		if not _write_new(folder.path_join("day-%02d.json" % expected_day), prior_save):
			return {}
		var retry: Dictionary = reloaded.settle_service()
		if not _check(not bool(retry["ok"]) and _json(reloaded) == serialized, label + ": reload cannot settle twice"):
			return {}
		if expected_day <= Research.ids().size():
			retry = reloaded.submit_research(Research.ids()[expected_day - 1], research_id)
			if not _check(not bool(retry["ok"]) and _json(reloaded) == serialized, label + ": reload cannot claim research twice"):
				return {}
		rows.append({"day": expected_day, "wallet_before_preparation": before,
			"actions": events.duplicate(true), "gates_before_investment": gates, "ready": ready,
			"service": report.duplicate(true), "turned_away": runtime["turned_away"],
			"wallet_after": state.wallet, "training_after": state.staff_training(),
			"snapshot": "day-%02d.json" % expected_day, "save_sha256": FileAccess.get_sha256(store.main_path())})
		events.clear()
		state = reloaded
	return {"id": label, "menu": menu, "policy": policy, "sale_config": cfg,
		"days": rows, "final_state": state.to_dict()}


func _taste(state: State, config: Dictionary, name: String, previous: int, events: Array) -> int:
	if previous == 0:
		state.start_new_recipe()
	elif not _success(state.select_record(previous), "select research revision"):
		return 0
	for slot in ["broth", "tare", "oil", "noodle", "cook"]:
		if not _success(state.set_draft_choice(slot, str(config[slot])), "set " + str(slot)):
			return 0
	if not _success(state.set_draft_toppings(config["toppings"]), "set toppings") or not _success(state.set_draft_price(int(config["price"])), "set price"):
		return 0
	# select_record already restores the immutable family name. Renaming even to
	# the same text is intentionally forbidden by the public revision API.
	if previous == 0 and not _success(state.set_draft_name(name), "set name"):
		return 0
	var cost: int = state.trial_cost()
	if not _transaction(state, "taste:" + name, "trial", -cost, func() -> Dictionary: return state.taste(), events):
		return 0
	return state.last_feedback_record_id


func _invest(state: State, policy: String, events: Array) -> bool:
	var facilities: Array = []
	if policy in ["bench", "all"]:
		facilities.append_array(["bench_1", "bench_2"])
	if policy in ["prep", "floor", "all"]:
		facilities.append("staff_1")
	if policy == "all":
		facilities.append("staff_2")
	for id in facilities:
		var review: Dictionary = state.facility_review(str(id))
		if bool(review["can_buy"]) and not _transaction(state, "facility:" + str(id), "facility", -int(review["price"]), func() -> Dictionary: return state.purchase_facility(str(id)), events):
			return false
	if policy in ["seats", "all"] and bool(state.expansion_review()["can_buy"]):
		if not _transaction(state, "expand", "facility", -State.EXPANSION_PRICE, func() -> Dictionary: return state.expand_shop(), events):
			return false
	var staff: Array = ["prep_assistant", "floor_assistant"] if policy == "all" else (["prep_assistant"] if policy == "prep" else (["floor_assistant"] if policy == "floor" else []))
	for id in staff:
		var review: Dictionary = state.staff_review(str(id))
		if bool(review["can_hire"]) and not _transaction(state, "hire:" + str(id), "hire", -int(review["hire_price"]), func() -> Dictionary: return state.hire_staff(str(id)), events):
			return false
		if not state.hired_staff().has(id):
			continue
		var style: String = "basic" if state.staff_training()[id]["lessons"].is_empty() else "speed"
		review = state.training_review(str(id), style)
		if not _check(str(review["error"]) == "", "valid training review: " + str(id)):
			return false
		if bool(review["eligible"]) and not _transaction(state, "train:" + str(id) + ":" + style, "training", -int(review["cost"]), func() -> Dictionary: return state.train_staff(str(id), style), events):
			return false
	return true


## Expected transaction amounts come from the public cost/reward catalog before
## mutation; the independent Python verifier later recomputes the whole ledger.
func _transaction(state: State, label: String, kind: String, delta: int, action: Callable, events: Array) -> bool:
	var before: int = state.wallet
	var result: Dictionary = action.call()
	if not _success(result, label):
		return false
	if not _check(state.wallet == before + delta, label + ": exact transaction delta"):
		return false
	events.append({"action": label, "kind": kind, "delta": delta, "wallet_before": before,
		"wallet_after": state.wallet, "day": state.day, "rank": state.rank()})
	return true


func _success(result: Dictionary, label: String) -> bool:
	return _check(bool(result["ok"]), label + ": " + str(result["message"]))


func _check(condition: bool, message: String) -> bool:
	checks += 1
	if not condition:
		failures.append(message)
		printerr("AUDIT FAILURE: " + message)
	return condition


func _json(state: State) -> String:
	return JSON.stringify(state.to_dict(), "", true)


func _write_new(path: String, content: String) -> bool:
	if not _check(not FileAccess.file_exists(path), "preserve existing output: " + path.get_file()):
		return false
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if not _check(file != null, "open output: " + path.get_file()):
		return false
	file.store_string(content)
	var error: Error = file.get_error()
	file.close()
	return _check(error == OK, "write output: " + path.get_file())
