extends "res://tests/bowl_editor_qa.gd"
## Actual ingredient-led dishes and service stages. Every formula is crafted
## through guarded APIs; game seconds are deliberately advanced by QA. This
## is native renderer/input evidence, not physical device or real-time play.
const Current=preload("res://scripts/domain/game_state.gd")
const Service=preload("res://scripts/domain/service_session.gd")
const RecipeLook=preload("res://scripts/ui/recipe_appearance.gd")
const CASES=[
	{"id":"clear","raw":["kelp","ginger"],"method":"gentle","flour":"wheat","water":"clear","cut":"thin","oil":"oil_garlic"},
	{"id":"chicken","raw":["chicken_bone","onion"],"method":"standard","flour":"wheat","water":"clear","cut":"thin","oil":"oil_garlic"},
	{"id":"bone","raw":["pork_bone","pork_bone","garlic"],"method":"standard","flour":"strong","water":"alkaline","cut":"thick","oil":"oil_garlic"},
	{"id":"chili","raw":["chicken_bone","onion"],"method":"standard","flour":"wheat","water":"clear","cut":"thin","oil":"oil_chili"},
	{"id":"herb","raw":["kelp","ginger"],"method":"gentle","flour":"wheat","water":"clear","cut":"medium","oil":"oil_scallion"},
	{"id":"double_chicken","raw":["chicken_bone","chicken_bone","onion"],"method":"gentle","flour":"strong","water":"alkaline","cut":"medium","oil":"oil_garlic"}
]
func food_state(row: Dictionary) -> Current:
	var st:=Current.new()
	for result in [st.set_broth_blend(row["raw"],row["method"]),st.begin_broth(),st.advance_broth(20.0),st.use_broth(0)]: _check(result["ok"],"actual raw soup "+str(row["id"]))
	for field in ["flour","water","cut"]: _check(st.set_noodle_formula(field,row[field])["ok"],"actual noodle "+field)
	for result in [st.begin_noodle(),st.advance_noodle(20.0),st.use_noodle(0),st.set_draft_choice("oil",row["oil"]),st.set_draft_toppings(["topping_chashu","topping_egg"])]: _check(result["ok"],"actual complete bowl "+str(row["id"]))
	return st
func _run() -> void:
	for profile in [{"tag":"portrait","size":Vector2i(390,844)},{"tag":"desktop","size":Vector2i(1280,800)}]:
		var holder:=SubViewport.new()
		holder.size=profile["size"]; holder.handle_input_locally=true; holder.render_target_update_mode=SubViewport.UPDATE_ALWAYS
		root.add_child(holder)
		var dir: String=_data_root.path_join(profile["tag"])
		_check(DirAccess.make_dir_recursive_absolute(dir)==OK,"own baseline directory")
		var app: Node=await _spawn(holder,dir)
		app.set_process(false)
		for row in CASES:
			var st: Current=food_state(row)
			app.set("state",st)
			app.call("_refresh_all"); app.call("_on_dev_pressed")
			await _settle()
			var before: Dictionary=st.to_dict()
			await _shot(holder,profile["tag"]+"_food_"+row["id"]+".png")
			_check(st.to_dict()==before,"rendering is read-only")
			app.call("_close_overlay"); app.call("_sync_bowl_editor")
		await service_flow(holder,app,profile["tag"])
		app.queue_free(); await _settle(); holder.queue_free(); await _settle()
	if not _layout_only: await rendered_guards()
	print("FOOD AND SERVICE checks=%d failures=%d" % [_checks,_failures.size()])
	for failure in _failures: printerr("FAIL: "+failure)
	quit(0 if _failures.is_empty() else 1)

