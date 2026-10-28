extends RefCounted
## Focused tests for the three story encounters (market/harbor/mountain). Pure and
## in-memory: no filesystem access. Two kinds of evidence are kept apart on purpose:
##  - "journey" tests drive the real public GameState (fixtures earn every unlock);
##  - "pure" tests build explicit, conserved ledgers (obtained == stock + used) to
##    reach states that would take hundreds of paid trips, e.g. a full storage box.
const State = preload("res://tests/legacy_game_fixture.gd")
const Core = preload("res://scripts/domain/sample_foraging.gd")
const Market = preload("res://scripts/domain/market_foraging.gd")
const Harbor = preload("res://scripts/domain/harbor_foraging.gd")
const Mountain = preload("res://scripts/domain/mountain_foraging.gd")
const MarketTests = preload("res://tests/market_foraging_tests.gd")
const HarborTests = preload("res://tests/harbor_foraging_tests.gd")
const MountainTests = preload("res://tests/mountain_foraging_tests.gd")
var check: Callable


## Literal expectations, deliberately not read back from the catalogs under test.
## Row i always yields ids[i], so a row's index doubles as its ingredient index.
func _regions() -> Array:
	return [
		{"key": "market", "spec": Market.SPEC, "fixture": MarketTests, "start": "start_foraging", "snap": "foraging_state", "save": "foraging",
			"fee": 1000, "min": 2, "ids": ["oil_roasted_sesame", "topping_citrus_peel"],
			"story": "market_group_buy", "title": "마감 공동구매",
			"rows": [{"id": "share_sesame_two", "cost": 0, "amount": 2}, {"id": "prepare_citrus_five", "cost": 900, "amount": 5}],
			"targets": ["sesame_stall", "citrus_cart"], "quantities": [{"id": "take_two", "cost": 0, "amount": 2}, {"id": "take_three", "cost": 300, "amount": 3}]},
		{"key": "harbor", "spec": Harbor.SPEC, "fixture": HarborTests, "start": "start_harbor_foraging", "snap": "harbor_foraging_state", "save": "harbor_foraging",
			"fee": 1200, "min": 1, "ids": ["broth_roasted_sardine", "topping_scallop"],
			"story": "harbor_shared_catch", "title": "새벽 어획물 나눔",
			"rows": [{"id": "sort_sardine_two", "cost": 400, "amount": 2}, {"id": "sort_scallop_five", "cost": 1400, "amount": 5}],
			"targets": ["sardine_boat", "scallop_diver"], "quantities": [{"id": "take_one", "cost": 0, "amount": 1}, {"id": "clean_three", "cost": 600, "amount": 3}]},
		{"key": "mountain", "spec": Mountain.SPEC, "fixture": MountainTests, "start": "start_mountain_foraging", "snap": "mountain_foraging_state", "save": "mountain_foraging",
			"fee": 1600, "min": 1, "ids": ["noodle_buckwheat", "topping_grilled_shiitake"],
			"story": "mountain_shared_mill", "title": "제분소 공동 주문",
			"rows": [{"id": "mill_buckwheat_five", "cost": 1800, "amount": 5}, {"id": "share_shiitake_two", "cost": 500, "amount": 2}],
			"targets": ["buckwheat_mill", "shiitake_grill"], "quantities": [{"id": "take_one", "cost": 0, "amount": 1}, {"id": "clean_three", "cost": 800, "amount": 3}]},
	]


func run(callback: Callable) -> void:
	check = callback
	for r in _regions():
		_catalog(r)
		_outcomes(r)
		_copies(r)
		_pure_transaction(r)
		_capacity(r)
		_parse_shapes(r)
		_truncated(r)
		_lifetime(r)
		_journey(r)
	_wrappers()


# ---------------------------------------------------------------- pure helpers

func _json(value: Variant) -> String:
	return JSON.stringify(value)


## Checks a ledger call succeeded and returns its new state (or the old one on error).
func _next(result: Dictionary, label: String, fallback: Dictionary) -> Dictionary:
	check.call(result["error"] == "", label + ": " + str(result["error"]))
	return result.get("state", fallback)


## Runs one whole ledger trip. mode: "hold" stops after the picks, "finish" claims, "retire" gives up.
func _trip(spec: Dictionary, state: Dictionary, day: int, picks: Array, mode: String) -> Dictionary:
	var s: Dictionary = _next(Core.begin(spec, state, day, 100000), "begin day %d" % day, state)
	for id in picks:
		s = _next(Core.choose(spec, s, id, 100000), "choose " + str(id), s)
	if mode != "hold":
		s = _next(Core.finish(spec, s, mode == "retire"), mode, s)
	return s


## Explicit conserved ledger (stock == obtained, nothing used); pure boundary fixture only.
func _stocked(spec: Dictionary, a: int, b: int) -> Dictionary:
	var s: Dictionary = Core.empty_state(spec)
	var amounts: Array = [a, b]
	for i in 2:
		var id: String = spec["ids"][i]
		s["stock"][id] = amounts[i]
		s["obtained"][id] = amounts[i]
		if amounts[i] > 0:
			s["first_day"][id] = 1
	return s


func _spend_all(spec: Dictionary, s: Dictionary) -> void:
	for id in spec["ids"]:
		s["used"][id] += s["stock"][id]
		s["stock"][id] = 0


