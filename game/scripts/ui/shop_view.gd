extends Control
## 매장 장면. 정적 배경(ShopPainter가 한 번 찍은 작은 이미지) 위에 ServiceSession의 논리 상태로 사람/그릇/김/말풍선을 그린다.
##
## 픽셀 규칙: 장면은 논리 픽셀(세로 128x208, 가로 320x148) 하나의 좌표계이고 화면에는 정수 배율 S 로만 확대한다.
## 모든 텍스처는 최근접 필터이며 위치는 논리 픽셀로 내림해서 그린다(서브픽셀 번짐 없음).
## 사람의 위치는 세션이 준 상태(state, 진행률 p, 자리 번호, 줄 번호)에서만 계산한다: 이 클래스에는 주문/돈 규칙이 없다.

const Layouts = preload("res://scripts/ui/shop_layout.gd")
const Art = preload("res://scripts/ui/pixel_art.gd")
const Painter = preload("res://scripts/ui/shop_painter.gd")
const Session = preload("res://scripts/domain/service_session.gd")

# match 패턴에 쓰려고 세션 상수를 이 파일의 상수로 복사한다.
const P_APPROACH: int = Session.P_APPROACH
const P_QUEUED: int = Session.P_QUEUED
const P_TO_SEAT: int = Session.P_TO_SEAT
const P_ORDERING: int = Session.P_ORDERING
const P_WAITING: int = Session.P_WAITING
const P_EATING: int = Session.P_EATING
const P_LEAVING: int = Session.P_LEAVING
const P_BALK: int = Session.P_BALK

const OUTSIDE: Color = Color(0.11, 0.12, 0.16)
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
var _tex_cache: Dictionary = {}
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
		_bg = Art.tex(Painter.paint(_layout))
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


func _person_tex(look: int, pose: String, frame: int, back: bool) -> ImageTexture:
	var key: String = "%d|%s|%d|%d" % [look, pose, frame, 1 if back else 0]
	if not _tex_cache.has(key):
		_tex_cache[key] = Art.tex(Art.person_image(look, pose, frame, back))
	return _tex_cache[key] as ImageTexture


func _bubble_tex(kind: String) -> ImageTexture:
	var key: String = "bubble|" + kind
	if not _tex_cache.has(key):
		_tex_cache[key] = Art.tex(Art.bubble_image(kind))
	return _tex_cache[key] as ImageTexture


func _bowl_tex(config: Dictionary) -> ImageTexture:
	var key: String = "bowl|" + str(config)
	if not _tex_cache.has(key):
		_tex_cache[key] = Art.tex(Art.bowl_image(config))
	return _tex_cache[key] as ImageTexture


