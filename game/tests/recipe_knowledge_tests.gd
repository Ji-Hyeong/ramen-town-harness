extends SceneTree
## Domain proof for recipe knowledge: a recipe is revealed only by a real, successful, explicit
## selection (or paid tasting) while both bowl components are genuinely ready; previews, partial
## bowls, failures, edits of price/name and save/load never reveal anything.
## Current-player cases use the real constructor and real crafts; the few private pokes are
## limited to building an "unknown but ready" bowl through the public save format.
## Run with --test-data-dir=/private/tmp/...; only that isolated directory is written.
const State=preload("res://scripts/domain/game_state.gd")
const Knowledge=preload("res://scripts/domain/recipe_knowledge.gd")
const Comparison=preload("res://scripts/domain/component_comparison.gd")
const Catalog=preload("res://scripts/domain/ingredient_catalog.gd")
const Eval=preload("res://scripts/domain/recipe_evaluator.gd")
const Check=preload("res://scripts/domain/data_check.gd")
const Save=preload("res://scripts/services/save_service.gd")
var checks: int=0
var failures: Array[String]=[]
var data_dir: String=""
## Configs the fresh player really selected (good, neutral and bad), for the restart checks.
var tried: Array=[]

func verify(value: bool, message: String) -> void:
	checks+=1
	if not value: failures.append(message); printerr("FAIL: "+message)

func json(value: Variant) -> String:
	return JSON.stringify(value.to_dict() if value is Object else value,"",true)

func count(st: State) -> int:
	return st.to_dict()["recipe_knowledge"]["keys"].size()

## Everything except the bowl and the knowledge list: money, day, records, stock, formulas...
func core(st: State) -> String:
	var d: Dictionary=st.to_dict()
	d.erase("draft"); d.erase("recipe_knowledge")
	return JSON.stringify(d,"",true)

func with_field(cfg: Dictionary, field: String, value: Variant) -> Dictionary:
	var next: Dictionary=cfg.duplicate(true)
	next[field]=value
	return Catalog.normalize_config(next)

func brew(st: State, raw: Dictionary) -> int:
	verify(st.set_broth_blend(raw["ingredients"],raw["method"])["ok"],"select raw broth")
	verify(st.broth_review()["reason"]=="" and st.begin_broth()["ok"] and st.advance_broth(20.0)["ok"],"actually brew broth")
	return st.broth_review()["recipes"].size()-1

func knead(st: State, formula: Dictionary) -> int:
	for field in ["flour","water","cut","method"]: verify(st.set_noodle_formula(field,formula[field])["ok"],"noodle choice "+field)
	verify(st.noodle_review()["reason"]=="" and st.begin_noodle()["ok"] and st.advance_noodle(20.0)["ok"],"actually knead noodles")
	return st.noodle_review()["recipes"].size()-1

func shape_ok(view: Dictionary, label: String) -> void:
	var keys: Array=view.keys()
	keys.sort()
	verify(keys==["compat","known"],"stable knowledge keys: "+label)

func unknown_view(st: State, cfg: Dictionary, label: String) -> void:
	var view: Dictionary=st.recipe_knowledge(cfg)
	shape_ok(view,label)
	verify(view["known"]==false and view["compat"]==[] and not st.recipe_known(cfg),"unknown reveals nothing: "+label)

func reject(st: State, label: String, action: Callable) -> void:
	var before: String=json(st)
	var result: Dictionary=action.call()
	verify(not bool(result["ok"]) and str(result["message"])!="" and not result.has("discovered"),"explicit failure: "+label)
	verify(json(st)==before,"failure is atomic and reveals nothing: "+label)

func expect_reveal(st: State, label: String, expected: Dictionary, action: Callable, keep_core: bool=true) -> void:
	verify(not st.recipe_known(expected),"unknown before: "+label)
	var before: String=core(st)
	var n: int=count(st)
	var r: Dictionary=action.call()
	verify(bool(r["ok"]),"selection succeeds: "+label)
	verify(r.get("discovered",false)==true,"selection reports the discovery: "+label)
	verify(st.recipe_known(expected) and st.recipe_known(st.draft_config) and count(st)==n+1,"exactly that recipe is now known: "+label)
	if keep_core: verify(core(st)==before,"selection grants nothing else: "+label)

func ready_player() -> State:
	var st:=State.new()
	var b: int=brew(st,{"ingredients":["chicken_bone","onion"],"method":"standard"})
	var n: int=knead(st,{"flour":"wheat","water":"clear","cut":"thin","method":"standard"})
	verify(st.use_broth(b)["ok"] and st.use_noodle(n)["ok"],"bowl uses both finished components")
	return st

## Same player, but the knowledge list is forgotten: a ready bowl whose recipe is unknown.
func forgotten(st: State) -> State:
	var d: Dictionary=st.to_dict()
	d["recipe_knowledge"]={"keys":[]}
	var out:=State.new()
	verify(out.load_from_dict(d)=="","load with empty knowledge")
	verify(out.broth_ready() and out.noodle_ready() and not out.recipe_known(out.draft_config),"ready but unknown bowl")
	return out

