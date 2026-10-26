extends Control
## Read-only staff/investment presentation. Existing controller handlers own
## every transaction and timed confirmation; navigation never grants benefits.
signal action_requested(kind: String, id: String, style: String)
const Shared = preload("res://scripts/ui/service_result_view.gd")
const Mock = preload("res://scripts/ui/mock_fidelity_art.gd")
const Art = preload("res://scripts/ui/bowl_editor_art.gd")
const Pixel = preload("res://scripts/ui/pixel_art.gd")
const Staffing = preload("res://scripts/domain/shop_staffing.gd")
const Training = preload("res://scripts/domain/staff_training.gd")
const Growth = preload("res://scripts/domain/shop_growth.gd")
const BODY = preload("res://assets/fonts/Pretendard-Regular.otf")
const BOLD = preload("res://assets/fonts/Pretendard-Bold.otf")
const INK := Color("18354f")
const TEAL := Color("087e80")
const RED := Color("aa3828")
var _state: Object
var _context: Dictionary = {}
var _key: String = ""
var _section: String = "staff"
var _page: String = "list"
var _id: String = ""
var _style: String = ""
var _margin: MarginContainer
var _frame: PanelContainer
var _title: Label
var _wallet: Label
var _summary: Label
var _back: Button
var _tabs: HBoxContainer
var _notice: Button
var _progress: ProgressBar
var _policy: Label
var _scroll: ScrollContainer
var _body: VBoxContainer
var _secondary: Button
var _primary: Button
var _positions: Dictionary = {}
var _generation: int = 0
var _portraits: Dictionary = {}
var _dismissed_notice: String = ""


func _label(text: String, fs: int = 16, color: Color = INK, bold: bool = false, node_name: String = "") -> Label:
	var out:=Label.new()
	if node_name!="": out.name=node_name
	out.text=text
	out.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	out.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	out.mouse_filter=Control.MOUSE_FILTER_IGNORE
	out.add_theme_font_override("font",BOLD if bold else BODY)
	out.add_theme_font_size_override("font_size",fs)
	out.add_theme_color_override("font_color",color)
	return out


func _button(text: String, node_name: String, skin: String = "summary", icon: String = "") -> Button:
	var out:=Shared.make_button(text,node_name,skin,icon)
	out.add_theme_stylebox_override("disabled",Mock.style("summary"))
	out.add_theme_color_override("font_disabled_color",Color("766e62"))
	out.add_theme_color_override("icon_disabled_color",Color("938b80"))
	if skin=="teal":
		for prop in ["font_color","font_hover_color","font_focus_color","icon_normal_color","icon_hover_color"]: out.add_theme_color_override(prop,Color.WHITE)
	return out


func _col(parent: Node, gap: int = 8) -> VBoxContainer:
	var out:=VBoxContainer.new()
	out.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	out.add_theme_constant_override("separation",gap)
	parent.add_child(out)
	return out


func _paper(parent: Node, node_name: String = "") -> VBoxContainer:
	var panel:=PanelContainer.new()
	if node_name!="": panel.name=node_name
	panel.add_theme_stylebox_override("panel",Mock.style("summary",Vector2(12,12)))
	parent.add_child(panel)
	return _col(panel)


func _picture(texture: Texture2D, minimum: Vector2) -> TextureRect:
	var out:=TextureRect.new()
	out.texture=texture
	out.custom_minimum_size=minimum
	out.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	out.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	out.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	out.mouse_filter=Control.MOUSE_FILTER_IGNORE
	return out


func _portrait(id: String) -> Texture2D:
	if id=="chef":
		if not _portraits.has(id): _portraits[id]=ImageTexture.create_from_image(Pixel.person_image(Pixel.LOOK_CHEF,"stand",0,false))
		return _portraits[id]
	if not _portraits.has(id): _portraits[id]=ImageTexture.create_from_image(Pixel.staff_portrait_image(id))
	return _portraits[id]


func _style_progress(bar: ProgressBar) -> void:
	bar.show_percentage=false
	var track:=StyleBoxFlat.new()
	track.bg_color=Color("d7c9ae")
	var fill:=StyleBoxFlat.new()
	fill.bg_color=TEAL
	bar.add_theme_stylebox_override("background",track)
	bar.add_theme_stylebox_override("fill",fill)


