extends RefCounted
## Read-only next step for an ingredient-led experiment. Only retained paid
## records or an immutable settled receipt can witness a bowl; never the draft,
## forecast or active session. No progress/reward ledger is created here.
const Directions=preload("res://scripts/domain/recipe_directions.gd")
const Check=preload("res://scripts/domain/data_check.gd")
const Evaluator=preload("res://scripts/domain/recipe_evaluator.gd")

static func describe(state: Object,direction_id: String) -> Dictionary:
	var out: Dictionary={"error":"","stage":"untasted","title":"","hint":"","record_id":0,"name":"","version":0,"units":0,"day":0}
	if Directions.find(direction_id).is_empty():return _error(out,"연구 방향을 확인해 주세요.")
	if state==null or not is_instance_valid(state) or not state.has_method("records") or not state.has_method("selling_records") or not "last_report" in state or not "day" in state:
		return _error(out,"판매 정보를 확인할 수 없어요.")
	var records: Variant=state.records()
	var selling: Variant=state.selling_records()
	var report: Variant=state.get("last_report")
	if typeof(records)!=TYPE_ARRAY or typeof(selling)!=TYPE_ARRAY or typeof(report)!=TYPE_DICTIONARY or not Check.in_range(state.get("day"),1,1000000):
		return _error(out,"판매 기록의 형식을 확인해 주세요.")
	var latest: Dictionary={}
	var selected: Dictionary={}
	var retained: Dictionary={}
	for record in records:
		if not _valid_record(record) or retained.has(record["record_id"]):return _error(out,"시식 기록을 확인해 주세요.")
		retained[record["record_id"]]=record
		if bool(Directions.assess(direction_id,record["config"])["matched"]) and (latest.is_empty() or int(record["record_id"])>int(latest["record_id"])):latest=record
	for record in selling:
		# Selling records are existing paid witnesses, not separately supplied
		# recipes with a reused id. Never claim a modified/impostor menu is ready.
		if not _valid_record(record) or not retained.has(record["record_id"]) or record!=retained[record["record_id"]]:return _error(out,"판매 메뉴와 시식 기록이 달라요.")
		if bool(Directions.assess(direction_id,record["config"])["matched"]) and (selected.is_empty() or int(record["record_id"])>int(selected["record_id"])):selected=record
	var sold: Dictionary=_receipt(report,int(state.get("day")),direction_id,retained)
	if str(sold["error"])!="":return _error(out,str(sold["error"]))
	if int(sold["units"])>0:
		out["stage"]="sold";out["title"]="최근 영업 · %d그릇" % int(sold["units"])
		out["units"]=int(sold["units"]);out["day"]=int(report["day"])
		_set_menu(out,sold["record"])
	elif not selected.is_empty():
		out["stage"]="ready";out["title"]="영업으로 확인하기";_set_menu(out,selected)
	elif not latest.is_empty():
		out["stage"]="choose";out["title"]="판매 메뉴 고르기";_set_menu(out,latest)
	return out

static func _valid_record(value: Variant) -> bool:
	return typeof(value)==TYPE_DICTIONARY and Check.in_range(value.get("record_id"),1,1000000000) and typeof(value.get("name"))==TYPE_STRING and Check.name_error(value["name"],false)=="" and Check.in_range(value.get("version"),1,9999) and typeof(value.get("config"))==TYPE_DICTIONARY and Check.config_error(value["config"])==""

static func _set_menu(out: Dictionary,record: Dictionary) -> void:
	out["record_id"]=int(record["record_id"]);out["name"]=str(record["name"]);out["version"]=int(record["version"])
	var short_name: String=out["name"]
	if short_name.length()>14:short_name=short_name.substr(0,13)+"…"
	out["hint"]="%s v%d · 영업 준비" % [short_name,out["version"]]

