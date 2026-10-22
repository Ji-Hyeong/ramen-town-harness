extends "res://tests/ui_depth_feedback_tests.gd"
## Exercise the new real UI before the already accepted disclosure, swipe,
## discovery, tasting/cancellation/restart/save-failure scenarios. Isolated data.


func _run_profile(tag: String, vp: Vector2i, scale: int) -> void:
	var holder := SubViewport.new()
	holder.size = vp
	holder.handle_input_locally = true
	holder.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(holder)
	var directory: String = _data_root.path_join(tag + "_expression")
	_check(DirAccess.make_dir_recursive_absolute(directory) == OK, tag + ": isolated experiment save")
	var app: Node = await _spawn(holder, directory)
	var state: Object = _state(app)
	_press(app, "DevButton")
	await _settle()
	var before: String = JSON.stringify(state.call("to_dict"))
	_check(_find(app, "ExperimentCluesIntro") == null, tag + ": untasted draft has no result clues")
	var preview := _find(app, "BowlPreview") as TextureRect
	# Food-first iteration enlarges the same dynamic48px dish, not a fake art.
	_check(preview.texture.get_width() == 192, tag + ": actual lab uses detailed48px dish at integer scale")
	await _shot(holder, tag + "_expression_01_preview.png")
	_press(app, "QuickTasteButton")
	app.set_process(false)
	app.call("advance_work", 12.0)
	await _settle()
	_check(state.call("record_count") == 1, tag + ": real paid tasting creates the source record")
	var result_snapshot: String = JSON.stringify(state.call("to_dict"))
	_check(before != result_snapshot, tag + ": tasting is a real transaction, not a preview")
	var bowl := _find(app, "FeedbackBowl") as TextureRect
	_check(bowl.texture.get_width() == 192, tag + ": actual result uses new dish at integer scale")
	await _shot(holder, tag + "_expression_02_result.png")
	var card: Node = _find(app, "ExperimentClue_aroma")
	_check(card != null, tag + ": actual tasted dish gives an aroma alternative")
	var scroll := _find(app, "TabFeedback") as ScrollContainer
	var header := card.get("header_button") as Button
	scroll.ensure_control_visible(header)
	await _settle()
	var fx: Node = app.get("_juice")
	fx.call("clear_effects")
	var ack: int = fx.call("acknowledgement_count")
	await _drag(holder, _visible_center(header, scroll), -70)
	_check(not card.get("expanded") and fx.call("acknowledgement_count") == ack, tag + ": swiping experiment card does not expand or commit feedback")
	await _stop(holder, scroll)
	await _tap_control(holder, header)
	_check(card.get("expanded") and fx.call("acknowledgement_count") == ack + 1, tag + ": real tap opens dynamic experiment with one effect")
	_check(JSON.stringify(state.call("to_dict")) == result_snapshot, tag + ": reading alternatives changes no save state")
	var delta := _find(app, "ExperimentDelta_aroma") as Label
	_check(delta.text.contains("예상 변화") and delta.text.contains("원가") and delta.text.contains("준비"), tag + ": costs and time accompany flavor facts")
	scroll.ensure_control_visible(_find(app, "ExperimentPair_aroma"))
	await _settle()
	_overflow(app, vp, tag + " experiment comparisons")
	await _shot(holder, tag + "_expression_03_clue.png")
	# Preserve a genuinely edited draft, not merely an untouched saved recipe.
	state.call("set_draft_price", int(state.get("draft_config")["price"]) + 100)
	var edited: String = JSON.stringify(state.call("to_dict"))
	await _tap_control(holder, _find(app, "ExperimentGo_aroma"))
	_check((app.get("tabs") as TabContainer).current_tab == 0, tag + ": clue leads to existing lab")
	_check(JSON.stringify(state.call("to_dict")) == edited, tag + ": navigation preserves edited draft/money/records")
	await _shot(holder, tag + "_expression_04_choices.png")
	app.call("_refresh_lab")
	_press(app, "QuickTasteButton")
	_check(app.call("work_active"), tag + ": independent new tasting starts")
	app.call("_apply_work_lock")
	for button in app.get("_experiment_buttons"):
		_check(button.disabled, tag + ": existing experiment actions lock during work")
	var busy_state: String = JSON.stringify(state.call("to_dict"))
	app.call("_open_experiment_choices", "broth")
	_check(JSON.stringify(state.call("to_dict")) == busy_state, tag + ": forced callback cannot bypass busy guard")
	_check(app.call("cancel_work"), tag + ": cancel remains available")
	_check(state.call("record_count") == 1, tag + ": cancel never records predicted alternative")
	app.queue_free()
	await _frames(3)
	holder.queue_free()
	await _frames(3)
	await super._run_profile(tag, vp, scale)
