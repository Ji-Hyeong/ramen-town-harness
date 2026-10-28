extends VBoxContainer
## 메뉴 정체성 카드 한 장. 시식 직후(kind=tasting)와 영업 영수증(kind=sales) 두 모양을 같은 틀로 보여 준다.
## 모델은 MenuIdentity.describe / MenuIdentity.sales 가 만든 사실뿐이다. 카드는 점수를 계산하지 않고 게임 상태도 갖지 않는다.
##
## - 시식 카드: 실제 재료 그림(최대 3), 제목과 특징(최대 2), "시식 취향" 손님. 실제 구매가 아니라는 설명을 함께 적는다.
## - 판매 카드: 같은 재료 그림과 제목, 실제 판매 그릇 수/재료비를 뺀 금액/(있을 때) 평균 대기, "실제 주문"이 가장 많은 손님.
##   그릇 구성이 남아 있지 않은 예전 영수증은 정체성 없이 판매 사실만 읽을 수 있게 보여 준다.
## - 카드 전체가 하나의 진짜 버튼(MenuIdentityOpen)이다. 그림/글자는 입력을 받지 않아 눌림과 드래그 취소(손을 떼야 눌리고,
##   스크롤로 넘어가면 취소)는 기존 Shared.make_button 과 같다. 누르면 details_requested 신호만 보낸다(화면을 여는 쪽의 몫).
## - 잘못된 모델이면 눈에 띄는 안내 글을 보이고 버튼을 잠근다. 예전 영수증(정체성 없음)도 잠그지만 판매 사실은 그대로 읽힌다.
## - 발견 연출은 play_reveal() 을 호스트가 명시적으로 부를 때만 한 번 돈다. present()/다시 열기/상세 전환은 절대 자동 재생하지 않는다.
##   연출은 투명도와 크기만 잠깐 바꾸고 끝나면 정지 화면과 똑같은 상태로 돌아간다(상태/보상/화면 이동 없음).

signal details_requested()

const SHARED_PATH := "res://scripts/ui/service_result_view.gd"
const Mock = preload("res://scripts/ui/mock_fidelity_art.gd")
const Art = preload("res://scripts/ui/bowl_editor_art.gd")
const Pixel = preload("res://scripts/ui/pixel_art.gd")
const BODY = preload("res://assets/fonts/Pretendard-Regular.otf")
const BOLD = preload("res://assets/fonts/Pretendard-Bold.otf")
const INK := Color("18354f")
const MUTED := Color("685c50")
const TEAL := Color("087e80")
const RED := Color("aa3828")
const MIN_HEIGHT: float = 78.0
const ART_SIZE: float = 32.0
const PORTRAIT_SIZE: float = 32.0
const CHEVRON_SIZE: float = 24.0
## 그림 틀(테두리 약 10px)과 글자가 겹치지 않도록 둔 안쪽 여백.
const PAD_X: int = 18
const PAD_Y: int = 12
const TITLE_SIZE: int = 16
const BODY_SIZE: int = 14
## 한 줄에 그릴 초상 최대 수. 더 많은 동점자는 글에서 "외 N명"으로 정확히 밝힌다.
const MAX_PORTRAITS: int = 3
const REVEAL_SECONDS: float = 0.3

## 시식 점수(맛 평가)와 실제 주문을 구분하는 짧은 이름표.
const MODE_TASTING := "시식 점수"
const MODE_SALES := "많이 주문한 손님"

## 같은 그림은 한 번만 만든다(카드가 여러 장이어도 텍스처를 공유).
static var _pictures: Dictionary = {}
static var _portraits: Dictionary = {}

var button: Button
var title_label: Label
var features_label: Label
var mode_label: Label
var line_label: Label
var stats_label: Label
var notice_label: Label
var chevron: TextureRect

var _holder: PanelContainer
var _column: VBoxContainer
var _art_row: HBoxContainer
var _portrait_row: HBoxContainer
var _taste_block: HBoxContainer
var _shown: Dictionary = {}
var _can_open: bool = false
var _revealable: bool = false
var _reveal_tween: Tween
var _reveals: int = 0
## 눌린 동안 흰색으로 바꿀 글자와 원래 색.
var _base_colors: Dictionary = {}