func _ready() -> void:
	name="GrowthWorkbench"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim:=ColorRect.new()
	dim.color=Color(0,0,0,0.65)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	_margin=MarginContainer.new()
	_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_margin)
	_frame=PanelContainer.new()
	_frame.name="GrowthFrame"
	_frame.add_theme_stylebox_override("panel",Mock.style("panel",Vector2(14,14)))
	_margin.add_child(_frame)
	var column:=_col(_frame,8)
	var head:=HBoxContainer.new()
	head.add_theme_constant_override("separation",8)
	column.add_child(head)
	_back=_button("","GrowthBack","summary","arrow_back")
	_back.size_flags_horizontal=Control.SIZE_SHRINK_BEGIN
	_back.tooltip_text="목록 또는 가게로 돌아가기"
	_back.pressed.connect(_go_back)
	head.add_child(_back)
	_title=_label("직원·가게",22,INK,true,"GrowthTitle")
	_title.autowrap_mode=TextServer.AUTOWRAP_OFF
	_title.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
	_title.size_flags_vertical=Control.SIZE_SHRINK_CENTER
	head.add_child(_title)
	head.add_child(_picture(Mock.texture("coin"),Vector2(24,24)))
	_wallet=_label("",16,INK,true,"GrowthWallet")
	_wallet.autowrap_mode=TextServer.AUTOWRAP_OFF
	_wallet.size_flags_horizontal=Control.SIZE_SHRINK_END
	_wallet.size_flags_vertical=Control.SIZE_SHRINK_CENTER
	head.add_child(_wallet)
	_summary=_label("",14,TEAL,false,"GrowthOverview")
	column.add_child(_summary)
	_tabs=HBoxContainer.new()
	_tabs.add_theme_constant_override("separation",6)
	column.add_child(_tabs)
	_notice=_button("","GrowthNotice","summary","info")
	_notice.add_theme_font_size_override("font_size",14)
	_notice.pressed.connect(func(): _navigate("notice"))
	column.add_child(_notice)
	_progress=ProgressBar.new()
	_progress.name="GrowthTrainingProgress"
	_progress.custom_minimum_size.y=16
	_style_progress(_progress)
	_progress.mouse_filter=Control.MOUSE_FILTER_IGNORE
	column.add_child(_progress)
	_scroll=ScrollContainer.new()
	_scroll.name="GrowthScroll"
	_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.scroll_deadzone=10
	_scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL
	column.add_child(_scroll)
	_body=_col(_scroll,10)
	_policy=_label("",14,RED,false,"GrowthActionPolicy")
	column.add_child(_policy)
	var footer:=HBoxContainer.new()
	footer.add_theme_constant_override("separation",8)
	column.add_child(footer)
	_secondary=_button("목록","GrowthSecondary")
	_secondary.pressed.connect(func():
		if _page=="list": action_requested.emit("develop","","")
		else: _go_back())
	footer.add_child(_secondary)
	_primary=_button("가게로","GrowthPrimary","gold")
	_primary.custom_minimum_size.y=54
	_primary.pressed.connect(_commit)
	footer.add_child(_primary)
	resized.connect(_layout)
	_layout()


func _layout() -> void:
	if _margin==null: return
	var side: int=maxi(10,int((size.x-860)/2))
	for edge in ["left","right"]: _margin.add_theme_constant_override("margin_"+edge,side)
	for edge in ["top","bottom"]: _margin.add_theme_constant_override("margin_"+edge,14 if size.y<780 else 22)
	var grid:=find_child("GrowthGrid",true,false) as GridContainer
	if grid!=null: grid.columns=2 if size.x>=760 else 1


func present(state: Object, context: Dictionary) -> void:
	_state=state
	_context=context
	# Controller revision changes on real refreshes. Timed progress is scalar:
	# do not re-evaluate hiring forecasts or rebuild a scrolled page every frame.
	var key: String=JSON.stringify([context["revision"],context["busy"],context["notice"],context["warning"],context["save_status"],context["promote_armed"],context["expand_armed"],context["training_armed"]])
	_progress.visible=float(context["training_left"])>0
	_progress.value=100.0*(1.0-float(context["training_left"])/2.0)
	if key!=_key:
		_key=key
		_render(true)


