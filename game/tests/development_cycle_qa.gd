extends "res://tests/noodle_workshop_qa.gd"
## A real first-menu journey. Every paid completion uses elapsed frames and
## public guarded transactions; all files stay in isolated QA directories.
const Focus=preload("res://scripts/ui/tasting_focus.gd")
const People=preload("res://scripts/domain/customer_catalog.gd")

func _run() -> void:
	_focus_cases()
	for profile in [{"tag":"portrait","size":Vector2i(390,844)},{"tag":"desktop","size":Vector2i(1280,800)}]:
		await _cycle(profile["tag"],profile["size"])
	print("DEVELOPMENT CYCLE checks=%d failures=%d mode=%s" % [_checks,_failures.size(),"layout" if _layout_only else "capture"])
	for failure in _failures: printerr("FAIL: "+failure)
	quit(0 if _failures.is_empty() else 1)

func _focus_cases() -> void:
	var profile: Dictionary=People.find("hayoung")["targets"].duplicate(true)
	_check(Focus.describe(profile,"hayoung")["matched"],"exact observed taste needs no corrective claim")
	profile["rich"]+=1
	_check(Focus.describe(profile,"hayoung")["matched"],"notice threshold matches actual evaluator")
	profile["rich"]=8
	profile["aroma"]=1
	var before: Dictionary=profile.duplicate(true)
	var result: Dictionary=Focus.describe(profile,"hayoung")
	_check(result["axis"]=="aroma" and result["current"]==1 and result["target"]==7,"weighted observed aroma gap9.6 outranks richness5")
	_check(result["group"]=="broth" and result["tab"]=="oil" and not result.has("score") and not result.has("config"),"focus contains navigation and observed facts, no forecast or candidate")
	_check(profile==before,"focus never mutates the tasted profile")
	_check(Focus.describe(profile,"missing")["error"]!="" and Focus.describe({},"hayoung")["error"]!="","invalid observations are explicit failures")

func _wait_component(st: Object, kind: String) -> void:
	var deadline: int=Time.get_ticks_msec()+12000
	while (st.broth_active() if kind=="broth" else st.noodle_active()) and Time.get_ticks_msec()<deadline:
		await process_frame
	await _settle()
	_check(not (st.broth_active() if kind=="broth" else st.noodle_active()),"actual elapsed "+kind+" work finishes")

