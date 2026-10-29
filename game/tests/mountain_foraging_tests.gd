extends RefCounted
## Earn every supplier, rank and sample through public actions. Invalid saves
## are derived from valid receipts, so rejection cannot pass on a broken setup.
const State=preload("res://tests/legacy_game_fixture.gd")
const Mountain=preload("res://scripts/domain/mountain_foraging.gd")
const Harbor=preload("res://scripts/domain/harbor_foraging.gd")
const Market=preload("res://scripts/domain/market_foraging.gd")
const Base=preload("res://tests/harbor_foraging_tests.gd")
const Research=preload("res://scripts/domain/ramen_research.gd")
const Catalog=preload("res://scripts/domain/ingredient_catalog.gd")
const Config=preload("res://scripts/domain/data_check.gd")
const Directions=preload("res://scripts/domain/recipe_directions.gd")
const Save=preload("res://scripts/services/save_service.gd")
const ChefFixture=preload("res://tests/chef_challenge_tests.gd")
var check: Callable
var finished: bool=false


func ok(result: Dictionary, text: String) -> bool:
	check.call(result["ok"],text+": "+str(result.get("message","")))
	return bool(result["ok"])


func json(st: Object) -> String:
	return JSON.stringify(st.to_dict(),"",true)


func ready() -> State:
	var base:=Base.new()
	base.check=check
	var st: State=base.ready()
	ok(st.purchase_facility("bench_1"),"earned research notebook expansion")
	for id in Research.ids():
		if st.research_completed_ids().has(id): continue
		var cfg: Dictionary=Research.WITNESSES[id]
		var found: int=0
		for record in st.records():
			if Config.same_config(record["config"],cfg): found=record["record_id"]
		if found==0:
			st.start_new_recipe()
			for slot in Catalog.SLOTS: ok(st.set_draft_choice(slot,cfg[slot]),"actual rank3 research choice")
			ok(st.set_draft_price(cfg["price"]),"research price")
			ok(st.set_draft_name("산골 연구%d" % Research.ids().find(id)),"research name")
			ok(st.taste(),"actual rank3 research tasting")
			found=st.selected_record_id
		ok(st.submit_research(id,found),"submit actual research witness")
	while st.completed_service_days()<10: ok(st.serve(),"actual promotion service day")
	ok(st.apply_promotion(3),"earned rank3")
	check.call(not st.mountain_foraging_review()["unlocked"],"rank alone does not unlock sampling")
	for choice in ["g_dry_pepper","g_learn_mushroom"]:
		ok(st.start_expedition("mountain"),"original mountain supplier departure")
		ok(st.advance_expedition("t_grove"),"mountain grove")
		ok(st.advance_expedition(choice),"original supplier choice")
		ok(st.finish_expedition(),"original supplier claim")
		check.call(not st.start_mountain_foraging()["ok"],"supplier trip consumes shared day")
		ok(st.serve(),"next day after supplier")
	check.call(st.mountain_foraging_review()["can_start"],"two real suppliers unlock sampling")
	return st


func collect(st: State, target: String, amount: String="clean_three") -> void:
	ok(st.start_mountain_foraging(),"mountain departure")
	ok(st.advance_expedition(target),"mountain target")
	ok(st.advance_expedition(amount),"mountain quantity")
	ok(st.finish_expedition(),"explicit mountain claim")


func compose(st: State, direction: String, repeated: bool=false) -> void:
	# Revise a real family instead of bypassing notebook capacity.
	var cfg: Dictionary=Catalog.default_config()
	cfg["broth"]="broth_chicken" if direction=="mountain_clear" else "broth_tonkotsu"
	cfg["tare"]="tare_shio" if direction=="mountain_clear" else "tare_miso"
	cfg["oil"]="oil_scallion" if direction=="mountain_clear" else "oil_garlic"
	cfg["noodle"]="noodle_buckwheat" if direction=="mountain_clear" else "noodle_thin"
	for slot in Catalog.SLOTS:
		if slot!="topping": ok(st.set_draft_choice(slot,cfg[slot]),"open experiment ingredient")
	ok(st.set_draft_toppings(["topping_nori"] if direction=="mountain_clear" else ([Mountain.IDS[1],Mountain.IDS[1]] if repeated else [Mountain.IDS[1]])),"explicit portions")


