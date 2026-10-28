extends SceneTree
## Pure proof for the early-journey projection (kitchen_journey.gd) and a native check of the card (journey_card.gd).
## Real GameState flows are used for every stage: raw broth/noodle crafting, paid tasting, a real sale, deleted records.
## A tiny fake object covers only what a real fresh game cannot reach cheaply (active expedition, odd inputs).
## Projection/navigation never mutate: every stage compares the full saved dictionary plus the transient
## craft/service flags (which to_dict() does not contain) before and after.
## Nothing is saved or written. Run (official engine, from the repository root):
##   <godot> --headless --path game --script res://tests/kitchen_journey_tests.gd

const State = preload("res://scripts/domain/game_state.gd")
const Legacy = preload("res://tests/legacy_game_fixture.gd")
const Journey = preload("res://scripts/ui/kitchen_journey.gd")
const Card = preload("res://scripts/ui/journey_card.gd")
const Eval = preload("res://scripts/domain/recipe_evaluator.gd")
const Customers = preload("res://scripts/domain/customer_catalog.gd")

var checks: int = 0
var failures: Array[String] = []


## A stand-in exposing exactly the public reads describe() relies on.
class Fake extends RefCounted:
	var expedition: bool = false
	var service: bool = false
	var craft: bool = false
	var broth: bool = true
	var noodle: bool = true
	var records: int = 0

	func exploration_active() -> bool: return expedition
	func service_active() -> bool: return service
	func craft_active() -> bool: return craft
	func broth_ready() -> bool: return broth
	func noodle_ready() -> bool: return noodle
	func record_count() -> int: return records
	func selling_records() -> Array: return []
	func completed_service_days() -> int: return 0
	func trial_cost() -> int: return 1000