func _refused(label: String, result: Dictionary, state: Dictionary, snapshot: String) -> void:
	check.call(result["error"] != "" and not result.has("state") and _json(state) == snapshot, label)


# --------------------------------------------------------------------- catalog

func _catalog(r: Dictionary) -> void:
	var spec: Dictionary = r["spec"]
	var k: String = r["key"]
	check.call(spec["ids"] == r["ids"] and spec["ids"].size() == 2, k + ": spec.ids stay the original two")
	check.call(int(spec["fee"]) == r["fee"] and int(spec["min_amount"]) == r["min"] and int(spec["max_amount"]) == 5, k + ": base fee/min unchanged, max raised to the real 5")
	check.call(spec["targets"].size() == 3 and spec["quantities"].size() == 2, k + ": exactly one appended target, generic quantities untouched")
	for i in 2:
		var t: Dictionary = spec["targets"][i]
		check.call(t["id"] == r["targets"][i] and t["ingredient_hint"] == r["ids"][i] and int(t["cost"]) == 0 and not t.has("quantities"), k + ": original target %d unchanged" % i)
		var q: Dictionary = spec["quantities"][i]
		check.call(q["id"] == r["quantities"][i]["id"] and int(q["cost"]) == r["quantities"][i]["cost"] and int(q["amount"]) == r["quantities"][i]["amount"], k + ": original quantity %d unchanged" % i)
	var story: Dictionary = spec["targets"][2]
	check.call(story["id"] == r["story"] and story["title"] == r["title"] and story["ingredient_hint"] == r["ids"][0] and int(story["cost"]) == 0, k + ": story identity and default hint")
	check.call(str(story["quantity_title"]) != "" and str(story["quantity_text"]) != "" and str(story["desc"]).split(".").size() <= 3, k + ": custom follow-up title/text, short situation")
	check.call(story["quantities"].size() == 2, k + ": two explicit outcomes")
	for i in 2:
		var row: Dictionary = story["quantities"][i]
		var want: Dictionary = r["rows"][i]
		check.call(row["id"] == want["id"] and int(row["cost"]) == want["cost"] and int(row["amount"]) == want["amount"] and row["ingredient"] == r["ids"][i], k + ": outcome " + want["id"])
		check.call(spec["ids"].has(row["ingredient"]), k + ": outcome ingredient belongs to the region")
		# The brief must name ingredient, quantity and extra cost before committing.
		check.call(str(row["label"]).contains(str(want["amount"]) + "개") and str(row["label"]).contains("%d원" % want["cost"]), k + ": label shows quantity and extra cost")
		check.call(str(story["desc"]).contains(str(want["amount"]) + "개") and str(story["desc"]).contains("%d원" % want["cost"]), k + ": target brief shows quantity and extra cost")
	# Original paths still resolve to the generic rows tagged with their own ingredient.
	for i in 2:
		var rows: Array = Core.choices(spec, [r["targets"][i]])
		check.call(rows.size() == 2 and rows[0]["ingredient"] == r["ids"][i] and rows[1]["ingredient"] == r["ids"][i] and rows[0]["id"] == r["quantities"][0]["id"] and rows[1]["id"] == r["quantities"][1]["id"], k + ": original target %d keeps generic rows" % i)
	var story_rows: Array = Core.choices(spec, [r["story"]])
	check.call(story_rows.size() == 2 and story_rows[0]["id"] == r["rows"][0]["id"] and story_rows[1]["id"] == r["rows"][1]["id"], k + ": story rows are its own")
	check.call(Core.choices(spec, ["nope"]).is_empty() and Core.choices(spec, [r["story"], r["rows"][0]["id"]]).is_empty(), k + ": unknown/over-long path has no choices")


func _outcomes(r: Dictionary) -> void:
	var spec: Dictionary = r["spec"]
	var k: String = r["key"]
	for i in 2:
		var want: Dictionary = r["rows"][i]
		check.call(Core.outcome(spec, [r["story"], want["id"]]) == {"extra": want["cost"], "ingredient": r["ids"][i], "amount": want["amount"]}, k + ": new outcome " + want["id"])
		# Old paths keep their exact effect: the generic row pays into the target's own ingredient.
		for j in 2:
			var q: Dictionary = r["quantities"][j]
			check.call(Core.outcome(spec, [r["targets"][i], q["id"]]) == {"extra": q["cost"], "ingredient": r["ids"][i], "amount": q["amount"]}, k + ": original path %d/%d" % [i, j])
	check.call(Core.outcome(spec, [r["story"]]) == {"extra": 0, "ingredient": "", "amount": 0}, k + ": target alone has no reward")
	var wrong: Array = [
		[r["story"], r["quantities"][0]["id"]], [r["story"], r["quantities"][1]["id"]],
		[r["targets"][0], r["rows"][0]["id"]], [r["targets"][1], r["rows"][1]["id"]],
		[r["rows"][0]["id"]], [r["story"], r["rows"][0]["id"], r["rows"][1]["id"]], [r["story"], r["story"]],
		[r["story"], "bogus"], ["bogus"], [r["story"], 3], [7, r["rows"][0]["id"]],
	]
	for path in wrong:
		check.call(Core.outcome(spec, path).is_empty(), k + ": rejected path " + str(path))


