extends Control
## 코드로 그린 라멘 그릇. 할당된 영역(size)에 맞춰 300x220 설계 좌표를 균등 축소/확대한다.
## config(재료 id들)에 따라 국물 색, 면 굵기, 토핑, 향미유가 달라지고 reveal(0~1)로 시식 연출을 한다.

const Catalog = preload("res://scripts/domain/ingredient_catalog.gd")

const DESIGN: Vector2 = Vector2(300.0, 220.0)
const INK: Color = Color(0.17, 0.15, 0.13)
const PAPER: Color = Color(0.96, 0.94, 0.88)
const VERMILION: Color = Color(0.78, 0.26, 0.17)
const TEAL: Color = Color(0.25, 0.48, 0.46)

var config: Dictionary = {}
var reveal: float = 1.0:
	set(value):
		reveal = clampf(value, 0.0, 1.0)
		queue_redraw()
var _time: float = 0.0


func _ready() -> void:
	set_process(true)


func _process(delta: float) -> void:
	# 김이 천천히 흔들리도록 보이는 동안만 다시 그린다.
	if is_visible_in_tree():
		_time += delta
		queue_redraw()


func set_config(new_config: Dictionary) -> void:
	config = new_config.duplicate(true)
	queue_redraw()


## 시식 연출: 그릇이 살짝 튀어 오르며 김이 짙어진다(약 0.7초, 입력을 막지 않음).
func play_reveal() -> void:
	reveal = 0.0
	var tw: Tween = create_tween()
	tw.tween_property(self, "reveal", 1.0, 0.7)


func _id(slot: String) -> String:
	return str(config.get(slot, ""))


func _broth_color() -> Color:
	match _id("broth"):
		"broth_tonkotsu":
			return Color(0.93, 0.85, 0.70)
		"broth_chicken":
			return Color(0.86, 0.66, 0.30)
		"broth_dashi":
			return Color(0.80, 0.74, 0.46)
	return Color(0.88, 0.80, 0.62)


func _ellipse(center: Vector2, rx: float, ry: float, steps: int = 40) -> PackedVector2Array:
	var pts: PackedVector2Array = PackedVector2Array()
	for i in steps:
		var a: float = TAU * float(i) / float(steps)
		pts.append(center + Vector2(cos(a) * rx, sin(a) * ry))
	return pts


func _draw() -> void:
	var s: float = minf(size.x / DESIGN.x, size.y / DESIGN.y)
	if s <= 0.0:
		return
	var pop: float = 1.0 + 0.05 * sin(reveal * PI)
	var scale_v: Vector2 = Vector2(s * pop, s * pop)
	var origin: Vector2 = (size - DESIGN * scale_v) * 0.5
	draw_set_transform(origin, 0.0, scale_v)

	# 간판처럼 떠오르는 붉은 해
	draw_circle(Vector2(150.0, 118.0), 104.0, Color(0.78, 0.26, 0.17, 0.16))

	var rim_c: Vector2 = Vector2(150.0, 120.0)
	# 그릇 몸통(아래쪽 반타원)
	var body: PackedVector2Array = PackedVector2Array()
	for i in 31:
		var a: float = PI * float(i) / 30.0
		body.append(rim_c + Vector2(cos(a) * 108.0, sin(a) * 82.0))
	draw_colored_polygon(body, VERMILION)
	draw_rect(Rect2(112.0, 198.0, 76.0, 8.0), INK)
	# 그릇 띠 장식(청록 선)
	var band: PackedVector2Array = PackedVector2Array()
	for i in 21:
		var a2: float = PI * (0.12 + 0.76 * float(i) / 20.0)
		band.append(rim_c + Vector2(cos(a2) * 100.0, 40.0 + sin(a2) * 36.0))
	draw_polyline(band, TEAL, 4.0, true)
	# 입구 테두리와 국물
	draw_colored_polygon(_ellipse(rim_c, 108.0, 24.0), Color(0.62, 0.17, 0.12))
	var broth: Color = _broth_color()
	draw_colored_polygon(_ellipse(rim_c + Vector2(0.0, 1.0), 98.0, 18.0), broth)

	_draw_noodles(rim_c)
	_draw_oil(rim_c)
	_draw_topping(rim_c)
	_draw_steam()
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_noodles(c: Vector2) -> void:
	var noodle: String = _id("noodle")
	if noodle == "":
		return
	var width: float = 1.6
	var color: Color = Color(0.97, 0.88, 0.58)
	var freq: float = 0.5
	match noodle:
		"noodle_medium":
			width = 2.6
			freq = 0.35
		"noodle_thick":
			width = 4.0
			freq = 0.22
	for row in 5:
		var y: float = c.y - 8.0 + float(row) * 4.5
		var half: float = 82.0 * sqrt(maxf(0.0, 1.0 - pow((y - c.y) / 17.0, 2.0))) * 0.9
		var pts: PackedVector2Array = PackedVector2Array()
		var x: float = c.x - half
		while x <= c.x + half:
			pts.append(Vector2(x, y + sin(x * freq + float(row)) * 1.8))
			x += 4.0
		if pts.size() > 1:
			draw_polyline(pts, color, width, true)


