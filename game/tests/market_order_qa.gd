extends "res://tests/operations_workbench_qa.gd"
## Real pointer-driven request flow, on separate earned players for each size.
## Fixture work accelerates only scoped game clocks; no rewards/rank/stock grants.
const MarketActual=preload("res://tests/market_order_integration_tests.gd")
const MarketState=preload("res://scripts/domain/game_state.gd")
var _market_profiles: int=0

func _run() -> void:
	for profile in [{"tag":"portrait","size":Vector2i(390,844),"direction":"citrus_clear"},{"tag":"desktop","size":Vector2i(1280,800),"direction":"sesame_depth"},{"tag":"compact","size":Vector2i(390,750),"direction":"citrus_clear"}]:
		await _market_flow(profile["tag"],profile["size"],profile["direction"])
	_check(_market_profiles==3,"all actual market request UI profiles finish")
	print("MARKET ORDER UI checks=%d failures=%d mode=%s" % [_checks,_failures.size(),"layout-only" if _layout_only else "capture"])
	for failure in _failures:printerr("FAIL: "+failure)
	quit(0 if _failures.is_empty() else 1)

func _market_open(app: Node,detail: bool=true) -> Control:
	app.call("_refresh_all")
	app.call("_open_overlay",4)
	await _settle()
	var view: Control=app.get("_operations_view")
	view.call("_navigate","detail" if detail else "list","market_tasting" if detail else "")
	await _settle()
	return view

func _market_bounds(holder: SubViewport,view: Control,tag: String) -> void:
	await _settle()
	await _bounds(holder,view,tag)
	for picture in view.find_children("OpsMarketIngredient","TextureRect",true,false):
		_check(picture.texture!=null and picture.size.y>=44,tag+": real route ingredient art is present")
	for name in ["OpsMarketTitle","OpsMarketDirection","OpsMarketMenu","OpsMarketUnits","OpsMarketStars","OpsMarketClaimed"]:
		var label: Label=view.find_child(name,true,false)
		if label==null:continue
		_check(_text_height_fits(label),tag+": full market label fits "+name)
		var rect: Rect2=label.get_global_rect()
		_check(rect.position.x>=20 and rect.end.x<=holder.size.x-20,tag+": padded market label "+name)

