extends "res://tests/exploration_workbench_qa.gd"
## The complete paid collection -> read-only preview -> deliberate edit -> real
## tasting journey. Fixtures reach unlocks with public transactions only.
const PreviewProjection = preload("res://scripts/ui/ingredient_trial_preview.gd")
const PayoffDirections = preload("res://scripts/domain/recipe_directions.gd")
const PayoffCheck = preload("res://scripts/domain/data_check.gd")


func _run() -> void:
	_projection_regression()
	var profiles: Array=[{"tag":"portrait","size":Vector2i(390,844)},{"tag":"desktop","size":Vector2i(1280,800)}]
	if OS.get_cmdline_user_args().has("--payoff-compact"):
		profiles=[{"tag":"compact","size":Vector2i(390,750)}]
	for profile in profiles:
		await _payoff(str(profile["tag"]),profile["size"])
	print("INGREDIENT PAYOFF mode=%s checks=%d failures=%d" % ["layout-only" if _layout_only else "capture",_checks,_failures.size()])
	for failure in _failures: printerr("FAIL: "+failure)
	quit(0 if _failures.is_empty() else 1)


func _projection_regression() -> void:
	# A real rank2/three-portion ledger covers behavior beyond the initial two
	# slots. Compare each projection with the public setter's accepted recipe.
	var fixture:=HarborFixture.new()
	fixture.check=_check
	var state: Object=fixture.ready()
	for result in [state.start_harbor_foraging(),state.advance_expedition("scallop_diver"),state.advance_expedition("clean_three"),state.finish_expedition(),state.set_draft_toppings(["topping_scallop","topping_scallop","topping_scallop"])]:
		_check(result["ok"],"real three-portion projection fixture")
	var before: String=JSON.stringify(state.to_dict())
	var repeated: Array=PreviewProjection.candidates(state,"topping_scallop")["rows"]
	_check(repeated.size()==3 and repeated[0]["samples"][0]["needed"]==3 and not repeated[0]["changed"],"three identical portions require three actual samples without inventing a change")
	var targeted: Array=PreviewProjection.candidates(state,"topping_nori",1)["rows"]
	_check(targeted.size()==1 and targeted[0]["replacement"]==1,"selected rank2 slot produces exactly one target")
	for row in PreviewProjection.candidates(state,"topping_nori")["rows"]:
		var copy:=GameProjection.new()
		_check(copy.load_from_dict(state.to_dict())=="","valid three-portion clone")
		var portions: Array=IngredientCatalog.toppings_of(copy.draft_config)
		portions[int(row["replacement"]) ]="topping_nori"
		_check(copy.set_draft_toppings(portions)["ok"] and PayoffCheck.same_config(copy.draft_config,row["config"]),"each full-slot counterfactual equals the real guarded setter")
		_check(int(row["after_cost"])-int(row["before_cost"])==-450 and row["samples"][0]["needed"]==2,"replacing one scallop changes one portion of cost and sample demand")
	_check(JSON.stringify(state.to_dict())==before,"all rank2 counterfactuals preserve original ledger")


func _preview_bounds(editor: Control, holder: SubViewport, tag: String) -> void:
	var sheet: Control=editor.get("_modal") as Control
	var action: Button=sheet.find_child("EditorDetailApply",true,false) as Button
	var scroll: Control=sheet.find_child("DetailsScroll",true,false) as Control
	_check(Rect2(Vector2.ZERO,Vector2(holder.size)).encloses(action.get_global_rect()),tag+": fixed preview action fits")
	_check(action.size.y>=44 and scroll.size.y>=100,tag+": meaningful body and44+ action")
	_check(scroll.get_global_rect().end.y<=action.get_global_rect().position.y,tag+": scrolling content cannot cover action")