func _init() -> void:
	name = "MenuIdentityCard"
	mouse_filter = Control.MOUSE_FILTER_PASS
	focus_mode = Control.FOCUS_NONE
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 0)

	# PanelContainer 는 자식 중 가장 큰 최소 크기로 자란다: 맨 아래 버튼 위에 안 눌리는 내용을 겹쳐서
	# 글이 줄바꿈되면 카드 높이도 같이 커지고 눌림은 항상 아래 진짜 버튼이 받는다.
	_holder = PanelContainer.new()
	_holder.name = "MenuIdentityFrame"
	_holder.mouse_filter = Control.MOUSE_FILTER_PASS
	_holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_holder.custom_minimum_size = Vector2(0, MIN_HEIGHT)
	_holder.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	add_child(_holder)

	# service_result_view 도 편집기를 불러오므로 preload 하면 정적 순환이 된다. 버튼 공장만 실행 중에 불러온다.
	var shared: GDScript = load(SHARED_PATH)
	button = shared.make_button("", "MenuIdentityOpen", "summary")
	button.custom_minimum_size = Vector2(0, MIN_HEIGHT)
	button.add_theme_stylebox_override("disabled", Mock.style("summary"))
	button.add_theme_color_override("font_disabled_color", MUTED)
	button.button_down.connect(_set_held.bind(true))
	button.button_up.connect(_set_held.bind(false))
	button.pressed.connect(_on_pressed)
	_holder.add_child(button)

	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", PAD_X)
	margin.add_theme_constant_override("margin_right", PAD_X - 4)
	margin.add_theme_constant_override("margin_top", PAD_Y)
	margin.add_theme_constant_override("margin_bottom", PAD_Y)
	_holder.add_child(margin)

	_column = VBoxContainer.new()
	_column.name = "MenuIdentityContent"
	_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_column.add_theme_constant_override("separation", 8)
	margin.add_child(_column)

	var head := HBoxContainer.new()
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_theme_constant_override("separation", 10)
	_column.add_child(head)
	_art_row = HBoxContainer.new()
	_art_row.name = "MenuIdentityArt"
	_art_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_art_row.add_theme_constant_override("separation", 4)
	_art_row.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(_art_row)
	var texts := VBoxContainer.new()
	texts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	texts.add_theme_constant_override("separation", 2)
	head.add_child(texts)
	title_label = _label("MenuIdentityTitle", TITLE_SIZE, BOLD, INK)
	texts.add_child(title_label)
	features_label = _label("MenuIdentityFeatures", BODY_SIZE, BODY, MUTED)
	texts.add_child(features_label)
	chevron = TextureRect.new()
	chevron.name = "MenuIdentityChevron"
	chevron.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chevron.texture = Art.icon("chevron_right")
	chevron.custom_minimum_size = Vector2(CHEVRON_SIZE, CHEVRON_SIZE)
	chevron.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	chevron.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	chevron.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	chevron.modulate = INK
	head.add_child(chevron)

	# 손님 한 줄: 초상 + (모드 설명, 손님 설명). 모드 설명이 시식 취향과 실제 구매를 구분한다.
	_taste_block = HBoxContainer.new()
	_taste_block.name = "MenuIdentityCustomers"
	_taste_block.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_taste_block.add_theme_constant_override("separation", 10)
	_column.add_child(_taste_block)
	_portrait_row = HBoxContainer.new()
	_portrait_row.name = "MenuIdentityPortraits"
	_portrait_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_portrait_row.add_theme_constant_override("separation", 4)
	_portrait_row.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_taste_block.add_child(_portrait_row)
	var who := VBoxContainer.new()
	who.mouse_filter = Control.MOUSE_FILTER_IGNORE
	who.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	who.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	who.add_theme_constant_override("separation", 2)
	_taste_block.add_child(who)
	mode_label = _label("MenuIdentityMode", BODY_SIZE, BOLD, TEAL)
	who.add_child(mode_label)
	line_label = _label("MenuIdentityCustomer", BODY_SIZE, BODY, INK)
	who.add_child(line_label)

	stats_label = _label("MenuIdentityStats", BODY_SIZE, BODY, INK)
	_column.add_child(stats_label)
	notice_label = _label("MenuIdentityNotice", BODY_SIZE, BOLD, RED)
	_column.add_child(notice_label)
	_show_error("")


