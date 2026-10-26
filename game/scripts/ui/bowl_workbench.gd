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
const BodyFont = preload("res://assets/fonts/Pretendard-Regular.otf")
const DisplayFont = preload("res://assets/fonts/Pretendard-Bold.otf")
const MockArt = preload("res://scripts/ui/mock_fidelity_art.gd")
const TrialPreview = preload("res://scripts/ui/ingredient_trial_preview.gd")
const Noodle=preload("res://scripts/domain/noodle_workshop.gd")
const NoodleView=preload("res://scripts/ui/noodle_work_view.gd")
const Broth = preload("res://scripts/domain/broth_workshop.gd")
const PantryArt = preload("res://scripts/ui/broth_material_art.gd")
const WorkView = preload("res://scripts/ui/tasting_work_view.gd")
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
var _slot_count: Label
var _pointer_left: TextureRect
var _pointer_right: TextureRect
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
var _work_scroll: ScrollContainer
var _result_customer: int = 0
var _group_scroll: Dictionary = {}
var _group_tab: Dictionary = {}
var _broth_category: String="전체"
var _broth_page: String="blend"
var _broth_scroll: Dictionary={}


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
	style.set_corner_radius_all(5)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style


func _label(text: String, font_size: int = 16, color: Color = INK) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	# UI text stays smooth at small native sizes; pixel filtering belongs to art.
	# Use an actual semibold face for hierarchy instead of thick bitmap glyphs.
	label.add_theme_font_override("font", DisplayFont if font_size >= 18 else BodyFont)
	return label


func _button(text: String, node_name: String, icon_name: String = "", bg: Color = CREAM) -> Button:
	var button := Button.new()
	button.name = node_name
	button.text = text
	button.custom_minimum_size = Vector2(48, 48)
	button.mouse_filter = Control.MOUSE_FILTER_PASS
	button.add_theme_font_size_override("font_size", 16)
	button.add_theme_font_override("font", DisplayFont)
	var skin: String = "gold" if bg == GOLD else ("teal" if bg == TEAL else ("blue" if bg == NAVY else "summary"))
	button.add_theme_stylebox_override("normal", MockArt.style(skin))
	var hover := MockArt.style(skin)
	hover.modulate_color = Color(1.05,1.05,1.05,1)
	button.add_theme_stylebox_override("hover", hover)
	var pressed := MockArt.style("teal")
	pressed.modulate_color = Color(0.85,0.9,0.9,1)
	button.add_theme_stylebox_override("pressed", pressed)
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
	picture.material = Art.image_material(texture)
	picture.custom_minimum_size = minimum
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	picture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return picture


func _ingredient_texture(id: String) -> Texture2D:
	# Reuse the selected mock's filled symbols consistently in rows and details.
	# Actual topping images stay ingredient-specific, including farmed materials.
	if id=="noodle_buckwheat" or id.begins_with("topping_"):
		return Art.food(id)
	if id.begins_with("broth_"):
		return MockArt.texture("pot")
	if id.begins_with("noodle_"):
		return MockArt.texture("noodles")
	return PixelArt.scaled_tex(PixelArt.icon_image(id),3)


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
	_column.add_theme_constant_override("separation", 3)
	_root_margin.add_child(_column)
	var header := Control.new()
	header.name = "WorkbenchHeader"
	header.custom_minimum_size.y = 48
	_column.add_child(header)
	_back = _button("가게", "EditorBack", "arrow_back", NAVY)
	_back.add_theme_font_size_override("font_size",18)
	_back.add_theme_color_override("font_color", CREAM)
	_back.add_theme_color_override("icon_normal_color", CREAM)
	_back.tooltip_text = "가게로 돌아가기"
	_back.pressed.connect(func(): _emit("close"))
	header.add_child(_back)
	var title := _label("메뉴 개발", 28, CREAM)
	title.name = "EditorTitle"
	title.autowrap_mode = TextServer.AUTOWRAP_OFF
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_shadow_color", Color("101f34"))
	title.add_theme_constant_override("shadow_offset_y", 2)
	header.add_child(title)
	var wallet_row := HBoxContainer.new()
	wallet_row.add_theme_constant_override("separation", 4)
	header.add_child(wallet_row)
	wallet_row.add_child(_picture(MockArt.texture("coin"), Vector2(20,24)))
	_wallet = _label("", 14, CREAM)
	_wallet.name = "EditorWallet"
	_wallet.autowrap_mode = TextServer.AUTOWRAP_OFF
	_wallet.clip_text = true
	_wallet.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_wallet.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_wallet.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	wallet_row.add_child(_wallet)
	var menu := _button("", "EditorMenu", "menu", NAVY)
	menu.add_theme_color_override("icon_normal_color", CREAM)
	menu.tooltip_text = "이름·판매가와 다른 작업"
	menu.pressed.connect(_show_menu)
	header.add_child(menu)
	var arrange_header := func():
		_back.position = Vector2(0,3)
		_back.size = Vector2(80,44)
		title.position = Vector2(header.size.x * 0.5 - 66,0)
		title.size = Vector2(132,50)
		wallet_row.position = Vector2(header.size.x - 130,3)
		wallet_row.size = Vector2(82,44)
		menu.position = Vector2(header.size.x - 44,3)
		menu.size = Vector2(44,44)
	header.resized.connect(arrange_header)
	arrange_header.call()
	_notice = _label("", 14, GOLD)
	_notice.name = "EditorNotice"
	_column.add_child(_notice)
	_content = GridContainer.new()
	_content.add_theme_constant_override("h_separation", 10)
	_content.add_theme_constant_override("v_separation", 0)
	_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_column.add_child(_content)
	_build_stage()
	_build_picker()
	var footer := PanelContainer.new()
	footer.name = "EditorFooter"
	footer.add_theme_stylebox_override("panel", MockArt.style("panel", Vector2(14,6)))
	_column.add_child(footer)
	var footer_row := HBoxContainer.new()
	footer_row.add_theme_constant_override("separation", 12)
	footer.add_child(footer_row)
	var cost_column := VBoxContainer.new()
	cost_column.add_theme_constant_override("separation", 4)
	cost_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cost_column.add_child(_label("현재 재료비", 14, MUTED))
	var cost_row := HBoxContainer.new()
	cost_row.add_theme_constant_override("separation", 6)
	cost_column.add_child(cost_row)
	cost_row.add_child(_picture(MockArt.texture("coin"), Vector2(24,24)))
	_cost = _label("", 24)
	# A numeric price inside an HBox must keep its real text width. Otherwise
	# smart wrapping can turn each digit into a line and inflate the fixed footer.
	_cost.autowrap_mode = TextServer.AUTOWRAP_OFF
	_cost.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_cost.name = "EditorTrialCost"
	cost_row.add_child(_cost)
	var cost_margin := MarginContainer.new()
	cost_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cost_margin.add_theme_constant_override("margin_left",12)
	cost_margin.add_child(cost_column)
	footer_row.add_child(cost_margin)
	_taste = _button("시식하기", "EditorTaste", "", GOLD)
	_taste.custom_minimum_size = Vector2(190, 54)
	_taste.add_theme_font_size_override("font_size", 24)
	_taste.pressed.connect(_primary_action)
	footer_row.add_child(_taste)


func _build_stage() -> void:
	_stage = PanelContainer.new()
	_stage.name = "RecipeStage"
	_stage.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var stage_style := _style(CREAM, NAVY)
	# This image-only surface needs its frame, not the text-card padding. Keep
	# that space for the dish when a shorter window also shows four portions.
	stage_style.content_margin_left = 2
	stage_style.content_margin_right = 2
	stage_style.content_margin_top = 2
	stage_style.content_margin_bottom = 2
	_stage.add_theme_stylebox_override("panel", stage_style)
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
	_pointer_left = _picture(MockArt.texture("pointer"), Vector2.ZERO)
	_pointer_left.name = "BrothCalloutPointer"
	_scene.add_child(_pointer_left)
	_pointer_right = _picture(MockArt.texture("pointer"), Vector2.ZERO)
	_pointer_right.name = "NoodleCalloutPointer"
	_pointer_right.flip_h = true
	_scene.add_child(_pointer_right)
	_summary = HBoxContainer.new()
	_summary.add_theme_constant_override("separation", 30)
	_scene.add_child(_summary)
	_broth = _button("", "EditorBroth")
	_noodle = _button("", "EditorNoodle")
	for button in [_broth, _noodle]:
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_font_size_override("font_size", 14)
		_summary.add_child(button)
	_broth_text = _summary_content(_broth, "국물", "broth_tonkotsu")
	_noodle_text = _summary_content(_noodle, "면", "noodle_thin")
	_broth.pressed.connect(func(): _show_group("broth"))
	_noodle.pressed.connect(func(): _show_group("noodle"))
	_slot_surface = PanelContainer.new()
	_slot_surface.name = "ToppingPortionPanel"
	_slot_surface.add_theme_stylebox_override("panel", MockArt.style("portions", Vector2(10,6)))
	_slot_surface.minimum_size_changed.connect(func(): _arrange_stage.call_deferred())
	_scene.add_child(_slot_surface)
	_slot_box = VBoxContainer.new()
	_slot_box.add_theme_constant_override("separation", 4)
	_slot_surface.add_child(_slot_box)
	var slot_heading := HBoxContainer.new()
	slot_heading.add_theme_constant_override("separation", 6)
	_slot_box.add_child(slot_heading)
	slot_heading.add_child(_picture(MockArt.bowl("noodle_thin"), Vector2(28,22)))
	_slot_title = _label("토핑", 18, INK)
	_slot_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slot_heading.add_child(_slot_title)
	_slot_count = _label("", 15)
	_slot_count.autowrap_mode = TextServer.AUTOWRAP_OFF
	_slot_count.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	slot_heading.add_child(_slot_count)
	_slots = GridContainer.new()
	_slots.add_theme_constant_override("h_separation", 0)
	_slots.add_theme_constant_override("v_separation", 4)
	_slots.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_slot_box.add_child(_slots)


