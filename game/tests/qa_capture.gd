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
const ResearchScript = preload("res://scripts/domain/ramen_research.gd")
const ExplorationScript = preload("res://scripts/domain/ingredient_exploration.gd")
const ContestScript = preload("res://scripts/domain/ramen_contest.gd")
const IngredientCatalog = preload("res://scripts/domain/ingredient_catalog.gd")

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
	# 적응(성장 단계): 노트 용량은 이제 조리대 확장에서 파생되는 값이라 처음에는 6칸이다(예전 고정 30 → "2/6"). 개수 표시 자체는 그대로 검사한다.
	_check(_text_of(app, "NotebookCount").find("2/6") >= 0, tag + ": 노트 개수/용량 표시: " + _text_of(app, "NotebookCount"))
	_check(_text_of(app, "NotebookNote").find("개정 기록") >= 0 and _text_of(app, "NotebookNote").find("동시에 파는 메뉴") >= 0, tag + ": 노트 한 칸은 개정 기록이라는 설명: " + _text_of(app, "NotebookNote"))
	await _reachable(app, vp, "NotebookNote")
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
	await _run_growth(holder, tag, vp)
	await _run_growth_failure(holder, tag, vp)
	await _run_exploration(holder, tag, vp)
	await _run_exploration_failure(holder, tag, vp)
	await _run_contests(holder, tag, vp)
	await _run_contest_failure(holder, tag, vp)

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
	# 적응(성장 단계): 여섯 번째 "성장" 탭이 붙었다. 기존 0~4번 탭의 순서/제목/동작은 그대로 검사한다.
	_check(tabs.get_tab_count() == 8, tag + ": 기존 탭 번호 유지와 새 대회 탭")
	var titles: Array = ["개발", "시식", "노트", "영업", "연구", "성장"]
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


# =====================================================================================================
# 가게 성장(등급 / 유료 확장 / 보조 직원 / 다중 토핑) 시나리오
# 승급·구매·고용·토핑 선택·저장은 모두 실제 UI 핸들러(pressed 신호/핸들러 직접 호출)로 밟는다. 자격을 채우는 준비(시식/연구/영업 일수)는
# 격리된 이 QA 인스턴스에서 실제 도메인 연산으로만 한다. 등급/확장/고용을 직접 쓰는 디버그 해금은 없다.
# 자금만은 격리 인스턴스에서 한 번씩 채운다(주석으로 표시): 승급 조건/가격 규칙을 건너뛰는 것이 아니라 구매 가능 금액을 맞추기 위해서다.
# 이 두 함수는 --layout-only 에서도 그대로 실행된다(스크린샷 파일만 건너뜀).
# 프로필마다 새로 찍는 스크린샷: 17 growth_locked, 18 growth_eligible, 19 growth_purchased, 20 shop_staffed, 21 multi_topping_lab,
# 22 multi_topping_feedback, 23 staffed_service, 24 growth_reloaded, 25 growth_save_failed, 26 growth_full, 27 full_service = 11장.
# =====================================================================================================

func _open_exploration(app: Node) -> void:
	app.call("_open_overlay", 6)
	await _settle()
	(tabs_of(app).get_child(6) as ScrollContainer).scroll_vertical = 0
	await _settle()


## 이동 시계만 앞당긴다. 사건·비용·보상은 실제 UI 버튼으로 처리한다.
func _arrive(app: Node) -> void:
	app.call("advance_travel", 2.0)
	await _settle()


func _exploration_reach(app: Node, vp: Vector2i) -> void:
	for name in ["ExplorationSummary", "ExplorationRules"]:
		await _reachable(app, vp, name)
	for i in 7:
		await _reachable(app, vp, "TabLink_" + str(i))
	for id in ExplorationScript.region_ids():
		for prefix in ["RegionTitle_", "RegionPicture_", "RegionInfo_", "ExpeditionDepart_"]:
			await _reachable(app, vp, prefix + id)
	for id in ["tare_plum", "topping_pickle", "broth_clam", "oil_shrimp", "oil_pepper", "topping_mushroom"]:
		await _reachable(app, vp, "Discovery_" + id)
	_overflow(app, vp, "탐색 모든 지역/재료")


## 실제 두 선택과 명시적 수령을 사용한다. 도착 시계만 앞당기고 어떤 보상도 직접 주입하지 않는다.
func _trip_via_ui(app: Node, region: String, second_index: int) -> void:
	var st: Object = _state(app)
	await _open_exploration(app)
	_press(app, "ExpeditionDepart_" + region)
	await _arrive(app)
	var first: Dictionary = (st.call("expedition") as Dictionary)["event"]
	_press(app, "ExpeditionChoice_" + str(first["choices"][0]["id"]))
	await _arrive(app)
	var second: Dictionary = (st.call("expedition") as Dictionary)["event"]
	_press(app, "ExpeditionChoice_" + str(second["choices"][second_index]["id"]))
	await _arrive(app)
	_press(app, "ExpeditionCollect")
	await _settle()


