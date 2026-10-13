extends Control
## 라멘 아틀리에 메인 화면. 모든 판단(평가/판매/저장 검증)은 domain·services가 하고 여기서는 표시와 입력만 맡는다.
## 레이아웃: 폭 720 미만이면 세로(그릇 위, 탭 아래), 아니면 가로(그릇 왼쪽, 탭 오른쪽).

const Catalog = preload("res://scripts/domain/ingredient_catalog.gd")
const Customers = preload("res://scripts/domain/customer_catalog.gd")
const Check = preload("res://scripts/domain/data_check.gd")
const Evaluator = preload("res://scripts/domain/recipe_evaluator.gd")
const Sim = preload("res://scripts/domain/sales_simulator.gd")
const GameStateScript = preload("res://scripts/domain/game_state.gd")
const SaveServiceScript = preload("res://scripts/services/save_service.gd")
const LocationScript = preload("res://scripts/services/data_location.gd")
const BowlViewScript = preload("res://scripts/ui/bowl_view.gd")
const StarMeterScript = preload("res://scripts/ui/star_meter.gd")

const INK: Color = Color(0.17, 0.15, 0.13)
const PAPER: Color = Color(0.96, 0.94, 0.88)
const PAPER_LIGHT: Color = Color(0.99, 0.97, 0.92)
const PAPER_DARK: Color = Color(0.91, 0.86, 0.75)
const VERMILION: Color = Color(0.78, 0.26, 0.17)
const TEAL: Color = Color(0.25, 0.48, 0.46)
const MUTED: Color = Color(0.43, 0.38, 0.32)
const LINE: Color = Color(0.78, 0.70, 0.56)
const MIN_TOUCH: float = 48.0
const WIDE_BREAKPOINT: float = 720.0

const TAB_LAB: int = 0
const TAB_FEEDBACK: int = 1
const TAB_NOTEBOOK: int = 2
const TAB_SERVE: int = 3

## 테스트/QA가 ready 전에 주입할 수 있다. 비어 있으면 명령줄에서 결정한다.
var data_location: Dictionary = {}

var state: GameStateScript
var saver: SaveServiceScript
var save_locked: bool = false

var tabs: TabContainer
var _body: BoxContainer
var _bowl_card: PanelContainer
var _bowl: BowlViewScript
var _bowl_caption: Label
var _day_label: Label
var _wallet_label: Label
var _load_label: Label
var _save_label: Label
var _dev_label: Label
var _banner: PanelContainer
var _banner_label: Label
var _reset_button: Button

var _name_edit: LineEdit
var _mode_label: Label
var _price_label: Label
var _profile_label: Label
var _compat_label: Label
var _taste_button: Button
var _taste_message: Label
var _groups: Dictionary = {}
var _buttons: Dictionary = {}
var _desc_labels: Dictionary = {}

var _feedback_box: VBoxContainer
var _notebook_count: Label
var _notebook_box: VBoxContainer
var _serve_intro: Label
var _serve_menu: Label
var _serve_forecast: Label
var _serve_button: Button
var _serve_message: Label
var _report_label: Label

var _pending_delete_id: int = 0


func _ready() -> void:
	theme = _build_theme()
	if data_location.is_empty():
		data_location = LocationScript.from_process()
	state = GameStateScript.new()
	saver = SaveServiceScript.new(str(data_location["dir"]))
	_build_ui()
	_load_save()
	_refresh_all()
	tabs.tab_changed.connect(_on_tab_changed)
	resized.connect(_apply_layout)
	_apply_layout()


func _notification(what: int) -> void:
	if state == null:
		return
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
		_persist()


# ---------- 테마/스타일 ----------

func _box(bg: Color, border: Color, border_w: int, radius: int, mx: float, my: float) -> StyleBoxFlat:
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(border_w)
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = mx
	sb.content_margin_right = mx
	sb.content_margin_top = my
	sb.content_margin_bottom = my
	return sb