func _copies(r: Dictionary) -> void:
	var spec: Dictionary = r["spec"]
	var k: String = r["key"]
	var before: String = _json(Core.choices(spec, []))
	var rows: Array = Core.choices(spec, [])
	rows[2]["quantities"][0]["amount"] = 99
	rows[2]["id"] = "tampered"
	rows.clear()
	check.call(_json(Core.choices(spec, [])) == before and spec["targets"][2]["id"] == r["story"], k + ": choices(target level) is a defensive copy")
	var picks: Array = Core.choices(spec, [r["story"]])
	picks[0]["cost"] = 12345
	check.call(int(Core.choices(spec, [r["story"]])[0]["cost"]) == r["rows"][0]["cost"], k + ": choices(story rows) is a defensive copy")
	var out: Dictionary = Core.outcome(spec, [r["story"], r["rows"][0]["id"]])
	out["amount"] = 77
	check.call(Core.outcome(spec, [r["story"], r["rows"][0]["id"]])["amount"] == r["rows"][0]["amount"], k + ": outcome is a defensive copy")
	var s: Dictionary = _trip(spec, Core.empty_state(spec), 1, [r["story"]], "hold")
	var snap: String = _json(s)
	var pristine: String = _json(Core.active_view(spec, s, 100000))
	var view: Dictionary = Core.active_view(spec, s, 100000)
	view["event"]["choices"][0]["cost"] = 1
	view["path"].append("tampered")
	check.call(_json(s) == snap and _json(Core.active_view(spec, s, 100000)) == pristine, k + ": active_view does not alias the ledger")
	check.call(Core.active_view(spec, s, 100000)["path"] == [r["story"]], k + ": active_view path is a fresh copy")


# ----------------------------------------------------- pure transaction: exact

func _pure_transaction(r: Dictionary) -> void:
	var spec: Dictionary = r["spec"]
	var k: String = r["key"]
	for i in 2:
		var want: Dictionary = r["rows"][i]
		var empty: Dictionary = Core.empty_state(spec)
		var snap: String = _json(empty)
		_refused(k + ": departure fee shortage atomic", Core.begin(spec, empty, 1, r["fee"] - 1), empty, snap)
		var s: Dictionary = _next(Core.begin(spec, empty, 3, r["fee"]), "begin", empty)
		check.call(s["active"]["stage"] == "choice_1" and s["last_departure_day"] == 3 and _json(empty) == snap, k + ": begin opens the shared day only on the copy")
		_refused(k + ": second departure same day", Core.begin(spec, s, 3, 100000), s, _json(s))
		var intro: Dictionary = Core.active_view(spec, s, 0)
		check.call(intro["event"]["step"] == 1 and intro["event"]["choices"].size() == 3 and intro["event"]["choices"][2]["id"] == r["story"], k + ": first step offers the story target")
		# With an empty wallet the target is open only if some outcome is free (market sesame).
		var cheapest: int = mini(r["rows"][0]["cost"], r["rows"][1]["cost"])
		var broke: Dictionary = Core.choose(spec, s, r["story"], 0)
		check.call((broke["error"] == "") == (cheapest == 0), k + ": story target needs one affordable outcome")
		var t: Dictionary = _next(Core.choose(spec, s, r["story"], want["cost"]), "story target", s)
		check.call(t["active"]["stage"] == "choice_2" and t["active"]["extra"] == 0 and t["active"]["path"] == [r["story"]], k + ": target costs nothing and moves to step two")
		var step2: Dictionary = Core.active_view(spec, t, want["cost"])
		check.call(step2["event"]["title"] == spec["targets"][2]["quantity_title"] and step2["event"]["text"] == spec["targets"][2]["quantity_text"] and step2["event"]["choices"].size() == 2, k + ": custom follow-up title/text shown")
		# Every wrong or unaffordable second choice leaves the ledger byte-identical.
		for bad in [r["quantities"][0]["id"], r["quantities"][1]["id"], r["targets"][0], r["story"], "bogus", ""]:
			_refused(k + ": wrong second choice " + str(bad), Core.choose(spec, t, bad, 100000), t, _json(t))
		if want["cost"] > 0:
			_refused(k + ": extra cost shortage", Core.choose(spec, t, want["id"], want["cost"] - 1), t, _json(t))
		_refused(k + ": result stage cannot be claimed early", Core.finish(spec, t), t, _json(t))
		var done: Dictionary = _next(Core.choose(spec, t, want["id"], want["cost"]), "outcome", t)
		check.call(done["active"]["stage"] == "result" and done["active"]["extra"] == want["cost"] and done["stock"][r["ids"][i]] == 0, k + ": result waits; nothing granted early")
		_refused(k + ": no third phase", Core.choose(spec, done, want["id"], 100000), done, _json(done))
		var claim: Dictionary = Core.finish(spec, done)
		check.call(claim["error"] == "" and claim["state"]["stock"][r["ids"][i]] == want["amount"] and claim["state"]["stock"][r["ids"][1 - i]] == 0, k + ": exact one-time reward")
		check.call(claim["receipt"] == {"day": 3, "outcome": "finished", "fee": r["fee"], "extra": want["cost"], "path": [r["story"], want["id"]], "ingredient": r["ids"][i], "amount": want["amount"]}, k + ": exact receipt")
		var after: Dictionary = claim["state"]
		check.call(after["completed"] == 1 and after["active"].is_empty() and after["first_day"][r["ids"][i]] == 3 and after["obtained"][r["ids"][i]] == want["amount"], k + ": counters")
		_refused(k + ": double claim", Core.finish(spec, after), after, _json(after))
		_refused(k + ": same-day relaunch locked", Core.begin(spec, after, 3, 100000), after, _json(after))
		check.call(Core.begin(spec, after, 4, 100000)["error"] == "", k + ": next day opens")
		check.call(Core.parse(spec, after, 3, 2, 1)["error"] == "", k + ": claimed ledger parses")
		# Retiring after the target keeps the fee and the day lock but gives nothing.
		var giveup: Dictionary = _trip(spec, Core.empty_state(spec), 5, [r["story"]], "retire")
		check.call(giveup["retired"] == 1 and giveup["completed"] == 0 and giveup["stock"][r["ids"][0]] == 0 and giveup["stock"][r["ids"][1]] == 0 and giveup["history"][0]["path"] == [r["story"]] and giveup["history"][0]["amount"] == 0, k + ": retire pays nothing")
		check.call(Core.parse(spec, giveup, 5, 2, 1)["error"] == "", k + ": retired story ledger parses")
	# Retired at step two (result stage) is refused: a result must be claimed.
	var res: Dictionary = _trip(spec, Core.empty_state(spec), 1, [r["story"], r["rows"][0]["id"]], "hold")
	_refused(k + ": cannot retire a finished result", Core.finish(spec, res, true), res, _json(res))
	check.call(Core.active_view(spec, res, 0)["result"]["message"].contains(str(r["rows"][0]["amount"])), k + ": result message names the amount")


