extends VBoxContainer
## 레시피 연구 노트 표시 컴포넌트. 부모가 넘긴 RecipeDiscovery.pages() 결과만 그리고, 사용자의 의도는 시그널로만 알린다.
## GameState/파일/저장소를 읽거나 쓰지 않으며 보상, 점수, 재료 지급, 레시피 자동 채우기를 하지 않는다.
## 데이터와 잠금(진행 중 여부)은 전부 부모의 몫이다. 이 컴포넌트는 busy 일 때 버튼을 끄고 콜백도 한 번 더 막는다.
##
## mode:
##   "target" 이번 실험 카드 한 장(기본). 제목/진행도/상태와 재료 경고는 바로 보이고, 전체 조건과 단서는 펼침 카드에 담는다.
##   "map"    라멘 연구 지도. 주제마다 접힌 요약 카드 한 장(번호, 상태, 진행도). 머리줄을 누르면 조건/단서/"이번 목표로"가 펼쳐진다.
##   그 밖의 값은 조용히 넘어가지 않고 "알 수 없는 표시 방식" 안내를 그린다.
##
## 펼침 카드(DisclosureCard)는 펼치기만 한다. 목표 선택, 재료 찾기, 비용 지불, 상태 변경은 하지 않는다.
## present() 가 다시 그려도 펼침 상태는 id 별로 기억했다가, 이번에 실제로 그려지는 카드에만 되돌린다.
##
## 잘못된 입력 처리(성공한 척하지 않는다):
##   - 형식이 맞지 않는 페이지(필수 키 누락/자료형 불일치/진행도 범위 밖)는 건너뛰고 건너뛴 개수를 화면에 알린다.
##   - 유효한 페이지가 하나도 없으면 "연구 주제 정보를 받지 못했어요" 안내만 그린다.
##   - target 모드에서 selected_id 에 맞는 유효한 페이지가 없으면 "이번 실험 정보를 찾지 못했어요" 안내와 연구 지도 버튼만 그린다.
##   - "시식함"은 부모가 넘긴 보관 중인 시식 노트 기준일 뿐 영구 해금이나 보상이 아니다.
##
## 입력: 버튼과 카드 패널은 MOUSE_FILTER_PASS(손가락 스크롤이 부모 ScrollContainer 로 전달), 글자/진행바/장식은 IGNORE.
## 누르기 효과(파티클/진동)는 부모가 모든 버튼에 한 곳에서 붙인다. 여기서는 따로 만들지 않는다.

signal target_selected(id: String)
signal book_requested
signal exploration_requested

const Catalog = preload("res://scripts/domain/ingredient_catalog.gd")
const Disclosure = preload("res://scripts/ui/disclosure_card.gd")

const INK: Color = Color(0.17, 0.12, 0.08)
const PAPER_LIGHT: Color = Color(0.99, 0.96, 0.88)
const PAPER_DARK: Color = Color(0.88, 0.80, 0.64)
const VERMILION: Color = Color(0.76, 0.23, 0.13)
const TEAL: Color = Color(0.20, 0.46, 0.44)
const MUTED: Color = Color(0.40, 0.33, 0.26)
const WOOD_D: Color = Color(0.24, 0.14, 0.08)
const CREAM: Color = Color(0.99, 0.94, 0.80)

const MIN_BUTTON_HEIGHT: float = 48.0
const MAP_NOTE: String = "보관 중인 시식 노트 기준 · 기록을 지우면 수록 표시도 바뀌어요"
const READY_TEXT: String = "조건 완성 · 시식으로 확인하세요"
const TESTED_TEXT: String = "시식 노트에 수록된 연구예요. 다른 조합으로도 도전해 보세요."
## 접힌 상태의 "이번 실험" 카드에 바로 보이는 못 채운 조건 수.
const MISSING_SHOWN: int = 2

const _REQUIRED_KEYS: Array = ["id", "title", "hint", "origin", "criteria", "tested", "ready", "progress", "total", "missing", "unavailable"]

## 부모가 present() 전에(노드를 붙이기 전에) 정한다.
var mode: String = "target"

var _pages: Array = []
var _selected_id: String = ""
var _busy: bool = false
var _sample_error: String = ""
## 펼쳐 둔 카드 키(주제 id 또는 "@target:<id>")와 지금 그려진 카드. present() 사이에 펼침 상태를 이어 주는 데만 쓴다.
var _open: Dictionary = {}
var _cards: Dictionary = {}


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 10)