func identity() -> void:
	var base: Dictionary=Catalog.default_config()
	var key: String=Knowledge.config_key(base)
	verify(key!="" and Knowledge.config_key(Catalog.default_config())==key,"stable key")
	var priced: Dictionary=base.duplicate(true)
	priced["price"]=Catalog.PRICE_MIN
	verify(Knowledge.config_key(priced)==key,"price is not part of the recipe")
	var no_price: Dictionary=base.duplicate(true)
	no_price.erase("price")
	verify(Knowledge.config_key(no_price)==key,"missing price is tolerated for previews")
	var old_shape: Dictionary=base.duplicate(true)
	old_shape.erase("toppings")
	old_shape["topping"]=base["toppings"][0]
	verify(Knowledge.config_key(old_shape)==key,"legacy single-topping shape is the same recipe")
	var spelled: Dictionary=base.duplicate(true)
	spelled["process"]={"broth":"standard","noodle":"standard"}
	verify(Knowledge.config_key(spelled)==key,"explicit standard methods equal the implicit default")
	var shuffled: Dictionary={}
	var names: Array=base.keys()
	names.reverse()
	for k in names: shuffled[k]=base[k]
	verify(Knowledge.config_key(shuffled)==key,"dictionary order is irrelevant")
	var ab: Dictionary=with_field(base,"toppings",["topping_egg","topping_chashu"])
	var ba: Dictionary=with_field(base,"toppings",["topping_chashu","topping_egg"])
	verify(Knowledge.config_key(ab)==Knowledge.config_key(ba),"topping order is presentation only")
	var soup: Dictionary={"ingredients":["chicken_bone","onion"],"method":"standard"}
	var variants: Array=[base,
		with_field(base,"cook","cook_soft"), with_field(base,"tare","tare_miso"), with_field(base,"oil","oil_chili"),
		with_field(base,"toppings",["topping_egg"]), with_field(base,"toppings",["topping_egg","topping_egg"]),
		with_field(base,"toppings",["topping_egg","topping_egg","topping_egg"]), ab,
		with_field(base,"process",{"broth":"standard","noodle":"rested"}),
		with_field(base,"process",{"broth":"gentle","noodle":"standard"}),
		Comparison.apply_recipe(base,"broth",soup),
		Comparison.apply_recipe(base,"broth",{"ingredients":["chicken_bone","garlic"],"method":"standard"}),
		Comparison.apply_recipe(base,"broth",{"ingredients":["chicken_bone","onion"],"method":"gentle"}),
		Comparison.apply_recipe(base,"noodle",{"flour":"wheat","water":"clear","cut":"thin","method":"standard"}),
		Comparison.apply_recipe(base,"noodle",{"flour":"strong","water":"clear","cut":"thin","method":"standard"}),
		Comparison.apply_recipe(base,"noodle",{"flour":"wheat","water":"alkaline","cut":"thin","method":"standard"}),
		Comparison.apply_recipe(base,"noodle",{"flour":"wheat","water":"clear","cut":"thin","method":"moist"})]
	var seen: Dictionary={}
	for v in variants:
		verify(Knowledge.config_key(v)!="","variant is a valid recipe")
		seen[Knowledge.config_key(v)]=true
	verify(seen.size()==variants.size() and not seen.has(""),"cooking, portions, methods, raw formulas and finished-vs-catalog all differ")
	# Same raw formula twice is one identity even if the callers built it independently.
	var again: Dictionary=Comparison.apply_recipe(Catalog.default_config(),"broth",soup.duplicate(true))
	verify(Knowledge.config_key(again)==Knowledge.config_key(Comparison.apply_recipe(priced,"broth",soup)),"raw broth formula identity ignores price")
	# Malformed input is safely unknown.
	# Raw copies on purpose: normalize_config is only for configs already known to be shaped correctly.
	var junk: Dictionary=base.duplicate(true)
	junk["junk"]=1
	var half_formula: Dictionary=base.duplicate(true)
	half_formula["noodle_recipe"]={"flour":"wheat"}
	var bad_cases: Array=[{}, with_field(base,"tare","tare_nope"), with_field(base,"toppings",["topping_egg","topping_egg","topping_egg","topping_egg","topping_egg"]),
		with_field(base,"toppings",[]), with_field(base,"price",12345), with_field(base,"process",{"broth":"x"}), junk,
		half_formula, with_field(base,"cook",7)]
	var index: Dictionary={Knowledge.config_key(base):true}
	for bad in bad_cases:
		verify(Knowledge.config_key(bad)=="" and Knowledge.entry(bad).is_empty(),"malformed has no identity: "+str(bad.keys()))
		var view: Dictionary=Knowledge.view(index,bad)
		verify(view=={"known":false,"compat":[]},"malformed reads as unknown")
		var added: Dictionary=Knowledge.with_recipe(Knowledge.empty_state(),{},bad)
		verify(not added["added"] and added["state"]["keys"].is_empty(),"malformed is never stored")
	# No aliases: callers can keep editing their dictionaries and arrays.
	var empty: Dictionary=Knowledge.empty_state()
	var cfg: Dictionary=with_field(base,"toppings",["topping_chashu"])
	var cfg_key: String=Knowledge.config_key(cfg)
	var stored: Dictionary=Knowledge.with_recipe(empty,{},cfg)
	cfg["toppings"].append("topping_egg")
	cfg["tare"]="tare_miso"
	verify(stored["added"] and stored["state"]["keys"]==[cfg_key] and cfg_key.length()==64,"stores one SHA-256 hash, not the caller's data")
	verify(empty["keys"].is_empty(),"input state is not mutated")
	var shown: Dictionary=Knowledge.view(stored["index"],base.duplicate(true))
	shown["compat"].append({"score":99,"note":"x"})
	verify(Knowledge.view(stored["index"],base.duplicate(true))["compat"]!=shown["compat"],"returned views are fresh copies")
	explore_many()

