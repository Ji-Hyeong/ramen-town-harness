extends SceneTree
## 펼침 카드와 연구 노트(저널) 컴포넌트 시험. 실제 노드를 트리에 붙여 레이아웃/신호/입력 정책을 확인한다.
## 순수 도메인 페이지(RecipeDiscovery.pages)를 그대로 쓰고 게임 상태/저장은 건드리지 않는다.
## 실제 손가락 스윕/네이티브 터치는 이 시험의 범위가 아니다(신호/상태 수준 확인).

const Card = preload("res://scripts/ui/disclosure_card.gd")
const Journal = preload("res://scripts/ui/recipe_journal.gd")
const Discovery = preload("res://scripts/domain/recipe_discovery.gd")

const NARROW: float = 300.0
const WIDE: float = 600.0

var checks := 0
var failures := 0
var _host: VBoxContainer


func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: ", label)


func _initialize() -> void:
	await _run()
	print("disclosure_card checks=%d failures=%d" % [checks, failures])
	quit(0 if failures == 0 else 1)


func _run() -> void:
	_host = VBoxContainer.new()
	_host.position = Vector2.ZERO
	_host.size = Vector2(NARROW, 1200)
	root.add_child(_host)
	await _card_basics()
	await _card_layout()
	await _card_input()
	await _journal_map()
	await _journal_target()
	await _journal_invalid()
	_host.queue_free()
	await _frames(2)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _reset_host(width: float) -> void:
	for child in _host.get_children():
		_host.remove_child(child)
		child.queue_free()
	_host.size = Vector2(width, 1200)


func _make_card(node_name: String, title: String = "제목", summary: String = "요약") -> Card:
	var card: Card = Card.new()
	card.name = node_name
	card.configure(title, summary)
	return card


func _signal_log(card: Object) -> Array:
	var seen: Array = []
	card.connect("toggled", func(value: bool) -> void: seen.append(value))
	return seen


# ---------- DisclosureCard ----------

func _card_basics() -> void:
	_reset_host(NARROW)
	var card := _make_card("TestCard")
	_host.add_child(card)
	var detail := Label.new()
	detail.text = "상세 내용"
	card.body.add_child(detail)
	await _frames(2)
	check(card.header_button.name == "TestCardToggle" and card.body.name == "TestCardBody", "stable header/body names")
	check(card.header_button is Button, "header is a Button")
	check(not card.expanded and not card.body.visible and not detail.is_visible_in_tree(), "starts collapsed and hides the body")
	check(card.header_button.is_visible_in_tree(), "header visible while collapsed")
	var seen :=_signal_log(card)
	var header_before: Button = card.header_button
	var body_before: VBoxContainer = card.body
	# 같은 상태는 신호가 없다.
	card.set_expanded(false)
	check(seen.is_empty(), "no signal for unchanged state")
	# 실제 눌러서 한 번 바뀌면 신호 한 번.
	card.header_button.pressed.emit()
	check(card.expanded and seen ==[true], "one press opens with exactly one signal")
	card.set_expanded(true)
	check(seen == [true], "setting the same expanded value emits nothing")
	await _frames(2)
	check(card.body.visible and detail.is_visible_in_tree(), "expanded body visible")
	# configure 는 머리줄/상세/펼침 상태를 그대로 두고 신호도 없다.
	card.configure("새 제목", "새 요약")
	check(card.header_button == header_before and card.body == body_before, "configure keeps header and body identity")
	check(detail.get_parent() == card.body and card.body.get_child_count() == 1, "configure keeps caller content")
	check(card.expanded and seen ==[true], "configure keeps expanded state without a signal")
	check(card.title_label.text == "새 제목" and card.summary_label.text == "새 요약", "configure updates texts")
	card.configure("제목만", "")
	check(not card.summary_label.visible, "empty summary hides its label")
	var icon_texture := ImageTexture.create_from_image(Image.create(8, 8, false, Image.FORMAT_RGBA8))
	card.configure("아이콘", "있음", icon_texture)
	check(card.icon_rect.visible and card.icon_rect.texture == icon_texture, "icon shown when supplied")
	card.configure("아이콘", "없음")
	check(not card.icon_rect.visible, "icon hidden when omitted")
	card.set_expanded(false)
	check(seen == [true, false] and not card.body.visible, "closing emits once and hides body")
	card.set_accent(Color(0.8, 0.2, 0.1))
	check(not card.expanded and seen ==[true, false], "accent change keeps state and emits nothing")
	if "accessibility_name" in card.header_button:
		check(str(card.header_button.get("accessibility_name")).contains("아이콘"), "accessibility name carries the title")
	# 이름이 바뀐 뒤 configure 를 다시 부르면 파생 이름도 따라간다.
	card.name = "Renamed"
	card.configure("제목", "요약")
	check(card.header_button.name == "RenamedToggle" and card.body.name == "RenamedBody", "derived names follow root name")