static func _by_y(a: Dictionary, b: Dictionary) -> bool:
	return float(a["y"]) < float(b["y"])


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), OUTSIDE)
	_ensure_layout()
	var world: Vector2i = _layout["size"]
	draw_texture_rect(_bg, Rect2(_origin, Vector2(world) * float(_scale)), false)
	_draw_signs()

	var bowl_config: Dictionary = {}
	if session != null:
		bowl_config = session.config
	var items: Array = []
	var bubbles: Array = []
	var chef_pos: Vector2 = _layout["chef_pos"]
	var pass_pos: Vector2 = _layout["pass_pos"]
	var seats: Array = _layout["seats"]
	var slots: Array = _layout["queue_slots"]
	var door_out: Vector2 = _layout["door_out"]
	var spawn: Vector2 = _layout["spawn"]
	var exit_pos: Vector2 = _layout["exit"]

	var ent: Dictionary = {}
	if session != null:
		ent = session.entities()

	# 요리사: 조리 중에는 팔을 저으며, 솥 위로 김이 짙어진다.
	var cooking: bool = bool(ent.get("chef_cooking", false))
	var chef_frame: int = int(_anim * (4.0 if cooking else 1.2)) % 2
	items.append({"y": chef_pos.y, "tex": _person_tex(Art.LOOK_CHEF, "cook" if cooking else "stand", chef_frame, false), "pos": chef_pos - Vector2(7.0, 18.0)})
	_draw_steam(cooking)

	# 서버: 대기 중에는 주방 앞, 서빙 중에는 자리까지 왕복
	var server_pos: Vector2 = pass_pos
	var server_pose: String = "stand"
	var carrying: bool = false
	var server_state: int = int(ent.get("server_state", Session.S_IDLE))
	if server_state != Session.S_IDLE:
		var seat_index: int = int(ent["server_seat"])
		var route: Array = (seats[seat_index] as Dictionary)["serve_path"]
		var sp: float = float(ent["server_p"])
		if server_state == Session.S_CARRY:
			server_pos = Layouts.along(route, sp)
			carrying = true
			server_pose = "carry"
		else:
			server_pos = Layouts.along(Layouts.reversed(route), sp)
			server_pose = "walk"
	var server_frame: int = int(_anim * 5.0) % 2 if server_pose != "stand" else int(_anim * 1.2) % 2
	items.append({"y": server_pos.y, "tex": _person_tex(Art.LOOK_SERVER, server_pose, server_frame, false), "pos": server_pos - Vector2(7.0, 18.0)})
	if carrying:
		items.append({"y": server_pos.y + 0.5, "tex": _bowl_tex(bowl_config), "pos": server_pos + Vector2(-6.0, -9.0)})
	# 주방 앞 작업대에 올라가 서빙을 기다리는 그릇
	var ready: int = int(ent.get("ready", 0))
	for i in mini(ready, 3):
		items.append({"y": pass_pos.y - 9.0, "tex": _bowl_tex(bowl_config), "pos": Vector2(pass_pos.x + 6.0 + 8.0 * float(i), pass_pos.y - 10.0)})

	if session != null:
		for p in ent["patrons"]:
			_add_patron(p, items, bubbles, seats, slots, door_out, spawn, exit_pos, bowl_config)

	items.sort_custom(_by_y)
	for it in items:
		var d: Dictionary = it
		var item_tex: Texture2D = d["tex"]
		var item_pos: Vector2 = d["pos"]
		_blit(item_tex, item_pos)
	for b in bubbles:
		var bd: Dictionary = b
		var bubble_pos: Vector2 = bd["pos"]
		_blit(_bubble_tex(str(bd["kind"])), bubble_pos)
	for pu in _popups:
		var pd: Dictionary = pu
		var rise: float = float(pd["t"]) * 10.0
		var pp: Vector2 = pd["pos"]
		_blit(_bubble_tex("coin"), Vector2(pp.x - 6.0, pp.y - 30.0 - rise), clampf(1.0 - float(pd["t"]), 0.0, 1.0))
	if session != null:
		_draw_overflow(ent, slots)


