extends RefCounted
## Real game transactions, not injected stock/rank/wallet. This fixture is also
## shared by native scene QA so both acceptance paths use the same unlock.
const State = preload("res://scripts/domain/game_state.gd")
const Harbor = preload("res://scripts/domain/harbor_foraging.gd")
const Market = preload("res://scripts/domain/market_foraging.gd")
const Research = preload("res://scripts/domain/ramen_research.gd")
const Catalog = preload("res://scripts/domain/ingredient_catalog.gd")
const Eval = preload("res://scripts/domain/recipe_evaluator.gd")
const Art = preload("res://scripts/ui/pixel_art.gd")
const Save = preload("res://scripts/services/save_service.gd")
var check: Callable


func ok(result: Dictionary, message: String) -> bool:
	check.call(bool(result["ok"]), message + ": " + str(result.get("message", "")))
	return bool(result["ok"])


func json(state: State) -> String:
	return JSON.stringify(state.to_dict(), "", true)


func ready() -> State:
	var state := State.new()
	for key in ["hayoung_basic", "dohyun_basic"]:
		state.start_new_recipe()
		var cfg: Dictionary = Research.WITNESSES[key]
		for slot in Catalog.SLOTS:
			ok(state.set_draft_choice(slot, cfg[slot]), "promotion recipe")
		ok(state.set_draft_price(int(cfg["price"])), "promotion price")
		ok(state.set_draft_name("연구 " + key), "unique promotion recipe name")
		ok(state.taste(), "real initial tasting")
		if key == "hayoung_basic":
			ok(state.submit_research(key, state.selected_record_id), "real research")
	for i in 3:
		ok(state.serve(), "real service for promotion")
	ok(state.apply_promotion(2), "real rank 2 promotion")
	for choice in ["h_share_soup", "h_rent_tools"]:
		ok(state.start_expedition("harbor"), "original harbor supplier trip")
		ok(state.advance_expedition("h_boat"), "meet supplier")
		ok(state.advance_expedition(choice), "learn original ingredient")
		ok(state.finish_expedition(), "collect original supplier")
		check.call(not state.start_harbor_foraging()["ok"], "old trip consumes shared departure")
		ok(state.serve(), "service opens next travel day")
	check.call(state.harbor_foraging_review()["can_start"], "two harbor suppliers unlock repeat sampling")
	return state


func collect(state: State, branch: String, quantity: String = "clean_three") -> void:
	ok(state.start_harbor_foraging(), "harbor sampling departure")
	ok(state.advance_expedition(branch), "target ingredient")
	ok(state.advance_expedition(quantity), "explicit quantity choice")
	ok(state.finish_expedition(), "deliberate reward claim")


