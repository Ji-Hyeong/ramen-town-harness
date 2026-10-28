extends Control
## Read-only exploration presentation. Region/mode/choice/details are transient
## view state; every paid transaction is delegated to the guarded controller.
signal action_requested(kind: String, data: Dictionary)
const Game = preload("res://scripts/domain/game_state.gd")
const Catalog = preload("res://scripts/domain/ingredient_catalog.gd")
const Regions = preload("res://scripts/domain/ingredient_exploration.gd")
const Market = preload("res://scripts/domain/market_foraging.gd")
const Harbor = preload("res://scripts/domain/harbor_foraging.gd")
const Mountain = preload("res://scripts/domain/mountain_foraging.gd")
const Pixel = preload("res://scripts/ui/pixel_art.gd")
const Art = preload("res://scripts/ui/bowl_editor_art.gd")
const Mock = preload("res://scripts/ui/mock_fidelity_art.gd")
const Editor = preload("res://scripts/ui/bowl_workbench.gd")
const GoalBoard=preload("res://scripts/ui/foraging_goal_board.gd")
const GoalDirections=preload("res://scripts/domain/recipe_directions.gd")
const BODY = preload("res://assets/fonts/Pretendard-Regular.otf")
const BOLD = preload("res://assets/fonts/Pretendard-Bold.otf")
const INK := Color("18354f")
const NAVY := Color("193e65")
const TEAL := Color("087e80")
const CREAM := Color("fff6e4")
const MUTED := Color("685c50")
const RED := Color("aa3828")
var state: Game
var region: String = "market"
var mode: String = "supplier"
var _info: Dictionary = {}
var _key: String = ""
var _choice: String = ""
var _detail: String = ""
var _retiring: bool = false
var _hide_receipt: bool = false
var _margin: MarginContainer
var _grid: GridContainer
var _column: VBoxContainer
var _region_buttons: Dictionary = {}
var _mode_buttons: Dictionary = {}
var _picture: TextureRect
var _region_title: Label
var _wallet: Label
var _status: Label
var _notice: Button
var _scroll: ScrollContainer
var _body: VBoxContainer
var _action: Button
var _secondary: Button
var _cost: Label
var _progress: ProgressBar
var _regions_row: HBoxContainer
var _modes_row: HBoxContainer
var _return_scroll: int = 0
var _render_serial: int = 0
var _reward_art: TextureRect
var _celebrations: int = 0
var _goal_button: Button


## Select a read-only source page. The controller retains every paid action.
func open_samples(id: String) -> void:
	region=id
	mode="sample"
	_detail=""
	_hide_receipt=true
	_key=""


func _ready() -> void:
	name = "ExplorationWorkbench"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()
	resized.connect(_layout)
	_layout()


## Configure a review only; never start/pay a trip. A same-day receipt must not
## obscure the new source's live rank/day/stock/fee requirements.
func open_source(id: String, purpose: String) -> void:
	if id not in Regions.region_ids() or purpose not in ["supplier","sample"]:
		push_error("재료 출처의 지역이나 탐색 방식이 올바르지 않아요.")
		return
	region=id
	mode=purpose
	_choice=""
	_detail=""
	_retiring=false
	_hide_receipt=true
	if state!=null: _render()


func open_goals(id: String="") -> void:
	if id!="": _info["direction_target"]=id
	_detail="goals"
	if state!=null: _render()


func _label(text: String, font_size: int = 16, color: Color = INK) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", BOLD if font_size >= 18 else BODY)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color",color)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return label


func _button(title: String, node_name: String, skin: String = "summary") -> Button:
	var button := Button.new()
	button.name = node_name
	button.text = title
	button.custom_minimum_size = Vector2(48,48)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.mouse_filter = Control.MOUSE_FILTER_PASS
	button.add_theme_font_override("font",BOLD)
	button.add_theme_font_size_override("font_size",16)
	button.add_theme_stylebox_override("normal",Mock.style(skin))
	button.add_theme_stylebox_override("hover",Mock.style(skin))
	button.add_theme_stylebox_override("pressed",Mock.style("teal"))
	var disabled := StyleBoxFlat.new()
	disabled.bg_color=Color("e0d9c9")
	disabled.border_color=MUTED
	disabled.set_border_width_all(2)
	disabled.content_margin_left=10
	disabled.content_margin_right=10
	button.add_theme_stylebox_override("disabled",disabled)
	button.add_theme_color_override("font_color",Color.WHITE if skin=="teal" else INK)
	button.add_theme_color_override("font_hover_color",Color.WHITE if skin=="teal" else INK)
	button.add_theme_color_override("font_pressed_color",Color.WHITE)
	return button


