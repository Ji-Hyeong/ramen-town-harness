extends "res://tools/audit_campaign_progression.gd"
## Deterministic witness-free exploration, NOT a human novice playtest. Choices
## are random within starter materials; only paid scores choose the sale menu.
## No evaluator, forecast or hidden research witness is used by this policy.
const Check=preload("res://scripts/domain/data_check.gd")
const Broth=preload("res://scripts/domain/broth_workshop.gd")
const Knowledge=preload("res://scripts/domain/recipe_knowledge.gd")
const SEEDS: Array[int]=[11,29,73]
const PRICES: Array[int]=[6500,9000]
const BUDGETS: Array[int]=[1,3]
const RESERVE: int=12000
const MAX_RUNTIME_MS: int=180000
var _began: int=0

func _initialize() -> void:
	_began=Time.get_ticks_msec()
	var output: String=_new_output_from_args()
	if output=="":return
	var cases: Array=[]
	for seed_value in SEEDS:
		for price in PRICES:
			for budget in BUDGETS:
				var result: Dictionary=_explore(seed_value,price,budget,output)
				if not result.is_empty():cases.append(result)
	_check(cases.size()==12,"all twelve witness-free paths complete")
	# The final fresh-file write performs three checks; include them just as the
	# shared campaign driver does, so accepted JSON and the console count agree.
	var report: Dictionary={"format":1,"algorithm":"starter-random-paid-score-v1","schema":State.SCHEMA_VERSION,"seeds":SEEDS,"prices":PRICES,"attempts_per_day":BUDGETS,"days":DAYS,"reserve":RESERVE,"cases":cases,"checks":checks+3,"failures":failures,"limits":"Deterministic bots, not humans. Starter materials/standard methods only; fixed price, random experiments, perfect paid-record bookkeeping, at most one eligible research/day, no investments/exploration/contests/stories. Recipe outcomes never queried before actual paid tasting. Craft/service clocks accelerated, not human time or fun. Different experiment budgets consume the RNG differently, not a controlled menu-equivalent causal comparison."}
	if not _write_new(output.path_join("report.json"),JSON.stringify(report,"\t",true)+"\n"):quit(2);return
	print("WITNESS-FREE PATHS cases=%d actual_days=%d checks=%d failures=%d" % [cases.size(),cases.size()*DAYS,checks,failures.size()])
	quit(0 if failures.is_empty() else 1)

func _explore(seed_value: int,price: int,budget: int,output: String) -> Dictionary:
	var label: String="seed%d_price%d_try%d" % [seed_value,price,budget]
	var folder: String=output.path_join(label)
	if not _check(DirAccess.make_dir_absolute(folder)==OK,"new isolated path "+label):return {}
	var rng:=RandomNumberGenerator.new();rng.seed=seed_value
	var state:=State.new();var store:=Save.new(folder)
	if not _check(not state.broth_ready() and not state.noodle_ready() and state.wallet==State.START_WALLET,"genuinely fresh raw player "+label):return {}
	var rows: Array=[];var milestones: Dictionary={};var previous_disk: String=""
	var novel_keys: Dictionary={};var paid_scores: Dictionary={}
	for on_day in range(1,DAYS+1):
		if not _check(Time.get_ticks_msec()-_began<MAX_RUNTIME_MS,"bounded exploratory audit runtime"):return {}
		if not _check(state.day==on_day,"calendar before actual service"):return {}
		var start_wallet: int=state.wallet;var events: Array=[];var trials: Array=[]
		for attempt in budget:
			var trial: Dictionary=_trial(state,rng,price,events)
			if not bool(trial.get("ok",false)):return {}
			trials.append(trial)
		var submitted: String=""
		# Public request reviews may inspect already-paid notebook witnesses. They
		# never provide a recipe to the random experiment generator above.
		for request in Research.ids():
			if state.research_status(request)!="open":continue
			for record in state.records():
				if not state.research_check(request,int(record["record_id"]))["all_met"]:continue
				var reward: int=int(Research.REWARD_CASH[Research.find(request)["tier"]])
				if not _transaction(state,request,"research",reward,func() -> Dictionary:return state.submit_research(request,int(record["record_id"])),events):return {}
				submitted=request
				if not milestones.has("first_research"):milestones["first_research"]=on_day
				break
			if submitted!="":break
		var promotion: Dictionary=state.promotion_review()
		if promotion["eligible"]:
			var rank: int=int(promotion["next"])
			if not _transaction(state,"rank%d" % rank,"promotion",0,func() -> Dictionary:return state.apply_promotion(rank),events):return {}
			milestones["rank%d" % rank]=on_day
		var best: Dictionary=_paid_best(state.records())
		if not _check(not best.is_empty(),"at least one actual paid menu before opening"):return {}
		for record in state.records():
			novel_keys[Knowledge.config_key(record["config"])]=true
			paid_scores[JSON.stringify(record["scores"],"",true)]=true
		if not _success(state.set_selling_menus([int(best["record_id"])]),"explicit best paid menu selection"):return {}
		var ready_wallet: int=state.wallet
		if not _success(state.begin_service(),"begin actual runtime"):return {}
		if not _check(state.active_session().run_to_end(),"finish actual completed-order runtime"):return {}
		var actual: Dictionary=state.active_session().summary()
		var result: Dictionary=state.settle_service()
		if not _success(result,"actual settlement"):return {}
		var report: Dictionary=result["report"]
		if not _check(state.wallet==ready_wallet+int(report["net"]) and state.day==on_day+1,"single actual settlement advances cash/calendar once"):return {}
		var delta: int=0
		for event in events:delta+=int(event["delta"])
		if not _check(state.wallet==start_wallet+delta+int(report["net"]),"whole preparation/research/service cash ledger"):return {}
		var whole: String=_json(state)
		if not _success(store.save_state(state),"daily scoped disk save"):return {}
		if on_day>1 and not _check(FileAccess.get_file_as_string(store.bak_path())==previous_disk,"daily backup preserves exact previous snapshot"):return {}
		previous_disk=FileAccess.get_file_as_string(store.main_path())
		var restored:=State.new()
		if not _check(store.load_into(restored)["status"]=="ok" and _json(restored)==whole,"all-value daily restart"):return {}
		if not _check(not restored.settle_service()["ok"] and _json(restored)==whole,"restart cannot settle again"):return {}
		if not _write_new(folder.path_join("day-%02d.json" % on_day),previous_disk):return {}
		rows.append({"day":on_day,"wallet_before":start_wallet,"events":events,"trials":trials,"research":submitted,"rank":state.rank(),"paid_recipes":novel_keys.size(),"paid_score_profiles":paid_scores.size(),"sold":{"record_id":best["record_id"],"version":best["version"],"scores":best["scores"],"config_key":Knowledge.config_key(best["config"])},"completed":int(report["units"]),"service_net":int(report["net"]),"stars":actual["avg_stars"],"turned_away":actual["turned_away"],"wallet_after":state.wallet,"snapshot":"day-%02d.json" % on_day,"snapshot_sha256":FileAccess.get_sha256(store.main_path())})
		state=restored
	return {"id":label,"seed":seed_value,"price":price,"attempts_per_day":budget,"milestones":milestones,"ending_wallet":state.wallet,"ending_rank":state.rank(),"research_count":state.research_completed_ids().size(),"paid_recipes":novel_keys.size(),"paid_score_profiles":paid_scores.size(),"rows":rows}

