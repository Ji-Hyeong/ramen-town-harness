extends RefCounted
## 사람/그릇/말풍선 항목을 만드는 곳. ShopView(그리기)와 compose_for(검사용 CPU 합성)가 같은 build() 를 쓴다.
## 위치는 ShopLayout 의 화면 경로(격자를 투영한 것)와 ServiceSession 이 준 상태/진행률에서만 나온다. 주문/돈 규칙은 없다.
##
## 깊이: 바닥에 선 항목은 발 위치 p 의 gx+gy = (p.y - origin.y)/4 를 깊이로 쓴다(ShopLayout.depth_of_screen).
## 가구 항목(ShopPainter.items)도 같은 눈금이라 사람과 한 목록으로 정렬된다.

const Layouts = preload("res://scripts/ui/shop_layout.gd")
const Art = preload("res://scripts/ui/pixel_art.gd")
const Painter = preload("res://scripts/ui/shop_painter.gd")
const Session = preload("res://scripts/domain/service_session.gd")

const P_APPROACH: int = Session.P_APPROACH
const P_QUEUED: int = Session.P_QUEUED
const P_TO_SEAT: int = Session.P_TO_SEAT
const P_ORDERING: int = Session.P_ORDERING
const P_WAITING: int = Session.P_WAITING
const P_EATING: int = Session.P_EATING
const P_LEAVING: int = Session.P_LEAVING
const P_BALK: int = Session.P_BALK


static func _person_img(cache: Dictionary, look: int, pose: String, frame: int, back: bool) -> Image:
	var key: String = "p|%d|%s|%d|%d" % [look, pose, frame, 1 if back else 0]
	if not cache.has(key):
		cache[key] = Art.person_image(look, pose, frame, back)
	return cache[key] as Image


static func _bowl_img(cache: Dictionary, config: Dictionary) -> Image:
	var key: String = "bowl|" + str(config)
	if not cache.has(key):
		cache[key] = Art.bowl_image(config)
	return cache[key] as Image


static func bubble_img(cache: Dictionary, kind: String) -> Image:
	var key: String = "bubble|" + kind
	if not cache.has(key):
		cache[key] = Art.bubble_image(kind)
	return cache[key] as Image


static func _item(layout: Dictionary, key: String, img: Image, top_left: Vector2, depth: float, n: int) -> Dictionary:
	# 그릇은 메뉴(재료)마다 그림이 다르므로 키에 구성을 넣어 ShopView 텍스처 캐시가 낡지 않게 한다.
	var k: String = key
	if key == "bowl":
		k = "bowl|" + str(img.get_data().hex_encode().hash())
	return {"depth": depth, "pos": top_left, "img": img, "key": k, "n": n}


