extends "res://tests/staff_growth_qa.gd"
## Real pointer paths, renderer and isolated disk state. Runtime service uses
## its public order clock; screenshots never substitute analytical estimates.
const ChefFixture = preload("res://tests/chef_challenge_tests.gd")


func _run() -> void:
	var profiles: Array=[{"tag":"portrait","size":Vector2i(390,844)},{"tag":"desktop","size":Vector2i(1280,800)}]
	if OS.get_cmdline_user_args().has("--chef-compact"): profiles=[{"tag":"compact","size":Vector2i(390,750)}]
	for profile in profiles: await _chef_flow(profile["tag"],profile["size"])
	print("CHEF CHALLENGE mode=%s checks=%d failures=%d" % ["layout-only" if _layout_only else "capture",_checks,_failures.size()])
	for failure in _failures: printerr("FAIL: "+failure)
	quit(0 if _failures.is_empty() else 1)


func _bounds(holder: SubViewport, view: Control, tag: String) -> void:
	super._bounds(holder,view,tag)
	if view.get("_page")!="chef": return
	var grid: GridContainer=view.find_child("GrowthGrid",true,false)
	_check(grid!=null and grid.get_child_count()==6,tag+": six actual condition cells")
	if grid==null: return
	for cell in grid.get_children():
		_check(cell.size.x>=grid.size.x/float(grid.columns)-12,tag+": condition uses its full column width")
		for label in cell.find_children("*","Label",true,false):
			_check(label.get_line_count()<=2 and cell.get_global_rect().grow(-6).encloses(label.get_global_rect()),tag+": condition text readable, padded and not a vertical glyph column")


func _actual_service(app: Object) -> void:
	app.call("_on_close_pressed")
	app.call("_on_start_pressed")
	var state: Object=app.get("state")
	_check(state.service_active(),"actual controller starts service")
	if not state.service_active(): return
	_check(state.active_session().run_to_end(),"real session clock finishes")
	app.call("_finish_service")
	await _settle()
	_check((app.get("_service_result") as Control).visible,"native actual report visible")


func _chef_flow(tag: String, vp: Vector2i) -> void:
	var holder:=SubViewport.new()
	holder.size=vp
	holder.handle_input_locally=true
	holder.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(holder)
	var dir: String=_data_root.path_join(tag)
	_check(DirAccess.make_dir_recursive_absolute(dir)==OK,"isolated chef directory")
	var app: Control=await _spawn(holder,dir)
	app.set_process(false)
	var st: Object=app.get("state")
	await _tap(holder,app.get("_home"),"HomeInfo")
	await _tap(holder,app.get("_home"),"HomeGrowth")
	var view: Control=app.get("_growth_view")
	_bounds(holder,view,tag+" chef list")
	await _shot(holder,tag+"_chef_01_list.png")
	var before: String=_json(st)
	await _drag_list(holder,(view.find_child("GrowthChef",true,false) as Control).get_global_rect().get_center())
	_check(view.get("_page")=="list" and _json(st)==before,tag+": chef portrait/card swipe does not activate")
	await _tap(holder,view,"GrowthChef")
	_bounds(holder,view,tag+" open")
	await _shot(holder,tag+"_chef_02_open.png")
	await _tap(holder,view,"GrowthPrimary")
	_check(st.chef_challenge_review()["status"]=="active",tag+": pointer accepts free challenge")
	await _tap(holder,view,"ChefDevelop")
	_check((app.get("_bowl_editor") as Control).visible,tag+": actual development navigation")
	_check(st.taste()["ok"],tag+": actual unchanged new tasting")
	await _update(app)
	await _actual_service(app)
	_check(st.chef_challenge_review()["status"]=="active",tag+": unchanged recipe fails actual challenge")
	await _tap(holder,app.get("_service_result"),"ResultChef")
	_check(view.visible and view.get("_page")=="chef",tag+": actual receipt goal opens correct chef depth")
	_bounds(holder,view,tag+" failed")
	await _shot(holder,tag+"_chef_03_failed.png")
	var scroll: ScrollContainer=view.find_child("GrowthScroll",true,false)
	scroll.scroll_vertical=99999
	await _settle()
	_bounds(holder,view,tag+" failed bottom")
	await _shot(holder,tag+"_chef_04_actual_metrics.png")
	var fixture:=ChefFixture.new()
	fixture.check=_check
	fixture.fast(st)
	await _update(app)
	await _tap(holder,view,"GrowthPrimary")
	_check((app.get("_operations_view") as Control).visible,tag+": active challenge routes to real selling screen")
	await _actual_service(app)
	_check(st.chef_challenge_review()["status"]=="ready",tag+": completed changed lunch actually qualifies")
	await _shot(holder,tag+"_chef_05_receipt_ready.png")
	await _tap(holder,app.get("_service_result"),"ResultChef")
	scroll.scroll_vertical=0
	await _settle()
	_bounds(holder,view,tag+" ready")
	await _shot(holder,tag+"_chef_06_ready.png")
	var saver: Object=app.get("saver")
	_check(app.call("_persist"),tag+": valid ready save")
	var disk: String=FileAccess.get_file_as_string(saver.main_path())
	_check(DirAccess.make_dir_recursive_absolute(saver.tmp_path())==OK,tag+": own isolated disk conflict")
	var wallet: int=st.wallet
	await _tap(holder,view,"GrowthPrimary")
	_check(st.chef_challenge_review()["status"]=="mastered" and st.wallet==wallet and FileAccess.get_file_as_string(saver.main_path())==disk,tag+": once-only mastery in memory; previous disk preserved on failure")
	_check(float(app.get("_training_left"))>0 and (view.find_child("GrowthPrimary",true,false) as Button).disabled,tag+": actual celebration locks duplicate input")
	app.call("advance_training",1.0)
	app.call("_sync_bowl_editor")
	await _settle()
	_check(is_equal_approx((view.find_child("GrowthTrainingProgress",true,false) as ProgressBar).value,50),tag+": celebration half progress")
	await _shot(holder,tag+"_chef_07_celebration_save_failure.png")
	before=_json(st)
	app.call("advance_training",2.0)
	app.call("_sync_bowl_editor")
	await _settle()
	app.call("_on_growth_view_action","chef_claim","","")
	_check(_json(st)==before,tag+": replay after animation never repeats mastery")
	await _tap(holder,view,"GrowthNotice")
	await _shot(holder,tag+"_chef_08_save_failure.png")
	_check(DirAccess.remove_absolute(saver.tmp_path())==OK,tag+": remove own empty conflict")
	app.call("_on_manual_save_pressed")
	app.call("_sync_bowl_editor")
	await _settle()
	_check(not (app.get("_banner") as Control).visible and FileAccess.get_file_as_string(saver.main_path())!=disk,tag+": manual save recovers actual disk")
	await _tap(holder,view,"GrowthBack")
	await _tap(holder,view,"GrowthChef")
	scroll.scroll_vertical=0
	await _settle()
	_bounds(holder,view,tag+" mastered")
	await _shot(holder,tag+"_chef_09_mastered.png")
	var saved: String=_json(st)
	app.queue_free()
	await _frames(3)
	app=await _spawn(holder,dir)
	app.set_process(false)
	_check(_json(app.get("state"))==saved,tag+": exact disk restart retains mastery and service proof")
	app.call("_open_overlay",5)
	await _settle()
	view=app.get("_growth_view")
	await _tap(holder,view,"GrowthChef")
	_bounds(holder,view,tag+" restart")
	await _shot(holder,tag+"_chef_10_restart.png")
	app.queue_free()
	await _frames(3)
	holder.queue_free()
	await _settle()
