extends "res://tools/audit_campaign_progression.gd"
## A finite, accelerated stress path, not a novice/fun or iOS benchmark. All
## money, products and retained revisions come through public production APIs.
const Raw=preload("res://tests/known_change_fixtures.gd")
const Broth=preload("res://scripts/domain/broth_workshop.gd")
var _milestones: Array=[]
var _services: Array=[]
var _overflow_broth: Dictionary={}
var _sale_id: int=0

func _initialize() -> void:
	var output: String=_new_output_from_args()
	if output!="":_run_notebook.call_deferred(output)

func _action(result: Dictionary,label: String) -> bool:
	return _check(bool(result.get("ok",false)),label+": "+str(result.get("message","")))

func _run_notebook(output: String) -> void:
	var folder: String=output.path_join("save")
	if not _check(DirAccess.make_dir_absolute(folder)==OK,"new isolated save folder"):quit(2);return
	var saver:=Save.new(folder)
	var fixture:=Raw.new();fixture.check=_check
	var state: State=fixture.initial()
	_sale_id=int(state.records()[0]["record_id"])
	if not _action(state.set_selling_menus([_sale_id]),"fix an actually tasted funding menu"):quit(1);return
	if not _checkpoint(state,saver,output,"01_initial"):quit(1);return
	if not _fill_workshops(state):quit(1);return
	if not _checkpoint(state,saver,output,"02_workshops"):quit(1);return
	# One actual family has room for revisions independently of registered-menu
	# capacity. Apply finished raw products, never inject a record or its score.
	for noodle in 24:
		for broth in 60:
			if state.record_count()>=State.MAX_RECORDS:break
			if noodle==0 and broth==0:continue # the genuine initial paid recipe
			if not _cash(state):quit(1);return
			var last: int=int(state.records().back()["record_id"])
			if not _action(state.select_record(last),"continue the real recipe family") or not _action(state.use_broth(broth),"apply completed broth") or not _action(state.use_noodle(noodle),"apply completed noodles"):quit(1);return
			var wallet: int=state.wallet;var fee: int=state.trial_cost();var count: int=state.record_count()
			if not _action(state.taste(),"paid raw revision"):quit(1);return
			_check(state.wallet==wallet-fee and state.record_count()==count+1,"one quoted fee and one actual revision")
			if state.record_count() in [100,200,300]:
				if not _checkpoint(state,saver,output,"03_records_%03d" % state.record_count()):quit(1);return
		if state.record_count()>=State.MAX_RECORDS:break
	_check(state.record_count()==300 and state.menu_count()==1,"300 revisions, one family, no silent pruning")
	# Both full ledgers reject before spending. The caller's explicit draft
	# selection happens before the immutable transaction snapshot.
	if not _action(state.set_broth_blend(_overflow_broth["ingredients"],_overflow_broth["method"]),"select distinct overflow broth"):quit(1);return
	var before: String=_json(state)
	var denied: Dictionary=state.begin_broth()
	_check(not denied["ok"] and str(denied["message"]).contains("가득") and _json(state)==before,"full broth ledger refuses atomically")
	if not _action(state.use_broth(59),"prepare distinct overflow bowl") or not _action(state.use_noodle(23),"use unused noodle combination"):quit(1);return
	before=_json(state);denied=state.taste()
	_check(not denied["ok"] and str(denied["message"]).contains("300/300") and _json(state)==before,"full paid archive refuses without fee or mutation")
	var achievements: String=JSON.stringify(state.to_dict()["taste_achievements"],"",true)
	var removed: int=int(state.records().back()["record_id"])
	if not _action(state.delete_record(removed),"explicitly delete only one owned last row"):quit(1);return
	_check(state.record_count()==299 and JSON.stringify(state.to_dict()["taste_achievements"],"",true)==achievements,"explicit deletion retains all best-score witnesses")
	if not _cash(state):quit(1);return
	if not _action(state.select_record(int(state.records().back()["record_id"])),"continue retained family") or not _action(state.use_broth(59),"replacement broth") or not _action(state.use_noodle(23),"replacement noodles"):quit(1);return
	var money: int=state.wallet;var fee: int=state.trial_cost()
	if not _action(state.taste(),"one paid replacement after explicit cleanup"):quit(1);return
	_check(state.record_count()==300 and state.wallet==money-fee,"one reclaimed slot and one actual fee")
	if not _checkpoint(state,saver,output,"04_after_cleanup"):quit(1);return
	var report: Dictionary={"format":1,"schema":State.SCHEMA_VERSION,"checks":checks+3,"failures":failures,"milestones":_milestones,"funding_services":_services,"final_records":state.record_count(),"broth_products":state.broth_review()["recipes"].size(),"noodle_products":state.noodle_review()["recipes"].size(),"limits":"Actual fresh raw/public API path with known funding recipe, accelerated manufacture and runtime service clocks. Local Mac HEADLESS wall timings only, including serialization/normal file IO. Not human/fun/6-10h/iOS timing or force-termination evidence. Finite workload only: remembered keys are unbounded, so this does not prove all future save sizes fit the2MiB guard."}
	if not _write_new(output.path_join("report.json"),JSON.stringify(report,"\t",true)+"\n"):quit(2);return
	print("RAW NOTEBOOK records=%d broths=%d noodles=%d services=%d checks=%d failures=%d" % [state.record_count(),state.broth_review()["recipes"].size(),state.noodle_review()["recipes"].size(),_services.size(),checks,failures.size()])
	quit(0 if failures.is_empty() else 1)

