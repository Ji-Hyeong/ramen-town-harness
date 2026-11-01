extends "res://tests/paid_result_change_qa.gd"
## Stored paid formulas only. Actual fresh, earned rank3 and supported legacy
## players are separate fixtures/storage, never one invented progression path.
var _formula_profiles: int=0
func _run() -> void:
	for profile in [{"tag":"portrait","size":Vector2i(390,844)},{"tag":"desktop","size":Vector2i(1280,800)},{"tag":"compact","size":Vector2i(390,750)}]:
		await _formula_flow(profile["tag"],profile["size"])
	_check(_formula_profiles==3,"all paid formula profiles finish")
	print("PAID FORMULA COMPARISON checks=%d failures=%d mode=%s" % [_checks,_failures.size(),"layout-only" if _layout_only else "capture"])
	for failure in _failures:printerr("FAIL: "+failure)
	quit(0 if _failures.is_empty() else 1)

func _formula_labels(editor: Control,vp: Vector2i) -> void:
	for label in editor.find_children("Journey*Formula_*","Label",true,false):
		_check(_text_height_fits(label),"whole formula text fits its allocated height")
		# Width is measured with the final inherited font, not an assumed Korean
		# character count. Every complete atomic choice must fit its own column.
		_check(label.autowrap_mode==TextServer.AUTOWRAP_OFF,"formula choices never split inside an ingredient or quantity")
		var font: Font=label.get_theme_font("font")
		for line in label.text.split("\n"):
			_check(font.get_string_size(line,HORIZONTAL_ALIGNMENT_LEFT,-1,label.get_theme_font_size("font_size")).x<=label.size.x,"complete ingredient/quantity fits the paid dish column: "+line)
		var rect: Rect2=label.get_global_rect()
		_check(rect.position.x>=22 and rect.end.x<=vp.x-22,"formula keeps modal horizontal padding")
	await _reachable(editor,vp,"EditorDetailsBack")

func _formula_open(holder: SubViewport,app: Node) -> Control:
	var editor: Control=await _paid_open(app)
	await _tap(holder,editor,"EditorRevisionSummary")
	await _formula_labels(editor,holder.size)
	return editor

