extends "res://tests/bowl_editor_qa.gd"
## Only public transactions prepare earned progression. Pointer actions use the
## actual native view; hidden legacy growth adapters are never visual evidence.
const Fixture = preload("res://tests/harbor_foraging_tests.gd")
const StaffRules = preload("res://scripts/domain/staff_training.gd")
const ConfigCheck = preload("res://scripts/domain/data_check.gd")


func _run() -> void:
	var profiles: Array=[{"tag":"portrait","size":Vector2i(390,844)},{"tag":"desktop","size":Vector2i(1280,800)}]
	if OS.get_cmdline_user_args().has("--growth-compact"): profiles=[{"tag":"compact","size":Vector2i(390,750)}]
	for profile in profiles: await _growth_flow(profile["tag"],profile["size"])
	print("STAFF GROWTH mode=%s checks=%d failures=%d" % ["layout-only" if _layout_only else "capture",_checks,_failures.size()])
	for failure in _failures: printerr("FAIL: "+failure)
	quit(0 if _failures.is_empty() else 1)


func _json(st: Object) -> String:
	return JSON.stringify(st.to_dict(),"",true)


func _update(app: Node) -> void:
	app.call("_refresh_all")
	app.call("_sync_bowl_editor")
	await _settle()


func _bounds(holder: SubViewport, view: Control, tag: String) -> void:
	var frame: Control=view.find_child("GrowthFrame",true,false)
	_check(Rect2(Vector2.ZERO,Vector2(holder.size)).encloses(frame.get_global_rect()),tag+": frame inside viewport")
	for name in ["GrowthBack","GrowthPrimary","GrowthSecondary"]:
		var control: Control=view.find_child(name,true,false)
		_check(frame.get_global_rect().encloses(control.get_global_rect()) and control.size.y>=44,tag+": fixed usable "+name)
	var scroll: Control=view.find_child("GrowthScroll",true,false)
	var footer: Control=view.find_child("GrowthPrimary",true,false)
	_check(scroll.size.y>=120 and scroll.get_global_rect().end.y<=footer.get_global_rect().position.y,tag+": body scroll stays above fixed action")
	var wallet: Label=view.find_child("GrowthWallet",true,false)
	_check(wallet.size.x>=wallet.get_theme_font("font").get_string_size(wallet.text,HORIZONTAL_ALIGNMENT_LEFT,-1,16).x-1,tag+": uncut wallet")
	for candidate in view.find_children("*","Label",true,false):
		var label: Label=candidate
		if label.is_visible_in_tree(): _check(_text_height_fits(label),tag+": text height fits "+label.name)


func _research(st: Object) -> void:
	_check(st.purchase_facility("bench_1")["ok"],"real recipe space for research witnesses")
	for id in ResearchScript.ids():
		if st.research_completed_ids().has(id): continue
		var config: Dictionary=ResearchScript.WITNESSES[id]
		var existing: int=0
		for record in st.records():
			if ConfigCheck.same_config(record["config"],config): existing=int(record["record_id"])
		if existing!=0:
			_check(st.submit_research(id,existing)["ok"],"submit actual existing witness "+id)
			continue
		st.start_new_recipe()
		for slot in IngredientCatalog.SLOTS: _check(st.set_draft_choice(slot,config[slot])["ok"],"real witness ingredient")
		_check(st.set_draft_price(config["price"])["ok"] and st.set_draft_name("육성 "+id)["ok"],"research draft "+id)
		var tasting: Dictionary=st.taste()
		_check(tasting["ok"],"real research tasting "+id+": "+str(tasting.get("message","")))
		var submitted: Dictionary=st.submit_research(id,st.selected_record_id)
		_check(submitted["ok"],"real research receipt "+id+": "+str(submitted.get("message","")))
	while st.completed_service_days()<10: _check(st.serve()["ok"],"real days for rank3")
	_check(st.promotion_review()["eligible"],"real rank3 requirements earned")


