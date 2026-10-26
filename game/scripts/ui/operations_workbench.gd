extends Control
## Presentation only: immutable records and domain reviews are the source of
## truth. Every paid, destructive or rewarding action goes back to main's
## existing guards. Browsing, filtering and comparison never mutate the save.
signal action_requested(kind: String, data: Dictionary)
const Shared = preload("res://scripts/ui/service_result_view.gd")
const Mock = preload("res://scripts/ui/mock_fidelity_art.gd")
const Art = preload("res://scripts/ui/bowl_editor_art.gd")
const Pixel = preload("res://scripts/ui/pixel_art.gd")
const Bowl = preload("res://scripts/ui/layered_recipe_view.gd")
const Catalog = preload("res://scripts/domain/ingredient_catalog.gd")
const Customers = preload("res://scripts/domain/customer_catalog.gd")
const Research = preload("res://scripts/domain/ramen_research.gd")
const Story = preload("res://scripts/domain/regular_story_catalog.gd")
const Stories = preload("res://scripts/domain/regular_stories.gd")
const Contest = preload("res://scripts/domain/ramen_contest.gd")
const Eval = preload("res://scripts/domain/recipe_evaluator.gd")
const Process = preload("res://scripts/domain/recipe_process.gd")
const Growth = preload("res://scripts/domain/shop_growth.gd")
const BODY = preload("res://assets/fonts/Pretendard-Regular.otf")
const BOLD = preload("res://assets/fonts/Pretendard-Bold.otf")
const INK := Color("18354f")
const TEAL := Color("087e80")
const RED := Color("aa3828")
const SECTIONS: Array = [["notebook","노트"],["research","의뢰"],["stories","단골"],["contests","대회"],["selling","판매"]]
const PAGE_SIZE: int = 8
var _state: Object
var _context: Dictionary = {}
var _key: String = ""
var _section: String = "notebook"
var _page: String = "list"
var _id: String = ""
var _filter: String = "menus"
var _index: int = 0
var _positions: Dictionary = {}
var _generation: int = 0
var _primary_kind: String = "close"
var _primary_data: Dictionary = {}
var _margin: MarginContainer
var _frame: PanelContainer
var _title: Label
var _wallet: Label
var _summary: Label
var _tabs: HBoxContainer
var _scroll: ScrollContainer
var _body: VBoxContainer
var _back: Button
var _notice: Button
var _policy: Label
var _primary: Button
var _secondary: Button
var _progress: ProgressBar
var _portraits: Dictionary = {}


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
	if skin in ["teal","blue"]:
		for prop in ["font_color","font_hover_color","font_focus_color","icon_normal_color","icon_hover_color"]: out.add_theme_color_override(prop,Color.WHITE)
	return out


func _col(parent: Node, gap: int = 8) -> VBoxContainer:
	var out:=VBoxContainer.new()
	out.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	out.add_theme_constant_override("separation",gap)
	parent.add_child(out)
	return out


func _paper(parent: Node) -> VBoxContainer:
	var panel:=PanelContainer.new()
	panel.add_theme_stylebox_override("panel",Mock.style("summary",Vector2(14,14)))
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
	if not _portraits.has(id): _portraits[id]=ImageTexture.create_from_image(Pixel.portrait_image(id))
	return _portraits[id]


func _dish(config: Dictionary, minimum: Vector2) -> Control:
	var out:=Bowl.new()
	out.custom_minimum_size=minimum
	out.mouse_filter=Control.MOUSE_FILTER_IGNORE
	out.set_config(config)
	return out