func run(callback: Callable, data_dir: String) -> void:
	check = callback
	var fresh := State.new()
	var before: String = json(fresh)
	check.call(not fresh.start_harbor_foraging()["ok"] and json(fresh) == before, "rank/supplier lock atomic")
	check.call(fresh.ingredient_lock_info(Harbor.IDS[0])["region"] == "harbor", "lock hint names correct sample source")
	var state: State = ready()
	if not state.harbor_foraging_review()["can_start"]:
		return
	var money: int = state.wallet
	ok(state.start_harbor_foraging(), "departure pays once")
	check.call(state.wallet == money - 1200, "exact departure fee")
	before = json(state)
	for result in [state.start_foraging(), state.start_harbor_foraging(), state.start_expedition("market"), state.taste(), state.begin_service(), state.advance_expedition("clean_three")]:
		check.call(not result["ok"] and json(state) == before, "busy/invalid transaction leaves complete state unchanged")
	for phase in 3:
		var store := Save.new(data_dir.path_join("phase%d" % phase))
		check.call(DirAccess.make_dir_recursive_absolute(store.dir) == OK, "isolated save directory")
		ok(store.save_state(state), "active stage saved")
		var restored := State.new()
		var loaded: Dictionary = store.load_into(restored)
		check.call(loaded["status"] == "ok" and json(restored) == json(state), "active stage round trip: " + str(loaded["message"]))
		state = restored
		if phase == 0:
			ok(state.advance_expedition("scallop_diver"), "choose scallop")
		elif phase == 1:
			ok(state.advance_expedition("clean_three"), "buy three scallops")
	check.call(state.sample_stock(Harbor.IDS[1]) == 0 and state.wallet == money - 1800, "waiting reward grants nothing, exact extra fee paid")
	ok(state.finish_expedition(), "claim three scallops")
	check.call(state.sample_stock(Harbor.IDS[1]) == 3, "exact claim")
	before = json(state)
	check.call(not state.finish_expedition()["ok"] and json(state) == before, "double claim atomic")
	ok(state.set_draft_toppings([Harbor.IDS[1], Harbor.IDS[1], Harbor.IDS[1]]), "rank2 supports triple repeated topping")
	var evaluation: Dictionary = Eval.evaluate(state.draft_config)
	var ordinary: Dictionary = Catalog.default_config()
	check.call(Art.recipe_bowl_image(state.draft_config).get_data() != Art.recipe_bowl_image(ordinary).get_data(), "actual detailed dish changes")
	check.call(Art.icon_image(Harbor.IDS[1]).get_size() == Vector2i(12, 12), "real scallop asset is logical12px")
	money = state.wallet
	var cost: int = state.trial_cost()
	ok(state.taste(), "triple scallop paid tasting")
	check.call(state.sample_stock(Harbor.IDS[1]) == 0 and state.harbor_foraging_state()["used"][Harbor.IDS[1]] == 3 and state.wallet == money - cost, "one sample per actual portion, exact cash")
	ok(state.set_draft_price(int(state.draft_config["price"]) + 100), "new trial variation")
	before = json(state)
	check.call(not state.taste()["ok"] and json(state) == before, "shortage consumes no money/ID/record")
	ok(state.serve(), "registered triple scallop sells at zero stock")
	check.call(state.harbor_foraging_state()["used"][Harbor.IDS[1]] == 3, "service consumes no research sample")
	collect(state, "sardine_boat", "take_one")
	ok(state.set_draft_choice("broth", Harbor.IDS[0]), "harbor broth")
	before = json(state)
	check.call(not state.taste()["ok"] and json(state) == before and state.sample_stock(Harbor.IDS[0]) == 1, "mixed stock shortage atomic across materials")
	ok(state.set_draft_toppings(["topping_nori"]), "remove unavailable scallops")
	var sardine: Dictionary = Eval.evaluate(state.draft_config)
	check.call(sardine["profile"] != evaluation["profile"] and sardine["unit_cost"] != evaluation["unit_cost"] and sardine["prep_seconds"] != evaluation["prep_seconds"], "harbor ingredients produce distinct flavor/cost/time")
	ok(state.taste(), "new broth trial")
	var restored := State.new()
	var error: String = restored.load_from_dict(JSON.parse_string(json(state)))
	check.call(error == "" and json(restored) == json(state), "sample recipes and historical proof round trip: " + error)
	_corruptions(state)
	_legacy(data_dir)
	_limits_and_retire()
	_cross_routes(state)
	_combined_samples(state)