func _payoff(tag: String, vp: Vector2i) -> void:
	var holder:=SubViewport.new()
	holder.size=vp
	holder.handle_input_locally=true
	holder.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	holder.set_meta("qa_tag",tag+"_payoff")
	root.add_child(holder)
	var dir: String=_data_root.path_join(tag+"_payoff")
	_check(DirAccess.make_dir_recursive_absolute(dir)==OK,tag+": isolated saves")
	var app: Node=await _spawn(holder,dir)
	app.set_process(false)
	var state: Object=app.get("state")
	var fixture:=MarketFixture.new()
	fixture.check=_check
	var prepared: Object=fixture.ready()
	_check(state.load_from_dict(prepared.to_dict())=="",tag+": real market fixture loads")
	app.call("_refresh_all")
	app.call("_open_overlay",6)
	var view: Control=await _show(app)
	await _tap(holder,view,"ExploreMode_sample")
	await _tap(holder,view,"ExplorePrimary")
	view=await _arrive_at(app)
	view=await _choose(holder,app,"citrus_cart")
	view=await _choose(holder,app,"take_three")
	_check(state.sample_stock("topping_citrus_peel")==0,tag+": waiting reward is not stock")
	await _tap(holder,view,"ExplorePrimary")
	await _settle()
	_check(state.sample_stock("topping_citrus_peel")==3 and view.call("celebration_count")==1,tag+": exact successful claim animates once")
	_check((view.find_child("ExploreRewardName",true,false) as Label).text.contains("×3"),tag+": quantity in actual reward card")
	_layout_checks(view,holder,tag+" reward")
	await _shot(holder,tag+"_payoff_01_reward.png")
	var before: String=_state_json(app)
	app.call("_on_exploration_collect")
	view.call("_render")
	await _settle()
	_check(_state_json(app)==before and view.call("celebration_count")==1,tag+": duplicate claim and redraw neither grant nor replay")
	await _tap(holder,view,"ExplorePrimary")
	await _settle()
	var editor: Control=app.get("_bowl_editor") as Control
	await _shot(holder,tag+"_payoff_02_material.png")
	var projection: Dictionary=PreviewProjection.candidates(state,"topping_citrus_peel")
	_check(_state_json(app)==before,tag+": projection itself is read-only")
	await _tap(holder,editor,"EditorIngredientExperiment")
	_preview_bounds(editor,holder,tag+" preview")
	var after_dish: Control=(editor.get("_modal") as Control).find_child("ExperimentDishAfter",true,false) as Control
	_check(PayoffCheck.same_config(after_dish.get("config"),projection["rows"][0]["config"]),tag+": real preview dish depicts projected ingredients")
	_check(_state_json(app)==before,tag+": opening preview changes nothing")
	await _shot(holder,tag+"_payoff_03_preview.png")
	await _tap(holder,editor,"EditorExperimentFacts")
	_check(_state_json(app)==before,tag+": detailed flavor/sample facts are read-only")
	await _shot(holder,tag+"_payoff_04_facts.png")
	await _tap(holder,editor,"EditorDetailApply")
	var action: Control=(editor.get("_modal") as Control).find_child("EditorDetailApply",true,false) as Control
	var effects: Object=app.get("_juice")
	var acknowledgements: int=effects.call("acknowledgement_count")
	await _drag_list(holder,action.get_global_rect().get_center())
	_check(_state_json(app)==before and effects.call("acknowledgement_count")==acknowledgements,tag+": preview confirmation drag cancels edit/effect")
	await _tap(holder,editor,"EditorDetailApply")
	_check(PayoffCheck.same_config(state.get("draft_config"),projection["rows"][0]["config"]),tag+": guarded apply equals the depicted one-change recipe")
	_check(state.sample_stock("topping_citrus_peel")==3,tag+": draft apply spends no samples")
	# At capacity, no default slot is selected. Choosing either compares only;
	# confirming uses the existing controller's exact single-position replacement.
	editor.call("reveal_ingredient","topping_citrus_peel")
	await _settle()
	await _tap(holder,editor,"EditorIngredientExperiment")
	_check(((editor.get("_modal") as Control).find_child("EditorDetailApply",true,false) as Button).disabled,tag+": full dock requires explicit preview target")
	before=_state_json(app)
	projection=PreviewProjection.candidates(state,"topping_citrus_peel")
	await _tap(holder,editor,"EditorExperimentSlot_0")
	_check(_state_json(app)==before,tag+": highlighting replacement cannot edit")
	await _shot(holder,tag+"_payoff_05_replacement.png")
	await _tap(holder,editor,"EditorDetailApply")
	_check(PayoffCheck.same_config(state.get("draft_config"),projection["rows"][0]["config"]),tag+": replacement matches selected target")
	var repeated: Array=PreviewProjection.candidates(state,"topping_citrus_peel")["rows"]
	_check(repeated.size()==2 and repeated[0]["samples"][0]["needed"]==2 and not bool(repeated[0]["changed"]),tag+": repeated portions need two samples and unchanged replacement is detected")
	# The player deliberately edits broth/oil too; the preview never invents or
	# auto-loads a complete optimal recipe to satisfy the direction.
	await _tap(holder,editor,"EditorBroth")
	# Temporarily restore the real frame loop for the mandatory broth task;
	# the rest of this fixture explicitly controls tasting time for capture.
	app.set_process(true)
	await _tap(holder,editor,"BrothAdd_chicken_bone")
	await _tap(holder,editor,"BrothAdd_onion")
	await _tap(holder,editor,"EditorDetailApply")
	var broth_deadline: int=Time.get_ticks_msec()+10000
	while state.call("broth_active") and Time.get_ticks_msec()<broth_deadline: await process_frame
	_check(not state.call("broth_active"),tag+": raw ingredient broth completes before editing ramen")
	await _settle()
	await _tap(holder,editor,"BrothUse_0")
	await _tap(holder,editor,"EditorBroth")
	await _tap(holder,editor,"BrothTab_seasoning")
	app.set_process(false)
	await _tap(holder,editor,"EditorGroupTab_oil")
	await _tap(holder,editor,"EditorAdd_oil_scallion")
	await _tap(holder,editor,"EditorDetailApply")
	before=_state_json(app)
	var wallet: int=int(state.get("wallet"))
	var cost: int=int(state.trial_cost())
	var records: int=int(state.record_count())
	await _tap(holder,editor,"EditorTaste")
	_check(app.call("work_active") and _state_json(app)==before,tag+": cooking starts without premature payment")
	await _tap(holder,editor,"EditorCancel")
	_check(_state_json(app)==before,tag+": real cancellation preserves whole state")
	await _tap(holder,editor,"EditorTaste")
	app.call("advance_work",12.0)
	app.call("_sync_bowl_editor")
	await _settle()
	_check(int(state.get("wallet"))==wallet-cost and state.sample_stock("topping_citrus_peel")==1 and state.record_count()==records+1,tag+": actual paid tasting consumes exact money/two portions once")
	var badge: Button=editor.find_child("EditorDiscoveryReward",true,false) as Button
	_check(badge!=null and badge.text.contains("유자 맑은탕") and badge.text.contains("새 방향"),tag+": controller's actual new direction is visible in native result")
	await _shot(holder,tag+"_payoff_06_discovery.png")
	before=_state_json(app)
	await _tap(holder,editor,"EditorDiscoveryReward")
	_preview_bounds(editor,holder,tag+" discovery details")
	_check(_state_json(app)==before,tag+": reading earned direction grants nothing extra")
	await _shot(holder,tag+"_payoff_07_discovery_facts.png")
	await _tap(holder,editor,"EditorDetailApply")
	await _tap(holder,editor,"EditorDevelopAgain")
	await _tap(holder,editor,"EditorRemove_1")
	await _tap(holder,editor,"EditorTaste")
	app.call("advance_work",12.0)
	app.call("_sync_bowl_editor")
	await _settle()
	_check(state.sample_stock("topping_citrus_peel")==0 and (app.get("_direction_new_titles") as Array).is_empty(),tag+": repeated direction is not re-awarded")
	badge=editor.find_child("EditorDiscoveryReward",true,false) as Button
	_check(badge!=null and not badge.text.contains("새 방향"),tag+": repeated result is labeled truthfully")
	await _shot(holder,tag+"_payoff_08_repeat.png")
	before=_state_json(app)
	app.queue_free()
	await _settle()
	app=await _spawn(holder,dir)
	app.set_process(false)
	state=app.get("state")
	app.call("_open_overlay",1)
	app.call("_sync_bowl_editor")
	await _settle()
	editor=app.get("_bowl_editor") as Control
	badge=editor.find_child("EditorDiscoveryReward",true,false) as Button
	_check(_state_json(app)==before and badge!=null and not badge.text.contains("새 방향"),tag+": restart keeps earned witness but does not fake a new discovery")
	await _tap(holder,editor,"EditorDevelopAgain")
	editor.call("reveal_ingredient","topping_citrus_peel")
	await _settle()
	await _tap(holder,editor,"EditorIngredientExperiment")
	projection=PreviewProjection.candidates(state,"topping_citrus_peel")
	_check(str(projection["rows"][0]["sample_error"])!="",tag+": shortage uses actual shared sample check")
	await _shot(holder,tag+"_payoff_09_shortage.png")
	_check(state.set_draft_price(int(state.get("draft_config")["price"])+100)["ok"],tag+": intervening deliberate price edit")
	before=_state_json(app)
	await _tap(holder,editor,"EditorDetailApply")
	_check(_state_json(app)==before and (editor.get("_modal") as Control)!=null,tag+": stale preview cannot overwrite intervening draft")
	await _shot(holder,tag+"_payoff_10_stale.png")
	editor.call("reveal_ingredient","topping_scallop")
	await _settle()
	await _tap(holder,editor,"EditorIngredientExperiment")
	_check(((editor.get("_modal") as Control).find_child("EditorDetailApply",true,false) as Button).disabled and _state_json(app)==before,tag+": locked material preview cannot unlock or apply")
	await _shot(holder,tag+"_payoff_11_locked.png")
	holder.size=Vector2i(390,750)
	await _settle()
	_preview_bounds(editor,holder,tag+" live resize")
	holder.size=vp
	app.queue_free()
	holder.queue_free()
	await _settle()
