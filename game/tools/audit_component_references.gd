extends "res://tools/audit_campaign_progression.gd"
## Read-only planning evidence. A scan is never permission to delete a player's
## products: the normal whole-state parser must also accept the counterfactual.
const KINDS: Array[String]=["broth","noodle"]
var _input_path: String=""
var _input_bytes: String=""
var _input_state: State
var _uses: Dictionary={"broth":{},"noodle":{}}
var _finished: bool=false

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--input="):_input_path=arg.trim_prefix("--input=")
	# Only the prior diagnostic's owned milestone snapshots are eligible. Check
	# scope, symlinks, byte limit and committed provenance before creating output.
	if not _owned_input():quit(2);return
	var output: String=_new_output_from_args()
	if output!="":
		create_timer(120.0).timeout.connect(func():
			if not _finished:printerr("REFERENCE AUDIT TIMEOUT");quit(1))
		_probe.call_deferred(output)

func _owned_input() -> bool:
	if not _input_path.is_absolute_path() or _input_path!=_input_path.simplify_path() or _input_path.get_base_dir().get_base_dir().get_file()!="ramen-raw-notebook-capacity-v1" or _input_path.get_file() not in ["01_initial.json","02_workshops.json","03_records_100.json","03_records_200.json","03_records_300.json","04_after_cleanup.json"]:
		printerr("INPUT REFUSED: explicit owned raw-capacity milestone required");return false
	var walk: String=_input_path
	while walk!="/":
		var parent:=DirAccess.open(walk.get_base_dir())
		if parent==null or parent.is_link(walk.get_file()):printerr("INPUT REFUSED: missing parent or symlink");return false
		walk=walk.get_base_dir()
	var file:=FileAccess.open(_input_path,FileAccess.READ)
	if file==null:printerr("INPUT REFUSED: missing milestone");return false
	if file.get_length()>Save.MAX_BYTES:file.close();printerr("INPUT REFUSED: oversized milestone");return false
	_input_bytes=file.get_as_text();file.close()
	var evidence_path: String=ProjectSettings.globalize_path("res://").trim_suffix("/").get_base_dir().path_join("evidence/raw-notebook-capacity-v1.json")
	if not FileAccess.file_exists(evidence_path):printerr("INPUT REFUSED: missing committed provenance");return false
	var evidence: Variant=JSON.parse_string(FileAccess.get_file_as_string(evidence_path))
	if typeof(evidence)!=TYPE_DICTIONARY or typeof(evidence.get("milestones_each"))!=TYPE_ARRAY:printerr("INPUT REFUSED: malformed provenance");return false
	var witnessed: bool=false
	for run in evidence["milestones_each"]:
		for row in run:
			if row["id"]+".json"==_input_path.get_file() and row["sha256"]==_input_bytes.sha256_text():witnessed=true
	if not witnessed:printerr("INPUT REFUSED: bytes do not match committed actual-path provenance");return false
	var raw: Variant=JSON.parse_string(_input_bytes)
	if typeof(raw)!=TYPE_DICTIONARY:printerr("INPUT REFUSED: malformed milestone");return false
	_input_state=State.new()
	var error: String=_input_state.load_from_dict(raw)
	if error!="":printerr("INPUT REFUSED: "+error);return false
	return true

func _key(recipe: Dictionary) -> String:
	return JSON.stringify(recipe,"",true)

func _pointer(key: String) -> String:
	return key.replace("~","~0").replace("/","~1")

func _collect(value: Variant,path: String,depth: int=0) -> void:
	if not _check(depth<=32,"bounded serialized reference depth"):return
	if typeof(value)==TYPE_DICTIONARY:
		for key in value:
			var next: String=path+"/"+_pointer(str(key))
			for kind in KINDS:
				if key==kind+"_recipe":
					if not _check(typeof(value[key])==TYPE_DICTIONARY,"complete recipe reference is an object"):continue
					var id: String=_key(value[key])
					if not _uses[kind].has(id):_uses[kind][id]=[]
					_uses[kind][id].append(next)
			_collect(value[key],next,depth+1)
	elif typeof(value)==TYPE_ARRAY:
		for i in value.size():_collect(value[i],path+"/"+str(i),depth+1)