func _earn(st: Object, bowls: int, days: int) -> void:
	var count: int=0
	while (st.staff_training()["prep_assistant"]["bowls"]<bowls or st.staff_training()["prep_assistant"]["work_days"]<days) and count<30:
		_check(st.serve()["ok"],"real completed service earns work experience")
		count+=1
	_check(count<30,"finite publicly earned training")


func _growth_flow(tag: String, vp: Vector2i) -> void:
	var holder:=SubViewport.new()
	holder.size=vp
	holder.handle_input_locally=true
	holder.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(holder)
	var dir: String=_data_root.path_join(tag)
	_check(DirAccess.make_dir_recursive_absolute(dir)==OK,"isolated growth directory")
	var app: Control=await _spawn(holder,dir)
	app.set_process(false)
	var st: Object=app.get("state")
	await _tap(holder,app.get("_home"),"HomeInfo")
	await _tap(holder,app.get("_home"),"HomeGrowth")
	var view: Control=app.get("_growth_view")
	_check(view.visible and not (app.get("_drawer_margin") as Control).visible,tag+": actual native view replaces legacy drawer")
	_bounds(holder,view,tag+" initial")
	await _shot(holder,tag+"_growth_01_initial.png")
	var before: String=_json(st)
	await _drag_list(holder,(view.find_child("GrowthStaff_prep_assistant",true,false) as Control).get_global_rect().get_center())
	_check(view.get("_page")=="list",tag+": card swipe cancels detail navigation")
	await _tap(holder,view,"GrowthStaff_prep_assistant")
	_check((view.find_child("GrowthPrimary",true,false) as Button).disabled and _json(st)==before,tag+": no-space hiring is read-only and locked")
	await _tap(holder,view,"GrowthBack")
	await _tap(holder,view,"GrowthTab_facility")
	await _tap(holder,view,"GrowthFacility_staff_1")
	_check((view.find_child("GrowthPrimary",true,false) as Button).disabled,tag+": actual rank lock")
	var fixture:=Fixture.new()
	fixture.check=_check
	_check(st.load_from_dict(fixture.ready().to_dict())=="",tag+": actual rank2 state clone")
	await _update(app)
	await _tap(holder,view,"GrowthTab_staff")
	await _shot(holder,tag+"_growth_02_rank2.png")
	await _tap(holder,view,"GrowthTab_facility")
	await _tap(holder,view,"GrowthFacility_staff_1")
	var wallet: int=st.wallet
	await _shot(holder,tag+"_growth_03_facility.png")
	await _tap(holder,view,"GrowthPrimary")
	_check(st.wallet==wallet-15000 and st.staff_capacity()==3 and st.hired_staff().is_empty(),tag+": exact one space purchase without auto hire")
	before=_json(st)
	app.call("_on_facility_buy","staff_1")
	_check(_json(st)==before,tag+": repeat space purchase cannot charge again")
	if vp.x<760:
		await _tap(holder,view,"GrowthTab_facility")
		await _tap(holder,view,"GrowthFacility_staff_2")
		await _tap(holder,view,"GrowthBack")
		_check((view.get("_scroll") as ScrollContainer).scroll_vertical>0,tag+": scrolled facility list returns to actual retained position")
	await _tap(holder,view,"GrowthTab_staff")
	await _tap(holder,view,"GrowthStaff_prep_assistant")
	var preview: Dictionary=st.hiring_preview("prep_assistant")
	_check((view.find_child("GrowthHiringForecast",true,false) as Label).text.contains(str(preview["after"]["units"])),tag+": actual hiring forecast shown")
	_bounds(holder,view,tag+" hiring")
	await _shot(holder,tag+"_growth_04_hiring.png")
	wallet=st.wallet
	await _tap(holder,view,"GrowthPrimary")
	_check(st.wallet==wallet-8000 and st.hired_staff()==["prep_assistant"],tag+": exact once-only hire")
	await _shot(holder,tag+"_growth_05_staff.png")
	await _tap(holder,view,"GrowthPrimary")
	await _tap(holder,view,"GrowthStyle_basic")
	_check((view.find_child("GrowthPrimary",true,false) as Button).disabled,tag+": real unearned XP lock")
	await _shot(holder,tag+"_growth_06_training_locked.png")
	var scroll: ScrollContainer=view.get("_scroll")
	var choice: Control=view.find_child("GrowthStyle_basic",true,false)
	scroll.scroll_vertical=0
	await _settle()
	before=_json(st)
	var acknowledgements: int=app.get("_juice").acknowledgement_count()
	await _drag_list(holder,choice.get_global_rect().get_center())
	_check(scroll.scroll_vertical>0 and _json(st)==before and app.get("_juice").acknowledgement_count()==acknowledgements,tag+": real drag over training choice scrolls without activating it")
	scroll.scroll_vertical=0
	await _settle()
	await _drag_list(holder,scroll.get_global_rect().position+Vector2(50,40))
	_check(scroll.scroll_vertical>0 and _json(st)==before,tag+": real drag over portrait/body scrolls")
	scroll.scroll_vertical=0
	await _settle()
	_earn(st,40,2)
	await _update(app)
	before=_json(st)
	app.call("_start_service")
	app.call("_sync_bowl_editor")
	await _settle()
	_check(st.service_active() and (view.find_child("GrowthPrimary",true,false) as Button).disabled,tag+": actual active service locks otherwise earned training")
	app.call("_on_staff_train","prep_assistant","basic")
	_check(_json(st)==before,tag+": active-service training handler leaves complete saved state unchanged")
	app.call("_abort_service","시험 중단")
	await _update(app)
	_bounds(holder,view,tag+" earned training")
	await _shot(holder,tag+"_growth_07_training.png")
	before=_json(st)
	await _tap(holder,view,"GrowthPrimary")
	_check(_json(st)==before and app.get("_training_armed")=="prep_assistant:basic",tag+": first training tap only arms confirmation")
	await _shot(holder,tag+"_growth_08_confirm.png")
	await _tap(holder,view,"GrowthBack")
	_check(app.get("_training_armed")=="" and _json(st)==before,tag+": cancel clears pending confirmation without cost")
	await _tap(holder,view,"GrowthPrimary")
	await _tap(holder,view,"GrowthStyle_basic")
	await _tap(holder,view,"GrowthPrimary")
	app.set("_training_armed_until",Time.get_ticks_msec()-1)
	app.call("_process",0.0)
	await _tap(holder,view,"GrowthPrimary")
	_check(_json(st)==before,tag+": expired confirmation must arm again")
	wallet=st.wallet
	await _tap(holder,view,"GrowthPrimary")
	_check(st.wallet==wallet-4000 and StaffRules.level(st.staff_training()["prep_assistant"])==1,tag+": exact one training charge/qualification")
	_check((view.find_child("GrowthPrimary",true,false) as Button).disabled and float(app.get("_training_left"))>0,tag+": real progress locks further transaction")
	app.call("advance_training",1.0)
	app.call("_sync_bowl_editor")
	await _settle()
	_check(is_equal_approx((view.find_child("GrowthTrainingProgress",true,false) as ProgressBar).value,50),tag+": actual presentation half progress")
	await _shot(holder,tag+"_growth_09_progress.png")
	before=_json(st)
	app.call("advance_training",2.0)
	app.call("_sync_bowl_editor")
	await _settle()
	_check(_json(st)==before,tag+": animation never grants extra XP/cash")
	_research(st)
	await _update(app)
	await _tap(holder,view,"GrowthTab_shop")
	await _tap(holder,view,"GrowthRank")
	await _shot(holder,tag+"_growth_10_rank.png")
	wallet=st.wallet
	await _tap(holder,view,"GrowthPrimary")
	_check(st.rank()==2 and st.wallet==wallet,tag+": rank confirmation before mutation")
	await _tap(holder,view,"GrowthPrimary")
	_check(st.rank()==3 and st.wallet==wallet,tag+": actual promotion has no cash reward")
	_earn(st,160,5)
	await _update(app)
	await _tap(holder,view,"GrowthTab_staff")
	await _tap(holder,view,"GrowthStaff_prep_assistant")
	await _tap(holder,view,"GrowthPrimary")
	await _tap(holder,view,"GrowthStyle_economy")
	_check((view.find_child("GrowthTrainingEffect",true,false) as Label).text.contains("500원"),tag+": actual economy branch upkeep visible before selection")
	await _tap(holder,view,"GrowthStyle_speed")
	await _shot(holder,tag+"_growth_11_specialization.png")
	wallet=st.wallet
	await _tap(holder,view,"GrowthPrimary")
	await _tap(holder,view,"GrowthPrimary")
	_check(st.wallet==wallet-12000 and StaffRules.level(st.staff_training()["prep_assistant"])==2,tag+": actual permanent specialization")
	app.call("advance_training",3.0)
	app.call("_sync_bowl_editor")
	await _settle()
	before=_json(st)
	app.call("_on_staff_train","prep_assistant","economy")
	_check(_json(st)==before,tag+": cannot reselect specialization")
	await _shot(holder,tag+"_growth_12_specialist.png")
	await _tap(holder,view,"GrowthTab_shop")
	await _tap(holder,view,"GrowthExpansion")
	wallet=st.wallet
	var cost: int=st.expansion_review()["price"]
	await _tap(holder,view,"GrowthPrimary")
	_check(st.wallet==wallet and not st.shop_expanded(),tag+": expansion only armed")
	await _shot(holder,tag+"_growth_13_expansion_confirm.png")
	await _tap(holder,view,"GrowthPrimary")
	_check(st.wallet==wallet-cost and st.seat_count()==12 and st.selling_capacity()==2,tag+": exact once-only expansion")
	holder.size=Vector2i(390,750)
	await _settle()
	_bounds(holder,view,tag+" live compact resize")
	holder.size=vp
	await _settle()
	var saver: Object=app.get("saver")
	_check(app.call("_persist"),tag+": save before scoped failure")
	var disk: String=FileAccess.get_file_as_string(saver.main_path())
	_check(DirAccess.make_dir_recursive_absolute(saver.tmp_path())==OK,tag+": isolated tmp conflict")
	await _tap(holder,view,"GrowthTab_facility")
	await _tap(holder,view,"GrowthFacility_bench_2")
	wallet=st.wallet
	await _tap(holder,view,"GrowthPrimary")
	_check(st.wallet==wallet-30000 and FileAccess.get_file_as_string(saver.main_path())==disk,tag+": failed save truthfully keeps memory change and previous disk")
	await _tap(holder,view,"GrowthNotice")
	await _shot(holder,tag+"_growth_14_save_failure.png")
	_check(DirAccess.remove_absolute(saver.tmp_path())==OK and app.call("_persist"),tag+": actual save recovery")
	app.call("_sync_bowl_editor")
	await _settle()
	_check((view.find_child("GrowthCurrentSave",true,false) as Label).text.contains("저장됨"),tag+": recovery shows actual current save separately from historical failed action")
	await _tap(holder,view,"GrowthBack")
	await _tap(holder,view,"GrowthPrimary")
	await _tap(holder,app.get("_home"),"HomeInfo")
	_check((app.get("_home").get("_capacity") as Label).text.contains("직원 3/3명"),tag+": home includes fixed chef/server in real staff count")
	await _tap(holder,app.get("_home"),"HomeDetailsClose")
	var saved: String=_json(st)
	app.queue_free()
	await _frames(3)
	app=await _spawn(holder,dir)
	app.set_process(false)
	_check(_json(app.get("state"))==saved,tag+": real restart retains exact progression")
	app.call("_open_overlay",5)
	await _settle()
	await _shot(holder,tag+"_growth_15_restart.png")
	app.queue_free()
	await _frames(3)
	holder.queue_free()
	await _settle()
