extends RefCounted
## Shared meaningful transaction tests, invoked by the full suite and a focused
## runner. Only the caller's disposable data directory is read or written.
const State = preload("res://scripts/domain/game_state.gd")
const Farm = preload("res://scripts/domain/market_foraging.gd")
const Catalog = preload("res://scripts/domain/ingredient_catalog.gd")
const Evaluator = preload("res://scripts/domain/recipe_evaluator.gd")
const Art = preload("res://scripts/ui/pixel_art.gd")
const Save = preload("res://scripts/services/save_service.gd")
const Research = preload("res://scripts/domain/ramen_research.gd")
var check: Callable


func _ok(result: Dictionary, label: String) -> bool:
	check.call(bool(result["ok"]), label + ": " + str(result.get("message", "")))
	return bool(result["ok"])


func _json(state: State) -> String:
	return JSON.stringify(state.to_dict(), "", true)


func _serve(state: State) -> void:
	if not _ok(state.begin_service(), "actual service starts"):
		return
	check.call(state.active_session().run_to_end(), "actual service finishes")
	_ok(state.settle_service(), "actual service settles once")


## No money/day/rank injection: discover each original market supplier and
## complete real services. This is the same unlock a fresh player must reach.
func ready() -> State:
	var state: State = State.new()
	_ok(state.taste(), "first baseline tasting")
	for choice in ["m_hear_recipe", "m_buy_pickle"]:
		_ok(state.start_expedition("market"), "supplier trip")
		_ok(state.advance_expedition("m_ask"), "supplier first choice")
		_ok(state.advance_expedition(choice), "supplier second choice")
		_ok(state.finish_expedition(), "supplier collected")
		check.call(not bool(state.start_foraging()["ok"]), "same-day sampling cannot bypass old trip")
		_serve(state)
	check.call(state.foraging_review()["can_start"], "market completion unlocks repeat sampling")
	return state


func _collect(state: State, branch: String, count: String = "take_two") -> void:
	_ok(state.start_foraging(), "sample trip starts")
	_ok(state.advance_expedition(branch), "sample material chosen")
	_ok(state.advance_expedition(count), "sample quantity chosen")
	_ok(state.finish_expedition(), "sample reward claimed")