func _build_theme() -> Theme:
	var t: Theme = Theme.new()
	var font: Font = load("res://assets/fonts/GowunDodum-Regular.ttf") as Font
	if font != null:
		t.default_font = font
	t.default_font_size = 18
	t.set_color("font_color", "Label", INK)

	t.set_stylebox("normal", "Button", _box(PAPER_LIGHT, LINE, 2, 10, 10.0, 8.0))
	t.set_stylebox("hover", "Button", _box(PAPER_DARK, LINE, 2, 10, 10.0, 8.0))
	t.set_stylebox("pressed", "Button", _box(TEAL, INK, 2, 10, 10.0, 8.0))
	t.set_stylebox("hover_pressed", "Button", _box(TEAL.darkened(0.1), INK, 2, 10, 10.0, 8.0))
	t.set_stylebox("disabled", "Button", _box(PAPER_DARK, PAPER_DARK, 2, 10, 10.0, 8.0))
	var focus: StyleBoxFlat = _box(Color(0, 0, 0, 0), TEAL, 3, 10, 10.0, 8.0)
	focus.draw_center = false
	t.set_stylebox("focus", "Button", focus)
	t.set_color("font_color", "Button", INK)
	t.set_color("font_hover_color", "Button", INK)
	t.set_color("font_focus_color", "Button", INK)
	t.set_color("font_pressed_color", "Button", PAPER)
	t.set_color("font_hover_pressed_color", "Button", PAPER)
	t.set_color("font_disabled_color", "Button", MUTED)

	t.set_stylebox("normal", "LineEdit", _box(Color(1, 1, 1), LINE, 2, 8, 10.0, 8.0))
	t.set_stylebox("focus", "LineEdit", _box(Color(1, 1, 1), TEAL, 3, 8, 10.0, 8.0))
	t.set_stylebox("read_only", "LineEdit", _box(PAPER_DARK, LINE, 2, 8, 10.0, 8.0))
	t.set_color("font_color", "LineEdit", INK)
	t.set_color("font_uneditable_color", "LineEdit", MUTED)
	t.set_color("caret_color", "LineEdit", VERMILION)

	t.set_stylebox("panel", "PanelContainer", _box(PAPER_LIGHT, LINE, 2, 12, 12.0, 10.0))

	var tab_sel: StyleBoxFlat = _box(VERMILION, VERMILION, 0, 10, 16.0, 11.0)
	var tab_un: StyleBoxFlat = _box(PAPER_DARK, PAPER_DARK, 0, 10, 16.0, 11.0)
	var tab_hover: StyleBoxFlat = _box(PAPER_LIGHT, LINE, 1, 10, 16.0, 11.0)
	t.set_stylebox("tab_selected", "TabContainer", tab_sel)
	t.set_stylebox("tab_unselected", "TabContainer", tab_un)
	t.set_stylebox("tab_hovered", "TabContainer", tab_hover)
	t.set_stylebox("tab_focus", "TabContainer", tab_hover)
	t.set_stylebox("panel", "TabContainer", _box(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0, 0, 0.0, 6.0))
	t.set_color("font_selected_color", "TabContainer", PAPER)
	t.set_color("font_unselected_color", "TabContainer", INK)
	t.set_color("font_hovered_color", "TabContainer", INK)
	t.set_font_size("font_size", "TabContainer", 19)
	return t


# ---------- UI 구성 보조 ----------

func _label(text: String, font_size: int = 18, color: Color = INK) -> Label:
	var l: Label = Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	return l


func _button(text: String, node_name: String) -> Button:
	var b: Button = Button.new()
	b.name = node_name
	b.text = text
	b.custom_minimum_size = Vector2(0.0, MIN_TOUCH)
	return b


func _primary(b: Button) -> void:
	b.add_theme_stylebox_override("normal", _box(VERMILION, INK, 2, 12, 14.0, 10.0))
	b.add_theme_stylebox_override("hover", _box(VERMILION.lightened(0.1), INK, 2, 12, 14.0, 10.0))
	b.add_theme_stylebox_override("pressed", _box(VERMILION.darkened(0.2), INK, 2, 12, 14.0, 10.0))
	b.add_theme_stylebox_override("disabled", _box(PAPER_DARK, PAPER_DARK, 2, 12, 14.0, 10.0))
	b.add_theme_color_override("font_color", PAPER_LIGHT)
	b.add_theme_color_override("font_hover_color", PAPER_LIGHT)
	b.add_theme_color_override("font_pressed_color", PAPER_LIGHT)
	b.add_theme_font_size_override("font_size", 20)
	b.custom_minimum_size = Vector2(0.0, 56.0)


func _card(node_name: String = "") -> PanelContainer:
	var p: PanelContainer = PanelContainer.new()
	if node_name != "":
		p.name = node_name
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return p


func _vbox(sep: int = 8) -> VBoxContainer:
	var v: VBoxContainer = VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return v


func _clear(container: Node) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()


func _make_tab(node_name: String, title: String) -> VBoxContainer:
	var sc: ScrollContainer = ScrollContainer.new()
	sc.name = node_name
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	tabs.add_child(sc)
	tabs.set_tab_title(tabs.get_tab_count() - 1, title)
	var margin: MarginContainer = MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_left", 4)
	margin.add_theme_constant_override("margin_right", 4)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_bottom", 16)
	sc.add_child(margin)
	var box: VBoxContainer = _vbox(12)
	margin.add_child(box)
	return box


static func _won(n: int) -> String:
	var digits: String = str(absi(n))
	var out: String = ""
	var count: int = 0
	for i in range(digits.length() - 1, -1, -1):
		out = digits[i] + out
		count += 1
		if count % 3 == 0 and i > 0:
			out = "," + out
	return ("-" if n < 0 else "") + out + "원"


# ---------- UI 구성 ----------

