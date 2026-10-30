extends "res://tests/foraging_encounters_qa.gd"
## The checkpoint was earned through real raw production/farming. Continue with
## paid regional tasting and real finished service, never injected progress.
const SalesView=preload("res://scripts/ui/foraging_sales_followup.gd")
var _sales_profiles: int=0

func _run() -> void:
	for profile in [{"tag":"portrait","size":Vector2i(390,844)},{"tag":"desktop","size":Vector2i(1280,800)},{"tag":"compact","size":Vector2i(390,750)}]:
		await _sales_flow(profile["tag"],profile["size"])
	_check(_sales_profiles==3,"all actual sales-follow-up profiles finish")
	print("FORAGING SALES LOOP checks=%d failures=%d mode=%s" % [_checks,_failures.size(),"layout-only" if _layout_only else "capture"])
	for failure in _failures:printerr("FAIL: "+failure)
	quit(0 if _failures.is_empty() else 1)

## Inherited farming helpers also request legacy screenshots. This bounded QA
## intentionally captures only its own new sales stages; old helper checks run.
func _shot(holder: SubViewport,file_name: String) -> void:
	if file_name.contains("_sales_"):await super._shot(holder,file_name)

func _sales_open(holder: SubViewport,app: Node,id: String) -> Control:
	app.call("_open_overlay",0)
	var editor: Control=app.get("_bowl_editor")
	editor.call("_show_directions");await _settle()
	await _tap(holder,editor,"GoalGroup_cross_region")
	await _tap(holder,editor,"GoalOpen_"+id)
	return editor

func _sales_reveal(holder: SubViewport,editor: Control,id: String,title: String) -> Button:
	var button: Button=editor.find_child("GoalSales_"+id,true,false)
	_check(button!=null,"actual research-to-selling card exists")
	if button==null:return null
	var scroll: ScrollContainer=editor.find_child("DetailsScroll",true,false)
	scroll.ensure_control_visible(button);await _settle()
	var card: Control=editor.find_child("GoalSales_"+id+"Card",true,false)
	_check(Rect2(Vector2.ZERO,Vector2(holder.size)).encloses(button.get_global_rect()),"whole sales card reaches actual viewport")
	_check(button.size.y>=78,"sales card retains touch-sized padded geometry")
	var heading: Label=card.find_child("GoalCardTitle",true,false)
	_check(heading.text==title,"research follow-up shows the actual stage: "+title)
	for label in card.find_children("*","Label",true,false):
		_check(_text_height_fits(label) and card.get_global_rect().grow(-9).encloses(label.get_global_rect()),"sales title/hint fit actual frame padding")
	return button

func _sales_service(holder: SubViewport,app: Node) -> void:
	app.call("_close_overlay");app.call("_refresh_all");await _settle()
	var st: Object=app.get("state")
	var day: int=st.day
	await _tap(holder,app,"StartServiceButton")
	_check(st.service_active() and st.day==day,"actual explicit start never settles early")
	_advance(app,6000.0);app.call("_process",0.0);await _settle()
	_check(not st.service_active() and st.day==day+1 and st.last_report["units"]>0,"actual finished orders settle once")
	app.call("_on_result_ok");await _settle()

