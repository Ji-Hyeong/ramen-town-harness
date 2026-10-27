extends RefCounted
## Read-only presentation data for the visible noodle formula cards. Nothing
## here touches player state: the workbench emits `noodle_set` and the controller
## stays the only writer.
const Noodle=preload("res://scripts/domain/noodle_workshop.gd")
const Methods=preload("res://scripts/domain/recipe_process.gd")
const PantryArt=preload("res://scripts/ui/broth_material_art.gd")
const MockArt=preload("res://scripts/ui/mock_fidelity_art.gd")
const SECTIONS: Array=[["flour","밀가루"],["water","배합수"],["cut","면 굵기"],["method","반죽·숙성"]]
## Card captions only; the exact names, traits and conditions stay in the
## tooltip and the optional disclosure. The preview carries the real totals.
const SHORT: Dictionary={
	"wheat":"중력분","strong":"강력분","buckwheat":"메밀분",
	"clear":"맑은 물","alkaline":"간수",
	"thin":"가는 면","medium":"중간 면","thick":"굵은 면",
	"standard":"기본","moist":"고가수","rested":"숙성",
}


static func options(field: String) -> Array:
	if field!="method": return Noodle.options(field)
	var rows: Array=[]
	for id in Methods.ids("noodle"): rows.append(Methods.method("noodle",id))
	return rows


## Water and method are add-ons to the base dough; flour and cut carry the
## base price, so only those two show a plain amount.
static func cost_caption(field: String, option: Dictionary) -> String:
	var value: int=int(option["cost"])
	if field=="flour" or field=="cut": return "%d원" % value
	return "+%d원" % value


## One short label (fits a 3-column card) for a choice that cannot be picked yet.
static func lock_caption(field: String, option: Dictionary, rank: int, discovered: Array) -> String:
	if field=="method" and int(option["rank"])>rank: return "랭크%d" % int(option["rank"])
	if field=="flour" and option["id"]=="buckwheat" and (rank<3 or not discovered.has("noodle_buckwheat")): return "샘플 필요"
	return ""


static func texture(field: String, id: String) -> Texture2D:
	if field=="flour" or field=="water": return PantryArt.texture(id)
	if field=="cut": return MockArt.bowl("noodle_"+id)
	return MockArt.texture("noodles")


## Existing original food art for the current formula; no recipe-specific art.
static func preview(base_id: String) -> Texture2D:
	return MockArt.bowl(base_id)