func _panel() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_PASS
	panel.add_theme_stylebox_override("panel",Mock.style("panel",Vector2(14,12)))
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return panel


func _box(parent: Node, gap: int = 8) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_PASS
	box.add_theme_constant_override("separation",gap)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(box)
	return box


func _image(texture: Texture2D, minimum: Vector2) -> TextureRect:
	var picture := TextureRect.new()
	picture.texture = texture
	picture.material = Art.image_material(texture)
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	picture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	picture.custom_minimum_size = minimum
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return picture


func _food(id: String) -> Texture2D:
	if id=="noodle_buckwheat" or id.begins_with("topping_"):
		return Art.food(id)
	if id.begins_with("broth_"):
		return Mock.texture("pot")
	return Pixel.scaled_tex(Pixel.icon_image(id),3)


func _build() -> void:
	var background := ColorRect.new()
	background.color = NAVY.darkened(0.5)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	_margin = MarginContainer.new()
	_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_margin)
	_column = _box(_margin)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation",8)
	_column.add_child(header)
	var back := _button("", "ExploreBack", "blue")
	back.icon = Art.icon("arrow_back")
	back.expand_icon = true
	back.add_theme_constant_override("icon_max_width",24)
	back.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	back.tooltip_text = "가게로 돌아가기 · 탐색 진행은 유지돼요."
	back.pressed.connect(func(): action_requested.emit("close",{}))
	header.add_child(back)
	header.add_child(_label("재료 탐색",24,CREAM))
	_wallet = _label("",14,CREAM)
	_wallet.size_flags_horizontal = Control.SIZE_SHRINK_END
	_wallet.autowrap_mode = TextServer.AUTOWRAP_OFF
	header.add_child(_wallet)
	_status = _label("",14,Color("ffd05a"))
	_column.add_child(_status)
	_notice = _button("", "ExploreNotice")
	_notice.icon = Art.icon("info")
	_notice.expand_icon = true
	_notice.add_theme_constant_override("icon_max_width",22)
	_notice.add_theme_color_override("icon_normal_color",INK)
	_notice.add_theme_color_override("icon_hover_color",INK)
	_notice.pressed.connect(func(): _detail="notice"; _render())
	_column.add_child(_notice)
	_grid = GridContainer.new()
	_grid.add_theme_constant_override("h_separation",12)
	_grid.add_theme_constant_override("v_separation",8)
	_grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_column.add_child(_grid)
	var location := _panel()
	_grid.add_child(location)
	var locations := _box(location,6)
	var row := HBoxContainer.new()
	_regions_row=row
	row.add_theme_constant_override("separation",5)
	locations.add_child(row)
	for pair in [["market","장터"],["harbor","항구"],["mountain","산골"]]:
		var button := _button(str(pair[1]),"ExploreRegion_"+str(pair[0]))
		button.pressed.connect(_choose_region.bind(str(pair[0])))
		_region_buttons[pair[0]] = button
		row.add_child(button)
	_picture = _image(null,Vector2(0,104))
	_picture.name = "ExploreLandscape"
	locations.add_child(_picture)
	_region_title = _label("",21)
	var goal_row:=HBoxContainer.new()
	goal_row.add_theme_constant_override("separation",8)
	locations.add_child(goal_row)
	goal_row.add_child(_region_title)
	_goal_button=_button("목표","ExploreGoals")
	_goal_button.size_flags_horizontal=Control.SIZE_SHRINK_END
	_goal_button.add_theme_font_size_override("font_size",14)
	_goal_button.custom_minimum_size.x=76
	_goal_button.icon=Art.icon("ramen_dining")
	_goal_button.add_theme_constant_override("icon_max_width",20)
	_goal_button.pressed.connect(func(): open_goals())
	goal_row.add_child(_goal_button)
	var modes := HBoxContainer.new()
	_modes_row=modes
	modes.add_theme_constant_override("separation",5)
	locations.add_child(modes)
	for pair in [["supplier","공급처 발견"],["sample","연구 재료 채집"]]:
		var button := _button(str(pair[1]),"ExploreMode_"+str(pair[0]))
		button.pressed.connect(_choose_mode.bind(str(pair[0])))
		_mode_buttons[pair[0]]=button
		modes.add_child(button)
	var content := _panel()
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_grid.add_child(content)
	_scroll = ScrollContainer.new()
	_scroll.name = "ExploreScroll"
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.scroll_deadzone = 10
	content.add_child(_scroll)
	_body = _box(_scroll,10)
	var footer := _panel()
	_column.add_child(footer)
	var bottom := _box(footer,6)
	_cost = _label("",14,MUTED)
	_cost.name = "ExploreCost"
	bottom.add_child(_cost)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation",8)
	bottom.add_child(actions)
	_secondary = _button("개발","ExploreSecondary")
	_secondary.custom_minimum_size.x = 88
	_secondary.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_secondary.pressed.connect(_secondary_action)
	actions.add_child(_secondary)
	_action = _button("", "ExplorePrimary", "gold")
	_action.custom_minimum_size.y = 54
	_action.add_theme_font_size_override("font_size",18)
	_action.pressed.connect(_primary_action)
	actions.add_child(_action)