func _position_key() -> String:
	return _section+":"+_page+":"+_id+":"+_style


func _navigate(page: String, id: String = "", style: String = "") -> void:
	_positions[_position_key()]=_scroll.scroll_vertical
	# A previous purchase error must not look like the newly opened hire is
	# blocked. Disk-save warnings remain persistent across every navigation.
	if page!="notice": _dismissed_notice=JSON.stringify([_context["notice"],_context["revision"]])
	_page=page
	_id=id
	_style=style
	_render()


func _go_back() -> void:
	action_requested.emit("cancel","","")
	if _page=="list": action_requested.emit("close","","")
	elif _page=="training": _navigate("staff",_id)
	else: _navigate("list")


func _restore_scroll(generation: int, position: int) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	if generation==_generation and is_inside_tree(): _scroll.scroll_vertical=position


func _render(preserve: bool = false) -> void:
	if _state==null: return
	var position: int=_scroll.scroll_vertical if preserve else int(_positions.get(_position_key(),0))
	for parent in [_body,_tabs]:
		for child in parent.get_children():
			parent.remove_child(child)
			child.queue_free()
	_wallet.text=Growth._won(_state.wallet)
	_summary.text="%d랭크 · 직원 %d/%d명 · 등록 메뉴 %d/%d종" % [_state.rank(),Staffing.BASE_STAFF+_state.hired_staff().size(),_state.staff_capacity(),_state.menu_count(),_state.menu_capacity()]
	_title.text={"list":"직원·가게","staff":"직원 상세","training":"직원 육성","facility":"설비 상세","expand":"가게 증축","rank":"등급 심사","notice":"처리 결과","chef":"요리사 도전"}[_page]
	for section in [["staff","직원"],["facility","설비"],["shop","증축·랭크"]]:
		var tab:=_button(section[1],"GrowthTab_"+section[0],"teal" if section[0]==_section else "summary")
		tab.disabled=bool(_context["closing_blocked"])
		tab.pressed.connect(func():
			action_requested.emit("cancel","","")
			_positions[_position_key()]=_scroll.scroll_vertical
			_section=section[0]
			_navigate("list"))
		_tabs.add_child(tab)
	var warning: bool=str(_context["warning"])!=""
	_notice.visible=warning or (str(_context["notice"])!="" and _dismissed_notice!=JSON.stringify([_context["notice"],_context["revision"]]))
	_notice.text="저장하지 못했어요 · 안내 보기" if warning else "최근 작업 안내 · 자세히 보기"
	_notice.add_theme_color_override("font_color",RED if warning or bool(_context["notice_error"]) else TEAL)
	_back.disabled=bool(_context["closing_blocked"])
	_secondary.disabled=bool(_context["closing_blocked"]) or (_page=="list" and bool(_context["busy"]))
	_secondary.text="메뉴 개발" if _page=="list" else "뒤로"
	_primary.disabled=false
	_primary.text="가게로"
	match _page:
		"list": _list_page()
		"staff": _staff_page()
		"training": _training_page()
		"chef": _chef_page()
		"facility": _facility_page()
		"expand": _expand_page()
		"rank": _rank_page()
		"notice":
			_body.add_child(_label("현재 저장 상태",20,INK,true))
			_body.add_child(_label(str(_context["warning"]) if warning else str(_context["save_status"]),16,RED if warning else TEAL,false,"GrowthCurrentSave"))
			_body.add_child(_label("최근 작업 메시지",20,INK,true))
			_body.add_child(_label(str(_context["notice"]).replace("⚠ ",""),17))
	_policy.text=""
	if _page=="training" and _style!="":
		var review: Dictionary=_state.training_review(_id,_style)
		_policy.text="훈련비 %s · 환불·전문화 변경 불가" % Growth._won(review["cost"])
	elif _page=="expand" and not _state.shop_expanded(): _policy.text="증축비 %s · 환불 없음" % Growth._won(_state.expansion_review()["price"])
	elif _page=="facility" and not _state.facility_review(_id)["owned"]: _policy.text="일회성 구매 · 환불 없음"
	elif _page=="staff" and not _state.hired_staff().has(_id): _policy.text="일회성 고용비 + 영업마다 일당 · 해고·환불 없음"
	if float(_context["training_left"])>0: _policy.text="성장 결과 정리 중 · 효과는 이미 반영됐어요"
	_policy.visible=_policy.text!=""
	if bool(_context["closing_blocked"]) or (_page not in ["list","notice"] and bool(_context["busy"])): _primary.disabled=true
	if bool(_context["busy"]):
		_body.add_child(_label("성장 연출 중이에요. 반복해도 효과나 경험은 더해지지 않아요." if float(_context["training_left"])>0 else "영업·탐색·준비를 마친 뒤 변경할 수 있어요.",15,TEAL))
	_generation+=1
	_restore_scroll.call_deferred(_generation,position)
	_layout()


