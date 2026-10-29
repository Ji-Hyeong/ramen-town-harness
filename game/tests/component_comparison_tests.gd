extends SceneTree
## Domain proof for completed-component comparison and explicit re-experiment.
## Fresh-player cases use the real constructor and real crafts; only the tamper
## cases reach into private workshop data, and only to prove atomic refusal.
## Legacy/progressed states come from the frozen v16 save or the existing mountain
## fixture. Only the explicit isolated --test-data-dir is written.
const State=preload("res://scripts/domain/game_state.gd")
const Comparison=preload("res://scripts/domain/component_comparison.gd")
const Noodle=preload("res://scripts/domain/noodle_workshop.gd")
const Broth=preload("res://scripts/domain/broth_workshop.gd")
const Catalog=preload("res://scripts/domain/ingredient_catalog.gd")
const Check=preload("res://scripts/domain/data_check.gd")
const Eval=preload("res://scripts/domain/recipe_evaluator.gd")
const Methods=preload("res://scripts/domain/recipe_process.gd")
const Save=preload("res://scripts/services/save_service.gd")
const MountainFixture=preload("res://tests/mountain_foraging_tests.gd")
const RESPONSE_KEYS: Array=["applied","candidate_ramen","current_component","current_ramen","kind","message","ok","recipe","selected_component"]
var checks: int=0
var failures: Array[String]=[]
var data_dir: String=""
var next_price: int=Catalog.PRICE_MIN

func verify(value: bool, message: String) -> void:
	checks+=1
	if not value: failures.append(message); printerr("FAIL: "+message)

func json(value: Variant) -> String:
	return JSON.stringify(value.to_dict() if value is Object else value,"",true)

## Real production: one guarded fee, nothing applied to the bowl.
func brew(st: State, raw: Dictionary) -> int:
	verify(st.set_broth_blend(raw["ingredients"],raw["method"])["ok"],"select raw broth")
	var review: Dictionary=st.broth_review()
	var money: int=st.wallet
	verify(review["reason"]=="","brew is allowed: "+str(review["reason"]))
	verify(st.begin_broth()["ok"] and st.advance_broth(20.0)["ok"],"actually brew broth")
	verify(st.wallet==money-int(review["cost"]),"one real broth fee")
	return st.broth_review()["recipes"].size()-1

func knead(st: State, formula: Dictionary) -> int:
	for field in Noodle.FIELDS: verify(st.set_noodle_formula(field,formula[field])["ok"],"actual noodle choice: "+field)
	var review: Dictionary=st.noodle_review()
	var money: int=st.wallet
	verify(review["reason"]=="","knead is allowed: "+str(review["reason"]))
	verify(st.begin_noodle()["ok"] and st.advance_noodle(20.0)["ok"],"actually produce noodles")
	verify(st.wallet==money-int(review["cost"]),"one real noodle fee")
	return st.noodle_review()["recipes"].size()-1

func shape(r: Dictionary, label: String) -> void:
	var keys: Array=r.keys()
	keys.sort()
	verify(keys==RESPONSE_KEYS,"stable response keys: "+label)

## Compare must be a pure read: identical state bytes before and after, and the
## returned value can be mutated freely without touching the state.
func pure_compare(st: State, kind: String, index: int) -> Dictionary:
	var before: String=json(st)
	var r: Dictionary=st.component_comparison(kind,index)
	shape(r,kind+str(index))
	verify(json(st)==before,"comparison never mutates state: "+kind+str(index))
	var again: Dictionary=st.component_comparison(kind,index)
	verify(json(r)==json(again),"comparison is deterministic")
	r["recipe"]["method"]="tampered"
	r["selected_component"]["axes"]["rich"]=99
	if r["current_component"].has("axes"): r["current_component"]["axes"]["chew"]=99
	for key in ["current_ramen","candidate_ramen"]:
		if not r[key].is_empty(): r[key]["customers"].clear(); r[key]["profile"]["rich"]=99
	verify(json(st.component_comparison(kind,index))==json(again) and json(st)==before,"returned values are deep copies")
	return again