func _formula_flow(tag: String,vp: Vector2i) -> void:
	var holder:=SubViewport.new();holder.size=vp;holder.handle_input_locally=true;holder.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(holder)
	var dir: String=_data_root.path_join(tag+"_formula")
	_check(DirAccess.make_dir_recursive_absolute(dir)==OK,"isolated formula root")
	# SaveService intentionally expects an existing explicit development path.
	for suffix in ["fresh","earned","legacy"]:
		_check(DirAccess.make_dir_recursive_absolute(dir.path_join(suffix))==OK,"isolated fixture directory: "+suffix)
	var app: Node=await _spawn(holder,dir.path_join("fresh"));app.set_process(false)
	var fixture:=PaidFixture.new();fixture.check=_check
	var st: Object=fixture.initial();fixture.known_expensive(st);app.set("state",st)
	var record: Dictionary=st.get_record(st.last_feedback_record_id)
	var before: String=_paid_ledger(st)
	var editor: Control=await _formula_open(holder,app)
	var a: Label=editor.find_child("JourneyBeforeFormula_broth",true,false)
	var b: Label=editor.find_child("JourneyAfterFormula_broth",true,false)
	_check(a!=null and b!=null and a.text.contains("돼지뼈 ×2") and b.text.contains("돼지뼈 ×3"),"same short broth names retain actual2and3portions under paid dishes")
	_check(editor.find_child("JourneyAfterFormula_noodle",true,false)==null,"unchanged noodles add no caption clutter")
	await _shot(holder,tag+"_formula_01_portions.png")
	await _tap(holder,editor,"JourneyComparisonDetails")
	var copy: Label=editor.find_child("ComparisonLabel",true,false)
	_check(copy.text.contains("돼지뼈 ×2") and copy.text.contains("돼지뼈 ×3"),"folded literal change text no longer hides same-named broth changes")
	await _shot(holder,tag+"_formula_02_details.png")
	var scroll: ScrollContainer=editor.find_child("DetailsScroll",true,false)
	scroll.ensure_control_visible(a);await _settle()
	if a!=null:await _drag_list(holder,a.get_global_rect().get_center())
	_check(editor.get("_modal")!=null and _paid_ledger(st)==before,"dragging literal formula text scrolls without acting or changing state")
	await _tap(holder,editor,"EditorDetailsBack")
	_check(st.select_record(record["record_id"])["ok"] and st.set_draft_price(9100)["ok"] and st.taste()["ok"],"actual price-only paid revision")
	editor=await _formula_open(holder,app)
	_check(editor.find_children("Journey*Formula_*","Label",true,false).is_empty(),"price-only paid revision adds no raw formula captions")
	await _shot(holder,tag+"_formula_03_price.png")
	await _tap(holder,editor,"EditorDetailsBack")
	var index: int=fixture.changed_noodle(st)
	_check(st.use_noodle(index)["ok"] and st.taste()["ok"],"actual changed raw noodles paid revision")
	editor=await _formula_open(holder,app)
	b=editor.find_child("JourneyAfterFormula_noodle",true,false)
	_check(b!=null and b.text.contains("강력 밀가루") and b.text.contains("간수 배합수") and b.text.contains("굵은 꼬불면"),"actual flour,water,cut are visible rather than an unchanged generic name")
	await _shot(holder,tag+"_formula_04_noodle.png")
	await _tap(holder,editor,"EditorDetailsBack")
	_check(st.select_record(record["record_id"])["ok"] and st.set_draft_choice("oil","oil_chili")["ok"] and st.delete_record(record["comparison"]["prev_record_id"])["ok"],"older paid result retained after a new draft and predecessor deletion")
	editor=await _formula_open(holder,app)
	a=editor.find_child("JourneyBeforeFormula_broth",true,false);b=editor.find_child("JourneyAfterFormula_broth",true,false)
	_check(a.text.contains("×2") and b.text.contains("×3") and st.get_record(record["record_id"])==record,"older paid quantities never borrow later draft or deleted record")
	await _tap(holder,editor,"EditorDetailsBack")
	_check(app.call("manual_save")["ok"],"formula session saves")
	before=_paid_ledger(st);app.queue_free();await _settle();app=await _spawn(holder,dir.path_join("fresh"));app.set_process(false)
	_check(_paid_ledger(app.get("state"))==before,"whole formula-session state exact after disk restart")
	editor=await _formula_open(holder,app)
	var restored_caption: Label=editor.find_child("JourneyAfterFormula_broth",true,false)
	_check(restored_caption!=null and restored_caption.text.contains("×3"),"paid quantity survives restart")
	await _shot(holder,tag+"_formula_05_restart.png")
	app.queue_free();await _settle()
	# Longest normal rank3 raw broth and changed raw noodles: no grants. The
	# checkpoint's earned rank/supply/cash are retained, new work is paid normally.
	app=await _spawn(holder,dir.path_join("earned"));app.set_process(false);st=PaidState.new()
	_check(st.load_from_dict(JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/foraging-earned-v18-save.json")))=="","earned rank3 raw checkpoint loads")
	app.set("state",st)
	index=fixture.brew(st,["pork_bone","chicken_bone","onion","ginger","garlic"])
	_check(st.use_broth(index)["ok"],"actual five-ingredient finished broth use")
	var formula: Dictionary={"flour":"strong","water":"alkaline","cut":"thick","method":"moist"}
	index=-1
	for i in st.noodle_review()["recipes"].size():
		if st.noodle_review()["recipes"][i]["recipe"]==formula:index=i
	if index<0:index=fixture.noodles(st,formula)
	_check(st.use_noodle(index)["ok"] and st.taste()["ok"],"actual paid changed full recipe from earned checkpoint")
	before=_paid_ledger(st);editor=await _formula_open(holder,app)
	b=editor.find_child("JourneyAfterFormula_broth",true,false)
	_check(b!=null and b.text.contains("돼지뼈") and b.text.contains("닭뼈") and b.text.contains("양파") and b.text.contains("생강") and b.text.contains("마늘"),"all five actual raw ingredients retained on small screens")
	_check(editor.find_children("Journey*Formula_*","Label",true,false).size()==4,"simultaneous changed broth/noodles annotate both paid dishes")
	await _shot(holder,tag+"_formula_06_long.png")
	_check(_paid_ledger(st)==before,"long formula comparison is entirely read-only")
	app.queue_free();await _settle()
	# Supported historical save is an explicit compatibility fixture, not a
	# fresh player who was gifted prepared broth/noodles.
	app=await _spawn(holder,dir.path_join("legacy"));app.set_process(false);st=PaidState.new()
	_check(st.load_from_dict(JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/broth-v15-save.json")))=="","supported legacy fixture loads")
	app.set("state",st)
	index=fixture.brew(st,["pork_bone","ginger"])
	_check(st.use_broth(index)["ok"] and st.taste()["ok"],"actual legacy-to-raw paid revision")
	editor=await _formula_open(holder,app)
	a=editor.find_child("JourneyBeforeFormula_broth",true,false)
	_check(a!=null and not a.text.contains("×"),"legacy missing raw data does not invent historical portions")
	await _shot(holder,tag+"_formula_07_legacy.png")
	_formula_profiles+=1;app.queue_free();await _settle();holder.queue_free();await _settle()