## Real, distinct, valid recipes far beyond any former ceiling: every one must be stored and recognised.
func explore_many() -> void:
	var base: Dictionary=Catalog.default_config()
	var pool: Array=["topping_chashu","topping_egg","topping_sprouts","topping_nori"]
	var portions: Array=[]
	for size in range(1,5): multisets(pool,size,0,[],portions)
	var state: Dictionary=Knowledge.empty_state()
	var index: Dictionary={}
	var expected: int=0
	var configs: Array=[]
	for tare in ["tare_shoyu","tare_shio","tare_miso"]:
		for oil in ["oil_garlic","oil_chili","oil_scallion"]:
			for cook in ["cook_firm","cook_normal","cook_soft"]:
				for tops in portions:
					var cfg: Dictionary=with_field(with_field(with_field(with_field(base,"tare",tare),"oil",oil),"cook",cook),"toppings",tops)
					var added: Dictionary=Knowledge.with_recipe(state,index,cfg)
					verify(added["added"],"every distinct real recipe is stored")
					state=added["state"]; index=added["index"]
					expected+=1
					configs.append(cfg)
	verify(expected>800 and state["keys"].size()==expected and index.size()==expected,"more than 800 distinct real experiments are all kept")
	for cfg in configs: verify(Knowledge.view(index,cfg)["known"],"each stays known")
	# They round-trip through a real save as hashes only.
	var st:=State.new()
	var d: Dictionary=st.to_dict()
	d["recipe_knowledge"]={"keys":state["keys"].duplicate()}
	verify(st.load_from_dict(d)=="" and count(st)==expected and st.recipe_known(configs[expected-1]) and st.recipe_known(configs[0]),"many hashes load and answer")
	var store:=Save.new(data_dir.path_join("many"))
	var restart:=State.new()
	verify(DirAccess.make_dir_recursive_absolute(store.dir)==OK and store.save_state(st)["ok"] and store.load_into(restart)["status"]=="ok" and json(restart)==json(st),"many experiments persist and restart")

func multisets(pool: Array, size: int, start: int, current: Array, out: Array) -> void:
	if current.size()==size: out.append(current.duplicate()); return
	for i in range(start,pool.size()):
		current.append(pool[i])
		multisets(pool,size,i,current,out)
		current.pop_back()