## The snapshot is taken BEFORE the action runs, so a mutating failure is caught.
func reject(st: State, label: String, action: Callable) -> void:
	var before: String=json(st)
	var result: Dictionary=action.call()
	if result.size()>2: shape(result,label)
	verify(not bool(result["ok"]) and str(result["message"])!="","explicit failure: "+label)
	verify(json(st)==before,"failure is atomic: "+label)

## Axis deltas of the evaluator must equal the component deltas whenever the final
## 0..10 clamp is not involved, proving a signed contribution is added once.
func axis_deltas(r: Dictionary, label: String) -> int:
	var tested: int=0
	for axis in Catalog.AXES:
		var a: int=int(r["current_ramen"]["profile"][axis])
		var b: int=int(r["candidate_ramen"]["profile"][axis])
		if a<=0 or a>=10 or b<=0 or b>=10: continue
		tested+=1
		verify(b-a==int(r["selected_component"]["axes"][axis])-int(r["current_component"]["axes"][axis]),"signed axis delta equals evaluator once: "+label+" "+axis)
	return tested

func strip_formula(d: Dictionary, kind: String) -> Dictionary:
	var out: Dictionary=JSON.parse_string(JSON.stringify(d))
	if kind=="broth":
		out["broth_workshop"].erase("ingredients"); out["broth_workshop"].erase("method")
	else: out["noodle_workshop"].erase("formula")
	return out

func pure_helper() -> void:
	var base: Dictionary=Catalog.default_config()
	var strong: Dictionary={"flour":"strong","water":"clear","cut":"thin","method":"standard"}
	var bowl: Dictionary=Comparison.apply_recipe(base,"noodle",strong)
	var part: Dictionary=Comparison.component(bowl,"noodle")
	verify(part["axes"]["aroma"]==-1 and part["axes"]["chew"]==4,"strong flour keeps signed aroma -1 (unclamped)")
	verify(part["cost"]==320 and part["seconds"]==40,"strong flour product cost and time")
	var rested: Dictionary={"flour":"buckwheat","water":"alkaline","cut":"medium","method":"rested"}
	var other: Dictionary=Comparison.apply_recipe(bowl,"noodle",rested)
	var method: Dictionary=Methods.method("noodle","rested")
	var product: Dictionary=Noodle.product(rested)
	var swapped: Dictionary=Comparison.component(other,"noodle")
	verify(swapped["cost"]==int(product["cost"])+int(method["cost"]) and swapped["seconds"]==int(product["seconds"])+int(method["seconds"]),"method cost/time applied exactly once")
	verify(swapped["axes"]["aroma"]==1 and swapped["axes"]["chew"]==int(product["axes"]["chew"])+2,"method axes applied exactly once")
	verify(Eval.unit_cost(other)-Eval.unit_cost(bowl)==int(swapped["cost"])-int(part["cost"]) and Eval.prep_seconds(other)-Eval.prep_seconds(bowl)==int(swapped["seconds"])-int(part["seconds"]),"component deltas equal evaluator cost/time deltas")
	verify(other["process"]=={"broth":"standard","noodle":"rested"} and not bowl.has("process"),"apply_recipe copies; only the swapped method changes and standard stays implicit")
	verify(not base.has("noodle_recipe") and base["noodle"]==Catalog.default_config()["noodle"],"apply_recipe never mutates its input")
	var soup: Dictionary={"ingredients":["chicken_bone","onion"],"method":"gentle"}
	var gentle: Dictionary=Comparison.component(Comparison.apply_recipe(base,"broth",soup),"broth")
	verify(gentle["axes"]["aroma"]==Broth.product(soup)["axes"]["aroma"]+2 and gentle["axes"]["rich"]==Broth.product(soup)["axes"]["rich"]-1 and gentle["cost"]==int(Broth.product(soup)["cost"])+180,"gentle method applied once to broth")
	verify(Comparison.component(base,"tare").is_empty() and Comparison.component({},"broth").is_empty(),"invalid slots yield no component")
	var extra: Dictionary={"ingredients":["chicken_bone","pork_bone"],"method":"standard","x":1}
	verify(Comparison.recipe_error("tare",soup,3,[])!="" and Comparison.recipe_error("broth",{"ingredients":["chicken_bone","pork_bone"],"method":"standard"},3,[])=="" and Comparison.recipe_error("broth",extra,3,[])!="","recipe validation is explicit")
	verify(Comparison.recipe_error("broth",{"ingredients":["pork_bone","chicken_bone"],"method":"standard"},3,[])!="","unsorted broth is not a stored canonical formula")

