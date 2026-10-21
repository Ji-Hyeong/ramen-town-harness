extends RefCounted
## 코드로 찍는 도트 스프라이트(사람, 말풍선, 그릇, 재료 아이콘). 외부 이미지·참조 에셋 없이 이 파일의 픽셀 규칙만 쓴다.
## 모든 이미지는 RGBA8 이고 작은 논리 해상도로 만든 뒤 화면에서 최근접 필터 + 정수 배율로 확대한다.
## 사람은 14x18, 머리가 큰 2.5등신. 좌표 기준은 왼쪽 위이며 발바닥은 맨 아래 줄(y=17)이다.

const Catalog = preload("res://scripts/domain/ingredient_catalog.gd")

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
	# 12 조리 보조(초록 두건 + 앞치마 + 국자), 13 홀 보조(보라 머리 + 앞치마 + 쟁반). 단골/손님 외형(0~9)과 색이 겹치지 않는 별도 직원 외형이다.
	{"hair": "#3d4a2a", "shirt": "#7fae6a", "pants": "#4a4a40", "style": "cap", "acc": "apron_ladle", "cap": "#4f8f5a"},
	{"hair": "#6a3a6a", "shirt": "#5a7fc0", "pants": "#2a2a3a", "style": "long", "acc": "apron_tray"},
]
const LOOK_CHEF: int = 10
const LOOK_SERVER: int = 11
const LOOK_PREP_ASSISTANT: int = 12
const LOOK_FLOOR_ASSISTANT: int = 13


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


## 원본 저해상도 그림에는 글자를 넣지 않는다. 메달과 잡지는 형태/색으로 읽히게 한다.
static func contest_badge_image(band: int) -> Image:
	var img: Image = Image.create(32, 24, false, Image.FORMAT_RGBA8)
	img.fill(Color.TRANSPARENT)
	var metal: Color = _c("bd8051") if band == 1 else (_c("c7d4dc") if band == 2 else _c("e9b846"))
	if band == 0:
		metal = _c("a7a18b")
	img.fill_rect(Rect2i(7, 3, 6, 7), _c("c6573d"))
	img.fill_rect(Rect2i(19, 3, 6, 7), _c("376e70"))
	img.fill_rect(Rect2i(10, 8, 12, 12), _c("543b2c"))
	img.fill_rect(Rect2i(9, 10, 14, 8), metal)
	img.fill_rect(Rect2i(12, 9, 8, 10), metal)
	img.fill_rect(Rect2i(12, 12, 8, 3), _c("faf0cf"))
	img.fill_rect(Rect2i(13, 15, 6, 2), _c("a65138"))
	if band == 0:
		img.fill_rect(Rect2i(12, 19, 8, 2), _c("a7a18b"))
	return img


static func magazine_image() -> Image:
	var img: Image = Image.create(48, 28, false, Image.FORMAT_RGBA8)
	img.fill(Color.TRANSPARENT)
	img.fill_rect(Rect2i(4, 2, 40, 24), _c("6b5340"))
	img.fill_rect(Rect2i(5, 2, 37, 22), _c("f7eac8"))
	img.fill_rect(Rect2i(8, 5, 30, 3), _c("a65035"))
	img.fill_rect(Rect2i(8, 11, 13, 10), _c("c3d1b5"))
	img.fill_rect(Rect2i(10, 12, 9, 4), _c("aa5b41"))
	img.fill_rect(Rect2i(12, 16, 6, 5), _c("e5b965"))
	for y in [11, 14, 17, 20]:
		img.fill_rect(Rect2i(25, y, 13 if y != 20 else 8, 1), _c("b5a38a"))
	return img


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
	if acc.begins_with("apron"):
		rect(img, 4, 10 + dy, 6, 5, WHITE if look_index == LOOK_SERVER else Color(0.9, 0.9, 0.88))
		rect(img, 4, 10 + dy, 6, 1, RED)
		rect(img, 5, 9 + dy, 4, 1, WHITE)
	# 보조 직원 소품: 조리 보조는 오른손의 국자, 홀 보조는 쟁반(둘 다 14x18 안). 직원 외형을 한눈에 구분하게 한다.
	if acc == "apron_ladle":
		rect(img, 11, 6 + dy, 1, 6, WOOD_LL)
		rect(img, 11, 4 + dy, 2, 2, Color(0.72, 0.75, 0.78))
	elif acc == "apron_tray":
		rect(img, 8, 11, 6, 1, Color(0.72, 0.75, 0.78))
		rect(img, 9, 12, 4, 1, Color(0.44, 0.47, 0.52))
		px(img, 12, 10, WHITE)
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


