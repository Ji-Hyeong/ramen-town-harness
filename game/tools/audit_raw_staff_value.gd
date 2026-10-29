extends SceneTree
## Raw-menu staff-policy audit: two fixed menus x three staff policies x 14 real
## completed services (84 settlements, 84 whole-state disk roundtrips).
## Every scenario starts from a fresh production State (30000 / day 1 / rank 1,
## no premade broth or noodles) and uses only public gameplay transactions:
## develop broth/noodle -> taste -> research -> promotion -> facility/hire/train
## -> pin the selling record -> begin_service -> run_to_end -> settle_service.
## No forecast, Sim.simulate, st.serve or value injection is used for results.
## Usage: godot --headless --path game --script res://tools/audit_raw_staff_value.gd -- --audit-out=/abs/new/folder
const State = preload("res://scripts/domain/game_state.gd")
const Save = preload("res://scripts/services/save_service.gd")
const Check = preload("res://scripts/domain/data_check.gd")
const Research = preload("res://scripts/domain/ramen_research.gd")

const DAYS: int = 14
## Hard wall-clock bounds: loops check MAX_RUNTIME_MS, the timer catches any path
## that returns from _initialize without quitting. Neither can report success.
const MAX_RUNTIME_MS: int = 1100000
const WATCHDOG_SECONDS: float = 1200.0
const MAX_FAILURES: int = 60

## Both menus are the real hand-made equivalents of the research witnesses.
## "other" menu is the distractor selected/tasted last before pinning each day.
const MENUS: Array = [
	{"id": "light", "name": "Light kelp shio", "research": "hayoung_basic", "broth": ["kelp", "ginger"],
		"flour": "wheat", "water": "clear", "cut": "thin", "method": "standard",
		"tare": "tare_shio", "oil": "oil_scallion", "topping": "topping_nori", "cook": "cook_firm", "price": 9000,
		"expect_broth": "broth_dashi", "expect_noodle": "noodle_thin"},
	{"id": "rich", "name": "Rich pork shoyu", "research": "dohyun_basic", "broth": ["pork_bone", "garlic"],
		"flour": "wheat", "water": "clear", "cut": "thick", "method": "standard",
		"tare": "tare_shoyu", "oil": "oil_garlic", "topping": "topping_nori", "cook": "cook_normal", "price": 9500,
		"expect_broth": "broth_tonkotsu", "expect_noodle": "noodle_thick"},
]
const POLICIES: Array = [
	{"id": "none", "helper": ""},
	{"id": "kitchen_policy", "helper": "prep_assistant"},
	{"id": "hall_policy", "helper": "floor_assistant"},
]

var checks: int = 0
var failures: Array[String] = []
var _root: String = ""
var _label: String = ""
var _started_ms: int = 0


func _initialize() -> void:
	_started_ms = Time.get_ticks_msec()
	# Last-resort guard: a missed quit can never idle forever or look successful.
	create_timer(WATCHDOG_SECONDS).timeout.connect(func() -> void:
		printerr("AUDIT WATCHDOG: audit did not finish in time")
		quit(4))
	_root = _output_from_args()
	if _root == "":
		return
	var scenarios: Array = []
	var settlements: int = 0
	for menu in MENUS:
		for policy in POLICIES:
			var scenario: Dictionary = _scenario(menu, policy)
			settlements += (scenario["days"] as Array).size()
			scenarios.append(scenario)
	_check(scenarios.size() == 6, "all six scenarios were attempted")
	_check(settlements == 6 * DAYS, "84 actual settlements completed")
	var summary: Dictionary = _summary(scenarios)
	# The report is written by _write_new, which performs exactly 4 more checks
	# (inside root, not existing, open, write). Count them so file and stdout agree.
	var report: Dictionary = {"format": 1, "kind": "raw_staff_value", "days_per_scenario": DAYS,
		"scope": "Two fixed raw-developed menus x none/kitchen_policy/hall_policy, 14 actual completed services each. Real paid records, research, promotion, facility, hire and basic training only; no forecast, state injection, specialization, rank 3, expansion or extra menu. Differences are valid only against the SAME menu's none scenario.",
		"scenarios": scenarios, "summary": summary, "settlements": settlements,
		"checks": checks + 4, "failures": failures}
	if not _write_new(_root.path_join("report.json"), JSON.stringify(report, "\t", true) + "\n"):
		quit(2)
		return
	print("raw staff audit: scenarios=%d settlements=%d checks=%d failures=%d" % [scenarios.size(), settlements, checks, failures.size()])
	quit(0 if failures.is_empty() else 1)


