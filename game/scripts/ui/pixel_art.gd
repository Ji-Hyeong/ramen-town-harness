extends RefCounted
## 코드로 찍는 도트 스프라이트(사람, 말풍선, 그릇, 재료 아이콘). 외부 이미지·참조 에셋 없이 이 파일의 픽셀 규칙만 쓴다.
## 모든 이미지는 RGBA8 이고 작은 논리 해상도로 만든 뒤 화면에서 최근접 필터 + 정수 배율로 확대한다.
## 사람은 14x18, 머리가 큰 2.5등신. 좌표 기준은 왼쪽 위이며 발바닥은 맨 아래 줄(y=17)이다.

const INK: Color = Color(0.149, 0.102, 0.071)
const WHITE: Color = Color(0.97, 0.95, 0.90)
const SKIN: Color = Color(0.94, 0.78, 0.63)
const BLUSH: Color = Color(0.93, 0.62, 0.55)
const RED: Color = Color(0.76, 0.23, 0.13)
const RED_D: Color = Color(0.54, 0.15, 0.09)
const WOOD_LL: Color = Color(0.82, 0.60, 0.36)

# 사람 외형. 0~2 는 단골(도윤/하영/마루), 3~9 는 처음 온 손님, 10 요리사, 11 서버.
const LOOKS: Array = [
	{"hair": "#2a2320", "shirt": "#7d8590", "pants": "#2d3a5a", "style": "short", "acc": "glasses"},
	{"hair": "#5a3524", "shirt": "#e08aa0", "pants": "#4b5a78", "style": "long", "acc": "none"},
	{"hair": "#3b2a22", "shirt": "#5f8a3f", "pants": "#8a7a50", "style": "cap", "acc": "backpack", "cap": "#3f7f78"},
	{"hair": "#c9c9c9", "shirt": "#2f4a7a", "pants": "#3a3a3a", "style": "short", "acc": "none"},
	{"hair": "#1d1d1d", "shirt": "#3a78c8", "pants": "#3a3a4a", "style": "spiky", "acc": "none"},
	{"hair": "#7a4a3a", "shirt": "#f0d8e0", "pants": "#6a4a7a", "style": "bun", "acc": "none"},
	{"hair": "#2a2a2a", "shirt": "#2a2a2a", "pants": "#2f3f6a", "style": "cap", "acc": "none", "cap": "#e8e8e0"},
	{"hair": "#a84a2a", "shirt": "#e0b840", "pants": "#3a4a6a", "style": "long", "acc": "none"},
	{"hair": "#4a3a30", "shirt": "#e8e8f0", "pants": "#2a2a38", "style": "short", "acc": "glasses"},
	{"hair": "#2a2a2a", "shirt": "#e08a3a", "pants": "#3a5a8a", "style": "spiky", "acc": "backpack"},
	{"hair": "#1d1d1d", "shirt": "#24242a", "pants": "#1c1c22", "style": "band", "acc": "none"},
	{"hair": "#4a2f22", "shirt": "#f0e8e0", "pants": "#3a3a48", "style": "bandana", "acc": "apron"},
]
const LOOK_CHEF: int = 10
const LOOK_SERVER: int = 11


static func new_image(w: int, h: int) -> Image:
	var img: Image = Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.0, 0.0, 0.0, 0.0))
	return img


static func rect(img: Image, x: int, y: int, w: int, h: int, c: Color) -> void:
	if w <= 0 or h <= 0:
		return
	img.fill_rect(Rect2i(x, y, w, h), c)


static func px(img: Image, x: int, y: int, c: Color) -> void:
	if x < 0 or y < 0 or x >= img.get_width() or y >= img.get_height():
		return
	img.set_pixel(x, y, c)