func _ready() -> void:
	name="OperationsWorkbench"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim:=ColorRect.new()
	dim.color=Color(0,0,0,0.65)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	_margin=MarginContainer.new()
	_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_margin)
	_frame=PanelContainer.new()
	_frame.name="OpsFrame"
	_frame.add_theme_stylebox_override("panel",Mock.style("panel",Vector2(14,14)))
	_margin.add_child(_frame)
	var column:=_col(_frame,8)
	var head:=HBoxContainer.new()
	head.add_theme_constant_override("separation",8)
	column.add_child(head)
	_back=_button("","OpsBack","summary","arrow_back")
	_back.size_flags_horizontal=Control.SIZE_SHRINK_BEGIN
	_back.tooltip_text="목록 또는 가게로 돌아가기"
	_back.pressed.connect(_go_back)
	head.add_child(_back)
	_title=_label("메뉴 노트",22,INK,true,"OpsTitle")
	_title.autowrap_mode=TextServer.AUTOWRAP_OFF
	_title.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
	_title.size_flags_vertical=Control.SIZE_SHRINK_CENTER
	head.add_child(_title)
	head.add_child(_picture(Mock.texture("coin"),Vector2(22,22)))
	_wallet=_label("",16,INK,true,"OpsWallet")
	_wallet.autowrap_mode=TextServer.AUTOWRAP_OFF
	_wallet.size_flags_horizontal=Control.SIZE_SHRINK_END
	_wallet.size_flags_vertical=Control.SIZE_SHRINK_CENTER
	head.add_child(_wallet)
	_tabs=HBoxContainer.new()
	_tabs.add_theme_constant_override("separation",4)
	column.add_child(_tabs)
	_summary=_label("",14,TEAL,false,"OpsOverview")
	column.add_child(_summary)
	_notice=_button("작업·저장 안내","OpsNotice","summary","info")
	_notice.add_theme_font_size_override("font_size",14)
	_notice.pressed.connect(func(): _navigate("notice"))
	column.add_child(_notice)
	_progress=ProgressBar.new()
	_progress.name="OpsJudging"
	_progress.custom_minimum_size.y=14
	_progress.show_percentage=false
	_progress.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var track:=StyleBoxFlat.new()
	track.bg_color=Color("d7c9ae")
	var fill:=StyleBoxFlat.new()
	fill.bg_color=TEAL
	_progress.add_theme_stylebox_override("background",track)
	_progress.add_theme_stylebox_override("fill",fill)
	column.add_child(_progress)
	_scroll=ScrollContainer.new()
	_scroll.name="OpsScroll"
	_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.scroll_deadzone=10
	_scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL
	column.add_child(_scroll)
	_body=_col(_scroll,10)
	_policy=_label("",14,RED,false,"OpsPolicy")
	column.add_child(_policy)
	var footer:=HBoxContainer.new()
	footer.add_theme_constant_override("separation",8)
	column.add_child(footer)
	_secondary=_button("메뉴 개발","OpsSecondary","summary","restaurant")
	_secondary.pressed.connect(func():
		if _page=="list": action_requested.emit("route",{"tab":0})
		else: _go_back())
	footer.add_child(_secondary)
	_primary=_button("가게로","OpsPrimary","gold")
	_primary.custom_minimum_size.y=54
	_primary.pressed.connect(func(): action_requested.emit(_primary_kind,_primary_data))
	footer.add_child(_primary)
	resized.connect(_layout)
	_layout()


func _layout() -> void:
	if _margin==null: return
	for edge in ["left","right"]: _margin.add_theme_constant_override("margin_"+edge,maxi(10,int((size.x-860)/2)))
	for edge in ["top","bottom"]: _margin.add_theme_constant_override("margin_"+edge,14 if size.y<780 else 22)
	var grid:=find_child("OpsGrid",true,false) as GridContainer
	if grid!=null: grid.columns=2 if size.x>=760 else 1


func present(state: Object, section: String, context: Dictionary) -> void:
	_state=state
	_context=context
	if section!=_section:
		_positions[_position_key()]=_scroll.scroll_vertical
		_section=section
		_page="list"
		_id=""
		_key=""
	var key: String=JSON.stringify([context["revision"],context["busy"],context["notice"],context["warning"],context["save_status"],context["delete_id"],context["story_armed"]])
	_progress.visible=float(context["contest_left"])>0 and _section=="contests"
	_progress.value=100.0*(1.0-float(context["contest_left"])/1.5)
	if key!=_key:
		_key=key
		_render(true)


func _position_key() -> String:
	return _section+":"+_page+":"+_id+":"+_filter+":"+str(_index)


func _navigate(page: String, id: String = "") -> void:
	_positions[_position_key()]=_scroll.scroll_vertical
	_page=page
	_id=id
	_render()


