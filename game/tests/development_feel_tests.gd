extends "res://tests/qa_capture.gd"
## Focused real-scene tests and render samples for the development workbench.
## Fixtures use disposable saves. Signals exercise semantic handlers here;
## touch_scroll_tests separately routes actual native touch/viewport events.


func _run_profile(tag: String, vp: Vector2i, _scale: int) -> void:
	var holder := SubViewport.new()
	holder.size = vp
	holder.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(holder)
	var directory := _data_root.path_join(tag + "_development")
	_check(DirAccess.make_dir_recursive_absolute(directory) == OK, tag + ": isolated fixture")
	var app: Node = await _spawn(holder, directory)
	var state = _state(app)
	_press(app, "DevButton")
	await _settle()
	var scroll := _find(app, "TabLab") as ScrollContainer
	_check(state.call("topping_slots") == 2, tag + ": starting rank has two positions")
	_check((_find(app, "ToppingSlot_2") as Button).disabled, tag + ": third position locked at rank1")
	_check(_text_of(app, "ToppingSlot_2").contains("등급 2"), tag + ": unlock rank shown")
	_overflow(app, vp, tag + " workbench")
	await _shot(holder, tag + "_feel_01_workbench.png")
	scroll.ensure_control_visible(_find(app, "Opt_topping_chashu") as Control)
	await _settle()
	_press(app, "Opt_topping_chashu")
	await _frames(2)
	_check(IngredientCatalog.toppings_of(state.get("draft_config")).count("topping_chashu") == 2, tag + ": same topping added as second portion")
	_check(_text_of(app, "Opt_topping_chashu").contains("×2"), tag + ": portion count visible")
	_check(app.get("_juice").effect_count() > 0, tag + ": committed addition creates visual feedback")
	await _shot(holder, tag + "_feel_02_ingredient_burst.png")
	var unchanged := JSON.stringify(state.call("to_dict"))
	_press(app, "Opt_topping_egg")
	_check(JSON.stringify(state.call("to_dict")) == unchanged, tag + ": full positions never silently replace")
	_press(app, "ToppingSlot_0")
	_press(app, "Opt_topping_egg")
	await _settle()
	var picked := IngredientCatalog.toppings_of(state.get("draft_config"))
	_check(picked.count("topping_chashu") == 1 and picked.count("topping_egg") == 1, tag + ": explicit selected-position replacement")
	_press(app, "RemoveTopping_0")
	await _settle()
	_check(IngredientCatalog.toppings_of(state.get("draft_config")).size() == 1, tag + ": remove exactly one portion")
	_press(app, "RemoveTopping_0")
	_check(IngredientCatalog.toppings_of(state.get("draft_config")).size() == 1, tag + ": last portion protected")
	_press(app, "Opt_topping_egg")
	await _settle()
	var profile: Dictionary = load("res://scripts/domain/recipe_evaluator.gd").build_profile(state.get("draft_config"))
	for axis in IngredientCatalog.AXES:
		_check((_find(app, "FlavorBar_" + axis) as ProgressBar).value == profile[axis], tag + ": actual flavor bar " + axis)
	scroll.scroll_vertical = 0
	await _settle()
	await _shot(holder, tag + "_feel_03_recipe_profile.png")
	var wallet: int = state.get("wallet")
	var count: int = state.call("record_count")
	var started: Dictionary = app.call("start_tasting")
	_check(started["ok"] and state.get("wallet") == wallet and state.call("record_count") == count, tag + ": cooking starts without charge")
	app.set_process(false)
	app.call("advance_work", 0.5)
	await _shot(holder, tag + "_feel_04_broth.png")
	app.call("advance_work", 1.8)
	await _shot(holder, tag + "_feel_05_noodles.png")
	app.call("advance_work", 10.0)
	await _frames(2)
	_check(state.call("record_count") == count + 1 and state.get("wallet") < wallet, tag + ": exactly one paid completion")
	_check(_find(app, "FeedbackBowl") != null, tag + ": result bowl lives on visible result tab")
	_check(app.get("_juice").effect_count() <= 1, tag + ": cooking cues never remain over the result screen")
	await _shot(holder, tag + "_feel_06_result_reveal.png")
	await create_timer(1.2).timeout
	_overflow(app, vp, tag + " result")
	await _shot(holder, tag + "_feel_07_result_settled.png")
	unchanged = JSON.stringify(state.call("to_dict"))
	app.get("_juice").advance_effects(10.0)
	_check(app.get("_juice").effect_count() == 0 and JSON.stringify(state.call("to_dict")) == unchanged, tag + ": effects expire without economic side effects")
	var saver = app.get("saver")
	_check(saver.save_state(state)["ok"], tag + ": repeated portions save")
	var restored = load("res://scripts/domain/game_state.gd").new()
	_check(saver.load_into(restored)["status"] == "ok" and JSON.stringify(restored.to_dict()) == unchanged, tag + ": repeated portions restart intact")
	# A second trial must reveal the actual result, even if the previous review
	# was scrolled down. Otherwise its celebratory bowl starts off screen.
	var feedback := _find(app, "TabFeedback") as ScrollContainer
	feedback.scroll_vertical = 180
	await _settle()
	app.call("_on_tab_link", 0)
	state.call("set_draft_price", 9500)
	_check(app.call("start_tasting")["ok"], tag + ": revised trial starts")
	app.call("advance_work", 10.0)
	await _settle()
	_check(feedback.scroll_vertical == 0, tag + ": repeated trial reveals result from top")
	app.queue_free()
	await _frames(3)
	# Reuse existing real-scene cancellation/restart/save-failure coverage for
	# the new deferred phase cues and effect cleanup at lifecycle boundaries.
	await _run_tasting_work(holder, tag, vp)
	holder.queue_free()
	await _frames(3)