func _run_exploration(holder: SubViewport, tag: String, vp: Vector2i) -> void:
	var dir: String = _data_root.path_join(tag + "_exploration")
	DirAccess.make_dir_recursive_absolute(dir)
	var saver: SaveServiceScript = SaveServiceScript.new(dir)
	saver.remove_known_files()
	var app: Node = await _spawn(holder, dir)
	var st: Object = _state(app)
	await _open_exploration(app)
	_check(tabs_of(app).get_tab_count() == 8 and tabs_of(app).get_tab_title(6) == "탐색", tag + ": 탐색 탭 번호")
	_check(_btn_disabled(app, "ExpeditionDepart_harbor") and _btn_disabled(app, "ExpeditionDepart_mountain"), tag + ": 등급 1에서 항구/산지 잠금")
	_check(not _btn_disabled(app, "ExpeditionDepart_market") and _text_of(app, "RegionInfo_market").contains("3,000"), tag + ": 실제 장터 가격과 출발")
	await _exploration_reach(app, vp)
	(tabs_of(app).get_child(6) as ScrollContainer).scroll_vertical = 0
	await _shot(holder, tag + "_28_exploration_regions.png")
	# 아직 모르는 재료는 버튼과 직접 호출 양쪽에서 막고, 획득 안내를 보여 준다.
	tabs_of(app).current_tab = 0
	await _settle()
	_check(_btn_disabled(app, "Opt_tare_plum") and _text_of(app, "DiscoveryHint_tare").contains("장터"), tag + ": 새 재료 잠금/획득 안내")
	var before: String = _dict_str(app)
	app.call("_on_option_pressed", "tare", "tare_plum")
	_check(_dict_str(app) == before, tag + ": 잠긴 재료 직접 선택 불변")
	await _open_exploration(app)
	var wallet0: int = int(st.get("wallet"))
	_press(app, "ExpeditionDepart_market")
	await _frames(3)
	var clock: Object = app.get("_travel") as Object
	_check(float(clock.call("progress")) > 0.0 and float(clock.call("progress")) < 1.0, tag + ": 실제 프레임에서 이동 연출 진행")
	# 이후 긴 배치/스크린샷 검사와 도착 시간이 경쟁하지 않게 이 인스턴스의 시계만 잠시 고정한다.
	app.set_process(false)
	_check(int(st.get("wallet")) == wallet0 - 3000 and bool(st.call("exploration_active")), tag + ": 출발 한 번 결제")
	before = _dict_str(app)
	app.call("_on_exploration_depart", "market")
	app.call("_on_exploration_choice", "m_ask")
	app.call("_on_exploration_collect")
	_check(_dict_str(app) == before, tag + ": 중복 출발/이동 중 선택/수령 불변")
	app.call("advance_travel", 0.3)
	await _reachable(app, vp, "ExpeditionTravelLabel")
	await _shot(holder, tag + "_29_exploration_travel.png")
	await _arrive(app)
	for name in ["ExpeditionEventTitle", "ExpeditionEventText", "ExpeditionChoice_m_ask", "ExpeditionChoice_m_browse", "ExpeditionRetire"]:
		await _reachable(app, vp, name)
	await _shot(holder, tag + "_30_exploration_first_choice.png")
	# 현재 탐색이 있는 동안 메뉴/시식/성장/영업은 변하지 않고 수동 저장은 가능하다.
	before = _dict_str(app)
	app.call("_on_new_recipe")
	app.call("_on_price_step", 100)
	app.call("_on_facility_buy", "bench_1")
	app.call("_on_research_submit", "dohyun_basic")
	app.call("_start_service")
	var tasting: Dictionary = app.call("start_tasting")
	_check(not bool(tasting["ok"]) and _dict_str(app) == before, tag + ": 탐색 중 다른 작업/영업 불변")
	_press(app, "ExpeditionChoice_m_ask")
	await _arrive(app)
	var snapshot: String = _dict_str(app)
	var manual: Dictionary = app.call("manual_save")
	_check(bool(manual["ok"]), tag + ": 진행 중 탐색 수동 저장 허용")
	app.call("_on_close_pressed")
	_check(not (_find(app, "Overlay") as Control).visible and _dict_str(app) == snapshot, tag + ": 닫기는 탐색을 완료/포기하지 않아요")
	app.notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
	app.queue_free()
	await _frames(2)
	app = await _spawn(holder, dir)
	app.set_process(false)
	st = _state(app)
	_check(_dict_str(app) == snapshot and str((st.call("expedition") as Dictionary)["stage"]) == "choice_2", tag + ": 재시작 후 이미 낸 비용/두 번째 만남 복원")
	await _open_exploration(app)
	await _arrive(app)
	await _reachable(app, vp, "ExpeditionChoice_m_hear_recipe")
	await _reachable(app, vp, "ExpeditionChoiceNote_m_hear_recipe")
	await _shot(holder, tag + "_31_exploration_resumed.png")
	_press(app, "ExpeditionChoice_m_hear_recipe")
	await _arrive(app)
	_check((st.call("discovered_ingredients") as Array).is_empty(), tag + ": 결과 수령 전에 발견 보상 없음")
	await _reachable(app, vp, "ExpeditionCollect")
	await _reachable(app, vp, "ExpeditionResult")
	await _shot(holder, tag + "_32_exploration_result.png")
	_press(app, "ExpeditionCollect")
	await _settle()
	_check(bool(st.call("is_discovered", "tare_plum")) and not bool(st.call("exploration_active")), tag + ": 수령하면 매실 타레 영구 개방")
	before = _dict_str(app)
	app.call("_on_exploration_collect")
	app.call("_on_exploration_depart", "market")
	_check(_dict_str(app) == before, tag + ": 중복 보상/같은 날 재출발 불변")
	(tabs_of(app).get_child(6) as ScrollContainer).scroll_vertical = 0
	await _shot(holder, tag + "_33_exploration_collection.png")
	tabs_of(app).current_tab = 0
	await _settle()
	_check(not _btn_disabled(app, "Opt_tare_plum"), tag + ": 발견한 재료 선택 활성")
	_press(app, "Opt_tare_plum")
	await _finish_tasting(app)
	_check(str((st.get("draft_config") as Dictionary)["tare"]) == "tare_plum" and int(st.call("record_count")) == 1, tag + ": 새 재료 시식 기록")
	await _shot(holder, tag + "_34_exploration_new_feedback.png")
	# 더 높은 지역은 실제 연구/영업/승급으로 여는 별도 합성 준비다. 제품의 무료 해금 경로는 만들지 않는다.
	_check(bool((st.call("delete_record", int(st.get("selected_record_id"))) as Dictionary)["ok"]), tag + ": 준비 기록 공간 확보")
	st.set("wallet", 900000)
	var records: Dictionary = {}
	for rid in ResearchScript.ids():
		records[rid] = _domain_taste(app, ResearchScript.WITNESSES[rid], "QA " + str(rid))
	for rid in ResearchScript.ids():
		_check(bool((st.call("submit_research", rid, int(records[rid])) as Dictionary)["ok"]), tag + ": 연구 준비")
	for i in 10:
		_check(bool((st.call("serve") as Dictionary)["ok"]), tag + ": 실제 영업으로 등급 준비")
	for rank in [2, 3]:
		_check(bool((st.call("apply_promotion", rank) as Dictionary)["ok"]), tag + ": 실제 승급")
	for id in ["bench_1", "bench_2"]:
		_check(bool((st.call("purchase_facility", id) as Dictionary)["ok"]), tag + ": 다중 재료 노트 확장")
	app.call("_refresh_all")
	await _trip_via_ui(app, "market", 0)
	_check((st.call("discovered_ingredients") as Array).size() == 2, tag + ": 장터 두 재료 발견")
	before = _dict_str(app)
	app.call("_on_exploration_depart", "market")
	_check(_dict_str(app) == before and _btn_disabled(app, "ExpeditionDepart_market"), tag + ": 완성된 지역은 비용을 받지 않아요")
	for region in ["harbor", "mountain"]:
		for index in 2:
			_check(bool((st.call("serve") as Dictionary)["ok"]), tag + ": 탐색 사이 다음 영업일")
			app.call("_refresh_all")
			if index == 0:
				await _open_exploration(app)
				_press(app, "ExpeditionDepart_" + region)
				await _arrive(app)
				await _reachable(app, vp, "ExpeditionEventText")
				await _shot(holder, tag + ("_35_exploration_harbor.png" if region == "harbor" else "_36_exploration_mountain.png"))
				var ev: Dictionary = (st.call("expedition") as Dictionary)["event"]
				_press(app, "ExpeditionChoice_" + str(ev["choices"][0]["id"]))
				await _arrive(app)
				ev = (st.call("expedition") as Dictionary)["event"]
				_press(app, "ExpeditionChoice_" + str(ev["choices"][0]["id"]))
				await _arrive(app)
				_press(app, "ExpeditionCollect")
				await _settle()
			else:
				await _trip_via_ui(app, region, 1)
	_check((st.call("discovered_ingredients") as Array).size() == 6, tag + ": 6종 모두 발견")
	await _exploration_reach(app, vp)
	(tabs_of(app).get_child(6) as ScrollContainer).scroll_vertical = 0
	await _shot(holder, tag + "_37_exploration_all_discovered.png")
	# 발견한 국물/간/기름과 새 토핑 두 종을 실제 개발 조작으로 조합한다. 카탈로그 단독 테스트 외에 연결 누락도 확인한다.
	tabs_of(app).current_tab = 0
	await _settle()
	for option in ["Opt_broth_clam", "Opt_tare_plum", "Opt_oil_shrimp"]:
		_check(not _btn_disabled(app, option), tag + ": 발견한 선택 활성 " + option)
		_press(app, option)
	var wanted: Array = ["topping_pickle", "topping_mushroom", "topping_egg"]
	var previous: Array = (st.get("draft_config") as Dictionary)["toppings"].duplicate()
	for id in previous:
		if not wanted.has(id):
			if ((st.get("draft_config") as Dictionary)["toppings"] as Array).size() == 1:
				_press(app, "Opt_topping_pickle")
			_press(app, "Opt_" + str(id))
	for id in wanted:
		if not ((st.get("draft_config") as Dictionary)["toppings"] as Array).has(id):
			_press(app, "Opt_" + str(id))
	await _settle()
	for name in ["Opt_broth_clam", "Opt_oil_shrimp", "Opt_topping_pickle", "Opt_topping_mushroom", "ToppingCount", "Desc_topping"]:
		await _reachable(app, vp, name)
	_check(_text_of(app, "Desc_topping").contains("절임") and _text_of(app, "Desc_topping").contains("표고"), tag + ": 새 토핑 두 종 설명")
	(tabs_of(app).get_child(0) as ScrollContainer).scroll_vertical = 0
	await _shot(holder, tag + "_40_exploration_combined_recipe.png")
	await _finish_tasting(app)
	_check(_text_of(app, "FeedbackRecipeDetails").contains("조개") and _text_of(app, "FeedbackRecipeDetails").contains("매실") and _text_of(app, "FeedbackRecipeDetails").contains("새우"), tag + ": 새 국물/간/기름 시식평 요약")
	_check(_text_of(app, "FeedbackToppings").contains("절임") and _text_of(app, "FeedbackToppings").contains("표고"), tag + ": 새 토핑 시식평 요약")
	await _reachable(app, vp, "FeedbackRecipeDetails")
	await _reachable(app, vp, "FeedbackToppings")
	_overflow(app, vp, "새 재료 조합 시식평")
	(tabs_of(app).get_child(1) as ScrollContainer).scroll_vertical = 0
	await _shot(holder, tag + "_41_exploration_combined_feedback.png")
	# 영업/시식 준비 중 직접 호출도 거부하며 포기한 출발은 환불하지 않는다(아래 별도 첫날 사례).
	app.call("_on_close_pressed")
	app.call("_on_start_pressed")
	before = _dict_str(app)
	app.call("_on_exploration_depart", "market")
	_check(bool(st.call("service_active")) and _dict_str(app) == before and _text_of(app, "ExplorationMessage").contains("영업"), tag + ": 영업 중 탐색 거부")
	app.call("_abort_service", "QA 중단")
	app.call("_open_overlay", 0)
	app.call("_on_price_step", 100)
	var work: Dictionary = app.call("start_tasting")
	_check(bool(work["ok"]), tag + ": 시식 준비 시작")
	before = _dict_str(app)
	app.call("_on_exploration_depart", "market")
	_check(_dict_str(app) == before and _text_of(app, "ExplorationMessage").contains("시식"), tag + ": 시식 준비 중 탐색 거부")
	app.call("_on_work_cancel")
	await _run_high_contests(app, holder, tag, vp)
	app.queue_free()
	await _frames(2)
	saver.remove_known_files()
	DirAccess.remove_absolute(dir)


func _run_exploration_failure(holder: SubViewport, tag: String, vp: Vector2i) -> void:
	var dir: String = _data_root.path_join(tag + "_exploration_failure")
	DirAccess.make_dir_recursive_absolute(dir)
	var saver: SaveServiceScript = SaveServiceScript.new(dir)
	saver.remove_known_files()
	var app: Node = await _spawn(holder, dir)
	app.set_process(false)
	app.call("_persist")
	var original: String = _read_file(saver.main_path())
	var conflict: String = saver.tmp_path()
	_check(DirAccess.make_dir_recursive_absolute(conflict) == OK, tag + ": 실제 저장 실패 충돌")
	await _open_exploration(app)
	app.call("_on_exploration_depart", "market")
	app.call("advance_travel", 0.5)
	await _settle()
	_check(bool(_state(app).call("exploration_active")) and _read_file(saver.main_path()) == original, tag + ": 저장 실패는 메모리에만 탐색을 남김")
	_check(_text_of(app, "ExplorationMessage").contains("저장하지 못했") and not _text_of(app, "ExplorationMessage").contains("저장했어요"), tag + ": 정직한 탐색 저장 실패")
	await _reachable(app, vp, "ExplorationMessage")
	_overflow(app, vp, "탐색 저장 실패")
	await _shot(holder, tag + "_38_exploration_save_failed.png")
	_check(DirAccess.remove_absolute(conflict) == OK, tag + ": QA 충돌만 해제")
	var saved: Dictionary = app.call("manual_save")
	_check(bool(saved["ok"]), tag + ": 진행 중 탐색 수동 저장 복구")
	var snapshot: String = _dict_str(app)
	app.notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
	app.queue_free()
	await _frames(2)
	app = await _spawn(holder, dir)
	app.set_process(false)
	_check(_dict_str(app) == snapshot, tag + ": 저장 복구 후 재시작 비용/진행 유지")
	await _open_exploration(app)
	await _arrive(app)
	await _shot(holder, tag + "_39_exploration_save_recovered.png")
	var before: int = int(_state(app).get("wallet"))
	_press(app, "ExpeditionRetire")
	await _settle()
	_check(not bool(_state(app).call("exploration_active")) and int(_state(app).get("wallet")) == before and (_state(app).call("discovered_ingredients") as Array).is_empty(), tag + ": 포기는 환불/보상 없음")
	var retired: String = _dict_str(app)
	app.call("_on_exploration_depart", "market")
	_check(_dict_str(app) == retired, tag + ": 포기해도 하루 기회 소비")
	app.queue_free()
	await _frames(2)
	var garbage: String = "{ QA 손상 탐색 저장"
	var file: FileAccess = FileAccess.open(saver.main_path(), FileAccess.WRITE)
	_check(file != null, tag + ": 손상 저장 준비")
	if file != null:
		file.store_string(garbage)
		file.close()
	app = await _spawn(holder, dir)
	app.set_process(false)
	_check(bool(app.get("save_locked")), tag + ": 손상 저장 보호")
	app.call("_on_exploration_depart", "market")
	_check(_read_file(saver.main_path()) == garbage and _text_of(app, "ExplorationMessage").contains("저장하지 못했"), tag + ": 손상 저장에 탐색도 덮어쓰지 않음")
	app.notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
	app.queue_free()
	await _frames(2)
	_check(_read_file(saver.main_path()) == garbage, tag + ": 닫아도 원본 손상 저장 보존")
	saver.remove_known_files()
	DirAccess.remove_absolute(dir)