## 11x8 작은 등(영업 여부 표시). 글자 대신 쓴다: 영업 중 = 붉은 등 + 노란 불, 아니면 회색 등 + 꺼진 불.
static func open_lamp_image(is_open: bool) -> Image:
	var img: Image = new_image(11, 8)
	var body: Color = RED if is_open else Color(0.45, 0.45, 0.50)
	var glow: Color = Color(1.0, 0.86, 0.50) if is_open else Color(0.30, 0.30, 0.34)
	px(img, 5, 0, INK)
	rect(img, 2, 1, 7, 6, body)
	rect(img, 2, 1, 7, 1, INK)
	rect(img, 2, 6, 7, 1, INK)
	rect(img, 3, 2, 1, 4, body.lightened(0.18))
	rect(img, 4, 2, 4, 4, glow)
	if is_open:
		px(img, 5, 3, Color(1.0, 0.97, 0.80))
		px(img, 6, 3, Color(1.0, 0.97, 0.80))
	px(img, 5, 7, INK)
	return img


# ---------- 단골 초상 (24x24) ----------

const PORTRAIT_IDS: Array = ["dohyun", "hayoung", "maru"]
const PORTRAIT_BG: Array = ["#9fb0c4", "#f0c9d0", "#b8d8b0"]


static func portrait_ids() -> Array:
	return PORTRAIT_IDS