func verify(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures.append(message)
		printerr("FAIL: " + message)


func snapshot(st: State) -> String:
	return JSON.stringify([st.to_dict(), st.craft_active(), st.service_active(), st.exploration_active()], "", true)


## Runs the projection and proves it left the state untouched; returns the describe() model.
func described(st: State, label: String, busy: bool = false) -> Dictionary:
	var before: String = snapshot(st)
	var model: Dictionary = Journey.describe(st, busy)
	Journey.choices(st)
	verify(snapshot(st) == before, "projection never mutates: " + label)
	var keys: Array = model.keys()
	keys.sort()
	verify(keys == ["action", "customer", "disabled", "hint", "id", "title"], "stable describe keys: " + label)
	verify(Journey.ACTIONS.has(model["action"]), "allowed action: " + label)
	return model


func brew(st: State) -> void:
	verify(st.set_broth_blend(["chicken_bone", "onion"], "standard")["ok"], "select raw broth")
	verify(st.begin_broth()["ok"], "begin broth")


func finish_broth(st: State) -> int:
	verify(st.advance_broth(20.0)["ok"], "finish broth")
	return st.broth_review()["recipes"].size() - 1


func set_noodle(st: State) -> void:
	for pair in [["flour", "wheat"], ["water", "clear"], ["cut", "thin"], ["method", "standard"]]:
		verify(st.set_noodle_formula(pair[0], pair[1])["ok"], "noodle choice " + pair[0])


func knead(st: State) -> void:
	set_noodle(st)
	verify(st.begin_noodle()["ok"], "begin noodles")
	verify(st.advance_noodle(20.0)["ok"], "finish noodles")


func _initialize() -> void:
	_staged_new_game()
	_old_save_and_deleted()
	_comparison()
	_bad_input_and_fake()
	await _card()
	print("kitchen_journey checks=%d failures=%d" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)


# ---------- 새 게임: 원재료 → 구성 → 유료 시식 → 실제 영업 → 다음 목표 ----------

func _staged_new_game() -> void:
	var st := State.new()
	var m: Dictionary = described(st, "fresh game")
	verify(m["id"] == "broth" and m["action"] == "broth" and not m["disabled"], "fresh game asks for the first broth")
	verify(m["customer"] == "dohyun" and str(m["hint"]).contains("한도윤") and str(m["hint"]).contains("든든한 국물"), "an existing customer's catalog taste motivates the first dish")
	verify(not str(m["hint"]).contains("9") and str(m["hint"]).length() <= 40, "first goal is a short qualitative brief, no numeric target")
	verify(Journey.choices(st) == [], "no next choices before any sale")
	var wallet: int = st.wallet

	brew(st)
	m = described(st, "brewing")
	verify(m["id"] == "busy" and m["action"] == "wait" and m["disabled"], "brewing is busy and disabled")
	verify(st.cancel_broth()["ok"] and st.wallet == wallet, "cancel costs nothing")
	m = described(st, "broth canceled")
	verify(m["id"] == "broth" and not m["disabled"], "canceled work returns to the broth step")
	brew(st)
	var index: int = finish_broth(st)
	m = described(st, "broth brewed but not in the bowl")
	verify(m["id"] == "broth_apply" and m["action"]=="broth", "finished but unapplied broth is a deliberate use step, not another paid brew")
	verify(st.use_broth(index)["ok"], "put the finished broth in the bowl")
	m = described(st, "broth ready")
	verify(m["id"] == "noodle" and m["action"] == "noodle", "next the first noodles")

	set_noodle(st)
	verify(st.begin_noodle()["ok"], "begin noodles")
	verify(described(st, "kneading")["id"] == "busy", "kneading is busy")
	verify(st.cancel_noodle()["ok"], "cancel noodles")
	knead(st)
	verify(st.use_noodle(0)["ok"], "put the finished noodles in the bowl")
	m = described(st, "bowl ready")
	verify(m["id"] == "compose" and m["action"] == "compose", "both components ready, no paid tasting yet")
	verify(str(m["hint"]).contains("%d원" % st.trial_cost()), "hint shows the real existing tasting fee")
	var money: int = st.wallet
	described(st, "browse spends nothing")
	verify(st.wallet == money and st.record_count() == 0, "browsing never tastes or spends")

	var restarted := State.new()
	verify(restarted.load_from_dict(st.to_dict()) == "", "restart: load saved state")
	verify(Journey.describe(restarted) == Journey.describe(st), "restart: same guidance without a progress ledger")

	var taste: Dictionary = st.taste()
	verify(taste["ok"], "paid tasting")
	m = described(st, "tasted")
	verify(m["id"] == "first_sale" and m["action"] == "selling" and not m["disabled"], "tasted menu is selected: first sale opens the selling view")
	verify(st.completed_service_days() == 0 and st.wallet == money - int(Eval.unit_cost(st.draft_config)), "opening guidance did not sell or charge again")
	verify(Journey.choices(st) == [], "still no next choices before the sale")

	verify(st.begin_service()["ok"], "begin service")
	m = described(st, "service running")
	verify(m["id"] == "busy" and m["disabled"], "service running disables the card")
	m = described(st, "busy flag", true)
	verify(m["action"] == "wait" and m["disabled"], "caller busy flag wins")
	st.cancel_service()
	verify(described(st, "service canceled")["id"] == "first_sale", "canceled service returns to the first sale")

	var restarted2 := State.new()
	verify(restarted2.load_from_dict(st.to_dict()) == "", "restart after tasting")
	verify(Journey.describe(restarted2) == Journey.describe(st), "restart after tasting: same first-sale guidance")

	var sale: Dictionary = st.serve()
	verify(sale["ok"] and st.completed_service_days() == 1, "first real sale completed")
	m = described(st, "after first sale")
	verify(m["id"] == "goals" and m["action"] == "goals" and not m["disabled"], "after the sale: choose the next goal")
	var list: Array = Journey.choices(st)
	verify(list.size() == 3, "three next choices")
	var actions: Array = []
	for row in list:
		var keys: Array = row.keys()
		keys.sort()
		verify(keys == ["action", "customer", "hint", "title"], "stable choice keys")
		verify(str(row["title"]) != "" and str(row["hint"]) != "", "readable choice")
		actions.append(row["action"])
	verify(actions == ["improve", "explore", "research"], "choice order")
	verify(str(list[0]["hint"]).contains("v1") and str(list[0]["hint"]).contains(st.draft_name), "improve cites the real tasted record")
	verify(Customers.ids().has(list[0]["customer"]), "improve names a catalog customer whose recorded score was lowest")
	verify(str(list[1]["hint"]).contains("0/"), "explore reports real discovery count")
	verify(str(list[2]["hint"]).contains("0/"), "research reports real completion count")
	var after_sale := State.new()
	verify(after_sale.load_from_dict(st.to_dict()) == "" and Journey.choices(after_sale) == list, "restart: same choices")

	# 선택 목록을 비우고 기록을 지운다: 판매 메뉴/시식 기록이 없는 상태.
	var id: int = int(st.get_record(st.selected_record_id)["record_id"])
	verify(st.delete_record(id)["ok"], "delete the only tasted record")
	m = described(st, "record deleted")
	verify(m["id"] == "compose", "no paid tasting remains: compose again")
	list = Journey.choices(st)
	verify(list.size() == 3 and str(list[0]["hint"]).contains("기록이 없어요") and list[0]["customer"] == "", "deleted record: improve does not invent one")


# ---------- 옛 저장/삭제 ----------

func _old_save_and_deleted() -> void:
	var old := Legacy.new()
	var m: Dictionary = described(old, "old save, no records")
	verify(m["id"] == "compose", "an old save already has both components: straight to tasting")

	# 시식한 기록이 있지만 판매 목록이 비는 상태(선택 해제).
	var st := State.new()
	brew(st)
	var index: int = finish_broth(st)
	st.use_broth(index)
	knead(st)
	st.use_noodle(0)
	verify(st.taste()["ok"], "taste for the unselected case")
	st.start_new_recipe()
	var m2: Dictionary = described(st, "tasted but not selected")
	verify(m2["id"] == "pick_menu" and m2["action"] == "selling", "a tasted menu that is not selected: pick a menu")
	verify(st.completed_service_days() == 0, "picking guidance never sells")


# ---------- 개정 비교 ----------

func _comparison() -> void:
	var st := State.new()
	brew(st)
	var index: int = finish_broth(st)
	st.use_broth(index)
	knead(st)
	st.use_noodle(0)
	verify(st.taste()["ok"], "first tasting")
	var first: Dictionary = st.get_record(st.selected_record_id)
	var none: Dictionary = Journey.comparison(first)
	verify(none["error"] == "" and none["available"] == false and none["rows"] == [], "first version has no comparison and no fabricated baseline")

	var other: String = "tare_shio" if str(st.draft_config["tare"]) != "tare_shio" else "tare_shoyu"
	verify(st.set_draft_choice("tare", other)["ok"], "change one ingredient")
	verify(st.taste()["ok"], "second (revised) tasting")
	var second: Dictionary = st.get_record(st.selected_record_id)
	var before: String = JSON.stringify(second, "", true)
	var cmp: Dictionary = Journey.comparison(second)
	verify(JSON.stringify(second, "", true) == before, "comparison never mutates the record")
	verify(cmp["error"] == "" and cmp["available"] == true, "revision compares")
	var keys: Array = cmp.keys()
	keys.sort()
	verify(keys == ["available", "error", "rows"], "stable comparison keys")
	var rows: Array = cmp["rows"]
	verify(rows.size() >= 2 and rows.size() <= 4, "two fixed rows plus at most two taste rows")
	verify(rows[0]["label"] == "재료비" and rows[0]["unit"] == "원" and rows[0]["before"] == Eval.unit_cost(first["config"]) and rows[0]["after"] == Eval.unit_cost(second["config"]), "real ingredient costs of the two tasted configurations")
	verify(rows[1]["label"] == "준비 시간" and rows[1]["before"] == Eval.prep_seconds(first["config"]) and rows[1]["after"] == Eval.prep_seconds(second["config"]), "real prep times")
	for i in range(2, rows.size()):
		verify(rows[i]["before"] != rows[i]["after"], "only changed taste axes are listed")
	var row_keys: Array = rows[0].keys()
	row_keys.sort()
	verify(row_keys == ["after", "before", "label", "unit"], "stable row keys")

	# 이전 버전을 지워도 기록 안의 불변 복사본이므로 결과가 같다.
	verify(st.delete_record(int(first["record_id"]))["ok"], "delete the predecessor")
	verify(Journey.comparison(st.get_record(int(second["record_id"]))) == cmp, "deleted predecessor does not change the comparison")


# ---------- 잘못된 입력, 가짜 상태 ----------

func _bad_input_and_fake() -> void:
	for bad in [null, RefCounted.new()]:
		var m: Dictionary = Journey.describe(bad)
		verify(m["action"] == "wait" and m["disabled"] == true, "unusable state is a disabled wait")
		verify(m["id"] == "unavailable" and str(m["title"]).contains("열 수 없") and str(m["hint"]) != "", "unusable state explains it is unavailable, not preparing")
		verify(Journey.choices(bad) == [], "unusable state has no choices")

	var f := Fake.new()
	f.expedition = true
	var m1: Dictionary = Journey.describe(f)
	verify(m1["id"] == "expedition" and m1["action"] == "resume_exploration" and not m1["disabled"], "active expedition resumes exploration")
	f.craft = true
	verify(Journey.describe(f)["action"] == "resume_exploration", "expedition outranks other work")
	verify(Journey.describe(f, true)["disabled"] == true, "busy flag disables the expedition card")
	f.expedition = false
	verify(Journey.describe(f)["id"] == "busy", "craft in progress is busy")
	f.craft = false
	verify(Journey.describe(f, true)["id"] == "busy", "busy flag without state is busy")
	f.broth = false
	verify(Journey.describe(f)["id"] == "broth", "missing broth outranks missing noodles")
	f.broth = true
	f.noodle = false
	verify(Journey.describe(f)["id"] == "noodle", "missing noodles")

	var base := {"record_id": 2, "version": 2, "config": {}, "scores": {}, "comparison": {"prev_record_id": 1, "prev_version": 1, "prev_scores": {}, "prev_config": {}}}
	for bad_record in [{}, {"config": 1}, {"record_id": 0}]:
		var c: Dictionary = Journey.comparison(bad_record)
		verify(c["error"] != "" and c["available"] == false and c["rows"] == [], "malformed record is an explicit error")
	var broken: Dictionary = base.duplicate(true)
	var c2: Dictionary = Journey.comparison(broken)
	verify(c2["error"] != "" and c2["available"] == false, "invalid configurations are rejected")
	broken["comparison"]["prev_version"] = 2
	verify(Journey.comparison(broken)["error"] != "", "a predecessor must be an earlier version")
	broken["comparison"].erase("prev_config")
	verify(Journey.comparison(broken)["error"] != "", "missing predecessor snapshot is an error, not a zero baseline")


# ---------- 카드(실제 노드) ----------

func _card() -> void:
	var host := VBoxContainer.new()
	host.size = Vector2(280, 800)
	root.add_child(host)
	var card: Card = Card.new()
	host.add_child(card)
	var requests: Array = []
	card.action_requested.connect(func(action: String): requests.append(action))

	card.present({"title": "첫 육수 만들기", "hint": "한도윤 님은 진함 9 정도를 좋아해요.", "action": "broth", "customer": "dohyun", "disabled": false})
	await process_frame
	await process_frame
	verify(card.button.name == "JourneyAction" and card.title_label.name == "JourneyTitle" and card.hint_label.name == "JourneyHint", "required node names")
	verify(card.title_label.text == "첫 육수 만들기" and card.hint_label.text != "", "text shown")
	verify(card.size.y >= 78.0 and card.get_combined_minimum_size().y >= 78.0, "minimum card height 78")
	verify(card.portrait.visible and card.portrait.custom_minimum_size == Vector2(40, 40), "40px portrait for a catalog customer")
	verify(card.size.x == 280.0 and card.button.get_global_rect().end.x <= card.get_global_rect().end.x + 0.5, "bounded width: button stays inside the card")
	verify(card.chevron.texture != null, "chevron icon")
	for node in card.find_children("*", "Control", true, false):
		if node != card.button and node != card.get_child(0):
			verify((node as Control).mouse_filter == Control.MOUSE_FILTER_IGNORE, "decoration ignores the mouse: " + str(node.name))
	card.button.pressed.emit()
	verify(requests == ["broth"], "press emits exactly the model's action")

	# 누르는 동안 글자/화살표는 흰색, 떼면 INK/MUTED. 눌림만으로는 이동하지 않는다.
	var white := Color.WHITE
	card.button.button_down.emit()
	verify(card.title_label.get_theme_color("font_color") == white and card.hint_label.get_theme_color("font_color") == white and card.chevron.modulate == white, "held: title, hint and chevron turn white")
	verify(requests == ["broth"], "holding never navigates")
	card.button.button_up.emit()
	verify(card.title_label.get_theme_color("font_color") == Card.INK and card.hint_label.get_theme_color("font_color") == Card.MUTED and card.chevron.modulate == Card.INK, "released or canceled: INK/MUTED restored")
	verify(requests == ["broth"], "release alone never navigates")

	# 같은 모델은 다시 만들지 않는다: 손으로 바꾼 글이 그대로면 present 가 건너뛴 것이다.
	card.title_label.text = "손으로 바꿈"
	card.present({"title": "첫 육수 만들기", "hint": "한도윤 님은 진함 9 정도를 좋아해요.", "action": "broth", "customer": "dohyun", "disabled": false})
	verify(card.title_label.text == "손으로 바꿈", "unchanged model does no work")
	card.present({"title": "첫 육수 만들기", "hint": "한도윤 님은 진함 9 정도를 좋아해요.", "action": "broth", "customer": "dohyun", "disabled": true})
	verify(card.title_label.text == "첫 육수 만들기" and card.button.disabled, "changed model refreshes and disables")
	card.button.pressed.emit()
	verify(requests == ["broth"], "disabled card emits nothing")

	for model in [{"title": "기다리는 중", "hint": "", "action": "wait", "customer": "", "disabled": false}, {}, {"action": "format_disk", "title": "x"}]:
		card.present(model)
		card.button.pressed.emit()
	verify(requests == ["broth"], "wait, empty and unknown actions can never be requested")
	verify(card.button.disabled and not card.portrait.visible and not card.hint_label.visible, "such cards are inert and tidy")

	# 아주 긴 이름도 폭 안에서 줄바꿈되고 카드가 커진다.
	card.present({"title": "가".repeat(50), "hint": "나".repeat(120), "action": "selling", "customer": "", "disabled": false})
	await process_frame
	await process_frame
	verify(card.size.x == 280.0 and card.title_label.get_global_rect().end.x <= card.get_global_rect().end.x + 0.5, "long title stays inside the card")
	verify(card.size.y > 78.0 and card.button.size.y == card.size.y, "long text grows the card and the full-card button follows")

	host.queue_free()
	await process_frame
