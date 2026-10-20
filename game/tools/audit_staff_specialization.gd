extends "res://tools/audit_campaign_progression.gd"
## Reuse actual service, disk reload, duplicate-settlement and wallet checks.
## The only treatment is the allowed training choice after its real unlock.
const LONG_DAYS: int = 35
const TRAINING_MODES: Array = ["untrained", "basic", "speed", "economy"]
var _mode: String = "untrained"


func _initialize() -> void:
	var output: String = _new_output_from_args()
	if output == "":
		return
	var cases: Array = []
	for mode in TRAINING_MODES:
		_mode = str(mode)
		var folder: String = output.path_join(_mode)
		if not _check(DirAccess.make_dir_absolute(folder) == OK, "new training-policy directory"):
			continue
		for menu in ["fast", "slow"]:
			var policies: Array = ["none", "prep", "floor"] if _mode == "untrained" else ["prep", "floor"]
			for policy in policies:
				var campaign: Dictionary = _campaign(str(menu), str(policy), folder, LONG_DAYS)
				if not campaign.is_empty():
					cases.append({"training_mode": _mode, "campaign": campaign})
	_check(cases.size() == 18, "all eighteen specialization campaigns complete")
	var report: Dictionary = {"format": 2, "kind": "staff_specialization", "days_per_campaign": LONG_DAYS,
		"scope": "Two fixed single menus, known research witnesses, no-hire controls and prep/floor helper training policies. Real eligibility/transactions/service/daily disk reload; no injected money/day/rank/experience. No expansion, exploration, contests, stories, UI/fun/iPhone claim or gameplay changes.",
		"cases": cases, "checks": checks + 3, "failures": failures}
	if not _write_new(output.path_join("report.json"), JSON.stringify(report, "\t", true) + "\n"):
		quit(2)
		return
	print("staff audit: campaigns=%d runtime_days=%d checks=%d failures=%d" % [cases.size(), cases.size() * LONG_DAYS, checks, failures.size()])
	quit(0 if failures.is_empty() else 1)


func _training_choice(state: State, id: String) -> String:
	var level: int = state.staff_training()[id]["lessons"].size()
	if _mode == "untrained" or level == 2 or (_mode == "basic" and level == 1):
		return ""
	return "basic" if level == 0 else _mode


## Observe completed-order facts, not a modeled promise of shorter waiting.
## Compact per-order witnesses let Python reconcile every aggregate separately.
func _runtime_metrics(session: RefCounted, summary: Dictionary) -> Dictionary:
	var completed: Array = session.get("completed")
	_check(completed.size() == int(summary["units"]), "completed-order metrics match actual settlement count")
	var orders: Array = []
	var wait_total: int = 0
	var stars_total: int = 0
	for raw in completed:
		var order: Dictionary = raw
		var witness: Dictionary = {}
		for key in ["order_id", "source", "wait", "stars", "done_t", "price", "unit_cost"]:
			witness[key] = order[key]
		orders.append(witness)
		wait_total += int(order["wait"])
		stars_total += int(order["stars"])
	return {"orders": orders, "wait_total": wait_total, "stars_total": stars_total,
		"finished_at": int(summary["finished_at"])}
