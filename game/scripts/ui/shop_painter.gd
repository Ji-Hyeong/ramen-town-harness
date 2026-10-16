extends RefCounted
## 매장 정적 그림(등각 컷어웨이). 두 층으로 나눈다.
##  - base(): 깊이 정렬이 필요 없는 것 = 하늘, 바닥 타일(나무/주방/인도/차도), 뒷벽 두 개와 벽 장식, 이웃 건물 지붕, 바닥 깔개.
##  - items(): 사람과 가려짐을 주고받는 것 = 가구, 소품, 파사드. 각각 따로 잘라 낸 작은 이미지 + 깊이(gx+gy)를 가진다.
## ShopView 는 base 위에 items 와 사람/그릇을 하나의 깊이 순서로 섞어 그린다. paint()/compose() 는 같은 데이터를 CPU 이미지로 합성한다(검사용).
## 모든 좌표는 ShopLayout.proj 투영이며(등각 2:1, 높이 h 는 화면 y 를 위로 올림) 외부 이미지/참조 에셋 없이 직접 짠 도트 규칙이다.
##
## 깊이 규칙: 일반 가구는 (가운데 gx + 앞 가장자리 gy). 긴 가구(카운터, 파사드, 난간)는 6px 세로 조각으로 잘라 조각마다
## "그 열에서 보이는 앞면 위치"의 깊이를 가진다(_emit_slices). 사람 깊이는 발 y 에서 구한 gx+gy 이므로 같은 눈금이다.

const Art = preload("res://scripts/ui/pixel_art.gd")
const Layouts = preload("res://scripts/ui/shop_layout.gd")

const INK: Color = Color(0.149, 0.102, 0.071)
const SKY: Color = Color(0.20, 0.22, 0.31)
const WOOD_D: Color = Color(0.29, 0.17, 0.09)
const WOOD: Color = Color(0.48, 0.29, 0.15)
const WOOD_F: Color = Color(0.62, 0.38, 0.20)
const WOOD_L: Color = Color(0.66, 0.41, 0.23)
const WOOD_LL: Color = Color(0.82, 0.60, 0.36)
const FLOOR_A: Color = Color(0.80, 0.60, 0.38)
const FLOOR_B: Color = Color(0.74, 0.54, 0.33)
const FLOOR_SEAM: Color = Color(0.58, 0.40, 0.23)
const KIT_A: Color = Color(0.60, 0.62, 0.65)
const KIT_B: Color = Color(0.52, 0.54, 0.58)
const KIT_SEAM: Color = Color(0.40, 0.42, 0.47)
const WALK_A: Color = Color(0.70, 0.66, 0.61)
const WALK_B: Color = Color(0.64, 0.60, 0.56)
const WALK_SEAM: Color = Color(0.48, 0.45, 0.43)
const ROAD_A: Color = Color(0.40, 0.40, 0.44)
const ROAD_B: Color = Color(0.35, 0.35, 0.39)
const ROAD_SEAM: Color = Color(0.26, 0.26, 0.30)
const ALLEY: Color = Color(0.50, 0.45, 0.41)
const STEEL: Color = Color(0.74, 0.77, 0.80)
const STEEL_D: Color = Color(0.44, 0.47, 0.52)
const PLASTER: Color = Color(0.93, 0.85, 0.68)
const PLASTER_D: Color = Color(0.80, 0.70, 0.52)
const RED: Color = Color(0.76, 0.23, 0.13)
const RED_D: Color = Color(0.54, 0.15, 0.09)
const ROOF: Color = Color(0.23, 0.26, 0.32)
const ROOF_L: Color = Color(0.36, 0.41, 0.50)
const GREEN: Color = Color(0.31, 0.54, 0.27)
const GREEN_D: Color = Color(0.18, 0.37, 0.19)
const PAPER: Color = Color(0.96, 0.92, 0.80)
const WHITE: Color = Color(0.97, 0.95, 0.90)
const GLASS: Color = Color(0.60, 0.76, 0.84)
const WARM: Color = Color(1.0, 0.82, 0.45)
const TERRA: Color = Color(0.70, 0.36, 0.22)
const PINK: Color = Color(0.98, 0.75, 0.82)
const SHADOW: Color = Color(0.0, 0.0, 0.0, 0.22)


# ---------- 투영 도우미 ----------

static func _p(L: Dictionary, x: float, y: float, h: float = 0.0) -> Vector2:
	return Layouts.proj(L, Vector2(x, y), h)


## 벽/면 위의 점. plane "X": x=c 인 면(t 가 gy), "Y": y=c 인 면(t 가 gx).
static func _pp(L: Dictionary, plane: String, c: float, t: float, h: float) -> Vector2:
	if plane == "X":
		return _p(L, c, t, h)
	return _p(L, t, c, h)


## 세로 면 위의 직사각형(화면에서는 평행사변형: 면을 따라 8px 가면 4px 기울어짐).
static func _pq(img: Image, L: Dictionary, plane: String, c: float, t0: float, t1: float, h0: float, h1: float, col: Color) -> void:
	Art.poly(img, [_pp(L, plane, c, t0, h1), _pp(L, plane, c, t1, h1), _pp(L, plane, c, t1, h0), _pp(L, plane, c, t0, h0)], col)


static func _pl(img: Image, L: Dictionary, plane: String, c: float, t0: float, h0: float, t1: float, h1: float, col: Color) -> void:
	Art.line(img, _pp(L, plane, c, t0, h0), _pp(L, plane, c, t1, h1), col)


## 바닥(또는 높이 h)에 눕힌 직사각형.
static func _flat(img: Image, L: Dictionary, x0: float, y0: float, x1: float, y1: float, h: float, col: Color) -> void:
	Art.poly(img, [_p(L, x0, y0, h), _p(L, x1, y0, h), _p(L, x1, y1, h), _p(L, x0, y1, h)], col)


## 높이 h0~h1 직육면체. 보이는 세 면만: 윗면(밝음), 앞왼쪽 면(y=y1, 보통), 앞오른쪽 면(x=x1, 어두움). 윤곽은 면보다 어두운 선.
static func _box(img: Image, L: Dictionary, x0: float, y0: float, x1: float, y1: float, h0: float, h1: float, top: Color, face: Color, side: Color) -> void:
	var a: Vector2 = _p(L, x0, y0, h1)
	var b: Vector2 = _p(L, x1, y0, h1)
	var c: Vector2 = _p(L, x1, y1, h1)
	var d: Vector2 = _p(L, x0, y1, h1)
	var c0: Vector2 = _p(L, x1, y1, h0)
	var d0: Vector2 = _p(L, x0, y1, h0)
	var b0: Vector2 = _p(L, x1, y0, h0)
	Art.poly(img, [d, c, c0, d0], face)
	Art.poly(img, [b, c, c0, b0], side)
	Art.poly(img, [a, b, c, d], top)
	var edge: Color = top.darkened(0.30)
	Art.line(img, d, c, edge)
	Art.line(img, c, b, edge)
	Art.line(img, a, d, edge)
	Art.line(img, a, b, edge)
	var vedge: Color = face.darkened(0.35)
	Art.line(img, d, d0, vedge)
	Art.line(img, c, c0, vedge)
	Art.line(img, b, b0, vedge)
	Art.line(img, d0, c0, vedge)
	Art.line(img, c0, b0, vedge)


static func _hash(a: int, b: int) -> int:
	return ((a * 73856093) ^ (b * 19349663)) & 0x7fffffff


# ---------- 합성 ----------

static func paint(layout: Dictionary) -> Image:
	return compose(base(layout), items(layout))


static func _by_depth(a: Dictionary, b: Dictionary) -> bool:
	var da: float = float(a["depth"])
	var db: float = float(b["depth"])
	if da == db:
		return int(a["n"]) < int(b["n"])
	return da < db


## base 위에 items(깊이 오름차순)를 알파 합성한 새 이미지. 사람 항목을 섞어 넘기면 같은 방식으로 합성된다.
static func compose(base_img: Image, its: Array) -> Image:
	var out: Image = base_img.duplicate() as Image
	var ordered: Array = its.duplicate()
	ordered.sort_custom(_by_depth)
	for it in ordered:
		var d: Dictionary = it
		var p: Vector2 = d["pos"]
		Art.blit(out, d["img"], Vector2i(int(p.x), int(p.y)))
	return out


static func sort_items(its: Array) -> Array:
	var ordered: Array = its.duplicate()
	ordered.sort_custom(_by_depth)
	return ordered


# ---------- 정적 바닥/벽 ----------

static func base(L: Dictionary) -> Image:
	var size: Vector2i = L["size"]
	var img: Image = Art.new_image(size.x, size.y)
	Art.rect(img, 0, 0, size.x, size.y, SKY)
	_ground(img, L)
	_decals(img, L)
	_neighbors(img, L)
	_slab(img, L)
	_walls(img, L)
	return img


static func _ground(img: Image, L: Dictionary) -> void:
	var size: Vector2i = L["size"]
	var o: Vector2 = L["origin"]
	for y in size.y:
		var v: float = (float(y) + 0.5 - o.y) / float(L.get("half_h", Layouts.HALF_H))
		for x in size.x:
			var u: float = (float(x) + 0.5 - o.x) / float(L.get("half_w", Layouts.HALF_W))
			var gx: float = (u + v) * 0.5
			var gy: float = (v - u) * 0.5
			# 뒷벽 너머(이웃 건물이 가리는 곳)는 바닥을 만들지 않는다.
			if gy < -0.6 or (gx < -0.6 and gy < Layouts.ROOM_D):
				continue
			img.set_pixel(x, y, _ground_color(L, gx, gy, x, y))