## 볼록 다각형 채우기(점은 화면 픽셀 좌표). 픽셀 중심이 안에 들어오면 칠한다.
## 이 규칙이면 변을 공유하는 두 면(윗면/옆면)이 틈도 겹침도 없이 붙는다. 등각 가구의 면 채우기에 쓴다.
static func poly(img: Image, pts: Array, c: Color) -> void:
	var n: int = pts.size()
	if n < 3:
		return
	var min_y: float = 1.0e9
	var max_y: float = -1.0e9
	for p in pts:
		var v: Vector2 = p
		min_y = minf(min_y, v.y)
		max_y = maxf(max_y, v.y)
	for y in range(int(floor(min_y)), int(ceil(max_y))):
		var cy: float = float(y) + 0.5
		var lo: float = 1.0e9
		var hi: float = -1.0e9
		for i in n:
			var a: Vector2 = pts[i]
			var b: Vector2 = pts[(i + 1) % n]
			if (a.y <= cy and b.y > cy) or (b.y <= cy and a.y > cy):
				var x: float = a.x + (cy - a.y) / (b.y - a.y) * (b.x - a.x)
				lo = minf(lo, x)
				hi = maxf(hi, x)
		if hi > lo:
			var xs: int = int(ceil(lo - 0.5))
			var xe: int = int(ceil(hi - 0.5))
			rect(img, xs, y, xe - xs, 1, c)


## 1픽셀 직선(브레젠험): 가구 모서리, 널 무늬, 난간.
static func line(img: Image, a: Vector2, b: Vector2, c: Color) -> void:
	var x0: int = int(roundf(a.x))
	var y0: int = int(roundf(a.y))
	var x1: int = int(roundf(b.x))
	var y1: int = int(roundf(b.y))
	var dx: int = absi(x1 - x0)
	var dy: int = -absi(y1 - y0)
	var sx: int = 1 if x0 < x1 else -1
	var sy: int = 1 if y0 < y1 else -1
	var err: int = dx + dy
	while true:
		px(img, x0, y0, c)
		if x0 == x1 and y0 == y1:
			break
		var e2: int = 2 * err
		if e2 >= dy:
			err += dy
			x0 += sx
		if e2 <= dx:
			err += dx
			y0 += sy


## src 를 dst 의 pos 에 알파 합성(범위 밖은 잘림). 가구 조각 합성과 검사용 CPU 장면 합성에 쓴다.
static func blit(dst: Image, src: Image, pos: Vector2i) -> void:
	dst.blend_rect(src, Rect2i(Vector2i.ZERO, src.get_size()), pos)


static func tex(img: Image) -> ImageTexture:
	return ImageTexture.create_from_image(img)


## 최근접 확대본 텍스처(버튼 아이콘·미리보기용). 장면 스프라이트는 화면에서 직접 확대하므로 쓰지 않는다.
static func scaled_tex(img: Image, factor: int) -> ImageTexture:
	var big: Image = img.duplicate() as Image
	big.resize(img.get_width() * factor, img.get_height() * factor, Image.INTERPOLATE_NEAREST)
	return ImageTexture.create_from_image(big)


static func _c(hex: String) -> Color:
	return Color.html(hex)


static func look_count() -> int:
	return LOOKS.size()


# ---------- 사람 ----------