# --------------------------------------------------------------- capacity logic

func _capacity(r: Dictionary) -> void:
	var spec: Dictionary = r["spec"]
	var k: String = r["key"]
	var ids: Array = r["ids"]
	# A) One ingredient full: the story target stays selectable through the other outcome.
	for full in 2:
		var stocks: Array = [0, 0]
		stocks[full] = 20
		var s: Dictionary = _next(Core.begin(spec, _stocked(spec, stocks[0], stocks[1]), 2, 100000), "begin one full", {})
		var view_row: Dictionary = Core.active_view(spec, s, 100000)["event"]["choices"][2]
		check.call(bool(view_row["affordable"]) and not bool(view_row["capacity_blocked"]), k + ": story target live while only %s is full" % ids[full])
		# Original target whose hint is full is unchanged: refused.
		var legacy: Dictionary = Core.active_view(spec, s, 100000)["event"]["choices"][full]
		check.call(bool(legacy["capacity_blocked"]) and not bool(legacy["affordable"]), k + ": original target view unchanged when its hint is full")
		_refused(k + ": original full hint refused", Core.choose(spec, s, r["targets"][full], 100000), s, _json(s))
		var t: Dictionary = _next(Core.choose(spec, s, r["story"], 100000), "story on partly full", s)
		var step2: Array = Core.active_view(spec, t, 100000)["event"]["choices"]
		check.call(bool(step2[full]["capacity_blocked"]) and not bool(step2[full]["affordable"]) and bool(step2[1 - full]["affordable"]), k + ": step two blocks only the full cross-ingredient outcome")
		_refused(k + ": full outcome refused before any change", Core.choose(spec, t, r["rows"][full]["id"], 100000), t, _json(t))
		var done: Dictionary = _next(Core.choose(spec, t, r["rows"][1 - full]["id"], 100000), "fitting outcome", t)
		check.call(Core.finish(spec, done)["state"]["stock"][ids[1 - full]] == r["rows"][1 - full]["amount"], k + ": fitting outcome claimed")
	# B) Nothing fits at all: refused with no change, shown as capacity blocked.
	var tight: Dictionary = _stocked(spec, 21 - r["rows"][0]["amount"], 21 - r["rows"][1]["amount"])
	var s2: Dictionary = _next(Core.begin(spec, tight, 2, 100000), "begin tight", {})
	var blocked: Dictionary = Core.active_view(spec, s2, 100000)["event"]["choices"][2]
	check.call(bool(blocked["capacity_blocked"]) and not bool(blocked["affordable"]) and str(blocked["desc"]).contains("20개"), k + ": no outcome fits -> blocked view")
	_refused(k + ": no outcome fits", Core.choose(spec, s2, r["story"], 100000), s2, _json(s2))
	# C) Cheap-but-full next to expensive-but-fitting: must NOT combine into availability.
	var cheap: int = 0 if r["rows"][0]["cost"] < r["rows"][1]["cost"] else 1
	var dear: int = 1 - cheap
	var stocks_c: Array = [0, 0]
	stocks_c[cheap] = 21 - r["rows"][cheap]["amount"]
	var s3: Dictionary = _next(Core.begin(spec, _stocked(spec, stocks_c[0], stocks_c[1]), 2, 100000), "begin mixed", {})
	var short: int = r["rows"][dear]["cost"] - 1
	var poor_view: Dictionary = Core.active_view(spec, s3, short)["event"]["choices"][2]
	check.call(not bool(poor_view["affordable"]) and not bool(poor_view["capacity_blocked"]), k + ": affordable-but-full + unaffordable-but-fitting is not selectable")
	_refused(k + ": mixed options refused", Core.choose(spec, s3, r["story"], short), s3, _json(s3))
	var rich_view: Dictionary = Core.active_view(spec, s3, short + 1)["event"]["choices"][2]
	check.call(bool(rich_view["affordable"]), k + ": same outcome fits and is affordable -> selectable")
	var t3: Dictionary = _next(Core.choose(spec, s3, r["story"], short + 1), "story with exact money", s3)
	_refused(k + ": step two money shortage", Core.choose(spec, t3, r["rows"][dear]["id"], short), t3, _json(t3))
	_refused(k + ": step two full option even when affordable", Core.choose(spec, t3, r["rows"][cheap]["id"], 100000), t3, _json(t3))
	var done3: Dictionary = _next(Core.choose(spec, t3, r["rows"][dear]["id"], short + 1), "exact-money outcome", t3)
	check.call(done3["active"]["extra"] == r["rows"][dear]["cost"], k + ": exact extra recorded")
	# Departure guard is unchanged: both ingredients unable to take the minimum refuses the trip.
	var full: Dictionary = _stocked(spec, 20, 20)
	_refused(k + ": begin refuses with a full box", Core.begin(spec, full, 2, 100000), full, _json(full))


