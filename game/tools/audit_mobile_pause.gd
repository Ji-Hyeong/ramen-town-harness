extends "res://tools/audit_campaign_progression.gd"
## Actual controller callbacks in owned HEADLESS scenes. This does not suspend
## macOS, close a desktop window, test iOS scheduling, or capture rendered UI.
const RawFixture=preload("res://tests/known_change_fixtures.gd")
const Session=preload("res://scripts/domain/service_session.gd")
var _cases: Array=[]
var _finished: bool=false

func _initialize() -> void:
	var output: String=_new_output_from_args()
	if output!="":_run_pause.call_deferred(output)

func _run_pause(output: String) -> void:
	# A script exception must not leave an unattended headless editor running
	# forever. This timer belongs only to this diagnostic SceneTree.
	create_timer(120.0).timeout.connect(func():
		if not _finished:
			printerr("PAUSE AUDIT TIMEOUT: not all callbacks completed")
			quit(1))
	for kind in ["broth","noodle","taste"]:await _work_case(kind,output,false)
	await _work_case("broth",output,true)
	await _service_case(output)
	await _exploration_case(output)
	_check(_cases.size()==6,"all six pause/restart cases finish")
	var report: Dictionary={"format":1,"schema":State.SCHEMA_VERSION,"cases":_cases,"checks":checks+3,"failures":failures,"limits":"Headless owned main-scene callbacks only. Node.notification(APPLICATION_PAUSED) is delivered to that one owned Node, not the OS or global tree. Same-process continuation and restart from a copied normal save are distinct. Accelerated frame/work/service clocks. No actual iPhone/OS termination, pause-time budget, rendering, performance/heat or final policy approval claim."}
	if not _write_new(output.path_join("report.json"),JSON.stringify(report,"\t",true)+"\n"):quit(2);return
	_finished=true
	print("MOBILE PAUSE CONTRACT cases=%d checks=%d failures=%d" % [_cases.size(),checks,failures.size()])
	quit(0 if failures.is_empty() else 1)

func _settle_frames() -> void:
	await process_frame
	await process_frame

func _owned_scene(folder: String) -> Node:
	if not _check(DirAccess.make_dir_recursive_absolute(folder)==OK,"create isolated scene save folder"):return null
	var holder:=SubViewport.new();holder.size=Vector2i(390,844);holder.render_target_update_mode=SubViewport.UPDATE_DISABLED;root.add_child(holder)
	var scene: PackedScene=load("res://scenes/main.tscn")
	var app: Node=scene.instantiate()
	# Inject BEFORE ready: fallback to user:// must never occur. No historical
	# supplier fixture is substituted; a missing file remains a real fresh game.
	app.set("data_location",{"ok":true,"dir":folder,"is_dev":true,"error":""})
	holder.add_child(app);app.set_process(false)
	await _settle_frames()
	_check(not app.get("save_locked"),"owned app can read its isolated save")
	return app

func _dispose(app: Node) -> void:
	if app!=null:app.get_parent().queue_free()
	await _settle_frames()

func _fork(app: Node,folder: String) -> Node:
	var saver: Object=app.get("saver")
	var bytes: String=FileAccess.get_file_as_string(saver.main_path())
	_check(bytes!="","pause checkpoint exists")
	_check(DirAccess.make_dir_recursive_absolute(folder)==OK,"new restart fork folder")
	if not _write_new(folder.path_join("ramen_lab_save.json"),bytes):return null
	var restored: Node=await _owned_scene(folder)
	var expected:=State.new()
	_check(expected.load_from_dict(JSON.parse_string(bytes))=="","copied paused save parses normally")
	_check(_json(restored.get("state"))==_json(expected),"actual startup restores all serialized paused values")
	return restored

func _pause(app: Node) -> void:
	# Only this owned test scene receives the real controller notification.
	# No global application or operating-system pause is generated.
	app.notification(Node.NOTIFICATION_APPLICATION_PAUSED)

