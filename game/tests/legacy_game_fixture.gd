extends "res://scripts/domain/game_state.gd"
## Historical suites exercise the supported v15 supply model. Enter through
## the real migration, never by weakening the fresh v16 game gate. New broth
## acceptance tests must use game_state.gd directly instead of this fixture.
func _init() -> void:
	super()
	var previous: Dictionary=to_dict()
	previous.erase("broth_workshop"); previous.erase("noodle_workshop")
	previous.erase("recipe_knowledge")
	previous["schema_version"]=15
	var err: String=load_from_dict(previous)
	if err!="": push_error("Historical v15 fixture migration failed: "+err)