func fresh_flow() -> State:
	var st:=State.new()
	var defaults: Dictionary=st.draft_config.duplicate(true)
	unknown_view(st,defaults,"fresh defaults")
	verify(count(st)==0 and st.to_dict()["recipe_knowledge"]=={"keys":[]},"fresh player knows nothing")
	# Partial / unprepared bowl: choices succeed but the component-less bowl reveals nothing.
	var partial: Array=[func(): return st.set_draft_choice("tare","tare_shio"), func(): return st.set_draft_choice("oil","oil_scallion"),
		func(): return st.set_draft_choice("cook","cook_normal"), func(): return st.set_draft_toppings(["topping_egg"]),
		func(): return st.toggle_draft_topping("topping_nori"), func(): return st.set_draft_process("broth","gentle"),
		func(): return st.set_draft_process("noodle","moist")]
	for action in partial:
		var r: Dictionary=action.call()
		verify(not r.has("discovered") and count(st)==0 and not st.recipe_known(st.draft_config),"fresh partial bowl reveals nothing")
	reject(st,"catalog broth for a fresh player",func(): return st.set_draft_choice("broth","broth_chicken"))
	reject(st,"catalog noodle for a fresh player",func(): return st.set_draft_choice("noodle","noodle_thick"))
	var soup: Dictionary={"ingredients":["chicken_bone","onion"],"method":"standard"}
	var b: int=brew(st,soup)
	verify(count(st)==0,"crafting a broth reveals nothing")
	var look: Dictionary=st.draft_config.duplicate(true)
	var snapshot: String=json(st)
	st.component_comparison("broth",b); st.recipe_known(look); st.recipe_knowledge(look)
	verify(json(st)==snapshot,"comparison and knowledge queries are read-only")
	verify(st.load_component_recipe("broth",b)["ok"] and count(st)==0,"reloading a workshop formula reveals nothing")
	var used: Dictionary=st.use_broth(b)
	verify(used["ok"] and not used.has("discovered") and count(st)==0 and not st.recipe_known(st.draft_config),"a finished broth alone is a partial bowl")
	var n: int=knead(st,{"flour":"wheat","water":"clear","cut":"thin","method":"standard"})
	verify(count(st)==0 and not st.recipe_known(st.draft_config),"crafting a noodle without applying reveals nothing")
	var thick: int=knead(st,{"flour":"wheat","water":"clear","cut":"thick","method":"standard"})
	verify(st.load_component_recipe("noodle",n)["ok"] and count(st)==0,"noodle reload reveals nothing")
	# Applying the second finished component completes the bowl: now the exact recipe is known.
	var wallet: int=st.wallet
	var chosen: Dictionary=Comparison.apply_recipe(st.draft_config,"noodle",st.noodle_review()["recipes"][n]["recipe"])
	var applied: Dictionary=st.use_noodle(n)
	verify(applied["ok"] and applied.get("discovered",false)==true and st.recipe_known(chosen) and count(st)==1,"applying the second finished component reveals the bowl")
	verify(st.wallet==wallet and st.recipe_known(st.draft_config),"discovery costs nothing")
	tried.append(st.draft_config.duplicate(true))
	verify(not st.use_noodle(n).has("discovered") and count(st)==1,"repeating a selection discovers nothing new")
	# A candidate preview never reveals; the explicit selection does.
	var candidate: Dictionary=Comparison.apply_recipe(st.draft_config,"noodle",st.noodle_review()["recipes"][thick]["recipe"])
	unknown_view(st,candidate,"thick-noodle preview")
	var cmp: Dictionary=st.component_comparison("noodle",thick)
	verify(cmp["ok"] and not cmp["candidate_ramen"].is_empty(),"the existing comparison still computes")
	unknown_view(st,candidate,"after comparison")
	verify(count(st)==1,"comparison revealed nothing")
	# Price/name never create or hide knowledge.
	var base_known: Dictionary=st.draft_config.duplicate(true)
	verify(st.set_draft_price(Catalog.PRICE_MIN)["ok"] and st.recipe_known(base_known) and st.recipe_known(st.draft_config) and count(st)==1,"price edit keeps the same knowledge")
	verify(st.set_draft_name("다른 이름")["ok"] and st.recipe_known(base_known) and count(st)==1,"name edit keeps the same knowledge")
	# Neutral recipe: known with no rules, never an invented bonus.
	for action in [func(): return st.set_draft_choice("tare","tare_shio"), func(): return st.set_draft_choice("oil","oil_garlic"),
			func(): return st.set_draft_choice("cook","cook_normal"), func(): return st.set_draft_toppings(["topping_chashu"])]:
		verify(action.call()["ok"],"neutral recipe choice")
	verify(Eval.applied_compat(st.draft_config).is_empty(),"precondition: this recipe has no compatibility rule")
	tried.append(st.draft_config.duplicate(true))
	var neutral: Dictionary=st.recipe_knowledge(st.draft_config)
	shape_ok(neutral,"neutral")
	verify(neutral["known"]==true and neutral["compat"]==[],"known neutral result lists nothing")
	# Bad recipe: remembered with its penalties, exactly the evaluator's list.
	verify(st.set_draft_choice("cook","cook_soft")["ok"] and st.use_noodle(thick)["ok"],"choose a clashing bowl")
	tried.append(st.draft_config.duplicate(true))
	var bad: Dictionary=st.recipe_knowledge(st.draft_config)
	var rules: Array=Eval.applied_compat(st.draft_config)
	verify(bad["known"] and bad["compat"].size()==rules.size() and not rules.is_empty(),"bad recipe lists the evaluator's rules")
	var total: int=0
	for i in rules.size():
		verify(bad["compat"][i]["score"]==rules[i]["score"] and bad["compat"][i]["note"]==rules[i]["note"],"note %d matches the evaluator" % i)
		verify(bad["compat"][i].keys().size()==2,"entry has exactly score and note")
		total+=int(rules[i]["score"])
	verify(total<0 and Eval.compat_total(rules)<0,"the remembered result is a genuinely bad one")
	bad["compat"].clear()
	verify(st.recipe_knowledge(st.draft_config)["compat"].size()==rules.size(),"mutating a returned view changes nothing")
	# A paid tasting confirms and records as usual.
	verify(st.set_draft_choice("cook","cook_firm")["ok"],"firm cooking")
	var money: int=st.wallet
	var cost: int=st.trial_cost()
	var tasted: Dictionary=st.taste()
	verify(tasted["ok"] and st.wallet==money-cost and st.record_count()==1,"actual tasting charges and records once")
	verify(st.recipe_known(st.get_record(1)["config"]),"a tasted recipe is known")
	# A second finished broth stays unapplied, so later cases have a real component to select.
	brew(st,{"ingredients":["pork_bone","garlic"],"method":"standard"})
	return st