func _trial(state: State,rng: RandomNumberGenerator,price: int,events: Array) -> Dictionary:
	if state.wallet<RESERVE:return {"ok":true,"status":"reserve_skip","wallet":state.wallet}
	var bases: Array=["kelp","chicken_bone","pork_bone"]
	var additives: Array=["","onion","ginger","garlic"]
	var ingredients: Array=[bases[rng.randi_range(0,2)]]
	var additive: String=additives[rng.randi_range(0,3)]
	if additive!="":ingredients.append(additive)
	var before: int=state.wallet
	if not _success(state.set_broth_blend(ingredients,"standard"),"legal random raw broth selection"):return {}
	var canon: Dictionary=Broth.canonical({"ingredients":ingredients,"method":"standard"})
	var index: int=-1
	for i in state.broth_review()["recipes"].size():
		if state.broth_review()["recipes"][i]["recipe"]==canon:index=i
	if index<0:
		if not _success(state.begin_broth(),"real paid raw broth") or not _success(state.advance_broth(20.0),"accelerated real broth work clock"):return {}
		index=state.broth_review()["recipes"].size()-1
	if not _success(state.use_broth(index),"explicit completed broth use"):return {}
	var formula: Dictionary={"flour":["wheat","strong"][rng.randi_range(0,1)],"water":["clear","alkaline"][rng.randi_range(0,1)],"cut":["thin","medium","thick"][rng.randi_range(0,2)],"method":"standard"}
	for field in ["flour","water","cut","method"]:
		if not _success(state.set_noodle_formula(field,formula[field]),"legal random noodle option"):return {}
	index=-1
	for i in state.noodle_review()["recipes"].size():
		if state.noodle_review()["recipes"][i]["recipe"]==formula:index=i
	if index<0:
		if not _success(state.begin_noodle(),"real paid noodle production") or not _success(state.advance_noodle(20.0),"accelerated real noodle work clock"):return {}
		index=state.noodle_review()["recipes"].size()-1
	if not _success(state.use_noodle(index),"explicit completed noodle use"):return {}
	for slot in ["tare","oil","cook"]:
		var choices: Array=state.available_items(slot)
		if not _check(not choices.is_empty(),"public legal starter choices exist"):return {}
		if not _success(state.set_draft_choice(slot,str(choices[rng.randi_range(0,choices.size()-1)]["id"])),"legal random bowl choice"):return {}
	var topping_choices: Array=state.available_items("topping")
	var toppings: Array=[]
	for i in rng.randi_range(1,mini(2,state.topping_slots())):toppings.append(topping_choices[rng.randi_range(0,topping_choices.size()-1)]["id"])
	if not _success(state.set_draft_toppings(toppings),"legal random topping portions") or not _success(state.set_draft_price(price),"fixed price policy"):return {}
	var craft_cost: int=before-state.wallet
	events.append({"kind":"craft","delta":-craft_cost})
	for record in state.records():
		if Check.same_config(record["config"],state.draft_config):return {"ok":true,"status":"duplicate_skip","craft_cost":craft_cost}
	var pre_taste: int=state.wallet
	var result: Dictionary=state.taste()
	if not _success(result,"actual paid tasting without a witness recipe"):return {}
	var taste_cost: int=pre_taste-state.wallet
	events.append({"kind":"taste","delta":-taste_cost})
	var paid: Dictionary=state.get_record(int(result["record_id"]))
	return {"ok":true,"status":"paid","craft_cost":craft_cost,"taste_cost":taste_cost,"record_id":paid["record_id"],"scores":paid["scores"],"config_key":Knowledge.config_key(paid["config"])}

## Only observed immutable paid scores choose a sale. New unknown draft values
## and theoretical outcome forecasts never enter this selection.
func _paid_best(records: Array) -> Dictionary:
	var best: Dictionary={};var best_sum: int=-1
	for record in records:
		var sum: int=0
		for score in record["scores"].values():sum+=int(score)
		if sum>best_sum or (sum==best_sum and int(record["record_id"])>int(best.get("record_id",0))):best=record;best_sum=sum
	return best
