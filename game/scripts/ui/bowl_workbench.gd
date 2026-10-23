extends Control
## 그릇 중심의 네이티브 편집 화면. 모든 거래는 action_requested를 받아 기존
## 루트 컨트롤러가 처리한다. 이 노드는 분류·상세·스크롤 같은 보기 상태만 소유한다.
signal action_requested(kind: String, data: Dictionary)
const Catalog = preload("res://scripts/domain/ingredient_catalog.gd")
const Evaluator = preload("res://scripts/domain/recipe_evaluator.gd")
const Game = preload("res://scripts/domain/game_state.gd")
const ProcessRules = preload("res://scripts/domain/recipe_process.gd")
const Categories = preload("res://scripts/ui/topping_categories.gd")
const Art = preload("res://scripts/ui/bowl_editor_art.gd")
const Dish = preload("res://scripts/ui/layered_recipe_view.gd")
const PixelArt = preload("res://scripts/ui/pixel_art.gd")
const NameEdit = preload("res://scripts/ui/scrollable_name_edit.gd")
const Directions = preload("res://scripts/domain/recipe_directions.gd")
const Experiments = preload("res://scripts/domain/recipe_experiments.gd")
const Check = preload("res://scripts/domain/data_check.gd")
const DisplayFont = preload("res://assets/fonts/Galmuri11-Bold.ttf")
const INK := Color("18354f")
const NAVY := Color("193e65")
const CREAM := Color("fff6e4")
const WHITE := Color("fffdf5")
const TEAL := Color("087e80")
const GOLD := Color("ffd05a")
const RED := Color("aa3828")
const MUTED := Color("685c50")
var state: Game
var category: String = "전체"
var scroll_positions: Dictionary = {}
var item_rows: Dictionary = {}
var add_buttons: Dictionary = {}
var detail_buttons: Dictionary = {}
var category_buttons: Dictionary = {}
var _mode: int = 0
var _selected: int = -1
var _info: Dictionary = {}
var _last_key: String = ""
var _modal: Control
var _root_margin: MarginContainer
var _column: VBoxContainer
var _content: GridContainer
var _stage: PanelContainer
var _scene: Control
var _dish: Dish
var _summary: HBoxContainer
var _broth: Button
var _noodle: Button
var _broth_text: Label
var _noodle_text: Label
var _slot_box: VBoxContainer
var _slot_surface: PanelContainer
var _slots: GridContainer
var _slot_title: Label
var _picker: VBoxContainer
var _heading: Label
var _heading_hint: Label
var _filters: HBoxContainer
var _scroll: ScrollContainer
var _rows: VBoxContainer
var _wallet: Label
var _notice: Label
var _cost: Label
var _taste: Button
var _back: Button
var _progress: ProgressBar
var _work_title: Label
var _work_box: VBoxContainer
var _result_customer: int = 0
var _group_scroll: Dictionary = {}


func _ready() -> void:
	name = "BowlWorkbench"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()
	resized.connect(_layout)
	_layout()


static func won(value: int) -> String:
	var digits: String = str(absi(value))
	var result: String = ""
	for i in digits.length():
		if i > 0 and (digits.length() - i) % 3 == 0:
			result += ","
		result += digits[i]
	return ("-" if value < 0 else "") + result + "원"


func _style(bg: Color, border: Color = INK) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(3)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 5
	style.content_margin_bottom = 5
	return style


func _label(text: String, font_size: int = 16, color: Color = INK) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	if font_size >= 18:
		label.add_theme_font_override("font", DisplayFont)
	return label


func _button(text: String, node_name: String, icon_name: String = "", bg: Color = CREAM) -> Button:
	var button := Button.new()
	button.name = node_name
	button.text = text
	button.custom_minimum_size = Vector2(48, 48)
	button.mouse_filter = Control.MOUSE_FILTER_PASS
	button.add_theme_font_size_override("font_size", 16)
	button.add_theme_font_override("font", DisplayFont)
	button.add_theme_stylebox_override("normal", _style(bg))
	button.add_theme_stylebox_override("hover", _style(bg.lightened(0.10), TEAL))
	button.add_theme_stylebox_override("pressed", _style(TEAL, NAVY))
	button.add_theme_stylebox_override("disabled", _style(Color("e0d9c9"), MUTED))
	button.add_theme_stylebox_override("focus", _style(Color(1, 1, 1, 0), TEAL))
	for property in ["font_color", "font_hover_color", "icon_normal_color", "icon_hover_color"]:
		button.add_theme_color_override(property, INK)
	for property in ["font_pressed_color", "icon_pressed_color"]:
		button.add_theme_color_override(property, Color.WHITE)
	button.add_theme_constant_override("icon_max_width", 26)
	if icon_name != "":
		button.icon = Art.icon(icon_name)
		button.expand_icon = true
	return button