func _build_picker() -> void:
	var panel := PanelContainer.new()
	panel.name = "IngredientPane"
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", MockArt.style("panel", Vector2(8,6)))
	_content.add_child(panel)
	_picker = VBoxContainer.new()
	_picker.add_theme_constant_override("separation", 4)
	panel.add_child(_picker)
	var heading_row := HBoxContainer.new()
	var heading_margin := MarginContainer.new()
	# Keep the title clear of the ornamental corner without padding every row.
	heading_margin.add_theme_constant_override("margin_left",8)
	heading_margin.add_theme_constant_override("margin_right",6)
	heading_margin.add_theme_constant_override("margin_top",3)
	heading_margin.add_theme_constant_override("margin_bottom",1)
	_picker.add_child(heading_margin)
	heading_margin.add_child(heading_row)
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
		button.custom_minimum_size = Vector2(0,44)
		button.toggle_mode = true
		var filter_style := _style(CREAM, Color("bca17d"))
		filter_style.set_border_width_all(1)
		button.add_theme_stylebox_override("normal",filter_style)
		button.add_theme_stylebox_override("hover",filter_style)
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
	_rows.add_theme_constant_override("separation", 2)
	_scroll.add_child(_rows)
	# A hidden wrapped VBox retains its narrow startup text height. Giving that
	# height directly to the picker can push the dish/footer off the viewport
	# when cooking starts. Bound the work body exactly like the ingredient list.
	_work_scroll=ScrollContainer.new()
	_work_scroll.name="CookingScroll"
	_work_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	_work_scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL
	_work_scroll.scroll_deadzone=10
	_work_scroll.visible=false
	_picker.add_child(_work_scroll)
	_work_box = VBoxContainer.new()
	_work_box.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	_work_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_work_scroll.add_child(_work_box)
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
	margin.name = "SummaryContent"
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# The real child inset is independent of the textured Button's style box.
	for edge in ["left","right"]:
		margin.add_theme_constant_override("margin_"+edge,6)
	for edge in ["top","bottom"]:
		margin.add_theme_constant_override("margin_"+edge,8)
	var row := HBoxContainer.new()
	row.name = "SummaryHeadingRow"
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation",4)
	margin.add_child(row)
	row.add_child(_picture(MockArt.texture("pot" if icon_name.begins_with("broth") else "noodles"),Vector2(42,40)))
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	column.add_theme_constant_override("separation",2)
	row.add_child(column)
	column.add_child(_label(title,20))
	var value := _label("",11)
	value.name = "SummaryValue"
	value.autowrap_mode = TextServer.AUTOWRAP_OFF
	value.clip_text = true
	value.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	column.add_child(value)
	var arrow := _picture(Art.icon("chevron_right"),Vector2(14,20))
	arrow.self_modulate = INK
	row.add_child(arrow)
	button.add_child(margin)
	return value


func present(new_state: Game, mode: int, information: Dictionary) -> void:
	state = new_state
	_info = information
	_mode = mode
	_selected = int(_info["selected"])
	_wallet.text = won(state.wallet)
	_wallet.tooltip_text = _wallet.text
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
		state.sample_stock("topping_citrus_peel"), state.sample_stock("topping_scallop"),
		_info.get("new_directions",[]),_info.get("new_themes",[])])
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
	_dish.visible=result or (state.broth_ready() and state.noodle_ready())
	_broth_text.text = "%s·%s·%s" % [Catalog.broth_name(config).replace(" 진국", "").replace(" 육수", ""), str(Catalog.find(str(config["tare"]))["name"]).replace(" 타레", ""), Catalog.find(str(config["oil"]))["name"]] if result or state.broth_ready() else "첫 육수를 개발해 주세요"
	_broth.tooltip_text = "%s · %s · %s" % [Catalog.broth_name(config), Catalog.find(str(config["tare"]))["name"], Catalog.find(str(config["oil"]))["name"]]
	_noodle_text.text = Catalog.noodle_name(config) + "·" + str(Catalog.find(str(config["cook"]))["name"]).replace("하게", "")
	if not result and not state.noodle_ready(): _noodle_text.text="첫 면을 개발해 주세요"
	_noodle.tooltip_text = str(Catalog.find(str(config["cook"]))["name"])
	var noodle_art: TextureRect=_noodle.find_child("SummaryHeadingRow",true,false).get_child(0)
	noodle_art.texture=_ingredient_texture(str(config["noodle"]))
	noodle_art.material=Art.image_material(noodle_art.texture)
	_broth.disabled = result or bool(_info["busy"])
	_noodle.disabled = _broth.disabled
	_cost.text = won(Evaluator.unit_cost(config))
	_taste.text = "영업 시작" if result else ("준비 중" if bool(_info["working"]) else "시식하기")
	if not result and not state.broth_ready():
		_taste.text="육수 개발하기"
		_cost.text="육수 미개발"
	if not result and state.broth_ready() and not state.noodle_ready():
		_taste.text="면 개발하기"
		_cost.text="면 미개발"
	_taste.disabled = bool(_info["busy"]) and not result
	_render_slots(config, result)
	_render_content()
	_layout()


