extends Control
## A read-only shop projection. Navigation goes back through main's guarded
## handlers; thumbnails always use the selling roster, never the editable draft.
signal action_requested(kind: String)
const Shared = preload("res://scripts/ui/service_result_view.gd")
const Mock = preload("res://scripts/ui/mock_fidelity_art.gd")
const Art = preload("res://scripts/ui/bowl_editor_art.gd")
const Dish = preload("res://scripts/ui/layered_recipe_view.gd")
const BODY = preload("res://assets/fonts/Pretendard-Regular.otf")
const BOLD = preload("res://assets/fonts/Pretendard-Bold.otf")
const INK := Color("18354f")
const TEAL := Color("087e80")
const RED := Color("aa3828")
var hud: PanelContainer
var status: PanelContainer
var nav: PanelContainer
var day_label: Label
var wallet_label: Label
var clock_label: Label
var progress: ProgressBar
var status_label: Label
var note_label: Label
var dev_button: Button
var start_button: Button
var speed_button: Button
var top_inset: float = 64
var bottom_inset: float = 156
var _rank: Label
var _info: Button
var _bottom: GridContainer
var _headline: Label
var _menu_name: Label
var _menu_note: Label
var _thumbs: HBoxContainer
var _details: Control
var _detail_margin: MarginContainer
var _detail_body: VBoxContainer
var _detail_scroll: ScrollContainer
var _menus: VBoxContainer
var _capacity: Label
var _save_note: Label
var _saved: Label
var _routes: Array[Button] = []
var _records: Array = []
var _records_key: String = "!"


func label(text: String, pixels: int = 16, color: Color = INK, bold: bool = false) -> Label:
	var out:=Label.new()
	out.text=text
	out.mouse_filter=Control.MOUSE_FILTER_IGNORE
	out.add_theme_font_override("font",BOLD if bold else BODY)
	out.add_theme_font_size_override("font_size",pixels)
	out.add_theme_color_override("font_color",color)
	out.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	out.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	return out


func button(text: String, node_name: String, skin: String = "summary", icon: String = "") -> Button:
	var out:=Shared.make_button(text,node_name,skin,icon)
	out.add_theme_stylebox_override("disabled",Mock.style("summary"))
	out.add_theme_color_override("font_disabled_color",Color("766e62"))
	out.add_theme_color_override("icon_disabled_color",Color("938b80"))
	out.add_theme_color_override("font_focus_color",INK)
	if skin=="blue":
		for prop in ["font_color","font_hover_color","font_focus_color","icon_normal_color","icon_hover_color","icon_focus_color"]:
			out.add_theme_color_override(prop,Color.WHITE)
	return out


func picture(texture: Texture2D, minimum: Vector2) -> TextureRect:
	var out:=TextureRect.new()
	out.texture=texture
	out.custom_minimum_size=minimum
	out.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	out.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	out.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	out.mouse_filter=Control.MOUSE_FILTER_IGNORE
	return out


func column(parent: Node, gap: int = 4) -> VBoxContainer:
	var out:=VBoxContainer.new()
	out.add_theme_constant_override("separation",gap)
	out.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	out.mouse_filter=Control.MOUSE_FILTER_IGNORE
	parent.add_child(out)
	return out


func panel(node_name: String, skin: String, padding: Vector2) -> PanelContainer:
	var out:=PanelContainer.new()
	out.name=node_name
	out.add_theme_stylebox_override("panel",Mock.style(skin,padding))
	out.mouse_filter=Control.MOUSE_FILTER_IGNORE
	return out


