extends Control
## Cosmetic, bounded effects in viewport coordinates. Never handles input or
## changes game state: only committed button actions call burst(). A canceled
## scroll gesture therefore cannot trigger a success animation or vibration.

const MAX_EFFECTS: int = 24
var _effects: Array[Dictionary] = []
var _press_sequence: int = 0
var _acknowledgements: int = 0
var _last_acknowledgement: Vector2 = Vector2.ZERO


## Observe each branch once, including controls added by journal/notebook
## rebuilds. Keeping ownership on the nodes avoids a growing list of dead UI.
func watch(branch: Node) -> void:
	if branch.has_meta("ramen_feedback_watcher"):
		var previous: Variant = branch.get_meta("ramen_feedback_watcher")
		if previous is WeakRef and previous.get_ref() == self:
			return
	branch.set_meta("ramen_feedback_watcher", weakref(self))
	branch.child_entered_tree.connect(watch)
	if branch is BaseButton:
		var button := branch as BaseButton
		button.button_down.connect(_remember_press.bind(button))
		button.button_up.connect(_release_press.bind(weakref(button)))
		button.pressed.connect(_acknowledge_button.bind(button))
	for child in branch.get_children():
		watch(child)


func is_bound(button: BaseButton) -> bool:
	if not button.has_meta("ramen_feedback_watcher"):
		return false
	var observer: Variant = button.get_meta("ramen_feedback_watcher")
	return observer is WeakRef and observer.get_ref() == self


func acknowledgement_count() -> int:
	return _acknowledgements


func last_acknowledgement_position() -> Vector2:
	return _last_acknowledgement


func _remember_press(button: BaseButton) -> void:
	_press_sequence += 1
	button.set_meta("ramen_feedback_press", {"serial": _press_sequence,
		"point": button.get_global_rect().get_center()})


func _release_press(reference: WeakRef) -> void:
	var button: BaseButton = reference.get_ref() as BaseButton
	if button == null:
		return
	var press: Dictionary = button.get_meta("ramen_feedback_press", {})
	# Godot can emit button_up when a business callback removes its own button,
	# before later pressed observers execute. Clear after signal delivery, and
	# never erase a newer press which began before this deferred cleanup runs.
	_forget_press.call_deferred(reference, int(press.get("serial", -1)))


func _forget_press(reference: WeakRef, serial: int) -> void:
	var button: BaseButton = reference.get_ref() as BaseButton
	if button != null:
		var press: Dictionary = button.get_meta("ramen_feedback_press", {})
		if int(press.get("serial", -1)) == serial:
			button.set_meta("ramen_feedback_press", {})


func _acknowledge_button(button: BaseButton) -> void:
	var press: Dictionary = button.get_meta("ramen_feedback_press", {})
	if press.is_empty() and (button.disabled or not button.is_inside_tree()):
		return
	# Real presses retain their original position even if their handler rebuilt
	# the list, changed tabs, or disabled the control. A canceled swipe never
	# emits pressed, so it produces no committed ring or acknowledgement.
	var point: Vector2
	if press.has("point"):
		point = press["point"]
	else:
		point = button.get_global_rect().get_center()
	button.set_meta("ramen_feedback_press", {})
	_acknowledgements += 1
	_last_acknowledgement = point
	if _effects.size() >= MAX_EFFECTS:
		_effects.pop_front()
	_effects.append({"kind": "tap", "point": point, "tint": Color(1.0, 0.76, 0.25),
		"age": 0.0, "duration": 0.30})
	queue_redraw()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	z_index = 100


func burst(point: Vector2, tint: Color, caption: String = "", icon: Texture2D = null, big: bool = false) -> void:
	if _effects.size() >= MAX_EFFECTS:
		_effects.pop_front()
	# Keep ingredient/result feedback inside the screen, including edge buttons.
	point.x = clampf(point.x, 24.0, maxf(24.0, size.x - 24.0))
	point.y = clampf(point.y, 70.0, maxf(70.0, size.y - 70.0))
	_effects.append({"point": point, "tint": tint, "caption": caption,
		"icon": icon, "big": big, "age": 0.0, "duration": 1.1 if caption != "" else 0.35})
	if big and OS.has_feature("ios"):
		Input.vibrate_handheld(18)
	queue_redraw()


func effect_count() -> int:
	return _effects.size()


func clear_effects() -> void:
	# Cooking/cancellation/result transitions must not leave an obsolete cue
	# floating over controls that now perform a different action.
	_effects.clear()
	queue_redraw()


func advance_effects(seconds: float) -> void:
	for effect in _effects:
		effect["age"] += maxf(0.0, seconds)
	_effects = _effects.filter(func(effect: Dictionary): return effect["age"] < effect["duration"])
	queue_redraw()


func _process(delta: float) -> void:
	if not _effects.is_empty():
		advance_effects(delta)


func _draw() -> void:
	var font := get_theme_font("font", "Label")
	for effect in _effects:
		var age: float = effect["age"]
		var t: float = age / float(effect["duration"])
		var point: Vector2 = effect["point"]
		var color: Color = effect["tint"]
		color.a = 1.0 - t
		if effect.get("kind", "burst") == "tap":
			# A quiet local ring acknowledges navigation, expansion and ordinary
			# actions. Larger semantic bursts still mean ingredient/result changes.
			var side: float = 14.0 + 30.0 * t
			draw_rect(Rect2(point - Vector2.ONE * side / 2.0, Vector2.ONE * side), color, false, 3.0)
			draw_circle(point, 3.0 * (1.0 - t), color)
			continue
		var big: bool = effect["big"]
		var radius: float = (64.0 if big else 28.0) * sin(minf(t * 2.0, 1.0) * PI * 0.5)
		# Square sparks suit the existing pixel-art language without covering
		# the entire shop in an opaque flash or shaking the touch targets.
		for i in (12 if big else 6):
			var angle := TAU * float(i) / (12.0 if big else 6.0)
			var offset := Vector2(cos(angle), sin(angle)) * radius
			offset.y += 22.0 * t * t
			var side: float = (5.0 if i % 2 == 0 else 3.0) * (1.0 - t)
			draw_rect(Rect2(point + offset, Vector2.ONE * side), color)
		var icon: Texture2D = effect["icon"]
		if icon != null:
			var side := 34.0 * (1.0 + 0.3 * sin(t * PI))
			draw_texture_rect(icon, Rect2(point + Vector2(-side / 2.0, -26.0 - t * 30.0), Vector2.ONE * side), false, Color(1, 1, 1, 1.0 - t))
		var caption: String = effect["caption"]
		if caption != "":
			var font_size: int = 18 if big else 15
			var width := minf(size.x - 24.0, font.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x + 20.0)
			var origin := Vector2(clampf(point.x - width / 2.0, 12.0, maxf(12.0, size.x - width - 12.0)), maxf(12.0, point.y - 62.0 - 16.0 * t))
			draw_rect(Rect2(origin, Vector2(width, 32)), Color(0.16, 0.10, 0.06, (1.0 - t) * 0.94))
			draw_string(font, origin + Vector2(10, 23), caption, HORIZONTAL_ALIGNMENT_LEFT, width - 20.0, font_size, Color(1.0, 0.9, 0.65, 1.0 - t))