func _render_slots(config: Dictionary, result: bool) -> void:
	_clear(_slots)
	var portions: Array = Catalog.toppings_of(config)
	var capacity: int = state.topping_slots()
	_slot_title.text = "토핑 교체" if _selected >= 0 and _selected < portions.size() else "토핑"
	_slot_count.text = "%d / %d칸" % [portions.size(),capacity]
	_slot_surface.tooltip_text = "랭크%d · 칸을 누르면 교체하고 빨간 버튼으로 한 분량씩 빼요." % state.rank()
	_slots.columns = 3 if capacity == 3 else 2
	_slots.visible = not result
	for index in capacity:
		var occupied: bool = index < portions.size()
		var compact: bool = capacity >= 4
		var tile_size: float = 52.0 if compact else 64.0
		var cell := Control.new()
		cell.custom_minimum_size = Vector2(88,60 if compact else 72)
		_slots.add_child(cell)
		var button := _button("", "EditorSlot_"+str(index), "" if occupied else "add", CREAM)
		button.position = Vector2(10,8)
		button.size = Vector2(tile_size,tile_size)
		button.custom_minimum_size = Vector2(tile_size,tile_size)
		var tile := _style(WHITE, TEAL if _selected == index or not occupied else Color("c8ad82"))
		tile.content_margin_left = 4
		tile.content_margin_right = 4
		tile.content_margin_top = 4
		tile.content_margin_bottom = 4
		tile.set_border_width_all(2)
		button.add_theme_stylebox_override("normal",tile)
		if not occupied or _selected == index:
			button.add_theme_stylebox_override("normal",MockArt.style("portions",Vector2(4,4)))
		if occupied:
			button.icon = Art.food(str(portions[index]))
			button.expand_icon = true
			button.add_theme_color_override("icon_normal_color",Color.WHITE)
			button.add_theme_constant_override("icon_max_width",int(tile_size-8))
		else:
			button.add_theme_color_override("icon_normal_color",TEAL)
			button.add_theme_constant_override("icon_max_width",36)
		button.tooltip_text = "이 칸 교체: "+str(Catalog.find(str(portions[index]))["name"]) if occupied else "빈 칸에 추가"
		button.disabled = result or bool(_info["busy"])
		button.pressed.connect(func(): _emit("slot",{"index":index}))
		cell.add_child(button)
		if occupied and not result:
			# The compact badge keeps a separate44px hit inside the portion panel;
			# its hit stops before the next tile, without shrinking mobile removal.
			var badge := Panel.new()
			badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
			badge.position = Vector2(59,9)
			badge.size = Vector2(26,26)
			var badge_style := _style(Color("e54230"),Color("a8291b"))
			badge_style.set_corner_radius_all(13)
			badge.add_theme_stylebox_override("panel",badge_style)
			badge.modulate.a = 0.45 if bool(_info["busy"]) else 1.0
			cell.add_child(badge)
			var remove := _button("","EditorRemove_"+str(index),"remove")
			remove.custom_minimum_size = Vector2(44,44)
			remove.position = Vector2(50,0)
			remove.size = Vector2(44,44)
			# Disabled removal must remain the same small badge. The generic44px
			# disabled Button surface would cover the selected food during cooking.
			for status in ["normal","hover","pressed","disabled"]:
				remove.add_theme_stylebox_override(status,StyleBoxEmpty.new())
			remove.add_theme_color_override("icon_normal_color",Color.WHITE)
			remove.add_theme_color_override("icon_hover_color",Color.WHITE)
			remove.add_theme_color_override("icon_focus_color",Color.WHITE)
			remove.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
			remove.icon = null
			var minus := _picture(Art.icon("remove"),Vector2.ZERO)
			minus.position = Vector2(9,9)
			minus.size = Vector2(26,26)
			remove.add_child(minus)
			remove.tooltip_text = "이 분량 빼기"
			remove.disabled = bool(_info["busy"])
			remove.modulate.a = 0.45 if remove.disabled else 1.0
			remove.pressed.connect(func(): _emit("remove",{"index":index}))
			cell.add_child(remove)


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
	_work_scroll.visible = working
	_heading.text = "한 그릇 완성" if result else ("조리 중" if working else "토핑 추가")
	_heading_hint.visible = not result and not working
	var portion_count: int = Catalog.toppings_of(state.draft_config).size()
	_heading_hint.text = ("선택한 칸에 교체" if _selected < portion_count else "선택한 칸에 추가") if _selected >= 0 else ("칸을 눌러 교체" if portion_count >= state.topping_slots() else "같은 재료도 가능")
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
	panel.custom_minimum_size.y = 60
	panel.mouse_filter = Control.MOUSE_FILTER_PASS
	var row_style := _style(WHITE if unlocked else Color("e8e1d4"), Color("d5c6ab"))
	row_style.set_border_width_all(1)
	row_style.content_margin_left = 6
	row_style.content_margin_right = 6
	row_style.content_margin_top = 4
	row_style.content_margin_bottom = 4
	panel.add_theme_stylebox_override("panel", row_style)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_PASS
	row.add_theme_constant_override("separation", 6)
	panel.add_child(row)
	var texture: Texture2D = _ingredient_texture(id)
	var tile := PanelContainer.new()
	var tile_style := _style(Color("eee0c1"),Color("eee0c1"))
	tile_style.set_border_width_all(0)
	tile_style.content_margin_left = 1
	tile_style.content_margin_right = 1
	tile_style.content_margin_top = 1
	tile_style.content_margin_bottom = 1
	tile.add_theme_stylebox_override("panel",tile_style)
	tile.add_child(_picture(texture,Vector2(48,48)))
	row.add_child(tile)
	var text_column := VBoxContainer.new()
	text_column.mouse_filter = Control.MOUSE_FILTER_PASS
	text_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_column.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	text_column.add_theme_constant_override("separation", 2)
	row.add_child(text_column)
	var item_name := _label(str(item.get("short_name", item["name"])) + ("  %d" % count if count > 0 else ""), 18)
	item_name.add_theme_font_override("font", DisplayFont)
	text_column.add_child(item_name)
	text_column.add_child(_label("%s · %d초" % [won(int(item["cost"])), int(item["seconds"])] if unlocked else "탐색으로 발견", 14, MUTED))
	var info := _button("", "EditorInfo_" + id, "info")
	info.custom_minimum_size = Vector2(44,44)
	info.add_theme_constant_override("icon_max_width",28)
	info.add_theme_color_override("icon_normal_color",Color("858581"))
	info.add_theme_stylebox_override("normal",StyleBoxEmpty.new())
	info.add_theme_stylebox_override("hover",StyleBoxEmpty.new())
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
		_choose_ingredient(slot, id, add.get_global_rect().get_center()))
	row.add_child(add)
	if slot == "topping":
		add_buttons[id] = add
		detail_buttons[id] = info
	return panel


func _choose_ingredient(slot: String, id: String, point: Vector2) -> bool:
	# Row and detail actions share the same guarded controller. Only accepted
	# recipe changes animate the food; browsing and rejected actions never do.
	var before: String = JSON.stringify(state.draft_config)
	_emit("ingredient", {"slot": slot, "id": id, "point": point})
	_refresh_modal_selections()
	var changed: bool = JSON.stringify(state.draft_config) != before
	if changed:
		_dish.play_addition()
	return changed


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
	var current: Label = _modal.find_child("GroupCurrentChoice",true,false) as Label
	if current != null:
		var tab: String = str(_modal.get_meta("tab"))
		var group: String = str(_modal.get_meta("group"))
		current.text = "현재 · " + (str(ProcessRules.method(group,ProcessRules.selected(state.draft_config.get("process",{}),group))["name"]) if tab == "method" else str(Catalog.find(str(state.draft_config[tab]))["name"]))


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
	margin.name = "DetailsMargin"
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_modal.add_child(margin)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", MockArt.style("panel",Vector2(14,12)))
	margin.add_child(panel)
	var column := VBoxContainer.new()
	column.name = "DetailsColumn"
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
	_arrange_modal()
	return body


func _close_modal() -> void:
	if _modal != null:
		remove_child(_modal)
		_modal.queue_free()
		_modal = null


func _arrange_modal() -> void:
	if _modal == null:
		return
	var margin: MarginContainer = _modal.find_child("DetailsMargin",true,false) as MarginContainer
	if margin == null:
		return # The sheet is still being constructed during its initial resize.
	var safe: Vector4 = _device_insets()
	# Recompute width and safe-area margins on a live resize, not just when the
	# sheet opens. Desktop margins must not survive into a narrow phone window.
	var horizontal: int = maxi(14,int((size.x-680)*0.5))
	margin.add_theme_constant_override("margin_left",horizontal+int(safe.x))
	margin.add_theme_constant_override("margin_right",horizontal+int(safe.z))
	if _modal.has_meta("compact_height"):
		var bottom: float = maxf(32,safe.w+8)
		var available: float = size.y-maxf(72,safe.y+8)-bottom
		margin.anchor_top = 1
		margin.anchor_bottom = 1
		margin.offset_top = -bottom-minf(float(_modal.get_meta("compact_height")),available)
		margin.offset_bottom = -bottom
		margin.add_theme_constant_override("margin_top",0)
		margin.add_theme_constant_override("margin_bottom",0)
	else:
		margin.anchor_top = 0
		margin.anchor_bottom = 1
		margin.offset_top = 0
		margin.offset_bottom = 0
		margin.add_theme_constant_override("margin_top",maxi(72,int(safe.y)+8))
		margin.add_theme_constant_override("margin_bottom",maxi(32,int(safe.w)+8))


func _compact_detail(height: float) -> void:
	# Short tasks retain the actual bowl context, with fixed back/action and a
	# scrollable body. Store the intent so a later resize can safely reflow it.
	_modal.set_meta("compact_height",height)
	_arrange_modal()


func _modal_footer(hint: String, title: String, action: Callable, disabled: bool = false) -> Button:
	var column: VBoxContainer = _modal.find_child("DetailsColumn",true,false) as VBoxContainer
	var footer := VBoxContainer.new()
	footer.name = "DetailsFooter"
	footer.add_theme_constant_override("separation",6)
	column.add_child(footer)
	var message := _label(hint,14,MUTED)
	message.name = "DetailsActionHint"
	footer.add_child(message)
	var button := _button(title,"EditorDetailApply","",GOLD)
	button.custom_minimum_size.y = 52
	button.add_theme_font_size_override("font_size",20)
	button.disabled = disabled
	button.pressed.connect(action)
	footer.add_child(button)
	return button


func _save_group_scroll() -> void:
	# Only the selector owns a tab scroll position. A nested ingredient detail
	# must not overwrite it with its own unrelated scroll when going back.
	if _modal == null or str(_modal.get_meta("view_kind","")) != "group":
		return
	var key: String = str(_modal.get_meta("group"))+":"+str(_modal.get_meta("tab"))
	var scroll: ScrollContainer = _modal.find_child("DetailsScroll",true,false) as ScrollContainer
	_group_scroll[key] = scroll.scroll_vertical


