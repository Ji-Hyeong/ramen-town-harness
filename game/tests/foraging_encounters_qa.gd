extends "res://tests/foraging_goals_qa.gd"
## Actual six encounter outcomes and three cross-region paid experiments.
## Public setup earns prerequisites; only isolated work/service clocks accelerate.
const EarnedMountain=preload("res://tests/mountain_foraging_tests.gd")
const Actual=preload("res://scripts/domain/game_state.gd")
const BrothRules=preload("res://scripts/domain/broth_workshop.gd")
const NoodleRules=preload("res://scripts/domain/noodle_workshop.gd")
const CrossDirections=preload("res://scripts/domain/recipe_directions.gd")
var _encounter_finished: int=0

func _run() -> void:
	for profile in [{"tag":"portrait","size":Vector2i(390,844)},{"tag":"desktop","size":Vector2i(1280,800)},{"tag":"compact","size":Vector2i(390,750)}]:
		await _encounter_profile(profile["tag"],profile["size"])
	_check(_encounter_finished==3,"all three full encounter/experiment profiles finished")
	print("FORAGING ENCOUNTERS checks=%d failures=%d mode=%s" % [_checks,_failures.size(),"layout" if _layout_only else "capture"])
	for failure in _failures: printerr("FAIL: "+failure)
	quit(0 if _failures.is_empty() else 1)

func _earned() -> Object:
	var fixture:=EarnedMountain.new()
	fixture.check=_check
	var st: Object=fixture.ready()
	for choice in ["m_hear_recipe","m_buy_pickle"]:
		_check(st.start_expedition("market")["ok"] and st.advance_expedition("m_ask")["ok"] and st.advance_expedition(choice)["ok"] and st.finish_expedition()["ok"],"actual remaining market supplier")
		_check(st.serve()["ok"],"actual next departure day")
	_raw(st,["kelp","ginger"],"wheat","thin")
	_check(st.taste()["ok"],"actual paid raw-component starting witness")
	return st

func _raw(st: Object, ingredients: Array, flour: String, cut: String) -> void:
	_check(st.set_broth_blend(ingredients,"standard")["ok"],"actual raw broth formula")
	var recipe: Dictionary=BrothRules.canonical({"ingredients":ingredients,"method":"standard"})
	var index: int=-1
	for i in st.broth_review()["recipes"].size():
		if st.broth_review()["recipes"][i]["recipe"]==recipe:index=i
	if index<0:
		_check(st.begin_broth()["ok"] and st.advance_broth(20.0)["ok"],"actual paid new broth completion")
		index=st.broth_review()["recipes"].size()-1
	_check(st.use_broth(index)["ok"],"explicit actual completed broth use")
	for pair in [["flour",flour],["water","clear"],["cut",cut],["method","standard"]]:
		_check(st.set_noodle_formula(pair[0],pair[1])["ok"],"actual raw noodle choice")
	recipe={"flour":flour,"water":"clear","cut":cut,"method":"standard"}
	index=-1
	for i in st.noodle_review()["recipes"].size():
		if st.noodle_review()["recipes"][i]["recipe"]==recipe:index=i
	if index<0:
		_check(st.begin_noodle()["ok"] and st.advance_noodle(20.0)["ok"],"actual paid new noodle completion")
		index=st.noodle_review()["recipes"].size()-1
	_check(st.use_noodle(index)["ok"],"explicit existing noodle use without duplicate manufacture")

func _cross_goal(holder: SubViewport, app: Node, id: String) -> void:
	app.call("_open_overlay",0)
	var editor: Control=app.get("_bowl_editor")
	editor.call("_show_directions")
	await _settle()
	var before: String=_ledger(app.get("state"))
	await _tap(holder,editor,"GoalGroup_cross_region")
	await _shot(holder,str(holder.get_meta("qa_tag"))+"_cross_list.png")
	await _tap(holder,editor,"GoalOpen_"+id)
	# An already selected goal has a deliberately disabled confirmation, not a
	# second transaction. Both fresh selection and revisiting must stay read-only.
	if app.get("_direction_target")!=id:await _tap(holder,editor,"GoalSelect_"+id)
	else:_check((editor.find_child("GoalSelect_"+id,true,false) as Button).disabled,"selected goal cannot be reconfirmed")
	_check(app.get("_direction_target")==id and _ledger(app.get("state"))==before,"cross-goal category/details/select never pay or apply")
	await _shot(holder,str(holder.get_meta("qa_tag"))+"_goal_"+id+".png")
	await _tap(holder,editor,"EditorDetailsBack")

