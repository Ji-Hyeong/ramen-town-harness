extends Control
## 라멘 아틀리에 메인 화면: 가게가 기본 화면이고, 메뉴 개발은 아래 버튼으로 여는 보조 서랍(overlay)이다.
## 모든 판단(평가/영업 운영/정산/저장 검증)은 domain·services가 하고 여기서는 표시와 입력만 맡는다.
##
## 영업 흐름: [영업 시작] → GameState.begin_service()(자금·일차 불변) → 매 프레임 세션을 진행 → 세션이 끝나면
## GameState.settle_service()가 완료 주문으로 딱 한 번 정산. 중간에 중단/종료하면 아무것도 저장되지 않는다.
## 레이아웃: 폭 720 미만이면 세로(휴대폰), 아니면 가로(데스크톱). 장면은 정수 배율 도트 장면이다.

const Catalog = preload("res://scripts/domain/ingredient_catalog.gd")
const Customers = preload("res://scripts/domain/customer_catalog.gd")
const Check = preload("res://scripts/domain/data_check.gd")
const Evaluator = preload("res://scripts/domain/recipe_evaluator.gd")
const Sim = preload("res://scripts/domain/sales_simulator.gd")
const SessionScript = preload("res://scripts/domain/service_session.gd")
const GameStateScript = preload("res://scripts/domain/game_state.gd")
const Research = preload("res://scripts/domain/ramen_research.gd")
const StoryCatalog = preload("res://scripts/domain/regular_story_catalog.gd")
const Stories = preload("res://scripts/domain/regular_stories.gd")
const Growth = preload("res://scripts/domain/shop_growth.gd")
const Staffing = preload("res://scripts/domain/shop_staffing.gd")
const Training = preload("res://scripts/domain/staff_training.gd")
const ProcessRules = preload("res://scripts/domain/recipe_process.gd")
const SaveServiceScript = preload("res://scripts/services/save_service.gd")
const FeedbackScript = preload("res://scripts/ui/action_feedback.gd")
const Discovery = preload("res://scripts/domain/recipe_discovery.gd")
const Experiments = preload("res://scripts/domain/recipe_experiments.gd")
const Directions = preload("res://scripts/domain/recipe_directions.gd")
const AudioScript = preload("res://scripts/ui/action_audio.gd")
const JournalScript = preload("res://scripts/ui/recipe_journal.gd")
const DetailsScript = preload("res://scripts/ui/disclosure_card.gd")
const ScrollableNameEdit = preload("res://scripts/ui/scrollable_name_edit.gd")
const LocationScript = preload("res://scripts/services/data_location.gd")
const StarMeterScript = preload("res://scripts/ui/star_meter.gd")
const ShopViewScript = preload("res://scripts/ui/shop_view.gd")
const ArtScript = preload("res://scripts/ui/pixel_art.gd")
const WorkScript = preload("res://scripts/ui/tasting_work.gd")
const WorkViewScript = preload("res://scripts/ui/tasting_work_view.gd")
const Exploration = preload("res://scripts/domain/ingredient_exploration.gd")
const Foraging = preload("res://scripts/domain/market_foraging.gd")
const Harbor = preload("res://scripts/domain/harbor_foraging.gd")
const TravelScript = preload("res://scripts/ui/expedition_travel.gd")
const Contest = preload("res://scripts/domain/ramen_contest.gd")
const BowlWorkbenchScript = preload("res://scripts/ui/bowl_workbench.gd")
var _bowl_editor: BowlWorkbenchScript
const ExplorationWorkbenchScript = preload("res://scripts/ui/exploration_workbench.gd")
var _exploration_view: ExplorationWorkbenchScript
const ServiceResultScript = preload("res://scripts/ui/service_result_view.gd")
var _service_result: ServiceResultScript
# Runtime evidence belongs only to the exact completed receipt. It is never
# serialized or inferred later from an edited draft or a different service day.
var _service_result_context: Dictionary = {}
var _service_result_key: String = ""
var _service_sold_snapshot: Array = []
var _last_report_button: Button
const ShopHomeScript = preload("res://scripts/ui/shop_home_view.gd")
var _home: ShopHomeScript
const StaffGrowthScript = preload("res://scripts/ui/staff_growth_workbench.gd")
var _growth_view: StaffGrowthScript
var _growth_revision: int = 0

const INK: Color = Color(0.17, 0.12, 0.08)
const PAPER: Color = Color(0.96, 0.92, 0.82)
const PAPER_LIGHT: Color = Color(0.99, 0.96, 0.88)
const PAPER_DARK: Color = Color(0.88, 0.80, 0.64)
const VERMILION: Color = Color(0.76, 0.23, 0.13)
const TEAL: Color = Color(0.20, 0.46, 0.44)
const MUTED: Color = Color(0.40, 0.33, 0.26)
const LINE: Color = Color(0.62, 0.45, 0.28)
const WOOD_D: Color = Color(0.24, 0.14, 0.08)
const WOOD: Color = Color(0.40, 0.25, 0.13)
const WOOD_L: Color = Color(0.58, 0.38, 0.20)
const CREAM: Color = Color(0.99, 0.94, 0.80)
const BACKDROP: Color = Color(0.11, 0.12, 0.16)

const MIN_TOUCH: float = 48.0
const WIDE_BREAKPOINT: float = 720.0
const HUD_H: float = 50.0
const NAV_H: float = 60.0
const GAP: float = 6.0

# 게임초/실제초. 40배속이면 점심 피크 40분(2400게임초)이 약 1분, 2배 빠르게면 약 30초다(마감 후 정리 시간 별도).
const SPEED_NORMAL: float = 36.0
const SPEED_FAST: float = 72.0
const STOP_CONFIRM_MS: int = 3000
const FLASH_MS: int = 4500

const TAB_LAB: int = 0
const TAB_FEEDBACK: int = 1
const TAB_NOTEBOOK: int = 2
const TAB_SERVE: int = 3
const TAB_RESEARCH: int = 4
const TAB_GROWTH: int = 5
const TAB_EXPLORATION: int = 6
## 등급 심사 신청은 실수로 누르기 쉬우므로 두 번 눌러야 확정된다(첫 누름 후 이 시간 안에 다시 눌러야 함).
const PROMOTE_CONFIRM_MS: int = 4000

const NOT_SAVED_NOTE: String = "영업은 끝까지 진행해야 정산·저장돼요. 도중에 끄면 저장되지 않고 영업 전으로 돌아가요."
const RUNNING_NOTE: String = "정산 전이에요. 끝까지 진행해야 반영·저장되고, 도중에 닫으면 저장되지 않아요."
const AUTOSAVE_NOTE: String = "자동 저장: 시식 완료, 연구 제출, 노트 정리, 영업 정산, 탐색 출발·선택·결과, 서랍 닫기·탭 이동 때 파일에 써요. 진행 중 탐색은 이어갈 수 있어요. 영업과 시식 준비는 끝나기 전 진행을 저장하지 않아요."
const WORK_NOTE: String = "아직 재료비가 나가지 않았고 기록도 없어요. 끝까지 준비되면 시식 기록이 한 번만 만들어지고 그때 저장돼요. 도중에 닫으면 사라져요."

## 테스트/QA가 ready 전에 주입할 수 있다. 비어 있으면 명령줄에서 결정한다.
var data_location: Dictionary = {}

var state: GameStateScript
var saver: SaveServiceScript
var save_locked: bool = false

var tabs: TabContainer
var _shop: ShopViewScript
var _hud: PanelContainer
var _day_label: Label
var _wallet_label: Label
var _clock_label: Label
var _progress: ProgressBar
var _banner: PanelContainer
var _banner_label: Label
var _reset_button: Button
var _status: PanelContainer
var _status_label: Label
var _note_label: Label
var _nav: PanelContainer
var _dev_button: Button
var _start_button: Button
var _speed_button: Button
var _result_layer: Control
var _result_title: Label
var _result_label: Label
var _result_note: Label
var _overlay: Control
var _drawer_margin: MarginContainer
var _guide_label: Label
var _open_button: Button
var _load_label: Label
var _save_label: Label
var _dev_label: Label

var _name_edit: LineEdit
var _mode_label: Label
var _price_label: Label
var _profile_label: Label
var _compat_label: Label
var _taste_button: Button
var _taste_message: Label
var _bowl_rect: TextureRect
var _bowl_caption: Label
var _groups: Dictionary = {}
var _buttons: Dictionary = {}
var _desc_labels: Dictionary = {}
var _icon_cache: Dictionary = {}

var _feedback_box: VBoxContainer
var _notebook_count: Label
var _notebook_box: VBoxContainer
var _notebook_page: int = 0
const NOTEBOOK_PAGE_SIZE: int = 20
var _serve_intro: Label
var _serve_menu: Label
var _serve_forecast: Label
var _report_label: Label
var _research_summary: Label
var _research_target: Label
var _research_message: Label
var _research_box: VBoxContainer
var _story_mode: bool = false
var _story_armed: String = ""
var _story_armed_until: int = 0
var _story_history: Dictionary = {}

## "성장" 탭(5): 가게 등급 / 유료 확장 / 보조 직원 고용. 위쪽 요약·메시지 라벨은 고정이고 카드 목록은 갱신 때마다 다시 만든다.
var _growth_summary: Label
var _growth_capacity: Label
var _growth_message: Label
var _growth_box: VBoxContainer
## 갱신 때 다시 만든 성장 행동 버튼(승급/구매/고용). 시식 준비 중에는 일괄로 꺼서 보여 준다(실제 차단은 각 핸들러의 _work_blocked + 도메인).
var _growth_buttons: Array[Button] = []
var _promote_armed_until: int = 0
var _expansion_armed_until: int = 0
var _selling_box: VBoxContainer
var _selling_message: Label
var _selling_buttons: Array[Button] = []
var _process_buttons: Dictionary = {}
var _process_infos: Dictionary = {}
## 훈련은 두 번 눌러 확정한다. 확정 직후 저장하며 2초 연습 연출은 거래/경험을 다시 만들지 않는다.
var _training_armed: String = ""
var _training_armed_until: int = 0
var _training_left: float = 0.0
var _training_target: String = ""
var _notebook_note: Label
var _juice: FeedbackScript
var _topping_positions: HFlowContainer
var _selected_topping_position: int = -1
var _flavor_bars: Dictionary = {}
var _flavor_labels: Dictionary = {}
var _experiment_note: Label
var _draft_change_note: Label
var _bowl_traits: Label
var _journal_target: JournalScript
var _journal_map: JournalScript
var _journal_toggle: Button
var _journal_target_id: String = "topping_stack"
var _journal_map_open: bool = false
var _journal_records_key: String = ""
var _journal_tested: Dictionary = {}
var _journal_new_titles: Array[String] = []
var _journal_new_record_id: int = 0
var _quick_taste_button: Button
var _quick_taste_notice: Label
var _ingredient_sections: Dictionary = {}
var _flavor_details: DetailsScript
var _experiment_cards: Array[DetailsScript] = []
var _experiment_buttons: Array[Button] = []
var _work_fx_phase: int = -1
var _topping_count: Label
var _topping_hint: Label
var _tab_navigation: GridContainer
var _navigation_details: DetailsScript
var _audio: AudioScript
var _audio_button: Button
var _direction_board: DetailsScript
var _direction_target: String = ""
var _direction_badge: Label
var _direction_actions: HBoxContainer
var _direction_status: Dictionary = {}
var _direction_buttons: Array[Button] = []
var _direction_records_key: String = ""
var _direction_tested: Array[String] = []
var _direction_new_titles: Array[String] = []
var _direction_new_record: int = 0
var _tab_links: Array[Button] = []
var _discovery_hints: Dictionary = {}
var _exploration_summary: Label
var _exploration_message: Label
var _exploration_box: VBoxContainer
var _exploration_buttons: Array[Button] = []
var _travel: TravelScript = TravelScript.new()
var _travel_art: TextureRect
var _travel_label: Label
var _travel_bar: ProgressBar
var _trip_notice: Label

## 시식 준비 작업(국물→면→시식). 진행 상태만 가지며, 끝났을 때 한 번만 state.taste()를 부른다.
var _work: WorkScript = WorkScript.new()
var _work_card: PanelContainer
var _work_title: Label
var _work_percent: Label
var _work_progress: ProgressBar
var _work_notice: Label
var _work_view: WorkViewScript
var _work_phase_labels: Array[Label] = []
var _work_cancel_button: Button
var _close_button: Button
var _new_button: Button
var _price_buttons: Array[Button] = []
var _autosave_label: Label
var _manual_save_button: Button
var _manual_save_result: Label

var _pending_delete_id: int = 0
var _fast: bool = false
var _stop_armed_until: int = 0
var _flash_text: String = ""
var _flash_until: int = 0
var _last_status_text: String = ""
var _last_save_message: String = ""
var _save_error_shown: bool = false
var _contest_summary: Label
var _contest_message: Label
var _contest_box: VBoxContainer
var _contest_left: float = 0.0
var _contest_buttons: Array[Button] = []


func _ready() -> void:
	theme = _build_theme()
	if data_location.is_empty():
		data_location = LocationScript.from_process()
	state = GameStateScript.new()
	saver = SaveServiceScript.new(str(data_location["dir"]))
	_build_ui()
	_juice = FeedbackScript.new()
	_juice.name = "ActionFeedback"
	add_child(_juice)
	_audio = AudioScript.new()
	_audio.name = "ActionAudio"
	add_child(_audio)
	_juice.action_committed.connect(func(): _audio.play("tap"))
	_load_save()
	_bowl_editor = BowlWorkbenchScript.new()
	_bowl_editor.visible = false
	_bowl_editor.action_requested.connect(_on_bowl_editor_action)
	add_child(_bowl_editor)
	_exploration_view = ExplorationWorkbenchScript.new()
	_exploration_view.visible = false
	_exploration_view.action_requested.connect(_on_exploration_view_action)
	add_child(_exploration_view)
	_growth_view = StaffGrowthScript.new()
	_growth_view.visible = false
	_growth_view.action_requested.connect(_on_growth_view_action)
	add_child(_growth_view)
	# 재개 시 이동 그림만 다시 보여 준다. 비용·경로·발견은 이미 불러온 도메인 상태를 사용한다.
	if state.exploration_active():
		_travel.start(str(state.expedition()["region"]))
	_refresh_all()
	# Observe existing and subsequently rebuilt buttons, including independent
	# journal components; per-factory effects previously missed those controls.
	_juice.watch(self)
	tabs.tab_changed.connect(_on_tab_changed)
	resized.connect(_apply_layout)
	_apply_layout()
	set_process(true)


func _notification(what: int) -> void:
	if state == null:
		return
	# 저장되는 것은 항상 "영업 전/시식 준비 전" 상태다: 진행 중 세션과 시식 준비는 자금/일차/기록을 바꾸지 않았고 편집도 잠겨 있다.
	# 닫기 요청이면 끝나지 않은 시식 준비를 먼저 버린다(완료로 처리하지 않고, 저장 파일에도 어떤 흔적도 남기지 않는다).
	# 앱이 잠깐 멈추는(PAUSED) 경우는 작업을 버리지 않고 확정된 상태만 저장한다.
	# 탐색은 이미 지불한 비용과 선택 단계가 확정된 상태이므로 닫기에서도 취소하지 않고 그대로 저장한다.
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_work.cancel()
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
		_persist()


func _process(delta: float) -> void:
	if state == null:
		return
	_sync_bowl_editor()
	var now: int = Time.get_ticks_msec()
	if _stop_armed_until != 0 and now > _stop_armed_until:
		_stop_armed_until = 0
		_refresh_nav()
	if _promote_armed_until != 0 and now > _promote_armed_until:
		_promote_armed_until = 0
		_refresh_growth()
	if _expansion_armed_until != 0 and now > _expansion_armed_until:
		_expansion_armed_until = 0
		_refresh_growth()
	if _training_armed_until != 0 and now > _training_armed_until:
		_training_armed_until = 0
		_training_armed = ""
		_refresh_growth()
	if _story_armed_until != 0 and now > _story_armed_until:
		_story_armed_until = 0
		_story_armed = ""
		_refresh_research()
	if _flash_until != 0 and now > _flash_until:
		_flash_until = 0
		_flash_text = ""
		_refresh_status()
	# 시식 준비는 화면 시간으로만 진행한다. 프레임이 튀어도 한 번에 0.1초까지만 반영해 연출이 건너뛰어지지 않는다.
	# (검사용으로 시간을 앞당기는 길은 advance_work()를 직접 부르는 것뿐이고, 실행 중인 게임에는 그런 설정이 없다.)
	if _work.is_running():
		advance_work(minf(delta, 0.1))
	if _travel.running():
		advance_travel(minf(delta, 0.1))
	if _contest_left > 0.0:
		advance_contest(minf(delta, 0.1))
	if _training_left > 0.0:
		advance_training(minf(delta, 0.1))
	if not state.service_active():
		return
	var session: SessionScript = state.active_session()
	# 프레임이 길게 튀어도 한 번에 0.1초(게임 3~7초)만 진행해 화면과 논리가 같이 움직이게 한다.
	session.advance(minf(delta, 0.1) * (SPEED_FAST if _fast else SPEED_NORMAL))
	if session.is_finished():
		_finish_service()
	elif session.state == SessionScript.STALLED:
		_abort_service("영업 진행에 문제가 생겨 정산하지 않고 닫았어요. 아무것도 바뀌지 않았어요.")
	else:
		_refresh_status()


# ---------- 테마/스타일 ----------

func _box(bg: Color, border: Color, border_w: int, radius: int, mx: float, my: float) -> StyleBoxFlat:
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(border_w)
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = mx
	sb.content_margin_right = mx
	sb.content_margin_top = my
	sb.content_margin_bottom = my
	return sb


func _build_theme() -> Theme:
	var t: Theme = Theme.new()
	var font: Font = load("res://assets/fonts/GowunDodum-Regular.ttf") as Font
	if font != null:
		t.default_font = font
	t.default_font_size = 18
	t.set_color("font_color", "Label", INK)

	# 도트 느낌의 각진 상자: 둥근 모서리 없이 굵은 갈색 테두리.
	t.set_stylebox("normal", "Button", _box(PAPER_LIGHT, WOOD_D, 3, 0, 10.0, 8.0))
	t.set_stylebox("hover", "Button", _box(PAPER_DARK, WOOD_D, 3, 0, 10.0, 8.0))
	t.set_stylebox("pressed", "Button", _box(TEAL, WOOD_D, 3, 0, 10.0, 8.0))
	t.set_stylebox("hover_pressed", "Button", _box(TEAL.darkened(0.1), WOOD_D, 3, 0, 10.0, 8.0))
	t.set_stylebox("disabled", "Button", _box(PAPER_DARK, PAPER_DARK, 3, 0, 10.0, 8.0))
	var focus: StyleBoxFlat = _box(Color(0, 0, 0, 0), VERMILION, 3, 0, 10.0, 8.0)
	focus.draw_center = false
	t.set_stylebox("focus", "Button", focus)
	t.set_color("font_color", "Button", INK)
	t.set_color("font_hover_color", "Button", INK)
	t.set_color("font_focus_color", "Button", INK)
	t.set_color("font_pressed_color", "Button", PAPER_LIGHT)
	t.set_color("font_hover_pressed_color", "Button", PAPER_LIGHT)
	t.set_color("font_disabled_color", "Button", MUTED)

	t.set_stylebox("normal", "LineEdit", _box(Color(1, 1, 1), WOOD_D, 3, 0, 10.0, 8.0))
	t.set_stylebox("focus", "LineEdit", _box(Color(1, 1, 1), VERMILION, 3, 0, 10.0, 8.0))
	t.set_stylebox("read_only", "LineEdit", _box(PAPER_DARK, LINE, 3, 0, 10.0, 8.0))
	t.set_color("font_color", "LineEdit", INK)
	t.set_color("font_uneditable_color", "LineEdit", MUTED)
	t.set_color("caret_color", "LineEdit", VERMILION)

	t.set_stylebox("panel", "PanelContainer", _box(PAPER_LIGHT, LINE, 2, 0, 12.0, 10.0))

	var tab_sel: StyleBoxFlat = _box(VERMILION, WOOD_D, 3, 0, 10.0, 10.0)
	var tab_un: StyleBoxFlat = _box(PAPER_DARK, LINE, 2, 0, 10.0, 10.0)
	var tab_hover: StyleBoxFlat = _box(PAPER_LIGHT, LINE, 2, 0, 10.0, 10.0)
	t.set_stylebox("tab_selected", "TabContainer", tab_sel)
	t.set_stylebox("tab_unselected", "TabContainer", tab_un)
	t.set_stylebox("tab_hovered", "TabContainer", tab_hover)
	t.set_stylebox("tab_focus", "TabContainer", tab_hover)
	t.set_stylebox("panel", "TabContainer", _box(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0, 0, 0.0, 6.0))
	t.set_color("font_selected_color", "TabContainer", PAPER_LIGHT)
	t.set_color("font_unselected_color", "TabContainer", INK)
	t.set_color("font_hovered_color", "TabContainer", INK)
	t.set_font_size("font_size", "TabContainer", 17)
	return t


# ---------- UI 구성 보조 ----------

func _label(text: String, font_size: int = 18, color: Color = INK) -> Label:
	var l: Label = Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	return l


func _plain_label(node_name: String, font_size: int, color: Color) -> Label:
	var l: Label = Label.new()
	l.name = node_name
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	return l


func _button(text: String, node_name: String) -> Button:
	var b: Button = Button.new()
	# 손가락을 버튼 위에서 밀어도 부모 ScrollContainer가 드래그를 받는다.
	# 실제 스크롤이 시작되면 Godot의 SCROLL_BEGIN이 누르기를 취소한다.
	b.mouse_filter = Control.MOUSE_FILTER_PASS
	b.name = node_name
	b.text = text
	b.custom_minimum_size = Vector2(0.0, MIN_TOUCH)
	return b


func _primary(b: Button) -> void:
	b.add_theme_stylebox_override("normal", _box(VERMILION, WOOD_D, 3, 0, 14.0, 10.0))
	b.add_theme_stylebox_override("hover", _box(VERMILION.lightened(0.1), WOOD_D, 3, 0, 14.0, 10.0))
	b.add_theme_stylebox_override("pressed", _box(VERMILION.darkened(0.2), WOOD_D, 3, 0, 14.0, 10.0))
	b.add_theme_stylebox_override("disabled", _box(PAPER_DARK, PAPER_DARK, 3, 0, 14.0, 10.0))
	b.add_theme_color_override("font_color", PAPER_LIGHT)
	b.add_theme_color_override("font_hover_color", PAPER_LIGHT)
	b.add_theme_color_override("font_pressed_color", PAPER_LIGHT)
	b.add_theme_font_size_override("font_size", 20)
	b.custom_minimum_size = Vector2(0.0, 56.0)


## 하단 바 버튼: 나무판 느낌.
func _wood_button(b: Button) -> void:
	b.add_theme_stylebox_override("normal", _box(WOOD_L, WOOD_D, 3, 0, 8.0, 6.0))
	b.add_theme_stylebox_override("hover", _box(WOOD_L.lightened(0.12), WOOD_D, 3, 0, 8.0, 6.0))
	b.add_theme_stylebox_override("pressed", _box(WOOD, WOOD_D, 3, 0, 8.0, 6.0))
	b.add_theme_color_override("font_color", CREAM)
	b.add_theme_color_override("font_hover_color", CREAM)
	b.add_theme_color_override("font_pressed_color", CREAM)
	b.add_theme_font_size_override("font_size", 17)
	b.custom_minimum_size = Vector2(0.0, 52.0)


func _card(node_name: String = "") -> PanelContainer:
	var p: PanelContainer = PanelContainer.new()
	# 카드의 빈 곳/테두리도 손가락 스크롤을 가로막지 않는다.
	p.mouse_filter = Control.MOUSE_FILTER_PASS
	if node_name != "":
		p.name = node_name
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return p


func _vbox(sep: int = 8) -> VBoxContainer:
	var v: VBoxContainer = VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return v


func _clear(container: Node) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()


func _anchor(c: Control, al: float, at: float, ar: float, ab: float, ol: float, ot: float, orr: float, ob: float) -> void:
	c.anchor_left = al
	c.anchor_top = at
	c.anchor_right = ar
	c.anchor_bottom = ab
	c.offset_left = ol
	c.offset_top = ot
	c.offset_right = orr
	c.offset_bottom = ob


func _make_tab(node_name: String, title: String) -> VBoxContainer:
	var sc: ScrollContainer = ScrollContainer.new()
	sc.name = node_name
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	# 0이면 손가락의 미세한 떨림까지 스크롤로 판단해 탭을 취소한다.
	sc.scroll_deadzone = 10
	tabs.add_child(sc)
	tabs.set_tab_title(tabs.get_tab_count() - 1, title)
	var margin: MarginContainer = MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_left", 2)
	margin.add_theme_constant_override("margin_right", 2)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_bottom", 16)
	sc.add_child(margin)
	var box: VBoxContainer = _vbox(12)
	margin.add_child(box)
	return box


static func _won(n: int) -> String:
	var digits: String = str(absi(n))
	var out: String = ""
	var count: int = 0
	for i in range(digits.length() - 1, -1, -1):
		out = digits[i] + out
		count += 1
		if count % 3 == 0 and i > 0:
			out = "," + out
	return ("-" if n < 0 else "") + out + "원"


## 단골 초상 텍스처(24x24 도트를 정수 배율로 확대, 캐시).
func _portrait_tex(customer_id: String, factor: int) -> ImageTexture:
	var key: String = "portrait|%s|%d" % [customer_id, factor]
	if not _icon_cache.has(key):
		_icon_cache[key] = ArtScript.scaled_tex(ArtScript.portrait_image(customer_id), factor)
	return _icon_cache[key] as ImageTexture


func _icon(id: String, factor: int) -> ImageTexture:
	var key: String = "%s|%d" % [id, factor]
	if not _icon_cache.has(key):
		_icon_cache[key] = ArtScript.scaled_tex(ArtScript.icon_image(id), factor)
	return _icon_cache[key] as ImageTexture


# ---------- UI 구성 ----------

func _build_ui() -> void:
	var backdrop: ColorRect = ColorRect.new()
	backdrop.name = "Backdrop"
	backdrop.color = BACKDROP
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backdrop)

	_shop = ShopViewScript.new()
	_shop.name = "ShopView"
	_shop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_shop)

	_build_home()
	_build_banner()
	_home.attach_warning(_banner)
	_build_result()
	_build_overlay()


func _build_home() -> void:
	_home = ShopHomeScript.new()
	add_child(_home)
	_hud = _home.hud
	_status = _home.status
	_nav = _home.nav
	_day_label = _home.day_label
	_wallet_label = _home.wallet_label
	_clock_label = _home.clock_label
	_progress = _home.progress
	_status_label = _home.status_label
	_note_label = _home.note_label
	_dev_button = _home.dev_button
	_start_button = _home.start_button
	_speed_button = _home.speed_button
	_dev_button.pressed.connect(_on_dev_pressed)
	_start_button.pressed.connect(_on_start_pressed)
	_speed_button.pressed.connect(_on_speed_pressed)
	_home.action_requested.connect(_on_home_action)