## 표시를 통째로 다시 만든다. 옛 자식은 먼저 트리에서 빼서 같은 프레임에도 이름이 겹치지 않는다.
## 버튼 시그널 처리 도중 호출돼도 안전하다(옛 노드는 queue_free 로 한 프레임 뒤 해제).
func present(pages: Array, selected_id: String, busy: bool = false, sample_error: String = "") -> void:
	_remember_open()
	_pages = pages
	_selected_id = selected_id
	_busy = busy
	_sample_error = sample_error
	_clear()
	match mode:
		"target":
			_build_target()
		"map":
			_build_map()
		_:
			add_child(_note_label("알 수 없는 표시 방식이에요 (%s)." % mode, VERMILION))
	# 이번에 그려지지 않은 카드의 펼침 기억은 버린다(없어진 id 가 나중에 되살아나지 않게).
	for key in _open.keys():
		if not _cards.has(key):
			_open.erase(key)


func _clear() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()


## Work progress updates every frame; synchronize locks without rebuilding the
## map or replacing a finger's touch target while a cooking timer advances.
func set_busy(value: bool) -> void:
	if value == _busy:
		return
	_busy = value
	for node in find_children("*", "BaseButton", true, false):
		(node as BaseButton).disabled = value


## 다시 그리기 직전, 지금 보이는 카드의 펼침 상태를 기억한다.
func _remember_open() -> void:
	for key in _cards.keys():
		var card: Variant = _cards[key]
		if is_instance_valid(card):
			if bool((card as Object).get("expanded")):
				_open[key] = true
			else:
				_open.erase(key)
	_cards = {}


func _on_disclosure(expanded: bool, key: String) -> void:
	if expanded:
		_open[key] = true
	else:
		_open.erase(key)


# ---------- 입력 의도 (busy 면 아무 것도 보내지 않는다) ----------

func _on_select(id: String) -> void:
	if _busy:
		return
	target_selected.emit(id)


func _on_book() -> void:
	if _busy:
		return
	book_requested.emit()


func _on_find() -> void:
	if _busy:
		return
	exploration_requested.emit()


# ---------- 이번 실험 ----------

func _build_target() -> void:
	var valid := _valid_pages()
	var page: Dictionary = {}
	for p in valid:
		if str((p as Dictionary)["id"]) == _selected_id:
			page = p
	# The goal title is the clickable card itself, rather than a title plus a
	# second "details" row. Warnings and routes remain outside its hidden body.
	var box: VBoxContainer = self
	if page.is_empty():
		var title := _text("이번 실험 정보를 찾지 못했어요", 18, INK)
		title.name = "JournalTargetTitle"
		box.add_child(title)
		box.add_child(_text("연구 지도에서 목표를 다시 골라 주세요.", 14, MUTED))
		box.add_child(_book_row())
		return
	var total: int = int(page["total"])
	var progress: int = int(page["progress"])
	var details := _disclosure("@target:" + _selected_id, "JournalTargetDetails", str(page["title"]), "실험 목표 · %d/%d 조건" % [progress, total])
	details.title_label.name = "JournalTargetTitle"
	details.body.add_child(_text(str(page["hint"]), 14, MUTED))
	var criteria := _criteria_text(page)
	if criteria != "":
		details.body.add_child(_text(criteria, 14, INK))
	details.body.add_child(_text("단서 · %s" % str(page["origin"]), 13, MUTED))
	box.add_child(details)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_PASS
	row.add_theme_constant_override("separation", 8)
	box.add_child(row)
	var bar := _bar(progress, total)
	bar.name = "JournalTargetProgress"
	row.add_child(bar)
	var count := _text("%d/%d 조건" % [progress, total], 14, TEAL)
	count.name = "JournalTargetCount"
	# A shrinking wrapped label beside an expanding bar can receive almost
	# zero width and stack its digits vertically. Reserve its one-line width.
	count.autowrap_mode = TextServer.AUTOWRAP_OFF
	count.size_flags_horizontal = Control.SIZE_SHRINK_END
	row.add_child(count)
	var missing := _text("", 14, INK)
	missing.name = "JournalMissing"
	if bool(page["ready"]):
		missing.text = READY_TEXT
		missing.add_theme_color_override("font_color", TEAL)
	else:
		missing.text = _compact_missing(page["missing"] as Array)
	box.add_child(missing)
	if bool(page["tested"]):
		var tested := _text(TESTED_TEXT, 13, TEAL)
		tested.name = "JournalTested"
		details.body.add_child(tested)
	# 재료 부족/시식 거절은 접힌 카드 안에 숨기지 않고 바로 보여 준다.
	var needs := _need_text(page["unavailable"] as Array)
	var sample_error := _text("", 14, VERMILION)
	sample_error.name = "JournalSampleError"
	var lines: Array[String] = []
	if needs != "":
		lines.append(needs)
	if _sample_error != "":
		lines.append(_sample_error)
	sample_error.text = "\n".join(lines)
	sample_error.visible = not lines.is_empty()
	box.add_child(sample_error)
	var buttons := _book_row()
	var find := _button("재료 찾기", "JournalFindMaterials", _on_find)
	find.visible = not lines.is_empty()
	buttons.add_child(find)
	box.add_child(buttons)


