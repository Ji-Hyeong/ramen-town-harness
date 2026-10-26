extends SceneTree
## True current constructor: craft both broth and noodles. Only explicit isolated
## paths are written. Legacy compatibility is separately proven by frozen bytes.
const State=preload("res://scripts/domain/game_state.gd")
const Noodle=preload("res://scripts/domain/noodle_workshop.gd")
const Broth=preload("res://scripts/domain/broth_workshop.gd")
const Catalog=preload("res://scripts/domain/ingredient_catalog.gd")
const Check=preload("res://scripts/domain/data_check.gd")
const Eval=preload("res://scripts/domain/recipe_evaluator.gd")
const Save=preload("res://scripts/services/save_service.gd")
const Research=preload("res://scripts/domain/ramen_research.gd")
const Experiments=preload("res://scripts/domain/recipe_experiments.gd")
const MountainFixture=preload("res://tests/mountain_foraging_tests.gd")
var checks: int=0
var failures: Array[String]=[]
var data_dir: String=""

func verify(value: bool, message: String) -> void:
	checks+=1
	if not value: failures.append(message); printerr("FAIL: "+message)

func json(st: Object) -> String:
	return JSON.stringify(st.to_dict(),"",true)

func craft(st: State, formula: Dictionary) -> void:
	for field in Noodle.FIELDS: verify(st.set_noodle_formula(field,formula[field])["ok"],"actual noodle choice: "+field)
	var money: int=st.wallet
	var fee: int=st.noodle_review()["cost"]
	verify(st.begin_noodle()["ok"],"begin guarded production")
	verify(not st.advance_noodle(0.1)["finished"] and st.wallet==money,"early frame cannot grant or charge")
	verify(st.advance_noodle(20.0)["ok"] and st.wallet==money-fee,"one real completion fee")
	var before: String=json(st)
	verify(not st.advance_noodle(20.0)["ok"] and json(st)==before,"duplicate completion is atomic")

func broth(st: State, raw: Dictionary) -> void:
	verify(st.set_broth_blend(raw["ingredients"],raw["method"])["ok"],"select raw broth")
	verify(st.begin_broth()["ok"] and st.advance_broth(20.0)["ok"],"actually brew broth")
	verify(st.use_broth(st.broth_review()["recipes"].size()-1)["ok"],"explicitly apply broth")

## Search verifies reachability only. No player-facing autofill or injected
## resources bypasses actual production/research/service/promotion transactions.
func candidate(request: String) -> Dictionary:
	var pantry: Array=["pork_bone","chicken_bone","kelp","onion","ginger","garlic"]
	for a in pantry.size():
		for b in range(a,pantry.size()):
			for c in range(b,pantry.size()):
				for method in ["standard","gentle"]:
					var raw: Dictionary={"ingredients":[pantry[a],pantry[b],pantry[c]],"method":method}
					if Broth.error(raw,1)!="": continue
					var cfg: Dictionary=Catalog.normalize_config(Research.WITNESSES[request])
					cfg["broth"]=Broth.base_id(raw)
					cfg["broth_recipe"]=Broth.canonical(raw)
					cfg["noodle_recipe"]={"flour":"wheat","water":"clear","cut":str(cfg["noodle"]).trim_prefix("noodle_"),"method":"standard"}
					if method!="standard": cfg["process"]={"broth":method,"noodle":"standard"}
					var scores: Dictionary={}
					for customer in Eval.evaluate(cfg)["customers"]: scores[customer["id"]]=customer["score"]
					if Research.check(request,cfg,scores)["all_met"]: return cfg
	return {}

