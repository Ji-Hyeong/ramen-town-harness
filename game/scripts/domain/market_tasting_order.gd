extends RefCounted
## One optional market event. This pure module records actual completed bowls;
## the host owns acceptance locks, settlement atomicity, wallet and persistence.
## A service request may use an existing recipe: it never rewards a discovery.
const Check=preload("res://scripts/domain/data_check.gd")
const Directions=preload("res://scripts/domain/recipe_directions.gd")
const Catalog=preload("res://scripts/domain/ingredient_catalog.gd")
const Evaluator=preload("res://scripts/domain/recipe_evaluator.gd")
const Exploration=preload("res://scripts/domain/ingredient_exploration.gd")
const Process=preload("res://scripts/domain/recipe_process.gd")
const MIN_RANK: int=2
const MIN_UNITS: int=5
const MIN_STARS: int=3
const REWARD: int=5000
const ROUTES: Array[String]=["citrus_clear","sesame_depth"]
const RECEIPT_KEYS: Array=["service_day","record_id","name","version","tasted_day","config","units","star_sum"]


static func empty_state() -> Dictionary:
	return {"start":{},"receipt":{},"claimed_day":0}


static func routes() -> Array:
	var out: Array=[]
	for id in ROUTES:out.append(Directions.find(id))
	return out


static func passing(receipt: Dictionary) -> bool:
	return not receipt.is_empty() and int(receipt["units"])>=MIN_UNITS and int(receipt["star_sum"])>=MIN_STARS*int(receipt["units"])


static func review(state: Dictionary,rank: int) -> Dictionary:
	var started: bool=not state["start"].is_empty()
	var receipt: Dictionary=state["receipt"]
	var status: String="done" if int(state["claimed_day"])>0 else ("ready" if passing(receipt) else ("active" if started else ("open" if rank>=MIN_RANK else "locked")))
	return {"status":status,"direction":str(state["start"].get("direction","")),"opened_day":int(state["start"].get("day",0)),"receipt":receipt.duplicate(true),"claimed_day":int(state["claimed_day"]),"reward":REWARD,"min_units":MIN_UNITS,"min_stars":MIN_STARS}


static func begin(state: Dictionary,direction: String,day: int,rank: int) -> Dictionary:
	if not _shape(state):return _reject(state,"시식회 상태를 확인해 주세요.")
	if rank<MIN_RANK:return _reject(state,"장터 시식회는 가게 2랭크부터 열려요.")
	if not ROUTES.has(direction) or day<1:return _reject(state,"시식회의 요리 방향을 골라 주세요.")
	if not state["start"].is_empty() or not state["receipt"].is_empty() or int(state["claimed_day"])>0:return _reject(state,"이미 방향을 정한 시식회예요.")
	var next: Dictionary=state.duplicate(true)
	next["start"]={"direction":direction,"day":day}
	return {"ok":true,"error":"","state":next}


## Called only after GameState has validated a finished real runtime session.
## A one-menu session has no per-order record_id; expanded sessions always do.
## Keep identities separate, prefer a passing menu, then actual units/latest id.
## Preserve the first passing proof even when later services use another menu.
static func observe(state: Dictionary,records: Array,on_day: int,completed: Array) -> Dictionary:
	if not _shape(state):return _reject(state,"시식회 상태를 확인해 주세요.")
	var same: Dictionary={"ok":true,"error":"","state":state.duplicate(true)}
	if state["start"].is_empty() or passing(state["receipt"]) or int(state["claimed_day"])>0:return same
	if on_day<int(state["start"]["day"]):return _reject(state,"수락하기 전 영업은 시식회에 쓸 수 없어요.")
	if records.is_empty() or records.size()>2 or completed.size()>200:return _reject(state,"시식회 영업의 메뉴/완료 수량을 확인해 주세요.")
	var by_id: Dictionary={}
	for record in records:
		if typeof(record)!=TYPE_DICTIONARY or not Check.in_range(record.get("record_id"),1,1000000000) or by_id.has(record["record_id"]):return _reject(state,"시식회 판매 메뉴 번호를 확인해 주세요.")
		if typeof(record.get("config"))!=TYPE_DICTIONARY or Check.config_error(record["config"])!="" or typeof(record.get("name"))!=TYPE_STRING or Check.name_error(record["name"],false)!="" or not Check.in_range(record.get("version"),1,9999) or not Check.in_range(record.get("tasted_day"),1,on_day):return _reject(state,"시식회 판매 메뉴의 원본을 확인해 주세요.")
		by_id[record["record_id"]]={"record":record,"units":0,"star_sum":0}
	for order in completed:
		if typeof(order)!=TYPE_DICTIONARY or not Check.in_range(order.get("stars"),1,5):return _reject(state,"시식회 완료 주문의 만족도를 확인해 주세요.")
		var id: Variant=order.get("record_id",records[0]["record_id"] if records.size()==1 else null)
		if not Check.in_range(id,1,1000000000) or not by_id.has(id):return _reject(state,"판매하지 않은 메뉴의 시식회 주문이에요.")
		by_id[id]["units"]+=1
		by_id[id]["star_sum"]+=int(order["stars"])
	var candidate: Dictionary={}
	for row in by_id.values():
		var rec: Dictionary=row["record"]
		if int(row["units"])==0 or not bool(Directions.assess(str(state["start"]["direction"]),rec["config"])["matched"]):continue
		var proof: Dictionary={"service_day":on_day,"units":int(row["units"]),"star_sum":int(row["star_sum"])}
		for key in ["record_id","name","version","tasted_day","config"]:proof[key]=rec[key].duplicate(true) if key=="config" else rec[key]
		if candidate.is_empty() or (passing(proof) and not passing(candidate)) or (passing(proof)==passing(candidate) and (int(proof["units"])>int(candidate["units"]) or (int(proof["units"])==int(candidate["units"]) and int(proof["record_id"])>int(candidate["record_id"])))):candidate=proof
	if not candidate.is_empty():same["state"]["receipt"]=candidate
	return same


