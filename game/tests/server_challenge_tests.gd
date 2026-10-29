extends RefCounted
## Pure fixtures for the server challenge rules. These explicit configs/orders
## exercise the module only; they are NOT earned player progress. Real raw-rank-2
## service witnesses live in Codex's native acceptance tests. No filesystem writes.
const Server = preload("res://scripts/domain/server_challenge.gd")
const Check = preload("res://scripts/domain/data_check.gd")
const Eval = preload("res://scripts/domain/recipe_evaluator.gd")
const Session = preload("res://scripts/domain/service_session.gd")
var check: Callable
# Notebook before acceptance (ids 1,2) and two structurally new revisions (ids 5,6).
const BASE_A: Dictionary = {"broth":"broth_dashi","tare":"tare_shio","oil":"oil_scallion","noodle":"noodle_thin","toppings":["topping_nori"],"cook":"cook_firm","price":9000}
const BASE_B: Dictionary = {"broth":"broth_chicken","tare":"tare_shoyu","oil":"oil_garlic","noodle":"noodle_medium","toppings":["topping_egg"],"cook":"cook_normal","price":8500}
const START_DAY: int = 3
const NEXT_ID: int = 5


func js(value: Variant) -> String:
	return JSON.stringify(value, "", true)


func rec(id: int, name: String, tasted_day: int, config: Dictionary) -> Dictionary:
	return {"record_id":id, "name":name, "tasted_day":tasted_day, "config":config.duplicate(true)}


func cfg(base: Dictionary, process: Dictionary, price: int) -> Dictionary:
	var out: Dictionary = base.duplicate(true)
	if not process.is_empty(): out["process"] = process
	out["price"] = price
	return out


func base_records() -> Array:
	return [rec(1, "기본 하나", 1, BASE_A), rec(2, "기본 둘", 2, BASE_B)]


func new_a(price: int = 9000) -> Dictionary:
	return rec(5, "점심 하나", START_DAY, cfg(BASE_A, {"broth":"gentle","noodle":"standard"}, price))


func new_b(price: int = 9500) -> Dictionary:
	return rec(6, "점심 둘", START_DAY, cfg(BASE_B, {"broth":"standard","noodle":"moist"}, price))


## Completed-order stubs shaped like Session.completed (extra keys are allowed).
func orders(count_a: int, count_b: int, wait: int, stars: Array, ids: Array = [5, 6]) -> Array:
	var out: Array = []
	for i in count_a + count_b:
		out.append({"order_id":i + 1, "record_id":ids[0] if i < count_a else ids[1], "wait":wait, "stars":stars[i % stars.size()], "price":9000})
	return out


func accepted() -> Dictionary:
	return Server.begin(Server.empty_state(), base_records(), START_DAY, NEXT_ID, 2)["state"]


func serve(state: Dictionary, a: Dictionary, b: Dictionary, done: Array, day: int = 4) -> Dictionary:
	return Server.observe(state, [a, b], day, done)


func passing_state() -> Dictionary:
	return serve(accepted(), new_a(), new_b(), orders(4, 4, 100, [4]))["state"]


func ready_met(state: Dictionary, row: int) -> bool:
	return Server.review(state)["rows"][row]["met"]


func parse(raw: Variant, day: int = 5, records: Array = []) -> Dictionary:
	return Server.parse(raw, day, 7, 2, 2, [], records)


func rejected(result: Dictionary, before: Dictionary, state: Dictionary, label: String) -> void:
	check.call(not result["ok"] and str(result["error"]) != "" and js(result["state"]) == js(before) and js(state) == js(before), label)


func run(callback: Callable) -> void:
	check = callback
	for config in [BASE_A, BASE_B, new_a()["config"], new_b()["config"]]:
		check.call(Check.config_error(normalized(config)) == "" and Eval.prep_seconds(config) > 0, "fixture config is evaluator-compatible")
	_acceptance()
	_conditions()
	_non_applicable_and_bad_evidence()
	_sticky_and_claim()
	_parse()