func _open_contests(app: Node) -> void:
	app.call("_open_overlay", 7)
	await _settle()
	(tabs_of(app).get_child(7) as ScrollContainer).scroll_vertical = 0
	await _settle()


func _contest_cfg(band: int) -> Dictionary:
	for broth in IngredientCatalog.items("broth"):
		for tare in IngredientCatalog.items("tare"):
			for oil in IngredientCatalog.items("oil"):
				for noodle in IngredientCatalog.items("noodle"):
					for topping in IngredientCatalog.items("topping"):
						for cook in IngredientCatalog.items("cook"):
							var cfg: Dictionary = {"broth": broth["id"], "tare": tare["id"], "oil": oil["id"], "noodle": noodle["id"], "topping": topping["id"], "cook": cook["id"], "price": 9000}
							if int(ContestScript.evaluate("clear_bowl", cfg)["band"]) == band:
								return cfg
	_check(false, "대회 QA 증인 구성이 없어요: %d" % band)
	return {}


func _contest_reach(app: Node, vp: Vector2i) -> void:
	for name in ["ContestSummary", "ContestRules"]:
		await _reachable(app, vp, name)
	for i in 8:
		await _reachable(app, vp, "TabLink_" + str(i))
	for id in ContestScript.ids():
		for prefix in ["ContestTitle_", "ContestLock_", "ContestEnter_"]:
			await _reachable(app, vp, prefix + id)
	_overflow(app, vp, "콘테스트 조건/탭/출품 버튼")


func _run_contests(holder: SubViewport, tag: String, vp: Vector2i) -> void:
	var dir: String = _data_root.path_join(tag + "_contests")
	DirAccess.make_dir_recursive_absolute(dir)
	var saver: SaveServiceScript = SaveServiceScript.new(dir)
	saver.remove_known_files()
	var app: Node = await _spawn(holder, dir)
	app.set_process(false)
	var st: Object = _state(app)
	await _open_contests(app)
	_check(tabs_of(app).get_tab_count() == 8 and tabs_of(app).get_tab_title(7) == "대회", tag + ": 기존7 탭 번호 유지 + 대회8")
	await _contest_reach(app, vp)
	(tabs_of(app).get_child(7) as ScrollContainer).scroll_vertical = 0
	await _settle()
	await _shot(holder, tag + "_42_contest_locked.png")
	var before: String = _dict_str(app)
	app.call("_on_contest_enter", "clear_bowl")
	_check(_dict_str(app) == before and _btn_disabled(app, "ContestEnter_clear_bowl"), tag + ": 첫날 직접 출품도 거부")
	_domain_taste(app, _contest_cfg(1), "동메달 후보")
	# 이 인스턴스에서 정지한 심사 시계는 영업 종료 프레임을 처리할 때만 잠시 다시 켠다.
	app.set_process(true)
	await _service_day_via_ui(app, tag)
	app.set_process(false)
	# 이 인스턴스에서 정지한 심사 시계는 영업 종료 프레임을 처리할 때만 잠시 다시 켠다.
	app.set_process(true)
	await _service_day_via_ui(app, tag)
	app.set_process(false)
	await _open_contests(app)
	await _reachable(app, vp, "ContestEnter_clear_bowl")
	var cash: int = int(st.get("wallet"))
	_press(app, "ContestEnter_clear_bowl")
	await _settle()
	_check(int(st.get("wallet")) == cash - 2000 + 4000 and float(app.get("_contest_left")) > 0.0, tag + ": 동메달 비용/상금1회, 심사 연출")
	app.call("advance_contest", 0.5)
	await _settle()
	await _reachable(app, vp, "ContestJudging")
	await _shot(holder, tag + "_43_contest_judging.png")
	before = _dict_str(app)
	app.call("_on_contest_enter", "clear_bowl")
	app.call("_on_exploration_depart", "market")
	var taste: Dictionary = app.call("start_tasting")
	app.call("_on_price_step", 100)
	_check(_dict_str(app) == before and not bool(taste["ok"]), tag + ": 심사 연출 중 중복 출품/탐색/시식/편집 잠금")
	_check(not bool((app.call("advance_contest", NAN) as Dictionary)["ok"]), tag + ": 잘못된 심사 시간 거부")
	app.call("advance_contest", 2.0)
	await _settle()
	await _reachable(app, vp, "ContestResult")
	await _reachable(app, vp, "ContestFeedback")
	(tabs_of(app).get_child(7) as ScrollContainer).scroll_vertical = 0
	await _settle()
	_overflow(app, vp, "동메달 결과/재개발 힌트")
	await _shot(holder, tag + "_44_contest_result.png")
	app.call("_on_contest_enter", "clear_bowl")
	_check(_dict_str(app) == before, tag + ": 연출 완료도 당일 중복 출품 불변")
	# 이 인스턴스에서 정지한 심사 시계는 영업 종료 프레임을 처리할 때만 잠시 다시 켠다.
	app.set_process(true)
	await _service_day_via_ui(app, tag)
	app.set_process(false)
	_domain_taste(app, _contest_cfg(3), "잡지 한 그릇")
	await _open_contests(app)
	await _reachable(app, vp, "ContestEnter_clear_bowl")
	cash = int(st.get("wallet"))
	_press(app, "ContestEnter_clear_bowl")
	app.call("advance_contest", 2.0)
	await _settle()
	_check(int(st.get("wallet")) == cash - 2000 + 14000, tag + ": 동→금 상금 차액14000")
	await _reachable(app, vp, "MagazineStory_clear_bowl")
	await _reachable(app, vp, "MagazineAccept_clear_bowl")
	_overflow(app, vp, "수상 메뉴 잡지 제안")
	await _shot(holder, tag + "_45_magazine_offer.png")
	cash = int(st.get("wallet"))
	_press(app, "MagazineAccept_clear_bowl")
	await _settle()
	_check(int(st.get("wallet")) == cash + 3000 and _text_of(app, "MagazineStory_clear_bowl").contains("잡지 한 그릇"), tag + ": 실제 메뉴 소개/협조비1회")
	await _reachable(app, vp, "MagazineStory_clear_bowl")
	await _reachable(app, vp, "MagazineStatus_clear_bowl")
	await _shot(holder, tag + "_46_magazine_published.png")
	before = _dict_str(app)
	app.call("_on_magazine_accept", "clear_bowl")
	_check(_dict_str(app) == before, tag + ": 중복 잡지 수락 불변")
	app.notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
	app.queue_free()
	await _frames(2)
	app = await _spawn(holder, dir)
	app.set_process(false)
	st = _state(app)
	await _open_contests(app)
	_check(_dict_str(app) == before and float(app.get("_contest_left")) == 0.0, tag + ": 재시작 메달/소개/비용 유지, 연출은 보상 아님")
	await _reachable(app, vp, "ContestResult")
	_overflow(app, vp, "출품/잡지 재시작")
	await _shot(holder, tag + "_47_contest_reloaded.png")
	app.queue_free()
	await _frames(2)
	saver.remove_known_files()
	DirAccess.remove_absolute(dir)


## 앞선 탐색 QA가 실제 승급/선택으로 얻은 상태를 재사용한다. 새 메뉴는 실제 시식하고 출품은 UI로 한다.
func _run_high_contests(app: Node, holder: SubViewport, tag: String, vp: Vector2i) -> void:
	var st: Object = _state(app)
	var deep: Dictionary = {"broth": "broth_tonkotsu", "tare": "tare_shio", "oil": "oil_garlic", "noodle": "noodle_thick", "topping": "topping_egg", "cook": "cook_normal", "price": 9000}
	_domain_taste(app, deep, "진국 대회")
	await _open_contests(app)
	await _reachable(app, vp, "ContestEnter_deep_bowl")
	_press(app, "ContestEnter_deep_bowl")
	app.call("advance_contest", 2.0)
	await _settle()
	_check(int((st.call("contest_best", "deep_bowl") as Dictionary).get("band", 0)) == 3, tag + ": 진한 대회 실제 금메달")
	await _reachable(app, vp, "MagazineAccept_deep_bowl")
	_press(app, "MagazineAccept_deep_bowl")
	await _settle()
	await _reachable(app, vp, "MagazineStory_deep_bowl")
	_overflow(app, vp, "진한 대회/잡지")
	await _shot(holder, tag + "_48_contest_deep.png")
	_check(bool((st.call("serve") as Dictionary)["ok"]), tag + ": 다음 출품일 실제 정산")
	var regional: Dictionary = {"broth": "broth_clam", "tare": "tare_plum", "oil": "oil_pepper", "noodle": "noodle_medium", "topping": "topping_mushroom", "cook": "cook_normal", "price": 9000}
	_domain_taste(app, regional, "산과 바다 라멘")
	await _open_contests(app)
	await _reachable(app, vp, "ContestEnter_regional_bowl")
	_press(app, "ContestEnter_regional_bowl")
	app.call("advance_contest", 2.0)
	await _settle()
	_check(int((st.call("contest_best", "regional_bowl") as Dictionary).get("band", 0)) == 3, tag + ": 발견한 재료 출품/지역 금메달")
	await _reachable(app, vp, "MagazineAccept_regional_bowl")
	_press(app, "MagazineAccept_regional_bowl")
	await _settle()
	await _reachable(app, vp, "MagazineStory_regional_bowl")
	_overflow(app, vp, "지역 대회/잡지")
	await _shot(holder, tag + "_49_contest_regional.png")
	var probe: Dictionary = _load_probe(str((app.get("data_location") as Dictionary)["dir"]))
	_check(str(probe["status"]) == "ok" and JSON.stringify((probe["state"] as Object).call("to_dict"), "", true) == _dict_str(app), tag + ": 높은 등급2 대회/잡지 실제 파일 왕복")


