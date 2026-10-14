extends SceneTree
## 선택 실행 QA: 실제 UI 씬을 만들어 데스크톱(1280x800)과 세로(390x844)에서 스크린샷을 저장한다.
## 실제 렌더러가 필요하므로 --headless 없이 실행한다.
##   Godot --path game --script res://tests/qa_capture.gd -- --qa-out=<절대경로> [--dev-data-dir=<절대경로>]
## --dev-data-dir 이 없으면 <qa-out>/qa_data 를 저장 폴더로 쓴다(user:// 는 절대 쓰지 않는다).
## 화면 크기별로 SubViewport 를 만들기 때문에 창 크기와 무관하게 정확한 해상도로 캡처된다.
## 매장 중심 흐름을 실제 UI의 pressed 신호로 밟는다: 빈 가게 → 메뉴 개발 서랍 → 시식/개정/노트 → 영업 시작 →
## 진행 중 장면·잠금 → 끝나서 정산 → 중단 → 도중 종료 후 재시작(영업 전 상태). 실패하면 종료 코드 1.
## 영업 시간은 실제 시간을 기다리지 않고 세션 API(advance/run_to_end)로 앞당긴다(화면 갱신은 실제 프레임이 한다).

const SaveServiceScript = preload("res://scripts/services/save_service.gd")

# scale: 장면 정수 배율의 하한. 등각 장면의 의도한 캔버스에 맞춘 값이다 — 가로 320x152 → 1280x608 (배율 4),
# 세로 176x264 → 352x528 (배율 2, 이전 128x208 프론탈 장면은 배율 3). 화면 55% 이상/뷰포트 포함/HUD 비겹침 검사는 그대로다.
const PROFILES: Array = [
	{"tag": "desktop", "w": 1280, "h": 800, "scale": 4},
	{"tag": "portrait", "w": 390, "h": 844, "scale": 2},
]

var _out_dir: String = ""
var _data_root: String = ""
var _failures: Array[String] = []
var _checks: int = 0
# 명시적 --layout-only 일 때만 켜진다(실패 시 자동 전환 없음). 이미지 추출과 frame_post_draw 대기만 건너뛰며
# 레이아웃/핸들러/도달성/오버플로 검사는 모두 그대로 실행한다. 시각 렌더링 검증이 아니다.
var _layout_only: bool = false


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	args.append_array(OS.get_cmdline_args())
	var dev_dir: String = ""
	for a in args:
		if a.begins_with("--qa-out="):
			_out_dir = a.substr("--qa-out=".length())
		elif a.begins_with("--dev-data-dir="):
			dev_dir = a.substr("--dev-data-dir=".length())
		elif a == "--layout-only":
			_layout_only = true
	if not _is_absolute(_out_dir):
		printerr("FAIL: --qa-out=<절대 경로> 가 필요해요.")
		quit(2)
		return
	if dev_dir != "" and not _is_absolute(dev_dir):
		printerr("FAIL: --dev-data-dir 는 절대 경로여야 해요.")
		quit(2)
		return
	_data_root = dev_dir if dev_dir != "" else _out_dir.path_join("qa_data")
	for p in [_out_dir, _data_root]:
		if not DirAccess.dir_exists_absolute(str(p)):
			var err: int = DirAccess.make_dir_recursive_absolute(str(p))
			if err != OK:
				printerr("FAIL: 폴더를 만들 수 없어요: %s (%s)" % [str(p), error_string(err)])
				quit(2)
				return
	if _layout_only:
		print("LAYOUT ONLY: no screenshots or visual rendering verified")
	_run()


func _is_absolute(path: String) -> bool:
	if path == "" or path.begins_with("user://") or path.begins_with("res://"):
		return false
	return path.begins_with("/") or (path.length() > 2 and path[1] == ":")


func _run() -> void:
	for p in PROFILES:
		var prof: Dictionary = p
		await _run_profile(str(prof["tag"]), Vector2i(int(prof["w"]), int(prof["h"])), int(prof["scale"]))
	var mode: String = "layout-only (no screenshots)" if _layout_only else "capture"
	print("QA mode=%s checks=%d failures=%d out=%s" % [mode, _checks, _failures.size(), _out_dir])
	if _layout_only:
		print("LAYOUT ONLY: no screenshots or visual rendering verified")
	for f in _failures:
		printerr("FAIL: " + f)
	quit(0 if _failures.is_empty() else 1)


# ---------- 보조 ----------

func _check(cond: bool, message: String) -> void:
	_checks += 1
	if not cond:
		_failures.append(message)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _settle() -> void:
	await _frames(3)
	await create_timer(0.15).timeout
	await _frames(2)


func _find(app: Node, node_name: String) -> Node:
	return app.find_child(node_name, true, false)


func _text_of(app: Node, node_name: String) -> String:
	var n: Node = _find(app, node_name)
	if n == null:
		_check(false, "컨트롤 없음: " + node_name)
		return ""
	return str(n.get("text"))


func _press(app: Node, node_name: String) -> void:
	var n: Node = _find(app, node_name)
	if n == null or not (n is BaseButton):
		_check(false, "버튼을 찾을 수 없어요: " + node_name)
		return
	var b: BaseButton = n
	if b.disabled:
		_check(false, "버튼이 비활성이에요: " + node_name)
		return
	b.pressed.emit()


## 게임 상태 객체(GameState)에서 값/메서드를 읽는다.
func _state(app: Node) -> Object:
	return app.get("state") as Object


func _spawn(holder: SubViewport, data_dir: String) -> Node:
	var scene: PackedScene = load("res://scenes/main.tscn") as PackedScene
	var app: Node = scene.instantiate()
	# 사용자 저장소(user://)를 건드리지 않도록 저장 위치를 ready 전에 주입한다.
	app.set("data_location", {"ok": true, "dir": data_dir, "is_dev": true, "error": ""})
	holder.add_child(app)
	await _settle()
	return app


func _shot(holder: SubViewport, file_name: String) -> void:
	await _settle()
	if _layout_only:
		return
	await RenderingServer.frame_post_draw
	var img: Image = holder.get_texture().get_image()
	var path: String = _out_dir.path_join(file_name)
	var err: int = img.save_png(path)
	_check(err == OK, "스크린샷 저장 실패: " + path)
	_check(img.get_width() == holder.size.x and img.get_height() == holder.size.y, "스크린샷 크기 불일치: " + file_name)


func _collect(node: Node, out: Array[Control]) -> void:
	for child in node.get_children():
		if child is Control:
			var c: Control = child
			out.append(c)
		_collect(child, out)


func _scroll_of(node: Control) -> ScrollContainer:
	var p: Node = node.get_parent()
	while p != null:
		if p is ScrollContainer:
			return p
		p = p.get_parent()
	return null


## 현재 화면에서 컨트롤이 보이고, 필요하면 스크롤해서 화면 안에 들어오며, 터치 크기를 만족하는지 본다.
func _reachable(app: Node, vp: Vector2i, node_name: String) -> void:
	var n: Node = _find(app, node_name)
	if n == null or not (n is Control):
		_check(false, "컨트롤 없음: " + node_name)
		return
	var c: Control = n
	_check(c.is_visible_in_tree(), "보이지 않아요: " + node_name)
	var sc: ScrollContainer = _scroll_of(c)
	if sc != null:
		sc.ensure_control_visible(c)
		await _frames(2)
	var r: Rect2 = c.get_global_rect()
	var view: Rect2 = Rect2(Vector2(-1.0, -1.0), Vector2(vp) + Vector2(2.0, 2.0))
	_check(view.encloses(r), "화면 밖에 있어요: %s 컨트롤=%s 뷰포트=%s" % [node_name, str(r), str(vp)])
	if sc != null:
		var sr: Rect2 = sc.get_global_rect().grow(2.0)
		_check(sr.encloses(r), "스크롤 영역 안으로 들어오지 않아요: %s 뷰포트=%s 컨트롤=%s 스크롤영역=%s scroll_v=%d (컨트롤 높이 %.0f / 스크롤 영역 높이 %.0f)" % [node_name, str(vp), str(r), str(sc.get_global_rect()), sc.scroll_vertical, r.size.y, sc.size.y])
	if c is BaseButton:
		_check(c.size.y >= 44.0 and c.size.x >= 44.0, "터치 크기 44px 미만: %s 크기=%s 뷰포트=%s" % [node_name, str(c.size), str(vp)])


func _overflow(app: Node, vp: Vector2i, label: String) -> void:
	var all: Array[Control] = []
	_collect(app, all)
	for c in all:
		if not c.is_visible_in_tree():
			continue
		if c is ScrollContainer:
			var sc: ScrollContainer = c
			_check(not sc.get_h_scroll_bar().visible, "가로 스크롤이 생겼어요: %s %s" % [label, sc.name])
			if sc.get_child_count() > 0:
				var content: Control = sc.get_child(0) as Control
				_check(content.get_combined_minimum_size().x <= sc.size.x + 1.0, "스크롤 내용이 폭을 넘어요: %s %s" % [label, sc.name])
		var r: Rect2 = c.get_global_rect()
		if r.size.x <= 0.0:
			continue
		_check(r.position.x >= -1.0 and r.end.x <= float(vp.x) + 1.0, "가로로 화면을 벗어나요: %s %s %s" % [label, str(c.name), str(r)])


