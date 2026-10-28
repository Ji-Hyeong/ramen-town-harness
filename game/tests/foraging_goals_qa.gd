extends "res://tests/exploration_workbench_qa.gd"
## Goal routing is verified with actual native controls and real paid trips.
## Public-state preparation accelerates existing manufacture/service clocks;
## that setup is not evidence of native manufacture animation or human fun.
const GoalState=preload("res://scripts/domain/game_state.gd")
const Goals=preload("res://scripts/ui/foraging_plan.gd")
const GoalDirections=preload("res://scripts/domain/recipe_directions.gd")
const GoalHarborFixture=preload("res://tests/harbor_foraging_tests.gd")
var _goal_finished: int=0

func _run() -> void:
	for profile in [{"tag":"portrait","size":Vector2i(390,844)},{"tag":"desktop","size":Vector2i(1280,800)},{"tag":"compact","size":Vector2i(390,750)}]:
		await _goal_profile(profile["tag"],profile["size"])
	_check(_goal_finished==3,"all three native goal profiles complete")
	print("FORAGING GOALS checks=%d failures=%d mode=%s" % [_checks,_failures.size(),"layout" if _layout_only else "capture"])
	for failure in _failures: printerr("FAIL: "+failure)
	quit(0 if _failures.is_empty() else 1)

func _ledger(st: Object) -> String:
	return JSON.stringify(st.to_dict(),"",true)

func _row(st: Object, direction: String, id: String) -> Dictionary:
	var plan: Dictionary=Goals.describe(st,direction)
	_check(plan["error"]=="","valid current goal projection")
	for row in plan["ingredients"]:
		if row["id"]==id: return row
	_check(false,"required goal material exists: "+id)
	return {}

func _open_goal(holder: SubViewport, app: Node, id: String) -> Control:
	var view: Control=app.get("_exploration_view")
	await _tap(holder,view,"ExploreGoals")
	var back: Button=view.find_child("GoalBoardBack",true,false)
	if back!=null and back.is_visible_in_tree(): await _tap(holder,view,"GoalBoardBack")
	await _tap(holder,view,"GoalOpen_"+id)
	return view

func _finish_trip(holder: SubViewport, app: Node, first: String, second: String) -> void:
	await _tap(holder,app.get("_exploration_view"),"ExplorePrimary")
	await _arrive_at(app)
	await _choose(holder,app,first)
	await _choose(holder,app,second)
	await _tap(holder,app.get("_exploration_view"),"ExplorePrimary")
	await _settle()
	_check(not app.get("state").exploration_active(),"explicit receipt claim ends actual trip")

func _prepare_base(st: Object) -> void:
	_check(st.set_broth_blend(["kelp","ginger"],"standard")["ok"],"public light broth formula")
	_check(st.begin_broth()["ok"] and st.advance_broth(20.0)["ok"] and st.use_broth(0)["ok"],"public actual broth paid completion and explicit use")
	_check(st.begin_noodle()["ok"] and st.advance_noodle(20.0)["ok"] and st.use_noodle(0)["ok"],"public actual noodle paid completion and explicit use")
	_check(st.taste()["ok"],"paid initial raw-component tasting")

func _next_day(app: Node) -> void:
	var st: Object=app.get("state")
	_check(st.serve()["ok"],"real settled service opens another departure day")
	_check(app.call("manual_save")["ok"],"public progress saved in isolated store")
	app.call("_refresh_all")
	app.call("_sync_bowl_editor")