func choice_paths(base: State) -> void:
	var u: State=forgotten(base)
	var cfg: Dictionary=u.draft_config.duplicate(true)
	# Read-only: queries, previews, price/name, new-recipe, serialization, reload never reveal.
	var snapshot: String=json(u)
	u.recipe_known(cfg); u.recipe_knowledge(cfg); u.component_comparison("noodle",1)
	verify(json(u)==snapshot,"previews are read-only on an unknown bowl")
	# A revision keeps its menu name, so naming is only possible once a new recipe is started (also reveals nothing).
	reject(u,"renaming a revision",func(): return u.set_draft_name("임시 이름"))
	u.start_new_recipe()
	verify(u.set_draft_price(Catalog.PRICE_MIN)["ok"] and u.set_draft_name("임시 이름")["ok"] and count(u)==0 and not u.recipe_known(cfg),"price and name edits reveal nothing")
	verify(count(u)==0 and u.load_component_recipe("noodle",1)["ok"] and count(u)==0,"new recipe and workshop reload reveal nothing")
	var round_trip:=State.new()
	verify(round_trip.load_from_dict(u.to_dict())=="" and count(round_trip)==0 and not round_trip.recipe_known(round_trip.draft_config),"serialize and load reveal nothing")
	# Each explicit successful bowl mutation confirms exactly the new recipe.
	expect_reveal(u,"cooking",with_field(u.draft_config,"cook","cook_soft"),func(): return u.set_draft_choice("cook","cook_soft"))
	expect_reveal(u,"tare",with_field(u.draft_config,"tare","tare_miso"),func(): return u.set_draft_choice("tare","tare_miso"))
	expect_reveal(u,"oil",with_field(u.draft_config,"oil","oil_chili"),func(): return u.set_draft_choice("oil","oil_chili"))
	expect_reveal(u,"single topping",with_field(u.draft_config,"toppings",["topping_egg"]),func(): return u.set_draft_choice("topping","topping_egg"))
	expect_reveal(u,"topping set",with_field(u.draft_config,"toppings",["topping_egg","topping_egg"]),func(): return u.set_draft_toppings(["topping_egg","topping_egg"]))
	u.set_draft_toppings(["topping_egg"])
	expect_reveal(u,"topping toggle",with_field(u.draft_config,"toppings",["topping_egg","topping_nori"]),func(): return u.toggle_draft_topping("topping_nori"))
	expect_reveal(u,"finished noodle",Comparison.apply_recipe(u.draft_config,"noodle",u.noodle_review()["recipes"][0]["recipe"]),func(): return u.use_noodle(0))
	expect_reveal(u,"finished broth",Comparison.apply_recipe(u.draft_config,"broth",u.broth_review()["recipes"][1]["recipe"]),func(): return u.use_broth(1))
	# Selecting a retained tasting record confirms that record's recipe even if knowledge was lost.
	var record_cfg: Dictionary=u.get_record(1)["config"]
	verify(not u.recipe_known(record_cfg),"the retained record's recipe is unknown here")
	var picked: Dictionary=u.select_record(1)
	verify(picked["ok"] and picked.get("discovered",false)==true and u.recipe_known(record_cfg) and u.recipe_known(u.draft_config),"selecting a retained tasting record confirms it")
	# A paid tasting confirms; an invalid tasting does not.
	var t: State=forgotten(base)
	var d: Dictionary=t.to_dict()
	d["draft"]["config"]["oil"]="oil_scallion"
	d["draft"]["lineage_id"]=0
	d["draft"]["name"]=""
	verify(t.load_from_dict(d)=="" and not t.recipe_known(t.draft_config),"unknown tamper-free draft with a new oil")
	var pending: Dictionary=t.draft_config.duplicate(true)
	reject(t,"tasting without a name",func(): return t.taste())
	verify(t.set_draft_name("확인용 국수")["ok"] and not t.recipe_known(pending),"naming does not reveal")
	var money: int=t.wallet
	var tasted: Dictionary=t.taste()
	verify(tasted["ok"] and tasted.get("discovered",false)==true and t.recipe_known(pending) and t.wallet<money and count(t)==1,"paid tasting confirms its recipe")

func invalid_paths(base: State) -> void:
	var u: State=forgotten(base)
	reject(u,"locked discovery tare",func(): return u.set_draft_choice("tare","tare_plum"))
	reject(u,"unknown slot",func(): return u.set_draft_choice("nope","tare_shio"))
	reject(u,"unknown id",func(): return u.set_draft_choice("tare","tare_nope"))
	reject(u,"catalog noodle after the workshop",func(): return u.set_draft_choice("noodle","noodle_thick"))
	reject(u,"catalog broth after the workshop",func(): return u.set_draft_choice("broth","broth_dashi"))
	reject(u,"empty toppings",func(): return u.set_draft_toppings([]))
	reject(u,"unknown topping",func(): return u.set_draft_toppings(["topping_nope"]))
	reject(u,"too many toppings",func(): return u.set_draft_toppings(["topping_egg","topping_egg","topping_egg"]))
	reject(u,"remove the last topping",func(): return u.toggle_draft_topping(u.draft_config["toppings"][0]))
	reject(u,"process on a finished noodle",func(): return u.set_draft_process("noodle","moist"))
	reject(u,"process on a finished broth",func(): return u.set_draft_process("broth","gentle"))
	reject(u,"unknown process",func(): return u.set_draft_process("broth","bogus"))
	reject(u,"rank-gated process",func(): return u.set_draft_process("broth","rolling"))
	reject(u,"missing finished broth",func(): return u.use_broth(99))
	reject(u,"negative noodle",func(): return u.use_noodle(-1))
	reject(u,"missing record",func(): return u.select_record(999))
	verify(count(u)==0 and not u.recipe_known(u.draft_config),"nothing was revealed by any invalid action")
	# Busy: work in progress locks the bowl, so nothing may be revealed either.
	verify(u.set_broth_blend(["kelp"],"standard")["ok"] and u.begin_broth()["ok"],"begin a cancellable brew")
	reject(u,"choice while brewing",func(): return u.set_draft_choice("cook","cook_soft"))
	reject(u,"toppings while brewing",func(): return u.set_draft_toppings(["topping_egg"]))
	reject(u,"toggle while brewing",func(): return u.toggle_draft_topping("topping_egg"))
	reject(u,"noodle while brewing",func(): return u.use_noodle(0))
	reject(u,"broth while brewing",func(): return u.use_broth(0))
	reject(u,"record while brewing",func(): return u.select_record(1))
	reject(u,"tasting while brewing",func(): return u.taste())
	verify(u.cancel_broth()["ok"] and count(u)==0,"cancelled work revealed nothing")
	var second: State=forgotten(base)
	verify(second.set_noodle_formula("cut","medium")["ok"] and second.begin_noodle()["ok"],"begin a cancellable noodle")
	reject(second,"choice while kneading",func(): return second.set_draft_choice("oil","oil_chili"))
	reject(second,"process while kneading",func(): return second.set_draft_process("noodle","moist"))
	verify(second.cancel_noodle()["ok"] and count(second)==0,"cancelled kneading revealed nothing")
	# An unfinished (partial) bowl whose second component was never produced by this player.
	var partial:=State.new()
	verify(partial.use_broth(0)["ok"]==false,"nothing to use yet")
	brew(partial,{"ingredients":["kelp"],"method":"standard"})
	verify(partial.use_broth(0)["ok"] and not partial.noodle_ready() and count(partial)==0,"broth only is partial")
	reject(partial,"tasting a partial bowl",func(): return partial.taste())