func present(new_state: Game, information: Dictionary) -> void:
	state = new_state
	_info = information
	_wallet.text = Editor.won(state.wallet)
	var key: String = JSON.stringify([state.to_dict(),_info["busy"],_info["travel"],_info["warning"],_info["notice"],_info.get("direction_target","")])
	if key != _key:
		_key = key
		var trip: Dictionary = state.expedition()
		if not trip.is_empty():
			region = str(trip["region"])
			mode = "sample" if not state.foraging_state()["active"].is_empty() or not state.harbor_foraging_state()["active"].is_empty() or not state.mountain_foraging_state()["active"].is_empty() else "supplier"
			_choice = ""
			_detail = ""
			_hide_receipt = false
		_render()
	if bool(_info["travel"]):
		_picture.texture = Pixel.scaled_tex(Pixel.exploration_image(region,float(_info["progress"]),true),4)
		if is_instance_valid(_progress):
			_progress.value = float(_info["progress"])*100


func _choose_region(id: String) -> void:
	region=id
	_choice=""
	_detail=""
	_retiring=false
	_hide_receipt=false
	_render()


func _choose_mode(value: String) -> void:
	mode=value
	_detail=""
	_retiring=false
	_hide_receipt=false
	_render()


func _review() -> Dictionary:
	return state.exploration_region(region) if mode=="supplier" else (state.foraging_review() if region=="market" else (state.harbor_foraging_review() if region=="harbor" else state.mountain_foraging_review()))


func _ids() -> Array:
	return Regions.find_region(region)["ingredients"] if mode=="supplier" else (Market.IDS if region=="market" else (Harbor.IDS if region=="harbor" else Mountain.IDS))


func _receipt() -> Dictionary:
	var history: Array = state.exploration_history() if mode=="supplier" else (state.foraging_state()["history"] if region=="market" else (state.harbor_foraging_state()["history"] if region=="harbor" else state.mountain_foraging_state()["history"]))
	if history.is_empty():
		return {}
	var last: Dictionary = history.back()
	if int(last["day"]) != state.day or str(last["outcome"]) != "finished" or (mode=="supplier" and str(last["region"])!=region):
		return {}
	return last


