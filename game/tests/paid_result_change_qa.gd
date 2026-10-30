extends "res://tests/bowl_editor_qa.gd"
## Replay actual paid revisions against old/new UI. BASELINE_MODE changes only
## title expectations; production rules, transactions and player fixtures agree.
const BASELINE_MODE: bool=false
const PaidFixture=preload("res://tests/known_change_fixtures.gd")
const PaidState=preload("res://scripts/domain/game_state.gd")
var _paid_profiles: int=0

## Synthetic view-only coverage: a paid ledger is valid, but the host withholds
## knowledge. This is not evidence of a naturally earned unknown paid recipe.
class HiddenKnowledgeState:
	extends "res://scripts/domain/game_state.gd"
	func recipe_known(_config: Dictionary) -> bool:
		return false

func _run() -> void:
	for profile in [{"tag":"portrait","size":Vector2i(390,844)},{"tag":"desktop","size":Vector2i(1280,800)},{"tag":"compact","size":Vector2i(390,750)}]:
		await _paid_flow(profile["tag"],profile["size"])
	_check(_paid_profiles==3,"all paid-result profiles finish")
	print("PAID RESULT CHANGE baseline=%s mode=%s checks=%d failures=%d" % [BASELINE_MODE,"layout-only" if _layout_only else "capture",_checks,_failures.size()])
	for failure in _failures:printerr("FAIL: "+failure)
	quit(0 if _failures.is_empty() else 1)

func _paid_ledger(st: Object) -> String:
	return JSON.stringify(st.to_dict(),"",true)

func _paid_open(app: Node) -> Control:
	app.call("_refresh_all");app.call("_open_overlay",1);await _settle()
	return app.get("_bowl_editor")

func _paid_button(holder: SubViewport,editor: Control,title: String) -> Button:
	var button: Button=editor.find_child("EditorRevisionSummary",true,false)
	_check(button!=null,"actual paid revision action exists")
	if button==null:return null
	var expected: String="이번 개량의 변화" if BASELINE_MODE else title
	_check(button.text==expected,"actual paid record determines short title: "+title)
	var scroll: ScrollContainer=editor.get("_scroll")
	scroll.ensure_control_visible(button);await _settle()
	_check(button.size.y==48 and button.get_global_rect().size.x>=44,"existing 48px single-line action remains")
	_check(Rect2(Vector2.ZERO,Vector2(holder.size)).encloses(button.get_global_rect()),"whole result action reaches viewport")
	var width: float=button.get_theme_font("font").get_string_size(button.text,HORIZONTAL_ALIGNMENT_LEFT,-1,button.get_theme_font_size("font_size")).x
	_check(width+26+32<=button.size.x,"actual title and icon fit with horizontal breathing room")
	return button

func _paid_snapshot(st: Object,dir: String,name: String) -> void:
	var path: String=dir.path_join(name+".json")
	_check(not FileAccess.file_exists(path),"fresh paid snapshot")
	var file:=FileAccess.open(path,FileAccess.WRITE)
	_check(file!=null,"paid snapshot writable")
	if file!=null:file.store_string(JSON.stringify(st.to_dict(),"\t",true));file.close()

