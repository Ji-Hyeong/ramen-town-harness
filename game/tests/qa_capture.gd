extends SceneTree
## 선택 실행 QA: 실제 UI 씬을 만들어 데스크톱(1280x800)과 세로(390x844)에서 스크린샷을 저장한다.
## 실제 렌더러가 필요하므로 --headless 없이 실행한다.
##   Godot --path game --script res://tests/qa_capture.gd -- --qa-out=<절대경로> [--dev-data-dir=<절대경로>]
## --dev-data-dir 이 없으면 <qa-out>/qa_data 를 저장 폴더로 쓴다(user:// 는 절대 쓰지 않는다).
## 화면 크기별로 SubViewport 를 만들기 때문에 창 크기와 무관하게 정확한 해상도로 캡처된다.
## 실제 UI의 pressed 신호를 보내 선택/시식/개정/노트/영업/재시작 복원을 확인하고, 실패하면 종료 코드 1.

const SaveServiceScript = preload("res://scripts/services/save_service.gd")

const PROFILES: Array = [
	{"tag": "desktop", "w": 1280, "h": 800},
	{"tag": "portrait", "w": 390, "h": 844},
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
		await _run_profile(str(prof["tag"]), Vector2i(int(prof["w"]), int(prof["h"])))
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


## 현재 탭에서 컨트롤이 보이고, 필요하면 스크롤해서 화면 안에 들어오며, 터치 크기를 만족하는지 본다.
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
	_check(view.encloses(r), "화면 밖에 있어요: %s %s (뷰 %s)" % [node_name, str(r), str(vp)])
	if sc != null:
		var sr: Rect2 = sc.get_global_rect().grow(2.0)
		_check(sr.encloses(r), "스크롤 영역 안으로 들어오지 않아요: %s" % node_name)
	if c is BaseButton:
		_check(c.size.y >= 44.0 and c.size.x >= 44.0, "터치 크기 44px 미만: %s %s" % [node_name, str(c.size)])


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


# ---------- 시나리오 ----------

func _run_profile(tag: String, vp: Vector2i) -> void:
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

	# 1) 시작 화면과 핵심 컨트롤
	_check(_text_of(app, "DayLabel").find("1일차") >= 0, tag + ": 시작은 1일차")
	_check(_text_of(app, "LoadStatusLabel").find("첫 방문") >= 0, tag + ": 첫 실행 상태 표시")
	_check(_text_of(app, "DevSaveLabel").find(data_dir) >= 0, tag + ": 개발용 저장 위치 표시")
	for name in ["DayLabel", "WalletLabel", "BowlView", "SaveStatusLabel"]:
		await _reachable(app, vp, name)
	tabs.current_tab = 0
	await _settle()
	for name in ["RecipeNameEdit", "NewRecipeButton", "Opt_broth_tonkotsu", "Opt_broth_dashi", "Opt_tare_shio", "Opt_oil_scallion", "Opt_noodle_thin", "Opt_topping_egg", "Opt_cook_firm", "PriceUp500", "PriceLabel", "TasteButton"]:
		await _reachable(app, vp, name)
	_overflow(app, vp, tag + " 연구")
	var lab_scroll: ScrollContainer = tabs.get_child(0) as ScrollContainer
	lab_scroll.scroll_vertical = 0
	await _shot(holder, tag + "_1_lab.png")

	# 2) 재료 선택 + 이름 + 가격
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
	await _shot(holder, tag + "_2_lab_selected.png")

	# 3) 시식
	_press(app, "TasteButton")
	await create_timer(1.2).timeout
	_check(tabs.current_tab == 1, tag + ": 시식 후 피드백 탭으로 이동")
	for id in ["dohyun", "hayoung", "maru"]:
		await _reachable(app, vp, "Card_" + id)
	_check(_text_of(app, "FeedbackTitle").find("QA 맑은 라멘 v1") >= 0, tag + ": 제목 v1")
	_check(_text_of(app, "Headline_dohyun") != _text_of(app, "Headline_hayoung"), tag + ": 손님별 피드백이 다름")
	_check(_text_of(app, "ComparisonLabel").find("첫 시식") >= 0, tag + ": 첫 시식은 비교 없음 안내")
	_overflow(app, vp, tag + " 시식")
	(tabs.get_child(1) as ScrollContainer).scroll_vertical = 0
	await _shot(holder, tag + "_3_feedback_v1.png")

	# 4) 개정 + 비교
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
	await _shot(holder, tag + "_4_comparison_v2.png")
	_overflow(app, vp, tag + " 비교")

	# 5) 노트
	tabs.current_tab = 2
	await _settle()
	for name in ["NotebookCount", "Row_1", "Row_2", "SelectRecord_1", "DeleteRecord_1", "SelectRecord_2"]:
		await _reachable(app, vp, name)
	_check(_text_of(app, "NotebookCount").find("2/30") >= 0, tag + ": 노트 개수 표시")
	_overflow(app, vp, tag + " 노트")
	(tabs.get_child(2) as ScrollContainer).scroll_vertical = 0
	await _shot(holder, tag + "_5_notebook.png")
	_press(app, "SelectRecord_1")
	await _settle()
	_check(tabs.current_tab == 0, tag + ": 불러오면 연구 탭으로 이동")
	_check((_find(app, "Opt_noodle_thin") as BaseButton).button_pressed, tag + ": 불러온 레시피의 면 복원")
	_check((_find(app, "Opt_cook_firm") as BaseButton).button_pressed, tag + ": 불러온 레시피의 익힘 복원")
	_check(_text_of(app, "PriceLabel").find("9,500") >= 0, tag + ": 불러온 레시피의 가격 복원")
	_check(_text_of(app, "RecipeNameEdit") == "QA 맑은 라멘", tag + ": 이름 복원")

	# 6) 하루 영업
	tabs.current_tab = 3
	await _settle()
	for name in ["ServeIntro", "ServeMenu", "ServeForecast", "ServeButton", "ReportLabel"]:
		await _reachable(app, vp, name)
	_check(_text_of(app, "ServeIntro").find("하루") >= 0, tag + ": 영업이 하루 단위임을 표시")
	_overflow(app, vp, tag + " 영업")
	(tabs.get_child(3) as ScrollContainer).scroll_vertical = 0
	await _shot(holder, tag + "_6_serve_before.png")
	_press(app, "ServeButton")
	await _settle()
	_check(_text_of(app, "DayLabel").find("2일차") >= 0, tag + ": 영업 후 2일차")
	var report: String = _text_of(app, "ReportLabel")
	_check(report.find("순영업이익") >= 0 and report.find("매출") >= 0 and report.find("재료비") >= 0, tag + ": 영업 보고: " + report)
	(tabs.get_child(3) as ScrollContainer).scroll_vertical = 0
	await _shot(holder, tag + "_7_serve_after.png")

	# 7) 재시작 복원
	app.queue_free()
	await _frames(2)
	var again: Node = await _spawn(holder, data_dir)
	_check(_text_of(again, "LoadStatusLabel").find("저장된 연구소") >= 0, tag + ": 재시작 시 불러오기 상태 표시: " + _text_of(again, "LoadStatusLabel"))
	_check(_text_of(again, "DayLabel").find("2일차") >= 0, tag + ": 재시작 후 일차 복원")
	var tabs2: TabContainer = _find(again, "MainTabs") as TabContainer
	tabs2.current_tab = 2
	await _settle()
	_check(_find(again, "Row_1") != null and _find(again, "Row_2") != null, tag + ": 재시작 후 노트 복원")
	_check(_text_of(again, "ReportLabel") != "" and _text_of(again, "ReportLabel").find("순영업이익") >= 0, tag + ": 재시작 후 영업 보고 복원")
	_overflow(again, vp, tag + " 재시작")
	await _shot(holder, tag + "_8_reloaded_notebook.png")

	holder.queue_free()
	await _frames(2)