## 단골 세 분의 가슴 위 초상. 색은 LOOKS(장면 속 사람과 같은 머리/옷 색)에서 가져오고 얼굴 특징은 각자 다르다:
## 도윤 = 짧은 머리 + 안경 + 무표정 + 가방끈, 하영 = 긴 머리 + 머리핀 + 웃음 + 교사증 목걸이, 마루 = 모자 + 굵은 눈썹 + 활짝 웃음 + 배낭끈.
## 알 수 없는 id 는 도윤 모양이 아니라 빈 틀(테두리 + 배경)만 돌려준다.
static func portrait_image(customer_id: String) -> Image:
	var img: Image = new_image(24, 24)
	var idx: int = PORTRAIT_IDS.find(customer_id)
	rect(img, 0, 0, 24, 24, INK)
	if idx < 0:
		rect(img, 1, 1, 22, 22, Color(0.80, 0.78, 0.72))
		return img
	var look: Dictionary = LOOKS[idx]
	var hair: Color = _c(str(look["hair"]))
	var shirt: Color = _c(str(look["shirt"]))
	rect(img, 1, 1, 22, 22, _c(str(PORTRAIT_BG[idx])))
	var skin_d: Color = SKIN.darkened(0.12)
	# 어깨/셔츠와 목
	rect(img, 3, 18, 18, 5, shirt)
	rect(img, 2, 20, 20, 3, shirt)
	rect(img, 10, 15, 4, 4, skin_d)
	rect(img, 10, 18, 4, 1, WHITE)
	px(img, 11, 19, WHITE)
	px(img, 12, 19, WHITE)
	# 머리(둥근 얼굴)와 귀
	rect(img, 7, 5, 10, 11, SKIN)
	rect(img, 6, 7, 12, 7, SKIN)
	px(img, 5, 10, SKIN)
	px(img, 18, 10, SKIN)
	match idx:
		0:
			rect(img, 6, 3, 12, 3, hair)
			rect(img, 5, 5, 2, 5, hair)
			rect(img, 17, 5, 2, 5, hair)
			rect(img, 7, 6, 10, 1, hair)
			rect(img, 14, 18, 2, 5, Color(0.23, 0.25, 0.30))
		1:
			rect(img, 6, 3, 12, 3, hair)
			rect(img, 6, 5, 12, 2, hair)
			px(img, 12, 6, SKIN)
			rect(img, 4, 5, 3, 15, hair)
			rect(img, 17, 5, 3, 15, hair)
			rect(img, 15, 5, 2, 1, Color(0.96, 0.77, 0.26))
			px(img, 16, 4, RED)
			rect(img, 11, 18, 1, 5, Color(0.25, 0.50, 0.48))
			rect(img, 10, 21, 3, 2, WHITE)
			px(img, 11, 21, INK)
		2:
			var cap: Color = _c(str(look["cap"]))
			rect(img, 5, 3, 14, 3, cap)
			rect(img, 6, 2, 12, 1, cap)
			rect(img, 12, 6, 10, 2, cap.darkened(0.25))
			rect(img, 5, 6, 2, 4, hair)
			rect(img, 17, 6, 1, 3, hair)
			var strap: Color = _c("#7a4a2a")
			rect(img, 5, 18, 2, 5, strap)
			rect(img, 17, 18, 2, 5, strap)
	# 눈/볼/코/입
	rect(img, 9, 10, 1, 2, INK)
	rect(img, 14, 10, 1, 2, INK)
	px(img, 8, 12, BLUSH)
	px(img, 15, 12, BLUSH)
	px(img, 12, 12, skin_d)
	match idx:
		0:
			var frame: Color = Color(0.20, 0.20, 0.26)
			for gx in [8, 13]:
				rect(img, int(gx), 9, 4, 1, frame)
				rect(img, int(gx), 12, 4, 1, frame)
				rect(img, int(gx), 9, 1, 4, frame)
				rect(img, int(gx) + 3, 9, 1, 4, frame)
			px(img, 12, 10, frame)
			rect(img, 11, 14, 3, 1, RED_D)
		1:
			px(img, 9, 9, INK)
			px(img, 14, 9, INK)
			px(img, 10, 13, RED_D)
			px(img, 14, 13, RED_D)
			rect(img, 11, 14, 3, 1, RED_D)
		2:
			rect(img, 8, 8, 3, 1, INK)
			rect(img, 13, 8, 3, 1, INK)
			rect(img, 10, 13, 5, 2, RED_D)
			rect(img, 10, 13, 5, 1, WHITE)
	return img


# ---------- 보조 직원 초상 (24x24) ----------

const STAFF_PORTRAIT_IDS: Array = ["prep_assistant", "floor_assistant"]
const STAFF_PORTRAIT_BG: Array = ["#c8dcb4", "#c4d0ec"]


