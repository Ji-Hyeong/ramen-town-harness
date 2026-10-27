extends RefCounted
## Pure, read-only mapping from an applied config to bounded presentation values.
## It reads only the supplied dictionary: no state, randomness, clock or writes.
## Colors are art direction for the pixels of soup/noodle/oil, never a score.
const Catalog = preload("res://scripts/domain/ingredient_catalog.gd")

## color: mid-tone of the finished soup; weight: share of the blend;
## milk: 0 clear .. 1 creamy/opaque emulsion.
const BROTH := {
	"pork_bone": {"color": Color(0.94, 0.86, 0.72), "weight": 1.0, "milk": 0.9},
	"chicken_bone": {"color": Color(0.92, 0.70, 0.22), "weight": 1.0, "milk": 0.1},
	"kelp": {"color": Color(0.66, 0.72, 0.50), "weight": 0.7, "milk": 0.0},
	"clam": {"color": Color(0.80, 0.76, 0.58), "weight": 0.9, "milk": 0.05},
	"sardine": {"color": Color(0.45, 0.34, 0.24), "weight": 1.2, "milk": 0.0},
	"onion": {"color": Color(0.86, 0.66, 0.30), "weight": 0.3, "milk": 0.1},
	"ginger": {"color": Color(0.84, 0.74, 0.34), "weight": 0.3, "milk": 0.0},
	"garlic": {"color": Color(0.88, 0.78, 0.52), "weight": 0.3, "milk": 0.2},
	"shiitake": {"color": Color(0.48, 0.32, 0.18), "weight": 0.5, "milk": 0.0},
}
const TARE := {
	"tare_shoyu": {"color": Color(0.50, 0.26, 0.10), "mix": 0.22},
	"tare_shio": {"color": Color(0.92, 0.88, 0.74), "mix": 0.12},
	"tare_miso": {"color": Color(0.74, 0.46, 0.20), "mix": 0.25},
	"tare_plum": {"color": Color(0.78, 0.38, 0.34), "mix": 0.15},
}
## amount: how many surface droplets show (0..1).
const OIL := {
	"oil_chili": {"color": Color(0.85, 0.14, 0.05), "amount": 0.85, "haze": 0.30},
	"oil_scallion": {"color": Color(0.45, 0.72, 0.22), "amount": 0.60, "haze": 0.08},
	"oil_garlic": {"color": Color(0.95, 0.78, 0.30), "amount": 0.60, "haze": 0.08},
	"oil_shrimp": {"color": Color(0.95, 0.50, 0.22), "amount": 0.60, "haze": 0.08},
	"oil_pepper": {"color": Color(0.50, 0.66, 0.26), "amount": 0.50, "haze": 0.08},
	"oil_roasted_sesame": {"color": Color(0.62, 0.40, 0.16), "amount": 0.55, "haze": 0.08},
}
const NOODLE_WHEAT := Color(0.93, 0.78, 0.40)


## Result keys:
## - error: "" when valid; otherwise the raw recipe is unusable and every other
##   value is inert. Callers must surface it, not substitute a look.
## - crafted: a RAW BROTH recipe exists; gates broth_color, strength, oil and tare.
##   Soup of a historical broth keeps its legacy shift in the view instead.
## - noodle_crafted: a raw noodle recipe exists (independent of crafted).
static func profile(config: Dictionary) -> Dictionary:
	var out := {"error": "", "crafted": false, "noodle_crafted": false, "broth_color": Color(0.55, 0.33, 0.12), "broth_strength": 0.0, "milk": 0.0,
		"oil_color": Color.WHITE, "oil_amount": 0.0, "noodle_color": NOODLE_WHEAT, "noodle_strength": 0.0, "cut": ""}
	var has_broth: bool = config.has("broth_recipe")
	var has_noodle: bool = config.has("noodle_recipe")
	if not has_broth and not has_noodle:
		return out
	# Reuse the domain's own validation (rank 3 = every method; sources unchecked
	# because an applied config was already accepted when it was bought/researched).
	if has_broth:
		var broth_error: String = Catalog.Broth.error(config["broth_recipe"])
		if broth_error != "":
			out["error"] = broth_error
			return out
	if has_noodle:
		var noodle_error: String = Catalog.Noodle.error(config["noodle_recipe"])
		if noodle_error != "":
			out["error"] = noodle_error
			return out
	if has_broth:
		_express_broth(config, out)
	if has_noodle:
		_express_noodle(config["noodle_recipe"], out)
	return out


static func _express_broth(config: Dictionary, out: Dictionary) -> void:
	var raw: Dictionary = config["broth_recipe"]
	var ids: Array = raw["ingredients"]
	var method: String = str(raw["method"])
	# Weighted blend: repeated portions pull the soup toward their ingredient.
	var sum := Color(0, 0, 0, 0)
	var total := 0.0
	var milk := 0.0
	for id in ids:
		var row: Dictionary = BROTH[str(id)]
		var w: float = row["weight"]
		sum += (row["color"] as Color) * w
		milk += float(row["milk"]) * w
		total += w
	var color := Color(sum.r / total, sum.g / total, sum.b / total)
	milk /= total
	# Method shifts emulsion: gentle simmer stays clearer, hard boil clouds and darkens.
	if method == "gentle":
		milk *= 0.6
		color = color.lerp(Color.WHITE, 0.05)
	elif method == "rolling":
		milk = minf(milk * 1.3, 1.0)
		color = color.darkened(0.05)
	var tare: Dictionary = TARE.get(str(config.get("tare", "")), {})
	if not tare.is_empty():
		color = color.lerp(tare["color"], tare["mix"])
	var oil: Dictionary = OIL.get(str(config.get("oil", "")), {})
	if not oil.is_empty():
		color = color.lerp(oil["color"], oil["haze"])
		out["oil_color"] = oil["color"]
		out["oil_amount"] = oil["amount"]
	out["crafted"] = true
	out["broth_color"] = color
	out["milk"] = milk
	out["broth_strength"] = clampf(0.70 + 0.04 * ids.size(), 0.0, 0.86)


static func _express_noodle(n: Dictionary, out: Dictionary) -> void:
	var noodle := NOODLE_WHEAT
	if n["flour"] == "strong": noodle = Color(0.95, 0.74, 0.30)
	elif n["flour"] == "buckwheat": noodle = Color(0.62, 0.55, 0.42)
	if n["water"] == "alkaline": noodle = noodle.lerp(Color(0.97, 0.82, 0.22), 0.3)
	if n["method"] == "moist": noodle = noodle.lerp(Color.WHITE, 0.12)
	elif n["method"] == "rested": noodle = noodle.lerp(Color(0.80, 0.60, 0.30), 0.15)
	out["noodle_crafted"] = true
	out["noodle_color"] = noodle
	out["noodle_strength"] = 0.55
	# Cut shape lives in the original cut-specific bowl texture; passed through only.
	out["cut"] = str(n["cut"])
