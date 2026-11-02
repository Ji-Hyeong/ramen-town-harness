extends "res://tests/component_comparison_qa.gd"
## Actual paid ownership is built separately per viewport. No legacy app-state
## fixture or progress/cash injection substitutes for the full working shelf.
const ShelfActual=preload("res://tests/broth_shelf_tests.gd")
const CueBroth=preload("res://scripts/domain/broth_workshop.gd")
const CueMethods=preload("res://scripts/domain/recipe_process.gd")
var _shelf_profiles: int=0
var _shelf_finished: bool=false

func _json(st: Object) -> String:
	return JSON.stringify(st.to_dict(),"",true)

func _run() -> void:
	create_timer(300.0).timeout.connect(func():
		if not _shelf_finished:printerr("SHELF QA TIMEOUT");quit(1))
	for profile in [{"tag":"portrait","size":Vector2i(390,844)},{"tag":"desktop","size":Vector2i(1280,800)},{"tag":"compact","size":Vector2i(390,750)}]:await _shelf_flow(profile["tag"],profile["size"])
	_check(_shelf_profiles==3,"all three actual shelf UI profiles finish")
	_shelf_finished=true
	print("BROTH SHELF UI checks=%d failures=%d mode=%s" % [_checks,_failures.size(),"layout-only" if _layout_only else "capture"])
	for failure in _failures:printerr("FAIL: "+failure)
	quit(0 if _failures.is_empty() else 1)

func _shelf_spawn(holder: SubViewport,folder: String) -> Node:
	var scene: PackedScene=load("res://scenes/main.tscn")
	var app: Node=scene.instantiate()
	app.set("data_location",{"ok":true,"dir":folder,"is_dev":true,"error":""})
	holder.add_child(app);app.set_process(false)
	await _settle()
	_check(not app.get("save_locked"),"isolated current raw app startup succeeds")
	return app

func _shelf_open(app: Node) -> Control:
	app.call("_refresh_all");app.call("_open_overlay",0);app.call("_sync_bowl_editor")
	var editor: Control=app.get("_bowl_editor")
	editor.call("_show_broth_workshop","library")
	await _settle()
	return editor

func _shelf_bounds(editor: Control,vp: Vector2i) -> void:
	_fixed_action(editor,vp,"broth shelf")
	var st: Object=editor.get("state")
	for flow in editor.find_children("BrothRecipeCues_*","HFlowContainer",true,false):
		var index: int=flow.get_meta("recipe_index")
		var recipe: Dictionary=st.broth_review()["recipes"][index]["recipe"]
		_check_cues(flow,recipe,vp.x-14)
		var facts: Label=editor.find_child("ComponentLibraryFacts_broth_"+str(index),true,false)
		var item: Dictionary=st.component_comparison("broth",index)["selected_component"]
		_check(facts!=null and facts.text.replace(",","")=="한 그릇 %d원 · 준비 %d초 · %s" % [item["cost"],item["seconds"],CueMethods.method("broth",recipe["method"])["name"]],"owned method and once-applied cost/time facts match exact comparison")
	for name in ["BrothShelfWorking","BrothShelfArchive"]:
		var button: Button=editor.find_child(name,true,false)
		_check(button!=null and button.size.y>=44 and button.get_global_rect().position.x>=14 and button.get_global_rect().end.x<=vp.x-14,"fixed shelf category remains padded and usable: "+name)
	for label in editor.find_children("*","Label",true,false):
		if label.is_visible_in_tree():_check(_text_height_fits(label),"full shelf label fits: "+label.name)

## Inspect actual laid-out child rectangles, not only a configured wrap flag.
## Catalog quantities come from the owned recipe, never its generic pot title.
func _check_cues(flow: HFlowContainer,recipe: Dictionary,right: float) -> void:
	var seen: Array=[]
	for id in recipe["ingredients"]:
		if not seen.has(id):seen.append(id)
	_check(flow.get_child_count()==seen.size(),"one complete icon/name group per distinct ingredient")
	for i in seen.size():
		var group: HBoxContainer=flow.get_child(i)
		var icon: TextureRect=group.get_child(0)
		var label: Label=group.get_child(1)
		var id: String=seen[i]
		_check(label.text=="%s ×%d" % [CueBroth.material(id)["name"],recipe["ingredients"].count(id)],"owned raw name and repeated portion count are explicit")
		_check(icon.texture!=null and icon.size.x>=24 and icon.size.y>=24,"raw pantry artwork is visible at readable size")
		_check(group.get_global_rect().end.x<=right and group.get_global_rect().position.x>=14,"whole ingredient group stays within padded content width")
		_check(group.get_global_rect().encloses(label.get_global_rect()) and _text_height_fits(label),"ingredient name/count stays whole inside its group")
		_check(label.mouse_filter==Control.MOUSE_FILTER_IGNORE and icon.mouse_filter==Control.MOUSE_FILTER_IGNORE and group.mouse_filter==Control.MOUSE_FILTER_PASS,"ingredient cues pass list gestures without new actions")

