extends RefCounted
## Synthetic defensive evidence only. These orders do not demonstrate game
## progression; the separate integration fixture completes real paid services.
const Order=preload("res://scripts/domain/market_tasting_order.gd")
const Directions=preload("res://scripts/domain/recipe_directions.gd")
const State=preload("res://scripts/domain/game_state.gd")
const Eval=preload("res://scripts/domain/recipe_evaluator.gd")
const CONFIG: Dictionary={"broth":"broth_dashi","tare":"tare_shio","oil":"oil_scallion","noodle":"noodle_thin","toppings":["topping_citrus_peel"],"cook":"cook_firm","price":7500}
var check: Callable

func js(value: Variant) -> String:
	return JSON.stringify(value,"",true)

func rec(id: int=11) -> Dictionary:
	return {"record_id":id,"name":"합성 유자탕","version":1,"tasted_day":2,"config":CONFIG.duplicate(true)}

func orders(count: int,stars: int,id: int=11) -> Array:
	var out: Array=[]
	for i in count:out.append({"record_id":id,"stars":stars})
	return out

func report(proof: Dictionary) -> Dictionary:
	return {"day":proof["service_day"],"recipe_name":proof["name"],"version":proof["version"],"units":proof["units"],"price":CONFIG["price"],"ingredient_cost":Eval.unit_cost(CONFIG)*int(proof["units"])}

func run(callback: Callable) -> void:
	check=callback
	check.call(Directions.assess("citrus_clear",CONFIG)["matched"],"synthetic defensive recipe satisfies the existing direction")
	var blank: Dictionary=Order.empty_state()
	for args in [["citrus_clear",3,1],["unknown",3,3],["citrus_clear",0,3]]:
		var rejected: Dictionary=Order.begin(blank,args[0],args[1],args[2])
		check.call(not rejected["ok"] and rejected["state"]==blank,"invalid acceptance rejects atomically")
	var opened: Dictionary=Order.begin(blank,"citrus_clear",3,3)["state"]
	check.call(not Order.begin(opened,"sesame_depth",3,3)["ok"],"choice cannot be reset or changed")
	check.call(not Order.claim(opened,3)["ok"],"acceptance alone never earns cash")
	check.call(not Order.observe(opened,[rec()],2,orders(5,5))["ok"],"pre-acceptance service cannot count")
	var four: Dictionary=Order.observe(opened,[rec()],3,orders(4,5))["state"]
	check.call(not Order.passing(four["receipt"]),"four matching bowls are insufficient")
	var weak: Dictionary=Order.observe(opened,[rec()],3,orders(8,2))["state"]
	check.call(not Order.passing(weak["receipt"]),"many unhappy bowls are insufficient")
	var split: Dictionary=Order.observe(opened,[rec(11),rec(12)],3,orders(3,5,11)+orders(3,5,12))["state"]
	check.call(int(split["receipt"]["units"])==3 and not Order.passing(split["receipt"]),"two concrete menu counts are never added together")
	var ready: Dictionary=Order.observe(opened,[rec(11),rec(12)],3,orders(8,2,11)+orders(5,3,12))["state"]
	check.call(Order.passing(ready["receipt"]) and int(ready["receipt"]["record_id"])==12,"passing menu wins over a more numerous failing menu")
	var proof: Dictionary=Order.observe(opened,[rec()],3,orders(5,3))["state"]
	check.call(not Order.claim(proof,3)["ok"],"unfinished same-day claim is rejected")
	check.call(Order.observe(proof,[rec()],4,[])["state"]==proof,"first passing proof survives a later service")
	var claimed: Dictionary=Order.claim(proof,4)
	check.call(claimed["ok"] and int(claimed["reward"])==5000 and not Order.claim(claimed["state"],5)["ok"],"claim is explicit and exactly once")
	for bad_orders in [orders(201,5),[{"record_id":99,"stars":5}],[{"record_id":11,"stars":true}],[{"record_id":11,"stars":6}]]:
		var result: Dictionary=Order.observe(opened,[rec()],3,bad_orders)
		check.call(not result["ok"] and result["state"]==opened,"malformed runtime orders refuse before state mutation")
	var earned:=State.new()
	check.call(earned.load_from_dict(JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/foraging-earned-v18-save.json")))=="","actual supplier context for synthetic parser cases")
	var discovered: Array=earned.discovered_ingredients()
	var args: Array=[4,20,3,4,discovered,[rec()],report(proof["receipt"])]
	check.call(Order.parse(proof,args[0],args[1],args[2],args[3],args[4],args[5],args[6])["ok"],"valid local proof parses")
	check.call(Order.parse(proof,4,20,3,4,discovered,[],report(proof["receipt"]))["ok"],"self-contained deleted notebook proof parses")
	var variants: Array=[]
	for key in ["service_day","record_id","version","tasted_day","units","star_sum"]:
		for value in [-1,true,0.5,1000000001]:
			var bad: Dictionary=proof.duplicate(true);bad["receipt"][key]=value;variants.append(bad)
	var bad: Dictionary=proof.duplicate(true);bad["receipt"]["config"]["toppings"]=["topping_nori"];variants.append(bad)
	bad=proof.duplicate(true);bad["start"]["day"]=4;variants.append(bad)
	bad=proof.duplicate(true);bad["start"]["direction"]="unknown";variants.append(bad)
	bad=proof.duplicate(true);bad["claimed_day"]=3;variants.append(bad)
	bad=proof.duplicate(true);bad["unexpected"]=1;variants.append(bad)
	for value in variants:check.call(not Order.parse(value,4,20,3,4,discovered,[rec()],report(proof["receipt"]))["ok"],"impossible/contradictory saved proof rejects")
	var wrong: Dictionary=report(proof["receipt"]);wrong["units"]=6
	check.call(not Order.parse(proof,4,20,3,4,discovered,[rec()],wrong)["ok"],"same-day actual receipt count must agree")
	var other: Dictionary=rec();other["name"]="다른 이름"
	check.call(not Order.parse(proof,4,20,3,4,discovered,[other],report(proof["receipt"]))["ok"],"retained immutable witness must agree")