func _ready() -> void:
	name="ShopHome"
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud=panel("Hud","blue",Vector2(12,4))
	add_child(hud)
	var row:=HBoxContainer.new()
	row.mouse_filter=Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation",8)
	hud.add_child(row)
	var date:=column(row,0)
	date.size_flags_horizontal=Control.SIZE_SHRINK_BEGIN
	date.size_flags_vertical=Control.SIZE_SHRINK_CENTER
	day_label=label("",18,Color.WHITE,true)
	day_label.name="DayLabel"
	day_label.autowrap_mode=TextServer.AUTOWRAP_OFF
	date.add_child(day_label)
	_rank=label("",12,Color("ecdcb6"))
	_rank.autowrap_mode=TextServer.AUTOWRAP_OFF
	date.add_child(_rank)
	row.add_child(picture(Mock.texture("coin"),Vector2(28,28)))
	wallet_label=label("",18,Color.WHITE,true)
	wallet_label.name="WalletLabel"
	wallet_label.size_flags_vertical=Control.SIZE_SHRINK_CENTER
	wallet_label.autowrap_mode=TextServer.AUTOWRAP_OFF
	row.add_child(wallet_label)
	_info=button("","HomeInfo","blue","menu")
	_info.add_theme_font_size_override("font_size",14)
	_info.autowrap_mode=TextServer.AUTOWRAP_OFF
	_info.tooltip_text="가게 운영·판매 메뉴·저장 안내"
	_info.size_flags_horizontal=Control.SIZE_SHRINK_END
	_info.custom_minimum_size=Vector2(44,44)
	_info.pressed.connect(show_details)
	row.add_child(_info)
	_bottom=GridContainer.new()
	_bottom.add_theme_constant_override("h_separation",6)
	_bottom.add_theme_constant_override("v_separation",6)
	_bottom.mouse_filter=Control.MOUSE_FILTER_IGNORE
	add_child(_bottom)
	status=panel("StatusStrip","summary",Vector2(10,6))
	status.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	_bottom.add_child(status)
	var open:=button("","HomeStatusDetails")
	# The actual content has explicit insets; a full-rect child would touch the
	# nine-slice border and repeat the earlier cramped-frame regression.
	open.add_theme_stylebox_override("normal",StyleBoxEmpty.new())
	open.add_theme_stylebox_override("hover",StyleBoxEmpty.new())
	open.add_theme_stylebox_override("focus",StyleBoxEmpty.new())
	open.custom_minimum_size.y=68
	open.tooltip_text="판매 중인 메뉴와 영업 상세 보기"
	open.pressed.connect(show_details)
	status.add_child(open)
	var content:=column(open,2)
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var phase:=HBoxContainer.new()
	phase.mouse_filter=Control.MOUSE_FILTER_IGNORE
	content.add_child(phase)
	clock_label=label("",14,TEAL,true)
	clock_label.name="ClockLabel"
	clock_label.autowrap_mode=TextServer.AUTOWRAP_OFF
	clock_label.size_flags_horizontal=Control.SIZE_SHRINK_BEGIN
	phase.add_child(clock_label)
	_headline=label("",14,INK)
	_headline.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
	_headline.autowrap_mode=TextServer.AUTOWRAP_OFF
	_headline.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
	phase.add_child(_headline)
	progress=ProgressBar.new()
	progress.name="ServiceProgress"
	progress.show_percentage=false
	progress.max_value=100
	progress.custom_minimum_size.y=4
	progress.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var track:=StyleBoxFlat.new()
	track.bg_color=Color("d7c9ae")
	var fill:=StyleBoxFlat.new()
	fill.bg_color=TEAL
	progress.add_theme_stylebox_override("background",track)
	progress.add_theme_stylebox_override("fill",fill)
	content.add_child(progress)
	var menu:=HBoxContainer.new()
	menu.mouse_filter=Control.MOUSE_FILTER_IGNORE
	menu.add_theme_constant_override("separation",8)
	content.add_child(menu)
	_thumbs=HBoxContainer.new()
	_thumbs.mouse_filter=Control.MOUSE_FILTER_IGNORE
	menu.add_child(_thumbs)
	var words:=column(menu,0)
	_menu_name=label("",16,INK,true)
	_menu_name.name="HomeMenuName"
	_menu_note=label("",14,TEAL)
	_menu_note.name="HomeMenuNote"
	for text in [_menu_name,_menu_note]:
		text.autowrap_mode=TextServer.AUTOWRAP_OFF
		text.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
		words.add_child(text)
	var arrow:=picture(Art.icon("chevron_right"),Vector2(20,24))
	arrow.modulate=TEAL
	menu.add_child(arrow)
	nav=panel("NavBar","panel",Vector2(8,6))
	nav.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	_bottom.add_child(nav)
	var actions:=HBoxContainer.new()
	actions.add_theme_constant_override("separation",6)
	nav.add_child(actions)
	dev_button=button("메뉴 개발","DevButton","blue","ramen_dining")
	start_button=button("영업 시작","StartServiceButton","gold")
	start_button.size_flags_stretch_ratio=1.5
	speed_button=button("속도 ×1","SpeedButton")
	speed_button.custom_minimum_size.x=66
	speed_button.add_theme_font_size_override("font_size",14)
	speed_button.size_flags_horizontal=Control.SIZE_SHRINK_END
	for action in [dev_button,start_button,speed_button]: actions.add_child(action)
	_build_details()
	resized.connect(layout_home)
	layout_home()