## pose: stand / walk / sit / carry / cook, frame: 0 또는 1(걷기 다리 교대, 숨쉬기, 젓기/먹기 팔 동작).
## back: 카운터 쪽을 보고 앉은 손님(머리를 뒤에서 본 모양).
static func person_image(look_index: int, pose: String, frame: int, back: bool) -> Image:
	var look: Dictionary = LOOKS[look_index % LOOKS.size()]
	var hair: Color = _c(str(look["hair"]))
	var shirt: Color = _c(str(look["shirt"]))
	var pants: Color = _c(str(look["pants"]))
	var style: String = str(look["style"])
	var acc: String = str(look["acc"])
	var img: Image = new_image(14, 18)
	# 가만히 있을 때만 숨쉬기처럼 한 칸 내려앉는다(머리/몸통이 dy 만큼 내려가고 다리가 짧아짐).
	var dy: int = 0
	if frame == 1 and (pose == "stand" or pose == "cook"):
		dy = 1

	# 다리/신발
	var shoe: Color = INK
	if pose == "sit":
		rect(img, 4, 14, 6, 3, pants)
		rect(img, 4, 17, 2, 1, shoe)
		rect(img, 8, 17, 2, 1, shoe)
	elif pose == "walk" or pose == "carry":
		var lift_left: bool = frame == 1
		rect(img, 5, 14, 2, 2 if lift_left else 4, pants)
		rect(img, 8, 14, 2, 4 if lift_left else 2, pants)
		px(img, 5, 15 if lift_left else 17, shoe)
		px(img, 6, 15 if lift_left else 17, shoe)
		px(img, 8, 17 if lift_left else 15, shoe)
		px(img, 9, 17 if lift_left else 15, shoe)
	else:
		rect(img, 5, 14 + dy, 2, 3 - dy, pants)
		rect(img, 8, 14 + dy, 2, 3 - dy, pants)
		rect(img, 5, 17, 2, 1, shoe)
		rect(img, 8, 17, 2, 1, shoe)

	# 몸통과 팔
	rect(img, 4, 8 + dy, 6, 6, shirt)
	var arm_left_y: int = 9 + dy
	var arm_right_y: int = 9 + dy
	var arm_h: int = 4
	if pose == "walk":
		arm_left_y += 1 if frame == 0 else 0
		arm_right_y += 1 if frame == 1 else 0
	if pose == "carry":
		arm_left_y = 10
		arm_right_y = 10
		arm_h = 2
	if pose == "cook" and frame == 1:
		arm_right_y = 6
		arm_h = 4
	var raise_eat: bool = pose == "sit" and frame == 1
	rect(img, 3, arm_left_y, 1, arm_h, shirt)
	if raise_eat:
		rect(img, 10, 6, 1, 4, shirt)
		px(img, 10, 5, SKIN)
		px(img, 11, 4, WOOD_LL)
		px(img, 11, 5, WOOD_LL)
	else:
		rect(img, 10, arm_right_y, 1, arm_h, shirt)
		px(img, 10, arm_right_y + arm_h, SKIN)
	px(img, 3, arm_left_y + arm_h, SKIN)
	if acc == "apron":
		rect(img, 4, 10 + dy, 6, 5, WHITE if look_index == LOOK_SERVER else Color(0.9, 0.9, 0.88))
		rect(img, 4, 10 + dy, 6, 1, RED)
		rect(img, 5, 9 + dy, 4, 1, WHITE)
	if acc == "backpack":
		if back:
			rect(img, 3, 9 + dy, 8, 6, _c("#7a4a2a"))
			rect(img, 3, 9 + dy, 8, 1, _c("#946037"))
		else:
			rect(img, 4, 9 + dy, 1, 4, _c("#7a4a2a"))
			rect(img, 9, 9 + dy, 1, 4, _c("#7a4a2a"))

	# 머리
	if back:
		rect(img, 3, 1 + dy, 8, 7, hair)
		rect(img, 2, 2 + dy, 1, 4, hair)
		rect(img, 11, 2 + dy, 1, 4, hair)
	else:
		rect(img, 3, 1 + dy, 8, 3, hair)
		rect(img, 3, 3 + dy, 8, 5, SKIN)
		rect(img, 3, 3 + dy, 1, 2, hair)
		rect(img, 10, 3 + dy, 1, 2, hair)
		px(img, 5, 5 + dy, INK)
		px(img, 8, 5 + dy, INK)
		px(img, 4, 6 + dy, BLUSH)
		px(img, 9, 6 + dy, BLUSH)
		px(img, 6, 7 + dy, RED_D)
		px(img, 7, 7 + dy, RED_D)
		if acc == "glasses":
			rect(img, 4, 5 + dy, 3, 1, Color(0.2, 0.2, 0.26))
			rect(img, 8, 5 + dy, 3, 1, Color(0.2, 0.2, 0.26))
			px(img, 7, 5 + dy, Color(0.2, 0.2, 0.26))
			px(img, 5, 5 + dy, INK)
			px(img, 9, 5 + dy, INK)
	match style:
		"long":
			rect(img, 2, 3 + dy, 2, 6, hair)
			rect(img, 10, 3 + dy, 2, 6, hair)
		"spiky":
			px(img, 4, 0 + dy, hair)
			px(img, 6, 0 + dy, hair)
			px(img, 8, 0 + dy, hair)
			px(img, 10, 0 + dy, hair)
		"bun":
			rect(img, 5, 0 + dy, 4, 2, hair)
		"cap":
			var cap: Color = _c(str(look.get("cap", "#3f7f78")))
			rect(img, 2, 1 + dy, 10, 2, cap)
			rect(img, 3, 0 + dy, 8, 1, cap)
			if not back:
				rect(img, 3, 3 + dy, 8, 1, cap.darkened(0.25))
		"band":
			rect(img, 3, 2 + dy, 8, 1, WHITE)
			px(img, 11, 2 + dy, WHITE)
			px(img, 12, 3 + dy, WHITE)
		"bandana":
			rect(img, 3, 1 + dy, 8, 3, RED)
			rect(img, 11, 3 + dy, 2, 2, RED)
			px(img, 5, 2 + dy, WHITE)
			px(img, 8, 2 + dy, WHITE)
	return img