func _paid_flow(tag: String,vp: Vector2i) -> void:
	var holder:=SubViewport.new();holder.size=vp;holder.handle_input_locally=true;holder.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(holder)
	var dir: String=_data_root.path_join(tag+"_paid")
	_check(DirAccess.make_dir_recursive_absolute(dir)==OK,"isolated paid-result storage")
	var app: Node=await _spawn(holder,dir);app.set_process(false)
	var fixture:=PaidFixture.new();fixture.check=_check
	var st: Object=fixture.initial();app.set("state",st)
	var editor: Control=await _paid_open(app)
	_check(editor.find_child("EditorRevisionSummary",true,false)==null,"first paid tasting has no fabricated predecessor")
	await _shot(holder,tag+"_paid_01_first.png")
	fixture.known_expensive(st)
	var second: Dictionary=st.get_record(st.last_feedback_record_id)
	var second_id: int=int(second["record_id"])
	var first_id: int=int(second["comparison"]["prev_record_id"])
	_check(second["version"]==2 and second["comparison"]["prev_config"]["broth_recipe"]["ingredients"].size()==2 and second["config"]["broth_recipe"]["ingredients"].size()==3,"real paid bone2 to bone3 witnesses")
	editor=await _paid_open(app)
	var button: Button=await _paid_button(holder,editor,"맛 같고 부담 늘어요")
	var before: String=_paid_ledger(st)
	await _shot(holder,tag+"_paid_02_burden.png")
	if button!=null:
		var acknowledgements: int=app.get("_juice").acknowledgement_count()
		_point(holder,button.get_global_rect().get_center(),true);await _settle()
		_check(button.get_theme_color("font_pressed_color")==Color.WHITE,"held result title uses readable white theme")
		await _shot(holder,tag+"_paid_03_pressed.png")
		var point: Vector2=button.get_global_rect().get_center()
		for step in 6:
			var motion:=InputEventMouseMotion.new();motion.position=point+Vector2(0,-12);motion.global_position=motion.position;motion.relative=Vector2(0,-12);motion.button_mask=MOUSE_BUTTON_MASK_LEFT;holder.push_input(motion);point=motion.position;await _frames(1)
		_point(holder,point,false);await _settle()
		_check(editor.get("_modal")==null and app.get("_juice").acknowledgement_count()==acknowledgements and _paid_ledger(st)==before,"drag cancels modal and committed effect without touching ledger")
	await _tap(holder,editor,"EditorRevisionSummary")
	var modal: Control=editor.get("_modal")
	_check(modal!=null and modal.find_child("JourneyBeforeDish",true,false)!=null and modal.find_child("JourneyAfterDish",true,false)!=null,"existing paid comparison still shows both real dishes")
	await _tap(holder,editor,"JourneyComparisonDetails")
	var copy: Label=editor.find_child("ComparisonLabel",true,false)
	_check(copy!=null and copy.text.contains("1,560") and copy.text.contains("2,040") and copy.text.contains("101") and copy.text.contains("125"),"existing detail preserves actual480won/24seconds evidence")
	await _shot(holder,tag+"_paid_04_detail.png")
	await _tap(holder,editor,"EditorDetailsBack")
	_check(_paid_ledger(st)==before,"result clicks never change draft, records, cash or knowledge")
	_paid_snapshot(st,dir,"01_burden")
	# fixture leaves the live draft on bone2, while feedback still describes the
	# paid bone3 record. Repricing avoids an existing identical record on saving.
	_check(st.set_draft_price(8900)["ok"] and st.taste()["ok"],"real paid cheaper faster revision")
	editor=await _paid_open(app);await _paid_button(holder,editor,"맛 같고 부담 줄어요")
	await _shot(holder,tag+"_paid_05_saving.png")
	var broth: int=fixture.changed_broth(st)
	_check(st.use_broth(broth)["ok"] and st.taste()["ok"],"real changed broth paid revision")
	editor=await _paid_open(app);await _paid_button(holder,editor,"맛이 달라졌어요")
	await _shot(holder,tag+"_paid_06_broth.png")
	var noodle: int=fixture.changed_noodle(st)
	_check(st.use_noodle(noodle)["ok"] and st.taste()["ok"],"real changed noodle paid revision")
	editor=await _paid_open(app);await _paid_button(holder,editor,"맛이 달라졌어요")
	await _shot(holder,tag+"_paid_07_noodle.png")
	_check(st.set_draft_price(15000)["ok"] and st.taste()["ok"],"real price-only paid revision")
	editor=await _paid_open(app);await _paid_button(holder,editor,"맛·원가·준비 그대로")
	await _shot(holder,tag+"_paid_08_price.png")
	before=_paid_ledger(st)
	await _tap(holder,editor,"EditorResultDetails")
	var values: Array=editor.find_children("*","Label",true,false)
	var has_price: bool=false
	for label in values:has_price=has_price or label.text.contains("15,000")
	_check(has_price,"price-only keeps actual paid price in existing customer detail")
	await _tap(holder,editor,"EditorDetailsBack")
	_check(_paid_ledger(st)==before,"customer price reasons remain read-only")
	_check(st.select_record(second_id)["ok"],"explicit older paid record selection")
	_check(st.set_draft_toppings(["topping_egg","topping_egg"])["ok"],"later live draft really differs from retained paid result")
	editor=await _paid_open(app);await _paid_button(holder,editor,"맛 같고 부담 늘어요")
	_check(st.get_record(second_id)==second,"old paid record remains immutable after later experiments")
	_check(st.delete_record(first_id)["ok"],"old predecessor can be deleted without deleting the retained revision")
	app.call("_close_overlay");editor=await _paid_open(app)
	await _paid_button(holder,editor,"맛 같고 부담 늘어요")
	await _shot(holder,tag+"_paid_09_retained.png")
	_paid_snapshot(st,dir,"02_retained")
	_check(app.call("manual_save")["ok"],"real paid-result save")
	before=_paid_ledger(st);app.queue_free();await _settle();app=await _spawn(holder,dir);app.set_process(false)
	st=app.get("state");_check(_paid_ledger(st)==before,"entire paid ledger exact after disk restart")
	editor=await _paid_open(app);await _paid_button(holder,editor,"맛 같고 부담 늘어요")
	await _shot(holder,tag+"_paid_10_restart.png")
	_paid_snapshot(st,dir,"03_restart")
	# This defensive host is deliberately synthetic; the actual earned/save
	# evidence above is never overwritten or described as an unknown tasting.
	var hidden:=HiddenKnowledgeState.new()
	_check(hidden.load_from_dict(st.to_dict())=="","synthetic withholding host loads the same valid ledger")
	app.call("_close_overlay");app.set("state",hidden)
	editor=await _paid_open(app)
	button=editor.find_child("EditorRevisionSummary",true,false)
	_check(button!=null and button.text=="이번 개량의 변화","withheld exact recipe knowledge never exposes new equality through title")
	_check(_paid_ledger(hidden)==before,"defensive rendering never grants knowledge or changes paid data")
	_paid_profiles+=1;app.queue_free();await _settle();holder.queue_free();await _settle()
