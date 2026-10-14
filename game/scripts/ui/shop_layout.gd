extends RefCounted
## 매장 장면의 좌표계(등각 투영). 모든 화면 값은 "논리 픽셀"이고 화면에는 정수 배율로만 확대한다.
##
## 두 좌표를 분리해서 쓴다.
##  - 바닥 격자(gx, gy): 타일 단위의 "논리 바닥". 가구 발자국, 걷는 경로, 좌석, 그릇의 물리 관계는 여기서 정한다.
##  - 화면(x, y): 격자를 proj() 로 투영한 결과. 사람/그릇/김은 이 화면 좌표로 그려진다.
## 런타임(ServiceSession)은 여전히 상태와 진행률만 주고, 위치는 이 표의 화면 경로(path, serve_path, queue_slots)를 따라 계산한다.
##
## 투영: 2:1 마름모 타일(너비 16, 높이 8). +gx 는 화면 오른쪽 아래, +gy 는 왼쪽 아래로 간다.
##   x = origin.x + (gx - gy) * 8
##   y = origin.y + (gx + gy) * 4 - h        (h = 바닥에서 올라간 높이, 픽셀)
## 그래서 물건의 높이는 y 만 위로 올린다(세로 벽/가구 면은 화면에서도 세로). 사람은 14x18 직립 스프라이트이며 발바닥이 proj(발 격자, 0) 이다.
## 깊이 정렬: 바닥에 선 것의 깊이는 gx + gy = (발 y - origin.y) / 4 이다. 앞(화면 아래)일수록 값이 크다. 긴 가구(카운터, 파사드, 난간)는
## 세로 조각으로 잘라 조각마다 자기 위치의 깊이를 가진다(ShopPainter.items). 그래야 서버는 카운터 뒤에, 손님은 카운터 앞에 서도 가려짐이 맞는다.
##
## 방 배치(격자): 뒷벽 두 개는 gx=0(왼쪽 벽)과 gy=0(오른쪽 벽)이다. 주방은 오른쪽 벽 아래(gy 0~2.8), 카운터는 그 앞(gy 2.8~3.8)에서 gx 방향으로 놓인다.
## 카운터 손님은 gy=4.5 에서 주방을 보고(뒷모습) 앉고, 테이블 두 개는 오른쪽(gx≈10.4)에 gy 방향으로 길게 놓여 양끝에 앉는다.
## 방 앞(gy≥8.5)은 인도: 점포 정면(파사드)과 문, 줄 서는 길(gy 10.5), 그 앞이 차도다. 줄은 문에서 오른쪽 아래로 늘어서고 손님은 오른쪽 아래에서 온다.
## 좌석 번호는 ServiceSession.SEAT_COUNT 와 같아야 한다: 0~3 카운터, 4~7 테이블.

const PORTRAIT: String = "portrait"
const LANDSCAPE: String = "landscape"

const SEAT_COUNT: int = 8
const SPRITE_W: int = 14
const SPRITE_H: int = 18

const HALF_W: float = 8.0
const HALF_H: float = 4.0

const ROOM_W: float = 12.0
const ROOM_D: float = 8.5
const WALL_H: float = 40.0
const COUNTER_H: float = 14.0
const TABLE_H: float = 11.0
const PREP_H: float = 10.0
const STOVE_H: float = 12.0

const KITCHEN: Rect2 = Rect2(0.0, 0.0, 8.6, 2.8)
const COUNTER: Rect2 = Rect2(0.9, 2.8, 7.4, 1.0)
const COUNTER_SEAT_X: Array = [1.9, 3.7, 5.5, 7.3]
const SEAT_Y: float = 4.5
const BOWL_Y: float = 3.3
const SERVE_Y: float = 2.35
const AISLE_Y: float = 6.6
const SIDE_X: float = 9.2
const TABLE_X: float = 10.4
const TABLE_Y: Array = [1.9, 6.4]
const TABLE_SIZE: Vector2 = Vector2(1.2, 2.0)
const DOOR_X: float = 4.0
const DOOR_IN: Vector2 = Vector2(4.0, 7.6)
const DOOR_OUT: Vector2 = Vector2(4.0, 10.1)
const LANE_Y: float = 10.5
const LANE2_Y: float = 11.5
const SIDEWALK_END: float = 12.3
const PASS: Vector2 = Vector2(6.6, 2.0)
const CHEF: Vector2 = Vector2(2.4, 1.75)
const STAFF_PREP: Vector2 = Vector2(4.1, 1.6)
const STAFF_FLOOR: Vector2 = Vector2(6.4, 7.7)
const FACADE: Rect2 = Rect2(0.0, 8.5, 7.2, 1.2)
const DOOR_GAP: Vector2 = Vector2(3.3, 4.7)


