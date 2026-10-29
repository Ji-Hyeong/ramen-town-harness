extends SceneTree
## Actual production, selection, paid witnesses and isolated disk restart.
## Comparing is read-only, including knowledge; only existing use actions reveal.
const Fixture=preload("res://tests/known_change_fixtures.gd")
const Summary=preload("res://scripts/ui/recipe_change_summary.gd")
const Save=preload("res://scripts/services/save_service.gd")
var checks: int=0
var failures: Array[String]=[]
var pure_finished: bool=false
var output: String=""

func check(ok: bool,message: String) -> void:
	checks+=1
	if message=="result edits cannot reach inputs": pure_finished=true
	if not ok: failures.append(message)

func _initialize() -> void:
	var args:=OS.get_cmdline_user_args()
	if args.size()!=1 or not args[0].begins_with("--test-data-dir="):
		printerr("Use --test-data-dir=<new absolute isolated folder>");quit(2);return
	output=args[0].trim_prefix("--test-data-dir=")
	if not output.is_absolute_path() or output.contains("://") or DirAccess.dir_exists_absolute(output) or FileAccess.file_exists(output):
		printerr("The isolated output must be a new absolute folder.");quit(2);return
	if DirAccess.make_dir_recursive_absolute(output)!=OK:
		printerr("Cannot create the isolated test folder.");quit(2);return
	_run.call_deferred()

func ledger(st: Object) -> String:
	return JSON.stringify(st.to_dict(),"",true)

func project(st: Object,kind: String,index: int) -> Dictionary:
	var before: String=ledger(st)
	var result: Dictionary=st.component_comparison(kind,index)
	check(result["ok"],"actual completed component comparison")
	var candidate: Dictionary=Fixture.Comparison.apply_recipe(st.draft_config,kind,result["recipe"])
	var projected: Dictionary=Summary.project(result["current_ramen"],result["candidate_ramen"],st.recipe_known(st.draft_config),st.recipe_known(candidate))
	check(ledger(st)==before,"comparison and projection cannot modify any player field")
	return projected

func _run() -> void:
	preload("res://tests/recipe_change_summary_tests.gd").new().run(check)
	check(pure_finished,"pure fixture reaches its final assertion")
	var fixture:=Fixture.new();fixture.check=check
	var st: Object=fixture.initial()
	var unknown: Dictionary=project(st,"broth",1)
	check(unknown["state"]=="neutral" and unknown["taste"]=="" and unknown["reason"]=="" and unknown["kind"]=="","unselected product cannot reveal whole taste equality")
	check(unknown["cost_delta"]==480 and unknown["prep_delta"]==24,"public costs remain accurate while taste unknown")
	fixture.known_expensive(st)
	var known: Dictionary=project(st,"broth",1)
	check(known["state"]=="same" and known["kind"]=="burden" and known["cost_delta"]==480 and known["prep_delta"]==24,"actual paid/selected bone2to3 has same taste and increased burden")
	var witnesses: String=JSON.stringify(st.records(),"",true)
	check(st.use_broth(1)["ok"],"explicit existing product swap")
	var saving: Dictionary=project(st,"broth",0)
	check(saving["state"]=="same" and saving["kind"]=="saving" and saving["cost_delta"]==-480 and saving["prep_delta"]==-24,"actual reverse comparison is cheaper/faster with equal taste")
	check(st.use_broth(0)["ok"],"explicit return to controlled current bowl")
	var index: int=fixture.changed_broth(st)
	check(project(st,"broth",index)["state"]=="changed","actual different raw broth changes taste")
	index=fixture.changed_noodle(st)
	check(project(st,"noodle",index)["state"]=="changed","actual different raw noodles change taste")
	check(JSON.stringify(st.records(),"",true)==witnesses,"new products and previews preserve both paid witnesses")
	var saver:=Save.new(output)
	check(saver.save_state(st)["ok"],"real isolated save")
	var restored:=Fixture.State.new()
	check(saver.load_into(restored)["status"]=="ok" and ledger(restored)==ledger(st),"full state and knowledge survive actual disk restart")
	var after: Dictionary=project(restored,"broth",1)
	check(after==known,"same exact known comparison after restart")
	var file:=FileAccess.open(output.path_join("summary-results.json"),FileAccess.WRITE)
	check(file!=null,"new evidence output")
	if file!=null:
		file.store_string(JSON.stringify({"unknown":unknown,"known":known,"saving":saving,"restarted":after,"state":restored.to_dict()},"\t",true));file.close()
	print("RECIPE CHANGE INTEGRATION checks=%d failures=%d" % [checks,failures.size()])
	for failure in failures:printerr("FAIL: "+failure)
	quit(0 if failures.is_empty() else 1)
