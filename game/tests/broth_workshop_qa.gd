extends "res://tests/bowl_editor_qa.gd"
## A historical schema16 broth-only new player, unlike the historical workbench fixtures.
## Use actual input, real elapsed brewing, isolated saves and rendered captures.
const CurrentState=preload("res://tests/broth_game_fixture.gd")
const BrothRules=preload("res://scripts/domain/broth_workshop.gd")
var profiles_done: int=0

func _run() -> void:
	for profile in [{"tag":"portrait","size":Vector2i(390,844)},{"tag":"desktop","size":Vector2i(1280,800)}]:
		await _broth_profile(profile["tag"],profile["size"])
	_check(profiles_done==2,"both current new-game profiles complete")
	print("RAW BROTH UI checks=%d failures=%d mode=%s" % [_checks,_failures.size(),"layout" if _layout_only else "capture"])
	for failure in _failures: printerr("FAIL: "+failure)
	quit(0 if _failures.is_empty() else 1)

func _fixed_action(editor: Control, vp: Vector2i, tag: String) -> void:
	var action: Button=editor.find_child("EditorDetailApply",true,false)
	_check(action!=null,tag+": workshop fixed action exists")
	if action!=null:
		_check(Rect2(Vector2.ZERO,Vector2(vp)).encloses(action.get_global_rect()),tag+": complete primary action fits viewport")
		_check(action.size.y>=44,tag+": primary touch height at least44")
	var scroll: ScrollContainer=editor.find_child("DetailsScroll",true,false)
	_check(scroll.size.y>=120,tag+": useful scrollable selection body")
	_check(scroll.get_global_rect().end.y<=action.get_global_rect().position.y,tag+": scrolling list cannot cover fixed action")

