extends "res://tests/ui_depth_feedback_tests.gd"
## Real routed gestures plus legitimate supplier/sampling/paid tasting APIs.
## No injected money, rank, ingredients, stock or invented tasting witnesses.
const DirectionTests = preload("res://tests/recipe_directions_tests.gd")
const DirectionRules = preload("res://scripts/domain/recipe_directions.gd")
const HarborFixture = preload("res://tests/harbor_foraging_tests.gd")


func _ok(result: Dictionary, label: String) -> void:
	_check(bool(result["ok"]), label + ": " + str(result.get("message", "")))


func _prepared() -> Object:
	var fixture := HarborFixture.new()
	fixture.check = _check
	var state: Object = fixture.ready()
	for choice in ["m_hear_recipe", "m_buy_pickle"]:
		_ok(state.call("start_expedition", "market"), "actual market supplier departure")
		_ok(state.call("advance_expedition", "m_ask"), "actual supplier meeting")
		_ok(state.call("advance_expedition", choice), "actual supplier choice")
		_ok(state.call("finish_expedition"), "actual discovery")
		_ok(state.call("serve"), "service opens next shared departure day")
	for choice in ["sesame_stall", "citrus_cart"]:
		_ok(state.call("start_foraging"), "actual market sampling")
		_ok(state.call("advance_expedition", choice), "actual market target")
		_ok(state.call("advance_expedition", "take_three"), "actual three samples")
		_ok(state.call("finish_expedition"), "claim actual market stock")
		_ok(state.call("serve"), "service before next sampling")
	for choice in ["sardine_boat", "scallop_diver"]:
		fixture.collect(state, choice)
		_ok(state.call("serve"), "actual service between harbor trips")
	return state


## Use the same editing operations available to a player. No recipe autofill
## feature is added to the game; this helper only scripts repeatable QA input.
func _compose(state: Object, id: String) -> void:
	var config: Dictionary = DirectionTests.witness(id)
	state.call("start_new_recipe")
	for slot in IngredientCatalog.SLOTS:
		if slot != IngredientCatalog.TOPPING_SLOT:
			_ok(state.call("set_draft_choice", slot, config[slot]), "real single choice")
	_ok(state.call("set_draft_toppings", config["toppings"]), "real mixed portions")
	for slot in ["broth", "noodle"]:
		_ok(state.call("set_draft_process", slot, config["process"][slot]), "real cooking method")
	_ok(state.call("set_draft_name", DirectionRules.find(id)["title"]), "real dish name")