static func _ground_color(L: Dictionary, gx: float, gy: float, px: int, py: int) -> Color:
	var tx: int = int(floor(gx))
	var ty: int = int(floor(gy))
	var fx: float = gx - float(tx)
	var fy: float = gy - float(ty)
	var par: int = (tx + ty) & 1
	var hs: int = _hash(px, py) % 11
	var pt: Vector2 = Vector2(gx, gy)
	var kitchen: Rect2 = L["kitchen"]
	var room: Rect2 = L["room"]
	if kitchen.has_point(pt):
		var kc: Color = KIT_A if par == 0 else KIT_B
		if fx < 0.07 or fy < 0.07:
			kc = KIT_SEAM
		elif hs == 0:
			kc = kc.darkened(0.06)
		return kc
	if room.has_point(pt):
		var wc: Color = FLOOR_A if par == 0 else FLOOR_B
		if gx > kitchen.end.x - 0.06 and gx < kitchen.end.x + 0.06 and gy < kitchen.end.y:
			return STEEL_D
		# 마름모 타일 경계는 어둡게, 타일 안은 gx 방향 널(세 줄)과 어긋난 이음매.
		if fx < 0.06 or fy < 0.06:
			return FLOOR_SEAM
		var row: int = int(floor(fy * 3.0))
		var rf: float = fy * 3.0 - float(row)
		if rf < 0.10:
			return wc.darkened(0.10)
		var jx: float = fposmod(gx * 0.5 + float(row) * 0.37 + float(ty) * 0.21, 1.0)
		if jx < 0.03:
			return wc.darkened(0.12)
		if hs == 0:
			return wc.darkened(0.05)
		return wc
	if gy >= Layouts.ROOM_D and gy < Layouts.SIDEWALK_END:
		var sc: Color = WALK_A if par == 0 else WALK_B
		if fx < 0.06 or fy < 0.06:
			return WALK_SEAM
		if hs == 0:
			return sc.darkened(0.05)
		if gy > Layouts.SIDEWALK_END - 0.16:
			return Color(0.80, 0.77, 0.72)
		return sc
	if gy >= Layouts.SIDEWALK_END:
		# 차도: 타일 하나를 3x3 조약돌로 쪼갠다.
		var cx: float = fx * 3.0 - floor(fx * 3.0)
		var cyy: float = fy * 3.0 - floor(fy * 3.0)
		var rc: Color = ROAD_A if par == 0 else ROAD_B
		if cx < 0.14 or cyy < 0.14:
			return ROAD_SEAM
		if hs < 2:
			return rc.lightened(0.08)
		return rc
	var ac: Color = ALLEY
	if fx < 0.06 or fy < 0.06:
		ac = ALLEY.darkened(0.2)
	elif hs == 0:
		ac = ac.darkened(0.06)
	return ac


## 바닥에 눕힌 깔개: 현관 매트, 테이블 아래 러그, 주방 고무 매트, 인도 위 꽃잎.
static func _decals(img: Image, L: Dictionary) -> void:
	_flat(img, L, 3.3, 7.0, 4.7, 8.0, 0.0, RED_D)
	_flat(img, L, 3.45, 7.15, 4.55, 7.85, 0.0, RED)
	_flat(img, L, 3.6, 7.3, 4.4, 7.7, 0.0, Color(0.88, 0.36, 0.22))
	_flat(img, L, 9.3, 5.0, 11.6, 7.8, 0.0, Color(0.55, 0.30, 0.20))
	_flat(img, L, 9.45, 5.15, 11.45, 7.65, 0.0, Color(0.93, 0.85, 0.66))
	_flat(img, L, 9.7, 5.4, 11.2, 7.4, 0.0, Color(0.70, 0.38, 0.28))
	_flat(img, L, 9.9, 5.6, 11.0, 7.2, 0.0, Color(0.93, 0.85, 0.66))
	_flat(img, L, 0.8, 1.3, 4.8, 2.3, 0.0, Color(0.30, 0.32, 0.36))
	for k in 5:
		_flat(img, L, 0.9 + float(k) * 0.8, 1.35, 1.2 + float(k) * 0.8, 2.25, 0.0, Color(0.34, 0.36, 0.41))
	for k in 12:
		var q: Vector2 = _p(L, 2.0 + float(k) * 1.3, 9.9 + float((k * 7) % 5) * 0.4)
		Art.px(img, int(q.x), int(q.y), PINK)
		Art.px(img, int(q.x) + 1, int(q.y), Color(0.95, 0.62, 0.72))


static func _tile_roof(img: Image, L: Dictionary, x0: float, x1: float, y0: float, y1: float, h: float, along_x: bool) -> void:
	_flat(img, L, x0, y0, x1, y1, h, ROOF)
	var k: float = (y0 if along_x else x0)
	var k_end: float = (y1 if along_x else x1)
	var odd: bool = false
	while k < k_end:
		var k2: float = minf(k + 1.0, k_end)
		if odd:
			if along_x:
				_flat(img, L, x0, k, x1, k2, h, ROOF_L)
			else:
				_flat(img, L, k, y0, k2, y1, h, ROOF_L)
		var a: Vector2 = _p(L, x0, k, h) if along_x else _p(L, k, y0, h)
		var b: Vector2 = _p(L, x1, k, h) if along_x else _p(L, k, y1, h)
		Art.line(img, a, b, ROOF.darkened(0.3))
		odd = not odd
		k = k2


## 방 뒤/옆의 이웃 건물(기와 지붕과 처마). 벽 위로 삐져나온 윗부분만 보이고, 컷어웨이 벽이 나중에 그려져 앞을 가린다.
static func _neighbors(img: Image, L: Dictionary) -> void:
	# 오른쪽 뒤 건물과 왼쪽 건물은 모서리에서 L 자로 만나 같은 높이의 지붕을 이룬다.
	_box(img, L, -9.0, -12.0, 22.0, -0.6, 0.0, 52.0, ROOF, PLASTER_D, PLASTER_D.darkened(0.2))
	_tile_roof(img, L, -9.0, 22.0, -12.0, -0.6, 52.0, true)
	_pq(img, L, "Y", -0.6, -9.0, 22.0, 46.0, 52.0, ROOF.darkened(0.15))
	_pq(img, L, "Y", -0.6, -9.0, 22.0, 45.0, 46.0, WOOD_D)
	_box(img, L, -9.0, -0.6, -0.6, 8.5, 0.0, 52.0, ROOF, PLASTER_D.darkened(0.12), PLASTER_D.darkened(0.12))
	_tile_roof(img, L, -9.0, -0.6, -0.6, 8.5, 52.0, false)
	_pq(img, L, "X", -0.6, -0.6, 8.5, 46.0, 52.0, ROOF.darkened(0.25))
	_pq(img, L, "X", -0.6, -0.6, 8.5, 45.0, 46.0, WOOD_D)
	# 지붕 위 굴뚝과 처마 등롱
	_box(img, L, 2.0, -6.0, 2.9, -5.1, 52.0, 60.0, STEEL_D, Color(0.42, 0.28, 0.22), Color(0.32, 0.2, 0.16))
	_box(img, L, 15.0, -4.0, 15.9, -3.1, 52.0, 58.0, STEEL_D, Color(0.42, 0.28, 0.22), Color(0.32, 0.2, 0.16))
	_box(img, L, -5.0, 2.0, -4.1, 2.9, 52.0, 59.0, STEEL_D, Color(0.42, 0.28, 0.22), Color(0.32, 0.2, 0.16))
	for k in 6:
		_lantern_up(img, _p(L, 1.0 + float(k) * 3.4, -0.6, 45.0))
	for k in 3:
		_lantern_up(img, _p(L, -0.6, 1.2 + float(k) * 2.8, 45.0))


## 바닥 판의 두께(컷어웨이 단면): 앞왼쪽 가장자리(gy=8.5)와 앞오른쪽 가장자리(gx=12).
static func _slab(img: Image, L: Dictionary) -> void:
	var room: Rect2 = L["room"]
	_pq(img, L, "Y", room.size.y, 0.0, room.size.x, -5.0, 0.0, WOOD.darkened(0.1))
	_pq(img, L, "Y", room.size.y, 0.0, room.size.x, -1.0, 0.0, WOOD_D)
	_pq(img, L, "X", room.size.x, 0.0, room.size.y, -5.0, 0.0, WOOD_D.lightened(0.05))
	_pq(img, L, "X", room.size.x, 0.0, room.size.y, -1.0, 0.0, Color(0.20, 0.11, 0.06))