## 가게 장면이 HUD/상태 줄/하단 바와 겹치지 않고 정수 배율로 영역 안에 들어오는지 본다.
func _check_shop_layout(app: Node, vp: Vector2i, tag: String, expect_scale: int) -> void:
	var shop: Node = _find(app, "ShopView")
	_check(shop != null, tag + ": ShopView 없음")
	if shop == null:
		return
	var info: Dictionary = shop.call("scene_info")
	var rect: Rect2 = info["rect"]
	_check(int(info["scale"]) >= expect_scale, "%s: 장면 배율이 %d 미만이에요: %s" % [tag, expect_scale, str(info["scale"])])
	_check(Rect2(Vector2.ZERO, Vector2(vp)).encloses(rect), "%s: 장면이 화면 밖으로 나가요: %s" % [tag, str(rect)])
	# 장면이 화면의 대부분을 차지해야 한다(폼/대시보드가 아니라 가게가 주인공).
	_check(rect.size.x * rect.size.y >= float(vp.x * vp.y) * 0.55, "%s: 장면이 화면의 55%% 미만이에요: %s" % [tag, str(rect)])
	for name in ["Hud", "StatusStrip", "NavBar"]:
		var n: Node = _find(app, name)
		_check(n != null and n is Control, "%s: %s 없음" % [tag, name])
		if n != null and n is Control:
			var c: Control = n
			var cr: Rect2 = c.get_global_rect()
			_check(Rect2(Vector2(-1.0, -1.0), Vector2(vp) + Vector2(2.0, 2.0)).encloses(cr), "%s: %s 가 화면 밖 %s" % [tag, name, str(cr)])
			_check(not cr.intersects(rect), "%s: %s 가 장면을 가려요 %s vs %s" % [tag, name, str(cr), str(rect)])
	_check_status_text(app, tag)


## 글 줄 전체가 라벨 사각형 안에 들어오는지: 실제 줄바꿈 줄 수(get_line_count) x 글꼴 높이 + 줄 간격 <= 라벨 높이.
func _text_height_fits(label: Label) -> bool:
	var fs: int = label.get_theme_font_size("font_size")
	var font: Font = label.get_theme_font("font")
	var lines: int = label.get_line_count()
	var needed: float = float(lines) * font.get_height(fs) + float(maxi(0, lines - 1)) * float(label.get_theme_constant("line_spacing"))
	return needed <= label.size.y + 1.0


## 상태/안내 글이 전부 보이고(라벨·띠 높이 안) 하단 바와 겹치지 않는지.
func _check_status_text(app: Node, tag: String) -> void:
	var strip: Control = _find(app, "StatusStrip") as Control
	var nav: Control = _find(app, "NavBar") as Control
	if strip == null or nav == null:
		return
	var sr: Rect2 = strip.get_global_rect()
	_check(sr.end.y <= nav.get_global_rect().position.y + 0.5, "%s: 상태 띠가 하단 바와 겹쳐요 %s vs %s" % [tag, str(sr), str(nav.get_global_rect())])
	for name in ["ServiceStatusLabel", "ServiceNoteLabel"]:
		var label: Label = _find(app, name) as Label
		if label == null or label.text == "":
			continue
		var lr: Rect2 = label.get_global_rect()
		_check(_text_height_fits(label), "%s: %s 글이 라벨 높이를 넘쳐요 (줄 %d, 높이 %.0f)" % [tag, name, label.get_line_count(), label.size.y])
		_check(lr.position.y >= sr.position.y - 0.5 and lr.end.y <= sr.end.y + 0.5, "%s: %s 가 상태 띠 밖 %s vs %s" % [tag, name, str(lr), str(sr)])
		_check(lr.end.y <= nav.get_global_rect().position.y + 0.5, "%s: %s 가 하단 바 아래로 내려가요" % [tag, name])


## 피드백 카드 한 장: 점수는 한 줄이고 카드 안에 들어오며, 이름 전체와 별도 카드 안에 있다.
func _check_score_line(app: Node, id: String, tag: String) -> void:
	var card: Control = _find(app, "Card_" + id) as Control
	var score: Label = _find(app, "Score_" + id) as Label
	var stars: Control = _find(app, "Stars_" + id) as Control
	_check(card != null and score != null and stars != null, "%s: %s 카드 구성요소 없음" % [tag, id])
	if card == null or score == null or stars == null:
		return
	var cr: Rect2 = card.get_global_rect()
	_check(score.get_line_count() == 1, "%s: %s 점수가 한 줄이 아니에요 (%d줄: %s)" % [tag, id, score.get_line_count(), score.text])
	_check(cr.encloses(score.get_global_rect()), "%s: %s 점수가 카드 밖 %s vs %s" % [tag, id, str(score.get_global_rect()), str(cr)])
	_check(cr.encloses(stars.get_global_rect()), "%s: %s 별이 카드 밖" % [tag, id])
	var fs: int = score.get_theme_font_size("font_size")
	var text_w: float = score.get_theme_font("font").get_string_size(score.text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, fs).x
	_check(score.size.x >= text_w - 0.5, "%s: %s 점수 폭 %.0f 이 글자 폭 %.0f 보다 좁아요" % [tag, id, score.size.x, text_w])
	for child in card.find_children("*", "Label", true, false):
		var lab: Label = child
		if lab.get_theme_font_size("font_size") == 19:
			var nw: float = lab.get_theme_font("font").get_string_size(lab.text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 19).x
			_check(lab.size.x >= nw - 0.5, "%s: %s 이름 폭 %.0f 이 글자 폭 %.0f 보다 좁아요" % [tag, id, lab.size.x, nw])
			_check(lab.get_line_count() == 1, "%s: %s 이름이 한 줄이 아니에요" % [tag, id])


## 시식 버튼을 눌러 준비 작업을 시작하고, 격리된 이 인스턴스에서만 advance_work()로 끝까지 앞당긴다(실제 게임에는 이런 길이 없다).
## 옛 즉시 시식 흐름을 대체한다: 시작 직후에는 작업 중이어야 하고, 끝나면 작업이 없어야 한다.
func _finish_tasting(app: Node) -> void:
	_press(app, "TasteButton")
	_check(bool(app.call("work_active")), "시식 버튼은 준비 작업을 시작해야 해요")
	var completed: bool = bool(app.call("advance_work", 10.0))
	_check(completed, "준비 작업이 한 번에 완료돼야 해요")
	await create_timer(1.2).timeout
	_check(not bool(app.call("work_active")), "완료 뒤에는 작업이 없어야 해요")


func _read_file(path: String) -> String:
	# FileAccess.get_file_as_text 는 정적 API 가 아니므로 인스턴스로 연다. 열 수 없으면 명시적으로 "<없음>" 표식.
	if not FileAccess.file_exists(path):
		return "<없음>"
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	if f == null:
		return "<읽기 실패:%d>" % FileAccess.get_open_error()
	var text: String = f.get_as_text()
	f.close()
	return text


## 초상 한 장: 카드 안에 들어오고 48x48 이상이며 이름/별/점수와 겹치지 않는다(점수와 이름 폭은 _check_score_line 이 따로 본다).
func _check_portrait(app: Node, id: String, tag: String) -> void:
	var card: Control = _find(app, "Card_" + id) as Control
	var portrait: Control = _find(app, "Portrait_" + id) as Control
	var score: Control = _find(app, "Score_" + id) as Control
	var stars: Control = _find(app, "Stars_" + id) as Control
	_check(card != null and portrait != null and score != null and stars != null, "%s: %s 초상 구성요소 없음" % [tag, id])
	if card == null or portrait == null or score == null or stars == null:
		return
	var pr: Rect2 = portrait.get_global_rect()
	_check(card.get_global_rect().encloses(pr), "%s: %s 초상이 카드 밖 %s vs %s" % [tag, id, str(pr), str(card.get_global_rect())])
	_check(pr.size.x >= 47.5 and pr.size.y >= 47.5, "%s: %s 초상이 너무 작아요 %s" % [tag, id, str(pr.size)])
	_check(not pr.intersects(score.get_global_rect()) and not pr.intersects(stars.get_global_rect()), "%s: %s 초상이 별/점수와 겹쳐요" % [tag, id])
	for child in card.find_children("*", "Label", true, false):
		var lab: Label = child
		if lab.get_theme_font_size("font_size") == 19:
			_check(not pr.intersects(lab.get_global_rect()), "%s: %s 초상이 이름과 겹쳐요" % [tag, id])


## 세션 게임초를 앞당긴다(렌더링은 실제 프레임이 한다).
func _advance(app: Node, game_seconds: float) -> void:
	var st: Object = _state(app)
	var sess: Object = st.call("active_session")
	if sess != null:
		sess.call("advance", game_seconds)


# ---------- 시나리오 ----------