## Accept only --audit-out=<new absolute folder>. All rejection happens before any
## filesystem write, and the live user data folder is never an acceptable target.
func _output_from_args() -> String:
	var output: String = ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--audit-out="):
			output = arg.substr(12)
	var live: String = OS.get_user_data_dir()
	if output == "" or not output.begins_with("/") or output.contains("://") or output != output.simplify_path() or output.ends_with("/") or output == "/" \
			or output == live or output.begins_with(live + "/"):
		printerr("--audit-out must be a new, normalized absolute filesystem folder (not user://, res://, or live user data).")
		quit(2)
		return ""
	# A symlinked parent could alias the live user-data folder past the lexical test
	# above, so every existing component of the parent chain must be a real directory.
	var walked: String = "/"
	for part in output.get_base_dir().split("/", false):
		var walker: DirAccess = DirAccess.open(walked)
		if walker == null or walker.is_link(part):
			printerr("Output parent chain contains a symlink or unreadable component (%s); pass the canonical absolute path. Nothing was written." % walked.path_join(part))
			quit(2)
			return ""
		walked = walked.path_join(part)
	var parent: DirAccess = DirAccess.open(output.get_base_dir())
	if parent == null or parent.file_exists(output.get_file()) or parent.dir_exists(output.get_file()) or parent.is_link(output.get_file()):
		printerr("Output parent must exist and the output path must not exist; nothing was written.")
		quit(2)
		return ""
	if DirAccess.make_dir_absolute(output) != OK:
		printerr("Cannot create the new audit folder.")
		quit(2)
		return ""
	return output


func _scenario(menu: Dictionary, policy: Dictionary) -> Dictionary:
	_label = "%s_%s" % [menu["id"], policy["id"]]
	var folder: String = _root.path_join(_label)
	var result: Dictionary = {"id": _label, "menu": menu["id"], "policy": policy["id"], "helper": policy["helper"],
		"complete": false, "days": [], "setup": {}, "action_days": {"promotion": 0, "staff_1": 0, "hire": 0, "train_basic": 0},
		"action_costs": {"staff_1": 0, "hire": 0, "train_basic": 0}}
	var state: State = State.new()
	var failures_before: int = failures.size()
	if _check(DirAccess.make_dir_absolute(folder) == OK, "create scenario folder") and _check(state.wallet == State.START_WALLET and state.day == 1 and state.rank() == 1 and state.record_count() == 0, "production start is 30000/day1/rank1 without records"):
		result["complete"] = _run(state, menu, policy, folder, result)
	result["complete"] = bool(result["complete"]) and failures.size() == failures_before and (result["days"] as Array).size() == DAYS
	var totals: Dictionary = {"units": 0, "revenue": 0, "ingredient_cost": 0, "overhead": 0, "service_net": 0, "preparation_spend": 0, "turned_away": 0}
	for row in result["days"]:
		var service: Dictionary = row["service"]
		totals["units"] += int(service["units"])
		totals["revenue"] += int(service["revenue"])
		totals["ingredient_cost"] += int(service["ingredient_cost"])
		totals["overhead"] += int(service["overhead"])
		totals["service_net"] += int(service["net"])
		totals["turned_away"] += int(service["turned_away"])
		totals["preparation_spend"] += int(row["preparation_spend"])
	result["totals"] = totals
	if (result["days"] as Array).size() > 0:
		var last: Dictionary = (result["days"] as Array)[-1]
		result["final"] = {"wallet": last["wallet_after"], "rank": last["rank_after"], "hired": last["helper_state"]["hired"],
			"facilities": last["helper_state"]["facilities"], "training": last["helper_state"]["training"],
			"state_sha256": last["save"]["state_sha256"]}
		# Ledger identity: every wallet change is a recorded setup/action/service amount.
		var setup: Dictionary = result["setup"]
		var expected: int = int(setup.get("wallet_after", 0)) - int(totals["preparation_spend"]) + int(totals["service_net"])
		_check(expected == int(last["wallet_after"]), "final wallet equals setup + actions + service nets")
	return result