func _trip(holder: SubViewport, app: Node, region: String, target: String, choice: String, ingredient: String, amount: int, fee: int, extra: int, suffix: String) -> void:
	var st: Object=app.get("state")
	app.call("_open_overlay",6)
	var view: Control=app.get("_exploration_view")
	view.call("open_source",region,"sample")
	app.call("_sync_bowl_editor")
	await _settle()
	var wallet: int=st.wallet
	var stock: int=st.sample_stock(ingredient)
	await _tap(holder,view,"ExplorePrimary")
	_check(st.wallet==wallet-fee,"real base departure once")
	await _arrive_at(app)
	_encounter_layout(view,holder,suffix+" routes")
	if choice in ["share_sesame_two","sort_sardine_two","mill_buckwheat_five"]:await _shot(holder,suffix+"_routes.png")
	await _choose(holder,app,target)
	_check(st.wallet==wallet-fee and st.sample_stock(ingredient)==stock,"story target chooses route without early material")
	_encounter_layout(view,holder,suffix+" offer")
	await _shot(holder,suffix+"_offer.png")
	if choice=="share_sesame_two":
		var card: Button=view.find_child("ExploreChoice_"+choice,true,false)
		var ledger: String=_ledger(st)
		await _drag_list(holder,card.get_global_rect().get_center())
		_check(_ledger(st)==ledger and view.get("_choice")=="","sample-card drag cancels choice and payment")
		_point(holder,card.get_global_rect().get_center(),true)
		await _settle()
		for words in card.find_children("*","Label",true,false):
			_check(words.get_theme_color("font_color")==Color.WHITE and _text_height_fits(words),"pictured outcome has readable held text")
		await _shot(holder,suffix+"_held.png")
		_point(holder,card.get_global_rect().get_center(),false)
		await _settle()
		_check(st.wallet==wallet-fee and st.sample_stock(ingredient)==stock,"sample-card tap selects without paying")
	await _choose(holder,app,choice)
	_encounter_layout(view,holder,suffix+" pending")
	_check(st.wallet==wallet-fee-extra and st.sample_stock(ingredient)==stock,"exact chosen extra and deferred real reward")
	var before: String=_ledger(st)
	_check(not st.advance_expedition(choice)["ok"] and _ledger(st)==before,"choice replay cannot charge again")
	await _shot(holder,suffix+"_pending.png")
	await _tap(holder,view,"ExplorePrimary")
	_encounter_layout(view,holder,suffix+" received")
	_check(st.sample_stock(ingredient)==stock+amount,"exact actual chosen ingredient/quantity claim")
	before=_ledger(st)
	_check(not st.finish_expedition()["ok"] and _ledger(st)==before,"claim replay has no reward")
	await _shot(holder,suffix+"_received.png")
	app.call("_close_overlay")
	_check(st.serve()["ok"] and app.call("_persist"),"real next day and isolated autosave")
	app.call("_refresh_all")


## Check the actual fixed footer and the expanded story labels, not a mirror
## of the formatter. Long text may scroll but must fit its own allocated height.
func _encounter_layout(view: Control,holder: SubViewport,tag: String) -> void:
	_layout_checks(view,holder,tag)
	for label in view.find_children("*","Label",true,false):
		if label.is_visible_in_tree():_check(_text_height_fits(label),tag+": visible label fits: "+label.text)

