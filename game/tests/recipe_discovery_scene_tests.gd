extends "res://tests/touch_scroll_tests.gd"
## Real scenes and disposable saves connect Claude's pure map to actual paid
## tasting. Pointer routing verifies journal cards preserve the accepted swipe.


func _page(app: Node, id: String) -> Dictionary:
	for page in app.call("_recipe_pages"):
		if page["id"] == id:
			return page
	return {}


func _run_profile(tag: String, vp: Vector2i, _scale: int) -> void:
	var holder := SubViewport.new()
	holder.size = vp
	holder.handle_input_locally = true
	holder.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(holder)
	var directory := _data_root.path_join(tag + "_discovery")
	_check(DirAccess.make_dir_recursive_absolute(directory) == OK, tag + ": isolated save")
	var app: Node = await _spawn(holder, directory)
	var state: Object = _state(app)
	_press(app, "DevButton")
	await _settle()
	_check(_text_of(app, "JournalTargetTitle") == "토핑 겹쌓기", tag + ": concrete first experiment")
	_check(not _page(app, "topping_stack")["tested"], tag + ": no invented discovery from draft")
	await _reachable(app, vp, "QuickTasteButton")
	_check(_scroll_of(_find(app, "QuickTasteButton")) == null, tag + ": taste action outside long ingredient scroll")
	_overflow(app, vp, tag + " workbench")
	await _shot(holder, tag + "_discovery_01_workbench.png")
	var before := JSON.stringify(state.call("to_dict"))
	_press(app, "JournalOpenBook")
	await _settle()
	_check(JSON.stringify(state.call("to_dict")) == before, tag + ": map is not a transaction")
	_check(_text_of(app, "JournalMapSummary").contains("0/8"), tag + ": eight untasted research directions")
	_overflow(app, vp, tag + " research map")
	await _shot(holder, tag + "_discovery_02_map.png")
	var scroll := _find(app, "TabNotebook") as ScrollContainer
	var button := _find(app, "JournalSelect_bone_depth") as Button
	scroll.ensure_control_visible(button)
	await _settle()
	var initial_scroll := scroll.scroll_vertical
	app.get("_juice").advance_effects(5.0)
	await _drag(holder, _visible_center(button, scroll), -72)
	_check(scroll.scroll_vertical > initial_scroll + 20, tag + ": journal button swipe scrolls")
	_check(app.get("_journal_target_id") == "topping_stack", tag + ": journal swipe does not choose a goal")
	_check(JSON.stringify(state.call("to_dict")) == before, tag + ": journal swipe preserves recipe and money")
	await _stop(holder, scroll)
	button = _find(app, "JournalSelect_citrus_light") as Button
	scroll.ensure_control_visible(button)
	await _settle()
	var point := _visible_center(button, scroll)
	_pointer(holder, point, true)
	_pointer(holder, point, false)
	await _settle()
	_check(app.get("_journal_target_id") == "citrus_light", tag + ": routed journal tap chooses exactly the intended target")
	_check(JSON.stringify(state.call("to_dict")) == before, tag + ": selecting a research goal never fills recipe or charges")
	_check(_text_of(app, "JournalSampleError").contains("유자"), tag + ": unavailable material explained")
	_press(app, "JournalFindMaterials")
	await _settle()
	_check((app.get("tabs") as TabContainer).current_tab == 6, tag + ": source button leads to real exploration")
	_check(JSON.stringify(state.call("to_dict")) == before, tag + ": source navigation never starts or pays for a trip")
	app.call("_on_tab_link", 0)
	await _settle()
	await _shot(holder, tag + "_discovery_03_material_goal.png")
	app.call("_select_recipe_target", "topping_stack")
	_press(app, "Opt_topping_chashu")
	await _settle()
	_check(_page(app, "topping_stack")["ready"] and not _page(app, "topping_stack")["tested"], tag + ": real repeat portion meets untasted target")
	_check(_text_of(app, "BowlCaption").contains("×2"), tag + ": identity reflects actual portions")
	var wallet: int = int(state.get("wallet"))
	var trial_cost: int = int(state.call("trial_cost"))
	_press(app, "QuickTasteButton")
	app.set_process(false)
	_check(app.call("work_active") and state.call("record_count") == 0 and state.get("wallet") == wallet, tag + ": fixed action starts preparation only")
	_check((_find(app, "JournalOpenBook") as Button).disabled, tag + ": journal locks during cooking")
	app.call("_select_recipe_target", "bone_depth")
	_check(app.get("_journal_target_id") == "topping_stack", tag + ": direct goal callback also guards busy")
	app.call("advance_work", 10.0)
	await _settle()
	_check(state.call("record_count") == 1 and state.get("wallet") == wallet - trial_cost, tag + ": exactly one real paid completion")
	_check(_page(app, "topping_stack")["tested"], tag + ": actual record enters research map")
	_check(_text_of(app, "NewRecipeThemes").contains("토핑 겹쌓기"), tag + ": result names actually newly recorded theme")
	_check(not (_find(app, "QuickTasteButton") as Control).is_visible_in_tree(), tag + ": tasting action hidden off workbench")
	await _shot(holder, tag + "_discovery_04_new_result.png")
	app.call("_on_tab_link", 0)
	await _settle()
	_press(app, "QuickTasteButton")
	await _settle()
	_check((_find(app, "QuickTasteNotice") as Control).is_visible_in_tree(), tag + ": duplicate refusal remains visible by fixed button")
	_check(not app.call("work_active") and state.call("record_count") == 1, tag + ": refused duplicate creates no work or record")
	var price: int = int(state.get("draft_config")["price"])
	state.call("set_draft_price", price + 100)
	app.call("_refresh_lab")
	_check(_text_of(app, "DraftComparison").contains("판매가 +100원") and _text_of(app, "DraftComparison").contains("맛 축 변화 없음"), tag + ": honest price-only comparison")
	_check(app.get("_journal_new_titles").size() > 0, tag + ": viewing comparison does not invent another result")
	var lab_scroll := _find(app, "TabLab") as ScrollContainer
	lab_scroll.ensure_control_visible(_find(app, "DraftComparison") as Control)
	await _settle()
	await _shot(holder, tag + "_discovery_05_comparison.png")
	_press(app, "QuickTasteButton")
	_check(app.call("cancel_work"), tag + ": new trial cancel")
	_check(state.call("record_count") == 1 and state.get("wallet") == wallet - trial_cost, tag + ": cancellation adds no record, money change or discovery")
	_press(app, "QuickTasteButton")
	app.call("advance_work", 10.0)
	await _settle()
	_check(state.call("record_count") == 2 and state.get("wallet") == wallet - 2 * trial_cost, tag + ": price revision completes through the ordinary transaction")
	_check(app.get("_journal_new_titles").is_empty() and _find(app, "NewRecipeThemes") == null, tag + ": price-only tasting does not invent another discovery")
	# The first result was saved by normal completion. Reload the real file;
	# target selection is intentionally transient, retained recipe evidence is not.
	app.queue_free()
	await _frames(3)
	app = await _spawn(holder, directory)
	state = _state(app)
	_check(state.call("record_count") == 2 and _page(app, "topping_stack")["tested"], tag + ": research projection survives actual disk restart")
	var id: int = int(state.get("last_feedback_record_id"))
	_check(state.call("delete_record", id)["ok"], tag + ": remove one of two retained witnesses")
	app.call("_refresh_all")
	_check(_page(app, "topping_stack")["tested"], tag + ": another matching record keeps research status")
	id = int(state.call("records")[0]["record_id"])
	_check(state.call("delete_record", id)["ok"], tag + ": remove final retained witness")
	app.call("_refresh_all")
	_check(not _page(app, "topping_stack")["tested"], tag + ": record cache invalidates after deletion")
	app.queue_free()
	await _frames(3)
	# The new fixed action and taller identity/result cards share the original
	# cooking lifecycle. Exercise cancel/restart/save-failure instead of treating
	# successful new-goal tasting as sufficient coverage of those boundaries.
	await _run_tasting_work(holder, tag, vp)
	# Exercise explicit malformed-data UI and the component's own busy guard,
	# independent of main.gd's transactional guards.
	var journal = load("res://scripts/ui/recipe_journal.gd").new()
	journal.mode = "map"
	holder.add_child(journal)
	journal.present([], "")
	_check(str(journal.find_child("JournalMapSummary", true, false).text).contains("받지 못"), tag + ": missing pages are an explicit error")
	var intents: Array[int] = [0]
	journal.target_selected.connect(func(_id: String): intents[0] += 1)
	var available: Array[String] = []
	var pure_pages: Array = load("res://scripts/domain/recipe_discovery.gd").pages([], IngredientCatalog.default_config(), available)
	journal.present(pure_pages, "bone_depth", true)
	(journal.find_child("JournalSelect_bone_depth", true, false) as Button).pressed.emit()
	_check(intents[0] == 0, tag + ": component itself rejects forced busy intent")
	journal.set_busy(false)
	(journal.find_child("JournalSelect_bone_depth", true, false) as Button).pressed.emit()
	_check(intents[0] == 1, tag + ": component resumes one intent after unlock")
	journal.queue_free()
	holder.queue_free()
	await _frames(3)
