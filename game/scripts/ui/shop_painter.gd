extends RefCounted
## 매장 정적 배경을 한 장의 작은 이미지(논리 픽셀)로 한 번만 찍는다: 지붕, 벽, 주방, 카운터, 바닥, 가구, 문, 골목.
## 움직이는 것(사람, 그릇, 김, 말풍선)은 ShopView 가 이 위에 매 프레임 그린다. 모든 구조물의 위치는 ShopLayout 에서 온다.
## 팔레트는 따뜻한 나무/종이/붉은 노렌이며 모양은 전부 직접 짠 도트 규칙이다(생성 이미지·참조 에셋 없음).

const Art = preload("res://scripts/ui/pixel_art.gd")

const INK: Color = Color(0.149, 0.102, 0.071)
const WOOD_D: Color = Color(0.29, 0.17, 0.09)
const WOOD: Color = Color(0.48, 0.29, 0.15)
const WOOD_L: Color = Color(0.66, 0.41, 0.23)
const WOOD_LL: Color = Color(0.82, 0.60, 0.36)
const FLOOR_A: Color = Color(0.79, 0.60, 0.38)
const FLOOR_B: Color = Color(0.72, 0.53, 0.32)
const TILE_A: Color = Color(0.55, 0.57, 0.60)
const TILE_B: Color = Color(0.48, 0.50, 0.54)
const STEEL: Color = Color(0.72, 0.75, 0.78)
const STEEL_D: Color = Color(0.44, 0.47, 0.52)
const PLASTER: Color = Color(0.91, 0.83, 0.66)
const PLASTER_D: Color = Color(0.79, 0.69, 0.50)
const RED: Color = Color(0.76, 0.23, 0.13)
const RED_D: Color = Color(0.54, 0.15, 0.09)
const ROOF: Color = Color(0.23, 0.26, 0.32)
const ROOF_L: Color = Color(0.34, 0.39, 0.48)
const STREET: Color = Color(0.43, 0.42, 0.45)
const STREET_L: Color = Color(0.53, 0.51, 0.54)
const CURB: Color = Color(0.62, 0.59, 0.55)
const GREEN: Color = Color(0.31, 0.54, 0.27)
const GREEN_D: Color = Color(0.18, 0.37, 0.19)
const PAPER: Color = Color(0.96, 0.92, 0.80)
const WHITE: Color = Color(0.97, 0.95, 0.90)
const CHAIR: Color = Color(0.57, 0.35, 0.18)


static func paint(layout: Dictionary) -> Image:
	var size: Vector2i = layout["size"]
	var img: Image = Art.new_image(size.x, size.y)
	# 바깥(지붕 위/옆)은 어두운 기와색으로 채워 화면 여백과 자연스럽게 이어지게 한다.
	Art.rect(img, 0, 0, size.x, size.y, ROOF)
	_back_wall(img, layout["wall"])
	_kitchen(img, layout)
	for f in layout["floors"]:
		_floor(img, f)
	_dining_wall_right(img, layout)
	for c in layout["counters"]:
		_counter(img, c)
	for t in layout["tables"]:
		var tv: Vector2i = t
		_table(img, tv.x, tv.y)
	for s in layout["seats"]:
		var sd: Dictionary = s
		var p: Vector2 = sd["pos"]
		if str(sd["kind"]) == "counter":
			_stool(img, int(p.x), int(p.y))
		else:
			_chair(img, int(p.x), int(p.y))
	for pl in layout["plants"]:
		var pv: Vector2 = pl
		_plant(img, int(pv.x), int(pv.y))
	_roof(img, layout["roof"])
	_street(img, layout["street"])
	_facade(img, layout["facade"], layout["door"], layout["sign"])
	_open_board(img, layout["open_sign"])
	return img


static func _roof(img: Image, r: Rect2i) -> void:
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			var shade: Color = ROOF_L if ((x + (y % 2) * 3) % 6) < 1 else ROOF
			img.set_pixel(x, y, shade)
	Art.rect(img, r.position.x, r.end.y - 1, r.size.x, 1, INK)