func _cue_boundaries(holder: SubViewport,editor: Control) -> void:
	# Synthetic layout only: these legal rank3 formulas are not granted/earned.
	# Reuse the actual narrow card width, without altering state or disk data.
	var actual: HFlowContainer=editor.find_children("BrothRecipeCues_*","HFlowContainer",true,false)[0]
	var probe:=VBoxContainer.new();probe.position=Vector2(16,16);probe.size.x=actual.size.x;holder.add_child(probe)
	var before: String=_json(editor.get("state"))
	for ids in [["kelp","kelp","kelp","kelp","kelp"],["chicken_bone","kelp","sardine","shiitake","ginger"],["pork_bone","chicken_bone","kelp","garlic","onion"]]:
		var recipe: Dictionary={"ingredients":ids,"method":"rolling"}
		_check(CueBroth.error(recipe,3)=="","synthetic maximum-portion layout formula is legal")
		editor.call("_broth_library_cues",probe,recipe,999)
		await _settle()
		var flow: HFlowContainer=probe.get_child(0)
		_check_cues(flow,recipe,16+actual.size.x)
		_check(flow.size.y<=84,"maximum five raw ingredients use at most three compact rows")
		flow.queue_free();await _settle()
	_check(_json(editor.get("state"))==before,"synthetic render probes neither grant ingredients nor mutate gameplay")
	probe.queue_free();await _settle()