func _run_contest_failure(holder: SubViewport, tag: String, vp: Vector2i) -> void:
	var dir: String = _data_root.path_join(tag + "_contest_failure")
	DirAccess.make_dir_recursive_absolute(dir)
	var saver: SaveServiceScript = SaveServiceScript.new(dir)
	saver.remove_known_files()
	var app: Node = await _spawn(holder, dir)
	app.set_process(false)
	var st: Object = _state(app)
	_domain_taste(app, _contest_cfg(3), "저장 확인 메뉴")
	_check(bool((st.call("serve") as Dictionary)["ok"]) and bool((st.call("serve") as Dictionary)["ok"]), tag + ": 실패 시험 정상 일차 준비")
	_check(bool(app.call("_persist")), tag + ": 거래 전 파일 저장")
	var old_file: String = _read_file(saver.main_path())
	DirAccess.make_dir_recursive_absolute(saver.tmp_path())
	await _open_contests(app)
	_press(app, "ContestEnter_clear_bowl")
	var pending: String = _dict_str(app)
	app.call("_on_contest_enter", "clear_bowl")
	app.call("_on_magazine_accept", "clear_bowl")
	_check(_dict_str(app) == pending and _text_of(app, "ContestMessage").contains("저장하지 못했"), tag + ": 심사 중 중복 입력이 저장 실패 안내/잔액을 덮지 않음")
	app.call("advance_contest", 2.0)
	await _settle()
	_check(_read_file(saver.main_path()) == old_file and _text_of(app, "ContestMessage").contains("저장하지 못했"), tag + ": 실제 파일 쓰기 실패/원본 보존/거짓 성공 없음")
	await _reachable(app, vp, "ContestMessage")
	_overflow(app, vp, "출품 저장 실패")
	await _shot(holder, tag + "_50_contest_save_failed.png")
	var snapshot: String = _dict_str(app)
	app.call("_on_contest_enter", "clear_bowl")
	_check(_dict_str(app) == snapshot, tag + ": 저장 실패 뒤 재출품도 비용 중복 없음")
	DirAccess.remove_absolute(saver.tmp_path())
	await _open_contests(app)
	var saved: Dictionary = app.call("manual_save")
	_check(bool(saved["ok"]), tag + ": 막힌 경로 제거 뒤 수동 저장 회복")
	app.queue_free()
	await _frames(2)
	app = await _spawn(holder, dir)
	app.set_process(false)
	await _open_contests(app)
	_check(_dict_str(app) == snapshot, tag + ": 저장 회복/재시작 상태 보존")
	await _reachable(app, vp, "ContestResult")
	await _shot(holder, tag + "_51_contest_save_recovered.png")
	app.queue_free()
	await _frames(2)
	saver.remove_known_files()
	DirAccess.remove_absolute(dir)


func _dict_str(app: Node) -> String:
	# 사전 삽입 순서는 저장 파서에서 달라질 수 있다. 모든 값/배열 순서는 유지하고 키만 정렬해 의미를 비교한다.
	return JSON.stringify(_state(app).call("to_dict"), "", true)


## 실제 도메인 연산으로 레시피 하나를 시식한다(연구 증인 조합은 옛 모양 topping 문자열을 쓴다: 단일 토핑 경로). 기록 번호를 돌려준다.
func _domain_taste(app: Node, cfg: Dictionary, recipe_name: String) -> int:
	var st: Object = _state(app)
	st.call("start_new_recipe")
	for slot in ["broth", "tare", "oil", "noodle", "cook"]:
		st.call("set_draft_choice", slot, str(cfg[slot]))
	st.call("set_draft_choice", "topping", str(cfg["topping"]))
	st.call("set_draft_price", int(cfg["price"]))
	st.call("set_draft_name", recipe_name)
	var r: Dictionary = st.call("taste")
	_check(bool(r["ok"]), "준비 시식 실패(%s): %s" % [recipe_name, str(r["message"])])
	return int(r.get("record_id", 0))


## 실제 UI 로 하루를 영업한다: 서랍을 닫고 영업 시작 → 세션 끝까지 → 정산 → 결과 확인. 영업 시간만 세션 API 로 앞당긴다.
func _service_day_via_ui(app: Node, tag: String) -> void:
	if (_find(app, "Overlay") as Control).visible:
		_press(app, "CloseButton")
		await _settle()
	var st: Object = _state(app)
	var day0: int = int(st.get("day"))
	_press(app, "StartServiceButton")
	await _settle()
	_check(bool(st.call("service_active")), tag + ": 성장 준비 영업 시작")
	_advance(app, 6000.0)
	await _settle()
	await _frames(4)
	_check(not bool(st.call("service_active")) and int(st.get("day")) == day0 + 1, tag + ": 성장 준비 영업 정산 1회")
	_press(app, "ResultOkButton")
	await _settle()


func _open_growth_tab(app: Node) -> void:
	if not (_find(app, "Overlay") as Control).visible:
		_press(app, "DevButton")
		await _settle()
	(_find(app, "MainTabs") as TabContainer).current_tab = 5
	await _settle()
	var sc: ScrollContainer = (_find(app, "MainTabs") as TabContainer).get_child(5) as ScrollContainer
	sc.scroll_vertical = 0
	await _settle()


func _growth_reach_all(app: Node, vp: Vector2i) -> void:
	for name in ["GrowthSummary", "GrowthCapacity", "RankCurrent", "RankConditions", "PromoteButton"]:
		await _reachable(app, vp, name)
	for fid in ["bench_1", "bench_2", "staff_1", "staff_2"]:
		for prefix in ["Facility_", "FacilityTitle_", "FacilityInfo_", "FacilityBuy_"]:
			await _reachable(app, vp, prefix + fid)
	for sid in ["prep_assistant", "floor_assistant"]:
		for prefix in ["Staff_", "StaffPortrait_", "StaffTitle_", "StaffCost_", "StaffInfo_", "StaffHire_"]:
			await _reachable(app, vp, prefix + sid)


func _btn_disabled(app: Node, node_name: String) -> bool:
	var b: BaseButton = _find(app, node_name) as BaseButton
	_check(b != null, "버튼 없음: " + node_name)
	return b == null or b.disabled


## 노드 아래 모든 라벨 글을 이어 붙인다(카드 한 장의 글 검사용).
func _all_text(node: Node) -> String:
	var parts: Array[String] = []
	for child in node.find_children("*", "Label", true, false):
		parts.append(str((child as Label).text))
	return "\n".join(parts)