static func _back_wall(img: Image, r: Rect2i) -> void:
	Art.rect(img, r.position.x, r.position.y, r.size.x, r.size.y, PLASTER)
	# 아랫부분 나무 판자 벽
	var wy: int = r.end.y - 7
	Art.rect(img, r.position.x, wy, r.size.x, 7, WOOD)
	for x in range(r.position.x, r.end.x, 6):
		Art.rect(img, x, wy, 1, 7, WOOD_D)
	Art.rect(img, r.position.x, wy, r.size.x, 1, WOOD_L)
	# 윗부분: 가로 들보와 일정 간격의 벽장식(메뉴판, 선반, 창). 높이가 낮은 가로 배치에서도 판자 위에 들어가게 아래 기준으로 놓는다.
	Art.rect(img, r.position.x, r.position.y, r.size.x, 2, WOOD_D)
	var step: int = 32
	var i: int = 0
	var x0: int = r.position.x + 6
	while x0 + 20 < r.end.x:
		match i % 3:
			0:
				_menu_boards(img, x0, wy - 14)
			1:
				_shelf(img, x0, wy - 9)
			2:
				_window(img, x0, wy - 14)
		_lantern(img, x0 + 22, r.position.y + 2)
		x0 += step
		i += 1


static func _menu_boards(img: Image, x: int, y: int) -> void:
	# 세로로 긴 종이 메뉴판 세 장. 글씨 대신 먹 선으로 "쓴 흔적"만 표현한다.
	for k in 3:
		var bx: int = x + k * 7
		Art.rect(img, bx, y, 6, 14, PAPER)
		Art.rect(img, bx, y, 6, 1, WOOD_D)
		Art.rect(img, bx, y + 13, 6, 1, WOOD_D)
		for ln in 3:
			Art.rect(img, bx + 2, y + 3 + ln * 3, 2, 2, INK)
		if k == 1:
			Art.rect(img, bx + 1, y + 2, 4, 1, RED)


static func _shelf(img: Image, x: int, y: int) -> void:
	Art.rect(img, x, y + 6, 22, 2, WOOD_D)
	Art.rect(img, x, y + 8, 22, 1, WOOD)
	# 병/항아리
	Art.rect(img, x + 2, y + 1, 3, 5, Color(0.30, 0.16, 0.08))
	Art.rect(img, x + 3, y, 1, 1, STEEL_D)
	Art.rect(img, x + 8, y + 2, 4, 4, Color(0.74, 0.50, 0.22))
	Art.rect(img, x + 8, y + 1, 4, 1, STEEL_D)
	Art.rect(img, x + 15, y + 0, 4, 6, Color(0.82, 0.88, 0.90))
	Art.rect(img, x + 16, y + 3, 2, 3, Color(0.36, 0.62, 0.28))


static func _window(img: Image, x: int, y: int) -> void:
	Art.rect(img, x, y, 18, 14, WOOD_D)
	Art.rect(img, x + 1, y + 1, 16, 12, Color(0.63, 0.78, 0.84))
	Art.rect(img, x + 8, y + 1, 2, 12, WOOD_D)
	Art.rect(img, x + 1, y + 6, 16, 1, WOOD_D)
	Art.rect(img, x + 2, y + 2, 4, 1, Color(0.85, 0.93, 0.95))


static func _lantern(img: Image, x: int, y: int) -> void:
	Art.rect(img, x + 2, y, 1, 3, INK)
	Art.rect(img, x, y + 3, 5, 6, RED)
	Art.rect(img, x + 1, y + 3, 1, 6, Color(0.92, 0.40, 0.22))
	Art.rect(img, x, y + 3, 5, 1, INK)
	Art.rect(img, x, y + 8, 5, 1, INK)
	Art.px(img, x + 2, y + 9, Color(1.0, 0.85, 0.40))


