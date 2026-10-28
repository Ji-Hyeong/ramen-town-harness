extends VBoxContainer
## 재료 목표 보드: 지역/지역연계 목록 -> 재료별 실제 준비 상태와 길.
## 보드는 상태를 갖지 않는다. ForagingPlan 이 읽은 사실만 보여 주고, 눌러도 ID 신호만 보낸다.
## 출발/결제/개발/시식/적용은 신호를 받은 쪽(실제 컨트롤러)이 다시 계산해 열 뿐이며, 보드는 아무것도 바꾸지 않는다.
## 목록/상세 전환은 이 보드 안의 화면 상태일 뿐 저장하지 않는다.
##
## 버튼 이름: GoalOpen_<방향>, GoalSelect_<방향>, GoalSource_<재료>, GoalDevelop_<재료>, GoalBoardBack.
## 눌림/드래그 취소는 기존 Shared.make_button 과 같다(손을 떼야 눌리고, 스크롤로 넘어가면 취소).

signal target_selected(direction_id: String)
signal source_requested(direction_id: String, ingredient_id: String)
signal develop_requested(direction_id: String, ingredient_id: String)

const SHARED_PATH := "res://scripts/ui/service_result_view.gd"
const Plan = preload("res://scripts/ui/foraging_plan.gd")
const Art = preload("res://scripts/ui/bowl_editor_art.gd")
const Mock = preload("res://scripts/ui/mock_fidelity_art.gd")
const Pixel = preload("res://scripts/ui/pixel_art.gd")
const BODY = preload("res://assets/fonts/Pretendard-Regular.otf")
const BOLD = preload("res://assets/fonts/Pretendard-Bold.otf")
const INK := Color("18354f")
const MUTED := Color("685c50")
const RED := Color("aa3828")
const TEAL := Color("087e80")
const CARD_MIN_HEIGHT: float = 78.0
const ART_SIZE: float = 48.0
const CHEVRON_SIZE: float = 24.0
## 그림 틀(테두리 약 10px)과 글자가 겹치지 않도록 둔 안쪽 여백.
const PAD_X: int = 18
const PAD_Y: int = 12
const TITLE_SIZE: int = 16
const BODY_SIZE: int = 14

## 같은 재료 그림은 한 번만 만든다.
static var _pictures: Dictionary = {}

var _plans: Array = []
var _selected: String = ""
var _busy: bool = false
var _detail: String = ""
var _group: String = "regional"
var _shown: Dictionary = {}
## 눌려 있는 동안 흰색으로 바꿀 글자/화살표. 카드마다 따로 보관한다.
var _held_parts: Dictionary = {}


func _init() -> void:
	name = "ForagingGoalBoard"
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mouse_filter = Control.MOUSE_FILTER_PASS
	add_theme_constant_override("separation", 10)


## 모델(읽은 사실, 선택, 바쁨, 상세 화면)이 이전과 같으면 아무것도 다시 만들지 않는다. 누르는 도중 버튼이 사라지지 않게 한다.
func present(state: Object, selected_id: String = "", busy: bool = false) -> void:
	var plans: Array = Plan.catalog(state)
	# Reopening a selected cross-region goal lands in its category; refreshing
	# the same selection preserves the category the player is currently browsing.
	if _selected!=selected_id or _shown.is_empty():
		for plan in plans:
			if plan["id"]==selected_id:_group=str(plan.get("category","regional"))
	var next: Dictionary = {"plans": plans, "selected": selected_id, "busy": busy, "detail": _detail,"group":_group}
	if not _plan_ids(plans).has(_detail):
		_detail = ""
		next["detail"] = ""
	if next == _shown:
		return
	_plans = plans
	_selected = selected_id
	_busy = busy
	_shown = next
	_rebuild()


## 마지막으로 보여 준 모델의 복사본(검사용). 보드가 상태를 소유하지 않음을 시험이 확인할 수 있게 한다.
func shown_model() -> Dictionary:
	return _shown.duplicate(true)


func detail_id() -> String:
	return _detail


## 상세로 들어가거나 목록으로 돌아간다. 화면 상태만 바꾸고 신호는 보내지 않는다.
func open_detail(direction_id: String) -> void:
	if _detail == direction_id or not _plan_ids(_plans).has(direction_id):
		return
	_detail = direction_id
	_group=str(_plan_of(direction_id).get("category","regional"))
	_shown["detail"] = direction_id
	_shown["group"] = _group
	_rebuild()


func show_list() -> void:
	if _detail == "":
		return
	_detail = ""
	_shown["detail"] = ""
	_rebuild()


# ---------- 화면 만들기 ----------