func run(callback: Callable, data_dir: String) -> void:
	check = callback
	var fresh: State = State.new()
	var unchanged: String = _json(fresh)
	check.call(not bool(fresh.start_foraging()["ok"]) and _json(fresh) == unchanged, "sampling cannot precede supplier discovery")
	var state: State = ready()
	var money: int = state.wallet
	_ok(state.start_foraging(), "first repeat trip")
	check.call(state.wallet == money - Farm.FEE and state.departed_today(), "fee and shared day consumed exactly once")
	unchanged = _json(state)
	for rejected in [state.start_foraging(), state.start_expedition("harbor"), state.taste(), state.begin_service(), state.advance_expedition("take_three")]:
		check.call(not bool(rejected["ok"]) and _json(state) == unchanged, "invalid/busy actions are atomic")
	for phase in 3:
		var store: Save = Save.new(data_dir.path_join("phase-%d" % phase))
		check.call(DirAccess.make_dir_recursive_absolute(store.dir) == OK, "isolated phase directory created")
		if not _ok(store.save_state(state), "each sampling phase saves"):
			return
		var restored: State = State.new()
		var loaded_phase: Dictionary = store.load_into(restored)
		var same: bool = loaded_phase["status"] == "ok" and _json(restored) == _json(state)
		check.call(same, "each sampling phase restores exactly: " + str(loaded_phase["message"]))
		if not same:
			return
		state = restored
		if phase == 0:
			_ok(state.advance_expedition("sesame_stall"), "first sampling choice")
		elif phase == 1:
			_ok(state.advance_expedition("take_two"), "second sampling choice")
	check.call(state.foraging_state()["stock"][Farm.IDS[0]] == 0, "result waiting does not grant samples")
	_ok(state.finish_expedition(), "claim two samples")
	check.call(state.foraging_state()["stock"][Farm.IDS[0]] == 2 and state.ingredient_unlocked(Farm.IDS[0]), "claim grants exactly two and knowledge")
	unchanged = _json(state)
	check.call(not bool(state.finish_expedition()["ok"]) and _json(state) == unchanged, "duplicate claim cannot grant samples")
	_ok(state.set_draft_choice("oil", Farm.IDS[0]), "use new oil")
	var plain: Dictionary = Evaluator.evaluate(Catalog.default_config())
	var developed: Dictionary = Evaluator.evaluate(state.draft_config)
	check.call(plain["profile"] != developed["profile"] and plain["unit_cost"] != developed["unit_cost"] and plain["prep_seconds"] != developed["prep_seconds"], "new material changes taste, cost and cooking time")
	check.call(Art.bowl_image(Catalog.default_config()).get_data() != Art.bowl_image(state.draft_config).get_data(), "new oil visibly changes bowl")
	money = state.wallet
	var cost: int = state.trial_cost()
	_ok(state.taste(), "farm ingredient prototype")
	check.call(state.wallet == money - cost and state.foraging_state()["stock"][Farm.IDS[0]] == 1 and state.foraging_state()["used"][Farm.IDS[0]] == 1, "one trial charges one sample and exact cash")
	unchanged = _json(state)
	check.call(not bool(state.taste()["ok"]) and _json(state) == unchanged, "duplicate trial costs nothing")
	_ok(state.set_draft_price(int(state.draft_config["price"]) + 100), "different revision")
	_ok(state.taste(), "second prototype uses last sample")
	_ok(state.set_draft_price(int(state.draft_config["price"]) + 100), "third draft")
	unchanged = _json(state)
	check.call(not bool(state.taste()["ok"]) and _json(state) == unchanged, "stock shortage preserves cash and all IDs/records")
	_serve(state)
	check.call(state.foraging_state()["stock"][Farm.IDS[0]] == 0 and state.foraging_state()["used"][Farm.IDS[0]] == 2, "registered menu sells at zero research stock without consumption")
	_collect(state, "citrus_cart", "take_three")
	_ok(state.set_draft_toppings([Farm.IDS[1]]), "new citrus topping")
	# A config using two samples must fail without consuming the available one.
	unchanged = _json(state)
	check.call(not bool(state.taste()["ok"]) and _json(state) == unchanged, "two-material shortage is atomic")
	_ok(state.set_draft_choice("oil", "oil_scallion"), "remove unavailable sesame")
	var citrus_bowl: PackedByteArray = Art.bowl_image(state.draft_config).get_data()
	var other: Dictionary = state.draft_config.duplicate(true)
	other["toppings"] = ["topping_egg"]
	check.call(citrus_bowl != Art.bowl_image(other).get_data(), "citrus is a distinct visible topping")
	_ok(state.taste(), "citrus prototype")
	var loaded: State = State.new()
	check.call(loaded.load_from_dict(JSON.parse_string(_json(state))) == "" and _json(loaded) == _json(state), "farmed records/cost/stock/achievements round trip")
	_serve(state)
	_collect(state, "sesame_stall")
	_ok(state.set_draft_choice("oil", Farm.IDS[0]), "both farmed ingredients")
	_ok(state.taste(), "both-material prototype")
	check.call(state.foraging_state()["used"][Farm.IDS[0]] == 3 and state.foraging_state()["used"][Farm.IDS[1]] == 2, "one sample each, including topping")
	_corruptions(state)
	_deleted_witness(state)
	_cross_features(state)
	_limits()
	_retirement()
	_legacy(data_dir)