## 지정한 화면 크기에서 쓸 배치. 가로로 충분히 넓으면 가로 배치를 쓴다.
static func variant_for(width: float, height: float) -> String:
	if width >= 720.0 and width > height:
		return LANDSCAPE
	return PORTRAIT


## 바닥 격자 → 화면. h 는 바닥에서의 높이(픽셀). 정수 픽셀로 반올림한다(모든 모서리가 같은 격자 위에 놓이게).
static func proj(layout: Dictionary, g: Vector2, h: float = 0.0) -> Vector2:
	var o: Vector2 = layout["origin"]
	return Vector2(roundf(o.x + (g.x - g.y) * HALF_W), roundf(o.y + (g.x + g.y) * HALF_H - h))


## 바닥 위 화면 점의 깊이(gx+gy). 사람/그릇처럼 바닥 좌표만 아는 것의 정렬 키다.
static func depth_of_screen(layout: Dictionary, p: Vector2) -> float:
	var o: Vector2 = layout["origin"]
	return (p.y - o.y) / HALF_H


static func make(variant: String) -> Dictionary:
	var landscape: bool = variant == LANDSCAPE
	var layout: Dictionary = {
		"variant": LANDSCAPE if landscape else PORTRAIT,
		# 세로 176x264(배율 2 → 352x528), 가로 320x152(배율 4 → 1280x608). 세로는 폭 360대 폰에서도 배율 2가 되도록 176 으로 잡았다.
		"size": Vector2i(320, 152) if landscape else Vector2i(176, 264),
		"origin": Vector2(150.0, 46.0) if landscape else Vector2(72.0, 84.0),
		"room": Rect2(0.0, 0.0, ROOM_W, ROOM_D),
		"kitchen": KITCHEN,
		"wall_h": WALL_H,
	}
	layout["furniture"] = _furniture(landscape)
	layout["counters"] = [{"rect": COUNTER, "h": COUNTER_H}]
	var tables: Array = []
	for cy in TABLE_Y:
		tables.append({"rect": Rect2(TABLE_X - TABLE_SIZE.x * 0.5, float(cy) - TABLE_SIZE.y * 0.5, TABLE_SIZE.x, TABLE_SIZE.y), "h": TABLE_H})
	layout["tables"] = tables
	var seats: Array = []
	for gx in COUNTER_SEAT_X:
		seats.append(_counter_seat(layout, float(gx)))
	for t in TABLE_Y.size():
		var cy: float = float(TABLE_Y[t])
		# 테이블 양끝: 안쪽(gy 작은 쪽)은 정면을 보고, 바깥쪽은 등을 보이고 앉는다. 그릇은 각자 자기 쪽 상판에 놓인다.
		seats.append(_table_seat(layout, t, Vector2(TABLE_X, cy - 1.5), Vector2(TABLE_X + 0.3, cy - 0.45), false))
		seats.append(_table_seat(layout, t, Vector2(TABLE_X, cy + 1.5), Vector2(TABLE_X - 0.3, cy + 0.45), true))
	layout["seats"] = seats
	var prep: Rect2 = Rect2(4.9, 0.2, 1.8, 1.0)
	layout["chef_grid"] = CHEF
	layout["pass_grid"] = PASS
	# 보조 직원 자리(격자 + 투영). 고용했을 때만 그려진다. 안전 조건(시험이 확인): 단단한 가구 발자국/손님·서빙 경로에서 0.45칸 이상 떨어져 있고 방 안이다.
	#  - 조리 보조: 주방 안 화로 오른쪽 끝과 준비대 사이 바닥(요리사 옆). 준비대를 향해 등을 보이고 선다. 서버 대기 자리(PASS)·서빙 길과 겹치지 않는다.
	#  - 홀 보조: 문 안쪽 홀 앞쪽 빈 바닥(손님이 문에서 통로로 올라가는 길 x=4, 테이블 통로 x=9.2 사이). 정면을 보고 쟁반을 든다.
	layout["staff_spots"] = {
		"prep_assistant": {"grid": STAFF_PREP, "pos": proj(layout, STAFF_PREP), "back": true},
		"floor_assistant": {"grid": STAFF_FLOOR, "pos": proj(layout, STAFF_FLOOR), "back": false},
	}
	layout["chef_pos"] = proj(layout, CHEF)
	layout["pass_pos"] = proj(layout, PASS)
	var ready: Array = []
	for gx in [5.0, 5.6, 6.2]:
		ready.append(proj(layout, Vector2(float(gx), 0.85), PREP_H) - Vector2(6.0, 6.0))
	layout["ready_bowls"] = ready
	layout["ready_depth"] = prep.get_center().x + prep.end.y + 0.3
	# 김이 오르는 곳: 곰탕 솥 둘(상판 12 + 솥 높이 10)과 면 삶는 통(상판 12 + 통 8).
	layout["pots"] = [proj(layout, Vector2(1.3, 0.55), 22.0), proj(layout, Vector2(2.8, 0.55), 22.0), proj(layout, Vector2(3.9, 0.55), 21.0)]
	layout["door_in"] = proj(layout, DOOR_IN)
	layout["door_out"] = proj(layout, DOOR_OUT)
	var spawn_g: Vector2 = Vector2(33.0 if landscape else 25.0, LANE_Y)
	var exit_g: Vector2 = Vector2(-12.0 if landscape else -6.0, LANE_Y)
	layout["spawn_grid"] = spawn_g
	layout["exit_grid"] = exit_g
	# 퇴장 길(논리 바닥): 문 밖 → 인도(gy 10.5)로 내려선 뒤 인도를 따라 퇴장점까지. 화면 축 점을 섞지 않고 격자에서 투영한다
	# (화면 y 를 그대로 쓰면 등각 격자에서는 벽/방 안으로 들어간다).
	var leave_g: Array = [DOOR_OUT, Vector2(DOOR_X, LANE_Y), exit_g]
	layout["leave_grid"] = leave_g
	layout["leave_tail"] = _pts(layout, leave_g)
	layout["spawn"] = proj(layout, spawn_g)
	layout["exit"] = proj(layout, exit_g)
	var count: int = 16 if landscape else 14
	var slot_grid: Array = _queue(count)
	var slots: Array = []
	for g in slot_grid:
		slots.append(proj(layout, g))
	layout["queue_grid"] = slot_grid
	layout["queue_slots"] = slots
	# 간판/영업중 글씨는 ShopView 가 벽 면의 기울기(x 8당 y 4)에 맞춰 비스듬히 쓴다. left 는 글자 줄의 왼쪽 끝 중앙.
	layout["sign"] = {"left": proj(layout, Vector2(1.0, 9.85), 35.0), "width": 48.0, "height": 10.0}
	layout["open_sign"] = {"left": proj(layout, Vector2(7.5, 9.6), 7.0), "width": 11.0, "height": 8.0}
	return layout