func _exit_group() -> void:
	_save_group_scroll()
	_close_modal()


func reveal_ingredient(id: String) -> void:
	# Collection navigation exposes the current material without selecting it,
	# replacing an edited draft or spending samples. Return context stays local.
	var item: Dictionary = Catalog.find(id)
	if item.is_empty():
		push_error("개발에서 열 재료가 없어요: "+id)
		return
	if id.begins_with("noodle_"):
		_show_noodle_source(id)
		return
	if id.begins_with("broth_"):
		_show_raw_broth_source(id)
		return
	if id.begins_with("topping_"):
		category=Categories.category(id)
		_last_key=""
		_render_content()
	else:
		_group_tab["broth"]=id.get_slice("_",0)
	_show_item(item)


func _show_item(item: Dictionary) -> void:
	if str(item["id"]).begins_with("noodle_"):
		_show_noodle_source(item["id"])
		return
	if str(item["id"]).begins_with("broth_"):
		_show_raw_broth_source(item["id"])
		return
	_save_group_scroll()
	var id: String = str(item["id"])
	var slot: String = id.get_slice("_",0)
	var group: String = "" if slot == "topping" else ("noodle" if slot in ["noodle","cook"] else "broth")
	var body := _modal_body(str(item["name"]))
	_modal.set_meta("view_kind","ingredient")
	if group != "":
		var back: Button = _modal.find_child("EditorDetailsBack",true,false) as Button
		back.pressed.disconnect(_close_modal)
		back.pressed.connect(_show_group.bind(group))
	var hero := HBoxContainer.new()
	hero.add_theme_constant_override("separation",12)
	body.add_child(hero)
	var texture: Texture2D = _ingredient_texture(id)
	hero.add_child(_picture(texture,Vector2(112,112)))
	var stats := VBoxContainer.new()
	stats.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stats.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	stats.add_theme_constant_override("separation",6)
	hero.add_child(stats)
	stats.add_child(_label(("설정" if slot == "cook" else "1분량")+" · "+str(Catalog.SLOT_NAMES[slot]),14,MUTED))
	stats.add_child(_label(won(int(item["cost"])),24))
	stats.add_child(_label("준비 +%d초" % int(item["seconds"]),16))
	body.add_child(_label(str(item["desc"]),18))
	body.add_child(_label(Catalog.axes_text(item),16,TEAL))
	if Catalog.is_farmed(id):
		body.add_child(_label("시제품용 샘플 %d개 · 완성할 때 분량만큼 사용해요." % state.sample_stock(id),16))
	var preview := _button("넣기 전후 비교","EditorIngredientExperiment","ramen_dining")
	preview.pressed.connect(_show_ingredient_experiment.bind(item))
	body.add_child(preview)
	var unlocked: bool = state.ingredient_unlocked(id)
	if not unlocked:
		for locked in state.locked_items(slot):
			if str(locked["id"]) == id:
				body.add_child(_label(str(locked["lock"]["hint"]),16,RED))
	var full: bool = Catalog.toppings_of(state.draft_config).size() >= state.topping_slots()
	var selected: bool = slot != "topping" and str(state.draft_config[slot]) == id
	var title: String = "선택 중" if selected else ("이 익힘으로 선택" if slot == "cook" else "이 재료 선택")
	var hint: String = "시식이 완료될 때 재료비가 나가요."
	if slot == "topping":
		title = ("선택한 칸에 교체" if _selected < Catalog.toppings_of(state.draft_config).size() else "선택한 칸에 추가") if _selected >= 0 else ("교체할 칸 고르기" if full else "이 토핑 추가")
		if full and _selected < 0:
			hint = "가득 찼어요. 어떤 토핑을 바꿀지 골라요."
	if not unlocked:
		title = "아직 발견하지 못했어요"
		hint = "발견 조건을 먼저 확인해 주세요."
	var apply := _modal_footer(hint,title,func():
		if slot == "topping" and full and _selected < 0:
			_show_replacement(item)
		else:
			_apply_detail(item,group),not unlocked or selected or bool(_info["busy"]))
	apply.tooltip_text = str(item["name"])+" 선택 · 시식 전에는 결제하지 않아요."
	_compact_detail(560 if Catalog.is_farmed(id) else 440)


func _show_ingredient_experiment(item: Dictionary, chosen: int = -1) -> void:
	var projection: Dictionary=TrialPreview.candidates(state,str(item["id"]),_selected)
	var body := _modal_body("한 재료 실험")
	_modal.set_meta("view_kind","experiment")
	var back: Button=_modal.find_child("EditorDetailsBack",true,false) as Button
	back.pressed.disconnect(_close_modal)
	back.pressed.connect(_show_item.bind(item))
	if str(projection["error"])!="":
		body.add_child(_label(str(projection["error"]),17,RED))
		return
	body.add_child(_label(str(item["name"])+" · 넣기 전후 비교",20))
	var rows: Array=projection["rows"]
	if rows.size()==1: chosen=0
	if rows.size()>1:
		body.add_child(_label("가득 찬 토핑 중 바꿀 한 칸을 골라요. 아직 초안은 바뀌지 않아요.",15,MUTED))
		for index in rows.size():
			var button := _button(str(rows[index]["title"]),"EditorExperimentSlot_"+str(index),"check" if index==chosen else "",TEAL if index==chosen else CREAM)
			if index==chosen: button.add_theme_color_override("font_color",Color.WHITE)
			button.pressed.connect(_show_ingredient_experiment.bind(item,index))
			body.add_child(button)
	if chosen<0:
		_modal_footer("비교할 칸을 골라도 결제하지 않아요.","교체할 칸을 골라 주세요",func(): pass,true)
		_compact_detail(640)
		return
	var row: Dictionary=rows[chosen]
	var pair := HBoxContainer.new()
	pair.add_theme_constant_override("separation",12)
	body.add_child(pair)
	for data in [["지금 그릇",projection["base"]],["바꾸면",row["config"]]]:
		var column := VBoxContainer.new()
		column.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		pair.add_child(column)
		column.add_child(_label(str(data[0]),15,TEAL))
		var dish := Dish.new()
		dish.name="ExperimentDishBefore" if data[0]=="지금 그릇" else "ExperimentDishAfter"
		dish.custom_minimum_size=Vector2(100,100)
		column.add_child(dish)
		dish.set_config(data[1])
	var flavor := _label(str(row["flavor"]),18,TEAL)
	flavor.name="ExperimentFlavor"
	body.add_child(flavor)
	body.add_child(_label("원가 %s → %s (%+d원)" % [won(row["before_cost"]),won(row["after_cost"]),int(row["after_cost"])-int(row["before_cost"])],16))
	body.add_child(_label("기본 준비 %d초 → %d초 (%+d초)" % [row["before_seconds"],row["after_seconds"],int(row["after_seconds"])-int(row["before_seconds"])],16))
	var facts := _button("풍미·샘플·실험 목표", "EditorExperimentFacts", "info")
	facts.pressed.connect(_show_experiment_facts.bind(item,chosen,row))
	body.add_child(facts)
	var hint: String="초안에만 반영해요. 유료 시식이 끝나야 샘플을 쓰고 기록돼요."
	if str(row["sample_error"])!="":
		body.add_child(_label(str(row["sample_error"]),15,RED))
		hint="초안 편집은 가능해요. 시식 전에 부족한 샘플을 구하세요."
	var unavailable: bool=not state.ingredient_unlocked(str(item["id"]))
	var title: String="아직 발견하지 못했어요" if unavailable else ("초안에 반영" if bool(row["changed"]) else "현재와 같은 구성")
	_modal_footer(hint,title,_apply_experiment.bind(item,projection["base"],row),unavailable or not bool(row["changed"]) or bool(_info["busy"]))
	_compact_detail(640)


func _show_experiment_facts(item: Dictionary, chosen: int, row: Dictionary) -> void:
	var body := _modal_body("실험의 자세한 변화")
	_modal.set_meta("view_kind","experiment_facts")
	var back: Button=_modal.find_child("EditorDetailsBack",true,false) as Button
	back.pressed.disconnect(_close_modal)
	back.pressed.connect(_show_ingredient_experiment.bind(item,chosen))
	for axis in row["axes"]:
		body.add_child(_label("%s %d → %d (%+d)" % [axis["name"],axis["before"],axis["after"],axis["delta"]],16))
	body.add_child(_label("시식에 필요한 샘플",20))
	if (row["samples"] as Array).is_empty(): body.add_child(_label("연구 샘플이 필요한 재료가 없어요.",16))
	for sample in row["samples"]:
		body.add_child(_label("%s · 필요 %d / 보관 %d개" % [Catalog.find(str(sample["id"]))["name"],sample["needed"],sample["stock"]],16))
	body.add_child(_label("이 조합의 궁합",20))
	if (row["compat"] as Array).is_empty(): body.add_child(_label("현재 조합에 별도 궁합 규칙이 없어요.",16))
	for rule in row["compat"]: body.add_child(_label(str(rule["note"]),16))
	for direction in row["directions"]:
		body.add_child(_label("실험 목표 · "+str(direction["title"]),20,TEAL))
		for condition in direction["assessment"]["checks"]:
			body.add_child(_label(("충족 · " if bool(condition["met"]) else "남은 조건 · ")+str(condition["text"]),16))
	body.add_child(_label("조합의 예상 변화예요. 손님 취향에 따라 반응이 달라져요.",15,MUTED))
	_modal_footer("아직 구성·돈·샘플·기록을 바꾸지 않았어요.","비교로 돌아가기",_show_ingredient_experiment.bind(item,chosen))


