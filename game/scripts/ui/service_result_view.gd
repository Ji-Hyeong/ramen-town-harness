extends Control
## Read-only settlement pages. Historical single-menu receipts have no recipe
## snapshot or live reactions: only matching, just-finished evidence fills them.
signal action_requested(kind: String)
const Mock = preload("res://scripts/ui/mock_fidelity_art.gd")
const Art = preload("res://scripts/ui/bowl_editor_art.gd")
const Dish = preload("res://scripts/ui/layered_recipe_view.gd")
const Pixel = preload("res://scripts/ui/pixel_art.gd")
const Customers = preload("res://scripts/domain/customer_catalog.gd")
const Editor = preload("res://scripts/ui/bowl_workbench.gd")
const BODY = preload("res://assets/fonts/Pretendard-Regular.otf")
const BOLD = preload("res://assets/fonts/Pretendard-Bold.otf")
const INK := Color("18354f")
const TEAL := Color("087e80")
const RED := Color("aa3828")
const MUTED := Color("685c50")
var _report: Dictionary = {}
var _context: Dictionary = {}
var _menus: Array = []
var _page: String = "summary"
var _chosen: int = 0
var _margin: MarginContainer
var _title: Label
var _note: Label
var _receipt: Label
var _body: VBoxContainer
var _scroll: ScrollContainer
var _back: Button
var _status: Button
var _footer: HBoxContainer


static func make_button(text: String, node_name: String, skin: String = "summary", icon: String = "") -> Button:
	var button := Button.new()
	button.name=node_name
	button.text=text
	button.custom_minimum_size=Vector2(48,48)
	button.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	button.mouse_filter=Control.MOUSE_FILTER_PASS
	button.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	button.add_theme_font_override("font",BOLD)
	button.add_theme_font_size_override("font_size",16)
	for prop in ["normal","hover","focus"]: button.add_theme_stylebox_override(prop,Mock.style(skin))
	button.add_theme_stylebox_override("pressed",Mock.style("teal"))
	button.add_theme_color_override("font_color",INK)
	button.add_theme_color_override("font_hover_color",INK)
	button.add_theme_color_override("font_pressed_color",Color.WHITE)
	if icon!="":
		button.icon=Art.icon(icon)
		button.add_theme_constant_override("icon_max_width",24)
		button.add_theme_color_override("icon_normal_color",INK)
		button.add_theme_color_override("icon_hover_color",INK)
		button.add_theme_color_override("icon_focus_color",INK)
	return button


func _label(text: String, font_size: int = 16, color: Color = INK, node_name: String = "") -> Label:
	var label:=Label.new()
	if node_name!="": label.name=node_name
	label.text=text
	label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter=Control.MOUSE_FILTER_IGNORE
	label.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	label.add_theme_font_override("font",BOLD if font_size>=18 else BODY)
	label.add_theme_font_size_override("font_size",font_size)
	label.add_theme_color_override("font_color",color)
	return label


func _box(parent: Node, gap: int = 8) -> VBoxContainer:
	var box:=VBoxContainer.new()
	box.add_theme_constant_override("separation",gap)
	box.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	parent.add_child(box)
	return box


func _paper(parent: Node) -> VBoxContainer:
	var panel:=PanelContainer.new()
	panel.add_theme_stylebox_override("panel",Mock.style("summary",Vector2(12,10)))
	parent.add_child(panel)
	return _box(panel)


func _picture(texture: Texture2D, minimum: Vector2) -> TextureRect:
	var picture:=TextureRect.new()
	picture.texture=texture
	picture.custom_minimum_size=minimum
	picture.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	picture.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	picture.mouse_filter=Control.MOUSE_FILTER_IGNORE
	return picture