func _go_back() -> void:
	action_requested.emit("cancel",{})
	if _page=="list": action_requested.emit("close",{})
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
	_title.text={"notebook":"메뉴 노트","research":"연구 의뢰","stories":"단골 이야기","contests":"라멘 대회","selling":"판매 메뉴"}[_section]
	_wallet.text=Growth._won(_state.wallet)
	for section in SECTIONS:
		var tab:=_button(section[1],"OpsTab_"+section[0],"teal" if section[0]==_section else "summary")
		tab.add_theme_font_size_override("font_size",14)
		tab.disabled=bool(_context["closing_blocked"])
		tab.pressed.connect(func(): action_requested.emit("section",{"section":section[0]}))
		_tabs.add_child(tab)
	_summary.text="%d일차 · %d랭크 · 시식 기록 %d개" % [_state.day,_state.rank(),_state.record_count()]
	_notice.visible=true
	_notice.text="저장하지 못했어요 · 안내 보기" if str(_context["warning"])!="" else ("최근 작업 안내 · 자세히 보기" if str(_context["notice"])!="" else "저장 상태·도움말")
	_notice.add_theme_color_override("font_color",RED if str(_context["warning"])!="" else TEAL)
	_policy.text=""
	_primary_kind="close"
	_primary_data={}
	_primary.text="가게로"
	_primary.disabled=bool(_context["closing_blocked"])
	_back.disabled=bool(_context["closing_blocked"])
	_secondary.text="메뉴 개발" if _page=="list" else "뒤로"
	_secondary.disabled=bool(_context["closing_blocked"]) or (_page=="list" and bool(_context["busy"]))
	if _page=="notice":
		var paper:=_paper(_body)
		paper.add_child(_label("현재 저장 상태",20,INK,true))
		paper.add_child(_label(str(_context["warning"]) if str(_context["warning"])!="" else str(_context["save_status"]),16,RED if str(_context["warning"])!="" else TEAL,false,"OpsCurrentSave"))
		if str(_context["notice"])!="":
			paper.add_child(_label("최근 작업",20,INK,true))
			paper.add_child(_label(str(_context["notice"]).replace("⚠ ",""),16))
		paper.add_child(_label(str(_context["save_policy"]),16))
		_primary.text="지금 저장"
		_primary_kind="save"
	elif _page=="map": action_requested.emit("map",{"body":_body})
	elif _page=="forecast":
		_body.add_child(_label("오늘의 영업 예상",22,INK,true))
		_body.add_child(_label(str(_context["forecast"]),17,INK,false,"OpsForecast"))
		_body.add_child(_label("수요는 가격·맛·조리 시간에 따른 예상이에요. 실제 정산은 완료한 주문만 반영해요. 두 메뉴는 주방과 손님을 공유해요.",15))
		_link("지난 영업 결과","OpsLastReport","report",{},_state.last_report.is_empty() or bool(_context["busy"]))
	elif _page=="detail":
		match _section:
			"notebook","selling": _record_page()
			"research": _research_page()
			"stories": _story_page()
			"contests": _contest_page()
	else:
		match _section:
			"notebook","selling": _records_page()
			"research": _research_list()
			"stories": _stories_list()
			"contests": _contests_list()
	_layout()
	_generation+=1
	_restore_scroll(_generation,position)


## The whole padded card is a single scroll-friendly button. Decorative
## descendants ignore input so dragging a bowl, portrait or title cancels tap.
func _row(parent: Node, title: String, subtitle: String, status: String, node_name: String, id: String, picture: Control) -> void:
	var button:=_button("",node_name)
	button.tooltip_text=title+"\n"+subtitle+"\n"+status
	button.custom_minimum_size.y=126
	button.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	parent.add_child(button)
	var inset:=MarginContainer.new()
	inset.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge in ["left","right"]: inset.add_theme_constant_override("margin_"+edge,14)
	for edge in ["top","bottom"]: inset.add_theme_constant_override("margin_"+edge,12)
	inset.mouse_filter=Control.MOUSE_FILTER_IGNORE
	button.add_child(inset)
	var line:=HBoxContainer.new()
	line.mouse_filter=Control.MOUSE_FILTER_IGNORE
	line.add_theme_constant_override("separation",10)
	inset.add_child(line)
	line.add_child(picture)
	var col:=_col(line,4)
	col.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var heading:=_label(title,18,INK,true)
	heading.max_lines_visible=2
	heading.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
	col.add_child(heading)
	col.add_child(_label(subtitle,14))
	col.add_child(_label(status,14,TEAL,true))
	var chevron:=_picture(Art.icon("chevron_right"),Vector2(18,22))
	chevron.modulate=TEAL
	line.add_child(chevron)
	button.pressed.connect(func(): _navigate("detail",id))