## ent: ServiceSession.entities()(없으면 빈 Dictionary), vis: 줄 선 손님의 부드러운 화면 위치(ShopView 가 관리), cache: 이미지 캐시.
## 반환: {"items": 정렬 전 사람/그릇 항목, "bubbles": [{kind,pos}]}. 가구는 호출한 쪽이 섞어서 Painter.sort_items 로 정렬한다.
## staff: 그릴 보조 직원 id 목록(영업 중에는 세션의 불변 직원 스냅샷, 영업 전에는 실제 고용 목록). 비어 있으면 요리사/서버만 그린다.
static func build(layout: Dictionary, ent: Dictionary, bowl_config: Dictionary, anim: float, vis: Dictionary, cache: Dictionary, staff: Array = []) -> Dictionary:
	var items: Array = []
	var bubbles: Array = []
	var n: int = 100000
	var chef_pos: Vector2 = layout["chef_pos"]
	var pass_pos: Vector2 = layout["pass_pos"]
	var seats: Array = layout["seats"]
	var slots: Array = layout["queue_slots"]
	var door_out: Vector2 = layout["door_out"]
	var spawn: Vector2 = layout["spawn"]
	var exit_pos: Vector2 = layout["exit"]
	var foot: Vector2 = Vector2(7.0, 18.0)

	# 요리사: 화로를 향해 등을 보이고 선다. 조리 중에는 팔을 젓는다.
	var cooking: bool = bool(ent.get("chef_cooking", false))
	var chef_frame: int = int(anim * (4.0 if cooking else 1.2)) % 2
	var chef_pose: String = "cook" if cooking else "stand"
	items.append(_item(layout, "chef|%s|%d" % [chef_pose, chef_frame], _person_img(cache, Art.LOOK_CHEF, chef_pose, chef_frame, true), chef_pos - foot, Layouts.depth_of_screen(layout, chef_pos), n))
	n += 1

	# 서버: 대기 중에는 주방 안 서빙 자리, 서빙 중에는 자리까지 왕복
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
	var server_frame: int = int(anim * 5.0) % 2 if server_pose != "stand" else int(anim * 1.2) % 2
	var sdepth: float = Layouts.depth_of_screen(layout, server_pos)
	items.append(_item(layout, "server|%s|%d" % [server_pose, server_frame], _person_img(cache, Art.LOOK_SERVER, server_pose, server_frame, false), server_pos - foot, sdepth, n))
	n += 1
	if carrying:
		items.append(_item(layout, "bowl", _bowl_img(cache, ent.get("server_config", bowl_config)), server_pos + Vector2(-6.0, -9.0), sdepth + 0.05, n))
		n += 1
	# 보조 직원: 고용했을 때만. 위치는 ShopLayout.staff_spots(안전 자리), 깊이는 발 위치(다른 사람과 같은 눈금)다.
	# 모션은 지원 역할만 보여 준다: 조리 보조는 요리사가 조리 중일 때 같이 손을 움직이고, 홀 보조는 서버가 서빙 중일 때 쟁반을 들고 거든다.
	# 주문 순서/조리/서빙 일정은 요리사·서버 그대로이며 여기서는 아무것도 계산하지 않는다.
	var spots: Dictionary = layout.get("staff_spots", {})
	for sid in staff:
		var staff_id: String = str(sid)
		if not spots.has(staff_id):
			continue
		var spot: Dictionary = spots[staff_id]
		var spos: Vector2 = spot["pos"]
		var is_prep: bool = staff_id == "prep_assistant"
		var look_idx: int = Art.LOOK_PREP_ASSISTANT if is_prep else Art.LOOK_FLOOR_ASSISTANT
		var spose: String = "stand"
		var sframe: int = int(anim * 1.2) % 2
		if is_prep and cooking:
			spose = "cook"
			sframe = int(anim * 3.5) % 2
		elif not is_prep and int(ent.get("server_state", Session.S_IDLE)) != Session.S_IDLE:
			spose = "carry"
			sframe = int(anim * 2.0) % 2
		var sback: bool = bool(spot["back"])
		items.append(_item(layout, "staff|%s|%s|%d" % [staff_id, spose, sframe], _person_img(cache, look_idx, spose, sframe, sback), spos - foot, Layouts.depth_of_screen(layout, spos), n))
		n += 1
	# 주방 작업대 위에서 서빙을 기다리는 그릇(최대 3개)
	var ready: int = int(ent.get("ready", 0))
	var ready_pos: Array = layout["ready_bowls"]
	for i in mini(ready, ready_pos.size()):
		var configs: Array = ent.get("ready_configs", [])
		var cfg: Dictionary = configs[i] if i < configs.size() else bowl_config
		items.append(_item(layout, "bowl", _bowl_img(cache, cfg), ready_pos[i], float(layout["ready_depth"]), n))
		n += 1

	if ent.has("patrons"):
		for p in ent["patrons"]:
			n = _add_patron(layout, p, items, bubbles, p.get("config", bowl_config), anim, vis, cache, n)
	return {"items": items, "bubbles": bubbles,"server_pos":server_pos,"carrying":carrying}


