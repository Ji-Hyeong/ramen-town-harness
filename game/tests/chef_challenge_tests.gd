extends RefCounted
## Acceptance uses earned public state and actual runtime orders. No XP, rank,
## wallet or challenge success is injected to manufacture an achievable target.
const State = preload("res://tests/legacy_game_fixture.gd")
const Chef = preload("res://scripts/domain/chef_challenge.gd")
const Staff = preload("res://scripts/domain/shop_staffing.gd")
const Catalog = preload("res://scripts/domain/ingredient_catalog.gd")
const Eval = preload("res://scripts/domain/recipe_evaluator.gd")
const Save = preload("res://scripts/services/save_service.gd")
const Fixture = preload("res://tests/harbor_foraging_tests.gd")
var check: Callable
var finished: bool = false
const FAST: Dictionary = {"broth":"broth_dashi","tare":"tare_shio","oil":"oil_scallion","noodle":"noodle_thin","toppings":["topping_nori"],"cook":"cook_firm","price":9000}


func json(state: Object) -> String:
	return JSON.stringify(state.to_dict(),"",true)


func fast(state: Object, process: bool = false) -> void:
	state.start_new_recipe()
	for slot in Catalog.SLOTS:
		if slot != "topping": check.call(state.set_draft_choice(slot,FAST[slot])["ok"],"lunch ingredient "+slot)
	check.call(state.set_draft_toppings(FAST["toppings"])["ok"],"lunch topping")
	check.call(state.set_draft_price(9000)["ok"] and state.set_draft_name("점심 연구")["ok"],"lunch name/price")
	if process: check.call(state.set_draft_process("noodle","moist")["ok"],"new lunch process distinct from existing notebook")
	var tasted: Dictionary=state.taste()
	check.call(tasted["ok"],"real lunch tasting: "+str(tasted["message"]))


func operate(state: Object) -> void:
	check.call(state.begin_service()["ok"],"real service begins")
	if state.active_session() == null: return
	check.call(state.active_session().run_to_end(),"actual order state machine completes")
	check.call(state.settle_service()["ok"],"actual completed orders settle once")