func legacy_paths(store_root: String) -> void:
	var fixture: Dictionary=load_fixture("broth-v15-save.json",store_root.path_join("legacy-paths"))
	var st: State=fixture["state"]
	verify(st.broth_ready() and st.noodle_ready() and count(st)==3,"old save is ready with exactly its three tasted recipes known")
	expect_reveal(st,"legacy tare",with_field(st.draft_config,"tare","tare_shio"),func(): return st.set_draft_choice("tare","tare_shio"))
	expect_reveal(st,"legacy catalog noodle",with_field(st.draft_config,"noodle","noodle_medium"),func(): return st.set_draft_choice("noodle","noodle_medium"))
	expect_reveal(st,"legacy catalog broth",with_field(st.draft_config,"broth","broth_tonkotsu"),func(): return st.set_draft_choice("broth","broth_tonkotsu"))
	expect_reveal(st,"legacy toppings",with_field(st.draft_config,"toppings",["topping_egg","topping_nori"]),func(): return st.set_draft_toppings(["topping_egg","topping_nori"]))
	var process: Dictionary=st.draft_config.get("process",{"broth":"standard","noodle":"standard"}).duplicate(true)
	process["broth"]="gentle"
	expect_reveal(st,"legacy process",with_field(st.draft_config,"process",process),func(): return st.set_draft_process("broth","gentle"))
	# Price/name stay irrelevant.
	var known_cfg: Dictionary=st.draft_config.duplicate(true)
	known_cfg["price"]=Catalog.PRICE_MAX
	verify(st.recipe_known(known_cfg),"price does not change knowledge")

func persistence(st: State) -> void:
	var keys: Array=st.to_dict().keys()
	keys.sort()
	var expected: Array=State.TOP_KEYS.duplicate()
	expected.sort()
	verify(State.SCHEMA_VERSION==18 and keys==expected and st.to_dict()["schema_version"]==18,"schema18 persisted keys")
	var cfgs: Array=tried.duplicate(true)
	verify(cfgs.size()==3 and count(st)>=cfgs.size(),"good, neutral and bad experiments are stored")
	for digest in st.to_dict()["recipe_knowledge"]["keys"]: verify(digest.length()==64,"only compact hashes are persisted")
	var store:=Save.new(data_dir.path_join("persist"))
	verify(DirAccess.make_dir_recursive_absolute(store.dir)==OK and store.save_state(st)["ok"],"save knowledge")
	var restart:=State.new()
	verify(store.load_into(restart)["status"]=="ok" and json(restart)==json(st),"exact disk round trip")
	for cfg in cfgs:
		verify(restart.recipe_known(cfg) and restart.recipe_knowledge(cfg)==st.recipe_knowledge(cfg),"known after restart with the same notes")
	unknown_view(restart,with_field(restart.draft_config,"oil","oil_chili"),"never selected after restart")
	# Deleting the notebook row never forgets the experiment.
	var record_cfg: Dictionary=restart.get_record(1)["config"]
	verify(restart.delete_record(1)["ok"] and restart.record_count()==0 and restart.recipe_known(record_cfg),"deleting the tasting row keeps the knowledge")
	verify(store.save_state(restart)["ok"],"save after delete")
	var again:=State.new()
	var total: int=count(st)
	verify(store.load_into(again)["status"]=="ok" and again.recipe_known(record_cfg) and count(again)==total and json(again)==json(restart),"deletion survives restart")
	# Exact isolation: nothing returned or loaded is a live reference.
	var dump: Dictionary=again.to_dict()
	dump["recipe_knowledge"]["keys"].clear()
	verify(count(again)==total and again.recipe_known(record_cfg),"to_dict is a deep copy")
	var source: Dictionary=again.to_dict()
	var loaded:=State.new()
	verify(loaded.load_from_dict(source)=="","load from dict")
	var expect: String=json(loaded)
	source["recipe_knowledge"]["keys"].clear()
	verify(json(loaded)==expect,"load does not keep the caller's dictionary")

