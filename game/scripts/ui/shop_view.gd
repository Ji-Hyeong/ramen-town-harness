extends Control
## 매장 장면. 정적 바탕(ShopPainter.base)과 가구 조각(ShopPainter.items) 위에 ServiceSession의 논리 상태로 사람/그릇/김/말풍선을 그린다.
##
## 픽셀 규칙: 장면은 논리 픽셀(세로 176x264, 가로 320x152) 하나의 좌표계이고 화면에는 정수 배율 S 로만 확대한다
## (세로 390x844 → 배율 2 = 352x528, 가로 1280x800 → 배율 4 = 1280x608). 모든 텍스처는 최근접 필터이며 위치는 논리 픽셀로 내림해서 그린다.
## 가구와 사람은 하나의 목록에 담겨 깊이(gx+gy)로 정렬된다: 투영/깊이의 근거는 shop_layout.gd, 항목 만들기는 shop_scene.gd 에 있다.
## 이 클래스에는 주문/돈 규칙이 없다.

const Layouts = preload("res://scripts/ui/shop_layout.gd")
const Art = preload("res://scripts/ui/pixel_art.gd")
const Painter = preload("res://scripts/ui/shop_painter.gd")
const Scene = preload("res://scripts/ui/shop_scene.gd")
const Session = preload("res://scripts/domain/service_session.gd")

const P_QUEUED: int = Session.P_QUEUED

const OUTSIDE: Color = Color(0.11, 0.12, 0.16)
## 장면 위/아래 남는 띠: 이웃 건물 지붕색과 차도색으로 바깥 세상이 이어지게 채운다(옆은 가장자리 열을 늘린다).
const FILL_TOP: Color = Color(0.26, 0.29, 0.36)
const FILL_BOTTOM: Color = Color(0.37, 0.37, 0.41)
const INK: Color = Color(0.149, 0.102, 0.071)
const RED: Color = Color(0.76, 0.23, 0.13)

## 영업 중이면 세션, 닫혀 있으면 null(요리사/서버만 대기 자세).
var session: Session = null
## 화면 위/아래에 다른 UI(HUD, 하단 바)가 덮는 높이. 장면은 남은 영역 안에서 정수 배율로 맞춘다.
var inset_top: float = 56.0
var inset_bottom: float = 120.0

var _layout: Dictionary = {}
var _variant: String = ""
var _bg: ImageTexture = null
var _furniture: Array = []
var _tex_cache: Dictionary = {}
var _img_cache: Dictionary = {}
var _anim: float = 0.0
var _scale: int = 1
var _origin: Vector2 = Vector2.ZERO
var _vis: Dictionary = {}
var _popups: Array = []
var _seen_completed: int = 0
var _font: Font = null


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = load("res://assets/fonts/GowunDodum-Regular.ttf") as Font
	set_process(true)


func set_session(s: Session) -> void:
	session = s
	_vis.clear()
	_popups.clear()
	_seen_completed = 0
	if s != null:
		_seen_completed = s.completed.size()
	queue_redraw()


## 현재 배치와 배율(테스트/QA에서 장면이 영역 안에 들어오는지 확인할 때 쓴다).
func scene_info() -> Dictionary:
	_ensure_layout()
	var world: Vector2i = _layout["size"]
	return {
		"variant": _variant,
		"scale": _scale,
		"origin": _origin,
		"rect": Rect2(_origin, Vector2(world) * float(_scale)),
	}


## 검사용: 지금 상태의 장면을 CPU 이미지(논리 픽셀)로 합성한다. 그리기와 같은 항목 목록을 쓴다. 글씨/김은 없고 전체 UI 도 아니다.
func compose_image() -> Image:
	_ensure_layout()
	return Scene.compose_for(_layout, session, _anim)


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_anim += delta
	_update_popups(delta)
	_update_queue_smoothing(delta)
	queue_redraw()