static func claim(state: Dictionary,day: int) -> Dictionary:
	if not _shape(state):return _reject(state,"시식회 상태를 확인해 주세요.")
	if int(state["claimed_day"])>0:return _reject(state,"시식회 답례는 이미 받았어요.")
	if state["start"].is_empty() or not passing(state["receipt"]):return _reject(state,"수락 후 한 영업에서 대상 메뉴 5그릇·평균 별3개를 채워 주세요.")
	if day<=int(state["receipt"]["service_day"]):return _reject(state,"영업 정산이 끝난 뒤 답례를 받을 수 있어요.")
	var next: Dictionary=state.duplicate(true)
	next["claimed_day"]=day
	return {"ok":true,"error":"","state":next,"reward":REWARD}


## Strict local consistency, not anti-cheat. Historical menus remain valid after
## notebook deletion, but cannot contradict a retained witness/current receipt.
static func parse(raw: Variant,day: int,next_id: int,rank: int,slots: int,discovered: Array,records: Array,report: Dictionary) -> Dictionary:
	var fail: Dictionary={"ok":false,"error":"장터 시식회 저장이 올바르지 않아요.","state":{}}
	if typeof(raw)!=TYPE_DICTIONARY or not _shape(raw) or not Check.in_range(raw["claimed_day"],0,day):return fail
	var out: Dictionary=raw.duplicate(true)
	out["claimed_day"]=int(out["claimed_day"])
	var start: Dictionary=out["start"]
	var receipt: Dictionary=out["receipt"]
	if start.is_empty():
		if not receipt.is_empty() or int(out["claimed_day"])!=0:return fail
		return {"ok":true,"error":"","state":out}
	if rank<MIN_RANK or Check.keys_error(start,["direction","day"],"시식회 수락")!="" or typeof(start["direction"])!=TYPE_STRING or not ROUTES.has(start["direction"]) or not Check.in_range(start["day"],1,day):return fail
	start["day"]=int(start["day"])
	if receipt.is_empty():
		if int(out["claimed_day"])!=0:return fail
		return {"ok":true,"error":"","state":out}
	if Check.keys_error(receipt,RECEIPT_KEYS,"시식회 영수증")!="":return fail
	if not Check.in_range(receipt["service_day"],int(start["day"]),day-1) or not Check.in_range(receipt["record_id"],1,next_id-1) or not Check.in_range(receipt["version"],1,9999) or not Check.in_range(receipt["tasted_day"],1,int(receipt["service_day"])):return fail
	if typeof(receipt["name"])!=TYPE_STRING or Check.name_error(receipt["name"],false)!="" or receipt["name"]!=receipt["name"].strip_edges():return fail
	if not Check.in_range(receipt["units"],1,200) or not Check.in_range(receipt["star_sum"],int(receipt["units"]),int(receipt["units"])*5):return fail
	var parsed: Dictionary=Check.parse_config(receipt["config"],"시식회 메뉴",false)
	if str(parsed["error"])!="":return fail
	receipt["config"]=parsed["config"]
	if Catalog.toppings_of(receipt["config"]).size()>slots or Exploration.locked_in(receipt["config"],discovered)!="" or int(Process.effects(receipt["config"].get("process",{}))["rank"])>rank:return fail
	if not bool(Directions.assess(str(start["direction"]),receipt["config"])["matched"]):return fail
	for key in ["service_day","record_id","version","tasted_day","units","star_sum"]:receipt[key]=int(receipt[key])
	for record in records:
		if int(record["record_id"])!=int(receipt["record_id"]):continue
		for key in ["name","version","tasted_day"]:
			if record[key]!=receipt[key]:return fail
		if not Check.same_config(record["config"],receipt["config"]):return fail
	if report.is_empty() or int(report["day"])<int(receipt["service_day"]):return fail
	if int(report["day"])==int(receipt["service_day"]) and not _same_report(receipt,report):return fail
	if int(out["claimed_day"])>0 and (not passing(receipt) or int(out["claimed_day"])<=int(receipt["service_day"])):return fail
	return {"ok":true,"error":"","state":out}


static func _same_report(receipt: Dictionary,report: Dictionary) -> bool:
	if report.has("menus"):
		for row in report["menus"]:
			if int(row["record_id"])==int(receipt["record_id"]):return row["recipe_name"]==receipt["name"] and int(row["version"])==int(receipt["version"]) and int(row["units"])==int(receipt["units"]) and Check.same_config(row["config"],receipt["config"])
		return false
	# Original one-menu receipts have no config/id. Match their full immutable
	# name/version/date witness and actual price/cost/count instead of a live draft.
	return report["recipe_name"]==receipt["name"] and int(report["version"])==int(receipt["version"]) and int(report["units"])==int(receipt["units"]) and int(report["price"])==int(receipt["config"]["price"]) and int(report["ingredient_cost"])==Evaluator.unit_cost(receipt["config"])*int(receipt["units"])


static func _shape(state: Dictionary) -> bool:
	return Check.keys_error(state,["start","receipt","claimed_day"],"시식회")=="" and typeof(state["start"])==TYPE_DICTIONARY and typeof(state["receipt"])==TYPE_DICTIONARY and Check.is_whole(state["claimed_day"])


static func _reject(state: Dictionary,message: String) -> Dictionary:
	return {"ok":false,"error":message,"state":state.duplicate(true)}