## Returns false on the first failed transaction; the caller reports the partial rows.
func _run(state_in: State, menu: Dictionary, policy: Dictionary, folder: String, result: Dictionary) -> bool:
	var state: State = state_in
	var helper: String = str(policy["helper"])
	var ids: Dictionary = {}
	var setup_events: Array = []
	# Prepare BOTH menus in the same order for every scenario, then earn research.
	for entry in MENUS:
		var record_id: int = _prepare_menu(state, entry, setup_events)
		if record_id == 0:
			return false
		ids[entry["id"]] = record_id
	for entry in MENUS:
		var request: String = str(entry["research"])
		var record_id: int = int(ids[entry["id"]])
		if not _check(bool(state.research_check(request, record_id).get("all_met", false)), "research conditions met by real tasted record: " + request):
			return false
		if _act(state, "research:" + request, "research", int(Research.REWARD_CASH["basic"]), func() -> Dictionary: return state.submit_research(request, record_id), setup_events).is_empty():
			return false
	var sold_id: int = int(ids[menu["id"]])
	var other_id: int = int(ids["rich" if menu["id"] == "light" else "light"])
	var sold_record: Dictionary = state.get_record(sold_id)
	var sold_config: Dictionary = sold_record["config"]
	var setup_text: String = JSON.stringify(setup_events, "", true)
	result["setup"] = {"events": setup_events, "wallet_after": state.wallet, "setup_signature": setup_text.sha256_text(),
		"records": {"light": ids["light"], "rich": ids["rich"]}, "sold_record_id": sold_id, "sold_name": sold_record["name"],
		"sold_price": int(sold_config["price"]), "config_signature": JSON.stringify(sold_config, "", true).sha256_text(),
		"menu_signatures": {"light": JSON.stringify(state.get_record(int(ids["light"]))["config"], "", true).sha256_text(),
			"rich": JSON.stringify(state.get_record(int(ids["rich"]))["config"], "", true).sha256_text()}}
	result["sold_config"] = sold_config.duplicate(true)
	var prior_save: String = ""
	for day in range(1, DAYS + 1):
		if not _check(Time.get_ticks_msec() - _started_ms < MAX_RUNTIME_MS, "audit stayed inside its runtime bound") or failures.size() > MAX_FAILURES:
			return false
		if not _check(state.day == day and not state.service_active(), "calendar before service"):
			return false
		var wallet_before: int = state.wallet if day > 1 else int(result["setup"]["wallet_after"])
		var events: Array = []
		# --- real, eligibility-gated preparation (same chronology for each policy) ---
		var promotion: Dictionary = state.promotion_review()
		if state.rank() == 1 and bool(promotion["eligible"]):
			if _act(state, "promotion:2", "promotion", 0, func() -> Dictionary: return state.apply_promotion(2), events).is_empty():
				return false
			result["action_days"]["promotion"] = day
		var gates: Dictionary = _gates(state, helper)
		if helper != "":
			var facility: Dictionary = state.facility_review("staff_1")
			if not state.facilities_owned().has("staff_1") and bool(facility["can_buy"]):
				var price: int = int(facility["price"])
				if _act(state, "facility:staff_1", "facility", -price, func() -> Dictionary: return state.purchase_facility("staff_1"), events).is_empty():
					return false
				result["action_days"]["staff_1"] = day
				result["action_costs"]["staff_1"] = price
			var hire: Dictionary = state.staff_review(helper)
			if not state.hired_staff().has(helper) and bool(hire["can_hire"]):
				var hire_price: int = int(hire["hire_price"])
				if _act(state, "hire:" + helper, "hire", -hire_price, func() -> Dictionary: return state.hire_staff(helper), events).is_empty():
					return false
				result["action_days"]["hire"] = day
				result["action_costs"]["hire"] = hire_price
			if state.hired_staff().has(helper) and (state.staff_training()[helper]["lessons"] as Array).is_empty():
				var review: Dictionary = state.training_review(helper, "basic")
				if not _check(str(review["error"]) == "", "valid basic training review"):
					return false
				if bool(review["eligible"]):
					var cost: int = int(review["cost"])
					if _act(state, "train:%s:basic" % helper, "training", -cost, func() -> Dictionary: return state.train_staff(helper, "basic"), events).is_empty():
						return false
					result["action_days"]["train_basic"] = day
					result["action_costs"]["train_basic"] = cost
		var preparation_spend: int = 0
		for event in events:
			preparation_spend -= int(event["delta"])
		# --- selling selection: the settled menu must be the pinned one, not the last tasted ---
		if _act(state, "select unsold record", "selection", 0, func() -> Dictionary: return state.select_record(other_id), []).is_empty():
			return false
		if _act(state, "pin selling record", "selection", 0, func() -> Dictionary: return state.set_selling_menus([sold_id]), []).is_empty():
			return false
		var selling: Array = state.selling_records()
		if not _check(state.pinned_menu_ids() == [sold_id] and selling.size() == 1 and int(selling[0]["record_id"]) == sold_id \
				and state.selected_record_id == other_id and state.last_feedback_record_id == other_id \
				and Check.same_config(selling[0]["config"], sold_config) and int(selling[0]["config"]["price"]) == int(sold_config["price"]), "pinned selling record is the intended menu, not the last selected/tasted"):
			return false
		var witness: Dictionary = {"pinned_menu_ids": state.pinned_menu_ids(), "record_id": sold_id, "version": int(selling[0]["version"]),
			"price": int(selling[0]["config"]["price"]), "selected_record_id": state.selected_record_id,
			"last_feedback_record_id": state.last_feedback_record_id, "config_signature": JSON.stringify(selling[0]["config"], "", true).sha256_text()}
		var ready: Dictionary = {"wallet": state.wallet, "rank": state.rank(), "staffing": state.current_staffing()}
		# --- the actual service ---
		if _act(state, "begin service", "service", 0, func() -> Dictionary: return state.begin_service(), []).is_empty():
			return false
		var session = state.active_session()
		if not _check(session.run_to_end(), "actual runtime finished"):
			return false
		var runtime: Dictionary = session.summary()
		var completed: Array = session.get("completed")
		var wait_total: int = 0
		for order in completed:
			wait_total += int(order["wait"])
		# Exact completed-order dictionaries of this actual session, for independent
		# recomputation. Runtime observation only: not a GameState saved field.
		var orders_text: String = JSON.stringify(completed, "\t", true) + "\n"
		if not _check(str(runtime["error"]) == "" and int(runtime["record_id"]) == sold_id and Check.same_config(runtime["config"], sold_config) and int(runtime["price"]) == int(sold_config["price"]) and completed.size() == int(runtime["units"]), "runtime sold the pinned record and config"):
			return false
		# The expected wallet change comes from the finished runtime orders, not a forecast.
		var net: int = int(runtime["revenue"]) - int(runtime["ingredient_cost"]) - int(runtime["overhead"])
		var settled: Dictionary = _act(state, "settle service", "service", net, func() -> Dictionary: return state.settle_service(), [])
		if settled.is_empty():
			return false
		var report: Dictionary = settled["report"]
		if not _check(state.day == day + 1 and int(report["day"]) == day and not state.service_active(), "one settlement advances exactly one day"):
			return false
		if not _check(int(report["net"]) == net and state.wallet == int(ready["wallet"]) + net and int(report["wallet_after"]) == state.wallet, "wallet equals pre-service wallet + actual-order net"):
			return false
		if not _check(str(report["recipe_name"]) == str(sold_record["name"]) and int(report["version"]) == int(sold_record["version"]) and int(report["price"]) == int(sold_config["price"]) and int(report["units"]) == int(runtime["units"]), "settlement report matches the pinned menu/price"):
			return false
		# --- daily whole-state disk boundary in a NEW folder; continue with the restored instance ---
		var day_folder: String = folder.path_join("day-%02d" % day)
		if not _check(DirAccess.make_dir_absolute(day_folder) == OK, "create new day folder"):
			return false
		var store: Save = Save.new(day_folder)
		var before_json: String = JSON.stringify(state.to_dict(), "", true)
		var saved: Dictionary = store.save_state(state)
		if not _check(bool(saved["ok"]), "write day save: " + str(saved["message"])):
			return false
		var reloaded: State = State.new()
		var loaded: Dictionary = store.load_into(reloaded)
		if not _check(str(loaded["status"]) == "ok", "reload day save: " + str(loaded["message"])):
			return false
		var after_json: String = JSON.stringify(reloaded.to_dict(), "", true)
		if not _check(before_json == after_json, "complete canonical state is identical after disk roundtrip"):
			return false
		var retry: Dictionary = reloaded.settle_service()
		if not _check(not bool(retry["ok"]) and JSON.stringify(reloaded.to_dict(), "", true) == after_json, "reloaded state cannot settle twice"):
			return false
		var save_text: String = FileAccess.get_file_as_string(store.main_path())
		var row: Dictionary = {"day": day, "wallet_before_preparation": wallet_before, "preparation_spend": preparation_spend,
			"actions": events, "gates_before_actions": gates, "selling_witness": witness,
			"rank_before_service": ready["rank"], "rank_after": reloaded.rank(), "wallet_before_service": ready["wallet"],
			"staffing_snapshot": ready["staffing"],
			"service": {"units": int(runtime["units"]), "revenue": int(runtime["revenue"]), "ingredient_cost": int(runtime["ingredient_cost"]),
				"overhead": int(runtime["overhead"]), "net": net, "turned_away": int(runtime["turned_away"]), "avg_stars": float(runtime["avg_stars"]),
				"by_source": runtime["by_source"], "finished_at": int(runtime["finished_at"])},
			"settlement_report": report.duplicate(true),
			# Runtime-only observation: wait is NOT part of the saved state.
			"runtime_observation_not_saved": {"completed_orders": completed.size(), "wait_total": wait_total,
				"orders_file": "runtime-orders.json", "orders_sha256": orders_text.sha256_text(),
				"orders_bytes": orders_text.to_utf8_buffer().size(), "saved_game_field": false},
			"wallet_after": reloaded.wallet,
			"helper_state": {"hired": reloaded.hired_staff(), "facilities": reloaded.facilities_owned(), "training": reloaded.staff_training(),
				"current_staffing": reloaded.current_staffing()},
			"save": {"folder": "day-%02d" % day, "file": "ramen_lab_save.json", "sha256": save_text.sha256_text(), "bytes": save_text.to_utf8_buffer().size(),
				"state_sha256": after_json.sha256_text(), "roundtrip_equal": true}}
		if day > 1:
			row["previous_day_state_sha256"] = prior_save
		prior_save = after_json.sha256_text()
		if not _write_new(day_folder.path_join("runtime-orders.json"), orders_text):
			return false
		if not _write_new(day_folder.path_join("receipt.json"), JSON.stringify(row, "\t", true) + "\n"):
			return false
		(result["days"] as Array).append(row)
		state = reloaded
		# Latest eligibility facts from the restored instance (reported if never trained by day 14).
		result["final_gates"] = _gates(state, helper)
	return true