func _build_details() -> void:
	_details=Control.new()
	_details.name="HomeDetails"
	_details.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_details)
	var dim:=ColorRect.new()
	dim.color=Color(0,0,0,0.6)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_details.add_child(dim)
	_detail_margin=MarginContainer.new()
	_detail_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_details.add_child(_detail_margin)
	var frame:=panel("HomeDetailsPanel","panel",Vector2(14,14))
	_detail_margin.add_child(frame)
	var body:=column(frame,10)
	var head:=HBoxContainer.new()
	body.add_child(head)
	var title:=label("가게 운영",22,INK,true)
	title.size_flags_vertical=Control.SIZE_SHRINK_CENTER
	head.add_child(title)
	var close:=button("","HomeDetailsClose","summary","close")
	close.size_flags_horizontal=Control.SIZE_SHRINK_END
	close.tooltip_text="가게로 돌아가기"
	close.pressed.connect(hide_details)
	head.add_child(close)
	_detail_scroll=ScrollContainer.new()
	_detail_scroll.name="HomeDetailsScroll"
	_detail_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	_detail_scroll.scroll_deadzone=10
	_detail_scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL
	body.add_child(_detail_scroll)
	_detail_body=column(_detail_scroll,12)
	_capacity=label("",16,TEAL,true)
	_detail_body.add_child(_capacity)
	status_label=label("",16)
	status_label.name="ServiceStatusLabel"
	_detail_body.add_child(status_label)
	note_label=label("",15,TEAL)
	note_label.name="ServiceNoteLabel"
	_detail_body.add_child(note_label)
	_detail_body.add_child(label("판매 중인 메뉴",20,INK,true))
	_menus=column(_detail_body,8)
	for data in [["판매 메뉴 관리","HomeMenus","menus","restaurant"],["재료 탐색","HomeExplore","explore","soup_kitchen"],["확장·직원·랭크","HomeGrowth","growth","chevron_right"],["지난 영업 결과","HomeLastReport","report","info"]]:
		var route:=button(data[0],data[1],"summary",data[3])
		route.pressed.connect(func(): action_requested.emit(data[2]))
		_detail_body.add_child(route)
		_routes.append(route)
	_detail_body.add_child(label("저장과 진행",20,INK,true))
	_saved=label("",15,TEAL)
	_saved.name="HomeSaveState"
	_detail_body.add_child(_saved)
	_save_note=label("",15)
	_save_note.name="HomeManualSaveResult"
	# A save refusal/failure must be visible next to the fixed action, not
	# appended below the scroll fold where a tap would appear to do nothing.
	body.add_child(_save_note)
	_save_note.hide()
	var save:=button("지금 저장","HomeSave","gold")
	save.pressed.connect(func(): action_requested.emit("save"))
	body.add_child(save)
	_details.hide()


func attach_warning(warning: Control) -> void:
	# This is the original guarded banner/reset control, moved into an actual
	# reachable depth. Header and summary signal every active warning outside it.
	warning.reparent(_detail_body,false)
	warning.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	_detail_body.move_child(warning,0)


