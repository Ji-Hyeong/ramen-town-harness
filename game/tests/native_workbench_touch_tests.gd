extends "res://tests/bowl_editor_qa.gd"
## Target the current visible native workbench. The old touch_scroll_tests
## targets TabLab behind this screen and reproduces30 failures on unchanged
## main; those hidden adapters cannot prove the touch behavior users receive.
var _completed_profiles: int=0


func _finger(point: Vector2, down: bool) -> void:
	var event:=InputEventScreenTouch.new()
	event.index=0
	event.position=point
	event.pressed=down
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func _finger_drag(point: Vector2) -> void:
	_finger(point,true)
	for step in 6:
		point.y-=12
		var event:=InputEventScreenDrag.new()
		event.index=0
		event.position=point
		event.relative=Vector2(0,-12)
		Input.parse_input_event(event)
		Input.flush_buffered_events()
		await process_frame
	_finger(point,false)
	await _settle()


func _finger_tap(view: Control, name: String) -> void:
	var button: Button=view.find_child(name,true,false)
	_check(button!=null,"visible current native control exists: "+name)
	if button==null: return
	_check(button.is_visible_in_tree() and not button.disabled,"usable native control: "+name)
	if not button.is_visible_in_tree() or button.disabled: return
	var ancestor: Node=button.get_parent()
	while ancestor!=null and not ancestor is ScrollContainer: ancestor=ancestor.get_parent()
	if ancestor is ScrollContainer:
		ancestor.ensure_control_visible(button)
		await _settle()
	_finger(button.get_global_rect().get_center(),true)
	_finger(button.get_global_rect().get_center(),false)
	await _settle()


func _scroll_moved(scroll: ScrollContainer, start: int, tag: String) -> void:
	var available: float=scroll.get_v_scroll_bar().max_value-scroll.get_v_scroll_bar().page
	print("NATIVE TOUCH SCROLL ",tag," available=",available," before=",start," after=",scroll.scroll_vertical)
	# The wide desktop renders all rows at once. It must remain stationary when
	# there is no overflow; the portrait must exercise actual scroll movement.
	if available>20:
		_check(scroll.scroll_vertical>start+20,tag+": finger scroll moves overflowing current content")
	else:
		_check(available<=0 and scroll.scroll_vertical==0,tag+": fitting current content has no fake scrolling")


func _run() -> void:
	for profile in [{"tag":"desktop","size":Vector2i(1280,800)},{"tag":"portrait","size":Vector2i(390,844)}]:
		await _native_touch(profile["tag"],profile["size"])
	_check(_completed_profiles==2,"both native touch profiles reach their final assertion")
	print("NATIVE WORKBENCH TOUCH checks=%d failures=%d" % [_checks,_failures.size()])
	for failure in _failures: printerr("FAIL: "+failure)
	quit(0 if _failures.is_empty() else 1)


func _native_touch(tag: String, dimensions: Vector2i) -> void:
	# Headless startup's initial64px resize is deferred. Let it finish before
	# setting the measured viewport, otherwise the first profile is invalid.
	await _settle()
	root.size=dimensions
	await _settle()
	_check(root.size==dimensions,tag+": actual root matches intended viewport")
	var dir: String=_data_root.path_join(tag+"_current_touch")
	_check(DirAccess.make_dir_recursive_absolute(dir)==OK,"isolated native touch directory")
	var app: Node=(load("res://scenes/main.tscn") as PackedScene).instantiate()
	app.set("data_location",{"ok":true,"dir":dir,"is_dev":true,"error":""})
	root.add_child(app)
	await _settle()
	app.call("_on_dev_pressed")
	app.set_process(false)
	await _settle()
	var editor: Control=app.get("_bowl_editor")
	_check(editor.is_visible_in_tree(),tag+": actual native screen receives input")
	var scroll: ScrollContainer=editor.get("_scroll")
	var button: Button=editor.find_child("EditorAdd_topping_chashu",true,false)
	_check(button!=null and button.is_visible_in_tree(),tag+": visible ingredient action")
	var clicks: Array[int]=[0]
	button.pressed.connect(func(): clicks[0]+=1)
	scroll.ensure_control_visible(button)
	await _settle()
	var point: Vector2=button.get_global_rect().intersection(scroll.get_global_rect()).get_center()
	var start: int=scroll.scroll_vertical
	var before: String=JSON.stringify(app.get("state").to_dict())
	var feedback: int=app.get("_juice").acknowledgement_count()
	await _finger_drag(point)
	_scroll_moved(scroll,start,tag+" enabled add")
	_check(clicks[0]==0 and JSON.stringify(app.get("state").to_dict())==before,tag+": native swipe never edits or pays")
	_check(app.get("_juice").acknowledgement_count()==feedback,tag+": canceled native swipe has no click effect")
	# Stop inertia with the same touch stream before an intentional short tap.
	point=scroll.get_global_rect().position+Vector2(1,10)
	_finger(point,true)
	_finger(point,false)
	scroll.ensure_control_visible(button)
	await _settle()
	await _finger_tap(editor,"EditorAdd_topping_chashu")
	_check(clicks[0]==1,tag+": one native tap emits exactly one action across translated input streams")
	_check(IngredientCatalog.toppings_of(app.get("state").draft_config).size()==2,tag+": one native tap adds one portion")
	_check(app.get("_juice").acknowledgement_count()==feedback+1,tag+": one visible action acknowledgement")
	button=editor.find_child("EditorAdd_topping_chashu",true,false)
	_check(button!=null,"current ingredient remains reachable after a single tap")
	if button==null:
		app.queue_free()
		await _settle()
		return
	button.disabled=true
	scroll.scroll_vertical=0
	await _settle()
	start=scroll.scroll_vertical
	point=button.get_global_rect().intersection(scroll.get_global_rect()).get_center()
	before=JSON.stringify(app.get("state").to_dict())
	await _finger_drag(point)
	_scroll_moved(scroll,start,tag+" disabled add")
	_check(JSON.stringify(app.get("state").to_dict())==before,tag+": disabled current ingredient button never acts")
	await _finger_tap(editor,"EditorMenu")
	await _finger_tap(editor,"EditorRecipeSettings")
	var edit: LineEdit=editor.find_child("EditorName",true,false)
	_check(edit!=null and edit.is_visible_in_tree(),tag+": visible current name input")
	point=edit.get_global_rect().get_center()
	_finger(point,true)
	_finger(point,false)
	await _settle()
	_check(edit.has_focus(),tag+": native name tap focuses current field")
	var old: String=edit.text
	edit.caret_column=edit.text.length()
	var key:=InputEventKey.new()
	key.pressed=true
	key.unicode=88
	Input.parse_input_event(key)
	Input.flush_buffered_events()
	await _settle()
	_check(edit.text==old+"X" and app.get("state").draft_name==edit.text,tag+": focused native field accepts actual text input")
	_completed_profiles+=1
	app.queue_free()
	await _settle()