func _picture(texture: Texture2D, minimum: Vector2) -> TextureRect:
	var picture := TextureRect.new()
	picture.texture = texture
	picture.custom_minimum_size = minimum
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	picture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return picture


func _emit(kind: String, data: Dictionary = {}) -> void:
	action_requested.emit(kind, data)


func _clear(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()


func _build() -> void:
	var surface := Panel.new()
	surface.add_theme_stylebox_override("panel", _style(NAVY, NAVY))
	surface.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	surface.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(surface)
	_root_margin = MarginContainer.new()
	_root_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_root_margin)
	_column = VBoxContainer.new()
	_column.add_theme_constant_override("separation", 5)
	_root_margin.add_child(_column)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 5)
	_column.add_child(header)
	_back = _button("", "EditorBack", "arrow_back")
	_back.tooltip_text = "가게로 돌아가기"
	_back.pressed.connect(func(): _emit("close"))
	header.add_child(_back)
	var title := _label("메뉴 개발", 24, CREAM)
	title.name = "EditorTitle"
	title.autowrap_mode = TextServer.AUTOWRAP_OFF
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header.add_child(title)
	_wallet = _label("", 15, CREAM)
	_wallet.name = "EditorWallet"
	_wallet.autowrap_mode = TextServer.AUTOWRAP_OFF
	_wallet.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header.add_child(_wallet)
	var menu := _button("", "EditorMenu", "menu")
	menu.tooltip_text = "이름·판매가와 다른 작업"
	menu.pressed.connect(_show_menu)
	header.add_child(menu)
	_notice = _label("", 14, GOLD)
	_notice.name = "EditorNotice"
	_column.add_child(_notice)
	_content = GridContainer.new()
	_content.add_theme_constant_override("h_separation", 10)
	_content.add_theme_constant_override("v_separation", 4)
	_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_column.add_child(_content)
	_build_stage()
	_build_picker()
	var footer := PanelContainer.new()
	footer.name = "EditorFooter"
	footer.add_theme_stylebox_override("panel", _style(CREAM, NAVY))
	_column.add_child(footer)
	var footer_row := HBoxContainer.new()
	footer_row.add_theme_constant_override("separation", 12)
	footer.add_child(footer_row)
	var cost_column := VBoxContainer.new()
	cost_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cost_column.add_child(_label("현재 재료비", 14, MUTED))
	_cost = _label("", 23)
	_cost.name = "EditorTrialCost"
	cost_column.add_child(_cost)
	footer_row.add_child(cost_column)
	_taste = _button("시식하기", "EditorTaste", "restaurant", GOLD)
	_taste.custom_minimum_size = Vector2(155, 58)
	_taste.add_theme_font_size_override("font_size", 22)
	_taste.pressed.connect(_primary_action)
	footer_row.add_child(_taste)


func _build_stage() -> void:
	_stage = PanelContainer.new()
	_stage.name = "RecipeStage"
	_stage.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_stage.add_theme_stylebox_override("panel", _style(CREAM, NAVY))
	_content.add_child(_stage)
	_scene = Control.new()
	_scene.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# The panel's Container assigns its final size after the parent's layout.
	# Reflow from that actual size, including the first frame and notice changes.
	_scene.resized.connect(_arrange_stage)
	_stage.add_child(_scene)
	var background := _picture(load("res://assets/ui/bowl-editor/workbench-background.png") as Texture2D, Vector2.ZERO)
	background.name = "WorkbenchBackground"
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_scene.add_child(background)
	_dish = Dish.new()
	_dish.name = "EditorDish"
	_scene.add_child(_dish)
	_summary = HBoxContainer.new()
	_summary.add_theme_constant_override("separation", 8)
	_scene.add_child(_summary)
	_broth = _button("", "EditorBroth")
	_noodle = _button("", "EditorNoodle")
	for button in [_broth, _noodle]:
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_font_size_override("font_size", 14)
		_summary.add_child(button)
	_broth_text = _summary_content(_broth, "국물", "soup_kitchen")
	_noodle_text = _summary_content(_noodle, "면", "ramen_dining")
	_broth.pressed.connect(func(): _show_group("broth"))
	_noodle.pressed.connect(func(): _show_group("noodle"))
	_slot_surface = PanelContainer.new()
	_slot_surface.name = "ToppingPortionPanel"
	_slot_surface.add_theme_stylebox_override("panel", _style(CREAM, TEAL))
	_slot_surface.minimum_size_changed.connect(func(): _arrange_stage.call_deferred())
	_scene.add_child(_slot_surface)
	_slot_box = VBoxContainer.new()
	_slot_box.add_theme_constant_override("separation", 2)
	_slot_surface.add_child(_slot_box)
	_slot_title = _label("", 16, INK)
	_slot_title.add_theme_font_override("font", DisplayFont)
	_slot_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_slot_title.add_theme_constant_override("shadow_offset_y", 1)
	_slot_box.add_child(_slot_title)
	_slots = GridContainer.new()
	_slots.add_theme_constant_override("h_separation", 6)
	_slots.add_theme_constant_override("v_separation", 4)
	_slot_box.add_child(_slots)