# ------------------------------------------------------------------ save shapes

func _history_ledger(r: Dictionary, old_only: bool) -> Dictionary:
	var spec: Dictionary = r["spec"]
	var last_q: String = r["quantities"][1]["id"]
	var s: Dictionary = _trip(spec, Core.empty_state(spec), 1, [r["targets"][0], last_q], "finish")
	if old_only:
		s = _trip(spec, s, 2, [r["targets"][1], r["quantities"][0]["id"]], "finish")
		s = _trip(spec, s, 3, [r["targets"][0]], "retire")
	else:
		s = _trip(spec, s, 2, [r["story"], r["rows"][0]["id"]], "finish")
		s = _trip(spec, s, 3, [r["story"]], "retire")
	return s


func _parse_ok(r: Dictionary, label: String, s: Dictionary, day: int) -> void:
	var spec: Dictionary = r["spec"]
	var snap: String = _json(s)
	var parsed: Dictionary = Core.parse(spec, s, day, 50, 3)
	check.call(parsed["error"] == "" and _json(parsed["state"]) == snap and _json(s) == snap, r["key"] + ": parse keeps whole value: " + label + " " + str(parsed["error"]))
	# Saved JSON has only floats; parsing must restore the identical ints.
	var thawed: Variant = JSON.parse_string(JSON.stringify(s))
	var again: Dictionary = Core.parse(spec, thawed, day, 50, 3)
	check.call(again["error"] == "" and _json(again["state"]) == snap, r["key"] + ": JSON round trip: " + label + " " + str(again["error"]))


func _rejects(r: Dictionary, label: String, s: Dictionary, day: int, mutate: Callable) -> void:
	var snap: String = _json(s)
	var copy: Dictionary = s.duplicate(true)
	mutate.call(copy)
	var parsed: Dictionary = Core.parse(r["spec"], copy, day, 50, 3)
	check.call(parsed["error"] != "" and not parsed.has("state") and _json(s) == snap, r["key"] + ": rejected atomically: " + label)