## 모델(MenuIdentity.describe/sales 결과)을 그린다. 이전과 같은 모델이면 아무것도 다시 만들지 않는다.
## 여기서는 연출을 시작하지 않는다. 진행 중이던 연출은 정지 화면 상태로 끝낸다.
func present(model: Dictionary) -> void:
	if model == _shown and not _shown.is_empty():
		return
	_finish_reveal()
	_shown = model.duplicate(true)
	var kind: String = str(model.get("kind", ""))
	var error: String = str(model.get("error", ""))
	if error == "" and kind != "tasting" and kind != "sales":
		error = "메뉴 정보를 확인할 수 없어요."
	if error != "":
		_show_error(error)
		return
	var available: bool = bool(model.get("available", false))
	var rows_error: String = _customers_error(model, kind, available)
	if rows_error != "":
		_show_error(rows_error)
		return
	_revealable = available
	_can_open = available
	notice_label.visible = false
	_set_pictures(_art_row, _material_textures(model.get("materials", [])), ART_SIZE)
	if available:
		title_label.text = str(model.get("headline", ""))
		features_label.text = " · ".join(PackedStringArray(_strings(model.get("features", []))))
		features_label.visible = features_label.text != ""
	else:
		# 예전 영수증: 현재 초안이나 이름으로 되살리지 않고 없다는 사실만 말한다.
		title_label.text = str(model.get("recipe_name", ""))
		features_label.text = ""
		features_label.visible = false
		notice_label.text = str(model.get("note", "그릇 구성 기록이 없어요."))
		notice_label.add_theme_color_override("font_color", MUTED)
		_base_colors[notice_label] = MUTED
		notice_label.visible = true
	if title_label.text == "":
		title_label.text = "메뉴"
	_art_row.visible = _art_row.get_child_count() > 0
	_fill_customers(model, kind)
	_fill_stats(model, kind)
	chevron.visible = _can_open
	button.disabled = not _can_open
	_set_held(false)
	if "accessibility_name" in button:
		button.set("accessibility_name", _spoken())
	update_minimum_size()


## 마지막으로 보여 준 모델의 복사본(검사용). 카드가 상태를 소유하지 않음을 시험이 확인할 수 있게 한다.
func shown_model() -> Dictionary:
	return _shown.duplicate(true)


## 발견 연출. 호스트가 실제로 막 끝난 시식에서만 한 번 부른다. 내용이 없거나 잘못된 모델, 화면 밖이면 아무것도 하지 않는다.
## 투명도와 크기만 잠깐 바꾸고 끝나면 정지 화면과 똑같은 상태로 돌아간다.
func play_reveal() -> void:
	if not _revealable or not is_inside_tree():
		return
	_finish_reveal()
	_reveals += 1
	_column.modulate.a = 0.0
	_art_row.pivot_offset = _art_row.size * 0.5
	_art_row.scale = Vector2(0.8, 0.8)
	_reveal_tween = create_tween()
	_reveal_tween.set_parallel(true)
	_reveal_tween.tween_property(_column, "modulate:a", 1.0, REVEAL_SECONDS)
	_reveal_tween.tween_property(_art_row, "scale", Vector2.ONE, REVEAL_SECONDS).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_reveal_tween.finished.connect(_finish_reveal)


## 연출이 시작된 횟수와 진행 여부(검사용). present()가 이 숫자를 올리지 않아야 한다.
func reveal_count() -> int:
	return _reveals


func reveal_active() -> bool:
	return _reveal_tween != null and _reveal_tween.is_valid() and _reveal_tween.is_running()


# ---------- 화면 만들기 ----------

func _show_error(message: String) -> void:
	_finish_reveal()
	_revealable = false
	_can_open = false
	for child in _art_row.get_children():
		_art_row.remove_child(child)
		child.queue_free()
	_art_row.visible = false
	_taste_block.visible = false
	stats_label.visible = false
	features_label.visible = false
	chevron.visible = false
	button.disabled = true
	title_label.text = "메뉴 정체성을 불러올 수 없어요"
	notice_label.text = message if message != "" else "메뉴 정보를 확인할 수 없어요."
	notice_label.add_theme_color_override("font_color", RED)
	_base_colors[notice_label] = RED
	notice_label.visible = true
	_set_held(false)
	if "accessibility_name" in button:
		button.set("accessibility_name", "%s, %s" % [title_label.text, notice_label.text])