static func _kitchen(img: Image, layout: Dictionary) -> void:
	var r: Rect2i = layout["kitchen"]
	# 타일 바닥(체스판)
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			img.set_pixel(x, y, TILE_A if ((x / 4 + y / 4) % 2) == 0 else TILE_B)
	var sx: int = int(layout["stove_x"])
	var top: int = r.position.y
	# 후드
	Art.rect(img, sx - 2, top, 40, 3, STEEL_D)
	Art.rect(img, sx, top + 3, 36, 2, STEEL)
	# 화구 두 개 + 큰 솥(국물)
	Art.rect(img, sx, top + 10, 36, 12, STEEL_D)
	Art.rect(img, sx, top + 10, 36, 2, STEEL)
	_pot(img, sx + 3, top + 4, Color(0.95, 0.88, 0.74))
	_pot(img, sx + 20, top + 4, Color(0.88, 0.68, 0.30))
	Art.rect(img, sx + 5, top + 20, 6, 2, Color(0.95, 0.55, 0.15))
	Art.rect(img, sx + 22, top + 20, 6, 2, Color(0.95, 0.55, 0.15))
	# 작업대: 그릇 더미와 고명 통
	var px0: int = sx + 46
	Art.rect(img, px0, top + 12, 34, 10, STEEL)
	Art.rect(img, px0, top + 12, 34, 2, STEEL_D)
	for k in 3:
		Art.rect(img, px0 + 2 + k * 2, top + 8 - k, 8, 4, Color(0.95, 0.93, 0.88))
		Art.rect(img, px0 + 2 + k * 2, top + 11 - k, 8, 1, RED)
	Art.rect(img, px0 + 16, top + 8, 6, 4, Color(0.55, 0.78, 0.40))
	Art.rect(img, px0 + 23, top + 8, 6, 4, Color(0.85, 0.60, 0.50))
	# 넓은 주방(가로 배치): 면 삶는 통과 두 번째 작업대를 더해 빈 벽이 없게 한다.
	if r.size.x > 150:
		var nx0: int = px0 + 46
		Art.rect(img, nx0, top + 10, 30, 12, STEEL_D)
		Art.rect(img, nx0, top + 10, 30, 2, STEEL)
		_pot(img, nx0 + 4, top + 3, Color(0.75, 0.80, 0.82))
		Art.rect(img, nx0 + 5, top + 20, 7, 2, Color(0.95, 0.55, 0.15))
		Art.rect(img, nx0 + 18, top + 5, 9, 5, Color(0.97, 0.88, 0.58))
		Art.rect(img, nx0 + 18, top + 9, 9, 1, STEEL_D)
	# 냉장고
	var fx: int = int(layout["fridge_x"])
	var fh: int = mini(r.size.y - 2, 26)
	Art.rect(img, fx, top + (r.size.y - fh), 20, fh, STEEL)
	Art.rect(img, fx, top + (r.size.y - fh), 20, 1, STEEL_D)
	Art.rect(img, fx + 9, top + (r.size.y - fh), 2, fh, STEEL_D)
	Art.rect(img, fx + 7, top + (r.size.y - fh) + 6, 1, 4, INK)
	Art.rect(img, fx + 12, top + (r.size.y - fh) + 6, 1, 4, INK)
	# 걸린 프라이팬/국자
	for k in 3:
		var hx: int = sx + 40 + k * 7
		Art.rect(img, hx, top, 1, 6, STEEL_D)
		Art.rect(img, hx - 2, top + 6, 5, 3, INK)
	Art.rect(img, r.position.x, r.end.y - 1, r.size.x, 1, STEEL_D)


static func _pot(img: Image, x: int, y: int, broth: Color) -> void:
	Art.rect(img, x, y + 2, 14, 8, STEEL)
	Art.rect(img, x - 1, y + 2, 16, 1, STEEL_D)
	Art.rect(img, x + 1, y, 12, 2, broth)
	Art.rect(img, x, y + 9, 14, 1, STEEL_D)
	Art.rect(img, x - 2, y + 4, 2, 2, STEEL_D)
	Art.rect(img, x + 14, y + 4, 2, 2, STEEL_D)


static func _floor(img: Image, r: Rect2i) -> void:
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			var plank: bool = ((y - r.position.y) / 6) % 2 == 0
			var seam: bool = ((x + (0 if plank else 8)) % 16) == 0
			var col: Color = FLOOR_A if plank else FLOOR_B
			if seam:
				col = col.darkened(0.18)
			img.set_pixel(x, y, col)


static func _dining_wall_right(img: Image, layout: Dictionary) -> void:
	# 가로 배치에서 주방 오른쪽 홀의 뒷벽 하단(바닥과 맞닿는 곳)에 걸레받이와 붉은 족자를 둔다.
	if str(layout["variant"]) != "landscape":
		return
	var y0: int = 32
	Art.rect(img, 192, y0, 128, 2, WOOD_D)
	Art.rect(img, 204, 12, 10, 18, RED)
	Art.rect(img, 204, 12, 10, 1, INK)
	Art.rect(img, 207, 16, 4, 4, PAPER)
	Art.rect(img, 207, 22, 4, 3, PAPER)