func _ensure_layout() -> void:
	var variant: String = Layouts.variant_for(size.x, size.y)
	if variant != _variant or _bg == null:
		_variant = variant
		_layout = Layouts.make(variant)
		_bg = Art.tex(Painter.base(_layout))
		_furniture = Painter.items(_layout)
		_tex_cache.clear()
		_vis.clear()
	var world: Vector2i = _layout["size"]
	var avail_h: float = maxf(1.0, size.y - inset_top - inset_bottom)
	_scale = maxi(1, int(floor(minf(size.x / float(world.x), avail_h / float(world.y)))))
	var ox: float = floor((size.x - float(world.x * _scale)) * 0.5)
	var oy: float = floor(inset_top + (avail_h - float(world.y * _scale)) * 0.5)
	_origin = Vector2(ox, maxf(0.0, oy))


func _update_popups(delta: float) -> void:
	if session != null and session.completed.size() > _seen_completed and not _layout.is_empty():
		var seats: Array = _layout["seats"]
		for i in range(_seen_completed, session.completed.size()):
			var d: Dictionary = session.completed[i]
			var seat: Dictionary = seats[int(d["seat"])]
			_popups.append({"pos": seat["pos"], "t": 0.0})
		_seen_completed = session.completed.size()
	for p in _popups:
		var pd: Dictionary = p
		pd["t"] = float(pd["t"]) + delta
	_popups = _popups.filter(func(e: Dictionary) -> bool: return float(e["t"]) < 1.0)


## 줄에 선 손님은 목표 칸으로 천천히 미끄러져 간다(앞사람이 들어갈 때 한 칸씩 당겨지는 연출). 논리 칸 자체는 세션이 정한다.
func _update_queue_smoothing(delta: float) -> void:
	if session == null or _layout.is_empty():
		return
	var slots: Array = _layout["queue_slots"]
	var ent: Dictionary = session.entities()
	for p in ent["patrons"]:
		var d: Dictionary = p
		if int(d["state"]) != P_QUEUED:
			_vis.erase(int(d["id"]))
			continue
		var target: Vector2 = _slot_pos(slots, int(d["slot"]))
		var id: int = int(d["id"])
		var cur: Vector2 = _vis.get(id, target)
		_vis[id] = cur.move_toward(target, 70.0 * delta)


func _slot_pos(slots: Array, slot: int) -> Vector2:
	var idx: int = clampi(slot, 0, slots.size() - 1)
	return slots[idx]


# ---------- 그리기 ----------

func _blit(texture: Texture2D, logical_top_left: Vector2, alpha: float = 1.0) -> void:
	var tl: Vector2 = _origin + logical_top_left.floor() * float(_scale)
	draw_texture_rect(texture, Rect2(tl, texture.get_size() * float(_scale)), false, Color(1, 1, 1, alpha))


func _tex_for(key: String, img: Image) -> ImageTexture:
	if not _tex_cache.has(key):
		_tex_cache[key] = Art.tex(img)
	return _tex_cache[key] as ImageTexture


## 장면 밖 남는 화면: 위는 이웃 지붕색, 아래는 차도색, 옆은 장면 가장자리 열을 늘려 세계가 이어지게 한다.
func _draw_surround(world_rect: Rect2, world: Vector2i) -> void:
	draw_rect(Rect2(0.0, 0.0, size.x, world_rect.position.y), FILL_TOP)
	draw_rect(Rect2(0.0, world_rect.end.y, size.x, maxf(0.0, size.y - world_rect.end.y)), FILL_BOTTOM)
	if world_rect.position.x > 0.0:
		draw_texture_rect_region(_bg, Rect2(0.0, world_rect.position.y, world_rect.position.x, world_rect.size.y), Rect2(0.0, 0.0, 1.0, float(world.y)))
	if world_rect.end.x < size.x:
		draw_texture_rect_region(_bg, Rect2(world_rect.end.x, world_rect.position.y, size.x - world_rect.end.x, world_rect.size.y), Rect2(float(world.x - 1), 0.0, 1.0, float(world.y)))


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), OUTSIDE)
	_ensure_layout()
	var world: Vector2i = _layout["size"]
	var world_rect: Rect2 = Rect2(_origin, Vector2(world) * float(_scale))
	_draw_surround(world_rect, world)
	draw_texture_rect(_bg, world_rect, false)

	var bowl_config: Dictionary = {}
	var ent: Dictionary = {}
	if session != null:
		bowl_config = session.config
		ent = session.entities()
	var scene: Dictionary = Scene.build(_layout, ent, bowl_config, _anim, _vis, _img_cache)
	var all: Array = _furniture.duplicate()
	all.append_array(scene["items"])
	for it in Painter.sort_items(all):
		var d: Dictionary = it
		var item_pos: Vector2 = d["pos"]
		var key: String = str(d["key"]) if d.has("key") else "f|" + str(d["id"]) + "|" + str(item_pos)
		_blit(_tex_for(key, d["img"]), item_pos)
	_draw_steam(ent)
	_draw_signs()
	for b in scene["bubbles"]:
		var bd: Dictionary = b
		var bubble_pos: Vector2 = bd["pos"]
		var kind: String = str(bd["kind"])
		_blit(_tex_for("bubble|" + kind, Scene.bubble_img(_img_cache, kind)), bubble_pos)
	for pu in _popups:
		var pd: Dictionary = pu
		var rise: float = float(pd["t"]) * 10.0
		var pp: Vector2 = pd["pos"]
		_blit(_tex_for("bubble|coin", Scene.bubble_img(_img_cache, "coin")), Vector2(pp.x - 6.0, pp.y - 30.0 - rise), clampf(1.0 - float(pd["t"]), 0.0, 1.0))
	if session != null:
		_draw_overflow(ent, _layout["queue_slots"])


