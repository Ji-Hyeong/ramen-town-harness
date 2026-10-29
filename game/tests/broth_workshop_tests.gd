extends SceneTree
## Current new-game acceptance, historical v16 behavior, independent of the v15 fixtures
## used by historical regression suites. Only isolated paths are written.
const State=preload("res://scripts/domain/game_state.gd")
const Broth=preload("res://scripts/domain/broth_workshop.gd")
const Catalog=preload("res://scripts/domain/ingredient_catalog.gd")
const Check=preload("res://scripts/domain/data_check.gd")
const Eval=preload("res://scripts/domain/recipe_evaluator.gd")
const Save=preload("res://scripts/services/save_service.gd")
const HarborFixture=preload("res://tests/harbor_foraging_tests.gd")
const Research=preload("res://scripts/domain/ramen_research.gd")
var checks: int=0
var failures: Array[String]=[]
var data_dir: String=""

## This is the historical v16 broth-only gate. Current v17 first-game acceptance
## lives in noodle_workshop_tests and requires both real products.
func broth_state() -> State:
	var st:=State.new()
	var previous: Dictionary=st.to_dict()
	previous.erase("noodle_workshop"); previous.erase("recipe_knowledge"); previous.erase("server_challenge")
	previous["schema_version"]=16
	var err: String=st.load_from_dict(previous)
	if err!="": push_error(err)
	return st

func verify(value: bool, message: String) -> void:
	checks+=1
	if not value: failures.append(message); printerr("FAIL: "+message)

func json(st: Object) -> String:
	return JSON.stringify(st.to_dict(),"",true)

func brew(st: State, ids: Array, method: String="standard") -> void:
	verify(st.set_broth_blend(ids,method)["ok"],"set actual raw blend")
	var fee: int=st.broth_review()["cost"]
	var wallet: int=st.wallet
	verify(st.begin_broth()["ok"],"begin real guarded brew")
	verify(not st.advance_broth(0.1)["finished"] and st.wallet==wallet,"early frame has no completed product or fee")
	verify(st.advance_broth(10.0)["ok"] and st.wallet==wallet-fee,"completion creates and charges exactly once")
	var after: String=json(st)
	verify(not st.advance_broth(10.0)["ok"] and json(st)==after,"duplicate completion is atomic")

## Search is a verification fixture, not a player-facing recipe autofill. It
## establishes that the new mandatory craft loop can actually finish the old
## research/promotion game instead of relying only on premade legacy witnesses.
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
					if method!="standard": cfg["process"]={"broth":method,"noodle":"standard"}
					var evaluation: Dictionary=Eval.evaluate(cfg)
					var scores: Dictionary={}
					for customer in evaluation["customers"]: scores[customer["id"]]=customer["score"]
					if Research.check(request,cfg,scores)["all_met"]: return cfg
	return {}

