extends "res://scripts/domain/game_state.gd"
## Explicit v16 compatibility fixture. Preserve the then-current raw broth gate
## while migrating the historical prepared-noodle supply without granting crafts.
func _init() -> void:
	super()
	var previous: Dictionary=to_dict()
	previous.erase("noodle_workshop")
	previous.erase("recipe_knowledge"); previous.erase("server_challenge")
	previous["schema_version"]=16
	var err: String=load_from_dict(previous)
	if err!="": push_error("Historical v16 fixture migration failed: "+err)