func _grid() -> GridContainer:
	var grid:=GridContainer.new()
	grid.name="GrowthGrid"
	grid.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation",10)
	grid.add_theme_constant_override("v_separation",10)
	_body.add_child(grid)
	return grid


func _card(parent: Node, title: String, subtitle: String, texture: Texture2D, node_name: String, callback: Callable) -> void:
	var card:=_button("",node_name)
	card.custom_minimum_size.y=118
	card.pressed.connect(callback)
	parent.add_child(card)
	var inset:=MarginContainer.new()
	inset.mouse_filter=Control.MOUSE_FILTER_IGNORE
	inset.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge in ["left","right"]: inset.add_theme_constant_override("margin_"+edge,12)
	for edge in ["top","bottom"]: inset.add_theme_constant_override("margin_"+edge,12)
	card.add_child(inset)
	var row:=HBoxContainer.new()
	row.mouse_filter=Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation",10)
	inset.add_child(row)
	row.add_child(_picture(texture,Vector2(64,64)))
	var words:=_col(row,5)
	words.mouse_filter=Control.MOUSE_FILTER_IGNORE
	words.size_flags_vertical=Control.SIZE_SHRINK_CENTER
	words.add_child(_label(title,18,INK,true))
	words.add_child(_label(subtitle,14,TEAL))
	var arrow:=_picture(Art.icon("chevron_right"),Vector2(20,24))
	arrow.modulate=TEAL
	row.add_child(arrow)


func _list_page() -> void:
	match _section:
		"staff":
			_body.add_child(_label("기본 직원 2명 · 요리사와 서버",16))
			_body.add_child(_label("요리사는 메뉴 개발 도전으로, 보조 직원은 영업 경험과 훈련으로 성장해요.",15))
			var grid:=_grid()
			var chef: Dictionary=_state.chef_challenge_review()
			_card(grid,"요리사 · 점심 조리",{"open":"새 도전 · 점심 라멘 개발","active":"도전 중 · %d/6 조건 달성" % chef["met"],"ready":"도전 달성! 성장 확인","mastered":"점심 조리 습득 · 조리 시간 -5%"}[chef["status"]],_portrait("chef"),"GrowthChef",_navigate.bind("chef"))
			for staff in _state.staff_reviews():
				var id: String=staff["id"]
				var hired: bool=staff["hired"]
				var entry: Dictionary=_state.staff_training().get(id,{})
				var subtitle: String="함께 일해요 · 훈련 %d/2단계" % Training.level(entry) if hired else "고용비 %s · 일당 %s" % [Growth._won(staff["hire_price"]),Growth._won(staff["wage"])]
				if not hired and not staff["can_hire"]: subtitle+="\n고용 조건 확인"
				_card(grid,staff["name"]+" · "+staff["role_name"],subtitle,_portrait(id),"GrowthStaff_"+id,_navigate.bind("staff",id))
		"facility":
			_body.add_child(_label("용량을 넓히는 투자",20,INK,true))
			_body.add_child(_label("설치만으로 메뉴·직원이 생기지는 않아요. 구매는 한 번이고 환불되지 않아요.",15))
			var grid:=_grid()
			for review in _state.facility_reviews():
				_card(grid,review["name"],"설치 완료" if review["owned"] else review["price_text"]+" · "+("구매 가능" if review["can_buy"] else "조건 확인"),Art.icon("restaurant" if Growth.find_facility(review["id"])["track"]=="recipe" else "menu"),"GrowthFacility_"+review["id"],_navigate.bind("facility",review["id"]))
		"shop":
			_body.add_child(_label("공간과 가게의 평판",20,INK,true))
			_body.add_child(_label("증축은 좌석·판매 칸, 등급은 토핑 칸과 투자 자격을 열어요.",15))
			var grid:=_grid()
			_card(grid,"가게 증축","%d석 · 판매 %d종 → 상세 보기" % [_state.seat_count(),_state.selling_capacity()],Art.icon("restaurant"),"GrowthExpansion",_navigate.bind("expand"))
			_card(grid,"%d랭크 · %s" % [_state.rank(),_state.rank_title()],"등급 심사와 해금 조건 보기",Art.icon("info"),"GrowthRank",_navigate.bind("rank"))
	_primary.disabled=bool(_context["closing_blocked"])


