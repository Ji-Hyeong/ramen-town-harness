extends RefCounted
## Independent witnesses use real ingredients/evaluator; no UI-derived labels
## or paid-state shortcuts. Shared with the real-scene end-to-end fixture.
const Directions = preload("res://scripts/domain/recipe_directions.gd")
const Catalog = preload("res://scripts/domain/ingredient_catalog.gd")
const Evaluator = preload("res://scripts/domain/recipe_evaluator.gd")
const Art = preload("res://scripts/ui/pixel_art.gd")


static func witness(id: String, variant: int = 0) -> Dictionary:
	var config: Dictionary = Catalog.default_config()
	config.erase("topping")
	config["toppings"] = ["topping_nori"]
	config["process"] = {"broth": "standard", "noodle": "standard"}
	match id:
		"citrus_clear":
			config.merge({"broth": "broth_chicken", "tare": "tare_shio", "oil": "oil_scallion", "noodle": "noodle_thin", "toppings": ["topping_citrus_peel", "topping_sprouts"]}, true)
			if variant == 1:
				config["broth"] = "broth_dashi"
				config["toppings"] = ["topping_citrus_peel", "topping_nori"]
		"sesame_depth":
			config.merge({"broth": "broth_tonkotsu", "tare": "tare_shoyu", "oil": "oil_roasted_sesame", "noodle": "noodle_thick", "toppings": ["topping_chashu", "topping_nori"]}, true)
			if variant == 1:
				config["tare"] = "tare_miso"
				config["toppings"] = ["topping_chashu", "topping_egg"]
		"harbor_sea":
			config.merge({"broth": "broth_roasted_sardine", "tare": "tare_shio", "oil": "oil_scallion", "noodle": "noodle_medium", "toppings": ["topping_scallop", "topping_nori"]}, true)
			if variant == 1:
				config["tare"] = "tare_shoyu"
				config["toppings"] = ["topping_scallop", "topping_egg"]
		"mountain_clear":
			config.merge({"broth":"broth_chicken","tare":"tare_shio","oil":"oil_scallion","noodle":"noodle_buckwheat","toppings":["topping_nori"]},true)
			if variant==1:
				config["broth"]="broth_dashi"
				config["toppings"]=["topping_sprouts"]
		"shiitake_depth":
			config.merge({"broth":"broth_tonkotsu","tare":"tare_miso","oil":"oil_garlic","noodle":"noodle_thin","toppings":["topping_grilled_shiitake"]},true)
			if variant==1:
				config["noodle"]="noodle_medium"
				config["toppings"]=["topping_grilled_shiitake","topping_grilled_shiitake"]
		"citrus_scallop":
			config.merge({"broth":"broth_chicken","tare":"tare_shio","oil":"oil_scallion","noodle":"noodle_thin","toppings":["topping_citrus_peel","topping_scallop"]},true)
			if variant==1:
				config["broth"]="broth_dashi"
				config["noodle"]="noodle_medium"
		"sesame_buckwheat":
			config.merge({"broth":"broth_tonkotsu","tare":"tare_miso","oil":"oil_roasted_sesame","noodle":"noodle_buckwheat","toppings":["topping_egg"]},true)
			if variant==1:
				config["tare"]="tare_shoyu"
				config["toppings"]=["topping_chashu","topping_nori"]
		"sardine_shiitake":
			config.merge({"broth":"broth_roasted_sardine","tare":"tare_shio","oil":"oil_scallion","noodle":"noodle_thin","toppings":["topping_grilled_shiitake"]},true)
			if variant==1:
				config["noodle"]="noodle_medium"
				config["toppings"]=["topping_grilled_shiitake","topping_sprouts"]
	return config