## Develop a broth and noodle through the real timed workshops, put them in the
## bowl, choose the remaining components and pay for one real tasting.
func _prepare_menu(state: State, menu: Dictionary, events: Array) -> int:
	var ingredients: Array = menu["broth"]
	state.start_new_recipe()
	if _act(state, menu["id"] + ":broth blend", "setup", 0, func() -> Dictionary: return state.set_broth_blend(ingredients, "standard"), events).is_empty():
		return 0
	var broth: Dictionary = state.broth_review()
	var broth_fee: int = int(broth["cost"])
	var broth_seconds: float = float(broth["duration"])
	if _act(state, menu["id"] + ":begin broth", "setup", 0, func() -> Dictionary: return state.begin_broth(), events).is_empty():
		return 0
	var brewed: Dictionary = _act(state, menu["id"] + ":finish broth", "broth_fee", -broth_fee, func() -> Dictionary: return state.advance_broth(broth_seconds), events)
	if brewed.is_empty() or not _check(bool(brewed["finished"]), "broth finished in one real step"):
		return 0
	var broth_index: int = int(brewed["index"])
	for field in ["flour", "water", "cut", "method"]:
		var choice: String = str(menu[field])
		if _act(state, "%s:noodle %s" % [menu["id"], field], "setup", 0, func() -> Dictionary: return state.set_noodle_formula(field, choice), events).is_empty():
			return 0
	var noodle: Dictionary = state.noodle_review()
	var noodle_fee: int = int(noodle["cost"])
	var noodle_seconds: float = float(noodle["duration"])
	if _act(state, menu["id"] + ":begin noodle", "setup", 0, func() -> Dictionary: return state.begin_noodle(), events).is_empty():
		return 0
	var made: Dictionary = _act(state, menu["id"] + ":finish noodle", "noodle_fee", -noodle_fee, func() -> Dictionary: return state.advance_noodle(noodle_seconds), events)
	if made.is_empty() or not _check(bool(made["finished"]), "noodle finished in one real step"):
		return 0
	var noodle_index: int = (state.noodle_review()["recipes"] as Array).size() - 1
	if _act(state, menu["id"] + ":use broth", "setup", 0, func() -> Dictionary: return state.use_broth(broth_index), events).is_empty() \
			or _act(state, menu["id"] + ":use noodle", "setup", 0, func() -> Dictionary: return state.use_noodle(noodle_index), events).is_empty():
		return 0
	for slot in ["tare", "oil", "cook"]:
		var id: String = str(menu[slot])
		if _act(state, "%s:%s" % [menu["id"], slot], "setup", 0, func() -> Dictionary: return state.set_draft_choice(slot, id), events).is_empty():
			return 0
	var toppings: Array = [str(menu["topping"])]
	var price: int = int(menu["price"])
	var recipe_name: String = str(menu["name"])
	if not _check(recipe_name.length() <= 20, "human recipe name is at most 20 characters") \
			or _act(state, menu["id"] + ":toppings", "setup", 0, func() -> Dictionary: return state.set_draft_toppings(toppings), events).is_empty() \
			or _act(state, menu["id"] + ":price", "setup", 0, func() -> Dictionary: return state.set_draft_price(price), events).is_empty() \
			or _act(state, menu["id"] + ":name", "setup", 0, func() -> Dictionary: return state.set_draft_name(recipe_name), events).is_empty():
		return 0
	var trial: int = state.trial_cost()
	var tasted: Dictionary = _act(state, menu["id"] + ":taste", "trial", -trial, func() -> Dictionary: return state.taste(), events)
	if tasted.is_empty():
		return 0
	var record_id: int = int(tasted["record_id"])
	# The stored record must be exactly the fixed raw recipe, not a similar premade bowl.
	var config: Dictionary = state.get_record(record_id)["config"]
	var expected_noodle: Dictionary = {"flour": menu["flour"], "water": menu["water"], "cut": menu["cut"], "method": menu["method"]}
	var sorted_ingredients: Array = ingredients.duplicate()
	sorted_ingredients.sort()
	if not _check(config["broth"] == menu["expect_broth"] and config["noodle"] == menu["expect_noodle"] and config["tare"] == menu["tare"] \
			and config["oil"] == menu["oil"] and config["cook"] == menu["cook"] and int(config["price"]) == price and str(config["toppings"]) == str(toppings) \
			and config["broth_recipe"] == {"ingredients": sorted_ingredients, "method": "standard"} and config["noodle_recipe"] == expected_noodle, \
			"tasted record is the fixed raw recipe: " + str(menu["id"])):
		return 0
	return record_id