func _broth_profile(tag: String, vp: Vector2i) -> void:
	var holder:=SubViewport.new()
	holder.size=vp
	holder.handle_input_locally=true
	holder.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(holder)
	var dir: String=_data_root.path_join(tag+"_raw_broth")
	_check(DirAccess.make_dir_recursive_absolute(dir)==OK,tag+": isolated directory")
	var app: Node=await _spawn(holder,dir)
	# Explicitly replace the inherited historical fixture before testing a
	# current fresh game. Production constructors never use the v15 fixture.
	app.set("state",CurrentState.new())
	app.call("_refresh_all")
	app.call("_on_dev_pressed")
	await _settle()
	var st: CurrentState=app.get("state")
	var editor: Control=app.get("_bowl_editor")
	_check(not st.broth_ready() and not (editor.get("_dish") as Control).visible,tag+": no free completed soup is drawn")
	_check((editor.get("_taste") as Button).text=="육수 개발하기",tag+": first action directs to broth development")
	await _shot(holder,tag+"_broth_00_first.png")
	await _tap(holder,editor,"EditorTaste")
	_fixed_action(editor,vp,tag)
	_check((editor.find_child("EditorDetailApply",true,false) as Button).disabled,tag+": empty blend cannot start")
	await _shot(holder,tag+"_broth_01_empty.png")
	await _tap(holder,editor,"BrothDetail_pork_bone")
	_check(editor.find_child("DetailsBody",true,false).get_child_count()>=4,tag+": raw ingredient has focused details")
	await _shot(holder,tag+"_broth_02_raw_detail.png")
	await _tap(holder,editor,"EditorDetailsBack")
	await _tap(holder,editor,"BrothAdd_pork_bone")
	await _tap(holder,editor,"BrothAdd_chicken_bone")
	await _tap(holder,editor,"BrothAdd_garlic")
	_check(st.broth_review()["blend"]["ingredients"].size()==3,tag+": actual card input adds raw portions")
	_check((editor.find_child("BrothAdd_pork_bone",true,false) as Button).disabled,tag+": full capacity disables adding")
	await _tap(holder,editor,"BrothPortion_2")
	_check(st.broth_review()["blend"]["ingredients"].size()==2,tag+": actual portion removal")
	var scroll: ScrollContainer=editor.find_child("DetailsScroll",true,false)
	var add: Button=editor.find_child("BrothAdd_pork_bone",true,false)
	scroll.ensure_control_visible(add)
	await _settle()
	var before: Dictionary=st.to_dict()
	var old_scroll: int=scroll.scroll_vertical
	await _drag_list(holder,add.get_global_rect().get_center())
	_check(st.to_dict()==before,tag+": scrolling from a raw add button does not add ingredients")
	_check(scroll.scroll_vertical>old_scroll,tag+": whole raw card swipe scrolls selection body")
	await _tap(holder,editor,"BrothAdd_garlic")
	await _tap(holder,editor,"BrothMethod_gentle")
	await _shot(holder,tag+"_broth_03_blend.png")
	var money: int=st.wallet
	await _tap(holder,editor,"EditorDetailApply")
	_check(st.broth_active() and st.wallet==money,tag+": starting real work charges nothing")
	await _shot(holder,tag+"_broth_04_brewing.png")
	_check(not app.call("start_tasting")["ok"] and not app.call("work_active"),tag+": controller cannot start ramen concurrently with raw brewing")
	_check(not app.call("manual_save")["ok"],tag+": unfinished brewing is not presented as saved work")
	await _tap(holder,editor,"EditorDetailApply")
	_check(not st.broth_active() and st.wallet==money and st.broth_review()["recipes"].is_empty(),tag+": actual cancel button cancels without cost")
	await _shot(holder,tag+"_broth_05_cancel.png")
	# Force the existing protected-save refusal during real completion. The
	# result remains usable in memory, with an explicit warning and safe retry.
	app.set("save_locked",true)
	await _tap(holder,editor,"EditorDetailApply")
	var deadline: int=Time.get_ticks_msec()+10000
	while st.broth_active() and Time.get_ticks_msec()<deadline: await process_frame
	_check(not st.broth_active() and st.broth_review()["recipes"].size()==1,tag+": actual elapsed time finishes one broth")
	_check(st.wallet<money and not st.broth_ready(),tag+": completion charges once and awaits explicit use")
	await _settle()
	_fixed_action(editor,vp,tag+" completed")
	_check(str(app.get("_last_save_message"))!="",tag+": completion save refusal is explicit")
	await _shot(holder,tag+"_broth_06_unsaved.png")
	app.set("save_locked",false)
	_check(app.call("manual_save")["ok"],tag+": save retry persists without another brew or charge")
	app.call("_sync_bowl_editor")
	editor.call("_show_broth_workshop","library")
	await _shot(holder,tag+"_broth_06_complete.png")
	await _tap(holder,editor,"BrothUse_0")
	_check(st.broth_ready() and st.draft_config.has("broth_recipe"),tag+": actual use action applies crafted provenance")
	_check((editor.get("_dish") as Control).visible,tag+": actual assembled bowl becomes visible")
	await _shot(holder,tag+"_broth_07_applied.png")
	before=st.to_dict()
	editor.call("reveal_ingredient","broth_roasted_sardine")
	await _settle()
	_check((editor.get("_modal") as Control).get_meta("raw_material","")=="sardine",tag+": old supplier ID opens actual raw material instead of a premade replacement")
	_check(st.to_dict()==before,tag+": source handoff preserves current broth/blend/stock/money")
	await _shot(holder,tag+"_broth_07_source.png")
	await _tap(holder,editor,"EditorDetailsBack")
	await _tap(holder,editor,"EditorDetailsBack")
	await _tap(holder,editor,"EditorTaste")
	deadline=Time.get_ticks_msec()+10000
	while app.call("work_active") and Time.get_ticks_msec()<deadline: await process_frame
	_check(st.record_count()==1,tag+": existing tasting completes with actual crafted soup")
	await _shot(holder,tag+"_broth_08_tasted.png")
	var loaded:=CurrentState.new()
	var saver: Object=app.get("saver")
	_check(saver.load_into(loaded)["status"]=="ok" and loaded.to_dict()==st.to_dict(),tag+": autosave contains completed broth and ramen")
	app.queue_free()
	await _settle()
	holder.queue_free()
	await _settle()
	profiles_done+=1