func _corruptions(state: State) -> void:
	for kind in ["missing", "unknown", "stock", "used", "future", "first", "fee", "amount", "path", "extra", "counter", "history_order", "bool", "fraction", "negative", "active_type"]:
		var bad: Dictionary = JSON.parse_string(_json(state))
		var farm: Dictionary = bad["foraging"]
		match kind:
			"missing": bad.erase("foraging")
			"unknown": farm["stock"]["fake"] = 1
			"stock": farm["stock"][Farm.IDS[0]] += 1
			"used": farm["used"][Farm.IDS[1]] = 0
			"future": farm["last_departure_day"] = state.day + 1
			"first": farm["first_day"][Farm.IDS[0]] = 1
			"fee": farm["history"][0]["fee"] = 0
			"amount": farm["history"][0]["amount"] = 100
			"path": farm["history"][0]["path"] = ["citrus_cart", "take_three"]
			"extra": farm["history"][0]["extra"] = 300
			"counter": farm["completed"] += 1
			"history_order": farm["history"].reverse()
			"bool": farm["stock"][Farm.IDS[0]] = true
			"fraction": farm["stock"][Farm.IDS[0]] = 0.5
			"negative": farm["used"][Farm.IDS[0]] = -1
			"active_type": farm["active"] = []
		var target: State = State.new()
		var before: String = _json(target)
		check.call(target.load_from_dict(bad) != "" and _json(target) == before, "corrupt save rejected atomically: " + kind)


func _deleted_witness(state: State) -> void:
	var pruned: Dictionary = state.to_dict()
	pruned["records"] = []
	pruned["selected_record_id"] = 0
	pruned["last_feedback_record_id"] = 0
	pruned["draft"]["lineage_id"] = 0
	var target: State = State.new()
	check.call(target.load_from_dict(pruned) == "", "historical taste proof survives notebook cleanup")
	var has_sample_proof: bool = false
	for proof in pruned["taste_achievements"].values():
		if not proof.is_empty():
			for id in Catalog.item_ids(proof["config"]):
				has_sample_proof = has_sample_proof or Catalog.is_farmed(id)
	check.call(has_sample_proof, "negative fixture retains a farmed best-taste witness")
	for id in Farm.IDS:
		pruned["foraging"]["used"][id] = 0
		pruned["foraging"]["stock"][id] = pruned["foraging"]["obtained"][id]
	var before: String = _json(target)
	check.call(target.load_from_dict(pruned).contains("소비") and _json(target) == before, "deleted notebook cannot erase sample consumption of surviving proof")


func _limits() -> void:
	var farm: Dictionary = Farm.empty_state()
	for day in range(1, 11):
		farm = Farm.begin(farm, day, 100000)["state"]
		farm = Farm.choose(farm, "sesame_stall", 100000)["state"]
		farm = Farm.choose(farm, "take_two", 100000)["state"]
		farm = Farm.finish(farm)["state"]
	check.call(farm["stock"][Farm.IDS[0]] == 20, "sample capacity reached")
	farm = Farm.begin(farm, 11, 100000)["state"]
	var before: String = JSON.stringify(farm)
	check.call(str(Farm.choose(farm, "sesame_stall", 100000)["error"]) != "" and JSON.stringify(farm) == before, "full material branch refused atomically before payment")
	check.call(str(Farm.parse(farm, 11, 1)["error"]) == "", "capacity/active state remains loadable")
	var empty: Dictionary = Farm.empty_state()
	check.call(str(Farm.begin(empty, 1, 999)["error"]) != "" and empty == Farm.empty_state(), "fee shortage does not mutate")
	# Trimmed receipts still retain cumulative collection/consumption and the
	# first discovery. A real trial uses one per ingredient, never random amounts.
	farm = Farm.empty_state()
	var cfg: Dictionary = Catalog.default_config()
	cfg["oil"] = Farm.IDS[0]
	for day in range(1, 17):
		farm = Farm.begin(farm, day, 100000)["state"]
		farm = Farm.choose(farm, "sesame_stall", 100000)["state"]
		farm = Farm.choose(farm, "take_two", 100000)["state"]
		farm = Farm.finish(farm)["state"]
		farm = Farm.use_samples(farm, cfg)["state"]
		farm = Farm.use_samples(farm, cfg)["state"]
	check.call(farm["history"].size() == 12 and farm["completed"] == 16 and farm["used"][Farm.IDS[0]] == 32 and farm["first_day"][Farm.IDS[0]] == 1, "history trimming preserves totals and original knowledge")
	check.call(Farm.parse(JSON.parse_string(JSON.stringify(farm)), 17, 33)["error"] == "", "trimmed sample ledger normalizes and loads")