func run(callback: Callable, data_dir: String) -> void:
	check=callback
	var fresh:=State.new()
	var before: String=json(fresh)
	check.call(not fresh.start_mountain_foraging()["ok"] and json(fresh)==before,"rank/supplier gate atomic")
	check.call(fresh.ingredient_lock_info(Mountain.IDS[0])["region"]=="mountain","source points to actual mountain")
	var st: State=ready()
	if not st.mountain_foraging_review()["can_start"]: return
	var money: int=st.wallet
	ok(st.start_mountain_foraging(),"exact departure")
	check.call(st.wallet==money-1600,"departure fee1600 once")
	before=json(st)
	for result in [st.start_foraging(),st.start_harbor_foraging(),st.start_mountain_foraging(),st.start_expedition("market"),st.taste(),st.begin_service(),st.advance_expedition("clean_three")]:
		check.call(not result["ok"] and json(st)==before,"shared active/invalid action does not mutate any state")
	for phase in 3:
		var store=Save.new(data_dir.path_join("phase%d" % phase))
		check.call(DirAccess.make_dir_recursive_absolute(store.dir)==OK,"isolated stage directory")
		ok(store.save_state(st),"save pending stage")
		var loaded:=State.new()
		check.call(store.load_into(loaded)["status"]=="ok" and json(loaded)==json(st),"exact pending stage disk restart")
		st=loaded
		if phase==0: ok(st.advance_expedition("shiitake_grill"),"choose grilled shiitake")
		elif phase==1: ok(st.advance_expedition("clean_three"),"choose three for extra800")
	check.call(st.wallet==money-2400 and st.sample_stock(Mountain.IDS[1])==0,"exact total and no early reward")
	ok(st.finish_expedition(),"claim three")
	check.call(st.sample_stock(Mountain.IDS[1])==3,"exact quantity")
	before=json(st)
	check.call(not st.finish_expedition()["ok"] and not st.start_harbor_foraging()["ok"] and json(st)==before,"claim replay and cross-route same day atomic")
	compose(st,"shiitake_depth",true)
	check.call(Directions.assess("shiitake_depth",st.draft_config)["matched"],"two portions are a real rich/aroma solution")
	money=st.wallet
	var cost: int=st.trial_cost()
	ok(st.taste(),"real repeated topping tasting")
	check.call(st.sample_stock(Mountain.IDS[1])==1 and st.mountain_foraging_state()["used"][Mountain.IDS[1]]==2 and st.wallet==money-cost,"two portions consumed only on paid success")
	before=json(st)
	check.call(not st.taste()["ok"] and json(st)==before,"shortage cannot spend cash or issue record")
	ok(st.serve(),"next day real service")
	collect(st,"buckwheat_mill","take_one")
	compose(st,"mountain_clear")
	check.call(Directions.assess("mountain_clear",st.draft_config)["matched"],"real buckwheat light/aroma/chew solution")
	ok(st.taste(),"one buckwheat sample tasting")
	check.call(st.sample_stock(Mountain.IDS[0])==0,"noodle uses one portion")
	var chef=ChefFixture.new()
	chef.check=check
	var used: Dictionary=st.mountain_foraging_state()["used"].duplicate(true)
	chef.operate(st)
	check.call(st.mountain_foraging_state()["used"]==used,"actual service can sell registered noodle at zero samples")
	var restored:=State.new()
	check.call(restored.load_from_dict(st.to_dict())=="" and json(restored)==json(st),"completed receipts/recipes/real service reload exactly")
	_corruptions(st)
	_combined(st)
	_chef_witness(st)
	_limits()
	_legacy(data_dir)
	finished=true