func _card_layout() -> void:
	_reset_host(NARROW)
	var long_title := "A very long disclosure title that has to wrap onto several lines in a narrow card"
	var card := _make_card("WrapCard", long_title, "Summary text that is also long enough to need wrapping at three hundred pixels")
	_host.add_child(card)
	card.body.add_child(Label.new())
	await _frames(3)
	check(card.header_button.size.y >= 48.0 and card.get_combined_minimum_size().y >= 48.0, "header is at least 48px tall")
	check(card.size.x <= NARROW + 0.5 and card.get_combined_minimum_size().x <= NARROW + 0.5, "card fits 300px width")
	check(card.title_label.size.x <= NARROW and card.title_label.size.y > card.title_label.get_line_height() * 1.5, "title wraps instead of growing wide")
	check(card.header_button.size.y >= card.title_label.size.y, "header grows with wrapped text")
	var chevron: Control = card.chevron
	check(chevron != null and chevron.size.x > 0.0 and chevron.size.y > 0.0, "drawn chevron has non-zero area")
	check(chevron.is_visible_in_tree(), "chevron visible at 300px")
	var header_rect := card.header_button.get_global_rect()
	check(header_rect.encloses(chevron.get_global_rect()), "chevron sits inside the header")
	check(not bool(chevron.get("up")), "collapsed chevron points down")
	card.set_expanded(true)
	check(bool(chevron.get("up")), "expanded chevron points up")
	card.set_expanded(false)
	check(not bool(chevron.get("up")), "collapsed again points down")
	# 넓은 폭에서도 화살표는 머리줄 오른쪽 끝에 남는다.
	_reset_host(WIDE)
	var wide := _make_card("WideCard", "짧은 제목", "요약")
	_host.add_child(wide)
	await _frames(3)
	check(wide.chevron.get_global_rect().end.x <= wide.header_button.get_global_rect().end.x + 0.5, "chevron stays inside the wide header")
	check(wide.chevron.get_global_rect().position.x > wide.header_button.get_global_rect().position.x + WIDE * 0.5, "chevron is at the right")


func _card_input() -> void:
	_reset_host(NARROW)
	var card := _make_card("PolicyCard")
	_host.add_child(card)
	var inner := Button.new()
	card.body.add_child(inner)
	await _frames(2)
	check(card.mouse_filter == Control.MOUSE_FILTER_PASS, "card passes input")
	check(card.header_button.mouse_filter == Control.MOUSE_FILTER_PASS, "header passes input")
	check(card.body.mouse_filter == Control.MOUSE_FILTER_PASS, "body passes input")
	for part in [card.title_label, card.summary_label, card.icon_rect, card.chevron]:
		check((part as Control).mouse_filter == Control.MOUSE_FILTER_IGNORE, "decoration ignores input: " + str((part as Control).get_class()))
	# 머리줄 위에 겹친 모든 내용 컨테이너는 입력을 가리지 않는다.
	var blocking := 0
	for node in card.find_children("*", "Control", true, false):
		var control := node as Control
		if control == card.header_button or card.body.is_ancestor_of(control) or control == card.body:
			continue
		if control.get_parent() == card:
			continue  # 머리줄 홀더와 상세 판: PASS
		if control.mouse_filter != Control.MOUSE_FILTER_IGNORE:
			blocking += 1
	check(blocking == 0, "overlay content never blocks the header")
	# 진짜로 꺼진 머리줄과 강제 신호 모두 펼치지 않는다.
	var seen :=_signal_log(card)
	card.header_button.disabled = true
	card.header_button.pressed.emit()
	check(not card.expanded and seen.is_empty(), "disabled header ignores a forced pressed signal")
	card.header_button.disabled = false
	card.header_button.pressed.emit()
	check(card.expanded and seen ==[true], "enabled header toggles")
	card.header_button.pressed.emit()
	check(not card.expanded and seen ==[true, false], "second press closes")
	# 눌림 효과는 크기를 바꾸지 않는다: 상태별 스타일의 안쪽 여백이 같다.
	var normal := card.header_button.get_theme_stylebox("normal")
	var pressed := card.header_button.get_theme_stylebox("pressed")
	check(normal != null and pressed != null, "normal and pressed styles exist")
	check(normal.get_minimum_size() == pressed.get_minimum_size(), "pressed look keeps the same inner size")
	check(card.header_button.get_theme_stylebox("focus") != null, "explicit focus style")


