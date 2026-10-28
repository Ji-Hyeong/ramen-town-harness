extends Control
## 다음 행동을 알려 주는 눌러서 여는 카드 한 장: [단골 초상] 제목/설명 [화살표].
## 카드 전체가 하나의 진짜 버튼(JourneyAction)이고 그 위의 그림/글자는 입력을 받지 않는다(MOUSE_FILTER_IGNORE).
## 버튼은 기존 Shared.make_button 과 같은 막대/눌림 모양이라 ActionFeedback 의 클릭 효과와 드래그 취소(손을 떼야
## 눌림, 스크롤로 넘어가면 취소)를 그대로 쓴다. 카드는 게임 상태를 갖지 않고 action_requested 만 보낸다.
## 이 신호를 받은 쪽이 화면을 열 뿐, 카드는 시작/결제/정산/적용을 하지 않는다.
##
## 사용: present(model) 에 KitchenJourney.describe()/choices() 의 항목({title,hint,action,customer,disabled})을 준다.
## 모델이 바뀐 경우에만 글/그림/잠금을 다시 만든다(같은 모델을 매 프레임 줘도 레이아웃 재계산이 없다).

signal action_requested(action: String)

const SHARED_PATH := "res://scripts/ui/service_result_view.gd"
const Mock = preload("res://scripts/ui/mock_fidelity_art.gd")
const Art = preload("res://scripts/ui/bowl_editor_art.gd")
const Pixel = preload("res://scripts/ui/pixel_art.gd")
const BODY = preload("res://assets/fonts/Pretendard-Regular.otf")
const BOLD = preload("res://assets/fonts/Pretendard-Bold.otf")
const INK := Color("18354f")
const MUTED := Color("685c50")

## 카드가 내보낼 수 있는 행동. 그 밖의 이름(wait 포함)은 눌러도 신호를 보내지 않는다.
const EMITTABLE: Array = ["broth", "noodle", "compose", "selling", "goals", "resume_exploration", "improve", "explore", "research"]
const MIN_HEIGHT: float = 78.0
const PORTRAIT_SIZE: float = 40.0
const CHEVRON_SIZE: float = 24.0
## 그림 틀(테두리 약 10px)과 글자가 겹치지 않도록 둔 안쪽 여백.
const PAD_X: int = 18
const PAD_Y: int = 12
const TITLE_SIZE: int = 16
const HINT_SIZE: int = 14

## 같은 초상은 한 번만 만든다(카드가 여러 장이어도 텍스처를 공유).
static var _portraits: Dictionary = {}

var button: Button
var title_label: Label
var hint_label: Label
var portrait: TextureRect
var chevron: TextureRect

var _holder: PanelContainer
var _action: String = ""
var _shown: Dictionary = {}


func _init() -> void:
	# 카드 자체는 입력을 가로채지 않고 부모(스크롤)로 넘긴다. 키보드 포커스는 안의 버튼이 받는다.
	mouse_filter = Control.MOUSE_FILTER_PASS
	focus_mode = Control.FOCUS_NONE
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	custom_minimum_size = Vector2(0, MIN_HEIGHT)
	clip_contents = true

	# PanelContainer 는 자식 중 가장 큰 최소 크기로 자란다: 맨 아래 버튼 위에 안 눌리는 내용을 겹쳐서
	# 글이 줄바꿈되면 카드 높이가 같이 커지고 눌림은 항상 아래 진짜 버튼이 받는다(disclosure_card.gd 와 같은 방식).
	_holder = PanelContainer.new()
	_holder.mouse_filter = Control.MOUSE_FILTER_PASS
	_holder.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	_holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_holder.minimum_size_changed.connect(update_minimum_size)
	add_child(_holder)

	# service_result_view 도 이 카드를 쓰므로 preload 하면 정적 순환이 된다. 버튼 공장만 여기서 실행 중에 불러온다.
	var shared: GDScript = load(SHARED_PATH)
	button = shared.make_button("", "JourneyAction", "summary")
	button.custom_minimum_size = Vector2(0, MIN_HEIGHT)
	# 눌린 동안은 청록 막대 위에 얹힌 글자/화살표가 버튼 색을 따르지 않으므로 직접 흰색으로 바꾼다.
	button.button_down.connect(_set_held.bind(true))
	button.button_up.connect(_set_held.bind(false))
	button.add_theme_stylebox_override("disabled", Mock.style("summary"))
	button.add_theme_color_override("font_disabled_color", MUTED)
	button.pressed.connect(_on_pressed)
	_holder.add_child(button)

	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", PAD_X)
	margin.add_theme_constant_override("margin_right", PAD_X - 4)
	margin.add_theme_constant_override("margin_top", PAD_Y)
	margin.add_theme_constant_override("margin_bottom", PAD_Y)
	_holder.add_child(margin)

	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 10)
	margin.add_child(row)

	portrait = TextureRect.new()
	portrait.name = "JourneyPortrait"
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait.custom_minimum_size = Vector2(PORTRAIT_SIZE, PORTRAIT_SIZE)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	portrait.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	portrait.visible = false
	row.add_child(portrait)

	var texts := VBoxContainer.new()
	texts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	texts.add_theme_constant_override("separation", 2)
	row.add_child(texts)

	title_label = _label("JourneyTitle", TITLE_SIZE, BOLD, INK)
	texts.add_child(title_label)
	hint_label = _label("JourneyHint", HINT_SIZE, BODY, MUTED)
	texts.add_child(hint_label)

	chevron = TextureRect.new()
	chevron.name = "JourneyChevron"
	chevron.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chevron.texture = Art.icon("chevron_right")
	chevron.custom_minimum_size = Vector2(CHEVRON_SIZE, CHEVRON_SIZE)
	chevron.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	chevron.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	chevron.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	chevron.modulate = INK
	row.add_child(chevron)