func _apply_experiment(item: Dictionary, base: Dictionary, row: Dictionary) -> void:
	# Never apply a comparison to a different draft after another action changed
	# it. Rebuild the comparison, rather than overwriting any intervening edit.
	if not Check.same_config(state.draft_config,base):
		_show_ingredient_experiment(item)
		(_modal.find_child("DetailsActionHint",true,false) as Label).text="초안이 바뀌었어요. 새 비교를 확인하고 다시 골라 주세요."
		return
	var slot: String=str(item["id"]).get_slice("_",0)
	var group: String="" if slot=="topping" else ("noodle" if slot in ["noodle","cook"] else "broth")
	_apply_detail(item,group,int(row["replacement"]))


func _apply_detail(item: Dictionary, group: String, replacement: int = -1) -> void:
	var id: String = str(item["id"])
	var slot: String = id.get_slice("_",0)
	if replacement >= 0 and _selected != replacement:
		_emit("slot",{"index":replacement})
	if replacement >= 0 and _selected != replacement:
		push_error("교체할 토핑 칸을 선택하지 못했어요.")
		return
	var apply: Control = _modal.find_child("EditorDetailApply",true,false) as Control
	var point: Vector2 = apply.get_global_rect().get_center() if apply != null else _modal.get_global_rect().get_center()
	var was_replacing: bool = slot == "topping" and _selected >= 0
	var changed: bool = _choose_ingredient(slot,id,point)
	if _modal == null:
		return # The controller closed the sheet for a work transition and displays its notice.
	# An accepted same-ingredient replacement is a no-op. The controller clears
	# its slot only after success; close normally without a food-change animation.
	var accepted: bool = changed or (was_replacing and _selected < 0)
	if accepted:
		if group == "":
			_close_modal()
		else:
			_show_group(group)
	else:
		var hint: Label = _modal.find_child("DetailsActionHint",true,false) as Label
		hint.text = str(_info["warning"]) if str(_info["warning"]) != "" else str(_info["notice"])
		hint.add_theme_color_override("font_color",RED)


func _show_replacement(item: Dictionary) -> void:
	var body := _modal_body("교체할 칸 고르기")
	_modal.set_meta("view_kind","replacement")
	var back: Button = _modal.find_child("EditorDetailsBack",true,false) as Button
	back.pressed.disconnect(_close_modal)
	back.pressed.connect(_show_item.bind(item))
	body.add_child(_label("추가할 토핑 · "+str(item["name"]),18))
	body.add_child(_label("고르기 전에는 구성이 바뀌지 않아요.",14,MUTED))
	var portions: Array = Catalog.toppings_of(state.draft_config)
	for index in portions.size():
		var old: Dictionary = Catalog.find(str(portions[index]))
		var choose := _button("%d번 칸 · %s" % [index+1,str(old["name"])],"EditorReplace_"+str(index))
		choose.custom_minimum_size.y = 72
		choose.icon = Art.food(str(portions[index]))
		choose.expand_icon = true
		choose.add_theme_constant_override("icon_max_width",56)
		choose.add_theme_color_override("icon_normal_color",Color.WHITE)
		choose.disabled = bool(_info["busy"])
		choose.pressed.connect(_apply_detail.bind(item,"",index))
		body.add_child(choose)
	_compact_detail(186+portions.size()*76)


func _switch_group_tab(group: String, tab: String) -> void:
	_save_group_scroll()
	_group_tab[group] = tab
	_show_group(group)


func _show_group(group: String) -> void:
	var tab: String = str(_group_tab.get(group,group))
	if group=="noodle" and tab in ["noodle","method"]:
		_show_noodle_workshop()
		return
	if group=="broth" and tab=="broth":
		_show_broth_workshop()
		return
	var body := _modal_body("국물 만들기" if group == "broth" else "면 고르기")
	_modal.set_meta("view_kind","group")
	_modal.set_meta("group",group)
	_modal.set_meta("tab",tab)
	var back: Button = _modal.find_child("EditorDetailsBack",true,false) as Button
	back.pressed.disconnect(_close_modal)
	back.pressed.connect(_exit_group)
	var tabs := HBoxContainer.new()
	tabs.name = "IngredientGroupTabs"
	tabs.add_theme_constant_override("separation",4)
	var column: VBoxContainer = _modal.find_child("DetailsColumn",true,false) as VBoxContainer
	column.add_child(tabs)
	column.move_child(tabs,1)
	if str(_info.get("warning",""))!="":
		body.add_child(_label(str(_info["warning"]),15,RED))
	var definitions: Array = [["broth","육수"],["tare","타레"],["oil","향미유"],["method","공법"]] if group == "broth" else [["noodle","면"],["cook","익힘"],["method","반죽"]]
	for definition in definitions:
		var button := _button(str(definition[1]),"EditorGroupTab_"+str(definition[0]))
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size = Vector2(44,44)
		button.toggle_mode = true
		button.set_pressed_no_signal(tab == str(definition[0]))
		button.pressed.connect(_switch_group_tab.bind(group,str(definition[0])))
		tabs.add_child(button)
	var current := _label("",15,TEAL)
	current.name = "GroupCurrentChoice"
	body.add_child(current)
	if tab == "method":
		if group=="broth":
			body.add_child(_label("우림 방식은 원재료를 배합할 때 정해요. 다른 방식은 새 육수로 개발해 보세요.",17))
			var develop:=_button("육수 개발실 열기","BrothOpenWorkshop","chevron_right",GOLD)
			develop.pressed.connect(_show_broth_workshop)
			body.add_child(develop)
			_modal_footer("육수를 바꾸지 않고 돌아가요.","그릇으로 돌아가기",_exit_group)
			return
		body.add_child(_label("시식할 때 반영되는 공법이에요.",14,MUTED))
		for id in ProcessRules.ids(group):
			var method: Dictionary = ProcessRules.method(group,id)
			var button := _button(str(method["name"])+" · 랭크%d" % int(method["rank"]),"EditorProcess_"+group+"_"+id)
			button.disabled = bool(_info["busy"]) or state.rank() < int(method["rank"])
			button.toggle_mode = true
			button.pressed.connect(func(): _emit("process",{"slot":group,"id":id}); _refresh_modal_selections())
			body.add_child(button)
	else:
		for item in Catalog.all_items(tab):
			body.add_child(_ingredient_row(item,tab))
	_refresh_modal_selections()
	_modal_footer("선택은 바로 반영돼요. 시식 전까지 바꿀 수 있어요.","그릇으로 돌아가기",_exit_group)
	(body.get_parent() as ScrollContainer).set_deferred("scroll_vertical",int(_group_scroll.get(group+":"+tab,0)))


