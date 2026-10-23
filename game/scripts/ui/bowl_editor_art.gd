extends RefCounted
## 원본을 수정하지 않고 측정한 투명 여백만 AtlasTexture로 제외한다.
## 음식과 아이콘은 실제 원본 자산이며, 플레이 중 임의 도형으로 대체하지 않는다.
const ROOT: String = "res://assets/ui/bowl-editor/"
const Bounds = preload("res://scripts/ui/bowl_editor_bounds.gd")
static var _textures: Dictionary = {}
static var _icons: Dictionary = {}
static var _bounds: Dictionary = {}


static func food(id: String) -> Texture2D:
	if _textures.has(id):
		return _textures[id]
	if _bounds.is_empty():
		_bounds = Bounds.DATA
	if not _bounds.has(id):
		push_error("음식 자산 누락: " + id)
		return null
	var data: Dictionary = _bounds[id]
	var texture: Texture2D = load(ROOT + str(data["file"])) as Texture2D
	if texture == null:
		push_error("음식 원본을 읽지 못했어요: " + id)
		return null
	var rect: Array = data["rect"]
	var atlas := AtlasTexture.new()
	atlas.atlas = texture
	atlas.region = Rect2(float(rect[0]), float(rect[1]), float(rect[2]), float(rect[3]))
	_textures[id] = atlas
	return atlas


static func icon(id: String) -> Texture2D:
	if not _icons.has(id):
		var path: String = "res://assets/ui/material-rounded/" + id + ".svg"
		# Importable real SVG resources survive PCK export; raw source reads do not.
		var texture: Texture2D = load(path) as Texture2D
		if texture == null:
			push_error("아이콘 로드 실패: " + id)
			return null
		_icons[id] = texture
	return _icons[id]