func _build_picker() -> void:
	var panel := PanelContainer.new()
	panel.name = "IngredientPane"
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _style(WHITE, NAVY))
	_content.add_child(panel)
	_picker = VBoxContainer.new()
	_picker.add_theme_constant_override("separation", 4)
	panel.add_child(_picker)
	var heading_row := HBoxContainer.new()
	_picker.add_child(heading_row)
	_heading = _label("토핑 추가", 20)
	_heading.name = "IngredientHeading"
	_heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading_row.add_child(_heading)
	_heading_hint = _label("같은 재료도 가능", 13, MUTED)
	_heading_hint.autowrap_mode = TextServer.AUTOWRAP_OFF
	_heading_hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	heading_row.add_child(_heading_hint)
	_filters = HBoxContainer.new()
	_filters.name = "ToppingCategories"
	_filters.add_theme_constant_override("separation", 3)
	_picker.add_child(_filters)
	for group in Categories.GROUPS:
		var button := _button(group, "Category_" + str(Categories.GROUPS.find(group)))
		button.add_theme_font_size_override("font_size", 14)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size.x = 0
		button.toggle_mode = true
		button.pressed.connect(select_category.bind(group))
		category_buttons[group] = button
		_filters.add_child(button)
	_scroll = ScrollContainer.new()
	_scroll.name = "IngredientScroll"
	_scroll.scroll_deadzone = 10
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_picker.add_child(_scroll)
	_rows = VBoxContainer.new()
	_rows.name = "IngredientRows"
	_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rows.add_theme_constant_override("separation", 3)
	_scroll.add_child(_rows)
	_work_box = VBoxContainer.new()
	_work_box.visible = false
	_work_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_picker.add_child(_work_box)
	_work_title = _label("", 23)
	_work_box.add_child(_work_title)
	_work_box.add_child(_label("국물 → 면 → 한 그릇", 18))
	_progress = ProgressBar.new()
	_progress.custom_minimum_size.y = 26
	_work_box.add_child(_progress)
	_work_box.add_child(_label("준비가 끝나면 한 번 시식해요.\n취소하면 재료비는 나가지 않아요.", 16, MUTED))
	var cancel := _button("준비 취소", "EditorCancel", "close")
	cancel.pressed.connect(func(): _emit("cancel"))
	_work_box.add_child(cancel)


func _summary_content(button: Button, title: String, icon_name: String) -> Label:
	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + edge, 5)
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 0)
	margin.add_child(column)
	var title_row := HBoxContainer.new()
	title_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var symbol := _picture(Art.icon(icon_name), Vector2(22, 22))
	symbol.self_modulate = INK
	title_row.add_child(symbol)
	var heading := _label(title, 19)
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(heading)
	var arrow := _picture(Art.icon("chevron_right"), Vector2(22, 22))
	arrow.self_modulate = INK
	title_row.add_child(arrow)
	column.add_child(title_row)
	var value := _label("", 13)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(value)
	button.add_child(margin)
	return value


func present(new_state: Game, mode: int, information: Dictionary) -> void:
	state = new_state
	_info = information
	_mode = mode
	_selected = int(_info["selected"])
	_wallet.text = won(state.wallet)
	_back.disabled = bool(_info["working"])
	_notice.text = str(_info["warning"]) if str(_info["warning"]) != "" else str(_info["notice"])
	_notice.visible = _notice.text != ""
	# A long actionable failure remains available in a dedicated detail dialog;
	# do not silently discard it or replace it with a success message.
	_notice.max_lines_visible = 2
	_notice.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_notice.tooltip_text = _notice.text
	_progress.value = float(_info["progress"]) * 100.0
	_work_title.text = str(_info["phase"])
	var key: String = JSON.stringify([state.draft_config, state.draft_name, state.wallet,
		state.rank(), state.topping_slots(), state.last_feedback_record_id, mode,
		_info["busy"], _info["working"], _selected, state.discovered_ingredients(),
		state.sample_stock("topping_citrus_peel"), state.sample_stock("topping_scallop")])
	if key == _last_key:
		return
	if _last_key != "" and _filters.visible:
		scroll_positions[category] = _scroll.scroll_vertical
	_last_key = key
	if _modal != null and bool(_info["working"]):
		_close_modal()
	var result: bool = mode == 1
	var config: Dictionary = state.draft_config
	var record: Dictionary = state.get_record(state.last_feedback_record_id)
	if result and not record.is_empty():
		config = record["config"]
	_dish.set_config(config)
	_broth_text.text = "%s · %s · %s" % [str(Catalog.find(str(config["broth"]))["name"]).replace(" 진국", "").replace(" 육수", ""), str(Catalog.find(str(config["tare"]))["name"]).replace(" 타레", ""), Catalog.find(str(config["oil"]))["name"]]
	_broth.tooltip_text = "%s · %s · %s" % [Catalog.find(str(config["broth"]))["name"], Catalog.find(str(config["tare"]))["name"], Catalog.find(str(config["oil"]))["name"]]
	_noodle_text.text = str(Catalog.find(str(config["noodle"]))["name"]) + " · " + str(Catalog.find(str(config["cook"]))["name"])
	_noodle.tooltip_text = str(Catalog.find(str(config["cook"]))["name"])
	_broth.disabled = result or bool(_info["busy"])
	_noodle.disabled = _broth.disabled
	_cost.text = won(Evaluator.unit_cost(config))
	_taste.text = "영업 시작" if result else ("준비 중" if bool(_info["working"]) else "시식하기")
	_taste.disabled = bool(_info["busy"]) and not result
	_render_slots(config, result)
	_render_content()
	_layout()