func _build_ui() -> void:
	var paper: ColorRect = ColorRect.new()
	paper.name = "Paper"
	paper.color = PAPER
	paper.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(paper)

	var frame: MarginContainer = MarginContainer.new()
	frame.name = "Frame"
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.add_theme_constant_override("margin_left", 10)
	frame.add_theme_constant_override("margin_right", 10)
	frame.add_theme_constant_override("margin_top", 10)
	frame.add_theme_constant_override("margin_bottom", 10)
	add_child(frame)
	var root: VBoxContainer = _vbox(8)
	frame.add_child(root)

	root.add_child(_build_header())

	_body = BoxContainer.new()
	_body.name = "Body"
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_theme_constant_override("separation", 10)
	root.add_child(_body)

	_bowl_card = PanelContainer.new()
	_bowl_card.name = "BowlCard"
	var bowl_col: VBoxContainer = _vbox(6)
	_bowl_card.add_child(bowl_col)
	_bowl = BowlViewScript.new()
	_bowl.name = "BowlView"
	_bowl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_bowl.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_bowl.custom_minimum_size = Vector2(0.0, 110.0)
	bowl_col.add_child(_bowl)
	_bowl_caption = _label("", 15, INK)
	_bowl_caption.name = "BowlCaption"
	_bowl_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bowl_col.add_child(_bowl_caption)
	_body.add_child(_bowl_card)

	tabs = TabContainer.new()
	tabs.name = "MainTabs"
	tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body.add_child(tabs)
	_build_lab(_make_tab("TabLab", "연구"))
	_build_feedback(_make_tab("TabFeedback", "시식"))
	_build_notebook(_make_tab("TabNotebook", "노트"))
	_build_serve(_make_tab("TabServe", "영업"))

	root.add_child(_build_footer())


func _build_header() -> PanelContainer:
	var header: PanelContainer = _card("Header")
	header.add_theme_stylebox_override("panel", _box(VERMILION, INK, 2, 12, 14.0, 8.0))
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	header.add_child(row)
	var title_box: VBoxContainer = _vbox(0)
	var title: Label = _label("라멘 아틀리에", 24, PAPER_LIGHT)
	title.name = "TitleLabel"
	var sub: Label = _label("레시피 연구소", 14, PAPER_DARK)
	title_box.add_child(title)
	title_box.add_child(sub)
	row.add_child(title_box)
	var stats: VBoxContainer = VBoxContainer.new()
	stats.add_theme_constant_override("separation", 0)
	_day_label = Label.new()
	_day_label.name = "DayLabel"
	_day_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_day_label.add_theme_font_size_override("font_size", 20)
	_day_label.add_theme_color_override("font_color", PAPER_LIGHT)
	_wallet_label = Label.new()
	_wallet_label.name = "WalletLabel"
	_wallet_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_wallet_label.add_theme_font_size_override("font_size", 16)
	_wallet_label.add_theme_color_override("font_color", PAPER_LIGHT)
	stats.add_child(_day_label)
	stats.add_child(_wallet_label)
	row.add_child(stats)
	return header


func _build_footer() -> VBoxContainer:
	var footer: VBoxContainer = _vbox(4)
	footer.name = "Footer"
	_banner = _card("SaveBanner")
	_banner.add_theme_stylebox_override("panel", _box(Color(0.98, 0.88, 0.82), VERMILION, 2, 10, 12.0, 8.0))
	var bb: VBoxContainer = _vbox(6)
	_banner.add_child(bb)
	_banner_label = _label("", 15, INK)
	_banner_label.name = "SaveBannerLabel"
	bb.add_child(_banner_label)
	_reset_button = _button("손상 파일 보관 후 새로 시작", "ResetSaveButton")
	_reset_button.pressed.connect(_on_reset_save)
	bb.add_child(_reset_button)
	_banner.visible = false
	footer.add_child(_banner)
	_load_label = _label("", 13, MUTED)
	_load_label.name = "LoadStatusLabel"
	footer.add_child(_load_label)
	_save_label = _label("", 13, MUTED)
	_save_label.name = "SaveStatusLabel"
	footer.add_child(_save_label)
	_dev_label = _label("", 12, MUTED)
	_dev_label.name = "DevSaveLabel"
	_dev_label.visible = false
	footer.add_child(_dev_label)
	return footer