## One public mutation with an exact wallet-delta check. Failure returns {}; a
## success returns the API result (never empty) and appends a receipt to events.
func _act(state: State, label: String, kind: String, delta: int, action: Callable, events: Array, quiet_event: bool = false) -> Dictionary:
	var before: int = state.wallet
	var day: int = state.day
	var rank: int = state.rank()
	var result: Dictionary = action.call()
	if not _check(bool(result.get("ok", false)), label + ": " + str(result.get("message", "no result"))):
		return {}
	if not _check(state.wallet == before + delta, label + ": exact wallet delta"):
		return {}
	if not quiet_event:
		events.append({"action": label, "kind": kind, "delta": delta, "wallet_before": before, "wallet_after": state.wallet, "day": day, "rank": rank})
	return result


## Read-only eligibility snapshot, taken before the day's helper actions.
func _gates(state: State, helper: String) -> Dictionary:
	var gates: Dictionary = {"wallet": state.wallet, "day": state.day, "rank": state.rank(), "promotion": state.promotion_review()}
	if helper != "":
		gates["staff_1"] = state.facility_review("staff_1")
		gates["helper_hire"] = state.staff_review(helper)
		if state.hired_staff().has(helper):
			gates["basic_training"] = state.training_review(helper, "basic")
	return gates