func _parse_shapes(r: Dictionary) -> void:
	var spec: Dictionary = r["spec"]
	var story: String = r["story"]
	var row0: Dictionary = r["rows"][0]
	var row1: Dictionary = r["rows"][1]
	for old_only in [true, false]:
		var base: Dictionary = _history_ledger(r, old_only)
		var tag: String = "old v18 paths" if old_only else "new paths"
		var first: String = r["targets"][1] if old_only else story
		var second: String = r["quantities"][0]["id"] if old_only else row1["id"]
		_parse_ok(r, tag + " history only", base, 3)
		_parse_ok(r, tag + " active choice_1", _trip(spec, base, 4, [], "hold"), 4)
		_parse_ok(r, tag + " active choice_2", _trip(spec, base, 4, [first], "hold"), 4)
		_parse_ok(r, tag + " active result", _trip(spec, base, 4, [first, second], "hold"), 4)
		_parse_ok(r, tag + " claimed", _trip(spec, base, 4, [first, second], "finish"), 4)
		_parse_ok(r, tag + " retired at start", _trip(spec, base, 4, [], "retire"), 4)
		_parse_ok(r, tag + " retired after target", _trip(spec, base, 4, [first], "retire"), 4)
	var base2: Dictionary = _history_ledger(r, false)
	var result: Dictionary = _trip(spec, base2, 4, [story, row1["id"]], "hold")
	var partial: Dictionary = _trip(spec, base2, 4, [story], "hold")
	var claimed: Dictionary = _trip(spec, base2, 4, [story, row1["id"]], "finish")
	var other_ing: String = r["ids"][0]
	# Active path forgeries (each result-stage/partial copy must fail as a whole).
	_rejects(r, "story target + original quantity", result, 4, func(d): d["active"]["path"] = [story, r["quantities"][0]["id"]])
	_rejects(r, "original target + story outcome", result, 4, func(d): d["active"]["path"] = [r["targets"][0], row1["id"]])
	_rejects(r, "unknown second choice", result, 4, func(d): d["active"]["path"] = [story, "bogus"])
	_rejects(r, "three-long path", result, 4, func(d): d["active"]["path"] = [story, row1["id"], row0["id"]])
	_rejects(r, "non-string path entry", result, 4, func(d): d["active"]["path"] = [story, 5])
	_rejects(r, "extra fee of the other outcome", result, 4, func(d): d["active"]["extra"] = row0["cost"])
	_rejects(r, "extra fee +1", result, 4, func(d): d["active"]["extra"] += 1)
	_rejects(r, "departure fee changed", result, 4, func(d): d["active"]["fee"] += 1)
	_rejects(r, "result stage on a one-step path", partial, 4, func(d): d["active"]["stage"] = "result")
	_rejects(r, "choice stage on a finished path", result, 4, func(d): d["active"]["stage"] = "choice_2")
	_rejects(r, "unknown stage", result, 4, func(d): d["active"]["stage"] = "fake")
	_rejects(r, "active day moved", result, 4, func(d): d["active"]["day"] = 3)
	_rejects(r, "result that no longer fits stock", result, 4, func(d):
		d["stock"][r["ids"][1]] = 20
		d["obtained"][r["ids"][1]] = 20)
	# History receipt forgeries.
	_rejects(r, "receipt ingredient swapped", claimed, 4, func(d): d["history"][1]["ingredient"] = r["ids"][1])
	_rejects(r, "receipt ingredient from another region", claimed, 4, func(d): d["history"][3]["ingredient"] = "broth_chicken")
	_rejects(r, "receipt amount +1", claimed, 4, func(d): d["history"][3]["amount"] += 1)
	_rejects(r, "receipt amount of the other outcome", claimed, 4, func(d): d["history"][3]["amount"] = row0["amount"])
	_rejects(r, "receipt extra changed", claimed, 4, func(d): d["history"][3]["extra"] = 0)
	_rejects(r, "receipt fee changed", claimed, 4, func(d): d["history"][3]["fee"] -= 1)
	_rejects(r, "receipt wrong target-specific path", claimed, 4, func(d): d["history"][3]["path"] = [story, r["quantities"][1]["id"]])
	_rejects(r, "receipt single-step finish", claimed, 4, func(d): d["history"][3]["path"] = [story])
	_rejects(r, "receipt day order", claimed, 4, func(d): d["history"][3]["day"] = 2)
	_rejects(r, "retired receipt granting something", claimed, 4, func(d):
		d["history"][2]["amount"] = 1
		d["history"][2]["ingredient"] = other_ing)
	# Counter, stock and chronology conservation.
	_rejects(r, "completed counter +1", claimed, 4, func(d): d["completed"] += 1)
	_rejects(r, "stock without matching obtained", claimed, 4, func(d): d["stock"][r["ids"][1]] += 1)
	# Conserved (stock follows obtained), so only the receipt/ceiling replay can catch it.
	_rejects(r, "obtained beyond what receipts and trips can explain", claimed, 4, func(d):
		d["obtained"][r["ids"][1]] += 5
		d["stock"][r["ids"][1]] += 5)
	_rejects(r, "first day after the last departure", claimed, 4, func(d): d["first_day"][r["ids"][1]] = 5)
	_rejects(r, "last departure rewound", claimed, 4, func(d): d["last_departure_day"] = 3)
	_rejects(r, "extra key", claimed, 4, func(d): d["fake"] = 1)
	_rejects(r, "fractional counter", claimed, 4, func(d): d["completed"] = 1.5)
	_rejects(r, "one history record dropped", claimed, 4, func(d): d["history"].pop_back())


func _truncated(r: Dictionary) -> void:
	var spec: Dictionary = r["spec"]
	var s: Dictionary = Core.empty_state(spec)
	# 14 trips mix story and original shapes; storage is emptied (used) each day so it stays <= 20.
	for day in range(1, 15):
		match day % 3:
			0: s = _trip(spec, s, day, [r["story"], r["rows"][0]["id"]], "finish")
			1: s = _trip(spec, s, day, [r["story"], r["rows"][1]["id"]], "finish")
			_: s = _trip(spec, s, day, [r["targets"][day % 2], r["quantities"][1]["id"]], "finish")
		_spend_all(spec, s)
	check.call(s["history"].size() == 12 and s["completed"] == 14 and s["history"][0]["day"] == 3, r["key"] + ": history bounded to 12")
	_parse_ok(r, "truncated history", s, 14)
	_rejects(r, "truncated history record dropped", s, 14, func(d): d["history"].pop_front())
	_rejects(r, "truncated history record added", s, 14, func(d): d["history"].append(d["history"][11].duplicate(true)))
	_rejects(r, "truncated receipt forged", s, 14, func(d): d["history"][5]["path"] = [r["story"], r["quantities"][0]["id"]])
	_rejects(r, "received more than obtained", s, 14, func(d):
		d["obtained"][r["ids"][0]] = 1
		d["used"][r["ids"][0]] = 1)
	# Next-record use bound still applies after the counter widening.
	var over: Dictionary = Core.parse(spec, s, 14, 2, 1)
	check.call(over["error"] != "" and not over.has("state"), r["key"] + ": used counter still bounded by next record")