## 손님 줄. 시식은 취향 점수가 가장 높은 손님(동점이면 모두), 판매는 실제 주문이 가장 많은 손님(동점이면 모두).
func _fill_customers(model: Dictionary, kind: String) -> void:
	var raw_rows: Variant = model.get("customers", [])
	# 모양이 틀린 항목은 건너뛴다(손님 줄이 없는 것으로 보여 주고 거짓 손님을 만들지 않는다).
	var rows: Array = []
	if typeof(raw_rows) == TYPE_ARRAY:
		for row in raw_rows:
			if typeof(row) == TYPE_DICTIONARY:
				rows.append(row)
	var ids: Array = []
	var names: Array[String] = []
	for row in rows:
		ids.append(str((row as Dictionary).get("id", "")))
		names.append(str((row as Dictionary).get("name", "")))
	var textures: Array = []
	for i in mini(ids.size(), MAX_PORTRAITS):
		textures.append(_portrait_for(str(ids[i])))
	_set_pictures(_portrait_row, textures, PORTRAIT_SIZE)
	_portrait_row.visible = _portrait_row.get_child_count() > 0
	mode_label.text = MODE_TASTING if kind == "tasting" else MODE_SALES
	_taste_block.visible = true
	if rows.is_empty():
		# 시식 모델은 present()에서 손님 줄이 없으면 오류로 거절했으므로 여기 오는 것은 주문이 없는 판매 카드뿐이다.
		line_label.text = "완료된 주문이 없어요."
		return
	var first: Dictionary = rows[0]
	var shown_names: Array[String] = []
	for i in mini(names.size(), MAX_PORTRAITS):
		shown_names.append(names[i])
	var who: String = "·".join(PackedStringArray(shown_names))
	if names.size() > MAX_PORTRAITS:
		who += " 외 %d명" % (names.size() - MAX_PORTRAITS)
	var tied: bool = names.size() > 1
	# 점수가 0점이어도 "가장 높다"고 꾸미지 않고 숫자만 그대로 적는다.
	if kind == "tasting":
		var score: int = int(first.get("score", 0))
		line_label.text = ("%s · 공동%d점" % [who, score]) if tied else ("%s · %d점" % [who, score])
	else:
		var units: int = int(first.get("units", 0))
		line_label.text = ("%s · 각%d그릇" % [who, units]) if tied else ("%s · %d그릇" % [who, units])


## 카드가 그릴 손님 줄의 최소 모양 검사. 사용 가능한 시식 모델은 손님이 하나 이상 있어야 한다.
## 판매 모델은 비어 있을 수 있지만(주문 없음) 있다면 모양이 맞아야 한다. 빈 칸을 "기록 없음"으로 꾸미지 않는다.
func _customers_error(model: Dictionary, kind: String, available: bool) -> String:
	var raw: Variant = model.get("customers", null)
	if typeof(raw) != TYPE_ARRAY:
		return "손님 정보가 없어요." if kind == "tasting" and available else ("" if kind == "sales" and not model.has("customers") else "손님 정보 모양이 올바르지 않아요.")
	var rows: Array = raw
	if kind == "tasting" and available and rows.is_empty():
		return "시식 손님 정보가 비어 있어요."
	var key: String = "score" if kind == "tasting" else "units"
	for row in rows:
		if typeof(row) != TYPE_DICTIONARY:
			return "손님 정보 모양이 올바르지 않아요."
		var d: Dictionary = row
		if typeof(d.get("id")) != TYPE_STRING or str(d["id"]) == "" or typeof(d.get("name")) != TYPE_STRING or str(d["name"]) == "":
			return "손님 정보 모양이 올바르지 않아요."
		if typeof(d.get(key)) != TYPE_INT:
			return "손님 정보 모양이 올바르지 않아요."
	return ""


## 판매 사실 줄. 마진은 재료비만 뺀 금액이고 운영비는 포함하지 않는다. 평균 대기는 모델이 계산한 값이 있을 때만 적는다.
func _fill_stats(model: Dictionary, kind: String) -> void:
	stats_label.visible = kind == "sales"
	if kind != "sales":
		return
	var units: int = int(model.get("units", 0))
	var text: String = "판매 %d그릇" % units
	if units > 0:
		text += " · 재료비를 뺀 금액 %s" % _won(int(model.get("margin", 0)))
	if bool(model.get("has_wait", false)):
		text += " · 평균 대기 %.0f초" % float(model.get("average_wait", 0.0))
	stats_label.text = text