static func _walls(img: Image, L: Dictionary) -> void:
	var w: float = Layouts.WALL_H
	var d: float = Layouts.ROOM_D
	var rw: float = (L["room"] as Rect2).size.x
	# 왼쪽 벽(gx=0, 오른쪽 아래를 향함)은 오른쪽 벽보다 한 톤 어둡다(빛이 왼쪽 앞에서 온다).
	_pq(img, L, "X", 0.0, 0.0, d, 0.0, w, PLASTER_D)
	_pq(img, L, "Y", 0.0, 0.0, rw, 0.0, w, PLASTER)
	_wall_left(img, L)
	_wall_right(img, L)
	# 벽 윗면(두께 0.5)과 끝 단면
	Art.poly(img, [_p(L, -0.5, 0.0, w), _p(L, 0.0, 0.0, w), _p(L, 0.0, d, w), _p(L, -0.5, d, w)], WOOD_L)
	Art.poly(img, [_p(L, -0.5, -0.5, w), _p(L, rw, -0.5, w), _p(L, rw, 0.0, w), _p(L, -0.5, 0.0, w)], WOOD_LL)
	_pq(img, L, "X", rw, -0.5, 0.0, 0.0, w, WOOD_D)
	_pq(img, L, "Y", d, -0.5, 0.0, 0.0, w, WOOD_D.lightened(0.05))
	Art.line(img, _p(L, 0.0, 0.0, w), _p(L, 0.0, d, w), WOOD_D)
	Art.line(img, _p(L, 0.0, 0.0, w), _p(L, rw, 0.0, w), WOOD_D)


static func _wainscot(img: Image, L: Dictionary, plane: String, t1: float) -> void:
	_pq(img, L, plane, 0.0, 0.0, t1, 0.0, 10.0, WOOD)
	_pq(img, L, plane, 0.0, 0.0, t1, 10.0, 11.0, WOOD_L)
	var t: float = 0.0
	while t < t1:
		_pl(img, L, plane, 0.0, t, 0.0, t, 10.0, WOOD_D)
		t += 0.6


static func _beam(img: Image, L: Dictionary, plane: String, t: float) -> void:
	_pq(img, L, plane, 0.0, t, t + 0.35, 0.0, Layouts.WALL_H, WOOD_D)
	_pq(img, L, plane, 0.0, t + 0.05, t + 0.12, 11.0, Layouts.WALL_H - 1.0, WOOD)


static func _wall_left(img: Image, L: Dictionary) -> void:
	_wainscot(img, L, "X", Layouts.ROOM_D)
	for t in [0.0, 3.0, 6.0, Layouts.ROOM_D - 0.35]:
		_beam(img, L, "X", float(t))
	# 메뉴 종이 네 장(라멘/차슈/계란/멘마 자리): 나무 틀에 매달린 세로 종이, 먹 자국 몇 줄.
	_pq(img, L, "X", 0.0, 0.5, 2.8, 33.0, 34.5, WOOD_D)
	for k in 4:
		var t0: float = 0.7 + float(k) * 0.52
		_pq(img, L, "X", 0.0, t0, t0 + 0.4, 17.0, 33.0, PAPER)
		_pq(img, L, "X", 0.0, t0, t0 + 0.4, 17.0, 18.0, WOOD_D)
		for ln in 3:
			_pq(img, L, "X", 0.0, t0 + 0.12, t0 + 0.28, 28.0 - float(ln) * 3.5, 30.0 - float(ln) * 3.5, INK)
		if k == 1:
			_pq(img, L, "X", 0.0, t0 + 0.08, t0 + 0.32, 20.0, 22.0, RED)
	# 창: 나무 틀 + 푸른 유리 + 십자 살 + 창턱 화분
	_pq(img, L, "X", 0.0, 3.5, 5.6, 15.0, 31.0, WOOD_D)
	_pq(img, L, "X", 0.0, 3.62, 5.48, 16.0, 30.0, GLASS)
	_pq(img, L, "X", 0.0, 3.62, 4.0, 25.0, 29.0, Color(0.85, 0.93, 0.95))
	_pq(img, L, "X", 0.0, 4.5, 4.62, 16.0, 30.0, WOOD_D)
	_pq(img, L, "X", 0.0, 3.62, 5.48, 22.5, 23.5, WOOD_D)
	_pq(img, L, "X", 0.0, 3.4, 5.7, 13.5, 15.0, WOOD_L)
	var sill: Vector2 = _p(L, 0.0, 4.2, 15.0)
	_plant_small(img, sill)
	# 선반: 병과 항아리, 붉은 달마
	_pq(img, L, "X", 0.0, 6.3, 8.2, 20.0, 21.5, WOOD_D)
	var sh: Vector2 = _p(L, 0.0, 6.6, 21.5)
	Art.rect(img, int(sh.x) - 2, int(sh.y) - 6, 3, 6, Color(0.30, 0.16, 0.08))
	Art.rect(img, int(sh.x) - 1, int(sh.y) - 7, 1, 1, STEEL_D)
	var sh2: Vector2 = _p(L, 0.0, 7.1, 21.5)
	Art.rect(img, int(sh2.x) - 2, int(sh2.y) - 5, 4, 5, Color(0.74, 0.50, 0.22))
	var sh3: Vector2 = _p(L, 0.0, 7.7, 21.5)
	Art.rect(img, int(sh3.x) - 3, int(sh3.y) - 7, 6, 7, RED)
	Art.rect(img, int(sh3.x) - 2, int(sh3.y) - 5, 4, 3, WHITE)
	Art.px(img, int(sh3.x) - 1, int(sh3.y) - 4, INK)
	Art.px(img, int(sh3.x) + 1, int(sh3.y) - 4, INK)


static func _wall_right(img: Image, L: Dictionary) -> void:
	_wainscot(img, L, "Y", (L["room"] as Rect2).size.x)
	for t in [0.0, 4.6, 8.6, 11.65]:
		_beam(img, L, "Y", float(t))
	# 주방 벽타일(체스판)
	for ix in 11:
		for iy in 3:
			var tc: Color = Color(0.82, 0.85, 0.86) if (ix + iy) % 2 == 0 else Color(0.70, 0.74, 0.77)
			_pq(img, L, "Y", 0.0, 0.5 + float(ix) * 0.7, 0.5 + float(ix + 1) * 0.7, 11.0 + float(iy) * 5.0, 16.0 + float(iy) * 5.0, tc)
	# 환풍 후드와 덕트
	_pq(img, L, "Y", 0.0, 0.6, 4.6, 26.0, 33.0, STEEL_D)
	_pq(img, L, "Y", 0.0, 0.6, 4.6, 32.0, 33.0, STEEL)
	_pq(img, L, "Y", 0.0, 1.9, 3.3, 33.0, 40.0, STEEL_D.darkened(0.1))
	_pq(img, L, "Y", 0.0, 0.8, 4.4, 26.0, 27.0, Color(0.26, 0.28, 0.32))
	# 환풍기(둥근 팬)와 날개
	var fc: Vector2 = _p(L, 6.6, 0.0, 31.0)
	var ring: Array = []
	for k in 12:
		var ang: float = TAU * float(k) / 12.0
		ring.append(fc + Vector2(cos(ang) * 6.0, sin(ang) * 6.0))
	Art.poly(img, ring, STEEL_D)
	var inner: Array = []
	for k in 12:
		var ang2: float = TAU * float(k) / 12.0
		inner.append(fc + Vector2(cos(ang2) * 4.5, sin(ang2) * 4.5))
	Art.poly(img, inner, Color(0.20, 0.22, 0.26))
	Art.line(img, fc + Vector2(-4, -2), fc + Vector2(4, 2), STEEL)
	Art.line(img, fc + Vector2(-2, 4), fc + Vector2(2, -4), STEEL)
	# 조리도구 걸이: 프라이팬 둘, 국자, 거름망
	_pq(img, L, "Y", 0.0, 4.9, 6.2, 27.5, 28.2, STEEL_D)
	var hp: Vector2 = _p(L, 5.1, 0.0, 27.5)
	Art.line(img, hp, hp + Vector2(0, 6), STEEL_D)
	Art.rect(img, int(hp.x) - 3, int(hp.y) + 6, 7, 5, INK)
	Art.rect(img, int(hp.x) - 2, int(hp.y) + 7, 5, 3, Color(0.25, 0.25, 0.28))
	var hp2: Vector2 = _p(L, 5.7, 0.0, 27.5)
	Art.line(img, hp2, hp2 + Vector2(0, 8), STEEL_D)
	Art.rect(img, int(hp2.x) - 1, int(hp2.y) + 8, 3, 2, STEEL)
	Art.rect(img, int(hp2.x) - 3, int(hp2.y) + 10, 7, 4, STEEL)
	# 홀 쪽 벽: 창, 라멘 그림 액자, 세로 붉은 족자
	_pq(img, L, "Y", 0.0, 8.85, 9.9, 16.0, 29.0, WOOD_D)
	_pq(img, L, "Y", 0.0, 8.95, 9.8, 17.0, 28.0, GLASS)
	_pq(img, L, "Y", 0.0, 9.3, 9.4, 17.0, 28.0, WOOD_D)
	_pq(img, L, "Y", 0.0, 10.2, 11.2, 17.0, 27.0, WOOD_D)
	_pq(img, L, "Y", 0.0, 10.28, 11.12, 17.8, 26.2, Color(0.97, 0.88, 0.62))
	var bowl: Vector2 = _p(L, 10.7, 0.0, 20.0)
	Art.rect(img, int(bowl.x) - 3, int(bowl.y), 7, 3, RED)
	Art.rect(img, int(bowl.x) - 2, int(bowl.y) - 1, 5, 1, Color(0.96, 0.78, 0.40))
	Art.px(img, int(bowl.x), int(bowl.y) - 2, WHITE)
	_pq(img, L, "Y", 0.0, 11.3, 11.62, 8.0, 36.0, RED)
	_pq(img, L, "Y", 0.0, 11.3, 11.62, 35.0, 36.0, INK)
	_pq(img, L, "Y", 0.0, 11.38, 11.54, 28.0, 31.0, PAPER)
	_pq(img, L, "Y", 0.0, 11.38, 11.54, 22.0, 25.0, PAPER)
	_pq(img, L, "Y", 0.0, 11.38, 11.54, 16.0, 19.0, PAPER)