## Compare only inside a menu: each worker scenario against that menu's none run.
func _summary(scenarios: Array) -> Dictionary:
	var out: Dictionary = {"comparison_rule": "difference = policy scenario minus the same menu's none scenario; never compare different menus", "menus": {}}
	for menu in MENUS:
		var base: Dictionary = {}
		for scenario in scenarios:
			if scenario["menu"] == menu["id"] and scenario["policy"] == "none":
				base = scenario
		var rows: Dictionary = {}
		for scenario in scenarios:
			if scenario["menu"] != menu["id"]:
				continue
			var totals: Dictionary = scenario["totals"]
			var row: Dictionary = {"complete": scenario["complete"], "totals": totals, "action_days": scenario["action_days"], "action_costs": scenario["action_costs"],
				"final_wallet": scenario.get("final", {}).get("wallet", 0), "final_rank": scenario.get("final", {}).get("rank", 0),
				"config_signature": scenario["setup"].get("config_signature", ""), "setup_signature": scenario["setup"].get("setup_signature", "")}
			if not base.is_empty() and scenario["policy"] != "none":
				var base_totals: Dictionary = base["totals"]
				var vs: Dictionary = {"final_wallet": int(row["final_wallet"]) - int(base.get("final", {}).get("wallet", 0))}
				for key in totals:
					vs[key] = int(totals[key]) - int(base_totals[key])
				row["difference_vs_none"] = vs
				row["same_setup_and_config_as_none"] = row["setup_signature"] == base["setup"].get("setup_signature", "x") and row["config_signature"] == base["setup"].get("config_signature", "x")
				_check(bool(row["same_setup_and_config_as_none"]), "paired scenario shares setup and sold config: %s" % scenario["id"])
			rows[scenario["policy"]] = row
		out["menus"][menu["id"]] = rows
	return out


func _check(condition: bool, message: String) -> bool:
	checks += 1
	if not condition:
		failures.append(_label + ": " + message)
		printerr("AUDIT FAILURE: " + _label + ": " + message)
	return condition


## Create-only write confined to the audit root. Existing files are never replaced.
func _write_new(path: String, content: String) -> bool:
	if not _check(path.begins_with(_root + "/"), "write stays inside audit root: " + path.get_file()):
		return false
	if not _check(not FileAccess.file_exists(path), "preserve existing output: " + path.get_file()):
		return false
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if not _check(file != null, "open output: " + path.get_file()):
		return false
	file.store_string(content)
	var error: Error = file.get_error()
	file.close()
	return _check(error == OK, "write output: " + path.get_file())