# Normalize through DataCheck so fixture configs match what GameState would store.
func normalized(config: Dictionary) -> Dictionary:
	return Check.parse_config(config, "fixture")["config"]


func _acceptance() -> void:
	var empty: Dictionary = Server.empty_state()
	var snapshot: String = js(empty)
	check.call(Server.level(empty) == 0 and Server.review(empty)["status"] == "open" and Server.review(empty)["met"] == 0, "empty state is open at level 0")
	rejected(Server.begin(empty, base_records(), START_DAY, NEXT_ID, 1), empty, empty, "rank 1 cannot accept")
	rejected(Server.begin(empty, [base_records()[0]], START_DAY, NEXT_ID, 2), empty, empty, "one record cannot accept")
	rejected(Server.begin(empty, [base_records()[0], base_records()[0]], START_DAY, NEXT_ID, 2), empty, empty, "duplicate record cannot accept")
	rejected(Server.begin(empty, [base_records()[0], rec(9, "미래", 1, BASE_B)], START_DAY, NEXT_ID, 2), empty, empty, "record id from the future cannot accept")
	rejected(Server.claim(empty, 9), empty, empty, "cannot claim without work")
	var opened: Dictionary = Server.begin(empty, base_records(), START_DAY, NEXT_ID, 2)
	var state: Dictionary = opened["state"]
	check.call(opened["ok"] and js(empty) == snapshot and Server.review(state)["status"] == "active", "free acceptance leaves input untouched")
	check.call(state["start"]["day"] == START_DAY and state["start"]["min_record_id"] == NEXT_ID and state["start"]["baselines"].size() == 2, "start captures day, min id and two baselines")
	rejected(Server.begin(state, base_records(), START_DAY + 1, NEXT_ID + 1, 2), state, state, "no reaccept/reset")
	var wrong: Dictionary = base_records()[0].duplicate(true)
	wrong["config"]["price"] = 9000.5
	rejected(Server.begin(empty, [wrong, base_records()[1]], START_DAY, NEXT_ID, 2), empty, empty, "fractional price cannot accept")


