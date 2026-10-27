extends RefCounted
## A view over the already tasted profile, never a counterfactual recipe or a
## score optimizer. Use the evaluator's notice threshold and weighted gap so
## the visible next action explains the same complaint as the customer.
const Catalog=preload("res://scripts/domain/ingredient_catalog.gd")
const Customers=preload("res://scripts/domain/customer_catalog.gd")
const Evaluator=preload("res://scripts/domain/recipe_evaluator.gd")

static func describe(profile: Dictionary, customer_id: String) -> Dictionary:
	var customer: Dictionary=Customers.find(customer_id)
	if customer.is_empty(): return {"error":"시식한 손님을 확인해 주세요."}
	var best: String=""
	var weight: float=-1.0
	for axis in Catalog.AXES:
		if not profile.has(axis) or typeof(profile[axis])!=TYPE_INT:
			return {"error":"시식한 그릇의 맛 정보를 확인해 주세요."}
		var gap: int=absi(int(profile[axis])-int(customer["targets"][axis]))
		var value: float=float(gap)*float(customer["weights"][axis])
		if gap>=Evaluator.NOTICE_GAP and value>weight:
			weight=value
			best=axis
	if best=="": return {"error":"","matched":true,"axis":"","caption":"취향과 잘 맞는 한 그릇"}
	var routes: Dictionary={"rich":["broth","broth","육수 배합 살펴보기"],"salt":["broth","tare","간 조절하기"],
		"aroma":["broth","oil","향미유 살펴보기"],"chew":["noodle","noodle","면 배합 살펴보기"],"spice":["broth","oil","매운 향미유 살펴보기"]}
	var route: Array=routes[best]
	return {"error":"","matched":false,"axis":best,"current":int(profile[best]),"target":int(customer["targets"][best]),
		"caption":"%s %d / 취향 %d" % [Catalog.AXIS_NAMES[best],profile[best],customer["targets"][best]],
		"group":route[0],"tab":route[1],"action":route[2]}