static func _add_patron(layout: Dictionary, p: Dictionary, items: Array, bubbles: Array, bowl_config: Dictionary, anim: float, vis: Dictionary, cache: Dictionary, n_in: int) -> int:
	var n: int = n_in
	var seats: Array = layout["seats"]
	var slots: Array = layout["queue_slots"]
	var door_out: Vector2 = layout["door_out"]
	var spawn: Vector2 = layout["spawn"]
	var state: int = int(p["state"])
	var prog: float = float(p["p"])
	var id: int = int(p["id"])
	var look: int = int(p["look"])
	var slot: int = clampi(int(p["slot"]), 0, slots.size() - 1)
	var pos: Vector2 = Vector2.ZERO
	var pose: String = "stand"
	var back: bool = false
	var frame: int = int(anim * 1.5 + float(id)) % 2
	var seat: Dictionary = {}
	if int(p["seat"]) >= 0:
		seat = seats[int(p["seat"])]
	var walk_frame: int = int(anim * 6.0 + float(id)) % 2
	match state:
		P_APPROACH:
			pos = spawn.lerp(slots[slot], prog)
			pose = "walk"
			frame = walk_frame
		P_BALK:
			pos = (slots[slot] as Vector2).lerp(spawn, prog)
			pose = "walk"
			frame = walk_frame
		P_QUEUED:
			var target: Vector2 = slots[slot]
			pos = vis.get(id, target)
			if pos.distance_to(target) > 0.5:
				pose = "walk"
				frame = walk_frame
		P_TO_SEAT:
			var route: Array = [slots[0], door_out]
			route.append_array(seat["path"])
			pos = Layouts.along(route, prog)
			pose = "walk"
			frame = walk_frame
		P_ORDERING, P_WAITING, P_EATING:
			pos = seat["pos"]
			pose = "sit"
			back = bool(seat["back"])
			frame = int(anim * 3.0 + float(id)) % 2 if state == P_EATING else 0
			if state == P_EATING and prog < 0.85:
				items.append(_item(layout, "bowl", _bowl_img(cache, bowl_config), seat["bowl"], float(seat["bowl_depth"]), n))
				n += 1
		P_LEAVING:
			var out_route: Array = Layouts.reversed(seat["path"])
			out_route.append_array(layout["leave_tail"])
			pos = Layouts.along(out_route, prog)
			pose = "walk"
			frame = walk_frame
	items.append(_item(layout, "p|%d|%s|%d|%d" % [look, pose, frame, 1 if back else 0], _person_img(cache, look, pose, frame, back), pos - Vector2(7.0, 18.0), Layouts.depth_of_screen(layout, pos), n))
	n += 1
	var bubble: String = str(p["bubble"])
	if bubble != "":
		bubbles.append({"id":id,"kind": bubble, "pos": pos - Vector2(6.0, 29.0)})
	return n


## 검사용 CPU 합성: base + 가구 + (세션이 있으면) 사람/그릇, 말풍선. 그리기와 같은 build() 를 쓴다.
## 움직이는 김과 영업 등(도트 등)은 ShopView 가 그릴 때만 들어가므로 이 이미지에는 없다. 장면에는 글자가 없다. 전체 UI 스크린샷이 아니다.
static func compose_for(layout: Dictionary, session: Session, anim: float = 0.0, idle_staff: Array = []) -> Image:
	var cache: Dictionary = {}
	var ent: Dictionary = {}
	var config: Dictionary = {}
	var staff: Array = idle_staff
	if session != null:
		ent = session.entities()
		config = session.config
		var snap_hired: Array = session.staffing.get("hired", [])
		staff = snap_hired
	var scene: Dictionary = build(layout, ent, config, anim, {}, cache, staff)
	var all: Array = Painter.items(layout)
	all.append_array(scene["items"])
	var img: Image = Painter.compose(Painter.base(layout), all)
	for b in scene["bubbles"]:
		var bd: Dictionary = b
		var bp: Vector2 = bd["pos"]
		Art.blit(img, bubble_img(cache, str(bd["kind"])), Vector2i(int(bp.x), int(bp.y)))
	return img