func new_game_progression() -> void:
	var st:=broth_state()
	var requests: Array=["dohyun_basic","hayoung_basic","maru_basic","dohyun_advanced","hayoung_advanced","maru_advanced"]
	for request in requests:
		var cfg: Dictionary=candidate(request)
		verify(not cfg.is_empty(),"raw-only pantry can satisfy research: "+request)
		if cfg.is_empty(): return
		var raw: Dictionary=cfg["broth_recipe"]
		var index: int=-1
		for i in st.broth_review()["recipes"].size():
			if st.broth_review()["recipes"][i]["recipe"]==raw: index=i
		if index<0:
			brew(st,raw["ingredients"],raw["method"])
			index=st.broth_review()["recipes"].size()-1
		verify(st.use_broth(index)["ok"],"progression explicitly uses actual brewed product")
		st.start_new_recipe()
		for slot in ["tare","oil","noodle","cook"]: verify(st.set_draft_choice(slot,cfg[slot])["ok"],"progression ingredient choice")
		verify(st.set_draft_toppings(cfg["toppings"])["ok"] and st.set_draft_price(cfg["price"])["ok"],"progression topping and selling price")
		verify(st.taste()["ok"],"new-player raw broth tasting for "+request)
		verify(st.submit_research(request,st.selected_record_id)["ok"],"actual research submission for "+request)
		if request=="maru_basic":
			for day_index in 3: verify(st.serve()["ok"],"real new-player service day")
			verify(st.apply_promotion(2)["ok"] and st.rank()==2,"fresh raw-only game earns rank2 and fourth blend position")
	while st.completed_service_days()<10: verify(st.serve()["ok"],"real late promotion service")
	verify(st.apply_promotion(3)["ok"] and st.rank()==3,"fresh raw-only game earns rank3 and fifth position")
	verify(broth_state().load_from_dict(st.to_dict())=="","complete raw-only research/rank3 progression remains a valid save")

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--test-data-dir="): data_dir=arg.substr(16)
	if not data_dir.begins_with("/private/tmp/"):
		printerr("Use an explicit isolated /private/tmp/ --test-data-dir")
		quit(2); return
	verify(DirAccess.make_dir_recursive_absolute(data_dir)==OK,"isolated test directory")
	var st:=broth_state()
	verify(not st.broth_ready() and st.broth_review()["recipes"].is_empty(),"new player is given no completed broth")
	var before: String=json(st)
	verify(not st.taste()["ok"] and json(st)==before,"direct tasting cannot bypass first broth")
	verify(not st.set_draft_choice("broth","broth_chicken")["ok"] and json(st)==before,"catalog choice cannot grant a premade broth")
	verify(not st.begin_broth()["ok"] and json(st)==before,"empty blend cannot brew")
	verify(st.set_broth_blend(["ginger"],"standard")["ok"],"partial draft may begin with an aromatic")
	verify(not st.begin_broth()["ok"],"aromatics alone are not a finished soup")
	for raw in [["unknown"],[1],[true],["pork_bone","pork_bone","pork_bone","pork_bone"],["clam"],["shiitake"],["sardine"]]:
		before=json(st)
		verify(not st.set_broth_blend(raw,"standard")["ok"] and json(st)==before,"unknown/rank/source gate is atomic: "+str(raw))
	before=json(st)
	verify(not st.set_broth_blend(["pork_bone"],"rolling")["ok"] and json(st)==before,"rank1 cannot use rank2 extraction")
	verify(st.set_broth_blend(["pork_bone","chicken_bone","garlic"],"standard")["ok"],"three genuine raw portions at rank1")
	verify(st.begin_broth()["ok"],"begin cancellable work")
	var money: int=st.wallet
	before=json(st)
	for result in [st.begin_broth(),st.taste(),st.use_broth(0),st.set_draft_choice("noodle","noodle_thin"),st.start_expedition("market"),st.begin_service(),st.set_broth_blend(["chicken_bone"],"standard")]:
		verify(not result["ok"] and json(st)==before,"brewing blocks conflicting/duplicate transactions")
	var resumed:=broth_state()
	verify(resumed.load_from_dict(st.to_dict())=="" and not resumed.broth_active() and resumed.broth_review()["recipes"].is_empty(),"restart preserves blend, cancels incomplete work without a product")
	verify(st.cancel_broth()["ok"] and st.wallet==money and st.broth_review()["recipes"].is_empty(),"cancel has no fee or recipe")
	brew(st,["pork_bone","chicken_bone","garlic"])
	verify(not st.broth_ready(),"finished broth is not silently applied")
	verify(st.use_broth(0)["ok"] and st.broth_ready(),"explicitly use completed broth")
	var rich_cfg: Dictionary=st.draft_config.duplicate(true)
	verify(Check.config_error(rich_cfg)=="","actual crafted ramen config validates")
	verify(Catalog.broth_name(rich_cfg).contains("겹맛"),"mixed main ingredients have a generated product identity")
	verify(st.taste()["ok"],"actual first ramen tasting succeeds")
	var first: Dictionary=st.get_record(st.selected_record_id)
	var record_before: String=JSON.stringify(first,"",true)
	verify(st.serve()["ok"],"crafted broth flows through real service")
	brew(st,["chicken_bone","kelp","ginger"],"gentle")
	verify(st.use_broth(1)["ok"],"use second craft")
	var clear_cfg: Dictionary=st.draft_config.duplicate(true)
	verify(Eval.unit_cost(clear_cfg)!=Eval.unit_cost(rich_cfg) and Eval.prep_seconds(clear_cfg)!=Eval.prep_seconds(rich_cfg),"raw blend replaces actual per-bowl cost and prep time")
	var rich: Dictionary=Eval.build_profile(rich_cfg)
	var clear: Dictionary=Eval.build_profile(clear_cfg)
	print("BLEND PROFILES rich=",rich," clear=",clear)
	verify(rich["rich"]>clear["rich"] and rich["aroma"]<clear["aroma"],"bone vs clear aromatic tradeoff is not a universal upgrade")
	verify(not st.set_draft_process("broth","standard")["ok"],"cannot change a completed broth's extraction in ramen composition")
	verify(JSON.stringify(st.get_record(first["record_id"]),"",true)==record_before,"later blend/edit cannot mutate old tasting record")
	st.start_new_recipe()
	verify(st.taste()["ok"],"different raw blend creates a real second ramen")
	brew(st,["pork_bone","pork_bone","onion"])
	verify(st.use_broth(2)["ok"],"repeated raw ingredient portions work")
	verify(not Check.same_config(st.draft_config,rich_cfg),"raw provenance distinguishes menus sharing a base type")
	st.start_new_recipe()
	verify(st.taste()["ok"],"third materially distinct menu accepted")
	var store:=Save.new(data_dir.path_join("current"))
	verify(DirAccess.make_dir_recursive_absolute(store.dir)==OK and store.save_state(st)["ok"],"save all completed recipes and active ramen")
	var loaded:=broth_state()
	var load_result: Dictionary=store.load_into(loaded)
	print("CURRENT DISK LOAD ",load_result)
	verify(load_result["status"]=="ok" and json(loaded)==json(st),"exact current schema16 disk round trip")
	before=json(st)
	for kind in ["missing","fake_stats","unknown_raw","uncrafted","method","capacity","duplicate","future_day","legacy_version"]:
		var bad: Dictionary=st.to_dict()
		match kind:
			"missing": bad.erase("broth_workshop")
			"fake_stats": bad["draft"]["config"]["broth_recipe"]["score"]=999
			"unknown_raw": bad["draft"]["config"]["broth_recipe"]["ingredients"]=["mystery"]
			"uncrafted": bad["broth_workshop"]["recipes"].pop_back()
			"method": bad["draft"]["config"]["broth_recipe"]["method"]="rolling"
			"capacity": bad["broth_workshop"]["ingredients"]=["pork_bone","pork_bone","pork_bone","pork_bone"]
			"duplicate": bad["broth_workshop"]["recipes"].append(bad["broth_workshop"]["recipes"][0].duplicate(true))
			"future_day": bad["broth_workshop"]["recipes"][0]["day"]=9999
			"legacy_version": bad["schema_version"]=15; bad.erase("broth_workshop"); bad.erase("noodle_workshop"); bad.erase("recipe_knowledge"); bad.erase("server_challenge")
		verify(st.load_from_dict(bad)!="" and json(st)==before,"corrupt craft rejected atomically: "+kind)
	# This fixture was emitted by frozen, unmodified main/v15, not by editing a
	# schema16 save until it looked old. Keep the original bytes as migration proof.
	var original: String=FileAccess.get_file_as_string("res://tests/fixtures/broth-v15-save.json")
	var old_raw: Dictionary=JSON.parse_string(original)
	var old_store:=Save.new(data_dir.path_join("v15"))
	verify(DirAccess.make_dir_recursive_absolute(old_store.dir)==OK,"legacy save directory")
	var file:=FileAccess.open(old_store.main_path(),FileAccess.WRITE)
	file.store_string(original); file.close()
	var migrated:=broth_state()
	verify(old_store.load_into(migrated)["status"]=="ok","frozen real v15 save migrates")
	var compared: Dictionary=migrated.to_dict()
	compared.erase("broth_workshop"); compared.erase("noodle_workshop"); compared.erase("recipe_knowledge"); compared.erase("server_challenge"); compared["schema_version"]=15
	verify(JSON.parse_string(JSON.stringify(compared))==old_raw,"every v15 wallet/day/config/score/report value is preserved")
	verify(migrated.broth_review()["recipes"].is_empty(),"migration fabricates no brewed recipes")
	verify(old_store.save_state(migrated)["ok"] and FileAccess.get_file_as_string(old_store.legacy_bak_path(15))==original,"first v16 save retains byte-identical old backup")
	verify(Broth.capacity(1)==3 and Broth.capacity(2)==4 and Broth.capacity(3)==5,"rank progressively opens actual3/4/5 raw positions")
	var archived: Dictionary=st.broth_review()
	archived["recipes"].clear()
	archived["blend"]["ingredients"].clear()
	verify(st.broth_review()["recipes"].size()==3 and st.broth_review()["blend"]["ingredients"].size()==3,"view snapshots cannot mutate recipes or current blend")
	var permutation: Dictionary=rich_cfg.duplicate(true)
	permutation["broth_recipe"]["ingredients"].reverse()
	verify(Check.same_config(rich_cfg,permutation),"ingredient order is the same actual broth recipe")
	verify(not Check.same_config(rich_cfg,clear_cfg),"different raw blend is a different recipe")
	# A legitimately progressed pre-v16 player can use the new system with real
	# rank/suppliers/sampling. No wallet, rank, supplier or stock is injected.
	var fixture:=HarborFixture.new()
	fixture.check=verify
	var advanced: State=fixture.ready()
	verify(advanced.set_broth_blend(["clam","kelp","onion","ginger"],"rolling")["ok"],"earned rank2 and supplier unlock fourth material and strong extraction")
	verify(advanced.begin_broth()["ok"] and advanced.advance_broth(10.0)["ok"],"real unlocked raw clam brew")
	verify(advanced.use_broth(0)["ok"] and advanced.draft_config["broth"]=="broth_clam","raw clam determines actual broth identity")
	fixture.collect(advanced,"sardine_boat")
	var samples: int=advanced.sample_stock("broth_roasted_sardine")
	verify(samples==3,"real harbor sampling supplies three sardine portions")
	brew(advanced,["sardine","kelp","ginger"])
	verify(advanced.sample_stock("broth_roasted_sardine")==samples,"brewing does not secretly double-charge ramen research samples")
	verify(advanced.use_broth(1)["ok"],"use actual sardine blend")
	advanced.start_new_recipe()
	verify(advanced.taste()["ok"] and advanced.sample_stock("broth_roasted_sardine")==samples-1,"successful crafted ramen consumes one real sample exactly once")
	var advanced_copy:=broth_state()
	verify(advanced_copy.load_from_dict(advanced.to_dict())=="","crafted farming provenance agrees with sample conservation and stored tasting witnesses")
	new_game_progression()
	print("RAW BROTH checks=%d failures=%d" % [checks,failures.size()])
	quit(0 if failures.is_empty() else 1)