static func _counter(img: Image, r: Rect2i) -> void:
	Art.rect(img, r.position.x, r.position.y, r.size.x, 5, WOOD_LL)
	Art.rect(img, r.position.x, r.position.y, r.size.x, 1, Color(0.92, 0.74, 0.50))
	Art.rect(img, r.position.x, r.position.y + 5, r.size.x, r.size.y - 5, WOOD)
	Art.rect(img, r.position.x, r.position.y + 5, r.size.x, 1, WOOD_D)
	for x in range(r.position.x + 4, r.end.x - 2, 8):
		Art.rect(img, x, r.position.y + 7, 1, r.size.y - 9, WOOD_D)
	Art.rect(img, r.position.x, r.end.y - 1, r.size.x, 1, WOOD_D)
	# 카운터 위 조미료통과 젓가락통
	var mid: int = r.position.x + r.size.x / 2
	Art.rect(img, mid - 6, r.position.y - 3, 2, 4, RED)
	Art.rect(img, mid - 3, r.position.y - 3, 2, 4, WHITE)
	Art.rect(img, mid + 2, r.position.y - 4, 4, 5, WOOD_D)
	Art.rect(img, mid + 3, r.position.y - 6, 1, 2, WOOD_LL)
	Art.rect(img, mid + 5, r.position.y - 6, 1, 2, WOOD_LL)


static func _stool(img: Image, cx: int, feet_y: int) -> void:
	# 붉은 방석 둥근 의자: 앉은 사람 몸에 가려지도록 발바닥 근처에 둔다.
	Art.rect(img, cx - 5, feet_y - 7, 10, 3, RED)
	Art.rect(img, cx - 4, feet_y - 8, 8, 1, Color(0.88, 0.36, 0.22))
	Art.rect(img, cx - 5, feet_y - 4, 10, 1, RED_D)
	Art.rect(img, cx - 1, feet_y - 3, 2, 3, WOOD_D)
	Art.rect(img, cx - 4, feet_y, 8, 1, WOOD_D)


static func _chair(img: Image, cx: int, feet_y: int) -> void:
	Art.rect(img, cx - 5, feet_y - 7, 10, 2, CHAIR)
	Art.rect(img, cx - 5, feet_y - 5, 1, 5, WOOD_D)
	Art.rect(img, cx + 4, feet_y - 5, 1, 5, WOOD_D)
	Art.rect(img, cx - 5, feet_y - 5, 10, 1, WOOD_D)


static func _table(img: Image, cx: int, cy: int) -> void:
	Art.rect(img, cx - 10, cy - 5, 20, 10, WOOD_LL)
	Art.rect(img, cx - 10, cy - 5, 20, 1, Color(0.92, 0.74, 0.50))
	Art.rect(img, cx - 10, cy + 3, 20, 2, WOOD)
	Art.rect(img, cx - 10, cy + 5, 2, 4, WOOD_D)
	Art.rect(img, cx + 8, cy + 5, 2, 4, WOOD_D)
	# 테이블 가운데: 젓가락통과 조미료
	Art.rect(img, cx - 2, cy - 7, 4, 4, WOOD_D)
	Art.rect(img, cx - 1, cy - 9, 1, 2, WOOD_LL)
	Art.rect(img, cx + 1, cy - 9, 1, 2, WOOD_LL)


static func _plant(img: Image, cx: int, feet_y: int) -> void:
	Art.rect(img, cx - 4, feet_y - 5, 8, 5, Color(0.70, 0.36, 0.22))
	Art.rect(img, cx - 4, feet_y - 5, 8, 1, Color(0.82, 0.48, 0.30))
	Art.rect(img, cx - 5, feet_y - 12, 10, 7, GREEN)
	Art.rect(img, cx - 3, feet_y - 15, 6, 3, GREEN)
	Art.rect(img, cx - 5, feet_y - 7, 3, 2, GREEN_D)
	Art.rect(img, cx + 2, feet_y - 10, 3, 2, GREEN_D)
	Art.px(img, cx, feet_y - 13, Color(0.55, 0.75, 0.40))