func _lifetime(r: Dictionary) -> void:
	var spec: Dictionary = r["spec"]
	var k: String = r["key"]
	var a: String = r["ids"][0]
	var b: String = r["ids"][1]
	var row0: Dictionary = r["rows"][0]
	# Explicit conserved boundary ledger (pure fixture, not a public acquisition): 99999
	# claimed days at the 5/day maximum legitimately exceed the old 300000 counter cap.
	var s: Dictionary = Core.empty_state(spec)
	s["completed"] = 99999
	s["last_departure_day"] = 99999
	s["obtained"][a] = 400000
	s["obtained"][b] = 99995
	s["used"][a] = 399980
	s["used"][b] = 99995
	s["stock"][a] = 20
	s["first_day"][a] = 1
	s["first_day"][b] = 2
	for i in 12:
		s["history"].append({"day": 99988 + i, "outcome": "finished", "fee": r["fee"], "extra": row0["cost"], "path": [r["story"], row0["id"]], "ingredient": a, "amount": row0["amount"]})
	check.call(int(s["obtained"][a]) > 300000, k + ": fixture really exceeds the old counter bound")
	var parsed: Dictionary = Core.parse(spec, s, 99999, 200000, 3)
	check.call(parsed["error"] == "" and _json(parsed["state"]) == _json(s), k + ": legitimate lifetime>300000 accepted: " + str(parsed["error"]))
	var thawed: Variant = JSON.parse_string(JSON.stringify(s))
	check.call(Core.parse(spec, thawed, 99999, 200000, 3)["error"] == "", k + ": lifetime>300000 survives a JSON round trip")
	# One past the 5/day x 99999-day ceiling, and wildly large counters, stay invalid.
	_strict(r, s, "counter above 5/day ceiling", func(d):
		d["obtained"][a] = 500000
		d["used"][a] = 499980)
	_strict(r, s, "arbitrary huge counter", func(d):
		d["obtained"][a] = 1000000000
		d["used"][a] = 999999980)
	_strict(r, s, "acquired beyond completed x max", func(d):
		d["obtained"][b] += 1
		d["used"][b] += 1)
	_strict(r, s, "used beyond next record bound", Callable(), 99999, 100000)
	_strict(r, s, "stock above storage cap", func(d):
		d["stock"][a] = 21
		d["obtained"][a] += 1)
	_strict(r, s, "history weakened: forged amount", func(d): d["history"][4]["amount"] = 1)
	_strict(r, s, "history from the future", func(d): d["history"][11]["day"] = 100000)
	_strict(r, s, "counters exceed game days", func(d): d["completed"] = 100000)
	_strict(r, s, "history day beyond the current day", Callable(), 99998)


func _strict(r: Dictionary, s: Dictionary, label: String, mutate: Callable, day: int = 99999, next_record: int = 200000) -> void:
	var copy: Dictionary = s.duplicate(true)
	if mutate.is_valid():
		mutate.call(copy)
	var out: Dictionary = Core.parse(r["spec"], copy, day, next_record, 3)
	check.call(out["error"] != "" and not out.has("state"), r["key"] + ": still rejected: " + label)


# ------------------------------------------------------------ public GameState

func _fund(state: State, need: int) -> void:
	var guard: int = 0
	while state.wallet < need and guard < 20:
		check.call(bool(state.serve()["ok"]), "service day to afford the next encounter")
		guard += 1


func _journey(r: Dictionary) -> void:
	var k: String = r["key"]
	var fixture: Variant = r["fixture"].new()
	fixture.check = check
	var state: State = fixture.ready()
	var review: String = "foraging_review" if k == "market" else k + "_foraging_review"
	if not state.call(review)["can_start"]:
		check.call(false, k + ": real fixture must unlock sampling")
		return
	var valid_partial: Dictionary = {}
	var valid_result: Dictionary = {}
	for i in 2:
		var want: Dictionary = r["rows"][i]
		_fund(state, r["fee"] + want["cost"])
		var ing: String = r["ids"][i]
		var other: String = r["ids"][1 - i]
		var money: int = state.wallet
		var stock: int = state.sample_stock(ing)
		var other_stock: int = state.sample_stock(other)
		check.call(bool(state.call(r["start"])["ok"]) and state.wallet == money - r["fee"], k + ": real departure pays the base fee once")
		# A wrong/unknown first choice never charges or moves the ledger.
		var snap: String = JSON.stringify(state.to_dict(), "", true)
		check.call(not bool(state.advance_expedition("bogus")["ok"]) and JSON.stringify(state.to_dict(), "", true) == snap, k + ": unknown first choice atomic")
		check.call(bool(state.advance_expedition(r["story"])["ok"]) and state.wallet == money - r["fee"], k + ": story target is free")
		if i == 0:
			valid_partial = state.to_dict().duplicate(true)
		snap = JSON.stringify(state.to_dict(), "", true)
		for bad in [r["quantities"][0]["id"], r["quantities"][1]["id"], r["targets"][0], "bogus"]:
			check.call(not bool(state.advance_expedition(bad)["ok"]) and JSON.stringify(state.to_dict(), "", true) == snap, k + ": wrong step-two choice atomic: " + bad)
		check.call(not bool(state.finish_expedition()["ok"]) and not bool(state.start_expedition("market")["ok"]) and JSON.stringify(state.to_dict(), "", true) == snap, k + ": early claim / second departure atomic")
		check.call(bool(state.advance_expedition(want["id"])["ok"]), k + ": choose " + want["id"])
		check.call(state.wallet == money - r["fee"] - want["cost"] and state.sample_stock(ing) == stock, k + ": exact extra paid, nothing granted before claim")
		if i == 1:
			valid_result = state.to_dict().duplicate(true)
		# Whole-value save round trip at the result stage, through real JSON floats.
		var restored := State.new()
		var err: String = restored.load_from_dict(JSON.parse_string(JSON.stringify(state.to_dict(), "", true)))
		check.call(err == "" and JSON.stringify(restored.to_dict(), "", true) == JSON.stringify(state.to_dict(), "", true), k + ": result stage restores exactly: " + err)
		check.call(bool(state.finish_expedition()["ok"]), k + ": explicit claim")
		check.call(state.sample_stock(ing) == stock + want["amount"] and state.sample_stock(other) == other_stock, k + ": exact reward in the outcome's own ingredient")
		var last: Dictionary = state.call(r["snap"])["history"].back()
		check.call(last["path"] == [r["story"], want["id"]] and last["extra"] == want["cost"] and last["amount"] == want["amount"] and last["ingredient"] == ing and last["fee"] == r["fee"], k + ": receipt is exact")
		snap = JSON.stringify(state.to_dict(), "", true)
		check.call(not bool(state.finish_expedition()["ok"]) and not bool(state.call(r["start"])["ok"]) and JSON.stringify(state.to_dict(), "", true) == snap, k + ": reward is one-time and the day stays spent")
		check.call(bool(state.serve()["ok"]), k + ": service reopens travel")
	# Retire path, then tasting-only use: samples are consumed by tasting, never by service.
	_fund(state, r["fee"])
	var cash: int = state.wallet
	check.call(bool(state.call(r["start"])["ok"]) and bool(state.advance_expedition(r["story"])["ok"]) and bool(state.retire_expedition()["ok"]), k + ": retire after the target")
	check.call(state.wallet == cash - r["fee"] and not bool(state.call(r["start"])["ok"]) and state.call(r["snap"])["retired"] == 1, k + ": retire keeps the fee and the day")
	check.call(bool(state.serve()["ok"]), k + ": next day after retire")
	var final_raw: Dictionary = state.to_dict().duplicate(true)
	var final_ok := State.new()
	check.call(final_ok.load_from_dict(final_raw.duplicate(true)) == "", k + ": history with story, retire and old shapes restores")
	_forged_saves(r, final_raw, valid_partial, valid_result)


