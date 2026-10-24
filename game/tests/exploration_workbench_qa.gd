extends "res://tests/bowl_editor_qa.gd"
## Real pointer journeys, using only disposable saves and public-transaction
## supplier fixtures. Advancing travel changes animation time, never rewards.
const MarketFixture = preload("res://tests/market_foraging_tests.gd")
const HarborFixture = preload("res://tests/harbor_foraging_tests.gd")


func _run() -> void:
	var profiles: Array = [{"tag":"portrait","size":Vector2i(390,844)},{"tag":"desktop","size":Vector2i(1280,800)}]
	if OS.get_cmdline_user_args().has("--exploration-compact"):
		profiles=[{"tag":"compact","size":Vector2i(390,750)}]
	for profile in profiles:
		await _journey(str(profile["tag"]),profile["size"])
	print("EXPLORATION WORKBENCH mode=%s checks=%d failures=%d" % ["layout-only" if _layout_only else "capture",_checks,_failures.size()])
	for failure in _failures:
		printerr("FAIL: "+failure)
	quit(0 if _failures.is_empty() else 1)


func _show(app: Node) -> Control:
	app.call("_sync_bowl_editor")
	await _settle()
	return app.get("_exploration_view") as Control


func _arrive_at(app: Node) -> Control:
	_check(bool(app.call("advance_travel",10.0)["ok"]),"only travel animation advanced")
	return await _show(app)


func _state_json(app: Node) -> String:
	return JSON.stringify(app.get("state").to_dict())


func _layout_checks(view: Control, holder: SubViewport, tag: String) -> void:
	var bounds:=Rect2(Vector2.ZERO,Vector2(holder.size))
	for name in ["ExploreBack","ExplorePrimary","ExploreSecondary","ExploreRegion_market","ExploreRegion_harbor","ExploreRegion_mountain","ExploreMode_sample","ExploreMode_supplier"]:
		var button: Button = view.find_child(name,true,false) as Button
		if button.is_visible_in_tree():
			_check(bounds.encloses(button.get_global_rect()),tag+": fixed control inside viewport "+name)
			_check(button.size.x>=44 and button.size.y>=44,tag+": minimum44 target "+name)
	var scroll: Control=view.get("_scroll") as Control
	var action: Control=view.get("_action") as Control
	_check(scroll.size.y>=100,tag+": stage has meaningful scroll height")
	_check(scroll.get_global_rect().end.y<action.get_global_rect().position.y,tag+": stage cannot cover fixed action")
	_check(not (view.get("_wallet") as Label).text.contains("\n"),tag+": wallet stays on one line")


func _choose(holder: SubViewport, app: Node, id: String) -> Control:
	var view: Control=app.get("_exploration_view") as Control
	var before: String=_state_json(app)
	await _tap(holder,view,"ExploreChoice_"+id)
	_check(_state_json(app)==before,"highlighting a choice is read-only: "+id)
	_check(not (view.get("_action") as Button).disabled,"explicit confirmation available")
	if id=="take_three":
		_check((view.get("_action") as Button).text.contains("300원"),"selected extra cost stays on fixed confirmation")
		await _shot(holder,str(holder.get_meta("qa_tag"))+"_explore_07b_selected.png")
	await _tap(holder,view,"ExplorePrimary")
	return await _arrive_at(app)