func run(check: Callable) -> void:
	var recipes: Array = []
	var signatures: Array[String] = []
	var dishes: Array[PackedByteArray] = []
	var definitions: Array = Directions.catalog()
	definitions[0]["requires"].clear()
	check.call(Directions.find("citrus_clear")["requires"].size() == 1, "definitions are independent deep copies")
	for definition in Directions.catalog():
		var id: String=definition["id"]
		for variant in 2:
			var config: Dictionary = witness(id, variant)
			var original: String = JSON.stringify(config)
			var assessment: Dictionary = Directions.assess(id, config)
			check.call(assessment["error"] == "" and assessment["matched"], id + ": two different real solutions")
			check.call(assessment["profile"] == Evaluator.build_profile(config), "actual profile, not invented gains")
			check.call(assessment["cost"] == Evaluator.unit_cost(config) and assessment["seconds"] == Evaluator.prep_seconds(config), "actual costs and duration")
			var priced: Dictionary = config.duplicate(true)
			priced["price"] = 12000
			check.call(Directions.assess(id, priced)["matched"], "price never determines discovery")
			var record := {"config": config}
			check.call(Directions.tested_ids([record]).has(id), "retained actual configuration witnesses style")
			check.call(not Directions.tested_ids([]).has(id), "removing witness removes status")
			check.call(JSON.stringify(config) == original, "read model never mutates its input")
			if variant == 0:
				recipes.append(record)
				signatures.append(JSON.stringify(Evaluator.build_profile(config)))
				dishes.append(Art.recipe_bowl_image(config).get_data())
		var wrong: Dictionary = witness(id)
		var material: String = Directions.find(id)["ingredient"]
		if str(Directions.find(id)["slot"]) == "topping":
			wrong["toppings"] = ["topping_nori"]
		else:
			wrong[Directions.find(id)["slot"]] = "oil_garlic" if material.begins_with("oil") else ("noodle_thin" if material.begins_with("noodle") else "broth_dashi")
		check.call(not Directions.assess(id, wrong)["matched"], "numeric similarity without required farmed material earns nothing")
		var unbalanced: Dictionary = witness(id)
		match id:
			"citrus_clear":
				unbalanced["broth"] = "broth_tonkotsu"
				unbalanced["toppings"] = ["topping_citrus_peel", "topping_chashu", "topping_chashu", "topping_chashu"]
			"sesame_depth":
				unbalanced["broth"] = "broth_chicken"
				unbalanced["toppings"] = ["topping_nori"]
			"harbor_sea":
				unbalanced["tare"] = "tare_shoyu"
				unbalanced["toppings"] = ["topping_scallop", "topping_nori", "topping_nori", "topping_nori"]
			"mountain_clear":
				unbalanced["broth"]="broth_tonkotsu"
				unbalanced["toppings"]=["topping_chashu","topping_chashu"]
			"shiitake_depth":
				unbalanced["broth"]="broth_chicken"
				unbalanced["tare"]="tare_shio"
			"citrus_scallop":
				unbalanced["broth"]="broth_tonkotsu"
				unbalanced["toppings"].append_array(["topping_chashu","topping_chashu"])
			"sesame_buckwheat":
				unbalanced["broth"]="broth_chicken"
				unbalanced["tare"]="tare_shio"
			"sardine_shiitake":
				unbalanced["tare"]="tare_shoyu"
				unbalanced["toppings"].append_array(["topping_nori","topping_nori","topping_nori"])
		check.call(not Directions.assess(id, unbalanced)["matched"], "required material alone cannot bypass actual flavor conditions")
	check.call(Directions.tested_ids(recipes).size() == 8, "eight real directions from actual witnesses")
	for i in signatures.size():
		for j in range(i + 1, signatures.size()):
			check.call(signatures[i] != signatures[j] and dishes[i] != dishes[j], "different actual flavor profiles and dish pixels")
	check.call(Directions.assess("unknown", Catalog.default_config())["error"] != "", "unknown direction is an explicit error")
	check.call(Directions.assess("citrus_clear", {})["error"] != "", "invalid composition is not a discovery")