func _cross_features(state: State) -> void:
	var sample_menu: int = state.selected_record_id
	state.start_new_recipe()
	var cfg: Dictionary = Research.WITNESSES["hayoung_basic"]
	for slot in Catalog.SLOTS:
		_ok(state.set_draft_choice(slot, cfg[slot]), "ordinary research menu after farming")
	_ok(state.set_draft_price(cfg["price"]), "ordinary research price")
	_ok(state.taste(), "ordinary trial does not spend samples")
	_ok(state.submit_research("hayoung_basic", state.selected_record_id), "actual research promotion prerequisite")
	_ok(state.apply_promotion(2), "actual promotion after normal services")
	_ok(state.expand_shop(), "actual expansion after farming")
	_ok(state.set_selling_menus([sample_menu, state.selected_record_id]), "mixed farm/ordinary selling roster")
	var inventory: Dictionary = state.foraging_state()
	_serve(state)
	check.call(state.foraging_state() == inventory and state.last_report.has("menus"), "two-menu actual service preserves all research samples")
	_ok(state.enter_contest("clear_bowl", sample_menu), "farm-derived recipe enters existing contest")
	var restored: State = State.new()
	var error: String = restored.load_from_dict(JSON.parse_string(_json(state)))
	check.call(error == "" and _json(restored) == _json(state), "expanded report/contest/farm discovery chronology round trip: " + error)


func _retirement() -> void:
	var state: State = ready()
	var wallet: int = state.wallet
	_ok(state.start_foraging(), "retirement trip")
	_ok(state.advance_expedition("sesame_stall"), "retirement first choice")
	_ok(state.retire_expedition(), "retire research trip")
	check.call(state.wallet == wallet - Farm.FEE and state.foraging_state()["stock"][Farm.IDS[0]] == 0 and state.departed_today(), "retirement refunds neither cash nor shared day")
	var restored: State = State.new()
	check.call(restored.load_from_dict(state.to_dict()) == "" and _json(restored) == _json(state), "retirement round trip")


func _legacy(data_dir: String) -> void:
	var state: State = ready()
	var old: Dictionary = state.to_dict()
	old.erase("foraging")
	old.erase("harbor_foraging")
	old.erase("chef_challenge")
	old.erase("mountain_foraging")
	old["schema_version"] = 10
	var store: Save = Save.new(data_dir.path_join("legacy10"))
	DirAccess.make_dir_recursive_absolute(store.dir)
	var text: String = JSON.stringify(old, "\t", true) + "\n"
	var file: FileAccess = FileAccess.open(store.main_path(), FileAccess.WRITE)
	check.call(file != null, "legacy fixture writable")
	if file == null:
		return
	file.store_string(text)
	file.close()
	var restored: State = State.new()
	check.call(store.load_into(restored)["status"] == "ok" and restored.foraging_state() == Farm.empty_state(), "v10 migrates without granting any samples")
	var migrated: Dictionary = restored.to_dict()
	migrated.erase("foraging")
	migrated.erase("harbor_foraging")
	migrated.erase("chef_challenge")
	migrated.erase("mountain_foraging")
	migrated["schema_version"] = 10
	check.call(migrated == old, "all existing v10 values preserved")
	check.call(store.save_state(restored)["ok"] and FileAccess.get_file_as_string(store.legacy_bak_path(10)) == text, "first v11 save preserves exact v10 original")