func _goal_profile(tag: String, vp: Vector2i) -> void:
	var holder:=SubViewport.new()
	holder.size=vp
	holder.handle_input_locally=true
	holder.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	holder.set_meta("qa_tag",tag)
	root.add_child(holder)
	var dir: String=_data_root.path_join(tag+"_goal")
	_check(DirAccess.make_dir_recursive_absolute(dir)==OK,tag+": fresh isolated storage")
	var app: Node=await _spawn(holder,dir)
	app.set("state",GoalState.new())
	app.set_process(false)
	var st: Object=app.get("state")
	app.call("_refresh_all")
	app.call("_on_dev_pressed")
	var editor: Control=app.get("_bowl_editor")
	editor.call("_show_directions")
	await _settle()
	var before: String=_ledger(st)
	await _shot(holder,tag+"_goal_01_list.png")
	var open: Button=editor.find_child("GoalOpen_citrus_clear",true,false)
	var acks: int=app.get("_juice").acknowledgement_count()
	await _drag_list(holder,open.get_global_rect().get_center())
	_check(editor.find_child("GoalDetailTitle",true,false)==null and _ledger(st)==before and app.get("_juice").acknowledgement_count()==acks,tag+": goal-card drag cancels navigation and success feedback")
	_point(holder,open.get_global_rect().get_center(),true)
	await _settle()
	for words in open.get_parent().find_children("*","Label",true,false):
		_check(words.get_theme_color("font_color")==Color.WHITE and _text_height_fits(words),tag+": held goal-card text is readable and fits")
	await _shot(holder,tag+"_goal_01b_pressed.png")
	_point(holder,open.get_global_rect().get_center(),false)
	await _settle()
	_check(editor.find_child("GoalDetailTitle",true,false)!=null and app.get("_juice").acknowledgement_count()>acks,tag+": released goal card opens details with existing click effect")
	await _tap(holder,editor,"GoalSelect_citrus_clear")
	_check(app.get("_direction_target")=="citrus_clear" and _ledger(st)==before,tag+": selecting a goal changes session UI only")
	await _shot(holder,tag+"_goal_02_detail.png")
	app.call("_on_foraging_source","citrus_clear","topping_scallop")
	_check(_ledger(st)==before and not st.exploration_active(),tag+": mismatched source callback cannot mutate state or depart")
	await _tap(holder,editor,"GoalSource_topping_citrus_peel")
	var view: Control=app.get("_exploration_view")
	_check(view.visible and view.get("region")=="market" and view.get("mode")=="supplier" and _ledger(st)==before,tag+": missing suppliers route to supplier mode without a fee")
	_layout_checks(view,holder,tag+" prerequisite source")
	await _shot(holder,tag+"_goal_03_supplier.png")
	await _finish_trip(holder,app,"m_ask","m_hear_recipe")
	_check(st.ingredient_unlocked("tare_plum") and not _row(st,"citrus_clear","topping_citrus_peel")["sample_ready"],tag+": another supplier reward never satisfies the desired sample")
	_prepare_base(st)
	_next_day(app)
	view=await _open_goal(holder,app,"citrus_clear")
	_check(_row(st,"citrus_clear","topping_citrus_peel")["mode"]=="supplier",tag+": one supplier still requires supplier mode")
	await _tap(holder,view,"GoalSource_topping_citrus_peel")
	await _finish_trip(holder,app,"m_ask","m_buy_pickle")
	_next_day(app)
	view=await _open_goal(holder,app,"citrus_clear")
	before=_ledger(st)
	await _tap(holder,view,"GoalSource_topping_citrus_peel")
	_check(view.get("mode")=="sample" and _ledger(st)==before,tag+": both suppliers open sampling review without departing")
	await _shot(holder,tag+"_goal_04_sampling.png")
	await _finish_trip(holder,app,"sesame_stall","take_two")
	_check(st.sample_stock("oil_roasted_sesame")==2 and st.sample_stock("topping_citrus_peel")==0 and not Goals.describe(st,"citrus_clear")["ready"],tag+": wrong sample remains a real reward, never a citrus success")
	await _shot(holder,tag+"_goal_05_other_reward.png")
	_next_day(app)
	view=await _open_goal(holder,app,"citrus_clear")
	await _tap(holder,view,"GoalSource_topping_citrus_peel")
	var wallet: int=st.wallet
	await _finish_trip(holder,app,"citrus_cart","take_three")
	_check(st.wallet==wallet-1300 and st.sample_stock("topping_citrus_peel")==3,tag+": target trip charges exact fee/extra and grants three only on claim")
	await _shot(holder,tag+"_goal_06_target_reward.png")
	view=await _open_goal(holder,app,"citrus_clear")
	_check(_row(st,"citrus_clear","topping_citrus_peel")["sample_ready"] and not Goals.describe(st,"citrus_clear")["tested"],tag+": collected material is not an earned tasted discovery")
	before=_ledger(st)
	await _tap(holder,view,"GoalDevelop_topping_citrus_peel")
	_check(editor.visible and _ledger(st)==before,tag+": develop callback reveals real material without applying it")
	await _tap(holder,editor,"EditorDetailApply")
	# Remove the existing pork explicitly, retaining the newly added citrus.
	await _tap(holder,editor,"EditorRemove_0")
	await _tap(holder,editor,"EditorBroth")
	await _tap(holder,editor,"BrothTab_seasoning")
	await _tap(holder,editor,"EditorGroupTab_oil")
	await _tap(holder,editor,"EditorAdd_oil_scallion")
	await _tap(holder,editor,"EditorDetailApply")
	var count: int=st.record_count()
	wallet=st.wallet
	var fee: int=st.trial_cost()
	await _tap(holder,editor,"EditorTaste")
	app.call("advance_work",10.0)
	await _settle()
	_check(st.record_count()==count+1 and st.wallet==wallet-fee and st.sample_stock("topping_citrus_peel")==2,tag+": paid prototype consumes exactly its real sample portion and fee")
	_check(Goals.describe(st,"citrus_clear")["tested"] and GoalDirections.tested_ids(st.records()).has("citrus_clear"),tag+": discovery follows the actual matching retained paid recipe")
	await _shot(holder,tag+"_goal_07_tasted.png")
	var restored:=GoalState.new()
	_check(app.get("saver").load_into(restored)["status"]=="ok" and restored.to_dict()==st.to_dict(),tag+": exact saved progress round trip")
	_check(Goals.describe(restored,"citrus_clear")==Goals.describe(st,"citrus_clear"),tag+": readiness and witnesses reconstruct without a new ledger")
	app.call("_close_overlay")
	app.call("_sync_bowl_editor")
	app.call("_on_journey_action","explore")
	view=app.get("_exploration_view")
	await _settle()
	_check(view.visible and view.get("_detail")=="goals",tag+": post-sales exploration choice reaches the goal board")
	await _shot(holder,tag+"_goal_08_resume.png")
	await _prepared_harbor(holder,app,tag)
	_goal_finished+=1
	app.queue_free()
	await _settle()
	holder.queue_free()
	await _settle()