func _cash(state: State) -> bool:
	# Fixed40-service ceiling guards even a broken nonpositive-income plan.
	for unused in 40:
		if state.wallet>=100000:return true
		var before: int=state.wallet;var day: int=state.day
		if not _action(state.begin_service(),"actual funding service begins"):return false
		if not _check(state.active_session().run_to_end(),"bounded real service completes"):return false
		if not _action(state.settle_service(),"actual completed orders settle"):return false
		if not _check(state.day==day+1 and state.wallet==before+int(state.last_report["net"]) and state.wallet>before,"funds derive only from actual positive settlement"):return false
		_services.append({"day":day,"units":state.last_report["units"],"net":state.last_report["net"]})
	return _check(false,"funding service ceiling exceeded")

func _fill_workshops(state: State) -> bool:
	var choices: Array=[]
	var ids: Array=["pork_bone","chicken_bone","kelp","onion","ginger","garlic"]
	# Finite catalog-ordered multisets; no hidden evaluator or progress grants.
	for a in ids.size():
		_append_broth(choices,[ids[a]])
		for b in range(a,ids.size()):
			_append_broth(choices,[ids[a],ids[b]])
			for c in range(b,ids.size()):_append_broth(choices,[ids[a],ids[b],ids[c]])
	_check(choices.size()>=61,"enough legal unique starter broth formulas for cap and overflow")
	for recipe in choices:
		if Broth.contains(state.broth_review()["recipes"],recipe):continue
		if state.broth_review()["recipes"].size()==60:
			_overflow_broth=recipe;break
		if not _cash(state):return false
		if not _action(state.set_broth_blend(recipe["ingredients"],recipe["method"]),"choose legal starter broth"):return false
		var money: int=state.wallet;var fee: int=state.broth_review()["cost"]
		if not _action(state.begin_broth(),"start actual broth") or not _action(state.advance_broth(20.0),"finish actual broth"):return false
		_check(state.wallet==money-fee,"one actual broth fee")
	for flour in ["wheat","strong"]:
		for water in ["clear","alkaline"]:
			for cut in ["thin","medium","thick"]:
				for method in ["standard","moist"]:
					if flour=="wheat" and water=="clear" and cut=="thin" and method=="standard":continue
					if not _cash(state):return false
					for pair in [["flour",flour],["water",water],["cut",cut],["method",method]]:
						if not _action(state.set_noodle_formula(pair[0],pair[1]),"choose legal rank1 noodles"):return false
					var money: int=state.wallet;var fee: int=state.noodle_review()["cost"]
					if not _action(state.begin_noodle(),"start actual noodles") or not _action(state.advance_noodle(20.0),"finish actual noodles"):return false
					_check(state.wallet==money-fee,"one actual noodle fee")
	return _check(state.broth_review()["recipes"].size()==60 and state.noodle_review()["recipes"].size()==24 and not _overflow_broth.is_empty(),"60unique broths and24rank1noodles actually manufactured")

func _append_broth(choices: Array,ids: Array) -> void:
	var recipe: Dictionary={"ingredients":ids,"method":"standard"}
	if Broth.error(recipe,1,[],true)=="":choices.append(Broth.canonical(recipe))

func _checkpoint(state: State,saver: RefCounted,output: String,label: String) -> bool:
	var began: int=Time.get_ticks_usec()
	var text: String=JSON.stringify(state.to_dict(),"\t",true)
	var serialize_us: int=Time.get_ticks_usec()-began
	var bytes: int=text.to_utf8_buffer().size()
	if not _check(bytes<=Save.MAX_BYTES,"actual UTF8 save fits normal size guard"):return false
	var previous: String=FileAccess.get_file_as_string(saver.main_path()) if saver.has_save() else ""
	began=Time.get_ticks_usec()
	if not _action(saver.save_state(state),"normal checkpoint save"):return false
	var save_us: int=Time.get_ticks_usec()-began
	if not _check(FileAccess.get_file_as_string(saver.main_path())==text,"exact serialized disk bytes"):return false
	if previous!="" and not _check(FileAccess.get_file_as_string(saver.bak_path())==previous,"exact prior checkpoint backup"):return false
	var loaded:=State.new();began=Time.get_ticks_usec()
	var result: Dictionary=saver.load_into(loaded)
	var load_us: int=Time.get_ticks_usec()-began
	if not _check(result["status"]=="ok" and _json(loaded)==_json(state),"all state values survive normal disk reload"):return false
	if not _write_new(output.path_join(label+".json"),text):return false
	_milestones.append({"id":label,"records":state.record_count(),"known_keys":state.to_dict()["recipe_knowledge"]["keys"].size(),"utf8_bytes":bytes,"sha256":text.sha256_text(),"serialize_us":serialize_us,"save_us":save_us,"load_us":load_us})
	return true