func _book_row() -> HFlowContainer:
	var buttons := HFlowContainer.new()
	buttons.mouse_filter = Control.MOUSE_FILTER_PASS
	buttons.add_theme_constant_override("h_separation", 8)
	buttons.add_theme_constant_override("v_separation", 8)
	buttons.add_child(_button("연구 지도", "JournalOpenBook", _on_book))
	return buttons


# ---------- 연구 지도 ----------

func _build_map() -> void:
	var heading := _text("라멘 연구 지도", 22, INK)
	heading.name = "JournalHeading"
	add_child(heading)
	var valid := _valid_pages()
	var skipped: int = _pages.size() - valid.size()
	var matched: int = 0
	for p in valid:
		if bool((p as Dictionary)["tested"]):
			matched += 1
	var summary := _text("", 16, TEAL)
	summary.name = "JournalMapSummary"
	add_child(summary)
	if valid.is_empty():
		summary.text = "연구 주제 정보를 받지 못했어요"
		summary.add_theme_color_override("font_color", VERMILION)
		if skipped > 0:
			add_child(_note_label("형식이 맞지 않는 주제 %d개는 표시하지 않았어요." % skipped, VERMILION))
		return
	summary.text = "시식 노트와 맞는 주제 %d/%d" % [matched, valid.size()]
	add_child(_note_label(MAP_NOTE, MUTED))
	add_child(_note_label("한 레시피가 여러 주제에 맞을 수 있어요. 카드를 눌러 조건을 확인하세요.", MUTED))
	if skipped > 0:
		add_child(_note_label("형식이 맞지 않는 주제 %d개는 표시하지 않았어요." % skipped, VERMILION))
	var number: int = 0
	for p in valid:
		number += 1
		add_child(_theme_card(p, number))


func _theme_card(page: Dictionary, number: int) -> Control:
	var id: String = str(page["id"])
	var selected: bool = id == _selected_id
	var status := _status(page)
	var line: String = "%s · %d/%d 조건" % [str(status[0]), int(page["progress"]), int(page["total"])]
	if selected:
		line = "현재 목표 · " + line
	var card := _disclosure(id, "JournalTheme_" + id, "%d. %s" % [number, str(page["title"])], line)
	card.summary_label.add_theme_color_override("font_color", status[1])
	if selected:
		card.set_accent(VERMILION)
	var box: VBoxContainer = card.body
	box.add_child(_text(str(page["hint"]), 14, MUTED))
	var criteria := _criteria_text(page)
	if criteria != "":
		box.add_child(_text(criteria, 14, INK))
	box.add_child(_text("단서 · %s" % str(page["origin"]), 13, MUTED))
	var need := _need_text(page["unavailable"] as Array)
	if need != "":
		box.add_child(_text(need, 13, VERMILION))
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_PASS
	row.add_theme_constant_override("separation", 8)
	box.add_child(row)
	var bar := _bar(int(page["progress"]), int(page["total"]))
	bar.name = "JournalProgress_" + id
	row.add_child(bar)
	var count := _text("%d/%d" % [int(page["progress"]), int(page["total"])], 14, TEAL)
	count.name = "JournalCount_" + id
	count.autowrap_mode = TextServer.AUTOWRAP_OFF
	count.size_flags_horizontal = Control.SIZE_SHRINK_END
	row.add_child(count)
	var pick := _button("현재 목표" if selected else "이번 목표로", "JournalSelect_" + id, _on_select.bind(id))
	pick.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(pick)
	return card


## [상태 글, 색]. 시식함 > 시식 전 준비됨 > 재료 필요 > 미시도 순으로 가장 강한 상태 하나만 보인다.
func _status(page: Dictionary) -> Array:
	if bool(page["tested"]):
		return ["시식함 · 노트에 수록", TEAL]
	if bool(page["ready"]):
		return ["조건 완성 · 시식 전", TEAL]
	if not (page["unavailable"] as Array).is_empty():
		return ["재료가 더 필요해요", VERMILION]
	return ["아직 시도 전", MUTED]


# ---------- 검증/공통 ----------