func layout_home() -> void:
	if _bottom==null: return
	var wide: bool=size.x>=1000 and size.x>size.y
	_bottom.columns=2 if wide else 1
	hud.position=Vector2(6,6)
	hud.size=Vector2(size.x-12,52)
	var height: float=84 if wide else 146
	_bottom.position=Vector2(6,size.y-6-height)
	_bottom.size=Vector2(size.x-12,height)
	top_inset=64
	bottom_inset=height+12
	var side: int=maxi(10,int((size.x-720)/2))
	for edge in ["left","right"]: _detail_margin.add_theme_constant_override("margin_"+edge,side)
	for edge in ["top","bottom"]: _detail_margin.add_theme_constant_override("margin_"+edge,18)


func show_details() -> void:
	_save_note.text=""
	_save_note.hide()
	_details.show()
	_detail_scroll.scroll_vertical=0


func hide_details() -> void:
	_details.hide()


func set_context(data: Dictionary) -> void:
	_rank.text="%d랭크 · %d석" % [data["rank"],data["seats"]]
	_headline.text=str(data["phase"])
	var warning: bool=bool(data["warning"])
	_info.text="저장" if warning else ""
	_info.custom_minimum_size.x=86 if warning else 44
	_info.icon=Art.icon("info" if warning else "menu")
	_info.add_theme_color_override("font_color",Color("ffd07c") if warning else Color.WHITE)
	_saved.text=str(data["save"])
	_saved.add_theme_color_override("font_color",RED if warning else TEAL)
	_capacity.text="%d랭크 · %d석 · 직원 %d/%d명" % [data["rank"],data["seats"],data["staff"],data["staff_limit"]]
	for route in _routes: route.disabled=bool(data["busy"])
	_routes[3].disabled=bool(data["busy"]) or not bool(data["has_report"])
	var key: String=JSON.stringify(data["menus"])
	if key!=_records_key:
		_records_key=key
		_records=data["menus"].duplicate(true)
		_rebuild_menus()
	if _records.is_empty():
		_menu_name.text="첫 라멘을 만들어 보세요" if bool(data["no_records"]) else "판매 메뉴를 골라 주세요"
		_menu_note.text="재료 고르기 → 시식 → 첫 영업" if bool(data["no_records"]) else "메뉴 노트에서 판매할 라멘 선택"
	else:
		_menu_name.text=str(_records[0]["name"]) if _records.size()==1 else "오늘의 라멘 %d종" % _records.size()
		_menu_note.text=Shared.Editor.won(int(_records[0]["config"]["price"]))+" · v%d" % int(_records[0]["version"]) if _records.size()==1 else "판매 메뉴와 가격 보기"
	if warning:
		_menu_note.text="저장하지 못했어요 · 안내 보기"
		_menu_note.add_theme_color_override("font_color",RED)
	else: _menu_note.add_theme_color_override("font_color",TEAL)


func set_save_result(message: String) -> void:
	_save_note.text=message
	_save_note.visible=message!=""


func _dish(config: Dictionary, node_name: String, minimum: Vector2) -> Control:
	var dish:=Dish.new()
	dish.name=node_name
	dish.custom_minimum_size=minimum
	dish.mouse_filter=Control.MOUSE_FILTER_IGNORE
	dish.set_config(config)
	return dish


func _rebuild_menus() -> void:
	for parent in [_thumbs,_menus]:
		for child in parent.get_children():
			parent.remove_child(child)
			child.queue_free()
	if _records.is_empty():
		_thumbs.add_child(picture(Mock.texture("noodles"),Vector2(56,38)))
		_menus.add_child(label("아직 판매 중인 메뉴가 없어요. 시식한 레시피를 판매 메뉴로 골라 주세요.",16))
	for i in _records.size():
		var record: Dictionary=_records[i]
		_thumbs.add_child(_dish(record["config"],"HomeDish_%d" % i,Vector2(60 if _records.size()==1 else 48,38)))
		var card:=panel("HomeMenu_%d" % i,"summary",Vector2(12,10))
		_menus.add_child(card)
		var row:=HBoxContainer.new()
		row.add_theme_constant_override("separation",12)
		card.add_child(row)
		row.add_child(_dish(record["config"],"HomeDetailDish_%d" % i,Vector2(84,60)))
		var words:=column(row,4)
		words.add_child(label(str(record["name"]),18,INK,true))
		words.add_child(label("v%d · %s" % [record["version"],Shared.Editor.won(int(record["config"]["price"]))],16,TEAL))