func _cycle(tag: String, vp: Vector2i) -> void:
	var holder:=SubViewport.new()
	holder.size=vp
	holder.handle_input_locally=true
	holder.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(holder)
	var dir: String=_data_root.path_join(tag+"_cycle")
	_check(DirAccess.make_dir_recursive_absolute(dir)==OK,tag+": own fresh save")
	var app: Node=await _spawn(holder,dir)
	app.set("state",ActualState.new())
	var st: Object=app.get("state")
	app.call("_refresh_all")
	app.call("_on_dev_pressed")
	await _settle()
	var editor: Control=app.get("_bowl_editor")
	_check(not st.broth_ready() and not st.noodle_ready(),tag+": no free prepared components")
	await _tap(holder,editor,"EditorTaste")
	await _tap(holder,editor,"BrothAdd_chicken_bone")
	await _tap(holder,editor,"BrothAdd_onion")
	await _tap(holder,editor,"EditorDetailApply")
	await _wait_component(st,"broth")
	_check(not st.broth_ready() and (editor.get("_modal") as Control).get_meta("view_kind","")=="component_complete",tag+": completion requires explicit broth use")
	_fixed_action(editor,vp,tag+" broth completion")
	await _shot(holder,tag+"_cycle_01_broth_complete.png")
	var before: Dictionary=st.to_dict()
	await _tap(holder,editor,"ComponentCompletionLibrary")
	_check(st.to_dict()==before,tag+": completion-to-library browsing is read-only")
	await _tap(holder,editor,"EditorDetailsBack")
	_check((editor.get("_taste") as Button).text=="만든 육수 담기",tag+": unapplied finished component has a truthful resume action")
	await _tap(holder,editor,"EditorTaste")
	_check((editor.get("_modal") as Control).get_meta("view_kind","")=="component_complete" and st.to_dict()==before,tag+": resume opens real completed product without crafting again")
	var wallet: int=st.wallet
	await _tap(holder,editor,"EditorDetailApply")
	_check(st.broth_ready() and not st.noodle_ready() and not st.noodle_active() and st.wallet==wallet,tag+": explicit broth apply opens next task without another fee/work")
	_check((editor.get("_modal") as Control).get_meta("view_kind","")=="noodle",tag+": broth-to-noodle is direct")
	await _shot(holder,tag+"_cycle_02_noodle_choices.png")
	await _tap(holder,editor,"NoodleChoose_strong")
	await _tap(holder,editor,"NoodleChoose_medium")
	await _tap(holder,editor,"NoodleChoose_moist")
	_check(st.wallet==wallet and not st.noodle_ready() and not st.recipe_known(st.draft_config),tag+": same-sheet raw choices do not apply/pay/discover")
	await _shot(holder,tag+"_cycle_03_noodle_selected.png")
	app.set("save_locked",true)
	await _tap(holder,editor,"EditorDetailApply")
	await create_timer(0.8).timeout
	await _shot(holder,tag+"_cycle_04_noodle_work.png")
	await _wait_component(st,"noodle")
	_check(not st.noodle_ready() and st.wallet<wallet,tag+": finished noodle paid once, still unapplied")
	var saved_wallet: int=st.wallet
	var warning: Label=editor.find_child("DevelopmentSaveWarning",true,false)
	_check(warning!=null and warning.visible and not warning.text.is_empty(),tag+": completion retains actionable unsaved warning")
	_fixed_action(editor,vp,tag+" unsaved completion")
	await _shot(holder,tag+"_cycle_05_unsaved_complete.png")
	before=st.to_dict()
	app.call("_on_noodle_action","noodle_use",{"index":999,"advance":true})
	_check(st.to_dict()==before and (editor.get("_modal") as Control).get_meta("view_kind","")=="component_complete",tag+": failed apply cannot advance or change state")
	app.set("save_locked",false)
	_check(app.call("manual_save")["ok"] and st.wallet==saved_wallet,tag+": retry does not charge twice")
	app.call("_sync_bowl_editor")
	_check(not warning.visible,tag+": successful retry clears completion warning")
	await _shot(holder,tag+"_cycle_06_noodle_complete.png")
	await _tap(holder,editor,"EditorDetailApply")
	_check(st.noodle_ready() and st.broth_ready() and editor.get("_modal")==null and st.wallet==saved_wallet,tag+": explicit noodle use returns to actual bowl without paying twice")
	await _tap(holder,editor,"EditorAdd_topping_egg")
	await _shot(holder,tag+"_cycle_07_bowl.png")
	await _tap(holder,editor,"EditorTaste")
	var deadline: int=Time.get_ticks_msec()+12000
	while app.call("work_active") and Time.get_ticks_msec()<deadline: await process_frame
	await _settle()
	_check(st.record_count()==1 and st.recipe_known(st.draft_config),tag+": actual paid tasting records crafted bowl")
	await _shot(holder,tag+"_cycle_08_tasted.png")
	before=st.to_dict()
	var evaluation: Dictionary=preload("res://scripts/domain/recipe_evaluator.gd").evaluate(st.get_record(st.last_feedback_record_id)["config"])
	for index in 3:
		await _tap(holder,editor,"EditorCustomer_"+str(index))
		var observed: Dictionary=Focus.describe(evaluation["profile"],evaluation["customers"][index]["id"])
		var label: Label=editor.find_child("TastingObservedFocus",true,false)
		_check(label.text==observed["caption"] and _text_height_fits(label),tag+": customer-specific observed values fit and match actual tasted profile")
		var card: Control=editor.find_child("EditorResultDetails",true,false)
		_check(card.get_global_rect().grow(-4).encloses(label.get_global_rect()),tag+": reaction values have actual frame padding")
	_check(st.to_dict()==before,tag+": reading reactions changes no record/knowledge/resources")
	await _shot(holder,tag+"_cycle_09_customer.png")
	var reaction: Button=editor.find_child("EditorResultDetails",true,false)
	var reaction_point: Vector2=reaction.get_global_rect().get_center()
	_point(holder,reaction_point,true)
	await _settle()
	_check(st.to_dict()==before and (editor.find_child("TastingObservedFocus",true,false) as Label).get_theme_color("font_color")==Color.WHITE,tag+": held reaction is readable without early navigation or state mutation")
	await _shot(holder,tag+"_cycle_09b_pressed.png")
	_point(holder,reaction_point,false)
	await _settle()
	_check(editor.get("_modal")!=null,tag+": reaction opens details only on release")
	await _shot(holder,tag+"_cycle_10_reaction_details.png")
	await _tap(holder,editor,"EditorDetailsBack")
	await _tap(holder,editor,"EditorDevelopAgain")
	_check(int(editor.get("_mode"))==0 and editor.get("_modal")!=null and st.to_dict()==before,tag+": observed complaint links to real editing without altering recipe")
	await _shot(holder,tag+"_cycle_11_next_experiment.png")
	var loaded:=ActualState.new()
	_check(app.get("saver").load_into(loaded)["status"]=="ok" and loaded.to_dict()==st.to_dict(),tag+": exact disk restart after complete cycle and read-only next action")
	app.queue_free()
	await _settle()
	holder.queue_free()
	await _settle()