func _shelf_flow(tag: String,vp: Vector2i) -> void:
	var holder:=SubViewport.new();holder.size=vp;holder.handle_input_locally=true;holder.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(holder)
	var folder: String=_data_root.path_join(tag+"_shelf")
	_check(DirAccess.make_dir_recursive_absolute(folder)==OK,"new owned shelf UI data directory")
	var fixture:=ShelfActual.new();fixture.check=_check
	var earned: Dictionary=fixture.make_full()
	if earned.is_empty():return
	var state: Object=earned["state"]
	var app: Node=await _shelf_spawn(holder,folder)
	app.set("state",state)
	var editor: Control=await _shelf_open(app)
	_check(app.call("_persist","actual full shelf baseline"),"actual manufactured baseline saves")
	await _shelf_bounds(editor,vp)
	await _shot(holder,tag+"_shelf_01_full_working.png")
	var original_records: String=JSON.stringify(state.records(),"",true)
	var before: String=_json(state)
	var cue: Control=editor.find_child("BrothRecipeCues_59",true,false)
	var scroll: ScrollContainer=editor.find_child("DetailsScroll",true,false)
	var old_scroll: int=scroll.scroll_vertical
	await _drag_list(holder,cue.get_global_rect().get_center())
	_check(scroll.scroll_vertical>old_scroll and _json(state)==before,"swiping actual ingredient icons scrolls without applying or archiving")
	var archive: Button=editor.find_child("BrothArchive_59",true,false)
	_check(archive!=null,"newest currently used formula has an archive control")
	var ack: int=app.get("_juice").acknowledgement_count()
	if archive!=null:
		(editor.find_child("DetailsScroll",true,false) as ScrollContainer).ensure_control_visible(archive);await _settle()
		var point: Vector2=archive.get_global_rect().get_center()
		_point(holder,point,true);await _settle()
		_check(_json(state)==before,"holding archive does not transact")
		await _shot(holder,tag+"_shelf_02_pressed.png")
		for i in 6:
			var motion:=InputEventMouseMotion.new();motion.position=point+Vector2(0,-12);motion.global_position=motion.position;motion.relative=Vector2(0,-12);motion.button_mask=MOUSE_BUTTON_MASK_LEFT;holder.push_input(motion);point=motion.position;await _frames(1)
		_point(holder,point,false);await _settle()
		_check(_json(state)==before and app.get("_juice").acknowledgement_count()==ack,"swiping archive cancels transaction and action feedback")
	await _tap(holder,editor,"BrothArchive_59")
	_check(state.broth_review()["working_count"]==59 and app.get("_juice").acknowledgement_count()>ack,"actual archive click refreshes same view and acknowledges action")
	await _tap(holder,editor,"BrothShelfArchive")
	await _shelf_bounds(editor,vp)
	await _shot(holder,tag+"_shelf_03_archived.png")
	before=_json(state)
	await _tap(holder,editor,"BrothUse_59")
	_check(_json(state)==before,"using an already-applied archived formula has no hidden fee/restore or grant")
	editor=await _shelf_open(app)
	var recipe: Dictionary=earned["next_recipe"]
	_check(state.set_broth_blend(recipe["ingredients"],recipe["method"])["ok"],"explicit legal distinct61st blend")
	editor.call("_show_broth_workshop");await _settle()
	var money: int=state.wallet;var fee: int=state.broth_review()["cost"]
	await _tap(holder,editor,"EditorDetailApply")
	_check(state.broth_active() and state.wallet==money,"actual click starts timed brew without early charge")
	app.call("_process",1.0);await _settle()
	await _shot(holder,tag+"_shelf_04_brewing.png")
	app.call("_process",20.0);await _settle()
	_check(state.broth_review()["recipes"].size()==61 and state.wallet==money-fee,"actual controller completes and charges61st broth exactly once")
	_check(JSON.stringify(state.records(),"",true)==original_records,"all60historical raw records stay byte-equivalent")
	await _shot(holder,tag+"_shelf_05_complete61.png")
	await _tap(holder,editor,"ComponentCompletionLibrary")
	await _tap(holder,editor,"BrothShelfArchive")
	var restore: Button=editor.find_child("BrothRestore_59",true,false)
	_check(restore!=null and restore.disabled,"full working shelf honestly disables restoration")
	_check(editor.find_child("BrothShelfFullHint",true,false)!=null,"full restore reason is visible without hovering")
	await _shot(holder,tag+"_shelf_06_restore_full.png")
	before=_json(state)
	await _tap(holder,editor,"EditorDetailApply")
	_check(editor.find_child("BrothArchive_60",true,false)!=null and _json(state)==before,"fixed full-shelf action opens working notes without a transaction")
	await _tap(holder,editor,"BrothArchive_60")
	await _tap(holder,editor,"BrothShelfArchive")
	money=state.wallet
	await _tap(holder,editor,"BrothRestore_59")
	_check(state.broth_review()["working_count"]==60 and state.wallet==money,"actual restore is free and only moves exact original formula")
	await _shot(holder,tag+"_shelf_07_restored.png")
	await _tap(holder,editor,"BrothUse_60")
	_check(state.broth_ready() and state.wallet==money and state.to_dict()["broth_shelf"]["archived"].size()==1,"new archived formula applies without hidden restore or new fee")
	# Controller-only tasting is transient; actual guarded shelf controls cannot
	# mutate it even though the pure game state has no tasting clock itself.
	_check(app.call("start_tasting")["ok"],"actual timed tasting begins")
	editor=await _shelf_open(app)
	await _tap(holder,editor,"BrothShelfWorking")
	var blocked: Button=editor.find_child("BrothArchive_59",true,false)
	_check(blocked!=null and blocked.disabled,"timed tasting disables shelf actions")
	before=_json(state);app.call("_on_broth_action","broth_archive",{"index":59})
	_check(_json(state)==before,"stale shelf command during tasting is rejected")
	app.call("_on_work_cancel");await _settle()
	editor=await _shelf_open(app)
	await _tap(holder,editor,"BrothShelfWorking")
	var saver: Object=app.get("saver")
	var old_disk: String=FileAccess.get_file_as_string(saver.main_path())
	_check(DirAccess.make_dir_recursive_absolute(saver.tmp_path())==OK,"real scoped shelf write conflict")
	await _tap(holder,editor,"BrothArchive_59")
	_check(app.get("_save_error_shown") and FileAccess.get_file_as_string(saver.main_path())==old_disk,"failed archive save preserves old disk and reports failure")
	var warning: Label=editor.find_child("DevelopmentSaveWarning",true,false)
	_check(warning!=null and warning.visible and warning.text!="","same open library shows honest unsaved warning")
	await _shot(holder,tag+"_shelf_08_unsaved.png")
	before=_json(state)
	_check(DirAccess.remove_absolute(saver.tmp_path())==OK,"remove only owned empty QA conflict")
	app.call("_on_manual_save_pressed");await _settle()
	_check(not app.get("_save_error_shown") and _json(state)==before,"actual manual save recovery changes no game value")
	editor=await _shelf_open(app)
	await _tap(holder,editor,"BrothShelfArchive")
	await _shelf_bounds(editor,vp)
	await _shot(holder,tag+"_shelf_09_recovered.png")
	app.queue_free();await _settle();app=await _shelf_spawn(holder,folder)
	_check(_json(app.get("state"))==before,"actual scene restart preserves all61owned formulas/archive/records/cash")
	editor=await _shelf_open(app)
	await _tap(holder,editor,"BrothShelfArchive")
	await _shelf_bounds(editor,vp)
	await _shot(holder,tag+"_shelf_10_restart.png")
	await _cue_boundaries(holder,editor)
	_shelf_profiles+=1;app.queue_free();await _settle();holder.queue_free();await _settle()