func _render_slots(config: Dictionary, result: bool) -> void:
	_clear(_slots)
	var portions: Array = Catalog.toppings_of(config)
	var capacity: int = state.topping_slots()
	_slot_title.text = "토핑 %d / %d칸 · 랭크 %d" % [portions.size(), capacity, state.rank()]
	if not result and portions.size() >= capacity:
		_slot_title.text = "토핑 %d/%d칸 · 칸을 눌러 교체" % [portions.size(), capacity]
	if not result and _selected >= 0 and _selected < portions.size():
		_slot_title.text = "교체할 토핑을 골라요 · %d/%d칸" % [portions.size(), capacity]
	_slots.columns = 3 if capacity == 3 else 2
	_slots.visible = not result
	for index in capacity:
		var occupied: bool = index < portions.size()
		var row := HBoxContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_theme_constant_override("separation", 2)
		_slots.add_child(row)
		var button := _button("", "EditorSlot_" + str(index), "" if occupied else "add", TEAL if _selected == index else CREAM)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if occupied:
			button.icon = Art.food(str(portions[index]))
			button.expand_icon = true
			button.add_theme_color_override("icon_normal_color", Color.WHITE)
			button.add_theme_constant_override("icon_max_width", 56)
		button.tooltip_text = "이 칸 교체: " + str(Catalog.find(str(portions[index]))["name"]) if occupied else "빈 칸에 추가"
		button.disabled = result or bool(_info["busy"])
		button.pressed.connect(func(): _emit("slot", {"index": index}))
		row.add_child(button)
		if occupied and not result:
			var remove := _button("", "EditorRemove_" + str(index), "remove")
			remove.tooltip_text = "이 분량 빼기"
			remove.disabled = bool(_info["busy"])
			remove.pressed.connect(func(): _emit("remove", {"index": index}))
			row.add_child(remove)


func select_category(group: String) -> void:
	if not Categories.GROUPS.has(group):
		push_error("알 수 없는 토핑 분류: " + group)
		return
	scroll_positions[category] = _scroll.scroll_vertical
	category = group
	_render_content()


func _render_content() -> void:
	item_rows.clear()
	add_buttons.clear()
	detail_buttons.clear()
	_clear(_rows)
	var working: bool = bool(_info["working"])
	var result: bool = _mode == 1
	_filters.visible = not result and not working
	_scroll.visible = not working
	_work_box.visible = working
	_heading.text = "한 그릇 완성" if result else ("조리 중" if working else "토핑 추가")
	_heading_hint.visible = not result and not working
	for group in category_buttons:
		(category_buttons[group] as Button).set_pressed_no_signal(category == group)
		(category_buttons[group] as Button).icon = Art.icon("check") if category == group else null
		(category_buttons[group] as Button).add_theme_constant_override("icon_max_width", 16)
	if working:
		return
	if result:
		_render_result()
		return
	var portions: Array = Catalog.toppings_of(state.draft_config)
	for item in Categories.filter_items(Catalog.all_items("topping"), category):
		var row := _ingredient_row(item, "topping", portions.count(str(item["id"])))
		_rows.add_child(row)
		item_rows[str(item["id"])] = row
	_scroll.set_deferred("scroll_vertical", int(scroll_positions.get(category, 0)))