func _rebuild() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_held_parts.clear()
	if _plans.is_empty() or str(_plans[0]["error"]) != "":
		add_child(_text("GoalBoardNotice", "재료 목표를 불러올 수 없어요.", BODY_SIZE, BODY, MUTED))
		return
	var plan: Dictionary = _plan_of(_detail)
	if plan.is_empty():
		_build_list()
	else:
		_build_detail(plan)


func _build_list() -> void:
	add_child(_text("GoalBoardTitle", "재료 목표", 20, BOLD, INK))
	add_child(_text("GoalBoardHint", "만들어 보고 싶은 실험을 고르면 필요한 재료를 보여 줘요.", BODY_SIZE, BODY, MUTED))
	var groups:=HBoxContainer.new()
	groups.add_theme_constant_override("separation",8)
	add_child(groups)
	for group in ["regional","cross_region"]:
		var choose:=_button("지역 실험" if group=="regional" else "지역 연계","GoalGroup_"+group,"teal" if group==_group else "summary")
		choose.pressed.connect(_select_group.bind(group))
		groups.add_child(choose)
	for plan in _plans:
		if str(plan.get("category","regional"))!=_group:continue
		var id: String = str(plan["id"])
		var title: String = str(plan["title"])
		var hint: String = _list_hint(plan)
		var broken: bool = str(plan["error"]) != ""
		var card: Control = _card("GoalOpen_" + id, title, hint, _art_ids(plan), not broken, broken)
		_bind(card, _on_open.bind(id))
		add_child(card)


## Category navigation is UI state only; no target or transaction is emitted.
func _select_group(group: String) -> void:
	_group=group
	_detail=""
	_shown["group"]=group
	_shown["detail"]=""
	_rebuild()


func _build_detail(plan: Dictionary) -> void:
	var id: String = str(plan["id"])
	var back: Button = _button("목록으로", "GoalBoardBack", "summary")
	back.custom_minimum_size = Vector2(0, 48)
	back.pressed.connect(show_list)
	add_child(back)
	add_child(_text("GoalDetailTitle", str(plan["title"]), 20, BOLD, INK))
	add_child(_text("GoalDetailBrief", str(plan["brief"]), BODY_SIZE, BODY, MUTED))
	if bool(plan["tested"]):
		add_child(_text("GoalDetailTested", "이 방향의 시식 기록이 있어요.", BODY_SIZE, BOLD, TEAL))
	add_child(_text("GoalDetailSource", "재료는 " + str(plan["source"]) + "에서 구해요.", BODY_SIZE, BODY, MUTED))
	for row in plan["ingredients"]:
		add_child(_ingredient_panel(id, plan, row))
	var select_text: String = "이 목표로 정하기"
	if _busy:
		select_text = "작업 중에는 정할 수 없어요"
	elif _selected == id:
		select_text = "선택한 목표"
	var select: Button = _button(select_text, "GoalSelect_" + id, "gold")
	select.custom_minimum_size = Vector2(0, 56)
	select.disabled = _busy or _selected == id
	select.add_theme_stylebox_override("disabled", Mock.style("summary"))
	select.add_theme_color_override("font_disabled_color", MUTED)
	if "accessibility_name" in select:
		select.set("accessibility_name", select_text)
	select.pressed.connect(_on_select.bind(id))
	add_child(select)


## 재료 한 칸: 그림 + 이름/상태/막힘 이유, 아래에 길 버튼(항상 열람 동작)과 필요하면 개발 버튼.
func _ingredient_panel(direction_id: String, plan: Dictionary, row: Dictionary) -> Control:
	var ingredient_id: String = str(row["id"])
	var panel := PanelContainer.new()
	panel.name = "GoalIngredient_" + ingredient_id
	panel.mouse_filter = Control.MOUSE_FILTER_PASS
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", Mock.style("summary"))
	var margin := _margin(PAD_X, PAD_X, PAD_Y, PAD_Y)
	panel.add_child(margin)
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_PASS
	column.add_theme_constant_override("separation", 8)
	margin.add_child(column)
	var head := HBoxContainer.new()
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_theme_constant_override("separation", 10)
	column.add_child(head)
	head.add_child(_picture(ingredient_id, ART_SIZE))
	var texts := VBoxContainer.new()
	texts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	texts.add_theme_constant_override("separation", 2)
	head.add_child(texts)
	texts.add_child(_text("GoalName_" + ingredient_id, str(row["name"]), TITLE_SIZE, BOLD, INK))
	texts.add_child(_text("GoalStatus_" + ingredient_id, str(row["status"]), BODY_SIZE, BODY, MUTED))
	if str(row["note"]) != "":
		column.add_child(_text("GoalNote_" + ingredient_id, str(row["note"]), BODY_SIZE, BODY, MUTED))
	column.add_child(_text("GoalRoute_" + ingredient_id, _route_text(row), BODY_SIZE, BODY, MUTED))
	if not bool(row["can_depart"]) and str(row["reason"]) != "":
		column.add_child(_text("GoalBlock_" + ingredient_id, str(row["reason"]), BODY_SIZE, BODY, RED))
	# 막혀 있어도 열람은 된다: 눌러도 출발하지 않고 실제 화면에서 다시 확인한다.
	var source_text: String = "공급처 탐험 보기" if str(row["mode"]) == Plan.MODE_SUPPLIER else "연구 샘플 채집 보기"
	var source: Button = _button(source_text, "GoalSource_" + ingredient_id, "summary")
	source.disabled = _busy
	source.pressed.connect(_on_source.bind(direction_id, ingredient_id))
	column.add_child(source)
	# 개발/실험 버튼: 쓸 수 있는 재료(또는 이미 만든 완성품)일 때만 열린다. 눌러도 열람 신호일 뿐 시식/적용은 아니다.
	var develop_text: String = "이 재료로 실험"
	if bool(row["develops"]):
		var noun: String = "육수" if str(plan["slot"]) == "broth" else "면"
		develop_text = ("완성한 %s 보기" if bool(row["prepared"]) else "%s 개발 보기") % noun
	var develop: Button = _button(develop_text, "GoalDevelop_" + ingredient_id, "summary")
	develop.disabled = _busy or not bool(row["usable"])
	develop.pressed.connect(_on_develop.bind(direction_id, ingredient_id))
	column.add_child(develop)
	return panel


