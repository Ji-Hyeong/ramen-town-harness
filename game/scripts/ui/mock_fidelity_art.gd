extends RefCounted
## Generated originals remain byte-identical. Atlas coordinates are transformed
## by the actual imported size, so high-resolution9slice art keeps native margins.
const ROOT: String = "res://assets/ui/mock-fidelity/"
const DATA: Dictionary = {
	"gold": ["gold-cta-v1.png", Vector2(1933,814), Rect2(41,165,1850,454)],
	"panel": ["navy-panel-v1.png", Vector2(1328,1184), Rect2(30,46,1269,1092)],
	"summary": ["summary-card-v1.png", Vector2(2079,756), Rect2(44,78,1992,588)],
	"portions": ["portion-panel-v1.png", Vector2(1806,871), Rect2(43,64,1722,742)],
	"blue": ["blue-button-v1.png", Vector2(1712,919), Rect2(66,180,1580,559)],
	"teal": ["teal-button-v1.png", Vector2(1227,1281), Rect2(209,244,809,795)],
	"pointer": ["pointer-v1.png", Vector2(1041,1510), Rect2(247,195,564,1127)],
	"pot": ["summary-icons-v1.png", Vector2(1774,887), Rect2(71,156,746,609)],
	"noodles": ["summary-icons-v1.png", Vector2(1774,887), Rect2(979,212,732,569)],
	"coin": ["gold-coin-v1.png", Vector2(1254,1254), Rect2(66,104,1122,1061)],
}
static var _textures: Dictionary = {}


static func texture(id: String) -> AtlasTexture:
	if _textures.has(id):
		return _textures[id]
	if not DATA.has(id):
		push_error("시안 자산이 없어요: " + id)
		return null
	var data: Array = DATA[id]
	var source: Texture2D = load(ROOT + str(data[0])) as Texture2D
	var scale: Vector2 = source.get_size() / (data[1] as Vector2)
	var rect: Rect2 = data[2]
	var origin: Vector2 = (rect.position * scale).floor()
	var end: Vector2 = (rect.end * scale).ceil()
	var result := AtlasTexture.new()
	result.atlas = source
	result.region = Rect2(origin, end - origin)
	_textures[id] = result
	return result


static func style(id: String, padding: Vector2 = Vector2(10,8)) -> StyleBoxTexture:
	var result := StyleBoxTexture.new()
	result.texture = texture(id)
	var edge: float = 10.0 if id in ["summary", "teal"] else 14.0
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		result.set_texture_margin(side, edge)
	result.content_margin_left = padding.x
	result.content_margin_right = padding.x
	result.content_margin_top = padding.y
	result.content_margin_bottom = padding.y
	return result


static func bowl(noodle: String) -> AtlasTexture:
	var key: String = "bowl_" + noodle
	if _textures.has(key):
		return _textures[key]
	var regions: Array[Rect2] = [Rect2(42,146,676,408), Rect2(748,146,677,408), Rect2(1453,146,678,408)]
	var result := AtlasTexture.new()
	result.atlas = load(ROOT + "bowl-bases-v2.png") as Texture2D
	var index: int = 0 if noodle == "noodle_thin" else (1 if noodle == "noodle_medium" else 2)
	result.region = regions[index]
	_textures[key] = result
	return result
