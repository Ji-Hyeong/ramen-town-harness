extends "res://tests/noodle_workshop_qa.gd"
## Independently exercise Claude's domain APIs through the actual native UI.
## Frozen pre-feature v17 bytes and a genuinely new partial player stay separate.
const ComponentRules=preload("res://scripts/domain/component_comparison.gd")
var component_profiles: int=0

func _run() -> void:
	for profile in [{"tag":"portrait","size":Vector2i(390,844)},{"tag":"desktop","size":Vector2i(1280,800)}]:
		await _component_profile(profile["tag"],profile["size"])
	_check(component_profiles==2,"both actual comparison profiles complete")
	print("COMPONENT UI checks=%d failures=%d mode=%s" % [_checks,_failures.size(),"layout" if _layout_only else "capture"])
	for failure in _failures: printerr("FAIL: "+failure)
	quit(0 if _failures.is_empty() else 1)

func _capture_comparison(holder: SubViewport, editor: Control, tag: String, kind: String, index: int) -> void:
	var st: ActualState=editor.get("state")
	var before: Dictionary=st.to_dict()
	await _tap(holder,editor,"ComponentCompare_"+kind+"_"+str(index))
	await _tap(holder,editor,"ComponentValuesToggle")
	_fixed_action(editor,holder.size,tag+" compare")
	_check(st.to_dict()==before,tag+": opening comparison changes nothing")
	var result: Dictionary=st.component_comparison(kind,index)
	var cost: Label=editor.find_child("ComponentValue_원가",true,false)
	_check(cost!=null and cost.text=="%d → %d원 (%+d)" % [result["current_component"]["cost"],result["selected_component"]["cost"],int(result["selected_component"]["cost"])-int(result["current_component"]["cost"])],tag+": actual rendered component cost matches independent domain result")
	await _shot(holder,tag+"_component_02_"+kind+".png")
	await _tap(holder,editor,"ComponentWholeRamen")
	var value: Label=editor.find_child("ComponentValue_한_그릇_원가",true,false)
	_check(value!=null and value.text.contains(str(result["candidate_ramen"]["unit_cost"])),tag+": whole-ramen forecast uses actual evaluator cost")
	for number in editor.find_children("ComponentValue_*","Label",true,false):
		_check(number.size.y<=32 and number.get_global_rect().end.x<=float(holder.size.x)-14,tag+": forecast values stay on one readable line inside screen")
	_check(st.to_dict()==before,tag+": forecast creates no tasting or transaction")
	await _shot(holder,tag+"_component_03_"+kind+"_ramen.png")
	var scroll: ScrollContainer=editor.find_child("DetailsScroll",true,false)
	var dishes: Control=editor.find_child("ComponentDishes",true,false)
	var original_scroll: int=scroll.scroll_vertical
	await _drag_list(holder,dishes.get_global_rect().get_center())
	_check(st.to_dict()==before,tag+": dragging rendered comparison bowls is read-only")
	if scroll.get_v_scroll_bar().max_value-scroll.get_v_scroll_bar().page>20:
		_check(scroll.scroll_vertical>original_scroll,tag+": swipe from actual bowl artwork scrolls forecast")
	var last: Label=editor.find_child("ComponentValue_윤마루",true,false)
	var candidate: Dictionary=ComponentRules.apply_recipe(st.draft_config,kind,result["recipe"])
	var known: bool=st.recipe_known(candidate) and st.recipe_known(st.draft_config)
	_check((last!=null)==known,tag+": only tried recipes expose customer-score forecasts")
	if last!=null:
		await _tap(holder,editor,"ComponentRatingsToggle")
		scroll.ensure_control_visible(last)
		await _settle()
		var customer: Dictionary=result["candidate_ramen"]["customers"][2]
		_check(last.text.contains(str(customer["score"])),tag+": rendered predicted customer score matches evaluator")
	await _shot(holder,tag+"_component_04_"+kind+"_ratings.png")
	await _tap(holder,editor,"EditorDetailsBack")

