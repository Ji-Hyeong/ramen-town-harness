extends VBoxContainer
## 눌러서 펼치는 카드. 항상 보이는 머리줄(header_button)과 접혀 있는 상세(body)로 이뤄진다.
## 머리줄은 도톰하게 솟은 카드 한 줄 전체가 버튼이다: [아이콘] 제목/요약 [그려 넣은 화살표].
## 화살표는 글꼴 글자가 아니라 직접 그린 도형이라 어떤 글꼴/폭에서도 보이고, 접힘은 아래, 펼침은 위를 가리킨다.
##
## 사용: 부모가 name 을 정한 뒤 configure() 를 부르고, 상세 컨트롤을 body 에 넣는다.
##   머리줄 이름 = str(name) + "Toggle", 상세 이름 = str(name) + "Body".
## 상태 변화는 set_expanded() 한 곳으로만 일어나고, 실제로 바뀔 때만 toggled 를 한 번 보낸다.
## 펼치기만으로는 게임 상태를 바꾸지 않는다(밖으로 나가는 신호는 toggled 뿐).
##
## 입력: 카드/머리줄/상세는 MOUSE_FILTER_PASS(손가락 스크롤이 부모로 전달), 글자/아이콘/화살표/장식은 IGNORE.
## 눌림 효과는 색과 테두리만 바꾼다. 눌리는 노드를 움직이거나 크기를 바꾸지 않는다.
## 사라지는 연출/타이머가 없어 노드가 해제된 뒤 값을 쓰는 일이 없다.

signal toggled(expanded: bool)

const INK: Color = Color(0.17, 0.12, 0.08)
const PAPER_LIGHT: Color = Color(0.99, 0.96, 0.88)
const PAPER_DARK: Color = Color(0.88, 0.80, 0.64)
const VERMILION: Color = Color(0.76, 0.23, 0.13)
const TEAL: Color = Color(0.20, 0.46, 0.44)
const MUTED: Color = Color(0.40, 0.33, 0.26)
const WOOD_D: Color = Color(0.24, 0.14, 0.08)
const CREAM: Color = Color(0.99, 0.94, 0.80)

const MIN_HEADER_HEIGHT: float = 48.0
const CHEVRON_SIZE: float = 32.0
const ICON_SIZE: float = 36.0


## 머리줄 오른쪽에 그리는 화살표. 상태는 up 하나뿐이고 입력은 받지 않는다.
class Chevron extends Control:
	var up: bool = false
	var color: Color = Color(0.76, 0.23, 0.13)

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		custom_minimum_size = Vector2(32, 32)
		size_flags_vertical = Control.SIZE_SHRINK_CENTER

	func set_up(value: bool) -> void:
		if value == up:
			return
		up = value
		queue_redraw()

	func _draw() -> void:
		var rect := Rect2(Vector2.ZERO, size)
		# 작은 판 위에 굵은 꺾쇠를 올려 눌러서 열린다는 표시가 한눈에 보이게 한다.
		draw_rect(rect, Color(0.88, 0.80, 0.64))
		draw_rect(rect, Color(0.24, 0.14, 0.08), false, 2.0)
		var center := size / 2.0
		var wing: float = minf(size.x, size.y) * 0.26
		var rise: float = wing * 0.6
		# 아래 화살표: 양 끝이 위, 꼭짓점이 아래. 위 화살표는 그 반대(위쪽을 가리킴).
		var side_y: float = rise if up else -rise
		var tip_y: float = -rise if up else rise
		draw_polyline(PackedVector2Array([
			center + Vector2(-wing, side_y), center + Vector2(0, tip_y), center + Vector2(wing, side_y),
		]), color, 3.0, true)


var header_button: Button
var body: VBoxContainer
var expanded: bool = false
## 화면 요소(검사/색칠용). 내용은 configure() 로만 바꾼다.
var title_label: Label
var summary_label: Label
var icon_rect: TextureRect
var chevron: Control