static func flipped(img: Image) -> Image:
	var copy: Image = img.duplicate() as Image
	copy.flip_x()
	return copy


# ---------- 말풍선 ----------

static func _blit(img: Image, rows: Array, ox: int, oy: int, colors: Dictionary) -> void:
	for y in rows.size():
		var line: String = str(rows[y])
		for x in line.length():
			var ch: String = line[x]
			if colors.has(ch):
				px(img, ox + x, oy + y, colors[ch])


## 13x11 말풍선. kind: heart note smile meh angry order wait impatient coin
static func bubble_image(kind: String) -> Image:
	var img: Image = new_image(13, 11)
	rect(img, 0, 0, 13, 9, INK)
	rect(img, 1, 1, 11, 7, WHITE)
	px(img, 0, 0, Color(0, 0, 0, 0))
	px(img, 12, 0, Color(0, 0, 0, 0))
	px(img, 0, 8, Color(0, 0, 0, 0))
	px(img, 12, 8, Color(0, 0, 0, 0))
	rect(img, 5, 9, 3, 1, INK)
	rect(img, 6, 9, 1, 1, WHITE)
	px(img, 6, 10, INK)
	var o: Dictionary = {"#": INK, "r": Color(0.86, 0.20, 0.25), "b": Color(0.29, 0.54, 0.78), "y": Color(0.96, 0.77, 0.26)}
	match kind:
		"heart":
			_blit(img, [".rr.rr.", "rrrrrrr", "rrrrrrr", ".rrrrr.", "..rrr..", "...r..."], 3, 1, o)
		"note":
			_blit(img, ["...####", "...#..#", "...#..#", "...#...", ".###...", "####..."], 3, 1, o)
		"order":
			_blit(img, ["...r...", "...r...", "...r...", "...r...", ".......", "...r..."], 3, 1, o)
		"wait":
			_blit(img, [".......", ".......", "#.#.#..", ".......", ".......", "......."], 3, 2, o)
		"impatient":
			_blit(img, ["...b...", "..bbb..", "..bbb..", ".bbbbb.", ".bbbbb.", "..bbb.."], 3, 1, o)
		"coin":
			_blit(img, ["..yyy..", ".yyyyy.", ".yy#yy.", ".yy#yy.", ".yyyyy.", "..yyy.."], 3, 1, o)
		"smile", "meh", "angry":
			var face: Color = Color(0.96, 0.77, 0.26)
			if kind == "meh":
				face = Color(0.82, 0.78, 0.62)
			elif kind == "angry":
				face = Color(0.90, 0.42, 0.30)
			rect(img, 4, 1, 5, 7, face)
			rect(img, 3, 2, 7, 5, face)
			px(img, 5, 3, INK)
			px(img, 7, 3, INK)
			if kind == "smile":
				px(img, 4, 5, INK)
				px(img, 8, 5, INK)
				rect(img, 5, 6, 3, 1, INK)
			elif kind == "meh":
				rect(img, 5, 5, 3, 1, INK)
			else:
				px(img, 5, 2, INK)
				px(img, 7, 2, INK)
				px(img, 5, 5, INK)
				px(img, 6, 4, INK)
				px(img, 7, 5, INK)
	return img