func _component_profile(tag: String, vp: Vector2i) -> void:
	var holder:=SubViewport.new()
	holder.size=vp
	holder.handle_input_locally=true
	holder.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(holder)
	var dir: String=_data_root.path_join(tag+"_component")
	_check(DirAccess.make_dir_recursive_absolute(dir)==OK,tag+": isolated directory")
	var app: Node=await _spawn(holder,dir)
	var fresh:=ActualState.new()
	_check(fresh.set_broth_blend(["chicken_bone","onion"],"standard")["ok"] and fresh.begin_broth()["ok"] and fresh.advance_broth(20.0)["ok"],tag+": partial fresh player actually crafts one soup")
	app.set("state",fresh)
	app.call("_refresh_all")
	app.call("_on_dev_pressed")
	await _settle()
	var editor: Control=app.get("_bowl_editor")
	editor.call("_show_component_comparison","broth",0)
	await _settle()
	_check((editor.find_child("ComponentWholeRamen",true,false) as Button).disabled and fresh.component_comparison("broth",0)["current_ramen"].is_empty(),tag+": incomplete player gets no phantom before score")
	await _shot(holder,tag+"_component_00_partial.png")
	var raw: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/component-v17-save.json"))
	var st:=ActualState.new()
	_check(st.load_from_dict(raw)=="",tag+": genuine pre-feature v17 loads")
	var migrated: Dictionary=st.to_dict()
	migrated.erase("recipe_knowledge"); migrated.erase("server_challenge"); migrated["schema_version"]=17
	_check(JSON.parse_string(JSON.stringify(migrated))==raw,tag+": every genuine v17 gameplay field is preserved")
	app.set("state",st)
	_check(st.set_broth_blend(["kelp"],"gentle")["ok"] and st.set_noodle_formula("cut","thick")["ok"],tag+": unfinished drafts differ from archived formulas")
	app.call("_refresh_all")
	app.call("_sync_bowl_editor")
	_check(app.call("_persist"),tag+": initial current v17 autosave")
	var saver: Object=app.get("saver")
	var disk: String=FileAccess.get_file_as_string(saver.main_path())
	var original_rows: String=JSON.stringify(st.records(),"",true)
	var original_bowl: Dictionary=st.draft_config.duplicate(true)
	editor.call("_show_component_comparison","broth",0)
	await _settle()
	_check((editor.find_child("EditorDetailApply",true,false) as Button).disabled and (editor.find_child("ComponentIntro",true,false) as Label).text.contains("지금 쓰는"),tag+": already-used formula has accurate copy and no duplicate apply action")
	await _shot(holder,tag+"_component_01_already_applied.png")
	editor.call("_show_broth_workshop","library")
	await _settle()
	await _shot(holder,tag+"_component_01_broth_library.png")
	await _capture_comparison(holder,editor,tag,"broth",1)
	_check(FileAccess.get_file_as_string(saver.main_path())==disk,tag+": reviewing and forecast never writes save")
	var money: int=st.wallet
	await _tap(holder,editor,"ComponentReload")
	_check(st.broth_review()["blend"]==st.broth_review()["recipes"][1]["recipe"] and st.draft_config==original_bowl and st.wallet==money,tag+": real reload copies only raw soup draft")
	_check((editor.find_child("EditorDetailApply",true,false) as Button).disabled,tag+": unchanged archived formula cannot charge for duplicate brew")
	await _shot(holder,tag+"_component_05_broth_reload.png")
	editor.call("_show_noodle_workshop","library")
	await _settle()
	var scroll: ScrollContainer=editor.find_child("DetailsScroll",true,false)
	var compare: Button=editor.find_child("ComponentCompare_noodle_1",true,false)
	scroll.ensure_control_visible(compare)
	await _settle()
	var before: Dictionary=st.to_dict()
	var old_scroll: int=scroll.scroll_vertical
	var feedback: Object=app.get("_juice")
	var count: int=feedback.call("acknowledgement_count")
	await _drag_list(holder,compare.get_global_rect().get_center())
	_check(st.to_dict()==before and feedback.call("acknowledgement_count")==count,tag+": library swipe cancels comparison tap and committed effect")
	if scroll.get_v_scroll_bar().max_value-scroll.get_v_scroll_bar().page>20:
		_check(scroll.scroll_vertical>old_scroll,tag+": whole library card/button swipe scrolls")
	await _capture_comparison(holder,editor,tag,"noodle",1)
	app.set("save_locked",true)
	await _tap(holder,editor,"ComponentReload")
	_check(st.noodle_review()["formula"]==st.noodle_review()["recipes"][1]["recipe"] and st.draft_config==original_bowl and st.wallet==money,tag+": noodle reload neither applies nor pays")
	_check(str(app.get("_last_save_message"))!="",tag+": reload save failure remains explicit")
	await _shot(holder,tag+"_component_06_noodle_unsaved.png")
	app.set("save_locked",false)
	_check(app.call("manual_save")["ok"] and st.wallet==money,tag+": free save retry persists reloaded formula")
	await _tap(holder,editor,"NoodleChoose_thick")
	await _tap(holder,editor,"EditorDetailApply")
	_check(st.noodle_active(),tag+": genuinely changed reloaded formula starts actual work")
	await _shot(holder,tag+"_component_07_new_work.png")
	var deadline: int=Time.get_ticks_msec()+10000
	while st.noodle_active() and Time.get_ticks_msec()<deadline: await process_frame
	_check(st.noodle_review()["recipes"].size()==3 and st.draft_config==original_bowl,tag+": real elapsed craft appends without auto-applying")
	_check((editor.get("_modal") as Control).get_meta("view_kind","")=="component_complete",tag+": actual completion has a focused result")
	await _tap(holder,editor,"ComponentCompletionLibrary")
	await _tap(holder,editor,"ComponentCompare_noodle_2")
	await _tap(holder,editor,"EditorDetailApply")
	_check(st.draft_config["noodle_recipe"]==st.noodle_review()["recipes"][2]["recipe"] and st.draft_config["broth_recipe"]==original_bowl["broth_recipe"],tag+": explicit fixed action swaps only selected component")
	await _tap(holder,editor,"EditorTaste")
	deadline=Time.get_ticks_msec()+10000
	while app.call("work_active") and Time.get_ticks_msec()<deadline: await process_frame
	_check(st.record_count()==2 and JSON.stringify(st.records().slice(0,1),"",true)==original_rows,tag+": real new tasting preserves prior immutable record")
	await _shot(holder,tag+"_component_08_revised_tasting.png")
	# Earn seven formulas by real public production; paging may never invent or
	# reorder the underlying archive. These are fixture actions, not player grants.
	for choice in [["wheat","thin","moist"],["wheat","medium","standard"],["wheat","thick","standard"],["strong","thin","standard"]]:
		for field in {"flour":choice[0],"water":"clear","cut":choice[1],"method":choice[2]}:
			var options: Dictionary={"flour":choice[0],"water":"clear","cut":choice[1],"method":choice[2]}
			_check(st.set_noodle_formula(field,options[field])["ok"],tag+": actual paging formula choice")
		_check(st.begin_noodle()["ok"] and st.advance_noodle(20.0)["ok"],tag+": actual additional paging craft")
	app.call("_refresh_all")
	app.call("_sync_bowl_editor")
	editor.call("_show_noodle_workshop","library")
	await _settle()
	_check(st.noodle_review()["recipes"].size()==7 and editor.find_child("ComponentCompare_noodle_6",true,false)!=null and editor.find_child("ComponentCompare_noodle_0",true,false)==null,tag+": first page shows newest six with stable archive indices")
	await _shot(holder,tag+"_component_09_page_one.png")
	before=st.to_dict()
	await _tap(holder,editor,"ComponentNext")
	_check(editor.find_child("ComponentCompare_noodle_0",true,false)!=null and st.to_dict()==before,tag+": older page is navigation only")
	await _shot(holder,tag+"_component_10_page_two.png")
	await _tap(holder,editor,"ComponentPrevious")
	_check(editor.find_child("ComponentCompare_noodle_6",true,false)!=null and st.to_dict()==before,tag+": returning preserves newest order and state")
	# Re-experiment from the older page; real completion must reveal the newest
	# result rather than leave it hidden behind the remembered page number.
	await _tap(holder,editor,"ComponentNext")
	await _tap(holder,editor,"ComponentCompare_noodle_0")
	await _tap(holder,editor,"ComponentReload")
	await _tap(holder,editor,"NoodleChoose_alkaline")
	await _tap(holder,editor,"EditorDetailApply")
	deadline=Time.get_ticks_msec()+10000
	while st.noodle_active() and Time.get_ticks_msec()<deadline: await process_frame
	_check(st.noodle_review()["recipes"].size()==8 and (editor.get("_modal") as Control).get_meta("component_index",-1)==7,tag+": completion from old page reveals exact newest result")
	await _shot(holder,tag+"_component_11_newest_completion.png")
	await _tap(holder,editor,"ComponentCompletionLibrary")
	_check(editor.find_child("ComponentCompare_noodle_7",true,false)!=null and editor.find_child("ComponentCompare_noodle_0",true,false)==null,tag+": completion library shortcut resets to newest six")
	_check(app.call("_persist"),tag+": save final completed experiment library")
	var loaded:=ActualState.new()
	_check(saver.load_into(loaded)["status"]=="ok" and loaded.to_dict()==st.to_dict(),tag+": exact final disk restart with raw formulas and revisions")
	app.queue_free()
	await _settle()
	holder.queue_free()
	await _settle()
	component_profiles+=1