func _probe(output: String) -> void:
	var original: Dictionary=_input_state.to_dict()
	_collect(original,"")
	var simulated: Dictionary=original.duplicate(true)
	var inventories: Dictionary={}
	for kind in KINDS:
		var rows: Array=original[kind+"_workshop"]["recipes"]
		var kept: Array=[];var inventory: Array=[];var found: Dictionary={}
		var referenced_index: int=-1
		for i in rows.size():
			var id: String=_key(rows[i]["recipe"])
			var refs: Array=_uses[kind].get(id,[])
			inventory.append({"original_index":i,"formula_sha256":id.sha256_text(),"paths":refs.duplicate(),"externally_referenced":not refs.is_empty()})
			found[id]=true
			if not refs.is_empty():kept.append(rows[i].duplicate(true));referenced_index=i
		for id in _uses[kind]:_check(found.has(id),"every "+kind+" reference has a real completed product")
		inventories[kind]={"original_count":rows.size(),"referenced_count":kept.size(),"counterfactual_unused_count":rows.size()-kept.size(),"rows":inventory}
		simulated[kind+"_workshop"]["recipes"]=kept
		if _check(referenced_index>=0,"real current bowl has a referenced "+kind):
			var bad: Dictionary=original.duplicate(true)
			bad[kind+"_workshop"]["recipes"].remove_at(referenced_index)
			var target:=State.new();var before: String=_json(target)
			var error: String=target.load_from_dict(bad)
			_check(error!="" and _json(target)==before,"referenced "+kind+" removal is rejected before assignment")
	var clone:=State.new()
	var error: String=clone.load_from_dict(simulated)
	if not _check(error=="","normal parser accepts only proposed unused cleanup: "+error):quit(1);return
	_check(_json(clone)==JSON.stringify(simulated,"",true),"all values equal the exact two intended library-array changes")
	# Re-resolve indices from formulas after compaction; numeric UI indices are
	# transient and must never be treated as durable recipe identities.
	var unchanged: String=_json(clone)
	for kind in KINDS:
		var rows: Array=clone.to_dict()[kind+"_workshop"]["recipes"]
		var index: int=-1
		for i in rows.size():
			if _key(rows[i]["recipe"])==_key(_input_state.draft_config[kind+"_recipe"]):index=i;break
		if _check(index>=0,"retained current "+kind+" resolves after simulated compaction"):
			var result: Dictionary=clone.use_broth(index) if kind=="broth" else clone.use_noodle(index)
			_check(result["ok"],"actual same bowl application remains legal")
	_check(_json(clone)==unchanged,"reapplying retained current bowl changes no saved value")
	_check(FileAccess.get_file_as_string(_input_path)==_input_bytes,"owned source input remains byte-identical")
	if not _write_new(output.path_join("unused-cleanup-simulation.json"),JSON.stringify(simulated,"\t",true)+"\n"):quit(2);return
	var report: Dictionary={"format":1,"schema":State.SCHEMA_VERSION,"source_name":_input_path.get_file(),"source_sha256":_input_bytes.sha256_text(),"checks":checks+3,"failures":failures,"inventories":inventories,"limits":"Read-only actual milestone inventory and isolated counterfactual parser test. No player-facing cleanup or deletion API/UI is implemented. References include entire serialized drafts, history comparisons and retained achievement/story/service witnesses. Hash-only recipe knowledge is unchanged, not a completed-component ownership witness. A scan alone never authorizes removal; future transactions must validate whole state atomically and handle busy/current selection/UI indices. Not human fun, native rendering or device acceptance."}
	if not _write_new(output.path_join("report.json"),JSON.stringify(report,"\t",true)+"\n"):quit(2);return
	_finished=true
	print("COMPONENT REFERENCES source=%s checks=%d failures=%d" % [_input_path.get_file(),checks,failures.size()])
	quit(0 if failures.is_empty() else 1)
