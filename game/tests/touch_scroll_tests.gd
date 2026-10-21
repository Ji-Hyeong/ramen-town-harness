extends "res://tests/qa_capture.gd"
## Route pointer events through the real viewport, not directly to a signal or
## scroll offset. iOS ScrollContainer consumes the mouse stream emulated from
## touch; emulate_touch_from_mouse also exposes this path on headless hosts.


func _initialize() -> void:
	Input.emulate_touch_from_mouse = true
	super._initialize()


func _pointer(holder: SubViewport, point: Vector2, down: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = point
	event.global_position = point
	event.button_index = MOUSE_BUTTON_LEFT
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
	event.pressed = down
	holder.push_input(event)


func _motion(holder: SubViewport, point: Vector2, delta: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = point
	event.global_position = point
	event.relative = delta
	event.button_mask = MOUSE_BUTTON_MASK_LEFT
	holder.push_input(event)


func _drag(holder: SubViewport, point: Vector2, distance: float) -> void:
	_pointer(holder, point, true)
	for step in 6:
		var delta := Vector2(0, distance / 6.0)
		point += delta
		_motion(holder, point, delta)
		await _frames(1)
	_pointer(holder, point, false)
	await _frames(2)


func _stop(holder: SubViewport, scroll: ScrollContainer) -> void:
	# A blank edge stops native inertia without activating any content action.
	var point := scroll.get_global_rect().position + Vector2(1, 10)
	_pointer(holder, point, true)
	_pointer(holder, point, false)
	await _frames(2)


func _visible_center(control: Control, scroll: ScrollContainer) -> Vector2:
	return control.get_global_rect().intersection(scroll.get_global_rect()).get_center()


func _run_profile(tag: String, vp: Vector2i, _scale: int) -> void:
	var holder := SubViewport.new()
	holder.size = vp
	holder.handle_input_locally = true
	root.add_child(holder)
	var data_dir := _data_root.path_join(tag + "_touch")
	_check(DirAccess.make_dir_recursive_absolute(data_dir) == OK, tag + ": fixture directory")
	var app: Node = await _spawn(holder, data_dir)
	_press(app, "DevButton")
	await _settle()
	var scroll := _find(app, "TabLab") as ScrollContainer
	var button := _find(app, "NewRecipeButton") as Button
	var clicks: Array[int] = [0]
	button.pressed.connect(func(): clicks[0] += 1)
	scroll.ensure_control_visible(button)
	await _settle()
	var button_start := scroll.scroll_vertical
	app.get("_juice").advance_effects(5.0)
	var before := JSON.stringify(_state(app).call("to_dict"))
	await _drag(holder, _visible_center(button, scroll), -72)
	_check(scroll.scroll_vertical > button_start + 20, tag + ": swipe starting on enabled button scrolls")
	_check(app.get("_juice").effect_count() == 0, tag + ": canceled swipe produces no click effects")
	_check(clicks[0] == 0, tag + ": swipe does not activate button")
	_check(JSON.stringify(_state(app).call("to_dict")) == before, tag + ": swipe never changes game state")
	await _stop(holder, scroll)
	scroll.ensure_control_visible(button)
	await _settle()
	var tap_start := scroll.scroll_vertical
	var point := _visible_center(button, scroll)
	_pointer(holder, point, true)
	_motion(holder, point + Vector2(0, -2), Vector2(0, -2))
	_pointer(holder, point + Vector2(0, -2), false)
	await _frames(2)
	_check(clicks[0] == 1, tag + ": small finger jitter is exactly one tap")
	_check(scroll.scroll_vertical == tap_start, tag + ": small finger jitter does not scroll")
	button.disabled = true
	var disabled_start := scroll.scroll_vertical
	await _drag(holder, _visible_center(button, scroll), -72)
	_check(scroll.scroll_vertical > disabled_start + 20, tag + ": disabled button also permits content swipe")
	_check(clicks[0] == 1, tag + ": disabled button never activates")
	await _stop(holder, scroll)
	button.disabled = false
	# Ingredient toggles use a separate factory from ordinary action buttons.
	var option: Button
	for candidate in app.get("_buttons").values():
		if candidate is Button and not candidate.disabled:
			option = candidate
			break
	_check(option != null, tag + ": ingredient fixture exists")
	if option != null:
		_reveal_control(option)
		await _settle()
		scroll.ensure_control_visible(option)
		await _settle()
		var initial_scroll := scroll.scroll_vertical
		var was_selected := option.button_pressed
		before = JSON.stringify(_state(app).call("to_dict"))
		await _drag(holder, _visible_center(option, scroll), -72)
		_check(scroll.scroll_vertical > initial_scroll + 20, tag + ": swipe on ingredient option scrolls")
		_check(option.button_pressed == was_selected, tag + ": ingredient swipe never toggles selection")
		_check(JSON.stringify(_state(app).call("to_dict")) == before, tag + ": ingredient swipe preserves recipe")
		await _stop(holder, scroll)
	scroll.scroll_vertical = 0
	await _settle()
	var picture := _find(app, "BowlPreview") as Control
	await _drag(holder, _visible_center(picture, scroll), -72)
	_check(scroll.scroll_vertical > 20, tag + ": swipe starting on bowl picture scrolls")
	await _stop(holder, scroll)
	scroll.scroll_vertical = 0
	await _settle()
	var edit := _find(app, "RecipeNameEdit") as LineEdit
	scroll.ensure_control_visible(edit)
	await _settle()
	var name_start := scroll.scroll_vertical
	before = JSON.stringify(_state(app).call("to_dict"))
	await _drag(holder, _visible_center(edit, scroll), -72)
	_check(scroll.scroll_vertical > name_start + 20, tag + ": vertical swipe starting on name field scrolls")
	_check(JSON.stringify(_state(app).call("to_dict")) == before, tag + ": name-field swipe changes no recipe data")
	await _stop(holder, scroll)
	# All tabs share the production factory, including dynamically built cards.
	for index in range(1, 8):
		app.call("_on_tab_link", index)
		await _settle()
		var current := (app.get("tabs") as TabContainer).get_child(index) as ScrollContainer
		_check(current.scroll_deadzone >= 8, tag + ": tap tolerance tab " + str(index))
	app.call("_on_tab_link", 4)
	await _settle()
	scroll = _find(app, "TabResearch") as ScrollContainer
	var summary := _find(app, "ResearchSummaryCard") as Control
	await _drag(holder, _visible_center(summary, scroll), -72)
	_check(scroll.scroll_vertical > 20, tag + ": swipe on card/text scrolls")
	await _stop(holder, scroll)
	var stopped := scroll.scroll_vertical
	await _frames(8)
	_check(scroll.scroll_vertical == stopped, tag + ": new touch stops inertia")
	scroll.scroll_vertical = 160
	await _settle()
	await _drag(holder, scroll.get_global_rect().position + Vector2(4, 90), 60)
	_check(scroll.scroll_vertical < 140, tag + ": reverse drag from content edge scrolls")
	await _stop(holder, scroll)
	var wheel := InputEventMouseButton.new()
	wheel.position = scroll.get_global_rect().get_center()
	wheel.global_position = wheel.position
	wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
	wheel.pressed = true
	var old_scroll := scroll.scroll_vertical
	holder.push_input(wheel)
	await _frames(2)
	_check(scroll.scroll_vertical > old_scroll, tag + ": desktop wheel preserved")
	holder.queue_free()
	await _frames(3)
	await _native_stream(tag, vp)


func _finger(point: Vector2, down: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = 0
	event.position = point
	event.pressed = down
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func _finger_drag(point: Vector2) -> void:
	_finger(point, true)
	for step in 6:
		point.y -= 12.0
		var event := InputEventScreenDrag.new()
		event.index = 0
		event.position = point
		event.relative = Vector2(0, -12)
		Input.parse_input_event(event)
		Input.flush_buffered_events()
		await _frames(1)
	_finger(point, false)
	await _frames(2)


func _native_stream(tag: String, vp: Vector2i) -> void:
	# Native touch goes through Input's real touch-to-mouse translation, so the
	# tests also cover duplicate activation/cancellation across both streams.
	root.size = vp
	var dir := _data_root.path_join(tag + "_native_touch")
	_check(DirAccess.make_dir_recursive_absolute(dir) == OK, tag + ": native fixture")
	var app: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	app.set("data_location", {"ok":true, "dir":dir, "is_dev":true, "error":""})
	root.add_child(app)
	await _settle()
	_press(app, "DevButton")
	await _settle()
	var scroll := _find(app, "TabLab") as ScrollContainer
	var button := _find(app, "NewRecipeButton") as Button
	var clicks: Array[int] = [0]
	button.pressed.connect(func(): clicks[0] += 1)
	scroll.ensure_control_visible(button)
	await _settle()
	var initial_scroll := scroll.scroll_vertical
	app.get("_juice").advance_effects(5.0)
	await _finger_drag(_visible_center(button, scroll))
	_check(scroll.scroll_vertical > initial_scroll + 20, tag + ": real touch stream scrolls from button")
	_check(app.get("_juice").effect_count() == 0, tag + ": native canceled swipe produces no effects")
	_check(clicks[0] == 0, tag + ": real touch drag never activates button")
	# Stop native inertia through the same original touch stream.
	var edge := scroll.get_global_rect().position + Vector2(1, 10)
	_finger(edge, true)
	_finger(edge, false)
	scroll.ensure_control_visible(button)
	await _settle()
	var point := _visible_center(button, scroll)
	_finger(point, true)
	_finger(point, false)
	await _frames(2)
	_check(clicks[0] == 1, tag + ": real touch tap activates exactly once")
	var edit := _find(app, "RecipeNameEdit") as LineEdit
	scroll.ensure_control_visible(edit)
	await _settle()
	initial_scroll = scroll.scroll_vertical
	await _finger_drag(_visible_center(edit, scroll))
	_check(scroll.scroll_vertical > initial_scroll + 20, tag + ": real touch stream scrolls from name field")
	scroll.ensure_control_visible(edit)
	await _settle()
	point = _visible_center(edit, scroll)
	_finger(point, true)
	_finger(point, false)
	await _frames(2)
	_check(edit.has_focus(), tag + ": normal name-field tap still focuses editor")
	var previous_text := edit.text
	edit.caret_column = edit.text.length()
	var key := InputEventKey.new()
	key.pressed = true
	key.unicode = 88
	Input.parse_input_event(key)
	Input.flush_buffered_events()
	await _frames(2)
	_check(edit.text == previous_text + "X", tag + ": focused name field still accepts text")
	app.queue_free()
	await _frames(3)