func _market_flow(tag: String,vp: Vector2i,direction: String) -> void:
	var holder:=SubViewport.new();holder.size=vp;holder.handle_input_locally=true;holder.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(holder)
	var folder: String=_data_root.path_join(tag+"_market")
	_check(DirAccess.make_dir_recursive_absolute(folder)==OK,"isolated market UI directory")
	var app: Node=await _spawn(holder,folder);app.set_process(false)
	app.set("state",MarketState.new())
	var view: Control=await _market_open(app)
	_check(view.find_child("OpsMarketLock",true,false)!=null,"fresh player sees honest rank lock")
	await _market_bounds(holder,view,tag)
	await _shot(holder,tag+"_market_01_locked.png")
	var actual:=MarketActual.new();actual.check=_check
	var state: Object=actual.fresh();app.set("state",state)
	view=await _market_open(app,false)
	_check(view.find_child("OpsMarketOrder",true,false)!=null,"existing request list exposes market event without a new tab")
	await _market_bounds(holder,view,tag)
	await _shot(holder,tag+"_market_02_list.png")
	await _tap(holder,view,"OpsMarketOrder")
	await _market_bounds(holder,view,tag)
	await _shot(holder,tag+"_market_03_choices.png")
	var accept: Button=view.find_child("OpsMarketAccept_"+direction,true,false)
	var before: String=_json(state)
	var ack: int=app.get("_juice").acknowledgement_count()
	if accept!=null:
		(view.get("_scroll") as ScrollContainer).ensure_control_visible(accept);await _settle()
		_point(holder,accept.get_global_rect().get_center(),true);await _settle()
		_check(_json(state)==before,"holding accept has no transaction before release")
		await _shot(holder,tag+"_market_04_pressed.png")
		var point: Vector2=accept.get_global_rect().get_center()
		for i in 6:
			var motion:=InputEventMouseMotion.new();motion.position=point+Vector2(0,-12);motion.global_position=motion.position;motion.relative=Vector2(0,-12);motion.button_mask=MOUSE_BUTTON_MASK_LEFT;holder.push_input(motion);point=motion.position;await _frames(1)
		_point(holder,point,false);await _settle()
		_check(_json(state)==before and app.get("_juice").acknowledgement_count()==ack,"scroll gesture cancels acceptance and action feedback")
	await _tap(holder,view,"OpsMarketAccept_"+direction)
	_check(state.market_order_review()["direction"]==direction and state.wallet==JSON.parse_string(before)["wallet"],"actual pointer accepts exactly the chosen route for free")
	await _market_bounds(holder,view,tag)
	await _shot(holder,tag+"_market_05_active.png")
	before=_json(state)
	await _tap(holder,view,"OpsMarketGoal")
	var board: Control=(app.get("_bowl_editor") as Control).find_child("ForagingGoalBoard",true,false)
	_check(board!=null and board.detail_id()==direction and _json(state)==before,"ingredient navigation opens existing direction without selecting recipe or mutating state")
	await _shot(holder,tag+"_market_06_goal.png")
	view=await _market_open(app)
	var id: int=actual.recipe(state,direction)
	_check(state.set_selling_menus([id])["ok"],"actual regional menu explicitly pinned")
	actual.operate(state)
	_check(state.market_order_review()["status"]=="ready","actual service earns eligibility before UI claim")
	await _update(app)
	await _market_bounds(holder,view,tag)
	_check((view.find_child("OpsPrimary",true,false) as Button).text=="답례 5,000원 받기","same open detail refreshes after settlement")
	await _shot(holder,tag+"_market_07_ready.png")
	before=_json(state)
	app.call("_show_service_report");await _settle()
	var report_view: Control=app.get("_service_result")
	_check(report_view.find_child("ResultMarketOrder",true,false)!=null,"settlement report exposes actually earned unclaimed event")
	await _shot(holder,tag+"_market_07a_report.png")
	await _tap(holder,report_view,"ResultMarketOrder")
	_check(_json(state)==before and view.find_child("OpsMarketDirection",true,false)!=null,"result link opens claim detail without auto-payment or recipe selection")
	var wallet: int=state.wallet
	var saver: Object=app.get("saver")
	var old_disk: String=FileAccess.get_file_as_string(saver.main_path())
	if tag=="portrait":
		# A real filesystem refusal scoped only to this QA save. The reward is
		# once-only in memory; old disk must survive until explicit save recovery.
		_check(DirAccess.make_dir_recursive_absolute(saver.tmp_path())==OK,"scoped real market payout save refusal")
	await _tap(holder,view,"OpsPrimary")
	_check(state.market_order_review()["status"]=="done" and state.wallet==wallet+5000,"actual pointer claims exactly5000cash once")
	_check((view.find_child("OpsPrimary",true,false) as Button).disabled,"claimed reward cannot be pressed again")
	app.call("_show_service_report");await _settle()
	_check((app.get("_service_result") as Control).find_child("ResultMarketOrder",true,false)==null,"claimed event no longer advertises another payout in report")
	app.call("_on_result_ok");await _settle()
	await _market_bounds(holder,view,tag)
	await _shot(holder,tag+"_market_08_claimed.png")
	if tag=="portrait":
		_check(FileAccess.get_file_as_string(saver.main_path())==old_disk,"failed payout save preserves original disk bytes")
		_check((view.find_child("OpsNotice",true,false) as Button).text.contains("저장하지 못"),"payout notice honestly shows unsaved state")
		before=_json(state);app.call("_on_market_order_action","market_claim",{})
		_check(_json(state)==before,"stale repeated claim after save failure grants nothing")
		await _shot(holder,tag+"_market_08a_unsaved.png")
		_check(DirAccess.remove_absolute(saver.tmp_path())==OK,"remove only own empty QA conflict directory")
		await _tap(holder,view,"OpsNotice")
		await _tap(holder,view,"OpsPrimary")
		_check(not app.get("_save_error_shown") and _json(state)==before,"manual save recovery preserves exactly one payout")
		view=await _market_open(app)
		await _shot(holder,tag+"_market_08b_recovered.png")
	before=_json(state)
	app.queue_free();await _settle();app=await _spawn(holder,folder);app.set_process(false)
	_check(_json(app.get("state"))==before,"whole actual UI state persists after real scene restart")
	view=await _market_open(app)
	_check(view.find_child("OpsMarketClaimed",true,false)!=null,"claimed event remains visible after restart")
	await _market_bounds(holder,view,tag)
	await _shot(holder,tag+"_market_09_restart.png")
	_market_profiles+=1;app.queue_free();await _settle();holder.queue_free();await _settle()
