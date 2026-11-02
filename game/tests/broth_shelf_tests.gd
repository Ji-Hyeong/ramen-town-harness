extends RefCounted
## Actual paid path and synthetic boundary documents are deliberately separate.
const State=preload("res://scripts/domain/game_state.gd")
const Broth=preload("res://scripts/domain/broth_workshop.gd")
const Shelf=preload("res://scripts/domain/broth_shelf.gd")
const Raw=preload("res://tests/known_change_fixtures.gd")
const Save=preload("res://scripts/services/save_service.gd")
var check: Callable
var finished: bool=false
var services: int=0

func js(state: Object) -> String:return JSON.stringify(state.to_dict(),"",true)
func ok(result: Dictionary,label: String) -> bool:
	var good: bool=bool(result.get("ok",false));check.call(good,label+": "+str(result.get("message","")));return good

func _combinations(out: Array,parts: Array,start: int,limit: int,methods: Array) -> void:
	var ids: Array=["pork_bone","chicken_bone","kelp","onion","ginger","garlic"]
	if not parts.is_empty():
		for method in methods:
			var raw: Dictionary={"ingredients":parts.duplicate(),"method":method}
			if Broth.error(raw,3,[],true)=="":out.append(Broth.canonical(raw))
	if parts.size()==limit:return
	for i in range(start,ids.size()):
		var next: Array=parts.duplicate();next.append(ids[i]);_combinations(out,next,i,limit,methods)

func candidates(limit: int=3,methods: Array=["standard"]) -> Array:
	var out: Array=[];_combinations(out,[],0,limit,methods);return out

func cash(state: Object) -> bool:
	for unused in 20:
		if state.wallet>=60000:return true
		var wallet: int=state.wallet;var day: int=state.day
		if not ok(state.begin_service(),"actual funding service begins"):return false
		if not state.active_session().run_to_end():check.call(false,"actual service completes");return false
		if not ok(state.settle_service(),"actual funding service settles"):return false
		check.call(state.wallet==wallet+state.last_report["net"] and state.wallet>wallet and state.day==day+1,"actual completed orders alone fund the raw path")
		services+=1
	check.call(false,"bounded funding limit exceeded");return false

func make_full() -> Dictionary:
	var maker:=Raw.new();maker.check=check
	var state: Object=maker.initial()
	if not ok(state.set_selling_menus([1]),"pin real paid funding menu"):return {}
	var overflow: Dictionary={}
	for recipe in candidates():
		if Broth.contains(state.broth_review()["recipes"],recipe):continue
		if state.broth_review()["recipes"].size()==60:overflow=recipe;break
		if not cash(state):return {}
		maker.brew(state,recipe["ingredients"])
	check.call(state.broth_review()["recipes"].size()==60 and not overflow.is_empty(),"60broths actually manufactured, plus distinct legal next formula")
	for index in range(1,60):
		if not cash(state):return {}
		if not ok(state.select_record(state.records().back()["record_id"]),"continue one real recipe family") or not ok(state.use_broth(index),"explicit actual broth application") or not ok(state.taste(),"actual paid distinct raw tasting"):return {}
	check.call(state.record_count()==60 and state.menu_count()==1 and state.broth_review()["working_count"]==60,"all60owned broths have actual paid retained menu references")
	return {"state":state,"next_recipe":overflow}

func disk(state: Object,path: String) -> void:
	check.call(DirAccess.make_dir_recursive_absolute(path)==OK,"isolated shelf data folder")
	var store:=Save.new(path)
	check.call(store.save_state(state)["ok"],"shelf save succeeds")
	var loaded:=State.new()
	check.call(store.load_into(loaded)["status"]=="ok" and js(loaded)==js(state),"whole shelf/ownership/menu state survives normal disk restart")

func run(callback: Callable,folder: String) -> void:
	check=callback
	var prepared: Dictionary=make_full()
	if prepared.is_empty():return
	var state: Object=prepared["state"]
	var original: Dictionary=state.to_dict()
	var before: String=js(state)
	check.call(not state.set_broth_archived(-1,true)["ok"] and not state.set_broth_archived(60,true)["ok"] and js(state)==before,"invalid shelf indices reject atomically")
	check.call(not state.set_broth_archived(59,false)["ok"] and js(state)==before,"duplicate working restore rejects atomically")
	check.call(state.set_broth_archived(59,true)["ok"],"archive a currently applied and historically referenced broth")
	var archived: Dictionary=state.to_dict();archived.erase("broth_shelf")
	var unchanged: Dictionary=original.duplicate(true);unchanged.erase("broth_shelf")
	check.call(archived==unchanged and state.broth_ready(),"archival changes only organization; all ownership/records/knowledge/cash/draft survive")
	before=js(state)
	check.call(not state.set_broth_archived(59,true)["ok"] and js(state)==before,"duplicate archive is a free atomic refusal")
	disk(state,folder.path_join("archived"))
	var maker:=Raw.new();maker.check=check
	var money: int=state.wallet
	maker.brew(state,prepared["next_recipe"]["ingredients"])
	check.call(state.broth_review()["recipes"].size()==61 and state.broth_review()["working_count"]==60 and state.wallet<money,"61st real paid broth completes without deleting any old formula")
	check.call(state.to_dict()["records"]==original["records"] and state.to_dict()["taste_achievements"]==original["taste_achievements"],"new production preserves every old menu/comparison/best witness")
	before=js(state)
	check.call(not state.set_broth_archived(59,false)["ok"] and js(state)==before,"restoring into full working shelf rejects before mutation")
	check.call(state.use_broth(59)["ok"] and state.broth_ready() and state.to_dict()["broth_shelf"]["archived"].size()==1,"archived formula applies exactly without fee or hidden restoration")
	check.call(state.set_broth_archived(60,true)["ok"] and state.set_broth_archived(59,false)["ok"],"free reversible restore after archiving another owned formula")
	check.call(state.set_broth_archived(0,true)["ok"] and state.begin_service()["ok"],"a fixed historical selling menu remains usable after archival")
	before=js(state)
	check.call(not state.set_broth_archived(0,false)["ok"] and js(state)==before,"service lock blocks shelf changes atomically")
	check.call(state.active_session().run_to_end() and state.settle_service()["ok"],"actual archived-menu service completes and settles")
	disk(state,folder.path_join("after61"))
	_malformed(state)
	_cap_synthetic()
	_migration(folder)
	finished=true