## 작은 화분 풀(창턱/선반용 장식).
static func _plant_small(img: Image, p: Vector2) -> void:
	Art.rect(img, int(p.x) - 2, int(p.y) - 3, 5, 3, TERRA)
	Art.rect(img, int(p.x) - 3, int(p.y) - 6, 7, 3, GREEN)
	Art.rect(img, int(p.x) - 1, int(p.y) - 8, 3, 2, GREEN_D)
	Art.px(img, int(p.x) + 2, int(p.y) - 7, PINK)


static func _lantern_up(img: Image, top: Vector2) -> void:
	var x: int = int(top.x)
	var y: int = int(top.y)
	Art.rect(img, x, y, 1, 3, INK)
	Art.rect(img, x - 2, y + 3, 5, 6, RED)
	Art.rect(img, x - 1, y + 4, 1, 4, Color(0.95, 0.45, 0.25))
	Art.rect(img, x - 2, y + 3, 5, 1, INK)
	Art.rect(img, x - 2, y + 8, 5, 1, INK)
	Art.px(img, x, y + 9, WARM)


# ---------- 깊이 정렬 항목(가구/소품/파사드) ----------

static func items(L: Dictionary) -> Array:
	var out: Array = []
	for f in L["furniture"]:
		var fd: Dictionary = f
		var r: Rect2 = fd["rect"]
		match str(fd["kind"]):
			"counter":
				# 윗면과 앞면이 y=3.8 면에 걸쳐 있다. 서버(뒤)와 손님(앞)이 각각 맞게 가려지도록 조각낸다.
				_emit_slices(out, L, fd, "", "Y", r.end.y, 0.0)
			"facade":
				_emit_slices(out, L, fd, "low", "Y", r.end.y, 0.0)
				# 지붕/간판/등롱은 물리적으로는 안쪽 손님을 가리지만, 복도 손님을 지우지 않도록 8만큼 일찍(=손님 뒤로) 그린다.
				_emit_slices(out, L, fd, "high", "Y", r.end.y, -8.0)
			"railing_x":
				_emit_slices(out, L, fd, "", "X", r.end.x, 0.0)
			"railing_y":
				_emit_slices(out, L, fd, "", "Y", r.end.y, 0.0)
			"neighbor_e":
				_emit(out, L, 0.0, str(fd["id"]), fd, "")
			_:
				_emit(out, L, r.get_center().x + r.end.y, str(fd["id"]), fd, "")
	# 좌석: 스툴/의자는 앉은 사람(깊이 같음)보다 0.05 먼저 그린다.
	var seats: Array = L["seats"]
	for i in seats.size():
		var sd: Dictionary = seats[i]
		var g: Vector2 = sd["grid"]
		var sf: Dictionary = {"kind": "stool" if str(sd["kind"]) == "counter" else "chair", "grid": g, "back": bool(sd["back"])}
		_emit(out, L, g.x + g.y - 0.05, "seat%d" % i, sf, "")
	# 카운터 위로 늘어진 등롱 세 개(사람 머리 위 높이 28 이상)
	for gx in [2.6, 5.0, 7.4]:
		var lf: Dictionary = {"kind": "hang_lantern", "grid": Vector2(float(gx), 3.3)}
		_emit(out, L, float(gx) + 3.3 + 1.5, "hang%d" % int(float(gx) * 10.0), lf, "")
	return out


## origin: img 의 (0,0) 이 장면 전체 좌표에서 어디인지. 조각(get_region)은 자기 지역 좌표를 가지므로 잘라 낸 위치를 반드시 더해
## 항목의 pos 가 항상 장면(전역) 픽셀 좌표가 되게 한다.
static func _push(out: Array, img: Image, depth: float, id: String, origin: Vector2 = Vector2.ZERO) -> void:
	var used: Rect2i = img.get_used_rect()
	if used.size.x <= 0 or used.size.y <= 0:
		return
	out.append({"depth": depth, "pos": Vector2(used.position) + origin, "img": img.get_region(used), "id": id, "n": out.size()})


static func _emit(out: Array, L: Dictionary, depth: float, id: String, f: Dictionary, part: String) -> void:
	var size: Vector2i = L["size"]
	var img: Image = Art.new_image(size.x, size.y)
	_draw(img, L, f, part)
	_push(out, img, depth, id)


## 긴 가구를 6px 폭 세로 조각으로 자른다. plane "Y"(앞면 y=c): 열 u=(x-ox)/8 의 앞면 점은 gx=u+c 이므로 깊이 = u+2c.
## plane "X"(앞면 x=c): gy=c-u 이므로 깊이 = 2c-u. depth_off 는 지붕처럼 일부러 앞뒤를 바꾸는 항목용 보정.
static func _emit_slices(out: Array, L: Dictionary, f: Dictionary, part: String, plane: String, c: float, depth_off: float) -> void:
	var size: Vector2i = L["size"]
	var o: Vector2 = L["origin"]
	var img: Image = Art.new_image(size.x, size.y)
	_draw(img, L, f, part)
	var used: Rect2i = img.get_used_rect()
	if used.size.x <= 0:
		return
	var sx: int = used.position.x
	while sx < used.end.x:
		var w: int = mini(6, used.end.x - sx)
		var piece: Image = img.get_region(Rect2i(sx, 0, w, size.y))
		var u: float = (float(sx) + float(w) * 0.5 - o.x) / float(L.get("half_w", Layouts.HALF_W))
		var depth: float = (u + 2.0 * c if plane == "Y" else 2.0 * c - u) + depth_off
		_push(out, piece, depth, "%s%s@%d" % [str(f["id"]), (":" + part) if part != "" else "", sx], Vector2(float(sx), 0.0))
		sx += w


static func _draw(img: Image, L: Dictionary, f: Dictionary, part: String) -> void:
	var r: Rect2 = f.get("rect", Rect2())
	match str(f["kind"]):
		"counter": _counter(img, L, r)
		"stove": _stove(img, L, r)
		"prep": _prep(img, L, r)
		"fridge": _fridge(img, L, r)
		"table": _table(img, L, r)
		"bench": _bench(img, L, r, WOOD_LL)
		"bench2": _bench(img, L, r, WOOD_L)
		"plant": _plant(img, L, r.get_center(), int(f["style"]))
		"railing_x": _railing(img, L, "X", r.end.x, 0.0, Layouts.ROOM_D)
		"railing_y": _railing(img, L, "Y", r.end.y, r.position.x, r.end.x)
		"facade":
			if part == "low":
				_facade_low(img, L)
			else:
				_facade_high(img, L)
		"stool": _stool(img, L, f["grid"])
		"chair": _chair(img, L, f["grid"], bool(f["back"]))
		"hang_lantern": _hang_lantern(img, L, f["grid"])
		"lantern_stand": _lantern_stand(img, L, r)
		"astand": _astand(img, L, r)
		"stall": _stall(img, L, r)
		"neighbor_e": _neighbor_e(img, L, r)
		"crates": _crates(img, L, r)
		"cat": _cat(img, L, r)
		"bike": _bike(img, L, r)
		"bin": _bin(img, L, r)
		"lamp": _lamp(img, L, r)
		"tree": _tree(img, L, r)
		"cart": _cart(img, L, r)
		"vending": _vending(img, L, r)


## 바닥 그림자(반투명). 가구 항목 안에서 먼저 그려 가구 아래에 깔린다.
static func _shadow(img: Image, L: Dictionary, x0: float, y0: float, x1: float, y1: float) -> void:
	_flat(img, L, x0 - 0.1, y0 - 0.1, x1 + 0.35, y1 + 0.35, 0.0, SHADOW)


