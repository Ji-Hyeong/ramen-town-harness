extends "res://tests/service_result_qa.gd"
## Three genuinely crafted/tasted dishes, followed by actual sales and a disk
## restart. Only disposable production/tasting/service clocks are accelerated.
const IdentityState=preload("res://scripts/domain/game_state.gd")
const Identity=preload("res://scripts/ui/menu_identity.gd")
const IdentityEval=preload("res://scripts/domain/recipe_evaluator.gd")
var _identity_finished: int=0

func _run() -> void:
	for profile in [{"tag":"portrait","size":Vector2i(390,844)},{"tag":"desktop","size":Vector2i(1280,800)},{"tag":"compact","size":Vector2i(390,750)}]:
		await _identity_profile(profile["tag"],profile["size"])
	_check(_identity_finished==3,"all three identity profiles finish")
	print("MENU IDENTITY checks=%d failures=%d mode=%s" % [_checks,_failures.size(),"layout" if _layout_only else "capture"])
	for failure in _failures: printerr("FAIL: "+failure)
	quit(0 if _failures.is_empty() else 1)

func _craft(st: Object, index: int) -> void:
	st.start_new_recipe()
	var names: Array=["맑은 향 라멘","진한 뼈 라멘","얼큰한 라멘"]
	var broths: Array=[["kelp","ginger"],["pork_bone","pork_bone","garlic"],["chicken_bone","ginger"]]
	_check(st.set_draft_name(names[index])["ok"],"actual authored recipe name")
	_check(st.set_broth_blend(broths[index],"standard")["ok"],"actual raw broth blend")
	_check(st.begin_broth()["ok"] and st.advance_broth(20.0)["ok"] and st.use_broth(st.broth_review()["recipes"].size()-1)["ok"],"paid real broth completion and explicit application")
	for pair in [["flour","wheat"],["water","clear"],["cut","thin" if index==0 else "thick"],["method","standard"]]:
		_check(st.set_noodle_formula(pair[0],pair[1])["ok"],"actual raw noodle formula")
	# Two dishes deliberately share one noodle formula. Reuse its actual archive
	# entry instead of asking the game to manufacture a forbidden duplicate.
	var review: Dictionary=st.noodle_review()
	var noodle_index: int=-1
	for i in review["recipes"].size():
		if review["recipes"][i]["recipe"]==review["formula"]: noodle_index=i
	if noodle_index<0:
		_check(st.begin_noodle()["ok"] and st.advance_noodle(20.0)["ok"],"paid real new noodle completion")
		noodle_index=st.noodle_review()["recipes"].size()-1
	var wallet: int=st.wallet
	_check(st.use_noodle(noodle_index)["ok"] and st.wallet==wallet,"explicit real completed noodle use has no second fee")
	_check(st.set_draft_choice("tare","tare_shio" if index==0 else "tare_miso")["ok"],"real tare")
	_check(st.set_draft_choice("oil",["oil_scallion","oil_garlic","oil_chili"][index])["ok"],"real oil")
	_check(st.set_draft_toppings(["topping_nori"] if index==0 else ["topping_chashu"])["ok"],"real topping")
	_check(st.set_draft_price(9000)["ok"],"same real sale price")

func _card_bounds(card: Control, tag: String) -> void:
	var button: Button=card.find_child("MenuIdentityOpen",true,false)
	_check(button!=null and button.size.x>=44 and button.size.y>=44,tag+": real whole-card target")
	for word in card.find_children("*","Label",true,false):
		if not word.is_visible_in_tree(): continue
		_check(_text_height_fits(word),tag+": full identity text height "+word.name)
		_check(card.get_global_rect().grow(-4).encloses(word.get_global_rect()),tag+": identity text inside padded frame "+word.name)

func _taste(holder: SubViewport, app: Node, tag: String) -> Dictionary:
	var st: Object=app.get("state")
	app.call("_refresh_all")
	app.call("_open_overlay",0)
	var editor: Control=app.get("_bowl_editor")
	editor.call("_close_modal")
	app.call("_sync_bowl_editor")
	await _settle()
	var wallet: int=st.wallet
	var records: int=st.record_count()
	await _tap(holder,editor,"EditorTaste")
	_check(app.call("advance_work",20.0),tag+": actual UI tasting completes")
	app.call("_sync_bowl_editor")
	await _settle()
	_check(st.record_count()==records+1 and st.wallet<wallet,tag+": exactly one paid immutable record")
	var record: Dictionary=st.get_record(st.last_feedback_record_id)
	var expected: Dictionary=Identity.describe(record)
	_check(expected["error"]=="" and expected["available"],tag+": actual tasted identity")
	var card: Control=editor.find_child("EditorMenuIdentity",true,false)
	_check(card!=null and card.call("shown_model")==expected,tag+": actual rendered identity equals paid record")
	if card==null: return record
	_check(card.call("reveal_count")==1,tag+": one explicit reveal for the actual completed tasting")
	_card_bounds(card,tag)
	var before: String=_json(app)
	var button: Button=card.find_child("MenuIdentityOpen",true,false)
	(editor.get("_scroll") as ScrollContainer).ensure_control_visible(button)
	await _settle()
	var acks: int=app.get("_juice").acknowledgement_count()
	await _drag_list(holder,button.get_global_rect().get_center())
	_check(editor.get("_modal")==null and _json(app)==before and app.get("_juice").acknowledgement_count()==acks,tag+": drag cancels identity details and success feedback")
	# The preceding deliberate swipe scrolls the new card out of view. Return
	# to that exact target before accepting a screenshot of the identity card.
	(editor.get("_scroll") as ScrollContainer).ensure_control_visible(button)
	await _settle()
	await _shot(holder,tag+"_taste.png")
	await _tap(holder,card,"MenuIdentityOpen")
	_check((editor.get("_modal") as Control).get_meta("view_kind","")=="menu_identity" and _json(app)==before,tag+": details read only")
	var dish: Control=editor.find_child("MenuIdentityDish",true,false)
	_check(dish!=null and dish.get("config")==record["config"],tag+": expanded food uses exact tasted snapshot")
	await _shot(holder,tag+"_taste_detail.png")
	await _tap(holder,editor,"EditorDetailsBack")
	app.call("_sync_bowl_editor")
	_check(_json(app)==before,tag+": closing/rebuilding does not pay or create discoveries")
	await _tap(holder,editor,"EditorCustomer_1")
	card=editor.find_child("EditorMenuIdentity",true,false)
	_check(card.call("reveal_count")==0 and _json(app)==before,tag+": customer selection redraw never replays discovery")
	app.call("_close_overlay")
	return record

