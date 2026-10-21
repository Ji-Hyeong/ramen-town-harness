extends "res://tests/recipe_discovery_scene_tests.gd"
## Exercise the visual affordance itself with routed pointer input, then reuse
## the existing discovery/tasting lifecycle. All saves remain isolated fixtures.


func _tap_control(holder: SubViewport, control: Control) -> Vector2:
	await _settle()
	var scroll := _scroll_of(control)
	if scroll != null:
		scroll.ensure_control_visible(control)
		await _settle()
	var point := control.get_global_rect().get_center()
	_pointer(holder, point, true)
	await _frames(1)
	_pointer(holder, point, false)
	await _settle()
	return point


func _run_profile(tag: String, vp: Vector2i, scale: int) -> void:
	var holder := SubViewport.new()
	holder.size = vp
	holder.handle_input_locally = true
	holder.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(holder)
	var directory := _data_root.path_join(tag + "_depth")
	_check(DirAccess.make_dir_recursive_absolute(directory) == OK, tag + ": isolated depth fixture")
	var app: Node = await _spawn(holder, directory)
	_press(app, "DevButton")
	await _settle()
	var state: Object = _state(app)
	var fx: Node = app.get("_juice")
	var before := JSON.stringify(state.call("to_dict"))
	for slot in IngredientCatalog.SLOTS:
		var card: Node = _find(app, "Section_" + slot)
		_check(not bool(card.get("expanded")), tag + ": ingredient starts summarized " + slot)
		_check(not (card.get("body") as Control).is_visible_in_tree(), tag + ": hidden choices use a deliberate depth " + slot)
		_check(fx.call("is_bound", card.get("header_button")), tag + ": detail action has shared feedback " + slot)
		_check((card.get("icon_rect") as TextureRect).texture != null, tag + ": current ingredient icon visible " + slot)
	for button in app.find_children("*", "BaseButton", true, false):
		_check(fx.call("is_bound", button), tag + ": all current action buttons observed " + str(button.name))
	_overflow(app, vp, tag + " compact initial")
	_check((_find(app, "JournalTargetCount") as Label).get_line_count() == 1, tag + ": goal count does not stack vertically beside its bar")
	await _shot(holder, tag + "_depth_01_summary.png")
	var scroll := _find(app, "TabLab") as ScrollContainer
	var broth: Node = _find(app, "Section_broth")
	var header := broth.get("header_button") as Button
	scroll.ensure_control_visible(header)
	await _settle()
	fx.call("clear_effects")
	var ack: int = fx.call("acknowledgement_count")
	var initial_scroll := scroll.scroll_vertical
	await _drag(holder, _visible_center(header, scroll), -72)
	_check(scroll.scroll_vertical > initial_scroll + 20, tag + ": whole detail header passes a swipe")
	_check(not broth.get("expanded") and fx.call("acknowledgement_count") == ack, tag + ": canceled detail swipe neither expands nor acknowledges a click")
	_check(fx.call("effect_count") == 0, tag + ": canceled detail swipe has no click effect")
	await _stop(holder, scroll)
	scroll.ensure_control_visible(header)
	await _settle()
	var rect := header.get_global_rect()
	_pointer(holder, rect.get_center(), true)
	await _frames(1)
	_check(header.get_draw_mode() in [BaseButton.DRAW_PRESSED, BaseButton.DRAW_HOVER_PRESSED], tag + ": immediate held-down visual state")
	_check(header.get_global_rect() == rect and not broth.get("expanded"), tag + ": press never moves hit target or opens before release")
	_check(fx.call("effect_count") == 0, tag + ": held press is not yet a committed click")
	await _shot(holder, tag + "_depth_02_pressed.png")
	_pointer(holder, rect.get_center(), false)
	await _settle()
	_check(broth.get("expanded") and fx.call("acknowledgement_count") == ack + 1, tag + ": detail release opens and acknowledges exactly once")
	_check(JSON.stringify(state.call("to_dict")) == before, tag + ": detail changes no recipe or money")
	_overflow(app, vp, tag + " broth details")
	await _shot(holder, tag + "_depth_03_ingredient.png")
	var flavor: Node = _find(app, "ExperimentCard")
	# Tap the drawn arrow, not a text label; ignored decoration must pass it to
	# the same whole-card hit target underneath.
	var arrow := flavor.get("chevron") as Control
	ack = fx.call("acknowledgement_count")
	await _tap_control(holder, arrow)
	_check(flavor.get("expanded") and fx.call("acknowledgement_count") == ack + 1, tag + ": drawn arrow is a usable detail affordance")
	_check((_find(app, "FlavorBar_rich") as Control).is_visible_in_tree(), tag + ": full flavor bars live in detail")
	_overflow(app, vp, tag + " flavor detail")
	await _shot(holder, tag + "_depth_04_flavor.png")
	await _tap_control(holder, _find(app, "JournalOpenBook") as Control)
	await _settle()
	var theme: Node = _find(app, "JournalTheme_topping_stack")
	_check(not theme.get("expanded"), tag + ": map begins as compact cards")
	ack = fx.call("acknowledgement_count")
	await _tap_control(holder, theme.get("header_button") as Control)
	_check(theme.get("expanded") and fx.call("acknowledgement_count") == ack + 1, tag + ": dynamic journal header gets exactly one acknowledgement")
	_check(JSON.stringify(state.call("to_dict")) == before, tag + ": reading research details never selects or pays")
	_check((_find(app, "JournalCount_topping_stack") as Label).get_line_count() == 1, tag + ": map count stays on one line")
	_overflow(app, vp, tag + " journal detail")
	await _shot(holder, tag + "_depth_05_map_detail.png")
	ack = fx.call("acknowledgement_count")
	var point: Vector2 = await _tap_control(holder, _find(app, "JournalSelect_topping_stack") as Control)
	_check(fx.call("acknowledgement_count") == ack + 1, tag + ": rebuilt journal action still acknowledges once")
	_check((fx.call("last_acknowledgement_position") as Vector2).distance_to(point) < 1.0, tag + ": rebuilt action effect retains original press position")
	_check(JSON.stringify(state.call("to_dict")) == before, tag + ": choosing a target changes no gameplay state")
	app.queue_free()
	await _frames(3)
	holder.queue_free()
	await _frames(3)
	await _native_acknowledgement(tag, vp)
	await super._run_profile(tag, vp, scale)


