extends Control
## 별 5개 평점 표시. 글꼴 글리프에 의존하지 않도록 직접 그린다.

const FILLED: Color = Color(0.78, 0.26, 0.17)
const EMPTY: Color = Color(0.80, 0.74, 0.62)

var stars: int = 0:
	set(value):
		stars = clampi(value, 0, 5)
		queue_redraw()


func _init() -> void:
	custom_minimum_size = Vector2(132.0, 26.0)


func _draw() -> void:
	var cell: float = minf(size.x / 5.0, size.y)
	var r: float = cell * 0.42
	var total_w: float = cell * 5.0
	var x0: float = (size.x - total_w) * 0.5
	for i in 5:
		var center: Vector2 = Vector2(x0 + cell * (float(i) + 0.5), size.y * 0.5)
		var pts: PackedVector2Array = PackedVector2Array()
		for k in 10:
			var radius: float = r if k % 2 == 0 else r * 0.45
			var a: float = -PI * 0.5 + PI * float(k) / 5.0
			pts.append(center + Vector2(cos(a), sin(a)) * radius)
		draw_colored_polygon(pts, FILLED if i < stars else EMPTY)