func _sell(holder: SubViewport, app: Node, record: Dictionary, tag: String) -> void:
	var st: Object=app.get("state")
	_check(st.set_selling_menus([record["record_id"]])["ok"],tag+": explicitly register real tasted record")
	app.call("_refresh_all")
	var view: Control=await _complete(holder,app,tag)
	await _shot(holder,tag+"_sales.png")
	var before: String=_json(app)
	await _tap(holder,view,"ResultMenu_0")
	var card: Control=view.find_child("SoldMenuIdentity",true,false)
	_check(card!=null,tag+": actual sold identity card")
	if card!=null:
		var model: Dictionary=card.call("shown_model")
		_check(model==Identity.sales(view.get("_menus")[0]),tag+": actual completed receipt supplies card")
		_check(model["headline"]==Identity.describe(record)["headline"] and model["config"]==record["config"],tag+": same tasted culinary identity reaches sales")
		_card_bounds(card,tag+" sales")
		await _shot(holder,tag+"_sales_menu.png")
		await _tap(holder,card,"MenuIdentityOpen")
		_check(view.get("_page")=="identity" and _json(app)==before,tag+": sold identity deeper page is read only")
		await _shot(holder,tag+"_sales_identity.png")
		await _tap(holder,view,"ResultBack")
		_check(view.get("_page")=="menu",tag+": identity back returns to its actual sold menu")
	_check(_json(app)==before,tag+": all identity inspection preserves ledger")
	await _tap(holder,view,"ResultOkButton")

func _identity_profile(tag: String, vp: Vector2i) -> void:
	var holder:=SubViewport.new()
	holder.size=vp
	holder.handle_input_locally=true
	holder.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(holder)
	var dir: String=_data_root.path_join(tag+"_identity")
	_check(DirAccess.make_dir_recursive_absolute(dir)==OK,tag+": disposable save")
	var app: Node=await _spawn(holder,dir)
	app.set_process(false)
	app.set("state",IdentityState.new())
	var st: Object=app.get("state")
	var headlines: Array=[]
	var records: Array=[]
	for index in 3:
		_craft(st,index)
		var record: Dictionary=await _taste(holder,app,tag+"_"+str(index))
		records.append(record)
		headlines.append(Identity.describe(record)["headline"])
		await _sell(holder,app,record,tag+"_"+str(index))
	_check(headlines[0]!=headlines[1] and headlines[1]!=headlines[2] and headlines[0]!=headlines[2],tag+": three actual different culinary characters remain distinguishable")
	# Known old record is unchanged even after editing the current draft.
	var original: Dictionary=Identity.describe(records[0])
	_check(st.set_draft_choice("oil","oil_scallion")["ok"],tag+": deliberate later draft edit")
	_check(Identity.describe(st.get_record(records[0]["record_id"]))==original,tag+": old identity never reads current edited draft")
	_check(app.call("manual_save")["ok"],tag+": save all real paid evidence")
	var before: String=_json(app)
	app.queue_free()
	await _settle()
	app=await _spawn(holder,dir)
	app.set_process(false)
	st=app.get("state")
	_check(_json(app)==before and Identity.describe(st.get_record(records[0]["record_id"]))==original,tag+": exact restart preserves actual identity evidence")
	app.call("_show_service_report")
	var view: Control=app.get("_service_result")
	await _tap(holder,view,"ResultMenu_0")
	var card: Control=view.find_child("SoldMenuIdentity",true,false)
	_check(card!=null and not card.call("shown_model")["available"],tag+": old single receipt has no fabricated identity after restart")
	await _shot(holder,tag+"_restored_unknown.png")
	_check(_json(app)==before,tag+": old receipt inspection is read only")
	_identity_finished+=1
	app.queue_free()
	await _settle()
	holder.queue_free()
	await _settle()