func _load_rejected(label: String, raw: Dictionary) -> void:
	var target := State.new()
	var snap: String = JSON.stringify(target.to_dict(), "", true)
	check.call(target.load_from_dict(raw) != "" and JSON.stringify(target.to_dict(), "", true) == snap, label)


func _forged_saves(r: Dictionary, claimed: Dictionary, partial: Dictionary, result: Dictionary) -> void:
	var k: String = r["key"]
	var control_a := State.new()
	var control_b := State.new()
	check.call(control_a.load_from_dict(partial.duplicate(true)) == "" and control_b.load_from_dict(result.duplicate(true)) == "", k + ": untouched partial/result saves load (controls)")
	_forge(r, result, "wrong target-specific path", func(f): f["active"]["path"] = [r["story"], r["quantities"][0]["id"]])
	_forge(r, result, "other fee", func(f): f["active"]["extra"] += 1)
	_forge(r, result, "bad stage", func(f): f["active"]["stage"] = "choice_2")
	_forge(r, partial, "premature result stage", func(f): f["active"]["stage"] = "result")
	_forge(r, claimed, "ingredient", func(f): f["history"][0]["ingredient"] = r["ids"][1 - r["ids"].find(f["history"][0]["ingredient"])])
	_forge(r, claimed, "amount", func(f): f["history"][0]["amount"] += 1)
	_forge(r, claimed, "receipt fee", func(f): f["history"][0]["fee"] += 1)
	_forge(r, claimed, "completed count", func(f): f["completed"] += 1)
	_forge(r, claimed, "stock", func(f): f["stock"][r["ids"][0]] += 1)


## Applies one forgery to the region's ledger inside an otherwise valid whole save.
func _forge(r: Dictionary, base: Dictionary, label: String, mutate: Callable) -> void:
	var raw: Dictionary = base.duplicate(true)
	mutate.call(raw[r["save"]])
	_load_rejected(r["key"] + ": forged save rejected atomically: " + label, raw)


# -------------------------------------------------------------- module wrappers

func _wrappers() -> void:
	# The thin region wrappers must forward the new target through the same ledger.
	var pairs: Array = [[Market, "market_group_buy", "share_sesame_two"], [Harbor, "harbor_shared_catch", "sort_sardine_two"], [Mountain, "mountain_shared_mill", "share_shiitake_two"]]
	for pair in pairs:
		var module: Variant = pair[0]
		check.call(module.choices([]).size() == 3 and module.choices([pair[1]]).size() == 2, "wrapper exposes three targets / two outcomes for " + pair[1])
		var fresh: Dictionary = module.empty_state()
		var s: Dictionary = module.begin(fresh, 1, 100000)["state"]
		s = module.choose(s, pair[1], 100000)["state"]
		check.call(module.active_view(s, 100000)["event"]["choices"].size() == 2, "wrapper active_view for " + pair[1])
		s = module.choose(s, pair[2], 100000)["state"]
		var done: Dictionary = module.finish(s)
		check.call(done["error"] == "" and module.outcome(done["receipt"]["path"])["amount"] == done["receipt"]["amount"] and module.parse(done["state"], 1, 2, 1)["error"] == "", "wrapper finish/outcome/parse for " + pair[1])