func _ready() -> void:
	name="ResultLayer"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim:=ColorRect.new()
	dim.color=Color(0,0,0,0.62)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	_margin=MarginContainer.new()
	_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_margin)
	var panel:=PanelContainer.new()
	panel.name="ResultPanel"
	panel.add_theme_stylebox_override("panel",Mock.style("panel",Vector2(14,14)))
	_margin.add_child(panel)
	var column:=_box(panel,10)
	var header:=HBoxContainer.new()
	header.add_theme_constant_override("separation",8)
	column.add_child(header)
	_back=make_button("","ResultBack","summary","arrow_back")
	_back.size_flags_horizontal=Control.SIZE_SHRINK_BEGIN
	_back.pressed.connect(func():
		if _page=="summary": action_requested.emit("close")
		else: _show_page("summary"))
	header.add_child(_back)
	_title=_label("영업 결과",22,INK,"ResultTitle")
	_title.size_flags_vertical=Control.SIZE_SHRINK_CENTER
	header.add_child(_title)
	_status=make_button("","ResultSaveStatus","summary","info")
	_status.add_theme_font_size_override("font_size",14)
	_status.pressed.connect(_show_page.bind("receipt"))
	column.add_child(_status)
	_scroll=ScrollContainer.new()
	_scroll.name="ResultScroll"
	_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL
	_scroll.scroll_deadzone=10
	column.add_child(_scroll)
	_body=_box(_scroll,10)
	# The full original receipt and save warning are a real, reachable depth,
	# not duplicate legacy controls used as proof of the new summary screen.
	_receipt=_label("",16,INK,"ResultLabel")
	_note=_label("",15,TEAL,"ResultNote")
	_footer=HBoxContainer.new()
	_footer.add_theme_constant_override("separation",8)
	column.add_child(_footer)
	var develop:=make_button("메뉴 개발","ResultDevelop","summary","ramen_dining")
	develop.tooltip_text="작성 중인 초안을 유지하고 메뉴 개발로 돌아가요."
	develop.pressed.connect(func(): action_requested.emit("develop"))
	_footer.add_child(develop)
	var close:=make_button("가게로","ResultOkButton","gold")
	close.custom_minimum_size.y=54
	close.pressed.connect(func(): action_requested.emit("close"))
	_footer.add_child(close)
	resized.connect(_layout)
	_layout()


func _layout() -> void:
	if _margin==null: return
	var side: int=maxi(10,int((size.x-860)/2))
	for edge in ["left","right"]: _margin.add_theme_constant_override("margin_"+edge,side)
	for edge in ["top","bottom"]: _margin.add_theme_constant_override("margin_"+edge,14 if size.y<780 else 28)
	var grid: GridContainer=find_child("ResultMenuGrid",true,false) as GridContainer
	if grid!=null: grid.columns=2 if size.x>=720 else 1


func present(report: Dictionary, context: Dictionary, receipt_text: String) -> void:
	_report=report.duplicate(true)
	_context=context.duplicate(true)
	_menus.clear()
	if report.has("menus"):
		_menus=report["menus"].duplicate(true)
	elif not report.is_empty():
		var row: Dictionary=report.duplicate(true)
		row["margin"]=int(report["revenue"])-int(report["ingredient_cost"])
		row["config"]={}
		if _context.has("sold") and _context["sold"].size()==1:
			row["config"]=_context["sold"][0]["config"].duplicate(true)
		_menus.append(row)
	_receipt.text=receipt_text
	_note.text=str(context.get("save_note","저장된 정산 기록이에요."))
	_note.add_theme_color_override("font_color",TEAL if bool(context.get("saved",true)) else RED)
	_status.text="정산 완료 · 저장했어요" if bool(context.get("saved",true)) else "저장하지 못했어요 · 안내 보기"
	_status.add_theme_color_override("font_color",TEAL if bool(context.get("saved",true)) else RED)
	_show_page("summary")


func _show_page(page: String) -> void:
	_page=page
	# Keep these two actual detail labels alive when switching pages; other
	# controls are disposable and contain no game state or reward actions.
	for retained in [_receipt,_note]:
		if retained.get_parent()!=null: retained.get_parent().remove_child(retained)
	for child in _body.get_children():
		_body.remove_child(child)
		child.queue_free()
	_title.text="%d일차 영업 결과" % int(_report.get("day",0)) if page=="summary" else {"menu":"메뉴 판매 상세","customers":"손님과 대기","cost":"비용 영수증","receipt":"정산·저장 안내"}[page]
	_back.tooltip_text="가게로" if page=="summary" else "결과 요약으로"
	if _report.is_empty():
		_body.add_child(_label("아직 마친 영업이 없어요.",20))
	elif page=="summary": _summary()
	elif page=="menu": _menu_details()
	elif page=="customers": _customers()
	elif page=="cost": _costs()
	else:
		_body.add_child(_note)
		_body.add_child(_label("전체 영업 영수증",20))
		_body.add_child(_receipt)
	for retained in [_note,_receipt]:
		retained.visible=page=="receipt"
		if retained.get_parent()==null: _body.add_child(retained)
	_scroll.set_deferred("scroll_vertical",0)


