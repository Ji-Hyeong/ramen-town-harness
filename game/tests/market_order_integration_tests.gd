extends RefCounted
## Historical schema projections also omit the v21 reversible broth shelf.
## Separate actual paid continuations for both routes. Rank, stock and cash
## come from the earned raw/farming fixture, never synthetic grants.
const State=preload("res://scripts/domain/game_state.gd")
const Save=preload("res://scripts/services/save_service.gd")
const Fixture=preload("res://tests/known_change_fixtures.gd")
const Directions=preload("res://scripts/domain/recipe_directions.gd")
var check: Callable
var finished: bool=false

func js(state: Object) -> String:
	return JSON.stringify(state.to_dict(),"",true)

func fresh() -> Object:
	var state:=State.new()
	check.call(state.load_from_dict(JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/foraging-earned-v18-save.json")))=="","earned raw/farming checkpoint loads with empty order progress")
	return state

func recipe(state: Object,direction: String) -> int:
	var citrus: bool=direction=="citrus_clear"
	check.call(state.select_record(1 if citrus else 2)["ok"],"select actual paid raw menu family")
	if not citrus:
		var maker:=Fixture.new();maker.check=check
		var index: int=maker.brew(state,["pork_bone","pork_bone","garlic"])
		check.call(state.use_broth(index)["ok"],"use actual newly developed rich raw broth")
	check.call(state.set_draft_choice("oil","oil_scallion" if citrus else "oil_roasted_sesame")["ok"],"explicit regional oil choice")
	check.call(state.set_draft_choice("tare","tare_shio" if citrus else "tare_miso")["ok"],"explicit target seasoning")
	check.call(state.set_draft_toppings(["topping_citrus_peel"] if citrus else ["topping_chashu"])["ok"],"explicit regional topping choice")
	check.call(state.set_draft_price(6500)["ok"],"explicit affordable serving price")
	var assessment: Dictionary=Directions.assess(direction,state.draft_config)
	check.call(assessment["matched"],"actual manufactured menu satisfies chosen open direction: "+direction+str(assessment))
	var sample: String="topping_citrus_peel" if citrus else "oil_roasted_sesame"
	var stock: int=state.sample_stock(sample)
	var result: Dictionary=state.taste()
	check.call(result["ok"] and state.sample_stock(sample)==stock-1,"real paid tasting consumes one actual regional sample")
	return int(result.get("record_id",0))

func operate(state: Object) -> void:
	check.call(state.begin_service()["ok"],"real runtime service starts")
	if not state.service_active():return
	check.call(state.active_session().run_to_end(),"real runtime service finishes")
	check.call(state.settle_service()["ok"],"actual finished orders settle")

func roundtrip(state: Object,path: String) -> void:
	check.call(DirAccess.make_dir_recursive_absolute(path)==OK,"isolated order disk directory")
	var service:=Save.new(path);check.call(service.save_state(state)["ok"],"order disk save succeeds")
	var restored:=State.new();var result: Dictionary=service.load_into(restored)
	check.call(result["status"]=="ok" and js(restored)==js(state),"whole actual order state survives disk restart")

func run(callback: Callable,folder: String) -> void:
	check=callback
	var first:=State.new();var before: String=js(first)
	check.call(not first.start_market_order("citrus_clear")["ok"] and js(first)==before,"fresh rank1 cannot accept, atomic")
	for direction in ["citrus_clear","sesame_depth"]:
		var state: Object=fresh()
		var wallet: int=state.wallet
		var original: Dictionary=state.to_dict();original.erase("market_tasting_order")
		check.call(state.start_market_order(direction)["ok"] and state.wallet==wallet,"explicit free actual route acceptance")
		var unchanged: Dictionary=state.to_dict();unchanged.erase("market_tasting_order")
		check.call(unchanged==original,"acceptance changes no currency/items/knowledge/rank/research or recipe fields")
		before=js(state)
		check.call(not state.start_market_order(direction)["ok"] and not state.claim_market_order()["ok"] and js(state)==before,"duplicate acceptance/premature claim are atomic")
		roundtrip(state,folder.path_join(direction+"_accepted"))
		var record_id: int=recipe(state,direction)
		check.call(state.set_selling_menus([record_id])["ok"],"explicitly choose actual regional sale menu")
		check.call(state.serve()["ok"] and state.market_order_review()["receipt"].is_empty(),"analytical service never grants market evidence")
		check.call(state.begin_service()["ok"],"begin partial service to check locks")
		before=js(state)
		check.call(not state.start_market_order(direction)["ok"] and not state.claim_market_order()["ok"] and not state.settle_service()["ok"] and js(state)==before,"busy/partial service refusal changes no persistent state")
		state.cancel_service()
		check.call(state.market_order_review()["receipt"].is_empty(),"canceled service grants nothing")
		# Each route is verified in both original and expanded serving modes.
		operate(state)
		var review: Dictionary=state.market_order_review()
		check.call(review["status"]=="ready","actual single-menu target service is attainable: "+direction+str(review))
		roundtrip(state,folder.path_join(direction+"_ready"))
		var proof: Dictionary=review["receipt"]
		# Full-host parsing, not just the pure helper, must reject malformed proof
		# before replacing any live fields (including cash and the chosen route).
		for key in ["service_day","record_id","units","star_sum"]:
			var forged: Dictionary=state.to_dict();forged["market_tasting_order"]["receipt"][key]=-1
			var target:=State.new();var untouched: String=js(target)
			check.call(target.load_from_dict(forged)!="" and js(target)==untouched,"malformed order proof cannot partially replace live host state: "+key)
		# Synthetic cap-only clone; never count its wallet as real progression.
		var cap_data: Dictionary=state.to_dict();cap_data["wallet"]=State.MAX_WALLET
		var capped:=State.new();check.call(capped.load_from_dict(cap_data)=="","synthetic defensive cap clone loads")
		before=js(capped);check.call(not capped.claim_market_order()["ok"] and js(capped)==before,"wallet overflow refuses the whole payout atomically")
		check.call(state.select_record(1)["ok"] and state.set_selling_menus([1])["ok"],"explicit different later menu")
		operate(state)
		check.call(state.market_order_review()["receipt"]==proof,"later unrelated actual service cannot erase first passing proof")
		check.call(state.delete_record(record_id)["ok"],"delete old paid notebook witness after changing sale selection")
		roundtrip(state,folder.path_join(direction+"_deleted"))
		wallet=state.wallet;var before_claim: Dictionary=state.to_dict()
		check.call(state.claim_market_order()["ok"] and state.wallet==wallet+5000,"explicit actual once-only5000cash payout")
		var only_payout: Dictionary=state.to_dict();only_payout["wallet"]-=5000;only_payout["market_tasting_order"]["claimed_day"]=0
		check.call(only_payout==before_claim,"claim changes exactly cash and once-only receipt acknowledgement")
		before=js(state);check.call(not state.claim_market_order()["ok"] and js(state)==before,"repeat actual payout rejects atomically")
		roundtrip(state,folder.path_join(direction+"_claimed"))
		# Independent earned player: expanded-mode analytical service is also
		# excluded; one real menu row must meet the request, never total diners.
		state=fresh();record_id=recipe(state,direction)
		check.call(state.expand_shop()["ok"] and state.set_selling_menus([record_id,4])["ok"] and state.start_market_order(direction)["ok"],"actual paid expanded branch chooses two menus and accepts")
		check.call(state.serve()["ok"] and state.market_order_review()["receipt"].is_empty(),"expanded analytical service grants no proof")
		operate(state);review=state.market_order_review()
		check.call(review["status"]=="ready" and int(review["receipt"].get("record_id",0))==record_id,"actual expanded per-menu completion is attainable: "+direction+str(review))
		roundtrip(state,folder.path_join(direction+"_expanded"))
	_migration(folder.path_join("migration"))
	finished=true

func _migration(folder: String) -> void:
	var source: String=FileAccess.get_file_as_string("res://tests/fixtures/market-order-v19-save.json")
	var raw: Dictionary=JSON.parse_string(source);var state:=State.new()
	check.call(int(raw["schema_version"])==19 and state.load_from_dict(raw)=="","exact accepted previous19save loads")
	var converted: Dictionary=state.to_dict();converted.erase("market_tasting_order");converted.erase("broth_shelf");converted["schema_version"]=19
	# JSON numbers enter as floats; compare both sides at the serialized boundary
	# rather than confusing integer normalization with a changed game value.
	check.call(JSON.parse_string(JSON.stringify(converted))==raw and state.market_order_review()["status"] in ["locked","open"],"migration changes only schema and adds empty optional progress")
	check.call(DirAccess.make_dir_recursive_absolute(folder)==OK,"isolated old19disk directory")
	var save:=Save.new(folder);var file:=FileAccess.open(save.main_path(),FileAccess.WRITE);check.call(file!=null,"old19original writable")
	if file!=null:file.store_string(source);file.close()
	check.call(save.load_into(state)["status"]=="ok" and FileAccess.get_file_as_string(save.main_path())==source,"reading old19does not rewrite original bytes")
	check.call(save.save_state(state)["ok"] and FileAccess.get_file_as_string(save.legacy_bak_path(19))==source,"first20save preserves byte-exact19backup")
	var bad: Dictionary=raw.duplicate(true);bad["market_tasting_order"]={}
	var before: String=js(state);check.call(state.load_from_dict(bad)!="" and js(state)==before,"downgraded extra20field rejects without replacing live state")
	bad=state.to_dict();bad.erase("market_tasting_order")
	check.call(state.load_from_dict(bad)!="" and js(state)==before,"current20save requires its complete order field")