# ---------- RecipeJournal ----------

func _config(broth: String, tare: String, oil: String, noodle: String, toppings: Array, cook: String) -> Dictionary:
	return {"broth": broth, "tare": tare, "oil": oil, "noodle": noodle, "toppings": toppings, "cook": cook, "price": 9000}


func _bone() -> Dictionary:
	return _config("broth_tonkotsu", "tare_miso", "oil_garlic", "noodle_thick", ["topping_chashu"], "cook_normal")


func _plain() -> Dictionary:
	return _config("broth_chicken", "tare_shoyu", "oil_scallion", "noodle_thin", ["topping_nori"], "cook_firm")


func _pages(records: Array, draft: Dictionary) -> Array:
	var available: Array[String] = []
	return Discovery.pages(records, draft, available)


func _make_journal(mode: String) -> Node:
	var journal: Node = Journal.new()
	journal.set("mode", mode)
	_host.add_child(journal)
	return journal


func _find(journal: Node, node_name: String) -> Node:
	return journal.find_child(node_name, true, false)


func _journal_map() -> void:
	_reset_host(NARROW)
	var journal := _make_journal("map")
	var events: Array = []
	journal.connect("target_selected", func(id: String) -> void: events.append("select:" + id))
	journal.connect("book_requested", func() -> void: events.append("book"))
	journal.connect("exploration_requested", func() -> void: events.append("explore"))
	var pages := _pages([{"record_id": "r1", "config": _bone()}], _plain())
	var tested_count := 0
	for p in pages:
		if p["tested"]:
			tested_count += 1
	journal.call("present", pages, "bone_depth")
	await _frames(3)
	check(_find(journal, "JournalHeading") != null, "map heading")
	check((_find(journal, "JournalMapSummary") as Label).text.contains("%d/8" % tested_count), "summary counts retained matches over total")
	var ids: Array = []
	for p in pages:
		ids.append(p["id"])
	for id in ids:
		var card := _find(journal, "JournalTheme_" + id) as Control
		check(card != null, "theme card " + id)
		if card == null:
			continue
		check(card.get("header_button").name == "JournalTheme_%sToggle" % id and card.get("body").name == "JournalTheme_%sBody" % id, "stable disclosure names " + id)
		check(not bool(card.get("expanded")) and not (card.get("body") as Control).visible, "collapsed by default " + id)
		check(card.size.y < 170.0, "compact summary card " + id)
		check((card.get("header_button") as Control).is_visible_in_tree(), "header visible " + id)
		var pick := _find(journal, "JournalSelect_" + id) as Button
		check(pick != null and not pick.is_visible_in_tree(), "select hidden until opened " + id)
	check(journal.get_child_count() == 4 + 8, "map children: heading, summary, two notes, eight cards")
	# 펼치기만으로는 목표 선택/탐험/지도 요청이 일어나지 않는다.
	(_find(journal, "JournalTheme_fire_oilToggle") as Button).pressed.emit()
	await _frames(2)
	check(events.is_empty(), "opening details emits no intent")
	check(bool(_find(journal, "JournalTheme_fire_oil").get("expanded")), "header press expands")
	var fire_pick := _find(journal, "JournalSelect_fire_oil") as Button
	check(fire_pick.is_visible_in_tree() and fire_pick.custom_minimum_size.y >= 48.0, "select button visible and 48px after opening")
	check(not bool(_find(journal, "JournalTheme_noodle_chew").get("expanded")), "other cards stay closed")
	fire_pick.pressed.emit()
	check(events == ["select:fire_oil"], "select button emits target intent only")
	# 다시 그려도 펼침이 유지되고 카드는 중복되지 않는다.
	journal.call("present", pages, "fire_oil")
	journal.call("present", pages, "fire_oil")
	journal.call("present", pages, "fire_oil")
	await _frames(3)
	check(journal.get_child_count() == 12, "repeated present keeps one set of children")
	check(journal.find_children("JournalTheme_fire_oil", "", true, false).size() == 1, "no duplicate card node")
	# Godot assigns @ names to ordinary unnamed decoration too. Check the
	# actual public controls for every theme, not the engine's internal names.
	for id in ids:
		for node_name in ["JournalTheme_" + id + "Toggle", "JournalTheme_" + id + "Body", "JournalSelect_" + id]:
			check(journal.find_children(node_name, "", true, false).size() == 1, "one current stable control after same-frame refresh: " + node_name)
	check(bool(_find(journal, "JournalTheme_fire_oil").get("expanded")), "expanded state survives present")
	check(not bool(_find(journal, "JournalTheme_clear_light").get("expanded")), "closed cards stay closed after present")
	check((_find(journal, "JournalSelect_fire_oil") as Button).text == "현재 목표", "selected card labelled as current")
	# 알려진 id 에만 복원한다: 빠졌다 돌아온 카드는 접힌 채로 돌아온다.
	var fewer: Array = []
	for p in pages:
		if p["id"] != "fire_oil":
			fewer.append(p)
	journal.call("present", fewer, "bone_depth")
	await _frames(2)
	check(_find(journal, "JournalTheme_fire_oil") == null, "removed theme disappears")
	journal.call("present", pages, "bone_depth")
	await _frames(2)
	check(not bool(_find(journal, "JournalTheme_fire_oil").get("expanded")), "returning theme is not resurrected as open")
	# 입력 정책.
	var card2 := _find(journal, "JournalTheme_bone_depth") as Control
	check(card2.mouse_filter == Control.MOUSE_FILTER_PASS and journal.mouse_filter == Control.MOUSE_FILTER_PASS, "journal and cards pass input")
	check((_find(journal, "JournalMapSummary") as Control).mouse_filter == Control.MOUSE_FILTER_IGNORE, "summary label ignores input")
	# 바쁨: 버튼이 꺼지고 직접 부른 신호도 의도를 보내지 않으며 펼침도 안 된다.
	events.clear()
	journal.call("present", pages, "bone_depth", true)
	await _frames(2)
	var busy_header := _find(journal, "JournalTheme_clear_lightToggle") as Button
	var busy_pick := _find(journal, "JournalSelect_clear_light") as Button
	check(busy_header.disabled and busy_pick.disabled, "rebuilt controls inherit busy")
	busy_pick.pressed.emit()
	busy_header.pressed.emit()
	check(events.is_empty() and not bool(_find(journal, "JournalTheme_clear_light").get("expanded")), "busy rejects forced intents and toggles")
	journal.call("set_busy", false)
	check(not busy_header.disabled and not busy_pick.disabled, "set_busy(false) re-enables controls")
	busy_header.pressed.emit()
	busy_pick.pressed.emit()
	check(events == ["select:clear_light"] and bool(_find(journal, "JournalTheme_clear_light").get("expanded")), "controls work again after busy")
	# 시식함/준비됨/재료필요/미시도 구분이 요약줄에 드러난다.
	var tested_card := _find(journal, "JournalTheme_bone_depth")
	check(str(tested_card.get("summary_label").text).begins_with("시식함") or str(tested_card.get("summary_label").text).begins_with("현재 목표 · 시식함"), "tested status shown")
	var needs_card := _find(journal, "JournalTheme_clam_mushroom")
	check(str(needs_card.get("summary_label").text).contains("재료가 더 필요해요"), "needs-ingredients status shown")
	_reset_host(NARROW)
	await _frames(2)