func _draw_oil(c: Vector2) -> void:
	var oil_color: Color = Color(0, 0, 0, 0)
	match _id("oil"):
		"oil_garlic":
			oil_color = Color(0.45, 0.28, 0.12, 0.85)
		"oil_chili":
			oil_color = Color(0.82, 0.18, 0.10, 0.85)
		"oil_scallion":
			oil_color = Color(0.36, 0.60, 0.28, 0.85)
	if oil_color.a == 0.0:
		return
	for i in 9:
		var a: float = float(i) * 2.4
		var r: float = 20.0 + float(i % 4) * 14.0
		draw_circle(c + Vector2(cos(a) * r, sin(a) * r * 0.17), 2.4, oil_color)


## 선택한 토핑을 모두 그린다(Catalog.toppings_of). 둘 이상이면 그릇 위에서 좌우로 나눠 놓는다.
func _draw_topping(c: Vector2) -> void:
	var tops: Array = Catalog.canonical_toppings(Catalog.toppings_of(config))
	for i in tops.size():
		var shift: Vector2 = Vector2.ZERO
		if tops.size() > 1:
			shift = Vector2(float(i) * 30.0 - float(tops.size() - 1) * 15.0, 0.0)
		_draw_one_topping(str(tops[i]), c + shift)


func _draw_one_topping(topping_id: String, c: Vector2) -> void:
	match topping_id:
		"topping_chashu":
			for i in 2:
				var p: Vector2 = c + Vector2(-34.0 + float(i) * 26.0, -4.0 + float(i) * 4.0)
				draw_colored_polygon(_ellipse(p, 20.0, 8.0), Color(0.76, 0.52, 0.42))
				draw_arc(p, 11.0, 0.0, TAU, 20, Color(0.58, 0.36, 0.28), 1.5)
		"topping_egg":
			var e: Vector2 = c + Vector2(-26.0, -2.0)
			draw_colored_polygon(_ellipse(e, 17.0, 9.0), Color(0.98, 0.96, 0.90))
			draw_colored_polygon(_ellipse(e, 7.0, 4.0), Color(0.96, 0.66, 0.16))
		"topping_sprouts":
			for i in 9:
				var base: Vector2 = c + Vector2(-30.0 + float(i) * 6.0, 0.0)
				draw_line(base, base + Vector2(float(i % 3) * 3.0 - 3.0, -12.0 - float(i % 4) * 2.0), Color(0.92, 0.95, 0.78), 2.0, true)
		"topping_nori":
			var pts: PackedVector2Array = PackedVector2Array([
				c + Vector2(40.0, -26.0), c + Vector2(62.0, -22.0),
				c + Vector2(58.0, 4.0), c + Vector2(36.0, 0.0)])
			draw_colored_polygon(pts, Color(0.12, 0.20, 0.16))
	# 파 고명(오른쪽 위에 흩뿌린 초록 점)은 파기름일 때만 의미가 있어 향미유에서 처리한다.


func _draw_steam() -> void:
	var strength: float = 0.25 + 0.45 * reveal
	for i in 3:
		var x0: float = 110.0 + float(i) * 40.0
		var pts: PackedVector2Array = PackedVector2Array()
		for k in 12:
			var t: float = float(k) / 11.0
			var y: float = 96.0 - t * 66.0
			var x: float = x0 + sin(t * 5.0 + _time * 1.6 + float(i) * 1.7) * (5.0 + 5.0 * t)
			pts.append(Vector2(x, y))
		draw_polyline(pts, Color(TEAL.r, TEAL.g, TEAL.b, strength * (0.8 - 0.1 * float(i))), 3.0, true)