## 솥/면 삶는 통 위 김. 위치는 레이아웃의 pots(격자 투영 점)이고 조리 중이면 짙고 높다.
func _draw_steam(ent: Dictionary) -> void:
	var strong: bool = bool(ent.get("chef_cooking", false))
	var pots: Array = _layout["pots"]
	for pot in pots.size():
		var base: Vector2 = pots[pot]
		for k in 3:
			var phase: float = fposmod(_anim * (0.9 if strong else 0.5) + float(k) / 3.0 + float(pot) * 0.37, 1.0)
			var y: float = base.y - 2.0 - phase * (12.0 if strong else 8.0)
			var x: float = base.x + sin(phase * 6.0 + float(k)) * 1.6 + float(k - 1) * 2.0
			var a: float = (0.85 if strong else 0.45) * (1.0 - phase)
			var tl: Vector2 = _origin + Vector2(floor(x), floor(y)) * float(_scale)
			draw_rect(Rect2(tl, Vector2(2.0, 1.0) * float(_scale)), Color(1.0, 1.0, 1.0, a))


## 벽 면의 글씨: 면을 따라 8px 가면 4px 내려가므로 같은 기울기(y = 0.5x)로 비스듬히 쓴다.
func _draw_wall_text(text: String, spec: Dictionary, fs: int, col: Color) -> void:
	var left: Vector2 = spec["left"]
	var width: float = float(spec["width"])
	var anchor: Vector2 = _origin + left * float(_scale)
	draw_set_transform_matrix(Transform2D(Vector2(1.0, 0.5), Vector2(0.0, 1.0), anchor))
	draw_string(_font, Vector2(0.0, float(fs) * 0.36), text, HORIZONTAL_ALIGNMENT_CENTER, width * float(_scale), fs, col)
	draw_set_transform_matrix(Transform2D.IDENTITY)


func _draw_signs() -> void:
	if _font == null:
		return
	_draw_wall_text("라멘 골목", _layout["sign"], int(float(_scale) * 6.0), INK)
	var is_open: bool = session != null and session.is_running()
	_draw_wall_text("영업중" if is_open else "준비중", _layout["open_sign"], maxi(8, int(float(_scale) * 3.6)), RED if is_open else INK)


## 보이는 줄 칸보다 대기자가 많으면 마지막 칸 옆에 남은 인원을 적는다.
func _draw_overflow(ent: Dictionary, slots: Array) -> void:
	if _font == null:
		return
	var queued: int = 0
	for p in ent["patrons"]:
		var d: Dictionary = p
		if int(d["state"]) == P_QUEUED:
			queued += 1
	if queued <= slots.size():
		return
	var last: Vector2 = slots[slots.size() - 1]
	var tl: Vector2 = _origin + (last + Vector2(8.0, -20.0)) * float(_scale)
	draw_string(_font, tl, "+%d" % (queued - slots.size()), HORIZONTAL_ALIGNMENT_LEFT, -1.0, int(float(_scale) * 5.0), Color(1, 1, 1))