## Broth has its own focused task depth; the accepted ramen composition stays
## behind this sheet. Mixing never silently replaces the currently used broth.
## Four focused selection depths keep the formula readable as the pantry grows.
## The controller owns edits; browsing a source never applies a finished noodle.
func _show_noodle_workshop(page: String="formula") -> void:
	var review: Dictionary=state.noodle_review()
	var active: bool=review["active"]
	var formula: Dictionary=review["formula"]
	var item: Dictionary=review["product"]
	var method: Dictionary=ProcessRules.method("noodle",formula["method"])
	var body:=_modal_body("제면 개발실")
	_modal.set_meta("view_kind","noodle")
	var back: Button=_modal.find_child("EditorDetailsBack",true,false)
	back.disabled=active
	var tabs:=HBoxContainer.new()
	tabs.add_theme_constant_override("separation",4)
	var column: VBoxContainer=_modal.find_child("DetailsColumn",true,false)
	column.add_child(tabs)
	column.move_child(tabs,1)
	for definition in [["formula","배합"],["library","완성 면 %d" % review["recipes"].size()],["cook","익힘"]]:
		var button:=_button(definition[1],"NoodleTab_"+definition[0])
		button.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		button.toggle_mode=true
		button.set_pressed_no_signal(page==definition[0])
		button.disabled=active
		if definition[0]=="cook": button.pressed.connect(func(): _switch_group_tab("noodle","cook"))
		else: button.pressed.connect(_show_noodle_workshop.bind(definition[0]))
		tabs.add_child(button)
	if str(_info.get("warning",""))!="": body.add_child(_label(str(_info["warning"]),15,RED))
	if page=="library" and not active:
		body.add_child(_label("직접 반죽해 뽑은 면",22))
		if review["recipes"].is_empty(): body.add_child(_label("아직 완성한 면이 없어요. 밀가루와 배합수를 골라 첫 면을 만들어 보세요.",17,MUTED))
		for index in review["recipes"].size():
			var recipe: Dictionary=review["recipes"][index]["recipe"]
			var product: Dictionary=Noodle.product(recipe)
			var process: Dictionary=ProcessRules.method("noodle",recipe["method"])
			var panel:=PanelContainer.new()
			panel.mouse_filter=Control.MOUSE_FILTER_PASS
			panel.add_theme_stylebox_override("panel",_style(WHITE,TEAL))
			var card:=VBoxContainer.new()
			card.mouse_filter=Control.MOUSE_FILTER_PASS
			card.add_theme_constant_override("separation",10)
			panel.add_child(card)
			card.add_child(_picture(_ingredient_texture(product["id"]),Vector2(72,48)))
			card.add_child(_label(product["name"],21))
			card.add_child(_label(product["desc"],16,MUTED))
			card.add_child(_label("한 그릇 %s · 삶기 %d초" % [won(int(product["cost"])+int(process["cost"])),int(product["seconds"])+int(process["seconds"])],16,TEAL))
			var use:=_button("이 면으로 라멘 만들기","NoodleUse_"+str(index),"check",GOLD)
			use.disabled=bool(_info["busy"])
			use.pressed.connect(func(): _emit("noodle_use",{"index":index}); _close_modal())
			card.add_child(use)
			body.add_child(panel)
		_modal_footer("새로운 가루·배합수·굵기·숙성을 조합해 보세요.","다른 면 개발",_show_noodle_workshop)
		_compact_detail(minf(650,290+220*maxi(1,review["recipes"].size())))
		return
	if page in Noodle.FIELDS and not active:
		back.pressed.disconnect(_close_modal)
		back.pressed.connect(_show_noodle_workshop)
		var definitions: Array=Noodle.options(page) if page!="method" else []
		if page=="method":
			for id in ProcessRules.ids("noodle"): definitions.append(ProcessRules.method("noodle",id))
		for option in definitions:
			var panel:=PanelContainer.new()
			panel.mouse_filter=Control.MOUSE_FILTER_PASS
			panel.add_theme_stylebox_override("panel",_style(WHITE,TEAL if formula[page]==option["id"] else MUTED))
			var card:=VBoxContainer.new()
			card.mouse_filter=Control.MOUSE_FILTER_PASS
			card.add_theme_constant_override("separation",12)
			panel.add_child(card)
			if page in ["flour","water"]: card.add_child(_picture(PantryArt.texture(option["id"]),Vector2(64,64)))
			card.add_child(_label(option["name"],21))
			var desc: String=option.get("desc","식감 %d · 삶기 %d초" % [option.get("chew",0),option.get("seconds",0)])
			card.add_child(_label(desc,16,MUTED))
			card.add_child(_label("한 그릇 재료비 %s" % won(option["cost"]),16,TEAL))
			var next: Dictionary=formula.duplicate(true)
			next[page]=option["id"]
			var reason: String=Noodle.error(next,state.rank(),state.discovered_ingredients(),true)
			if option["id"]=="buckwheat":
				card.add_child(_label("산골 채집 · 라멘 시식 완료 때 연구 샘플 1개 사용",15,MUTED))
				_modal.set_meta("raw_material","buckwheat")
			var choose:=_button("선택됨" if formula[page]==option["id"] else "이 배합으로", "NoodleChoose_"+str(option["id"]),"check",GOLD)
			choose.disabled=bool(_info["busy"]) or reason!=""
			choose.pressed.connect(func(): _emit("noodle_set",{"field":page,"id":option["id"]}))
			card.add_child(choose)
			if reason!="": card.add_child(_label(reason,15,RED))
			body.add_child(panel)
		_modal_footer("선택해도 아직 면이 완성되거나 비용이 들지 않아요.","배합으로 돌아가기",_show_noodle_workshop)
		return
	var hero:=HBoxContainer.new()
	hero.add_theme_constant_override("separation",14)
	var work:=NoodleView.new()
	work.name="NoodleBoard"
	work.buckwheat=formula["flour"]=="buckwheat"
	work.thick=formula["cut"]=="thick"
	hero.add_child(work)
	var description:=VBoxContainer.new()
	description.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	hero.add_child(description)
	description.add_child(_label(item["name"],22))
	# These are component contributions. Keep a negative aroma visible; the
	# evaluator clamps only after adding the soup, seasoning and other parts.
	var flavor:=_label("식감 %d · 향 %+d" % [int(item["axes"]["chew"])+int(method["axes"]["chew"]),int(item["axes"]["aroma"])+int(method["axes"]["aroma"])],17,TEAL)
	flavor.name="NoodleExpectedFlavor"
	description.add_child(flavor)
	description.add_child(_label("한 그릇 %s\n삶기 %d초" % [won(review["cost"]),int(item["seconds"])+int(method["seconds"])],16,MUTED))
	body.add_child(hero)
	if active:
		var phase:=_label("",19,TEAL)
		phase.name="NoodlePhase"
		body.add_child(phase)
		var progress:=ProgressBar.new()
		progress.name="NoodleProgress"
		progress.custom_minimum_size.y=24
		body.add_child(progress)
		body.add_child(_label("반죽 → 밀기·숙성 → 면 뽑기",16,MUTED))
		_modal_footer("완료할 때 개발비 %s · 취소하면 비용이 들지 않아요." % won(review["cost"]),"제면 취소",func(): _emit("noodle_cancel"))
		_compact_detail(450)
		update_noodle_progress()
		return
	for definition in [["flour","밀가루"],["water","배합수"],["cut","면 굵기"],["method","반죽·숙성"]]:
		var selected: Dictionary=method if definition[0]=="method" else Noodle.option(definition[0],formula[definition[0]])
		var row:=_button(definition[1]+" · "+str(selected["name"]),"NoodleField_"+definition[0],"chevron_right")
		row.pressed.connect(_show_noodle_workshop.bind(definition[0]))
		body.add_child(row)
	body.add_child(_label("배합수 비율 · "+("고가수 40%" if formula["method"]=="moist" else ("저가수 30% · 숙성" if formula["method"]=="rested" else "기본 35%")),16,MUTED))
	_modal_footer(review["reason"] if review["reason"]!="" else "개발비 %s · 약 %d초 · 완성 후 직접 그릇에 넣어요." % [won(review["cost"]),int(ceil(review["duration"]))],"반죽하고 면 뽑기",func(): _emit("noodle_begin"),review["reason"]!="" or bool(_info["busy"]))
	_compact_detail(680)


func _show_noodle_source(id: String) -> void:
	_show_noodle_workshop("flour" if id=="noodle_buckwheat" else "cut")


func update_noodle_progress() -> void:
	if _modal==null or _modal.get_meta("view_kind","")!="noodle": return
	var progress: ProgressBar=_modal.find_child("NoodleProgress",true,false)
	if progress==null: return
	var review: Dictionary=state.noodle_review()
	progress.value=100.0*float(review["progress"])
	var phase: Label=_modal.find_child("NoodlePhase",true,false)
	phase.text=["반죽을 치대는 중","밀기·숙성하는 중","면을 뽑는 중"][mini(2,int(float(review["progress"])*3.0))]+" · %d%%" % int(round(progress.value))
	var board: Control=_modal.find_child("NoodleBoard",true,false)
	board.progress=review["progress"]