## 카드 전체가 하나의 진짜 버튼이다. 그림/글자는 입력을 받지 않고 눌린 동안 흰색으로 바뀐다.
func _card(node_name: String, title: String, hint: String, art_ids: Array, chevron: bool, locked: bool) -> Control:
	var root := PanelContainer.new()
	root.name = node_name + "Card"
	root.mouse_filter = Control.MOUSE_FILTER_PASS
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.custom_minimum_size = Vector2(0, CARD_MIN_HEIGHT)
	root.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	var button: Button = _button("", node_name, "summary")
	button.custom_minimum_size = Vector2(0, CARD_MIN_HEIGHT)
	button.disabled = locked
	if "accessibility_name" in button:
		button.set("accessibility_name", title if hint == "" else "%s, %s" % [title, hint])
	root.add_child(button)
	# 버튼 위에 얹힌 내용은 입력을 받지 않아 눌림은 항상 아래 버튼이 받고, 글이 늘면 카드도 같이 커진다.
	var margin := _margin(PAD_X, PAD_X - 4, PAD_Y, PAD_Y)
	root.add_child(margin)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 10)
	margin.add_child(row)
	for art_id in art_ids:
		row.add_child(_picture(str(art_id), ART_SIZE))
	var texts := VBoxContainer.new()
	texts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	texts.add_theme_constant_override("separation", 2)
	row.add_child(texts)
	var title_label: Label = _text("GoalCardTitle", title, TITLE_SIZE, BOLD, INK)
	texts.add_child(title_label)
	var hint_label: Label = _text("GoalCardHint", hint, BODY_SIZE, BODY, MUTED)
	hint_label.visible = hint != ""
	texts.add_child(hint_label)
	var parts: Array = [[title_label, INK], [hint_label, MUTED]]
	if chevron:
		var arrow := TextureRect.new()
		arrow.name = "GoalChevron"
		arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		arrow.texture = Art.icon("chevron_right")
		arrow.custom_minimum_size = Vector2(CHEVRON_SIZE, CHEVRON_SIZE)
		arrow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		arrow.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		arrow.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		arrow.modulate = INK
		row.add_child(arrow)
		parts.append([arrow, INK])
	_held_parts[button] = parts
	button.button_down.connect(_set_held.bind(button, true))
	button.button_up.connect(_set_held.bind(button, false))
	return root


func _bind(card: Control, callback: Callable) -> void:
	var button: Button = _button_of(card)
	if button != null:
		button.pressed.connect(callback)


func _button_of(card: Control) -> Button:
	return card.get_child(0) as Button


## 누르는 동안(true)은 흰색, 손을 떼거나 취소하면(false) 원래 색으로 되돌린다.
func _set_held(button: Button, held: bool) -> void:
	if not _held_parts.has(button):
		return
	for part in _held_parts[button]:
		var node: CanvasItem = part[0]
		if not is_instance_valid(node):
			continue
		if node is Label:
			(node as Label).add_theme_color_override("font_color", Color.WHITE if held else part[1])
		else:
			node.modulate = Color.WHITE if held else part[1]


# ---------- 신호 (ID 만 보낸다) ----------

func _on_open(direction_id: String) -> void:
	open_detail(direction_id)


func _on_select(direction_id: String) -> void:
	if _busy:
		return
	target_selected.emit(direction_id)


