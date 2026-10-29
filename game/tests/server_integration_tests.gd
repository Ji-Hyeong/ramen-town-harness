extends RefCounted
## Continue a genuinely earned raw-production v18 checkpoint. Every expansion,
## tasting, service and claim is public; no wallet/rank/XP/stock is manufactured.
const State=preload("res://scripts/domain/game_state.gd")
const Staff=preload("res://scripts/domain/shop_staffing.gd")
const Save=preload("res://scripts/services/save_service.gd")
var check: Callable
var finished: bool=false

func js(st: Object) -> String:
	return JSON.stringify(st.to_dict(),"",true)

func fresh() -> Object:
	var st:=State.new()
	var raw: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/server-earned-v18-save.json"))
	check.call(st.load_from_dict(raw)=="","actual raw earned checkpoint loads")
	check.call(st.rank()==2 and not raw["broth_workshop"]["legacy"] and not raw["noodle_workshop"]["legacy"],"no historical supply or progression injection")
	return st

func setup(st: Object) -> void:
	check.call(st.expand_shop()["ok"] and st.set_selling_menus([1,2])["ok"],"paid expansion and actual two selling menus")

func revise(st: Object) -> Array:
	var ids: Array=[]
	for i in 2:
		check.call(st.select_record(i+1)["ok"],"select actual existing raw family")
		check.call(st.set_draft_toppings(["topping_nori","topping_egg"] if i==0 else ["topping_nori","topping_sprouts"])["ok"],"actual structural revision")
		var result: Dictionary=st.taste()
		check.call(result["ok"],"actual paid new revision")
		if result["ok"]: ids.append(result["record_id"])
	return ids

func operate(st: Object) -> Array:
	check.call(st.begin_service()["ok"],"actual service begins")
	if not st.service_active(): return []
	var session=st.active_session()
	check.call(session.run_to_end(),"actual runtime finishes")
	var completed: Array=session.completed.duplicate(true)
	check.call(st.settle_service()["ok"],"actual settlement")
	return completed

func roundtrip(st: Object,folder: String) -> void:
	check.call(DirAccess.make_dir_recursive_absolute(folder)==OK,"isolated server save directory")
	var saver:=Save.new(folder)
	check.call(saver.save_state(st)["ok"],"actual server disk save")
	var restored:=State.new()
	var result: Dictionary=saver.load_into(restored)
	check.call(result["status"]=="ok" and js(restored)==js(st),"whole state disk reload is exact")

func run(callback: Callable,folder: String) -> void:
	check=callback
	var st:=fresh()
	var before: String=js(st)
	check.call(not st.start_server_challenge()["ok"] and js(st)==before,"no expansion cannot accept, atomic")
	setup(st)
	var money: int=st.wallet
	check.call(st.start_server_challenge()["ok"] and st.wallet==money,"explicit acceptance is free")
	before=js(st)
	check.call(not st.start_server_challenge()["ok"] and js(st)==before,"no reset/reaccept")
	roundtrip(st,folder.path_join("accepted"))
	check.call(st.serve()["ok"] and st.server_challenge_review()["attempt"].is_empty(),"analytical shortcut never grants server proof")
	operate(st)
	check.call(st.server_challenge_review()["status"]=="active" and not st.server_challenge_review()["rows"][0]["met"],"old two-menu service cannot count as new development")
	roundtrip(st,folder.path_join("failed"))
	# Use the attainable day-15 witness independently of the preceding failed day.
	st=fresh();setup(st);check.call(st.start_server_challenge()["ok"],"new isolated actual challenge")
	var ids: Array=revise(st)
	check.call(st.set_selling_menus(ids)["ok"],"explicitly pin both new menus")
	before=js(st)
	check.call(st.begin_service()["ok"],"cancel test starts real service")
	check.call(not st.claim_server_challenge()["ok"],"busy claim is rejected")
	st.cancel_service()
	check.call(js(st)==before,"partial/cancel awards no proof or money")
	var completed: Array=operate(st)
	var review: Dictionary=st.server_challenge_review()
	check.call(review["status"]=="ready" and review["met"]==6,"actual raw revised two-menu witness passes")
	var units: Dictionary={};var waits: int=0;var stars: int=0
	for order in completed:
		units[order["record_id"]]=int(units.get(order["record_id"],0))+1
		waits+=order["wait"];stars+=order["stars"]
	check.call(review["attempt"]["units"]==completed.size() and review["attempt"]["wait_total"]==waits and review["attempt"]["star_sum"]==stars,"proof equals actual completed orders")
	for menu in review["attempt"]["menus"]: check.call(menu["units"]==units[menu["record_id"]],"each actual record count")
	roundtrip(st,folder.path_join("ready"))
	money=st.wallet;var report: Dictionary=st.last_report.duplicate(true)
	check.call(st.claim_server_challenge()["ok"] and st.wallet==money and st.last_report==report,"explicit one-time claim has no money or retroactive report effect")
	check.call(st.current_staffing().get("server",0)==1 and not report["staffing"].has("server"),"next snapshot mastered; old receipt unmodified")
	before=js(st)
	check.call(not st.claim_server_challenge()["ok"] and js(st)==before,"duplicate claim no transaction")
	roundtrip(st,folder.path_join("claimed_old_report"))
	var proof: Dictionary=st.server_challenge_review()["attempt"].duplicate(true)
	operate(st)
	check.call(st.last_report["staffing"].get("server",0)==1 and st.server_challenge_review()["attempt"]==proof,"next actual service uses mastery and preserves first proof")
	roundtrip(st,folder.path_join("mastered_report"))
	# All helper compositions and old shapes, with exact two-stage integer rounding.
	for hired in [[],["floor_assistant"],["prep_assistant","floor_assistant"]]:
		for chef in 2:
			var plain: Dictionary=Staff.snapshot(hired,{},chef)
			var mastered: Dictionary=Staff.snapshot(hired,{},chef,1)
			check.call(not plain.has("server") and Staff.snapshot_error(mastered)=="","optional mastery preserves old snapshot shape")
			check.call(Staff.daily_wage(plain)==Staff.daily_wage(mastered),"no mastery wage increase")
			for base in range(1,61):
				var carry: int=Staff.effective_carry(base,plain)
				var back: int=Staff.effective_return(base,60,plain)
				check.call(Staff.effective_carry(base,mastered)==maxi(1,(carry*80+99)/100),"carry applies after helper rounding")
				check.call(Staff.effective_return(base,60,mastered)==maxi(1,(back*80+99)/100),"return applies after helper rounding")
				check.call(Staff.effective_prep(base,plain)==Staff.effective_prep(base,mastered),"server never improves cooking")
	var invalid: Dictionary=st.to_dict()
	for field in ["units","wait_total","star_sum","day"]:
		var forged: Dictionary=invalid.duplicate(true)
		forged["server_challenge"]["attempt"][field]=-1
		var target:=State.new();before=js(target)
		check.call(target.load_from_dict(forged)!="" and js(target)==before,"corrupt server counter rejects atomically "+field)
	var forged: Dictionary=invalid.duplicate(true)
	forged["server_challenge"]["completed_day"]=forged["server_challenge"]["attempt"]["day"]
	check.call(State.new().load_from_dict(forged)!="","same-day forged mastery rejected")
	forged=invalid.duplicate(true);forged.erase("server_challenge")
	check.call(State.new().load_from_dict(forged)!="","v19 missing required server field rejected")
	forged=invalid.duplicate(true);forged["server_challenge"]["completed_day"]=0
	check.call(State.new().load_from_dict(forged)!="","report cannot invent unclaimed server mastery")
	finished=true