## Home routes call the same guarded controller as existing tabs. A detail page
## never starts service, settles money, changes a recipe or edits a save itself.
func _on_home_action(kind: String) -> void:
	if kind == "save":
		var result: Dictionary = manual_save()
		_home.set_save_result(str(result["message"]))
		_refresh_home()
		return
	if state.service_active() or _work.is_running() or _contest_left > 0.0 or _training_left > 0.0:
		return
	_home.hide_details()
	match kind:
		"menus": _open_overlay(TAB_SERVE)
		"explore": _open_overlay(TAB_EXPLORATION)
		"growth": _open_overlay(TAB_GROWTH)
		"report": _show_service_report()
		_: push_error("알 수 없는 가게 화면 동작: " + kind)
	_sync_bowl_editor()


func _build_banner() -> void:
	_banner = _card("SaveBanner")
	_banner.add_theme_stylebox_override("panel", _box(Color(0.98, 0.88, 0.82), VERMILION, 3, 0, 12.0, 8.0))
	_anchor(_banner, 0.0, 0.0, 1.0, 0.0, GAP, GAP + HUD_H + GAP, -GAP, GAP + HUD_H + GAP)
	var bb: VBoxContainer = _vbox(6)
	_banner.add_child(bb)
	_banner_label = _label("", 15, INK)
	_banner_label.name = "SaveBannerLabel"
	bb.add_child(_banner_label)
	_reset_button = _button("손상 파일 보관 후 새로 시작", "ResetSaveButton")
	_reset_button.pressed.connect(_on_reset_save)
	bb.add_child(_reset_button)
	_banner.visible = false
	add_child(_banner)


func _build_result() -> void:
	_service_result=ServiceResultScript.new()
	_service_result.visible=false
	_service_result.z_index=40
	_service_result.action_requested.connect(_on_service_result_action)
	_result_layer=_service_result
	add_child(_result_layer)
	_result_title=_service_result.get("_title") as Label
	_result_label=_service_result.get("_receipt") as Label
	_result_note=_service_result.get("_note") as Label


func _build_overlay() -> void:
	_overlay = Control.new()
	_overlay.name = "Overlay"
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.visible = false
	var dim: ColorRect = ColorRect.new()
	dim.name = "Dim"
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(dim)
	_drawer_margin = MarginContainer.new()
	_drawer_margin.name = "DrawerMargin"
	_drawer_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(_drawer_margin)
	var drawer: PanelContainer = _card("Drawer")
	drawer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	drawer.add_theme_stylebox_override("panel", _box(PAPER, WOOD_D, 4, 0, 10.0, 8.0))
	_drawer_margin.add_child(drawer)
	var col: VBoxContainer = _vbox(4)
	drawer.add_child(col)

	var header: HBoxContainer = HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	var title: Label = _label("메뉴 개발", 22, VERMILION)
	title.name = "DrawerTitle"
	header.add_child(title)
	var close: Button = _button("닫기", "CloseButton")
	close.custom_minimum_size = Vector2(88.0, MIN_TOUCH)
	close.pressed.connect(_on_close_pressed)
	_close_button = close
	header.add_child(close)
	col.add_child(header)

	_guide_label = _label("", 15, TEAL)
	_guide_label.name = "GuideLabel"
	col.add_child(_guide_label)
	_trip_notice = _label("탐색 중 · 마치거나 포기하면 메뉴 개발과 영업을 재개해요. 닫기는 진행을 저장해요.", 14, TEAL)
	_trip_notice.name = "ExpeditionLockNotice"
	_trip_notice.visible = false
	col.add_child(_trip_notice)
	_build_work_card(col)
	# 세로에서는 4+3개의 두 줄 탭을 사용한다. 작은 스크롤 화살표 대신 모든 탭이 44px 이상의 직접 터치 대상이다.
	_tab_navigation = GridContainer.new()
	_tab_navigation.name = "TabNavigation"
	_tab_navigation.add_theme_constant_override("h_separation", 4)
	_tab_navigation.add_theme_constant_override("v_separation", 4)
	# A visible chevron and whole-row hit target keep every old tab accessible
	# one deliberate depth below the food, instead of reserving two rows forever.
	_navigation_details = DetailsScript.new()
	_navigation_details.name = "NavigationMenu"
	_navigation_details.configure("작업 바꾸기", "개발 · 시식 · 노트 · 영업")
	_navigation_details.body.add_child(_tab_navigation)
	_guide_label.reparent(_navigation_details.body)
	col.add_child(_navigation_details)

	tabs = TabContainer.new()
	tabs.name = "MainTabs"
	tabs.tabs_visible = false
	tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(tabs)
	_build_lab(_make_tab("TabLab", "개발"))
	_build_feedback(_make_tab("TabFeedback", "시식"))
	_build_notebook(_make_tab("TabNotebook", "노트"))
	_build_serve(_make_tab("TabServe", "영업"))
	_build_research(_make_tab("TabResearch", "연구"))
	_build_growth(_make_tab("TabGrowth", "성장"))
	_build_exploration(_make_tab("TabExploration", "탐색"))
	_build_contests(_make_tab("TabContests", "대회"))
	var link_group: ButtonGroup = ButtonGroup.new()
	for i in tabs.get_tab_count():
		var link: Button = _button(tabs.get_tab_title(i), "TabLink_" + str(i))
		link.custom_minimum_size = Vector2(44.0, 48.0)
		link.add_theme_font_size_override("font_size", 16)
		link.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		link.toggle_mode = true
		link.button_group = link_group
		link.pressed.connect(_on_tab_link.bind(i))
		_tab_links.append(link)
		_tab_navigation.add_child(link)
	_sync_tab_links()
	_audio_button = _button("소리 켜짐", "AudioToggle")
	_audio_button.tooltip_text = "효과음 켜기/끄기 · 이번 실행 동안 유지돼요."
	_audio_button.pressed.connect(_toggle_audio)
	_navigation_details.body.add_child(_audio_button)

	_open_button = _button("영업하러 가기", "OverlayOpenButton")
	_primary(_open_button)
	_open_button.pressed.connect(_on_overlay_open_pressed)
	_open_button.custom_minimum_size = Vector2(0.0, MIN_TOUCH)
	_quick_taste_notice = _label("", 14, VERMILION)
	_quick_taste_notice.name = "QuickTasteNotice"
	_quick_taste_notice.visible = false
	col.add_child(_quick_taste_notice)
	# Keep the actual tasting action reachable while browsing deep ingredient
	# lists. Both entry points use the same transactional start_tasting guard.
	var actions := HBoxContainer.new()
	actions.name = "WorkbenchActions"
	actions.add_theme_constant_override("separation", 8)
	_open_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_open_button.add_theme_font_size_override("font_size", 16)
	actions.add_child(_open_button)
	_quick_taste_button = _button("시식 시작", "QuickTasteButton")
	_primary(_quick_taste_button)
	_quick_taste_button.custom_minimum_size = Vector2(0, MIN_TOUCH)
	_quick_taste_button.add_theme_font_size_override("font_size", 16)
	_quick_taste_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_quick_taste_button.pressed.connect(_on_quick_taste)
	actions.add_child(_quick_taste_button)
	col.add_child(actions)
	add_child(_overlay)


## 시식 준비 카드: 작업 중에만 보이는 서랍 맨 위 카드(탭 위라서 어느 탭에서나 보인다).
## 왼쪽은 솥/면/그릇 연출, 오른쪽은 단계 이름·진행 막대, 아래는 취소 버튼과 안내.
func _build_work_card(col: VBoxContainer) -> void:
	_work_card = _card("TastingWorkCard")
	_work_card.add_theme_stylebox_override("panel", _box(PAPER_LIGHT, VERMILION, 3, 0, 10.0, 6.0))
	_work_card.visible = false
	var wb: VBoxContainer = _vbox(4)
	_work_card.add_child(wb)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	wb.add_child(row)
	_work_view = WorkViewScript.new()
	_work_view.name = "TastingWorkView"
	_work_view.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_work_view)
	var side: VBoxContainer = _vbox(2)
	row.add_child(side)
	_work_title = _label("", 17, VERMILION)
	_work_title.name = "WorkTitle"
	side.add_child(_work_title)
	for ph in WorkScript.PHASES:
		var pd: Dictionary = ph
		var pl: Label = _label("", 14, MUTED)
		pl.name = "WorkPhase_" + str(pd["id"])
		pl.autowrap_mode = TextServer.AUTOWRAP_OFF
		_work_phase_labels.append(pl)
		side.add_child(pl)
	var bar_row: HBoxContainer = HBoxContainer.new()
	bar_row.add_theme_constant_override("separation", 8)
	side.add_child(bar_row)
	_work_progress = ProgressBar.new()
	_work_progress.name = "WorkProgress"
	_work_progress.show_percentage = false
	_work_progress.min_value = 0.0
	_work_progress.max_value = 100.0
	_work_progress.custom_minimum_size = Vector2(60.0, 16.0)
	_work_progress.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_work_progress.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_work_progress.add_theme_stylebox_override("background", _box(WOOD_D, INK, 2, 0, 0.0, 0.0))
	_work_progress.add_theme_stylebox_override("fill", _box(VERMILION, VERMILION, 0, 0, 0.0, 0.0))
	bar_row.add_child(_work_progress)
	_work_percent = _plain_label("WorkPercent", 15, INK)
	_work_percent.custom_minimum_size = Vector2(44.0, 0.0)
	_work_percent.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	bar_row.add_child(_work_percent)
	_work_notice = _label(WORK_NOTE, 13, MUTED)
	_work_notice.name = "WorkNotice"
	wb.add_child(_work_notice)
	_work_cancel_button = _button("준비 취소", "WorkCancelButton")
	_work_cancel_button.pressed.connect(_on_work_cancel)
	wb.add_child(_work_cancel_button)
	col.add_child(_work_card)


func _build_lab(box: VBoxContainer) -> void:
	var bowl_card: PanelContainer = _card("BowlCard")
	var hero := _vbox(6)
	bowl_card.add_child(hero)
	var headline := _label("나만의 한 그릇", 22, VERMILION)
	headline.name = "WorkbenchHeading"
	hero.add_child(headline)
	_bowl_rect = TextureRect.new()
	_bowl_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bowl_rect.name = "BowlPreview"
	_bowl_rect.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	_bowl_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_bowl_rect.custom_minimum_size = Vector2(192.0, 128.0)
	hero.add_child(_bowl_rect)
	_bowl_caption = _label("", 17, INK)
	_bowl_caption.name = "BowlCaption"
	hero.add_child(_bowl_caption)
	_bowl_traits = _label("", 14, TEAL)
	_bowl_traits.name = "BowlTraits"
	hero.add_child(_bowl_traits)
	_direction_badge = _label("재료를 골라 나만의 맛을 만들어요.", 15, TEAL)
	_direction_badge.name = "DirectionProgress"
	hero.add_child(_direction_badge)
	_direction_actions = HBoxContainer.new()
	_direction_actions.add_theme_constant_override("separation", 8)
	for spec in [["DirectionChoices", "재료 고르기", _direction_choices], ["DirectionSources", "재료 찾기", _find_recipe_materials]]:
		var button := _button(spec[1], spec[0])
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(spec[2])
		_direction_buttons.append(button)
		_direction_actions.add_child(button)
	hero.add_child(_direction_actions)
	box.add_child(bowl_card)
	_build_direction_board(box)
	_journal_target = JournalScript.new()
	_journal_target.name = "ResearchTargetBoard"
	_journal_target.book_requested.connect(_open_recipe_map)
	_journal_target.exploration_requested.connect(_find_recipe_materials)

	var name_card: PanelContainer = _card("NameCard")
	var nb: VBoxContainer = _vbox(6)
	name_card.add_child(nb)
	nb.add_child(_label("시제품 이름", 16, MUTED))
	_name_edit = ScrollableNameEdit.new()
	(_name_edit as ScrollableNameEdit).scroll_target = tabs.get_child(TAB_LAB) as ScrollContainer
	_name_edit.name = "RecipeNameEdit"
	_name_edit.mouse_filter = Control.MOUSE_FILTER_PASS
	_name_edit.custom_minimum_size = Vector2(0.0, MIN_TOUCH)
	_name_edit.max_length = Check.NAME_MAX
	_name_edit.placeholder_text = "예: 새벽 돈코츠"
	_name_edit.text_changed.connect(_on_name_changed)
	nb.add_child(_name_edit)
	_mode_label = _label("", 15, TEAL)
	_mode_label.name = "ModeLabel"
	nb.add_child(_mode_label)
	var new_button: Button = _button("새 레시피 시작", "NewRecipeButton")
	new_button.pressed.connect(_on_new_recipe)
	_new_button = new_button
	nb.add_child(new_button)

	for slot in Catalog.SLOTS:
		var sec := DetailsScript.new()
		sec.name = "Section_" + slot
		sec.configure(str(Catalog.SLOT_NAMES[slot]), "")
		_ingredient_sections[slot] = sec
		var sb: VBoxContainer = sec.body
		var flow: HFlowContainer = HFlowContainer.new()
		flow.name = "Flow_" + slot
		flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		flow.add_theme_constant_override("h_separation", 8)
		flow.add_theme_constant_override("v_separation", 8)
		# 토핑만 여러 개를 고를 수 있어 버튼 그룹(하나만 눌림)을 쓰지 않는다. 눌린 상태는 도메인 초안에서 읽어 맞춘다.
		var group: ButtonGroup = null
		if slot != Catalog.TOPPING_SLOT:
			group = ButtonGroup.new()
			_groups[slot] = group
		for item in Catalog.all_items(slot):
			var d: Dictionary = item
			flow.add_child(_make_option(slot, d, group))
		if slot == Catalog.TOPPING_SLOT:
			# 선택 개수/한도/해금 방법. 슬롯이 하나일 때는 "고르면 바뀌는" 단순 선택, 둘 이상일 때는 눌러서 넣고 빼는 다중 선택이다.
			_topping_count = _label("", 16, TEAL)
			_topping_count.name = "ToppingCount"
			sb.add_child(_topping_count)
			_topping_hint = _label("", 14, MUTED)
			_topping_hint.name = "ToppingHint"
			sb.add_child(_topping_hint)
			_topping_positions = HFlowContainer.new()
			_topping_positions.name = "ToppingPositions"
			_topping_positions.add_theme_constant_override("h_separation", 6)
			_topping_positions.add_theme_constant_override("v_separation", 6)
			sb.add_child(_topping_positions)
		sb.add_child(flow)
		var desc: Label = _label("", 15, INK)
		desc.name = "Desc_" + slot
		_desc_labels[slot] = desc
		sb.add_child(desc)
		var discovery_hint: Label = _label("", 14, TEAL)
		discovery_hint.name = "DiscoveryHint_" + slot
		_discovery_hints[slot] = discovery_hint
		sb.add_child(discovery_hint)
		box.add_child(sec)
		if ProcessRules.SLOTS.has(slot):
			sb.add_child(_process_card(slot))
	# The research ledger and full analytical bars remain available after actual
	# ingredients; they no longer displace the dish on the first mobile screen.
	box.add_child(_journal_target)
	_build_experiment_card(box)
	# Name/version management remains available after the cooking choices;
	# it no longer pushes those choices down the first screen.
	box.add_child(name_card)

	var price_card: PanelContainer = _card("PriceCard")
	var pb: VBoxContainer = _vbox(8)
	price_card.add_child(pb)
	pb.add_child(_label("판매 가격", 20, VERMILION))
	_price_label = _label("", 22, INK)
	_price_label.name = "PriceLabel"
	pb.add_child(_price_label)
	var price_row: HBoxContainer = HBoxContainer.new()
	price_row.add_theme_constant_override("separation", 8)
	for spec in [["PriceDown500", "-500", -500], ["PriceDown100", "-100", -100], ["PriceUp100", "+100", 100], ["PriceUp500", "+500", 500]]:
		var arr: Array = spec
		var pbtn: Button = _button(str(arr[1]), str(arr[0]))
		pbtn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		pbtn.pressed.connect(_on_price_step.bind(int(arr[2])))
		_price_buttons.append(pbtn)
		price_row.add_child(pbtn)
	pb.add_child(price_row)
	pb.add_child(_label("비싸게 팔면 마진은 늘지만 손님이 줄어요. 손님마다 기대 가격이 달라요.", 14, MUTED))
	box.add_child(price_card)

	var taste_card: PanelContainer = _card("TasteCard")
	var tb: VBoxContainer = _vbox(8)
	taste_card.add_child(tb)
	tb.add_child(_label("지금 구성", 20, VERMILION))
	_profile_label = _label("", 16, INK)
	_profile_label.name = "ProfileLabel"
	tb.add_child(_profile_label)
	_compat_label = _label("", 14, TEAL)
	_compat_label.name = "CompatLabel"
	tb.add_child(_compat_label)
	_taste_button = _button("시식하기", "TasteButton")
	_primary(_taste_button)
	_taste_button.pressed.connect(_on_taste)
	tb.add_child(_taste_button)
	_taste_message = _label("", 15, TEAL)
	_taste_message.name = "TasteMessage"
	tb.add_child(_taste_message)
	box.add_child(taste_card)


## Reuse disclosure affordances and real ingredient icons. Reading/selecting a
## direction is UI state only; stock is spent exclusively by existing tasting.
func _build_direction_board(box: VBoxContainer) -> void:
	_direction_board = DetailsScript.new()
	_direction_board.name = "RecipeDirections"
	box.add_child(_direction_board)
	_direction_board.body.add_child(_label("노트에 남은 실제 시식만 세어요. 정답 조합은 하나가 아니에요.", 14, MUTED))
	for definition in Directions.catalog():
		var id: String = definition["id"]
		var card := _card("DirectionCard_" + id)
		var col := _vbox(6)
		card.add_child(col)
		var title := _label(str(definition["title"]), 20, VERMILION)
		col.add_child(title)
		col.add_child(_label(str(definition["brief"]), 15, INK))
		var status := _label("", 14, TEAL)
		status.name = "DirectionStatus_" + id
		_direction_status[id] = status
		col.add_child(status)
		var select := _button("이 방향으로 실험", "DirectionSelect_" + id)
		select.icon = _icon(str(definition["ingredient"]), 2)
		select.pressed.connect(_select_direction.bind(id))
		_direction_buttons.append(select)
		col.add_child(select)
		_direction_board.body.add_child(card)


## Mute and navigation must never mutate recipe, wallet or save schema. They
## remain usable independently of the audio output backend on this device.
func _toggle_audio() -> void:
	_audio.set_muted(not _audio.muted)
	_audio_button.text = "소리 꺼짐" if _audio.muted else "소리 켜짐"


func _select_direction(id: String) -> void:
	if _work_blocked("실험 방향을 바꿀"):
		return
	if Directions.find(id).is_empty():
		_flash("알려진 실험 방향을 골라 주세요.")
		return
	_direction_target = id
	_direction_board.set_expanded(false)
	_refresh_directions()
	(tabs.get_child(TAB_LAB) as ScrollContainer).scroll_vertical = 0


func _direction_choices() -> void:
	var definition: Dictionary = Directions.find(_direction_target)
	if definition.is_empty():
		_flash("먼저 실험 방향을 골라 주세요.")
		return
	_open_experiment_choices(str(definition["slot"]))


## A result leads back to an open-ended choice, never an automatic recipe.
func _open_direction_board() -> void:
	if _work_blocked("다음 실험을 고를"):
		return
	tabs.current_tab = TAB_LAB
	_direction_board.set_expanded(true)
	await get_tree().process_frame
	(tabs.get_child(TAB_LAB) as ScrollContainer).ensure_control_visible(_direction_board.header_button)


## Cache only retained-record facts. Draft readiness and shortages always use
## current values, so a canceled work or a deleted witness cannot earn progress.
func _refresh_directions() -> void:
	var records: Array = state.records()
	var key: String = JSON.stringify(records)
	if key != _direction_records_key:
		_direction_tested = Directions.tested_ids(records)
		_direction_records_key = key
	var selected: Dictionary = Directions.find(_direction_target)
	_direction_board.configure("파밍으로 여는 세 가지 맛", "%d/3 시식 · %s" % [_direction_tested.size(), "방향 고르기" if selected.is_empty() else selected["title"]], _icon("topping_citrus_peel", 2))
	_direction_actions.visible = not selected.is_empty()
	_direction_badge.text = "재료를 골라 나만의 맛을 만들어요."
	for definition in Directions.catalog():
		var id: String = definition["id"]
		var assessment: Dictionary = Directions.assess(id, state.draft_config)
		var lines: Array[String] = []
		for condition in assessment["checks"]:
			lines.append(("✓ " if condition["met"] else "· ") + str(condition["text"]))
		var missing: Array[String] = []
		for ingredient in definition["requires"]:
			if not state.ingredient_unlocked(ingredient) or state.sample_stock(ingredient) < 1:
				missing.append(str(Catalog.find(ingredient)["name"]))
		var status: Label = _direction_status[id]
		status.text = "%s\n%s\n재료 출처 · %s%s" % ["노트에 시식 기록 있음" if _direction_tested.has(id) else "아직 시식 전", "\n".join(lines), definition["source"], "\n필요한 재료 · " + " / ".join(missing) if not missing.is_empty() else ""]
		if id == _direction_target:
			var matched: bool = bool(assessment["matched"])
			_direction_badge.text = "%s · %s\n%s" % [definition["title"], "시식으로 확인해 보세요" if matched else "맛을 다듬는 중", " · ".join(lines)]
			var stock: Dictionary = state.sample_check(state.draft_config)
			if stock["error"] != "":
				_direction_badge.text += "\n" + str(stock["error"])
	for button in _direction_buttons:
		button.disabled = _development_busy()


func _make_option(slot: String, item: Dictionary, group: ButtonGroup) -> Button:
	var id: String = str(item["id"])
	var b: Button = Button.new()
	# Ingredient toggles must also pass a swipe to their scroll parent.
	b.mouse_filter = Control.MOUSE_FILTER_PASS
	b.name = "Opt_" + id
	b.toggle_mode = true
	if group != null:
		b.button_group = group
	b.custom_minimum_size = Vector2(150.0, 64.0)
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.add_theme_font_size_override("font_size", 15)
	b.icon = _icon(id, 2)
	b.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.expand_icon = false
	var cost: int = int(item["cost"])
	var secs: int = int(item["seconds"])
	# Keep long ingredient names readable beside the icon; full names remain
	# in section headers, stock and details.
	b.text = "%s\n%s · %d초" % [str(item.get("short_name", item["name"])), _won(cost), secs]
	b.pressed.connect(_on_option_pressed.bind(slot, id))
	_buttons[id] = b
	return b


## Live flavor bars expose the real recipe profile, not a promised score.
func _build_experiment_card(box: VBoxContainer) -> void:
	var card := DetailsScript.new()
	card.name = "ExperimentCard"
	card.configure("맛 실험대", "")
	_flavor_details = card
	var col: VBoxContainer = card.body
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 8)
	flow.add_theme_constant_override("v_separation", 6)
	for axis in Catalog.AXES:
		var pair := _vbox(2)
		pair.custom_minimum_size.x = 128
		var title := _label("", 13, INK)
		title.name = "Flavor_" + axis
		_flavor_labels[axis] = title
		pair.add_child(title)
		var bar := ProgressBar.new()
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.name = "FlavorBar_" + axis
		bar.max_value = 10
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(128, 10)
		bar.add_theme_stylebox_override("background", _box(LINE, LINE, 0, 0, 0, 0))
		bar.add_theme_stylebox_override("fill", _box(TEAL, TEAL, 0, 0, 0, 0))
		_flavor_bars[axis] = bar
		pair.add_child(bar)
		flow.add_child(pair)
	col.add_child(flow)
	_experiment_note = _label("", 14, TEAL)
	_experiment_note.name = "ExperimentNote"
	col.add_child(_experiment_note)
	_draft_change_note = _label("", 14, INK)
	_draft_change_note.name = "DraftComparison"
	col.add_child(_draft_change_note)
	box.add_child(card)


func _build_feedback(box: VBoxContainer) -> void:
	_feedback_box = box


func _build_notebook(box: VBoxContainer) -> void:
	_journal_toggle = _button("연구 지도 펼치기", "RecipeMapToggle")
	_journal_toggle.pressed.connect(_toggle_recipe_map)
	box.add_child(_journal_toggle)
	_journal_map = JournalScript.new()
	_journal_map.mode = "map"
	_journal_map.name = "RecipeResearchMap"
	_journal_map.target_selected.connect(_select_recipe_target)
	_journal_map.visible = false
	box.add_child(_journal_map)
	_notebook_count = _label("", 18, INK)
	_notebook_count.name = "NotebookCount"
	box.add_child(_notebook_count)
	# Registered families and immutable revision history have independent limits.
	_notebook_note = _label("", 14, MUTED)
	_notebook_note.name = "NotebookNote"
	box.add_child(_notebook_note)
	_notebook_box = _vbox(10)
	_notebook_box.name = "NotebookList"
	box.add_child(_notebook_box)


## "영업" 탭: 오늘 영업 정보(읽기 전용). 영업은 가게 화면의 [영업 시작] 으로만 한다.
func _build_serve(box: VBoxContainer) -> void:
	var intro_card: PanelContainer = _card("ServeIntroCard")
	var ib: VBoxContainer = _vbox(6)
	intro_card.add_child(ib)
	ib.add_child(_label("오늘의 영업", 20, VERMILION))
	_last_report_button=ServiceResultScript.make_button("지난 영업 결과 보기","LastServiceReport","summary","chevron_right")
	_last_report_button.pressed.connect(_show_service_report)
	ib.add_child(_last_report_button)
	_serve_intro = _label("", 16, INK)
	_serve_intro.name = "ServeIntro"
	ib.add_child(_serve_intro)
	box.add_child(intro_card)

	var menu_card: PanelContainer = _card("ServeMenuCard")
	var mb: VBoxContainer = _vbox(6)
	menu_card.add_child(mb)
	mb.add_child(_label("영업할 메뉴", 20, VERMILION))
	_serve_menu = _label("", 16, INK)
	_serve_menu.name = "ServeMenu"
	mb.add_child(_serve_menu)
	_serve_forecast = _label("", 16, INK)
	_serve_forecast.name = "ServeForecast"
	mb.add_child(_serve_forecast)
	# Keep explanatory prose separate so a two-menu forecast remains readable
	# as a whole on portrait screens without shrinking its type or touch targets.
	var forecast_policy: Label = _label("수요는 가격·맛·조리 시간을 보고 올 것으로 예상한 손님이에요. 매장 앞에서 돌아간 손님과는 달라요. 실제 정산은 완료 주문 기준이에요.", 14, MUTED)
	forecast_policy.name = "ServeForecastPolicy"
	mb.add_child(forecast_policy)
	box.add_child(menu_card)
	var selling_card: PanelContainer = _card("SellingCard")
	_selling_box = _vbox(7)
	selling_card.add_child(_selling_box)
	box.add_child(selling_card)
	_selling_message = _label("", 15, TEAL)
	_selling_message.name = "SellingMessage"
	box.add_child(_selling_message)

	var report_card: PanelContainer = _card("ReportCard")
	var rb: VBoxContainer = _vbox(6)
	report_card.add_child(rb)
	rb.add_child(_label("지난 영업 결과", 20, VERMILION))
	_report_label = _label("", 16, INK)
	_report_label.name = "ReportLabel"
	rb.add_child(_report_label)
	box.add_child(report_card)

	# 저장 상태/개발용 저장 위치는 항상 보이는 바닥글이 아니라 이 탭 맨 아래에 둔다(다른 탭의 화면 공간을 쓰지 않음).
	var info_card: PanelContainer = _card("SaveInfoCard")
	var sb: VBoxContainer = _vbox(4)
	info_card.add_child(sb)
	_load_label = _label("", 13, MUTED)
	_load_label.name = "LoadStatusLabel"
	sb.add_child(_load_label)
	_save_label = _label("", 13, MUTED)
	_save_label.name = "SaveStatusLabel"
	sb.add_child(_save_label)
	_autosave_label = _label(AUTOSAVE_NOTE, 13, MUTED)
	_autosave_label.name = "AutoSaveInfo"
	sb.add_child(_autosave_label)
	_manual_save_button = _button("지금 저장", "ManualSaveButton")
	_manual_save_button.custom_minimum_size = Vector2(0.0, 44.0)
	_manual_save_button.pressed.connect(_on_manual_save_pressed)
	sb.add_child(_manual_save_button)
	_manual_save_result = _label("", 13, MUTED)
	_manual_save_result.name = "ManualSaveResult"
	sb.add_child(_manual_save_result)
	_dev_label = _label("", 12, MUTED)
	_dev_label.name = "DevSaveLabel"
	_dev_label.visible = false
	sb.add_child(_dev_label)
	box.add_child(info_card)


