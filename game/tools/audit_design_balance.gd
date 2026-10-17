extends SceneTree
## Read-only design probe: enumerates a bounded ingredient space, then checks
## selected forecasts against the real completed-order runtime. Never loads saves.
const Catalog = preload("res://scripts/domain/ingredient_catalog.gd")
const Evaluator = preload("res://scripts/domain/recipe_evaluator.gd")
const Sim = preload("res://scripts/domain/sales_simulator.gd")
const Session = preload("res://scripts/domain/service_session.gd")
const Prices: Array[int] = [6000, 7500, 9000, 10500, 12000]
var failures: int = 0
var forecast_cases: int = 0
var process_cases: int = 0
var top: Dictionary = {}
var balanced: Dictionary = {}
var redundant: Dictionary = {}


func _initialize() -> void:
	var output: String = ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			output = arg.substr(6)
	if not output.is_absolute_path() or FileAccess.file_exists(output):
		printerr("--out must be an absolute, new output file; existing files are preserved.")
		quit(2)
		return
	var count: int = 0
	for broth in Catalog.ITEMS["broth"]:
		for tare in Catalog.ITEMS["tare"]:
			for oil in Catalog.ITEMS["oil"]:
				for noodle in Catalog.ITEMS["noodle"]:
					for topping in Catalog.ITEMS["topping"]:
						for cook in Catalog.ITEMS["cook"]:
							var cfg: Dictionary = {"broth": broth["id"], "tare": tare["id"], "oil": oil["id"], "noodle": noodle["id"], "toppings": [topping["id"]], "cook": cook["id"], "price": 9000}
							inspect_config(cfg)
							count += 1
	var actual: Array = []
	if not top.is_empty() and not balanced.is_empty():
		actual.append(actual_week("default", Catalog.default_config()))
		actual.append(actual_week("best_sampled_forecast", top["config"]))
		actual.append(actual_week("best_minimum_taste_at_9000", balanced["config"]))
	if count != 972 or forecast_cases != 34020 or process_cases != 8748 or actual.size() != 3:
		failures += 1
	var result: Dictionary = {"format": 1, "ingredient_configs": count, "prices": Prices,
		"days": [1, 2, 3, 4, 5, 6, 7], "forecast_cases": forecast_cases, "process_cases": process_cases,
		"scope": "Base ingredients, exactly one topping, no discoveries/helpers/expansion. Forecast sweep uses default processes. Process comparisons include rank-2 methods. Fresh runtime record_id=1 for each sampled day; no campaign progression, taste costs or rewards.",
		"best_sampled_forecast": top, "best_minimum_taste_at_9000": balanced,
		"same_scores_but_costlier_and_no_faster_than_default": redundant,
		"runtime_samples": actual, "failures": failures}
	if failures != 0:
		printerr("Audit failed: %d errors; no successful evidence written." % failures)
		quit(1)
		return
	var file: FileAccess = FileAccess.open(output, FileAccess.WRITE)
	if file == null:
		printerr("Cannot write audit: %s" % error_string(FileAccess.get_open_error()))
		quit(2)
		return
	file.store_string(JSON.stringify(result, "\t", true) + "\n")
	file.close()
	print("design audit: ingredients=%d forecasts=%d processes=%d runtime_days=21 failures=%d" % [count, forecast_cases, process_cases, failures])
	quit(0)


func scores_for(ev: Dictionary) -> Dictionary:
	var scores: Dictionary = {}
	for row in ev["customers"]:
		scores[row["id"]] = int(row["score"])
	return scores


func inspect_config(cfg: Dictionary) -> void:
	var ev: Dictionary = Evaluator.evaluate(cfg)
	if str(ev["error"]) != "":
		failures += 1
		return
	var scores: Dictionary = scores_for(ev)
	var minimum: int = mini(int(scores["dohyun"]), mini(int(scores["hayoung"]), int(scores["maru"])))
	if balanced.is_empty() or minimum > int(balanced["minimum_score"]):
		balanced = {"config": cfg.duplicate(true), "scores": scores, "minimum_score": minimum}
	for price in Prices:
		var priced: Dictionary = cfg.duplicate(true)
		priced["price"] = price
		var net: int = 0
		for day in range(1, 8):
			var fc: Dictionary = Sim.simulate(priced, scores, day)
			forecast_cases += 1
			if str(fc["error"]) != "":
				failures += 1
			else:
				net += int(fc["net"])
		if top.is_empty() or net > int(top["weekly_forecast_net"]):
			top = {"config": priced, "scores": scores, "weekly_forecast_net": net}
	# This detects only local score-equivalence against the same default recipe.
	# It does not prove a method is dominated for stories, contests or other recipes.
	for broth in ["standard", "gentle", "rolling"]:
		for noodle in ["standard", "moist", "rested"]:
			var method_cfg: Dictionary = cfg.duplicate(true)
			if broth != "standard" or noodle != "standard":
				method_cfg["process"] = {"broth": broth, "noodle": noodle}
			var m: Dictionary = Evaluator.evaluate(method_cfg)
			process_cases += 1
			if str(m["error"]) != "":
				failures += 1
				continue
			if scores_for(m) == scores and int(m["unit_cost"]) > int(ev["unit_cost"]) and int(m["prep_seconds"]) >= int(ev["prep_seconds"]):
				var key: String = broth + ":" + noodle
				redundant[key] = int(redundant.get(key, 0)) + 1


func actual_week(label: String, cfg: Dictionary) -> Dictionary:
	var scores: Dictionary = scores_for(Evaluator.evaluate(cfg))
	var record: Dictionary = {"record_id": 1, "name": label, "version": 1, "config": cfg, "scores": scores}
	var rows: Array = []
	var total: int = 0
	for day in range(1, 8):
		var plan: Dictionary = Session.make_plan(record, day)
		if str(plan["error"]) != "":
			failures += 1
			continue
		var runtime: RefCounted = Session.new(plan)
		if not runtime.run_to_end():
			failures += 1
			continue
		var row: Dictionary = runtime.summary()
		if str(row["error"]) != "":
			failures += 1
			continue
		var net: int = int(row["revenue"]) - int(row["ingredient_cost"]) - int(row["overhead"])
		total += net
		rows.append({"day": day, "net": net, "units": row["units"], "revenue": row["revenue"],
			"ingredient_cost": row["ingredient_cost"], "overhead": row["overhead"],
			"turned_away": row["turned_away"], "forecast_net": plan["forecast"]["net"]})
	if rows.size() != 7:
		failures += 1
	return {"label": label, "config": cfg, "scores": scores, "days": rows, "weekly_net": total}