func _build_lab(box: VBoxContainer) -> void:
	var name_card: PanelContainer = _card("NameCard")
	var nb: VBoxContainer = _vbox(6)
	name_card.add_child(nb)
	nb.add_child(_label("시제품 이름", 16, MUTED))
	_name_edit = LineEdit.new()
	_name_edit.name = "RecipeNameEdit"
	_name_edit.custom_minimum_size = Vector2(0.0, MIN_TOUCH)
	_name_edit.max_length = Check.NAME_MAX
	_name_edit.placeholder_text = "예: 새벽 돈코츠"
	_name_edit.text_changed.connect(_on_name_changed)
	nb.add_child(_name_edit)
	_mode_label = _label("", 15, TEAL)
	_mode_label.name = "ModeLabel"
	nb.add_child(_mode_label)
	var new_button: Button = _button("새 레시피 시작", "NewRecipeButton")
	new_button.pressed.connect(_on_new_recipe)
	nb.add_child(new_button)
	box.add_child(name_card)

	for slot in Catalog.SLOTS:
		var sec: PanelContainer = _card("Section_" + slot)
		var sb: VBoxContainer = _vbox(8)
		sec.add_child(sb)
		sb.add_child(_label(str(Catalog.SLOT_NAMES[slot]), 20, VERMILION))
		var flow: HFlowContainer = HFlowContainer.new()
		flow.name = "Flow_" + slot
		flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		flow.add_theme_constant_override("h_separation", 8)
		flow.add_theme_constant_override("v_separation", 8)
		var group: ButtonGroup = ButtonGroup.new()
		_groups[slot] = group
		for item in Catalog.items(slot):
			var d: Dictionary = item
			flow.add_child(_make_option(slot, d, group))
		sb.add_child(flow)
		var desc: Label = _label("", 15, INK)
		desc.name = "Desc_" + slot
		_desc_labels[slot] = desc
		sb.add_child(desc)
		box.add_child(sec)

	var price_card: PanelContainer = _card("PriceCard")
	var pb: VBoxContainer = _vbox(8)
	price_card.add_child(pb)
	pb.add_child(_label("판매 가격", 20, VERMILION))
	_price_label = _label("", 24, INK)
	_price_label.name = "PriceLabel"
	pb.add_child(_price_label)
	var price_row: HBoxContainer = HBoxContainer.new()
	price_row.add_theme_constant_override("separation", 8)
	for spec in [["PriceDown500", "-500", -500], ["PriceDown100", "-100", -100], ["PriceUp100", "+100", 100], ["PriceUp500", "+500", 500]]:
		var arr: Array = spec
		var pbtn: Button = _button(str(arr[1]), str(arr[0]))
		pbtn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		pbtn.pressed.connect(_on_price_step.bind(int(arr[2])))
		price_row.add_child(pbtn)
	pb.add_child(price_row)
	pb.add_child(_label("비싸게 팔면 마진은 늘지만 손님이 줄어요. 손님마다 기대 가격이 달라요.", 14, MUTED))
	box.add_child(price_card)

	var taste_card: PanelContainer = _card("TasteCard")
	var tb: VBoxContainer = _vbox(8)
	taste_card.add_child(tb)
	tb.add_child(_label("지금 구성", 20, VERMILION))
	_profile_label = _label("", 16, INK)
	_profile_label.name = "ProfileLabel"
	tb.add_child(_profile_label)
	_compat_label = _label("", 14, TEAL)
	_compat_label.name = "CompatLabel"
	tb.add_child(_compat_label)
	_taste_button = _button("시식하기", "TasteButton")
	_primary(_taste_button)
	_taste_button.pressed.connect(_on_taste)
	tb.add_child(_taste_button)
	_taste_message = _label("", 15, TEAL)
	_taste_message.name = "TasteMessage"
	tb.add_child(_taste_message)
	box.add_child(taste_card)


func _make_option(slot: String, item: Dictionary, group: ButtonGroup) -> Button:
	var id: String = str(item["id"])
	var b: Button = Button.new()
	b.name = "Opt_" + id
	b.toggle_mode = true
	b.button_group = group
	b.custom_minimum_size = Vector2(150.0, 68.0)
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.add_theme_font_size_override("font_size", 16)
	var cost: int = int(item["cost"])
	var secs: int = int(item["seconds"])
	b.text = "%s\n%s · %d초" % [str(item["name"]), _won(cost), secs]
	b.pressed.connect(_on_option_pressed.bind(slot, id))
	_buttons[id] = b
	return b


func _build_feedback(box: VBoxContainer) -> void:
	_feedback_box = box


func _build_notebook(box: VBoxContainer) -> void:
	_notebook_count = _label("", 18, INK)
	_notebook_count.name = "NotebookCount"
	box.add_child(_notebook_count)
	_notebook_box = _vbox(10)
	_notebook_box.name = "NotebookList"
	box.add_child(_notebook_box)


func _build_serve(box: VBoxContainer) -> void:
	var intro_card: PanelContainer = _card("ServeIntroCard")
	var ib: VBoxContainer = _vbox(6)
	intro_card.add_child(ib)
	ib.add_child(_label("하루 영업", 20, VERMILION))
	_serve_intro = _label("", 16, INK)
	_serve_intro.name = "ServeIntro"
	ib.add_child(_serve_intro)
	box.add_child(intro_card)

	var menu_card: PanelContainer = _card("ServeMenuCard")
	var mb: VBoxContainer = _vbox(6)
	menu_card.add_child(mb)
	mb.add_child(_label("오늘의 메뉴", 20, VERMILION))
	_serve_menu = _label("", 16, INK)
	_serve_menu.name = "ServeMenu"
	mb.add_child(_serve_menu)
	_serve_forecast = _label("", 16, INK)
	_serve_forecast.name = "ServeForecast"
	mb.add_child(_serve_forecast)
	box.add_child(menu_card)

	_serve_button = _button("하루 영업하기", "ServeButton")
	_primary(_serve_button)
	_serve_button.pressed.connect(_on_serve)
	box.add_child(_serve_button)
	_serve_message = _label("", 15, TEAL)
	_serve_message.name = "ServeMessage"
	box.add_child(_serve_message)

	var report_card: PanelContainer = _card("ReportCard")
	var rb: VBoxContainer = _vbox(6)
	report_card.add_child(rb)
	rb.add_child(_label("지난 영업 결과", 20, VERMILION))
	_report_label = _label("", 16, INK)
	_report_label.name = "ReportLabel"
	rb.add_child(_report_label)
	box.add_child(report_card)


# ---------- 레이아웃 ----------