func _run_profile(tag: String, vp: Vector2i, expect_scale: int) -> void:
	var data_dir: String = _data_root.path_join(tag)
	DirAccess.make_dir_recursive_absolute(data_dir)
	SaveServiceScript.new(data_dir).remove_known_files()

	var holder: SubViewport = SubViewport.new()
	holder.size = vp
	holder.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(holder)
	var app: Node = await _spawn(holder, data_dir)
	var tabs: TabContainer = _find(app, "MainTabs") as TabContainer
	_check(tabs != null, "탭 컨테이너 없음")
	if tabs == null:
		holder.queue_free()
		return
	var overlay: Control = _find(app, "Overlay") as Control

	# 1) 첫 화면: 기본은 가게. 개발 서랍은 닫혀 있다.
	_check(not overlay.visible, tag + ": 기본 화면에서 개발 서랍은 닫혀 있어야 해요")
	_check(_text_of(app, "DayLabel").find("1일차") >= 0, tag + ": 시작은 1일차")
	_check(_text_of(app, "WalletLabel").find("30,000") >= 0, tag + ": 시작 자금 표시")
	_check(_text_of(app, "LoadStatusLabel").find("첫 방문") >= 0, tag + ": 첫 실행 상태 표시")
	_check(_text_of(app, "ServiceStatusLabel").find("메뉴가 없어요") >= 0, tag + ": 메뉴가 없을 때 다음 행동 안내: " + _text_of(app, "ServiceStatusLabel"))
	_check(_text_of(app, "ServiceNoteLabel").find("저장되지 않") >= 0, tag + ": 미완료 영업이 저장되지 않는다는 안내")
	_check(_text_of(app, "StartServiceButton").find("첫 메뉴") >= 0, tag + ": 시작 버튼이 메뉴 개발로 안내: " + _text_of(app, "StartServiceButton"))
	_check(not (_find(app, "StartServiceButton") as BaseButton).disabled, tag + ": 시작 버튼이 이유 없이 비활성이면 안 돼요")
	_check(not (_find(app, "SpeedButton") as Control).visible, tag + ": 영업 전에는 속도 버튼이 보이지 않아요")
	for name in ["DayLabel", "WalletLabel", "ClockLabel", "ServiceProgress", "ShopView", "ServiceStatusLabel", "DevButton", "StartServiceButton"]:
		await _reachable(app, vp, name)
	_check_shop_layout(app, vp, tag + " 첫 화면", expect_scale)
	_overflow(app, vp, tag + " 가게")
	await _shot(holder, tag + "_1_shop_closed.png")

	# 2) 시작 버튼 → 메뉴 개발 서랍(첫 메뉴 안내)
	_press(app, "StartServiceButton")
	await _settle()
	_check(overlay.visible, tag + ": 첫 메뉴 만들기가 개발 서랍을 열어야 해요")
	_check(_text_of(app, "GuideLabel").find("처음이에요") >= 0, tag + ": 첫 사용자 안내: " + _text_of(app, "GuideLabel"))
	tabs.current_tab = 0
	await _settle()
	for name in ["CloseButton", "OverlayOpenButton", "RecipeNameEdit", "NewRecipeButton", "BowlPreview", "Opt_broth_tonkotsu", "Opt_broth_dashi", "Opt_tare_shio", "Opt_oil_scallion", "Opt_noodle_thin", "Opt_topping_egg", "Opt_cook_firm", "PriceUp500", "PriceLabel", "TasteButton"]:
		await _reachable(app, vp, name)
	_check(_find(app, "DevSaveLabel") != null and _text_of(app, "DevSaveLabel").find(data_dir) >= 0, tag + ": 개발용 저장 위치 표시")
	_overflow(app, vp, tag + " 서랍")
	var lab_scroll: ScrollContainer = tabs.get_child(0) as ScrollContainer
	lab_scroll.scroll_vertical = 0
	await _shot(holder, tag + "_2_dev_overlay.png")

	# 3) 재료 선택 + 이름 + 가격
	for opt in ["Opt_broth_dashi", "Opt_tare_shio", "Opt_oil_scallion", "Opt_noodle_thin", "Opt_topping_egg", "Opt_cook_firm"]:
		_press(app, opt)
	var edit: LineEdit = _find(app, "RecipeNameEdit") as LineEdit
	edit.text = "QA 맑은 라멘"
	edit.text_changed.emit(edit.text)
	_press(app, "PriceUp500")
	await _settle()
	_check((_find(app, "Opt_broth_dashi") as BaseButton).button_pressed, tag + ": 선택이 버튼에 반영")
	_check(not (_find(app, "Opt_broth_tonkotsu") as BaseButton).button_pressed, tag + ": 이전 선택 해제")
	_check(_text_of(app, "PriceLabel").find("9,500") >= 0, tag + ": 가격 표시 9,500원")
	await _shot(holder, tag + "_3_lab_selected.png")

	# 4) 시식
	# 4a) 시식 준비 작업 진행 중: 단계/진행률 표시, 중복 시작·편집·이동 거부, 취소/완료(상세는 _run_tasting_work).
	await _finish_tasting(app)
	_check(tabs.current_tab == 1, tag + ": 시식 후 피드백 탭으로 이동")
	for id in ["dohyun", "hayoung", "maru"]:
		await _reachable(app, vp, "Card_" + id)
		await _reachable(app, vp, "Portrait_" + id)
		_check_score_line(app, id, tag)
		_check_portrait(app, id, tag)
	_check(_text_of(app, "FeedbackTitle").find("QA 맑은 라멘 v1") >= 0, tag + ": 제목 v1")
	_check(_text_of(app, "Headline_dohyun") != _text_of(app, "Headline_hayoung"), tag + ": 손님별 피드백이 다름")
	_check(_text_of(app, "ComparisonLabel").find("첫 시식") >= 0, tag + ": 첫 시식은 비교 없음 안내")
	_check(_text_of(app, "GuideLabel").find("영업 메뉴: QA 맑은 라멘 v1") >= 0, tag + ": 시식 후 영업 메뉴 안내: " + _text_of(app, "GuideLabel"))
	_check(_text_of(app, "OverlayOpenButton").find("영업하러") >= 0, tag + ": 시식 후 영업으로 가는 길이 보임")
	_overflow(app, vp, tag + " 시식")
	(tabs.get_child(1) as ScrollContainer).scroll_vertical = 0
	await _shot(holder, tag + "_4_feedback_v1.png")

	# 5) 개정 + 비교
	tabs.current_tab = 0
	await _settle()
	_check(not (_find(app, "RecipeNameEdit") as LineEdit).editable, tag + ": 개정 중에는 이름 고정")
	_press(app, "Opt_noodle_medium")
	_press(app, "Opt_cook_normal")
	await _finish_tasting(app)
	_check(tabs.current_tab == 1, tag + ": 개정 시식 후 피드백 탭")
	_check(_text_of(app, "FeedbackTitle").find("v2") >= 0, tag + ": 제목 v2")
	var cmp_text: String = _text_of(app, "ComparisonLabel")
	_check(cmp_text.find("v1 → v2") >= 0 and cmp_text.find("면") >= 0 and cmp_text.find("평균") >= 0, tag + ": 이전 버전과의 비교 표시: " + cmp_text)
	await _reachable(app, vp, "ComparisonPanel")
	await _shot(holder, tag + "_5_comparison_v2.png")
	_overflow(app, vp, tag + " 비교")

	# 6) 노트에서 v1을 영업 메뉴로 불러오기
	tabs.current_tab = 2
	await _settle()
	for name in ["NotebookCount", "Row_1", "Row_2", "SelectRecord_1", "DeleteRecord_1", "SelectRecord_2"]:
		await _reachable(app, vp, name)
	_check(_text_of(app, "NotebookCount").find("2/30") >= 0, tag + ": 노트 개수 표시")
	_overflow(app, vp, tag + " 노트")
	(tabs.get_child(2) as ScrollContainer).scroll_vertical = 0
	await _shot(holder, tag + "_6_notebook.png")
	_press(app, "SelectRecord_1")
	await _settle()
	_check(tabs.current_tab == 0, tag + ": 불러오면 개발 탭으로 이동")
	_check((_find(app, "Opt_noodle_thin") as BaseButton).button_pressed, tag + ": 불러온 레시피의 면 복원")
	_check((_find(app, "Opt_cook_firm") as BaseButton).button_pressed, tag + ": 불러온 레시피의 익힘 복원")
	_check(_text_of(app, "PriceLabel").find("9,500") >= 0, tag + ": 불러온 레시피의 가격 복원")
	_check(_text_of(app, "RecipeNameEdit") == "QA 맑은 라멘", tag + ": 이름 복원")
	tabs.current_tab = 3
	await _settle()
	for name in ["ServeIntro", "ServeMenu", "ServeForecast", "ReportLabel"]:
		await _reachable(app, vp, name)
	_check(_text_of(app, "ServeIntro").find("저장되지 않") >= 0, tag + ": 영업 탭에도 미저장 정책 표시")
	_overflow(app, vp, tag + " 영업 정보")

	# 7) 서랍을 닫아 가게로. 닫으면 영업 시작 버튼이 일차를 알려 준다.
	_press(app, "CloseButton")
	await _settle()
	_check(not overlay.visible, tag + ": 닫기로 서랍이 닫혀야 해요")
	_check(_text_of(app, "StartServiceButton").find("1일차 영업 시작") >= 0, tag + ": 메뉴가 있으면 영업 시작 버튼: " + _text_of(app, "StartServiceButton"))
	_check(_text_of(app, "ServiceStatusLabel").find("QA 맑은 라멘 v1") >= 0, tag + ": 오늘 메뉴 표시")
	_check_shop_layout(app, vp, tag + " 메뉴 선택 후", expect_scale)
	var wallet_pre: int = int(_state(app).get("wallet"))
	var day_pre: int = int(_state(app).get("day"))

	# 8) 영업 시작: 장면이 움직이고 자금/일차는 그대로, 미정산 매출만 쌓인다.
	_press(app, "StartServiceButton")
	await _settle()
	var st: Object = _state(app)
	_check(bool(st.call("service_active")), tag + ": 영업이 시작돼야 해요")
	var sess: Object = st.call("active_session")
	var planned: int = int(sess.call("planned_orders"))
	_check(planned > 0, tag + ": 오늘 손님이 있어야 해요")
	_check(_text_of(app, "StartServiceButton").find("중단") >= 0, tag + ": 영업 중에는 중단 버튼")
	_check((_find(app, "SpeedButton") as Control).visible, tag + ": 영업 중에는 속도 버튼")
	await _reachable(app, vp, "SpeedButton")
	_press(app, "SpeedButton")
	await _settle()
	_check(_text_of(app, "SpeedButton").find("×2") >= 0, tag + ": 속도 전환")
	_advance(app, 900.0)
	await _settle()
	_check(bool(st.call("service_active")) and int(st.get("wallet")) == wallet_pre and int(st.get("day")) == day_pre, tag + ": 영업 중에는 자금/일차가 그대로예요")
	_check(_text_of(app, "ServiceStatusLabel").find("미정산") >= 0, tag + ": 미정산 매출 표시: " + _text_of(app, "ServiceStatusLabel"))
	_check(_text_of(app, "ServiceNoteLabel").find("저장되지 않") >= 0, tag + ": 영업 중에도 미저장 안내")
	_check((_find(app, "ServiceProgress") as ProgressBar).value > 0.0, tag + ": 진행률 표시")
	_check_shop_layout(app, vp, tag + " 영업 중", expect_scale)
	_overflow(app, vp, tag + " 영업 중")
	await _shot(holder, tag + "_7_service_mid.png")
	# 영업 중 개발 버튼은 서랍을 열지 않고 이유를 알려 준다.
	_press(app, "DevButton")
	await _settle()
	_check(not overlay.visible, tag + ": 영업 중에는 개발 서랍이 열리지 않아요")
	_check(_text_of(app, "ServiceStatusLabel").find("영업 중에는") >= 0, tag + ": 잠금 이유 안내: " + _text_of(app, "ServiceStatusLabel"))
	_check(not bool(st.call("set_draft_price", 12000)["ok"]) and not bool(st.call("taste")["ok"]), tag + ": 영업 중 상태 변경은 거부")

	# 9) 끝까지 진행 → 정산은 한 번만
	_advance(app, 3000.0)
	var completed_count: int = int(sess.get("completed").size())
	await _settle()
	await _frames(4)
	_check(not bool(st.call("service_active")), tag + ": 영업이 끝나면 세션이 닫혀야 해요")
	_check(int(st.get("day")) == day_pre + 1, tag + ": 영업 후 일차가 한 번만 올라야 해요")
	var report: Dictionary = st.get("last_report")
	_check(int(report["units"]) == completed_count and completed_count == planned, tag + ": 보고 판매량 = 완료 주문 = 계획 손님")
	_check(int(st.get("wallet")) == wallet_pre + int(report["net"]), tag + ": 자금 = 이전 + 순이익")
	_check((_find(app, "ResultLayer") as Control).visible, tag + ": 결과 창이 보여야 해요")
	var result_text: String = _text_of(app, "ResultLabel")
	_check(result_text.find("순영업이익") >= 0 and result_text.find("매출") >= 0 and result_text.find("재료비") >= 0, tag + ": 영업 결과: " + result_text)
	_check(_text_of(app, "DayLabel").find("2일차") >= 0, tag + ": HUD 2일차")
	await _reachable(app, vp, "ResultOkButton")
	await _shot(holder, tag + "_8_result.png")
	_press(app, "ResultOkButton")
	await _settle()
	_check(not (_find(app, "ResultLayer") as Control).visible, tag + ": 결과 확인 후 닫힘")
	var wallet_after: int = int(st.get("wallet"))

	# 10) 중단: 아무것도 정산되지 않는다(두 번 눌러야 중단).
	_press(app, "StartServiceButton")
	await _settle()
	_check(bool(st.call("service_active")), tag + ": 두 번째 영업 시작")
	_advance(app, 700.0)
	await _settle()
	_press(app, "StartServiceButton")
	await _settle()
	_check(bool(st.call("service_active")) and _text_of(app, "StartServiceButton").find("다시 눌러") >= 0, tag + ": 첫 누름은 확인만")
	_press(app, "StartServiceButton")
	await _settle()
	_check(not bool(st.call("service_active")), tag + ": 두 번째 누름에 중단")
	_check(int(st.get("wallet")) == wallet_after and int(st.get("day")) == day_pre + 1, tag + ": 중단은 자금/일차를 바꾸지 않아요")
	_check(_text_of(app, "ServiceStatusLabel").find("중단") >= 0, tag + ": 중단 안내: " + _text_of(app, "ServiceStatusLabel"))

	# 11) 도중 종료 → 재시작: 영업 전 상태(일차/자금 그대로), 지난 보고는 유지
	_press(app, "StartServiceButton")
	await _settle()
	_check(bool(st.call("service_active")), tag + ": 세 번째 영업 시작")
	_advance(app, 500.0)
	await _settle()
	app.notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
	app.queue_free()
	await _frames(2)
	var again: Node = await _spawn(holder, data_dir)
	var st2: Object = _state(again)
	_check(_text_of(again, "LoadStatusLabel").find("저장된 연구소") >= 0, tag + ": 재시작 시 불러오기 상태 표시: " + _text_of(again, "LoadStatusLabel"))
	_check(not bool(st2.call("service_active")), tag + ": 재시작하면 진행 중인 영업이 없어요")
	_check(_text_of(again, "DayLabel").find("2일차") >= 0 and int(st2.get("wallet")) == wallet_after, tag + ": 재시작 후 일차/자금은 영업 전 값")
	_check(_text_of(again, "StartServiceButton").find("2일차 영업 시작") >= 0, tag + ": 재시작 후 다시 처음부터 영업 가능")
	_press(again, "DevButton")
	await _settle()
	var tabs2: TabContainer = _find(again, "MainTabs") as TabContainer
	tabs2.current_tab = 2
	await _settle()
	_check(_find(again, "Row_1") != null and _find(again, "Row_2") != null, tag + ": 재시작 후 노트 복원")
	tabs2.current_tab = 3
	await _settle()
	_check(_text_of(again, "ReportLabel").find("순영업이익") >= 0, tag + ": 재시작 후 영업 보고 복원")
	_overflow(again, vp, tag + " 재시작")
	await _shot(holder, tag + "_9_reloaded.png")

	again.queue_free()
	await _frames(2)
	await _run_save_failure(holder, tag, vp)
	await _run_research(holder, tag, vp)
	await _run_tasting_work(holder, tag, vp)
	await _run_manual_save(holder, tag, vp)

	holder.queue_free()
	await _frames(2)