func new_player(st: State) -> void:
	verify(not st.broth_ready() and not st.noodle_ready(),"actual constructor has no finished component")
	for kind in ["broth","noodle"]:
		reject(st,"no finished "+kind,func(): return st.component_comparison(kind,0))
		reject(st,"nothing to reload: "+kind,func(): return st.load_component_recipe(kind,0))
	for bad in [["tare",0],["",0],["broth",-1],["noodle",5]]:
		reject(st,"invalid request "+str(bad),func(): return st.component_comparison(bad[0],bad[1]))
		reject(st,"invalid reload "+str(bad),func(): return st.load_component_recipe(bad[0],bad[1]))
	verify(str(st.component_comparison("tare",0)["kind"])=="","an unsupported kind is never echoed as supported")
	var soup: Dictionary={"ingredients":["chicken_bone","onion"],"method":"standard"}
	var index: int=brew(st,soup)
	var r: Dictionary=pure_compare(st,"broth",index)
	var expected: Dictionary=Comparison.component(Comparison.apply_recipe(st.draft_config,"broth",soup),"broth")
	verify(r["ok"] and r["selected_component"]==expected and not r["applied"],"finished broth reviewable before it is in the bowl")
	verify(r["current_component"].is_empty() and r["current_ramen"].is_empty() and r["candidate_ramen"].is_empty(),"new player gets no phantom before-bowl")
	reject(st,"no noodle exists yet",func(): return st.component_comparison("noodle",0))
	verify(st.use_broth(index)["ok"],"explicitly use broth")
	r=pure_compare(st,"broth",index)
	verify(r["applied"] and r["current_component"]==r["selected_component"],"applied broth is its own baseline")
	verify(r["current_ramen"].is_empty() and r["candidate_ramen"].is_empty(),"one finished component is still not a full bowl")
	var formula: Dictionary={"flour":"wheat","water":"clear","cut":"thin","method":"standard"}
	index=knead(st,formula)
	r=pure_compare(st,"noodle",index)
	verify(r["ok"] and not r["applied"] and r["current_component"].is_empty() and r["current_ramen"].is_empty() and r["candidate_ramen"].is_empty(),"unused noodle does not turn the default catalog noodle into a finished baseline")
	verify(pure_compare(st,"broth",0)["current_ramen"].is_empty(),"broth review stays partial until the noodle is in the bowl")
	verify(st.use_noodle(index)["ok"],"explicitly use noodle")
	r=pure_compare(st,"noodle",index)
	verify(r["applied"] and r["current_ramen"]==Eval.evaluate(st.draft_config) and r["candidate_ramen"]==r["current_ramen"],"full bowl evaluates the real draft; applying the same product changes nothing")
	verify(st.taste()["ok"],"actual first tasting")