func _grid() -> GridContainer:
	var grid:=GridContainer.new()
	grid.name="OpsGrid"
	grid.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	grid.columns=2 if size.x>=760 else 1
	grid.add_theme_constant_override("h_separation",10)
	grid.add_theme_constant_override("v_separation",10)
	_body.add_child(grid)
	return grid


func _link(text: String, node_name: String, kind: String, data: Dictionary = {}, disabled: bool = false) -> void:
	var button:=_button(text,node_name,"summary","chevron_right")
	button.disabled=disabled
	button.pressed.connect(func(): action_requested.emit(kind,data))
	_body.add_child(button)


func _records_page() -> void:
	_summary.text="등록 %d/%d종 · 개정 %d/%d · 판매 %d/%d종" % [_state.menu_count(),_state.menu_capacity(),_state.record_count(),_state.record_history_capacity(),_state.selling_records().size(),_state.selling_capacity()]
	var filters:=HBoxContainer.new()
	filters.add_theme_constant_override("separation",4)
	_body.add_child(filters)
	for item in [["menus","최신 메뉴"],["history","개정 이력"],["selling","판매 중"]]:
		var button:=_button(item[1],"OpsFilter_"+item[0],"teal" if _filter==item[0] else "summary")
		button.add_theme_font_size_override("font_size",14)
		button.pressed.connect(func():
			_filter=item[0]
			_index=0
			_navigate("list"))
		filters.add_child(button)
	var records: Array=_state.records()
	records.reverse()
	var rows: Array=[]
	var families: Dictionary={}
	var selling: Array=[]
	for rec in _state.selling_records(): selling.append(int(rec["record_id"]))
	for rec in records:
		if _filter=="selling" and not selling.has(int(rec["record_id"])): continue
		if _filter=="menus" and families.has(rec["lineage_id"]): continue
		families[rec["lineage_id"]]=true
		rows.append(rec)
	var pages: int=maxi(1,ceili(rows.size()/float(PAGE_SIZE)))
	_index=clampi(_index,0,pages-1)
	if rows.is_empty():
		var empty:=_paper(_body)
		empty.add_child(_picture(Mock.texture("pot"),Vector2(0,100)))
		empty.add_child(_label("첫 그릇을 기록해 보세요",22,INK,true))
		empty.add_child(_label("메뉴를 개발하고 시식하면 그릇과 평가가 여기에 남아요. 초안은 시식 기록으로 제출하거나 판매할 수 없어요.",17))
		_primary.text="메뉴 개발"
		_primary_kind="route"
		_primary_data={"tab":0}
	else:
		var grid:=_grid()
		for rec in rows.slice(_index*PAGE_SIZE,(_index+1)*PAGE_SIZE):
			var id: int=rec["record_id"]
			var markers: PackedStringArray=[]
			if id==_state.selected_record_id: markers.append("제출 대상")
			if selling.has(id): markers.append("판매 중")
			if markers.is_empty(): markers.append("상세·비교 보기")
			_row(grid,"%s v%d" % [rec["name"],rec["version"]],"%s · %d초" % [Growth._won(rec["config"]["price"]),Eval.prep_seconds(rec["config"])]," · ".join(markers),"OpsRecord_%d" % id,str(id),_dish(rec["config"],Vector2(84,88)))
	if pages>1:
		var pager:=HBoxContainer.new()
		_body.add_child(pager)
		for item in [[-1,"최근","OpsNewer"],[1,"이전","OpsOlder"]]:
			var button:=_button(item[1],item[2])
			button.disabled=(_index==0 if item[0]==-1 else _index==pages-1)
			button.pressed.connect(func():
				_index+=int(item[0])
				_navigate("list"))
			pager.add_child(button)
		_body.add_child(_label("%d / %d쪽 · 최신순" % [_index+1,pages],14,TEAL))
	if _section=="notebook":
		_link("발견한 메뉴 연구 지도","OpsMap","map_page")
		_link("판매 메뉴 관리","OpsSellingLink","section",{"section":"selling"})
	else:
		var forecast:=_button("수요·주방 예상 보기","OpsForecastLink","summary","info")
		forecast.pressed.connect(func(): _navigate("forecast"))
		_body.add_child(forecast)
		_link("선택 기록 자동 판매로","OpsAuto","auto",{},bool(_context["busy"]))
		_body.add_child(_label("고정한 메뉴는 개발 대상을 바꿔도 계속 팔아요. 목록을 모두 빼면 선택한 시식 기록을 자동 판매해요. 판매 칸은 증축으로 늘어나요.",15))