## 개발 서랍에서 재료를 눌러 고르고 이름/가격을 정해 시식한다(실제 pressed 신호). 시식 후 피드백 탭으로 이동한다.
func _taste_via_ui(app: Node, options: Array, recipe_name: String, price_buttons: Array) -> void:
	var tabs: TabContainer = _find(app, "MainTabs") as TabContainer
	tabs.current_tab = 0
	await _settle()
	_press(app, "NewRecipeButton")
	for opt in options:
		_press(app, str(opt))
	if recipe_name != "":
		var edit: LineEdit = _find(app, "RecipeNameEdit") as LineEdit
		edit.text = recipe_name
		edit.text_changed.emit(edit.text)
	for pb in price_buttons:
		_press(app, str(pb))
	await _finish_tasting(app)


## 연구 탭(보조 서랍 탭): 열기/미시식 거부/조건 미충족 거부/제출 보상/재제출·잠금/해금/저장 후 복원을 실제 UI 핸들러로 밟는다.
## 이 함수는 --layout-only 에서도 그대로 실행된다(스크린샷만 건너뜀). 화면의 시각 품질은 별도 눈 검수가 필요하다.
func _run_research(holder: SubViewport, tag: String, vp: Vector2i) -> void:
	var dir: String = _data_root.path_join(tag + "_research")
	DirAccess.make_dir_recursive_absolute(dir)
	SaveServiceScript.new(dir).remove_known_files()
	var app: Node = await _spawn(holder, dir)
	var st: Object = _state(app)
	var tabs: TabContainer = _find(app, "MainTabs") as TabContainer
	var overlay: Control = _find(app, "Overlay") as Control
	var ids: Array = ["dohyun_basic", "hayoung_basic", "maru_basic", "dohyun_advanced", "hayoung_advanced", "maru_advanced"]

	# 1) 기존 탭 순서/제목은 그대로고 연구 탭이 5번째로 붙는다. 개발 버튼으로 서랍을 열고 연구 탭을 연다.
	_check(tabs.get_tab_count() == 5, tag + ": 탭은 5개")
	var titles: Array = ["개발", "시식", "노트", "영업", "연구"]
	for i in titles.size():
		_check(tabs.get_tab_title(i) == str(titles[i]), "%s: 탭 %d 제목 %s" % [tag, i, tabs.get_tab_title(i)])
	_press(app, "DevButton")
	await _settle()
	_check(overlay.visible, tag + ": 서랍이 열려야 해요")
	tabs.current_tab = 4
	await _settle()
	_check(int(st.get("wallet")) == 30000 and int(st.call("research_points")) == 0, tag + ": 탭을 열어도 보상/자금 변화 없음")
	_check(_text_of(app, "ResearchSummary").find("연구 점수 0점") >= 0 and _text_of(app, "ResearchSummary").find("0/6") >= 0, tag + ": 연구 요약: " + _text_of(app, "ResearchSummary"))
	_check(_text_of(app, "ResearchTarget").find("제출할 기록이 없어요") >= 0, tag + ": 시식 전 제출 대상 안내")
	for rid in ids:
		for prefix in ["Research_", "ResearchTitle_", "ResearchStatus_", "ResearchConditions_", "ResearchSubmit_"]:
			await _reachable(app, vp, prefix + str(rid))
	for rid in ["dohyun_basic", "hayoung_basic", "maru_basic"]:
		_check((_find(app, "ResearchSubmit_" + rid) as BaseButton).disabled, tag + ": 시식한 기록이 없으면 제출 버튼이 꺼져야 해요: " + rid)
	for rid in ["dohyun_advanced", "hayoung_advanced", "maru_advanced"]:
		_check(_text_of(app, "ResearchStatus_" + rid).find("잠김") >= 0 and _text_of(app, "ResearchStatus_" + rid).find("0/2") >= 0, tag + ": 잠금 이유 표시: " + _text_of(app, "ResearchStatus_" + rid))
		_check((_find(app, "ResearchSubmit_" + rid) as BaseButton).disabled, tag + ": 잠긴 의뢰는 제출 버튼이 꺼져야 해요: " + rid)
	_overflow(app, vp, tag + " 연구 첫 화면")
	(tabs.get_child(4) as ScrollContainer).scroll_vertical = 0
	await _shot(holder, tag + "_11_research_open.png")

	# 2) 시식하지 않은 초안(도윤 입문 증인)은 어떤 진행도 만들지 않는다.
	for opt in ["Opt_tare_shoyu", "Opt_oil_garlic", "Opt_noodle_thick", "Opt_topping_nori", "Opt_cook_normal"]:
		_press(app, opt)
	app.call("_refresh_all")
	await _settle()
	_check((_find(app, "ResearchSubmit_dohyun_basic") as BaseButton).disabled, tag + ": 초안만 있으면 제출 버튼은 여전히 꺼져 있어요")
	app.call("_on_research_submit", "dohyun_basic")
	await _settle()
	_check(int(st.call("research_points")) == 0 and int(st.get("wallet")) == 30000, tag + ": 초안 제출 시도는 아무것도 바꾸지 않아요")

	# 3) 조건을 못 채운 기록(기본 초안, 원가 2,200원)을 시식해 제출하면 거부 + 힌트가 보인다.
	app.call("_on_new_recipe")
	for opt in ["Opt_tare_shoyu", "Opt_oil_garlic", "Opt_noodle_thin", "Opt_topping_chashu", "Opt_cook_firm"]:
		_press(app, opt)
	await _finish_tasting(app)
	var wallet_a: int = int(st.get("wallet"))
	tabs.current_tab = 4
	await _settle()
	_check(_text_of(app, "ResearchTarget").find("제출 대상") >= 0 and _text_of(app, "ResearchTarget").find("v1") >= 0, tag + ": 제출 대상 기록/버전 표시: " + _text_of(app, "ResearchTarget"))
	_check(_text_of(app, "ResearchConditions_dohyun_basic").find("[부족]") >= 0 and _text_of(app, "ResearchConditions_dohyun_basic").find("2,200원") >= 0, tag + ": 조건별 현재 값: " + _text_of(app, "ResearchConditions_dohyun_basic"))
	await _reachable(app, vp, "ResearchHint_dohyun_basic")
	await _reachable(app, vp, "ResearchSubmit_dohyun_basic")
	_press(app, "ResearchSubmit_dohyun_basic")
	await _settle()
	_check(int(st.call("research_points")) == 0 and int(st.get("wallet")) == wallet_a, tag + ": 조건 미충족 제출은 거부")
	_check(_text_of(app, "ResearchMessage").find("조건") >= 0, tag + ": 거부 이유 표시: " + _text_of(app, "ResearchMessage"))

	# 4) 도윤 입문 증인 조합을 시식(가격 9,500)하고 제출 → 보상 한 번.
	await _taste_via_ui(app, ["Opt_broth_tonkotsu", "Opt_tare_shoyu", "Opt_oil_garlic", "Opt_noodle_thick", "Opt_topping_nori", "Opt_cook_normal"], "QA 도윤 연구", ["PriceUp500"])
	var wallet_b: int = int(st.get("wallet"))
	tabs.current_tab = 4
	await _settle()
	_check(_text_of(app, "ResearchTarget").find("QA 도윤 연구 v1") >= 0, tag + ": 새 기록이 제출 대상: " + _text_of(app, "ResearchTarget"))
	_check(_text_of(app, "ResearchConditions_dohyun_basic").find("[부족]") < 0, tag + ": 증인 기록은 입문 조건을 모두 달성: " + _text_of(app, "ResearchConditions_dohyun_basic"))
	_check(not (_find(app, "ResearchSubmit_dohyun_basic") as BaseButton).disabled, tag + ": 제출 버튼이 켜져야 해요")
	_press(app, "ResearchSubmit_dohyun_basic")
	await _settle()
	_check(int(st.call("research_points")) == 2 and int(st.get("wallet")) == wallet_b + 2000, tag + ": 입문 보상 점수 2 / 자금 +2,000")
	_check(_text_of(app, "ResearchMessage").find("연구를 마쳤어요") >= 0 and _text_of(app, "ResearchMessage").find("한 번만") >= 0, tag + ": 보상 확인 메시지: " + _text_of(app, "ResearchMessage"))
	_check(_text_of(app, "ResearchSummary").find("완료 1/6") >= 0 and _text_of(app, "ResearchSummary").find("연구 점수 2점") >= 0, tag + ": 요약 갱신: " + _text_of(app, "ResearchSummary"))
	var expected_wallet: String = "%d,%03d" % [(wallet_b + 2000) / 1000, (wallet_b + 2000) % 1000]
	_check(_text_of(app, "WalletLabel").find(expected_wallet) >= 0, tag + ": 상단 자금 표시가 보상을 반영: %s (기대 %s)" % [_text_of(app, "WalletLabel"), expected_wallet])
	_check((_find(app, "ResearchSubmit_dohyun_basic") as BaseButton).disabled and _text_of(app, "ResearchSubmit_dohyun_basic").find("제출 완료") >= 0, tag + ": 완료 의뢰는 버튼이 '제출 완료'로 꺼져요")
	_check(int((st.call("research_receipts") as Array).size()) == 1 and _text_of(app, "ResearchStatus_dohyun_basic").find("완료") >= 0, tag + ": 완료 표시/영수증")

	# 5) 재제출·잠긴 의뢰는 핸들러를 직접 불러도 거부된다(보상 없음).
	var wallet_c: int = int(st.get("wallet"))
	app.call("_on_research_submit", "dohyun_basic")
	app.call("_on_research_submit", "dohyun_advanced")
	await _settle()
	_check(int(st.call("research_points")) == 2 and int(st.get("wallet")) == wallet_c, tag + ": 재제출/잠긴 의뢰는 보상이 없어요")
	_check(_text_of(app, "ResearchMessage") != "" and _text_of(app, "ResearchMessage").find("연구를 마쳤어요") < 0, tag + ": 잠긴 의뢰 거부 메시지: " + _text_of(app, "ResearchMessage"))
	_check((_find(app, "ResearchSubmit_dohyun_advanced") as BaseButton).disabled, tag + ": 입문 1개로는 심화 버튼이 꺼져 있어요")

	# 6) 하영 입문 증인(가격 9,000) → 두 번째 입문 완료로 심화 해금.
	await _taste_via_ui(app, ["Opt_broth_dashi", "Opt_tare_shio", "Opt_oil_scallion", "Opt_noodle_thin", "Opt_topping_nori", "Opt_cook_firm"], "QA 하영 연구", ["PriceDown500"])
	tabs.current_tab = 4
	await _settle()
	_press(app, "ResearchSubmit_hayoung_basic")
	await _settle()
	_check(int(st.call("research_points")) == 4, tag + ": 두 번째 입문 완료 점수 4: " + _text_of(app, "ResearchMessage"))
	_check(_text_of(app, "ResearchSummary").find("완료 2/6") >= 0, tag + ": 요약 완료 2/6")
	for rid in ["dohyun_advanced", "hayoung_advanced", "maru_advanced"]:
		_check(_text_of(app, "ResearchStatus_" + rid).find("도전 가능") >= 0, tag + ": 심화 해금: " + rid)
		_check(not (_find(app, "ResearchSubmit_" + rid) as BaseButton).disabled, tag + ": 해금된 심화는 버튼이 켜져요(조건은 도메인이 판정): " + rid)
	var wallet_d: int = int(st.get("wallet"))
	_press(app, "ResearchSubmit_maru_advanced")
	await _settle()
	_check(int(st.call("research_points")) == 4 and int(st.get("wallet")) == wallet_d, tag + ": 조건 안 맞는 기록으로 심화 제출은 거부")
	for rid in ids:
		for prefix in ["Research_", "ResearchTitle_", "ResearchStatus_", "ResearchConditions_", "ResearchSubmit_"]:
			await _reachable(app, vp, prefix + str(rid))
	await _reachable(app, vp, "ResearchMessage")
	_overflow(app, vp, tag + " 연구 진행 후")
	(tabs.get_child(4) as ScrollContainer).scroll_vertical = 0
	await _shot(holder, tag + "_12_research_progress.png")

	# 7) 저장/재시작 후에도 진행이 남고 보상은 다시 받을 수 없다(마지막 변경은 제출 직후 저장됨).
	var wallet_e: int = int(st.get("wallet"))
	app.notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
	app.queue_free()
	await _frames(2)
	var again: Node = await _spawn(holder, dir)
	var st2: Object = _state(again)
	_check(int(st2.call("research_points")) == 4 and int(st2.get("wallet")) == wallet_e, tag + ": 재시작 후 연구 점수/자금 복원")
	_press(again, "DevButton")
	await _settle()
	var tabs2: TabContainer = _find(again, "MainTabs") as TabContainer
	tabs2.current_tab = 4
	await _settle()
	_check(_text_of(again, "ResearchSummary").find("완료 2/6") >= 0 and _text_of(again, "ResearchSummary").find("연구 점수 4점") >= 0, tag + ": 재시작 후 요약: " + _text_of(again, "ResearchSummary"))
	_check((_find(again, "ResearchSubmit_dohyun_basic") as BaseButton).disabled and (_find(again, "ResearchSubmit_hayoung_basic") as BaseButton).disabled, tag + ": 재시작 후 완료 의뢰는 꺼져 있어요")
	again.call("_on_research_submit", "hayoung_basic")
	await _settle()
	_check(int(st2.call("research_points")) == 4 and int(st2.get("wallet")) == wallet_e, tag + ": 재시작 후 재제출은 보상이 없어요")
	_check(_text_of(again, "ResearchStatus_maru_advanced").find("도전 가능") >= 0, tag + ": 재시작 후에도 심화 해금 유지")
	for rid in ids:
		await _reachable(again, vp, "ResearchSubmit_" + str(rid))
	_overflow(again, vp, tag + " 연구 재시작")
	await _shot(holder, tag + "_13_research_reloaded.png")
	again.queue_free()
	await _frames(2)
	SaveServiceScript.new(dir).remove_known_files()
	DirAccess.remove_absolute(dir)