# ---------- 그릇 ----------

static func broth_color(config: Dictionary) -> Color:
	match str(config.get("broth", "")):
		"broth_tonkotsu":
			return Color(0.95, 0.88, 0.74)
		"broth_chicken":
			return Color(0.88, 0.68, 0.30)
		"broth_dashi":
			return Color(0.78, 0.74, 0.46)
	return Color(0.88, 0.80, 0.62)


## 12x7 라멘 그릇(위에서 비스듬히). 재료가 바뀌면 국물색/면/토핑/향미유 점이 바뀐다. 장면의 그릇과 미리보기가 같은 함수를 쓴다.
static func bowl_image(config: Dictionary) -> Image:
	var img: Image = new_image(12, 7)
	var broth: Color = broth_color(config)
	rect(img, 3, 0, 6, 1, RED_D)
	rect(img, 1, 1, 10, 1, RED_D)
	rect(img, 2, 1, 8, 1, broth)
	rect(img, 2, 2, 8, 1, RED_D)
	rect(img, 3, 2, 6, 1, broth)
	rect(img, 2, 3, 8, 1, RED)
	rect(img, 3, 4, 6, 1, RED)
	rect(img, 4, 5, 4, 1, RED_D)
	rect(img, 3, 6, 6, 1, INK)
	# 면: 굵을수록 줄무늬가 성기고 색이 진하다.
	var noodle: Color = Color(0.97, 0.88, 0.58)
	var n: String = str(config.get("noodle", ""))
	if n == "noodle_thick":
		noodle = Color(0.93, 0.80, 0.44)
	for x in range(3, 9, 1 if n == "noodle_thin" else 2):
		px(img, x, 1, noodle)
		px(img, x + 1 if n != "noodle_thin" else x, 2, noodle)
	match str(config.get("topping", "")):
		"topping_chashu":
			rect(img, 2, 1, 3, 1, Color(0.80, 0.54, 0.44))
			px(img, 3, 2, Color(0.80, 0.54, 0.44))
		"topping_egg":
			rect(img, 2, 1, 2, 1, WHITE)
			px(img, 2, 2, WHITE)
			px(img, 3, 2, Color(0.96, 0.66, 0.16))
		"topping_sprouts":
			px(img, 2, 1, Color(0.88, 0.95, 0.70))
			px(img, 4, 1, Color(0.88, 0.95, 0.70))
			px(img, 3, 2, Color(0.88, 0.95, 0.70))
		"topping_nori":
			rect(img, 8, 0, 2, 2, Color(0.12, 0.20, 0.16))
	var oil: Color = Color(0, 0, 0, 0)
	match str(config.get("oil", "")):
		"oil_garlic":
			oil = Color(0.55, 0.34, 0.14)
		"oil_chili":
			oil = Color(0.85, 0.16, 0.08)
		"oil_scallion":
			oil = Color(0.36, 0.62, 0.28)
	if oil.a > 0.0:
		px(img, 6, 1, oil)
		px(img, 5, 2, oil)
		px(img, 8, 2, oil)
	return img


# ---------- 재료 아이콘 (12x12) ----------