var _holder: PanelContainer
var _body_panel: PanelContainer
var _accent: Color = WOOD_D


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 0)

	# 머리줄: PanelContainer 안에 [맨 아래 버튼] + [그 위의 안 눌리는 내용]을 겹친다.
	# 내용 높이(글줄바꿈 포함)가 버튼 높이를 정하고, 눌림은 맨 아래 진짜 버튼이 받는다.
	_holder = PanelContainer.new()
	_holder.mouse_filter = Control.MOUSE_FILTER_PASS
	_holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_holder.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	add_child(_holder)

	header_button = Button.new()
	header_button.mouse_filter = Control.MOUSE_FILTER_PASS
	header_button.custom_minimum_size = Vector2(0, MIN_HEADER_HEIGHT)
	header_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_button.clip_text = true
	header_button.pressed.connect(_on_header_pressed)
	_holder.add_child(header_button)

	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 10)
	_holder.add_child(margin)

	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 10)
	margin.add_child(row)

	icon_rect = TextureRect.new()
	icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_rect.custom_minimum_size = Vector2(ICON_SIZE, ICON_SIZE)
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon_rect.visible = false
	row.add_child(icon_rect)

	var texts := VBoxContainer.new()
	texts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	texts.add_theme_constant_override("separation", 2)
	row.add_child(texts)

	title_label = _label(17, INK)
	texts.add_child(title_label)
	summary_label = _label(13, MUTED)
	summary_label.visible = false
	texts.add_child(summary_label)

	chevron = Chevron.new()
	row.add_child(chevron)

	_body_panel = PanelContainer.new()
	_body_panel.mouse_filter = Control.MOUSE_FILTER_PASS
	_body_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body_panel.add_theme_stylebox_override("panel", _box(PAPER_LIGHT, _accent, 3, 12.0, 10.0, 3, 0))
	_body_panel.visible = false
	add_child(_body_panel)

	body = VBoxContainer.new()
	body.mouse_filter = Control.MOUSE_FILTER_PASS
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 6)
	body.visible = false
	_body_panel.add_child(body)

	_apply_state()


## 제목/요약/아이콘만 갱신한다. 머리줄 노드, 상세 내용, 펼침 상태는 그대로이고 toggled 도 보내지 않는다.
## 부모가 name 을 먼저 정해 두어야 하며, 이름에서 파생되는 노드 이름도 여기서 맞춘다.
func configure(title: String, summary: String, icon: Texture2D = null) -> void:
	header_button.name = str(name) + "Toggle"
	body.name = str(name) + "Body"
	title_label.text = title
	summary_label.text = summary
	summary_label.visible = summary != ""
	icon_rect.texture = icon
	icon_rect.visible = icon != null
	# 머리줄에는 글자를 직접 그리지 않으므로 보조기기용 이름은 엔진이 지원하는 속성으로만 붙인다.
	var label_text: String = title if summary == "" else "%s, %s" % [title, summary]
	if "accessibility_name" in header_button:
		header_button.set("accessibility_name", label_text)


## 펼침/접힘. 값이 실제로 바뀔 때만 toggled 를 한 번 보낸다.
func set_expanded(value: bool) -> void:
	if value == expanded:
		return
	expanded = value
	_apply_state()
	toggled.emit(expanded)


## 머리줄 테두리 색(예: 현재 목표 강조). 상태/내용은 바꾸지 않는다.
func set_accent(color: Color) -> void:
	_accent = color
	_apply_state()


# 진짜로 꺼진 버튼은 pressed 를 보내지 않지만, 시그널을 직접 보내 강제로 부르는 경우도 막는다.
func _on_header_pressed() -> void:
	if header_button.disabled:
		return
	set_expanded(not expanded)


func _apply_state() -> void:
	var edge: Color = VERMILION if expanded else _accent
	# 내용 여백은 모든 상태에서 같게 둬서 눌러도 레이아웃이 움직이지 않는다. 솟음/눌림은 아래 테두리 두께로만 표현한다.
	header_button.add_theme_stylebox_override("normal", _box(CREAM if expanded else PAPER_LIGHT, edge, 3, 0.0, 0.0, 6, 3))
	header_button.add_theme_stylebox_override("hover", _box(CREAM, edge, 3, 0.0, 0.0, 6, 3))
	header_button.add_theme_stylebox_override("pressed", _box(PAPER_DARK, edge, 3, 0.0, 0.0, 3, 3))
	header_button.add_theme_stylebox_override("hover_pressed", _box(PAPER_DARK, edge, 3, 0.0, 0.0, 3, 3))
	header_button.add_theme_stylebox_override("disabled", _box(PAPER_DARK, MUTED, 3, 0.0, 0.0, 3, 3))
	var focus := _box(Color(0, 0, 0, 0), VERMILION, 4, 0.0, 0.0, 4, 4)
	focus.draw_center = false
	header_button.add_theme_stylebox_override("focus", focus)
	(chevron as Chevron).set_up(expanded)
	(chevron as Chevron).color = TEAL if expanded else VERMILION
	chevron.queue_redraw()
	_body_panel.visible = expanded
	body.visible = expanded
	_body_panel.add_theme_stylebox_override("panel", _box(PAPER_LIGHT, edge, 3, 12.0, 10.0, 3, 0))


func _label(font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


func _box(bg: Color, border: Color, side_w: int, mx: float, my: float, bottom_w: int, top_w: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.border_width_left = side_w
	sb.border_width_right = side_w
	sb.border_width_top = top_w
	sb.border_width_bottom = maxi(bottom_w, 0)
	sb.content_margin_left = mx
	sb.content_margin_right = mx
	sb.content_margin_top = my
	sb.content_margin_bottom = my
	return sb