func _on_source(direction_id: String, ingredient_id: String) -> void:
	if _busy:
		return
	source_requested.emit(direction_id, ingredient_id)


func _on_develop(direction_id: String, ingredient_id: String) -> void:
	if _busy:
		return
	for row in _plan_of(direction_id).get("ingredients", []):
		if str(row["id"]) == ingredient_id and not bool(row["usable"]):
			return
	develop_requested.emit(direction_id, ingredient_id)


# ---------- 문구 ----------

func _list_hint(plan: Dictionary) -> String:
	var parts: Array[String] = []
	if str(plan["error"]) != "":
		return str(plan["error"])
	if str(plan["id"]) == _selected:
		parts.append("선택 중")
	if bool(plan["tested"]):
		parts.append("시식함")
	if str(plan.get("category","regional"))=="cross_region":
		# Keep status and numeric readiness on separate short lines even after
		# selection+tasting. Otherwise the final unit can become an orphan line.
		var ready: int=0
		for row in plan["ingredients"]:
			if bool(row["sample_ready"]):ready+=1
		return (" · ".join(parts)+"\n" if not parts.is_empty() else "")+"샘플 %d/%d" % [ready,plan["ingredients"].size()]
	if bool(plan["ready"]):
		parts.append("샘플 준비됨")
	else:
		for row in plan["ingredients"]:
			if str(row["id"]) == str(plan["focus"]):
				parts.append("%s %s" % [row["name"], row["status"]])
	return " · ".join(parts)


func _route_text(row: Dictionary) -> String:
	return "%s · 출발비 %s" % [row["source_title"], _won(int(row["fee"]))]


static func _won(amount: int) -> String:
	var digits: String = str(absi(amount))
	var out: String = ""
	while digits.length() > 3:
		out = "," + digits.substr(digits.length() - 3) + out
		digits = digits.substr(0, digits.length() - 3)
	return ("-" if amount < 0 else "") + digits + out + "원"


# ---------- 조각 ----------

func _plan_of(direction_id: String) -> Dictionary:
	for plan in _plans:
		if str(plan["id"]) == direction_id:
			return plan
	return {}


func _plan_ids(plans: Array) -> Array:
	var ids: Array = []
	for plan in plans:
		if str(plan["error"]) == "":
			ids.append(str(plan["id"]))
	return ids


## 카드 그림: 방향의 모든 필요 재료 그림. 두 재료 방향도 둘 다 보인다.
func _art_ids(plan: Dictionary) -> Array:
	var ids: Array = []
	for row in plan["ingredients"]:
		ids.append(str(row["id"]))
	return ids


func _button(text: String, node_name: String, skin: String) -> Button:
	# service_result_view 도 편집기를 불러오므로 preload 하면 정적 순환이 된다. 버튼 공장만 실행 중에 불러온다.
	var shared: GDScript = load(SHARED_PATH)
	var button: Button = shared.make_button(text, node_name, skin)
	if text != "" and "accessibility_name" in button:
		button.set("accessibility_name", text)
	return button


func _margin(left: int, right: int, top: int, bottom: int) -> MarginContainer:
	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", left)
	margin.add_theme_constant_override("margin_right", right)
	margin.add_theme_constant_override("margin_top", top)
	margin.add_theme_constant_override("margin_bottom", bottom)
	return margin


func _text(node_name: String, text: String, font_size: int, font: Font, color: Color) -> Label:
	var label := Label.new()
	label.name = node_name
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# 긴 문장은 단어 단위로, 폭보다 긴 단어는 글자 단위로 줄바꿈해 옆 칸을 밀지 않는다.
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


func _picture(ingredient_id: String, side: float) -> TextureRect:
	var picture := TextureRect.new()
	picture.name = "GoalArt_" + ingredient_id
	var texture: Texture2D = _food(ingredient_id)
	picture.texture = texture
	picture.material = Art.image_material(texture)
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	picture.custom_minimum_size = Vector2(side, side)
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	picture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	picture.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return picture


## 탐험 화면과 같은 원본 재료 그림 규칙: 육수는 냄비, 메밀면/고명은 음식 그림, 나머지는 작은 재료 그림.
static func _food(ingredient_id: String) -> Texture2D:
	if not _pictures.has(ingredient_id):
		if ingredient_id == "noodle_buckwheat" or ingredient_id.begins_with("topping_"):
			_pictures[ingredient_id] = Art.food(ingredient_id)
		elif ingredient_id.begins_with("broth_"):
			_pictures[ingredient_id] = Mock.texture("pot")
		else:
			_pictures[ingredient_id] = Pixel.scaled_tex(Pixel.icon_image(ingredient_id), 3)
	return _pictures[ingredient_id]
