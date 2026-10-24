extends "res://tests/bowl_editor_qa.gd"
## Exercise the visible detail journey with pointer input and isolated saves.
## Layout-only/compact runs are explicitly separate from actual rendering.
const FlowClues = preload("res://scripts/domain/recipe_experiments.gd")
const FlowProcesses = preload("res://scripts/domain/recipe_process.gd")


func _run() -> void:
	var profiles: Array = [{"tag":"portrait","size":Vector2i(390,844)}, {"tag":"desktop","size":Vector2i(1280,800)}]
	if OS.get_cmdline_user_args().has("--flow-compact"):
		profiles = [{"tag":"compact","size":Vector2i(390,750)}]
	for profile in profiles:
		await _flow(str(profile["tag"]),profile["size"])
	print("INGREDIENT FLOW mode=%s checks=%d failures=%d" % ["layout-only" if _layout_only else "capture",_checks,_failures.size()])
	for message in _failures:
		printerr("FAIL: "+message)
	quit(0 if _failures.is_empty() else 1)


func _sheet(editor: Control, holder: SubViewport, tag: String, has_footer: bool = true) -> void:
	var modal: Control = editor.get("_modal") as Control
	var column: Control = modal.find_child("DetailsColumn",true,false) as Control
	_check(column.size.x <= 680,tag+": detail has a readable maximum line width")
	var viewport := Rect2(Vector2.ZERO,Vector2(holder.size))
	for button in modal.find_children("*","Button",true,false):
		if (button as Button).is_visible_in_tree():
			_check((button as Button).size.x >= 44 and (button as Button).size.y >= 44,tag+": sheet minimum44 hit")
	var back: Control = modal.find_child("EditorDetailsBack",true,false) as Control
	_check(viewport.encloses(back.get_global_rect()),tag+": back reachable inside viewport")
	if has_footer:
		var apply: Button = modal.find_child("EditorDetailApply",true,false) as Button
		var scroll: ScrollContainer = modal.find_child("DetailsScroll",true,false) as ScrollContainer
		_check(viewport.encloses(apply.get_global_rect()),tag+": fixed primary action inside viewport")
		_check(scroll.get_global_rect().end.y <= apply.get_global_rect().position.y,tag+": content scroll cannot cover primary action")


func _resize_sheet(editor: Control, holder: SubViewport, tag: String) -> void:
	# A sheet opened on desktop must also survive a live narrow-window resize.
	var previous: Vector2i = holder.size
	holder.size = Vector2i(390,640)
	await _settle()
	_sheet(editor,holder,tag+" live resize")
	var modal: Control = editor.get("_modal") as Control
	var apply: Control = modal.find_child("EditorDetailApply",true,false) as Control
	if str(modal.get_meta("view_kind",""))=="group" and Rect2(Vector2.ZERO,Vector2(holder.size)).encloses(apply.get_global_rect()):
		var scroll: ScrollContainer = modal.find_child("DetailsScroll",true,false) as ScrollContainer
		var bar: VScrollBar = scroll.get_v_scroll_bar()
		var available: float = maxf(0,bar.max_value-bar.page)
		_check(available>0,tag+": narrow selector has real scrollable content")
		scroll.scroll_vertical = int(minf(40,available))
		await _settle()
		var saved: int = scroll.scroll_vertical
		var tab: String = str(modal.get_meta("tab"))
		await _tap(holder,editor,"EditorGroupTab_oil")
		await _tap(holder,editor,"EditorGroupTab_"+tab)
		var returned: ScrollContainer = (editor.get("_modal") as Control).find_child("DetailsScroll",true,false) as ScrollContainer
		_check(returned.scroll_vertical==saved and saved>0,tag+": each tab restores its actual nonzero scroll")
	holder.size = previous
	await _settle()