func _conditions() -> void:
	var start: Dictionary = accepted()
	var done: Dictionary = serve(start, new_a(), new_b(), orders(4, 4, 100, [4]))
	var state: Dictionary = done["state"]
	check.call(done["ok"] and done["applicable"] and Server.review(state)["status"] == "ready" and Server.review(state)["met"] == 6, "all six conditions pass")
	check.call(state["attempt"]["units"] == 8 and state["attempt"]["menus"][0]["units"] == 4 and state["attempt"]["wait_total"] == 800 and state["attempt"]["star_sum"] == 32, "attempt keeps actual unit/wait/star totals")
	check.call(js(start) == js(accepted()) and start["attempt"].is_empty(), "observe does not mutate input state")
	# Per-menu minimum 3 and total minimum 8 boundaries.
	var low: Dictionary = serve(start, new_a(), new_b(), orders(6, 2, 100, [4]))["state"]
	check.call(not ready_met(low, 1) and ready_met(low, 2) and Server.review(low)["status"] == "active", "a menu with 2 bowls fails even with 7+ total")
	var seven: Dictionary = serve(start, new_a(), new_b(), orders(4, 3, 100, [4]))["state"]
	check.call(ready_met(seven, 1) and not ready_met(seven, 2), "7 total bowls fail")
	var eight: Dictionary = serve(start, new_a(), new_b(), orders(3, 5, 100, [4]))["state"]
	check.call(ready_met(eight, 1) and ready_met(eight, 2) and Server.review(eight)["status"] == "ready", "3 + 5 bowls pass the count rows")
	# Integer average wait: exactly 150 passes, total 1201 over 8 fails.
	check.call(ready_met(serve(start, new_a(), new_b(), orders(4, 4, 150, [4]))["state"], 3), "average wait 150 passes")
	var slow: Array = orders(4, 4, 150, [4])
	slow[0]["wait"] = 151
	check.call(not ready_met(serve(start, new_a(), new_b(), slow)["state"], 3), "average wait just above 150 fails")
	# Integer stars: sum 28 over 8 passes, 27 fails.
	check.call(ready_met(serve(start, new_a(), new_b(), orders(4, 4, 100, [4, 3]))["state"], 4), "average 3.5 stars passes")
	var dim: Array = orders(4, 4, 100, [4, 3])
	dim[0]["stars"] = 3
	check.call(not ready_met(serve(start, new_a(), new_b(), dim)["state"], 4), "average below 3.5 fails")
	# Price caps apply to each menu.
	check.call(ready_met(serve(start, new_a(10000), new_b(10000), orders(4, 4, 100, [4]))["state"], 5), "price 10000 passes")
	check.call(not ready_met(serve(start, new_a(10100), new_b(), orders(4, 4, 100, [4]))["state"], 5), "price just above 10000 (next 100 step) on one menu fails")
	# Condition 1: price-only, shared structure, old records, old tasting, mixed baselines.
	var price_only: Dictionary = rec(5, "가격만", START_DAY, cfg(BASE_A, {}, 9900))
	check.call(not ready_met(serve(start, price_only, new_b(), orders(4, 4, 100, [4]))["state"], 0), "price-only revision of baseline does not qualify")
	var twin: Dictionary = rec(6, "같은 구성", START_DAY, cfg(new_a()["config"], {}, 9100))
	check.call(not ready_met(serve(start, new_a(), twin, orders(4, 4, 100, [4]))["state"], 0), "two menus identical except price do not qualify")
	var mixed: Dictionary = rec(6, "기존 둘", START_DAY, cfg(BASE_B, {}, 9000))
	check.call(not ready_met(serve(start, new_a(), mixed, orders(4, 4, 100, [4]))["state"], 0), "mixed baselines: one new and one old structure fails")
	var old_one: Dictionary = rec(4, "수락 전", START_DAY, new_a()["config"])
	check.call(not ready_met(serve(start, old_one, new_b(), orders(4, 4, 100, [4], [4, 6]))["state"], 0), "record id below min_record_id earns no credit")
	var stale: Dictionary = rec(5, "옛 시식", START_DAY - 1, new_a()["config"])
	check.call(not ready_met(serve(start, stale, new_b(), orders(4, 4, 100, [4]))["state"], 0), "tasted before acceptance day earns no credit")
	# Argument order of the selling records does not matter.
	check.call(Server.review(serve(start, new_b(), new_a(), orders(4, 4, 100, [4]))["state"])["status"] == "ready", "record order is canonicalized")
	# Latest failed attempt replaces the previous failed one.
	var failed_twice: Dictionary = serve(serve(start, new_a(), new_b(), orders(4, 3, 100, [4]))["state"], new_a(), new_b(), orders(2, 2, 90, [5]), 5)["state"]
	check.call(failed_twice["attempt"]["day"] == 5 and failed_twice["attempt"]["units"] == 4, "only the latest failed attempt is kept")
	# Zero-order two-menu service is a valid failed attempt with zero totals.
	var zero: Dictionary = serve(start, new_a(), new_b(), [])
	check.call(zero["ok"] and zero["state"]["attempt"]["units"] == 0 and Server.review(zero["state"])["status"] == "active", "zero completed orders is a failed attempt")
	# Public review is a deep copy.
	var view: Dictionary = Server.review(state_ready())
	view["attempt"]["menus"][0]["config"]["price"] = 1
	check.call(Server.review(state_ready())["attempt"]["menus"][0]["config"]["price"] == 9000, "review attempt is a defensive copy")


func state_ready() -> Dictionary:
	return passing_state()