func _set_pictures(row: HBoxContainer, textures: Array, side: float) -> void:
	for child in row.get_children():
		row.remove_child(child)
		child.queue_free()
	for value in textures:
		var texture: Texture2D = value as Texture2D
		if texture == null:
			continue
		var picture := TextureRect.new()
		picture.name = "MenuIdentityPicture"
		picture.texture = texture
		picture.material = Art.image_material(texture)
		picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
		picture.custom_minimum_size = Vector2(side, side)
		picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		picture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		picture.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(picture)


func _material_textures(ids: Variant) -> Array:
	var out: Array = []
	if typeof(ids) != TYPE_ARRAY:
		return out
	for id in ids:
		out.append(_food(str(id)))
	return out


func _strings(values: Variant) -> Array[String]:
	var out: Array[String] = []
	if typeof(values) == TYPE_ARRAY:
		for value in values:
			out.append(str(value))
	return out


## 읽어 주는 이름(보조기기): 제목, 특징, 손님 줄, 판매 줄.
func _spoken() -> String:
	var parts: Array[String] = [title_label.text]
	for label in [features_label, mode_label, line_label, stats_label, notice_label]:
		if (label as Label).visible and (label as Label).text != "":
			parts.append((label as Label).text)
	return ", ".join(PackedStringArray(parts))


# ---------- 눌림 / 신호 / 연출 정리 ----------

## 누르는 동안(true)은 글자/화살표를 흰색, 손을 떼거나 취소하면(false) 원래 색으로 되돌린다.
func _set_held(held: bool) -> void:
	for node in _base_colors:
		if is_instance_valid(node):
			(node as Label).add_theme_color_override("font_color", Color.WHITE if held else _base_colors[node])
	chevron.modulate = Color.WHITE if held else INK


func _on_pressed() -> void:
	# 진짜로 꺼진 버튼은 pressed 를 보내지 않지만 시그널을 직접 보내는 경우도 막는다.
	if button.disabled or not _can_open:
		return
	details_requested.emit()


## 진행 중인 연출을 끝내고 정지 화면의 값(불투명, 원래 크기)으로 되돌린다.
func _finish_reveal() -> void:
	if _reveal_tween != null and _reveal_tween.is_valid():
		_reveal_tween.kill()
	_reveal_tween = null
	if _column != null:
		_column.modulate.a = 1.0
	if _art_row != null:
		_art_row.scale = Vector2.ONE


# ---------- 조각 ----------

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
	_base_colors[label] = color
	return label


func _portrait_for(customer_id: String) -> Texture2D:
	if customer_id == "" or not Pixel.portrait_ids().has(customer_id):
		return null
	if not _portraits.has(customer_id):
		_portraits[customer_id] = Pixel.scaled_tex(Pixel.portrait_image(customer_id), 2)
	return _portraits[customer_id]


## 탐험/재료 목표 화면과 같은 원본 재료 그림 규칙: 육수는 냄비, 메밀면/고명은 음식 그림, 나머지는 작은 재료 그림.
static func _food(ingredient_id: String) -> Texture2D:
	if not _pictures.has(ingredient_id):
		if ingredient_id == "noodle_buckwheat" or ingredient_id.begins_with("topping_"):
			_pictures[ingredient_id] = Art.food(ingredient_id)
		elif ingredient_id.begins_with("broth_"):
			_pictures[ingredient_id] = Mock.texture("pot")
		elif ingredient_id.begins_with("noodle_"):
			# 일반 밀 면(가는/중간/굵은)은 작업대가 쓰는 원본 면 다발 그림을 쓴다(12px 아이콘은 32px에서 거친 사각형이 된다).
			_pictures[ingredient_id] = Mock.texture("noodles")
		else:
			_pictures[ingredient_id] = Pixel.scaled_tex(Pixel.icon_image(ingredient_id), 3)
	return _pictures[ingredient_id]


static func _won(amount: int) -> String:
	var digits: String = str(absi(amount))
	var out: String = ""
	while digits.length() > 3:
		out = "," + digits.substr(digits.length() - 3) + out
		digits = digits.substr(0, digits.length() - 3)
	return ("-" if amount < 0 else "") + digits + out + "원"