func swap_numbers(st: State) -> void:
	var soup: Dictionary={"ingredients":["pork_bone","chicken_bone","garlic"],"method":"gentle"}
	var soup_index: int=brew(st,soup)
	var thick: Dictionary={"flour":"strong","water":"alkaline","cut":"thick","method":"moist"}
	var noodle_index: int=knead(st,thick)
	var cur: Dictionary=st.draft_config.duplicate(true)
	for pair in [["broth",soup_index],["noodle",noodle_index]]:
		var kind: String=pair[0]
		var r: Dictionary=pure_compare(st,kind,pair[1])
		verify(r["ok"] and not r["applied"] and not r["current_ramen"].is_empty() and not r["candidate_ramen"].is_empty(),"complete before/after exists: "+kind)
		verify(r["current_ramen"]==Eval.evaluate(cur),"before equals actual evaluator: "+kind)
		var clone:=State.new()
		verify(clone.load_from_dict(st.to_dict())=="","clone for actual swap: "+kind)
		verify((clone.use_broth(pair[1]) if kind=="broth" else clone.use_noodle(pair[1]))["ok"],"actual use: "+kind)
		verify(r["candidate_ramen"]==Eval.evaluate(clone.draft_config),"candidate equals evaluator with exactly one component swapped: "+kind)
		verify(r["candidate_ramen"]["unit_cost"]-r["current_ramen"]["unit_cost"]==int(r["selected_component"]["cost"])-int(r["current_component"]["cost"]),"component cost delta equals actual unit cost delta: "+kind)
		verify(r["candidate_ramen"]["prep_seconds"]-r["current_ramen"]["prep_seconds"]==int(r["selected_component"]["seconds"])-int(r["current_component"]["seconds"]),"component time delta equals actual prep delta: "+kind)
		verify(axis_deltas(r,kind)>0,"at least one unclamped axis proves the signed delta: "+kind)
		verify(clone.draft_config.get("process",{}).get(kind)==r["recipe"]["method"],"selected method is exactly the swapped slot method")
		for key in ["recipe","selected_component"]: verify(not r[key].is_empty(),"selected data present: "+key)
	var noodle: Dictionary=st.component_comparison("noodle",noodle_index)["selected_component"]
	var product: Dictionary=Noodle.product(thick)
	verify(noodle["axes"]["aroma"]==-1 and noodle["axes"]["chew"]==int(product["axes"]["chew"])-2 and noodle["cost"]==int(product["cost"])+80 and noodle["seconds"]==int(product["seconds"])-8,"signed strong flour/moist method contribution is counted once")
	verify(st.draft_config==cur,"comparison never changed the bowl")

func busy_guards(st: State) -> void:
	verify(st.set_broth_blend(["kelp"],"standard")["ok"] and st.begin_broth()["ok"],"begin cancellable brew")
	var before: String=json(st)
	var live: Dictionary=st.component_comparison("broth",0)
	verify(live["ok"] and json(st)==before,"review remains readable during work without mutation")
	reject(st,"reload while brewing",func(): return st.load_component_recipe("broth",0))
	reject(st,"reload noodle while brewing",func(): return st.load_component_recipe("noodle",0))
	verify(st.cancel_broth()["ok"],"cancel brew")
	var formula: Dictionary=st.noodle_review()["formula"]
	verify(st.set_noodle_formula("cut","medium")["ok"] and st.begin_noodle()["ok"],"begin cancellable noodle")
	reject(st,"reload while kneading",func(): return st.load_component_recipe("broth",0))
	reject(st,"reload noodle while kneading",func(): return st.load_component_recipe("noodle",0))
	verify(st.cancel_noodle()["ok"] and st.set_noodle_formula("cut",formula["cut"])["ok"],"cancel noodle")

