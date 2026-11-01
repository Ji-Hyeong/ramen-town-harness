extends RefCounted
## Synthetic defensive view inputs, separate from the actual paid/native flow.
const Followup=preload("res://scripts/ui/foraging_sales_followup.gd")
const Broth=preload("res://scripts/domain/broth_workshop.gd")
const Ingredients=preload("res://scripts/domain/ingredient_catalog.gd")
const Direction=preload("res://scripts/domain/recipe_directions.gd")
const ConfigCheck=preload("res://scripts/domain/data_check.gd")
const Eval=preload("res://scripts/domain/recipe_evaluator.gd")
class ViewState:
	extends RefCounted
	var day: int=2
	var last_report: Dictionary={}
	var notebook: Array=[]
	var selling: Array=[]
	func records() -> Array:return notebook.duplicate(true)
	func selling_records() -> Array:return selling.duplicate(true)

func record(id: int=1) -> Dictionary:
	var checkpoint: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/foraging-earned-v18-save.json"))
	var item: Dictionary=checkpoint["records"][-1].duplicate(true)
	item["record_id"]=id;item["name"]="판매 실험 %d" % id;item["tasted_day"]=1
	# JSON numbers cross the same canonical configuration boundary as save
	# loading. The projection consumes typed memory state, not raw save JSON.
	item["config"]=ConfigCheck.parse_config(item["config"],"합성 판매 구성")["config"]
	var cfg: Dictionary=item["config"]
	cfg["broth_recipe"]=Broth.canonical({"ingredients":["kelp","ginger"],"method":"standard"})
	cfg["broth"]=Broth.base_id(cfg["broth_recipe"]);cfg["oil"]="oil_scallion";cfg["tare"]="tare_shio";cfg["toppings"]=["topping_citrus_peel","topping_scallop"]
	item["config"]=Ingredients.normalize_config(cfg)
	return item

func row(rec: Dictionary,units: int) -> Dictionary:
	return {"record_id":rec["record_id"],"recipe_name":rec["name"],"version":rec["version"],"config":rec["config"].duplicate(true),"units":units}