func _ingredient_row(item: Dictionary, slot: String, count: int = 0) -> PanelContainer:
	var id: String = str(item["id"])
	var unlocked: bool = state.ingredient_unlocked(id)
	var panel := PanelContainer.new()
	panel.name = "Ingredient_" + id
	panel.custom_minimum_size.y = 68
	panel.mouse_filter = Control.MOUSE_FILTER_PASS
	panel.add_theme_stylebox_override("panel", _style(WHITE if unlocked else Color("e8e1d4"), Color("d5c6ab")))
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_PASS
	row.add_theme_constant_override("separation", 4)
	panel.add_child(row)
	var texture: Texture2D = Art.food(id) if slot == "topping" else PixelArt.scaled_tex(PixelArt.icon_image(id), 2)
	row.add_child(_picture(texture, Vector2(56, 56)))
	var text_column := VBoxContainer.new()
	text_column.mouse_filter = Control.MOUSE_FILTER_PASS
	text_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_column.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(text_column)
	var item_name := _label(str(item.get("short_name", item["name"])) + (" ×%d" % count if count > 0 else ""), 17)
	item_name.add_theme_font_override("font", DisplayFont)
	text_column.add_child(item_name)
	text_column.add_child(_label("%s · %d초" % [won(int(item["cost"])), int(item["seconds"])] if unlocked else "탐색으로 발견", 14, MUTED))
	var info := _button("", "EditorInfo_" + id, "info")
	info.tooltip_text = str(item["name"]) + " 상세"
	info.pressed.connect(_show_item.bind(item))
	row.add_child(info)
	var add := _button("", "EditorAdd_" + id, "add" if slot == "topping" else "check", TEAL)
	add.add_theme_color_override("icon_normal_color", Color.WHITE)
	add.tooltip_text = str(item["name"]) + (" 한 분량 추가/교체" if slot == "topping" else " 선택")
	add.disabled = bool(_info["busy"]) or not unlocked
	if slot != "topping":
		add.toggle_mode = true
		add.set_pressed_no_signal(str(state.draft_config[slot]) == id)
	if slot == "topping":
		add.disabled = add.disabled or (_selected < 0 and Catalog.toppings_of(state.draft_config).size() >= state.topping_slots())
	add.pressed.connect(func():
		var before: String = JSON.stringify(state.draft_config)
		_emit("ingredient", {"slot": slot, "id": id, "point": add.get_global_rect().get_center()})
		_refresh_modal_selections()
		# A refused transaction may still produce a button press; only a real
		# recipe change receives the food-addition celebration.
		if JSON.stringify(state.draft_config) != before:
			_dish.play_addition())
	row.add_child(add)
	if slot == "topping":
		add_buttons[id] = add
		detail_buttons[id] = info
	return panel


func _refresh_modal_selections() -> void:
	if _modal == null:
		return
	# Read the accepted state after the guarded controller returns. Independent
	# toggle buttons must never imply two broths or an unselected actual recipe.
	# Updating in place preserves the dialog's current scroll and focus.
	for slot in Catalog.SLOTS:
		if slot == "topping":
			continue
		for item in Catalog.all_items(slot):
			var id: String = str(item["id"])
			var button: Button = _modal.find_child("EditorAdd_" + id, true, false) as Button
			if button != null:
				var selected: bool = str(state.draft_config[slot]) == id
				button.set_pressed_no_signal(selected)
				button.icon = Art.icon("check" if selected else "add")
	for slot in ProcessRules.SLOTS:
		for id in ProcessRules.ids(slot):
			var button: Button = _modal.find_child("EditorProcess_" + slot + "_" + id, true, false) as Button
			if button != null:
				var selected: bool = ProcessRules.selected(state.draft_config.get("process", {}), slot) == id
				button.set_pressed_no_signal(selected)
				button.icon = Art.icon("check") if selected else null


func _modal_body(title: String) -> VBoxContainer:
	_close_modal()
	_modal = Control.new()
	_modal.name = "EditorDetails"
	_modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_modal)
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.08, 0.12, 0.8)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_modal.add_child(dim)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + edge, 14)
	var safe: Vector4 = _device_insets()
	margin.add_theme_constant_override("margin_top", maxi(72, int(safe.y) + 8))
	margin.add_theme_constant_override("margin_bottom", maxi(32, int(safe.w) + 8))
	_modal.add_child(margin)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _style(CREAM, NAVY))
	margin.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	panel.add_child(column)
	var header := HBoxContainer.new()
	var back := _button("", "EditorDetailsBack", "arrow_back")
	back.tooltip_text = "목록으로 돌아가기"
	back.pressed.connect(_close_modal)
	header.add_child(back)
	var heading := _label(title, 22)
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(heading)
	column.add_child(header)
	var scroll := ScrollContainer.new()
	scroll.name = "DetailsScroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.scroll_deadzone = 10
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(scroll)
	var body := VBoxContainer.new()
	body.name = "DetailsBody"
	body.add_theme_constant_override("separation", 10)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(body)
	return body


func _close_modal() -> void:
	if _modal != null:
		remove_child(_modal)
		_modal.queue_free()
		_modal = null