## Reload is free and explicit: only the matching draft changes. The next real
## change creates a new product and a distinct immutable ramen record.
func reload_cycle(st: State) -> void:
	verify(st.use_broth(1)["ok"] and st.use_noodle(1)["ok"],"bowl uses the second broth and noodle")
	verify(st.taste()["ok"],"record with second products")
	var kept: Dictionary=st.draft_config.duplicate(true)
	var first: String=JSON.stringify(st.records(),"",true)
	var before: Dictionary=st.to_dict()
	var original: Dictionary=st.broth_review()["recipes"][0]["recipe"]
	var result: Dictionary=st.load_component_recipe("broth",0)
	verify(result["ok"] and str(result["message"])!="","explicit broth reload succeeds")
	var after: Dictionary=st.to_dict()
	verify(JSON.stringify(strip_formula(after,"broth"),"",true)==JSON.stringify(strip_formula(before,"broth"),"",true),"broth reload changes only the broth draft")
	verify(after["broth_workshop"]["ingredients"]==original["ingredients"] and after["broth_workshop"]["method"]==original["method"],"raw formula copied from the finished recipe")
	verify(st.draft_config==kept and st.wallet==before["wallet"] and not st.broth_active() and not st.noodle_active(),"reload keeps bowl and wallet, starts no work")
	var review: Dictionary=st.broth_review()
	verify(review["reason"]!="" and not st.begin_broth()["ok"] and st.wallet==before["wallet"],"reloaded formula cannot be re-completed or charged")
	var settled: String=json(st)
	verify(st.load_component_recipe("broth",0)["ok"] and json(st)==settled,"reload is repeatable and idempotent")
	verify(st.set_broth_blend(["chicken_bone","onion","garlic"],"standard")["ok"],"change the reloaded formula")
	var money: int=st.wallet
	var fee: int=st.broth_review()["cost"]
	verify(st.begin_broth()["ok"] and st.advance_broth(20.0)["finished"] and st.wallet==money-fee,"changed formula is a new real craft charged once")
	var made: int=st.broth_review()["recipes"].size()-1
	verify(made==2 and st.draft_config==kept,"completed craft is not auto-applied")
	verify(st.use_broth(made)["ok"] and st.taste()["ok"],"explicit use then real tasting")
	var rows: Array=st.records()
	verify(rows.size()==3 and JSON.stringify(rows.slice(0,2),"",true)==first,"new tasting appends without rewriting prior records")
	verify(rows[2]["record_id"]!=rows[1]["record_id"] and rows[2]["config"]["broth_recipe"]!=rows[1]["config"]["broth_recipe"] and rows[2]["comparison"]["prev_record_id"]==rows[1]["record_id"],"distinct immutable revision record")
	# The same cycle for noodles.
	var noodle_before: Dictionary=st.to_dict()
	verify(st.load_component_recipe("noodle",0)["ok"],"explicit noodle reload")
	var noodle_after: Dictionary=st.to_dict()
	verify(JSON.stringify(strip_formula(noodle_after,"noodle"),"",true)==JSON.stringify(strip_formula(noodle_before,"noodle"),"",true) and noodle_after["noodle_workshop"]["formula"]==noodle_before["noodle_workshop"]["recipes"][0]["recipe"],"noodle reload changes only the noodle draft")
	verify(not st.begin_noodle()["ok"] and st.wallet==noodle_before["wallet"],"reloaded noodle is free and not re-completed")
	verify(st.set_noodle_formula("cut","medium")["ok"],"change reloaded noodle")
	money=st.wallet
	fee=st.noodle_review()["cost"]
	verify(st.begin_noodle()["ok"] and st.advance_noodle(20.0)["finished"] and st.wallet==money-fee,"new noodle craft charged once")
	verify(st.use_noodle(st.noodle_review()["recipes"].size()-1)["ok"] and st.taste()["ok"] and st.records().size()==4,"fourth distinct record from new noodle")
	verify(JSON.stringify(st.records().slice(0,3),"",true)==JSON.stringify(rows,"",true),"earlier records remain byte-identical")

func tamper(st: State) -> void:
	var clone:=State.new()
	verify(clone.load_from_dict(st.to_dict())=="","tamper clone")
	clone._broth_workshop["recipes"][0]["recipe"]["method"]="rolling"
	reject(clone,"formula above the current rank",func(): return clone.component_comparison("broth",0))
	reject(clone,"reload of rank-gated formula",func(): return clone.load_component_recipe("broth",0))
	clone._broth_workshop["recipes"][0]["recipe"]={"ingredients":["onion","chicken_bone"],"method":"standard"}
	reject(clone,"unsorted stored formula",func(): return clone.component_comparison("broth",0))
	clone._noodle_workshop["recipes"][0]["recipe"]["flour"]="buckwheat"
	reject(clone,"unearned source formula",func(): return clone.component_comparison("noodle",0))
	reject(clone,"unearned source reload",func(): return clone.load_component_recipe("noodle",0))
	var other:=State.new()
	verify(other.load_from_dict(st.to_dict())=="","draft tamper clone")
	other.draft_config["junk"]=1
	reject(other,"invalid bowl config",func(): return other.component_comparison("broth",0))
	other.draft_config.erase("junk")
	other.draft_config["noodle"]="noodle_thick"
	reject(other,"bowl formula does not match product",func(): return other.component_comparison("broth",0))