func _apply_layout() -> void:
	var portrait: bool = size.x < WIDE_BREAKPOINT
	_body.vertical = portrait
	if portrait:
		_bowl_card.custom_minimum_size = Vector2(0.0, 150.0)
		_bowl_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_bowl_card.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		_bowl.custom_minimum_size = Vector2(0.0, 100.0)
	else:
		_bowl_card.custom_minimum_size = Vector2(380.0, 0.0)
		_bowl_card.size_flags_horizontal = Control.SIZE_FILL
		_bowl_card.size_flags_vertical = Control.SIZE_EXPAND_FILL
		_bowl.custom_minimum_size = Vector2(0.0, 220.0)


# ---------- 저장/불러오기 ----------

func _load_save() -> void:
	if not bool(data_location["ok"]):
		save_locked = true
		_load_label.text = "저장 위치를 사용할 수 없어요: " + str(data_location["error"])
		_save_label.text = "저장이 꺼져 있어요."
		_show_banner(str(data_location["error"]), false)
		return
	if bool(data_location["is_dev"]):
		_dev_label.visible = true
		_dev_label.text = "개발용 저장 위치: " + str(data_location["dir"])
	var res: Dictionary = saver.load_into(state)
	var status: String = str(res["status"])
	match status:
		"ok":
			_load_label.text = "불러오기: 저장된 연구소를 열었어요 · 기록 %d개 · %d일차" % [state.record_count(), state.day]
		"missing":
			_load_label.text = "불러오기: 첫 방문이에요. 새 연구소를 열었어요."
			_persist()
		"corrupt", "unsupported", "io_error":
			save_locked = true
			_load_label.text = "불러오기 실패: " + str(res["message"])
			_save_label.text = "저장이 꺼져 있어요."
			_show_banner(str(res["message"]) + " 기존 파일은 지우거나 덮어쓰지 않았어요.", status != "io_error")


func _show_banner(message: String, can_reset: bool) -> void:
	_banner.visible = true
	_banner_label.text = message
	_reset_button.visible = can_reset


func _persist() -> void:
	if save_locked:
		_save_label.text = "저장이 꺼져 있어요: 기존 저장 파일을 보호하는 중이에요."
		return
	var res: Dictionary = saver.save_state(state)
	if bool(res["ok"]):
		_save_label.text = "저장됨 · 기록 %d개 · %d일차" % [state.record_count(), state.day]
	else:
		_save_label.text = "저장 실패: " + str(res["message"])


func _on_reset_save() -> void:
	var res: Dictionary = saver.archive_corrupt()
	if not bool(res["ok"]):
		_banner_label.text = str(res["message"])
		return
	save_locked = false
	state = GameStateScript.new()
	_banner.visible = false
	_load_label.text = "불러오기: 문제가 있던 저장은 따로 보관하고 새로 시작했어요."
	_persist()
	_refresh_all()


func _on_tab_changed(_index: int) -> void:
	_pending_delete_id = 0
	_persist()
	_refresh_notebook()


# ---------- 입력 처리 ----------

func _on_name_changed(text: String) -> void:
	var res: Dictionary = state.set_draft_name(text)
	if not bool(res["ok"]):
		_taste_message.text = str(res["message"])


func _on_new_recipe() -> void:
	_pending_delete_id = 0
	state.start_new_recipe()
	_taste_message.text = "새 레시피를 시작했어요. 이름을 정하고 시식해 보세요."
	_persist()
	_refresh_all()


func _on_option_pressed(slot: String, id: String) -> void:
	_pending_delete_id = 0
	var res: Dictionary = state.set_draft_choice(slot, id)
	if not bool(res["ok"]):
		_taste_message.text = str(res["message"])
	_refresh_lab()


func _on_price_step(delta: int) -> void:
	var current: int = int(state.draft_config["price"])
	var target: int = clampi(current + delta, Catalog.PRICE_MIN, Catalog.PRICE_MAX)
	var res: Dictionary = state.set_draft_price(target)
	if not bool(res["ok"]):
		_taste_message.text = str(res["message"])
	_refresh_lab()


func _on_taste() -> void:
	_pending_delete_id = 0
	var res: Dictionary = state.taste()
	_taste_message.text = str(res["message"])
	if not bool(res["ok"]):
		_taste_message.add_theme_color_override("font_color", VERMILION)
		_refresh_lab()
		return
	_taste_message.add_theme_color_override("font_color", TEAL)
	_persist()
	_refresh_all()
	tabs.current_tab = TAB_FEEDBACK
	_play_reveal()


## 시식 연출: 그릇 연출 + 손님 카드가 차례로 나타남. 전체 약 1초 이내이며 조작을 막지 않는다.
func _play_reveal() -> void:
	_bowl.play_reveal()
	var i: int = 0
	for child in _feedback_box.get_children():
		if child is Control and str(child.name).begins_with("Card_"):
			var c: Control = child
			c.modulate.a = 0.0
			var tw: Tween = c.create_tween()
			tw.tween_interval(0.12 * float(i))
			tw.tween_property(c, "modulate:a", 1.0, 0.25)
			i += 1