## 보조 직원 둘의 초상(조리 보조 = 초록 두건 + 국자, 홀 보조 = 긴 보라 머리 + 쟁반). 단골 초상과 같은 24x24 틀/테두리지만
## 색과 소품이 달라 단골 누구와도 헷갈리지 않는다. 알 수 없는 id 는 빈 틀(테두리 + 배경)만 돌려준다.
static func staff_portrait_image(staff_id: String) -> Image:
	var img: Image = new_image(24, 24)
	var idx: int = STAFF_PORTRAIT_IDS.find(staff_id)
	rect(img, 0, 0, 24, 24, INK)
	if idx < 0:
		rect(img, 1, 1, 22, 22, Color(0.80, 0.78, 0.72))
		return img
	var look: Dictionary = LOOKS[LOOK_PREP_ASSISTANT + idx]
	var hair: Color = _c(str(look["hair"]))
	var shirt: Color = _c(str(look["shirt"]))
	rect(img, 1, 1, 22, 22, _c(str(STAFF_PORTRAIT_BG[idx])))
	var skin_d: Color = SKIN.darkened(0.12)
	# 어깨 + 앞치마 + 목
	rect(img, 3, 18, 18, 5, shirt)
	rect(img, 2, 20, 20, 3, shirt)
	rect(img, 8, 19, 8, 4, Color(0.9, 0.9, 0.88))
	rect(img, 8, 19, 8, 1, RED)
	rect(img, 10, 15, 4, 4, skin_d)
	# 얼굴
	rect(img, 7, 5, 10, 11, SKIN)
	rect(img, 6, 7, 12, 7, SKIN)
	px(img, 5, 10, SKIN)
	px(img, 18, 10, SKIN)
	if idx == 0:
		var cap: Color = _c(str(look["cap"]))
		rect(img, 5, 3, 14, 4, cap)
		rect(img, 6, 2, 12, 1, cap)
		rect(img, 5, 7, 2, 3, hair)
		rect(img, 17, 7, 2, 3, hair)
		rect(img, 20, 8, 1, 12, WOOD_LL)
		rect(img, 19, 6, 3, 3, Color(0.72, 0.75, 0.78))
	else:
		rect(img, 6, 3, 12, 3, hair)
		rect(img, 4, 5, 3, 14, hair)
		rect(img, 17, 5, 3, 14, hair)
		rect(img, 7, 5, 10, 2, hair)
		rect(img, 4, 21, 8, 2, Color(0.72, 0.75, 0.78))
	# 눈/볼/입
	rect(img, 9, 10, 1, 2, INK)
	rect(img, 14, 10, 1, 2, INK)
	px(img, 8, 12, BLUSH)
	px(img, 15, 12, BLUSH)
	px(img, 12, 12, skin_d)
	rect(img, 10, 14, 4, 1, RED_D)
	px(img, 9, 13, RED_D)
	px(img, 14, 13, RED_D)
	return img


# ---------- 그릇 ----------

## 글자 없는 72x26 지역 풍경. 진행률은 배낭 여행자의 위치·걸음만 바꾸며 보상과 무관하다.
static func exploration_image(region: String, progress: float = 1.0, moving: bool = false) -> Image:
	var img: Image = new_image(72, 26)
	img.fill(Color(0.91, 0.88, 0.71))
	rect(img, 0, 0, 72, 14, Color(0.73, 0.84, 0.79))
	if region == "market":
		for x in [3, 26, 49]:
			rect(img, x, 7, 18, 12, Color(0.53, 0.36, 0.20))
			rect(img, x - 1, 5, 20, 4, RED)
			for stripe in range(0, 20, 4):
				rect(img, x - 1 + stripe, 5, 2, 4, WHITE)
			rect(img, x + 2, 10, 14, 5, Color(0.28, 0.25, 0.17))
			for crate in 3:
				rect(img, x + 2 + crate * 4, 14, 3, 3, Color(0.86, 0.70, 0.29))
	elif region == "harbor":
		rect(img, 0, 10, 72, 10, Color(0.31, 0.62, 0.68))
		for x in range(2, 70, 8):
			line(img, Vector2(x, 13), Vector2(x + 4, 13), WHITE)
		poly(img, [Vector2(35, 13), Vector2(64, 13), Vector2(58, 18), Vector2(41, 18)], Color(0.43, 0.29, 0.18))
		line(img, Vector2(49, 1), Vector2(49, 13), INK)
		poly(img, [Vector2(50, 2), Vector2(60, 11), Vector2(50, 11)], WHITE)
		rect(img, 2, 15, 24, 6, Color(0.64, 0.45, 0.26))
		for x in [4, 14, 24]:
			rect(img, x, 13, 2, 9, INK)
	else:
		poly(img, [Vector2(0, 17), Vector2(20, 1), Vector2(36, 17)], Color(0.30, 0.48, 0.34))
		poly(img, [Vector2(26, 17), Vector2(51, 0), Vector2(72, 17)], Color(0.43, 0.60, 0.40))
		for x in [3, 13, 59, 66]:
			rect(img, x + 2, 11, 2, 9, Color(0.43, 0.29, 0.18))
			poly(img, [Vector2(x, 13), Vector2(x + 3, 6), Vector2(x + 6, 13)], Color(0.22, 0.40, 0.28))
	rect(img, 0, 22, 72, 4, Color(0.67, 0.52, 0.34))
	for x in range(1, 70, 7):
		px(img, x, 24, WHITE)
	var p: float = clampf(progress, 0.0, 1.0) if is_finite(progress) else 0.0
	var frame: int = int(p * 12.0) % 2 if moving else 0
	blit(img, person_image(9, "walk" if moving else "stand", frame, false), Vector2i(3 + int(p * 50.0), 5))
	return img