func persistence(st: State) -> void:
	var keys: Array=st.to_dict().keys()
	keys.sort()
	var expected: Array=State.TOP_KEYS.duplicate()
	expected.sort()
	verify(State.SCHEMA_VERSION==19 and keys==expected and st.to_dict()["schema_version"]==19,"schema19 includes server challenge while comparison leaves persisted keys intact")
	var store:=Save.new(data_dir.path_join("current"))
	verify(DirAccess.make_dir_recursive_absolute(store.dir)==OK and store.save_state(st)["ok"],"save reloaded and crafted formulas")
	var restart:=State.new()
	verify(store.load_into(restart)["status"]=="ok" and json(st)==json(restart),"exact disk round trip")
	for kind in ["broth","noodle"]:
		var size: int=st.broth_review()["recipes"].size() if kind=="broth" else st.noodle_review()["recipes"].size()
		for i in size: verify(json(st.component_comparison(kind,i))==json(restart.component_comparison(kind,i)),"same comparison after restart: "+kind+str(i))
	# Current-schema round trip; genuine frozen17 migration lives in recipe_knowledge_tests.gd.
	verify(st.load_component_recipe("broth",0)["ok"],"draft reload before saving")
	var raw: String=JSON.stringify(st.to_dict(),"\t",true)
	var old:=Save.new(data_dir.path_join("v18"))
	verify(DirAccess.make_dir_recursive_absolute(old.dir)==OK,"v18 directory")
	var file:=FileAccess.open(old.main_path(),FileAccess.WRITE)
	file.store_string(raw); file.close()
	var loaded:=State.new()
	verify(old.load_into(loaded)["status"]=="ok" and json(loaded)==json(st),"current bytes load unchanged")
	verify(loaded.broth_review()["blend"]["ingredients"]==Broth.canonical(loaded.broth_review()["recipes"][0]["recipe"])["ingredients"],"reloaded draft survives disk")
	var snapshot: String=json(loaded)
	for i in loaded.broth_review()["recipes"].size(): loaded.component_comparison("broth",i)
	verify(snapshot==json(loaded) and FileAccess.get_file_as_string(old.main_path())==raw,"saved file and state untouched by review")

func old_save() -> void:
	var original: String=FileAccess.get_file_as_string("res://tests/fixtures/noodle-v16-save.json")
	var store:=Save.new(data_dir.path_join("v16"))
	verify(DirAccess.make_dir_recursive_absolute(store.dir)==OK,"v16 directory")
	var file:=FileAccess.open(store.main_path(),FileAccess.WRITE)
	file.store_string(original); file.close()
	var st:=State.new()
	verify(store.load_into(st)["status"]=="ok" and st.noodle_ready() and st.noodle_review()["recipes"].is_empty(),"frozen v16 loads with a historical noodle and no fabricated crafts")
	var r: Dictionary=pure_compare(st,"broth",0)
	verify(r["ok"] and r["applied"] and r["current_ramen"]==Eval.evaluate(st.draft_config),"historical bowl is a valid baseline against its crafted broth")
	for record in JSON.parse_string(original)["records"]:
		verify(Eval.evaluate(st.get_record(int(record["record_id"]))["config"])["customers"]==Eval.evaluate(Check.parse_config(record["config"],"baseline")["config"])["customers"],"old evaluation unchanged")
	var index: int=knead(st,{"flour":"wheat","water":"clear","cut":"medium","method":"standard"})
	r=pure_compare(st,"noodle",index)
	var catalog: Dictionary=Catalog.find(str(st.draft_config["noodle"]))
	var method: Dictionary=Methods.method("noodle",Methods.selected(st.draft_config.get("process",{}),"noodle"))
	verify(r["ok"] and r["current_component"]["name"]==catalog["name"] and r["current_component"]["cost"]==int(catalog["cost"])+int(method["cost"]) and r["current_component"]["seconds"]==int(catalog["seconds"])+int(method["seconds"]),"historical catalog noodle is the exact baseline, method once")
	verify(not r["current_ramen"].is_empty() and r["current_ramen"]==Eval.evaluate(st.draft_config) and axis_deltas(r,"v16")>=0,"historical full baseline evaluates")
	var kept: Dictionary=st.draft_config.duplicate(true)
	verify(st.load_component_recipe("noodle",index)["ok"] and st.draft_config==kept and st.noodle_ready(),"old save can reload without touching the historical bowl")
	for key in ["current_ramen","candidate_ramen"]: verify(not st.component_comparison("noodle",index)[key].is_empty(),"old save keeps evaluations: "+key)