func _staff_header(parent: Node) -> void:
	var staff: Dictionary=Staffing.find(_id)
	var row:=HBoxContainer.new()
	row.add_theme_constant_override("separation",12)
	parent.add_child(row)
	row.add_child(_picture(_portrait(_id),Vector2(72,72)))
	var words:=_col(row,4)
	words.add_child(_label(staff["name"],24,INK,true))
	words.add_child(_label(staff["role_name"],16,TEAL))


func _effect_text(effect: Dictionary) -> String:
	var staff: Dictionary=Staffing.find(_id)
	var base: int=Staffing.PREP_PERCENT if staff["role"]=="prep" else Staffing.SERVE_PERCENT
	return "%s 시간 %d%% · 하루 운영비 %s" % ["조리" if staff["role"]=="prep" else "서빙 왕복",base-int(effect["percent_discount"]),Growth._won(int(staff["wage"])+int(effect["wage_delta"]))]


func _staff_page() -> void:
	var review: Dictionary=_state.staff_review(_id)
	var paper:=_paper(_body)
	_staff_header(paper)
	paper.add_child(_label(review["desc"],16))
	if review["hired"]:
		_experience()
		_primary.text="육성 자세히"
		return
	var price:=_paper(_body)
	price.add_child(_label("고용비 "+Growth._won(review["hire_price"]),22,INK,true,"GrowthHireCost"))
	price.add_child(_label("영업 정산마다 일당 "+Growth._won(review["wage"])+" · 해고·환불 없음",16,TEAL))
	_body.add_child(_label("고용할 수 있어요." if review["can_hire"] else review["reason"],16,TEAL if review["can_hire"] else RED,false,"GrowthHireReason"))
	var preview: Dictionary=_state.hiring_preview(_id)
	var forecast:=_paper(_body)
	forecast.add_child(_label("오늘 메뉴로 비교한 예상",20,INK,true))
	if preview["error"]!="": forecast.add_child(_label(preview["error"],16))
	else:
		var before: Dictionary=preview["before"]
		var after: Dictionary=preview["after"]
		for i in before["menus"].size():
			forecast.add_child(_label("%s v%d · 조리 %d→%d초" % [before["menus"][i]["recipe_name"],before["menus"][i]["version"],before["menus"][i]["prep"],after["menus"][i]["prep"]],16))
		forecast.add_child(_label("예상 판매 %d→%d그릇\n하루 운영비 %s→%s\n순영업이익 %s→%s" % [before["units"],after["units"],Growth._won(before["overhead"]),Growth._won(after["overhead"]),Growth._won(before["net"]),Growth._won(after["net"])],16,TEAL,false,"GrowthHiringForecast"))
		forecast.add_child(_label("일회성 고용비는 이익에 포함하지 않았어요. 실제 정산은 완료 주문 기준이에요."+(" 서빙 대기 단축은 예상 이익에 미포함이에요." if Staffing.find(_id)["role"]=="floor" else ""),15))
	_primary.text="고용 · "+Growth._won(review["hire_price"])
	_primary.disabled=not review["can_hire"]


