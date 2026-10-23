extends "res://tests/qa_capture.gd"
## Dedicated current-screen QA. Legacy hidden controls are never visual proof.
## Capture uses the real renderer; --layout-only omits images explicitly.
const CategoryRules = preload("res://scripts/ui/topping_categories.gd")
const GameProjection = preload("res://scripts/domain/game_state.gd")
const DetailsEvaluation = preload("res://scripts/domain/recipe_evaluator.gd")


func _initialize() -> void:
	Input.emulate_touch_from_mouse = true
	_check(FileAccess.get_file_as_string("res://assets/fonts/Pretendard-OFL.txt").contains("SIL OPEN FONT LICENSE Version 1.1"), "original UI font redistribution license ships in the actual pack")
	var black := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	black.fill(Color.BLACK)
	_check(not image_has_rendered_content(black), "nonblank guard rejects black output")
	black.fill(Color.GRAY)
	_check(not image_has_rendered_content(black), "nonblank guard rejects uniform gray output")
	# Three foreground pixels miss every old8x8 sample; still real nonblank data.
	black.set_pixel(0, 0, Color.RED)
	black.set_pixel(2, 0, Color.GREEN)
	black.set_pixel(4, 0, Color.BLUE)
	_check(image_has_rendered_content(black), "nonblank guard accepts sparse actual pixels between old grid samples")
	super._initialize()


func _assert_current_stage(editor: Control, label: String) -> void:
	var scene: Control = editor.get("_scene") as Control
	var summary: Control = editor.get("_summary") as Control
	var dish: Control = editor.get("_dish") as Control
	var slots: Control = editor.get("_slot_surface") as Control
	var base: Control = dish.get("_base") as Control
	_check(summary.size.x >= scene.size.x * 0.85, label + ": summaries fill final scene width from first presentation")
	# Check the actual laid-out content, not just a theme constant: a Button's
	# full-rect child can otherwise ignore its border/content margins entirely.
	for button in summary.get_children():
		var heading: Control = button.find_child("SummaryHeadingRow", true, false)
		var value: Control = button.find_child("SummaryValue", true, false)
		var inset: Rect2 = button.get_global_rect().grow_individual(-12, -10, -12, -10)
		_check(inset.encloses(heading.get_global_rect()), label + ": summary heading has real horizontal12/vertical10 breathing room")
		_check(inset.encloses(value.get_global_rect()), label + ": summary value stays inside padded content")
	_check(base.size.x >= 180 and base.size.y >= 120, label + ": actual base bowl has meaningful rendered dimensions")
	_check(base.size.x > base.size.y * 1.2, label + ": landscape bowl silhouette never collapses into a square")
	_check(scene.get_global_rect().encloses(slots.get_global_rect()), label + ": all portion controls fit the final scene after reflow")
	_check(slots.get_global_rect().encloses((editor.get("_slots") as Control).get_global_rect()) or not (editor.get("_slots") as Control).visible, label + ": portion grid remains within its surface")