func _journal_target() -> void:
	_reset_host(NARROW)
	var journal := _make_journal("target")
	var events: Array = []
	journal.connect("target_selected", func(id: String) -> void: events.append("select:" + id))
	journal.connect("book_requested", func() -> void: events.append("book"))
	journal.connect("exploration_requested", func() -> void: events.append("explore"))
	var pages := _pages([], _bone())
	var clam: Dictionary = {}
	for p in pages:
		if p["id"] == "clam_mushroom":
			clam = p
	var shortage := "시식 재료가 모자라요."
	journal.call("present", pages, "clam_mushroom", false, shortage)
	await _frames(3)
	check((_find(journal, "JournalTargetTitle") as Label).text == clam["title"], "target title from page")
	var bar := _find(journal, "JournalTargetProgress") as ProgressBar
	check(bar != null and int(bar.max_value) == int(clam["total"]) and int(bar.value) == int(clam["progress"]), "target progress is the page progress")
	var missing := _find(journal, "JournalMissing") as Label
	check(missing.is_visible_in_tree() and missing.text.contains("·"), "missing hints visible")
	var warning := _find(journal, "JournalSampleError") as Label
	check(warning.is_visible_in_tree() and warning.text.contains(shortage) and warning.text.contains("조개 맑은탕"), "shortage and missing material stay visible while details are collapsed")
	var find := _find(journal, "JournalFindMaterials") as Button
	check(find.is_visible_in_tree() and find.custom_minimum_size.y >= 48.0, "material route button visible")
	var book := _find(journal, "JournalOpenBook") as Button
	check(book.is_visible_in_tree(), "map button always visible")
	var details := _find(journal, "JournalTargetDetails")
	check(details != null and not bool(details.get("expanded")) and not (details.get("body") as Control).visible, "details collapsed by default")
	check(details.get("header_button").name == "JournalTargetDetailsToggle", "details header name")
	# 펼쳐도 의도는 나가지 않고 경고는 그대로 보인다.
	(details.get("header_button") as Button).pressed.emit()
	await _frames(2)
	check(events.is_empty() and bool(details.get("expanded")), "opening details emits no intent")
	check(warning.is_visible_in_tree() and find.is_visible_in_tree() and book.is_visible_in_tree(), "warning and actions stay visible when open")
	journal.call("present", pages, "clam_mushroom", false, shortage)
	await _frames(2)
	check(bool(_find(journal, "JournalTargetDetails").get("expanded")), "target details stay open across present")
	journal.call("present", pages, "bone_depth", false, "")
	await _frames(2)
	check(not bool(_find(journal, "JournalTargetDetails").get("expanded")), "another target does not inherit the open state")
	check(journal.find_children("JournalTargetDetails", "", true, false).size() == 1 and journal.find_children("JournalTargetTitle", "", true, false).size() == 1, "no duplicate target nodes")
	# 조건이 모두 맞고 재료도 충분하면 안내만 있고 재료 버튼은 숨는다.
	check((_find(journal, "JournalMissing") as Label).text == Journal.READY_TEXT, "ready text")
	check(not (_find(journal, "JournalSampleError") as Control).visible and not (_find(journal, "JournalFindMaterials") as Control).visible, "no warning or material route when nothing is needed")
	# 의도.
	(_find(journal, "JournalOpenBook") as Button).pressed.emit()
	check(events == ["book"], "book intent")
	journal.call("present", pages, "clam_mushroom", false, shortage)
	await _frames(2)
	(_find(journal, "JournalFindMaterials") as Button).pressed.emit()
	check(events == ["book", "explore"], "material intent")
	# 바쁨.
	events.clear()
	journal.call("present", pages, "clam_mushroom", true, shortage)
	await _frames(2)
	var busy_find := _find(journal, "JournalFindMaterials") as Button
	var busy_book := _find(journal, "JournalOpenBook") as Button
	var busy_head := _find(journal, "JournalTargetDetailsToggle") as Button
	check(busy_find.disabled and busy_book.disabled and busy_head.disabled, "target controls inherit busy")
	busy_find.pressed.emit()
	busy_book.pressed.emit()
	busy_head.pressed.emit()
	check(events.is_empty() and not bool(_find(journal, "JournalTargetDetails").get("expanded")), "busy rejects forced target intents")
	journal.call("set_busy", false)
	check(not busy_find.disabled and not busy_book.disabled and not busy_head.disabled, "set_busy(false) re-enables target controls")
	# 입력 정책.
	check((_find(journal, "JournalSampleError") as Control).mouse_filter == Control.MOUSE_FILTER_IGNORE, "labels ignore input")
	check((_find(journal, "JournalFindMaterials") as Button).mouse_filter == Control.MOUSE_FILTER_PASS and (_find(journal, "JournalOpenBook") as Button).mouse_filter == Control.MOUSE_FILTER_PASS, "buttons pass input")
	_reset_host(NARROW)
	await _frames(2)