func _summary() -> void:
	var hero:=_paper(_body)
	var earnings:=HBoxContainer.new()
	earnings.add_theme_constant_override("separation",12)
	hero.add_child(earnings)
	earnings.add_child(_picture(Mock.texture("coin"),Vector2(48,48)))
	var amount:=_box(earnings,2)
	amount.add_child(_label("오늘 남긴 돈",16,MUTED))
	amount.add_child(_label(Editor.won(int(_report["net"])),32,TEAL if int(_report["net"])>=0 else RED,"ResultNet"))
	hero.add_child(_label("매출에서 재료비와 하루 운영비를 뺀 금액",14,MUTED))
	var numbers:=HBoxContainer.new()
	numbers.add_theme_constant_override("separation",12)
	hero.add_child(numbers)
	for pair in [["완료 주문","%d그릇" % int(_report["units"]),"ResultUnits"],["매출",Editor.won(int(_report["revenue"])),"ResultRevenue"]]:
		var box:=_box(numbers,2)
		box.add_child(_label(str(pair[0]),14,MUTED))
		box.add_child(_label(str(pair[1]),22,INK,str(pair[2])))
	var chef: Dictionary=_context.get("chef_challenge",{})
	if not chef.is_empty():
		var status: String=chef["status"]
		var text: String={"open":"요리사 새 도전 보기","active":"요리사 현재 도전 · %d/6 조건" % chef["met"],"ready":"요리사 도전 달성! 성장 확인","mastered":"요리사 · 점심 조리 습득"}[status]
		var goal:=make_button(text,"ResultChef","gold" if status=="ready" else "summary","chevron_right")
		goal.pressed.connect(func(): action_requested.emit("chef"))
		_body.add_child(goal)
	_body.add_child(_label("어떤 메뉴가 팔렸나요?",20))
	var menu_grid:=GridContainer.new()
	menu_grid.name="ResultMenuGrid"
	menu_grid.columns=2 if size.x>=720 else 1
	menu_grid.add_theme_constant_override("h_separation",10)
	menu_grid.add_theme_constant_override("v_separation",10)
	_body.add_child(menu_grid)
	for index in _menus.size():
		var row: Dictionary=_menus[index]
		var button:=make_button("","ResultMenu_"+str(index))
		button.custom_minimum_size.y=126
		button.tooltip_text="%s 판매 상세 보기" % row["recipe_name"]
		var inset:=MarginContainer.new()
		inset.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		inset.mouse_filter=Control.MOUSE_FILTER_IGNORE
		for side in ["left","right","top","bottom"]: inset.add_theme_constant_override("margin_"+side,12)
		button.add_child(inset)
		var card:=HBoxContainer.new()
		card.add_theme_constant_override("separation",10)
		card.mouse_filter=Control.MOUSE_FILTER_IGNORE
		inset.add_child(card)
		if not (row["config"] as Dictionary).is_empty():
			var stage:=Control.new()
			stage.custom_minimum_size=Vector2(112,90)
			stage.clip_contents=true
			stage.mouse_filter=Control.MOUSE_FILTER_IGNORE
			card.add_child(stage)
			var background:=_picture(load("res://assets/ui/bowl-editor/workbench-background.png") as Texture2D,Vector2.ZERO)
			background.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_COVERED
			background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			stage.add_child(background)
			var dish:=Dish.new()
			dish.name="SoldMenuThumbnail_"+str(index)
			dish.mouse_filter=Control.MOUSE_FILTER_IGNORE
			dish.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			stage.add_child(dish)
			dish.set_config(row["config"])
		else: card.add_child(_picture(Art.icon("ramen_dining"),Vector2(48,48)))
		var text:=_box(card,3)
		text.mouse_filter=Control.MOUSE_FILTER_IGNORE
		var menu_name:=_label("%s v%d" % [row["recipe_name"],row["version"]],18)
		menu_name.max_lines_visible=2
		menu_name.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
		text.add_child(menu_name)
		text.add_child(_label("%d그릇 판매" % int(row["units"]),22,TEAL))
		text.add_child(_label("매출 "+Editor.won(int(row["revenue"])),14,MUTED))
		var arrow:=_picture(Art.icon("chevron_right"),Vector2(24,24))
		arrow.self_modulate=TEAL
		card.add_child(arrow)
		button.pressed.connect(func(): _chosen=index; _show_page("menu"))
		menu_grid.add_child(button)
	var customer:=make_button("손님과 대기","ResultCustomers","summary","info")
	customer.pressed.connect(_show_page.bind("customers"))
	_body.add_child(customer)
	var faces:=HBoxContainer.new()
	faces.add_theme_constant_override("separation",8)
	faces.mouse_filter=Control.MOUSE_FILTER_IGNORE
	_body.add_child(faces)
	for id in Customers.ids():
		faces.add_child(_picture(Pixel.scaled_tex(Pixel.portrait_image(id),2),Vector2(32,32)))
	faces.add_child(_label(("만족도 %.1f / 5" % float(_context["avg_stars"]) if int(_report["units"])>0 else "완료 주문 없음") if _context.has("avg_stars") else "손님별 완료 주문",16,TEAL))
	var cost:=make_button("비용 영수증","ResultCosts","summary","chevron_right")
	cost.pressed.connect(_show_page.bind("cost"))
	_body.add_child(cost)