func _point(holder: SubViewport, position: Vector2, down: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = position
	event.global_position = position
	event.button_index = MOUSE_BUTTON_LEFT
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
	event.pressed = down
	holder.push_input(event)


func _tap(holder: SubViewport, editor: Control, node_name: String) -> void:
	var button: Button = editor.find_child(node_name, true, false) as Button
	_check(button != null, "actual control exists: " + node_name)
	if button == null:
		return
	_check(button.is_visible_in_tree() and not button.disabled, "actual control usable: " + node_name)
	if not button.is_visible_in_tree() or button.disabled:
		return
	var ancestor: Node = button.get_parent()
	while ancestor != null and not ancestor is ScrollContainer:
		ancestor = ancestor.get_parent()
	if ancestor is ScrollContainer:
		(ancestor as ScrollContainer).ensure_control_visible(button)
		await _settle()
	_check(Rect2(Vector2.ZERO, Vector2(holder.size)).encloses(button.get_global_rect()), "actual control in viewport: " + node_name)
	var point: Vector2 = button.get_global_rect().get_center()
	_point(holder, point, true)
	_point(holder, point, false)
	await _settle()


func _drag_list(holder: SubViewport, point: Vector2) -> void:
	_point(holder, point, true)
	for step in 6:
		var motion := InputEventMouseMotion.new()
		motion.position = point + Vector2(0, -12)
		motion.global_position = motion.position
		motion.relative = Vector2(0, -12)
		motion.button_mask = MOUSE_BUTTON_MASK_LEFT
		holder.push_input(motion)
		point = motion.position
		await _frames(1)
	_point(holder, point, false)
	await _frames(2)


func _run_profile(tag: String, vp: Vector2i, _scale: int) -> void:
	var holder := SubViewport.new()
	holder.size = vp
	holder.handle_input_locally = true
	holder.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(holder)
	var dir: String = _data_root.path_join(tag + "_bowl_editor")
	_check(DirAccess.make_dir_recursive_absolute(dir) == OK, tag + ": isolated data dir")
	var app: Node = await _spawn(holder, dir)
	app.call("_on_dev_pressed")
	await _settle()
	var editor: Control = app.get("_bowl_editor") as Control
	var state: Object = app.get("state")
	_check(editor.visible and editor.is_visible_in_tree(), tag + ": current native editor visible")
	_check(not (app.get("_drawer_margin") as Control).visible, tag + ": legacy drawer not shown over editor")
	var scroll: ScrollContainer = editor.get("_scroll") as ScrollContainer
	var stage: Control = editor.get("_stage") as Control
	var taste: Button = editor.get("_taste") as Button
	_check(taste.get_global_rect().end.y <= vp.y, tag + ": fixed tasting action inside viewport")
	_check(scroll.size.y >= 120, tag + ": ingredient list has useful height")
	_check((editor.get("_wallet") as Label).size.y <= 48, tag + ": wallet never wraps into a vertical column")
	_check((editor.get("_broth_text") as Label).text.contains("간장"), tag + ": tare visible in broth summary")
	_check((editor.get("_noodle_text") as Label).text.contains("꼬들"), tag + ": cooking firmness visible in noodle summary")
	_assert_current_stage(editor, tag + " initial")
	for button in (editor.get("category_buttons") as Dictionary).values():
		_check(button.size.x >= 44 and button.size.y >= 44, tag + ": category minimum44 hit area")
	for button in (editor.get("detail_buttons") as Dictionary).values():
		_check(button.size.x >= 44 and button.size.y >= 44, tag + ": separate detail minimum44 hit area")
	await _shot(holder, tag + "_editor_01_initial.png")
	var before: String = JSON.stringify(state.call("to_dict"))
	await _tap(holder, editor, "Category_3")
	_check((editor.get("item_rows") as Dictionary).keys().size() == 2, tag + ": seafood includes nori and scallop only")
	_check((editor.get("add_buttons") as Dictionary)["topping_scallop"].disabled, tag + ": undiscovered scallop remains locked")
	_check(JSON.stringify(state.call("to_dict")) == before, tag + ": category changes no game state")
	await _shot(holder, tag + "_editor_02_category.png")
	await _tap(holder, editor, "EditorInfo_topping_scallop")
	_check(JSON.stringify(state.call("to_dict")) == before, tag + ": locked material detail is read-only")
	await _shot(holder, tag + "_editor_03_details.png")
	await _tap(holder, editor, "EditorDetailsBack")
	_check(str(editor.get("category")) == "해산물", tag + ": details return retains category")
	await _tap(holder, editor, "Category_0")
	scroll.scroll_vertical = 0
	await _settle()
	var fixed_stage: Rect2 = stage.get_global_rect()
	var fixed_taste: Rect2 = taste.get_global_rect()
	var add: Button = (editor.get("add_buttons") as Dictionary)["topping_chashu"]
	var effects: Object = app.get("_juice")
	effects.call("advance_effects", 5.0)
	var acknowledgements: int = int(effects.call("acknowledgement_count"))
	var bar: VScrollBar = scroll.get_v_scroll_bar()
	var available_scroll: float = maxf(0.0, bar.max_value - bar.page)
	await _drag_list(holder, add.get_global_rect().get_center())
	# Compact rows can make the entire desktop list fit. Require real scrolling
	# when content overflows, while retaining the same canceled-press checks below.
	if available_scroll > 2.0:
		_check(scroll.scroll_vertical > minf(20.0, available_scroll * 0.5), tag + ": swipe beginning on add button scrolls overflowing list")
	else:
		_check(scroll.scroll_vertical <= ceili(available_scroll), tag + ": fully visible list stays within its actual scroll range")
	_check(JSON.stringify(state.call("to_dict")) == before, tag + ": canceled swipe never adds or pays")
	_check(int(effects.call("acknowledgement_count")) == acknowledgements, tag + ": canceled swipe gives no committed tap")
	_check(stage.get_global_rect() == fixed_stage and taste.get_global_rect() == fixed_taste, tag + ": context and action stay fixed during list scroll")
	var stop: Vector2 = scroll.get_global_rect().position + Vector2(1, 10)
	_point(holder, stop, true)
	_point(holder, stop, false)
	scroll.scroll_vertical = 0
	await _settle()
	await _tap(holder, editor, "EditorAdd_topping_chashu")
	var config: Dictionary = state.get("draft_config")
	_check(IngredientCatalog.toppings_of(config).count("topping_chashu") == 2, tag + ": real tap adds repeated portion")
	_check(int(state.get("wallet")) == 30000, tag + ": editing does not pay trial fee")
	_check((editor.get("add_buttons") as Dictionary)["topping_egg"].disabled, tag + ": full two slots block accidental overflow")
	_assert_current_stage(editor, tag + " after notice")
	await _shot(holder, tag + "_editor_04_duplicate.png")
	await _tap(holder, editor, "EditorSlot_0")
	_check(not (editor.get("add_buttons") as Dictionary)["topping_egg"].disabled, tag + ": selecting occupied slot enables replacement")
	await _tap(holder, editor, "EditorAdd_topping_egg")
	config = state.get("draft_config")
	_check(IngredientCatalog.toppings_of(config).has("topping_egg") and IngredientCatalog.toppings_of(config).size() == 2, tag + ": replace preserves capacity")
	await _shot(holder, tag + "_editor_05_replace.png")
	await _tap(holder, editor, "EditorRemove_1")
	before = JSON.stringify(state.call("to_dict"))
	await _tap(holder, editor, "EditorRemove_0")
	_check(JSON.stringify(state.call("to_dict")) == before, tag + ": minimum one portion is enforced by real controller")
	await _tap(holder, editor, "EditorBroth")
	var group_scroll: ScrollContainer = (editor.get("_modal") as Control).find_child("DetailsScroll", true, false) as ScrollContainer
	var chicken: Control = (editor.get("_modal") as Control).find_child("EditorAdd_broth_chicken", true, false) as Control
	group_scroll.ensure_control_visible(chicken)
	await _settle()
	await _tap(holder, editor, "EditorAdd_broth_chicken")
	_check(str((state.get("draft_config") as Dictionary)["broth"]) == "broth_chicken", tag + ": broth editor uses existing guarded choice")
	var current_modal: Control = editor.get("_modal") as Control
	_check((current_modal.find_child("EditorAdd_broth_chicken", true, false) as Button).button_pressed, tag + ": chosen broth marked inside open dialog")
	_check(not (current_modal.find_child("EditorAdd_broth_tonkotsu", true, false) as Button).button_pressed, tag + ": old broth marker clears immediately")
	await _tap(holder, editor, "EditorAdd_broth_chicken")
	_check((current_modal.find_child("EditorAdd_broth_chicken", true, false) as Button).button_pressed, tag + ": repeated selection cannot visually deselect actual broth")
	await _shot(holder, tag + "_editor_06_broth_edit.png")
	await _tap(holder, editor, "EditorDetailsBack")
	# Freeze frame-time advancement only in QA so each genuine cooking state can
	# be photographed deterministically; production uses the unchanged time loop.
	app.set_process(false)
	await _tap(holder, editor, "EditorMenu")
	await _tap(holder, editor, "EditorDirections")
	_check(JSON.stringify(state.call("to_dict")).contains("broth_chicken"), tag + ": research direction browsing preserves current broth")
	await _shot(holder, tag + "_editor_06b_directions.png")
	await _tap(holder, editor, "EditorDetailsBack")
	await _tap(holder, editor, "EditorMenu")
	await _tap(holder, editor, "EditorRecipeSettings")
	var price: int = int((state.get("draft_config") as Dictionary)["price"])
	await _tap(holder, editor, "EditorPrice_100")
	_check(int((state.get("draft_config") as Dictionary)["price"]) == price + 100, tag + ": actual price action edits future draft price")
	var name_edit: LineEdit = (editor.get("_modal") as Control).find_child("EditorName", true, false) as LineEdit
	name_edit.text = "검증용 한 그릇"
	name_edit.text_changed.emit(name_edit.text)
	_check(str(state.get("draft_name")) == name_edit.text, tag + ": name field connected to validated draft")
	await _tap(holder, editor, "EditorDetailsBack")
	var wallet: int = int(state.get("wallet"))
	var count: int = int(state.call("record_count"))
	var fee: int = int(state.call("trial_cost"))
	await _tap(holder, editor, "EditorTaste")
	_check(bool(app.call("work_active")), tag + ": actual tasting action starts work")
	_check(int(state.get("wallet")) == wallet and int(state.call("record_count")) == count, tag + ": work start has no premature charge/record")
	app.call("advance_work", 0.6)
	app.call("_sync_bowl_editor")
	await _shot(holder, tag + "_editor_07_cooking.png")
	await _tap(holder, editor, "EditorCancel")
	_check(int(state.get("wallet")) == wallet and int(state.call("record_count")) == count, tag + ": cooking cancel preserves money and records")
	await _tap(holder, editor, "EditorTaste")
	app.call("advance_work", 100.0)
	app.call("_sync_bowl_editor")
	await _settle()
	_check(int(state.get("wallet")) == wallet - fee and int(state.call("record_count")) == count + 1, tag + ": complete work charges and records once")
	_check(not bool(app.call("advance_work", 100.0)), tag + ": completed work cannot pay twice")
	var customer: Control = editor.find_child("EditorCustomer_0", true, false) as Control
	_check(customer != null and scroll.get_global_rect().encloses(customer.get_global_rect()), tag + ": first customer reaction selection visible without scrolling")
	_assert_current_stage(editor, tag + " result")
	await _shot(holder, tag + "_editor_08_result.png")
	await _tap(holder, editor, "EditorCustomer_1")
	await _shot(holder, tag + "_editor_09_second_customer.png")
	before = JSON.stringify(state.call("to_dict"))
	await _tap(holder, editor, "EditorResultDetails")
	_check((editor.get("_modal") as Control).find_child("ComparisonPanel", true, false) != null, tag + ": real version comparison remains accessible")
	var actual_record: Dictionary = state.call("get_record", state.get("last_feedback_record_id"))
	var selected_customer: Dictionary = DetailsEvaluation.evaluate(actual_record["config"])["customers"][1]
	var detail_texts: Array[String] = []
	var customer_name: Control = (editor.get("_modal") as Control).find_child("EditorCustomerDetailName", true, false) as Control
	_check(customer_name != null and customer_name.size.x >= 100 and customer_name.size.y <= 80, tag + ": customer detail name remains readable beside portrait")
	for node in (editor.get("_modal") as Control).find_children("*", "Label", true, false):
		detail_texts.append(str((node as Label).text))
	for reason in selected_customer["reasons"]:
		_check(detail_texts.has(str(reason)), tag + ": all selected-customer reasons remain available in visible detail modal")
	_check(detail_texts.has(str(selected_customer["value_note"])), tag + ": selected customer's price reaction remains available")
	await _shot(holder, tag + "_editor_09b_comparison.png")
	var details_scroll: ScrollContainer = (editor.get("_modal") as Control).find_child("DetailsScroll", true, false) as ScrollContainer
	details_scroll.ensure_control_visible((editor.get("_modal") as Control).find_child("ComparisonPanel", true, false) as Control)
	await _settle()
	await _shot(holder, tag + "_editor_09d_numbers.png")
	await _tap(holder, editor, "EditorDetailsBack")
	await _tap(holder, editor, "EditorClues")
	_check(JSON.stringify(state.call("to_dict")) == before, tag + ": actual experiment clues are read-only")
	await _shot(holder, tag + "_editor_09c_clues.png")
	await _tap(holder, editor, "EditorDetailsBack")
	await _tap(holder, editor, "EditorDevelopAgain")
	# Explicit synthetic VIEW projection: no claim that this fresh player earned
	# rank3, no mutation of the real controller state and no fixture save to disk.
	var projection := GameProjection.new()
	projection.set("_rank", 3)
	var projected: Dictionary = projection.set_draft_toppings(["topping_chashu", "topping_egg", "topping_nori", "topping_sprouts"])
	_check(bool(projected["ok"]), tag + ": four-slot layout projection valid")
	var view_info: Dictionary = (editor.get("_info") as Dictionary).duplicate(true)
	view_info["selected"] = -1
	editor.call("present", projection, 0, view_info)
	await _settle()
	_check((editor.get("_slots") as GridContainer).get_child_count() == 4, tag + ": actual four-slot native layout")
	_assert_current_stage(editor, tag + " four-slot projection")
	if taste.get_global_rect().end.y > vp.y or scroll.size.y < 100:
		print("LAYOUT DIAGNOSTIC ", tag, " viewport=", vp, " taste=", taste.get_global_rect(), " scroll=", scroll.get_global_rect(), " stage=", stage.get_global_rect(), " notice=", (editor.get("_notice") as Label).get_global_rect())
	_check(taste.get_global_rect().end.y <= vp.y and scroll.size.y >= 100, tag + ": four slots retain action and usable list")
	await _shot(holder, tag + "_editor_10_rank3_layout_projection.png")
	app.call("_sync_bowl_editor")
	await _settle()
	# Returning to an old feature must remain reachable via current visible menu.
	await _tap(holder, editor, "EditorMenu")
	var menu_scroll: ScrollContainer = (editor.get("_modal") as Control).find_child("DetailsScroll", true, false) as ScrollContainer
	var route: Control = (editor.get("_modal") as Control).find_child("EditorRoute_2", true, false) as Control
	menu_scroll.ensure_control_visible(route)
	await _settle()
	await _tap(holder, editor, "EditorRoute_2")
	_check((app.get("tabs") as TabContainer).current_tab == 2 and not editor.visible, tag + ": notebook route reaches existing feature")
	app.queue_free()
	await _settle()
	await _run_editor_save_failure(holder, tag, dir + "_failedsave")
	holder.queue_free()
	await _settle()


func _run_editor_save_failure(holder: SubViewport, tag: String, dir: String) -> void:
	_check(DirAccess.make_dir_recursive_absolute(dir) == OK, tag + ": isolated save-failure dir")
	var app: Node = await _spawn(holder, dir)
	app.call("_on_dev_pressed")
	await _settle()
	app.set_process(false)
	var editor: Control = app.get("_bowl_editor") as Control
	var saver: SaveServiceScript = app.get("saver") as SaveServiceScript
	var state: Object = app.get("state")
	_check(DirAccess.make_dir_absolute(saver.tmp_path()) == OK, tag + ": create owned temporary-file collision")
	await _tap(holder, editor, "EditorTaste")
	app.call("advance_work", 100.0)
	app.call("_sync_bowl_editor")
	await _settle()
	_check(int(state.call("record_count")) == 1, tag + ": failed-save tasting exists in memory")
	_check((editor.get("_notice") as Label).text.contains("저장하지 못"), tag + ": failure visible in actual current screen")
	await _shot(holder, tag + "_editor_11_failed_save.png")
	_check(DirAccess.remove_absolute(saver.tmp_path()) == OK, tag + ": remove only owned empty collision dir")
	var saved: Dictionary = app.call("manual_save")
	_check(bool(saved["ok"]), tag + ": existing manual save recovers real file")
	app.queue_free()
	await _settle()