func malformed(st: State) -> void:
	var good: Dictionary=st.to_dict()
	var other: State=ready_player()
	verify(other.load_from_dict(good)=="" and other.set_draft_choice("cook","cook_soft")["ok"],"target has its own state")
	var target_before: String=json(other)
	var first: String=good["recipe_knowledge"]["keys"][0]
	var cases: Dictionary={}
	var d: Dictionary
	d=good.duplicate(true); d.erase("recipe_knowledge"); cases["missing top key"]=d
	d=good.duplicate(true); d["recipe_knowledge"]["extra"]=1; cases["extra state key"]=d
	d=good.duplicate(true); d["recipe_knowledge"]=[]; cases["state not a dictionary"]=d
	d=good.duplicate(true); d["recipe_knowledge"]["keys"]={}; cases["keys not an array"]=d
	d=good.duplicate(true); d["recipe_knowledge"]["keys"].append(7); cases["key not a string"]=d
	d=good.duplicate(true); d["recipe_knowledge"]["keys"].append(first.substr(1)); cases["key too short"]=d
	d=good.duplicate(true); d["recipe_knowledge"]["keys"].append(first+"0"); cases["key too long"]=d
	d=good.duplicate(true); d["recipe_knowledge"]["keys"].append(first.substr(0,63)+"G"); cases["key not lowercase hex"]=d
	d=good.duplicate(true); d["recipe_knowledge"]["keys"].append("g".repeat(64)); cases["key with non-hex letters"]=d
	d=good.duplicate(true); d["recipe_knowledge"]["keys"].append(first); cases["duplicate key"]=d
	d=good.duplicate(true); d["recipe_knowledge"]["keys"][0]={"tare":"tare_shio"}; cases["config snapshot instead of a hash"]=d
	d=good.duplicate(true); d["schema_version"]=17; cases["v17 may not carry knowledge"]=d
	d=good.duplicate(true); d["schema_version"]=16; cases["v16 may not carry knowledge"]=d
	for label in cases:
		var message: String=other.load_from_dict(cases[label])
		verify(message!="","malformed save is refused: "+label)
		verify(json(other)==target_before,"refusal leaves the live state untouched: "+label)
	# A valid load still works after all the refusals.
	verify(other.load_from_dict(good)=="" and json(other)==json(st),"valid save loads after refusals")

func bytes_of(path: String) -> String:
	return FileAccess.get_file_as_string(path) if FileAccess.file_exists(path) else "<missing>"

## SaveService must never replace the last loadable save with one it would refuse to load.
## The oversized state uses synthetic, format-valid hashes: this checks the byte boundary only
## and makes no claim about real experiments (those are covered by explore_many).
func save_limit() -> void:
	var big_keys: Array=[]
	for i in 32000: big_keys.append("%064x" % i)
	var big:=State.new()
	var d: Dictionary=big.to_dict()
	d["recipe_knowledge"]={"keys":big_keys}
	verify(big.load_from_dict(d)=="","an oversized but well-formed state exists in memory")
	verify(JSON.stringify(big.to_dict(),"\t",true).to_utf8_buffer().size()>Save.MAX_BYTES,"the state really serialises past MAX_BYTES")
	# 1) A current-version main with its backup and a stale tmp: all bytes survive a refused save.
	var store:=Save.new(data_dir.path_join("limit"))
	var small:=State.new()
	verify(DirAccess.make_dir_recursive_absolute(store.dir)==OK and store.save_state(small)["ok"] and store.save_state(small)["ok"],"small saves, main and backup exist")
	var tmp:=FileAccess.open(store.tmp_path(),FileAccess.WRITE)
	tmp.store_string("stale tmp"); tmp.close()
	var before: Array=[bytes_of(store.main_path()),bytes_of(store.tmp_path()),bytes_of(store.bak_path())]
	verify(before[0]!="<missing>" and before[2]!="<missing>","precondition: main and backup present")
	var result: Dictionary=store.save_state(big)
	verify(not result["ok"] and str(result["message"]).contains(str(Save.MAX_BYTES)),"explicit actionable size failure")
	verify([bytes_of(store.main_path()),bytes_of(store.tmp_path()),bytes_of(store.bak_path())]==before,"main, tmp and backup bytes are unchanged")
	var restart:=State.new()
	verify(store.load_into(restart)["status"]=="ok" and json(restart)==json(small),"the last valid save still loads")
	# 2) An old-version main: no versioned backup is created and the original is untouched.
	var old_store:=Save.new(data_dir.path_join("limit-old"))
	var original: String=FileAccess.get_file_as_string("res://tests/fixtures/component-v17-save.json")
	verify(DirAccess.make_dir_recursive_absolute(old_store.dir)==OK,"old directory")
	var file:=FileAccess.open(old_store.main_path(),FileAccess.WRITE)
	file.store_string(original); file.close()
	verify(not old_store.save_state(big)["ok"],"oversized save over a v17 main is refused")
	verify(bytes_of(old_store.main_path())==original and bytes_of(old_store.legacy_bak_path(17))=="<missing>" and bytes_of(old_store.tmp_path())=="<missing>" and bytes_of(old_store.bak_path())=="<missing>","nothing was created or modified")
	# 3) Just under the limit still saves and loads.
	var fits: Array=[]
	for i in 20000: fits.append("%064x" % i)
	var near:=State.new()
	var nd: Dictionary=near.to_dict()
	nd["recipe_knowledge"]={"keys":fits}
	verify(near.load_from_dict(nd)=="" and JSON.stringify(near.to_dict(),"\t",true).to_utf8_buffer().size()<=Save.MAX_BYTES,"a large state under the limit")
	var reload:=State.new()
	verify(store.save_state(near)["ok"] and store.load_into(reload)["status"]=="ok" and count(reload)==20000,"under-limit knowledge saves and loads")

