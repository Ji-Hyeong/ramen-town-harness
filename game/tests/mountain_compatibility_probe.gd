extends SceneTree
## Run the exact same probe against the accepted-main pack and current pack.
## Hash all original 972 base dishes/evaluations rather than accepting a change
## merely because the new renderer and tests agree with one another.
const Catalog=preload("res://scripts/domain/ingredient_catalog.gd")
const Eval=preload("res://scripts/domain/recipe_evaluator.gd")
const Art=preload("res://scripts/ui/pixel_art.gd")


func _initialize() -> void:
	var output: String=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--probe-out="): output=arg.trim_prefix("--probe-out=")
	if not output.begins_with("/private/tmp/"):
		printerr("probe requires an explicit disposable /private/tmp output")
		quit(2)
		return
	var results: Array=[]
	for broth in Catalog.items("broth"):
		for tare in Catalog.items("tare"):
			for oil in Catalog.items("oil"):
				for noodle in Catalog.items("noodle"):
					for topping in Catalog.items("topping"):
						for cook in Catalog.items("cook"):
							var cfg: Dictionary={"broth":broth["id"],"tare":tare["id"],"oil":oil["id"],"noodle":noodle["id"],"toppings":[topping["id"]],"cook":cook["id"],"price":9000}
							var pixels:=HashingContext.new()
							pixels.start(HashingContext.HASH_SHA256)
							pixels.update(Art.recipe_bowl_image(cfg).get_data())
							results.append({"config":cfg,"evaluation":Eval.evaluate(cfg),"dish_sha256":pixels.finish().hex_encode()})
	var file=FileAccess.open(output,FileAccess.WRITE)
	if file==null:
		printerr("probe output cannot be written")
		quit(2)
		return
	file.store_string(JSON.stringify(results,"",true))
	file.close()
	print("COMPATIBILITY probe dishes=%d" % results.size())
	quit(0)