func _run_profile(tag: String, vp: Vector2i, _scale: int) -> void:
	var holder := SubViewport.new()
	holder.size = vp
	holder.handle_input_locally = true
	holder.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(holder)
	var directory: String = _data_root.path_join(tag + "_workbench")
	_check(DirAccess.make_dir_recursive_absolute(directory) == OK, "isolated workbench data")
	var app: Node = await _spawn(holder, directory)
	app.call("_open_overlay", 0)
	await _settle()
	var nav: Node = _find(app, "NavigationMenu")
	_check(not nav.get("expanded"), "navigation begins compact")
	var preview := _find(app, "BowlPreview") as TextureRect
	_check(preview.texture.get_width() == 192, "larger actual dish texture")
	_check((_scroll_of(preview).get_global_rect()).encloses(preview.get_global_rect()), "food is visible initially without test scrolling")
	_overflow(app, vp, tag + " initial food-first lab")
	await _shot(holder, tag + "_workbench_01_food.png")
	var audio: Node = _find(app, "ActionAudio")
	var clicks: int = audio.call("count", "tap")
	var scroll := _find(app, "TabLab") as ScrollContainer
	await _drag(holder, preview.get_global_rect().get_center(), -72)
	_check(scroll.scroll_vertical > 20 and audio.call("count", "tap") == clicks, "dragging bowl scrolls, with no committed tap sound")
	await _stop(holder, scroll)
	await _tap_control(holder, nav.get("header_button"))
	_check(nav.get("expanded"), "whole navigation card opens")
	_check((_find(app, "TabLink_7") as Control).is_visible_in_tree(), "all eight real destinations remain accessible")
	await _shot(holder, tag + "_workbench_02_navigation.png")
	var before: String = _dict_str(app)
	await _tap_control(holder, _find(app, "AudioToggle"))
	_check(audio.get("muted") and _dict_str(app) == before, "mute changes no game state")
	clicks = audio.call("count", "tap")
	await _tap_control(holder, nav.get("header_button"))
	_check(audio.call("count", "tap") == clicks, "muted committed action is silent")
	await _tap_control(holder, nav.get("header_button"))
	await _tap_control(holder, _find(app, "AudioToggle"))
	_check(not audio.get("muted"), "actual toggle restores cues")
	await _tap_control(holder, _find(app, "TabLink_0"))
	_check(not nav.get("expanded"), "choosing current destination still collapses menu")

	var prepared: Object = _prepared()
	app.set("state", prepared)
	_check(app.call("_persist"), "legitimate farming fixture saved")
	app.call("_refresh_all")
	app.call("_open_overlay", 0)
	await _settle()
	var board: Node = _find(app, "RecipeDirections")
	await _tap_control(holder, board.get("header_button"))
	await _reachable(app, vp, "DirectionSelect_citrus_clear")
	_overflow(app, vp, tag + " direction choices")
	await _shot(holder, tag + "_workbench_03_directions.png")
	before = _dict_str(app)
	await _tap_control(holder, _find(app, "DirectionSelect_citrus_clear"))
	_check(app.get("_direction_target") == "citrus_clear" and _dict_str(app) == before, "direction selection does not autofill or spend")
	await _tap_control(holder, _find(app, "DirectionSources"))
	_check((app.get("tabs") as TabContainer).current_tab == 6 and _dict_str(app) == before, "source navigation never departs or spends")
	app.call("_open_overlay", 0)
	await _settle()
	await _shot(holder, tag + "_workbench_04_goal.png")
	for id in ["citrus_clear", "sesame_depth", "harbor_sea"]:
		_compose(prepared, id)
		app.call("_refresh_all")
		app.call("_select_direction", id)
		app.call("_open_overlay", 0)
		await _settle()
		_check(DirectionRules.assess(id, prepared.get("draft_config"))["matched"], "actual composed dish meets open direction")
		_check(not DirectionRules.tested_ids(prepared.call("records")).has(id), "untasted composition earns no completion")
		await _shot(holder, tag + "_workbench_05_" + id + ".png")
		var wallet: int = prepared.get("wallet")
		var count: int = prepared.call("record_count")
		var cost: int = prepared.call("trial_cost")
		before = _dict_str(app)
		await _tap_control(holder, _find(app, "QuickTasteButton"))
		app.set_process(false)
		_check(app.call("work_active") and _dict_str(app) == before, "work starts without spending or discovery")
		if id == "citrus_clear":
			await _shot(holder, tag + "_workbench_06_broth.png")
			app.call("advance_work", 2.0)
			await _settle()
			await _shot(holder, tag + "_workbench_07_noodle.png")
			app.call("_select_direction", "sesame_depth")
			_check(app.get("_direction_target") == id and _dict_str(app) == before, "forced callbacks respect work lock")
			_check(app.call("cancel_work"), "cancel actual work")
			_check(_dict_str(app) == before and not DirectionRules.tested_ids(prepared.call("records")).has(id), "cancellation spends and discovers nothing")
			await _tap_control(holder, _find(app, "QuickTasteButton"))
			app.call("advance_work", 3.7)
			await _settle()
			await _shot(holder, tag + "_workbench_08_plating.png")
		app.call("advance_work", 20.0)
		await _settle()
		_check(prepared.call("record_count") == count + 1 and prepared.get("wallet") == wallet - cost, "exactly one paid successful tasting")
		_check(DirectionRules.tested_ids(prepared.call("records")).has(id), "paid immutable record completes direction")
		_check(_text_of(app, "DirectionResult").contains("새로운 맛 발견"), "honest first-in-retained-record discovery")
		_check((_find(app, "FeedbackBowl") as Control).is_visible_in_tree(), "actual visible result, not shop screenshot")
		var receipt: Node = _find(app, "ResultRecipeDetails")
		_check(not receipt.get("expanded"), "long receipt is one deliberate depth below the result")
		_overflow(app, vp, tag + " actual direction result")
		await _shot(holder, tag + "_workbench_09_" + id + "_result.png")
		before = _dict_str(app)
		await _tap_control(holder, _find(app, "DirectionNextExperiment"))
		_check((app.get("tabs") as TabContainer).current_tab == 0 and board.get("expanded") and _dict_str(app) == before, "next experiment opens choices without modifying recipe or earning progress")
	_check(DirectionRules.tested_ids(prepared.call("records")).size() == 3, "all three directions have real witnesses")
	_check(audio.call("count", "discover") == 3 and audio.call("count", "broth") >= 3, "distinct accepted discovery and cooking cues")
	app.queue_free()
	await _frames(3)
	app = await _spawn(holder, directory)
	app.call("_open_overlay", 0)
	await _settle()
	_check(DirectionRules.tested_ids(_state(app).call("records")).size() == 3, "three actual witnesses restored from unchanged schema13")
	app.call("_open_overlay", 1)
	await _settle()
	_check(not _text_of(app, "DirectionResult").contains("새로운 맛 발견"), "reload does not fabricate another fresh discovery")
	await _shot(holder, tag + "_workbench_10_reloaded.png")
	app.queue_free()
	await _frames(3)
	holder.queue_free()
	await _frames(3)