func _sales_flow(tag: String,vp: Vector2i) -> void:
	var holder:=SubViewport.new();holder.size=vp;holder.handle_input_locally=true;holder.render_target_update_mode=SubViewport.UPDATE_ALWAYS;holder.set_meta("qa_tag",tag);root.add_child(holder)
	var dir: String=_data_root.path_join(tag+"_sales")
	_check(DirAccess.make_dir_recursive_absolute(dir)==OK,"isolated sales-follow-up storage")
	var app: Node=await _spawn(holder,dir);app.set_process(false)
	var st:=Actual.new();var checkpoint: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/foraging-earned-v18-save.json"))
	_check(st.load_from_dict(checkpoint)=="" and not st.to_dict()["broth_workshop"]["legacy"] and not st.to_dict()["noodle_workshop"]["legacy"],"actual earned raw/farming checkpoint, no legacy ingredients")
	app.set("state",st);app.call("_refresh_all")
	var old_id: int=st.selected_record_id
	_check(st.set_selling_menus([old_id])["ok"],"explicit unrelated selling witness remains pinned while researching")
	var id: String="citrus_scallop"
	var before: String=_ledger(st)
	var editor: Control=await _sales_open(holder,app,id)
	_check(editor.find_child("GoalSales_"+id,true,false)==null and _ledger(st)==before,"untried research does not invent a paid/selling step")
	await _shot(holder,tag+"_sales_01_untried.png")
	await _tap(holder,editor,"EditorDetailsBack")
	await _experiment(holder,app,id,0,tag)
	var paid: int=st.last_feedback_record_id
	editor=await _sales_open(holder,app,id)
	var button: Button=await _sales_reveal(holder,editor,id,"판매 메뉴 고르기")
	before=_ledger(st)
	await _shot(holder,tag+"_sales_02_choose.png")
	if button!=null:
		var acks: int=app.get("_juice").acknowledgement_count()
		_point(holder,button.get_global_rect().get_center(),true);await _settle()
		var card: Control=editor.find_child("GoalSales_"+id+"Card",true,false)
		for text in card.find_children("*","Label",true,false):_check(text.get_theme_color("font_color")==Color.WHITE,"held sales card text is actually white")
		await _shot(holder,tag+"_sales_03_pressed.png")
		var point: Vector2=button.get_global_rect().get_center()
		for step in 6:
			var motion:=InputEventMouseMotion.new();motion.position=point+Vector2(0,-12);motion.global_position=motion.position;motion.relative=Vector2(0,-12);motion.button_mask=MOUSE_BUTTON_MASK_LEFT;holder.push_input(motion);point=motion.position;await _frames(1)
		_point(holder,point,false);await _settle()
		_check(editor.get("_modal")!=null and _ledger(st)==before and app.get("_juice").acknowledgement_count()==acks,"drag cancels sales route and success feedback without changing ledger")
	# Refresh the same still-open board when only selling selection changes.
	# A cache keyed only by ingredient/tested flags would keep the old stage.
	var live_board: Control=editor.find_child("ForagingGoalBoard",true,false)
	_check(st.set_selling_menus([paid])["ok"],"explicit matching selection for live-detail refresh")
	live_board.call("present",st,str(app.get("_direction_target")),false);await _settle()
	await _sales_reveal(holder,editor,id,"영업으로 확인하기")
	_check(st.set_selling_menus([old_id])["ok"],"explicit restore of unrelated selected menu")
	live_board.call("present",st,str(app.get("_direction_target")),false);await _settle()
	await _sales_reveal(holder,editor,id,"판매 메뉴 고르기")
	_check(_ledger(st)==before,"live-detail selection roundtrip preserves the complete original ledger")
	await _tap(holder,editor,"GoalSales_"+id)
	_check(app.get("tabs").current_tab==3 and app.get("_operations_view").visible and _ledger(st)==before,"actual sales card opens existing preparation only, no implicit selection/start/payment")
	await _shot(holder,tag+"_sales_04_preparation.png")
	_check(st.set_selling_menus([paid])["ok"],"explicit paid research menu selection")
	editor=await _sales_open(holder,app,id)
	await _sales_reveal(holder,editor,id,"영업으로 확인하기")
	await _shot(holder,tag+"_sales_05_ready.png")
	var board: Control=editor.find_child("ForagingGoalBoard",true,false)
	board.call("present",st,str(app.get("_direction_target")),true);await _settle()
	_check((editor.find_child("GoalSales_"+id,true,false) as Button).disabled,"busy sales follow-up cannot navigate")
	board.call("present",st,str(app.get("_direction_target")),false);await _settle()
	await _sales_service(holder,app)
	var single: Dictionary=SalesView.describe(st,id)
	_check(single["stage"]=="sold" and single["units"]==st.last_report["units"] and single["record_id"]==paid,"actual single-menu receipt is the completed research menu")
	editor=await _sales_open(holder,app,id);await _sales_reveal(holder,editor,id,str(single["title"]))
	await _shot(holder,tag+"_sales_06_sold.png")
	await _tap(holder,editor,"EditorDetailsBack")
	# Second real regional recipe plus real paid expansion exercise shared menu
	# service. Counts must come from the matching row, never all served diners.
	await _experiment(holder,app,"sesame_buckwheat",1,tag)
	var other: int=st.last_feedback_record_id
	_check(st.expand_shop()["ok"] and st.set_selling_menus([paid,other])["ok"],"actual paid expansion and explicit two-menu selection")
	await _sales_service(holder,app)
	var expected: int=0
	for row in st.last_report["menus"]:
		if row["record_id"]==paid:expected=int(row["units"])
	var multi: Dictionary=SalesView.describe(st,id)
	_check(expected>0 and multi["units"]==expected and multi["record_id"]==paid,"actual two-menu result counts this dish only")
	_check(multi["units"]<st.last_report["units"],"other menu's completed orders are not added to this dish")
	_check(st.set_draft_toppings(["topping_nori"])["ok"] and SalesView.describe(st,id)==multi,"later unrelated draft cannot replace sold food snapshot")
	editor=await _sales_open(holder,app,id);await _sales_reveal(holder,editor,id,str(multi["title"]))
	await _shot(holder,tag+"_sales_07_shared.png")
	var prior_receipt_day: int=int(multi["day"])
	_check(st.begin_service()["ok"],"actual another service starts while read-only model retains prior receipt")
	_check(SalesView.describe(st,id)==multi,"active session and forecast are not a new completed sale")
	st.active_session().run_to_end()
	_check(st.settle_service()["ok"],"actual next receipt completes through public transaction")
	board=editor.find_child("ForagingGoalBoard",true,false)
	board.call("present",st,str(app.get("_direction_target")),false);await _settle()
	multi=SalesView.describe(st,id)
	_check(board.call("shown_model")["sale"]==multi and multi["day"]>prior_receipt_day,"same open detail refreshes for a new actual receipt without a new recipe or stock")
	before=_ledger(st)
	# Refresh the still-open detail when only selling changes: its cache must
	# include this projection, not just ingredient stock and tested flags.
	_check(st.set_selling_menus([old_id])["ok"],"explicit unrelated next selling selection")
	board=editor.find_child("ForagingGoalBoard",true,false)
	board.call("present",st,str(app.get("_direction_target")),false);await _settle()
	_check(board.call("shown_model")["sale"]["stage"]=="sold","recent actual sale remains visible after selecting another menu")
	_check(st.delete_record(paid)["ok"] and SalesView.describe(st,id)==multi,"deleting paid notebook witness preserves actual immutable sale evidence")
	_check(app.call("manual_save")["ok"],"actual follow-up state saves")
	before=_ledger(st);app.queue_free();await _settle();app=await _spawn(holder,dir);app.set_process(false)
	st=app.get("state");_check(_ledger(st)==before and SalesView.describe(st,id)==multi,"whole save and recent sale exact after disk restart")
	editor=await _sales_open(holder,app,id);await _sales_reveal(holder,editor,id,str(multi["title"]))
	await _shot(holder,tag+"_sales_08_restart.png")
	_check(_ledger(st)==before,"reopening sales evidence cannot change any saved field")
	_sales_profiles+=1;app.queue_free();await _settle();holder.queue_free();await _settle()