func _on_select_record(id: int) -> void:
	_pending_delete_id = 0
	var res: Dictionary = state.select_record(id)
	if not bool(res["ok"]):
		_notebook_count.text = str(res["message"])
		return
	var rec: Dictionary = state.get_record(id)
	_taste_message.add_theme_color_override("font_color", TEAL)
	_taste_message.text = "'%s v%d'를 불러왔어요. 재료나 가격을 바꿔 시식하면 v%d로 기록돼요." % [str(rec["name"]), int(rec["version"]), int(rec["version"]) + 1]
	_persist()
	_refresh_all()
	tabs.current_tab = TAB_LAB


func _on_delete_record(id: int) -> void:
	if _pending_delete_id != id:
		_pending_delete_id = id
		_refresh_notebook()
		return
	_pending_delete_id = 0
	state.delete_record(id)
	_persist()
	_refresh_all()


func _on_serve() -> void:
	_pending_delete_id = 0
	var res: Dictionary = state.serve()
	_serve_message.text = str(res["message"])
	if not bool(res["ok"]):
		_serve_message.add_theme_color_override("font_color", VERMILION)
		return
	_serve_message.add_theme_color_override("font_color", TEAL)
	_persist()
	_refresh_all()


# ---------- 화면 갱신 ----------

func _refresh_all() -> void:
	_refresh_header()
	_refresh_lab()
	_refresh_feedback()
	_refresh_notebook()
	_refresh_serve()


func _refresh_header() -> void:
	_day_label.text = "%d일차" % state.day
	_wallet_label.text = "자금 " + _won(state.wallet)


func _next_version(lineage: int) -> int:
	var best: int = 0
	for r in state.records():
		var d: Dictionary = r
		if int(d["lineage_id"]) == lineage:
			best = maxi(best, int(d["version"]))
	return best + 1


func _refresh_lab() -> void:
	for slot in Catalog.SLOTS:
		var chosen: String = str(state.draft_config[slot])
		for item in Catalog.items(slot):
			var d: Dictionary = item
			var id: String = str(d["id"])
			var b: Button = _buttons[id]
			b.set_pressed_no_signal(id == chosen)
		var sel: Dictionary = Catalog.find(chosen)
		var desc: Label = _desc_labels[slot]
		desc.text = "%s — %s\n비용 %s · 준비 %d초 · %s" % [str(sel["name"]), str(sel["desc"]), _won(int(sel["cost"])), int(sel["seconds"]), Catalog.axes_text(sel)]

	if _name_edit.text != state.draft_name:
		_name_edit.text = state.draft_name
	_name_edit.editable = state.draft_lineage_id == 0
	if state.draft_lineage_id == 0:
		_mode_label.text = "새 레시피로 기록돼요."
	else:
		_mode_label.text = "개정 중: 같은 이름의 v%d로 기록되고 이전 버전과 비교해 드려요." % _next_version(state.draft_lineage_id)

	var price: int = int(state.draft_config["price"])
	var cost: int = Evaluator.unit_cost(state.draft_config)
	var prep: int = Evaluator.prep_seconds(state.draft_config)
	_price_label.text = "%s (그릇당 마진 %s)" % [_won(price), _won(price - cost)]

	var profile: Dictionary = Evaluator.build_profile(state.draft_config)
	var parts: Array[String] = []
	for axis in Catalog.AXES:
		parts.append("%s %d" % [str(Catalog.AXIS_NAMES[axis]), int(profile[axis])])
	_profile_label.text = "맛 프로필(0~10): " + " · ".join(parts) + "\n원가 %s · 준비 %d초\n시식하면 시제품 재료비 %s가 자금에서 빠져요." % [_won(cost), prep, _won(cost)]
	var applied: Array = Evaluator.applied_compat(state.draft_config)
	var lines: Array[String] = []
	for a in applied:
		var ad: Dictionary = a
		lines.append("%s %s" % ["+%d" % int(ad["score"]) if int(ad["score"]) > 0 else str(int(ad["score"])), str(ad["note"])])
	_compat_label.text = "재료 궁합 메모\n" + "\n".join(lines) if not lines.is_empty() else "재료 궁합 메모: 특별히 눈에 띄는 조합은 없어요."
	_taste_button.text = "시식하기"

	_bowl.set_config(state.draft_config)
	_bowl_caption.text = "%s\n원가 %s · 준비 %d초 · 판매가 %s" % [state.draft_name, _won(cost), prep, _won(price)]


func _refresh_feedback() -> void:
	_clear(_feedback_box)
	var rec: Dictionary = state.get_record(state.last_feedback_record_id)
	if rec.is_empty():
		var empty: PanelContainer = _card("EmptyFeedbackCard")
		empty.add_child(_label("아직 시식한 레시피가 없어요. '연구' 탭에서 재료를 고르고 시식해 보세요. 손님 세 분의 솔직한 반응을 들려드려요.", 16, INK))
		_feedback_box.add_child(empty)
		return
	var config: Dictionary = rec["config"]
	var evaluation: Dictionary = Evaluator.evaluate(config)

	var title_card: PanelContainer = _card("FeedbackTitleCard")
	var tcb: VBoxContainer = _vbox(4)
	title_card.add_child(tcb)
	var title: Label = _label("%s v%d" % [str(rec["name"]), int(rec["version"])], 24, VERMILION)
	title.name = "FeedbackTitle"
	tcb.add_child(title)
	tcb.add_child(_label("평균 %d점 · 판매가 %s · 원가 %s · 준비 %d초" % [int(evaluation["average_score"]), _won(int(config["price"])), _won(int(evaluation["unit_cost"])), int(evaluation["prep_seconds"])], 15, MUTED))
	_feedback_box.add_child(title_card)

	for c in evaluation["customers"]:
		var cd: Dictionary = c
		_feedback_box.add_child(_customer_card(cd))
	_feedback_box.add_child(_comparison_card(rec, evaluation))