func _run_growth(holder: SubViewport, tag: String, vp: Vector2i) -> void:
	var dir: String = _data_root.path_join(tag + "_growth")
	DirAccess.make_dir_recursive_absolute(dir)
	var saver: SaveServiceScript = SaveServiceScript.new(dir)
	saver.remove_known_files()
	var app: Node = await _spawn(holder, dir)
	var st: Object = _state(app)
	var tabs: TabContainer = _find(app, "MainTabs") as TabContainer
	var witnesses: Dictionary = ResearchScript.WITNESSES

	# 1) 잠긴 첫 화면: 탭 6개(0~4 그대로 + 성장), 등급 1, 승급/구매/고용 모두 꺼짐 + 이유 표시.
	_check(tabs.get_tab_count() == 8 and tabs.get_tab_title(5) == "성장", tag + ": 성장 번호 유지 + 탐색 탭")
	_press(app, "DevButton")
	await _settle()
	await _open_growth_tab(app)
	var snap0: String = _dict_str(app)
	_check(_text_of(app, "GrowthSummary").find("1단계") >= 0 and _text_of(app, "GrowthSummary").find("골목 가게") >= 0, tag + ": 현재 등급 표시: " + _text_of(app, "GrowthSummary"))
	var cap_text: String = _text_of(app, "GrowthCapacity")
	_check(cap_text.find("토핑 슬롯 1/3") >= 0 and cap_text.find("0/6") >= 0 and cap_text.find("직원 2/2명") >= 0 and cap_text.find("빈 자리 0") >= 0 and cap_text.find("0원") >= 0, tag + ": 용량/직원/운영비 표시: " + cap_text)
	_check(_text_of(app, "RankConditions").find("[부족]") >= 0 and _text_of(app, "RankConditions").find("동네 맛집") >= 0, tag + ": 다음 등급 조건과 측정값: " + _text_of(app, "RankConditions"))
	_check(_btn_disabled(app, "PromoteButton") and _text_of(app, "PromoteButton").find("조건 부족") >= 0, tag + ": 조건이 모자라면 승급 버튼은 꺼짐")
	for fid in ["bench_1", "bench_2", "staff_1", "staff_2"]:
		_check(_btn_disabled(app, "FacilityBuy_" + fid) and _text_of(app, "FacilityInfo_" + fid).find("잠김") >= 0, tag + ": 잠긴 확장은 이유와 함께 꺼짐: " + fid)
		_check(_text_of(app, "FacilityInfo_" + fid).find("→") >= 0 and _text_of(app, "FacilityInfo_" + fid).find("필요:") >= 0, tag + ": 현재→새 용량/선행 조건 표시: " + _text_of(app, "FacilityInfo_" + fid))
	for sid in ["prep_assistant", "floor_assistant"]:
		_check(_btn_disabled(app, "StaffHire_" + sid) and _text_of(app, "StaffInfo_" + sid).find("직원 공간") >= 0, tag + ": 자리가 없으면 고용 불가 이유: " + sid)
	_check(_text_of(app, "StaffCost_prep_assistant").find("8,000원") >= 0 and _text_of(app, "StaffCost_prep_assistant").find("600원") >= 0, tag + ": 조리 보조 고용비/운영비 공개: " + _text_of(app, "StaffCost_prep_assistant"))
	_check(_text_of(app, "StaffCost_floor_assistant").find("7,000원") >= 0 and _text_of(app, "StaffCost_floor_assistant").find("500원") >= 0, tag + ": 홀 보조 고용비/운영비 공개: " + _text_of(app, "StaffCost_floor_assistant"))
	_check(_text_of(app, "StaffTitle_prep_assistant").find("조리 보조") >= 0 and _text_of(app, "StaffTitle_floor_assistant").find("홀 보조") >= 0, tag + ": 직원 역할 표시")
	var portraits: Array = []
	for sid2 in ["prep_assistant", "floor_assistant"]:
		var ptr: TextureRect = _find(app, "StaffPortrait_" + sid2) as TextureRect
		_check(ptr != null and ptr.size.x >= 47.5 and ptr.size.y >= 47.5, tag + ": 직원 초상 48px 이상: " + sid2)
		if ptr != null:
			portraits.append(ptr.texture.get_image().get_data())
	_check(portraits.size() == 2 and portraits[0] != portraits[1], tag + ": 두 직원 초상이 달라요")
	await _growth_reach_all(app, vp)
	_overflow(app, vp, tag + " 성장 잠김")
	# 핸들러를 직접 불러도(버튼이 꺼져 있어도) 도메인이 거부하고 아무것도 바뀌지 않는다.
	app.call("_on_promote_pressed")
	_check(_dict_str(app) == snap0 and _text_of(app, "GrowthMessage") != "", tag + ": 잠긴 승급 신청 거부: " + _text_of(app, "GrowthMessage"))
	app.call("_on_facility_buy", "bench_1")
	_check(_dict_str(app) == snap0 and _text_of(app, "GrowthMessage").find("등급") >= 0, tag + ": 등급 부족 구매 거부: " + _text_of(app, "GrowthMessage"))
	app.call("_on_facility_buy", "bench_2")
	app.call("_on_facility_buy", "nope")
	app.call("_on_staff_hire", "prep_assistant")
	_check(_dict_str(app) == snap0 and _text_of(app, "GrowthMessage").find("직원 공간") >= 0, tag + ": 자리 없는 고용 거부: " + _text_of(app, "GrowthMessage"))
	_check(_text_of(app, "GrowthMessage").find("저장했어요") < 0, tag + ": 거부 메시지가 저장했다고 말하면 안 돼요")
	_check(int(st.get("wallet")) == 30000 and st.call("rank") == 1 and (st.call("hired_staff") as Array).is_empty(), tag + ": 탭을 열고 거부해도 보상/고용/자금 변화 없음")
	await _open_growth_tab(app)
	await _shot(holder, tag + "_17_growth_locked.png")

	# 2) 토핑 슬롯 1개: 예전처럼 "다른 토핑을 고르면 바뀌는" 단순 선택, 개수/한도/해금 안내.
	tabs.current_tab = 0
	await _settle()
	_press(app, "Opt_topping_egg")
	_press(app, "Opt_topping_nori")
	await _settle()
	_check(not (_find(app, "Opt_topping_egg") as BaseButton).button_pressed and (_find(app, "Opt_topping_nori") as BaseButton).button_pressed, tag + ": 슬롯 1개는 선택이 바뀌어요")
	_check(_text_of(app, "ToppingCount").find("1/1") >= 0 and _text_of(app, "ToppingHint").find("1개만") >= 0 and _text_of(app, "ToppingHint").find("열려요") >= 0, tag + ": 토핑 개수/한도/해금 안내: " + _text_of(app, "ToppingCount") + " / " + _text_of(app, "ToppingHint"))
	await _reachable(app, vp, "ToppingCount")
	await _reachable(app, vp, "ToppingHint")

	# 3) 자격 채우기(실제 도메인 연산): 증인 여섯 시식 → 연구 1건 제출(UI 핸들러) → 실제 UI 영업 3일.
	var rec: Dictionary = {}
	for rid in ResearchScript.ids():
		rec[rid] = _domain_taste(app, witnesses[rid], "QA " + str(rid))
	_check(int(st.call("record_count")) == 6, tag + ": 증인 기록 6개(기본 용량 6칸)")
	st.call("select_record", int(rec["dohyun_basic"]))
	app.call("_refresh_all")
	app.call("_on_research_submit", "dohyun_basic")
	await _settle()
	_check(int(st.call("research_points")) == 2, tag + ": 연구 1건 완료")
	st.call("select_record", int(rec["hayoung_basic"]))
	for i in 3:
		await _service_day_via_ui(app, tag)
	_check(int(st.get("day")) == 4 and int(st.call("completed_service_days")) == 3, tag + ": 영업 3일 마침")
	await _open_growth_tab(app)
	_check(st.call("rank") == 1, tag + ": 조건을 채워도 저절로 승급하지 않아요")
	_check(not _btn_disabled(app, "PromoteButton") and _text_of(app, "PromoteButton").find("신청") >= 0, tag + ": 조건을 채우면 승급 버튼이 켜져요")
	_check(_text_of(app, "RankConditions").find("[부족]") < 0 and _text_of(app, "RankConditions").find("[달성]") >= 0, tag + ": 조건이 모두 달성: " + _text_of(app, "RankConditions"))
	await _growth_reach_all(app, vp)
	_overflow(app, vp, tag + " 성장 승급 가능")
	(tabs.get_child(5) as ScrollContainer).scroll_vertical = 0
	await _shot(holder, tag + "_18_growth_eligible.png")

	# 4) 명시적 승급(두 번 눌러 확정) + 실제 저장 결과.
	var wallet_pre: int = int(st.get("wallet"))
	_press(app, "PromoteButton")
	await _settle()
	_check(st.call("rank") == 1 and _text_of(app, "PromoteButton").find("한 번 더") >= 0 and _text_of(app, "GrowthMessage").find("한 번 더") >= 0, tag + ": 첫 누름은 확인만: " + _text_of(app, "GrowthMessage"))
	_press(app, "PromoteButton")
	await _settle()
	_check(st.call("rank") == 2 and int(st.get("wallet")) == wallet_pre, tag + ": 승급 완료, 자금 보상 없음")
	_check(_text_of(app, "GrowthMessage").find("동네 맛집") >= 0 and _text_of(app, "GrowthMessage").find("저장했어요") >= 0, tag + ": 승급 결과/저장 결과 표시: " + _text_of(app, "GrowthMessage"))
	_check(_text_of(app, "GrowthSummary").find("2단계") >= 0 and _text_of(app, "GrowthSummary").find("동네 맛집") >= 0, tag + ": 등급 표시 갱신")
	var after_rank: Dictionary = _load_probe(dir)
	_check(str(after_rank["status"]) == "ok" and (after_rank["state"] as Object).call("rank") == 2, tag + ": 승급이 실제 파일에 저장")
	_check(_btn_disabled(app, "PromoteButton") and _text_of(app, "RankConditions").find("이름난 라멘집") >= 0, tag + ": 3단계 조건이 다음 목표로 보이고 아직 신청 불가")
	_check(st.call("topping_slots") == 1 and st.call("record_capacity") == 6, tag + ": 승급만으로는 용량이 늘지 않아요")

	# 5) 유료 확장: 자금만 격리 인스턴스에서 채운다(가격/등급/선행 규칙은 그대로 도메인이 검증).
	st.set("wallet", 200000)
	app.call("_refresh_all")
	await _open_growth_tab(app)
	_check(not _btn_disabled(app, "FacilityBuy_bench_1") and not _btn_disabled(app, "FacilityBuy_staff_1"), tag + ": 2단계에서 I 단계 확장은 살 수 있어요")
	_check(_btn_disabled(app, "FacilityBuy_bench_2") and _text_of(app, "FacilityInfo_bench_2").find("등급 3단계") >= 0 and _btn_disabled(app, "FacilityBuy_staff_2"), tag + ": II 단계는 아직 잠김(등급 3 필요)")
	var w1: int = int(st.get("wallet"))
	_press(app, "FacilityBuy_bench_1")
	await _settle()
	_check(int(st.get("wallet")) == w1 - 12000 and st.call("topping_slots") == 2 and st.call("record_capacity") == 12, tag + ": 조리대 I: 12,000원 한 번, 토핑 2/노트 12")
	var buy_text: String = _text_of(app, "GrowthMessage")
	_check(buy_text.find("토핑 슬롯 1→2 · 노트 6→12") >= 0 and buy_text.find("2→2") < 0 and buy_text.find("저장했어요") >= 0, tag + ": 구매 메시지가 구매 전→후 변화와 저장 결과를 알려요: " + buy_text)
	app.call("_on_facility_buy", "bench_1")
	_check(int(st.get("wallet")) == w1 - 12000 and _text_of(app, "GrowthMessage") == "이미 설치했어요.", tag + ": 같은 확장 재구매 거부: " + _text_of(app, "GrowthMessage"))
	_check(_btn_disabled(app, "FacilityBuy_bench_1") and _text_of(app, "FacilityBuy_bench_1").find("설치 완료") >= 0, tag + ": 설치한 확장은 '설치 완료'")
	var w2: int = int(st.get("wallet"))
	_press(app, "FacilityBuy_staff_1")
	await _settle()
	_check(int(st.get("wallet")) == w2 - 15000 and st.call("staff_capacity") == 3 and (st.call("hired_staff") as Array).is_empty(), tag + ": 직원 공간 I: 15,000원, 직원 3명까지, 자동 고용 없음")
	_check(_text_of(app, "GrowthMessage").find("직원 2→3명까지") >= 0 and _text_of(app, "GrowthCapacity").find("직원 2/3명") >= 0 and _text_of(app, "GrowthCapacity").find("빈 자리 1") >= 0, tag + ": 직원 용량 표시: " + _text_of(app, "GrowthMessage"))
	_check(not _btn_disabled(app, "StaffHire_prep_assistant") and not _btn_disabled(app, "StaffHire_floor_assistant"), tag + ": 자리가 생기면 고용 버튼이 켜져요")

	# 6) 고용(역할/고용비/운영비 공개) → 한 명만, 중복/자리 부족 거부.
	var w3: int = int(st.get("wallet"))
	_press(app, "StaffHire_prep_assistant")
	await _settle()
	_check(int(st.get("wallet")) == w3 - 8000 and str(st.call("hired_staff")) == str(["prep_assistant"]), tag + ": 조리 보조 고용: 8,000원 한 번")
	_check(_text_of(app, "GrowthMessage").find("조리 보조") >= 0 and _text_of(app, "GrowthMessage").find("저장했어요") >= 0, tag + ": 고용 결과/저장 결과: " + _text_of(app, "GrowthMessage"))
	_check(_text_of(app, "GrowthCapacity").find("600원") >= 0 and _text_of(app, "GrowthCapacity").find("빈 자리 0") >= 0, tag + ": 하루 운영비/빈 자리 갱신: " + _text_of(app, "GrowthCapacity"))
	_check(_btn_disabled(app, "StaffHire_prep_assistant") and _text_of(app, "StaffHire_prep_assistant").find("고용 완료") >= 0 and _btn_disabled(app, "StaffHire_floor_assistant"), tag + ": 고용 완료/자리 없음 표시")
	var after_hire: String = _dict_str(app)
	app.call("_on_staff_hire", "prep_assistant")
	app.call("_on_staff_hire", "floor_assistant")
	_check(_dict_str(app) == after_hire, tag + ": 재고용/자리 없는 고용은 상태를 바꾸지 않아요")
	_check(_text_of(app, "GrowthMessage").find("직원 공간") >= 0, tag + ": 자리 부족 이유: " + _text_of(app, "GrowthMessage"))
	var shop: Node = _find(app, "ShopView")
	_check(str(shop.call("visible_staff")) == str(["prep_assistant"]), tag + ": 가게에 고용한 조리 보조가 보여요")
	await _growth_reach_all(app, vp)
	_overflow(app, vp, tag + " 성장 구매 후")
	(tabs.get_child(5) as ScrollContainer).scroll_vertical = 0
	await _shot(holder, tag + "_19_growth_purchased.png")
	# 서랍을 닫으면 가게 장면에 조리 보조가 서 있다.
	_press(app, "CloseButton")
	await _settle()
	_check_shop_layout(app, vp, tag + " 직원 고용 후", _scale_of(tag))
	_overflow(app, vp, tag + " 직원 있는 가게")
	await _shot(holder, tag + "_20_shop_staffed.png")

	# 7) 다중 토핑(슬롯 2개): 눌러서 넣고 빼기, 가득 찼을 때 거부, 마지막 하나 보호, 순서만 다른 중복 거부, 모든 토핑이 미리보기/피드백/노트/비교에 보인다.
	_press(app, "DevButton")
	await _settle()
	tabs.current_tab = 0
	await _settle()
	_press(app, "NewRecipeButton")
	for opt in ["Opt_broth_dashi", "Opt_tare_shio", "Opt_oil_scallion", "Opt_noodle_thin", "Opt_cook_firm"]:
		_press(app, opt)
	var edit: LineEdit = _find(app, "RecipeNameEdit") as LineEdit
	edit.text = "QA 두 토핑"
	edit.text_changed.emit(edit.text)
	# 지금 토핑은 [김] 하나. 반숙란을 더하면 둘, 차슈를 더하려 하면 가득 차서 거부된다.
	var bowl_one: PackedByteArray = (_find(app, "BowlPreview") as TextureRect).texture.get_image().get_data()
	_press(app, "Opt_topping_egg")
	await _settle()
	_check(_draft_toppings_text(st).find("topping_egg") >= 0 and _draft_toppings_text(st).find("topping_nori") >= 0, tag + ": 도메인 초안에도 토핑 둘: " + _draft_toppings_text(st))
	_check((_find(app, "Opt_topping_egg") as BaseButton).button_pressed and (_find(app, "Opt_topping_nori") as BaseButton).button_pressed and _text_of(app, "ToppingCount").find("2/2") >= 0, tag + ": 두 번째 토핑 추가: " + _text_of(app, "ToppingCount"))
	var bowl_two: PackedByteArray = (_find(app, "BowlPreview") as TextureRect).texture.get_image().get_data()
	_check(bowl_two != bowl_one, tag + ": 토핑을 더하면 그릇 미리보기가 달라져요")
	_press(app, "Opt_topping_chashu")
	await _settle()
	_check(not (_find(app, "Opt_topping_chashu") as BaseButton).button_pressed and (_find(app, "Opt_topping_egg") as BaseButton).button_pressed and (_find(app, "Opt_topping_nori") as BaseButton).button_pressed, tag + ": 가득 찼을 때 다른 토핑을 몰래 바꾸지 않아요")
	_check(_text_of(app, "TasteMessage").find("2개까지") >= 0, tag + ": 가득 참 거부 이유(한도/해금): " + _text_of(app, "TasteMessage"))
	_check(_text_of(app, "ToppingHint").find("최소 1개") >= 0 and _text_of(app, "ToppingHint").find("최대 2개") >= 0, tag + ": 다중 선택 안내: " + _text_of(app, "ToppingHint"))
	_press(app, "Opt_topping_nori")
	await _settle()
	_check(not (_find(app, "Opt_topping_nori") as BaseButton).button_pressed and _text_of(app, "ToppingCount").find("1/2") >= 0, tag + ": 눌러서 빼기")
	_press(app, "Opt_topping_egg")
	await _settle()
	_check((_find(app, "Opt_topping_egg") as BaseButton).button_pressed and _text_of(app, "ToppingCount").find("1/2") >= 0, tag + ": 마지막 하나는 뺄 수 없어요")
	_check(_text_of(app, "TasteMessage").find("최소 1개") >= 0, tag + ": 마지막 하나 보호 이유: " + _text_of(app, "TasteMessage"))
	_press(app, "Opt_topping_chashu")
	await _settle()
	_check((_find(app, "Opt_topping_chashu") as BaseButton).button_pressed and (_find(app, "Opt_topping_egg") as BaseButton).button_pressed, tag + ": 차슈 + 반숙란")
	_check(_text_of(app, "Desc_topping").find("차슈") >= 0 and _text_of(app, "Desc_topping").find("반숙란") >= 0, tag + ": 레시피 설명에 선택한 토핑이 모두 나와요")
	_check(_text_of(app, "ProfileLabel").find("원가") >= 0, tag + ": 구성 요약")
	for name in ["ToppingCount", "ToppingHint", "Opt_topping_chashu", "Opt_topping_egg", "Opt_topping_sprouts", "Opt_topping_nori", "TasteButton"]:
		await _reachable(app, vp, name)
	_overflow(app, vp, tag + " 다중 토핑 개발")
	(tabs.get_child(0) as ScrollContainer).scroll_vertical = 0
	await _shot(holder, tag + "_21_multi_topping_lab.png")
	await _finish_tasting(app)
	_check(tabs.current_tab == 1 and _text_of(app, "FeedbackToppings").find("차슈") >= 0 and _text_of(app, "FeedbackToppings").find("반숙란") >= 0 and _text_of(app, "FeedbackToppings").find("2개") >= 0, tag + ": 피드백에 토핑이 모두 보여요: " + _text_of(app, "FeedbackToppings"))
	var first_id: int = int(st.get("selected_record_id"))
	_check(_record_toppings_count(st.call("get_record", first_id)) == 2, tag + ": 기록에 토핑 2개")
	for id2 in ["dohyun", "hayoung", "maru"]:
		await _reachable(app, vp, "Card_" + id2)
		_check_score_line(app, id2, tag)
	(tabs.get_child(1) as ScrollContainer).scroll_vertical = 0
	_overflow(app, vp, tag + " 다중 토핑 피드백")
	await _shot(holder, tag + "_22_multi_topping_feedback.png")
	# 같은 토핑을 다른 순서로 다시 맞춰도 새 메뉴가 생기지 않는다(순서만 다른 구성 = 같은 레시피).
	tabs.current_tab = 0
	await _settle()
	# [차슈, 반숙란] → 차슈를 빼고 다시 넣어 [반숙란, 차슈] 순서로 같은 집합을 만든다.
	_press(app, "Opt_topping_chashu")
	await _settle()
	_press(app, "Opt_topping_chashu")
	await _settle()
	_check((_find(app, "Opt_topping_chashu") as BaseButton).button_pressed and (_find(app, "Opt_topping_egg") as BaseButton).button_pressed, tag + ": 같은 토핑 집합 복원")
	var count_before: int = int(st.call("record_count"))
	var dup: Dictionary = app.call("start_tasting")
	_check(not bool(dup["ok"]) and not bool(app.call("work_active")) and int(st.call("record_count")) == count_before and str(dup["message"]).find("이미 같은 구성") >= 0, tag + ": 순서만 바꾼 같은 구성은 시식 거부: " + str(dup["message"]))
	# 개정: 토핑을 바꿔 v2 로 시식하면 비교에 토핑 변화가 보인다.
	_press(app, "Opt_topping_chashu")
	_press(app, "Opt_topping_nori")
	await _settle()
	await _finish_tasting(app)
	_check(tabs.current_tab == 1 and _text_of(app, "FeedbackTitle").find("v2") >= 0, tag + ": 토핑 개정 v2")
	var cmp_text: String = _text_of(app, "ComparisonLabel")
	_check(cmp_text.find("토핑") >= 0 and cmp_text.find("차슈") >= 0 and cmp_text.find("김") >= 0 and cmp_text.find("→") >= 0, tag + ": 개정 비교에 토핑 변화: " + cmp_text)
	tabs.current_tab = 2
	await _settle()
	var row_text: String = _all_text(_find(app, "Row_%d" % int(st.get("selected_record_id"))))
	_check(row_text.find("반숙란") >= 0 and row_text.find("김") >= 0, tag + ": 노트 행에 토핑이 모두 보여요: " + row_text)
	_check(_text_of(app, "NotebookCount").find("/12") >= 0, tag + ": 확장 후 노트 용량 12: " + _text_of(app, "NotebookCount"))

	# 8) 보조 직원이 있는 영업: 세션은 시작 때 복사한 직원 스냅샷을 쓰고, 영업 중 성장 행동은 모두 거부된다. 운영비는 정산 한 번에 정확히.
	var recipe_id: int = int(st.get("selected_record_id"))
	_press(app, "CloseButton")
	await _settle()
	var wallet_s0: int = int(st.get("wallet"))
	var day_s0: int = int(st.get("day"))
	_press(app, "StartServiceButton")
	await _settle()
	_check(bool(st.call("service_active")), tag + ": 직원이 있는 영업 시작")
	var sess: Object = st.call("active_session")
	_check(int((sess.get("staffing") as Dictionary)["wage"]) == 600 and str((sess.get("staffing") as Dictionary)["hired"]) == str(["prep_assistant"]), tag + ": 세션의 직원 스냅샷: " + str(sess.get("staffing")))
	_check(int(st.get("wallet")) == wallet_s0, tag + ": 영업 시작은 운영비를 선청구하지 않아요")
	_advance(app, 900.0)
	await _settle()
	_check(str(shop.call("visible_staff")) == str(["prep_assistant"]), tag + ": 영업 중 장면은 직원 스냅샷")
	var busy_snap: String = _dict_str(app)
	app.call("_on_promote_pressed")
	app.call("_on_facility_buy", "bench_2")
	app.call("_on_facility_buy", "staff_2")
	app.call("_on_staff_hire", "floor_assistant")
	await _settle()
	_check(_dict_str(app) == busy_snap and bool(st.call("service_active")), tag + ": 영업 중 승급/구매/고용은 거부되고 아무것도 안 바뀌어요")
	_check(str((sess.get("staffing") as Dictionary)["hired"]) == str(["prep_assistant"]), tag + ": 영업 중 직원 스냅샷 불변")
	_check_shop_layout(app, vp, tag + " 직원 영업 중", _scale_of(tag))
	_overflow(app, vp, tag + " 직원 영업 중")
	await _shot(holder, tag + "_23_staffed_service.png")
	_advance(app, 6000.0)
	await _settle()
	await _frames(4)
	var rep: Dictionary = st.get("last_report")
	_check(not bool(st.call("service_active")) and int(st.get("day")) == day_s0 + 1, tag + ": 영업 정산 1회")
	_check(int(rep["overhead"]) == 3600 and int(st.get("wallet")) == wallet_s0 + int(rep["net"]), tag + ": 운영비 3,000 + 보조 600 이 정산에 정확히 한 번: " + str(rep))
	_check(_text_of(app, "ResultLabel").find("3,600원") >= 0, tag + ": 결과 창에 운영비 표시: " + _text_of(app, "ResultLabel"))
	_press(app, "ResultOkButton")
	await _settle()

	# 9) 시식 준비 중에는 성장 핸들러도 아무것도 바꾸기 전에 거부된다.
	_press(app, "DevButton")
	await _settle()
	tabs.current_tab = 0
	await _settle()
	_press(app, "PriceUp500")
	_press(app, "TasteButton")
	_check(bool(app.call("work_active")), tag + ": 시식 준비 시작")
	var work_snap: String = _dict_str(app)
	app.call("_on_promote_pressed")
	app.call("_on_facility_buy", "bench_2")
	app.call("_on_staff_hire", "floor_assistant")
	await _settle()
	_check(_dict_str(app) == work_snap and bool(app.call("work_active")), tag + ": 준비 중 성장 핸들러는 거부되고 상태 불변")
	_check(_text_of(app, "WorkNotice").find("시식 준비 중에는") >= 0, tag + ": 준비 중 거부 이유: " + _text_of(app, "WorkNotice"))
	for b in (_find(app, "GrowthList") as Node).find_children("*", "Button", true, false):
		_check((b as Button).disabled, tag + ": 준비 중 성장 버튼은 모두 꺼져요: " + str(b.name))
	_press(app, "WorkCancelButton")
	await _settle()
	_check(not bool(app.call("work_active")), tag + ": 준비 취소")

	# 10) 저장/재시작: 등급/확장/고용/용량이 그대로 복원되고 저절로 늘어나는 것이 없다.
	var wallet_r: int = int(st.get("wallet"))
	var records_r: int = int(st.call("record_count"))
	app.notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
	app.queue_free()
	await _frames(2)
	app = await _spawn(holder, dir)
	st = _state(app)
	shop = _find(app, "ShopView")
	_check(st.call("rank") == 2 and str(st.call("facilities_owned")) == str(["bench_1", "staff_1"]) and str(st.call("hired_staff")) == str(["prep_assistant"]), tag + ": 재시작 후 등급/확장/고용 복원")
	_check(int(st.get("wallet")) == wallet_r and int(st.call("record_count")) == records_r and st.call("topping_slots") == 2 and st.call("record_capacity") == 12 and st.call("staff_capacity") == 3, tag + ": 재시작 후 자금/기록/용량 복원(공짜 성장 없음)")
	_check(str(shop.call("visible_staff")) == str(["prep_assistant"]), tag + ": 재시작 후 가게에 직원이 서 있어요")
	await _open_growth_tab(app)
	_check(_text_of(app, "GrowthSummary").find("2단계") >= 0 and _text_of(app, "GrowthCapacity").find("직원 3/3명") >= 0 and _text_of(app, "StaffHire_prep_assistant").find("고용 완료") >= 0, tag + ": 재시작 후 성장 탭: " + _text_of(app, "GrowthCapacity"))
	_check(_btn_disabled(app, "PromoteButton"), tag + ": 재시작 후에도 승급은 저절로 일어나지 않아요")
	await _growth_reach_all(app, vp)
	_overflow(app, vp, tag + " 성장 재시작")
	(tabs_of(app).get_child(5) as ScrollContainer).scroll_vertical = 0
	await _shot(holder, tag + "_24_growth_reloaded.png")

	# 11) 3단계까지: 남은 자격은 실제 도메인 연산(연구 제출, 영업)으로 채우고, 승급/구매/고용/토핑 3개는 UI 로 한다.
	for rid3 in ["hayoung_basic", "maru_basic", "dohyun_advanced", "hayoung_advanced", "maru_advanced"]:
		var res: Dictionary = st.call("submit_research", rid3, int(rec[rid3]))
		_check(bool(res["ok"]), tag + ": 연구 제출 " + rid3 + " " + str(res["message"]))
	st.call("select_record", int(rec["hayoung_basic"]))
	var guard: int = 0
	while int(st.get("day")) < 11 and guard < 20:
		st.call("serve")
		guard += 1
	_check(int(st.get("day")) >= 11 and int(st.call("research_points")) == 21, tag + ": 3단계 자격 채움(영업 10일, 연구 6건)")
	app.call("_refresh_all")
	await _open_growth_tab(app)
	_check(not _btn_disabled(app, "PromoteButton"), tag + ": 3단계 승급 가능")
	_press(app, "PromoteButton")
	_press(app, "PromoteButton")
	await _settle()
	_check(st.call("rank") == 3 and _text_of(app, "GrowthMessage").find("이름난 라멘집") >= 0 and _text_of(app, "GrowthMessage").find("저장했어요") >= 0, tag + ": 3단계 승급: " + _text_of(app, "GrowthMessage"))
	_check(_btn_disabled(app, "PromoteButton") and _text_of(app, "PromoteButton").find("최고") >= 0, tag + ": 최고 등급 표시")
	app.call("_on_promote_pressed")
	_check(_text_of(app, "GrowthMessage").find("가장 높은 등급") >= 0, tag + ": 최고 등급 이후 신청 거부")
	st.set("wallet", 300000)
	app.call("_refresh_all")
	await _open_growth_tab(app)
	var w4: int = int(st.get("wallet"))
	_press(app, "FacilityBuy_bench_2")
	await _settle()
	_check(int(st.get("wallet")) == w4 - 30000 and st.call("topping_slots") == 3 and st.call("record_capacity") == 30, tag + ": 조리대 II: 30,000원, 토핑 3/노트 30")
	_check(_text_of(app, "GrowthMessage").find("토핑 슬롯 2→3 · 노트 12→30") >= 0, tag + ": 조리대 II 메시지: " + _text_of(app, "GrowthMessage"))
	_press(app, "FacilityBuy_staff_2")
	await _settle()
	_check(st.call("staff_capacity") == 4 and (st.call("hired_staff") as Array).size() == 1, tag + ": 직원 공간 II: 4명까지, 자동 고용 없음")
	_press(app, "StaffHire_floor_assistant")
	await _settle()
	_check(str(st.call("hired_staff")) == str(["prep_assistant", "floor_assistant"]) and _text_of(app, "GrowthCapacity").find("직원 4/4명") >= 0 and _text_of(app, "GrowthCapacity").find("1,100원") >= 0, tag + ": 홀 보조 고용: " + _text_of(app, "GrowthCapacity"))
	_check(str(shop.call("visible_staff")) == str(["prep_assistant", "floor_assistant"]), tag + ": 가게에 보조 둘")
	await _growth_reach_all(app, vp)
	_overflow(app, vp, tag + " 성장 전체")
	(tabs_of(app).get_child(5) as ScrollContainer).scroll_vertical = 0
	await _shot(holder, tag + "_26_growth_full.png")
	# 토핑 3개: 차슈 + 반숙란 + 김. 네 번째는 거부.
	tabs_of(app).current_tab = 0
	await _settle()
	_press(app, "NewRecipeButton")
	st.call("set_draft_toppings", ["topping_chashu"])
	app.call("_refresh_all")
	for opt2 in ["Opt_broth_tonkotsu", "Opt_tare_shoyu", "Opt_oil_garlic", "Opt_noodle_medium", "Opt_cook_normal"]:
		_press(app, opt2)
	var edit3: LineEdit = _find(app, "RecipeNameEdit") as LineEdit
	edit3.text = "QA 세 토핑"
	edit3.text_changed.emit(edit3.text)
	_press(app, "Opt_topping_egg")
	_press(app, "Opt_topping_nori")
	await _settle()
	_check(_text_of(app, "ToppingCount").find("3/3") >= 0, tag + ": 토핑 3/3: " + _text_of(app, "ToppingCount"))
	_press(app, "Opt_topping_sprouts")
	await _settle()
	_check(not (_find(app, "Opt_topping_sprouts") as BaseButton).button_pressed and _text_of(app, "TasteMessage").find("3개까지") >= 0, tag + ": 네 번째 토핑 거부: " + _text_of(app, "TasteMessage"))
	await _finish_tasting(app)
	_check(_text_of(app, "FeedbackToppings").find("차슈") >= 0 and _text_of(app, "FeedbackToppings").find("반숙란") >= 0 and _text_of(app, "FeedbackToppings").find("김") >= 0 and _text_of(app, "FeedbackToppings").find("3개") >= 0, tag + ": 피드백에 토핑 3개: " + _text_of(app, "FeedbackToppings"))
	_check(_record_toppings_count(st.call("get_record", int(st.get("selected_record_id")))) == 3, tag + ": 기록에 토핑 3개")
	# 보조 둘 + 토핑 3개 영업.
	_press(app, "CloseButton")
	await _settle()
	var wallet_f0: int = int(st.get("wallet"))
	var day_f0: int = int(st.get("day"))
	_press(app, "StartServiceButton")
	await _settle()
	_check(bool(st.call("service_active")), tag + ": 완전 성장 상태 영업 시작")
	_advance(app, 900.0)
	await _settle()
	_check(str(shop.call("visible_staff")) == str(["prep_assistant", "floor_assistant"]), tag + ": 영업 중 보조 둘이 보여요")
	_check_shop_layout(app, vp, tag + " 보조 둘 영업 중", _scale_of(tag))
	_overflow(app, vp, tag + " 보조 둘 영업 중")
	await _shot(holder, tag + "_27_full_service.png")
	_advance(app, 6000.0)
	await _settle()
	await _frames(4)
	var rep2: Dictionary = st.get("last_report")
	_check(int(st.get("day")) == day_f0 + 1 and int(rep2["overhead"]) == 4100 and int(st.get("wallet")) == wallet_f0 + int(rep2["net"]), tag + ": 운영비 3,000 + 1,100: " + str(rep2))
	_press(app, "ResultOkButton")
	await _settle()
	app.queue_free()
	await _frames(2)
	saver.remove_known_files()
	DirAccess.remove_absolute(dir)