func _record_page() -> void:
	var rec: Dictionary=_state.get_record(int(_id))
	if rec.is_empty():
		_body.add_child(_label("이 기록은 정리됐어요. 목록에서 다른 메뉴를 골라 주세요.",18))
		return
	var cfg: Dictionary=rec["config"]
	var hero:=_paper(_body)
	hero.add_child(_dish(cfg,Vector2(0,156)))
	hero.add_child(_label("%s v%d" % [rec["name"],rec["version"]],24,INK,true,"OpsRecordName"))
	hero.add_child(_label("판매가 %s · 원가 %s\n준비 %d초 · %d일차 시식" % [Growth._won(cfg["price"]),Growth._won(Eval.unit_cost(cfg)),Eval.prep_seconds(cfg),rec["tasted_day"]],16,TEAL))
	var ingredients: PackedStringArray=[]
	for id in Catalog.item_ids(cfg): ingredients.append(Catalog.find(id)["name"])
	hero.add_child(_label(" · ".join(ingredients),16))
	if cfg.has("process"): hero.add_child(_label("제조: "+Process.summary(cfg["process"]),15))
	var ratings:=_paper(_body)
	ratings.add_child(_label("단골 시식 평가",20,INK,true))
	for customer in Customers.all():
		var line:=HBoxContainer.new()
		ratings.add_child(line)
		line.add_child(_picture(_portrait(customer["id"]),Vector2(48,48)))
		line.add_child(_label("%s · %d점 · %d/5" % [customer["name"],rec["scores"][customer["id"]],Eval.stars_for(rec["scores"][customer["id"]])],16))
	action_requested.emit("comparison",{"body":_body,"record":rec})
	if _section=="selling":
		var pinned: Array=_state.pinned_menu_ids()
		_primary.text="판매에서 빼기" if pinned.has(int(_id)) else ("이 메뉴로 판매 고정" if _state.selling_capacity()==1 else "판매 목록에 추가")
		_primary_kind="selling"
		_primary_data={"id":int(_id)}
		_policy.text="고정 %d/%d종 · 개발·제출 대상과 별개예요." % [pinned.size(),_state.selling_capacity()]
	else:
		_primary.text="불러와서 개발"
		_primary_kind="select"
		_primary_data={"id":int(_id)}
		_policy.text="불러오면 편집 중 초안도 이 기록으로 바뀌어요."
		_link("불러와 의뢰·대접 대상으로","OpsTarget","target",{"id":int(_id)},bool(_context["busy"]))
		_link("판매 메뉴로 보기","OpsRecordSelling","selling_detail",{"id":int(_id)})
		_link("다시 눌러 기록 삭제" if int(_context["delete_id"])==int(_id) else "이 개정 기록 삭제","OpsDelete","delete",{"id":int(_id)},bool(_context["busy"]) or _state.pinned_menu_ids().has(int(_id)))
		_body.add_child(_label("삭제한 기록은 복구되지 않아요. 판매에 고정한 기록은 먼저 목록에서 빼 주세요. 최고 시식 성적은 유지돼요.",14,RED))
	_primary.disabled=bool(_context["busy"])