## Count exact completed menu rows, not total customers or a forecast. A single
## expanded-shop receipt carries its own config. Original single-menu receipts
## need one retained immutable paid witness matching date/name/version/price/cost.
## Missing/deleted/ambiguous witnesses remain unavailable, never filled by a draft.
static func _receipt(report: Dictionary,day: int,id: String,retained: Dictionary) -> Dictionary:
	var result: Dictionary={"error":"","units":0,"record":{}}
	if report.is_empty():return result
	if not Check.in_range(report.get("day"),1,day-1) or not Check.in_range(report.get("units"),0,200):
		result["error"]="최근 완료 영업을 확인해 주세요.";return result
	var rows: Array=[]
	if report.has("menus"):
		if typeof(report["menus"])!=TYPE_ARRAY or report["menus"].is_empty() or report["menus"].size()>2:
			result["error"]="메뉴별 영업 기록을 확인해 주세요.";return result
		rows=report["menus"]
	elif report.has("config"):
		if typeof(report["config"])!=TYPE_DICTIONARY or report["config"].is_empty():
			result["error"]="판매한 그릇 구성을 확인해 주세요.";return result
		rows=[report]
	else:
		var bound: Dictionary=_single_witness(report,retained)
		if str(bound["error"])!="":result["error"]=bound["error"];return result
		if bound["row"].is_empty():return result
		rows=[bound["row"]]
	var seen: Dictionary={}
	var total: int=0
	for row in rows:
		if typeof(row)!=TYPE_DICTIONARY or not Check.in_range(row.get("record_id"),1,1000000000) or not Check.in_range(row.get("version"),1,9999) or typeof(row.get("recipe_name"))!=TYPE_STRING or Check.name_error(row["recipe_name"],false)!="" or typeof(row.get("config"))!=TYPE_DICTIONARY or Check.config_error(row["config"])!="" or not Check.in_range(row.get("units"),0,200) or seen.has(row["record_id"]):
			result["error"]="판매한 그릇의 기록을 확인해 주세요.";return result
		seen[row["record_id"]]=true;total+=int(row["units"])
		var record: Dictionary={"record_id":int(row["record_id"]),"name":str(row["recipe_name"]),"version":int(row["version"]),"config":row["config"]}
		if retained.has(record["record_id"]):
			var actual: Dictionary=retained[record["record_id"]]
			if record["name"]!=actual["name"] or record["version"]!=actual["version"] or not Check.same_config(record["config"],actual["config"]):
				result["error"]="판매 기록과 남은 시식 기록이 달라요.";return result
		if int(row["units"])>0 and bool(Directions.assess(id,record["config"])["matched"]):
			# Several sold recipes can fit the same direction. Show one concrete
			# menu/count instead of merging two identities into a fabricated bowl.
			if result["record"].is_empty() or int(row["units"])>int(result["units"]) or (int(row["units"])==int(result["units"]) and int(record["record_id"])>int(result["record"]["record_id"])):
				result["record"]=record;result["units"]=int(row["units"])
	if total!=int(report["units"]):result["error"]="메뉴별 완료 수량과 영업 합계가 달라요."
	return result

## A bounded bridge to the existing pre-expansion receipt format. This neither
## changes that receipt nor manufactures a snapshot. Name/version alone is not
## sufficient: a newly recreated name, repriced draft or ambiguous record fails.
static func _single_witness(report: Dictionary,retained: Dictionary) -> Dictionary:
	var result: Dictionary={"error":"","row":{}}
	for field in ["recipe_name","version","price","revenue","ingredient_cost"]:
		if not report.has(field):return result
	if typeof(report["recipe_name"])!=TYPE_STRING or not Check.in_range(report["version"],1,9999) or not Check.in_range(report["price"],0,1000000000) or not Check.in_range(report["revenue"],0,1000000000) or not Check.in_range(report["ingredient_cost"],0,1000000000):
		result["error"]="단일 메뉴 영업의 금액과 버전을 확인해 주세요.";return result
	if int(report["units"])==0:return result
	if int(report["price"])*int(report["units"])!=int(report["revenue"]):
		result["error"]="완료 수량과 판매 금액이 달라요.";return result
	for record in retained.values():
		if record["name"]!=report["recipe_name"] or int(record["version"])!=int(report["version"]) or not Check.in_range(record.get("tasted_day"),1,int(report["day"])) or int(record["config"]["price"])!=int(report["price"]):continue
		if Evaluator.unit_cost(record["config"])*int(report["units"])!=int(report["ingredient_cost"]):continue
		if not result["row"].is_empty():result["error"]="단일 메뉴 시식 원본을 하나로 확인할 수 없어요.";return result
		result["row"]={"record_id":int(record["record_id"]),"recipe_name":str(record["name"]),"version":int(record["version"]),"config":record["config"].duplicate(true),"units":int(report["units"])}
	return result

static func _error(out: Dictionary,message: String) -> Dictionary:
	out["error"]=message;out["stage"]="error";return out