## "연구" 탭: 단골 세 분의 의뢰 여섯 개. 위쪽은 진행 요약/제출 대상/결과 메시지(고정), 아래는 의뢰 카드(갱신 때마다 다시 만든다).
func _build_research(box: VBoxContainer) -> void:
	var modes: HBoxContainer = HBoxContainer.new()
	for item in [["연구 의뢰", false], ["단골 이야기", true]]:
		# 기존 연구를 기본으로 두고 같은 탭 안에서 전환한다. 새 탭으로 터치 영역을 더 쪼개지 않는다.
		var text: String = "연구 의뢰" if not bool(item[1]) else str(item[0])
		var mode: Button = _button(text, "ResearchModeStories" if bool(item[1]) else "ResearchModeResearch")
		mode.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		mode.pressed.connect(_on_research_mode.bind(bool(item[1])))
		modes.add_child(mode)
	box.add_child(modes)
	var sum_card: PanelContainer = _card("ResearchSummaryCard")
	var sb: VBoxContainer = _vbox(6)
	sum_card.add_child(sb)
	sb.add_child(_label("라멘 연구", 20, VERMILION))
	_research_summary = _label("", 16, INK)
	_research_summary.name = "ResearchSummary"
	sb.add_child(_research_summary)
	_research_target = _label("", 15, TEAL)
	_research_target.name = "ResearchTarget"
	sb.add_child(_research_target)
	_research_message = _label("", 15, TEAL)
	_research_message.name = "ResearchMessage"
	sb.add_child(_research_message)
	box.add_child(sum_card)
	_research_box = _vbox(12)
	_research_box.name = "ResearchList"
	box.add_child(_research_box)


## "성장" 탭: 가게 등급 심사 / 유료 확장 / 보조 직원 고용. 화면은 GameState 의 review 결과를 보여 줄 뿐 판단하지 않는다.
func _build_growth(box: VBoxContainer) -> void:
	var sum_card: PanelContainer = _card("GrowthSummaryCard")
	var sb: VBoxContainer = _vbox(6)
	sum_card.add_child(sb)
	sb.add_child(_label("가게 성장", 20, VERMILION))
	_growth_summary = _label("", 17, INK)
	_growth_summary.name = "GrowthSummary"
	sb.add_child(_growth_summary)
	_growth_capacity = _label("", 15, INK)
	_growth_capacity.name = "GrowthCapacity"
	sb.add_child(_growth_capacity)
	_growth_message = _label("", 15, TEAL)
	_growth_message.name = "GrowthMessage"
	sb.add_child(_growth_message)
	box.add_child(sum_card)
	_growth_box = _vbox(12)
	_growth_box.name = "GrowthList"
	box.add_child(_growth_box)


# ---------- 레이아웃 ----------

func _is_portrait() -> bool:
	return size.x < WIDE_BREAKPOINT


## The shop keeps its original integer-scale scene; home chrome occupies a
## bounded bottom row on desktop or two short rows on portrait/compact screens.
func _place_status() -> void:
	if _home == null or _shop == null:
		return
	_home.layout_home()
	_shop.inset_top = _home.top_inset
	_shop.inset_bottom = _home.bottom_inset


func _apply_layout() -> void:
	var portrait: bool = _is_portrait()
	_tab_navigation.columns = 4 if portrait else 8
	_place_status()
	var side: int = 6 if portrait else maxi(6, int((size.x - 820.0) * 0.5))
	_drawer_margin.add_theme_constant_override("margin_left", side)
	_drawer_margin.add_theme_constant_override("margin_right", side)
	_drawer_margin.add_theme_constant_override("margin_top", int(GAP + HUD_H + 4.0))
	_drawer_margin.add_theme_constant_override("margin_bottom", int(GAP + NAV_H + 8.0))
	_refresh_status()


# ---------- 저장/불러오기 ----------

func _load_save() -> void:
	if not bool(data_location["ok"]):
		save_locked = true
		_load_label.text = "저장 위치를 사용할 수 없어요: " + str(data_location["error"])
		_save_label.text = "저장이 꺼져 있어요."
		_show_banner(str(data_location["error"]), false)
		return
	if bool(data_location["is_dev"]):
		_dev_label.visible = true
		_dev_label.text = "개발용 저장 위치: " + str(data_location["dir"])
	var res: Dictionary = saver.load_into(state)
	var status: String = str(res["status"])
	match status:
		"ok":
			_load_label.text = "불러오기: 저장된 연구소를 열었어요 · 기록 %d개 · %d일차" % [state.record_count(), state.day]
			_save_label.text = "자동 저장 켜짐 · 이번 실행에서는 아직 저장하지 않았어요."
		"missing":
			_load_label.text = "불러오기: 첫 방문이에요. 새 연구소를 열었어요."
			_persist()
		"corrupt", "unsupported", "io_error":
			save_locked = true
			_load_label.text = "불러오기 실패: " + str(res["message"])
			_save_label.text = "저장이 꺼져 있어요."
			_show_banner(str(res["message"]) + " 기존 파일은 지우거나 덮어쓰지 않았어요.", status != "io_error")


func _show_banner(message: String, can_reset: bool) -> void:
	_banner.visible = true
	_banner_label.text = message
	_reset_button.visible = can_reset
	_refresh_home()


## 저장하고 실제 결과를 돌려준다(true = 파일에 기록됨). 실패/저장 꺼짐이면 서랍이 닫혀 있어도 보이는
## 가게 화면의 배너로 알리고, 마지막 저장 결과를 _last_save_message 에 남겨 호출자가 거짓 성공을 말하지 않게 한다.
## source 는 "자동"(행동 경계의 자동 저장) 또는 "직접"(수동 저장 버튼). 마지막 저장 상태 글에 어느 쪽이었는지와 시각을 남긴다.
## 저장되는 것은 항상 확정된 상태뿐이다(진행 중인 영업/시식 준비는 상태에 들어 있지 않다).
func _persist(source: String = "자동") -> bool:
	if save_locked:
		_last_save_message = "저장이 꺼져 있어요: 기존 저장 파일을 보호하는 중이에요."
		_save_label.text = _last_save_message
		return false
	var res: Dictionary = saver.save_state(state)
	if bool(res["ok"]):
		_save_label.text = "%s 저장됨 · 기록 %d개 · %d일차 · %s" % [source, state.record_count(), state.day, Time.get_time_string_from_system()]
		_last_save_message = ""
		if _save_error_shown:
			_save_error_shown = false
			_banner.visible = false
		_refresh_home()
		return true
	_last_save_message = str(res["message"])
	_save_label.text = "저장 실패: " + _last_save_message
	_save_error_shown = true
	_show_banner("저장하지 못했어요: " + _last_save_message + " 지금 진행은 이 게임 안에만 남아 있고, 닫으면 사라질 수 있어요.", false)
	return false


## 수동 저장. 영업 중이거나 시식 준비 중이면 거부한다(끝나지 않은 일은 저장하지 않는다는 기존 정책과 같다).
## 저장 꺼짐(손상 파일 보호 중)이면 파일을 건드리지 않고 이유를 알린다. 결과는 실제 저장 결과 그대로이며 거짓 성공을 말하지 않는다.
func manual_save() -> Dictionary:
	var ok: bool = false
	var message: String = ""
	if state.service_active():
		message = "영업 중에는 직접 저장할 수 없어요. 영업을 끝까지 마쳐 정산되면 자동으로 저장돼요."
	elif _work.is_running():
		message = "시식 준비 중에는 직접 저장할 수 없어요. 준비가 끝나 기록되면 자동으로 저장돼요."
	elif save_locked:
		_persist("직접")
		message = "저장하지 못했어요: %s 저장 파일은 지우거나 덮어쓰지 않았어요." % _last_save_message
	elif _persist("직접"):
		ok = true
		message = "직접 저장했어요 · 기록 %d개 · %d일차 · %s" % [state.record_count(), state.day, Time.get_time_string_from_system()]
	else:
		message = "저장하지 못했어요: %s" % _last_save_message
	_manual_save_result.text = message
	_manual_save_result.add_theme_color_override("font_color", TEAL if ok else VERMILION)
	return {"ok": ok, "message": message}


func _on_manual_save_pressed() -> void:
	manual_save()


func _on_reset_save() -> void:
	# 시식 준비 중에는 상태 교체를 막는다(교체되면 준비 중인 스냅샷과 어긋난다).
	if _work_blocked("손상 파일을 정리"):
		return
	var res: Dictionary = saver.archive_corrupt()
	if not bool(res["ok"]):
		_banner_label.text = str(res["message"])
		return
	save_locked = false
	_home.set_save_result("")
	state = GameStateScript.new()
	_shop.set_session(null)
	_banner.visible = false
	_load_label.text = "불러오기: 문제가 있던 저장은 따로 보관하고 새로 시작했어요."
	_persist()
	_refresh_all()


## 안내 문구는 개발·노트 탭에서만 보인다(시식 카드가 쓸 세로 공간을 확보).
func _sync_guide_visibility() -> void:
	_guide_label.visible = tabs.current_tab == TAB_LAB or tabs.current_tab == TAB_NOTEBOOK
	if is_instance_valid(_quick_taste_button):
		_quick_taste_button.visible = tabs.current_tab == TAB_LAB
		_quick_taste_notice.visible = tabs.current_tab == TAB_LAB and _quick_taste_notice.text != ""


func _on_tab_changed(_index: int) -> void:
	_sync_tab_links()
	_navigation_details.set_expanded(false)
	_sync_guide_visibility()
	_pending_delete_id = 0
	_promote_armed_until = 0
	# 탭 이동은 읽기 전용 보기이므로 시식 준비 중에도 허용하지만, 준비 중에는 자동 저장하지 않는다(확정된 변화가 없다).
	if not _work.is_running():
		_persist()
	_refresh_notebook()
	_refresh_growth()
	_refresh_exploration()
	_refresh_contests()


func _on_tab_link(index: int) -> void:
	tabs.current_tab = index
	_navigation_details.set_expanded(false)


func _sync_tab_links() -> void:
	for i in _tab_links.size():
		_tab_links[i].set_pressed_no_signal(i == tabs.current_tab)
	if _navigation_details != null:
		_navigation_details.configure("%s · 다른 작업" % tabs.get_tab_title(tabs.current_tab), "펼쳐서 이동", _icon("broth_chicken", 2))


# ---------- 가게 화면 입력 ----------

func _flash(text: String) -> void:
	_flash_text = text
	_flash_until = Time.get_ticks_msec() + FLASH_MS
	_refresh_status()


func _on_dev_pressed() -> void:
	if state.service_active():
		_flash("영업 중에는 메뉴를 바꿀 수 없어요. 영업이 끝난 뒤 개발하세요.")
		return
	# 시식 준비 중에는 서랍을 닫지 못한다(보이지 않는 곳에서 끝나 기록이 생기는 일을 막는다). 먼저 [준비 취소]를 누른다.
	if _overlay.visible and _work_blocked("서랍을 닫", true):
		return
	if _overlay.visible:
		_close_overlay()
	else:
		_open_overlay(TAB_LAB)


func _open_overlay(tab: int) -> void:
	if state.service_active():
		return
	_pending_delete_id = 0
	_refresh_all()
	_overlay.visible = true
	if tab >= 0:
		tabs.current_tab = tab
	_refresh_guide()
	_sync_guide_visibility()
	_sync_bowl_editor()


func _close_overlay() -> void:
	_overlay.visible = false
	_pending_delete_id = 0
	_persist()
	_refresh_status()
	_refresh_nav()
	# Native feature views are root siblings of the legacy drawer. Closing must
	# release their GUI input immediately, including paused/deterministic flows.
	_sync_bowl_editor()


func _on_close_pressed() -> void:
	if _work_blocked("서랍을 닫", true):
		return
	_close_overlay()


func _on_overlay_open_pressed() -> void:
	if state.exploration_active():
		_close_overlay()
		return
	if _work_blocked("영업을 시작"):
		return
	_close_overlay()
	if not state.selling_records().is_empty():
		_start_service()


func _on_start_pressed() -> void:
	if state.exploration_active():
		_open_overlay(TAB_EXPLORATION)
		return
	# 시식 준비 중에는 영업 시작/서랍 열기 모두 거부한다. 영업 중 중단 흐름과는 겹치지 않는다(둘은 동시에 있을 수 없다).
	if _work_blocked("영업을 시작"):
		return
	if state.service_active():
		# 실수로 누르기 쉬운 위치라 두 번 눌러야 중단된다.
		var now: int = Time.get_ticks_msec()
		if _stop_armed_until != 0 and now <= _stop_armed_until:
			_abort_service("영업을 중단했어요. 정산하지 않았고 자금·일차·기록은 그대로예요.")
		else:
			_stop_armed_until = now + STOP_CONFIRM_MS
			_refresh_nav()
		return
	if state.selling_records().is_empty():
		_open_overlay(TAB_LAB if state.record_count() == 0 else TAB_NOTEBOOK)
		return
	_start_service()


func _start_service() -> void:
	if _work_blocked("영업을 시작"):
		return
	var res: Dictionary = state.begin_service()
	if not bool(res["ok"]):
		_flash(str(res["message"]))
		return
	_fast = false
	_stop_armed_until = 0
	_flash_text = ""
	_flash_until = 0
	_shop.set_session(state.active_session())
	_service_sold_snapshot=state.selling_records().duplicate(true)
	_refresh_all()


func _abort_service(message: String) -> void:
	state.cancel_service()
	_service_sold_snapshot.clear()
	_shop.set_session(null)
	_stop_armed_until = 0
	_fast = false
	_refresh_all()
	_flash(message)


func _on_speed_pressed() -> void:
	_fast = not _fast
	_refresh_nav()


## 세션이 끝나면 정산을 딱 한 번 호출한다. 성공하면 결과 창을 띄우고 저장한다.
func _finish_service() -> void:
	var res: Dictionary = state.settle_service()
	_shop.set_session(null)
	_fast = false
	_stop_armed_until = 0
	_flash_text = ""
	_flash_until = 0
	if not bool(res["ok"]):
		state.cancel_service()
		_refresh_all()
		_flash("정산하지 못했어요: " + str(res["message"]))
		return
	var saved: bool = _persist()
	var report: Dictionary = state.last_report
	_result_title.text = "%d일차 영업 결과" % int(report["day"])
	_result_label.text = _report_text(report)
	var save_line: String = "영업이 끝나 저장했어요."
	if not saved:
		# 정산은 메모리에 반영됐지만 파일에는 없다. 거짓으로 저장됐다고 말하지 않는다.
		save_line = "⚠ 저장하지 못했어요: %s\n정산은 지금 실행 중인 게임에만 반영돼 있고, 지금 닫으면 이 영업은 사라질 수 있어요." % _last_save_message
	var experience: String = ""
	if not state.hired_staff().is_empty() and int(report["units"]) > 0:
		experience = "\n함께 일한 보조 직원: 각자 실무 +1일 · 경험 +%d그릇" % int(report["units"])
	_result_note.text = "평균 만족도 %.1f / 5 · 매장 앞에서 돌아간 손님 %d명%s\n%s" % [float(res["avg_stars"]), int(res["turned_away"]), experience, save_line]
	_result_note.add_theme_color_override("font_color", TEAL if saved else VERMILION)
	_service_result_key=JSON.stringify(report,"",true)
	_service_result_context={"sold":_service_sold_snapshot.duplicate(true),"avg_stars":res["avg_stars"],"turned_away":res["turned_away"],"experience":experience.strip_edges()}
	_service_sold_snapshot.clear()
	_show_service_report()
	_service_result.play_reveal()
	_refresh_all()


func _show_service_report() -> void:
	if state.last_report.is_empty() or state.service_active() or _development_busy():
		return
	_home.hide_details()
	var context: Dictionary=_service_result_context.duplicate(true) if _service_result_key==JSON.stringify(state.last_report,"",true) else {}
	context["saved"]=_last_save_message=="" and not save_locked
	context["save_note"]="영업 정산을 저장했어요." if bool(context["saved"]) else "저장하지 못했어요: %s\n정산은 지금 실행 중인 게임에만 반영돼 있고, 지금 닫으면 이 영업은 사라질 수 있어요." % _last_save_message
	if context.has("avg_stars"):
		var reaction: String="평균 만족도 %.1f / 5" % float(context["avg_stars"]) if int(state.last_report["units"])>0 else "완료 주문 없음 · 만족도 집계 없음"
		context["save_note"]="%s · 매장 앞에서 돌아간 손님 %d명\n%s\n%s" % [reaction,int(context["turned_away"]),str(context.get("experience","")),context["save_note"]]
	_service_result.present(state.last_report,context,_report_text(state.last_report))
	_result_layer.visible=true
	# Godot GUI picking follows sibling order, independently of visual z_index.
	# A report opened above the drawer must also receive its actual pointer input.
	move_child(_result_layer,get_child_count()-1)


func _on_service_result_action(kind: String) -> void:
	_on_result_ok()
	if kind=="develop":
		_open_overlay(TAB_LAB)
		_sync_bowl_editor()


func _on_result_ok() -> void:
	_result_layer.visible = false
	_refresh_status()


# ---------- 개발 서랍 입력 ----------

## 시식 준비 중 잠금 판정. 버튼을 꺼 두는 것과 별개로 모든 상태 변경 핸들러가 맨 앞에서 이 함수를 불러 막는다
## (버튼 비활성만 믿으면 직접 호출/단축 입력으로 초안이 시작 때 복사한 스냅샷과 어긋날 수 있다). 막았으면 true.
func _work_blocked(action: String, allow_trip: bool = false) -> bool:
	if _training_left > 0.0 and not allow_trip:
		_flash("훈련 결과를 정리하는 중에는 %s 수 없어요. 잠시 기다려 주세요." % action)
		return true
	if _contest_left > 0.0 and not allow_trip:
		_flash("심사 결과를 정리하는 중에는 %s 수 없어요. 잠시 기다려 주세요." % action)
		return true
	if _work.is_running():
		_work_reject("시식 준비 중에는 %s 수 없어요. 끝나길 기다리거나 [준비 취소]를 누르세요." % action)
		return true
	if not allow_trip and state.exploration_active():
		_flash("탐색 중에는 %s 수 없어요. [탐색]에서 마치거나 포기하세요." % action)
		return true
	return false


func _work_reject(message: String) -> Dictionary:
	_work_notice.text = message
	_flash(message)
	return {"ok": false, "message": message}


## 공법도 다른 초안 편집과 같은 잠금을 통과한다. 선택은 무료이고 시제품 완료 때 실제 원가를 한 번 낸다.
func _on_process_choice(slot: String, id: String) -> void:
	if _work_blocked("제조 공법을 바꿀"):
		return
	var result: Dictionary = state.set_draft_process(slot, id)
	_taste_message.text = str(result["message"])
	_taste_message.add_theme_color_override("font_color", TEAL if bool(result["ok"]) else VERMILION)
	_refresh_lab()


func _process_card(slot: String) -> PanelContainer:
	var card: PanelContainer = _card("ProcessSection_" + slot)
	var box: VBoxContainer = _vbox(6)
	card.add_child(box)
	box.add_child(_label("육수 추출 공법" if slot == "broth" else "면 반죽과 숙성", 18, VERMILION))
	var flow: HFlowContainer = HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 6)
	flow.add_theme_constant_override("v_separation", 6)
	box.add_child(flow)
	for id in ProcessRules.ids(slot):
		var definition: Dictionary = ProcessRules.method(slot, id)
		var button: Button = _button(str(definition["name"]) + "\n등급 %d부터" % definition["rank"], "ProcessOpt_" + slot + "_" + id)
		button.custom_minimum_size = Vector2(98, 54)
		button.toggle_mode = true
		button.pressed.connect(_on_process_choice.bind(slot, id))
		_process_buttons[slot + ":" + id] = button
		flow.add_child(button)
	var info: Label = _label("", 14, INK)
	info.name = "ProcessInfo_" + slot
	box.add_child(info)
	_process_infos[slot] = info
	return card


func _refresh_process_controls() -> void:
	var chosen: Dictionary = state.draft_config.get("process", {})
	for slot in ProcessRules.SLOTS:
		var current: String = ProcessRules.selected(chosen, slot)
		for id in ProcessRules.ids(slot):
			var button: Button = _process_buttons[slot + ":" + id]
			button.set_pressed_no_signal(current == id)
		var definition: Dictionary = ProcessRules.method(slot, current)
		var axes: Dictionary = {}
		for axis in Catalog.AXES:
			if int(definition["axes"][axis]) != 0:
				axes[axis] = definition["axes"][axis]
		var label: Label = _process_infos[slot]
		label.text = "%s — %s\n%s\n그릇당 추가 원가 %s · 영업 조리 %+d초\n시제품 제조 연출 +%.1f초 · 고급 공법은 등급2부터 열려요." % [definition["name"], definition["desc"], Catalog.axes_text({"axes": axes}), _won(int(definition["cost"])), definition["seconds"], definition["work_extra"]]


func _on_name_changed(text: String) -> void:
	if _work_blocked("이름을 바꿀"):
		# 입력창에 이미 들어간 글자는 되돌린다(프로그램으로 바꾼 text 는 text_changed 를 다시 부르지 않는다).
		_name_edit.text = state.draft_name
		return
	var res: Dictionary = state.set_draft_name(text)
	if not bool(res["ok"]):
		_taste_message.text = str(res["message"])


func _on_new_recipe() -> void:
	if _work_blocked("새 레시피를 시작할"):
		return
	_pending_delete_id = 0
	state.start_new_recipe()
	_selected_topping_position = -1
	_taste_message.text = "새 레시피를 시작했어요. 이름을 정하고 시식해 보세요."
	_persist()
	_refresh_all()


func _on_option_pressed(slot: String, id: String, source_point: Vector2 = Vector2.INF) -> void:
	if _work_blocked("재료를 바꿀"):
		_refresh_lab()
		return
	_pending_delete_id = 0
	var previous := state.draft_config.duplicate(true)
	var point := (_buttons[id] as Button).get_global_rect().get_center() if source_point == Vector2.INF else source_point
	var result: Dictionary
	if slot == Catalog.TOPPING_SLOT:
		var portions: Array = Catalog.toppings_of(state.draft_config)
		if _selected_topping_position >= 0 and _selected_topping_position < portions.size():
			portions[_selected_topping_position] = id
		else:
			portions.append(id)
		result = state.set_draft_toppings(portions)
		if result["ok"]:
			_selected_topping_position = -1
	else:
		result = state.set_draft_choice(slot, id)
	if not result["ok"]:
		_taste_message.text = str(result["message"])
		_taste_message.add_theme_color_override("font_color", VERMILION)
		_juice.burst(point, VERMILION, str(result["message"]).left(22))
	else:
		_ingredient_reaction(previous, id, point)
	_refresh_lab()


func _select_topping_position(index: int) -> void:
	if _work_blocked("토핑 칸을 고를"):
		return
	_selected_topping_position = -1 if _selected_topping_position == index else index
	_refresh_lab()


func _remove_topping_position(index: int) -> void:
	if _work_blocked("토핑을 뺄"):
		return
	var portions: Array = Catalog.toppings_of(state.draft_config)
	if index < 0 or index >= portions.size():
		return
	portions.remove_at(index)
	var result := state.set_draft_toppings(portions)
	if not result["ok"]:
		_taste_message.text = result["message"]
		_juice.burst(get_viewport_rect().size * Vector2(0.5, 0.65), VERMILION, "토핑은 최소 1개")
	_selected_topping_position = -1
	_refresh_lab()


func _ingredient_reaction(previous: Dictionary, id: String, point: Vector2) -> void:
	_audio.play("ingredient")
	var old_profile := Evaluator.build_profile(previous)
	var profile := Evaluator.build_profile(state.draft_config)
	var change: String = "재료 교체"
	var largest: int = 0
	for axis in Catalog.AXES:
		var delta: int = int(profile[axis]) - int(old_profile[axis])
		if absi(delta) > absi(largest):
			largest = delta
			change = "%s %+d" % [Catalog.AXIS_NAMES[axis], delta]
	var before: Array = Evaluator.applied_compat(previous)
	for rule in Evaluator.applied_compat(state.draft_config):
		if not before.has(rule):
			change = "궁합 발견!" if int(rule["score"]) > 0 else "엇갈리는 맛!"
			break
	_juice.burst(point, TEAL, change, _icon(id, 2), true)
	_taste_message.text = "%s · %s · 원가 %+d원" % [Catalog.find(id)["name"], change, Evaluator.unit_cost(state.draft_config) - Evaluator.unit_cost(previous)]
	_taste_message.add_theme_color_override("font_color", TEAL)


func _on_price_step(delta: int) -> void:
	if _work_blocked("가격을 바꿀"):
		return
	var current: int = int(state.draft_config["price"])
	var target: int = clampi(current + delta, Catalog.PRICE_MIN, Catalog.PRICE_MAX)
	var res: Dictionary = state.set_draft_price(target)
	if not bool(res["ok"]):
		_taste_message.text = str(res["message"])
	_refresh_lab()


func _on_taste() -> void:
	start_tasting()


func _on_quick_taste() -> void:
	var result: Dictionary = start_tasting()
	# The original refusal label may be far down the ingredient list. Keep the
	# actual full refusal next to the fixed action, not only in a clipped burst.
	_quick_taste_notice.text = "" if result["ok"] else str(result["message"])
	_quick_taste_notice.visible = not bool(result["ok"])