static func _facade(img: Image, f: Rect2i, door: Rect2i, sign: Rect2i) -> void:
	# 기와 처마(어두운 슬레이트 줄무늬) + 나무 벽
	Art.rect(img, f.position.x, f.position.y, f.size.x, 7, ROOF)
	for x in range(f.position.x, f.end.x, 4):
		Art.rect(img, x, f.position.y + 1, 1, 5, ROOF_L)
	Art.rect(img, f.position.x, f.position.y + 6, f.size.x, 1, INK)
	Art.rect(img, f.position.x, f.position.y + 7, f.size.x, f.size.y - 7, WOOD)
	for x in range(f.position.x, f.end.x, 5):
		Art.rect(img, x, f.position.y + 7, 1, f.size.y - 7, WOOD_D)
	Art.rect(img, f.position.x, f.end.y - 1, f.size.x, 1, WOOD_D)
	# 간판: 나무판(글씨는 ShopView 가 위에 쓴다)
	Art.rect(img, sign.position.x, sign.position.y, sign.size.x, sign.size.y, WOOD_LL)
	Art.rect(img, sign.position.x, sign.position.y, sign.size.x, 1, WOOD_D)
	Art.rect(img, sign.position.x, sign.end.y - 1, sign.size.x, 1, WOOD_D)
	Art.rect(img, sign.position.x, sign.position.y, 1, sign.size.y, WOOD_D)
	Art.rect(img, sign.end.x - 1, sign.position.y, 1, sign.size.y, WOOD_D)
	Art.rect(img, sign.position.x + 2, sign.position.y - 2, 1, 2, INK)
	Art.rect(img, sign.end.x - 3, sign.position.y - 2, 1, 2, INK)
	# 문(안쪽 따뜻한 불빛) + 붉은 노렌 세 폭
	Art.rect(img, door.position.x - 1, door.position.y - 1, door.size.x + 2, door.size.y + 1, WOOD_D)
	Art.rect(img, door.position.x, door.position.y, door.size.x, door.size.y, Color(1.0, 0.82, 0.45))
	Art.rect(img, door.position.x, door.position.y, door.size.x, 3, Color(0.75, 0.55, 0.30))
	var nw: int = door.size.x / 3
	for k in 3:
		var nx: int = door.position.x + k * nw
		Art.rect(img, nx + 1, door.position.y, nw - 2, 11, RED)
		Art.rect(img, nx + 1, door.position.y + 10, nw - 2, 1, RED_D)
		Art.rect(img, nx + nw / 2 - 1, door.position.y + 3, 2, 3, PAPER)
	Art.rect(img, door.position.x - 1, door.position.y, door.size.x + 2, 1, INK)
	# 문 옆 등
	_lantern(img, door.position.x - 8, door.position.y + 1)
	_lantern(img, door.end.x + 3, door.position.y + 1)
	# 창(격자)
	var wx: int = door.end.x + 12
	if wx + 16 < f.end.x:
		Art.rect(img, wx, f.position.y + 9, 14, 9, WOOD_D)
		Art.rect(img, wx + 1, f.position.y + 10, 12, 7, Color(1.0, 0.82, 0.45))
		Art.rect(img, wx + 6, f.position.y + 10, 1, 7, WOOD_D)


static func _street(img: Image, r: Rect2i) -> void:
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			var brick: int = ((y - r.position.y) / 4) % 2
			var col: Color = STREET
			if ((x + brick * 5) % 10) == 0 or ((y - r.position.y) % 4) == 0:
				col = STREET_L
			img.set_pixel(x, y, col)
	Art.rect(img, r.position.x, r.position.y, r.size.x, 2, CURB)
	Art.rect(img, r.position.x, r.position.y + 2, r.size.x, 1, Color(0.35, 0.34, 0.37))
	# 길가 틈새 풀
	for x in range(5, r.size.x, 29):
		Art.px(img, r.position.x + x, r.position.y + 3, GREEN)
		Art.px(img, r.position.x + x + 1, r.position.y + 3, GREEN_D)
	# 벚꽃 잎 몇 점
	for k in 6:
		Art.px(img, r.position.x + 11 + k * 23, r.position.y + 8 + (k * 7) % (maxi(1, r.size.y - 10)), Color(0.98, 0.75, 0.82))


static func _open_board(img: Image, r: Rect2i) -> void:
	# 길가 입간판(영업중/준비중 글씨는 ShopView 가 쓴다)
	Art.rect(img, r.position.x, r.position.y, r.size.x, r.size.y - 2, WOOD_L)
	Art.rect(img, r.position.x, r.position.y, r.size.x, 1, WOOD_D)
	Art.rect(img, r.position.x, r.position.y, 1, r.size.y - 2, WOOD_D)
	Art.rect(img, r.end.x - 1, r.position.y, 1, r.size.y - 2, WOOD_D)
	Art.rect(img, r.position.x, r.end.y - 3, r.size.x, 1, WOOD_D)
	Art.rect(img, r.position.x + 2, r.end.y - 2, 1, 2, WOOD_D)
	Art.rect(img, r.end.x - 3, r.end.y - 2, 1, 2, WOOD_D)