func _customer_card(cd: Dictionary) -> PanelContainer:
	var card: PanelContainer = _card("Card_" + str(cd["id"]))
	var cb: VBoxContainer = _vbox(6)
	card.add_child(cb)
	cb.add_child(_label(str(cd["name"]), 20, VERMILION))
	cb.add_child(_label(str(cd["persona"]), 14, MUTED))
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var meter: StarMeterScript = StarMeterScript.new()
	meter.name = "Stars_" + str(cd["id"])
	meter.stars = int(cd["stars"])
	row.add_child(meter)
	var score: Label = _label("%d점" % int(cd["score"]), 18, INK)
	score.name = "Score_" + str(cd["id"])
	row.add_child(score)
	cb.add_child(row)
	var headline: Label = _label(str(cd["headline"]), 18, INK)
	headline.name = "Headline_" + str(cd["id"])
	cb.add_child(headline)
	for r in cd["reasons"]:
		cb.add_child(_label("· " + str(r), 15, INK))
	cb.add_child(_label(str(cd["value_note"]), 14, TEAL))
	return card


func _comparison_card(rec: Dictionary, evaluation: Dictionary) -> PanelContainer:
	var card: PanelContainer = _card("ComparisonPanel")
	var cb: VBoxContainer = _vbox(6)
	card.add_child(cb)
	cb.add_child(_label("이전 버전과 비교", 20, VERMILION))
	var body: Label = _label("", 15, INK)
	body.name = "ComparisonLabel"
	cb.add_child(body)
	var cmp: Dictionary = rec["comparison"]
	if cmp.is_empty():
		body.text = "첫 시식이라 비교할 이전 버전이 없어요. 재료나 가격을 바꿔 다시 시식하면 v2와 비교해 드려요."
		return card
	var prev_cfg: Dictionary = cmp["prev_config"]
	var prev_scores: Dictionary = cmp["prev_scores"]
	var cfg: Dictionary = rec["config"]
	var lines: Array[String] = ["v%d → v%d" % [int(cmp["prev_version"]), int(rec["version"])]]
	var changes: Array[String] = []
	for slot in Catalog.SLOTS:
		if str(prev_cfg[slot]) != str(cfg[slot]):
			var old_item: Dictionary = Catalog.find(str(prev_cfg[slot]))
			var new_item: Dictionary = Catalog.find(str(cfg[slot]))
			changes.append("%s: %s → %s" % [str(Catalog.SLOT_NAMES[slot]), str(old_item["name"]), str(new_item["name"])])
	if int(prev_cfg["price"]) != int(cfg["price"]):
		changes.append("가격: %s → %s" % [_won(int(prev_cfg["price"])), _won(int(cfg["price"]))])
	lines.append("바뀐 점 — " + ", ".join(changes))
	var up: int = 0
	var down: int = 0
	var prev_sum: int = 0
	for c in evaluation["customers"]:
		var cd: Dictionary = c
		var before: int = int(prev_scores[str(cd["id"])])
		var after: int = int(cd["score"])
		prev_sum += before
		if after > before:
			up += 1
		elif after < before:
			down += 1
		lines.append("%s: %d점 → %d점 (%+d)" % [str(cd["name"]), before, after, after - before])
	var prev_avg: int = roundi(float(prev_sum) / 3.0)
	lines.append("평균: %d점 → %d점 (%+d)" % [prev_avg, int(evaluation["average_score"]), int(evaluation["average_score"]) - prev_avg])
	var prev_cost: int = Evaluator.unit_cost(prev_cfg)
	var prev_prep: int = Evaluator.prep_seconds(prev_cfg)
	lines.append("원가: %s → %s · 준비 시간: %d초 → %d초" % [_won(prev_cost), _won(int(evaluation["unit_cost"])), prev_prep, int(evaluation["prep_seconds"])])
	lines.append("%d명이 더 만족하고 %d명이 덜 만족해요." % [up, down])
	body.text = "\n".join(lines)
	return card


func _refresh_notebook() -> void:
	_clear(_notebook_box)
	var all_records: Array = state.records()
	_notebook_count.text = "레시피 노트 %d/%d" % [all_records.size(), GameStateScript.MAX_RECORDS]
	if all_records.is_empty():
		var empty: PanelContainer = _card("EmptyNotebookCard")
		empty.add_child(_label("노트가 비어 있어요. 시식한 레시피가 이곳에 기록돼요.", 16, INK))
		_notebook_box.add_child(empty)
		return
	for i in range(all_records.size() - 1, -1, -1):
		var rec: Dictionary = all_records[i]
		_notebook_box.add_child(_notebook_row(rec))