func _target() -> void:
	var rec: Dictionary=_state.get_record(_state.selected_record_id)
	var target:=_button("제출할 시식 기록 고르기" if rec.is_empty() else "대상: %s v%d" % [rec["name"],rec["version"]],"OpsChooseTarget","summary","chevron_right")
	target.pressed.connect(func(): action_requested.emit("section",{"section":"notebook"}))
	_body.add_child(target)
	_body.add_child(_label("시식 당시 기록을 심사해요. 편집 중인 초안은 대상이 아니에요.",14,TEAL))


func _research_list() -> void:
	var stage: Dictionary=_state.research_stage()
	_summary.text="%s · %d점 · 완료 %d/%d" % [stage["title"],_state.research_points(),_state.research_completed_ids().size(),Research.REQUESTS.size()]
	_target()
	var grid:=_grid()
	for req in Research.REQUESTS:
		var status: String=_state.research_status(req["id"])
		var text: String={"done":"완료 · 보상 수령","locked":"잠김 · 해금 조건 보기","open":"도전 가능 · 조건 보기"}[status]
		_row(grid,req["title"],"%s · %s" % [Customers.find(req["customer"])["name"],"입문" if req["tier"]=="basic" else "심화"],text,"OpsResearch_"+req["id"],req["id"],_picture(_portrait(req["customer"]),Vector2(64,72)))


func _research_page() -> void:
	var req: Dictionary=Research.find(_id)
	var status: String=_state.research_status(_id)
	var paper:=_paper(_body)
	paper.add_child(_picture(_portrait(req["customer"]),Vector2(0,80)))
	paper.add_child(_label(req["title"],24,INK,true))
	if status=="done": paper.add_child(_label("제출 완료 · 보상 수령",18,TEAL,true))
	paper.add_child(_label("“%s”" % req["dialogue"],17))
	_target()
	var rec: Dictionary=_state.get_record(_state.selected_record_id)
	var chk: Dictionary={} if rec.is_empty() else _state.research_check(_id,_state.selected_record_id)
	for i in req["conditions"].size():
		var condition:=_paper(_body)
		if chk.is_empty() or chk["conditions"].size()!=req["conditions"].size(): condition.add_child(_label(Research.condition_text(req["conditions"][i]),17))
		else:
			var result: Dictionary=chk["conditions"][i]
			condition.add_child(_label(("달성" if result["met"] else "부족")+" · "+result["text"],17,TEAL if result["met"] else INK,true))
			condition.add_child(_label("지금 "+result["measured_text"],16))
			if not result["met"]: condition.add_child(_label(result["hint"],15,TEAL))
	_body.add_child(_label("의뢰인의 조언 · "+req["hint"],16))
	_policy.text="보상 %d점 · %s · 한 번만" % [Research.REWARD_POINTS[req["tier"]],Growth._won(Research.REWARD_CASH[req["tier"]])]
	if status=="locked": _body.add_child(_label(_state.research_lock_reason(_id),17,RED,false,"OpsResearchLock"))
	if status=="done":
		for receipt in _state.research_receipts():
			if receipt["request_id"]==_id: _body.add_child(_label("%d일차 · %s v%d로 제출\n보상 수령 완료" % [receipt["day"],receipt["recipe_name"],receipt["version"]],17,TEAL,false,"OpsResearchReceipt"))
	_primary.text={"open":"이 기록으로 제출","done":"제출 완료","locked":"아직 잠겨 있어요"}[status]
	_primary_kind="research"
	_primary_data={"id":_id}
	_primary.disabled=status!="open" or rec.is_empty() or bool(_context["busy"])


func _stories_list() -> void:
	_target()
	var grid:=_grid()
	for id in Story.ids():
		var arc: Dictionary=_state.story_arc(id)
		_row(grid,Customers.find(id)["name"],Story.story(id)["title"],"방향 선택 · 첫 영업 후" if arc.is_empty() else "대접 %d/2장 · 이야기 보기" % arc["receipts"].size(),"OpsStory_"+id,id,_picture(_portrait(id),Vector2(64,72)))
	_body.add_child(_label("방향 선택 → 메뉴 시식 → 실제 영업에서 대접 → 이야기 마치기",16,TEAL))