static func _counter(img: Image, L: Dictionary, r: Rect2) -> void:
	var h: float = Layouts.COUNTER_H
	_shadow(img, L, r.position.x, r.position.y, r.end.x, r.end.y)
	_box(img, L, r.position.x, r.position.y, r.end.x, r.end.y, 0.0, h, WOOD_LL, WOOD_F, WOOD.darkened(0.1))
	# 윗면: gx 방향 널 이음 두 줄
	for k in 2:
		var yy: float = r.position.y + r.size.y * float(k + 1) / 3.0
		Art.line(img, _p(L, r.position.x + 0.05, yy, h), _p(L, r.end.x - 0.05, yy, h), WOOD_L)
	Art.line(img, _p(L, r.position.x, r.end.y, h), _p(L, r.end.x, r.end.y, h), Color(0.95, 0.78, 0.55))
	# 앞면: 발판(어두운 받침), 세로 판 이음, 손님 쪽 장식 띠
	_pq(img, L, "Y", r.end.y, r.position.x, r.end.x, 0.0, 2.0, WOOD_D)
	_pq(img, L, "Y", r.end.y, r.position.x, r.end.x, 9.5, 10.5, WOOD)
	var x: float = r.position.x + 0.9
	while x < r.end.x - 0.2:
		_pl(img, L, "Y", r.end.y, x, 2.0, x, 13.0, WOOD.darkened(0.15))
		x += 0.9
	# 카운터 위 소품(좌석 사이): 간장/후추, 젓가락통, 메뉴 슬립, 티슈
	var kinds: Array = [0, 1, 2]
	var xs: Array = [2.8, 4.6, 6.4]
	for i in 3:
		var p: Vector2 = _p(L, float(xs[i]), 3.05, h)
		var ix: int = int(p.x)
		var iy: int = int(p.y)
		match int(kinds[i]):
			0:
				Art.rect(img, ix - 3, iy - 6, 2, 6, Color(0.30, 0.16, 0.08))
				Art.rect(img, ix - 3, iy - 7, 2, 1, STEEL_D)
				Art.rect(img, ix, iy - 4, 2, 4, WHITE)
				Art.rect(img, ix, iy - 5, 2, 1, RED)
			1:
				Art.rect(img, ix - 2, iy - 5, 4, 5, WOOD_D)
				Art.rect(img, ix - 1, iy - 8, 1, 3, WOOD_LL)
				Art.rect(img, ix + 1, iy - 8, 1, 3, WOOD_LL)
			2:
				Art.rect(img, ix - 2, iy - 7, 5, 7, PAPER)
				Art.rect(img, ix - 1, iy - 5, 3, 1, INK)
				Art.rect(img, ix - 1, iy - 3, 3, 1, RED)
	var t: Vector2 = _p(L, 1.3, 3.2, h)
	Art.rect(img, int(t.x) - 2, int(t.y) - 3, 5, 3, WHITE)
	Art.rect(img, int(t.x) - 2, int(t.y) - 3, 5, 1, STEEL)
	var m: Vector2 = _p(L, 8.0, 3.1, h)
	Art.rect(img, int(m.x) - 2, int(m.y) - 4, 4, 4, Color(0.85, 0.72, 0.30))
	Art.rect(img, int(m.x) - 2, int(m.y) - 5, 4, 1, STEEL_D)


static func _pot_up(img: Image, p: Vector2, broth: Color) -> void:
	var x: int = int(p.x)
	var y: int = int(p.y)
	Art.rect(img, x - 6, y - 9, 12, 9, STEEL)
	Art.rect(img, x - 6, y - 2, 12, 2, STEEL_D)
	Art.rect(img, x - 7, y - 10, 14, 2, STEEL_D)
	Art.rect(img, x - 5, y - 11, 10, 2, broth)
	Art.rect(img, x - 9, y - 7, 3, 2, STEEL_D)
	Art.rect(img, x + 6, y - 7, 3, 2, STEEL_D)
	Art.rect(img, x - 4, y - 8, 1, 5, WHITE)
	Art.px(img, x + 2, y - 11, WHITE)


static func _stove(img: Image, L: Dictionary, r: Rect2) -> void:
	var h: float = Layouts.STOVE_H
	_shadow(img, L, r.position.x, r.position.y, r.end.x, r.end.y)
	_box(img, L, r.position.x, r.position.y, r.end.x, r.end.y, 0.0, h, STEEL, STEEL_D, STEEL_D.darkened(0.25))
	# 앞면: 불구멍(주황 불꽃)과 손잡이
	for gx in [1.3, 2.8]:
		var p: Vector2 = _p(L, float(gx), r.end.y, 3.0)
		Art.rect(img, int(p.x) - 4, int(p.y) - 1, 8, 5, INK)
		Art.rect(img, int(p.x) - 3, int(p.y) + 1, 6, 3, Color(0.95, 0.55, 0.15))
		Art.rect(img, int(p.x) - 1, int(p.y) + 1, 2, 2, Color(1.0, 0.88, 0.40))
	for k in 4:
		var kp: Vector2 = _p(L, r.position.x + 0.4 + float(k) * 0.9, r.end.y, 9.0)
		Art.rect(img, int(kp.x), int(kp.y), 2, 2, RED if k % 2 == 0 else INK)
	# 곰탕 솥 둘(곰탕/닭 육수 색)과 면 삶는 통
	_pot_up(img, _p(L, 1.3, 0.55, h), Color(0.95, 0.88, 0.74))
	_pot_up(img, _p(L, 2.8, 0.55, h), Color(0.88, 0.68, 0.30))
	_box(img, L, 3.45, 0.1, 4.4, 0.95, h, h + 8.0, Color(0.55, 0.78, 0.88), STEEL, STEEL_D)
	var bt: Vector2 = _p(L, 3.9, 0.55, h + 8.0)
	Art.rect(img, int(bt.x) - 4, int(bt.y) - 1, 8, 2, Color(0.97, 0.9, 0.62))
	Art.line(img, bt + Vector2(-3, 0), bt + Vector2(-7, -5), STEEL_D)
	Art.line(img, bt + Vector2(3, 0), bt + Vector2(7, -5), STEEL_D)
	Art.rect(img, int(bt.x) - 8, int(bt.y) - 6, 3, 1, INK)
	Art.rect(img, int(bt.x) + 6, int(bt.y) - 6, 3, 1, INK)


static func _prep(img: Image, L: Dictionary, r: Rect2) -> void:
	var h: float = Layouts.PREP_H
	_shadow(img, L, r.position.x, r.position.y, r.end.x, r.end.y)
	_box(img, L, r.position.x, r.position.y, r.end.x, r.end.y, 0.0, h, STEEL, Color(0.64, 0.67, 0.71), STEEL_D)
	_pl(img, L, "Y", r.end.y, r.position.x + 0.9, 0.5, r.position.x + 0.9, h - 1.0, STEEL_D)
	for k in 2:
		var hp: Vector2 = _p(L, r.position.x + 0.65 + float(k) * 0.5, r.end.y, 6.0)
		Art.rect(img, int(hp.x), int(hp.y), 1, 3, INK)
	# 고명 트레이(대파/차슈/멘마)와 그릇 더미
	var colors: Array = [Color(0.45, 0.72, 0.32), Color(0.85, 0.58, 0.50), Color(0.85, 0.66, 0.30)]
	for k in 3:
		var x: float = 5.1 + float(k) * 0.55
		var tc: Color = colors[k]
		_box(img, L, x, 0.3, x + 0.45, 0.6, h, h + 1.3, tc.lightened(0.15), tc, tc.darkened(0.25))
	var bp: Vector2 = _p(L, 6.45, 0.9, h)
	for k in 3:
		Art.rect(img, int(bp.x) - 4, int(bp.y) - 3 - k * 2, 8, 3, WHITE)
		Art.rect(img, int(bp.x) - 4, int(bp.y) - 2 - k * 2, 8, 1, RED)


static func _fridge(img: Image, L: Dictionary, r: Rect2) -> void:
	_shadow(img, L, r.position.x, r.position.y, r.end.x, r.end.y)
	_box(img, L, r.position.x, r.position.y, r.end.x, r.end.y, 0.0, r.size.y * 0.0 + 30.0, STEEL, Color(0.80, 0.83, 0.85), STEEL_D)
	var xm: float = (r.position.x + r.end.x) * 0.5
	_pl(img, L, "Y", r.end.y, xm, 0.0, xm, 30.0, STEEL_D)
	_pl(img, L, "Y", r.end.y, r.position.x, 19.0, r.end.x, 19.0, STEEL_D)
	for gx in [xm - 0.12, xm + 0.12]:
		var hp: Vector2 = _p(L, float(gx), r.end.y, 22.0)
		Art.rect(img, int(hp.x), int(hp.y), 1, 4, INK)
	var np: Vector2 = _p(L, r.position.x + 0.3, r.end.y, 26.0)
	Art.rect(img, int(np.x), int(np.y), 3, 4, PAPER)
	Art.px(img, int(np.x) + 1, int(np.y) + 1, RED)


static func _table(img: Image, L: Dictionary, r: Rect2) -> void:
	_shadow(img, L, r.position.x, r.position.y, r.end.x, r.end.y)
	var legs: Array = [Vector2(r.position.x + 0.05, r.position.y + 0.05), Vector2(r.end.x - 0.17, r.position.y + 0.05), Vector2(r.position.x + 0.05, r.end.y - 0.17), Vector2(r.end.x - 0.17, r.end.y - 0.17)]
	for lg in legs:
		var lv: Vector2 = lg
		_box(img, L, lv.x, lv.y, lv.x + 0.12, lv.y + 0.12, 0.0, 9.5, WOOD, WOOD, WOOD_D)
	_box(img, L, r.position.x + 0.05, r.position.y + 0.05, r.end.x - 0.05, r.end.y - 0.05, 8.0, 9.5, WOOD, WOOD, WOOD_D)
	_box(img, L, r.position.x, r.position.y, r.end.x, r.end.y, 9.5, Layouts.TABLE_H, WOOD_LL, WOOD_F, WOOD.darkened(0.1))
	var cx: float = r.get_center().x
	var cy: float = r.get_center().y
	# 상판 가운데: 젓가락통, 간장병, 메뉴 슬립
	var p: Vector2 = _p(L, cx, cy, Layouts.TABLE_H)
	var ix: int = int(p.x)
	var iy: int = int(p.y)
	Art.rect(img, ix - 2, iy - 4, 4, 4, WOOD_D)
	Art.rect(img, ix - 1, iy - 7, 1, 3, WOOD_LL)
	Art.rect(img, ix + 1, iy - 7, 1, 3, WOOD_LL)
	Art.rect(img, ix + 3, iy - 4, 2, 4, Color(0.30, 0.16, 0.08))
	Art.rect(img, ix + 3, iy - 5, 2, 1, STEEL_D)
	Art.rect(img, ix - 6, iy - 4, 3, 5, PAPER)
	Art.px(img, ix - 5, iy - 2, RED)