func _render() -> void:
	if state==null:
		return
	_render_serial+=1
	for child in _body.get_children():
		_body.remove_child(child)
		child.queue_free()
	_progress=null
	_reward_art=null
	var trip: Dictionary = state.expedition()
	var active: bool = not trip.is_empty()
	var goal: Dictionary=GoalDirections.find(str(_info.get("direction_target","")))
	_goal_button.text="목표" if goal.is_empty() else str(goal["title"])
	_goal_button.tooltip_text="개발 목표와 재료 준비 보기"
	_goal_button.disabled=active or bool(_info["busy"]) or bool(_info["travel"])
	var received: bool=not active and not _hide_receipt and not _receipt().is_empty()
	_status.text = "%d일차 · 랭크%d · %s" % [state.day,state.rank(),"오늘 출발 사용함" if state.departed_today() else "오늘 한 번 출발 가능"]
	var warning: String = str(_info["warning"])
	var notice: String = warning if warning!="" else str(_info["notice"])
	_notice.visible = notice!=""
	_notice.text = "저장 안내 · 눌러서 확인" if warning!="" else "탐색 안내 · 눌러서 확인"
	_notice.tooltip_text = notice
	_regions_row.visible=not active and not received and _detail==""
	_modes_row.visible=_regions_row.visible
	for id in _region_buttons:
		var button: Button = _region_buttons[id]
		button.disabled=active
		_select_skin(button,region==id)
	for id in _mode_buttons:
		var button: Button = _mode_buttons[id]
		button.disabled=active
		_select_skin(button,mode==id)
	_picture.texture=Pixel.scaled_tex(Pixel.exploration_image(region),4)
	_region_title.text=str(Regions.find_region(region)["name"])
	if active:
		_region_title.text+=" · "+("연구 채집" if mode=="sample" else "공급처 탐색")
	_action.disabled=bool(_info["busy"])
	_secondary.disabled=bool(_info["busy"])
	_secondary.text="개발"
	_secondary.visible=true
	_cost.text="모든 지역을 합쳐 하루 한 번 · 다음 기회는 영업 후"
	if _detail!="":
		_render_detail()
	elif _retiring and active:
		_body.add_child(_label("탐색을 포기할까요?",22,RED))
		_body.add_child(_label("이미 낸 비용과 오늘 출발 기회는 돌아오지 않아요. 재료도 받지 못해요.",18))
		_secondary.text="계속 탐색"
		_action.text="포기 확정"
	elif active:
		_render_active(trip)
	elif not _hide_receipt and not _receipt().is_empty():
		var receipt: Dictionary = _receipt()
		_render_reward(receipt)
		if not goal.is_empty():
			var goal_review:=_button("목표 준비 확인","ExploreGoalReceipt")
			goal_review.pressed.connect(func(): open_goals())
			_body.add_child(goal_review)
		_cost.text="지불 합계 "+Editor.won(int(receipt["fee"])+int(receipt["extra"]))+" · 추가 결제 없음"
		_secondary.text="지역 보기"
		_action.text="이 재료로 개발"
	else:
		_render_preview()
	_scroll.set_deferred("scroll_vertical",0)
	_layout()


func _select_skin(button: Button, selected: bool) -> void:
	# Hover must preserve the chosen category, rather than masking its normal
	# teal frame with an unselected paper frame while the pointer rests on it.
	for property in ["normal","hover"]:
		button.add_theme_stylebox_override(property,Mock.style("teal" if selected else "summary"))
	for property in ["font_color","font_hover_color"]:
		button.add_theme_color_override(property,Color.WHITE if selected else INK)


func _render_reward(receipt: Dictionary) -> void:
	var id: String=str(receipt["ingredient"])
	var item: Dictionary=Catalog.find(id)
	_body.add_child(_label("연구 재료 획득!" if mode=="sample" else ("새 공급처 발견!" if bool(receipt["new"]) else "알고 있는 공급처예요"),24,TEAL))
	_reward_art=_image(_food(id),Vector2(112,112))
	_reward_art.name="ExploreRewardArt"
	_body.add_child(_reward_art)
	var title:=_label(str(item["name"])+(" ×%d" % int(receipt["amount"]) if mode=="sample" else ""),22)
	title.name="ExploreRewardName"
	_body.add_child(title)
	var stock:=_label("지금 보관 %d/20개 · 시제품 완성 때 사용" % state.sample_stock(id) if mode=="sample" else "개발에서 계속 사용할 수 있는 공급처예요.",16,TEAL)
	stock.name="ExploreRewardStock"
	_body.add_child(stock)
	_body.add_child(_label(Catalog.axes_text(item),18))
	_body.add_child(_label(str(item["desc"]),16))
	_body.add_child(_label("개발에서 넣기 전후를 비교해 보세요. 직접 반영하기 전에는 초안이 바뀌지 않아요.",15,MUTED))