## 시식 시작: 곧바로 기록하지 않고 약 4초짜리 준비 작업(국물→면→시식)을 시작한다.
## 이 시점에는 자금/기록/보상이 전혀 바뀌지 않는다(도메인 taste()는 완료 때 정확히 한 번만 부른다).
## 거부 사유: 이미 준비 중(중복 시작), 영업 중, 또는 시식해도 도메인이 거부할 초안(이름/중복 구성/자금 등 — 복제본으로 미리 확인한다).
func start_tasting() -> Dictionary:
	_pending_delete_id = 0
	if _training_left > 0.0:
		return _taste_refused("훈련 결과를 정리한 뒤 시식할 수 있어요.")
	if _contest_left > 0.0:
		return _taste_refused("심사 결과를 정리한 뒤 시식할 수 있어요.")
	if _work.is_running():
		return _work_reject("이미 시식을 준비하고 있어요. 하나씩만 준비할 수 있어요.")
	if state.service_active():
		return _taste_refused("영업 중에는 시식할 수 없어요. 영업이 끝난 뒤 시도하세요.")
	# 미리 확인(드라이런): 저장용 직렬화로 복제한 상태에서 taste()를 해 본다. 원본 state 는 전혀 건드리지 않는다.
	# 복제에 실패하면 상태가 저장 규칙과 어긋난 것이므로 시작하지 않는다(재료비/기록 변화 없음).
	var probe: GameStateScript = GameStateScript.new()
	var probe_err: String = probe.load_from_dict(state.to_dict())
	if probe_err != "":
		return _taste_refused("시식 전 상태 확인에 실패해서 시작하지 않았어요: " + probe_err)
	var dry: Dictionary = probe.taste()
	if not bool(dry["ok"]):
		return _taste_refused(str(dry["message"]))
	# 시작 시점 스냅샷: 이후 초안이 이것과 달라지면(막아 두었지만 우회된 경우) 완료하지 않고 취소한다.
	var snap: Dictionary = {
		"config": state.draft_config.duplicate(true),
		"name": state.draft_name,
		"lineage_id": state.draft_lineage_id,
		"wallet": state.wallet,
		"day": state.day,
		"records": state.record_count(),
	}
	if not _work.start(snap):
		return _work_reject("이미 시식을 준비하고 있어요.")
	_work_fx_phase = -1
	_work_notice.text = WORK_NOTE
	_taste_message.add_theme_color_override("font_color", TEAL)
	_taste_message.text = "시식을 준비하고 있어요. 국물 → 면 → 시식 순서로 잠깐 걸려요."
	_refresh_work_ui()
	_refresh_lab()
	return {"ok": true, "message": "시식 준비를 시작했어요."}


func _taste_refused(message: String) -> Dictionary:
	_audio.play("refuse")
	_taste_message.text = message
	_taste_message.add_theme_color_override("font_color", VERMILION)
	_juice.burst(_taste_button.get_global_rect().get_center(), VERMILION, message.left(22))
	_refresh_lab()
	return {"ok": false, "message": message}


## 시간을 seconds 만큼 진행하는 단 하나의 진행 함수. _process(delta)가 실제 프레임 시간으로 부르고,
## 격리된 QA 인스턴스는 이 함수를 직접 불러 앞당긴다. 이번 호출로 끝났으면 true(= _complete_work 가 정확히 한 번 실행됨).
func advance_work(seconds: float) -> bool:
	if not _work.is_running():
		return false
	if _work.advance(seconds):
		_complete_work()
		return true
	_refresh_work_ui()
	return false


## 완료 처리(진행 함수가 완료 신호를 한 번 낸 직후에만 불린다). 이 시점에 작업은 이미 IDLE 이라 같은 작업의 두 번째 완료는 없다.
## 도메인 taste() 호출은 이 함수 안의 단 한 곳이다: 기록 1개·재료비 1회·자동 저장 1회가 여기서만 일어난다.
func _complete_work() -> void:
	_juice.clear_effects()
	var snap: Dictionary = _work.take_snapshot()
	if snap.is_empty() or not _snapshot_still_valid(snap):
		_taste_message.text = "준비하는 동안 구성이나 자금이 달라져서 시식을 취소했어요. 재료비는 나가지 않았고 기록도 그대로예요."
		_taste_message.add_theme_color_override("font_color", VERMILION)
		_refresh_all()
		return
	# Compare actual retained witnesses before and after the successful payment.
	# Merely choosing a goal or composing an untasted draft earns no discovery.
	var previously_tested: Dictionary = {}
	var prior_directions: Array[String] = Directions.tested_ids(state.records())
	for page in _recipe_pages():
		if page["tested"]:
			previously_tested[page["id"]] = true
	var res: Dictionary = state.taste()
	if bool(res["ok"]):
		_direction_new_record = int(res["record_id"])
		_direction_new_titles.clear()
		for id in Directions.tested_ids(state.records()):
			if not prior_directions.has(id):
				_direction_new_titles.append(str(Directions.find(id)["title"]))
		_notebook_page = 0
		_journal_new_record_id = int(res["record_id"])
		_journal_new_titles.clear()
		for page in _recipe_pages():
			if page["tested"] and not previously_tested.has(page["id"]):
				_journal_new_titles.append(str(page["title"]))
	_taste_message.text = str(res["message"])
	if not bool(res["ok"]):
		_taste_message.add_theme_color_override("font_color", VERMILION)
		_refresh_all()
		return
	_taste_message.add_theme_color_override("font_color", TEAL)
	var saved: bool = _persist()
	if not saved:
		# 기록은 메모리에는 있고 파일에는 없다. 저장했다고 말하지 않는다.
		_taste_message.text += "\n⚠ 저장하지 못했어요: %s 지금 닫으면 이 시식 기록은 사라질 수 있어요." % _last_save_message
		_taste_message.add_theme_color_override("font_color", VERMILION)
	_refresh_all()
	tabs.current_tab = TAB_FEEDBACK
	(tabs.get_child(TAB_FEEDBACK) as ScrollContainer).scroll_vertical = 0
	_audio.play("discover" if not _direction_new_titles.is_empty() else "complete")
	_play_reveal()


func _snapshot_still_valid(snap: Dictionary) -> bool:
	if state.service_active():
		return false
	return Check.same_config(state.draft_config, snap["config"]) and state.draft_name == str(snap["name"]) \
		and state.draft_lineage_id == int(snap["lineage_id"]) and state.wallet == int(snap["wallet"]) \
		and state.day == int(snap["day"]) and state.record_count() == int(snap["records"])


func _on_work_cancel() -> void:
	cancel_work()


## 명시적 취소: 작업만 버린다. 자금/기록/보상/저장 파일은 그대로이고 조작이 다시 풀린다.
func cancel_work(message: String = "") -> bool:
	if not _work.is_running():
		return false
	_work.cancel()
	_juice.clear_effects()
	_taste_message.text = message if message != "" else "시식 준비를 취소했어요. 재료비는 나가지 않았고 기록도 그대로예요."
	_taste_message.add_theme_color_override("font_color", MUTED)
	_flash_text = ""
	_flash_until = 0
	_refresh_all()
	return true


func work_active() -> bool:
	return _work.is_running()