func _show_item(item: Dictionary) -> void:
	var group: String = ""
	if not str(item["id"]).begins_with("topping_"):
		group = "noodle" if str(item["id"]).begins_with("noodle_") or str(item["id"]).begins_with("cook_") else "broth"
		if _modal != null:
			var previous: ScrollContainer = _modal.find_child("DetailsScroll", true, false) as ScrollContainer
			_group_scroll[group] = previous.scroll_vertical
	var body := _modal_body(str(item["name"]))
	if group != "":
		var back: Button = _modal.find_child("EditorDetailsBack", true, false) as Button
		back.pressed.disconnect(_close_modal)
		back.pressed.connect(_show_group.bind(group))
	var id: String = str(item["id"])
	var texture: Texture2D = Art.food(id) if id.begins_with("topping_") else PixelArt.scaled_tex(PixelArt.icon_image(id), 3)
	body.add_child(_picture(texture, Vector2(120, 100)))
	body.add_child(_label(str(item["desc"]), 18))
	body.add_child(_label("한 분량 · " + won(int(item["cost"])) + "\n그릇당 준비시간 +%d초" % int(item["seconds"]), 17))
	body.add_child(_label(Catalog.axes_text(item), 16, TEAL))
	if Catalog.is_farmed(id):
		body.add_child(_label("시제품용 샘플 %d개 · 완성할 때 분량만큼 사용해요." % state.sample_stock(id), 16))
	if not state.ingredient_unlocked(id):
		for locked in state.locked_items("topping" if id.begins_with("topping_") else str(id.split("_")[0])):
			if str(locked["id"]) == id:
				body.add_child(_label(str(locked["lock"]["hint"]), 16, RED))


func _show_group(group: String) -> void:
	var body := _modal_body("국물 만들기" if group == "broth" else "면 고르기")
	var slots: Array[String] = []
	slots.assign(["broth", "tare", "oil"] if group == "broth" else ["noodle", "cook"])
	for slot in slots:
		body.add_child(_label(str(Catalog.SLOT_NAMES[slot]), 20))
		for item in Catalog.all_items(slot):
			body.add_child(_ingredient_row(item, slot))
	body.add_child(_label("육수 공법" if group == "broth" else "면 반죽", 20))
	for id in ProcessRules.ids(group):
		var method: Dictionary = ProcessRules.method(group, id)
		var button := _button(str(method["name"]) + " · 랭크%d" % int(method["rank"]), "EditorProcess_" + group + "_" + id)
		button.disabled = bool(_info["busy"]) or state.rank() < int(method["rank"])
		button.toggle_mode = true
		button.pressed.connect(func(): _emit("process", {"slot": group, "id": id}); _refresh_modal_selections())
		body.add_child(button)
	_refresh_modal_selections()
	(body.get_parent() as ScrollContainer).set_deferred("scroll_vertical", int(_group_scroll.get(group, 0)))


func _show_menu() -> void:
	var body := _modal_body("작업 메뉴")
	var edit := _button("이름·판매가", "EditorRecipeSettings", "settings")
	edit.pressed.connect(_show_settings)
	body.add_child(edit)
	var directions := _button("파밍 연구 방향", "EditorDirections", "ramen_dining")
	directions.pressed.connect(_show_directions)
	body.add_child(directions)
	var labels: Array[String] = ["개발", "시식 결과", "레시피 노트", "영업", "연구", "성장", "탐색", "대회"]
	for index in labels.size():
		var button := _button(labels[index], "EditorRoute_" + str(index), "chevron_right")
		button.disabled = bool(_info["working"])
		button.pressed.connect(func(): _close_modal(); _emit("route", {"index": index}))
		body.add_child(button)
	if _notice.visible:
		var message := _button("현재 안내 자세히", "EditorReadNotice", "info")
		message.pressed.connect(func(): _modal_body("현재 안내").add_child(_label(_notice.text, 17, RED)))
		body.add_child(message)
	var audio := _button("소리 켜기" if bool(_info["muted"]) else "소리 끄기", "EditorAudio", "volume_up")
	audio.pressed.connect(func(): _emit("audio"); _show_menu())
	body.add_child(audio)


func _show_settings() -> void:
	var body := _modal_body("이름·판매가")
	body.add_child(_label("시제품 이름", 18))
	var edit := NameEdit.new()
	edit.name = "EditorName"
	edit.scroll_target = body.get_parent() as ScrollContainer
	edit.max_length = Check.NAME_MAX
	edit.text = state.draft_name
	edit.editable = not bool(_info["busy"]) and state.draft_lineage_id == 0
	edit.custom_minimum_size.y = 48
	edit.text_changed.connect(func(value: String): _emit("name", {"value": value}))
	body.add_child(edit)
	body.add_child(_label("판매가 " + won(int(state.draft_config["price"])), 20))
	for delta in [-500, -100, 100, 500]:
		var button := _button("%+d원" % delta, "EditorPrice_" + str(delta))
		button.disabled = bool(_info["busy"])
		button.pressed.connect(func(): _emit("price", {"delta": delta}); _show_settings())
		body.add_child(button)
	var new_recipe := _button("새 레시피 시작", "EditorNewRecipe")
	new_recipe.disabled = bool(_info["busy"])
	new_recipe.pressed.connect(func(): _close_modal(); _emit("new"))
	body.add_child(new_recipe)