static func icon_image(id: String) -> Image:
	var img: Image = new_image(12, 12)
	var steel: Color = Color(0.72, 0.75, 0.78)
	var steel_d: Color = Color(0.44, 0.47, 0.52)
	if id.begins_with("broth_"):
		var cfg: Dictionary = {"broth": id}
		rect(img, 1, 3, 10, 8, steel)
		rect(img, 1, 3, 10, 1, steel_d)
		rect(img, 2, 4, 8, 2, broth_color(cfg))
		rect(img, 0, 5, 1, 2, steel_d)
		rect(img, 11, 5, 1, 2, steel_d)
		rect(img, 2, 10, 8, 1, steel_d)
		rect(img, 3, 1, 6, 1, steel_d)
		px(img, 5, 0, steel_d)
	elif id.begins_with("tare_"):
		var sauce: Color = Color(0.30, 0.16, 0.08)
		if id == "tare_shio":
			sauce = Color(0.93, 0.90, 0.78)
		elif id == "tare_miso":
			sauce = Color(0.74, 0.50, 0.22)
		rect(img, 4, 0, 4, 2, steel_d)
		rect(img, 3, 2, 6, 9, Color(0.82, 0.88, 0.90))
		rect(img, 4, 5, 4, 5, sauce)
		rect(img, 3, 11, 6, 1, steel_d)
	elif id.begins_with("oil_"):
		var oc: Color = Color(0.55, 0.34, 0.14)
		if id == "oil_chili":
			oc = Color(0.85, 0.16, 0.08)
		elif id == "oil_scallion":
			oc = Color(0.36, 0.62, 0.28)
		rect(img, 5, 0, 2, 2, steel_d)
		rect(img, 4, 2, 4, 2, oc)
		rect(img, 3, 4, 6, 4, oc)
		rect(img, 2, 6, 8, 3, oc)
		rect(img, 3, 9, 6, 1, oc)
		px(img, 4, 5, WHITE)
	elif id.begins_with("noodle_"):
		var amp: int = 1
		var thick: int = 1
		if id == "noodle_medium":
			thick = 2
		elif id == "noodle_thick":
			thick = 3
		for row in 3:
			for x in 12:
				var yy: int = 2 + row * 3 + (amp if (x / 2) % 2 == 0 else 0)
				rect(img, x, yy, 1, thick, Color(0.97, 0.88, 0.58))
	elif id.begins_with("topping_"):
		match id:
			"topping_chashu":
				rect(img, 1, 3, 10, 6, Color(0.80, 0.54, 0.44))
				rect(img, 3, 4, 6, 4, Color(0.90, 0.68, 0.58))
				rect(img, 4, 5, 4, 2, Color(0.70, 0.42, 0.34))
			"topping_egg":
				rect(img, 2, 2, 8, 8, WHITE)
				rect(img, 1, 3, 10, 6, WHITE)
				rect(img, 4, 4, 4, 4, Color(0.96, 0.66, 0.16))
			"topping_sprouts":
				for i in 5:
					rect(img, 1 + i * 2, 3 + (i % 2) * 2, 1, 7, Color(0.88, 0.95, 0.70))
					px(img, 1 + i * 2, 2 + (i % 2) * 2, Color(0.50, 0.75, 0.35))
			"topping_nori":
				rect(img, 2, 1, 8, 10, Color(0.12, 0.20, 0.16))
				rect(img, 3, 2, 6, 1, Color(0.22, 0.34, 0.26))
	elif id.begins_with("cook_"):
		var lines: int = 1
		if id == "cook_normal":
			lines = 2
		elif id == "cook_soft":
			lines = 3
		rect(img, 2, 6, 8, 5, steel)
		rect(img, 2, 6, 8, 1, steel_d)
		for i in lines:
			rect(img, 3 + i * 3, 1, 1, 4, Color(0.80, 0.84, 0.88))
			px(img, 4 + i * 3, 3, Color(0.80, 0.84, 0.88))
	elif id == "coin":
		rect(img, 3, 0, 6, 12, Color(0.96, 0.77, 0.26))
		rect(img, 1, 2, 10, 8, Color(0.96, 0.77, 0.26))
		rect(img, 4, 2, 4, 8, Color(1.0, 0.90, 0.50))
		rect(img, 5, 3, 2, 6, Color(0.82, 0.58, 0.14))
	elif id == "star":
		rect(img, 5, 0, 2, 12, Color(0.96, 0.77, 0.26))
		rect(img, 0, 4, 12, 3, Color(0.96, 0.77, 0.26))
		rect(img, 2, 2, 8, 8, Color(0.96, 0.77, 0.26))
	return img