func _work_case(kind: String,output: String,fail_save: bool) -> void:
	var label: String=kind+("_save_refusal" if fail_save else "")
	var folder: String=output.path_join(label)
	var app: Node=await _owned_scene(folder.path_join("live"))
	if app==null:return
	var state: State=app.get("state")
	if kind=="taste":
		var fixture:=RawFixture.new();fixture.check=_check
		state=fixture.initial();app.set("state",state);app.call("_refresh_all")
	# Real craft actions originate in the development view. Bind its presenter
	# before driving completion, rather than invent a hidden, uninitialized UI.
	app.call("_open_overlay",0)
	_check(app.call("_persist","audit baseline"),"confirmed initial checkpoint")
	var saver: Object=app.get("saver")
	var original_disk: String=FileAccess.get_file_as_string(saver.main_path())
	var before_wallet: int=state.wallet
	var before_products: int=state.broth_review()["recipes"].size() if kind=="broth" else state.noodle_review()["recipes"].size()
	var before_records: int=state.record_count()
	var fee: int=0
	if kind=="broth":
		_check(state.set_broth_blend(["pork_bone","ginger"],"standard")["ok"],"actual fresh broth input")
		fee=int(state.broth_review()["cost"])
		_check(state.begin_broth()["ok"],"actual unpaid pending brew")
		app.call("_process",1.0)
	elif kind=="noodle":
		_check(state.set_noodle_formula("flour","strong")["ok"],"actual fresh noodle input")
		fee=int(state.noodle_review()["cost"])
		_check(state.begin_noodle()["ok"],"actual unpaid pending noodles")
		app.call("_process",1.0)
	else:
		_check(state.use_broth(1)["ok"],"explicit new completed broth selection before tasting")
		app.call("_refresh_all")
		fee=state.trial_cost()
		_check(app.call("start_tasting")["ok"],"actual timed tasting controller begins")
		app.call("advance_work",0.1)
	var confirmed: String=_json(state)
	_check(state.wallet==before_wallet and state.record_count()==before_records,"partial work has no early fee or paid record")
	if fail_save:_check(DirAccess.make_dir_recursive_absolute(saver.tmp_path())==OK,"scoped real temporary-path write conflict")
	_pause(app)
	_check(_json(state)==confirmed,"pause callback changes no confirmed game value")
	_check(state.broth_active() if kind=="broth" else (state.noodle_active() if kind=="noodle" else app.get("_work").is_running()),"same-process pause retains pending work")
	if fail_save:
		_check(app.get("_save_error_shown") and FileAccess.get_file_as_string(saver.main_path())==original_disk,"real pause write refusal shows failure and preserves original bytes")
	else:
		var disk:=State.new()
		_check((app.get("saver") as RefCounted).load_into(disk)["status"]=="ok" and _json(disk)==confirmed,"pause saves all confirmed work inputs without premature completion")
	var checkpoint_sha: String=FileAccess.get_sha256(saver.main_path())
	var restored: Node=await _fork(app,folder.path_join("restart"))
	if restored==null:return
	var loaded: State=restored.get("state")
	_check(not loaded.craft_active() and not loaded.service_active() and not restored.get("_work").is_running(),"restart never recreates unpaid transient work")
	_check(loaded.wallet==before_wallet and loaded.record_count()==before_records,"restart loses no work fee and invents no tasting")
	if fail_save:_check(DirAccess.remove_absolute(saver.tmp_path())==OK,"remove only own empty QA conflict")
	# Resume through the actual controller completion path. The process remains
	# disabled between these explicit, bounded accelerated frame steps.
	if kind=="taste":_check(app.call("advance_work",20.0),"same-process tasting completes")
	else:app.call("_process",20.0)
	_check(state.wallet==before_wallet-fee,"completion charges the one quoted fee exactly once")
	_check(not state.craft_active() and not app.get("_work").is_running(),"resumed work finishes")
	if kind=="taste":_check(state.record_count()==before_records+1,"one actual new paid tasting")
	else:
		var products: int=state.broth_review()["recipes"].size() if kind=="broth" else state.noodle_review()["recipes"].size()
		_check(products==before_products+1,"one actual completed product")
		_check(not state.broth_ready() if kind=="broth" else not state.noodle_ready(),"completion still requires explicit bowl application")
	var after: String=_json(state)
	app.call("_process",20.0);app.call("advance_work",20.0)
	_check(_json(state)==after,"extra resume frames never charge/complete again")
	var persisted:=State.new()
	_check(saver.load_into(persisted)["status"]=="ok" and _json(persisted)==after,"completion automatically saves exact confirmed state")
	_check(not app.get("_save_error_shown"),"successful completion clears any prior pause save warning")
	_cases.append({"id":label,"quoted_fee":fee,"pause_checkpoint_sha256":checkpoint_sha,"wallet_before":before_wallet,"wallet_after":state.wallet,"restart_has_no_pending_job":true,"same_process_completes_once":true,"real_save_refusal":fail_save})
	await _dispose(restored);await _dispose(app)