## Follow a genuine paid recipe and service. Each captured stage is found by
## advancing the actual simulation; no invented patrons or reaction kinds.
func service_flow(holder: SubViewport, app: Node, tag: String) -> void:
	var st: Current=food_state(CASES[3])
	_check(st.taste()["ok"],tag+": actual tasting before selling")
	app.set("state",st)
	app.call("_refresh_all"); app.call("_close_overlay"); app.call("_sync_bowl_editor")
	var shop: Control=app.get("_shop")
	var before: Dictionary=st.to_dict()
	await _tap(holder,app,"StartServiceButton")
	var session: Service=st.active_session()
	_check(session!=null,tag+": actual service starts")
	if session==null: return
	var observer: Object=shop.get("_activity")
	var seen: Dictionary={}
	var counter: int=0
	while session.is_running() and counter<1800 and seen.size()<4:
		session.advance(1.0)
		shop.call("_process",0.0)
		var ent: Dictionary=session.entities()
		var stage: String=""
		if ent["chef_cooking"] and not seen.has("cook"): stage="cook"
		elif int(ent["server_state"])==Service.S_CARRY and not seen.has("carry"): stage="carry"
		else:
			for event in observer.events():
				if event["kind"] in ["served","reaction"] and not seen.has(event["kind"]):
					stage=event["kind"]
					break
		if stage!="":
			seen[stage]=true
			var count: int=observer.transition_count()
			shop.call("_process",0.0)
			_check(observer.transition_count()==count,tag+": repeated actual snapshot never replays "+stage)
			app.call("_refresh_status")
			var actual: Dictionary=session.entities().duplicate(true)
			await _settle()
			await _shot(holder,tag+"_service_"+stage+".png")
			_check(session.entities()==actual,tag+": rendering never advances actual service "+stage)
			if stage=="carry" and holder.size.x<720:
				await _tap(holder,shop,"ShopCamera")
				var camera: Dictionary=shop.call("scene_info")
				_check(camera["focus_zoom"] and int(camera["scale"])==3,tag+": real close-view action uses integer3x pixels")
				_check(Rect2(Vector2.ZERO,Vector2(holder.size)).encloses(camera["rect"]),tag+": visible camera inside actual viewport")
				await _shot(holder,tag+"_service_close.png")
				_check(session.entities()==actual and st.to_dict()==before,tag+": camera only changes the view")
				var original_size: Vector2i=holder.size
				holder.size=Vector2i(390,750)
				await _settle()
				camera=shop.call("scene_info")
				_check(int(camera["scale"])==3 and Rect2(Vector2.ZERO,Vector2(holder.size)).encloses(camera["rect"]),tag+": compact camera keeps integer3x and visible bounds")
				await _shot(holder,tag+"_service_compact_close.png")
				holder.size=original_size
				await _settle()
		counter+=1
	_check(seen.size()==4,tag+": cooking/carry/served/reaction all reached in actual service")
	_check(st.to_dict()==before,tag+": drawing and unfinished service never change wallet/day/records")
	var discarded: int=observer.transition_count()
	shop.call("set_session",session)
	_check(observer.events().is_empty() and observer.transition_count()==0,tag+": attaching existing session seeds without replaying old events")
	_check(discarded>0,tag+": actual service transitions were observed")
	if bool(shop.get("focus_zoom")): await _tap(holder,shop,"ShopCamera")
	st.cancel_service()
	shop.call("set_session",null)
	_check(observer.events().is_empty() and observer.transition_count()==0 and st.to_dict()==before,tag+": cancellation clears only cosmetics, never settles")

## Real GPU pixels: colored soup changes while the ceramic body remains equal.
## The independent opaque topping is checked with8-bit compositing tolerance.
func rendered_guards() -> void:
	var holder:=SubViewport.new()
	holder.size=Vector2i(512,320)
	holder.transparent_bg=true
	holder.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(holder)
	var view: Control=preload("res://scripts/ui/layered_recipe_view.gd").new()
	view.size=Vector2(512,320)
	holder.add_child(view)
	view.set_process(false)
	view.set_config(food_state(CASES[1]).draft_config)
	await _settle()
	RenderingServer.force_draw()
	var first: Image=holder.get_texture().get_image()
	var base: Control=view.get("_base")
	var bounds: Rect2=base.get_global_rect()
	view.set_config(food_state(CASES[3]).draft_config)
	await _settle()
	RenderingServer.force_draw()
	var second: Image=holder.get_texture().get_image()
	_check(image_has_rendered_content(first) and image_has_rendered_content(second),"GPU guard images are actual nonblank pixels")
	var ceramic: int=0
	for y in range(int(bounds.position.y+bounds.size.y*0.76),int(bounds.position.y+bounds.size.y*0.97)):
		for x in range(int(bounds.position.x),int(bounds.end.x)):
			if first.get_pixel(x,y)!=second.get_pixel(x,y): ceramic+=1
	_check(ceramic==0,"red ceramic body is not globally tinted")
	# Ask the GPU for the actual uppermost layer's coverage. Atlas margins and
	# raster rounding make a CPU reconstruction an unreliable opaque-pixel mask.
	base.visible=false
	var portions: Array=view.get("_portions")
	for i in portions.size()-1: portions[i].visible=false
	for wisp in view.get("_steam"): wisp.visible=false
	await _settle()
	RenderingServer.force_draw()
	var coverage: Image=holder.get_texture().get_image()
	var samples: int=0
	var topping_changes: int=0
	var maximum_delta: float=0.0
	for y in range(holder.size.y):
		for x in range(holder.size.x):
			if coverage.get_pixel(x,y).a>=0.999:
				samples+=1
				var a: Color=first.get_pixel(x,y)
				var b: Color=second.get_pixel(x,y)
				var difference: float=maxf(absf(a.r-b.r),maxf(absf(a.g-b.g),absf(a.b-b.b)))
				maximum_delta=maxf(maximum_delta,difference)
				if difference>1.01/255.0: topping_changes+=1
	_check(samples>20 and topping_changes==0,"opaque independent egg retains colors within8-bit compositing precision")
	var changed: int=0
	for y in range(holder.size.y):
		for x in range(holder.size.x):
			if first.get_pixel(x,y)!=second.get_pixel(x,y): changed+=1
	_check(changed>500,"real native surface visibly changes with the applied oil")
	print("FOOD PIXEL GUARDS ceramic=%d topping=%d opaque_samples=%d surface=%d max_topping_delta=%f" % [ceramic,topping_changes,samples,changed,maximum_delta])
	holder.queue_free()
	await _settle()