## 저장이 실패해도 정산 결과 화면이 "저장했어요"라고 거짓말하지 않고 보이는 곳에 실패를 알리는지 본다.
## 실패는 QA 전용 하위 폴더(<저장 루트>/<tag>_savefail) 안에서 임시 저장 파일 이름과 같은 "폴더"를 만들어 유도한다.
## 일반 저장 폴더/user:// 는 건드리지 않는다.
func _run_save_failure(holder: SubViewport, tag: String, vp: Vector2i) -> void:
	var dir: String = _data_root.path_join(tag + "_savefail")
	DirAccess.make_dir_recursive_absolute(dir)
	var saver: SaveServiceScript = SaveServiceScript.new(dir)
	saver.remove_known_files()
	var conflict: String = saver.tmp_path()
	if DirAccess.dir_exists_absolute(conflict):
		DirAccess.remove_absolute(conflict)
	var app: Node = await _spawn(holder, dir)
	_check(not (_find(app, "SaveBanner") as Control).visible, tag + ": 저장 실패 시나리오 시작 때는 경고가 없어야 해요")
	_check(FileAccess.file_exists(saver.main_path()), tag + ": 첫 방문 저장 파일이 있어야 해요")
	var mk: int = DirAccess.make_dir_recursive_absolute(conflict)
	_check(mk == OK and DirAccess.dir_exists_absolute(conflict), tag + ": 저장 충돌(임시 파일 자리에 폴더) 준비")
	var st: Object = _state(app)
	var taste: Dictionary = st.call("taste")
	_check(bool(taste["ok"]), tag + ": 시식 준비: " + str(taste["message"]))
	app.call("_refresh_all")
	_press(app, "StartServiceButton")
	await _settle()
	_check(bool(st.call("service_active")), tag + ": 저장 실패 시나리오의 영업 시작")
	_advance(app, 6000.0)
	await _settle()
	await _frames(4)
	_check(not bool(st.call("service_active")) and int(st.get("day")) == 2, tag + ": 정산은 메모리에 반영")
	var note: String = _text_of(app, "ResultNote")
	_check((_find(app, "ResultLayer") as Control).visible, tag + ": 결과 창 표시")
	_check(note.find("저장하지 못했") >= 0, tag + ": 저장 실패를 결과 창에 알려야 해요: " + note)
	_check(note.find("저장했어요") < 0, tag + ": 실패했는데 저장했다고 말하면 안 돼요: " + note)
	_check((_find(app, "SaveBanner") as Control).visible and _text_of(app, "SaveBannerLabel").find("저장하지 못했") >= 0, tag + ": 서랍이 닫혀 있어도 보이는 경고 배너")
	await _reachable(app, vp, "ResultOkButton")
	_overflow(app, vp, tag + " 저장 실패")
	await _shot(holder, tag + "_10_save_failed.png")
	# 파일에는 정산이 없다: 불러오면 여전히 1일차
	var probe: Variant = load("res://scripts/domain/game_state.gd").new()
	var lr: Dictionary = saver.load_into(probe)
	_check(str(lr["status"]) == "ok" and int(probe.get("day")) == 1, tag + ": 실패한 저장이 파일에 반영되면 안 돼요")
	app.queue_free()
	await _frames(2)
	DirAccess.remove_absolute(conflict)
	saver.remove_known_files()
	DirAccess.remove_absolute(dir)