func _journal_invalid() -> void:
	_reset_host(NARROW)
	var target := _make_journal("target")
	target.call("present", [5, {}], "bone_depth")
	await _frames(2)
	check((_find(target, "JournalTargetTitle") as Label).text.contains("찾지 못했어요") and _find(target, "JournalOpenBook") != null, "invalid pages in target mode are reported, map button kept")
	target.call("present", [], "")
	await _frames(2)
	check((_find(target, "JournalTargetTitle") as Label).text.contains("찾지 못했어요"), "empty pages in target mode are reported")
	var map := _make_journal("map")
	map.call("present", [5, {}], "")
	await _frames(2)
	var summary := (_find(map, "JournalMapSummary") as Label).text
	check(summary.contains("받지 못했어요"), "empty valid set is not presented as success")
	var one := _pages([], _plain())
	var mixed: Array = [one[0], {"id": "broken"}, 3]
	map.call("present", mixed, one[0]["id"])
	await _frames(2)
	check(_find(map, "JournalTheme_" + str(one[0]["id"])) != null and (_find(map, "JournalMapSummary") as Label).text.contains("/1"), "only valid pages are counted")
	var odd := _make_journal("sideways")
	odd.call("present", one, "")
	await _frames(2)
	check(odd.get_child_count() == 1, "unknown mode shows a single notice")
	_reset_host(NARROW)
	await _frames(2)