## 펼침 카드를 만든다. 이름은 configure 전에 정하고, 기억해 둔 카드는 신호를 연결하기 전에 펼쳐서 기억을 건드리지 않는다.
func _disclosure(key: String, node_name: String, title: String, summary: String) -> Disclosure:
	var card := Disclosure.new()
	card.name = node_name
	card.configure(title, summary)
	card.header_button.disabled = _busy
	if _open.has(key):
		card.set_expanded(true)
	card.toggled.connect(_on_disclosure.bind(key))
	_cards[key] = card
	return card


## 필수 키와 자료형이 맞는 페이지만 돌려준다(순서 유지). 나머지는 호출자에게 알려야 하므로 개수 차이로 센다.
func _valid_pages() -> Array:
	var out: Array = []
	for p in _pages:
		if _page_ok(p):
			out.append(p)
	return out


func _page_ok(p: Variant) -> bool:
	if typeof(p) != TYPE_DICTIONARY:
		return false
	var d: Dictionary = p
	for key in _REQUIRED_KEYS:
		if not d.has(key):
			return false
	for key in ["id", "title", "hint", "origin"]:
		if typeof(d[key]) != TYPE_STRING:
			return false
	for key in ["criteria", "missing", "unavailable"]:
		if typeof(d[key]) != TYPE_ARRAY:
			return false
	if typeof(d["tested"]) != TYPE_BOOL or typeof(d["ready"]) != TYPE_BOOL:
		return false
	if typeof(d["progress"]) != TYPE_INT or typeof(d["total"]) != TYPE_INT:
		return false
	var total: int = d["total"]
	var progress: int = d["progress"]
	return total >= 0 and progress >= 0 and progress <= total and str(d["id"]) != ""


## 접힌 카드에 바로 보이는 못 채운 조건: 앞의 MISSING_SHOWN 개와 나머지 개수.
func _compact_missing(items: Array) -> String:
	var shown: Array = items.slice(0, MISSING_SHOWN)
	var text := _bullets(shown)
	if items.size() > shown.size():
		text += "\n· 외 %d가지" % (items.size() - shown.size())
	return text


func _bullets(items: Array) -> String:
	var lines: Array[String] = []
	for item in items:
		lines.append("· " + str(item))
	return "\n".join(lines)


## 모든 조건을 완료/필요로 표시한 글. 못 채운 조건은 page.missing 에 같은 힌트가 있는지로 가린다.
func _criteria_text(page: Dictionary) -> String:
	var missing: Array = page["missing"]
	var lines: Array[String] = []
	for c in (page["criteria"] as Array):
		if typeof(c) != TYPE_DICTIONARY or not (c as Dictionary).has("hint"):
			continue
		var hint: String = str((c as Dictionary)["hint"])
		lines.append(("필요 · " if missing.has(hint) else "완료 · ") + hint)
	return "\n".join(lines)


func _need_text(unavailable: Array) -> String:
	if unavailable.is_empty():
		return ""
	var names: Array[String] = []
	for id in unavailable:
		var item: Dictionary = Catalog.find(str(id))
		names.append(str(item["name"]) if not item.is_empty() else str(id))
	return "아직 구하지 못한 재료가 있어요: " + ", ".join(names)


func _card(selected: bool) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_PASS
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _box(CREAM if selected else PAPER_LIGHT, VERMILION if selected else WOOD_D, 4 if selected else 3, 12.0, 10.0))
	return panel


func _bar(value: int, total: int) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.min_value = 0
	bar.max_value = maxi(total, 1)
	bar.value = value
	bar.show_percentage = false
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.custom_minimum_size = Vector2(0, 14)
	bar.add_theme_stylebox_override("background", _box(PAPER_DARK, WOOD_D, 2, 0.0, 0.0))
	bar.add_theme_stylebox_override("fill", _box(TEAL, TEAL, 0, 0.0, 0.0))
	return bar


func _text(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


func _note_label(text: String, color: Color) -> Label:
	return _text(text, 13, color)


func _button(text: String, node_name: String, callback: Callable) -> Button:
	var button := Button.new()
	button.name = node_name
	button.text = text
	# 손가락을 버튼 위에서 밀어도 부모 ScrollContainer 가 드래그를 받는다.
	button.mouse_filter = Control.MOUSE_FILTER_PASS
	button.custom_minimum_size = Vector2(120, MIN_BUTTON_HEIGHT)
	button.disabled = _busy
	button.pressed.connect(callback)
	return button


func _box(bg: Color, border: Color, border_w: int, mx: float, my: float) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(border_w)
	sb.content_margin_left = mx
	sb.content_margin_right = mx
	sb.content_margin_top = my
	sb.content_margin_bottom = my
	return sb