func _load_probe(dir: String) -> Dictionary:
	var probe: Object = load("res://scripts/domain/game_state.gd").new()
	var res: Dictionary = SaveServiceScript.new(dir).load_into(probe)
	return {"status": str(res["status"]), "state": probe}


## 시식 준비 작업: 시작/진행 표시/중복 거부/편집·이동·저장·연구 차단/취소/완료 1회/자동 저장/도중 종료.
## 시간은 이 격리 인스턴스에서 advance_work()를 직접 불러 앞당긴다(실제 프레임 진행도 함께 확인). --layout-only 에서도 실행된다.
func _run_tasting_work(holder: SubViewport, tag: String, vp: Vector2i) -> void:
	var dir: String = _data_root.path_join(tag + "_work")
	DirAccess.make_dir_recursive_absolute(dir)
	var saver: SaveServiceScript = SaveServiceScript.new(dir)
	saver.remove_known_files()
	var app: Node = await _spawn(holder, dir)
	var st: Object = _state(app)
	var tabs: TabContainer = _find(app, "MainTabs") as TabContainer
	var overlay: Control = _find(app, "Overlay") as Control
	_press(app, "DevButton")
	await _settle()
	tabs.current_tab = 0
	await _settle()
	var edit: LineEdit = _find(app, "RecipeNameEdit") as LineEdit
	edit.text = "QA 준비 라멘"
	edit.text_changed.emit(edit.text)
	var cost: int = int(st.call("trial_cost"))
	var wallet0: int = int(st.get("wallet"))
	var file_before: String = _read_file(saver.main_path())
	_check(not bool(app.call("work_active")) and not (_find(app, "TastingWorkCard") as Control).visible, tag + ": 시작 전에는 준비 카드가 없어요")

	# 1) 시작: 즉시 기록되지 않고 준비 중이 된다. 단계/진행률이 보이고 자금·기록은 그대로.
	_press(app, "TasteButton")
	var bar: ProgressBar = _find(app, "WorkProgress") as ProgressBar
	var view: Control = _find(app, "TastingWorkView") as Control
	_check(bool(app.call("work_active")), tag + ": 시식 누름 → 준비 중")
	# 2) 실제 프레임 진행 관찰(격리된 빨리감기 없이): 먼저 두 번 읽어 0보다 크고 100 미만으로 늘어나는지, 연출이 움직이는지 본다.
	#    이 관찰은 4초 작업 중 약 0.6초만 쓰고 바로 끝난다. 이후의 긴 검사는 이 격리 인스턴스의 _process 를 끈 채 advance_work() 로만 진행한다.
	await _frames(2)
	var first_value: float = bar.value
	var sig_a: String = str(view.call("signature"))
	await create_timer(0.3).timeout
	var real_value: float = bar.value
	_check(first_value >= 0.0 and real_value > first_value and real_value > 0.0 and real_value < 100.0, tag + ": 실제 프레임 진행 %.1f%% → %.1f%%" % [first_value, real_value])
	_check(bool(app.call("work_active")), tag + ": 관찰 중 아직 준비 중")
	# 이 인스턴스만 자동 진행을 멈춘다(Node.set_process; 엔진 전체 시간/상용 게임에는 영향 없음). 이후 진행은 전부 명시적이다.
	app.set_process(false)
	await _settle()
	var frozen_value: float = bar.value
	await create_timer(0.3).timeout
	_check(bar.value == frozen_value and bool(app.call("work_active")), tag + ": 자동 진행을 끈 인스턴스는 시간이 지나도 진행하지 않아요")
	_check(int(st.call("record_count")) == 0 and int(st.get("wallet")) == wallet0, tag + ": 시작만으로는 기록/재료비가 없어요")
	_check((_find(app, "TastingWorkCard") as Control).visible, tag + ": 준비 카드 표시")
	_check(_text_of(app, "WorkTitle").find("1/3") >= 0 and _text_of(app, "WorkPhase_broth").find("진행 중") >= 0, tag + ": 1단계(국물) 표시: " + _text_of(app, "WorkTitle"))
	_check(_text_of(app, "WorkPhase_noodle").find("면") >= 0 and _text_of(app, "WorkPhase_taste").find("시식") >= 0, tag + ": 세 단계 이름 표시")
	_check(_text_of(app, "TasteButton").find("준비 중") >= 0 and (_find(app, "TasteButton") as BaseButton).disabled, tag + ": 시식 버튼은 준비 중 표시/비활성")
	for name in ["TastingWorkCard", "TastingWorkView", "WorkTitle", "WorkProgress", "WorkPercent", "WorkNotice", "WorkCancelButton"]:
		await _reachable(app, vp, name)
	for pid in ["broth", "noodle", "taste"]:
		await _reachable(app, vp, "WorkPhase_" + pid)
	_check(bool(app.call("work_active")) and not bool(app.call("advance_work", -1.0)) and bar.value >= real_value, tag + ": 음수 시간은 무시")
	# 3) 중복 시작은 거부되고 진행이 되돌아가지 않는다.
	var dup: Dictionary = app.call("start_tasting")
	_check(not bool(dup["ok"]) and bar.value >= real_value, tag + ": 중복 시작 거부: " + str(dup["message"]))
	# 4) 명시 진행: 한 번에 +0.3초 → 진행률 상승, 연출 서명 변화
	app.call("advance_work", 0.3)
	await _settle()
	_check(bar.value > real_value and str(view.call("signature")) != sig_a, tag + ": 진행하면 막대와 연출이 달라져요")
	_check(_text_of(app, "WorkPercent").find("%") >= 0, tag + ": 퍼센트 표시")
	# 5) 차단: 모든 변경 핸들러를 직접 불러도 초안/기록/자금/연구/서비스가 안 바뀐다.
	var draft_before: Dictionary = (st.get("draft_config") as Dictionary).duplicate(true)
	app.call("_on_option_pressed", "broth", "broth_dashi")
	app.call("_on_price_step", 500)
	edit.text = "바뀐 이름"
	edit.text_changed.emit(edit.text)
	app.call("_on_new_recipe")
	app.call("_on_select_record", 1)
	app.call("_on_delete_record", 1)
	app.call("_on_research_submit", "dohyun_basic")
	app.call("_on_overlay_open_pressed")
	app.call("_on_start_pressed")
	app.call("_on_dev_pressed")
	app.call("_on_close_pressed")
	await _settle()
	_check(str(st.get("draft_config")) == str(draft_before), tag + ": 준비 중 초안(재료/가격)이 안 바뀌어요")
	_check(str(st.get("draft_name")) == "QA 준비 라멘" and edit.text == "QA 준비 라멘", tag + ": 준비 중 이름이 안 바뀌고 입력창이 되돌려져요")
	_check(not bool(st.call("service_active")) and overlay.visible, tag + ": 준비 중 영업 시작/서랍 닫기 거부")
	_check(int(st.call("record_count")) == 0 and int(st.get("wallet")) == wallet0 and int(st.call("research_points")) == 0, tag + ": 차단 시도가 기록/자금/연구를 안 바꿔요")
	_check(_text_of(app, "WorkNotice").find("시식 준비 중에는") >= 0, tag + ": 거부 이유가 서랍 안에 보여요: " + _text_of(app, "WorkNotice"))
	for name in ["Opt_broth_dashi", "PriceUp500", "NewRecipeButton", "CloseButton", "OverlayOpenButton"]:
		_check((_find(app, name) as BaseButton).disabled, tag + ": 준비 중 비활성: " + name)
	_check(not edit.editable, tag + ": 준비 중 이름 입력 잠김")
	# 6) 수동 저장 거부 + 탭 이동에도 자동 저장 안 함 → 파일 그대로
	tabs.current_tab = 3
	await _settle()
	await _reachable(app, vp, "ManualSaveButton")
	_press(app, "ManualSaveButton")
	await _settle()
	_check(_text_of(app, "ManualSaveResult").find("시식 준비 중에는 직접 저장할 수 없어요") >= 0, tag + ": 준비 중 수동 저장 거부 이유: " + _text_of(app, "ManualSaveResult"))
	_check(_read_file(saver.main_path()) == file_before, tag + ": 준비 중에는 저장 파일이 그대로예요")
	tabs.current_tab = 0
	await _settle()
	_check_shop_layout_drawer(app, vp, tag + " 준비 중")
	_overflow(app, vp, tag + " 시식 준비 중")
	await _shot(holder, tag + "_14_tasting_work.png")

	# 7) 취소: 자금/기록/보상/파일 그대로, 조작 복구, 이후 진행/완료 없음
	_press(app, "WorkCancelButton")
	await _settle()
	_check(not bool(app.call("work_active")) and not (_find(app, "TastingWorkCard") as Control).visible, tag + ": 취소하면 준비 카드가 사라져요")
	_check(int(st.call("record_count")) == 0 and int(st.get("wallet")) == wallet0 and int(st.call("research_points")) == 0, tag + ": 취소는 기록/재료비/보상 없음")
	_check(_read_file(saver.main_path()) == file_before, tag + ": 취소는 저장 파일을 바꾸지 않아요")
	_check(_text_of(app, "TasteMessage").find("취소") >= 0, tag + ": 취소 안내: " + _text_of(app, "TasteMessage"))
	_check(not bool(app.call("advance_work", 10.0)) and int(st.call("record_count")) == 0, tag + ": 취소된 작업은 더 이상 완료되지 않아요")
	for name in ["Opt_broth_dashi", "PriceUp500", "NewRecipeButton", "CloseButton", "OverlayOpenButton", "TasteButton"]:
		_check(not (_find(app, name) as BaseButton).disabled, tag + ": 취소 뒤 조작 복구: " + name)
	_check(edit.editable and _text_of(app, "TasteButton") == "시식하기", tag + ": 취소 뒤 입력/버튼 글 복구")

	# 8) 완료: 기록 1개·재료비 1회·자동 저장 1회. 진행 함수를 또 불러도 늘지 않는다.
	# 여기서부터 자동 진행을 다시 켠다. 시작 뒤 곧바로(약 0.3초 안에) 명시 진행으로 끝내므로 4초 경쟁은 없다.
	app.set_process(true)
	_press(app, "TasteButton")
	await _settle()
	_check(bool(app.call("work_active")), tag + ": 취소 뒤 다시 시작 가능")
	var done: bool = bool(app.call("advance_work", 10.0))
	await create_timer(1.2).timeout
	_check(done and not bool(app.call("work_active")), tag + ": 완료 신호 한 번")
	_check(not bool(app.call("advance_work", 10.0)), tag + ": 완료 뒤 두 번째 완료 없음")
	_check(int(st.call("record_count")) == 1 and int(st.get("wallet")) == wallet0 - cost, tag + ": 기록 1개, 재료비 한 번만: 자금 %d (기대 %d)" % [int(st.get("wallet")), wallet0 - cost])
	var reloaded: Dictionary = _load_probe(dir)
	var rs: Object = reloaded["state"]
	_check(str(reloaded["status"]) == "ok" and int(rs.call("record_count")) == 1 and int(rs.get("wallet")) == wallet0 - cost, tag + ": 완료 직후 자동 저장이 파일에 반영")
	_check(_text_of(app, "SaveStatusLabel").find("자동 저장됨") >= 0, tag + ": 자동 저장 상태 표시: " + _text_of(app, "SaveStatusLabel"))
	_check(tabs.current_tab == 1 and _text_of(app, "FeedbackTitle").find("QA 준비 라멘 v1") >= 0, tag + ": 완료 후 피드백 탭")
	# 세 초상: 모두 도달 가능하고 서로 다른 그림이다.
	var pixel_sets: Array = []
	for id in ["dohyun", "hayoung", "maru"]:
		await _reachable(app, vp, "Card_" + id)
		await _reachable(app, vp, "Portrait_" + id)
		await _reachable(app, vp, "Headline_" + id)
		_check_score_line(app, id, tag)
		_check_portrait(app, id, tag)
		var tr: TextureRect = _find(app, "Portrait_" + id) as TextureRect
		pixel_sets.append(tr.texture.get_image().get_data())
	_check(pixel_sets[0] != pixel_sets[1] and pixel_sets[1] != pixel_sets[2] and pixel_sets[0] != pixel_sets[2], tag + ": 세 초상이 서로 달라요")
	_overflow(app, vp, tag + " 초상 피드백")
	(tabs.get_child(1) as ScrollContainer).scroll_vertical = 0
	await _shot(holder, tag + "_14b_feedback_portraits.png")
	# 같은 구성을 다시 시식하면 시작 단계에서 거부된다(작업/재료비 없음).
	tabs.current_tab = 0
	await _settle()
	var wallet1: int = int(st.get("wallet"))
	var again_res: Dictionary = app.call("start_tasting")
	_check(not bool(again_res["ok"]) and not bool(app.call("work_active")) and int(st.get("wallet")) == wallet1, tag + ": 이미 기록된 구성은 시작 거부: " + str(again_res["message"]))

	# 9) 도중 종료: 다른 가격으로 준비를 시작하고 닫으면 기록/자금/파일에 흔적이 없다.
	_press(app, "PriceUp500")
	_press(app, "TasteButton")
	await _settle()
	_check(bool(app.call("work_active")), tag + ": 두 번째 준비 시작")
	app.call("advance_work", 2.0)
	var file_mid: String = _read_file(saver.main_path())
	app.notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
	_check(not bool(app.call("work_active")), tag + ": 닫기 요청이 준비를 취소")
	app.queue_free()
	await _frames(2)
	var after_close: Dictionary = _load_probe(dir)
	var cs: Object = after_close["state"]
	_check(int(cs.call("record_count")) == 1 and int(cs.get("wallet")) == wallet1, tag + ": 닫은 뒤 파일에는 미완료 시식이 없어요")
	_check(file_mid != "<없음>", tag + ": 저장 파일이 남아 있어요")
	var app2: Node = await _spawn(holder, dir)
	_check(not bool(app2.call("work_active")) and int(_state(app2).call("record_count")) == 1, tag + ": 재시작 후 준비 중인 작업은 없어요")
	app2.queue_free()
	await _frames(2)
	saver.remove_known_files()
	DirAccess.remove_absolute(dir)