func _non_applicable_and_bad_evidence() -> void:
	var empty: Dictionary = Server.empty_state()
	var skipped: Dictionary = serve(empty, new_a(), new_b(), orders(4, 4, 100, [4]))
	check.call(skipped["ok"] and not skipped["applicable"] and js(skipped["state"]) == js(empty), "unaccepted challenge ignores service")
	var start: Dictionary = accepted()
	var single: Dictionary = Server.observe(start, [new_a()], 4, orders(8, 0, 100, [4]))
	check.call(single["ok"] and not single["applicable"] and js(single["state"]) == js(start), "single-menu service is a known non-applicable event")
	var good: Array = orders(4, 4, 100, [4])
	var unknown: Array = orders(4, 4, 100, [4])
	unknown[3]["record_id"] = 99
	rejected(serve(start, new_a(), new_b(), unknown), start, start, "unknown order record id fails")
	for kind in ["stars0", "stars6", "wait_neg", "wait_limit", "bool_id", "float_wait", "missing", "not_dict"]:
		var bad: Array = good.duplicate(true)
		match kind:
			"stars0": bad[0]["stars"] = 0
			"stars6": bad[0]["stars"] = 6
			"wait_neg": bad[0]["wait"] = -1
			"wait_limit": bad[0]["wait"] = Session.HARD_LIMIT + 1
			"bool_id": bad[0]["record_id"] = true
			"float_wait": bad[0]["wait"] = 10.5
			"missing": bad[0].erase("stars")
			"not_dict": bad[0] = 5
		rejected(serve(start, new_a(), new_b(), bad), start, start, "malformed completed order fails: " + kind)
	rejected(serve(start, new_a(), new_a(), good), start, start, "duplicate menus fail")
	rejected(Server.observe(start, [new_a(), new_b(), rec(7, "셋", START_DAY, BASE_A)], 4, good), start, start, "three menus fail")
	rejected(serve(start, new_a(), new_b(), good, START_DAY - 1), start, start, "service before acceptance day fails")
	var broken: Dictionary = new_b()
	broken["config"]["broth"] = "missing"
	rejected(serve(start, new_a(), broken, good), start, start, "invalid runtime config fails")
	var too_many: Array = []
	for i in 1001: too_many.append({"record_id":5, "wait":1, "stars":3})
	rejected(serve(start, new_a(), new_b(), too_many), start, start, "more than 1000 orders fails")
	var shapeless: Dictionary = {"start":{}}
	check.call(not Server.observe(shapeless, [new_a(), new_b()], 4, good)["ok"] and not Server.claim(shapeless, 9)["ok"] and not Server.begin(shapeless, base_records(), START_DAY, NEXT_ID, 2)["ok"], "malformed state shape fails every transaction")


func _sticky_and_claim() -> void:
	var ready: Dictionary = passing_state()
	var proof: String = js(ready["attempt"])
	var later: Dictionary = serve(ready, new_a(), new_b(), orders(1, 1, 400, [1]), 5)
	check.call(later["ok"] and later["applicable"] and js(later["state"]) == js(ready) and js(later["state"]["attempt"]) == proof, "first passing proof survives a later failed service")
	check.call(Server.review(later["state"])["status"] == "ready", "ready status is sticky")
	rejected(Server.claim(ready, 4), ready, ready, "no claim on the passing day")
	rejected(Server.claim(accepted(), 9), accepted(), accepted(), "unready claim fails")
	var claimed: Dictionary = Server.claim(ready, 5)
	var mastered: Dictionary = claimed["state"]
	check.call(claimed["ok"] and Server.level(mastered) == 1 and mastered["completed_day"] == 5 and Server.level(ready) == 0, "claim masters once on a later day without mutating input")
	check.call(js(mastered["attempt"]) == proof and js(mastered["start"]) == js(ready["start"]), "claim stores no extra reward fields")
	rejected(Server.claim(mastered, 6), mastered, mastered, "claim replay fails")
	rejected(Server.begin(mastered, base_records(), 6, 9, 2), mastered, mastered, "no acceptance after mastery")
	var after: Dictionary = serve(mastered, new_a(), new_b(), orders(1, 1, 400, [1]), 6)
	check.call(after["ok"] and js(after["state"]) == js(mastered) and Server.review(after["state"])["status"] == "mastered", "mastered proof is frozen")