func _render_result() -> void:
	var record: Dictionary = state.get_record(state.last_feedback_record_id)
	if record.is_empty():
		_rows.add_child(_label("시식할 한 그릇을 먼저 만들어봐요.", 18))
		return
	var evaluation: Dictionary = Evaluator.evaluate(record["config"])
	_rows.add_child(_label("%s v%d · 평균 %d점" % [record["name"], record["version"], evaluation["average_score"]], 20))
	var customers := HBoxContainer.new()
	_rows.add_child(customers)
	for index in (evaluation["customers"] as Array).size():
		var data: Dictionary = evaluation["customers"][index]
		var button := _button("%s\n%d점" % [data["name"], data["score"]], "EditorCustomer_" + str(index))
		button.icon = PixelArt.scaled_tex(PixelArt.portrait_image(str(data["id"])), 2)
		button.add_theme_color_override("icon_normal_color", Color.WHITE)
		button.add_theme_constant_override("icon_max_width", 40)
		button.custom_minimum_size.y = 72
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.toggle_mode = true
		button.set_pressed_no_signal(_result_customer == index)
		button.pressed.connect(func(): _result_customer = index; _render_content())
		customers.add_child(button)
	var selected: Dictionary = evaluation["customers"][_result_customer]
	_rows.add_child(_label(str(selected["headline"]), 19, TEAL))
	_rows.add_child(_label(str(selected["reasons"][0]), 16))
	var details := _button("시식평 자세히", "EditorResultDetails", "info")
	details.pressed.connect(func():
		var body := _modal_body(str(selected["name"]) + "의 시식평")
		var customer_row := HBoxContainer.new()
		customer_row.add_child(_picture(PixelArt.scaled_tex(PixelArt.portrait_image(str(selected["id"])), 3), Vector2(56, 56)))
		var customer_title := _label("%s · %d점" % [selected["name"], selected["score"]], 20)
		customer_title.name = "EditorCustomerDetailName"
		customer_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		customer_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		customer_row.add_child(customer_title)
		body.add_child(customer_row)
		body.add_child(_label(str(selected["headline"]), 19, TEAL))
		# The summary shows one reason, but none of the evaluator's remaining
		# reasons or price feedback may be lost when replacing the old screen.
		for reason in selected["reasons"]:
			body.add_child(_label(str(reason), 17))
		body.add_child(_label("가격에 대한 반응", 18))
		body.add_child(_label(str(selected["value_note"]), 17))
		body.add_child(_label("이 그릇의 수치", 20))
		body.add_child(_label("판매가 %s · 원가 %s\n준비 %d초\n토핑: %s" % [won(int(record["config"]["price"])), won(int(evaluation["unit_cost"])), int(evaluation["prep_seconds"]), Catalog.topping_names(record["config"])], 17))
		_emit("comparison", {"body": body}))
	_rows.add_child(details)
	var clues := _button("다음 실험의 단서", "EditorClues", "info")
	clues.pressed.connect(_show_clues)
	_rows.add_child(clues)
	var again := _button("다시 개발", "EditorDevelopAgain", "ramen_dining")
	again.pressed.connect(func(): _emit("route", {"index": 0}))
	_rows.add_child(again)
	_scroll.set_deferred("scroll_vertical", 0)


func _show_directions() -> void:
	var body := _modal_body("파밍 연구 방향")
	var tested: Array[String] = Directions.tested_ids(state.records())
	for definition in Directions.catalog():
		var id: String = str(definition["id"])
		var button := _button(str(definition["title"]) + (" · 시식 기록 있음" if tested.has(id) else " · 살펴보기"), "EditorDirection_" + id, "chevron_right")
		button.pressed.connect(func():
			var detail := _modal_body(str(definition["title"]))
			var assessment: Dictionary = Directions.assess(id, state.draft_config)
			detail.add_child(_label(str(definition["source"]), 17, TEAL))
			for condition in assessment["checks"]:
				detail.add_child(_label(("확인 · " if bool(condition["met"]) else "목표 · ") + str(condition["text"]), 16))
			var go := _button("이 방향으로 실험", "EditorChooseDirection_" + id, "ramen_dining")
			go.disabled = bool(_info["busy"])
			go.pressed.connect(func(): _emit("direction", {"id": id}); _close_modal())
			detail.add_child(go)
			var find := _button("재료 찾기", "EditorDirectionExplore", "chevron_right")
			find.pressed.connect(func(): _close_modal(); _emit("route", {"index": 6}))
			detail.add_child(find))
		body.add_child(button)