func _show_broth_workshop(page: String="blend") -> void:
	if _modal!=null and _modal.get_meta("view_kind","")=="broth":
		var previous_scroll: ScrollContainer=_modal.find_child("DetailsScroll",true,false)
		_broth_scroll[str(_modal.get_meta("scroll_key",""))]=previous_scroll.scroll_vertical
	_broth_page=page
	var review: Dictionary=state.broth_review()
	var active: bool=bool(review["active"])
	var body:=_modal_body("육수 개발실")
	_modal.set_meta("view_kind","broth")
	var scroll_key: String=page+":"+_broth_category
	_modal.set_meta("scroll_key",scroll_key)
	var back: Button=_modal.find_child("EditorDetailsBack",true,false)
	back.disabled=active
	var tabs:=HBoxContainer.new()
	tabs.add_theme_constant_override("separation",4)
	var column: VBoxContainer=_modal.find_child("DetailsColumn",true,false)
	column.add_child(tabs)
	column.move_child(tabs,1)
	if str(_info.get("warning",""))!="": body.add_child(_label(str(_info["warning"]),15,RED))
	for definition in [["blend","배합"],["library","육수 %d" % review["recipes"].size()],["seasoning","간·향미"]]:
		var button:=_button(definition[1],"BrothTab_"+definition[0])
		button.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		button.toggle_mode=true
		button.set_pressed_no_signal(page==definition[0])
		button.disabled=active
		if definition[0]=="seasoning":
			button.pressed.connect(func(): _group_tab["broth"]="tare"; _show_group("broth"))
		else: button.pressed.connect(_show_broth_workshop.bind(definition[0]))
		tabs.add_child(button)
	if page=="library" and not active:
		body.add_child(_label("직접 우려낸 육수",22))
		if review["recipes"].is_empty(): body.add_child(_label("아직 완성한 육수가 없어요. 배합에서 주재료를 골라 첫 육수를 만들어 보세요.",17,MUTED))
		for index in review["recipes"].size():
			var recipe: Dictionary=review["recipes"][index]["recipe"]
			var item: Dictionary=Broth.product(recipe)
			var panel:=PanelContainer.new()
			panel.add_theme_stylebox_override("panel",_style(WHITE,TEAL))
			var card:=VBoxContainer.new()
			card.add_theme_constant_override("separation",10)
			panel.add_child(card)
			card.add_child(_label(item["name"],21))
			card.add_child(_label(item["desc"],16,MUTED))
			var method: Dictionary=ProcessRules.method("broth",recipe["method"])
			card.add_child(_label("한 그릇 %s · 준비 %d초" % [won(int(item["cost"])+int(method["cost"])),int(item["seconds"])+int(method["seconds"])],16,TEAL))
			var use:=_button("이 육수로 라멘 만들기","BrothUse_"+str(index),"check",GOLD)
			use.disabled=bool(_info["busy"])
			use.pressed.connect(func(): _emit("broth_use",{"index":index}); _close_modal())
			card.add_child(use)
			body.add_child(panel)
		_modal_footer("배합을 바꿔 다른 맛의 육수도 개발할 수 있어요.","새 육수 배합",_show_broth_workshop.bind("blend"))
		_compact_detail(minf(650,270+180*maxi(1,review["recipes"].size())))
		return
	var hero:=HBoxContainer.new()
	hero.add_theme_constant_override("separation",14)
	var pot:=WorkView.new()
	pot.name="BrothPot"
	pot.custom_minimum_size=Vector2(100,112)
	pot.mouse_filter=Control.MOUSE_FILTER_IGNORE
	hero.add_child(pot)
	var description:=VBoxContainer.new()
	description.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	hero.add_child(description)
	var item: Dictionary=review["product"]
	description.add_child(_label("원재료 배합" if item.is_empty() else item["name"],22))
	description.add_child(_label("주재료에 향채를 더해 나만의 육수를 만들어요." if item.is_empty() else item["desc"],15,MUTED))
	if not item.is_empty():
		var extraction: Dictionary=ProcessRules.method("broth",review["blend"]["method"])
		var richness: int=clampi(int(item["axes"]["rich"])+int(extraction["axes"]["rich"]),0,10)
		var aroma: int=clampi(int(item["axes"]["aroma"])+int(extraction["axes"]["aroma"]),0,10)
		description.add_child(_label("육수 예상 · 진함 %d / 향 %d" % [richness,aroma],15,TEAL))
		if item["combo"]!="": description.add_child(_label(item["combo"],14,TEAL))
	body.add_child(hero)
	var progress:=ProgressBar.new()
	progress.name="BrothProgress"
	progress.custom_minimum_size.y=22
	progress.visible=active
	body.add_child(progress)
	var phase:=_label("",17,TEAL)
	phase.name="BrothPhase"
	phase.visible=active
	body.add_child(phase)
	if active:
		body.add_child(_label("선택한 원재료의 맛과 향을 우려내고 있어요.",16,MUTED))
		_modal_footer("완료할 때 개발비 %s · 취소하면 비용 없이 배합으로 돌아가요." % won(review["cost"]),"우림 취소",func(): _emit("broth_cancel"))
		_compact_detail(440)
		update_broth_progress()
		return
	var ids: Array=review["blend"]["ingredients"]
	body.add_child(_label("배합 %d / %d칸 · 랭크가 오르면 한 칸씩 추가" % [ids.size(),review["capacity"]],16))
	var portions:=GridContainer.new()
	portions.columns=2
	portions.add_theme_constant_override("h_separation",6)
	portions.add_theme_constant_override("v_separation",6)
	body.add_child(portions)
	for index in int(review["capacity"]):
		var filled: bool=index<ids.size()
		var button:=_button(str(Broth.material(ids[index])["name"])+"  −" if filled else "빈 배합 칸","BrothPortion_"+str(index))
		button.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		button.disabled=active or not filled
		button.tooltip_text="이 원재료 한 분량 빼기" if filled else "아래 원재료 목록에서 추가"
		if filled:
			button.icon=PantryArt.texture(ids[index])
			button.expand_icon=true
			button.add_theme_color_override("icon_normal_color",Color.WHITE)
			button.add_theme_color_override("icon_hover_color",Color.WHITE)
			button.pressed.connect(func(): _emit("broth_remove",{"index":index}))
		portions.add_child(button)
	var filters:=HBoxContainer.new()
	filters.add_theme_constant_override("separation",4)
	body.add_child(filters)
	for category_name in ["전체","뼈","해산물","향채"]:
		var filter:=_button(category_name,"BrothCategory_"+category_name)
		filter.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		filter.toggle_mode=true
		filter.set_pressed_no_signal(category_name==_broth_category)
		filter.disabled=active
		filter.pressed.connect(func(): _broth_category=category_name; _show_broth_workshop())
		filters.add_child(filter)
	for material in Broth.DATA:
		if _broth_category!="전체" and material["category"]!=_broth_category: continue
		var row:=HBoxContainer.new()
		row.add_theme_constant_override("separation",10)
		row.add_child(_picture(PantryArt.texture(material["id"]),Vector2(40,44)))
		var content:=VBoxContainer.new()
		content.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		content.add_child(_label(material["name"],18))
		var unlocked: bool=not material.has("source") or state.ingredient_unlocked(material["source"])
		content.add_child(_label("%s · %d초" % [won(material["cost"]),material["seconds"]] if unlocked else material["source_name"],14,TEAL if unlocked else MUTED))
		if material["id"]=="sardine" and unlocked: content.add_child(_label("연구 샘플 %d개" % state.sample_stock("broth_roasted_sardine"),14,MUTED))
		row.add_child(content)
		var add:=_button("","BrothAdd_"+material["id"],"add",GOLD)
		add.tooltip_text=material["name"]+" 한 분량 추가"
		add.disabled=active or not unlocked or ids.size()>=int(review["capacity"]) or (material["id"]=="sardine" and ids.has("sardine"))
		add.pressed.connect(func(): _emit("broth_add",{"id":material["id"]}))
		var detail:=_button("","BrothDetail_"+material["id"],"info")
		detail.tooltip_text=material["name"]+" 성질과 구입처"
		detail.disabled=active
		detail.pressed.connect(_show_broth_material.bind(material))
		row.add_child(detail)
		row.add_child(add)
		body.add_child(row)
	body.add_child(_label("우림 방식",19))
	for method_id in ProcessRules.ids("broth"):
		var method: Dictionary=ProcessRules.method("broth",method_id)
		var button:=_button(method["name"],"BrothMethod_"+method_id)
		button.toggle_mode=true
		button.set_pressed_no_signal(review["blend"]["method"]==method_id)
		button.disabled=active or state.rank()<int(method["rank"])
		button.pressed.connect(func(): _emit("broth_method",{"method":method_id}))
		body.add_child(button)
		body.add_child(_label(method["desc"]+(" · 랭크%d부터" % method["rank"] if state.rank()<int(method["rank"]) else ""),14,MUTED))
	var hint: String="완료할 때 개발비 %s · 우림 약 %.1f초" % [won(review["cost"]),review["duration"]]
	if review["reason"]!="": hint=review["reason"]
	if ids.has("sardine"): hint+="\n정어리 샘플은 라멘 시제품 완성 때 1개 사용해요."
	_modal_footer(hint,"우림 취소" if active else "육수 우리기",func(): _emit("broth_cancel" if active else "broth_begin"),not active and (review["reason"]!="" or bool(_info["busy"])))
	(body.get_parent() as ScrollContainer).set_deferred("scroll_vertical",int(_broth_scroll.get(scroll_key,0)))
	update_broth_progress()