static func broth_color(config: Dictionary) -> Color:
	var base: Color = _base_broth_color(config)
	var process: Dictionary = config.get("process", {})
	# 제조한 육수의 맑기 차이만 표현한다. 기본 공법은 이전 픽셀/색을 그대로 돌려준다.
	if process.get("broth", "standard") == "gentle":
		return base.lightened(0.10)
	if process.get("broth", "standard") == "rolling":
		return base.darkened(0.12)
	return base


static func _base_broth_color(config: Dictionary) -> Color:
	match str(config.get("broth", "")):
		"broth_tonkotsu":
			return Color(0.95, 0.88, 0.74)
		"broth_chicken":
			return Color(0.88, 0.68, 0.30)
		"broth_dashi":
			return Color(0.78, 0.74, 0.46)
		"broth_clam":
			return Color(0.70, 0.83, 0.81)
	return Color(0.88, 0.80, 0.62)


## 토핑 하나일 때의 예전 그림(그릇 왼쪽/오른쪽 위 고정 위치). 단일 토핑 레시피의 모습을 바꾸지 않는다.
static func _draw_topping_single(img: Image, id: String) -> void:
	match id:
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
		"topping_pickle":
			rect(img, 2, 1, 3, 1, Color(0.83, 0.82, 0.29))
			px(img, 3, 2, Color(0.55, 0.65, 0.24))
		"topping_mushroom":
			rect(img, 2, 1, 3, 1, Color(0.52, 0.33, 0.20))
			px(img, 3, 2, Color(0.88, 0.78, 0.57))
		"topping_citrus_peel":
			px(img, 2, 1, Color(1.0, 0.83, 0.12))
			px(img, 3, 2, Color(1.0, 0.83, 0.12))
			px(img, 4, 1, Color(0.94, 0.68, 0.08))