func _experience() -> void:
	var entry: Dictionary=_state.staff_training()[_id]
	var level: int=Training.level(entry)
	var style: String="" if level==0 else entry["lessons"][level-1]["style"]
	var effect: Dictionary=Training.effect(level,style)
	var paper:=_paper(_body)
	paper.add_child(_label("%s · 훈련 %d/2단계" % [effect["title"],level],20,INK,true,"GrowthQualification"))
	paper.add_child(_label("실무 %d일 · 경험 %d그릇" % [entry["work_days"],entry["bowls"]],16,TEAL,false,"GrowthExperience"))
	paper.add_child(_label("현재 효과: "+_effect_text(effect),16))
	var xp:=ProgressBar.new()
	xp.name="GrowthExperienceBar"
	xp.custom_minimum_size.y=18
	_style_progress(xp)
	xp.value=minf(100,100.0*float(entry["bowls"])/float(Training.NEED_BOWLS[mini(level,1)]))
	paper.add_child(xp)
	paper.add_child(_label("끝까지 정산한 영업의 완료 그릇만 경험이 돼요. 훈련은 맛 점수를 바꾸지 않아요.",15))


func _training_page() -> void:
	_staff_header(_body)
	_experience()
	var level: int=Training.level(_state.staff_training()[_id])
	if level==2:
		_body.add_child(_label("전문화 완료 · 선택은 유지되며 더 훈련하거나 바꿀 수 없어요.",18,TEAL))
		_primary.text="육성 완료"
		_primary.disabled=true
		return
	# A completed stage invalidates its old choice. Never project the previous
	# basic style as a specialization or read an empty review effect afterward.
	if not Training.STAGE_STYLES[level].has(_style): _style=""
	_body.add_child(_label("다음 훈련을 고르세요",20,INK,true))
	for style in Training.STAGE_STYLES[level]:
		var review: Dictionary=_state.training_review(_id,style)
		var target: Dictionary=review["effect"]
		var choice:=_button(target["title"]+" · "+Growth._won(review["cost"]),"GrowthStyle_"+style,"teal" if _style==style else "summary","check" if _style==style else "chevron_right")
		choice.disabled=bool(_context["busy"])
		choice.pressed.connect(func():
			action_requested.emit("cancel","","")
			_navigate("training",_id,style))
		_body.add_child(choice)
	if _style=="":
		_primary.text="훈련 방식을 선택하세요"
		_primary.disabled=true
		return
	var review: Dictionary=_state.training_review(_id,_style)
	var detail:=_paper(_body)
	detail.add_child(_label("훈련 후: "+_effect_text(review["effect"]).replace(" · ","\n"),18,TEAL,true,"GrowthTrainingEffect"))
	detail.add_child(_label("필요 경험 %d그릇 · 실무 %d일 · %d랭크\n훈련비 %s · 경험은 유지돼요" % [review["min_bowls"],review["min_work_days"],review["min_rank"],Growth._won(review["cost"])],16))
	# Full domain reason is displayed, including the same-day restriction.
	detail.add_child(_label("조건을 모두 충족했어요." if review["eligible"] else review["reason"],16,TEAL if review["eligible"] else RED,false,"GrowthTrainingReason"))
	detail.add_child(_label("훈련비는 환불되지 않아요. 같은 직원은 하루 한 번만 훈련하며 전문화는 나중에 바꿀 수 없어요.",15,RED))
	_primary.text="다시 눌러 훈련 확정" if _context["training_armed"]==_id+":"+_style else "훈련 준비 · "+Growth._won(review["cost"])
	_primary.disabled=not review["eligible"]


func _facility_page() -> void:
	var review: Dictionary=_state.facility_review(_id)
	var definition: Dictionary=Growth.find_facility(_id)
	var paper:=_paper(_body)
	paper.add_child(_label(review["name"],24,INK,true))
	paper.add_child(_label(review["price_text"],24,TEAL,true))
	paper.add_child(_label(review["desc"],17))
	var effect: String=review["effect_text"]
	if review["owned"]: effect="현재 등록 메뉴 %d종까지" % _state.menu_capacity() if definition["track"]=="recipe" else "현재 직원 %d명까지" % _state.staff_capacity()
	paper.add_child(_label(effect,18,TEAL,true,"GrowthFacilityEffect"))
	paper.add_child(_label("필요 등급 %d랭크%s" % [definition["min_rank"]," · 선행 "+Growth.find_facility(definition["requires"])["name"] if definition["requires"]!="" else ""],16))
	paper.add_child(_label("설치 완료" if review["owned"] else ("구매할 수 있어요." if review["can_buy"] else review["reason"]),16,TEAL if review["can_buy"] or review["owned"] else RED,false,"GrowthFacilityReason"))
	_body.add_child(_label("구매는 한 번이며 환불은 없어요. 열린 용량을 직접 개발·고용에 활용하세요. 맛 점수나 방문 손님이 자동으로 늘지 않아요.",16))
	_primary.text="설치 완료" if review["owned"] else "구매 · "+review["price_text"]
	_primary.disabled=not review["can_buy"]