func _add_patron(p: Dictionary, items: Array, bubbles: Array, seats: Array, slots: Array, door_out: Vector2, spawn: Vector2, exit_pos: Vector2, bowl_config: Dictionary) -> void:
	var state: int = int(p["state"])
	var prog: float = float(p["p"])
	var id: int = int(p["id"])
	var look: int = int(p["look"])
	var slot: int = int(p["slot"])
	var pos: Vector2 = Vector2.ZERO
	var pose: String = "stand"
	var back: bool = false
	var frame: int = int(_anim * 1.5 + float(id)) % 2
	var seat: Dictionary = {}
	if int(p["seat"]) >= 0:
		seat = seats[int(p["seat"])]
	match state:
		P_APPROACH:
			pos = spawn.lerp(_slot_pos(slots, slot), prog)
			pose = "walk"
			frame = int(_anim * 6.0 + float(id)) % 2
		P_BALK:
			pos = _slot_pos(slots, slot).lerp(spawn, prog)
			pose = "walk"
			frame = int(_anim * 6.0 + float(id)) % 2
		P_QUEUED:
			var target: Vector2 = _slot_pos(slots, slot)
			pos = _vis.get(id, target)
			if pos.distance_to(target) > 0.5:
				pose = "walk"
				frame = int(_anim * 6.0 + float(id)) % 2
		P_TO_SEAT:
			var route: Array = [_slot_pos(slots, 0), door_out]
			route.append_array(seat["path"])
			pos = Layouts.along(route, prog)
			pose = "walk"
			frame = int(_anim * 6.0 + float(id)) % 2
		P_ORDERING, P_WAITING, P_EATING:
			pos = seat["pos"]
			pose = "sit"
			back = str(seat["kind"]) == "counter"
			frame = int(_anim * 3.0 + float(id)) % 2 if state == P_EATING else 0
			if state == P_EATING and prog < 0.85:
				var bp: Vector2 = seat["bowl"]
				items.append({"y": bp.y + 7.0, "tex": _bowl_tex(bowl_config), "pos": bp})
		P_LEAVING:
			var out_route: Array = Layouts.reversed(seat["path"])
			out_route.append(door_out)
			out_route.append(Vector2(door_out.x, exit_pos.y))
			out_route.append(exit_pos)
			pos = Layouts.along(out_route, prog)
			pose = "walk"
			frame = int(_anim * 6.0 + float(id)) % 2
	items.append({"y": pos.y, "tex": _person_tex(look, pose, frame, back), "pos": pos - Vector2(7.0, 18.0)})
	var bubble: String = str(p["bubble"])
	if bubble != "":
		bubbles.append({"kind": bubble, "pos": pos - Vector2(6.0, 29.0)})


func _draw_steam(strong: bool) -> void:
	var kitchen: Rect2i = _layout["kitchen"]
	var sx: int = int(_layout["stove_x"])
	for pot in 2:
		var px0: float = float(sx + 9 + pot * 17)
		for k in 3:
			var phase: float = fposmod(_anim * (0.9 if strong else 0.5) + float(k) / 3.0 + float(pot) * 0.37, 1.0)
			var y: float = float(kitchen.position.y + 3) - phase * (11.0 if strong else 7.0)
			var x: float = px0 + sin(phase * 6.0 + float(k)) * 1.6 + float(k - 1) * 2.0
			var a: float = (0.85 if strong else 0.45) * (1.0 - phase)
			var tl: Vector2 = _origin + Vector2(floor(x), floor(y)) * float(_scale)
			draw_rect(Rect2(tl, Vector2(2.0, 1.0) * float(_scale)), Color(1.0, 1.0, 1.0, a))


func _draw_signs() -> void:
	if _font == null:
		return
	var sign_r: Rect2i = _layout["sign"]
	var fs: int = int(float(_scale) * 7.0)
	var base: Vector2 = _origin + Vector2(float(sign_r.position.x), float(sign_r.position.y) + float(sign_r.size.y) * 0.5) * float(_scale)
	draw_string(_font, base + Vector2(0.0, float(fs) * 0.36), "라멘 골목", HORIZONTAL_ALIGNMENT_CENTER, float(sign_r.size.x * _scale), fs, INK)
	var open_r: Rect2i = _layout["open_sign"]
	var is_open: bool = session != null and session.is_running()
	var fs2: int = maxi(8, int(float(_scale) * 4.2))
	var base2: Vector2 = _origin + Vector2(float(open_r.position.x), float(open_r.position.y) + float(open_r.size.y) * 0.45) * float(_scale)
	draw_string(_font, base2 + Vector2(0.0, float(fs2) * 0.36), "영업중" if is_open else "준비중", HORIZONTAL_ALIGNMENT_CENTER, float(open_r.size.x * _scale), fs2, RED if is_open else INK)


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
	var tl: Vector2 = _origin + (last + Vector2(-26.0, -4.0)) * float(_scale)
	draw_string(_font, tl, "+%d" % (queued - slots.size()), HORIZONTAL_ALIGNMENT_LEFT, -1.0, int(float(_scale) * 5.0), Color(1, 1, 1))