func _corruptions(st: State) -> void:
	for kind in ["missing","extra","stock","used","date","first","amount","path","fee","fraction","negative","stage","type","version","supplier"]:
		var raw: Dictionary=st.to_dict()
		var farm: Dictionary=raw["mountain_foraging"]
		match kind:
			"missing": raw.erase("mountain_foraging")
			"extra": farm["fake"]=1
			"stock": farm["stock"][Mountain.IDS[0]]+=1
			"used":
				farm["used"][Mountain.IDS[0]]=0
				farm["stock"][Mountain.IDS[0]]=farm["obtained"][Mountain.IDS[0]]
			"date": farm["history"][0]["day"]=1
			"first": farm["first_day"][Mountain.IDS[1]]=1
			"amount": farm["history"][0]["amount"]=30
			"path": farm["history"][0]["path"]=["shiitake_grill","take_three"]
			"fee": farm["history"][0]["extra"]=0
			"fraction": farm["stock"][Mountain.IDS[0]]=0.5
			"negative": farm["used"][Mountain.IDS[0]]=-1
			"stage": farm["active"]={"stage":"fake"}
			"type": farm["completed"]=true
			"version":
				raw["schema_version"]=14; raw.erase("broth_workshop"); raw.erase("noodle_workshop"); raw.erase("recipe_knowledge"); raw.erase("server_challenge")
				raw.erase("mountain_foraging")
			"supplier": raw["exploration"]["discovered"].pop_back()
		var target:=State.new()
		var before: String=json(target)
		check.call(target.load_from_dict(raw)!="" and json(target)==before,"invalid mountain save atomic: "+kind)
	# A deleted recipe still lives in the next revision's comparison witness.
	ok(st.set_draft_choice("noodle","noodle_thin"),"ordinary revision")
	ok(st.taste(),"real comparison witness")
	var raw: Dictionary=st.to_dict()
	raw["records"]=[st.records().back()]
	raw["selected_record_id"]=st.selected_record_id
	raw["last_feedback_record_id"]=st.last_feedback_record_id
	var target:=State.new()
	check.call(target.load_from_dict(raw)=="","deleted sampled record remains valid comparison")
	for id in Mountain.IDS:
		raw["mountain_foraging"]["used"][id]=0
		raw["mountain_foraging"]["stock"][id]=raw["mountain_foraging"]["obtained"][id]
	check.call(target.load_from_dict(raw).contains("소비"),"deleted recipe cannot erase witnessed sample use")


func _combined(st: State) -> void:
	# Stock from all regions commits atomically, including a late shortage.
	var base:=Base.new()
	base.check=check
	base.collect(st,"scallop_diver")
	ok(st.serve(),"next day for mountain stock")
	collect(st,"buckwheat_mill")
	ok(st.serve(),"next day for market suppliers")
	for choice in ["m_hear_recipe","m_buy_pickle"]:
		ok(st.start_expedition("market"),"actual market supplier")
		ok(st.advance_expedition("m_ask"),"market meeting")
		ok(st.advance_expedition(choice),"market supplier choice")
		ok(st.finish_expedition(),"market supplier claim")
		ok(st.serve(),"next day after market")
	ok(st.start_foraging(),"actual market sampling")
	ok(st.advance_expedition("sesame_stall"),"sesame")
	ok(st.advance_expedition("take_two"),"two sesame")
	ok(st.finish_expedition(),"claim sesame")
	compose(st,"mountain_clear")
	ok(st.set_draft_choice("oil",Market.IDS[0]),"market oil")
	ok(st.set_draft_toppings([Harbor.IDS[1],Mountain.IDS[1],Mountain.IDS[1]]),"mixed repeated toppings")
	var before: String=json(st)
	check.call(not st.taste()["ok"] and json(st)==before,"late mountain shortage does not consume earlier market/harbor ledger")
	ok(st.set_draft_toppings([Harbor.IDS[1],Mountain.IDS[1]]),"available portions")
	ok(st.taste(),"all three sampling ledgers commit together")
	check.call(st.sample_stock(Market.IDS[0])==1 and st.sample_stock(Harbor.IDS[1])==2 and st.sample_stock(Mountain.IDS[0])==2 and st.sample_stock(Mountain.IDS[1])==0,"exact multi-region portions")
	var loaded:=State.new()
	check.call(loaded.load_from_dict(st.to_dict())=="" and json(loaded)==json(st),"four-route calendar and mixed consumed witnesses reload")
	var same: Dictionary=Mountain.begin(Mountain.empty_state(),st.day,10000)["state"]
	check.call(State._sample_calendar_error([st.to_dict()["exploration"],st.foraging_state(),st.harbor_foraging_state(),same])!="","otherwise valid concurrent mountain departure rejected by cross-region calendar")