func progression() -> void:
	var st:=State.new()
	for request in ["dohyun_basic","hayoung_basic","maru_basic","dohyun_advanced","hayoung_advanced","maru_advanced"]:
		var cfg: Dictionary=candidate(request)
		verify(not cfg.is_empty(),"raw broth AND raw noodle research reachable: "+request)
		if cfg.is_empty(): return
		var index: int=-1
		for i in st.broth_review()["recipes"].size():
			if st.broth_review()["recipes"][i]["recipe"]==cfg["broth_recipe"]: index=i
		if index<0: broth(st,cfg["broth_recipe"])
		else: verify(st.use_broth(index)["ok"],"reuse actually crafted soup")
		index=-1
		for i in st.noodle_review()["recipes"].size():
			if st.noodle_review()["recipes"][i]["recipe"]==cfg["noodle_recipe"]: index=i
		if index<0:
			craft(st,cfg["noodle_recipe"])
			index=st.noodle_review()["recipes"].size()-1
		verify(st.use_noodle(index)["ok"],"explicitly use actually produced noodle")
		st.start_new_recipe()
		for slot in ["tare","oil","cook"]: verify(st.set_draft_choice(slot,cfg[slot])["ok"],"remaining recipe choice")
		verify(st.set_draft_toppings(cfg["toppings"])["ok"] and st.set_draft_price(cfg["price"])["ok"],"recipe portions and price")
		verify(st.taste()["ok"] and st.submit_research(request,st.selected_record_id)["ok"],"actual research submission: "+request)
		if request=="maru_basic":
			for i in 3: verify(st.serve()["ok"],"actual new-player service")
			verify(st.apply_promotion(2)["ok"],"new-player earns rank2")
	while st.completed_service_days()<10: verify(st.serve()["ok"],"late real service")
	verify(st.apply_promotion(3)["ok"] and st.rank()==3,"both raw systems reach rank3")
	verify(State.new().load_from_dict(st.to_dict())=="","whole raw-only progression validates")

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--test-data-dir="): data_dir=arg.substr(16)
	if not data_dir.begins_with("/private/tmp/"): printerr("Explicit isolated --test-data-dir required"); quit(2); return
	verify(DirAccess.make_dir_recursive_absolute(data_dir)==OK,"isolated directory")
	var st:=State.new()
	verify(not st.broth_ready() and not st.noodle_ready() and st.noodle_review()["recipes"].is_empty(),"new player has neither finished component")
	broth(st,{"ingredients":["chicken_bone","onion"],"method":"standard"})
	var before: String=json(st)
	verify(not st.taste()["ok"] and json(st)==before,"broth alone cannot bypass first noodle")
	verify(not st.set_draft_choice("noodle","noodle_thick")["ok"] and json(st)==before,"finished catalog selector cannot bypass production")
	for choice in [["flour","buckwheat"],["method","rested"],["cut","giant"],["water","unknown"],["unknown","thin"]]:
		verify(not st.set_noodle_formula(choice[0],choice[1])["ok"] and json(st)==before,"source/rank/unknown choices rejected atomically")
	verify(st.begin_noodle()["ok"],"begin cancellable noodle")
	var money: int=st.wallet
	before=json(st)
	for result in [st.begin_noodle(),st.begin_broth(),st.taste(),st.use_broth(0),st.use_noodle(0),st.set_broth_blend(["kelp"],"standard"),st.start_expedition("market"),st.begin_service(),st.start_foraging(),st.start_harbor_foraging(),st.start_mountain_foraging(),st.set_draft_price(10000)]:
		verify(not result["ok"] and json(st)==before,"production guards conflicting mutations")
	verify(not st.advance_noodle(NAN)["ok"] and not st.advance_noodle(-1.0)["ok"],"invalid deltas cannot progress work")
	var restart:=State.new()
	verify(restart.load_from_dict(st.to_dict())=="" and not restart.noodle_active() and restart.noodle_review()["recipes"].is_empty(),"restart cancels transient production without fee/product")
	verify(st.cancel_noodle()["ok"] and st.wallet==money,"cancel without charge")
	var formula: Dictionary=Noodle.empty_state()["formula"]
	craft(st,formula)
	verify(not st.noodle_ready(),"completion never silently applies product")
	verify(st.use_noodle(0)["ok"] and st.noodle_ready(),"explicitly use completed noodles")
	verify(st.taste()["ok"] and st.serve()["ok"],"actual current first tasting and service")
	var first: String=JSON.stringify(st.records(),"",true)
	var plain: Dictionary=st.draft_config.duplicate(true)
	formula["flour"]="strong"; formula["water"]="alkaline"; formula["cut"]="thick"; formula["method"]="moist"
	craft(st,formula)
	verify(st.use_noodle(1)["ok"],"explicit strong thick moist noodle")
	var rich: Dictionary=st.draft_config.duplicate(true)
	verify(Eval.unit_cost(rich)>Eval.unit_cost(plain) and Eval.prep_seconds(rich)>Eval.prep_seconds(plain),"thick alternative trades cost and time for texture")
	verify(Eval.build_profile(rich)!=Eval.build_profile(plain),"formula changes actual flavor profile")
	verify(first==JSON.stringify(st.records(),"",true),"new formula leaves tasted witnesses immutable")
	verify(not st.set_draft_process("noodle","standard")["ok"],"finished formula method cannot be silently changed")
	var available: Array[String]=[]
	for slot in Catalog.SLOTS:
		for option in Catalog.items(slot): available.append(option["id"])
	var clues: Dictionary=Experiments.clues(rich,available,1)
	verify(clues["error"]=="" and not clues["clues"].is_empty(),"crafted recipes retain useful counterfactual clues")
	for clue in clues["clues"]:
		verify(Check.config_error(clue["config"])=="" and clue["config"].has("noodle_recipe") and clue["config"].has("broth_recipe"),"every clue retains valid raw provenance")
	var store:=Save.new(data_dir.path_join("current"))
	verify(DirAccess.make_dir_recursive_absolute(store.dir)==OK and store.save_state(st)["ok"],"save current raw components")
	verify(store.load_into(restart)["status"]=="ok" and json(st)==json(restart),"exact schema17 disk round trip")
	before=json(st)
	for kind in ["missing","stats","source","uncrafted","method","id","duplicate","future","old_root","witness"]:
		var bad: Dictionary=st.to_dict()
		match kind:
			"missing": bad.erase("noodle_workshop")
			"stats": bad["draft"]["config"]["noodle_recipe"]["score"]=999
			"source": bad["noodle_workshop"]["formula"]["flour"]="buckwheat"
			"uncrafted": bad["noodle_workshop"]["recipes"].pop_back()
			"method": bad["draft"]["config"]["noodle_recipe"]["method"]="standard"
			"id": bad["draft"]["config"]["noodle"]="noodle_thin"
			"duplicate": bad["noodle_workshop"]["recipes"].append(bad["noodle_workshop"]["recipes"][0])
			"future": bad["noodle_workshop"]["recipes"][0]["day"]=9999
			"old_root": bad.erase("noodle_workshop"); bad["schema_version"]=16
			"witness": bad["records"][0]["config"].erase("noodle_recipe")
		verify(st.load_from_dict(bad)!="" and json(st)==before,"malformed nested formula rejected atomically: "+kind)
	var original: String=FileAccess.get_file_as_string("res://tests/fixtures/noodle-v16-save.json")
	var old: Dictionary=JSON.parse_string(original)
	var old_store:=Save.new(data_dir.path_join("v16"))
	verify(DirAccess.make_dir_recursive_absolute(old_store.dir)==OK,"old-save directory")
	var file:=FileAccess.open(old_store.main_path(),FileAccess.WRITE)
	file.store_string(original); file.close()
	var migrated:=State.new()
	verify(old_store.load_into(migrated)["status"]=="ok","genuine frozen v16 migrates")
	var compared: Dictionary=migrated.to_dict()
	compared.erase("noodle_workshop"); compared["schema_version"]=16
	verify(JSON.parse_string(JSON.stringify(compared))==old and migrated.noodle_review()["recipes"].is_empty(),"all old broth/menu/report/wallet values preserved without fake noodles")
	for record in old["records"]:
		verify(Eval.evaluate(Check.parse_config(record["config"],"baseline")["config"])["customers"]==Eval.evaluate(migrated.get_record(int(record["record_id"]))["config"])["customers"],"old actual evaluation remains equal")
	verify(old_store.save_state(migrated)["ok"] and FileAccess.get_file_as_string(old_store.legacy_bak_path(16))==original,"byte-identical v16 backup retained")
	var fixture:=MountainFixture.new()
	fixture.check=verify
	var advanced: State=fixture.ready()
	fixture.collect(advanced,"buckwheat_mill")
	var stock: int=advanced.sample_stock("noodle_buckwheat")
	formula={"flour":"buckwheat","water":"clear","cut":"medium","method":"rested"}
	craft(advanced,formula)
	verify(advanced.sample_stock("noodle_buckwheat")==stock,"crafting does not double-consume mountain sample")
	verify(advanced.use_noodle(0)["ok"],"apply earned mountain flour product")
	advanced.start_new_recipe()
	verify(advanced.taste()["ok"] and advanced.sample_stock("noodle_buckwheat")==stock-1,"successful tasting consumes exactly one earned sample")
	verify(State.new().load_from_dict(advanced.to_dict())=="","sample conservation and crafted witnesses validate together")
	progression()
	print("RAW NOODLE checks=%d failures=%d" % [checks,failures.size()])
	quit(0 if failures.is_empty() else 1)
