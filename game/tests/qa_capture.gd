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

const PROFILES: Array = [
	{"tag": "desktop", "w": 1280, "h": 800, "scale": 4},
	{"tag": "portrait", "w": 390, "h": 844, "scale": 3},
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
	_press(app, "TasteButton")
	await create_timer(1.2).timeout
	_check(tabs.current_tab == 1, tag + ": 시식 후 피드백 탭으로 이동")
	for id in ["dohyun", "hayoung", "maru"]:
		await _reachable(app, vp, "Card_" + id)
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
	_press(app, "TasteButton")
	await create_timer(1.2).timeout
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

	holder.queue_free()
	await _frames(2)


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
