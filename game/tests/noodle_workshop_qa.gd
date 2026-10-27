extends "res://tests/broth_workshop_qa.gd"
## Current v17 uses real input and elapsed production, with isolated autosaves.
## The parent supplies geometry/capture helpers only; replace its v16 state.
const ActualState=preload("res://scripts/domain/game_state.gd")
const Bowl=preload("res://scripts/ui/bowl_workbench.gd")
var noodle_profiles: int=0

func _run() -> void:
	for profile in [{"tag":"portrait","size":Vector2i(390,844)},{"tag":"short","size":Vector2i(390,750)},{"tag":"desktop","size":Vector2i(1280,800)}]:
		await _noodle_profile(profile["tag"],profile["size"])
	_check(noodle_profiles==3,"all current raw-noodle profiles complete")
	print("RAW NOODLE UI checks=%d failures=%d mode=%s" % [_checks,_failures.size(),"layout" if _layout_only else "capture"])
	for failure in _failures: printerr("FAIL: "+failure)
	quit(0 if _failures.is_empty() else 1)

func _noodle_profile(tag: String, vp: Vector2i) -> void:
	var holder:=SubViewport.new()
	holder.size=vp
	holder.handle_input_locally=true
	holder.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(holder)
	var dir: String=_data_root.path_join(tag+"_raw_noodle")
	_check(DirAccess.make_dir_recursive_absolute(dir)==OK,tag+": isolated save directory")
	var app: Node=await _spawn(holder,dir)
	app.set("state",ActualState.new())
	var st: ActualState=app.get("state")
	_check(st.set_broth_blend(["chicken_bone","onion"],"standard")["ok"] and st.begin_broth()["ok"] and st.advance_broth(10.0)["ok"] and st.use_broth(0)["ok"],tag+": real current broth prerequisite")
	app.call("_refresh_all")
	app.call("_on_dev_pressed")
	await _settle()
	var editor: Control=app.get("_bowl_editor")
	_check(not st.noodle_ready() and not (editor.get("_dish") as Control).visible,tag+": broth alone draws no free completed ramen")
	_check((editor.get("_taste") as Button).text=="면 개발하기",tag+": next action explains missing noodle")
	await _shot(holder,tag+"_noodle_00_first.png")
	await _tap(holder,editor,"EditorTaste")
	_fixed_action(editor,vp,tag+" formula")
	await _shot(holder,tag+"_noodle_01_formula.png")
	var scroll: ScrollContainer=editor.find_child("DetailsScroll",true,false)
	var preview: Control=editor.find_child("NoodlePreview",true,false)
	_check(preview!=null and not scroll.is_ancestor_of(preview),tag+": current food preview stays outside the scrolling choices")
	_check(editor.find_child("NoodleField_flour",true,false)==null,tag+": no field-to-subpage navigation remains")
	# Every field is a visible card on this one sheet; none is a hidden page.
	for id in ["wheat","strong","buckwheat","clear","alkaline","thin","medium","thick","standard","moist","rested"]:
		var card: Button=editor.find_child("NoodleChoose_"+id,true,false) as Button
		_check(card!=null and card.is_visible_in_tree() and scroll.is_ancestor_of(card),tag+": choice card on the formula sheet: "+id)
		if card==null: continue
		_check(card.size.y>=44 and card.size.x>=44 and card.size.y<=90,tag+": compact 44px+ choice target: "+id)
		for label in card.find_children("*","Label",true,false):
			_check(card.get_global_rect().grow(-3).encloses(label.get_global_rect()),tag+": card text clear of its border: "+id)
		_check(card.get_global_rect().position.x>=scroll.get_global_rect().position.x-1 and card.get_global_rect().end.x<=scroll.get_global_rect().end.x+1,tag+": no horizontal clipping: "+id)
	for field in ["flour","water","cut","method"]:
		var first: Control=editor.find_child("NoodleFieldSection_"+field,true,false)
		_check(first!=null and first.get_child_count()==2,tag+": "+field+" is a heading plus one compact card row")
	_check((editor.find_child("NoodleChoose_buckwheat",true,false) as Button).disabled,tag+": unearned mountain flour remains locked")
	_check((editor.find_child("NoodleChoose_rested",true,false) as Button).disabled,tag+": rank2 aging unavailable at rank1")
	_check(editor.find_child("NoodleChoose_wheat",true,false)!=null and (editor.find_child("NoodleChoose_wheat",true,false) as Button).get_theme_stylebox("normal").get("border_width_left")==4,tag+": current choice is visibly selected")
	await _shot(holder,tag+"_noodle_02_flours.png")
	var choose: Button=editor.find_child("NoodleChoose_wheat",true,false)
	scroll.ensure_control_visible(choose)
	await _settle()
	var before: Dictionary=st.to_dict()
	var old_scroll: int=scroll.scroll_vertical
	var feedback: Object=app.get("_juice")
	var acknowledgements: int=feedback.call("acknowledgement_count")
	await _drag_list(holder,choose.get_global_rect().get_center())
	_check(st.to_dict()==before and feedback.call("acknowledgement_count")==acknowledgements,tag+": scrolling from selection cancels click and committed effect")
	var overflow: float=scroll.get_v_scroll_bar().max_value-scroll.get_v_scroll_bar().page
	_check(scroll.scroll_vertical>old_scroll if overflow>0 else scroll.scroll_vertical==0,tag+": formula cards scroll only when their real content overflows")
	var food_before: Texture2D=(editor.find_child("NoodlePreviewFood",true,false) as TextureRect).texture
	await _tap(holder,editor,"NoodleChoose_strong")
	_check(st.noodle_review()["formula"]["flour"]=="strong",tag+": actual flour input")
	_check(feedback.call("acknowledgement_count")>acknowledgements,tag+": committed raw selection receives visible click feedback")
	_check((editor.find_child("NoodlePreviewName",true,false) as Label).text.contains("탄력"),tag+": preview follows flour in the same sheet")
	_check(editor.find_child("NoodleChoose_alkaline",true,false)!=null,tag+": next field needs no page change")
	await _shot(holder,tag+"_noodle_03_water.png")
	# A successful choice rebuilds the sheet; the offset must survive it.
	scroll=editor.find_child("DetailsScroll",true,false)
	var alkaline: Button=editor.find_child("NoodleChoose_alkaline",true,false)
	scroll.ensure_control_visible(alkaline)
	await _settle()
	var kept: int=scroll.scroll_vertical
	await _tap(holder,editor,"NoodleChoose_alkaline")
	scroll=editor.find_child("DetailsScroll",true,false)
	_check(st.noodle_review()["formula"]["water"]=="alkaline" and scroll.scroll_vertical==kept,tag+": scroll position survives a successful choice rebuild")
	await _tap(holder,editor,"NoodleChoose_medium")
	_check(st.noodle_review()["formula"]["cut"]=="medium" and (editor.find_child("NoodlePreviewFood",true,false) as TextureRect).texture!=food_before,tag+": cut choice changes the existing food texture preview")
	_check((editor.find_child("NoodlePreviewCost",true,false) as Label).text.contains(Bowl.won(int(st.noodle_review()["cost"]))),tag+": preview cost matches actual formula cost")
	await _shot(holder,tag+"_noodle_04_methods.png")
	await _tap(holder,editor,"NoodleChoose_moist")
	_check(st.noodle_review()["formula"]["method"]=="moist",tag+": actual dough selection")
	_check((editor.find_child("NoodleExpectedFlavor",true,false) as Label).text.contains("-1"),tag+": strong flour aroma tradeoff remains visible before final ramen clamp")
	await _shot(holder,tag+"_noodle_05_ready.png")
	var money: int=st.wallet
	await _tap(holder,editor,"EditorDetailApply")
	_check(st.noodle_active() and st.wallet==money,tag+": actual work starts with no charge")
	_fixed_action(editor,vp,tag+" active")
	await create_timer(0.8).timeout
	await _shot(holder,tag+"_noodle_06_kneading.png")
	var work: Control=editor.find_child("NoodleBoard",true,false)
	_check(float(work.get("elapsed"))>0.1 and float(work.get("progress"))>0.01,tag+": real frame time animates visible dough production")
	_check(not app.call("start_tasting")["ok"] and not app.call("manual_save")["ok"],tag+": concurrent tasting/save explicitly refused")
	await _tap(holder,editor,"EditorDetailApply")
	_check(not st.noodle_active() and st.wallet==money and st.noodle_review()["recipes"].is_empty(),tag+": actual cancel returns without fee/product")
	await _shot(holder,tag+"_noodle_07_cancelled.png")
	app.set("save_locked",true)
	await _tap(holder,editor,"EditorDetailApply")
	await create_timer(2.8).timeout
	await _shot(holder,tag+"_noodle_08_rolling.png")
	var deadline: int=Time.get_ticks_msec()+10000
	while st.noodle_active() and Time.get_ticks_msec()<deadline: await process_frame
	await _settle()
	_check(st.noodle_review()["recipes"].size()==1 and st.wallet<money and not st.noodle_ready(),tag+": real completion charges once and awaits use")
	_check(str(app.get("_last_save_message"))!="",tag+": protected-save refusal is visible")
	await _shot(holder,tag+"_noodle_09_unsaved.png")
	money=st.wallet
	app.set("save_locked",false)
	_check(app.call("manual_save")["ok"] and st.wallet==money,tag+": save retry has no second fee")
	app.call("_sync_bowl_editor")
	editor.call("_show_noodle_workshop","library")
	await _shot(holder,tag+"_noodle_10_complete.png")
	await _tap(holder,editor,"NoodleUse_0")
	_check(st.noodle_ready() and st.draft_config.has("noodle_recipe") and (editor.get("_dish") as Control).visible,tag+": explicit use assembles actual crafted ramen")
	_assert_current_stage(editor,tag+" crafted")
	await _shot(holder,tag+"_noodle_11_applied.png")
	before=st.to_dict()
	editor.call("reveal_ingredient","noodle_buckwheat")
	await _settle()
	_check((editor.get("_modal") as Control).get_meta("raw_material","")=="buckwheat" and st.to_dict()==before,tag+": mountain source points to flour without changing recipe/stock")
	_check((editor.get("_modal") as Control).get_meta("noodle_focus","")=="flour" and editor.find_child("NoodleChoose_buckwheat",true,false)!=null,tag+": source shortcut highlights the visible flour field")
	var source_scroll: ScrollContainer=editor.find_child("DetailsScroll",true,false)
	var flour_top: float=(editor.find_child("NoodleFieldSection_flour",true,false) as Control).position.y
	_check(source_scroll.scroll_vertical==int(flour_top) or source_scroll.scroll_vertical==int(source_scroll.get_v_scroll_bar().max_value),tag+": source shortcut scrolls to its field")
	await _shot(holder,tag+"_noodle_12_source.png")
	await _tap(holder,editor,"NoodleTab_cook")
	await _tap(holder,editor,"EditorAdd_cook_normal")
	await _tap(holder,editor,"EditorDetailApply")
	_check(st.draft_config["cook"]=="cook_normal",tag+": existing firmness selection remains reachable")
	await _tap(holder,editor,"EditorTaste")
	deadline=Time.get_ticks_msec()+10000
	while app.call("work_active") and Time.get_ticks_msec()<deadline: await process_frame
	_check(st.record_count()==1,tag+": actual elapsed tasting records both crafted components")
	await _shot(holder,tag+"_noodle_13_tasted.png")
	var loaded:=ActualState.new()
	var saver: Object=app.get("saver")
	_check(saver.load_into(loaded)["status"]=="ok" and loaded.to_dict()==st.to_dict(),tag+": exact autosave with raw broth and noodle witnesses")
	app.queue_free()
	await _settle()
	holder.queue_free()
	await _settle()
	noodle_profiles+=1