func _story_page() -> void:
	var definition: Dictionary=Story.story(_id)
	var arc: Dictionary=_state.story_arc(_id)
	var paper:=_paper(_body)
	paper.add_child(_picture(_portrait(_id),Vector2(0,88)))
	paper.add_child(_label(Customers.find(_id)["name"]+" · "+definition["title"],22,INK,true))
	if arc.is_empty():
		paper.add_child(_label(definition["opening"],18))
		for route in definition["routes"]:
			var key: String=_id+":"+str(route["id"])
			_link(("다시 눌러 확정 · " if _context["story_armed"]==key else "선택 · ")+route["label"],"OpsChoice_"+route["id"],"story_choice",{"id":_id,"route":route["id"]},_state.day<2 or bool(_context["busy"]))
		_policy.text="무료 · 확정 후 방향 변경 불가\n6초 안에 같은 선택을 다시 눌러 확정해요."
		return
	var route: Dictionary=Story.route(_id,arc["route"])
	var chapter: int=arc["receipts"].size()
	paper.add_child(_label(route["label"]+" · 완료 %d/2" % chapter,16,TEAL,true))
	if chapter<2:
		var current: Dictionary=Story.chapter(_id,arc["route"],chapter)
		paper.add_child(_label("%d장 · %s" % [chapter+1,current["title"]],20,INK,true))
		paper.add_child(_label(current["dialogue"],18))
		_target()
		var checked: Dictionary=_state.story_check(_id,_state.selected_record_id)
		_body.add_child(_label(checked["error"] if checked["error"]!="" else "\n".join(checked["lines"]),17,INK,false,"OpsStoryConditions"))
		_policy.text="답례 %s · 이 장에서 한 번만\n시식만으로 완료되지 않아요." % Growth._won(Stories.REWARDS[chapter])
		_primary.text="대접 결과로 마치기"
		_primary_kind="story_complete"
		_primary_data={"id":_id}
		_primary.disabled=_state.get_record(_state.selected_record_id).is_empty() or bool(_context["busy"])
	else: paper.add_child(_label("사연 완료\n"+route["ending"],18,TEAL,false,"OpsStoryEnding"))
	var history:=_paper(_body)
	history.add_child(_label("지난 대화와 대접 기록",20,INK,true))
	history.add_child(_label(definition["opening"]+"\n"+route["reply"],16))
	for i in chapter:
		var receipt: Dictionary=arc["receipts"][i]
		history.add_child(_label(Story.chapter(_id,arc["route"],i)["success"]+"\n%d일차 · %s v%d · %d그릇\n답례 %s 수령" % [receipt["service_day"],receipt["name"],receipt["version"],receipt["units"],Growth._won(Stories.REWARDS[i])],16,TEAL))


func _contests_list() -> void:
	var progress: Dictionary=_state.contest_progress()
	_summary.text="출품 %d회 · 잡지 %d편 · 하루 한 번 출품" % [progress["attempts"],progress["articles"].size()]
	_target()
	var grid:=_grid()
	for review in _state.contest_reviews():
		var best: Dictionary=review["best"]
		_row(grid,review["title"],"출품료 "+Growth._won(review["fee"]),"은메달 이상 · 잡지 제안" if review["article_pending"] else ("조건·상금 보기" if best.is_empty() else "최고 "+Contest.band_name(best["band"])),"OpsContest_"+review["id"],review["id"],_picture(ImageTexture.create_from_image(Pixel.contest_badge_image(0 if best.is_empty() else best["band"])),Vector2(64,72)))
	_body.add_child(_label("대회 기준 70% + 단골 평가 30%. 처음 얻거나 더 높은 메달의 상금 차액만 받아요. 금메달 대회는 완료돼요.",16))