func _parse() -> void:
	var records: Array = base_records() + [new_a(), new_b()]
	var start: Dictionary = accepted()
	var failed: Dictionary = serve(start, new_a(), new_b(), orders(4, 3, 100, [4]))["state"]
	var ready: Dictionary = passing_state()
	var mastered: Dictionary = Server.claim(ready, 5)["state"]
	for pair in [["empty", Server.empty_state()], ["active", start], ["failed", failed], ["ready", ready], ["mastered", mastered]]:
		var through_disk: Variant = JSON.parse_string(JSON.stringify(pair[1]))
		var parsed: Dictionary = parse(through_disk, 5, records)
		check.call(parsed["ok"] and js(parsed["state"]) == js(pair[1]), "JSON round trip parses: " + pair[0])
		# Deleted notebook rows keep validated proof (no records at all, or only base rows).
		check.call(parse(through_disk, 5, [])["ok"] and parse(through_disk, 5, base_records())["ok"], "deleted notebook records keep proof: " + pair[0])
	# A consistent but unmet attempt (1 + 4 bowls, no claim) is a valid failed attempt.
	var unmet: Dictionary = failed.duplicate(true)
	unmet["attempt"]["menus"][0]["units"] = 1
	unmet["attempt"]["menus"][1]["units"] = 4
	unmet["attempt"]["units"] = 5
	unmet["attempt"]["wait_total"] = 100
	unmet["attempt"]["star_sum"] = 20
	var unmet_parsed: Dictionary = parse(JSON.parse_string(JSON.stringify(unmet)), 5, records)
	check.call(unmet_parsed["ok"] and js(unmet_parsed["state"]) == js(unmet) and Server.review(unmet_parsed["state"])["status"] == "active", "valid unmet failed attempt parses and stays active")
	var before: String = js(mastered)
	var copy: Dictionary = parse(mastered, 5, records)["state"]
	copy["attempt"]["menus"][0]["config"]["price"] = 1
	check.call(js(mastered) == before, "parse returns a deep copy")
	check.call(Server.level(parse(mastered, 5, [])["state"]) == 1 and Server.review(parse(ready, 5, [])["state"])["status"] == "ready", "parsed ready/mastered keep status")
	check.call(parse(start, 5, records)["ok"] and not Server.parse(start, 5, 7, 1, 2, [], records)["ok"], "rank 1 cannot hold an accepted challenge")
	var bad_cases: Array = ["not_dict", "extra", "missing", "bool_completed", "fraction_completed", "completed_future", "orphan_attempt", "orphan_completed",
		"start_day0", "start_day_future", "min_id_future", "one_baseline", "dup_baseline", "baseline_not_old", "baseline_config", "baseline_mismatch",
		"attempt_before_start", "attempt_today", "one_menu", "menu_dup", "menu_order", "menu_future", "menu_tasted_late", "menu_name", "menu_name_pad", "menu_config",
		"menu_bool_units", "units_sum", "units_cap", "wait_over", "wait_neg", "stars_low", "stars_high", "stars_zero_orders", "forged_ready", "completed_same_day",
		"record_mismatch_name", "record_mismatch_config", "record_mismatch_day", "baseline_menu_mismatch", "locked_ingredient", "slot_overflow", "baseline_tasted_late"]
	for kind in bad_cases:
		var raw: Variant = ready.duplicate(true)
		var recs: Array = records
		match kind:
			"not_dict": raw = []
			"extra": raw["extra"] = 1
			"missing": raw.erase("attempt")
			"bool_completed": raw["completed_day"] = true
			"fraction_completed": raw["completed_day"] = 5.5
			"completed_future": raw["completed_day"] = 6
			"orphan_attempt": raw = {"start":{}, "attempt":ready["attempt"].duplicate(true), "completed_day":0}
			"orphan_completed": raw = {"start":{}, "attempt":{}, "completed_day":1}
			"start_day0": raw["start"]["day"] = 0
			"start_day_future": raw["start"]["day"] = 6
			"min_id_future": raw["start"]["min_record_id"] = 8
			"one_baseline": raw["start"]["baselines"].pop_back()
			"dup_baseline": raw["start"]["baselines"][1]["record_id"] = 1
			"baseline_not_old": raw["start"]["baselines"][1]["record_id"] = 5
			"baseline_config": raw["start"]["baselines"][0]["config"]["tare"] = "missing"
			"baseline_mismatch": raw["start"]["baselines"][0]["config"]["price"] = 9100
			"attempt_before_start": raw["attempt"]["day"] = 2
			"attempt_today": raw["attempt"]["day"] = 5
			"one_menu": raw["attempt"]["menus"].pop_back()
			"menu_dup": raw["attempt"]["menus"][1]["record_id"] = 5
			"menu_order": raw["attempt"]["menus"].reverse()
			"menu_future": raw["attempt"]["menus"][1]["record_id"] = 7
			"menu_tasted_late": raw["attempt"]["menus"][0]["tasted_day"] = 5
			"menu_name": raw["attempt"]["menus"][0]["name"] = ""
			"menu_name_pad": raw["attempt"]["menus"][0]["name"] = " 점심 "
			"menu_config": raw["attempt"]["menus"][0]["config"]["broth"] = "missing"
			"menu_bool_units": raw["attempt"]["menus"][0]["units"] = true
			"units_sum": raw["attempt"]["units"] = 9
			"units_cap": raw["attempt"]["units"] = 1001
			"wait_over": raw["attempt"]["wait_total"] = 8 * Session.HARD_LIMIT + 1
			"wait_neg": raw["attempt"]["wait_total"] = -1
			"stars_low": raw["attempt"]["star_sum"] = 7
			"stars_high": raw["attempt"]["star_sum"] = 41
			"stars_zero_orders": raw["attempt"]["units"] = 0; raw["attempt"]["menus"][0]["units"] = 0; raw["attempt"]["menus"][1]["units"] = 0; raw["attempt"]["wait_total"] = 0; raw["attempt"]["star_sum"] = 1
			# Consistent but unmet attempt (1 + 4 bowls) combined with a claimed mastery.
			"forged_ready": raw["attempt"]["menus"][0]["units"] = 1; raw["attempt"]["units"] = 5; raw["attempt"]["wait_total"] = 100; raw["attempt"]["star_sum"] = 20; raw["completed_day"] = 5
			"baseline_tasted_late": recs = base_records(); recs[0]["tasted_day"] = START_DAY + 1
			"completed_same_day": raw["completed_day"] = 4
			"record_mismatch_name": recs = [new_a(), new_b()]; recs[0]["name"] = "다른 이름"
			"record_mismatch_config": recs = [new_a(), new_b()]; recs[1]["config"]["price"] = 9999
			"record_mismatch_day": recs = [new_a(), new_b()]; recs[0]["tasted_day"] = 2
			"baseline_menu_mismatch": raw["start"]["baselines"][0]["record_id"] = 4; raw["attempt"]["menus"][0]["record_id"] = 4
			"locked_ingredient": raw["attempt"]["menus"][0]["config"]["broth"] = "broth_clam"
			"slot_overflow": raw["attempt"]["menus"][0]["config"]["toppings"] = ["topping_chashu", "topping_egg", "topping_nori"]
		var snapshot: String = js(raw)
		var verdict: Dictionary = parse(raw, 5, recs)
		check.call(not verdict["ok"] and str(verdict["error"]) != "" and verdict["state"].is_empty() and js(raw) == snapshot, "malformed save rejected without reset: " + kind)
