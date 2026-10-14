extends Control
## 매장 장면. 정적 바탕(ShopPainter.base)과 가구 조각(ShopPainter.items) 위에 ServiceSession의 논리 상태로 사람/그릇/김/말풍선을 그린다.
##
## 픽셀 규칙: 장면은 논리 픽셀(세로 176x264, 가로 320x152) 하나의 좌표계이고 화면에는 정수 배율 S 로만 확대한다
## (세로 390x844 → 배율 2 = 352x528, 가로 1280x800 → 배율 4 = 1280x608). 모든 텍스처는 최근접 필터이며 위치는 논리 픽셀로 내림해서 그린다.
## 가구와 사람은 하나의 목록에 담겨 깊이(gx+gy)로 정렬된다: 투영/깊이의 근거는 shop_layout.gd, 항목 만들기는 shop_scene.gd 에 있다.
## 이 클래스에는 주문/돈 규칙이 없다. 장면 캔버스에는 어떤 글자도 그리지 않는다(문양/김/도트만).

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


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(true)


## 영업 전(닫힌 가게)에 보여 줄 실제 고용 목록. 영업 중에는 이 값이 아니라 세션의 직원 스냅샷을 쓴다(영업 중 바뀌지 않는다).
var idle_staff: Array = []


func set_idle_staff(ids: Array) -> void:
	if str(ids) != str(idle_staff):
		idle_staff = ids.duplicate()
		queue_redraw()


## 지금 그릴 보조 직원: 영업 중 = 세션 시작 때 복사한 스냅샷, 아니면 실제 고용 목록.
func visible_staff() -> Array:
	if session != null:
		var snap: Array = session.staffing.get("hired", [])
		return snap
	return idle_staff


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
	return Scene.compose_for(_layout, session, _anim, idle_staff)


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
	var scene: Dictionary = Scene.build(_layout, ent, bowl_config, _anim, _vis, _img_cache, visible_staff())
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


## 장면 안에는 글자를 그리지 않는다(저해상도 도트 위 글씨는 읽기 어렵다). 간판의 붉은 그릇 문양은 ShopPainter 가 바탕에 찍었고,
## 여기서는 그 위로 오르는 움직이는 김과 영업 여부를 보여 주는 작은 도트 등(영업 중 = 붉은 등+노란 불, 아니면 회색 등)만 얹는다.
## 정확한 글(영업 상태/대기 인원)은 일반 UI 라벨(상태 띠)이 담당한다.
func _draw_signs() -> void:
	var sign_spec: Dictionary = _layout["sign"]
	var left: Vector2 = sign_spec["left"]
	# 간판 판자는 격자 x 1.0~7.0(8px당 4px 기울어짐)이고 그릇은 가운데(격자 x 4.0) = left + (24, 12).
	var bowl_top: Vector2 = left + Vector2(24.0, 12.0) + Vector2(0.0, -7.0)
	for k in 3:
		var phase: float = fposmod(_anim * 0.55 + float(k) / 3.0, 1.0)
		var wx: float = bowl_top.x - 3.0 + float(k) * 3.0 + sin(phase * 6.28 + float(k) * 1.7) * 0.8
		var wy: float = bowl_top.y - phase * 7.0
		var tl: Vector2 = _origin + Vector2(floor(wx), floor(wy)) * float(_scale)
		draw_rect(Rect2(tl, Vector2(1.0, 2.0) * float(_scale)), Color(1.0, 1.0, 1.0, 0.8 * (1.0 - phase)))
	var is_open: bool = session != null and session.is_running()
	var lamp: Vector2 = _layout["open_sign"]["left"]
	_blit(_tex_for("open_lamp|" + ("1" if is_open else "0"), Art.open_lamp_image(is_open)), lamp - Vector2(5.0, 4.0))


## 보이는 줄 칸보다 대기자가 많으면 마지막 칸 옆에 남은 인원을 작은 점(최대 6개)으로 보여 준다. 숫자는 상태 띠의 "줄 N"에 있다.
func _draw_overflow(ent: Dictionary, slots: Array) -> void:
	var queued: int = 0
	for p in ent["patrons"]:
		var d: Dictionary = p
		if int(d["state"]) == P_QUEUED:
			queued += 1
	if queued <= slots.size():
		return
	var extra: int = mini(queued - slots.size(), 6)
	var last: Vector2 = slots[slots.size() - 1]
	for i in extra:
		var tl: Vector2 = _origin + (last + Vector2(8.0 + float(i) * 3.0, -20.0)).floor() * float(_scale)
		draw_rect(Rect2(tl - Vector2(float(_scale), float(_scale)), Vector2(3.0, 3.0) * float(_scale)), INK)
		draw_rect(Rect2(tl, Vector2(1.0, 1.0) * float(_scale)), Color(1, 1, 1))