func _prepared_harbor(holder: SubViewport, app: Node, tag: String) -> void:
	var fixture:=GoalHarborFixture.new()
	fixture.check=_check
	var st: Object=fixture.ready()
	_check(st.start_harbor_foraging()["ok"] and st.advance_expedition("sardine_boat")["ok"] and st.advance_expedition("take_one")["ok"] and st.finish_expedition()["ok"],tag+": legitimate single sardine sample")
	_check(st.set_broth_blend(["sardine"],"standard")["ok"] and st.begin_broth()["ok"] and st.advance_broth(20.0)["ok"] and st.use_broth(0)["ok"],tag+": actual completed raw sardine broth")
	_check(st.taste()["ok"] and st.sample_stock("broth_roasted_sardine")==0,tag+": real tasting spends the last sardine sample")
	app.set("state",st)
	app.call("_refresh_all")
	app.call("_open_overlay",0)
	var editor: Control=app.get("_bowl_editor")
	editor.call("_show_directions")
	await _settle()
	await _tap(holder,editor,"GoalOpen_harbor_sea")
	var row: Dictionary=_row(st,"harbor_sea","broth_roasted_sardine")
	_check(row["prepared"] and row["usable"] and not row["sample_ready"],tag+": completed raw product is distinct from sample readiness at stock0")
	_check(editor.find_child("GoalIngredient_topping_scallop",true,false)!=null,tag+": both required harbor materials remain visible")
	await _shot(holder,tag+"_goal_09_prepared_stock0.png")
	var before: String=_ledger(st)
	await _tap(holder,editor,"GoalDevelop_broth_roasted_sardine")
	_check((editor.get("_modal") as Control).get_meta("view_kind","")=="component_complete" and _ledger(st)==before,tag+": prepared product at stock0 opens the actual immutable completion without manufacture/payment")
	await _shot(holder,tag+"_goal_10_prepared_product.png")