func load_fixture(name: String, dir: String) -> Dictionary:
	var original: String=FileAccess.get_file_as_string("res://tests/fixtures/"+name)
	var store:=Save.new(dir)
	verify(original!="" and DirAccess.make_dir_recursive_absolute(store.dir)==OK,"directory for "+name)
	var file:=FileAccess.open(store.main_path(),FileAccess.WRITE)
	file.store_string(original); file.close()
	var st:=State.new()
	verify(store.load_into(st)["status"]=="ok","frozen fixture loads: "+name)
	return {"state":st,"store":store,"text":original}

func migration(name: String, version: int) -> void:
	var fixture: Dictionary=load_fixture(name,data_dir.path_join("mig%d" % version))
	var st: State=fixture["state"]
	var store: Save=fixture["store"]
	var original: String=fixture["text"]
	var parsed: Dictionary=JSON.parse_string(original)
	verify(int(parsed["schema_version"])==version,"fixture is genuinely v%d" % version)
	verify(st.wallet==int(parsed["wallet"]) and st.day==int(parsed["day"]) and st.record_count()==parsed["records"].size(),"v%d: money, day and records preserved" % version)
	# Expected seeds: retained rows, their predecessor configs and best-taste witnesses; nothing else.
	var unique: Dictionary={}
	var witnesses: Array=[]
	for row in parsed["records"]:
		witnesses.append(row["config"])
		if not row["comparison"].is_empty(): witnesses.append(row["comparison"]["prev_config"])
	for who in parsed["taste_achievements"]:
		if not parsed["taste_achievements"][who].is_empty(): witnesses.append(parsed["taste_achievements"][who]["config"])
	for raw in witnesses: unique[Knowledge.config_key(Check.parse_config(raw,"witness")["config"])]=true
	for row in parsed["records"]:
		var rec: Dictionary=st.get_record(int(row["record_id"]))
		verify(not rec.is_empty() and rec["name"]==row["name"] and rec["version"]==int(row["version"]),"v%d: record preserved" % version)
		for who in row["scores"]: verify(rec["scores"][who]==int(row["scores"][who]),"v%d: score preserved" % version)
		verify(st.recipe_known(rec["config"]),"v%d: tasted record is seeded as known" % version)
		var repriced: Dictionary=rec["config"].duplicate(true)
		repriced["price"]=Catalog.PRICE_MAX
		verify(st.recipe_known(repriced),"v%d: seeded identity ignores price" % version)
	verify(count(st)==unique.size(),"v%d: only tasted recipes are seeded" % version)
	var fresh:=State.new()
	unknown_view(fresh,fresh.draft_config,"v%d: a new player's defaults" % version)
	# An untested draft is never evidence.
	var d: Dictionary=parsed.duplicate(true)
	d["draft"]["config"]["tare"]="tare_miso"
	d["draft"]["config"]["oil"]="oil_chili"
	var probe:=State.new()
	verify(probe.load_from_dict(d)=="" and not probe.recipe_known(probe.draft_config) and count(probe)==unique.size(),"v%d: untested draft stays unknown" % version)
	# Saving: v18 main file, the original bytes kept under the generic versioned backup.
	var before: String=core(st)
	verify(store.save_state(st)["ok"],"v%d: first save" % version)
	verify(FileAccess.get_file_as_string(store.legacy_bak_path(version))==original,"v%d: original bytes preserved in the versioned backup" % version)
	var written: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(store.main_path()))
	verify(int(written["schema_version"])==18 and written.has("recipe_knowledge") and int(written["wallet"])==int(parsed["wallet"]),"v%d: main file is now schema 18" % version)
	var reread:=State.new()
	verify(store.load_into(reread)["status"]=="ok" and json(reread)==json(st) and core(reread)==before,"v%d: migrated save round-trips" % version)
	verify(store.save_state(reread)["ok"] and FileAccess.get_file_as_string(store.legacy_bak_path(version))==original,"v%d: later saves keep the original bytes" % version)

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--test-data-dir="): data_dir=arg.substr(16)
	if not data_dir.begins_with("/private/tmp/"): printerr("Explicit isolated --test-data-dir required"); quit(2); return
	verify(DirAccess.make_dir_recursive_absolute(data_dir)==OK,"isolated directory")
	identity()
	var st: State=fresh_flow()
	choice_paths(st)
	invalid_paths(st)
	legacy_paths(data_dir)
	persistence(st)
	malformed(st)
	save_limit()
	migration("broth-v15-save.json",15)
	migration("noodle-v16-save.json",16)
	migration("component-v17-save.json",17)
	print("RECIPE KNOWLEDGE checks=%d failures=%d" % [checks,failures.size()])
	quit(0 if failures.is_empty() else 1)