static func _pts(layout: Dictionary, grid: Array) -> Array:
	var out: Array = []
	for g in grid:
		out.append(proj(layout, g))
	return out


static func _counter_seat(layout: Dictionary, gx: float) -> Dictionary:
	var pos_g: Vector2 = Vector2(gx, SEAT_Y)
	var bowl_g: Vector2 = Vector2(gx, BOWL_Y)
	var path_g: Array = [DOOR_IN, Vector2(DOOR_X, AISLE_Y), Vector2(gx, AISLE_Y), pos_g]
	var serve_g: Array = [PASS, Vector2(gx, SERVE_Y)]
	return {
		"kind": "counter",
		"back": true,
		"grid": pos_g,
		"pos": proj(layout, pos_g),
		"path_grid": path_g,
		"path": _pts(layout, path_g),
		"serve_grid": serve_g,
		"serve_path": _pts(layout, serve_g),
		"bowl_grid": bowl_g,
		"bowl_h": COUNTER_H,
		# 그릇 그림은 12x7, 아랫면 가운데가 접지점. 카운터 조각(깊이 gx+3.6~)보다 늦고 손님(gx+4.5)보다도 늦게 그려 윗면 위에 놓인다.
		"bowl": proj(layout, bowl_g, COUNTER_H) - Vector2(6.0, 6.0),
		"bowl_depth": gx + SEAT_Y + 0.7,
		"table": -1,
	}