func _limits() -> void:
	var farm: Dictionary=Mountain.empty_state()
	for day in 20:
		farm=Mountain.begin(farm,day+1,10000)["state"]
		farm=Mountain.choose(farm,"buckwheat_mill",10000)["state"]
		farm=Mountain.choose(farm,"take_one",10000)["state"]
		farm=Mountain.finish(farm)["state"]
	farm=Mountain.begin(farm,21,10000)["state"]
	farm=Mountain.finish(farm,true)["state"]
	check.call(farm["stock"][Mountain.IDS[0]]==20 and farm["history"].size()==12 and farm["retired"]==1,"bounded history/full stock/paid retirement")
	check.call(Mountain.parse(farm,21,1)["error"]=="","trimmed valid receipts parse")
	farm=Mountain.begin(farm,22,10000)["state"]
	var before: String=JSON.stringify(farm)
	check.call(Mountain.choose(farm,"buckwheat_mill",10000)["error"]!="" and JSON.stringify(farm)==before,"full ingredient choice atomic")
	farm=Mountain.choose(farm,"shiitake_grill",10000)["state"]
	check.call(Mountain.choose(farm,"clean_three",799)["error"]!="","exact extra fee shortage")
	check.call(Mountain.finish(farm)["error"]!="","cannot claim before quantity")
	check.call(Mountain.finish(farm,true)["state"]["last_departure_day"]==22,"retirement retains shared day")


func _chef_witness(st: State) -> void:
	ok(st.start_chef_challenge(),"accept chef challenge after earned mountain stock")
	compose(st,"mountain_clear")
	ok(st.set_draft_process("noodle","moist"),"new noodle process after chef acceptance")
	ok(st.taste(),"new sampled recipe after chef acceptance")
	var chef=ChefFixture.new()
	chef.check=check
	chef.operate(st)
	var proof: Dictionary=st.to_dict()["chef_challenge"]["attempt"]
	check.call(not proof.is_empty() and proof["config"]["noodle"]==Mountain.IDS[0],"actual chef attempt retains sampled noodle witness")
	var only_chef: Dictionary={"chef_challenge":{"attempt":proof}}
	var farm: Dictionary=st.mountain_foraging_state()
	check.call(State._sample_witness_error(only_chef,farm,Mountain.IDS)=="","chef-only immutable receipt valid with real sample use")
	for id in Mountain.IDS:
		farm["used"][id]=0
		farm["stock"][id]=farm["obtained"][id]
	check.call(State._sample_witness_error(only_chef,farm,Mountain.IDS).contains("소비"),"chef proof alone prevents restoring spent samples")


func _legacy(data_dir: String) -> void:
	# A genuine progressed v14 shape includes earned chef mastery, never grants
	# mountain stock, and is backed up byte-for-byte on first v15 write.
	var st:=State.new()
	var chef=ChefFixture.new()
	chef.check=check
	ok(st.start_chef_challenge(),"old version chef acceptance")
	chef.fast(st)
	chef.operate(st)
	ok(st.claim_chef_challenge(),"old version earned mastery")
	var raw: Dictionary=st.to_dict()
	raw.erase("mountain_foraging")
	raw["schema_version"]=14; raw.erase("broth_workshop"); raw.erase("noodle_workshop"); raw.erase("recipe_knowledge"); raw.erase("server_challenge")
	var text: String=JSON.stringify(raw,"\t",true)+"\n"
	var store=Save.new(data_dir.path_join("legacy14"))
	check.call(DirAccess.make_dir_recursive_absolute(store.dir)==OK,"isolated legacy directory")
	var file=FileAccess.open(store.main_path(),FileAccess.WRITE)
	check.call(file!=null,"legacy fixture writable")
	if file==null: return
	file.store_string(text)
	file.close()
	var migrated:=State.new()
	check.call(store.load_into(migrated)["status"]=="ok" and migrated.mountain_foraging_state()==Mountain.empty_state(),"v14 migration grants no materials")
	var compared: Dictionary=migrated.to_dict()
	compared.erase("mountain_foraging")
	compared["schema_version"]=14; compared.erase("broth_workshop"); compared.erase("noodle_workshop"); compared.erase("recipe_knowledge"); compared.erase("server_challenge")
	check.call(compared==raw and migrated.chef_challenge_review()["status"]=="mastered","every progressed value/mastery exactly preserved")
	ok(store.save_state(migrated),"first v15 save")
	check.call(FileAccess.get_file_as_string(store.legacy_bak_path(14))==text,"original v14 bytes backed up")
	ok(store.save_state(migrated),"second v15 save")
	check.call(FileAccess.get_file_as_string(store.legacy_bak_path(14))==text,"v14 backup never overwritten")
