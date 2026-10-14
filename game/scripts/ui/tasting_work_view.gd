extends Control
## 시식 준비 연출: 솥(국물이 차오름·거품·불꽃) → 면 건지개(면이 담겼다 올라옴) → 그릇(면이 옮겨지고 김이 오름).
## 글자는 그리지 않는다(단계 이름/퍼센트는 옆의 일반 라벨이 보여 준다). 논리 캔버스 48x30 을 정수 배율로 최근접 확대한다.
## 움직임은 진행률(실제 작업 진행)과 애니메이션 시간 _t 에서만 나오며, 이 컨트롤은 돈/기록 규칙을 전혀 모른다.

const Art = preload("res://scripts/ui/pixel_art.gd")
const Work = preload("res://scripts/ui/tasting_work.gd")

const W: int = 48
const H: int = 30

const BG: Color = Color(0.88, 0.80, 0.64)
const INK: Color = Color(0.149, 0.102, 0.071)
const STEEL: Color = Color(0.74, 0.77, 0.80)
const STEEL_D: Color = Color(0.44, 0.47, 0.52)
const COUNTER: Color = Color(0.29, 0.17, 0.09)
const COUNTER_L: Color = Color(0.48, 0.29, 0.15)
const FLAME_A: Color = Color(0.92, 0.36, 0.12)
const FLAME_B: Color = Color(1.0, 0.82, 0.45)
const NOODLE: Color = Color(0.97, 0.88, 0.58)

var _progress: float = 0.0
var _config: Dictionary = {}
var _t: float = 0.0
var _bowl_tex: ImageTexture = null


func _init() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(float(W * 3), float(H * 3))


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_t += delta
	queue_redraw()


## 진행률(0~1)과 시식 구성(그릇/국물 색용). 구성이 바뀌면 그릇 텍스처를 다시 만든다.
func set_state(progress_value: float, config: Dictionary) -> void:
	_progress = clampf(progress_value, 0.0, 1.0)
	if config != _config:
		_config = config.duplicate(true)
		_bowl_tex = Art.tex(Art.bowl_image(_config))
	queue_redraw()


func anim_time() -> float:
	return _t


## 같은 (진행률, 시간)이면 항상 같은 값: 그리기와 검사가 함께 쓰는 순수 계산.
## level = 솥 국물 높이(0~1), depth = 면 건지개가 잠긴 정도(0~1, 면 단계에서만 >0), bowl_alpha = 그릇이 또렷해진 정도,
## transfer = 면이 솥에서 그릇으로 옮겨지는 정도(시식 단계, 0~1), flame = 불꽃 모양 교대(0/1), steam = 김 세기.
static func frame_params(progress_value: float, t: float) -> Dictionary:
	var p: float = clampf(progress_value, 0.0, 1.0)
	var phase: int = Work.phase_for(p)
	var b_end: float = float((Work.PHASES[0] as Dictionary)["end"])
	var n_end: float = float((Work.PHASES[1] as Dictionary)["end"])
	var level: float = clampf(p / b_end, 0.0, 1.0)
	var depth: float = 0.0
	var transfer: float = 0.0
	var bowl_alpha: float = 0.35
	if phase == 1:
		var local1: float = clampf((p - b_end) / (n_end - b_end), 0.0, 1.0)
		depth = sin(local1 * PI) * (0.85 + 0.15 * sin(t * 9.0))
	elif phase == 2:
		var local2: float = clampf((p - n_end) / (1.0 - n_end), 0.0, 1.0)
		transfer = local2
		bowl_alpha = 0.35 + 0.65 * local2
	var steam: float = 0.55 if phase == 0 else (1.0 if phase == 1 else 0.6)
	return {
		"phase": phase,
		"level": level,
		"depth": maxf(0.0, depth),
		"transfer": transfer,
		"bowl_alpha": bowl_alpha,
		"flame": int(floor(t * 8.0)) % 2,
		"steam": steam,
	}


## 검사용: 한 프레임의 모양을 문자열로(예: 시간이 흐르면/진행이 바뀌면 달라진다). 픽셀 캡처 없이도 움직임 유무를 확인한다.
func signature() -> String:
	var fp: Dictionary = frame_params(_progress, _t)
	return "%d|%.3f|%.3f|%.3f|%d" % [int(fp["phase"]), float(fp["level"]), float(fp["depth"]), float(fp["transfer"]), int(fp["flame"])]


func _scale_and_origin() -> Array:
	var s: int = maxi(1, int(floor(minf(size.x / float(W), size.y / float(H)))))
	var o: Vector2 = Vector2(floorf((size.x - float(W * s)) * 0.5), floorf((size.y - float(H * s)) * 0.5))
	return [s, o]