func _corruptions(state: State) -> void:
	for kind in ["missing", "extra_key", "stock", "used", "date", "first", "amount", "path", "fee", "fraction", "negative", "stage", "type", "old_version"]:
		var raw: Dictionary = state.to_dict()
		var farm: Dictionary = raw["harbor_foraging"]
		match kind:
			"missing": raw.erase("harbor_foraging")
			"extra_key": farm["fake"] = 1
			"stock": farm["stock"][Harbor.IDS[0]] += 1
			"used":
				farm["used"][Harbor.IDS[1]] = 0
				farm["stock"][Harbor.IDS[1]] = farm["obtained"][Harbor.IDS[1]]
			"date": farm["history"][0]["day"] = 1
			"first": farm["first_day"][Harbor.IDS[1]] = 1
			"amount": farm["history"][0]["amount"] = 30
			"path": farm["history"][0]["path"] = ["scallop_diver", "take_three"]
			"fee": farm["history"][0]["extra"] = 0
			"fraction": farm["stock"][Harbor.IDS[0]] = 0.5
			"negative": farm["used"][Harbor.IDS[0]] = -1
			"stage": farm["active"] = {"stage": "fake"}
			"type": farm["completed"] = true
			"old_version":
				raw["schema_version"] = 12
				raw.erase("harbor_foraging")
				raw.erase("chef_challenge")
				raw.erase("mountain_foraging")
		var target := State.new()
		var before: String = json(target)
		check.call(target.load_from_dict(raw) != "" and json(target) == before, "forgery rejected atomically: " + kind)
	# A real ordinary revision retains the deleted sample recipe as its
	# comparison witness, even if it never beat any historical customer best.
	ok(state.set_draft_choice("broth", "broth_chicken"), "ordinary revision after sampled broth")
	ok(state.taste(), "real revision preserves preceding sample witness")
	var deleted: Dictionary = state.to_dict()
	deleted["records"] = [state.records().back()]
	deleted["selected_record_id"] = state.selected_record_id
	deleted["last_feedback_record_id"] = state.last_feedback_record_id
	deleted["draft"]["lineage_id"] = state.draft_lineage_id
	var target := State.new()
	check.call(target.load_from_dict(deleted) == "", "notebook cleanup retains valid sample proof")
	for id in Harbor.IDS:
		deleted["harbor_foraging"]["used"][id] = 0
		deleted["harbor_foraging"]["stock"][id] = deleted["harbor_foraging"]["obtained"][id]
	check.call(target.load_from_dict(deleted).contains("소비"), "deleted recipes cannot erase surviving sample consumption witness")


func _legacy(data_dir: String) -> void:
	var state: State = ready()
	var raw: Dictionary = state.to_dict()
	raw.erase("harbor_foraging")
	raw.erase("chef_challenge")
	raw.erase("mountain_foraging")
	raw["schema_version"] = 12
	var text: String = JSON.stringify(raw, "\t", true) + "\n"
	var store := Save.new(data_dir.path_join("legacy12"))
	check.call(DirAccess.make_dir_recursive_absolute(store.dir) == OK, "legacy isolated directory")
	var file := FileAccess.open(store.main_path(), FileAccess.WRITE)
	check.call(file != null, "legacy fixture writable")
	if file == null:
		return
	file.store_string(text)
	file.close()
	var migrated := State.new()
	check.call(store.load_into(migrated)["status"] == "ok" and migrated.harbor_foraging_state() == Harbor.empty_state(), "v12 migration grants no samples")
	var compared: Dictionary = migrated.to_dict()
	compared.erase("harbor_foraging")
	compared.erase("chef_challenge")
	compared.erase("mountain_foraging")
	compared["schema_version"] = 12
	check.call(compared == raw, "all old values preserved exactly")
	ok(store.save_state(migrated), "first v13 write")
	check.call(FileAccess.get_file_as_string(store.legacy_bak_path(12)) == text, "exact original v12 bytes backed up")
	ok(store.save_state(migrated), "second v13 write")
	check.call(FileAccess.get_file_as_string(store.legacy_bak_path(12)) == text, "legacy backup never overwritten")


