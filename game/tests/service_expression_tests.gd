extends SceneTree
## Deterministic presentation tests. Synthetic transition snapshots below test
## observer boundaries only; the native fixture separately follows real service.
const Observer=preload("res://scripts/ui/service_expression.gd")
const Session=preload("res://scripts/domain/service_session.gd")
const Catalog=preload("res://scripts/domain/ingredient_catalog.gd")
const Art=preload("res://scripts/ui/pixel_art.gd")
var checks: int=0
var failures: int=0

func check(value: bool, message: String) -> void:
	checks+=1
	if not value: failures+=1; printerr("FAIL: "+message)

func _initialize() -> void:
	var tracker:=Observer.new()
	var data: Dictionary={"chef_cooking":false,"ready":0,"server_state":Session.S_IDLE,"server_seat":-1,"patrons":[]}
	tracker.reset(data)
	check(tracker.events().is_empty(),"initial attach does not invent work")
	data["chef_cooking"]=true
	tracker.observe(data)
	check(tracker.transition_count()==1 and tracker.age("cook")>=0,"actual cooking transition")
	var before: String=JSON.stringify(data)
	tracker.observe(data)
	check(JSON.stringify(data)==before and tracker.transition_count()==1,"read-only/idempotent snapshot")
	data["ready"]=1
	data["server_state"]=Session.S_CARRY
	data["server_seat"]=0
	tracker.observe(data)
	check(tracker.age("ready")>=0 and tracker.age("carry")>=0,"ready and actual carry are distinct")
	data["patrons"]=[{"id":1,"state":Session.P_EATING,"seat":0,"bubble":""}]
	tracker.observe(data)
	check(tracker.age("served",1)>=0 and tracker.age("reaction",1)<0,"arrival at plate is not fabricated praise")
	data["patrons"][0]["bubble"]="angry"
	tracker.observe(data)
	check(tracker.events()[-1]["reaction"]=="angry","negative actual reaction remains negative")
	var count: int=tracker.transition_count()
	tracker.advance(2.0)
	tracker.observe(data)
	check(tracker.events().is_empty() and tracker.transition_count()==count,"expired effects do not replay unchanged reaction")
	tracker.reset(data)
	check(tracker.events().is_empty() and tracker.transition_count()==0,"existing active session seeds without retrospective feedback")
	for id in 40:
		data["patrons"]=[{"id":id+10,"state":Session.P_EATING,"seat":0,"bubble":"heart"}]
		tracker.observe(data)
	check(tracker.events().size()<=Observer.MAX_EVENTS and tracker.get("_people").size()==1,"burst and visible-patron memory are bounded")
	var copy: Array=tracker.events()
	copy[0]["age"]=999
	check(float(tracker.events()[0]["age"])<1,"external view cannot mutate observer storage")
	tracker.reset()
	check(tracker.events().is_empty(),"closed session clears cosmetics")
	# Independent golden from unchanged mainb517337's frozen native package.
	# All1080 historical single-ID sprites must remain byte-identical.
	var digest:=HashingContext.new()
	digest.start(HashingContext.HASH_SHA256)
	var images: int=0
	for broth in Catalog.all_items("broth"):
		for noodle in Catalog.all_items("noodle"):
			for oil in Catalog.all_items("oil"):
				for topping in Catalog.all_items("topping"):
					var cfg: Dictionary=Catalog.default_config()
					cfg["broth"]=broth["id"]; cfg["noodle"]=noodle["id"]; cfg["oil"]=oil["id"]; cfg["toppings"]=[topping["id"]]
					digest.update(Art.bowl_image(cfg).get_data()); images+=1
	check(images==1080 and digest.finish().hex_encode()=="ab734daa26a75db40086ad65a8513873010d5cee06e3937054d22d3f4827bd98","legacy1080 golden sprites unchanged")
	var first: Dictionary=Catalog.default_config()
	first["broth_recipe"]={"ingredients":["chicken_bone","onion"],"method":"standard"}
	first["broth"]="broth_chicken"
	var second: Dictionary=first.duplicate(true)
	second["broth_recipe"]={"ingredients":["pork_bone","garlic"],"method":"standard"}
	second["broth"]="broth_tonkotsu"
	check(Art.bowl_image(first).get_data()!=Art.bowl_image(second).get_data(),"actual crafted identities reach tiny service food")
	var soup: Color=Art.broth_color(first)
	var drawn: Color=Art.recipe_bowl_image(first).get_pixel(6,13)
	check(absf(soup.r-drawn.r)<=1.0/255.0 and absf(soup.g-drawn.g)<=1.0/255.0 and absf(soup.b-drawn.b)<=1.0/255.0,"crafted inspection soup applies its tare exactly once")
	print("SERVICE EXPRESSION checks=%d failures=%d legacy_images=%d" % [checks,failures,images])
	quit(0 if failures==0 else 1)