## 시식 연출: 그릇이 한 번 튀고 손님 카드가 차례로 나타남. 전체 약 1초 이내이며 조작을 막지 않는다.
func _play_reveal() -> void:
	# The old reveal bounced the bowl on the now-hidden lab tab. Animate the
	# actual result bowl and cards after their real layout has settled instead.
	await get_tree().process_frame
	if not is_inside_tree():
		return
	_sync_bowl_editor()
	if _bowl_editor.visible:
		_bowl_editor.play_discovery_reveal()
	var bowl := _feedback_box.find_child("FeedbackBowl", true, false) as Control
	if is_instance_valid(_bowl_editor) and _bowl_editor.visible:
		bowl = _bowl_editor._dish
	if bowl != null:
		bowl.pivot_offset = bowl.size * 0.5
		bowl.scale = Vector2.ONE * 0.65
		var tween := bowl.create_tween()
		tween.tween_property(bowl, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		var is_new: bool = _journal_new_record_id == state.last_feedback_record_id and not _journal_new_titles.is_empty()
		var new_direction: bool = _direction_new_record == state.last_feedback_record_id and not _direction_new_titles.is_empty()
		_juice.burst(bowl.get_global_rect().get_center(), TEAL, "새로운 맛 발견!" if new_direction else ("새 연구 수록!" if is_new else "시제품 완성!"), null, true)
	var index: int = 0
	for child in _feedback_box.get_children():
		if child is Control and str(child.name).begins_with("Card_"):
			var card: Control = child
			card.modulate.a = 0.0
			card.pivot_offset = card.size * 0.5
			card.scale = Vector2.ONE * 0.94
			var tween := card.create_tween()
			tween.tween_interval(0.12 * float(index))
			tween.tween_property(card, "modulate:a", 1.0, 0.25)
			tween.parallel().tween_property(card, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			index += 1


func _on_select_record(id: int) -> void:
	if _work_blocked("레시피를 불러올"):
		return
	_pending_delete_id = 0
	var res: Dictionary = state.select_record(id)
	if not bool(res["ok"]):
		_notebook_count.text = str(res["message"])
		return
	var rec: Dictionary = state.get_record(id)
	_taste_message.add_theme_color_override("font_color", TEAL)
	_taste_message.text = "'%s v%d'를 불러왔어요. 재료나 가격을 바꿔 시식하면 v%d로 기록돼요." % [str(rec["name"]), int(rec["version"]), int(rec["version"]) + 1]
	_persist()
	_refresh_all()
	tabs.current_tab = TAB_LAB


func _on_delete_record(id: int) -> void:
	if _work_blocked("기록을 삭제할"):
		return
	if _pending_delete_id != id:
		_pending_delete_id = id
		_refresh_notebook()
		return
	_pending_delete_id = 0
	var result: Dictionary = state.delete_record(id)
	if not bool(result["ok"]):
		# 판매 고정 등으로 거절된 삭제를 저장 성공처럼 처리하지 않는다. 노트 자리에서 이유를 알린다.
		_refresh_notebook()
		_notebook_count.text = str(result["message"])
		_flash(str(result["message"]))
		return
	_persist()
	_refresh_all()


## 연구 제출: 검증/보상은 전부 GameState.submit_research()가 한다. 여기서는 선택된 기록 번호를 넘기고 결과를 보여 줄 뿐이다.
## 제출 대상은 영업 메뉴로 선택된 "시식 기록"이며, 개발 탭의 편집 중인 초안은 대상이 아니다.
func _on_research_submit(request_id: String) -> void:
	if _work_blocked("연구를 제출할"):
		return
	_pending_delete_id = 0
	var res: Dictionary = state.submit_research(request_id, state.selected_record_id)
	if not bool(res["ok"]):
		_research_message.text = str(res["message"])
		_research_message.add_theme_color_override("font_color", VERMILION)
		_refresh_research()
		return
	var saved: bool = _persist()
	var text: String = "%s. 한 번만 받는 보상이에요." % str(res["message"])
	if not saved:
		# 보상은 메모리에 반영됐지만 파일에는 없다. 저장됐다고 말하지 않는다.
		text += "\n⚠ 저장하지 못했어요: %s 지금 닫으면 이 제출은 사라질 수 있어요." % _last_save_message
	_refresh_all()
	_research_message.text = text
	_research_message.add_theme_color_override("font_color", TEAL if saved else VERMILION)


# ---------- 가게 성장 입력 (승급 / 확장 구매 / 고용) ----------
##
## 경계 규칙: 이 핸들러들은 (1) 시식 준비 중이면 아무것도 바꾸기 전에 거부하고(_work_blocked, 버튼을 꺼 두는 것과 별개),
## (2) 거래 자체는 GameState 의 apply_promotion/purchase_facility/hire_staff 가 검증하고 실행한다(영업 중 거부, 자금/등급/자리/선행 검사 포함).
## 화면은 도메인이 돌려준 결과만 보여 준다: 실패하면 상태가 그대로이고, 성공하면 메모리가 이미 바뀐 것이므로 저장을 시도해
## 실제 저장 결과를 그대로 알린다(저장 실패/잠김이면 "저장하지 못했어요" 경고, 거짓 성공 없음). 불러오기/갱신/탭 이동은 어떤 보상도 만들지 않는다.

func _on_promote_pressed() -> void:
	if _work_blocked("등급 심사를 신청할"):
		return
	_pending_delete_id = 0
	var review: Dictionary = state.promotion_review()
	if bool(review["top"]):
		_growth_fail("이미 가장 높은 등급이에요.")
		return
	var target: int = int(review["next"])
	if not bool(review["eligible"]) or state.service_active():
		# 버튼은 꺼져 있지만 직접 호출돼도 도메인이 이유와 함께 거부한다(상태 불변).
		_promote_armed_until = 0
		_finish_growth_action(state.apply_promotion(target))
		return
	var now: int = Time.get_ticks_msec()
	if _promote_armed_until == 0 or now > _promote_armed_until:
		# 첫 누름은 확인만: 한 번 더 눌러야 실제로 신청한다.
		_promote_armed_until = now + PROMOTE_CONFIRM_MS
		_growth_message.text = "「%s」 심사를 신청할까요? 보상은 없고 등급만 올라요. 한 번 더 누르면 확정돼요." % str(review["next_title"])
		_growth_message.add_theme_color_override("font_color", TEAL)
		_refresh_growth()
		return
	_promote_armed_until = 0
	_finish_growth_action(state.apply_promotion(target))


func _on_facility_buy(id: String) -> void:
	if _work_blocked("확장을 살"):
		return
	_pending_delete_id = 0
	_finish_growth_action(state.purchase_facility(id))


func _on_staff_hire(id: String) -> void:
	if _work_blocked("직원을 고용할"):
		return
	_pending_delete_id = 0
	_finish_growth_action(state.hire_staff(id))


func _on_expand_shop() -> void:
	if _work_blocked("매장을 증축할"):
		return
	if state.service_active():
		_growth_fail("영업을 마친 뒤 매장을 증축하세요.")
		return
	var review: Dictionary = state.expansion_review()
	if not bool(review["can_buy"]):
		_growth_fail(str(review["reason"]))
		return
	if _expansion_armed_until == 0 or Time.get_ticks_msec() > _expansion_armed_until:
		_expansion_armed_until = Time.get_ticks_msec() + 6000
		_refresh_growth()
		return
	_expansion_armed_until = 0
	_finish_growth_action(state.expand_shop())


func _on_selling_toggle(id: int) -> void:
	if _work_blocked("판매 메뉴를 바꿀"):
		return
	var ids: Array = state.pinned_menu_ids()
	if ids.is_empty():
		for rec in state.selling_records():
			ids.append(int(rec["record_id"]))
		if state.selling_capacity() == 1 or ids.has(id):
			ids = [id]
		else:
			ids.append(id)
	elif ids.has(id):
		ids.erase(id)
	else:
		ids.append(id)
	_finish_selling_action(state.set_selling_menus(ids))


func _on_selling_auto() -> void:
	if _work_blocked("자동 판매로 돌아갈"):
		return
	_finish_selling_action(state.set_selling_menus([]))


func _finish_selling_action(result: Dictionary) -> void:
	if not bool(result["ok"]):
		_selling_message.text = str(result["message"])
		return
	var saved: bool = _persist()
	_refresh_all()
	_selling_message.text = str(result["message"]) + (" 저장했어요." if saved else "\n저장하지 못했어요: " + _last_save_message)


func _on_staff_train(id: String, style: String) -> void:
	if _work_blocked("직원을 훈련할"):
		return
	if state.service_active():
		_growth_fail("영업을 끝내거나 중단한 뒤 훈련해 주세요.")
		return
	var review: Dictionary = state.training_review(id, style)
	if str(review["error"]) != "":
		_growth_fail(str(review["error"]))
		return
	if not bool(review["eligible"]):
		_growth_fail(str(review["reason"]))
		return
	var key: String = id + ":" + style
	if _training_armed != key or Time.get_ticks_msec() > _training_armed_until:
		_training_armed = key
		_training_armed_until = Time.get_ticks_msec() + 6000
		_growth_message.text = "%s 훈련을 한 번 더 눌러 확정하세요. 비용은 즉시 사용하며 환불·전문화 변경은 없어요." % Growth._won(int(review["cost"]))
		_refresh_growth()
		return
	_training_armed = ""
	_training_armed_until = 0
	var result: Dictionary = state.train_staff(id, style)
	if bool(result["ok"]):
		_training_left = 2.0
		_training_target = id
	_finish_growth_action(result)


## 시간 전진은 결과 연출만 한다. 저장/자금/자격/경험은 확정 시 이미 한 번 반영됐다.
func advance_training(seconds: float) -> Dictionary:
	if not is_finite(seconds) or seconds < 0.0:
		return {"ok": false, "message": "훈련 연출 시간은 유한한 0 이상의 값이어야 해요."}
	if _training_left <= 0.0:
		return {"ok": false, "message": "진행 중인 훈련 연출이 없어요."}
	_training_left = maxf(0.0, _training_left - seconds)
	if _training_left == 0.0:
		_refresh_all()
	else:
		var bar: ProgressBar = find_child("TrainingProgressBar", true, false) as ProgressBar
		if bar != null:
			bar.value = 100.0 * (1.0 - _training_left / 2.0)
	return {"ok": true, "message": "훈련 연출만 진행했어요."}


func _growth_fail(message: String) -> void:
	_growth_message.text = message
	_growth_message.add_theme_color_override("font_color", VERMILION)
	_refresh_growth()


## 도메인 결과를 화면에 반영한다. 성공이면 저장을 시도하고 그 실제 결과를 메시지에 붙인다.
func _finish_growth_action(res: Dictionary) -> void:
	_promote_armed_until = 0
	if not bool(res["ok"]):
		_growth_fail(str(res["message"]))
		return
	var saved: bool = _persist()
	var text: String = str(res["message"])
	if saved:
		text += " 저장했어요."
	else:
		# 변화는 메모리에는 있고 파일에는 없다. 저장됐다고 말하지 않는다.
		text += "\n⚠ 저장하지 못했어요: %s 지금 닫으면 이 변화는 사라질 수 있어요." % _last_save_message
	_refresh_all()
	_growth_message.text = text
	_growth_message.add_theme_color_override("font_color", TEAL if saved else VERMILION)


# ---------- 화면 갱신 ----------

## 탐색 버튼은 도메인 허용 조건과 화면의 준비/이동 잠금을 함께 반영한다. 실제 핸들러에서도 다시 검사한다.
func _build_exploration(box: VBoxContainer) -> void:
	_exploration_summary = _label("", 18, VERMILION)
	_exploration_summary.name = "ExplorationSummary"
	box.add_child(_exploration_summary)
	var note: Label = _label("지역을 골라 두 번의 만남에서 선택하면 새 재료를 발견해요. 발견한 재료는 계속 개발에 쓸 수 있는 공급처가 열려요. 출발은 하루 한 번, 다음 기회는 영업을 마친 뒤예요.", 14, MUTED)
	note.name = "ExplorationRules"
	box.add_child(note)
	_exploration_message = _label("", 15, TEAL)
	_exploration_message.name = "ExplorationMessage"
	box.add_child(_exploration_message)
	_exploration_box = _vbox(12)
	box.add_child(_exploration_box)


func _exploration_button(text: String, node_name: String, locked: bool, travel_guard: bool = false) -> Button:
	var b: Button = _button(text, node_name)
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.set_meta("locked", locked)
	b.set_meta("travel_guard", travel_guard)
	_exploration_buttons.append(b)
	return b


func _region_picture(region: String, node_name: String) -> TextureRect:
	var picture: TextureRect = TextureRect.new()
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	picture.name = node_name
	picture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	picture.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	picture.texture = ArtScript.scaled_tex(ArtScript.exploration_image(region), 4)
	picture.custom_minimum_size = Vector2(288.0, 104.0)
	picture.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return picture


func _refresh_exploration() -> void:
	if _exploration_box == null:
		return
	_clear(_exploration_box)
	_exploration_buttons.clear()
	_travel_art = null
	_travel_bar = null
	_travel_label = null
	var progress: Dictionary = state.exploration_progress()
	_exploration_summary.text = "재료 탐색 · 발견 %d/%d종\n%d일차 · 자금 %s · 가게 등급 %d" % [int(progress["obtained"]), int(progress["total"]), state.day, _won(state.wallet), state.rank()]
	_exploration_message.visible = _exploration_message.text != ""
	var trip: Dictionary = state.expedition()
	if not trip.is_empty():
		var active: PanelContainer = _card("ExpeditionCard")
		var ab: VBoxContainer = _vbox(6)
		active.add_child(ab)
		var title: Label = _label(str(trip["region_name"]) + " · 탐색 수첩", 19, VERMILION)
		title.name = "ExpeditionTitle"
		ab.add_child(title)
		_travel_art = _region_picture(str(trip["region"]), "ExpeditionLandscape")
		ab.add_child(_travel_art)
		var paid: Label = _label("출발 %s + 선택 %s · 이미 지불한 비용이에요." % [_won(int(trip["fee"])), _won(int(trip["extra"]))], 14, MUTED)
		paid.name = "ExpeditionPaid"
		ab.add_child(paid)
		if _travel.running():
			_travel_label = _label("", 16, TEAL)
			_travel_label.name = "ExpeditionTravelLabel"
			ab.add_child(_travel_label)
			_travel_bar = ProgressBar.new()
			_travel_bar.name = "ExpeditionTravelProgress"
			_travel_bar.show_percentage = false
			_travel_bar.custom_minimum_size = Vector2(0.0, 16.0)
			ab.add_child(_travel_bar)
			_update_travel_picture()
		elif str(trip["stage"]) == Exploration.STAGE_RESULT:
			var result: Dictionary = trip["result"]
			var result_text: Label = _label(str(result["message"]), 18, TEAL)
			result_text.name = "ExpeditionResult"
			ab.add_child(result_text)
			var collect: Button = _exploration_button("결과 받기", "ExpeditionCollect", false, true)
			collect.pressed.connect(_on_exploration_collect)
			ab.add_child(collect)
		else:
			var event: Dictionary = trip["event"]
			var event_title: Label = _label("만남 %d/2 · %s" % [int(event["step"]), str(event["title"])], 18, VERMILION)
			event_title.name = "ExpeditionEventTitle"
			ab.add_child(event_title)
			var event_text: Label = _label(str(event["text"]), 16, INK)
			event_text.name = "ExpeditionEventText"
			ab.add_child(event_text)
			for choice in event["choices"]:
				var ch: Dictionary = choice
				var action: Button = _exploration_button(str(ch["label"]), "ExpeditionChoice_" + str(ch["id"]), not bool(ch["affordable"]), true)
				action.pressed.connect(_on_exploration_choice.bind(str(ch["id"])))
				ab.add_child(action)
				var text: String = str(ch["desc"])
				if ch.has("ingredient_name"):
					text += "\n" + str(ch["ingredient_name"]) + (" · 이미 발견한 재료" if bool(ch["known"]) else " · 새 재료")
				if not bool(ch["affordable"]) and not bool(ch.get("capacity_blocked", false)):
					text += " · 자금이 모자라요."
				var detail: Label = _label(text, 14, MUTED)
				detail.name = "ExpeditionChoiceNote_" + str(ch["id"])
				ab.add_child(detail)
		if bool(trip["can_retire"]):
			var retire: Button = _exploration_button("탐색 포기 (비용·오늘 기회는 돌아오지 않아요)", "ExpeditionRetire", false)
			retire.add_theme_font_size_override("font_size", 14)
			retire.pressed.connect(_on_exploration_retire)
			ab.add_child(retire)
		_exploration_box.add_child(active)
	elif not state.exploration_history().is_empty():
		var receipt: Dictionary = state.exploration_history().back()
		var message: String = "%d일차 탐색 · %s" % [int(receipt["day"]), str(Exploration.find_region(str(receipt["region"]))["name"])]
		message += "\n포기했어요. 보상과 환불은 없어요." if str(receipt["outcome"]) == Exploration.OUTCOME_RETIRED else "\n" + Exploration.ingredient_name(str(receipt["ingredient"])) + (" · 새 발견" if bool(receipt["new"]) else " · 이미 발견한 재료")
		var last: Label = _label(message, 16, TEAL)
		last.name = "ExplorationLastReceipt"
		_exploration_box.add_child(last)
	if state.harbor_foraging_review()["unlocked"]:
		_refresh_harbor_card()
		_refresh_foraging_card()
	else:
		_refresh_foraging_card()
		_refresh_harbor_card()
	for rv in state.exploration_regions():
		var region: Dictionary = rv
		var id: String = str(region["id"])
		var card: PanelContainer = _card("RegionCard_" + id)
		var box: VBoxContainer = _vbox(6)
		card.add_child(box)
		var head: Label = _label("%s · %d/%d종" % [str(region["name"]), int(region["obtained"]), int(region["total"])], 20, VERMILION)
		head.name = "RegionTitle_" + id
		box.add_child(head)
		box.add_child(_region_picture(id, "RegionPicture_" + id))
		var info: Label = _label("등급 %d부터 · 출발 %s\n%s" % [int(region["min_rank"]), _won(int(region["fee"])), str(region["summary"])], 15, INK)
		info.name = "RegionInfo_" + id
		box.add_child(info)
		for ingredient in region["ingredients"]:
			var item: Dictionary = ingredient
			var material: Label = _label(("발견 · " if bool(item["discovered"]) else "미발견 · ") + str(item["name"]) + "\n" + str(item["desc"]), 14, TEAL if bool(item["discovered"]) else MUTED)
			material.name = "Discovery_" + str(item["id"])
			box.add_child(material)
		var reason: Label = _label(str(region["reason"]), 14, MUTED)
		reason.name = "RegionReason_" + id
		reason.visible = reason.text != ""
		box.add_child(reason)
		var depart: Button = _exploration_button("모두 발견했어요" if bool(region["complete"]) else "출발 · " + _won(int(region["fee"])), "ExpeditionDepart_" + id, not bool(region["can_start"]))
		depart.pressed.connect(_on_exploration_depart.bind(id))
		box.add_child(depart)
		_exploration_box.add_child(card)
	_sync_exploration_lock()
	if not _travel.running() and not state.harbor_foraging_state()["active"].is_empty() and str(trip.get("stage", "")) == Exploration.STAGE_RESULT:
		_reveal_harbor_reward.call_deferred()


## A pending reward is the next action. Reveal its button after layout without
## granting it, changing tabs, or scrolling away from a failed-save warning.
func _reveal_harbor_reward() -> void:
	await get_tree().process_frame
	if tabs.current_tab != TAB_EXPLORATION or _travel.running() or _last_save_message != "":
		return
	if state.harbor_foraging_state()["active"].is_empty() or str(state.expedition().get("stage", "")) != Exploration.STAGE_RESULT:
		return
	var collect := find_child("ExpeditionCollect", true, false) as Button
	if collect != null and collect.is_visible_in_tree():
		(tabs.get_child(TAB_EXPLORATION) as ScrollContainer).ensure_control_visible(collect)


## No new management tab: the market sample loop lives next to supplier trips.
## Display the trial-only consumption contract before the player pays a fee.
func _refresh_foraging_card() -> void:
	var review: Dictionary = state.foraging_review()
	var samples: Dictionary = review["state"]
	var card: PanelContainer = _card("ForagingCard")
	var box: VBoxContainer = _vbox(6)
	card.add_child(box)
	box.add_child(_label("새벽 장터 · 연구 재료 채집", 18, VERMILION))
	var rules: Label = _label("출발 1,000원 · 기존 탐색과 합쳐 하루 한 번\n시제품에 넣은 분량만큼 완성 때 써요. 취소하면 쓰지 않아요. 등록한 메뉴의 판매는 영업 원가로 공급돼요.", 14, MUTED)
	rules.name = "ForagingRules"
	box.add_child(rules)
	var stock_lines: Array[String] = []
	for id in Foraging.IDS:
		stock_lines.append("%s · 연구 재료 %d/20개" % [Catalog.find(id)["name"], samples["stock"][id]])
	var stock: Label = _label("\n".join(stock_lines), 15, TEAL)
	stock.name = "ForagingStock"
	box.add_child(stock)
	if not samples["history"].is_empty():
		var receipt: Dictionary = samples["history"].back()
		var text: String = "%d일차 채집 · 포기 (환불 없음)" % receipt["day"]
		if receipt["outcome"] == "finished":
			text = "%d일차 · %s %d개 수령" % [receipt["day"], Catalog.find(receipt["ingredient"])["name"], receipt["amount"]]
		box.add_child(_label(text, 14, TEAL))
	var reason: Label = _label(str(review["reason"]), 14, MUTED)
	reason.name = "ForagingReason"
	reason.visible = reason.text != ""
	box.add_child(reason)
	var depart: Button = _exploration_button("연구 재료 채집 · 1,000원", "ForagingDepart", not bool(review["can_start"]))
	depart.pressed.connect(_on_foraging_depart)
	box.add_child(depart)
	_exploration_box.add_child(card)


## The region art and two compact disclosure rows keep the loop legible on a
## phone. Facts and fees are visible before departure; details are opt-in.
func _refresh_harbor_card() -> void:
	var review: Dictionary = state.harbor_foraging_review()
	var samples: Dictionary = review["state"]
	var card: PanelContainer = _card("HarborForagingCard")
	var box: VBoxContainer = _vbox(8)
	card.add_child(box)
	if not review["unlocked"]:
		# Early players see a compact goal, rather than a long unavailable
		# inventory that buries the market they can actually play now.
		box.add_child(_label("다음 채집지 · 항구", 18, VERMILION))
		var locked_reason: Label = _label(str(review["reason"]), 14, MUTED)
		locked_reason.name = "HarborForagingReason"
		box.add_child(locked_reason)
		box.add_child(_label("구운 정어리 육수 · 가리비 고명", 14, TEAL))
		box.add_child(_exploration_button("항구 채집 잠김 · 등급 2 / 공급처 2곳", "HarborForagingDepart", true))
		_exploration_box.add_child(card)
		return
	box.add_child(_label("항구 · 오늘의 연구 어획물", 20, VERMILION))
	box.add_child(_region_picture("harbor", "HarborForagingPicture"))
	var rules: Label = _label("출발 1,200원 · 모든 탐색과 합쳐 하루 한 번\n재료 선택 → 손질 선택 → 수령 → 메뉴 실험", 15, INK)
	rules.name = "HarborForagingRules"
	box.add_child(rules)
	var price: Label = _label("기본 1개 / 추가 0원 · 손질 3개 / 추가 600원\n시제품에 넣은 분량만큼 완성 때 소모해요. 취소는 소모 없음. 등록한 메뉴는 연구 재료가 없어도 판매할 수 있어요.", 14, MUTED)
	price.name = "HarborForagingCosts"
	box.add_child(price)
	for id in Harbor.IDS:
		var item: Dictionary = Catalog.find(id)
		var detail := DetailsScript.new()
		detail.name = "HarborMaterial_" + id
		box.add_child(detail)
		detail.configure(str(item["name"]), "연구 재료 %d/20개 · 펼쳐 보기" % samples["stock"][id], _icon(id, 2))
		var facts: Label = _label("%s\n%s\n메뉴 한 그릇 원가 %s · 준비 %d초" % [item["desc"], Catalog.axes_text(item), _won(int(item["cost"])), item["seconds"]], 14, INK)
		facts.name = "HarborFacts_" + id
		detail.body.add_child(facts)
		var go: Button = _exploration_button("개발에서 조합하기  →", "HarborLab_" + id, not state.ingredient_unlocked(id) or state.exploration_active())
		go.pressed.connect(_open_sample_lab.bind(str(id)))
		detail.body.add_child(go)
	if not samples["history"].is_empty():
		var receipt: Dictionary = samples["history"].back()
		var text: String = "%d일차 · 채집 포기 / 환불 없음" % receipt["day"]
		if receipt["outcome"] == "finished":
			text = "%d일차 수령 · %s ×%d\n지금 보관 %d개 · 다시 받으면 중복 지급되지 않아요." % [receipt["day"], Catalog.find(receipt["ingredient"])["name"], receipt["amount"], state.sample_stock(str(receipt["ingredient"]))]
			var go: Button = _exploration_button("이 재료로 실험  →", "HarborLatestLab", state.exploration_active())
			go.pressed.connect(_open_sample_lab.bind(str(receipt["ingredient"])))
			box.add_child(go)
		var receipt_label: Label = _label(text, 15, TEAL)
		receipt_label.name = "HarborLastReceipt"
		box.add_child(receipt_label)
	var reason: Label = _label(str(review["reason"]), 14, MUTED)
	reason.name = "HarborForagingReason"
	reason.visible = reason.text != ""
	box.add_child(reason)
	var depart: Button = _exploration_button("항구 채집 출발 · 1,200원", "HarborForagingDepart", not bool(review["can_start"]))
	depart.pressed.connect(_on_harbor_foraging_depart)
	box.add_child(depart)
	_exploration_box.add_child(card)


func _on_harbor_foraging_depart() -> void:
	if _exploration_guard():
		return
	_finish_exploration_action(state.start_harbor_foraging(), true)


## Navigation exposes existing controls and never overwrites an edited draft,
## auto-selects the catch, spends samples or starts a tasting.
func _open_sample_lab(id: String) -> void:
	if _exploration_guard(true):
		return
	var item: Dictionary = Catalog.find(id)
	if item.is_empty() or not state.ingredient_unlocked(id):
		_flash("먼저 연구 재료를 수령하세요.")
		return
	var slot: String = "broth" if id.begins_with("broth_") else "topping"
	await _open_experiment_choices(slot)
	_taste_message.text = "%s · 초안은 유지했어요. 직접 골라 조합해 보세요." % item["name"]
	await get_tree().process_frame
	# The actual native editor, rather than its hidden legacy adapter, owns the
	# material handoff. Revealing details must not apply an ingredient or charge.
	_sync_bowl_editor()
	if tabs.current_tab == TAB_LAB:
		_bowl_editor.reveal_ingredient(id)


func _on_foraging_depart() -> void:
	if _exploration_guard():
		return
	_finish_exploration_action(state.start_foraging(), true)


func _sync_exploration_lock() -> void:
	var busy: bool = _work.is_running() or state.service_active() or _contest_left > 0.0 or _training_left > 0.0
	for button in _exploration_buttons:
		if is_instance_valid(button):
			button.disabled = busy or bool(button.get_meta("locked")) or (_travel.running() and bool(button.get_meta("travel_guard")))


func _exploration_guard(moving_action: bool = false) -> bool:
	var reason: String = ""
	if _training_left > 0.0:
		reason = "훈련 결과를 정리한 뒤 탐색할 수 있어요."
	elif _contest_left > 0.0:
		reason = "심사 결과를 정리한 뒤 탐색할 수 있어요."
	elif _work.is_running():
		reason = "시식 준비 중에는 탐색할 수 없어요. 준비를 마치거나 취소하세요."
	elif state.service_active():
		reason = "영업 중에는 탐색할 수 없어요. 정산을 마친 뒤 출발하세요."
	elif moving_action and _travel.running():
		reason = "이동 중이에요. 도착하면 다음 선택을 할 수 있어요."
	if reason == "":
		return false
	_exploration_message.text = reason
	_exploration_message.visible = true
	_exploration_message.add_theme_color_override("font_color", VERMILION)
	return true


func _on_exploration_depart(region: String) -> void:
	if _exploration_guard():
		return
	_finish_exploration_action(state.start_expedition(region), true)


func _on_exploration_choice(choice: String) -> void:
	if _exploration_guard(true):
		return
	_finish_exploration_action(state.advance_expedition(choice), true)


func _on_exploration_collect() -> void:
	if _exploration_guard(true):
		return
	var result: Dictionary = state.finish_expedition()
	_finish_exploration_action(result)
	if result["ok"] and result.has("receipt"):
		await get_tree().process_frame
		var id: String = str(result["receipt"]["ingredient"])
		_sync_bowl_editor()
		var origin: Vector2=await _exploration_view.celebrate_receipt(id)
		if origin.x<0:
			origin=get_viewport_rect().size*Vector2(0.5,0.4)
		var caption: String = "%s +%d" % [Catalog.find(id)["name"], result["receipt"]["amount"]] if Catalog.is_farmed(id) else str(Catalog.find(id)["name"])+" 발견!"
		_juice.burst(origin, TEAL, caption, _icon(id, 3), true)


func _on_exploration_retire() -> void:
	if _exploration_guard():
		return
	_finish_exploration_action(state.retire_expedition())


## 먼저 실제 도메인 거래가 성공한 뒤 저장 결과를 표시한다. 저장 실패는 메모리에만 반영된 변화임을 분명히 알린다.
func _finish_exploration_action(result: Dictionary, travel: bool = false) -> void:
	var message: String = str(result["message"])
	if not bool(result["ok"]):
		_exploration_message.text = _unsaved_notice(message)
		_exploration_message.visible = true
		_exploration_message.add_theme_color_override("font_color", VERMILION)
		return
	if travel and state.exploration_active():
		_travel.start(str(state.expedition()["region"]))
	else:
		_travel.stop()
	var saved: bool = _persist()
	message += " 저장했어요." if saved else "\n⚠ 저장하지 못했어요: %s 지금 진행은 이 게임 안에만 남아 있어요." % _last_save_message
	_refresh_all()
	_exploration_message.text = message
	_exploration_message.visible = true
	_exploration_message.add_theme_color_override("font_color", TEAL if saved else VERMILION)
	# 아래쪽 지역에서 출발해도 새 만남/저장 경고가 있는 위쪽으로 돌아간다. 이전 카드의 스크롤 위치를 재사용하지 않는다.
	(tabs.get_child(TAB_EXPLORATION) as ScrollContainer).scroll_vertical = 0


## 연출이 끝나도 사건 선택/보상은 건드리지 않는다. 도착하면 버튼을 보여 주기만 한다.
func advance_travel(seconds: float) -> Dictionary:
	var result: Dictionary = _travel.advance(seconds)
	if not bool(result["ok"]):
		return result
	if _travel.running():
		_update_travel_picture()
	else:
		_refresh_exploration()
	return result


func _update_travel_picture() -> void:
	if _travel_art == null:
		return
	_travel_art.texture = ArtScript.scaled_tex(ArtScript.exploration_image(_travel.region(), _travel.progress(), true), 4)
	if _travel_bar != null:
		_travel_bar.value = _travel.progress() * 100.0
	if _travel_label != null:
		_travel_label.text = "이동 중… %d%%" % int(_travel.progress() * 100.0)

func _build_contests(box: VBoxContainer) -> void:
	_contest_summary = _label("", 18, VERMILION)
	_contest_summary.name = "ContestSummary"
	box.add_child(_contest_summary)
	var rules: Label = _label("시식한 메뉴로 하루 한 번 출품해요. 대회 기준 70% + 단골 평가 30%로 심사해요. 처음 얻거나 더 높은 메달의 상금 차액만 지급하며, 금메달 대회는 완료돼요. 은메달부터 잡지 소개 제안이 와요.", 14, MUTED)
	rules.name = "ContestRules"
	box.add_child(rules)
	_contest_message = _label("", 15, TEAL)
	_contest_message.name = "ContestMessage"
	box.add_child(_contest_message)
	_contest_box = _vbox(12)
	box.add_child(_contest_box)


func _contest_picture(band: int, magazine: bool = false) -> TextureRect:
	var picture: TextureRect = TextureRect.new()
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	picture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	picture.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	picture.texture = ArtScript.scaled_tex(ArtScript.magazine_image() if magazine else ArtScript.contest_badge_image(band), 4)
	picture.custom_minimum_size = Vector2(0.0, 96.0 if not magazine else 112.0)
	picture.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return picture


func _refresh_contests() -> void:
	if _contest_box == null:
		return
	_clear(_contest_box)
	_contest_buttons.clear()
	var progress: Dictionary = state.contest_progress()
	_contest_summary.text = "라멘 대회 · 출품 %d회 · 잡지 %d편\n%d일차 · 자금 %s" % [int(progress["attempts"]), progress["articles"].size(), state.day, _won(state.wallet)]
	_contest_message.visible = _contest_message.text != ""
	var judging: bool = _contest_left > 0.0
	if judging:
		var note: Label = _label("심사위원들이 한 그릇을 살펴보고 있어요… 결과 정리 중", 16, VERMILION)
		note.name = "ContestJudging"
		_contest_box.add_child(note)
		var bar: ProgressBar = ProgressBar.new()
		bar.name = "ContestProgressBar"
		bar.value = 100.0 * (1.0 - _contest_left / 1.5)
		bar.custom_minimum_size.y = 18.0
		_contest_box.add_child(bar)
	elif not progress["history"].is_empty():
		var last: Dictionary = progress["history"][-1]
		var result_card: PanelContainer = _card("ContestResultCard")
		var rb: VBoxContainer = _vbox(6)
		result_card.add_child(rb)
		_contest_box.add_child(result_card)
		rb.add_child(_contest_picture(int(last["band"])))
		var result: Label = _label("%s · %d점\n'%s v%d' · %s\n출품료 %s · 이번 상금 %s" % [str(Contest.find(str(last["contest_id"]))["title"]), int(last["score"]), str(last["recipe_name"]), int(last["version"]), Contest.band_name(int(last["band"])), _won(int(last["fee"])), _won(int(last["prize"]))], 16, INK)
		result.name = "ContestResult"
		rb.add_child(result)
		var evaluated: Dictionary = Contest.evaluate(str(last["contest_id"]), last["config"])
		var hints: PackedStringArray = []
		for axis in evaluated["feedback"]:
			hints.append(str(axis["hint"]))
		var feedback: Label = _label("대회 기준 %d · 단골 평가 %d\n%s\n노트에서 이 메뉴를 불러와 고친 뒤 다시 시식하세요." % [int(evaluated["theme_score"]), int(evaluated["audience_score"]), "\n".join(hints)], 14, MUTED)
		feedback.name = "ContestFeedback"
		rb.add_child(feedback)
	for review in state.contest_reviews():
		var def: Dictionary = review
		var id: String = str(def["id"])
		var card: PanelContainer = _card("ContestCard_" + id)
		var col: VBoxContainer = _vbox(6)
		card.add_child(col)
		_contest_box.add_child(card)
		var best: Dictionary = def["best"]
		var title: Label = _label(str(def["title"]), 18, VERMILION)
		title.name = "ContestTitle_" + id
		col.add_child(title)
		var targets: PackedStringArray = []
		for axis in Catalog.AXES:
			targets.append("%s %d" % [str(Catalog.AXIS_NAMES[axis]), int(def["targets"][axis])])
		col.add_child(_label("%s\n%s\n목표: %s\n등급 %d · %d일차 · 출품료 %s\n동 55점/4,000원 · 은 70점/10,000원 · 금 85점/18,000원 (누적 상금 상한)\n최고 메달: %s" % [str(def["description"]), str(def["criteria"]), " · ".join(targets), int(def["rank"]), int(def["min_day"]), _won(int(def["fee"])), "없음" if best.is_empty() else Contest.band_name(int(best["band"]))], 14, MUTED))
		var reason: Label = _label(str(def["reason"]), 14, VERMILION)
		reason.name = "ContestLock_" + id
		col.add_child(reason)
		var enter: Button = _button("선택한 시식 메뉴로 출품 · " + _won(int(def["fee"])), "ContestEnter_" + id)
		enter.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		enter.disabled = not bool(def["can_enter"]) or judging or work_active() or _training_left > 0.0
		enter.pressed.connect(_on_contest_enter.bind(id))
		_contest_buttons.append(enter)
		col.add_child(enter)
		if bool(def["article_pending"]) or not def["article"].is_empty():
			var magazine: Dictionary = def["article"]
			var featured: Dictionary = best if magazine.is_empty() else magazine["entry"]
			col.add_child(_contest_picture(0, true))
			var story: Label = _label("골목 한 그릇 · %s\n%s" % [str(def["article_title"]) % str(featured["recipe_name"]), str(def["article_text"]) % str(featured["recipe_name"])], 15, INK)
			story.name = "MagazineStory_" + id
			col.add_child(story)
			var published: Label = _label("소개 제안 도착 · 촬영 협조비 %s (한 번)" % _won(int(def["article_cash"])) if magazine.is_empty() else "%d일차 잡지 게재 완료 · 협조비 수령 완료" % int(magazine["day"]), 14, TEAL)
			published.name = "MagazineStatus_" + id
			col.add_child(published)
			if magazine.is_empty():
				var accept: Button = _button("잡지 소개 수락", "MagazineAccept_" + id)
				accept.disabled = judging or work_active() or state.service_active() or state.exploration_active() or _training_left > 0.0
				accept.pressed.connect(_on_magazine_accept.bind(id))
				_contest_buttons.append(accept)
				col.add_child(accept)


## 심사 연출 이전에 도메인 거래와 저장을 확정한다. 끄거나 재시작해도 비용/결과가 반복되지 않는다.
func _on_contest_enter(id: String) -> void:
	if _work_blocked("출품할") or state.service_active():
		# 일시적인 입력 거부가 직전 거래의 저장 성공/실패 안내를 덮지 않게 한다.
		_flash("영업·탐색·시식·심사를 마친 뒤 출품하세요.")
		return
	var result: Dictionary = state.enter_contest(id, state.selected_record_id)
	_finish_contest_action(result, true)


func _on_magazine_accept(id: String) -> void:
	if _work_blocked("잡지 소개를 수락할") or state.service_active():
		_flash("영업·탐색·시식·심사를 마친 뒤 수락하세요.")
		return
	_finish_contest_action(state.claim_magazine(id), false)


func _finish_contest_action(result: Dictionary, present: bool) -> void:
	if not bool(result["ok"]):
		_contest_message.text = str(result["message"])
		_refresh_contests()
		return
	var saved: bool = _persist()
	_contest_message.text = str(result["message"]) + (" 저장했어요." if saved else "\n⚠ 저장하지 못했어요: %s 지금 변화는 이 게임 안에만 남아 있어요." % _last_save_message)
	_contest_left = 1.5 if present else 0.0
	_refresh_all()
	var scroll: ScrollContainer = tabs.find_child("TabContests", true, false) as ScrollContainer
	if scroll != null:
		scroll.scroll_vertical = 0


func advance_contest(seconds: float) -> Dictionary:
	if not is_finite(seconds) or seconds < 0.0:
		return {"ok": false, "message": "심사 시간은 유한한 0 이상의 값이어야 해요."}
	if _contest_left <= 0.0:
		return {"ok": false, "message": "정리 중인 심사 결과가 없어요."}
	_contest_left = maxf(0.0, _contest_left - seconds)
	if _contest_left == 0.0:
		_refresh_all()
	else:
		var bar: ProgressBar = find_child("ContestProgressBar", true, false) as ProgressBar
		if bar != null:
			bar.value = 100.0 * (1.0 - _contest_left / 1.5)
	return {"ok": true, "message": "심사 연출만 진행했어요."}


## The native editor presents existing state and delegates all mutations to the
## established guarded actions. Hidden legacy lab nodes are controller adapters,
## not current visual evidence; other feature pages remain reachable from its menu.
func _sync_bowl_editor() -> void:
	if not is_instance_valid(_bowl_editor):
		return
	var active: bool = _overlay.visible and tabs.current_tab in [TAB_LAB, TAB_FEEDBACK]
	var exploring: bool = _overlay.visible and tabs.current_tab == TAB_EXPLORATION
	_bowl_editor.visible = active
	_exploration_view.visible = exploring
	var growing: bool = _overlay.visible and tabs.current_tab == TAB_GROWTH
	_drawer_margin.visible = not active and not exploring and not growing
	if is_instance_valid(_growth_view):
		_growth_view.visible = growing
		if growing:
			_growth_view.present(state,{"revision":_growth_revision,"busy":_development_busy(),
				"closing_blocked":_work.is_running() or _training_left>0.0 or _contest_left>0.0,
				"notice":_growth_message.text,"notice_error":_growth_message.get_theme_color("font_color")==VERMILION,
				"save_status":_save_label.text,
				"warning":_banner_label.text if _banner.visible else "",
				"promote_armed":_promote_armed_until!=0 and Time.get_ticks_msec()<=_promote_armed_until,
				"expand_armed":_expansion_armed_until!=0 and Time.get_ticks_msec()<=_expansion_armed_until,
				"training_armed":_training_armed if Time.get_ticks_msec()<=_training_armed_until else "",
				"training_left":_training_left})
	if exploring:
		var save_warning: String = _last_save_message if _last_save_message!="" else (_banner_label.text if _banner.visible else "")
		_exploration_view.present(state,{
			"busy":_work.is_running() or state.service_active() or _contest_left>0.0 or _training_left>0.0,
			"travel":_travel.running(),"progress":_travel.progress(),
			"warning":save_warning,"notice":_exploration_message.text if _exploration_message.get_theme_color("font_color")==VERMILION else ""})
	if not active:
		return
	var warning: String = _banner_label.text if _banner.visible else ""
	if _save_error_shown or save_locked:
		warning = "저장하지 못했어요. 작업 메뉴의 현재 안내를 확인하세요. " + _last_save_message
	_bowl_editor.present(state, 1 if tabs.current_tab == TAB_FEEDBACK else 0, {
		"selected": _selected_topping_position, "busy": _development_busy(),
		"working": work_active(), "progress": _work.progress(),
		"phase": WorkScript.phase_name(_work.phase_index()) if work_active() else "",
		"notice": _taste_message.text, "warning": warning, "muted": _audio.muted,
		"new_directions":_direction_new_titles if _direction_new_record==state.last_feedback_record_id else [],
		"new_themes":_journal_new_titles if _journal_new_record_id==state.last_feedback_record_id else []})


## The native growth screen uses established handlers and their domain guards.
## Cancel only clears temporary confirmations; no business state is reverted.
func _on_growth_view_action(kind: String, id: String, style: String) -> void:
	match kind:
		"close": _on_close_pressed()
		"develop":
			if not _work_blocked("메뉴 개발로 이동할"): _open_overlay(TAB_LAB)
		"hire": _on_staff_hire(id)
		"facility": _on_facility_buy(id)
		"expand": _on_expand_shop()
		"promote": _on_promote_pressed()
		"train": _on_staff_train(id,style)
		"cancel":
			_promote_armed_until = 0
			_expansion_armed_until = 0
			_training_armed = ""
			_training_armed_until = 0
		_: push_error("알 수 없는 성장 화면 동작: " + kind)
	_sync_bowl_editor()


func _on_bowl_editor_action(kind: String, data: Dictionary) -> void:
	match kind:
		"close": _on_close_pressed()
		"taste": _on_taste()
		"cancel": _on_work_cancel()
		"serve": _on_overlay_open_pressed()
		"ingredient": _on_option_pressed(str(data["slot"]), str(data["id"]), data["point"])
		"slot": _select_topping_position(int(data["index"]))
		"remove": _remove_topping_position(int(data["index"]))
		"process": _on_process_choice(str(data["slot"]), str(data["id"]))
		"route": _on_tab_link(int(data["index"]))
		"name": _on_name_changed(str(data["value"]))
		"price": _on_price_step(int(data["delta"]))
		"new": _on_new_recipe()
		"audio": _toggle_audio()
		"direction": _select_direction(str(data["id"]))
		"comparison":
			var record: Dictionary = state.get_record(state.last_feedback_record_id)
			var body: VBoxContainer = data["body"] as VBoxContainer
			if body == null or record.is_empty():
				push_error("시식 비교 대상이나 표시 영역이 없어요.")
			else:
				body.add_child(_comparison_card(record, Evaluator.evaluate(record["config"])))
		_:
			push_error("알 수 없는 편집 동작: " + kind)
	_sync_bowl_editor()


func _on_exploration_view_action(kind: String, data: Dictionary) -> void:
	# View-only selection never calls the state. Paid/claim actions retain the
	# same business and travel guards as the legacy controller entry points.
	match kind:
		"close": _on_close_pressed()
		"depart":
			if str(data["mode"])=="supplier":
				_on_exploration_depart(str(data["region"]))
			elif str(data["mode"])=="sample" and str(data["region"])=="market":
				_on_foraging_depart()
			elif str(data["mode"])=="sample" and str(data["region"])=="harbor":
				_on_harbor_foraging_depart()
			else:
				push_error("탐색 출발 지역이나 목적이 올바르지 않아요.")
		"choice": _on_exploration_choice(str(data["id"]))
		"collect": _on_exploration_collect()
		"retire": _on_exploration_retire()
		"lab": _on_tab_link(TAB_LAB)
		"material": _open_sample_lab(str(data["id"]))
		_: push_error("알 수 없는 탐색 화면 동작: "+kind)
	_sync_bowl_editor()


func _refresh_all() -> void:
	_trip_notice.visible = state.exploration_active()
	_refresh_header()
	_refresh_lab()
	_refresh_feedback()
	_refresh_notebook()
	_refresh_serve()
	_refresh_research()
	_refresh_growth()
	_refresh_exploration()
	_refresh_contests()
	_refresh_guide()
	_refresh_status()
	_refresh_nav()
	_refresh_work_ui()
	# 닫힌 가게에는 실제 고용 목록을 보여 준다(영업 중에는 ShopView 가 세션의 직원 스냅샷을 쓴다).
	_shop.set_idle_staff(state.hired_staff())
	_shop.set_expanded(state.shop_expanded())


## 시식 준비 카드/단계/진행 막대를 현재 작업 상태로 맞추고, 준비 중이면 편집 조작을 꺼서 보여 준다(실제 차단은 각 핸들러의 _work_blocked).
func _refresh_work_ui() -> void:
	if _work_card == null:
		return
	var active: bool = _work.is_running()
	_work_card.visible = active
	if active:
		var p: float = _work.progress()
		var phase: int = _work.phase_index()
		var snap: Dictionary = _work.snapshot()
		var process: Dictionary = snap.get("config", {}).get("process", {})
		_work_progress.value = p * 100.0
		_work_percent.text = "%d%%" % int(floor(p * 100.0))
		_work_title.text = "시식 준비 중 (%d/%d)" % [phase + 1, WorkScript.PHASES.size()]
		if not process.is_empty():
			_work_title.text = "제조·시식 준비 (%d/3)\n약 %.1f초" % [phase + 1, _work.duration()]
		var marks: Array[String] = ["①", "②", "③"]
		for i in _work_phase_labels.size():
			var lab: Label = _work_phase_labels[i]
			var done: bool = i < phase
			var phase_name: String = WorkScript.phase_name(i)
			if i < 2 and not process.is_empty():
				var slot: String = ProcessRules.SLOTS[i]
				phase_name = str(ProcessRules.method(slot, ProcessRules.selected(process, slot))["name"])
			lab.text = "%s %s%s" % [marks[i], phase_name, " · 끝" if done else (" · 진행 중" if i == phase else "")]
			lab.add_theme_color_override("font_color", TEAL if done else (VERMILION if i == phase else MUTED))
		if phase != _work_fx_phase and is_instance_valid(_juice):
			_work_fx_phase = phase
			_show_work_phase_feedback(phase)
		_work_view.set_state(p, snap["config"] if snap.has("config") else {})
	_apply_work_lock()


func _show_work_phase_feedback(phase: int) -> void:
	# Showing the work card schedules a container layout. Its old rectangle is
	# not a valid effect origin yet; wait for layout and discard obsolete cues.
	await get_tree().process_frame
	if not work_active() or WorkScript.phase_for(_work.progress()) != phase:
		return
	_audio.play(["broth", "noodle", "plate"][phase])
	var origin: Vector2 = _bowl_editor._dish.get_global_rect().get_center() if is_instance_valid(_bowl_editor) and _bowl_editor.visible else _work_view.get_global_rect().get_center()
	_juice.burst(origin, TEAL, WorkScript.phase_name(phase), null, true)


func _development_busy() -> bool:
	return _work.is_running() or state.exploration_active() or state.service_active() or _contest_left > 0.0 or _training_left > 0.0


func _apply_work_lock() -> void:
	if _work_card == null:
		return
	var busy: bool = _development_busy()
	for id in _buttons.keys():
		(_buttons[id] as Button).disabled = busy or not state.ingredient_unlocked(str(id))
	for b in _price_buttons:
		b.disabled = busy
	for slot in ProcessRules.SLOTS:
		for id in ProcessRules.ids(slot):
			var button: Button = _process_buttons[slot + ":" + id]
			button.disabled = busy or state.rank() < int(ProcessRules.method(slot, id)["rank"])
	for b in _selling_buttons:
		if is_instance_valid(b):
			b.disabled = busy
	_new_button.disabled = busy
	_quick_taste_button.disabled = busy
	_quick_taste_button.text = "준비 중…" if _work.is_running() else "시식 · " + _won(state.trial_cost())
	_journal_target.set_busy(busy)
	_journal_map.set_busy(busy)
	_journal_toggle.disabled = busy
	for card in _experiment_cards:
		card.header_button.disabled = busy
	for button in _experiment_buttons:
		button.disabled = busy
	for button in _direction_buttons:
		button.disabled = busy
	_taste_button.disabled = busy
	_taste_button.text = "시식 준비 중…" if _work.is_running() else ("탐색을 먼저 마치세요" if state.exploration_active() else "시식하기")
	_close_button.disabled = _work.is_running()
	_open_button.disabled = _work.is_running() or _contest_left > 0.0 or _training_left > 0.0
	_name_edit.editable = (not busy) and state.draft_lineage_id == 0
	_sync_growth_lock()
	_sync_exploration_lock()


func _refresh_header() -> void:
	_day_label.text = "%d일차" % state.day
	_wallet_label.text = _won(state.wallet)


func _refresh_guide() -> void:
	if state.exploration_active():
		_guide_label.text = "탐색 중에는 메뉴를 바꿀 수 없어요. [탐색]에서 마치거나 포기하세요."
		_open_button.text = "닫고 가게로"
		return
	if not state.pinned_menu_ids().is_empty():
		_guide_label.text = "판매 메뉴 %d종을 고정했어요. [영업]에서 바꿀 수 있어요. 개발·시식 대상은 판매 목록과 별개예요." % state.selling_records().size()
		_open_button.text = "영업하러 가기"
		return
	var selling: Array = state.selling_records()
	var rec: Dictionary = {} if selling.is_empty() else selling[0]
	if state.record_count() == 0:
		_guide_label.text = "처음이에요! ① 재료와 가격을 고르고 ② 이름을 정해 [시식하기]를 누르면 ③ 그 메뉴로 영업할 수 있어요."
		_open_button.text = "닫고 가게로"
	elif rec.is_empty():
		_guide_label.text = "영업할 메뉴가 선택되지 않았어요. [노트]에서 레시피를 불러오거나 새로 시식하세요."
		_open_button.text = "닫고 가게로"
	else:
		_guide_label.text = "영업 메뉴: %s v%d. 재료나 가격을 바꿔 시식하면 새 버전이 영업 메뉴가 돼요." % [str(rec["name"]), int(rec["version"])]
		_open_button.text = "영업하러 가기"


func _refresh_nav() -> void:
	var active: bool = state.service_active()
	_start_button.disabled = _contest_left > 0.0 or _training_left > 0.0
	_speed_button.visible = active
	_speed_button.text = "속도 ×2" if _fast else "속도 ×1"
	_dev_button.text = "메뉴 개발"
	if active:
		var armed: bool = _stop_armed_until != 0 and Time.get_ticks_msec() <= _stop_armed_until
		_start_button.text = "다시 눌러 중단" if armed else "영업 중단"
		return
	if state.exploration_active():
		_start_button.text = "탐색 이어가기"
		return
	var selling: Array = state.selling_records()
	var rec: Dictionary = {} if selling.is_empty() else selling[0]
	if state.record_count() == 0:
		_start_button.text = "첫 메뉴 만들기"
	elif rec.is_empty():
		_start_button.text = "영업 메뉴 고르기"
	else:
		_start_button.text = "%d일차 영업 시작" % state.day


func _refresh_status() -> void:
	if _status_label == null:
		return
	var text: String = ""
	var note: String = ""
	if state.service_active():
		var s: SessionScript = state.active_session()
		var st: Dictionary = s.stats()
		var minute: int = int(st["time"]) / 60
		_clock_label.text = "12:%02d" % minute
		var closing: bool = int(st["time"]) >= SessionScript.SERVICE_SECONDS
		_progress.value = minf(100.0, float(st["time"]) * 100.0 / float(SessionScript.SERVICE_SECONDS))
		var kitchen: String = "조리 중" if bool(st["cooking"]) else "대기"
		var serving: String = "서빙 중" if bool(st["serving"]) else "대기"
		text = "줄 %d · 주방 %s(%d) · 서빙 %s · 완료 %d/%d · 미정산 %s" % [int(st["queue"]), kitchen, int(st["cook_backlog"]), serving, int(st["completed"]), int(st["planned"]), _won(int(st["pending_revenue"]))]
		if closing:
			text += " · 마감 정리"
		note = RUNNING_NOTE
	elif state.exploration_active():
		var trip: Dictionary = state.expedition()
		_clock_label.text = "탐색 중"
		_progress.value = 100.0 * float((trip["path"] as Array).size()) / 2.0
		text = "%s 탐색 · %s · 지불 %s" % [str(trip["region_name"]), "결과 수령 전" if str(trip["stage"]) == Exploration.STAGE_RESULT else "만남 %d/2" % ((trip["path"] as Array).size() + 1), _won(int(trip["fee"]) + int(trip["extra"]))]
		note = "선택할 때 저장해요. 닫았다가 이어갈 수 있어요."
	else:
		_clock_label.text = "영업 전"
		_progress.value = 0.0
		text = _idle_status_text()
		note = NOT_SAVED_NOTE
	if _flash_text != "":
		text = _flash_text
		note = ""
	var combined: String = text + "|" + note
	if combined != _last_status_text:
		_last_status_text = combined
		_status_label.text = text
		_note_label.text = note
		_place_status()
	_refresh_home()


func _refresh_home() -> void:
	if _home == null or _banner == null:
		return
	var phase: String = "영업 준비 · %d종 판매" % state.selling_records().size()
	if state.service_active():
		var stats: Dictionary = state.active_session().stats()
		phase = "완료 %d/%d · 대기 %d명" % [stats["completed"],stats["planned"],stats["queue"]]
	elif state.exploration_active():
		phase = str(state.expedition()["region_name"]) + " 탐색 중"
	elif _flash_text != "":
		phase = "알림 · 눌러서 확인"
	_home.set_context({"rank":state.rank(),"seats":state.seat_count(),"staff":Staffing.BASE_STAFF+state.hired_staff().size(),"staff_limit":state.staff_capacity(),
		"phase":phase,"menus":state.selling_records(),"no_records":state.record_count()==0,"warning":_banner.visible or save_locked,
		"busy":state.service_active() or _work.is_running() or _contest_left>0.0 or _training_left>0.0,
		"has_report":not state.last_report.is_empty(),"save":_banner_label.text if _banner.visible else _save_label.text})


func _idle_status_text() -> String:
	var selling: Array = state.selling_records()
	var rec: Dictionary = {} if selling.is_empty() else selling[0]
	if state.record_count() == 0:
		return "아직 메뉴가 없어요. [첫 메뉴 만들기]를 눌러 재료를 고르고 시식하면 영업할 수 있어요."
	if rec.is_empty():
		return "영업할 메뉴를 고르세요. [영업 메뉴 고르기]에서 노트의 레시피를 불러와요."
	var fc: Dictionary = state.forecast()
	if str(fc["error"]) != "":
		return str(fc["error"])
	if state.shop_expanded():
		return "%d종 판매 · %d석 · 예상 %d그릇 · 공통 운영비 %s" % [selling.size(), state.seat_count(), fc["units"], _won(int(fc["overhead"]))]
	return "오늘 메뉴 %s v%d · %s · 예상 손님 %d명" % [str(rec["name"]), int(rec["version"]), _won(int((rec["config"] as Dictionary)["price"])), int(fc["units"])]


func _next_version(lineage: int) -> int:
	var best: int = 0
	for r in state.records():
		var d: Dictionary = r
		if int(d["lineage_id"]) == lineage:
			best = maxi(best, int(d["version"]))
	return best + 1


## Discovery status is a projection of retained immutable notebook entries.
## Re-evaluating300 recipes on every ingredient tap measured57ms on this Mac;
## cache only the record-derived flags, not draft facts or material availability.
func _recipe_pages() -> Array:
	var records: Array = state.records()
	var key: String = JSON.stringify(records)
	var available: Array[String] = []
	for slot in Catalog.SLOTS:
		for item in Catalog.all_items(slot):
			if state.ingredient_unlocked(str(item["id"])):
				available.append(str(item["id"]))
	if key != _journal_records_key:
		_journal_tested.clear()
		for page in Discovery.pages(records, state.draft_config, available):
			_journal_tested[page["id"]] = bool(page["tested"])
		_journal_records_key = key
	var pages: Array = Discovery.pages([], state.draft_config, available)
	for page in pages:
		page["tested"] = bool(_journal_tested.get(page["id"], false))
	return pages


func _refresh_recipe_target() -> void:
	var sample_check: Dictionary = state.sample_check(state.draft_config)
	_journal_target.present(_recipe_pages(), _journal_target_id, _development_busy(), str(sample_check["error"]))
	var identity: Dictionary = Discovery.describe(state.draft_config)
	_bowl_traits.text = " · ".join((identity["tags"] as Array).slice(0, 3))
	_bowl_caption.text = str(identity["title"]) + "\n원가 %s · 준비 %d초" % [_won(state.trial_cost()), Evaluator.prep_seconds(state.draft_config)]
	var previous: Dictionary = state.get_record(state.selected_record_id)
	if previous.is_empty():
		_draft_change_note.text = "첫 시제품을 시식하면 다음 실험부터 바뀐 맛·원가·준비 시간을 비교할 수 있어요."
		return
	var before: Dictionary = previous["config"]
	var profile: Dictionary = Evaluator.build_profile(state.draft_config)
	var old_profile: Dictionary = Evaluator.build_profile(before)
	var changes: Array[String] = []
	for axis in Catalog.AXES:
		var delta: int = int(profile[axis]) - int(old_profile[axis])
		if delta != 0:
			changes.append("%s %+d" % [Catalog.AXIS_NAMES[axis], delta])
	_draft_change_note.text = "기준 · %s v%d\n%s\n원가 %+d원 · 준비 %+d초 · 판매가 %+d원" % [str(previous["name"]), int(previous["version"]), "맛 축 변화 없음" if changes.is_empty() else " · ".join(changes), Evaluator.unit_cost(state.draft_config) - Evaluator.unit_cost(before), Evaluator.prep_seconds(state.draft_config) - Evaluator.prep_seconds(before), int(state.draft_config["price"]) - int(before["price"])]


func _open_recipe_map() -> void:
	if _work_blocked("연구 목표를 고를"):
		return
	_journal_map_open = true
	tabs.current_tab = TAB_NOTEBOOK
	_refresh_notebook()
	(tabs.get_child(TAB_NOTEBOOK) as ScrollContainer).scroll_vertical = 0


func _toggle_recipe_map() -> void:
	if _work_blocked("연구 지도를 펼칠"):
		return
	_journal_map_open = not _journal_map_open
	_refresh_notebook()


func _select_recipe_target(id: String) -> void:
	if _work_blocked("연구 목표를 바꿀"):
		return
	for page in _recipe_pages():
		if str(page["id"]) == id:
			_journal_target_id = id
			tabs.current_tab = TAB_LAB
			_refresh_lab()
			(tabs.get_child(TAB_LAB) as ScrollContainer).scroll_vertical = 0
			return
	_flash("연구 지도에서 알려진 목표를 골라 주세요.")


func _find_recipe_materials() -> void:
	if _work_blocked("재료를 찾으러 갈"):
		return
	# Navigate only: existing rank, daily departure, money and stock rules apply
	# when the player explicitly starts the trip on the exploration screen.
	tabs.current_tab = TAB_EXPLORATION
	_refresh_exploration()
	(tabs.get_child(TAB_EXPLORATION) as ScrollContainer).scroll_vertical = 0


func _refresh_lab() -> void:
	_quick_taste_notice.text = ""
	_quick_taste_notice.visible = false
	for slot in Catalog.SLOTS:
		# 선택된 재료 id 목록: 토핑은 여러 개일 수 있다(Catalog.toppings_of 하나의 읽기 경로), 나머지는 하나.
		var chosen_ids: Array[String] = []
		if slot == Catalog.TOPPING_SLOT:
			chosen_ids = Catalog.toppings_of(state.draft_config)
		else:
			chosen_ids.append(str(state.draft_config[slot]))
		for item in Catalog.all_items(slot):
			var d: Dictionary = item
			var id: String = str(d["id"])
			var b: Button = _buttons[id]
			b.set_pressed_no_signal(chosen_ids.has(id))
			var locked: bool = not state.ingredient_unlocked(id)
			b.text = "%s\n탐색으로 해금" % str(d.get("short_name", d["name"])) if locked else "%s%s\n%s · %d초" % [str(d.get("short_name", d["name"])), " ×%d" % chosen_ids.count(id) if slot == Catalog.TOPPING_SLOT and chosen_ids.has(id) else "", _won(int(d["cost"])), int(d["seconds"])]
		var hints: Array[String] = []
		for locked_item in state.locked_items(slot):
			var li: Dictionary = locked_item
			hints.append(str(li["name"]) + ": " + str((li["lock"] as Dictionary)["hint"]))
		var hint_label: Label = _discovery_hints[slot]
		hint_label.text = "\n".join(hints)
		hint_label.visible = not hints.is_empty()
		var desc_lines: Array[String] = []
		var described: Array[String] = []
		for cid in chosen_ids:
			if described.has(cid):
				continue
			described.append(cid)
			var sel: Dictionary = Catalog.find(cid)
			desc_lines.append("%s — %s\n비용 %s · 준비 %d초 · %s" % [str(sel["name"]), str(sel["desc"]), _won(int(sel["cost"])), int(sel["seconds"]), Catalog.axes_text(sel)])
			if Catalog.is_farmed(cid):
				desc_lines.append("연구 재료 %d개 보관 · 시제품 완성에 %d개 필요\n판매는 추가 샘플 없이 영업 원가로 공급돼요." % [state.sample_stock(cid), chosen_ids.count(cid)])
		var desc: Label = _desc_labels[slot]
		desc.text = "\n".join(desc_lines)
		var summary: String = Catalog.topping_names(state.draft_config) if slot == Catalog.TOPPING_SLOT else str(Catalog.find(chosen_ids[0])["name"])
		if slot == Catalog.TOPPING_SLOT:
			summary += " · %d/%d칸" % [chosen_ids.size(), state.topping_slots()]
		(_ingredient_sections[slot] as DetailsScript).configure(str(Catalog.SLOT_NAMES[slot]), summary, _icon(chosen_ids[0], 2))
	var slots: int = state.topping_slots()
	var portions := Catalog.toppings_of(state.draft_config)
	_topping_count.text = "가게 등급 %d · 토핑 %d/%d칸" % [state.rank(), portions.size(), slots]
	_topping_hint.text = "재료를 누르면 한 칸 추가해요. 같은 재료도 여러 칸 가능!
교체는 칸을 먼저 고르고, 빼기는 [−]. 최소 1개, 최대 %d개. %s" % [slots, Growth.topping_unlock_hint(state.rank(), state.facilities_owned())]
	_clear(_topping_positions)
	for index in Catalog.MAX_TOPPINGS:
		var occupied: bool = index < portions.size()
		var title := str(Catalog.find(portions[index])["name"]) if occupied else "빈 칸 +"
		if index >= slots:
			title = "등급 %d 해금" % index
		var row := HBoxContainer.new()
		var position_button := _button(("교체: " if _selected_topping_position == index else "") + title, "ToppingSlot_" + str(index))
		position_button.custom_minimum_size.x = 116
		position_button.add_theme_font_size_override("font_size", 14)
		position_button.disabled = index >= slots or work_active() or state.service_active() or state.exploration_active() or _training_left > 0.0 or _contest_left > 0.0
		position_button.pressed.connect(_select_topping_position.bind(index))
		row.add_child(position_button)
		if occupied:
			var remove := _button("−", "RemoveTopping_" + str(index))
			remove.custom_minimum_size.x = MIN_TOUCH
			remove.disabled = position_button.disabled
			remove.pressed.connect(_remove_topping_position.bind(index))
			row.add_child(remove)
		_topping_positions.add_child(row)

	if _name_edit.text != state.draft_name:
		_name_edit.text = state.draft_name
	if state.draft_lineage_id == 0:
		_mode_label.text = "새 레시피로 기록돼요."
	else:
		_mode_label.text = "개정 중: 같은 이름의 v%d로 기록되고 이전 버전과 비교해 드려요." % _next_version(state.draft_lineage_id)

	var price: int = int(state.draft_config["price"])
	var cost: int = Evaluator.unit_cost(state.draft_config)
	var prep: int = Evaluator.prep_seconds(state.draft_config)
	_price_label.text = "%s (그릇당 마진 %s)" % [_won(price), _won(price - cost)]

	var profile: Dictionary = Evaluator.build_profile(state.draft_config)
	_flavor_details.configure("맛 실험대", "진함 %d · 향 %d · 매운맛 %d" % [profile["rich"], profile["aroma"], profile["spice"]], ArtScript.scaled_tex(ArtScript.bowl_image(state.draft_config), 2))
	for axis in Catalog.AXES:
		(_flavor_bars[axis] as ProgressBar).value = profile[axis]
		(_flavor_labels[axis] as Label).text = "%s %d/10" % [Catalog.AXIS_NAMES[axis], profile[axis]]
	var combinations := Evaluator.applied_compat(state.draft_config)
	_experiment_note.text = "재료를 바꿔 맛의 균형을 찾아보세요. 많이 넣는다고 모두 좋아하진 않아요." if combinations.is_empty() else str(combinations[-1]["note"])
	var parts: Array[String] = []
	for axis in Catalog.AXES:
		parts.append("%s %d" % [str(Catalog.AXIS_NAMES[axis]), int(profile[axis])])
	_profile_label.text = "맛 프로필(0~10): " + " · ".join(parts) + "\n원가 %s · 준비 %d초\n시식하면 시제품 재료비 %s가 자금에서 빠져요." % [_won(cost), prep, _won(cost)]
	var staffed_prep: int = Staffing.effective_prep(prep, state.current_staffing())
	_refresh_process_controls()
	if state.draft_config.has("process"):
		_profile_label.text += "\n공법: " + ProcessRules.summary(state.draft_config["process"]) + "\n제조·시식 연출 약 %.1f초 (영업 조리시간과 별개)" % float(ProcessRules.effects(state.draft_config["process"])["work_seconds"])
	if staffed_prep != prep:
		_profile_label.text += "\n영업 중 실제 준비 %d초 (조리 보조 효과, 맛 점수는 그대로)" % staffed_prep
	var applied: Array = Evaluator.applied_compat(state.draft_config)
	var lines: Array[String] = []
	for a in applied:
		var ad: Dictionary = a
		lines.append("%s %s" % ["+%d" % int(ad["score"]) if int(ad["score"]) > 0 else str(int(ad["score"])), str(ad["note"])])
	_compat_label.text = "재료 궁합 메모\n" + "\n".join(lines) if not lines.is_empty() else "재료 궁합 메모: 특별히 눈에 띄는 조합은 없어요."
	# 시식 버튼 글/이름 입력/재료 버튼의 켜짐은 시식 준비 상태에 따라 한곳에서 정한다.
	_apply_work_lock()

	_bowl_rect.texture = ArtScript.scaled_tex(ArtScript.recipe_bowl_image(state.draft_config), 4)
	_bowl_caption.text = "%s\n원가 %s · 준비 %d초 · 판매가 %s" % [state.draft_name, _won(cost), prep, _won(price)]
	_refresh_recipe_target()
	_refresh_directions()


func _refresh_feedback() -> void:
	_experiment_cards.clear()
	_experiment_buttons.clear()
	_clear(_feedback_box)
	var rec: Dictionary = state.get_record(state.last_feedback_record_id)
	if rec.is_empty():
		var empty: PanelContainer = _card("EmptyFeedbackCard")
		empty.add_child(_label("아직 시식한 레시피가 없어요. '개발' 탭에서 재료를 고르고 시식해 보세요. 손님 세 분의 솔직한 반응을 들려드려요.", 16, INK))
		_feedback_box.add_child(empty)
		return
	var config: Dictionary = rec["config"]
	var evaluation: Dictionary = Evaluator.evaluate(config)

	var title_card: PanelContainer = _card("FeedbackTitleCard")
	var tcb: VBoxContainer = _vbox(4)
	title_card.add_child(tcb)
	var bowl := TextureRect.new()
	bowl.name = "FeedbackBowl"
	bowl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bowl.texture = ArtScript.scaled_tex(ArtScript.recipe_bowl_image(rec["config"]), 4)
	bowl.custom_minimum_size = Vector2(192, 128)
	bowl.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	bowl.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	tcb.add_child(bowl)
	tcb.add_child(_label("시제품 완성!", 22, TEAL))
	var actual_directions: Array[String] = []
	for definition in Directions.catalog():
		if Directions.assess(definition["id"], config)["matched"]:
			actual_directions.append(str(definition["title"]))
	if not actual_directions.is_empty():
		var result_direction := _label("새로운 맛 발견!\n" + " / ".join(_direction_new_titles) if _direction_new_record == int(rec["record_id"]) and not _direction_new_titles.is_empty() else "이 그릇의 방향 · " + " / ".join(actual_directions), 20, TEAL)
		result_direction.name = "DirectionResult"
		tcb.add_child(result_direction)
	var title: Label = _label("%s v%d" % [str(rec["name"]), int(rec["version"])], 24, VERMILION)
	title.name = "FeedbackTitle"
	tcb.add_child(title)
	tcb.add_child(_label("평균 %d점 · 판매가 %s · 원가 %s · 준비 %d초" % [int(evaluation["average_score"]), _won(int(config["price"])), _won(int(evaluation["unit_cost"])), int(evaluation["prep_seconds"])], 15, MUTED))
	# Food/result facts lead; the complete receipt remains one recognizable
	# disclosure deeper, instead of repeating every ingredient above reactions.
	var recipe_receipt := DetailsScript.new()
	recipe_receipt.name = "ResultRecipeDetails"
	recipe_receipt.configure("재료와 공법", "토핑 %d분량 · 구성 펼쳐 보기" % Catalog.toppings_of(config).size(), _icon(str(config["broth"]), 2))
	tcb.add_child(recipe_receipt)
	var tops_label: Label = _label("토핑 %d개: %s" % [Catalog.toppings_of(config).size(), Catalog.topping_names(config)], 14, MUTED)
	tops_label.name = "FeedbackToppings"
	recipe_receipt.body.add_child(tops_label)
	var ingredients: Array[String] = []
	for slot in Catalog.SLOTS:
		if slot != Catalog.TOPPING_SLOT:
			ingredients.append(str(Catalog.find(str(config[slot]))["name"]))
	var recipe_details: Label = _label(" · ".join(ingredients), 14, MUTED)
	recipe_details.name = "FeedbackRecipeDetails"
	recipe_receipt.body.add_child(recipe_details)
	if config.has("process"):
		var method_label: Label = _label("제조: " + ProcessRules.summary(config["process"]), 15, TEAL)
		method_label.name = "FeedbackProcess"
		recipe_receipt.body.add_child(method_label)
	var identity: Dictionary = Discovery.describe(config)
	var identity_label := _label(str(identity["title"]), 16, INK)
	identity_label.name = "FeedbackIdentity"
	recipe_receipt.body.add_child(identity_label)
	if _journal_new_record_id == int(rec["record_id"]) and not _journal_new_titles.is_empty():
		var discovery_label := _label("", 16, TEAL)
		discovery_label.name = "NewRecipeThemes"
		discovery_label.text = "새 연구 수록 · " + " / ".join(_journal_new_titles)
		tcb.add_child(discovery_label)
	var next_experiment := _button("다음 한 그릇 구상하기", "DirectionNextExperiment")
	next_experiment.pressed.connect(_open_direction_board)
	_experiment_buttons.append(next_experiment)
	tcb.add_child(next_experiment)
	_feedback_box.add_child(title_card)

	for c in evaluation["customers"]:
		var cd: Dictionary = c
		_feedback_box.add_child(_customer_card(cd))
	_build_experiment_clues(rec)
	_feedback_box.add_child(_comparison_card(rec, evaluation))


## These read-only alternatives are based on the actual tasted record, not the
## possibly edited draft. Rebuilding feedback never performs a recipe edit or
## tasting transaction. The ordinary evaluator owns every displayed delta.
func _build_experiment_clues(rec: Dictionary) -> void:
	var available: Array[String] = []
	for slot in Catalog.SLOTS:
		for item in Catalog.all_items(slot):
			if state.ingredient_unlocked(str(item["id"])):
				available.append(str(item["id"]))
	var result: Dictionary = Experiments.clues(rec["config"], available, state.rank())
	if str(result["error"]) != "":
		_feedback_box.add_child(_label(str(result["error"]), 15, VERMILION))
		return
	var intro: Label = _label("다음 실험의 단서\n%s v%d에서 한 가지만 바꿔보기 · 좋은 맛의 정답은 손님마다 달라요." % [rec["name"], rec["version"]], 16, TEAL)
	intro.name = "ExperimentCluesIntro"
	_feedback_box.add_child(intro)
	if (result["clues"] as Array).is_empty():
		_feedback_box.add_child(_label("지금 재료로 향·식감을 더 높이거나 준비를 줄일 단서는 없어요. 연구 지도에서 다른 방향을 찾아보세요.", 15, MUTED))
	for data in result["clues"]:
		var clue: Dictionary = data
		var direction: String = str(clue["direction"])
		var card := DetailsScript.new()
		card.name = "ExperimentClue_" + direction
		_feedback_box.add_child(card)
		_experiment_cards.append(card)
		card.configure(str(clue["title"]), str(clue["change"]), ArtScript.scaled_tex(ArtScript.recipe_bowl_image(clue["config"]), 1))
		var pair := HBoxContainer.new()
		pair.name = "ExperimentPair_" + direction
		pair.mouse_filter = Control.MOUSE_FILTER_PASS
		card.body.add_child(pair)
		for variant in 2:
			var column := _vbox(3)
			column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			pair.add_child(column)
			column.add_child(_label("이번 시제품" if variant == 0 else "한 가지 바꾸면", 14, MUTED))
			var dish := TextureRect.new()
			dish.name = ("ExperimentBefore_" if variant == 0 else "ExperimentAfter_") + direction
			dish.mouse_filter = Control.MOUSE_FILTER_IGNORE
			dish.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			dish.custom_minimum_size = Vector2(90, 64)
			dish.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			dish.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			dish.texture = ArtScript.scaled_tex(ArtScript.recipe_bowl_image(rec["config"] if variant == 0 else clue["config"]), 2)
			column.add_child(dish)
		var change: Label = _label("", 15, INK)
		change.name = "ExperimentDelta_" + direction
		change.text = "예상 변화 · %s\n원가 %+d원 · 준비 %+d초\n판매가와 토핑 칸 수는 그대로예요." % [clue["flavor_text"], clue["cost_delta"], clue["seconds_delta"]]
		card.body.add_child(change)
		var sample: Dictionary = state.sample_check(clue["config"])
		var notice: Label = _label("직접 재료를 골라 시식해야 결과가 기록돼요. 손님 점수 상승을 보장하지 않아요." if str(sample["error"]) == "" else "다음 시제품의 샘플 부족 · " + str(sample["error"]), 14, MUTED if str(sample["error"]) == "" else VERMILION)
		notice.name = "ExperimentStock_" + direction
		card.body.add_child(notice)
		var go: Button = _button("선택 화면에서 살펴보기", "ExperimentGo_" + direction)
		go.disabled = _development_busy()
		go.pressed.connect(_open_experiment_choices.bind(str(clue["slot"])))
		card.body.add_child(go)
		_experiment_buttons.append(go)


func _open_experiment_choices(slot: String) -> void:
	if _work_blocked("실험 재료를 살펴볼"):
		return
	# Merely reveal the relevant existing controls. Do not replace unsaved draft
	# edits, select a record, spend samples or persist any presentation state.
	tabs.current_tab = TAB_LAB
	var card := find_child("Section_" + slot, true, false) as DetailsScript
	if card == null:
		_flash("이 실험에 해당하는 재료 선택 화면을 찾지 못했어요.")
		return
	card.set_expanded(true)
	_taste_message.text = "시식한 메뉴에서 얻은 단서예요. 현재 초안은 유지했어요. 재료·공법을 직접 골라 실험해 보세요."
	await get_tree().process_frame
	(tabs.get_child(TAB_LAB) as ScrollContainer).ensure_control_visible(card.header_button)


func _customer_card(cd: Dictionary) -> PanelContainer:
	var card: PanelContainer = _card("Card_" + str(cd["id"]))
	# 카드 한 장이 서랍 스크롤 영역(세로 휴대폰에서 가장 작음) 안에 통째로 들어오도록 여백을 줄였다.
	card.add_theme_stylebox_override("panel", _box(PAPER_LIGHT, LINE, 2, 0, 10.0, 6.0))
	# 윗줄 = 왼쪽 48x48 초상(24x24 도트 x2) + 오른쪽(이름·별·점수, 소개). 본문(헤드라인/이유)은 카드 전체 폭을 써서
	# 초상 때문에 줄 수가 늘지 않는다. 초상은 고정 크기라 이름/점수 칸을 줄이지 않는다.
	var cb: VBoxContainer = _vbox(2)
	card.add_child(cb)
	var head: HBoxContainer = HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	cb.add_child(head)
	var portrait: TextureRect = TextureRect.new()
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait.name = "Portrait_" + str(cd["id"])
	portrait.texture = _portrait_tex(str(cd["id"]), 2)
	portrait.stretch_mode = TextureRect.STRETCH_KEEP
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	portrait.custom_minimum_size = Vector2(48.0, 48.0)
	portrait.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	portrait.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	head.add_child(portrait)
	var side: VBoxContainer = _vbox(2)
	head.add_child(side)
	# 이름·별·점수를 한 줄에 둬 손님 식별과 평가를 먼저 보여 준다.
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var name_label: Label = _label(str(cd["name"]), 19, VERMILION)
	# 이름은 한 줄로(이름이 길면 별/점수 폭을 뺀 나머지에서 줄어든다). 점수 칸은 아래에서 글자 폭만큼 보장한다.
	name_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	row.add_child(name_label)
	var meter: StarMeterScript = StarMeterScript.new()
	# Decorative ratings never intercept the surrounding page swipe.
	meter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	meter.name = "Stars_" + str(cd["id"])
	meter.stars = int(cd["stars"])
	meter.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(meter)
	var score: Label = _label("%d점" % int(cd["score"]), 17, INK)
	score.name = "Score_" + str(cd["id"])
	# 점수는 줄바꿈 없이 한 줄: 자동 줄바꿈 라벨은 최소 폭이 거의 0 이라 "71점"이 세로로 쪼개졌다.
	score.autowrap_mode = TextServer.AUTOWRAP_OFF
	score.size_flags_horizontal = Control.SIZE_SHRINK_END
	score.custom_minimum_size = Vector2(score.get_theme_font("font").get_string_size(score.text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 17).x + 4.0, 0.0)
	row.add_child(score)
	side.add_child(row)
	side.add_child(_label(str(cd["persona"]), 13, MUTED))
	var headline: Label = _label(str(cd["headline"]), 17, INK)
	headline.name = "Headline_" + str(cd["id"])
	cb.add_child(headline)
	for r in cd["reasons"]:
		cb.add_child(_label("· " + str(r), 14, INK))
	cb.add_child(_label(str(cd["value_note"]), 13, TEAL))
	return card


func _comparison_card(rec: Dictionary, evaluation: Dictionary) -> PanelContainer:
	var card: PanelContainer = _card("ComparisonPanel")
	var cb: VBoxContainer = _vbox(6)
	card.add_child(cb)
	cb.add_child(_label("이전 버전과 비교", 20, VERMILION))
	var body: Label = _label("", 15, INK)
	body.name = "ComparisonLabel"
	cb.add_child(body)
	var cmp: Dictionary = rec["comparison"]
	if cmp.is_empty():
		body.text = "첫 시식이라 비교할 이전 버전이 없어요. 재료나 가격을 바꿔 다시 시식하면 v2와 비교해 드려요."
		return card
	var prev_cfg: Dictionary = cmp["prev_config"]
	var prev_scores: Dictionary = cmp["prev_scores"]
	var cfg: Dictionary = rec["config"]
	var lines: Array[String] = ["v%d → v%d" % [int(cmp["prev_version"]), int(rec["version"])]]
	var changes: Array[String] = []
	for slot in Catalog.SLOTS:
		if slot == Catalog.TOPPING_SLOT:
			# 토핑은 여러 개일 수 있어 종류별 분량을 비교한다(카탈로그 순서로 정규화돼 있어 순서만 다른 경우는 "바뀐 점"이 아니다).
			if str(Catalog.toppings_of(prev_cfg)) != str(Catalog.toppings_of(cfg)):
				changes.append("%s: %s → %s" % [str(Catalog.SLOT_NAMES[slot]), Catalog.topping_names(prev_cfg), Catalog.topping_names(cfg)])
		elif str(prev_cfg[slot]) != str(cfg[slot]):
			var old_item: Dictionary = Catalog.find(str(prev_cfg[slot]))
			var new_item: Dictionary = Catalog.find(str(cfg[slot]))
			changes.append("%s: %s → %s" % [str(Catalog.SLOT_NAMES[slot]), str(old_item["name"]), str(new_item["name"])])
	if int(prev_cfg["price"]) != int(cfg["price"]):
		changes.append("가격: %s → %s" % [_won(int(prev_cfg["price"])), _won(int(cfg["price"]))])
	if prev_cfg.get("process", {}) != cfg.get("process", {}):
		changes.append("제조: %s → %s" % [ProcessRules.summary(prev_cfg.get("process", {})), ProcessRules.summary(cfg.get("process", {}))])
	lines.append("바뀐 점 — " + ", ".join(changes))
	var up: int = 0
	var down: int = 0
	var prev_sum: int = 0
	for c in evaluation["customers"]:
		var cd: Dictionary = c
		var before: int = int(prev_scores[str(cd["id"])])
		var after: int = int(cd["score"])
		prev_sum += before
		if after > before:
			up += 1
		elif after < before:
			down += 1
		lines.append("%s: %d점 → %d점 (%+d)" % [str(cd["name"]), before, after, after - before])
	var prev_avg: int = roundi(float(prev_sum) / 3.0)
	lines.append("평균: %d점 → %d점 (%+d)" % [prev_avg, int(evaluation["average_score"]), int(evaluation["average_score"]) - prev_avg])
	var prev_cost: int = Evaluator.unit_cost(prev_cfg)
	var prev_prep: int = Evaluator.prep_seconds(prev_cfg)
	lines.append("원가: %s → %s · 준비 시간: %d초 → %d초" % [_won(prev_cost), _won(int(evaluation["unit_cost"])), prev_prep, int(evaluation["prep_seconds"])])
	lines.append("%d명이 더 만족하고 %d명이 덜 만족해요." % [up, down])
	body.text = "\n".join(lines)
	return card


func _refresh_notebook() -> void:
	_journal_map.visible = _journal_map_open
	_journal_toggle.text = "연구 지도 접기" if _journal_map_open else "연구 지도 펼치기"
	if _journal_map_open:
		_journal_map.present(_recipe_pages(), _journal_target_id, _development_busy())
	_clear(_notebook_box)
	var all_records: Array = state.records()
	var cap: int = state.menu_capacity()
	var menus: int = state.menu_count()
	_notebook_count.text = "등록 메뉴 %d/%d종 · 개정 이력 %d/%d" % [menus, cap, all_records.size(), state.record_history_capacity()]
	var note: String = "같은 메뉴의 개정은 등록 자리를 더 쓰지 않아요. 동시에 파는 메뉴 칸은 별개이며 [영업]에서 고정해요(기본1종, 증축 후2종). 기록을 지워도 최고 시식 성적은 유지돼요."
	if menus > cap:
		note += "\n예전 메뉴를 모두 보관 중이에요. 기존 메뉴 개정과 영업은 가능해요. 새 종류는 조리대 확장 또는 한 메뉴의 모든 개정본 정리 후 추가하세요."
	elif cap < GameStateScript.MAX_MENUS:
		var nxt: Dictionary = Growth.facility_review("bench_1" if not state.facilities_owned().has("bench_1") else "bench_2", state.rank(), state.facilities_owned(), state.wallet)
		note += "\n다음 확장 「%s」(%s)으로 늘려요: %s" % [str(nxt["name"]), str(nxt["price_text"]), str(nxt["effect_text"])]
	if all_records.size() >= state.record_history_capacity():
		note += "\n실험 이력 보관함이 가득 찼어요. 필요 없는 개정본을 직접 정리해야 시식할 수 있어요. 자동 삭제는 하지 않아요."
	_notebook_note.text = note
	if all_records.is_empty():
		var empty: PanelContainer = _card("EmptyNotebookCard")
		empty.add_child(_label("노트가 비어 있어요. 시식한 레시피가 이곳에 기록돼요.", 16, INK))
		_notebook_box.add_child(empty)
		return
	# Only materialize a bounded page of rows, rather than300 complex mobile cards.
	var pages: int = maxi(1, (all_records.size() + NOTEBOOK_PAGE_SIZE - 1) / NOTEBOOK_PAGE_SIZE)
	_notebook_page = clampi(_notebook_page, 0, pages - 1)
	if pages > 1:
		var pager: HBoxContainer = HBoxContainer.new()
		pager.name = "NotebookPager"
		var newer: Button = _button("더 최근 기록", "NotebookNewer")
		var older: Button = _button("더 오래된 기록", "NotebookOlder")
		for button in [newer, older]:
			button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			button.custom_minimum_size = Vector2(0.0, 48.0)
		newer.disabled = _notebook_page == 0
		older.disabled = _notebook_page == pages - 1
		newer.pressed.connect(_on_notebook_page.bind(-1))
		older.pressed.connect(_on_notebook_page.bind(1))
		pager.add_child(newer)
		pager.add_child(older)
		_notebook_box.add_child(_label("개정 이력 %d/%d쪽 · 최신 순" % [_notebook_page + 1, pages], 14, MUTED))
		_notebook_box.add_child(pager)
	var first: int = all_records.size() - 1 - _notebook_page * NOTEBOOK_PAGE_SIZE
	for i in range(first, maxi(-1, first - NOTEBOOK_PAGE_SIZE), -1):
		var rec: Dictionary = all_records[i]
		_notebook_box.add_child(_notebook_row(rec))


func _on_notebook_page(offset: int) -> void:
	_notebook_page += offset
	_refresh_notebook()


func _notebook_row(rec: Dictionary) -> PanelContainer:
	var id: int = int(rec["record_id"])
	var cfg: Dictionary = rec["config"]
	var scores: Dictionary = rec["scores"]
	var row: PanelContainer = _card("Row_%d" % id)
	var rb: VBoxContainer = _vbox(6)
	row.add_child(rb)
	var selected: bool = id == state.selected_record_id
	var title: String = "%s v%d" % [str(rec["name"]), int(rec["version"])]
	if selected:
		title += " · 개발·시식 대상"
	rb.add_child(_label(title, 20, TEAL if selected else VERMILION))
	# 선택한 재료 전부(토핑 포함)를 이름으로 보여 준다.
	var names: Array[String] = []
	for iid in Catalog.item_ids(cfg):
		var item: Dictionary = Catalog.find(iid)
		names.append(str(item["name"]))
	rb.add_child(_label(" · ".join(names), 14, MUTED))
	if cfg.has("process"):
		var method_label: Label = _label("제조: " + ProcessRules.summary(cfg["process"]), 14, TEAL)
		method_label.name = "RecordProcess_%d" % id
		rb.add_child(method_label)
	var ratings: Array[String] = []
	for c in Customers.all():
		var cd: Dictionary = c
		ratings.append("%s %d/5" % [str(cd["name"]), Evaluator.stars_for(int(scores[str(cd["id"])]))])
	rb.add_child(_label(" · ".join(ratings) + "\n판매가 " + _won(int(cfg["price"])) + " · " + "%d일차 시식" % int(rec["tasted_day"]), 15, INK))
	var buttons: HBoxContainer = HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 8)
	var sel_btn: Button = _button("불러오기", "SelectRecord_%d" % id)
	sel_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sel_btn.pressed.connect(_on_select_record.bind(id))
	sel_btn.disabled = _work.is_running()
	buttons.add_child(sel_btn)
	var del_text: String = "한 번 더 눌러 삭제" if id == _pending_delete_id else "삭제"
	var del_btn: Button = _button(del_text, "DeleteRecord_%d" % id)
	del_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	del_btn.pressed.connect(_on_delete_record.bind(id))
	del_btn.disabled = _work.is_running()
	buttons.add_child(del_btn)
	rb.add_child(buttons)
	return row


func _refresh_serve() -> void:
	_last_report_button.disabled=state.last_report.is_empty() or _development_busy()
	_last_report_button.text="아직 마친 영업이 없어요" if state.last_report.is_empty() else "%d일차 영업 결과 보기" % int(state.last_report["day"])
	_serve_intro.text = "영업은 가게 화면의 [영업 시작]으로 해요. 한 번은 점심 피크 %d분(게임 시간)이고 손님이 도착해 자리에 앉고 주문·조리·서빙·식사를 마친 만큼만 정산돼요. 운영비 %s는 하루마다 들어요.\n지금: %d일차 · 보유 자금 %s\n%s" % [Sim.SERVICE_SECONDS / 60, _won(Sim.overhead_for(state.current_staffing())), state.day, _won(state.wallet), NOT_SAVED_NOTE]
	_refresh_selling()
	var selling: Array = state.selling_records()
	var rec: Dictionary = {} if selling.is_empty() else selling[0]
	if rec.is_empty():
		_serve_menu.text = "'노트' 탭에서 영업할 레시피를 불러오세요."
		_serve_forecast.text = ""
	else:
		var cfg: Dictionary = rec["config"]
		_serve_menu.text = "%s v%d · 판매가 %s · 원가 %s · 준비 %d초\n토핑: %s" % [str(rec["name"]), int(rec["version"]), _won(int(cfg["price"])), _won(Evaluator.unit_cost(cfg)), Evaluator.prep_seconds(cfg), Catalog.topping_names(cfg)]
		var staffed: int = Staffing.effective_prep(Evaluator.prep_seconds(cfg), state.current_staffing())
		if staffed != Evaluator.prep_seconds(cfg):
			_serve_menu.text += "\n영업 중 실제 준비 %d초 (조리 보조)" % staffed
		if selling.size() == 2:
			var second: Dictionary = selling[1]
			_serve_menu.text += "\n함께 판매: %s v%d · %s" % [second["name"], second["version"], _won(int(second["config"]["price"]))]
		var fc: Dictionary = state.forecast()
		if str(fc["error"]) != "":
			_serve_forecast.text = str(fc["error"])
		else:
			_serve_forecast.text = _forecast_text(fc)
	if state.last_report.is_empty():
		_report_label.text = "아직 영업한 날이 없어요."
	else:
		_report_label.text = _report_text(state.last_report)


func _refresh_selling() -> void:
	_selling_buttons.clear()
	_clear(_selling_box)
	var header: Label = _label("판매 메뉴 %d/%d종 · 좌석 %d석" % [state.selling_records().size(), state.selling_capacity(), state.seat_count()], 18, VERMILION)
	header.name = "SellingHeader"
	_selling_box.add_child(header)
	_selling_box.add_child(_label("목록을 고정하면 개발·시식 메뉴를 바꿔도 계속 팔아요. 목록을 모두 빼면 선택한 시식 기록을 자동 판매해요. 두 메뉴는 손님·주방 시간을 공유해요.", 14, MUTED))
	var auto: Button = _button("선택 기록 자동 판매로 돌아가기", "SellingAuto")
	auto.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	auto.pressed.connect(_on_selling_auto)
	_selling_box.add_child(auto)
	_selling_buttons.append(auto)
	var effective: Array = []
	for rec in state.selling_records():
		effective.append(int(rec["record_id"]))
	for rec in state.records():
		var id: int = int(rec["record_id"])
		var row: PanelContainer = _card("SellingRow_%d" % id)
		var col: VBoxContainer = _vbox(5)
		row.add_child(col)
		var label: Label = _label("%s v%d · %s%s" % [rec["name"], rec["version"], _won(int(rec["config"]["price"])), " · 판매 중" if effective.has(id) else ""], 15, INK)
		label.name = "SellingTitle_%d" % id
		col.add_child(label)
		var pinned: Array = state.pinned_menu_ids()
		var text: String = "판매 목록에 추가"
		if pinned.has(id):
			text = "판매에서 빼기"
		elif state.selling_capacity() == 1 or (pinned.is_empty() and effective.has(id)):
			text = "이 메뉴로 판매 고정"
		var button: Button = _button(text, "SellingToggle_%d" % id)
		button.pressed.connect(_on_selling_toggle.bind(id))
		col.add_child(button)
		_selling_buttons.append(button)
		_selling_box.add_child(row)


func _refresh_research() -> void:
	if _research_box == null:
		return
	if _story_mode:
		_refresh_stories()
		return
	var done: Array = state.research_completed_ids()
	var stage: Dictionary = state.research_stage()
	_research_summary.text = "연구 점수 %d점 · 완료 %d/%d · %s (%d/%d단계)" % [state.research_points(), done.size(), Research.REQUESTS.size(), str(stage["title"]), int(stage["stage"]), int(stage["stages"])]
	var rec: Dictionary = state.get_record(state.selected_record_id)
	if rec.is_empty():
		_research_target.text = "제출할 기록이 없어요. 시식하거나 [노트]에서 시식한 레시피를 불러오면 그 기록이 제출 대상이 돼요. 시식하지 않은 초안은 제출할 수 없어요."
	else:
		_research_target.text = "제출 대상: %s v%d (%d일차 시식 기록). 개발 탭에서 고치는 중인 초안이 아니라, 이 기록의 시식 당시 구성이 심사돼요." % [str(rec["name"]), int(rec["version"]), int(rec["tasted_day"])]
	_clear(_research_box)
	if state.research_complete():
		var fin: PanelContainer = _card("ResearchChapterDone")
		fin.add_child(_label("연구 과정 완료! 세 분의 의뢰를 모두 해결해 「%s」가 됐어요. 이번 단계에는 더 이상 새 의뢰가 없어요." % str(stage["title"]), 17, TEAL))
		_research_box.add_child(fin)
	for r in Research.REQUESTS:
		var req: Dictionary = r
		_research_box.add_child(_research_card(req, rec))


func _on_research_mode(stories: bool) -> void:
	_story_mode = stories
	_story_armed = ""
	_story_armed_until = 0
	_research_message.text = _unsaved_notice("") if stories else ""
	_refresh_research()
	(tabs.get_child(TAB_RESEARCH) as ScrollContainer).scroll_vertical = 0


func _on_story_choice(customer: String, route: String) -> void:
	if _work_blocked("이야기를 시작할"):
		return
	var key: String = customer + ":" + route
	if _story_armed != key or Time.get_ticks_msec() > _story_armed_until:
		_story_armed = key
		_story_armed_until = Time.get_ticks_msec() + 6000
		_research_message.text = _unsaved_notice("이번 사연의 방향은 선택 후 바꿀 수 없어요. 같은 버튼을6초 안에 다시 누르면 확정해요. 비용은 없어요.")
		_refresh_research()
		return
	_story_armed = ""
	_story_armed_until = 0
	_story_result(state.start_story(customer, route))


func _on_story_complete(customer: String) -> void:
	if _work_blocked("단골과 대화할"):
		return
	_story_result(state.complete_story(customer, state.selected_record_id))


## UI 성공 안내는 실제 저장 결과를 포함한다. 거래를 재호출해 저장 실패를 보상하지 않는다.
func _story_result(result: Dictionary) -> void:
	var text: String = str(result["message"])
	var saved: bool = false
	if bool(result["ok"]):
		saved = _persist()
		text += " 저장했어요." if saved else " 저장하지 못했어요: " + _last_save_message + " 수동 저장 후 닫아 주세요."
	else:
		text = _unsaved_notice(text)
	_refresh_all()
	_research_message.text = text
	_research_message.add_theme_color_override("font_color", TEAL if saved else VERMILION)


## 거부/화면 전환 같은 부수 조작이 미저장 거래의 경고를 가리지 않게 한다.
func _unsaved_notice(text: String) -> String:
	return text + ("\n아직 저장하지 못했어요: " + _last_save_message + " 수동 저장 후 닫아 주세요." if _save_error_shown else "")


func _on_story_history(customer: String) -> void:
	_story_history[customer] = not bool(_story_history.get(customer, false))
	_refresh_stories()


func _refresh_stories() -> void:
	var finished: int = 0
	for arc in state.story_arcs():
		finished += arc["receipts"].size()
	_research_summary.text = "단골 이야기 · 대접 %d/6 · 세 사람의 두 가지 요리 방향" % finished
	_research_target.text = "방향 선택 → 메뉴 시식 → 실제 영업에서 그 손님에게 대접 → 이야기 마치기. 시식만으로는 완료되지 않아요. 두 번째 장에는 첫 답례 이후 새로 시식한 다른 구성과 새 영업이 필요해요."
	_clear(_research_box)
	for customer in StoryCatalog.ids():
		_research_box.add_child(_story_card(customer))


func _story_card(customer: String) -> PanelContainer:
	var definition: Dictionary = StoryCatalog.story(customer)
	var arc: Dictionary = state.story_arc(customer)
	var card: PanelContainer = _card("Story_" + customer)
	var box: VBoxContainer = _vbox(6)
	card.add_child(box)
	var header: HBoxContainer = HBoxContainer.new()
	var face: TextureRect = TextureRect.new()
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	face.texture = _portrait_tex(customer, 2)
	face.custom_minimum_size = Vector2(48, 48)
	face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	header.add_child(face)
	var title: Label = _label(Customers.find(customer)["name"] + " · " + definition["title"], 18, VERMILION)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	box.add_child(header)
	if arc.is_empty():
		box.add_child(_label(definition["opening"], 15, INK))
		box.add_child(_label("무료 선택 · 첫 영업 후 열림 · 확정하면 이번 사연의 방향 고정", 14, TEAL))
		for route in definition["routes"]:
			var key: String = customer + ":" + str(route["id"])
			var button: Button = _button(("확정: " if _story_armed == key else "선택: ") + str(route["label"]), "StoryChoice_" + customer + "_" + str(route["id"]))
			button.disabled = state.day < 2 or state.service_active() or state.exploration_active() or _work.is_running() or _training_left > 0 or _contest_left > 0
			button.pressed.connect(_on_story_choice.bind(customer, str(route["id"])))
			box.add_child(button)
		return card
	var route: Dictionary = StoryCatalog.route(customer, arc["route"])
	var chapter: int = arc["receipts"].size()
	box.add_child(_label("선택: " + str(route["label"]) + " · 완료 %d/2" % chapter, 15, TEAL))
	if chapter < 2:
		var current: Dictionary = StoryCatalog.chapter(customer, arc["route"], chapter)
		box.add_child(_label("%d장 · %s" % [chapter + 1, current["title"]], 17, VERMILION))
		box.add_child(_label(current["dialogue"], 15, INK))
		var rec: Dictionary = state.get_record(state.selected_record_id)
		box.add_child(_label("대접 대상: " + ("노트에서 시식한 메뉴를 골라 주세요." if rec.is_empty() else "%s v%d" % [rec["name"],rec["version"]]), 15, TEAL))
		var checked: Dictionary = state.story_check(customer, state.selected_record_id)
		var condition: Label = _label(str(checked["error"]) if str(checked["error"]) != "" else "\n".join(checked["lines"]), 14, INK)
		condition.name = "StoryConditions_" + customer
		box.add_child(condition)
		box.add_child(_label("이 장을 마칠 때 답례 %s · 한 번만. 초안/시식만/이전 영업은 인정하지 않아요." % _won(Stories.REWARDS[chapter]), 14, MUTED))
		var complete: Button = _button("대접 결과로 이야기 마치기", "StoryComplete_" + customer)
		complete.disabled = rec.is_empty() or state.service_active() or state.exploration_active() or _work.is_running() or _training_left > 0 or _contest_left > 0
		complete.pressed.connect(_on_story_complete.bind(customer))
		box.add_child(complete)
	else:
		var ending: Label = _label("사연 완료\n" + str(route["ending"]), 16, TEAL)
		ending.name = "StoryEnding_" + customer
		box.add_child(ending)
	var history: Button = _button("지난 대화 접기" if bool(_story_history.get(customer, false)) else "지난 대화와 대접 기록", "StoryHistory_" + customer)
	history.pressed.connect(_on_story_history.bind(customer))
	box.add_child(history)
	if bool(_story_history.get(customer, false)):
		box.add_child(_label(definition["opening"] + "\n" + route["reply"], 14, INK))
		for i in arc["receipts"].size():
			var receipt: Dictionary = arc["receipts"][i]
			var text: String = StoryCatalog.chapter(customer, arc["route"], i)["success"] + "\n%d일차 %s v%d · %d그릇 · 답례 %s" % [receipt["service_day"], receipt["name"], receipt["version"], receipt["units"], _won(Stories.REWARDS[i])]
			box.add_child(_label(text, 14, INK))
	return card


func _research_card(req: Dictionary, rec: Dictionary) -> PanelContainer:
	var id: String = str(req["id"])
	var status: String = state.research_status(id)
	var customer: Dictionary = Customers.find(str(req["customer"]))
	var tier_text: String = "입문" if str(req["tier"]) == Research.TIER_BASIC else "심화"
	var card: PanelContainer = _card("Research_" + id)
	card.add_theme_stylebox_override("panel", _box(PAPER_LIGHT, LINE, 2, 0, 10.0, 6.0))
	var cb: VBoxContainer = _vbox(4)
	card.add_child(cb)
	var title: Label = _label("[%s] %s · %s" % [tier_text, str(customer["name"]), str(req["title"])], 18, TEAL if status == "done" else VERMILION)
	title.name = "ResearchTitle_" + id
	cb.add_child(title)

	var status_label: Label = _label("", 14, MUTED)
	status_label.name = "ResearchStatus_" + id
	match status:
		"done":
			status_label.text = "완료 · 보상을 받았어요."
			for e in state.research_receipts():
				var ed: Dictionary = e
				if str(ed["request_id"]) == id:
					status_label.text = "완료 · %d일차에 '%s v%d'로 제출 (점수 +%d, 자금 +%s)" % [int(ed["day"]), str(ed["recipe_name"]), int(ed["version"]), int(ed["points"]), _won(int(ed["cash"]))]
		"locked":
			status_label.text = "잠김 · " + state.research_lock_reason(id)
		_:
			var tier: String = str(req["tier"])
			status_label.text = "도전 가능 · 보상: 연구 점수 +%d, 자금 +%s (한 번만)" % [int(Research.REWARD_POINTS[tier]), _won(int(Research.REWARD_CASH[tier]))]
	cb.add_child(status_label)

	cb.add_child(_label("“%s”" % str(req["dialogue"]), 15, INK))

	var chk: Dictionary = {}
	if not rec.is_empty():
		chk = state.research_check(id, int(rec["record_id"]))
	var lines: Array[String] = []
	var hints: Array[String] = []
	var conds: Array = req["conditions"]
	for i in conds.size():
		var cond: Dictionary = conds[i]
		if chk.is_empty() or (chk["conditions"] as Array).size() != conds.size():
			lines.append("· " + Research.condition_text(cond))
			continue
		var cr: Dictionary = (chk["conditions"] as Array)[i]
		lines.append("%s %s — 지금 %s" % ["[달성]" if bool(cr["met"]) else "[부족]", str(cr["text"]), str(cr["measured_text"])])
		if not bool(cr["met"]):
			hints.append(str(cr["hint"]))
	var cond_label: Label = _label("조건\n" + "\n".join(lines), 15, INK)
	cond_label.name = "ResearchConditions_" + id
	cb.add_child(cond_label)
	if rec.is_empty():
		cb.add_child(_label("제출할 기록을 고르면 각 조건의 현재 값을 보여 드려요.", 13, MUTED))
	elif status != "done" and not hints.is_empty():
		var hint_label: Label = _label("힌트: " + hints[0], 14, TEAL)
		hint_label.name = "ResearchHint_" + id
		cb.add_child(hint_label)
	if status != "done":
		cb.add_child(_label("의뢰인의 조언: " + str(req["hint"]), 13, MUTED))

	var submit: Button = _button("이 기록으로 연구 제출", "ResearchSubmit_" + id)
	_primary(submit)
	match status:
		"done":
			submit.text = "제출 완료"
		"locked":
			submit.text = "잠김"
	# 버튼은 "제출할 수 있는 상태"에서만 켠다. 조건 미충족은 눌러서 이유를 보게 두고(도메인이 거부), 기록 없음/잠김/완료/영업 중은 끈다.
	submit.disabled = status != "open" or rec.is_empty() or state.service_active() or _work.is_running()
	submit.pressed.connect(_on_research_submit.bind(id))
	cb.add_child(submit)
	return card


## 보조 직원 초상(24x24 도트 x2, 캐시).
func _staff_portrait_tex(staff_id: String) -> ImageTexture:
	var key: String = "staff_portrait|%s" % staff_id
	if not _icon_cache.has(key):
		_icon_cache[key] = ArtScript.scaled_tex(ArtScript.staff_portrait_image(staff_id), 2)
	return _icon_cache[key] as ImageTexture


## 성장 탭 갱신: 요약/용량은 라벨을 고쳐 쓰고, 등급/확장/직원 카드는 매번 다시 만든다. 읽기만 하며 상태를 바꾸지 않는다.
func _refresh_growth() -> void:
	_growth_revision += 1
	if _growth_box == null:
		return
	var staffing: Dictionary = state.current_staffing()
	var hired: Array = state.hired_staff()
	var days: int = state.completed_service_days()
	_growth_summary.text = "가게 등급 %d단계 「%s」 · 영업 %d일 마침 · 자금 %s" % [state.rank(), state.rank_title(), days, _won(state.wallet)]
	var slots: int = state.topping_slots()
	var picked: int = Catalog.toppings_of(state.draft_config).size()
	var count: int = state.menu_count()
	var cap: int = state.menu_capacity()
	var cap_lines: Array[String] = []
	cap_lines.append("토핑 슬롯 %d/%d개 (지금 레시피 %d개)" % [slots, Catalog.MAX_TOPPINGS, picked])
	cap_lines.append("등록 메뉴 %d/%d종%s · 개정 이력 %d/%d (동시 판매 칸은 별개)" % [count, cap, " · 초과 보관 중" if count > cap else "", state.record_count(), state.record_history_capacity()])
	cap_lines.append("직원 %d/%d명 (요리사·서버 + 보조 %d) · 빈 자리 %d · 보조 하루 운영비 %s" % [Staffing.BASE_STAFF + hired.size(), state.staff_capacity(), hired.size(), state.free_staff_slots(), _won(int(staffing["wage"]))])
	_growth_capacity.text = "\n".join(cap_lines)

	_growth_buttons.clear()
	_clear(_growth_box)
	_growth_box.add_child(_rank_card())
	_growth_box.add_child(_expansion_card())
	var training_head: Label = _label("직원 육성 · 실무를 쌓고 전문화하기", 18, VERMILION)
	training_head.name = "TrainingHeader"
	_growth_box.add_child(training_head)
	_growth_box.add_child(_label("끝까지 마친 영업의 판매 그릇만 경험이 돼요. 두 보조 직원부터 육성할 수 있고 맛 점수는 바뀌지 않아요.", 14, MUTED))
	if _training_left > 0.0:
		var pending: Label = _label("%s · 반복 연습과 훈련 결과 정리 중…\n비용·자격을 반영했어요. 이 연출은 경험을 더 주지 않아요." % Staffing.find(_training_target)["name"], 15, TEAL)
		pending.name = "TrainingPresentation"
		_growth_box.add_child(pending)
		var bar: ProgressBar = ProgressBar.new()
		bar.name = "TrainingProgressBar"
		bar.custom_minimum_size.y = 24.0
		bar.value = 100.0 * (1.0 - _training_left / 2.0)
		_growth_box.add_child(bar)
	for staff_id in Staffing.ids():
		_growth_box.add_child(_training_card(staff_id))
	var head1: Label = _label("유료 확장 (한 번만 살 수 있고 환불은 없어요)", 18, VERMILION)
	head1.name = "GrowthFacilityHeader"
	_growth_box.add_child(head1)
	for rv in state.facility_reviews():
		_growth_box.add_child(_facility_card(rv))
	var head2: Label = _label("보조 직원 (직원 공간을 넓혀도 자동으로 고용되지 않아요)", 18, VERMILION)
	head2.name = "GrowthStaffHeader"
	_growth_box.add_child(head2)
	var hiring_policy: Label = _label("현재 판매 메뉴·가격·날짜로 비교해요. 고용 조건은 별도이며 실제 정산은 완료 주문 기준이에요.", 14, MUTED)
	hiring_policy.name = "GrowthHiringPolicy"
	_growth_box.add_child(hiring_policy)
	for sv in state.staff_reviews():
		_growth_box.add_child(_staff_card(sv))
	_sync_growth_lock()


## 시식 준비 중이거나 영업 중이면 성장 행동 버튼을 모두 끈다. 나머지 이유(조건/자금/자리)로 꺼진 버튼은 메타 "locked" 로 구분한다.
func _sync_growth_lock() -> void:
	var busy: bool = _work.is_running() or _contest_left > 0.0 or _training_left > 0.0 or (state != null and (state.service_active() or state.exploration_active()))
	for b in _growth_buttons:
		if is_instance_valid(b):
			b.disabled = busy or bool(b.get_meta("locked", false))


func _growth_button(text: String, node_name: String, locked: bool) -> Button:
	var b: Button = _button(text, node_name)
	b.custom_minimum_size = Vector2(0.0, 48.0)
	b.set_meta("locked", locked)
	b.disabled = locked
	_growth_buttons.append(b)
	return b


func _expansion_card() -> PanelContainer:
	var review: Dictionary = state.expansion_review()
	var card: PanelContainer = _card("ShopExpansionCard")
	var box: VBoxContainer = _vbox(5)
	card.add_child(box)
	box.add_child(_label("가게 증축 · 홀과 판매 메뉴 늘리기", 18, VERMILION))
	var info: Label = _label("%d석 · 판매 %d종\n증축하면 테이블 2개와 4석이 실제로 생기고 두 메뉴를 함께 팔아요. 주방은 하나라 조리 시간과 손님을 공유해요.\n가게 등급 2 · 비용 %s · 한 번만 구매 · 환불 없음\n%s" % [state.seat_count(), state.selling_capacity(), _won(int(review["price"])), "증축 완료" if bool(review["owned"]) else str(review["reason"])], 14, INK)
	info.name = "ShopExpansionInfo"
	box.add_child(info)
	var usage: Label = _label("좌석과 판매 칸을 늘리는 투자예요. 방문 손님이 자동으로 늘지는 않아요. 두 메뉴를 직접 판매 목록에 넣어 새 칸을 활용하세요.", 14, MUTED)
	usage.name = "ShopExpansionUsage"
	box.add_child(usage)
	var armed: bool = _expansion_armed_until != 0 and Time.get_ticks_msec() <= _expansion_armed_until
	var button: Button = _growth_button("증축 완료" if bool(review["owned"]) else ("다시 눌러 증축 확정" if armed else "증축 · " + _won(int(review["price"]))), "ShopExpandButton", not bool(review["can_buy"]))
	button.pressed.connect(_on_expand_shop)
	box.add_child(button)
	return card


func _training_card(id: String) -> PanelContainer:
	var card: PanelContainer = _card("Training_" + id)
	var box: VBoxContainer = _vbox(5)
	card.add_child(box)
	var def: Dictionary = Staffing.find(id)
	var head: HBoxContainer = HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	box.add_child(head)
	var picture: TextureRect = TextureRect.new()
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	picture.name = "TrainingPortrait_" + id
	picture.texture = _staff_portrait_tex(id)
	picture.custom_minimum_size = Vector2(48, 48)
	picture.stretch_mode = TextureRect.STRETCH_KEEP
	picture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	head.add_child(picture)
	var title: Label = _label("%s · %s" % [def["name"], def["role_name"]], 18, TEAL)
	title.name = "TrainingTitle_" + id
	head.add_child(title)
	var all_training: Dictionary = state.staff_training()
	if not all_training.has(id):
		box.add_child(_label("아직 함께 일하지 않아요. 직원 공간을 넓힌 뒤 아래에서 고용하세요. 고용 전 경험은 소급되지 않아요.", 14, MUTED))
		box.add_child(_growth_button("고용 후 훈련 가능", "Train_" + id + "_basic", true))
		return card
	var entry: Dictionary = all_training[id]
	var lv: int = Training.level(entry)
	var style: String = "" if lv == 0 else str(entry["lessons"][lv - 1]["style"])
	var fx: Dictionary = Training.effect(lv, style)
	var status: Label = _label("%s · 훈련 %d/2단계\n실무 %d일 · 경험 %d그릇" % [fx["title"], lv, entry["work_days"], entry["bowls"]], 15, INK)
	status.name = "TrainingExperience_" + id
	box.add_child(status)
	var current: Label = _label("지금 효과: " + _training_effect_text(id, fx), 14, TEAL)
	current.name = "TrainingEffect_" + id
	box.add_child(current)
	if lv == 2:
		var done: Label = _label("전문화 완료 · 선택은 유지돼요. 더 훈련하거나 전문화를 바꿀 수 없어요.", 14, MUTED)
		done.name = "TrainingComplete_" + id
		box.add_child(done)
		return card
	var goal: int = 40 if lv == 0 else 160
	var progress: ProgressBar = ProgressBar.new()
	progress.name = "TrainingXP_" + id
	progress.custom_minimum_size.y = 22.0
	progress.value = minf(100.0, 100.0 * float(entry["bowls"]) / float(goal))
	box.add_child(progress)
	var needs: Label = _label("다음 훈련: 경험 %d그릇 · 실무 %d일 · 가게 등급 %d\n비용 %s · 경험 유지 · 같은 직원 하루 1회" % [goal, 2 if lv == 0 else 5, 2 if lv == 0 else 3, _won(4000 if lv == 0 else 12000)], 14, INK)
	needs.name = "TrainingRequirements_" + id
	box.add_child(needs)
	var policy: Label = _label("훈련비는 돌려받지 못해요. 전문화는 한 번만 고르며 나중에 바꿀 수 없어요.", 13, VERMILION)
	policy.name = "TrainingPolicy_" + id
	box.add_child(policy)
	for choice in (["basic"] if lv == 0 else ["speed", "economy"]):
		var review: Dictionary = state.training_review(id, choice)
		var target: Dictionary = Training.effect(lv + 1, choice)
		var text: Label = _label("%s: %s" % [target["title"], _training_effect_text(id, target)], 14, INK)
		text.name = "TrainingChoice_" + id + "_" + choice
		box.add_child(text)
		var ready: bool = bool(review["eligible"])
		var armed: bool = _training_armed == id + ":" + choice and Time.get_ticks_msec() <= _training_armed_until
		var btn: Button = _growth_button("다시 눌러 확정 · " + _won(int(review["cost"])) if armed else str(target["title"]) + " 훈련 · " + _won(int(review["cost"])), "Train_" + id + "_" + choice, not ready)
		btn.pressed.connect(_on_staff_train.bind(id, choice))
		box.add_child(btn)
		if not ready:
			var reason: Label = _label(str(review["reason"]), 13, MUTED)
			reason.name = "TrainingLock_" + id + "_" + choice
			box.add_child(reason)
	return card


func _training_effect_text(id: String, effect: Dictionary) -> String:
	var def: Dictionary = Staffing.find(id)
	var base: int = Staffing.PREP_PERCENT if str(def["role"]) == "prep" else Staffing.SERVE_PERCENT
	return "%s 시간 %d%% (올림) · 하루 운영비 %s" % ["조리" if str(def["role"]) == "prep" else "서빙 왕복", base - int(effect["percent_discount"]), _won(int(def["wage"]) + int(effect["wage_delta"]))]


func _rank_card() -> PanelContainer:
	var rv: Dictionary = state.promotion_review()
	var card: PanelContainer = _card("GrowthRankCard")
	card.add_theme_stylebox_override("panel", _box(PAPER_LIGHT, LINE, 2, 0, 10.0, 6.0))
	var cb: VBoxContainer = _vbox(4)
	card.add_child(cb)
	cb.add_child(_label("가게 등급 심사", 20, VERMILION))
	var cur: Label = _label("지금: %d단계 「%s」 — %s" % [int(rv["rank"]), str(rv["title"]), str(rv["summary"])], 15, INK)
	cur.name = "RankCurrent"
	cb.add_child(cur)
	var armed: bool = _promote_armed_until != 0 and Time.get_ticks_msec() <= _promote_armed_until
	var btn: Button
	if bool(rv["top"]):
		var done: Label = _label("가장 높은 등급이에요. 더 올릴 등급이 없어요.", 15, TEAL)
		done.name = "RankConditions"
		cb.add_child(done)
		btn = _growth_button("최고 등급", "PromoteButton", true)
	else:
		var lines: Array[String] = ["다음: %d단계 「%s」 조건" % [int(rv["next"]), str(rv["next_title"])]]
		for c in rv["conditions"]:
			var cd: Dictionary = c
			lines.append("%s %s — %s" % ["[달성]" if bool(cd["met"]) else "[부족]", str(cd["text"]), str(cd["measured_text"])])
		var cond: Label = _label("\n".join(lines), 15, INK)
		cond.name = "RankConditions"
		cb.add_child(cond)
		cb.add_child(_label("심사는 신청할 때 노트의 시식 기록으로 다시 계산해요. 보상은 없고 등급만 올라요.", 13, MUTED))
		var eligible: bool = bool(rv["eligible"])
		btn = _growth_button("한 번 더 눌러 확정" if armed else ("등급 심사 신청" if eligible else "신청 조건 부족"), "PromoteButton", not eligible)
		btn.pressed.connect(_on_promote_pressed)
	cb.add_child(btn)
	return card


func _facility_card(rv: Dictionary) -> PanelContainer:
	var id: String = str(rv["id"])
	var def: Dictionary = Growth.find_facility(id)
	var card: PanelContainer = _card("Facility_" + id)
	card.add_theme_stylebox_override("panel", _box(PAPER_LIGHT, LINE, 2, 0, 10.0, 6.0))
	var cb: VBoxContainer = _vbox(4)
	card.add_child(cb)
	var owned: bool = bool(rv["owned"])
	var title: Label = _label("%s · %s" % [str(rv["name"]), str(rv["price_text"])], 18, TEAL if owned else VERMILION)
	title.name = "FacilityTitle_" + id
	cb.add_child(title)
	var req_parts: Array[String] = ["가게 등급 %d단계(%s) 이상" % [int(def["min_rank"]), Growth.rank_title(int(def["min_rank"]))]]
	if str(def["requires"]) != "":
		req_parts.append("먼저 「%s」" % str(Growth.find_facility(str(def["requires"]))["name"]))
	var lines: Array[String] = [str(rv["desc"]), "효과: " + str(rv["effect_text"]), "필요: " + " + ".join(req_parts)]
	lines.append("설치했어요." if owned else ("살 수 있어요." if bool(rv["can_buy"]) else "잠김 · " + str(rv["reason"])))
	var info: Label = _label("\n".join(lines), 14, INK)
	info.name = "FacilityInfo_" + id
	cb.add_child(info)
	var usage: Label = _label("새 토핑과 메뉴를 직접 개발해 열린 용량을 활용하세요. 설치만으로 맛 점수나 방문 손님이 늘지는 않아요." if str(def["track"]) == "recipe" else "고용할 자리를 여는 투자예요. 직원은 따로 골라야 하고, 고용비와 영업할 때의 일당이 추가돼요.", 14, MUTED)
	usage.name = "FacilityUsage_" + id
	cb.add_child(usage)
	var text: String = "설치 완료" if owned else ("구매 · %s" % str(rv["price_text"]) if bool(rv["can_buy"]) else "구매 불가")
	var btn: Button = _growth_button(text, "FacilityBuy_" + id, not bool(rv["can_buy"]))
	btn.pressed.connect(_on_facility_buy.bind(id))
	cb.add_child(btn)
	return card


func _staff_card(sv: Dictionary) -> PanelContainer:
	var id: String = str(sv["id"])
	var card: PanelContainer = _card("Staff_" + id)
	card.add_theme_stylebox_override("panel", _box(PAPER_LIGHT, LINE, 2, 0, 10.0, 6.0))
	var cb: VBoxContainer = _vbox(4)
	card.add_child(cb)
	var head: HBoxContainer = HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	cb.add_child(head)
	var portrait: TextureRect = TextureRect.new()
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait.name = "StaffPortrait_" + id
	portrait.texture = _staff_portrait_tex(id)
	portrait.stretch_mode = TextureRect.STRETCH_KEEP
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	portrait.custom_minimum_size = Vector2(48.0, 48.0)
	portrait.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	portrait.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	head.add_child(portrait)
	var side: VBoxContainer = _vbox(2)
	head.add_child(side)
	var is_hired: bool = bool(sv["hired"])
	var title: Label = _label("%s %s" % [str(sv["role_name"]), str(sv["name"])], 18, TEAL if is_hired else VERMILION)
	title.name = "StaffTitle_" + id
	side.add_child(title)
	var cost_label: Label = _label("고용비 %s (한 번) · 하루 운영비 %s (영업 정산마다)" % [_won(int(sv["hire_price"])), _won(int(sv["wage"]))], 14, INK)
	cost_label.name = "StaffCost_" + id
	side.add_child(cost_label)
	var status: String = "함께 일하고 있어요." if is_hired else ("고용할 수 있어요." if bool(sv["can_hire"]) else "고용 불가 · " + str(sv["reason"]))
	var info: Label = _label("%s\n%s" % [str(sv["desc"]), status], 14, INK)
	info.name = "StaffInfo_" + id
	cb.add_child(info)
	if not is_hired:
		var preview: Label = _label(_hiring_preview_text(state.hiring_preview(id), str(Staffing.find(id)["role"])), 14, TEAL)
		preview.name = "StaffPreview_" + id
		cb.add_child(preview)
	var text: String = "고용 완료" if is_hired else ("고용 · %s" % _won(int(sv["hire_price"])) if bool(sv["can_hire"]) else "고용 불가")
	var btn: Button = _growth_button(text, "StaffHire_" + id, not bool(sv["can_hire"]))
	btn.pressed.connect(_on_staff_hire.bind(id))
	cb.add_child(btn)
	return card


## Show a same-day comparison without promising future sales or payback. The
## existing hire control/lock remains the sole action; building this text is pure.
func _hiring_preview_text(preview: Dictionary, role: String) -> String:
	if str(preview["error"]) != "":
		return str(preview["error"])
	var before: Dictionary = preview["before"]
	var after: Dictionary = preview["after"]
	var lines: Array[String] = ["오늘 판매 메뉴 · 고용 후 예상"]
	for i in before["menus"].size():
		var row: Dictionary = before["menus"][i]
		lines.append("%s v%d: 한 그릇 조리 %d→%d초(게임 시간)" % [row["recipe_name"], row["version"], row["prep"], after["menus"][i]["prep"]])
	lines.append("예상 판매 %d→%d그릇 · 하루 운영비 %s→%s" % [before["units"], after["units"], _won(int(before["overhead"])), _won(int(after["overhead"]))])
	var delta: int = int(preview["delta_net"])
	var change: String = ("+" if delta > 0 else ("−" if delta < 0 else "")) + _won(absi(delta))
	lines.append("순영업이익 %s→%s (%s)" % [_won(int(before["net"])), _won(int(after["net"])), change])
	lines.append("별도 고용비 %s (일회성·이익에 미포함)" % _won(int(preview["hire_price"])))
	if int(preview["delta_units"]) <= 0:
		lines.append("오늘 판매 증가 예상은 없어요.")
	if role == "floor":
		lines.append("서빙 대기 단축은 이 예상 이익에 미포함.")
	return "\n".join(lines)


func _source_text(by_source: Dictionary) -> String:
	var parts: Array[String] = []
	for c in Customers.all():
		var cd: Dictionary = c
		parts.append("%s %d그릇" % [str(cd["name"]), int(by_source[str(cd["id"])])])
	parts.append("처음 온 손님 %d그릇" % int(by_source[Sim.WALKIN_ID]))
	return " · ".join(parts)


## 두 메뉴 보고에는 단위를 머리말에 한 번만 쓴다. 세로 화면에서도 메뉴별 수량을 한 묶음으로 읽을 수 있다.
func _menu_source_text(by_source: Dictionary) -> String:
	var parts: Array[String] = []
	for c in Customers.all():
		parts.append("%s %d" % [c["name"], by_source[c["id"]]])
	parts.append("첫 손님 %d" % by_source[Sim.WALKIN_ID])
	return "손님별 그릇: " + " · ".join(parts)


func _forecast_text(fc: Dictionary) -> String:
	if fc.has("menus"):
		var lines: Array[String] = ["오늘 %d종 예상 · 손님과 조리 2,400초를 공유해요." % fc["menus"].size()]
		for row in fc["menus"]:
			lines.append("%s v%d: %d/%d그릇(판매/수요) · 조리 %d초\n매출 %s · 재료비 %s · 메뉴 이익 %s\n%s" % [row["recipe_name"], row["version"], row["units"], row["demand"], row["prep"], _won(int(row["revenue"])), _won(int(row["ingredient_cost"])), _won(int(row["margin"])), _menu_source_text(row["by_source"])])
		lines.append("메뉴 이익은 공통 운영비 차감 전이에요. 공통 운영비 %s를 한 번 뺀 순영업이익 %s. 실제 대기는 영업 후 비교해요." % [_won(int(fc["overhead"])), _won(int(fc["net"]))])
		return "\n".join(lines)
	var lines: Array[String] = ["오늘 예상 (%d일차)" % state.day]
	lines.append("손님 수요 %d그릇, 만들 수 있는 양 %d그릇 → 판매 %d그릇" % [int(fc["demand"]), int(fc["capacity"]), int(fc["units"])])
	lines.append(_source_text(fc["by_source"]))
	lines.append("매출 %s − 재료비 %s − 운영비 %s" % [_won(int(fc["revenue"])), _won(int(fc["ingredient_cost"])), _won(int(fc["overhead"]))])
	lines.append("순영업이익 %s (실제 완료한 주문으로 정산해요)" % _won(int(fc["net"])))
	return "\n".join(lines)


func _report_text(report: Dictionary) -> String:
	if report.has("menus"):
		var lines: Array[String] = ["%d일차 · %d석 · %d종 메뉴 영업" % [report["day"], report["seat_count"], report["menus"].size()]]
		for row in report["menus"]:
			var wait: String = "판매 없음" if int(row["units"]) == 0 else "평균 대기 %.0f초" % (float(row["wait_total"]) / float(row["units"]))
			lines.append("%s v%d · %d그릇 · %s\n매출 %s − 재료비 %s = 메뉴 이익 %s\n%s" % [row["recipe_name"], row["version"], row["units"], wait, _won(int(row["revenue"])), _won(int(row["ingredient_cost"])), _won(int(row["margin"])), _menu_source_text(row["by_source"])])
		lines.append("메뉴 이익은 공통 운영비 차감 전이에요. 운영비 %s 한 번 차감\n순영업이익 %s · 영업 후 자금 %s" % [_won(int(report["overhead"])), _won(int(report["net"])), _won(int(report["wallet_after"]))])
		return "\n".join(lines)
	var lines: Array[String] = ["%d일차 · %s v%d · 판매가 %s" % [int(report["day"]), str(report["recipe_name"]), int(report["version"]), _won(int(report["price"]))]]
	lines.append("판매 %d그릇" % int(report["units"]))
	lines.append(_source_text(report["by_source"]))
	lines.append("매출 %s · 재료비 %s · 운영비 %s" % [_won(int(report["revenue"])), _won(int(report["ingredient_cost"])), _won(int(report["overhead"]))])
	lines.append("순영업이익 %s · 영업 후 자금 %s" % [_won(int(report["net"])), _won(int(report["wallet_after"]))])
	return "\n".join(lines)