func _notebook_row(rec: Dictionary) -> PanelContainer:
	var id: int = int(rec["record_id"])
	var cfg: Dictionary = rec["config"]
	var scores: Dictionary = rec["scores"]
	var row: PanelContainer = _card("Row_%d" % id)
	var rb: VBoxContainer = _vbox(6)
	row.add_child(rb)
	var selected: bool = id == state.selected_record_id
	var title: String = "%s v%d" % [str(rec["name"]), int(rec["version"])]
	if selected:
		title += " · 선택됨"
	rb.add_child(_label(title, 20, TEAL if selected else VERMILION))
	var names: Array[String] = []
	for slot in Catalog.SLOTS:
		var item: Dictionary = Catalog.find(str(cfg[slot]))
		names.append(str(item["name"]))
	rb.add_child(_label(" · ".join(names), 14, MUTED))
	var ratings: Array[String] = []
	for c in Customers.all():
		var cd: Dictionary = c
		ratings.append("%s %d/5" % [str(cd["name"]), Evaluator.stars_for(int(scores[str(cd["id"])]))])
	rb.add_child(_label(" · ".join(ratings) + "\n판매가 " + _won(int(cfg["price"])) + " · " + "%d일차 시식" % int(rec["tasted_day"]), 15, INK))
	var buttons: HBoxContainer = HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 8)
	var sel_btn: Button = _button("불러오기", "SelectRecord_%d" % id)
	sel_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sel_btn.pressed.connect(_on_select_record.bind(id))
	buttons.add_child(sel_btn)
	var del_text: String = "한 번 더 눌러 삭제" if id == _pending_delete_id else "삭제"
	var del_btn: Button = _button(del_text, "DeleteRecord_%d" % id)
	del_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	del_btn.pressed.connect(_on_delete_record.bind(id))
	buttons.add_child(del_btn)
	rb.add_child(buttons)
	return row


func _refresh_serve() -> void:
	_serve_intro.text = "영업 한 번은 하루예요. 누르면 %d일차가 끝나고 다음 날로 넘어가요.\n지금: %d일차 · 보유 자금 %s\n점심 피크 %d분 동안 만들 수 있는 그릇 수에는 한계가 있고, 하루 운영비 %s가 들어요." % [state.day, state.day, _won(state.wallet), Sim.SERVICE_SECONDS / 60, _won(Sim.OVERHEAD)]
	var rec: Dictionary = state.get_record(state.selected_record_id)
	if rec.is_empty():
		_serve_menu.text = "'노트' 탭에서 영업할 레시피를 불러오세요."
		_serve_forecast.text = ""
		_serve_button.disabled = true
	else:
		var cfg: Dictionary = rec["config"]
		_serve_menu.text = "%s v%d · 판매가 %s · 원가 %s · 준비 %d초" % [str(rec["name"]), int(rec["version"]), _won(int(cfg["price"])), _won(Evaluator.unit_cost(cfg)), Evaluator.prep_seconds(cfg)]
		var fc: Dictionary = state.forecast()
		if str(fc["error"]) != "":
			_serve_forecast.text = str(fc["error"])
			_serve_button.disabled = true
		else:
			_serve_forecast.text = _forecast_text(fc)
			_serve_button.disabled = false
	_serve_button.text = "%d일차 영업하기" % state.day
	if state.last_report.is_empty():
		_report_label.text = "아직 영업한 날이 없어요."
	else:
		_report_label.text = _report_text(state.last_report)


func _source_text(by_source: Dictionary) -> String:
	var parts: Array[String] = []
	for c in Customers.all():
		var cd: Dictionary = c
		parts.append("%s %d그릇" % [str(cd["name"]), int(by_source[str(cd["id"])])])
	parts.append("처음 온 손님 %d그릇" % int(by_source[Sim.WALKIN_ID]))
	return " · ".join(parts)


func _forecast_text(fc: Dictionary) -> String:
	var lines: Array[String] = ["오늘 예상 (%d일차)" % state.day]
	lines.append("손님 수요 %d그릇, 만들 수 있는 양 %d그릇 → 판매 %d그릇" % [int(fc["demand"]), int(fc["capacity"]), int(fc["units"])])
	lines.append(_source_text(fc["by_source"]))
	lines.append("매출 %s − 재료비 %s − 운영비 %s" % [_won(int(fc["revenue"])), _won(int(fc["ingredient_cost"])), _won(int(fc["overhead"]))])
	lines.append("순영업이익 %s" % _won(int(fc["net"])))
	return "\n".join(lines)


func _report_text(report: Dictionary) -> String:
	var lines: Array[String] = ["%d일차 · %s v%d · 판매가 %s" % [int(report["day"]), str(report["recipe_name"]), int(report["version"]), _won(int(report["price"]))]]
	lines.append("판매 %d그릇" % int(report["units"]))
	lines.append(_source_text(report["by_source"]))
	lines.append("매출 %s · 재료비 %s · 운영비 %s" % [_won(int(report["revenue"])), _won(int(report["ingredient_cost"])), _won(int(report["overhead"]))])
	lines.append("순영업이익 %s · 영업 후 자금 %s" % [_won(int(report["net"])), _won(int(report["wallet_after"]))])
	return "\n".join(lines)
