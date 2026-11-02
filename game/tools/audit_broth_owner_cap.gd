extends "res://tools/audit_campaign_progression.gd"
## Separate synthetic guard proof: leave a working slot FREE so the active60
## bound cannot accidentally mask a broken total300-ownership transaction guard.
const Fixtures=preload("res://tests/broth_shelf_tests.gd")
const Broth=preload("res://scripts/domain/broth_workshop.gd")
const Shelf=preload("res://scripts/domain/broth_shelf.gd")

func _initialize() -> void:
	var output: String=_new_output_from_args()
	if output!="":_probe_cap.call_deferred(output)

func _probe_cap(output: String) -> void:
	var seed:=State.new()
	if not _check(seed.load_from_dict(JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/foraging-earned-v18-save.json")))=="","base earned supplier grammar loads"):quit(1);return
	var raw: Dictionary=seed.to_dict();var rows: Array=raw["broth_workshop"]["recipes"]
	var fixtures:=Fixtures.new();var next_recipe: Dictionary={}
	for recipe in fixtures.candidates(4,["standard","gentle","rolling"]):
		if Broth.contains(rows,recipe):continue
		if rows.size()==Shelf.OWNED_LIMIT:next_recipe=recipe;break
		rows.append({"recipe":recipe,"day":1})
	var archived: Array=[]
	for i in range(rows.size()-Shelf.ACTIVE_LIMIT+1):archived.append(Shelf.key(rows[i]["recipe"]))
	raw["broth_shelf"]={"archived":archived}
	var state:=State.new()
	if not _check(state.load_from_dict(raw)=="","synthetic300owned/59working document parses"):quit(1);return
	_check(state.broth_review()["recipes"].size()==300 and state.broth_review()["working_count"]==59,"one actual working slot is free")
	if not _check(not next_recipe.is_empty() and state.set_broth_blend(next_recipe["ingredients"],next_recipe["method"])["ok"],"distinct legal candidate is selected"):quit(1);return
	var review: Dictionary=state.broth_review()
	_check(Broth.error(review["blend"],state.rank(),[],true)=="" and not Broth.contains(rows,review["blend"]) and state.wallet>int(review["cost"]),"not blocked by recipe duplication/rank/source/cash")
	var before: String=_json(state);var refused: Dictionary=state.begin_broth()
	_check(not refused["ok"] and refused["message"]=="육수 개발 기록이 가득 찼어요." and _json(state)==before and not state.broth_active(),"total ownership alone refuses before fee/work mutation")
	_check(state.set_broth_archived(0,false)["ok"] and state.broth_review()["working_count"]==60,"owned300still permits free restore into its available working slot")
	before=_json(state)
	_check(not state.set_broth_archived(1,false)["ok"] and _json(state)==before,"working60independently refuses a second restore")
	_check(state.set_broth_archived(0,true)["ok"] and state.broth_review()["working_count"]==59,"reversible archival frees the slot again")
	var report: Dictionary={"format":1,"schema":State.SCHEMA_VERSION,"checks":checks+3,"failures":failures,"owned":300,"working_at_brew_refusal":59,"money_and_duplicate_not_blocking":true,"limits":"Explicitly synthetic boundary document built from legal catalog formulas. No actual300manufacture, currency/rank progress, UI or human-fun claim. Read-only in-memory transitions and new isolated report only; no player save is opened or changed."}
	if not _write_new(output.path_join("report.json"),JSON.stringify(report,"\t",true)+"\n"):quit(2);return
	print("BROTH OWNER CAP checks=%d failures=%d" % [checks,failures.size()])
	quit(0 if failures.is_empty() else 1)