static func _table_seat(layout: Dictionary, t: int, pos_g: Vector2, bowl_g: Vector2, back: bool) -> Dictionary:
	var cy: float = float(TABLE_Y[t])
	var path_g: Array = [DOOR_IN, Vector2(DOOR_X, AISLE_Y), Vector2(SIDE_X, AISLE_Y), Vector2(SIDE_X, pos_g.y), pos_g]
	var serve_g: Array = [PASS, Vector2(SIDE_X, SERVE_Y), Vector2(SIDE_X + 0.1, pos_g.y)]
	return {
		"kind": "table",
		"back": back,
		"grid": pos_g,
		"pos": proj(layout, pos_g),
		"path_grid": path_g,
		"path": _pts(layout, path_g),
		"serve_grid": serve_g,
		"serve_path": _pts(layout, serve_g),
		"bowl_grid": bowl_g,
		"bowl_h": TABLE_H,
		"bowl": proj(layout, bowl_g, TABLE_H) - Vector2(6.0, 6.0),
		# 테이블 앞 가장자리 깊이 + 0.1: 뒤쪽 손님(작은 깊이)보다 앞, 앞쪽 손님(+1.5)보다 뒤.
		"bowl_depth": TABLE_X + cy + TABLE_SIZE.y * 0.5 + 0.1,
		"table": t,
	}


## 줄: 앞줄 8명은 문 앞 인도(gy 10.5)에 한 칸 1.4(화면 11px), 그다음은 반 칸 어긋난 뒷줄. 줄 끝은 오른쪽 아래다.
static func _queue(count: int) -> Array:
	var slots: Array = []
	for i in count:
		if i < 8:
			slots.append(Vector2(DOOR_X + 1.4 * float(i), LANE_Y))
		else:
			slots.append(Vector2(DOOR_X + 0.7 + 1.4 * float(i - 8), LANE2_Y))
	return slots


static func _f(id: String, kind: String, rect: Rect2, h: float, solid: bool = true) -> Dictionary:
	return {"id": id, "kind": kind, "rect": rect, "h": h, "solid": solid, "rects": [rect]}


static func _plant_f(id: String, cx: float, cy: float, style: int) -> Dictionary:
	var d: Dictionary = _f(id, "plant", Rect2(cx - 0.4, cy - 0.4, 0.8, 0.8), 22.0)
	d["style"] = style
	return d


