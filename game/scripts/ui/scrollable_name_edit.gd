extends LineEdit
## LineEdit consumes pointer presses even with MOUSE_FILTER_PASS. Vertical
## touch drags therefore need forwarding, while normal taps/text editing keep
## the native LineEdit behavior. Other content uses native ScrollContainer.

var scroll_target: ScrollContainer
var _tracking: bool = false
var _vertical_drag: bool = false
var _distance: Vector2 = Vector2.ZERO
var _initial_scroll: int = 0


func _gui_input(event: InputEvent) -> void:
	if scroll_target == null or not DisplayServer.is_touchscreen_available():
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_tracking = true
			_vertical_drag = false
			_distance = Vector2.ZERO
			_initial_scroll = scroll_target.scroll_vertical
		else:
			if _vertical_drag:
				accept_event()
				_scroll_finished()
			_tracking = false
	elif event is InputEventMouseMotion and _tracking:
		_distance += event.relative
		if not _vertical_drag and absf(_distance.y) > scroll_target.scroll_deadzone and absf(_distance.y) > absf(_distance.x):
			_vertical_drag = true
			# A vertical page swipe must neither select text nor leave its keyboard
			# covering the page. Horizontal text selection remains native.
			release_focus()
			deselect()
			DisplayServer.virtual_keyboard_hide()
			scroll_target.propagate_notification(Control.NOTIFICATION_SCROLL_BEGIN)
		if _vertical_drag:
			scroll_target.scroll_vertical = _initial_scroll - int(_distance.y)
			accept_event()


func _scroll_finished() -> void:
	_vertical_drag = false
	scroll_target.propagate_notification(Control.NOTIFICATION_SCROLL_END)


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and not is_visible_in_tree():
		if _vertical_drag and is_instance_valid(scroll_target):
			_scroll_finished()
		_tracking = false