func run(check: Callable) -> void:
	var st:=ViewState.new();var id: String="citrus_scallop"
	check.call(Followup.describe(null,id)["stage"]=="error","null source explicitly unavailable")
	check.call(Followup.describe(st,"unknown")["stage"]=="error","unknown direction explicitly unavailable")
	check.call(Followup.describe(st,id)["stage"]=="untasted","no paid record means no follow-up")
	var a: Dictionary=record();check.call(Direction.assess(id,a["config"])["matched"],"synthetic positive input actually fits production culinary condition")
	st.notebook=[a];var model: Dictionary=Followup.describe(st,id)
	check.call(model["stage"]=="choose" and model["record_id"]==1 and model["units"]==0,"paid witness alone is not selected or sold")
	var unrelated: Dictionary=record(2);unrelated["config"]["toppings"]=["topping_nori"];st.notebook.append(unrelated);st.selling=[unrelated]
	check.call(Followup.describe(st,id)["stage"]=="choose","unrelated selected menu never satisfies preparation")
	st.selling=[a];check.call(Followup.describe(st,id)["stage"]=="ready","actual matching selected paid witness is ready")
	st.last_report=row(a,4);st.last_report["day"]=1
	model=Followup.describe(st,id)
	check.call(model["stage"]=="sold" and model["units"]==4 and model["name"]==a["name"] and model["day"]==1,"single receipt uses immutable config, identity and completed count")
	var before: String=JSON.stringify([st.notebook,st.selling,st.last_report],"",true)
	model["name"]="changed output";Followup.describe(st,id)
	check.call(JSON.stringify([st.notebook,st.selling,st.last_report],"",true)==before,"projection and returned output cannot modify input witnesses")
	st.last_report["units"]=0;check.call(Followup.describe(st,id)["stage"]=="ready","zero completed units never claim sale")
	st.last_report={"day":1,"units":4,"recipe_name":a["name"],"version":a["version"]}
	check.call(Followup.describe(st,id)["stage"]=="ready","old missing config is never borrowed from today's matching notebook")
	st.last_report={"day":1,"units":4,"recipe_name":a["name"],"version":a["version"],"price":a["config"]["price"],"revenue":a["config"]["price"]*4,"ingredient_cost":Eval.unit_cost(a["config"])*4}
	check.call(Followup.describe(st,id)["stage"]=="sold","original receipt binds one exact dated immutable paid witness")
	var original_day: Variant=a["tasted_day"];a["tasted_day"]=2;st.notebook=[a];st.selling=[a]
	check.call(Followup.describe(st,id)["stage"]=="ready","later recreated same name/version cannot impersonate older receipt")
	a["tasted_day"]=original_day;st.notebook=[a];st.selling=[a]
	var ambiguous: Dictionary=a.duplicate(true);ambiguous["record_id"]=9;st.notebook.append(ambiguous)
	check.call(Followup.describe(st,id)["stage"]=="error","ambiguous original single-menu witness is explicitly rejected")
	st.notebook=[a];st.last_report["price"]=15000;st.last_report["revenue"]=60000
	check.call(Followup.describe(st,id)["stage"]=="ready","different paid price is not matched by name/version alone")
	st.last_report["price"]=a["config"]["price"];st.last_report["revenue"]=a["config"]["price"]*4
	st.last_report["ingredient_cost"]+=1;check.call(Followup.describe(st,id)["stage"]=="ready","inconsistent ingredient cost provides no single-menu proof")
	st.last_report["ingredient_cost"]-=1;st.notebook=[];st.selling=[]
	check.call(Followup.describe(st,id)["stage"]=="untasted","deleted original single-menu witness is unavailable, never reconstructed")
	st.notebook=[a];st.selling=[a]
	st.last_report={"day":1,"units":7,"menus":[row(a,3),row(unrelated,4)]}
	model=Followup.describe(st,id);check.call(model["units"]==3 and model["record_id"]==1,"mixed menus count only the matching dish, not all7guests")
	var b: Dictionary=record(3);st.notebook.append(b)
	st.last_report={"day":1,"units":9,"menus":[row(a,3),row(b,6)]}
	model=Followup.describe(st,id);check.call(model["units"]==6 and model["record_id"]==3,"two matching dishes retain one concrete identity and its count")
	st.last_report["menus"][0]["units"]=6;st.last_report["units"]=12
	check.call(Followup.describe(st,id)["record_id"]==3,"equal sold counts use stable newer-record tie break")
	st.notebook=[];st.selling=[]
	check.call(Followup.describe(st,id)["stage"]=="sold","deleted paid record does not erase actual immutable receipt")
	st.notebook=[a];st.selling=[a];st.last_report=row(a,4);st.last_report["day"]=1
	for field in ["record_id","version","units"]:
		for invalid in [true,-1,1.5,"4",null]:
			var valid: Dictionary=st.last_report.duplicate(true);st.last_report[field]=invalid
			check.call(Followup.describe(st,id)["stage"]=="error","malformed receipt value rejected: "+field)
			st.last_report=valid
	st.last_report["day"]=st.day;check.call(Followup.describe(st,id)["stage"]=="error","future/unsettled day is not completed receipt")
	st.last_report["day"]=1;st.last_report["recipe_name"]="another record"
	check.call(Followup.describe(st,id)["stage"]=="error","retained paid name and receipt must agree")
	st.last_report=row(a,4);st.last_report["day"]=1;st.last_report["config"]["price"]+=100
	check.call(Followup.describe(st,id)["stage"]=="error","same id with different full config cannot impersonate a sold bowl")
	st.last_report={"day":1,"units":6,"menus":[row(a,3),row(a,3)]}
	check.call(Followup.describe(st,id)["stage"]=="error","duplicate sold identity rejected")
	st.last_report={"day":1,"units":99,"menus":[row(a,3)]}
	check.call(Followup.describe(st,id)["stage"]=="error","menu counts must agree with full receipt total")
	st.last_report={};st.selling=[a.duplicate(true)];st.selling[0]["config"]["price"]+=100
	check.call(Followup.describe(st,id)["stage"]=="error","unpaid modified selection cannot impersonate retained witness")
	st.selling=[];st.notebook=[a,a]
	check.call(Followup.describe(st,id)["stage"]=="error","duplicate retained witness rejected")
	st.notebook=[a];st.notebook[0]["config"]["price"]=true
	check.call(Followup.describe(st,id)["stage"]=="error","malformed paid config explicitly rejected")
	check.call(true,"foraging-sales defensive suite reaches final assertion")