func _journey(tag: String, vp: Vector2i) -> void:
	var holder:=SubViewport.new()
	holder.size=vp
	holder.handle_input_locally=true
	holder.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	holder.set_meta("qa_tag",tag)
	root.add_child(holder)
	var dir: String=_data_root.path_join(tag+"_exploration")
	_check(DirAccess.make_dir_recursive_absolute(dir)==OK,tag+": isolated data root")
	var app: Node=await _spawn(holder,dir)
	app.set_process(false)
	app.call("_open_overlay",6)
	var view: Control=await _show(app)
	var state: Object=app.get("state")
	_check(view.is_visible_in_tree() and not (app.get("_drawer_margin") as Control).visible,tag+": actual native exploration replaces legacy drawer")
	_layout_checks(view,holder,tag+" initial")
	await _shot(holder,tag+"_explore_01_supplier.png")
	var before: String=_state_json(app)
	await _tap(holder,view,"ExploreRegion_harbor")
	await _tap(holder,view,"ExploreMode_sample")
	_check((view.get("_action") as Button).disabled,tag+": rank/supplier locked sampling has no paid action")
	_check((view.find_child("ExploreReason",true,false) as Label).text.contains("등급 2"),tag+": actual harbor gate explained")
	await _shot(holder,tag+"_explore_02_locked.png")
	await _tap(holder,view,"ExploreRegion_market")
	await _tap(holder,view,"ExploreMode_supplier")
	_check(_state_json(app)==before,tag+": region and mode browsing does not change game state")
	var wallet: int=int(state.get("wallet"))
	await _tap(holder,view,"ExplorePrimary")
	_check(int(state.get("wallet"))==wallet-3000,tag+": supplier departure pays exact fee")
	view=await _arrive_at(app)
	view=await _choose(holder,app,"m_ask")
	view=await _choose(holder,app,"m_hear_recipe")
	_check(not state.call("is_discovered","tare_plum"),tag+": pending supplier not granted early")
	await _tap(holder,view,"ExplorePrimary")
	_check(state.call("is_discovered","tare_plum"),tag+": deliberate supplier claim unlocks once")
	before=_state_json(app)
	await _tap(holder,view,"ExplorePrimary")
	await _settle()
	_check(_state_json(app)==before,tag+": supplier handoff preserves entire draft and wallet")
	var editor: Control=app.get("_bowl_editor") as Control
	_check(editor.is_visible_in_tree() and (editor.get("_modal") as Control)!=null,tag+": supplier opens actual native ingredient details")
	await _tap(holder,editor,"EditorDetailsBack")
	await _tap(holder,editor,"EditorDetailsBack")
	# A public transaction fixture reaches the real two-supplier market gate.
	var market:=MarketFixture.new()
	market.check=_check
	var prepared: Object=market.ready()
	_check(state.call("load_from_dict",prepared.to_dict())=="",tag+": valid market fixture loads")
	_check(app.call("_persist"),tag+": isolated unlocked fixture saved")
	app.get("_exploration_message").text=""
	app.call("_refresh_all")
	app.call("_open_overlay",6)
	view=await _show(app)
	await _tap(holder,view,"ExploreMode_sample")
	_layout_checks(view,holder,tag+" sample preview")
	await _shot(holder,tag+"_explore_03_sample.png")
	before=_state_json(app)
	if tag=="compact":
		var material: Control=view.find_child("ExploreMaterial_oil_roasted_sesame",true,false) as Control
		await _drag_list(holder,material.get_global_rect().get_center())
		_check(_state_json(app)==before and str(view.get("_detail"))=="",tag+": dragging a material card scrolls without opening or paying")
	await _tap(holder,view,"ExploreMaterial_topping_citrus_peel")
	var return_scroll: int=int(view.get("_return_scroll"))
	await _shot(holder,tag+"_explore_04_detail.png")
	await _tap(holder,view,"ExplorePrimary")
	_check(_state_json(app)==before,tag+": material details/cancel read-only")
	_check((view.get("_scroll") as ScrollContainer).scroll_vertical==return_scroll,tag+": detail returns to actual previous scroll %d -> %d" % [return_scroll,(view.get("_scroll") as ScrollContainer).scroll_vertical])
	if tag=="compact":
		_check(return_scroll>0,tag+": detail restoration exercises real nonzero scroll")
	var button: Button=view.get("_action") as Button
	var effects: Object=app.get("_juice")
	var acknowledged: int=int(effects.call("acknowledgement_count"))
	await _drag_list(holder,button.get_global_rect().get_center())
	_check(_state_json(app)==before and int(effects.call("acknowledgement_count"))==acknowledged,tag+": drag off departure cancels transaction and success effect")
	wallet=int(state.get("wallet"))
	await _tap(holder,view,"ExplorePrimary")
	_check(int(state.get("wallet"))==wallet-1000,tag+": exact sample departure fee")
	_check((view.get("_action") as Button).disabled,tag+": travel prevents confirmation")
	before=_state_json(app)
	_check(bool(app.call("advance_travel",0.6)["ok"]),tag+": partial travel clock advances")
	view=await _show(app)
	_check(is_equal_approx((view.get("_progress") as ProgressBar).value,50.0) and _state_json(app)==before,tag+": visible halfway progress changes neither events nor money nor reward")
	await _shot(holder,tag+"_explore_05_travel.png")
	before=_state_json(app)
	app.call("_on_foraging_depart")
	_check(_state_json(app)==before,tag+": duplicate callback cannot spend twice")
	view=await _show(app)
	_check((view.get("_notice") as Button).visible,tag+": rejected action gives visible notice")
	await _tap(holder,view,"ExploreNotice")
	_check((view.get("_body") as Control).get_child(0).text=="탐색 안내",tag+": transaction rejection is not mislabeled as save failure")
	await _tap(holder,view,"ExplorePrimary")
	view=await _arrive_at(app)
	await _shot(holder,tag+"_explore_06_target.png")
	view=await _choose(holder,app,"citrus_cart")
	await _shot(holder,tag+"_explore_07_quantity.png")
	view=await _choose(holder,app,"take_three")
	_check(int(state.get("wallet"))==wallet-1300 and state.call("sample_stock","topping_citrus_peel")==0,tag+": selected extra paid exactly once; pending reward grants nothing")
	_layout_checks(view,holder,tag+" pending")
	await _shot(holder,tag+"_explore_08_pending.png")
	before=_state_json(app)
	app.queue_free()
	await _settle()
	app=await _spawn(holder,dir)
	app.set_process(false)
	state=app.get("state")
	app.call("_open_overlay",6)
	view=await _arrive_at(app)
	_check(_state_json(app)==before,tag+": pending state exactly resumes from saved checkpoint")
	await _tap(holder,view,"ExplorePrimary")
	_check(state.call("sample_stock","topping_citrus_peel")==3,tag+": actual claim gives exactly three")
	await _shot(holder,tag+"_explore_09_received.png")
	before=_state_json(app)
	app.call("_on_exploration_collect")
	_check(_state_json(app)==before,tag+": duplicate claim leaves stock and wallet unchanged")
	await _tap(holder,view,"ExplorePrimary")
	await _settle()
	editor=app.get("_bowl_editor") as Control
	_check(editor.is_visible_in_tree() and str(editor.get("category"))=="채소·과일",tag+": received material focuses correct native category")
	_check((editor.get("_modal") as Control)!=null and (editor.get("_modal") as Control).find_child("EditorDetailApply",true,false)!=null,tag+": received actual material details actionable")
	_check(_state_json(app)==before,tag+": native handoff does not apply ingredient/pay/taste")
	await _shot(holder,tag+"_explore_10_native_handoff.png")
	# The same UI handles the other real sampling ledger without rewriting it.
	var harbor:=HarborFixture.new()
	harbor.check=_check
	prepared=harbor.ready()
	_check(state.call("load_from_dict",prepared.to_dict())=="",tag+": valid rank2 harbor fixture loads")
	app.get("_exploration_message").text=""
	app.call("_refresh_all")
	app.call("_open_overlay",6)
	view=await _show(app)
	await _tap(holder,view,"ExploreRegion_harbor")
	await _tap(holder,view,"ExploreMode_sample")
	await _shot(holder,tag+"_explore_11_harbor.png")
	await _tap(holder,view,"ExplorePrimary")
	view=await _arrive_at(app)
	before=_state_json(app)
	await _tap(holder,view,"ExploreSecondary")
	_check(_state_json(app)==before and (view.get("_action") as Button).text=="포기 확정",tag+": retire first opens explicit no-refund confirmation")
	await _shot(holder,tag+"_explore_12_retire.png")
	await _tap(holder,view,"ExploreSecondary")
	_check(_state_json(app)==before,tag+": cancel retirement preserves active trip")
	view=await _choose(holder,app,"scallop_diver")
	view=await _choose(holder,app,"clean_three")
	await _tap(holder,view,"ExplorePrimary")
	_check(state.call("sample_stock","topping_scallop")==3,tag+": same presentation claims real harbor stock")
	_check(bool(state.call("serve")["ok"]),tag+": actual service opens next departure day")
	app.call("_refresh_all")
	view=await _show(app)
	wallet=int(state.get("wallet"))
	await _tap(holder,view,"ExplorePrimary")
	view=await _arrive_at(app)
	await _tap(holder,view,"ExploreSecondary")
	await _tap(holder,view,"ExplorePrimary")
	_check(not state.call("exploration_active") and int(state.get("wallet"))==wallet-1200 and state.call("departed_today") and state.call("sample_stock","topping_scallop")==3,tag+": confirmed retirement keeps paid fee/day and grants nothing")
	# Save failure is a real file-as-directory blocker inside this QA root.
	var blocker: String=dir.path_join("blocked-save")
	var file:=FileAccess.open(blocker,FileAccess.WRITE)
	file.store_string("QA file, not a directory")
	file.close()
	app.set("saver",SaveServiceScript.new(blocker))
	_check(not bool(app.call("_persist")),tag+": real isolated save failure")
	view=await _show(app)
	_check((view.get("_notice") as Button).visible,tag+": save failure stays visible above collection")
	await _tap(holder,view,"ExploreNotice")
	_layout_checks(view,holder,tag+" save failure")
	await _shot(holder,tag+"_explore_13_save_warning.png")
	# Open-screen resizing must reflow the fixed action and real scroll surface.
	holder.size=Vector2i(390,750)
	await _settle()
	_layout_checks(view,holder,tag+" live resize")
	holder.size=vp
	await _settle()
	app.queue_free()
	holder.queue_free()
	await _settle()