func run(callback: Callable, data_dir: String) -> void:
	check=callback
	var state:=State.new()
	var original: String=json(state)
	check.call(state.chef_challenge_review()["status"]=="open" and json(state)==original,"review is pure; initial challenge open")
	check.call(not state.claim_chef_challenge()["ok"] and json(state)==original,"cannot claim without work")
	check.call(state.taste()["ok"],"pre-acceptance recipe")
	check.call(state.start_chef_challenge()["ok"],"explicit free acceptance")
	var accepted: Dictionary=state.to_dict()["chef_challenge"]
	var wallet: int=state.wallet
	check.call(not state.start_chef_challenge()["ok"] and state.wallet==wallet,"no repeated acceptance charge/reset")
	operate(state)
	check.call(not state.chef_challenge_review()["rows"][0]["met"],"old tasted record cannot satisfy new development")
	state.set_draft_price(9500)
	check.call(state.taste()["ok"],"price-only tasting")
	operate(state)
	check.call(not state.chef_challenge_review()["rows"][0]["met"],"price-only revision does not qualify")
	fast(state)
	var before: String=json(state)
	check.call(state.begin_service()["ok"],"partial service begins")
	check.call(not state.claim_chef_challenge()["ok"] and not state.settle_service()["ok"],"busy/incomplete settlement refuse")
	state.active_session().advance(50.0)
	state.cancel_service()
	check.call(json(state)==before,"partial/canceled service leaves no progress or money")
	check.call(state.serve()["ok"],"legacy analytical service remains usable")
	check.call(state.to_dict()["chef_challenge"]["attempt"]["record_id"] != state.selected_record_id,"analytical estimate is not actual challenge evidence")
	operate(state)
	var review: Dictionary=state.chef_challenge_review()
	print("CHEF PUBLIC WITNESS "+JSON.stringify(review["attempt"]))
	check.call(review["status"]=="ready","rank1 public lunch recipe satisfies all real targets")
	var proof: Dictionary=review["attempt"].duplicate(true)
	var receipt_state: String=JSON.stringify(state.to_dict()["chef_challenge"],"",true)
	operate(state)
	check.call(JSON.stringify(state.to_dict()["chef_challenge"],"",true)==receipt_state,"first passing proof frozen across later service")
	var base_staff: Dictionary=state.current_staffing()
	wallet=state.wallet
	check.call(state.claim_chef_challenge()["ok"] and state.wallet==wallet,"mastery claimed once without cash/wage transaction")
	check.call(Staff.effective_prep(100,state.current_staffing())==95 and Staff.daily_wage(state.current_staffing())==Staff.daily_wage(base_staff),"actual next service snapshot has modest prep effect only")
	before=json(state)
	check.call(not state.claim_chef_challenge()["ok"] and not state.start_chef_challenge()["ok"] and json(state)==before,"claim replay/acceptance reset atomic")
	review["attempt"]["config"]["price"]=5000
	check.call(state.chef_challenge_review()["attempt"]["config"]["price"]==proof["config"]["price"],"public proof deep copy")
	check.call(DirAccess.make_dir_recursive_absolute(data_dir)==OK,"isolated chef save directory")
	var store=Save.new(data_dir)
	check.call(store.save_state(state)["ok"],"mastery real save")
	var restored:=State.new()
	check.call(store.load_into(restored)["status"]=="ok" and json(restored)==json(state),"mastery exact disk restart")
	check.call(not restored.claim_chef_challenge()["ok"],"restart cannot repeat claim")
	# Deleted notebook records do not erase an earned immutable service proof.
	check.call(state.delete_record(proof["record_id"])["ok"],"delete retained witness using public action")
	var deleted:=State.new()
	check.call(deleted.load_from_dict(state.to_dict())=="" and deleted.chef_challenge_review()["status"]=="mastered","deleted witness remains valid after strict load")
	# Every historical root shape migrates without granting a challenge/reward.
	for version in range(1,15):
		var raw: Dictionary=State.new().to_dict()
		var keys: Array=State.TOP_KEYS_V14 if version==14 else State.TOP_KEYS_V13
		if version<=2: keys=State.TOP_KEYS_V1 if version==1 else State.TOP_KEYS_V2
		elif version==3: keys=State.TOP_KEYS_V3
		elif version==4: keys=State.TOP_KEYS_V4
		elif version==5: keys=State.TOP_KEYS_V5
		elif version==6: keys=State.TOP_KEYS_V6
		elif version<=8: keys=State.TOP_KEYS_V7
		elif version==9: keys=State.TOP_KEYS_V9
		elif version==10: keys=State.TOP_KEYS_V10
		elif version<=12: keys=State.TOP_KEYS_V11
		for key in raw.keys():
			if not keys.has(key): raw.erase(key)
		raw["schema_version"]=version; raw.erase("broth_workshop")
		if version<=2:
			raw["draft"]["config"]["topping"]=raw["draft"]["config"]["toppings"][0]
			raw["draft"]["config"].erase("toppings")
		var old:=State.new()
		check.call(old.load_from_dict(JSON.parse_string(JSON.stringify(raw)))=="" and old.chef_challenge_review()["status"]=="open" and old.wallet==State.START_WALLET and old.day==1,"v%d no retroactive grant" % version)
	var good: Dictionary=restored.to_dict()
	for kind in ["extra","bad_day","bad_config","bad_stars","bad_wait","bad_record","unearned","old_root","boolean"]:
		var bad: Dictionary=good.duplicate(true)
		match kind:
			"extra": bad["chef_challenge"]["extra"]=1
			"bad_day": bad["chef_challenge"]["attempt"]["day"]=bad["day"]
			"bad_config": bad["chef_challenge"]["attempt"]["config"]["broth"]="missing"
			"bad_stars": bad["chef_challenge"]["attempt"]["star_sum"]=999999
			"bad_wait": bad["chef_challenge"]["attempt"]["wait_total"]=-1
			"bad_record": bad["chef_challenge"]["attempt"]["record_id"]=bad["next_record_id"]
			"unearned": bad["chef_challenge"]["attempt"]["units"]=0; bad["chef_challenge"]["attempt"]["wait_total"]=0; bad["chef_challenge"]["attempt"]["star_sum"]=0
			"old_root": bad["schema_version"]=13; bad.erase("broth_workshop")
			"boolean": bad["chef_challenge"]["completed_day"]=true
		before=json(restored)
		check.call(restored.load_from_dict(bad)!="" and json(restored)==before,"malformed chef load atomic: "+kind)
	for base in range(1,301):
		for hired in [[],["prep_assistant"]]:
			var plain: Dictionary=Staff.snapshot(hired)
			var mastered: Dictionary=Staff.snapshot(hired,{},1)
			var expected: int=(Staff.effective_prep(base,plain)*95+99)/100
			check.call(Staff.effective_prep(base,mastered)==maxi(1,expected) and Staff.snapshot_error(mastered)=="","rounded mastery composes with assistant")
	# Expanded single-menu service, historical staffing and hiring previews use
	# the same mastery snapshot; two-menu services never claim a single-menu goal.
	var fixture:=Fixture.new()
	fixture.check=check
	var grown: Object=fixture.ready()
	check.call(grown.expand_shop()["ok"],"public expansion for runtime/mastery integration")
	check.call(grown.start_chef_challenge()["ok"],"grown chef challenge")
	fast(grown,true)
	check.call(grown.set_selling_menus([grown.selected_record_id])["ok"],"explicit single selling menu")
	operate(grown)
	check.call(grown.claim_chef_challenge()["ok"],"expanded public challenge claim")
	var historical:=State.new()
	check.call(historical.load_from_dict(grown.to_dict())=="","pre-mastery historical report still valid")
	operate(grown)
	check.call(historical.load_from_dict(grown.to_dict())=="","post-mastery historical report validated")
	var fake_old: Dictionary=grown.to_dict()
	fake_old.erase("chef_challenge")
	fake_old.erase("mountain_foraging")
	fake_old["schema_version"]=13; fake_old.erase("broth_workshop")
	check.call(historical.load_from_dict(fake_old)!="","old schema rejects nested mastery snapshot")

	var preview: Dictionary=grown.hiring_preview("prep_assistant")
	check.call(preview["error"]=="" and preview["after"]["menus"][0]["prep"]==Staff.effective_prep(Eval.prep_seconds(grown.selling_records()[0]["config"]),Staff.snapshot(["prep_assistant"],{},1)),"hiring comparison preserves earned chef mastery")
	check.call(grown.purchase_facility("staff_1")["ok"] and grown.hire_staff("prep_assistant")["ok"],"publicly hire assistant after mastery")
	operate(grown)
	check.call(historical.load_from_dict(grown.to_dict())=="" and grown.current_staffing().get("chef",0)==1,"actual assistant/mastery combined service persists")
	var multi: Object=fixture.ready()
	check.call(multi.expand_shop()["ok"],"real two-menu expansion")
	var ids: Array=[]
	for record in multi.records(): ids.append(record["record_id"])
	check.call(multi.set_selling_menus(ids)["ok"] and multi.start_chef_challenge()["ok"],"real two-menu challenge setup")
	operate(multi)
	check.call(multi.to_dict()["chef_challenge"]["attempt"].is_empty(),"two-menu report never fabricates one-menu proof")
	# An existing progressed v13 file retains every value and exact backup bytes.
	var old_dir: String=data_dir.path_join("v13")
	check.call(DirAccess.make_dir_recursive_absolute(old_dir)==OK,"isolated progressed v13 directory")
	var raw13: Dictionary=multi.to_dict()
	raw13.erase("chef_challenge")
	raw13.erase("mountain_foraging")
	raw13["schema_version"]=13; raw13.erase("broth_workshop")
	var old_text: String=JSON.stringify(raw13,"\t",true)
	var old_store=Save.new(old_dir)
	var old_file:=FileAccess.open(old_store.main_path(),FileAccess.WRITE)
	check.call(old_file!=null,"own v13 source save")
	if old_file==null: return
	old_file.store_string(old_text)
	old_file.close()
	var migrated:=State.new()
	check.call(old_store.load_into(migrated)["status"]=="ok" and migrated.chef_challenge_review()["status"]=="open","progressed v13 migration has no retroactive grant")
	var projected: Dictionary=migrated.to_dict()
	projected.erase("chef_challenge")
	projected.erase("mountain_foraging")
	projected["schema_version"]=13; projected.erase("broth_workshop")
	check.call(JSON.stringify(projected,"",true)==JSON.stringify(raw13,"",true),"all v13 progression/report/records/wallet remain exact")
	check.call(old_store.save_state(migrated)["ok"] and FileAccess.get_file_as_string(old_store.legacy_bak_path(13))==old_text,"first schema14 save preserves exact v13 original")
	finished=true
