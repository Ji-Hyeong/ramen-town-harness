extends RefCounted
## 매장 장면의 좌표계. 모든 값은 "논리 픽셀"(화면에는 정수 배율로 확대)이며 사람 위치는 발바닥 가운데 기준이다.
## 같은 가게를 세로(휴대폰)와 가로(데스크톱) 두 배치로 놓는다. 장면 그리기와 사람 이동은 이 표만 참고하고,
## 어떤 사람이 어디에 있는지는 ServiceSession의 논리 상태가 정한다(여기에는 상태가 없다).
##
## 좌석 번호는 ServiceSession.SEAT_COUNT 와 같아야 한다: 0~3 카운터(등을 보이고 앉음), 4~7 테이블.
## path: 문 안쪽에서 자리까지의 경로(퇴장은 역순). serve_path: 서버가 주방 앞에서 자리까지 가는 경로.
## 경로는 가구를 피해 복도/중앙 통로로만 이어지도록 직접 잡았다(자동 길찾기 없음).

const PORTRAIT: String = "portrait"
const LANDSCAPE: String = "landscape"

const SEAT_COUNT: int = 8
const SPRITE_W: int = 14
const SPRITE_H: int = 18


## 지정한 화면 크기에서 쓸 배치. 가로로 충분히 넓으면 가로 배치를 쓴다.
static func variant_for(width: float, height: float) -> String:
	if width >= 720.0 and width > height:
		return LANDSCAPE
	return PORTRAIT


static func make(variant: String) -> Dictionary:
	if variant == LANDSCAPE:
		return _landscape()
	return _portrait()


static func _seat(kind: String, pos: Vector2, path: Array, serve_path: Array, bowl: Vector2, table: int) -> Dictionary:
	return {
		"kind": kind,
		"pos": pos,
		"path": path,
		"serve_path": serve_path,
		"bowl": bowl,
		"table": table,
	}


static func _queue(row1_y: float, row2_y: float, door_x: float, count: int) -> Array:
	# 앞줄 8명, 그다음은 반 칸 어긋난 뒷줄. 줄의 끝은 왼쪽이고 새 손님은 왼쪽 가장자리에서 걸어온다.
	var slots: Array = []
	for i in count:
		if i < 8:
			slots.append(Vector2(door_x - 13.0 * float(i), row1_y))
		else:
			slots.append(Vector2(door_x - 6.0 - 13.0 * float(i - 8), row2_y))
	return slots


static func _portrait() -> Dictionary:
	var door_x: float = 101.0
	var door_in: Vector2 = Vector2(door_x, 150.0)
	var pass_pos: Vector2 = Vector2(64.0, 62.0)
	var seats: Array = []
	for cx in [20.0, 44.0, 84.0, 108.0]:
		var x: float = float(cx)
		# 앉은 몸(발바닥 y=90, 머리 y=72)이 카운터 앞면(y 71~80)에 붙고, 그릇은 카운터 윗면(y 66~71)의 바로 앞(머리 위)에 놓인다.
		var seat_pos: Vector2 = Vector2(x, 90.0)
		seats.append(_seat("counter", seat_pos,
			[door_in, Vector2(64.0, 150.0), Vector2(64.0, 106.0), Vector2(x, 106.0), seat_pos],
			[pass_pos, Vector2(x, 62.0)],
			Vector2(x - 6.0, 63.0), -1))
	# 테이블 두 개: 중심 x=28, 100 / 좌석은 테이블 양옆
	for t in 2:
		var tcx: float = 28.0 if t == 0 else 100.0
		for side in 2:
			var sx: float = tcx - 16.0 if side == 0 else tcx + 16.0
			var seat_pos2: Vector2 = Vector2(sx, 134.0)
			var bowl_x: float = tcx - 9.0 if side == 0 else tcx + 1.0
			seats.append(_seat("table", seat_pos2,
				[door_in, Vector2(sx, 150.0), seat_pos2],
				[pass_pos, Vector2(64.0, 142.0), Vector2(sx, 142.0)],
				Vector2(bowl_x, 122.0), t))
	return {
		"variant": PORTRAIT,
		"size": Vector2i(128, 208),
		"roof": Rect2i(0, 0, 128, 8),
		"wall": Rect2i(0, 8, 128, 28),
		"kitchen": Rect2i(0, 36, 128, 30),
		"counters": [Rect2i(8, 66, 48, 14), Rect2i(72, 66, 48, 14)],
		"floors": [Rect2i(0, 80, 128, 72)],
		"facade": Rect2i(0, 152, 128, 24),
		"door": Rect2i(89, 158, 24, 18),
		"sign": Rect2i(6, 155, 72, 14),
		"open_sign": Rect2i(111, 184, 17, 15),
		"street": Rect2i(0, 176, 128, 32),
		"tables": [Vector2i(28, 128), Vector2i(100, 128)],
		"stove_x": 10,
		"fridge_x": 100,
		# 복도(y=150)와 중앙 통로(x=64)를 비워 둔다. 화분은 걷는 경로에서 떨어진 가장자리에만 둔다.
		"plants": [Vector2(4.0, 112.0), Vector2(122.0, 100.0)],
		"chef_pos": Vector2(30.0, 62.0),
		"pass_pos": pass_pos,
		"door_in": door_in,
		"door_out": Vector2(door_x, 178.0),
		"spawn": Vector2(-12.0, 200.0),
		"exit": Vector2(142.0, 200.0),
		"queue_slots": _queue(200.0, 206.0, door_x, 14),
		"seats": seats,
	}


