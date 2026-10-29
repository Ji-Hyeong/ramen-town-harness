extends RefCounted
## Actual fresh raw production only; no legacy supply or progress injection.
const State=preload("res://scripts/domain/game_state.gd")
const Comparison=preload("res://scripts/domain/component_comparison.gd")
var check: Callable
func brew(st: Object,ingredients: Array,method: String="standard") -> int:
 check.call(st.set_broth_blend(ingredients,method)["ok"],"actual selected raw broth")
 var count: int=st.broth_review()["recipes"].size()
 var money: int=st.wallet
 var fee: int=st.broth_review()["cost"]
 check.call(st.begin_broth()["ok"] and st.advance_broth(20.0)["ok"],"actual paid broth completion")
 check.call(st.wallet==money-fee and st.broth_review()["recipes"].size()==count+1,"one real fee and product")
 return count
func noodles(st: Object,formula: Dictionary) -> int:
 for field in ["flour","water","cut","method"]:check.call(st.set_noodle_formula(field,formula[field])["ok"],"actual raw noodle setting")
 var count: int=st.noodle_review()["recipes"].size()
 var money: int=st.wallet
 var fee: int=st.noodle_review()["cost"]
 check.call(st.begin_noodle()["ok"] and st.advance_noodle(20.0)["ok"],"actual paid noodle completion")
 check.call(st.wallet==money-fee and st.noodle_review()["recipes"].size()==count+1,"one real noodle fee and product")
 return count
func initial() -> Object:
 var st:=State.new()
 check.call(not st.broth_ready() and not st.noodle_ready(),"true fresh raw player")
 for pair in [["tare","tare_shio"],["oil","oil_scallion"],["cook","cook_firm"]]:check.call(st.set_draft_choice(pair[0],pair[1])["ok"],"actual fixed context")
 check.call(st.set_draft_toppings(["topping_nori"])["ok"] and st.set_draft_price(9000)["ok"],"actual fixed topping and price")
 brew(st,["pork_bone","pork_bone"])
 check.call(st.use_broth(0)["ok"],"explicit first broth use")
 noodles(st,{"flour":"wheat","water":"clear","cut":"thin","method":"standard"})
 check.call(st.use_noodle(0)["ok"] and st.recipe_known(st.draft_config),"explicit complete bowl selection grants knowledge")
 check.call(st.taste()["ok"],"actual paid starting witness")
 brew(st,["pork_bone","pork_bone","pork_bone"])
 var candidate: Dictionary=Comparison.apply_recipe(st.draft_config,"broth",st.broth_review()["recipes"][1]["recipe"])
 check.call(not st.recipe_known(candidate) and st.recipe_known(st.draft_config),"unselected completed product doesn't reveal whole recipe")
 return st
func known_expensive(st: Object) -> void:
 check.call(st.use_broth(1)["ok"] and st.recipe_known(st.draft_config),"explicit second bowl selection")
 check.call(st.taste()["ok"],"actual paid second witness")
 check.call(st.use_broth(0)["ok"],"return to known starting bowl")
 var review: Dictionary=st.component_comparison("broth",1)
 check.call(review["ok"] and review["candidate_ramen"]["unit_cost"]-review["current_ramen"]["unit_cost"]==480 and review["candidate_ramen"]["prep_seconds"]-review["current_ramen"]["prep_seconds"]==24,"real same-taste expensive pair has480/24delta")
func changed_broth(st: Object) -> int:
 var index: int=brew(st,["kelp","ginger"])
 check.call(st.use_broth(index)["ok"] and st.use_broth(0)["ok"],"explicit changed broth then restore baseline")
 return index
func changed_noodle(st: Object) -> int:
 var index: int=noodles(st,{"flour":"strong","water":"alkaline","cut":"thick","method":"moist"})
 check.call(st.use_noodle(index)["ok"] and st.use_noodle(0)["ok"],"explicit changed noodle then restore baseline")
 return index