func _contest_page() -> void:
	var review: Dictionary={}
	for item in _state.contest_reviews():
		if item["id"]==_id: review=item
	var best: Dictionary=review["best"]
	_contest_receipt()
	if float(_context["contest_left"])>0:
		_policy.text="접수 완료 · 결과를 정리하고 있어요."
		_primary.text="심사 결과 정리 중…"
		_primary.disabled=true
		return
	var hero:=_paper(_body)
	hero.add_child(_picture(ImageTexture.create_from_image(Pixel.contest_badge_image(0 if best.is_empty() else best["band"])),Vector2(0,88)))
	hero.add_child(_label(review["title"],24,INK,true))
	hero.add_child(_label(review["description"],17))
	hero.add_child(_label(review["criteria"],17,TEAL,true))
	var targets: PackedStringArray=[]
	for axis in Catalog.AXES: targets.append("%s %d" % [Catalog.AXIS_NAMES[axis],review["targets"][axis]])
	hero.add_child(_label("목표 · "+" · ".join(targets),16))
	_target()
	if review["reason"]!="": _body.add_child(_label(review["reason"],17,RED,false,"OpsContestLock"))
	_body.add_child(_label("동 55점 · 4,000원\n은 70점 · 10,000원\n금 85점 · 18,000원\n대회별 누적 상금 상한이에요. 재도전에는 출품료가 다시 들어요.",16))
	if review["article_pending"] or not review["article"].is_empty():
		var article: Dictionary=review["article"]
		var featured: Dictionary=best if article.is_empty() else article["entry"]
		var magazine:=_paper(_body)
		magazine.add_child(_picture(ImageTexture.create_from_image(Pixel.magazine_image()),Vector2(0,100)))
		magazine.add_child(_label("골목 한 그릇",18,TEAL,true))
		magazine.add_child(_label(str(review["article_title"]) % featured["recipe_name"],22,INK,true))
		magazine.add_child(_label(str(review["article_text"]) % featured["recipe_name"],17))
		magazine.add_child(_label("소개 제안 · 협조비 %s · 한 번만" % Growth._won(review["article_cash"]) if article.is_empty() else "%d일차 게재 · 협조비 수령 완료" % article["day"],16,TEAL,false,"OpsMagazineStatus"))
		if article.is_empty(): _link("잡지 소개 수락","OpsMagazine","magazine",{"id":_id},bool(_context["busy"]))
	_policy.text="출품료 %s · %d랭크 · %d일차부터" % [Growth._won(review["fee"]),review["rank"],review["min_day"]]
	_primary.text="심사 결과 정리 중…" if float(_context["contest_left"])>0 else ("금메달 달성" if not best.is_empty() and best["band"]==3 else "출품 · "+Growth._won(review["fee"]))
	_primary_kind="contest"
	_primary_data={"id":_id}
	_primary.disabled=not review["can_enter"] or bool(_context["busy"])


## Put the actual outcome before eligibility prose after judging, so the
## action has a visible payoff. Stored historical configurations are immutable.
func _contest_receipt() -> void:
	var history: Array=_state.contest_progress()["history"]
	for i in range(history.size()-1,-1,-1):
		var last: Dictionary=history[i]
		if last["contest_id"]!=_id: continue
		var result:=_paper(_body)
		if float(_context["contest_left"])>0:
			result.add_child(_label("한 그릇을 심사하고 있어요",22,INK,true))
			result.add_child(_dish(last["config"],Vector2(0,160)))
			result.add_child(_label("시식·향·국물의 조화를 심사 중이에요. 잠시 후 점수와 결과를 확인해요.",17))
			return
		result.add_child(_label("최근 출품 · %s · %d점" % [Contest.band_name(last["band"]),last["score"]],20,TEAL,true,"OpsContestResult"))
		result.add_child(_dish(last["config"],Vector2(0,140)))
		result.add_child(_label("%s v%d\n출품료 %s · 이번 상금 %s" % [last["recipe_name"],last["version"],Growth._won(last["fee"]),Growth._won(last["prize"])],16))
		var evaluated: Dictionary=Contest.evaluate(_id,last["config"])
		result.add_child(_label("대회 기준 %d · 단골 평가 %d" % [evaluated["theme_score"],evaluated["audience_score"]],16))
		for axis in evaluated["feedback"]: result.add_child(_label(axis["hint"],15))
		break