func _experiment(holder: SubViewport, app: Node, id: String, index: int, tag: String) -> void:
	await _cross_goal(holder,app,id)
	var st: Object=app.get("state")
	st.start_new_recipe()
	var ingredients: Array=[["kelp","ginger"],["pork_bone","garlic"],["sardine"]][index]
	_raw(st,ingredients,"buckwheat" if index==1 else "wheat","thick" if index==1 else "thin")
	_check(st.set_draft_name(["유자 가리비 연구","참깨 메밀 연구","정어리 표고 연구"][index])["ok"],"authored cross-region prototype name")
	_check(st.set_draft_price(9000)["ok"] and st.set_draft_choice("tare","tare_miso" if index==1 else "tare_shio")["ok"],"real price/tare choice")
	_check(st.set_draft_choice("oil","oil_roasted_sesame" if index==1 else "oil_scallion")["ok"],"real cross-region oil")
	_check(st.set_draft_toppings([["topping_citrus_peel","topping_scallop"],["topping_nori"],["topping_grilled_shiitake"]][index])["ok"],"actual required cross-region portions")
	var assessment: Dictionary=CrossDirections.assess(id,st.draft_config)
	_check(assessment["error"]=="" and assessment["matched"],"actual crafted recipe reaches cross-region condition: "+id)
	var definition: Dictionary=CrossDirections.find(id)
	var before: Dictionary={}
	for ingredient in definition["requires"]: before[ingredient]=st.sample_stock(ingredient)
	app.call("_refresh_all")
	app.call("_open_overlay",0)
	var editor: Control=app.get("_bowl_editor")
	editor.call("_close_modal")
	await _settle()
	await _tap(holder,editor,"EditorTaste")
	_check(app.call("advance_work",20.0),"actual paid native cross-region tasting completes")
	app.call("_sync_bowl_editor")
	await _settle()
	for ingredient in definition["requires"]:_check(st.sample_stock(ingredient)==int(before[ingredient])-1,"actual required sample consumed once: "+ingredient)
	_check(CrossDirections.tested_ids(st.records()).has(id),"real retained paid witness, not merely recipe selection")
	await _shot(holder,tag+"_tasted_"+id+".png")
	app.call("_close_overlay")

func _encounter_profile(tag: String, vp: Vector2i) -> void:
	var holder:=SubViewport.new();holder.size=vp;holder.handle_input_locally=true;holder.render_target_update_mode=SubViewport.UPDATE_ALWAYS;holder.set_meta("qa_tag",tag);root.add_child(holder)
	var dir: String=_data_root.path_join(tag+"_encounters")
	_check(DirAccess.make_dir_recursive_absolute(dir)==OK,"isolated encounter store")
	var app: Node=await _spawn(holder,dir);app.set_process(false);app.set("state",_earned());app.call("_refresh_all")
	await _cross_goal(holder,app,"citrus_scallop")
	var offers: Array=[
		["market","market_group_buy","share_sesame_two","oil_roasted_sesame",2,1000,0],
		["market","market_group_buy","prepare_citrus_five","topping_citrus_peel",5,1000,900],
		["harbor","harbor_shared_catch","sort_sardine_two","broth_roasted_sardine",2,1200,400],
		["harbor","harbor_shared_catch","sort_scallop_five","topping_scallop",5,1200,1400],
		["mountain","mountain_shared_mill","mill_buckwheat_five","noodle_buckwheat",5,1600,1800],
		["mountain","mountain_shared_mill","share_shiitake_two","topping_grilled_shiitake",2,1600,500]]
	for i in offers.size():
		var row: Array=offers[i]
		await _trip(holder,app,row[0],row[1],row[2],row[3],row[4],row[5],row[6],tag+"_event_"+str(i))
	for i in 3:await _experiment(holder,app,["citrus_scallop","sesame_buckwheat","sardine_shiitake"][i],i,tag)
	var st: Object=app.get("state")
	_check(app.call("manual_save")["ok"],"save all actual encounter/experiment evidence")
	var before: String=_ledger(st)
	app.queue_free();await _settle();app=await _spawn(holder,dir);app.set_process(false)
	_check(_ledger(app.get("state"))==before,"whole state equal after actual disk restart")
	for id in ["citrus_scallop","sesame_buckwheat","sardine_shiitake"]:_check(CrossDirections.tested_ids(app.get("state").records()).has(id),"all three paid cross-region witnesses survive restart")
	_encounter_finished+=1
	app.queue_free();await _settle();holder.queue_free();await _settle()