## 토핑이 둘 이상일 때의 2칸 폭 작은 모양. ax 는 왼쪽 끝 x(2/5/8). 모두 국물 면 두 줄(y 1~2)과 테두리(y 0) 안에 있다.
static func _draw_topping_compact(img: Image, id: String, ax: int) -> void:
	match id:
		"topping_chashu":
			rect(img, ax, 1, 2, 1, Color(0.80, 0.54, 0.44))
			px(img, ax, 2, Color(0.66, 0.40, 0.32))
			px(img, ax + 1, 2, Color(0.80, 0.54, 0.44))
		"topping_egg":
			rect(img, ax, 1, 2, 1, WHITE)
			px(img, ax, 2, WHITE)
			px(img, ax + 1, 2, Color(0.96, 0.66, 0.16))
		"topping_sprouts":
			px(img, ax, 1, Color(0.88, 0.95, 0.70))
			px(img, ax + 1, 1, Color(0.50, 0.75, 0.35))
			px(img, ax, 2, Color(0.50, 0.75, 0.35))
			px(img, ax + 1, 2, Color(0.88, 0.95, 0.70))
		"topping_nori":
			rect(img, ax, 0, 2, 2, Color(0.12, 0.20, 0.16))
		"topping_pickle":
			rect(img, ax, 1, 2, 1, Color(0.83, 0.82, 0.29))
			px(img, ax + 1, 2, Color(0.55, 0.65, 0.24))
		"topping_mushroom":
			rect(img, ax, 1, 2, 1, Color(0.52, 0.33, 0.20))
			px(img, ax + 1, 2, Color(0.88, 0.78, 0.57))
		"topping_citrus_peel":
			px(img, ax, 1, Color(1.0, 0.83, 0.12))
			px(img, ax + 1, 2, Color(0.94, 0.68, 0.08))


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
	var process: Dictionary = config.get("process", {})
	if process.get("noodle", "standard") == "moist":
		noodle = noodle.lightened(0.12)
	elif process.get("noodle", "standard") == "rested":
		noodle = noodle.darkened(0.10)
	for x in range(3, 9, 1 if n == "noodle_thin" else 2):
		px(img, x, 1, noodle)
		px(img, x + 1 if n != "noodle_thin" else x, 2, noodle)
	# 선택한 토핑을 모두 그린다(Catalog.toppings_of 하나의 읽기 경로, 카탈로그 순서). 하나뿐이면 예전 그림과 픽셀까지 같다.
	var tops: Array = Catalog.canonical_toppings(Catalog.toppings_of(config))
	if tops.size() == 1:
		_draw_topping_single(img, str(tops[0]))
	else:
		# 둘 이상: 12x7 그릇 안의 국물 면(왼쪽 x2, 가운데 x5, 오른쪽 x8)에 토핑마다 2칸 폭의 작은 모양으로 나눠 얹는다.
		# 둘이면 왼쪽/오른쪽, 셋이면 왼쪽/가운데/오른쪽. 토핑마다 색과 모양이 달라 서로 구별된다.
		var anchors: Array = [2, 8] if tops.size() == 2 else ([2, 5, 8] if tops.size() == 3 else [1, 4, 7, 9])
		for i in mini(tops.size(), anchors.size()):
			_draw_topping_compact(img, str(tops[i]), int(anchors[i]))
	var oil: Color = Color(0, 0, 0, 0)
	match str(config.get("oil", "")):
		"oil_garlic":
			oil = Color(0.55, 0.34, 0.14)
		"oil_chili":
			oil = Color(0.85, 0.16, 0.08)
		"oil_scallion":
			oil = Color(0.36, 0.62, 0.28)
		"oil_shrimp":
			oil = Color(0.95, 0.43, 0.20)
		"oil_pepper":
			oil = Color(0.17, 0.35, 0.23)
		"oil_roasted_sesame":
			oil = Color(0.77, 0.52, 0.19)
	if oil.a > 0.0:
		px(img, 6, 1, oil)
		px(img, 5, 2, oil)
		px(img, 8, 2, oil)
	# 새 매실 간만 색을 더한다. 예전 간/단일 토핑 그림은 그대로 유지한다.
	if str(config.get("tare", "")) == "tare_plum":
		px(img, 4, 2, Color(0.60, 0.25, 0.37))
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
		elif id == "tare_plum":
			sauce = Color(0.60, 0.25, 0.37)
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
		elif id == "oil_shrimp":
			oc = Color(0.95, 0.43, 0.20)
		elif id == "oil_pepper":
			oc = Color(0.17, 0.35, 0.23)
		elif id == "oil_roasted_sesame":
			oc = Color(0.77, 0.52, 0.19)
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
			"topping_pickle":
				for y in [2, 5, 8]:
					rect(img, 2, y, 8, 2, Color(0.83, 0.82, 0.29))
					px(img, 9, y, Color(0.55, 0.65, 0.24))
			"topping_mushroom":
				rect(img, 3, 4, 6, 6, Color(0.88, 0.78, 0.57))
				rect(img, 1, 2, 10, 4, Color(0.52, 0.33, 0.20))
				px(img, 4, 3, WHITE)
				px(img, 8, 4, WHITE)
			"topping_citrus_peel":
				for x in [2, 5, 8]:
					rect(img, x, 3, 1, 5, Color(1.0, 0.83, 0.12))
					px(img, x + 1, 7, Color(0.94, 0.68, 0.08))
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
