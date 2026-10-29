extends "res://tests/component_comparison_qa.gd"
## Actual native pointer/capture proof. Previewing is read-only; only successful
## explicit selections learn a recipe. All saves use fresh isolated directories.
const KnowledgePreview=preload("res://scripts/ui/ingredient_trial_preview.gd")
var knowledge_profiles: int=0


func _run() -> void:
	var profiles: Array=[{"tag":"portrait","size":Vector2i(390,844)},{"tag":"desktop","size":Vector2i(1280,800)}]
	if OS.get_cmdline_user_args().has("--knowledge-compact"):
		profiles=[{"tag":"compact","size":Vector2i(390,750)}]
	for profile in profiles:
		await _knowledge_profile(profile["tag"],profile["size"])
	_check(knowledge_profiles==profiles.size(),"every requested knowledge profile reaches the end")
	print("RECIPE KNOWLEDGE UI checks=%d failures=%d mode=%s" % [_checks,_failures.size(),"layout" if _layout_only else "capture"])
	for failure in _failures: printerr("FAIL: "+failure)
	quit(0 if _failures.is_empty() else 1)


func _hidden_compat(editor: Control, config: Dictionary, tag: String) -> void:
	var sheet: Control=editor.get("_modal")
	_check(sheet!=null,tag+": inspected actual modal")
	if sheet==null: return
	var notes: Array=preload("res://scripts/domain/recipe_evaluator.gd").applied_compat(config)
	for label in sheet.find_children("*","Label",true,false):
		for rule in notes:
			_check(not label.text.contains(str(rule["note"])),tag+": no unknown note exists even in folded text")
	for customer in ["박도현","이소연","윤마루"]:
		_check(sheet.find_child("ComponentValue_"+customer,true,false)==null,tag+": unknown recipe has no customer score label")


func _shot_sheet(holder: SubViewport, editor: Control, file: String) -> void:
	print("KNOWLEDGE CAPTURE ",file)
	await _settle()
	_fixed_action(editor,holder.size,file)
	for button in (editor.get("_modal") as Control).find_children("*","Button",true,false):
		if button.is_visible_in_tree():
			_check(button.get_combined_minimum_size().y>=44,file+": visible actions keep44px minimum")
	await _shot(holder,file+".png")