static func _bench(img: Image, L: Dictionary, r: Rect2, top: Color) -> void:
	_shadow(img, L, r.position.x, r.position.y, r.end.x, r.end.y)
	var h: float = 6.0
	for gy in [r.position.y + 0.05, r.end.y - 0.17]:
		for gx in [r.position.x + 0.03, r.end.x - 0.13]:
			_box(img, L, float(gx), float(gy), float(gx) + 0.1, float(gy) + 0.12, 0.0, h - 1.5, WOOD, WOOD_D, WOOD_D)
	_box(img, L, r.position.x, r.position.y, r.end.x, r.end.y, h - 1.5, h, top, WOOD_F, WOOD.darkened(0.1))
	var along_x: bool = r.size.x > r.size.y
	var slats: int = int((r.size.x if along_x else r.size.y) / 0.35)
	for k in range(1, slats):
		if along_x:
			var xx: float = r.position.x + float(k) * 0.35
			Art.line(img, _p(L, xx, r.position.y, h), _p(L, xx, r.end.y, h), WOOD_L)
		else:
			var yy: float = r.position.y + float(k) * 0.35
			Art.line(img, _p(L, r.position.x, yy, h), _p(L, r.end.x, yy, h), WOOD_L)
	if r.size.x < r.size.y:
		# 대기 의자 위 붉은 방석
		var c: Vector2 = _p(L, r.get_center().x, r.position.y + 0.5, h)
		Art.rect(img, int(c.x) - 3, int(c.y) - 2, 6, 3, RED)
		Art.rect(img, int(c.x) - 2, int(c.y) - 3, 4, 1, Color(0.88, 0.36, 0.22))


static func _plant(img: Image, L: Dictionary, c: Vector2, style: int) -> void:
	var p: Vector2 = _p(L, c.x, c.y)
	var x: int = int(p.x)
	var y: int = int(p.y)
	Art.poly(img, [Vector2(x - 6, y - 1), Vector2(x + 6, y - 1), Vector2(x + 3, y + 2), Vector2(x - 3, y + 2)], SHADOW)
	Art.rect(img, x - 4, y - 7, 8, 7, TERRA)
	Art.rect(img, x - 5, y - 8, 10, 2, Color(0.82, 0.48, 0.30))
	Art.rect(img, x - 4, y - 2, 8, 1, TERRA.darkened(0.25))
	match style:
		0:
			Art.rect(img, x - 6, y - 17, 12, 9, GREEN)
			Art.rect(img, x - 4, y - 21, 8, 4, GREEN)
			Art.rect(img, x - 6, y - 12, 4, 3, GREEN_D)
			Art.rect(img, x + 2, y - 16, 4, 3, GREEN_D)
			Art.px(img, x - 1, y - 19, Color(0.55, 0.75, 0.40))
		1:
			for k in 5:
				Art.rect(img, x - 4 + k * 2, y - 22 + (k % 2) * 4, 1, 14 - (k % 2) * 4, GREEN)
				Art.rect(img, x - 5 + k * 2, y - 23 + (k % 2) * 4, 3, 2, GREEN_D)
		_:
			Art.rect(img, x - 5, y - 15, 10, 7, GREEN)
			Art.rect(img, x - 3, y - 18, 6, 3, GREEN)
			for k in 4:
				Art.rect(img, x - 4 + k * 3, y - 17 + (k % 2) * 3, 2, 2, PINK)
				Art.px(img, x - 4 + k * 3, y - 17 + (k % 2) * 3, WHITE)


static func _railing(img: Image, L: Dictionary, plane: String, c: float, t0: float, t1: float) -> void:
	var t: float = t0
	while t <= t1 + 0.01:
		_pl(img, L, plane, c, t, 0.0, t, 8.0, WOOD_D)
		_pl(img, L, plane, c, t + 0.0, 0.0, t, 7.0, WOOD_D)
		t += 1.0
	_pq(img, L, plane, c, t0, t1, 6.5, 8.0, WOOD_L)
	_pq(img, L, plane, c, t0, t1, 3.2, 3.9, WOOD)
	_pl(img, L, plane, c, t0, 8.0, t1, 8.0, WOOD_LL)


static func _stool(img: Image, L: Dictionary, g: Vector2) -> void:
	var c: Vector2 = _p(L, g.x, g.y, 5.0)
	var f: Vector2 = _p(L, g.x, g.y)
	Art.poly(img, [f + Vector2(-6, 0), f + Vector2(0, -3), f + Vector2(6, 0), f + Vector2(0, 3)], SHADOW)
	for dx in [-3, 3]:
		Art.rect(img, int(f.x) + int(dx), int(c.y) + 2, 1, int(f.y) - int(c.y) - 1, WOOD_D)
	Art.rect(img, int(f.x) - 3, int(f.y) - 2, 7, 1, WOOD_D)
	Art.poly(img, [c + Vector2(-5, 0), c + Vector2(-3, 2), c + Vector2(3, 2), c + Vector2(5, 0), c + Vector2(5, 2), c + Vector2(3, 4), c + Vector2(-3, 4), c + Vector2(-5, 2)], RED_D)
	Art.poly(img, [c + Vector2(-5, 0), c + Vector2(-3, -2), c + Vector2(3, -2), c + Vector2(5, 0), c + Vector2(3, 2), c + Vector2(-3, 2)], Color(0.88, 0.36, 0.22))


## 의자: 등받이는 앉은 사람 뒤쪽(back=true 면 사람이 등을 보이므로 화면 앞쪽 gy+)에 선다.
static func _chair(img: Image, L: Dictionary, g: Vector2, back: bool) -> void:
	var f: Vector2 = _p(L, g.x, g.y)
	Art.poly(img, [f + Vector2(-8, 0), f + Vector2(0, -4), f + Vector2(8, 0), f + Vector2(0, 4)], SHADOW)
	var side: float = 1.0 if back else -1.0
	var chair_top: Color = Color(0.66, 0.42, 0.22)
	var chair_side: Color = Color(0.57, 0.35, 0.18)
	for lx in [-0.35, 0.25]:
		for ly in [-0.35, 0.25]:
			_box(img, L, g.x + float(lx), g.y + float(ly), g.x + float(lx) + 0.1, g.y + float(ly) + 0.1, 0.0, 4.5, WOOD, WOOD_D, WOOD_D)
	if side < 0.0:
		_box(img, L, g.x - 0.4, g.y - 0.45, g.x + 0.4, g.y - 0.35, 5.0, 15.0, chair_top, chair_side, WOOD_D)
	_box(img, L, g.x - 0.4, g.y - 0.4, g.x + 0.4, g.y + 0.4, 4.0, 5.2, chair_top.lightened(0.1), chair_side, WOOD_D)
	if side > 0.0:
		_box(img, L, g.x - 0.4, g.y + 0.35, g.x + 0.4, g.y + 0.45, 5.0, 13.0, chair_top, chair_side, WOOD_D)


static func _hang_lantern(img: Image, L: Dictionary, g: Vector2) -> void:
	var top: Vector2 = _p(L, g.x, g.y, 34.0)
	Art.line(img, _p(L, g.x, g.y, Layouts.WALL_H), top, INK)
	_lantern_up(img, top)


static func _facade_low(img: Image, L: Dictionary) -> void:
	var y0: float = Layouts.FACADE.position.y
	var y1: float = Layouts.FACADE.end.y
	var gap: Vector2 = Layouts.DOOR_GAP
	var x1: float = Layouts.FACADE.end.x
	for seg in [Vector2(0.0, gap.x), Vector2(gap.y, x1)]:
		var s: Vector2 = seg
		_shadow(img, L, s.x, y0, s.y, y1)
		_box(img, L, s.x, y0, s.y, y1, 0.0, 11.0, WOOD_LL, WOOD_F, WOOD.darkened(0.1))
		_pq(img, L, "Y", y1, s.x, s.y, 0.0, 3.0, Color(0.52, 0.50, 0.48))
		var t: float = s.x + 0.6
		while t < s.y:
			_pl(img, L, "Y", y1, t, 3.0, t, 11.0, WOOD.darkened(0.2))
			t += 0.6
	# 기둥(문 양옆, 양끝)
	for px in [0.0, gap.x - 0.15, gap.y - 0.05, x1 - 0.4]:
		var w: float = 0.4 if (float(px) == 0.0 or float(px) == x1 - 0.4) else 0.2
		_box(img, L, float(px), y1 - 0.4, float(px) + w, y1, 0.0, 29.0, WOOD_F, WOOD_D.lightened(0.1), WOOD_D)
	# 노렌: 세 폭(틈이 있어 지나가는 손님이 조금 보임)
	var span: float = (gap.y - gap.x - 0.2) / 3.0
	for k in 3:
		var a: float = gap.x + 0.1 + float(k) * span + 0.04
		var b: float = a + span - 0.08
		_pq(img, L, "Y", y1 + 0.05, a, b, 15.0, 22.0, RED)
		_pq(img, L, "Y", y1 + 0.05, a, b, 15.0, 16.0, RED_D)
		_pq(img, L, "Y", y1 + 0.05, a + span * 0.35, b - span * 0.35, 18.0, 20.0, PAPER)