## 가구/소품 목록. solid 인 것은 사람이 걷는 경로와 겹치면 안 된다(테스트가 확인한다). 그리는 법은 ShopPainter 가 kind 로 정한다.
static func _furniture(landscape: bool) -> Array:
	var list: Array = []
	list.append(_f("counter", "counter", COUNTER, COUNTER_H))
	list.append(_f("stove", "stove", Rect2(0.6, 0.0, 4.0, 1.1), STOVE_H))
	list.append(_f("prep", "prep", Rect2(4.9, 0.2, 1.8, 1.0), PREP_H))
	list.append(_f("fridge", "fridge", Rect2(7.1, 0.0, 1.3, 1.0), 30.0))
	for t in TABLE_Y.size():
		var cy: float = float(TABLE_Y[t])
		list.append(_f("table%d" % t, "table", Rect2(TABLE_X - TABLE_SIZE.x * 0.5, cy - TABLE_SIZE.y * 0.5, TABLE_SIZE.x, TABLE_SIZE.y), TABLE_H))
	list.append(_f("bench", "bench", Rect2(0.1, 4.6, 0.7, 2.0), 6.0))
	list.append(_plant_f("plant_door", 0.55, 7.35, 0))
	list.append(_plant_f("plant_mid", 11.55, 4.9, 1))
	list.append(_plant_f("plant_edge", 11.55, 7.6, 2))
	list.append(_f("rail_x", "railing_x", Rect2(11.85, 0.0, 0.15, ROOM_D), 8.0, false))
	list.append(_f("rail_y", "railing_y", Rect2(7.2, ROOM_D - 0.15, 4.8, 0.15), 8.0, false))
	var facade: Dictionary = _f("facade", "facade", FACADE, 11.0)
	facade["rects"] = [Rect2(FACADE.position.x, FACADE.position.y, DOOR_GAP.x, FACADE.size.y), Rect2(DOOR_GAP.y, FACADE.position.y, FACADE.end.x - DOOR_GAP.y, FACADE.size.y)]
	list.append(facade)
	# 인도/골목 소품(경로 밖): 입간판 옆 영업중 안내, 등롱, 벤치, 이웃 노점과 건물, 상자, 고양이, 자전거, 가로등, 벚나무, 손수레.
	list.append(_f("lantern", "lantern_stand", Rect2(0.7, 9.75, 0.6, 0.35), 24.0))
	list.append(_f("astand", "astand", Rect2(7.4, 8.9, 1.6, 0.7), 14.0))
	list.append(_f("bench2", "bench2", Rect2(9.4, 9.0, 1.6, 0.7), 6.0))
	list.append(_f("stall", "stall", Rect2(13.0, 4.5, 3.0, 3.6), 26.0))
	list.append(_f("neighbor_e", "neighbor_e", Rect2(12.8, -0.6, 9.2, 4.6), 44.0, false))
	list.append(_f("crates", "crates", Rect2(9.8, 13.0, 1.2, 0.8), 9.0))
	list.append(_f("cat", "cat", Rect2(6.3, 11.9, 0.6, 0.4), 4.0))
	list.append(_f("bike", "bike", Rect2(14.2, 13.3, 1.5, 0.5), 12.0))
	list.append(_f("bin", "bin", Rect2(12.2, 12.7, 0.6, 0.6), 9.0))
	list.append(_f("lamp_a", "lamp", Rect2(1.5, 12.3, 0.3, 0.3), 46.0))
	list.append(_f("lamp_b", "lamp", Rect2(13.0, 12.3, 0.3, 0.3), 46.0))
	list.append(_f("tree", "tree", Rect2(16.0, 11.9, 1.2, 1.2), 36.0))
	list.append(_f("cart", "cart", Rect2(3.0, 13.5, 2.2, 0.9), 14.0))
	list.append(_plant_f("shrub", 1.2, 11.9, 1))
	if landscape:
		list.append(_f("vending", "vending", Rect2(-2.8, 8.9, 1.0, 0.8), 26.0))
		list.append(_f("tree_l", "tree", Rect2(-5.0, 11.4, 1.2, 1.2), 36.0))
	return list


## 점 목록을 따라 비율 t(0~1)만큼 걸은 위치(구간 길이에 비례).
static func along(points: Array, t: float) -> Vector2:
	if points.is_empty():
		return Vector2.ZERO
	if points.size() == 1 or t <= 0.0:
		return points[0]
	var total: float = 0.0
	for i in range(1, points.size()):
		total += (points[i] as Vector2).distance_to(points[i - 1])
	if total <= 0.0 or t >= 1.0:
		return points[points.size() - 1]
	var target: float = total * t
	var walked: float = 0.0
	for i in range(1, points.size()):
		var a: Vector2 = points[i - 1]
		var b: Vector2 = points[i]
		var seg: float = a.distance_to(b)
		if walked + seg >= target:
			if seg <= 0.0:
				return b
			return a.lerp(b, (target - walked) / seg)
		walked += seg
	return points[points.size() - 1]


static func reversed(points: Array) -> Array:
	var out: Array = points.duplicate()
	out.reverse()
	return out