func _show_clues() -> void:
	var body := _modal_body("다음 실험의 단서")
	var record: Dictionary = state.get_record(state.last_feedback_record_id)
	if record.is_empty():
		body.add_child(_label("먼저 시식한 한 그릇이 필요해요.", 18))
		return
	var available: Array[String] = []
	for slot in Catalog.SLOTS:
		for item in Catalog.all_items(slot):
			if state.ingredient_unlocked(str(item["id"])):
				available.append(str(item["id"]))
	var result: Dictionary = Experiments.clues(record["config"], available, state.rank())
	if str(result["error"]) != "":
		body.add_child(_label(str(result["error"]), 17, RED))
		return
	for clue in result["clues"]:
		body.add_child(_label(str(clue["title"]), 20, TEAL))
		var pair := HBoxContainer.new()
		pair.custom_minimum_size.y = 105
		body.add_child(pair)
		for config in [record["config"], clue["config"]]:
			var dish := Dish.new()
			dish.custom_minimum_size = Vector2(90, 100)
			dish.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			pair.add_child(dish)
			dish.set_config(config)
		body.add_child(_label("이번 그릇 → 한 가지 바꾸면\n%s\n예상 %s · 원가 %+d원 · 준비 %+d초" % [clue["change"], clue["flavor_text"], clue["cost_delta"], clue["seconds_delta"]], 16))
		body.add_child(_label("직접 재료를 골라 유료 시식을 마쳐야 기록돼요.", 14, MUTED))
		var go := _button("재료 선택으로", "EditorClueGo_" + str(clue["direction"]), "chevron_right")
		go.disabled = bool(_info["busy"])
		go.pressed.connect(func():
			_close_modal()
			_emit("route", {"index": 0})
			var slot: String = str(clue["slot"])
			if slot != "topping":
				_show_group("noodle" if slot in ["noodle", "cook"] else "broth"))
		body.add_child(go)


func _primary_action() -> void:
	_close_modal()
	_emit("serve" if _mode == 1 else "taste")


func _layout() -> void:
	if _content == null:
		return
	var wide: bool = size.x >= 720
	_content.columns = 2 if wide else 1
	var horizontal: int = maxi(6, int((size.x - 1180.0) * 0.5))
	var insets: Vector4 = _device_insets()
	for edge in ["left", "right"]:
		_root_margin.add_theme_constant_override("margin_" + edge, horizontal + int(insets.x if edge == "left" else insets.z))
	_root_margin.add_theme_constant_override("margin_top", 6 + int(insets.y))
	_root_margin.add_theme_constant_override("margin_bottom", 8 + int(insets.w))
	var stage_height: float = 300.0 if _mode == 1 else (360.0 if state == null or state.topping_slots() < 4 else 412.0)
	if not wide:
		# Safe areas or a shorter window consume real space. Share that loss with
		# the preview so the independently scrollable list retains usable height.
		var usable_height: float = size.y - insets.y - insets.w
		stage_height = maxf(260.0 if _mode == 1 else 300.0, stage_height - maxf(0.0, 844.0 - usable_height) * 0.35)
	_stage.custom_minimum_size = Vector2(0, stage_height)
	_stage.size_flags_vertical = Control.SIZE_EXPAND_FILL if wide else Control.SIZE_FILL
	_arrange_stage.call_deferred()


func _device_insets() -> Vector4:
	if OS.get_name() not in ["iOS", "Android"]:
		return Vector4.ZERO
	# Physical safe-area pixels are converted into this viewport's logical space.
	# OS chrome belongs to the device and is never drawn into app content.
	var safe: Rect2i = DisplayServer.get_display_safe_area()
	var window: Vector2i = DisplayServer.window_get_size()
	if window.x <= 0 or window.y <= 0:
		push_error("안전 영역을 위한 창 크기가 올바르지 않아요.")
		return Vector4.ZERO
	var factor: Vector2 = size / Vector2(window)
	return Vector4(maxi(0, safe.position.x) * factor.x, maxi(0, safe.position.y) * factor.y, maxi(0, window.x - safe.end.x) * factor.x, maxi(0, window.y - safe.end.y) * factor.y)


func _arrange_stage() -> void:
	var dimensions: Vector2 = _scene.size
	if _slot_surface == null or _summary == null or _dish == null or dimensions.x <= 0 or dimensions.y <= 0:
		return # Container's first real resize will finish the layout.
	var slot_height: float = maxf(_slot_surface.get_combined_minimum_size().y, 32.0 if _mode == 1 else (144.0 if state != null and state.topping_slots() == 4 else 86.0))
	_summary.position = Vector2(6, 6)
	_summary.size = Vector2(dimensions.x - 12, 68)
	var slot_width: float = minf(dimensions.x - 20, 320)
	_slot_surface.position = Vector2((dimensions.x - slot_width) * 0.5, dimensions.y - slot_height - 4)
	_slot_surface.size = Vector2(slot_width, slot_height)
	_dish.position = Vector2(20, 76)
	_dish.size = Vector2(dimensions.x - 40, maxf(80, dimensions.y - slot_height - 80))