func _knowledge_profile(tag: String, vp: Vector2i) -> void:
	print("KNOWLEDGE PROFILE begin ",tag)
	var holder:=SubViewport.new()
	holder.size=vp
	holder.handle_input_locally=true
	holder.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(holder)
	var dir: String=_data_root.path_join(tag+"_knowledge")
	_check(DirAccess.make_dir_recursive_absolute(dir)==OK,tag+": own save directory")
	var app: Node=await _spawn(holder,dir)
	print("KNOWLEDGE PROFILE spawned ",tag)
	var raw: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/component-v17-save.json"))
	var st:=ActualState.new()
	_check(st.load_from_dict(raw)=="",tag+": genuine previous-main17 fixture migrates")
	var projected: Dictionary=st.to_dict()
	projected.erase("recipe_knowledge"); projected.erase("server_challenge")
	projected["schema_version"]=17
	_check(JSON.parse_string(JSON.stringify(projected))==raw,tag+": migration preserves every pre-feature field")
	app.set("state",st)
	app.call("_refresh_all")
	app.call("_on_dev_pressed")
	await _settle()
	var editor: Control=app.get("_bowl_editor")
	var saver: Object=app.get("saver")
	_check(app.call("_persist"),tag+": isolated migrated autosave")
	var disk: String=FileAccess.get_file_as_string(saver.main_path())
	var witness: Array=st.records()
	var before: Dictionary=st.to_dict()
	await _shot(holder,tag+"_knowledge_01_editor.png")
	print("KNOWLEDGE PROFILE first capture ",tag)
	editor.call("_show_item",IngredientCatalog.find("topping_egg"))
	await _settle()
	var properties: Control=editor.find_child("IngredientPropertiesBody",true,false)
	_check(properties!=null and not properties.visible,tag+": ingredient prose is folded by default")
	await _shot_sheet(holder,editor,tag+"_knowledge_02_ingredient")
	var toggle: Button=editor.find_child("IngredientPropertiesToggle",true,false)
	var feedback: Object=app.get("_juice")
	var clicks: int=feedback.call("acknowledgement_count")
	await _drag_list(holder,toggle.get_global_rect().get_center())
	_check(not properties.visible and st.to_dict()==before and feedback.call("acknowledgement_count")==clicks,tag+": swipe on a disclosure cancels its click and learning")
	_point(holder,toggle.get_global_rect().get_center(),true)
	await _settle()
	_check(not properties.visible,tag+": holding a detail button never activates it early")
	await _shot_sheet(holder,editor,tag+"_knowledge_02b_pressed")
	_point(holder,toggle.get_global_rect().get_center(),false)
	await _settle()
	_check(feedback.call("acknowledgement_count")==clicks+1,tag+": deliberate detail tap acknowledges exactly once")
	_check(properties.visible and st.to_dict()==before,tag+": explicit detail opens real explanation without learning")
	await _shot_sheet(holder,editor,tag+"_knowledge_03_properties")
	await _tap(holder,editor,"EditorIngredientExperiment")
	var row: Dictionary=KnowledgePreview.candidates(st,"topping_egg")["rows"][0]
	_check(not row["known"] and row["compat"].is_empty(),tag+": unknown candidate projection contains no compatibility")
	_hidden_compat(editor,row["config"],tag+" preview")
	await _shot_sheet(holder,editor,tag+"_knowledge_04_unknown")
	await _tap(holder,editor,"EditorExperimentFacts")
	_hidden_compat(editor,row["config"],tag+" facts")
	_check(st.to_dict()==before and FileAccess.get_file_as_string(saver.main_path())==disk,tag+": all preview depths leave knowledge and disk unchanged")
	await _shot_sheet(holder,editor,tag+"_knowledge_05_unknown_facts")
	await _tap(holder,editor,"EditorDetailsBack")
	var money: int=st.wallet
	await _tap(holder,editor,"EditorDetailApply")
	_check(st.draft_config==row["config"] and st.recipe_known(row["config"]),tag+": real fixed apply confirms exactly depicted recipe")
	_check(st.wallet==money and st.records()==witness,tag+": selection grants no money/record and charges no tasting")
	var restart:=ActualState.new()
	_check(saver.load_into(restart)["status"]=="ok" and restart.recipe_known(row["config"]),tag+": successful selection is remembered on disk")
	await _tap(holder,editor,"EditorCompatibility")
	var known: Control=editor.find_child("BowlKnowledge",true,false)
	_check(known!=null and known.get_meta("known")==true,tag+": explicit compatibility action shows learned state")
	await _shot_sheet(holder,editor,tag+"_knowledge_06_discovered")
	await _tap(holder,editor,"EditorDetailApply")
	# A whole-ramen score would spoil an unknown component swap too.
	var candidate: Dictionary=ComponentRules.apply_recipe(st.draft_config,"broth",st.broth_review()["recipes"][1]["recipe"])
	_check(not st.recipe_known(candidate),tag+": component candidate is genuinely untried")
	before=st.to_dict()
	editor.call("_show_component_comparison","broth",1)
	await _shot_sheet(holder,editor,tag+"_knowledge_07_component")
	await _tap(holder,editor,"ComponentValuesToggle")
	_check((editor.find_child("ComponentValuesBody",true,false) as Control).visible,tag+": component recipe and exact deltas are reachable")
	await _shot_sheet(holder,editor,tag+"_knowledge_08_component_details")
	await _tap(holder,editor,"ComponentWholeRamen")
	_hidden_compat(editor,candidate,tag+" whole ramen")
	_check(st.to_dict()==before,tag+": whole comparison cannot unlock candidate")
	await _shot_sheet(holder,editor,tag+"_knowledge_09_unknown_component")
	var scroll: ScrollContainer=editor.find_child("DetailsScroll",true,false)
	var dishes: Control=editor.find_child("ComponentDishes",true,false)
	var original_scroll: int=scroll.scroll_vertical
	await _drag_list(holder,dishes.get_global_rect().get_center())
	_check(st.to_dict()==before,tag+": artwork swipe does not apply or reveal")
	if scroll.get_v_scroll_bar().max_value-scroll.get_v_scroll_bar().page>20:
		_check(scroll.scroll_vertical>original_scroll,tag+": swiping actual bowl artwork scrolls overflowing sheet")
	await _tap(holder,editor,"EditorDetailApply")
	_check(st.recipe_known(candidate) and st.draft_config==candidate,tag+": actual component application confirms candidate")
	# Repeat the same comparison after selecting: known facts/forecast are now
	# available, and opening their details still cannot modify any game state.
	editor.call("_show_component_comparison","broth",1,true)
	await _tap(holder,editor,"ComponentRatingsToggle")
	_check(editor.find_child("ComponentValue_윤마루",true,false)!=null,tag+": known recipe exposes real customer forecast on demand")
	await _shot_sheet(holder,editor,tag+"_knowledge_10_known_component")
	# Save refusal is a real protected-store failure; it must not claim that a
	# newly learned recipe survives restart until the player retries saving.
	editor.call("_close_modal")
	app.set("save_locked",true)
	disk=FileAccess.get_file_as_string(saver.main_path())
	editor.call("_show_item",IngredientCatalog.find("oil_chili"))
	await _tap(holder,editor,"EditorDetailApply")
	var unsaved: Dictionary=st.draft_config.duplicate(true)
	_check(st.recipe_known(unsaved) and str(app.get("_last_save_message"))!="",tag+": rejected save keeps honest in-memory discovery and explicit warning")
	_check(FileAccess.get_file_as_string(saver.main_path())==disk,tag+": protected previous save remains byte-identical")
	restart=ActualState.new()
	_check(saver.load_into(restart)["status"]=="ok" and not restart.recipe_known(unsaved),tag+": unsaved experiment is not falsely claimed on disk")
	await _shot_sheet(holder,editor,tag+"_knowledge_11_unsaved")
	app.set("save_locked",false)
	_check(app.call("manual_save")["ok"],tag+": explicit save retry succeeds")
	await _settle()
	var warning: Label=editor.find_child("DevelopmentSaveWarning",true,false)
	_check(warning==null or not warning.visible,tag+": successful retry clears the warning in the still-open sheet")
	_check(not str((editor.get("_notice") as Label).text).contains("저장하지 못"),tag+": recovered save does not retain a false failure notice")
	restart=ActualState.new()
	_check(saver.load_into(restart)["status"]=="ok" and restart.recipe_known(unsaved),tag+": retry persists discovery without another selection/fee")
	var tasted: Dictionary=st.get_record(1)["config"]
	_check(st.delete_record(1)["ok"] and st.recipe_known(tasted),tag+": notebook deletion does not erase knowledge")
	_check(app.call("_persist"),tag+": persist notebook deletion")
	restart=ActualState.new()
	_check(saver.load_into(restart)["status"]=="ok" and restart.recipe_known(tasted),tag+": known recipe survives deletion and restart")
	editor.call("_show_noodle_workshop")
	await _shot_sheet(holder,editor,tag+"_knowledge_12_noodle")
	editor.call("_show_noodle_workshop","flour")
	await _settle()
	_check(editor.find_child("NoodleChoose_wheat",true,false)!=null and (editor.get("_modal") as Control).get_meta("noodle_page","")=="formula",tag+": flour shortcut stays on actual shared formula sheet")
	await _shot_sheet(holder,editor,tag+"_knowledge_13_flours")
	before=st.to_dict()
	await _tap(holder,editor,"NoodleOptionNotesToggle")
	_check((editor.find_child("NoodleOptionNotesBody",true,false) as Control).visible and st.to_dict()==before,tag+": option traits remain reachable and read-only")
	await _shot_sheet(holder,editor,tag+"_knowledge_14_flour_details")
	editor.call("_show_broth_workshop")
	await _shot_sheet(holder,editor,tag+"_knowledge_15_broth")
	editor.call("_show_noodle_workshop","library")
	await _shot_sheet(holder,editor,tag+"_knowledge_16_library")
	app.queue_free()
	holder.queue_free()
	await _settle()
	knowledge_profiles+=1