func _menu_details() -> void:
	var row: Dictionary=_menus[_chosen]
	_body.add_child(_label("%s v%d" % [row["recipe_name"],row["version"]],22))
	if not (row["config"] as Dictionary).is_empty():
		var dish:=Dish.new()
		dish.name="ResultSoldDish"
		dish.custom_minimum_size=Vector2(180,154)
		_body.add_child(dish)
		dish.set_config(row["config"])
	else:
		_body.add_child(_label("이전 단일 메뉴 기록에는 그릇 구성이 남아 있지 않아요.",15,MUTED))
	_body.add_child(_label("판매 %d그릇 · 판매가 %s" % [row["units"],Editor.won(int(row["price"]))],18))
	_body.add_child(_label("매출 %s\n재료비 −%s\n재료비를 뺀 금액 %s" % [Editor.won(int(row["revenue"])),Editor.won(int(row["ingredient_cost"])),Editor.won(int(row["margin"]))],18,TEAL))
	_body.add_child(_label("하루 운영비는 전체 영업 결과에서 한 번 차감해요.",15,MUTED))
	if row.has("wait_total"):
		_body.add_child(_label("완료 주문 평균 대기 %.0f초" % (float(row["wait_total"])/float(row["units"])) if int(row["units"])>0 else "완료 주문이 없어 평균 대기를 계산하지 않아요.",17))
	_body.add_child(_label("누가 먹었나요?",20))
	_sources(row["by_source"])


func _sources(source: Dictionary) -> void:
	for id in source:
		var row:=HBoxContainer.new()
		row.add_theme_constant_override("separation",10)
		_body.add_child(row)
		var customer: Dictionary=Customers.find(str(id))
		if not customer.is_empty():
			var portrait:=TextureRect.new()
			portrait.texture=Pixel.scaled_tex(Pixel.portrait_image(str(id)),2)
			portrait.custom_minimum_size=Vector2(40,40)
			portrait.mouse_filter=Control.MOUSE_FILTER_IGNORE
			row.add_child(portrait)
		row.add_child(_label((str(customer["name"]) if not customer.is_empty() else "일반 손님")+" · %d그릇" % int(source[id]),18))


func _customers() -> void:
	if _context.has("avg_stars"):
		_body.add_child(_label("평균 만족도 %.1f / 5" % float(_context["avg_stars"]) if int(_report["units"])>0 else "만족도 집계 없음",24,TEAL))
		_body.add_child(_label("매장 앞에서 돌아간 손님 %d명" % int(_context["turned_away"]),18))
		_body.add_child(_label("이번에 끝난 영업의 실제 반응이에요. 메뉴 시식 점수나 방문 수요와 달라요.",15,MUTED))
	else:
		_body.add_child(_label("만족도·돌아간 손님 수는 영업 직후에만 확인할 수 있어요. 저장 기록에는 포함되지 않아요.",16,MUTED))
	_body.add_child(_label("손님별 완료 주문",20))
	_sources(_report["by_source"])
	_body.add_child(_label("영업을 끝까지 마친 주문만 집계해요. 예상 수요에서 판매를 뺀 수를 이탈 손님으로 표시하지 않아요.",15,MUTED))
	for row in _menus:
		if row.has("wait_total"):
			_body.add_child(_label(str(row["recipe_name"])+(" · 평균 대기 %.0f초" % (float(row["wait_total"])/float(row["units"])) if int(row["units"])>0 else " · 완료 주문 없음"),17))
	if str(_context.get("experience",""))!="": _body.add_child(_label(str(_context["experience"]),16,TEAL))


func _costs() -> void:
	for pair in [["매출",_report["revenue"]],["재료비",-int(_report["ingredient_cost"])],["하루 운영비",-int(_report["overhead"])],["오늘 남긴 돈",_report["net"]],["정산 직후 자금",_report["wallet_after"]]]:
		var box:=_paper(_body)
		box.add_child(_label(str(pair[0]),15,MUTED))
		box.add_child(_label(Editor.won(int(pair[1])),24,INK))
	_body.add_child(_label("정산 직후 자금은 당시의 기록이에요. 그 뒤의 시식·구매 비용은 이 영수증을 바꾸지 않아요.",15,MUTED))


func play_reveal() -> void:
	# Call once after successful settlement, never from render/reopen/details.
	var net: Control=find_child("ResultNet",true,false) as Control
	if net==null: return
	net.modulate.a=0.25
	var tween:=net.create_tween()
	tween.tween_property(net,"modulate:a",1.0,0.35)
	for index in _menus.size():
		var card: Control=find_child("ResultMenu_"+str(index),true,false) as Control
		if card==null: continue
		card.pivot_offset=card.size*0.5
		card.scale=Vector2.ONE*0.94
		var reveal:=card.create_tween()
		reveal.tween_property(card,"scale",Vector2.ONE,0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _exit_tree() -> void:
	# Detached reusable labels are owned here even when another depth is open.
	for label in [_note,_receipt]:
		if is_instance_valid(label) and label.get_parent()==null: label.free()