## Earned research stock gates only later production and tasting, never review or reload.
func research_stock() -> void:
	var fixture:=MountainFixture.new()
	fixture.check=verify
	var st: State=fixture.ready()
	fixture.collect(st,"buckwheat_mill")
	var stock: int=st.sample_stock("noodle_buckwheat")
	verify(stock>0,"earned mountain flour stock")
	var buck: int=knead(st,{"flour":"buckwheat","water":"clear","cut":"medium","method":"rested"})
	var wheat: int=knead(st,{"flour":"strong","water":"clear","cut":"thin","method":"standard"})
	verify(st.sample_stock("noodle_buckwheat")==stock,"crafting spends no sample")
	var r: Dictionary=pure_compare(st,"noodle",buck)
	verify(r["ok"] and not r["current_component"].is_empty() and r["current_ramen"]==Eval.evaluate(st.draft_config) and r["candidate_ramen"]==Eval.evaluate(Comparison.apply_recipe(st.draft_config,"noodle",r["recipe"])),"progressed legacy bowl compares against a historical baseline")
	verify(r["selected_component"]["axes"]["aroma"]==1 and r["selected_component"]["axes"]["chew"]==7,"buckwheat/rested keeps flour and method signs once")
	verify(st.use_noodle(buck)["ok"],"use buckwheat noodle")
	st.start_new_recipe()
	var guard: int=0
	while st.sample_stock("noodle_buckwheat")>0 and guard<200 and next_price<=Catalog.PRICE_MAX:
		guard+=1
		if st.set_draft_price(next_price)["ok"]: st.taste()
		next_price+=Catalog.PRICE_STEP
	verify(st.sample_stock("noodle_buckwheat")==0,"real tastings consumed every earned sample")
	verify(next_price<=Catalog.PRICE_MAX and st.set_draft_price(next_price)["ok"],"unused price remains")
	reject(st,"zero stock blocks tasting",func(): return st.taste())
	var before: String=json(st)
	r=pure_compare(st,"noodle",buck)
	verify(r["ok"] and r["applied"] and not r["candidate_ramen"].is_empty() and json(st)==before,"zero stock still allows review")
	verify(st.component_comparison("noodle",wheat)["ok"] and not st.component_comparison("noodle",wheat)["candidate_ramen"].is_empty(),"zero stock review of the other formula")
	var wallet: int=st.wallet
	verify(st.use_noodle(wheat)["ok"] and st.load_component_recipe("noodle",buck)["ok"],"zero stock still reloads an earned formula")
	verify(st.noodle_review()["formula"]["flour"]=="buckwheat" and st.wallet==wallet and st.sample_stock("noodle_buckwheat")==0,"reload spends nothing")
	verify(not st.begin_noodle()["ok"] and st.wallet==wallet,"nothing completes from reload")
	verify(st.taste()["ok"],"non-sample bowl can still be tasted")

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--test-data-dir="): data_dir=arg.substr(16)
	if not data_dir.begins_with("/private/tmp/"): printerr("Explicit isolated --test-data-dir required"); quit(2); return
	verify(DirAccess.make_dir_recursive_absolute(data_dir)==OK,"isolated directory")
	pure_helper()
	var st:=State.new()
	new_player(st)
	swap_numbers(st)
	busy_guards(st)
	reload_cycle(st)
	tamper(st)
	persistence(st)
	old_save()
	research_stock()
	print("COMPONENT COMPARISON checks=%d failures=%d" % [checks,failures.size()])
	quit(0 if failures.is_empty() else 1)