## 서랍 안 레이아웃 검사(서랍이 열린 상태에서 가게 장면이 아니라 서랍 틀과 카드가 화면 안에 들어오는지).
func _check_shop_layout_drawer(app: Node, vp: Vector2i, tag: String) -> void:
	var drawer: Control = _find(app, "Drawer") as Control
	_check(drawer != null and Rect2(Vector2(-1.0, -1.0), Vector2(vp) + Vector2(2.0, 2.0)).encloses(drawer.get_global_rect()), tag + ": 서랍이 화면 안에 있어요")
	var card: Control = _find(app, "TastingWorkCard") as Control
	if card != null and card.visible and drawer != null:
		_check(drawer.get_global_rect().grow(1.0).encloses(card.get_global_rect()), tag + ": 준비 카드가 서랍 안에 있어요")
		var tabs_node: Control = _find(app, "MainTabs") as Control
		_check(tabs_node.size.y >= 160.0, tag + ": 준비 카드 아래 탭 영역이 최소 160px 남아요 (%.0f)" % tabs_node.size.y)


## 수동 저장: 성공/재시작 복원/강제 실패 배너와 복구/손상 파일 보호/영업 중 거부. 실제 저장 결과만 표시되는지 본다.
func _run_manual_save(holder: SubViewport, tag: String, vp: Vector2i) -> void:
	# A) 성공 + 복원
	var dir: String = _data_root.path_join(tag + "_manual")
	DirAccess.make_dir_recursive_absolute(dir)
	var saver: SaveServiceScript = SaveServiceScript.new(dir)
	saver.remove_known_files()
	var app: Node = await _spawn(holder, dir)
	var st: Object = _state(app)
	var tabs: TabContainer = _find(app, "MainTabs") as TabContainer
	_press(app, "DevButton")
	await _settle()
	tabs.current_tab = 3
	await _settle()
	for name in ["SaveStatusLabel", "AutoSaveInfo", "ManualSaveButton", "ManualSaveResult"]:
		await _reachable(app, vp, name)
	_check(_text_of(app, "AutoSaveInfo").find("자동 저장") >= 0, tag + ": 자동 저장 안내가 보여요")
	_check((_find(app, "ManualSaveButton") as Control).size.y >= 44.0, tag + ": 수동 저장 버튼 44px 이상")
	var edit_state: Dictionary = st.call("set_draft_price", 10000)
	_check(bool(edit_state["ok"]), tag + ": 초안 가격 변경(저장 안 된 변경)")
	_press(app, "ManualSaveButton")
	await _settle()
	_check(_text_of(app, "ManualSaveResult").find("직접 저장했어요") >= 0, tag + ": 수동 저장 성공 표시: " + _text_of(app, "ManualSaveResult"))
	_check(_text_of(app, "SaveStatusLabel").find("직접 저장됨") >= 0, tag + ": 저장 상태에 직접 저장 표시: " + _text_of(app, "SaveStatusLabel"))
	var probe: Dictionary = _load_probe(dir)
	_check(str(probe["status"]) == "ok" and int((probe["state"] as Object).get("draft_config")["price"]) == 10000, tag + ": 수동 저장이 실제 파일에 반영")
	_check(not (_find(app, "SaveBanner") as Control).visible, tag + ": 성공 때 경고 배너 없음")
	_overflow(app, vp, tag + " 수동 저장")
	(tabs.get_child(3) as ScrollContainer).scroll_vertical = 100000
	await _shot(holder, tag + "_15_manual_save.png")
	app.notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
	app.queue_free()
	await _frames(2)
	var back: Node = await _spawn(holder, dir)
	_check(int(_state(back).get("draft_config")["price"]) == 10000, tag + ": 재시작 후 수동 저장한 값 복원")
	back.queue_free()
	await _frames(2)

	# B) 강제 실패: 임시 파일 자리에 폴더 → 실패 보고 + 배너, 폴더를 치우면 성공하고 배너가 사라진다.
	saver.remove_known_files()
	var conflict: String = saver.tmp_path()
	var app3: Node = await _spawn(holder, dir)
	_check(DirAccess.make_dir_recursive_absolute(conflict) == OK, tag + ": 저장 충돌 준비")
	var good_file: String = _read_file(saver.main_path())
	_press(app3, "DevButton")
	await _settle()
	(_find(app3, "MainTabs") as TabContainer).current_tab = 3
	await _settle()
	_press(app3, "ManualSaveButton")
	await _settle()
	var fail_text: String = _text_of(app3, "ManualSaveResult")
	_check(fail_text.find("저장하지 못했") >= 0 and fail_text.find("직접 저장했어요") < 0, tag + ": 수동 저장 실패를 실제로 보고: " + fail_text)
	_check((_find(app3, "SaveBanner") as Control).visible and _text_of(app3, "SaveStatusLabel").find("저장 실패") >= 0, tag + ": 실패 배너/상태")
	_check(_read_file(saver.main_path()) == good_file, tag + ": 실패한 저장이 기존 파일을 망가뜨리지 않아요")
	await _reachable(app3, vp, "ManualSaveResult")
	_overflow(app3, vp, tag + " 수동 저장 실패")
	await _shot(holder, tag + "_16_manual_save_failed.png")
	DirAccess.remove_absolute(conflict)
	_press(app3, "ManualSaveButton")
	await _settle()
	_check(_text_of(app3, "ManualSaveResult").find("직접 저장했어요") >= 0 and not (_find(app3, "SaveBanner") as Control).visible, tag + ": 문제를 치우면 저장되고 배너가 사라져요: " + _text_of(app3, "ManualSaveResult"))
	# C) 영업 중 거부: 시식 기록을 만들고 영업을 시작한 상태
	var s3: Object = _state(app3)
	_check(bool(s3.call("taste")["ok"]), tag + ": 영업 준비용 시식")
	app3.call("_refresh_all")
	app3.call("_on_overlay_open_pressed")
	await _settle()
	_check(bool(s3.call("service_active")), tag + ": 영업 시작")
	var saved_before_service: String = _read_file(saver.main_path())
	var refused: Dictionary = app3.call("manual_save")
	_check(not bool(refused["ok"]) and str(refused["message"]).find("영업 중에는 직접 저장할 수 없어요") >= 0, tag + ": 영업 중 수동 저장 거부: " + str(refused["message"]))
	_check(_read_file(saver.main_path()) == saved_before_service, tag + ": 영업 중 거부는 파일을 안 바꿔요")
	app3.queue_free()
	await _frames(2)

	# D) 손상 파일 보호: 잠금 상태에서는 수동 저장이 파일을 건드리지 않는다.
	saver.remove_known_files()
	DirAccess.remove_absolute(conflict)
	var garbage: String = "{ 손상된 저장 파일"
	var gf: FileAccess = FileAccess.open(saver.main_path(), FileAccess.WRITE)
	_check(gf != null, tag + ": 손상 파일 준비")
	if gf != null:
		gf.store_string(garbage)
		gf.close()
	var app4: Node = await _spawn(holder, dir)
	_check(bool(app4.get("save_locked")) and (_find(app4, "SaveBanner") as Control).visible, tag + ": 손상 저장은 잠기고 배너가 떠요")
	_press(app4, "DevButton")
	await _settle()
	(_find(app4, "MainTabs") as TabContainer).current_tab = 3
	await _settle()
	_press(app4, "ManualSaveButton")
	await _settle()
	_check(_text_of(app4, "ManualSaveResult").find("저장하지 못했") >= 0, tag + ": 잠금 상태 수동 저장 거부 보고: " + _text_of(app4, "ManualSaveResult"))
	_check(_read_file(saver.main_path()) == garbage, tag + ": 손상 파일이 지워지거나 덮어써지지 않았어요")
	app4.notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
	app4.queue_free()
	await _frames(2)
	_check(_read_file(saver.main_path()) == garbage, tag + ": 닫은 뒤에도 손상 파일 그대로")
	saver.remove_known_files()
	DirAccess.remove_absolute(dir)