func _native_acknowledgement(tag: String, vp: Vector2i) -> void:
	# Actual native touch must survive business callbacks that disable or remove
	# their own button before the later universal feedback observer runs.
	root.size = vp
	var branch := Control.new()
	branch.size = Vector2(vp)
	root.add_child(branch)
	var fx = load("res://scripts/ui/action_feedback.gd").new()
	branch.add_child(fx)
	var button := Button.new()
	button.text = "confirm"
	button.position = Vector2(24, 80)
	button.size = Vector2(200, 56)
	button.pressed.connect(func(): button.disabled = true)
	branch.add_child(button)
	fx.watch(branch)
	fx.watch(branch)
	await _settle()
	_finger(button.get_global_rect().get_center(), true)
	_finger(button.get_global_rect().get_center(), false)
	await _frames(2)
	_check(fx.acknowledgement_count() == 1 and button.disabled, tag + ": native touch acknowledges once even after handler disables button")
	var removed := Button.new()
	removed.text = "dynamic"
	removed.position = Vector2(24, 160)
	removed.size = Vector2(200, 56)
	removed.pressed.connect(func():
		branch.remove_child(removed)
		removed.queue_free())
	branch.add_child(removed)
	await _settle()
	var point := removed.get_global_rect().get_center()
	_finger(point, true)
	_finger(point, false)
	await _frames(2)
	_check(fx.acknowledgement_count() == 2 and fx.last_acknowledgement_position().distance_to(point) < 1.0, tag + ": new native action acknowledges from original position after removal")
	fx.clear_effects()
	_finger(button.get_global_rect().get_center(), true)
	_finger(button.get_global_rect().get_center(), false)
	await _frames(2)
	_check(fx.acknowledgement_count() == 2 and fx.effect_count() == 0, tag + ": disabled native action creates no click effect")
	branch.queue_free()
	await _frames(3)