func _flow(tag: String, vp: Vector2i) -> void:
	var holder := SubViewport.new()
	holder.size = vp
	holder.handle_input_locally = true
	holder.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(holder)
	var dir: String = _data_root.path_join(tag+"_ingredient_flow")
	_check(DirAccess.make_dir_recursive_absolute(dir)==OK,tag+": isolated flow data")
	var app: Node = await _spawn(holder,dir)
	app.call("_on_dev_pressed")
	await _settle()
	app.set_process(false)
	var editor: Control = app.get("_bowl_editor") as Control
	var state: Object = app.get("state")
	var wallet: int = int(state.get("wallet"))
	var records: int = int(state.call("record_count"))
	var before: String = JSON.stringify(state.call("to_dict"))
	await _tap(holder,editor,"Category_3")
	await _tap(holder,editor,"EditorInfo_topping_scallop")
	_sheet(editor,holder,tag+" locked")
	_check((editor.find_child("EditorDetailApply",true,false) as Button).disabled,tag+": locked detail cannot apply ingredient")
	await _shot(holder,tag+"_flow_01_locked.png")
	await _tap(holder,editor,"EditorDetailsBack")
	_check(str(editor.get("category"))=="해산물",tag+": locked detail returns to category")
	_check(JSON.stringify(state.call("to_dict"))==before,tag+": browsing locked detail is read-only")
	await _tap(holder,editor,"Category_0")
	if tag != "desktop":
		await _tap(holder,editor,"EditorSlot_1")
		_check((editor.get("_heading_hint") as Label).text.contains("추가"),tag+": empty selected slot describes addition, not replacement")
	var list: ScrollContainer = editor.get("_scroll") as ScrollContainer
	list.ensure_control_visible(editor.find_child("EditorInfo_topping_egg",true,false) as Control)
	await _settle()
	var old_scroll: int = list.scroll_vertical
	await _tap(holder,editor,"EditorInfo_topping_egg")
	_sheet(editor,holder,tag+" ingredient")
	if tag != "desktop":
		_check((editor.find_child("EditorDetailApply",true,false) as Button).text.contains("추가"),tag+": detail action names selected empty-slot addition")
	await _resize_sheet(editor,holder,tag+" ingredient")
	await _shot(holder,tag+"_flow_02_ingredient.png")
	var apply: Button = editor.find_child("EditorDetailApply",true,false) as Button
	await _drag_list(holder,apply.get_global_rect().get_center())
	_check(JSON.stringify(state.call("to_dict"))==before,tag+": drag from detail action does not add food")
	await _tap(holder,editor,"EditorDetailsBack")
	_check(list.scroll_vertical==old_scroll,tag+": detail cancel preserves ingredient scroll")
	await _tap(holder,editor,"EditorInfo_topping_egg")
	await _tap(holder,editor,"EditorDetailApply")
	_check(editor.get("_modal")==null,tag+": accepted detail addition returns to bowl")
	_check(IngredientCatalog.toppings_of(state.get("draft_config"))==["topping_chashu","topping_egg"],tag+": detail adds exactly one portion")
	_check((editor.get("_heading_hint") as Label).text.contains("교체"),tag+": full dock explains replacement")
	await _tap(holder,editor,"Category_3")
	await _tap(holder,editor,"EditorInfo_topping_nori")
	before = JSON.stringify(state.call("to_dict"))
	await _tap(holder,editor,"EditorDetailApply")
	_sheet(editor,holder,tag+" replacement",false)
	_check(JSON.stringify(state.call("to_dict"))==before,tag+": opening replacement choice changes no state")
	_check(int(editor.get("_selected"))==-1,tag+": browsing replacement does not secretly select a slot")
	await _shot(holder,tag+"_flow_03_replacement.png")
	await _tap(holder,editor,"EditorDetailsBack")
	_check(JSON.stringify(state.call("to_dict"))==before,tag+": canceling replacement is read-only")
	await _tap(holder,editor,"EditorDetailApply")
	await _tap(holder,editor,"EditorReplace_1")
	_check(IngredientCatalog.toppings_of(state.get("draft_config"))==["topping_chashu","topping_nori"],tag+": capacity flow replaces only chosen portion")
	_check(str(editor.get("category"))=="해산물",tag+": replacement returns to same category")
	await _shot(holder,tag+"_flow_04_replaced.png")
	await _tap(holder,editor,"EditorSlot_0")
	await _tap(holder,editor,"Category_1")
	await _tap(holder,editor,"EditorInfo_topping_egg")
	_check((editor.find_child("EditorDetailApply",true,false) as Button).text.contains("선택한 칸"),tag+": preselected slot is explicit in detail action")
	await _tap(holder,editor,"EditorDetailApply")
	_check(IngredientCatalog.toppings_of(state.get("draft_config"))==["topping_egg","topping_nori"],tag+": preselected detail replaces exactly that slot")
	await _tap(holder,editor,"EditorBroth")
	_sheet(editor,holder,tag+" broth")
	await _resize_sheet(editor,holder,tag+" broth")
	await _shot(holder,tag+"_flow_05_broth.png")
	await _tap(holder,editor,"EditorGroupTab_tare")
	_check(editor.find_child("EditorAdd_broth_chicken",true,false)==null,tag+": tare tab does not mix unrelated broth rows")
	await _tap(holder,editor,"EditorGroupTab_oil")
	_sheet(editor,holder,tag+" oil")
	await _shot(holder,tag+"_flow_06_oil.png")
	await _tap(holder,editor,"EditorInfo_oil_chili")
	await _tap(holder,editor,"EditorDetailsBack")
	_check((editor.get("_modal") as Control).get_meta("tab")=="oil",tag+": nested detail returns to correct group tab")
	await _tap(holder,editor,"EditorInfo_oil_chili")
	await _tap(holder,editor,"EditorDetailApply")
	_check(str((state.get("draft_config") as Dictionary)["oil"])=="oil_chili",tag+": detail applies actual oil through controller")
	_check((editor.get("_modal") as Control).get_meta("tab")=="oil",tag+": oil selection returns to oil tab")
	_check((editor.find_child("EditorAdd_oil_chili",true,false) as Button).button_pressed,tag+": accepted oil marked selected")
	await _tap(holder,editor,"EditorGroupTab_method")
	await _shot(holder,tag+"_flow_07_method.png")
	await _tap(holder,editor,"EditorDetailsBack")
	await _tap(holder,editor,"EditorBroth")
	_check((editor.get("_modal") as Control).get_meta("tab")=="method",tag+": reopened group retains active tab")
	await _tap(holder,editor,"EditorDetailApply")
	await _tap(holder,editor,"EditorNoodle")
	await _tap(holder,editor,"EditorGroupTab_cook")
	await _tap(holder,editor,"EditorAdd_cook_normal")
	_check(str((state.get("draft_config") as Dictionary)["cook"])=="cook_normal",tag+": firmness tab uses guarded selection")
	_sheet(editor,holder,tag+" firmness")
	await _shot(holder,tag+"_flow_08_firmness.png")
	await _tap(holder,editor,"EditorGroupTab_method")
	_check((editor.find_child("EditorProcess_noodle_rested",true,false) as Button).disabled,tag+": higher-rank dough method stays locked")
	await _tap(holder,editor,"EditorProcess_noodle_moist")
	_check(str((state.get("draft_config") as Dictionary)["process"]["noodle"])=="moist",tag+": dough tab applies actual method")
	await _tap(holder,editor,"EditorDetailsBack")
	_check(int(state.get("wallet"))==wallet and int(state.call("record_count"))==records,tag+": all browsing/recipe choices avoid automatic trial payment or record")
	# A real tasting unlocks experiment links. Infer the expected category from
	# the returned recipe difference, independently of the selector's last tab.
	await _tap(holder,editor,"EditorTaste")
	app.call("advance_work",100.0)
	app.call("_sync_bowl_editor")
	await _settle()
	await _tap(holder,editor,"EditorClues")
	var record: Dictionary = state.call("get_record",state.get("last_feedback_record_id"))
	var available: Array[String] = []
	for slot in IngredientCatalog.SLOTS:
		for item in IngredientCatalog.all_items(slot):
			if state.call("ingredient_unlocked",str(item["id"])):
				available.append(str(item["id"]))
	var clues: Array = FlowClues.clues(record["config"],available,state.call("rank"))["clues"]
	_check(not clues.is_empty(),tag+": actual completed recipe has experiment clues")
	if not clues.is_empty():
		var clue: Dictionary = {}
		for candidate in clues:
			if str(candidate["direction"]) == "chew":
				clue = candidate
		_check(not clue.is_empty(),tag+": actual thin-noodle recipe offers a chew experiment")
		if clue.is_empty():
			app.queue_free()
			holder.queue_free()
			await _settle()
			return
		var go: Control = editor.find_child("EditorClueGo_"+str(clue["direction"]),true,false) as Control
		var detail_scroll: ScrollContainer = editor.find_child("DetailsScroll",true,false) as ScrollContainer
		detail_scroll.ensure_control_visible(go)
		await _settle()
		var previous_tab: String = str((editor.get("_group_tab") as Dictionary).get("noodle",""))
		_check(previous_tab=="method",tag+": directed-link regression starts on a different remembered noodle tab")
		await _tap(holder,editor,go.name)
		var slot: String = str(clue["slot"])
		if slot != "topping":
			var expected: String = slot
			if slot in FlowProcesses.SLOTS and FlowProcesses.selected(record["config"].get("process",{}),slot) != FlowProcesses.selected(clue["config"].get("process",{}),slot):
				expected = "method"
			_check(str((editor.get("_modal") as Control).get_meta("tab"))==expected,tag+": experiment link opens its actual ingredient/method tab")
			await _shot(holder,tag+"_flow_09_clue_target.png")
		else:
			_check(editor.get("_modal")==null,tag+": topping experiment returns to actual bowl picker")
	app.queue_free()
	holder.queue_free()
	await _settle()