func _draw() -> void:
	var so: Array = _scale_and_origin()
	var s: int = int(so[0])
	var o: Vector2 = so[1]
	var fp: Dictionary = frame_params(_progress, _t)
	var fs: float = float(s)

	var fill: Callable = func(x: int, y: int, w: int, h: int, c: Color) -> void:
		draw_rect(Rect2(o + Vector2(float(x), float(y)) * fs, Vector2(float(w), float(h)) * fs), c)

	fill.call(0, 0, W, H, BG)
	# 조리대와 화구
	fill.call(0, 28, W, 2, COUNTER)
	fill.call(0, 27, W, 1, COUNTER_L)
	fill.call(2, 25, 24, 3, STEEL_D)
	# 불꽃
	var flame_t: int = int(fp["flame"])
	for i in 4:
		var fx: int = 6 + i * 5
		var fh: int = 3 if (i + flame_t) % 2 == 0 else 2
		fill.call(fx, 25 - fh, 3, fh, FLAME_A)
		fill.call(fx + 1, 25 - fh + 1, 1, maxi(1, fh - 1), FLAME_B)
	# 솥: 몸통, 안쪽(어둡게), 국물, 테두리, 손잡이
	fill.call(4, 11, 20, 12, STEEL)
	fill.call(4, 11, 20, 1, STEEL_D)
	fill.call(5, 12, 18, 10, STEEL_D)
	var broth: Color = Art.broth_color(_config)
	var broth_h: int = int(round(float(fp["level"]) * 10.0))
	if broth_h > 0:
		fill.call(5, 22 - broth_h, 18, broth_h, broth)
		fill.call(5, 22 - broth_h, 18, 1, broth.lightened(0.15))
		# 거품: 국물 표면 위로 올라왔다 터진다(시간에 따라 위치가 달라짐).
		for k in 4:
			var ph: float = fposmod(_t * 0.9 + float(k) * 0.27, 1.0)
			var bx: int = 7 + int(floor(fposmod(float(k) * 5.3 + _t * 1.7, 15.0)))
			var by: int = 22 - broth_h - int(floor(ph * 3.0))
			if ph < 0.8 and by >= 12:
				fill.call(bx, by, 1, 1, Color(1, 1, 1, 0.9 * (1.0 - ph)))
	fill.call(3, 10, 22, 2, STEEL)
	fill.call(3, 10, 22, 1, INK)
	fill.call(1, 13, 3, 2, STEEL_D)
	fill.call(24, 13, 3, 2, STEEL_D)

	# 면 건지개: 손잡이는 위에서 내려오고 바구니와 면발이 솥 안으로 잠겼다 올라온다.
	var depth: float = float(fp["depth"])
	if int(fp["phase"]) == 1 and depth > 0.0:
		var by2: int = 2 + int(round(depth * 9.0))
		fill.call(21, 0, 1, by2 + 1, COUNTER_L)
		fill.call(10, by2, 11, 2, STEEL)
		fill.call(10, by2 + 1, 11, 1, STEEL_D)
		for i in 5:
			var wig: int = 1 if (int(floor(_t * 8.0)) + i) % 2 == 0 else 0
			fill.call(11 + i * 2, by2 + 2, 1, 3 + wig, NOODLE)

	# 면이 솥에서 그릇으로 옮겨진다(시식 단계): 세 가닥이 시차를 두고 포물선으로 날아간다.
	var transfer: float = float(fp["transfer"])
	if int(fp["phase"]) == 2:
		for k in 3:
			var u: float = fposmod(transfer * 1.6 + float(k) / 3.0, 1.0)
			var px: int = 24 + int(round(u * 12.0))
			var py: int = 10 + int(round(u * 8.0 - 6.0 * sin(u * PI)))
			fill.call(px, py, 2, 1, NOODLE)

	# 그릇: 처음엔 흐릿한 빈 그릇 자리, 시식 단계에서 또렷해지며 한 번 튄다.
	if _bowl_tex != null:
		var bounce: int = -1 if (int(fp["phase"]) == 2 and transfer < 0.12) else 0
		var bpos: Vector2 = o + Vector2(31.0, float(19 + bounce)) * fs
		draw_texture_rect(_bowl_tex, Rect2(bpos, Vector2(12.0, 7.0) * fs), false, Color(1, 1, 1, float(fp["bowl_alpha"])))
		fill.call(30, 26, 14, 1, COUNTER_L)

	# 김: 솥 위(항상)와 그릇 위(시식 단계)
	var strength: float = float(fp["steam"])
	for k in 5:
		var ph2: float = fposmod(_t * 0.8 + float(k) / 5.0, 1.0)
		var sx: int = 7 + k * 3 + int(round(sin(ph2 * 6.28 + float(k)) * 1.2))
		var sy: int = 9 - int(floor(ph2 * 9.0))
		fill.call(sx, maxi(0, sy), 1, 2, Color(1, 1, 1, strength * (1.0 - ph2)))
	if int(fp["phase"]) == 2:
		for k in 3:
			var ph3: float = fposmod(_t * 0.7 + float(k) / 3.0, 1.0)
			var bx2: int = 34 + k * 3 + int(round(sin(ph3 * 6.28 + float(k)) * 1.0))
			var by3: int = 18 - int(floor(ph3 * 8.0))
			fill.call(bx2, maxi(0, by3), 1, 2, Color(1, 1, 1, transfer * (1.0 - ph3)))

	# 바깥 테두리
	draw_rect(Rect2(o, Vector2(float(W), float(H)) * fs), INK, false, fs)