func celebrate_receipt(id: String) -> Vector2:
	# The controller calls this only after a successful once-only claim. Merely
	# drawing/restoring a receipt must not celebrate or grant it again.
	await get_tree().process_frame
	if not is_visible_in_tree() or not is_instance_valid(_reward_art) or str(_receipt().get("ingredient",""))!=id:
		return Vector2(-1,-1)
	_celebrations+=1
	_reward_art.pivot_offset=_reward_art.size*0.5
	_reward_art.scale=Vector2.ONE*0.65
	var tween:=_reward_art.create_tween()
	tween.tween_property(_reward_art,"scale",Vector2.ONE,0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	return _reward_art.get_global_rect().get_center()


func celebration_count() -> int:
	return _celebrations


func _material(id: String, caption: String) -> void:
	var button := _button("","ExploreMaterial_"+id)
	button.custom_minimum_size.y=84
	var margin := MarginContainer.new()
	margin.mouse_filter=Control.MOUSE_FILTER_IGNORE
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge in ["left","right","top","bottom"]:
		margin.add_theme_constant_override("margin_"+edge,12)
	button.add_child(margin)
	var row := HBoxContainer.new()
	row.mouse_filter=Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation",10)
	margin.add_child(row)
	row.add_child(_image(_food(id),Vector2(54,54)))
	var text := _box(row,4)
	text.mouse_filter=Control.MOUSE_FILTER_IGNORE
	text.add_child(_label(str(Catalog.find(id)["name"]),18))
	text.add_child(_label(caption,14,TEAL))
	var info := _image(Art.icon("info"),Vector2(24,24))
	info.self_modulate=MUTED
	row.add_child(info)
	button.tooltip_text=str(Catalog.find(id)["name"])+" 상세 보기"
	button.pressed.connect(func():
		_return_scroll=_scroll.scroll_vertical
		_detail=id
		_render())
	_body.add_child(button)


func _render_preview() -> void:
	var review: Dictionary = _review()
	_body.add_child(_label("연구 재료를 모아요" if mode=="sample" else "새 공급처를 찾아요",21))
	_body.add_child(_label("시제품 완성 때 넣은 분량만큼 소모해요. 판매용 재료는 별도예요." if mode=="sample" else "한 번 발견하면 개발에서 계속 쓸 수 있어요. 두 번의 만남에서 선택해요.",15,MUTED))
	for id in _ids():
		_material(str(id),"보관 %d/20개" % state.sample_stock(str(id)) if mode=="sample" else ("발견 완료" if state.ingredient_unlocked(str(id)) else "아직 발견하지 못했어요"))
	if str(review["reason"])!="":
		var reason := _label(str(review["reason"]),15,RED)
		reason.name="ExploreReason"
		_body.add_child(reason)
	if mode=="sample":
		_body.add_child(_label("2개 / 추가 0원 · 3개 / 추가 300원" if region=="market" else ("1개 / 추가 0원 · 3개 / 추가 600원" if region=="harbor" else "1개 / 추가 0원 · 3개 / 추가 800원"),15,TEAL))
	_action.text="출발 · "+Editor.won(int(review["fee"]))
	_action.disabled=_action.disabled or not bool(review["can_start"])
	_cost.text="출발비 "+Editor.won(int(review["fee"]))+" · 선택 비용은 별도 표시"


func _render_active(trip: Dictionary) -> void:
	_cost.text="지불 완료 · 출발 %s + 선택 %s" % [Editor.won(int(trip["fee"])),Editor.won(int(trip["extra"]))]
	_secondary.text="탐색 포기"
	_secondary.visible=bool(trip["can_retire"])
	if bool(_info["travel"]):
		_body.add_child(_label("재료를 만나러 가는 중",22))
		_body.add_child(_label("도착하면 다음 선택이 열려요. 재료는 마지막에 직접 받아요.",16,MUTED))
		_progress=ProgressBar.new()
		_progress.name="ExploreTravelProgress"
		_progress.custom_minimum_size.y=22
		# Progress is a structural widget, using the accepted paper/gold tokens
		# rather than an unrelated platform-gray loading treatment.
		var track:=StyleBoxFlat.new()
		track.bg_color=CREAM.darkened(0.1)
		track.border_color=NAVY
		track.set_border_width_all(2)
		var fill:=StyleBoxFlat.new()
		fill.bg_color=Color("ffd05a")
		_progress.add_theme_stylebox_override("background",track)
		_progress.add_theme_stylebox_override("fill",fill)
		_progress.add_theme_color_override("font_color",INK)
		_progress.add_theme_color_override("font_outline_color",Color.TRANSPARENT)
		_progress.add_theme_font_override("font",BODY)
		_progress.add_theme_font_size_override("font_size",14)
		_body.add_child(_progress)
		_action.text="이동 중…"
		_action.disabled=true
		return
	if str(trip["stage"])==Regions.STAGE_RESULT:
		var reward: Dictionary = {"ingredient":Regions.ingredient_for(region,trip["path"])}
		if mode=="sample":
			reward=Market.outcome(trip["path"]) if region=="market" else (Harbor.outcome(trip["path"]) if region=="harbor" else Mountain.outcome(trip["path"]))
		_body.add_child(_label("발견! 직접 받아 주세요",22,TEAL))
		_material(str(reward["ingredient"]),"연구 재료 ×%d개 · 아직 보관함에 들어오지 않았어요" % int(reward["amount"]) if mode=="sample" else "수령하면 공급처가 열려요")
		_body.add_child(_label(str(trip["result"]["message"]),17))
		_action.text="재료 받기 · %d개" % int(reward["amount"]) if mode=="sample" else "발견 확정하기"
		return
	var event: Dictionary = trip["event"]
	_body.add_child(_label("만남 %d/2 · %s" % [int(event["step"]),event["title"]],21))
	_body.add_child(_label(str(event["text"]),15,MUTED))
	for row in event["choices"]:
		var choice: Dictionary = row
		var button := _button(str(choice["label"])+"\n추가 "+Editor.won(int(choice["cost"])),"ExploreChoice_"+str(choice["id"]),"teal" if _choice==str(choice["id"]) else "summary")
		button.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		button.custom_minimum_size.y=78
		button.disabled=bool(_info["busy"]) or not bool(choice["affordable"])
		button.pressed.connect(func():
			var position: int=_scroll.scroll_vertical
			_choice=str(choice["id"])
			_render()
			_restore_body_scroll(position,_render_serial))
		_body.add_child(button)
		var description: String = str(choice["desc"])
		if choice.has("ingredient_name"):
			description+=" · "+str(choice["ingredient_name"])+(" / 이미 발견" if bool(choice["known"]) else " / 새 재료")
		if not bool(choice["affordable"]) and not bool(choice.get("capacity_blocked",false)):
			description+=" · 자금 부족"
		_body.add_child(_label(description,14,MUTED))
	_action.text="선택을 골라 주세요"
	for row in event["choices"]:
		if str(row["id"])==_choice:
			_action.text="진행 · 추가 "+Editor.won(int(row["cost"]))
	_action.disabled=_action.disabled or _choice==""


func _render_detail() -> void:
	_cost.text="상세 열람 · 결제나 재료 사용 없음"
	_action.disabled=false
	_secondary.disabled=false
	_secondary.text="뒤로"
	_action.text="목록으로 돌아가기"
	if _detail=="notice":
		_body.add_child(_label("저장 안내" if str(_info["warning"])!="" else "탐색 안내",22,RED))
		if str(_info["warning"])!="":
			_body.add_child(_label("현재 진행을 저장하지 못했어요. 다시 저장될 때까지 게임을 종료하지 마세요.",18))
		_body.add_child(_label(str(_info["warning"]) if str(_info["warning"])!="" else str(_info["notice"]),17,RED))
		return
	if _detail=="goals":
		_action.text="지역 보기"
		_secondary.visible=false
		var board:=GoalBoard.new()
		board.name="ExploreGoalBoard"
		_body.add_child(board)
		var id: String=str(_info.get("direction_target",""))
		board.present(state,id,bool(_info["busy"]) or state.exploration_active() or bool(_info["travel"]))
		if id!="": board.open_detail(id)
		board.target_selected.connect(func(chosen: String): action_requested.emit("goal_target",{"id":chosen}))
		board.source_requested.connect(func(chosen: String, ingredient: String): action_requested.emit("goal_source",{"id":chosen,"ingredient":ingredient}))
		board.develop_requested.connect(func(chosen: String, ingredient: String): action_requested.emit("goal_develop",{"id":chosen,"ingredient":ingredient}))
		return
	var item: Dictionary = Catalog.find(_detail)
	_body.add_child(_image(_food(_detail),Vector2(112,112)))
	_body.add_child(_label(str(item["name"]),22))
	_body.add_child(_label(str(item["desc"]),18))
	_body.add_child(_label(Catalog.axes_text(item),16,TEAL))
	_body.add_child(_label("한 분량 원가 %s · 준비 +%d초" % [Editor.won(int(item["cost"])),int(item["seconds"])],16))
	_body.add_child(_label("보관 %d/20개 · 시제품 완성 때 사용" % state.sample_stock(_detail) if Catalog.is_farmed(_detail) else "공급처를 발견하면 개발에서 계속 사용 가능",15,MUTED))


func _secondary_action() -> void:
	if _detail!="":
		_detail=""
		_render()
		_restore_body_scroll(_return_scroll,_render_serial)
		return
	elif _retiring:
		_retiring=false
	elif state.exploration_active():
		_retiring=true
	elif not _hide_receipt and not _receipt().is_empty():
		_hide_receipt=true
	else:
		action_requested.emit("lab",{})
		return
	_render()


func _primary_action() -> void:
	if _detail!="":
		_detail=""
		_render()
		_restore_body_scroll(_return_scroll,_render_serial)
	elif _retiring:
		_retiring=false
		action_requested.emit("retire",{})
	elif state.exploration_active():
		if str(state.expedition()["stage"])==Regions.STAGE_RESULT:
			action_requested.emit("collect",{})
		elif _choice!="":
			action_requested.emit("choice",{"id":_choice})
	elif not _hide_receipt and not _receipt().is_empty():
		action_requested.emit("material",{"id":str(_receipt()["ingredient"])})
	else:
		action_requested.emit("depart",{"region":region,"mode":mode})


func _restore_body_scroll(position: int, serial: int) -> void:
	# Expanding the region controls after details changes the real scroll page.
	# Restore after container reflow; an earlier setter is clamped to zero using
	# the detail page's height. Never apply a late restore to a newer screen.
	var tree: SceneTree=get_tree()
	await tree.process_frame
	await tree.process_frame
	if is_inside_tree() and serial==_render_serial:
		_scroll.scroll_vertical=position


func _layout() -> void:
	if _margin==null:
		return
	# Match the editor's physical-safe-area conversion; no OS chrome is painted.
	var safe := Vector4.ZERO
	if OS.get_name() in ["iOS","Android"]:
		var area: Rect2i = DisplayServer.get_display_safe_area()
		var window: Vector2i = DisplayServer.window_get_size()
		if window.x>0 and window.y>0:
			var factor: Vector2 = size/Vector2(window)
			safe=Vector4(maxi(0,area.position.x)*factor.x,maxi(0,area.position.y)*factor.y,maxi(0,window.x-area.end.x)*factor.x,maxi(0,window.y-area.end.y)*factor.y)
	var horizontal: int=maxi(12,int((size.x-1040)*0.5))
	for pair in [["left",safe.x],["top",safe.y],["right",safe.z],["bottom",safe.w]]:
		_margin.add_theme_constant_override("margin_"+str(pair[0]),(horizontal if pair[0] in ["left","right"] else 12)+int(pair[1]))
	_grid.columns=2 if size.x>=720 else 1
	var focused: bool=state!=null and (state.exploration_active() or _detail!="" or (not _hide_receipt and not _receipt().is_empty()))
	_picture.custom_minimum_size.y=(120 if focused else 160) if size.x>=720 else (64 if focused else (72 if size.y<780 else 104))