func _service_case(output: String) -> void:
	var folder: String=output.path_join("service")
	var app: Node=await _owned_scene(folder.path_join("live"))
	if app==null:return
	var fixture:=RawFixture.new();fixture.check=_check
	var state: State=fixture.initial();app.set("state",state);app.call("_refresh_all")
	_check(app.call("_persist","service baseline"),"real raw sale checkpoint")
	var confirmed: String=_json(state);var before_wallet: int=state.wallet
	app.call("_start_service")
	_check(state.service_active(),"actual controller starts service")
	var session: RefCounted=state.active_session()
	for i in Session.HARD_LIMIT:
		if not session.completed.is_empty() or session.is_finished():break
		session.advance(1.0)
	_check(not session.completed.is_empty() and not session.is_finished(),"actual partial completed orders exist before pause")
	var partial_units: int=session.completed.size()
	_pause(app)
	_check(state.service_active() and state.active_session()==session and _json(state)==confirmed,"same-process pause retains the exact session but no partial accounting")
	var restored: Node=await _fork(app,folder.path_join("restart"))
	if restored==null:return
	var loaded: State=restored.get("state");var loaded_text: String=_json(loaded)
	_check(not loaded.service_active() and loaded_text==confirmed,"restart returns to exact pre-service confirmed state")
	_check(not loaded.settle_service()["ok"] and _json(loaded)==loaded_text,"restart cannot settle discarded partial orders")
	_check(session.run_to_end(),"same-process actual service finishes")
	app.call("_finish_service")
	_check(not state.service_active() and state.day==loaded.day+1 and state.wallet==before_wallet+int(state.last_report["net"]),"actual controller settles once after resuming")
	var final: String=_json(state)
	_check(not state.settle_service()["ok"] and _json(state)==final,"second settlement is rejected")
	var saved:=State.new()
	_check(app.get("saver").load_into(saved)["status"]=="ok" and _json(saved)==final,"controller persists the complete resumed settlement")
	_cases.append({"id":"service","partial_orders_before_pause":partial_units,"final_units":state.last_report["units"],"net":state.last_report["net"],"restart_discards_unsettled_orders":true,"same_process_settles_once":true})
	await _dispose(restored);await _dispose(app)

func _exploration_case(output: String) -> void:
	var folder: String=output.path_join("exploration")
	var app: Node=await _owned_scene(folder.path_join("live"))
	if app==null:return
	var state:=State.new()
	_check(state.load_from_dict(JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/foraging-earned-v18-save.json")))=="","separate actual earned supply checkpoint")
	app.set("state",state);app.call("_refresh_all")
	var wallet: int=state.wallet;var stock: int=state.sample_stock("topping_citrus_peel")
	_check(state.start_foraging()["ok"] and state.advance_expedition("market_group_buy")["ok"] and state.advance_expedition("prepare_citrus_five")["ok"],"actual prepaid research trip choices")
	_check(state.wallet==wallet-1900 and state.sample_stock("topping_citrus_peel")==stock,"prepaid costs with no early stock reward")
	var confirmed: String=_json(state)
	_pause(app)
	_check(state.exploration_active() and _json(state)==confirmed,"pause keeps selected paid exploration path")
	var restored: Node=await _fork(app,folder.path_join("restart"))
	if restored==null:return
	var loaded: State=restored.get("state")
	_check(loaded.exploration_active() and _json(loaded)==confirmed,"restart preserves every prepaid exploration field")
	_check(loaded.finish_expedition()["ok"] and loaded.wallet==wallet-1900 and loaded.sample_stock("topping_citrus_peel")==stock+5,"resumed trip charges no second fee and awards real result once")
	var final: String=_json(loaded)
	_check(not loaded.finish_expedition()["ok"] and _json(loaded)==final,"resumed trip result cannot be received twice")
	_check(restored.call("_persist","resumed exploration"),"resumed trip result persists")
	var saved:=State.new()
	_check(restored.get("saver").load_into(saved)["status"]=="ok" and _json(saved)==final,"all resumed trip values survive normal disk load")
	_cases.append({"id":"exploration","prepaid_cost":1900,"received_samples":5,"restart_preserves_paid_choices":true,"once_only_result":true})
	await _dispose(restored);await _dispose(app)