## 최소 높이는 안쪽 내용(줄바꿈 포함)이 정한다. Control 은 자식 크기를 모르므로 직접 알려 준다.
func _get_minimum_size() -> Vector2:
	if _holder == null:
		return Vector2(0, MIN_HEIGHT)
	return Vector2(0, maxf(MIN_HEIGHT, _holder.get_combined_minimum_size().y))


## 모델이 이전과 같으면 아무것도 하지 않는다. 모양이 이상한 모델은 눌리지 않는 빈 카드로 둔다.
func present(model: Dictionary) -> void:
	var next: Dictionary = {
		"title": str(model.get("title", "")),
		"hint": str(model.get("hint", "")),
		"action": str(model.get("action", "")),
		"customer": str(model.get("customer", "")),
		"disabled": bool(model.get("disabled", false)),
	}
	if next == _shown:
		return
	_shown = next
	_action = next["action"] if EMITTABLE.has(next["action"]) else ""
	# 제목이 비면 조용히 빈 카드가 되지 않도록 못 여는 이유를 직접 보여 준다.
	title_label.text = next["title"] if next["title"] != "" else "지금은 열 수 없어요"
	hint_label.text = next["hint"]
	hint_label.visible = next["hint"] != ""
	_set_held(false)
	var tex: Texture2D = _portrait_for(next["customer"])
	portrait.texture = tex
	portrait.visible = tex != null
	# 보낼 수 없는 행동(wait/알 수 없음)은 모델이 켜 두었어도 누를 수 없게 막는다.
	var locked: bool = next["disabled"] or _action == ""
	button.disabled = locked
	modulate = Color(1, 1, 1, 0.62) if locked else Color.WHITE
	# 보조기기용 이름은 엔진이 지원하는 속성으로만 붙인다.
	if "accessibility_name" in button:
		button.set("accessibility_name", next["title"] if next["hint"] == "" else "%s, %s" % [next["title"], next["hint"]])
	update_minimum_size()


## 마지막으로 보여 준 모델의 복사본(검사용). 카드가 상태를 소유하지 않음을 시험이 확인할 수 있게 한다.
func shown_model() -> Dictionary:
	return _shown.duplicate()


## 누르는 동안(true)은 글자/화살표를 흰색, 손을 떼거나 취소하면(false) 원래 INK/MUTED 로 되돌린다.
func _set_held(held: bool) -> void:
	title_label.add_theme_color_override("font_color", Color.WHITE if held else INK)
	hint_label.add_theme_color_override("font_color", Color.WHITE if held else MUTED)
	chevron.modulate = Color.WHITE if held else INK


func _on_pressed() -> void:
	# 진짜로 꺼진 버튼은 pressed 를 보내지 않지만 시그널을 직접 보내는 경우도 막는다.
	if button.disabled or _action == "":
		return
	action_requested.emit(_action)


func _portrait_for(customer_id: String) -> Texture2D:
	if customer_id == "" or not Pixel.portrait_ids().has(customer_id):
		return null
	if not _portraits.has(customer_id):
		_portraits[customer_id] = Pixel.scaled_tex(Pixel.portrait_image(customer_id), 2)
	return _portraits[customer_id]


func _label(node_name: String, font_size: int, font: Font, color: Color) -> Label:
	var label := Label.new()
	label.name = node_name
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# 긴 이름/문장은 단어 단위로, 단어가 폭보다 길면 글자 단위로 줄바꿈한다. 폭이 좁아도 옆 칸을 밀지 않는다.
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label