static func _facade_high(img: Image, L: Dictionary) -> void:
	var y1: float = Layouts.FACADE.end.y
	var x1: float = Layouts.FACADE.end.x + 0.3
	# 처마: 뒤쪽(gy 9.7, 높이 26)에서 앞쪽(gy 10.4, 높이 21)으로 기운 기와 슬래브. 높이를 낮게 잡아 안쪽 복도를 덜 가린다.
	Art.poly(img, [_p(L, -0.2, y1, 26.0), _p(L, x1, y1, 26.0), _p(L, x1, 10.4, 21.0), _p(L, -0.2, 10.4, 21.0)], ROOF)
	var x: float = -0.2
	while x < x1:
		Art.line(img, _p(L, x, y1, 26.0), _p(L, x, 10.4, 21.0), ROOF_L)
		x += 0.5
	Art.line(img, _p(L, -0.2, y1, 26.0), _p(L, x1, y1, 26.0), INK)
	_pq(img, L, "Y", 10.4, -0.2, x1, 19.0, 21.0, ROOF.darkened(0.2))
	var s: float = -0.2
	while s < x1:
		_pq(img, L, "Y", 10.4, s, s + 0.25, 18.0, 19.0, ROOF.darkened(0.2))
		s += 0.5
	Art.poly(img, [_p(L, x1, y1, 26.0), _p(L, x1, 10.4, 21.0), _p(L, x1, 10.4, 19.0), _p(L, x1, y1, 24.0)], ROOF.darkened(0.35))
	# 간판: 지붕 위 나무판 + 받침 두 개. 글씨는 쓰지 않고 가운데 김 나는 붉은 그릇(젓가락 한 쌍), 양끝 붉은 인장 문양만 둔다.
	# 움직이는 김은 ShopView 가 sign_emblem_anchor() 위치에 얹는다(이 이미지에는 짧은 정적 김만 있다).
	for t in [1.4, 6.6]:
		_pq(img, L, "Y", 9.85, float(t), float(t) + 0.15, 26.0, 30.0, WOOD_D)
	_pq(img, L, "Y", 9.85, 0.8, 7.2, 29.0, 41.0, WOOD_D)
	_pq(img, L, "Y", 9.85, 0.95, 7.05, 30.0, 40.0, WOOD_LL)
	_pq(img, L, "Y", 9.85, 0.95, 7.05, 39.0, 40.0, Color(0.92, 0.74, 0.50))
	_pq(img, L, "Y", 9.85, 0.95, 7.05, 30.0, 31.0, RED_D)
	for seal_x in [1.2, 6.0]:
		var sx: float = float(seal_x)
		_pq(img, L, "Y", 9.85, sx, sx + 0.8, 32.0, 38.0, RED)
		_pq(img, L, "Y", 9.85, sx + 0.2, sx + 0.6, 33.5, 36.5, PAPER)
		_pq(img, L, "Y", 9.85, sx + 0.3, sx + 0.5, 34.5, 35.5, RED)
	_pq(img, L, "Y", 9.85, 3.65, 4.35, 31.0, 32.0, INK)
	_pq(img, L, "Y", 9.85, 3.2, 4.8, 32.0, 35.0, RED)
	_pq(img, L, "Y", 9.85, 3.2, 4.8, 32.0, 33.0, RED_D)
	_pq(img, L, "Y", 9.85, 3.1, 4.9, 35.0, 36.0, WARM)
	_pq(img, L, "Y", 9.85, 3.1, 4.9, 35.0, 35.5, Color(0.92, 0.74, 0.40))
	_pl(img, L, "Y", 9.85, 4.55, 36.0, 5.8, 39.0, WOOD_D)
	_pl(img, L, "Y", 9.85, 4.85, 36.0, 6.0, 38.5, WOOD_D)
	for wx in [3.5, 4.0]:
		_pq(img, L, "Y", 9.85, float(wx), float(wx) + 0.1, 37.0, 38.5, WHITE)
	# 처마 밑 등롱
	_lantern_up(img, _p(L, 2.9, 10.15, 18.0) - Vector2(0, 0))
	_lantern_up(img, _p(L, 5.3, 10.15, 18.0))


static func _lantern_stand(img: Image, L: Dictionary, r: Rect2) -> void:
	var c: Vector2 = r.get_center()
	var f: Vector2 = _p(L, c.x, c.y)
	Art.poly(img, [f + Vector2(-6, 0), f + Vector2(0, -3), f + Vector2(6, 0), f + Vector2(0, 3)], SHADOW)
	Art.line(img, f + Vector2(-5, 0), f + Vector2(-1, -14), WOOD_D)
	Art.line(img, f + Vector2(5, 0), f + Vector2(1, -14), WOOD_D)
	Art.line(img, f + Vector2(0, 2), f + Vector2(0, -14), WOOD_D)
	var x: int = int(f.x)
	var y: int = int(f.y) - 26
	Art.rect(img, x - 5, y, 10, 14, RED)
	Art.rect(img, x - 4, y + 1, 2, 12, Color(0.95, 0.45, 0.25))
	Art.rect(img, x - 5, y, 10, 2, INK)
	Art.rect(img, x - 5, y + 12, 10, 2, INK)
	Art.rect(img, x - 2, y + 4, 5, 2, PAPER)
	Art.rect(img, x - 1, y + 6, 3, 1, PAPER)
	Art.rect(img, x - 2, y + 8, 5, 2, PAPER)


static func _astand(img: Image, L: Dictionary, r: Rect2) -> void:
	_shadow(img, L, r.position.x, r.position.y + 0.2, r.end.x, r.end.y)
	var y: float = r.end.y - 0.1
	_pq(img, L, "Y", y - 0.4, r.position.x + 0.1, r.end.x - 0.1, 0.0, 13.0, WOOD_D)
	_pq(img, L, "Y", y, r.position.x + 0.05, r.end.x - 0.05, 0.0, 14.0, WOOD_L)
	_pq(img, L, "Y", y, r.position.x + 0.15, r.end.x - 0.15, 2.0, 12.0, WOOD_LL)
	_pq(img, L, "Y", y, r.position.x + 0.05, r.end.x - 0.05, 13.0, 14.0, WOOD_D)


static func _stall(img: Image, L: Dictionary, r: Rect2) -> void:
	_shadow(img, L, r.position.x, r.position.y, r.end.x, r.end.y)
	_box(img, L, r.position.x, r.position.y, r.end.x, r.end.y, 0.0, 10.0, WOOD_LL, WOOD_F, WOOD.darkened(0.1))
	_pq(img, L, "Y", r.end.y, r.position.x, r.end.x, 0.0, 2.0, WOOD_D)
	for gx in [r.position.x + 0.1, r.end.x - 0.2]:
		for gy in [r.position.y + 0.1, r.end.y - 0.2]:
			_box(img, L, float(gx), float(gy), float(gx) + 0.1, float(gy) + 0.1, 10.0, 27.0, WOOD_D, WOOD_D, WOOD_D.darkened(0.2))
	# 줄무늬 천막(붉은색/흰색 번갈아)
	var k: int = 0
	var x: float = r.position.x - 0.3
	while x < r.end.x + 0.3:
		var x2: float = minf(x + 0.5, r.end.x + 0.3)
		Art.poly(img, [_p(L, x, r.position.y - 0.2, 29.0), _p(L, x2, r.position.y - 0.2, 29.0), _p(L, x2, r.end.y + 0.4, 23.0), _p(L, x, r.end.y + 0.4, 23.0)], RED if k % 2 == 0 else WHITE)
		k += 1
		x = x2
	Art.line(img, _p(L, r.position.x - 0.3, r.end.y + 0.4, 23.0), _p(L, r.end.x + 0.3, r.end.y + 0.4, 23.0), RED_D)
	# 상판 위 꼬치/항아리, 앞 칠판
	var jp: Vector2 = _p(L, r.position.x + 0.8, r.position.y + 1.0, 10.0)
	Art.rect(img, int(jp.x) - 2, int(jp.y) - 5, 5, 5, Color(0.74, 0.50, 0.22))
	Art.rect(img, int(jp.x) - 2, int(jp.y) - 6, 5, 1, STEEL_D)
	for q in 4:
		var sp: Vector2 = _p(L, r.position.x + 1.6 + float(q) * 0.25, r.position.y + 1.3, 10.0)
		Art.rect(img, int(sp.x), int(sp.y) - 5, 1, 5, WOOD_LL)
		Art.rect(img, int(sp.x), int(sp.y) - 6, 1, 2, Color(0.80, 0.45, 0.30))
	_pq(img, L, "Y", r.end.y + 0.02, r.position.x + 0.3, r.position.x + 1.3, 2.5, 9.0, INK)
	_pq(img, L, "Y", r.end.y + 0.02, r.position.x + 0.4, r.position.x + 1.2, 3.5, 8.0, Color(0.20, 0.26, 0.22))
	_pl(img, L, "Y", r.end.y + 0.02, r.position.x + 0.5, 7.0, r.position.x + 1.1, 7.0, WHITE)
	_pl(img, L, "Y", r.end.y + 0.02, r.position.x + 0.5, 5.2, r.position.x + 1.0, 5.2, WHITE)
	_lantern_up(img, _p(L, r.end.x - 0.3, r.end.y + 0.2, 23.0))