static func _landscape() -> Dictionary:
	var door_x: float = 106.0
	var door_in: Vector2 = Vector2(door_x, 106.0)
	var pass_pos: Vector2 = Vector2(door_x, 54.0)
	var seats: Array = []
	for cx in [30.0, 62.0, 142.0, 174.0]:
		var x: float = float(cx)
		# 카운터 윗면 y 58~63, 앞면 63~72. 앉은 머리(y=62)가 앞면에 붙고 그릇(y 55~62)이 그 바로 위 윗면에 놓인다.
		var seat_pos: Vector2 = Vector2(x, 80.0)
		seats.append(_seat("counter", seat_pos,
			[door_in, Vector2(x, 106.0), seat_pos],
			[pass_pos, Vector2(x, 54.0)],
			Vector2(x - 6.0, 55.0), -1))
	for t in 2:
		var tcx: float = 226.0 if t == 0 else 288.0
		for side in 2:
			var sx: float = tcx - 16.0 if side == 0 else tcx + 16.0
			var seat_pos2: Vector2 = Vector2(sx, 82.0)
			var bowl_x: float = tcx - 9.0 if side == 0 else tcx + 1.0
			seats.append(_seat("table", seat_pos2,
				[door_in, Vector2(sx, 106.0), seat_pos2],
				[pass_pos, Vector2(door_x, 92.0), Vector2(sx, 92.0)],
				Vector2(bowl_x, 70.0), t))
	return {
		"variant": LANDSCAPE,
		"size": Vector2i(320, 148),
		"roof": Rect2i(0, 0, 320, 8),
		"wall": Rect2i(0, 8, 320, 24),
		"kitchen": Rect2i(0, 32, 192, 26),
		"counters": [Rect2i(10, 58, 86, 14), Rect2i(116, 58, 76, 14)],
		"floors": [Rect2i(0, 72, 192, 40), Rect2i(192, 32, 128, 80)],
		"facade": Rect2i(0, 112, 320, 24),
		"door": Rect2i(94, 114, 24, 22),
		"sign": Rect2i(8, 116, 80, 14),
		"open_sign": Rect2i(124, 133, 17, 15),
		"street": Rect2i(0, 136, 320, 12),
		"tables": [Vector2i(226, 76), Vector2i(288, 76)],
		"stove_x": 14,
		"fridge_x": 166,
		"plants": [Vector2(193.0, 50.0), Vector2(318.0, 112.0), Vector2(8.0, 100.0), Vector2(256.0, 50.0)],
		"chef_pos": Vector2(40.0, 54.0),
		"pass_pos": pass_pos,
		"door_in": door_in,
		"door_out": Vector2(door_x, 138.0),
		"spawn": Vector2(-12.0, 145.0),
		"exit": Vector2(334.0, 145.0),
		"queue_slots": _queue(145.0, 148.0, door_x, 16),
		"seats": seats,
	}


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