func _expand_page() -> void:
	var review: Dictionary=_state.expansion_review()
	var paper:=_paper(_body)
	paper.add_child(_label("홀과 판매 메뉴 늘리기",22,INK,true))
	paper.add_child(_label("8석 → 12석\n동시 판매 1종 → 2종",24,TEAL,true,"GrowthExpansionEffect"))
	paper.add_child(_label("현재 %d석 · 판매 %d종" % [_state.seat_count(),_state.selling_capacity()],16))
	paper.add_child(_label("필요 2랭크 · 증축비 "+Growth._won(review["price"]),18,INK,true))
	paper.add_child(_label("테이블 2개와 4석이 실제 매장에 추가돼요. 주방은 하나이고 방문 손님이 자동으로 늘지는 않아요. 판매할 두 메뉴는 직접 골라야 해요.",17))
	_body.add_child(_label("증축 완료" if review["owned"] else ("증축할 수 있어요." if review["can_buy"] else review["reason"]),16,TEAL if review["can_buy"] or review["owned"] else RED,false,"GrowthExpansionReason"))
	_body.add_child(_label("한 번만 구매하며 환불되지 않아요. 기존 메뉴는 유지돼요.",16,RED))
	_primary.text="증축 완료" if review["owned"] else ("다시 눌러 증축 확정" if _context["expand_armed"] else "증축 · "+Growth._won(review["price"]))
	_primary.disabled=not review["can_buy"]


func _rank_page() -> void:
	var review: Dictionary=_state.promotion_review()
	var paper:=_paper(_body)
	paper.add_child(_label("%d랭크 · %s" % [review["rank"],review["title"]],24,INK,true))
	paper.add_child(_label(review["summary"],17))
	paper.add_child(_label("현재 토핑 %d칸 · 등록 메뉴 %d종 · 직원 %d명까지" % [_state.topping_slots(),_state.menu_capacity(),_state.staff_capacity()],16,TEAL))
	if review["top"]:
		_body.add_child(_label("가장 높은 가게 등급이에요.",20,TEAL,true))
		_primary.text="최고 등급"
		_primary.disabled=true
		return
	_body.add_child(_label("다음: %d랭크 · %s" % [review["next"],review["next_title"]],20,INK,true))
	for condition in review["conditions"]:
		var line:=_paper(_body)
		line.add_child(_label(("달성 · " if condition["met"] else "부족 · ")+condition["text"],17,TEAL if condition["met"] else INK,true))
		line.add_child(_label(condition["measured_text"],16))
	_body.add_child(_label("심사는 시식 기록으로 다시 계산해요. 비용·금전 보상은 없고 등급만 올라요. 토핑 칸은 등급으로 열리며, 설비·직원은 별도 구매·고용이 필요해요.",16))
	_primary.text="다시 눌러 등급 확정" if _context["promote_armed"] else "등급 심사 신청"
	_primary.disabled=not review["eligible"]


func _commit() -> void:
	match _page:
		"chef":
			var status: String=_state.chef_challenge_review()["status"]
			if status=="open": action_requested.emit("chef_start","","")
			elif status=="ready": action_requested.emit("chef_claim","","")
			elif status=="active": action_requested.emit("chef_sell","","")
			else: action_requested.emit("close","","")
		"staff":
			if _state.hired_staff().has(_id): _navigate("training",_id)
			else: action_requested.emit("hire",_id,"")
		"training": action_requested.emit("train",_id,_style)
		"facility": action_requested.emit("facility",_id,"")
		"expand": action_requested.emit("expand","","")
		"rank": action_requested.emit("promote","","")
		_: action_requested.emit("close","","")


## The chef is the existing kitchen sprite, not an invented hired employee.
## A single bounded challenge keeps actual service evidence separate from draft previews.
func open_chef() -> void:
	_section="staff"
	_navigate("chef")