static func _neighbor_e(img: Image, L: Dictionary, r: Rect2) -> void:
	_box(img, L, r.position.x, r.position.y, r.end.x, r.end.y, 0.0, 44.0, ROOF, PLASTER_D, PLASTER_D.darkened(0.2))
	_tile_roof(img, L, r.position.x, r.end.x, r.position.y, r.end.y, 44.0, false)
	_pq(img, L, "Y", r.end.y, r.position.x, r.end.x, 36.0, 44.0, ROOF.darkened(0.15))
	_pq(img, L, "Y", r.end.y, r.position.x, r.end.x, 35.0, 36.0, WOOD_D)
	for k in 3:
		var t: float = r.position.x + 1.0 + float(k) * 2.8
		_pq(img, L, "Y", r.end.y, t, t + 1.5, 14.0, 28.0, WOOD_D)
		_pq(img, L, "Y", r.end.y, t + 0.1, t + 1.4, 15.0, 27.0, WARM)
		_pq(img, L, "Y", r.end.y, t + 0.7, t + 0.8, 15.0, 27.0, WOOD_D)
		_pq(img, L, "Y", r.end.y, t, t + 1.5, 12.5, 14.0, WOOD_L)


static func _crates(img: Image, L: Dictionary, r: Rect2) -> void:
	_shadow(img, L, r.position.x, r.position.y, r.end.x, r.end.y)
	_box(img, L, r.position.x, r.position.y, r.end.x, r.end.y, 0.0, 5.0, WOOD_LL, WOOD_L, WOOD.darkened(0.1))
	_box(img, L, r.position.x + 0.1, r.position.y + 0.1, r.end.x - 0.4, r.end.y - 0.1, 5.0, 9.0, WOOD_LL, WOOD_F, WOOD.darkened(0.1))
	_pl(img, L, "Y", r.end.y, r.position.x, 2.5, r.end.x, 2.5, WOOD_D)
	var gp: Vector2 = _p(L, r.position.x + 0.5, r.position.y + 0.4, 9.0)
	Art.rect(img, int(gp.x) - 1, int(gp.y) - 3, 3, 3, Color(0.85, 0.40, 0.20))
	Art.px(img, int(gp.x), int(gp.y) - 4, GREEN)


static func _cat(img: Image, L: Dictionary, r: Rect2) -> void:
	var p: Vector2 = _p(L, r.get_center().x, r.get_center().y)
	var x: int = int(p.x)
	var y: int = int(p.y)
	Art.rect(img, x - 5, y - 5, 10, 5, Color(0.90, 0.60, 0.28))
	Art.rect(img, x - 4, y - 6, 8, 1, Color(0.90, 0.60, 0.28))
	Art.rect(img, x - 1, y - 6, 3, 4, WHITE)
	Art.rect(img, x - 5, y - 4, 3, 2, INK)
	Art.rect(img, x + 3, y - 7, 3, 3, Color(0.90, 0.60, 0.28))
	Art.px(img, x + 3, y - 8, INK)
	Art.px(img, x + 5, y - 8, INK)
	Art.rect(img, x - 7, y - 2, 3, 1, Color(0.90, 0.60, 0.28))


static func _wheel(img: Image, c: Vector2, rad: float) -> void:
	var prev: Vector2 = c + Vector2(rad, 0.0)
	for k in range(1, 17):
		var a: float = TAU * float(k) / 16.0
		var q: Vector2 = c + Vector2(cos(a) * rad, sin(a) * rad)
		Art.line(img, prev, q, INK)
		prev = q
	Art.px(img, int(c.x), int(c.y), STEEL_D)


static func _bike(img: Image, L: Dictionary, r: Rect2) -> void:
	var rear: Vector2 = _p(L, r.position.x + 0.2, r.get_center().y, 5.0)
	var front: Vector2 = _p(L, r.end.x - 0.2, r.get_center().y, 5.0)
	var blue: Color = Color(0.25, 0.45, 0.78)
	_wheel(img, rear, 5.0)
	_wheel(img, front, 5.0)
	var mid: Vector2 = rear.lerp(front, 0.45) + Vector2(0, -6)
	Art.line(img, rear, mid, blue)
	Art.line(img, mid, front, blue)
	Art.line(img, rear, rear.lerp(front, 0.45), blue)
	Art.line(img, front, front + Vector2(-1, -9), blue)
	Art.line(img, front + Vector2(-3, -9), front + Vector2(2, -9), INK)
	Art.rect(img, int(mid.x) - 2, int(mid.y) - 3, 5, 2, INK)
	Art.rect(img, int(front.x) - 4, int(front.y) - 8, 4, 3, WOOD_L)


static func _bin(img: Image, L: Dictionary, r: Rect2) -> void:
	_shadow(img, L, r.position.x, r.position.y, r.end.x, r.end.y)
	_box(img, L, r.position.x, r.position.y, r.end.x, r.end.y, 0.0, 9.0, STEEL, Color(0.45, 0.58, 0.50), Color(0.32, 0.43, 0.36))
	_pl(img, L, "Y", r.end.y, r.position.x, 6.0, r.end.x, 6.0, Color(0.25, 0.33, 0.28))


static func _lamp(img: Image, L: Dictionary, r: Rect2) -> void:
	var f: Vector2 = _p(L, r.get_center().x, r.get_center().y)
	var x: int = int(f.x)
	Art.rect(img, x - 1, int(f.y) - 40, 2, 40, Color(0.17, 0.17, 0.21))
	Art.rect(img, x - 3, int(f.y) - 2, 6, 2, Color(0.17, 0.17, 0.21))
	Art.rect(img, x - 4, int(f.y) - 47, 8, 7, Color(0.17, 0.17, 0.21))
	Art.rect(img, x - 3, int(f.y) - 46, 6, 5, WARM)
	Art.px(img, x - 2, int(f.y) - 45, WHITE)


static func _tree(img: Image, L: Dictionary, r: Rect2) -> void:
	var f: Vector2 = _p(L, r.get_center().x, r.get_center().y)
	var x: int = int(f.x)
	var y: int = int(f.y)
	Art.poly(img, [f + Vector2(-9, 0), f + Vector2(0, -4), f + Vector2(9, 0), f + Vector2(0, 4)], SHADOW)
	Art.rect(img, x - 6, y - 5, 12, 5, TERRA)
	Art.rect(img, x - 1, y - 20, 3, 15, Color(0.36, 0.22, 0.14))
	for blob in [Vector3(-8, -26, 8), Vector3(5, -28, 8), Vector3(-2, -33, 9), Vector3(-9, -20, 6), Vector3(8, -21, 6)]:
		var b: Vector3 = blob
		var bx: int = x + int(b.x)
		var by: int = y + int(b.y)
		var rad: int = int(b.z)
		Art.rect(img, bx - rad, by - rad / 2, rad * 2, rad, PINK)
		Art.rect(img, bx - rad + 2, by - rad / 2 - 2, rad * 2 - 4, rad + 4, PINK)
		Art.rect(img, bx - rad + 2, by + 1, 3, 2, Color(0.95, 0.60, 0.72))
		Art.px(img, bx + 1, by - 2, WHITE)


static func _cart(img: Image, L: Dictionary, r: Rect2) -> void:
	_shadow(img, L, r.position.x, r.position.y, r.end.x, r.end.y)
	_box(img, L, r.position.x, r.position.y, r.end.x, r.end.y, 3.0, 10.0, WOOD_LL, WOOD_F, WOOD.darkened(0.1))
	for gx in [r.position.x + 0.3, r.end.x - 0.3]:
		_wheel(img, _p(L, float(gx), r.end.y, 3.0), 3.0)
	var k: int = 0
	var x: float = r.position.x
	while x < r.end.x:
		var x2: float = minf(x + 0.45, r.end.x)
		Art.poly(img, [_p(L, x, r.position.y, 20.0), _p(L, x2, r.position.y, 20.0), _p(L, x2, r.end.y, 16.0), _p(L, x, r.end.y, 16.0)], RED if k % 2 == 0 else WHITE)
		k += 1
		x = x2
	for gx in [r.position.x + 0.1, r.end.x - 0.15]:
		_pl(img, L, "Y", r.end.y - 0.05, float(gx), 10.0, float(gx), 16.0, WOOD_D)
	var jp: Vector2 = _p(L, r.position.x + 0.8, r.position.y + 0.45, 10.0)
	Art.rect(img, int(jp.x) - 2, int(jp.y) - 4, 5, 4, Color(0.74, 0.50, 0.22))
	Art.rect(img, int(jp.x) + 5, int(jp.y) - 3, 4, 3, WHITE)


static func _vending(img: Image, L: Dictionary, r: Rect2) -> void:
	_shadow(img, L, r.position.x, r.position.y, r.end.x, r.end.y)
	_box(img, L, r.position.x, r.position.y, r.end.x, r.end.y, 0.0, 26.0, Color(0.85, 0.30, 0.25), Color(0.80, 0.26, 0.22), Color(0.55, 0.16, 0.14))
	_pq(img, L, "Y", r.end.y, r.position.x + 0.1, r.end.x - 0.1, 8.0, 23.0, Color(0.90, 0.95, 0.98))
	for k in 3:
		var p: Vector2 = _p(L, r.position.x + 0.2 + float(k) * 0.25, r.end.y, 18.0)
		Art.rect(img, int(p.x), int(p.y), 2, 4, [Color(0.3, 0.6, 0.9), Color(0.9, 0.5, 0.2), Color(0.4, 0.8, 0.4)][k])
	var s: Vector2 = _p(L, r.get_center().x, r.end.y, 3.0)
	Art.rect(img, int(s.x) - 2, int(s.y), 4, 2, INK)