func _show_broth_material(material: Dictionary) -> void:
	var previous: ScrollContainer=_modal.find_child("DetailsScroll",true,false)
	_broth_scroll[str(_modal.get_meta("scroll_key",""))]=previous.scroll_vertical
	var body:=_modal_body(material["name"])
	_modal.set_meta("raw_material",material["id"])
	var back: Button=_modal.find_child("EditorDetailsBack",true,false)
	back.pressed.disconnect(_close_modal)
	back.pressed.connect(_show_broth_workshop)
	body.add_child(_picture(PantryArt.texture(material["id"]),Vector2(96,96)))
	body.add_child(_label("주재료 · 육수의 바탕이 돼요." if material["base"] else "향채 · 주재료에 맛과 향을 더해요.",18))
	body.add_child(_label(Catalog.axes_text(material),17,TEAL))
	body.add_child(_label("한 분량 %s · 준비 %d초" % [won(material["cost"]),material["seconds"]],17))
	body.add_child(_label(material.get("source_name","가게 기본 공급처 · 개발 후 통상 원가로 공급"),16,MUTED))
	if material["id"]=="sardine": body.add_child(_label("라멘 시제품이 완성될 때 연구 샘플을 1개 써요. 한 배합에는 한 분량까지 넣어요.",16))
	_modal_footer("한 분량마다 배합 한 칸을 사용해요.","배합으로 돌아가기",_show_broth_workshop)


func _show_raw_broth_source(id: String) -> void:
	var material: Dictionary=Broth.material_for_broth(id)
	if material.is_empty():
		push_error("육수 원재료 연결이 없어요: "+id)
		return
	_broth_category=material["category"]
	_show_broth_workshop()
	_show_broth_material(material)


func update_broth_progress() -> void:
	if _modal==null or _modal.get_meta("view_kind","")!="broth": return
	var review: Dictionary=state.broth_review()
	var progress: ProgressBar=_modal.find_child("BrothProgress",true,false)
	if progress==null: return
	progress.value=float(review["progress"])*100.0
	var phase: Label=_modal.find_child("BrothPhase",true,false)
	phase.text=["재료 넣기","향을 우려내는 중","완성 육수 정리"][mini(2,int(float(review["progress"])*3.0))]+" · %d%%" % int(round(progress.value))
	var pot: WorkView=_modal.find_child("BrothPot",true,false)
	var cfg: Dictionary=state.draft_config.duplicate(true)
	if not review["product"].is_empty(): cfg["broth"]=review["product"]["id"]
	# Hold the existing pot illustration in its soup phase throughout brewing;
	# the later noodle/plating phases belong to ramen, not raw broth production.
	pot.set_state(float(review["progress"])*0.44,cfg)


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
	var fresh: Array=_info.get("new_directions",[])
	var new_themes: Array=_info.get("new_themes",[])
	var actual: Array[String]=[]
	for definition in Directions.catalog():
		if bool(Directions.assess(str(definition["id"]),record["config"])["matched"]):
			actual.append(str(definition["title"]))
	if not fresh.is_empty() or not new_themes.is_empty() or not actual.is_empty():
		var title: String=(str(fresh[0])+" · 새 방향 발견") if not fresh.is_empty() else ((str(new_themes[0])+" · 새 연구 기록") if not new_themes.is_empty() else str(actual[0])+" · 완성한 방향")
		var found := _button(title,"EditorDiscoveryReward","check",GOLD)
		found.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		found.custom_minimum_size.y=56
		found.pressed.connect(_show_result_discoveries)
		_rows.add_child(found)
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


func _show_result_discoveries() -> void:
	var record: Dictionary=state.get_record(state.last_feedback_record_id)
	var body := _modal_body("이번 시식의 발견")
	_modal.set_meta("view_kind","result_discoveries")
	if record.is_empty():
		body.add_child(_label("확인할 시식 노트가 없어요.",17,RED))
		return
	for title in _info.get("new_directions",[]):
		body.add_child(_label("새 방향 발견 · "+str(title),21,TEAL))
	for title in _info.get("new_themes",[]):
		body.add_child(_label("새 연구 기록 · "+str(title),18,TEAL))
	var tested: Array[String]=Directions.tested_ids(state.records())
	body.add_child(_label("보관 중인 시식 노트 · 연구 방향 %d/%d" % [tested.size(),Directions.catalog().size()],18))
	for definition in Directions.catalog():
		var assessment: Dictionary=Directions.assess(str(definition["id"]),record["config"])
		if not bool(assessment["matched"]): continue
		body.add_child(_label("이 그릇으로 완성 · "+str(definition["title"]),20,TEAL))
		for condition in assessment["checks"]:
			body.add_child(_label(str(condition["text"]),16))
	body.add_child(_label("실제로 시식한 노트를 기준으로 확인해요. 방향이 같아도 재료·풍미·손님 반응은 달라질 수 있어요.",16,MUTED))
	_modal_footer("이 시식의 비용과 샘플은 완성할 때 반영했어요.","시식 결과로",_close_modal)


func play_discovery_reveal() -> void:
	# Called only after a real completed tasting, never by rendering or customer
	# selection. Revisiting/reloading results does not replay the reward animation.
	var badge: Control=_rows.find_child("EditorDiscoveryReward",true,false) as Control
	if badge==null: return
	badge.pivot_offset=badge.size*0.5
	badge.scale=Vector2.ONE*0.94
	var tween:=badge.create_tween()
	tween.tween_property(badge,"scale",Vector2.ONE,0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


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
			find.pressed.connect(func(): _close_modal(); _emit("direction_source", {"id": id}))
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
				var group: String = "noodle" if slot in ["noodle", "cook"] else "broth"
				# A directed experiment must open its actual category, even if the
				# player last visited a different tab. Method clues share slot names.
				var method_changed: bool = slot in ProcessRules.SLOTS and ProcessRules.selected(record["config"].get("process",{}),slot) != ProcessRules.selected(clue["config"].get("process",{}),slot)
				_switch_group_tab(group,"method" if method_changed else slot))
		body.add_child(go)


func _primary_action() -> void:
	if _mode==0 and state.broth_ready() and not state.noodle_ready():
		_show_noodle_workshop()
		return
	if _mode==0 and not state.broth_ready():
		_show_broth_workshop()
		return
	_close_modal()
	_emit("serve" if _mode == 1 else "taste")


func _layout() -> void:
	if _content == null:
		return
	var wide: bool = size.x >= 720
	_content.columns = 2 if wide else 1
	var horizontal: int = maxi(4, int((size.x - 1180.0) * 0.5))
	var insets: Vector4 = _device_insets()
	for edge in ["left", "right"]:
		_root_margin.add_theme_constant_override("margin_" + edge, horizontal + int(insets.x if edge == "left" else insets.z))
	_root_margin.add_theme_constant_override("margin_top", 3 + int(insets.y))
	_root_margin.add_theme_constant_override("margin_bottom", 3 + int(insets.w))
	var stage_height: float = 300.0 if _mode == 1 else (372.0 if state == null or state.topping_slots() < 4 else 430.0)
	if not wide:
		# Safe areas or a shorter window consume real space. Share that loss with
		# the preview so the independently scrollable list retains usable height.
		var usable_height: float = size.y - insets.y - insets.w
		stage_height = maxf(260.0 if _mode == 1 else 300.0, stage_height - maxf(0.0, 844.0 - usable_height) * 0.35)
	_stage.custom_minimum_size = Vector2(0, stage_height)
	_stage.size_flags_vertical = Control.SIZE_EXPAND_FILL if wide else Control.SIZE_FILL
	_arrange_stage.call_deferred()
	_arrange_modal()


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
		return # Container's first real resize finishes the layout.
	var capacity: int = 2 if state == null else state.topping_slots()
	var slot_height: float = maxf(_slot_surface.get_combined_minimum_size().y, 36.0 if _mode == 1 else (162.0 if capacity >= 4 else 110.0))
	_summary.position = Vector2(8,26)
	_summary.size = Vector2(dimensions.x-16,60)
	var slot_width: float = minf(dimensions.x-20,310.0 if capacity == 3 else 224.0)
	_slot_surface.position = Vector2((dimensions.x-slot_width)*0.5,dimensions.y-slot_height-4)
	_slot_surface.size = Vector2(slot_width,slot_height)
	var dish_height: float = maxf(120,dimensions.y-slot_height-104)
	_dish.position = Vector2(28,104)
	_dish.size = Vector2(dimensions.x-56,dish_height)
	_pointer_left.position = Vector2(dimensions.x*0.30,82)
	_pointer_left.size = Vector2(40,58)
	_pointer_right.position = Vector2(dimensions.x*0.67,82)
	_pointer_right.size = Vector2(40,58)