func _limits_and_retire() -> void:
	var farm: Dictionary = Harbor.empty_state()
	var before: String = JSON.stringify(farm)
	check.call(Harbor.begin(farm, 1, 1199)["error"] != "" and JSON.stringify(farm) == before, "pure fee refusal atomic")
	for day in range(1, 21):
		farm = Harbor.begin(farm, day, 10000)["state"]
		farm = Harbor.choose(farm, "scallop_diver", 10000)["state"]
		farm = Harbor.choose(farm, "take_one", 10000)["state"]
		farm = Harbor.finish(farm)["state"]
	check.call(farm["stock"][Harbor.IDS[1]] == 20 and farm["history"].size() == 12, "capacity and bounded history")
	check.call(Harbor.parse(farm, 20, 1)["error"] == "", "trimmed history remains valid")
	farm = Harbor.begin(farm, 21, 10000)["state"]
	before = JSON.stringify(farm)
	check.call(Harbor.choose(farm, "scallop_diver", 10000)["error"] != "" and JSON.stringify(farm) == before, "full chosen material refused without payment")
	farm = Harbor.choose(farm, "sardine_boat", 10000)["state"]
	before = JSON.stringify(farm)
	check.call(Harbor.choose(farm, "clean_three", 599)["error"] != "" and JSON.stringify(farm) == before, "extra money shortage atomic")
	check.call(Harbor.finish(farm)["error"] != "", "claim before result refused")
	farm = Harbor.finish(farm, true)["state"]
	check.call(farm["retired"] == 1 and farm["stock"][Harbor.IDS[0]] == 0 and farm["last_departure_day"] == 21, "retirement keeps spent day and no reward")
	check.call(Harbor.parse(farm, 21, 1)["error"] == "", "retired trimmed ledger valid")


func _cross_routes(state: State) -> void:
	# An individually valid market receipt on a harbor receipt's day must not
	# pass the combined calendar, even with plausible lifetime counters.
	var raw: Dictionary = state.to_dict()
	var on_day: int = int(raw["harbor_foraging"]["history"][0]["day"])
	var market: Dictionary = Market.begin(Market.empty_state(), on_day, 100000)["state"]
	market = Market.choose(market, "sesame_stall", 100000)["state"]
	market = Market.choose(market, "take_two", 100000)["state"]
	market = Market.finish(market)["state"]
	check.call(Market.parse(market, state.day, state.next_record_id, 4)["error"] == "", "calendar negative fixture individually valid")
	check.call(State._sample_calendar_error([raw["exploration"], market, raw["harbor_foraging"]]) != "", "two sampling routes cannot overlap calendar days")


func _combined_samples(state: State) -> void:
	ok(state.serve(), "open new day for combined sampling")
	collect(state, "scallop_diver")
	ok(state.serve(), "next day after scallops")
	for choice in ["m_hear_recipe", "m_buy_pickle"]:
		ok(state.start_expedition("market"), "real market supplier after harbor")
		ok(state.advance_expedition("m_ask"), "market supplier first choice")
		ok(state.advance_expedition(choice), "market supplier second choice")
		ok(state.finish_expedition(), "market supplier claim")
		ok(state.serve(), "shared day advances after market supplier")
	ok(state.start_foraging(), "real market sampling after harbor")
	check.call(not state.start_harbor_foraging()["ok"], "market active blocks harbor")
	ok(state.advance_expedition("sesame_stall"), "sesame target")
	ok(state.advance_expedition("take_two"), "sesame quantity")
	ok(state.finish_expedition(), "sesame collected")
	check.call(not state.start_harbor_foraging()["ok"], "market claimed trip blocks harbor same day")
	ok(state.set_draft_choice("oil", Market.IDS[0]), "market sample selected")
	ok(state.set_draft_choice("broth", Harbor.IDS[0]), "known but empty harbor sample selected")
	ok(state.set_draft_toppings([Harbor.IDS[1], Harbor.IDS[1], Harbor.IDS[1]]), "three available scallops")
	var before: String = json(state)
	check.call(not state.taste()["ok"] and json(state) == before and state.sample_stock(Market.IDS[0]) == 2 and state.sample_stock(Harbor.IDS[1]) == 3, "later harbor shortage cannot commit earlier market consumption")
	ok(state.set_draft_choice("broth", "broth_chicken"), "remove empty broth")
	ok(state.taste(), "real combined market/harbor trial")
	check.call(state.sample_stock(Market.IDS[0]) == 1 and state.sample_stock(Harbor.IDS[1]) == 0, "two independent ledgers commit exact portions together")
	var restored := State.new()
	var error: String = restored.load_from_dict(state.to_dict())
	check.call(error == "" and json(restored) == json(state), "actual three-route calendar/combined recipe round trip: " + error)