func _malformed(state: Object) -> void:
	var base: Dictionary=state.to_dict()
	for kind in ["missing","extra","array","duplicate","unknown","order","active61","downgrade"]:
		var bad: Dictionary=base.duplicate(true)
		match kind:
			"missing":bad.erase("broth_shelf")
			"extra":bad["broth_shelf"]["extra"]=0
			"array":bad["broth_shelf"]["archived"]="not an array"
			"duplicate":bad["broth_shelf"]["archived"].append(bad["broth_shelf"]["archived"][0])
			"unknown":bad["broth_shelf"]["archived"]=["0".repeat(64)]
			"order":bad["broth_shelf"]["archived"].reverse()
			"active61":bad["broth_shelf"]["archived"]=[]
			"downgrade":bad["schema_version"]=20;bad.erase("broth_shelf")
		var target:=State.new();var before: String=js(target)
		check.call(target.load_from_dict(bad)!="" and js(target)==before,"malformed/unsupported shelf rejects before assignment: "+kind)

func _cap_synthetic() -> void:
	# This boundary document is explicitly synthetic. It proves grammar/guard
	# behavior, not that a player manufactured300different broths or found fun.
	var seed:=State.new()
	check.call(seed.load_from_dict(JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/foraging-earned-v18-save.json")))=="","independent earned supplier state for synthetic cap grammar")
	var raw: Dictionary=seed.to_dict();var recipes: Array=raw["broth_workshop"]["recipes"]
	var overflow: Dictionary={}
	for recipe in candidates(4,["standard","gentle","rolling"]):
		if Broth.contains(recipes,recipe):continue
		if recipes.size()==Shelf.OWNED_LIMIT:overflow=recipe;break
		recipes.append({"recipe":recipe,"day":1})
	raw["broth_shelf"]["archived"]=[]
	for index in range(recipes.size()-Shelf.ACTIVE_LIMIT):raw["broth_shelf"]["archived"].append(Shelf.key(recipes[index]["recipe"]))
	var cap:=State.new()
	check.call(cap.load_from_dict(raw)=="" and recipes.size()==300 and not overflow.is_empty(),"synthetic legal300owned/60working cap parses")
	check.call(cap.set_broth_blend(overflow["ingredients"],overflow["method"])["ok"],"synthetic cap distinct draft")
	var before: String=js(cap)
	check.call(not cap.begin_broth()["ok"] and js(cap)==before,"total ownership cap300 refuses before spending")
	raw["broth_workshop"]["recipes"].append({"recipe":overflow,"day":1})
	raw["broth_shelf"]["archived"].append(Shelf.key(overflow))
	var target:=State.new();before=js(target)
	check.call(target.load_from_dict(raw)!="" and js(target)==before,"301owned formulas reject atomically")

func _migration(folder: String) -> void:
	var bytes: String=FileAccess.get_file_as_string("res://tests/fixtures/broth-shelf-v20-save.json")
	var previous: Dictionary=JSON.parse_string(bytes)
	var state:=State.new()
	check.call(previous["schema_version"]==20 and state.load_from_dict(previous)=="","exact actual previous20save loads")
	var modern: Dictionary=state.to_dict();modern.erase("broth_shelf");modern["schema_version"]=20
	# JSON parses numeric literals as floats; compare the complete serialized
	# value set after that same boundary, not an int-vs-float rendering detail.
	check.call(JSON.parse_string(JSON.stringify(modern))==previous,"migration changes no existing20field")
	var path: String=folder.path_join("migration");check.call(DirAccess.make_dir_recursive_absolute(path)==OK,"isolated migration folder")
	var store:=Save.new(path);var file:=FileAccess.open(store.main_path(),FileAccess.WRITE);file.store_string(bytes);file.close()
	check.call(store.save_state(state)["ok"] and FileAccess.get_file_as_string(store.legacy_bak_path(20))==bytes,"first21write preserves exact original20bytes")
	check.call(store.save_state(state)["ok"] and FileAccess.get_file_as_string(store.legacy_bak_path(20))==bytes,"later21write never overwrites original20backup")