func tabs_of(app: Node) -> TabContainer:
	return _find(app, "MainTabs") as TabContainer


func _scale_of(tag: String) -> int:
	for p in PROFILES:
		var prof: Dictionary = p
		if str(prof["tag"]) == tag:
			return int(prof["scale"])
	return 1


## 기록 딕셔너리의 토핑 개수(없으면 0).
func _record_toppings_count(rec: Dictionary) -> int:
	if rec.is_empty():
		return 0
	var cfg: Dictionary = rec["config"]
	return (cfg["toppings"] as Array).size()


## 지금 초안의 토핑 id 목록 문자열(화면과 별개로 도메인 값을 읽는다).
func _draft_toppings_text(st: Object) -> String:
	var cfg: Dictionary = st.get("draft_config")
	return str(cfg["toppings"])


## 저장이 실패해도 성장 행동이 "저장했어요"라고 거짓말하지 않는지, 메모리 변화는 남는지, 문제를 치우면 다음 행동에서 복구되는지 본다.
## 실패는 QA 전용 폴더에서 임시 저장 파일 이름과 같은 "폴더"를 만들어 유도한다.
func _run_growth_failure(holder: SubViewport, tag: String, vp: Vector2i) -> void:
	var dir: String = _data_root.path_join(tag + "_growthfail")
	DirAccess.make_dir_recursive_absolute(dir)
	var saver: SaveServiceScript = SaveServiceScript.new(dir)
	saver.remove_known_files()
	var conflict: String = saver.tmp_path()
	if DirAccess.dir_exists_absolute(conflict):
		DirAccess.remove_absolute(conflict)
	var app: Node = await _spawn(holder, dir)
	var st: Object = _state(app)
	var witnesses: Dictionary = ResearchScript.WITNESSES
	# 자격(실제 도메인 연산): 증인 둘 시식 → 연구 1건 → 영업 3일(즉시 영업 경로).
	var rid_d: int = _domain_taste(app, witnesses["dohyun_basic"], "QA 실패 도윤")
	var rid_h: int = _domain_taste(app, witnesses["hayoung_basic"], "QA 실패 하영")
	_check(bool(st.call("submit_research", "dohyun_basic", rid_d)["ok"]), tag + ": 실패 시나리오 연구 제출")
	st.call("select_record", rid_h)
	for i in 3:
		_check(bool(st.call("serve")["ok"]), tag + ": 실패 시나리오 영업 %d일" % (i + 1))
	st.set("wallet", 100000)
	app.call("_refresh_all")
	_check(not (_find(app, "SaveBanner") as Control).visible, tag + ": 시작 때는 저장 경고가 없어요")
	await _open_growth_tab(app)
	_check(FileAccess.file_exists(saver.main_path()), tag + ": 첫 방문 저장 파일")
	_check(DirAccess.make_dir_recursive_absolute(conflict) == OK, tag + ": 저장 충돌 준비")
	_press(app, "PromoteButton")
	_press(app, "PromoteButton")
	await _settle()
	var msg: String = _text_of(app, "GrowthMessage")
	_check(st.call("rank") == 2, tag + ": 저장에 실패해도 메모리의 승급은 그대로(정직하게 알림)")
	_check(msg.find("저장하지 못했") >= 0 and msg.find("저장했어요") < 0, tag + ": 승급 결과가 저장 실패를 알려요: " + msg)
	_check((_find(app, "SaveBanner") as Control).visible and _text_of(app, "SaveBannerLabel").find("저장하지 못했") >= 0, tag + ": 서랍이 닫혀도 보이는 경고 배너")
	var probe: Dictionary = _load_probe(dir)
	_check(str(probe["status"]) == "ok" and (probe["state"] as Object).call("rank") == 1, tag + ": 실패한 저장은 파일에 반영되지 않았어요")
	await _reachable(app, vp, "GrowthMessage")
	_overflow(app, vp, tag + " 성장 저장 실패")
	(tabs_of(app).get_child(5) as ScrollContainer).scroll_vertical = 0
	await _shot(holder, tag + "_25_growth_save_failed.png")
	# 복구: 문제를 치우고 다음 행동(구매)을 하면 앞선 승급까지 함께 저장되고 배너가 사라진다.
	DirAccess.remove_absolute(conflict)
	_press(app, "FacilityBuy_bench_1")
	await _settle()
	_check(_text_of(app, "GrowthMessage").find("저장했어요") >= 0 and not (_find(app, "SaveBanner") as Control).visible, tag + ": 복구 후 구매는 저장되고 배너가 사라져요: " + _text_of(app, "GrowthMessage"))
	var healed: Dictionary = _load_probe(dir)
	var hs: Object = healed["state"]
	_check(str(healed["status"]) == "ok" and hs.call("rank") == 2 and str(hs.call("facilities_owned")) == str(["bench_1"]), tag + ": 복구 후 파일에 승급+구매가 모두 있어요")
	# 손상 저장 잠금: 성장 행동도 파일을 지우거나 덮어쓰지 않는다(메모리 변화만, 실패를 알림).
	app.queue_free()
	await _frames(2)
	var garbage: String = "{ 손상된 성장 저장"
	var gf: FileAccess = FileAccess.open(saver.main_path(), FileAccess.WRITE)
	_check(gf != null, tag + ": 손상 파일 준비")
	if gf != null:
		gf.store_string(garbage)
		gf.close()
	var locked_app: Node = await _spawn(holder, dir)
	_check(bool(locked_app.get("save_locked")), tag + ": 손상 저장은 잠겨요")
	_check(_text_of(locked_app, "ResetSaveButton") != "", tag + ": 손상 파일 보관 버튼")
	await _open_growth_tab(locked_app)
	locked_app.call("_on_facility_buy", "bench_1")
	# 새 게임 상태라 실제 구매는 도메인이 거부한다. 그래서 "도메인이 성공했을 때 화면이 저장을 시도하는 경로"를 직접 불러
	# 잠금 상태가 파일을 건드리지 않고 거짓 성공도 말하지 않는지 본다(화면 쪽 저장 경계만 검사하며 도메인 상태는 바꾸지 않는다).
	locked_app.call("_finish_growth_action", {"ok": true, "message": "QA 잠금 시험."})
	_check(_text_of(locked_app, "GrowthMessage").find("저장하지 못했") >= 0 and _text_of(locked_app, "GrowthMessage").find("저장했어요") < 0, tag + ": 잠금 상태 성장 결과는 저장 실패를 알려요: " + _text_of(locked_app, "GrowthMessage"))
	_check(_read_file(saver.main_path()) == garbage, tag + ": 잠금 상태에서 성장 행동이 손상 파일을 건드리지 않아요")
	locked_app.notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
	locked_app.queue_free()
	await _frames(2)
	_check(_read_file(saver.main_path()) == garbage, tag + ": 닫은 뒤에도 손상 파일 그대로")
	saver.remove_known_files()
	DirAccess.remove_absolute(conflict)
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