func _chef_page() -> void:
	var review: Dictionary=_state.chef_challenge_review()
	var status: String=review["status"]
	var hero:=_paper(_body,"ChefHero")
	var header:=HBoxContainer.new()
	header.add_theme_constant_override("separation",12)
	hero.add_child(header)
	header.add_child(_picture(_portrait("chef"),Vector2(64,80)))
	var heading:=_col(header,4)
	heading.add_child(_label("요리사 · 첫 성장",15,TEAL))
	heading.add_child(_label("점심 라멘 개발",23,INK,true,"ChefChallengeTitle"))
	heading.add_child(_label({"open":"도전 대기","active":"도전 중 · %d/6" % review["met"],"ready":"달성! 성장 확인 가능","mastered":"점심 조리 습득"}[status],16,TEAL,true,"ChefChallengeState"))
	hero.add_child(_label("빠르고 부담 없는 한 그릇. 손님이 기다리는 점심시간을 줄여 보세요.",16))
	var reward:=_paper(_body,"ChefReward")
	reward.add_child(_label("성장 효과 · 조리 시간 -5%",19,TEAL,true))
	reward.add_child(_label("보조 직원 효과를 적용한 뒤 5% 단축하고 올림해요. 다음 영업부터 적용 · 비용·일당 변화 없음",15))
	if not review["attempt"].is_empty():
		var prep: int=preload("res://scripts/domain/recipe_evaluator.gd").prep_seconds(review["attempt"]["config"])
		var plain: Dictionary=Staffing.snapshot(_state.hired_staff(),_state.staff_training())
		var mastered: Dictionary=Staffing.snapshot(_state.hired_staff(),_state.staff_training(),1)
		reward.add_child(_label("현재 직원 구성 · 도전 메뉴 %d초 → %d초" % [Staffing.effective_prep(prep,plain),Staffing.effective_prep(prep,mastered)],15,TEAL))
	if status=="mastered":
		reward.add_child(_label("%d일차 습득 · 한 단계 성장했어요!" % review["completed_day"],16,TEAL,false,"ChefMastery"))
	else:
		var guide:=_button("메뉴 개발로 · 구성을 바꿔 시식","ChefDevelop","summary","ramen_dining")
		guide.disabled=bool(_context["busy"])
		guide.pressed.connect(func(): action_requested.emit("develop","",""))
		_body.add_child(guide)
	_body.add_child(_label("도전을 완료한 영업" if status in ["ready","mastered"] else "한 영업에서 함께 달성",19,INK,true))
	var bar:=ProgressBar.new()
	bar.custom_minimum_size.y=12
	_style_progress(bar)
	bar.value=100.0*float(review["met"])/6.0
	bar.mouse_filter=Control.MOUSE_FILTER_IGNORE
	_body.add_child(bar)
	var conditions:=_grid()
	for row in review["rows"]:
		var paper:=_paper(conditions)
		# Wrapped labels have zero horizontal minimum. Expand each grid cell,
		# otherwise GridContainer can allocate only a border-wide text column.
		paper.get_parent().size_flags_horizontal=Control.SIZE_EXPAND_FILL
		paper.add_child(_label(("달성 · " if row["met"] else "목표 · ")+row["title"],16,TEAL if row["met"] else INK,true))
		paper.add_child(_label(row["value"],15,TEAL if row["met"] else INK))
	if not review["attempt"].is_empty():
		var attempt: Dictionary=review["attempt"]
		_body.add_child(_label("%s · %d일차 실제 영업%s" % [attempt["name"],attempt["day"]," · 첫 달성 기록 보존" if status in ["ready","mastered"] else " · 최근 시도"],16,TEAL,false,"ChefAttempt"))
	_body.add_child(_label("수락 후 새 기록을 시식해야 해요. 가격만 바꾸면 개발로 인정되지 않아요. 판매 메뉴를 한 종류로 지정하고 영업을 끝까지 마치세요. 중단·예측·이전 영업은 집계하지 않아요.",15))
	_primary.text={"open":"무료로 도전 수락","active":"판매 메뉴 확인","ready":"성장 확인 · 조리 -5%","mastered":"가게로"}[status]
