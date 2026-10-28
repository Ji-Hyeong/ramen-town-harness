extends RefCounted
## ForagingPlan 은 공개 조회만 읽는 투영이다. 여기서는 (1) 설정 가능한 읽기 전용 대역으로 모든 경우를 정확히 만들고
## (2) 실제 GameState 로 새 게임/탐험 진행/포기/저장 왕복에서도 같은 사실과 불변을 확인한다.
## 대역은 review 값을 그대로 돌려줄 뿐이며, 계획이 그 값을 새로 계산하거나 우회하지 않는지가 검사 대상이다.
## 보드 검사는 씬 트리 없이 버튼 신호를 직접 내보내 눌림/취소/ID 신호/바쁨 잠금을 확인한다.
const Plan = preload("res://scripts/ui/foraging_plan.gd")
const Board = preload("res://scripts/ui/foraging_goal_board.gd")
const Game = preload("res://scripts/domain/game_state.gd")
const Directions = preload("res://scripts/domain/recipe_directions.gd")
const DirectionTests = preload("res://tests/recipe_directions_tests.gd")
const Exploration = preload("res://scripts/domain/ingredient_exploration.gd")
const Market = preload("res://scripts/domain/market_foraging.gd")
const Harbor = preload("res://scripts/domain/harbor_foraging.gd")
const Mountain = preload("res://scripts/domain/mountain_foraging.gd")
const Broth = preload("res://scripts/domain/broth_workshop.gd")
const MarketTests = preload("res://tests/market_foraging_tests.gd")
const HarborTests = preload("res://tests/harbor_foraging_tests.gd")

const SARDINE: String = "broth_roasted_sardine"
const SCALLOP: String = "topping_scallop"
const BUCKWHEAT: String = "noodle_buckwheat"
const SHIITAKE: String = "topping_grilled_shiitake"
const CITRUS: String = "topping_citrus_peel"
const SESAME: String = "oil_roasted_sesame"
const SUPPLIERS: Dictionary = {"market": ["tare_plum", "topping_pickle"], "harbor": ["broth_clam", "oil_shrimp"], "mountain": ["oil_pepper", "topping_mushroom"]}
const BLOCKED: String = "대역이 막은 이유"

var check: Callable


## 공개 조회 전부를 가진 읽기 전용 대역. 어떤 메서드도 필드를 바꾸지 않는다.
class FakeState extends RefCounted:
	const Region = preload("res://scripts/domain/ingredient_exploration.gd")
	const MarketSpec = preload("res://scripts/domain/market_foraging.gd")
	const HarborSpec = preload("res://scripts/domain/harbor_foraging.gd")
	const MountainSpec = preload("res://scripts/domain/mountain_foraging.gd")
	const Cat = preload("res://scripts/domain/ingredient_catalog.gd")
	var rank_value: int = 1
	var draft_config: Dictionary = Cat.default_config()
	var found: Array = []
	var unlocked: Array = []
	var stock: Dictionary = {}
	var saved_records: Array = []
	var broths: Array = []
	var noodles: Array = []
	var service: bool = false
	var craft: bool = false
	var trip: bool = false
	## 지역 id -> 막는 이유. 비어 있으면 review 가 출발 가능이라고 말한다.
	var supplier_block: Dictionary = {}
	var sample_block: Dictionary = {}

	func rank() -> int:
		return rank_value

	func records() -> Array:
		return saved_records.duplicate(true)

	func is_discovered(id: String) -> bool:
		return found.has(id) or unlocked.has(id)

	func ingredient_unlocked(id: String) -> bool:
		return unlocked.has(id)

	func sample_stock(id: String) -> int:
		return int(stock.get(id, 0))

	func exploration_region(region_id: String) -> Dictionary:
		var region: Dictionary = Region.find_region(region_id)
		var reason: String = str(supplier_block.get(region_id, ""))
		return {"id": region_id, "name": region["name"], "fee": region["fee"], "min_rank": region["min_rank"],
			"can_start": reason == "", "reason": reason}

	func _sample(region_id: String, fee: int) -> Dictionary:
		var reason: String = str(sample_block.get(region_id, ""))
		return {"can_start": reason == "", "reason": reason, "fee": fee}

	func foraging_review() -> Dictionary:
		return _sample("market", MarketSpec.FEE)

	func harbor_foraging_review() -> Dictionary:
		return _sample("harbor", HarborSpec.FEE)

	func mountain_foraging_review() -> Dictionary:
		return _sample("mountain", MountainSpec.FEE)

	func broth_review() -> Dictionary:
		return {"recipes": broths.duplicate(true)}

	func noodle_review() -> Dictionary:
		return {"recipes": noodles.duplicate(true)}

	func service_active() -> bool:
		return service

	func craft_active() -> bool:
		return craft

	func exploration_active() -> bool:
		return trip

	func snapshot() -> String:
		return JSON.stringify([rank_value, draft_config, found, unlocked, stock, saved_records, broths, noodles, service, craft, trip, supplier_block, sample_block])


func run(callback: Callable) -> void:
	check = callback
	_projection()
	_routes()
	_completed_components()
	_blockers()
	_bad_input()
	_real_state()
	_real_market_sample()
	_real_harbor_archive()
	_board()


# ---------- 도우미 ----------

func _fake(rank_value: int = 1, found: Array = []) -> FakeState:
	var fake := FakeState.new()
	fake.rank_value = rank_value
	fake.found = found.duplicate()
	return fake


func _all_suppliers() -> Array:
	return SUPPLIERS["market"] + SUPPLIERS["harbor"] + SUPPLIERS["mountain"]


func _row(plan: Dictionary, ingredient_id: String) -> Dictionary:
	for row in plan["ingredients"]:
		if row["id"] == ingredient_id:
			return row
	return {}


func _sardine_broth() -> Dictionary:
	return {"recipe": {"ingredients": ["sardine"], "method": "standard"}, "day": 1}


func _buckwheat_noodle() -> Dictionary:
	return {"recipe": {"flour": "buckwheat", "water": "clear", "cut": "thin", "method": "standard"}, "day": 1}


# ---------- 순수 투영 ----------

func _projection() -> void:
	var fake: FakeState = _fake()
	var before: String = fake.snapshot()
	var plans: Array = Plan.catalog(fake)
	var definitions: Array = Directions.catalog()
	check.call(plans.size() == 5 and definitions.size() == 5, "five existing directions")
	for i in plans.size():
		var plan: Dictionary = plans[i]
		var definition: Dictionary = definitions[i]
		check.call(plan["error"] == "" and plan["id"] == definition["id"], "catalog keeps direction order: " + str(definition["id"]))
		check.call(plan["title"] == definition["title"] and plan["brief"] == definition["brief"], "culinary brief comes from the existing direction")
		check.call(plan["ingredients"].size() == definition["requires"].size(), "every required material stays visible")
		check.call(not bool(plan["tested"]) and not bool(plan["ready"]), "new game: nothing earned or ready")
		for j in plan["ingredients"].size():
			var row: Dictionary = plan["ingredients"][j]
			check.call(row["id"] == definition["requires"][j], "required ingredient order is kept")
			check.call(row["mode"] == "supplier" and row["stock"] == 0 and not bool(row["prepared"]) and not bool(row["usable"]), "new game rows are supplier, stock0, unprepared, unusable")
			check.call(str(row["name"]) != "" and str(row["status"]) != "" and str(row["source_title"]) != "", "row carries name, short status and source")
			check.call(row["status"] == "공급처 0/2곳 발견", "status is a short supplier count")
	var harbor: Dictionary = plans[2]
	check.call(harbor["id"] == "harbor_sea" and harbor["ingredients"].size() == 2, "both harbor materials are listed")
	check.call(_row(harbor, SARDINE)["primary"] and not _row(harbor, SCALLOP)["primary"], "only the direction ingredient is primary")
	check.call(_row(harbor, SARDINE)["develops"] and not _row(harbor, SCALLOP)["develops"], "broth is a developable completed component, scallop is not")
	check.call(_row(plans[3], BUCKWHEAT)["develops"], "buckwheat noodle is a developable completed component")
	check.call(not _row(plans[0], CITRUS)["develops"] and not _row(plans[1], SESAME)["develops"], "toppings and oils have no completed component")
	check.call(harbor["focus"] == SARDINE, "first unusable material is the focus")
	check.call(fake.snapshot() == before, "projection never changes the fake state")
	check.call(JSON.stringify(Plan.catalog(fake)) == JSON.stringify(plans), "projection is deterministic")


func _routes() -> void:
	# 새 게임: 항구/산골은 등급이 막지만 길은 여전히 공급처 탐험이다.
	var fake: FakeState = _fake()
	fake.supplier_block = {"harbor": "가게 등급 2단계부터 갈 수 있어요.", "mountain": "가게 등급 3단계부터 갈 수 있어요."}
	var plans: Array = Plan.catalog(fake)
	var citrus: Dictionary = _row(plans[0], CITRUS)
	check.call(citrus["region"] == "market" and citrus["fee"] == Exploration.find_region("market")["fee"] and bool(citrus["can_depart"]) and citrus["reason"] == "", "market supplier trip is available with its real fee")
	check.call(citrus["source_title"].contains("탐험") and citrus["min_rank"] == 1, "supplier route is named as an exploration")
	var sardine: Dictionary = _row(plans[2], SARDINE)
	check.call(sardine["mode"] == "supplier" and not bool(sardine["can_depart"]) and sardine["reason"] == "가게 등급 2단계부터 갈 수 있어요." and sardine["fee"] == 6000, "rank lock reason and fee are the public review values")
	check.call(_row(plans[2], SCALLOP)["reason"] == sardine["reason"], "second harbor material shows the same real blocker")
	check.call(_row(plans[3], BUCKWHEAT)["min_rank"] == 3 and _row(plans[4], SHIITAKE)["mode"] == "supplier", "mountain materials are locked behind suppliers and rank")

	# 공급처 한 곳만: 아직 공급처 길이고, 샘플 길은 열리지 않는다.
	fake = _fake(1, ["tare_plum"])
	var one: Dictionary = _row(Plan.describe(fake, "citrus_clear"), CITRUS)
	check.call(one["mode"] == "supplier" and one["suppliers_found"] == 1 and one["status"] == "공급처 1/2곳 발견" and not bool(one["usable"]), "one supplier of two keeps supplier mode")
	check.call(one["fee"] == 3000, "one supplier still pays the supplier trip fee")

	# 두 곳: 샘플 채집 길, 샘플 비용.
	fake = _fake(1, SUPPLIERS["market"])
	var both: Dictionary = _row(Plan.describe(fake, "sesame_depth"), SESAME)
	check.call(both["mode"] == "sample" and both["fee"] == Market.FEE and both["source_title"] == Market.SPEC["name"], "two suppliers open the sampling route")
	check.call(both["status"] == "연구 샘플 0/1개" and not bool(both["usable"]) and not bool(both["prepared"]) and not bool(both["sample_ready"]), "stock0 sample is not usable, not prepared and not sample-ready")
	fake = _fake(2, SUPPLIERS["harbor"])
	var harbor_sample: Dictionary = _row(Plan.describe(fake, "harbor_sea"), SCALLOP)
	check.call(harbor_sample["mode"] == "sample" and harbor_sample["fee"] == Harbor.FEE and harbor_sample["source_title"] == Harbor.SPEC["name"], "harbor sampling route and fee")
	fake = _fake(3, SUPPLIERS["mountain"])
	var mountain_sample: Dictionary = _row(Plan.describe(fake, "shiitake_depth"), SHIITAKE)
	check.call(mountain_sample["mode"] == "sample" and mountain_sample["fee"] == Mountain.FEE and mountain_sample["source_title"] == Mountain.SPEC["name"], "mountain sampling route and fee")
	# 한 지역의 공급처는 다른 지역 재료의 길을 열지 않는다.
	check.call(_row(Plan.describe(fake, "harbor_sea"), SARDINE)["mode"] == "supplier", "mountain suppliers do not open the harbor sampling route")

	# 재고: 있으면 쓸 수 있고, 시식으로 소모되는 개수를 그대로 보여 준다.
	fake = _fake(2, SUPPLIERS["harbor"])
	fake.stock = {SARDINE: 2, SCALLOP: 3}
	fake.unlocked = [SARDINE, SCALLOP]
	var plan: Dictionary = Plan.describe(fake, "harbor_sea")
	check.call(_row(plan, SARDINE)["stock"] == 2 and _row(plan, SCALLOP)["stock"] == 3, "actual sample stock is shown per material")
	check.call(_row(plan, SARDINE)["usable"] and _row(plan, SCALLOP)["sample_ready"] and plan["ready"] and plan["focus"] == "", "stocked materials make the direction ready")
	check.call(_row(plan, SARDINE)["status"] == "연구 샘플 2/1개" and not bool(_row(plan, SARDINE)["prepared"]), "stock is not a completed component")
	# 한 번 알게 된 채집 재료는 샘플을 다 써도 unlocked 로 남지만 새 시식에는 쓸 수 없다.
	fake.stock = {}
	var spent_plan: Dictionary = Plan.describe(fake, "harbor_sea")
	var spent: Dictionary = _row(spent_plan, SARDINE)
	check.call(spent["stock"] == 0 and bool(spent["unlocked"]) and not bool(spent["usable"]) and not bool(spent["sample_ready"]) and not bool(spent_plan["ready"]), "unlocked with empty stock is neither usable nor sample-ready")
	check.call(spent["required_samples"] == 1 and spent["status"] == "연구 샘플 0/1개", "a target needs at least one sample")
	# 현재 초안이 담은 실제 횟수(반복 토핑 포함)가 필요 샘플 수다.
	fake.stock = {SCALLOP: 1}
	fake.draft_config["toppings"] = [SCALLOP, SCALLOP]
	var twice: Dictionary = _row(Plan.describe(fake, "harbor_sea"), SCALLOP)
	check.call(twice["required_samples"] == 2 and twice["stock"] == 1 and not bool(twice["sample_ready"]) and twice["status"] == "연구 샘플 1/2개", "repeat toppings in the draft require one sample each")
	fake.stock = {SCALLOP: 2}
	check.call(bool(_row(Plan.describe(fake, "harbor_sea"), SCALLOP)["sample_ready"]), "two samples fund the two-portion draft")
	fake.draft_config["toppings"] = ["topping_egg"]
	check.call(_row(Plan.describe(fake, "harbor_sea"), SCALLOP)["required_samples"] == 1, "a material outside the draft still needs one")
	fake.draft_config = {"broken": true}
	check.call(_row(Plan.describe(fake, "harbor_sea"), SCALLOP)["required_samples"] == 1, "an unreadable draft falls back to one sample")


func _completed_components() -> void:
	var fake: FakeState = _fake(2, SUPPLIERS["harbor"])
	fake.broths = [_sardine_broth()]
	var before: String = fake.snapshot()
	var plan: Dictionary = Plan.describe(fake, "harbor_sea")
	var sardine: Dictionary = _row(plan, SARDINE)
	check.call(sardine["stock"] == 0 and bool(sardine["prepared"]) and sardine["prepared_count"] == 1 and bool(sardine["usable"]), "completed sardine broth is usable at stock0")
	check.call(not bool(sardine["sample_ready"]) and sardine["required_samples"] == 1, "completed broth at stock0 does not fund a new tasting")
	check.call(sardine["status"] == "연구 샘플 0/1개 · 완성품 1개", "status distinguishes samples from completed product")
	check.call(sardine["note"] != "", "tasting still needing a sample is stated honestly")
	check.call(not bool(_row(plan, SCALLOP)["usable"]) and not bool(plan["ready"]) and plan["focus"] == SARDINE, "prepared product alone does not make the direction ready")
	check.call(fake.snapshot() == before, "reading completed components does not change state")
	fake.stock = {SARDINE: 1}
	check.call(_row(Plan.describe(fake, "harbor_sea"), SARDINE)["note"] == "", "no sample warning when a sample exists")

	fake = _fake(2, SUPPLIERS["harbor"])
	fake.broths = [{"recipe": {"ingredients": ["pork_bone"], "method": "standard"}, "day": 1}, {"recipe": {"ingredients": ["clam"], "method": "standard"}, "day": 1}]
	check.call(not bool(_row(Plan.describe(fake, "harbor_sea"), SARDINE)["prepared"]), "other broths are not the sardine component")
	fake.broths.append(_sardine_broth())
	fake.broths.append({"recipe": Broth.canonical({"ingredients": ["sardine", "ginger"], "method": "standard"}), "day": 2})
	check.call(_row(Plan.describe(fake, "harbor_sea"), SARDINE)["prepared_count"] == 2, "every completed sardine broth is counted")

	fake = _fake(3, SUPPLIERS["mountain"])
	fake.noodles = [{"recipe": {"flour": "wheat", "water": "clear", "cut": "thin", "method": "standard"}, "day": 1}]
	var wheat: Dictionary = _row(Plan.describe(fake, "mountain_clear"), BUCKWHEAT)
	check.call(not bool(wheat["prepared"]) and not bool(wheat["usable"]), "a wheat noodle is not the buckwheat component")
	fake.noodles.append(_buckwheat_noodle())
	var buckwheat: Dictionary = _row(Plan.describe(fake, "mountain_clear"), BUCKWHEAT)
	check.call(bool(buckwheat["prepared"]) and bool(buckwheat["usable"]) and buckwheat["stock"] == 0 and not bool(buckwheat["sample_ready"]) and not Plan.describe(fake, "mountain_clear")["ready"], "completed buckwheat noodle is browsable but not sample-ready at stock0")
	fake.stock = {BUCKWHEAT: 1}
	check.call(Plan.describe(fake, "mountain_clear")["ready"], "one sample plus the completed noodle makes the direction ready")
	fake.stock = {}
	# 토핑/기름 방향은 완성품 개념이 없다.
	fake.broths = [_sardine_broth()]
	fake.noodles = [_buckwheat_noodle()]
	check.call(not bool(_row(Plan.describe(fake, "citrus_clear"), CITRUS)["prepared"]) and not bool(_row(Plan.describe(fake, "shiitake_depth"), SHIITAKE)["prepared"]), "toppings are never satisfied by a broth or noodle")
	# 손상된 기록은 건너뛰지 않고 명시적 오류가 된다. 해당 슬롯의 방향만 오류이고 입력은 바뀌지 않는다.
	var broken_broths: Array = [[{"recipe": {}, "day": 1}], [{"day": 1}], [7],
		[{"recipe": {"ingredients": ["sardine", "ginger"], "method": "standard"}, "day": 1}],
		[{"recipe": {"ingredients": ["sardine"], "method": "unknown"}, "day": 1}]]
	for broken in broken_broths:
		fake.broths = broken
		var snapshot: String = fake.snapshot()
		var bad: Dictionary = Plan.describe(fake, "harbor_sea")
		check.call(str(bad["error"]) != "" and bad["ingredients"].is_empty() and not bool(bad["ready"]), "malformed broth archive is an explicit error: " + JSON.stringify(broken))
		check.call(fake.snapshot() == snapshot, "error projection does not mutate the input")
		check.call(str(Plan.describe(fake, "citrus_clear")["error"]) == "" and str(Plan.describe(fake, "mountain_clear")["error"]) == "", "a broth archive error stays on the broth direction")
	fake.broths = []
	fake.noodles = [{"recipe": {"flour": "buckwheat"}, "day": 1}]
	check.call(str(Plan.describe(fake, "mountain_clear")["error"]) != "" and str(Plan.describe(fake, "harbor_sea")["error"]) == "", "malformed noodle archive is an explicit error")
	fake.noodles = [{"recipe": {"flour": "buckwheat", "water": "clear", "cut": "thin", "method": "standard", "extra": 1}, "day": 1}]
	check.call(str(Plan.describe(fake, "mountain_clear")["error"]) != "", "extra noodle fields are an explicit error")


func _blockers() -> void:
	# 영업/제작/탐험 중: 공급처 길은 review 가 말하지 않는 잠금을 같은 거절 조건으로 덧붙인다.
	for kind in ["service", "craft", "trip"]:
		var busy: FakeState = _fake()
		busy.set(kind, true)
		var row: Dictionary = _row(Plan.describe(busy, "citrus_clear"), CITRUS)
		check.call(not bool(row["can_depart"]) and str(row["reason"]) != "" and row["fee"] == 3000, "supplier trip is blocked while busy: " + kind)
	var service: FakeState = _fake()
	service.service = true
	check.call(_row(Plan.describe(service, "citrus_clear"), CITRUS)["reason"].contains("영업"), "service reason names the service")
	var craft: FakeState = _fake()
	craft.craft = true
	check.call(_row(Plan.describe(craft, "citrus_clear"), CITRUS)["reason"].contains("만드는"), "craft reason names the crafting")
	# 이미 막힌 이유(등급 등)는 덮어쓰지 않는다.
	var locked: FakeState = _fake()
	locked.service = true
	locked.supplier_block = {"harbor": "가게 등급 2단계부터 갈 수 있어요."}
	check.call(_row(Plan.describe(locked, "harbor_sea"), SARDINE)["reason"] == "가게 등급 2단계부터 갈 수 있어요.", "a rank reason is kept while busy")
	# 샘플 길: 하루 1번/자금/가득 참 등 모든 이유는 review 문장 그대로다.
	for reason in ["오늘은 이미 출발했어요. 영업을 마친 뒤 다시 오세요.", "출발 비용 1,200원이 부족해요.", "연구 재료 보관함이 가득 찼어요. 먼저 시제품에 사용하세요.", "진행 중인 영업이나 탐색을 먼저 마치세요."]:
		var sampling: FakeState = _fake(2, SUPPLIERS["harbor"])
		sampling.sample_block = {"harbor": reason}
		var blocked_row: Dictionary = _row(Plan.describe(sampling, "harbor_sea"), SARDINE)
		check.call(blocked_row["mode"] == "sample" and not bool(blocked_row["can_depart"]) and blocked_row["reason"] == reason and blocked_row["fee"] == Harbor.FEE, "sample route passes the public review reason through: " + reason)
	# 완료 표시는 유지된 유료 시식 기록만 증명한다.
	var witnessed: FakeState = _fake()
	for id in ["citrus_clear", "sesame_depth", "harbor_sea", "mountain_clear", "shiitake_depth"]:
		witnessed.saved_records = [{"config": DirectionTests.witness(id)}]
		for entry in Plan.catalog(witnessed):
			check.call(bool(entry["tested"]) == (entry["id"] == id), "only the witnessed direction is tested: %s / %s" % [id, entry["id"]])
	witnessed.saved_records = [{"config": DirectionTests.witness("shiitake_depth", 1)}]
	check.call(Plan.describe(witnessed, "shiitake_depth")["tested"], "repeat topping portions witness the direction")
	# 같은 방향 증거가 둘이어도 한 번만 완료로 세고, 첫 기록이 아닌 증거도 인정한다.
	witnessed.saved_records = [{"config": DirectionTests.witness("harbor_sea")}, {"config": DirectionTests.witness("harbor_sea")}, {"config": DirectionTests.witness("citrus_clear")}]
	var snapshot: String = witnessed.snapshot()
	var tested_ids: Array = []
	for entry in Plan.catalog(witnessed):
		if bool(entry["tested"]):
			tested_ids.append(entry["id"])
	check.call(tested_ids == ["citrus_clear", "harbor_sea"], "duplicate and later witnesses mark each direction once, in catalog order")
	check.call(witnessed.snapshot() == snapshot, "witness projection does not mutate the records")
	witnessed.saved_records = []
	check.call(not Plan.describe(witnessed, "shiitake_depth")["tested"], "removing the witness removes the status")
	check.call(not Plan.describe(witnessed, "shiitake_depth")["ready"], "tested and ready are independent facts")
	# 시식 기록 때문에 재료가 준비된 것으로 바뀌지도 않는다.
	witnessed.saved_records = [{"config": DirectionTests.witness("harbor_sea")}]
	check.call(not _row(Plan.describe(witnessed, "harbor_sea"), SARDINE)["usable"], "a record does not make materials usable")


func _bad_input() -> void:
	var fake: FakeState = _fake()
	for bad in ["", "unknown", "CITRUS_CLEAR", " harbor_sea", "harbor_sea "]:
		var plan: Dictionary = Plan.describe(fake, bad)
		check.call(str(plan["error"]) != "" and plan["id"] == bad and plan["ingredients"].is_empty() and not bool(plan["tested"]), "bad direction id is an explicit error: '%s'" % bad)
	var no_state: Dictionary = Plan.describe(null, "citrus_clear")
	check.call(str(no_state["error"]) != "" and no_state["ingredients"].is_empty(), "missing state is an explicit error")
	var wrong: Dictionary = Plan.describe(RefCounted.new(), "citrus_clear")
	check.call(str(wrong["error"]) != "", "an object without the public reviews is an explicit error")
	var plans: Array = Plan.catalog(null)
	check.call(plans.size() == 5, "bad state still reports five entries")
	for plan in plans:
		check.call(str(plan["error"]) != "", "bad state entry is an error")
	var freed := RefCounted.new()
	check.call(Plan.describe(freed, "x")["error"] != "", "unknown direction on a wrong object is an error")


# ---------- 실제 GameState ----------

func _json(state: Object) -> String:
	return JSON.stringify(state.to_dict(), "", true)


func _real_state() -> void:
	var fresh := Game.new()
	var before: String = _json(fresh)
	var plans: Array = Plan.catalog(fresh)
	check.call(_json(fresh) == before, "real new game: projection changes no saved state")
	check.call(plans.size() == 5 and plans[0]["id"] == Directions.catalog()[0]["id"], "real catalog order")
	for plan in plans:
		check.call(plan["error"] == "" and not bool(plan["tested"]) and not bool(plan["ready"]), "real new game: nothing earned: " + str(plan["id"]))
		for row in plan["ingredients"]:
			check.call(row["mode"] == "supplier" and row["stock"] == 0 and not bool(row["usable"]) and not bool(row["prepared"]), "real new game row is a supplier with no stock: " + str(row["id"]))
	check.call(bool(_row(plans[0], CITRUS)["can_depart"]) and _row(plans[0], CITRUS)["fee"] == Exploration.find_region("market")["fee"], "real new game market trip is available")
	var sardine: Dictionary = _row(plans[2], SARDINE)
	check.call(not bool(sardine["can_depart"]) and str(sardine["reason"]) != "" and sardine["fee"] == Exploration.find_region("harbor")["fee"], "real new game harbor trip shows its rank blocker")
	check.call(fresh.exploration_region("harbor")["reason"] == sardine["reason"], "the reason is the public GameState review")
	var loaded := Game.new()
	check.call(loaded.load_from_dict(fresh.to_dict()) == "" and JSON.stringify(Plan.catalog(loaded)) == JSON.stringify(plans), "real saved-state round trip keeps the same plan")

	# 진행 중 탐험: 같은 지역 출발은 막히고, 계획은 그 사실만 보여 준다.
	var st := Game.new()
	var started: Dictionary = st.start_expedition("market")
	check.call(bool(started["ok"]), "real market departure for the active-trip case")
	if not bool(started["ok"]):
		return
	before = _json(st)
	var active: Dictionary = _row(Plan.describe(st, "citrus_clear"), CITRUS)
	check.call(not bool(active["can_depart"]) and str(active["reason"]) != "" and _json(st) == before, "real active trip blocks departure without changing state")
	check.call(not bool(_row(Plan.describe(st, "harbor_sea"), SARDINE)["can_depart"]), "an active trip blocks every route")
	var money: int = st.wallet
	var retired: Dictionary = st.retire_expedition()
	check.call(bool(retired["ok"]), "real canceled trip")
	before = _json(st)
	var canceled: Dictionary = _row(Plan.describe(st, "citrus_clear"), CITRUS)
	check.call(canceled["suppliers_found"] == 0 and canceled["mode"] == "supplier" and not bool(canceled["can_depart"]) and st.wallet == money, "a canceled trip finds no supplier and the day is spent")
	check.call(_json(st) == before, "projection after cancel changes nothing")
	var round_trip := Game.new()
	check.call(round_trip.load_from_dict(st.to_dict()) == "" and JSON.stringify(Plan.catalog(round_trip)) == JSON.stringify(Plan.catalog(st)), "canceled-trip save round trip keeps the plan")

	# 실제로 공급처 한 곳을 찾은 상태.
	var found := Game.new()
	var steps: Array = [found.start_expedition("market"), found.advance_expedition("m_ask"), found.advance_expedition("m_hear_recipe"), found.finish_expedition()]
	var all_ok: bool = true
	for step in steps:
		all_ok = all_ok and bool(step["ok"])
	check.call(all_ok, "real first market supplier found")
	if all_ok:
		before = _json(found)
		var citrus: Dictionary = _row(Plan.describe(found, "citrus_clear"), CITRUS)
		check.call(citrus["suppliers_found"] == 1 and citrus["mode"] == "supplier" and citrus["status"] == "공급처 1/2곳 발견", "real one supplier keeps supplier routing")
		check.call(not bool(citrus["can_depart"]) and str(citrus["reason"]) != "" and not bool(citrus["usable"]), "real daily departure is spent after the trip")
		check.call(_json(found) == before, "projection after a real discovery changes nothing")
		var again := Game.new()
		check.call(again.load_from_dict(found.to_dict()) == "" and JSON.stringify(Plan.catalog(again)) == JSON.stringify(Plan.catalog(found)), "one-supplier save round trip keeps the plan")


# ---------- 실제 공개 거래로 만든 상태 (파일/주입 없음) ----------

func _must(result: Dictionary, label: String) -> bool:
	check.call(bool(result["ok"]), label + ": " + str(result.get("message", "")))
	return bool(result["ok"])


## 시장: 실제로 공급처 두 곳과 영업을 거쳐 샘플을 채집하고, 두 접시 시식으로 소모한다.
func _real_market_sample() -> void:
	var tests = MarketTests.new()
	tests.check = check
	var state = tests.ready()
	if not state.foraging_review()["can_start"]:
		return
	tests._collect(state, "citrus_cart", "take_three")
	var saved: String = _json(state)
	var row: Dictionary = _row(Plan.describe(state, "citrus_clear"), CITRUS)
	check.call(_json(state) == saved, "real sample projection changes no saved state")
	check.call(row["stock"] == 3 and bool(row["unlocked"]) and bool(row["sample_ready"]) and row["required_samples"] == 1, "collected citrus funds a one-portion tasting")
	if not _must(state.set_draft_toppings([CITRUS, CITRUS]), "two citrus portions in the draft"):
		return
	row = _row(Plan.describe(state, "citrus_clear"), CITRUS)
	check.call(row["required_samples"] == 2 and bool(row["sample_ready"]) and row["status"] == "연구 샘플 3/2개", "the actual draft requires two samples")
	if not _must(state.taste(), "paid two-portion citrus tasting"):
		return
	check.call(state.sample_stock(CITRUS) == 1, "the real tasting consumed two samples")
	row = _row(Plan.describe(state, "citrus_clear"), CITRUS)
	check.call(row["stock"] == 1 and row["required_samples"] == 2 and not bool(row["sample_ready"]), "stock1 cannot fund the same two-portion draft")
	if not _must(state.set_draft_toppings([CITRUS]), "one citrus portion in the draft"):
		return
	row = _row(Plan.describe(state, "citrus_clear"), CITRUS)
	check.call(row["required_samples"] == 1 and bool(row["sample_ready"]) and Plan.describe(state, "citrus_clear")["ready"], "stock1 funds a one-portion draft")
	if not _must(state.taste(), "paid one-portion citrus tasting"):
		return
	saved = _json(state)
	var plan: Dictionary = Plan.describe(state, "citrus_clear")
	row = _row(plan, CITRUS)
	check.call(state.sample_stock(CITRUS) == 0 and bool(row["unlocked"]) and row["stock"] == 0, "real citrus is still known but its samples are spent")
	check.call(not bool(row["sample_ready"]) and not bool(row["usable"]) and not bool(plan["ready"]) and plan["focus"] == CITRUS, "known with stock0 is not ready")
	check.call(_json(state) == saved, "reading spent samples changes no saved state")


## 항구: 정어리 샘플로 실제 육수를 개발/적용하고 시식으로 샘플을 소모해도 완성품은 남는다.
func _real_harbor_archive() -> void:
	var tests = HarborTests.new()
	tests.check = check
	var state = tests.ready()
	if not state.harbor_foraging_review()["can_start"]:
		return
	tests.collect(state, "sardine_boat", "take_one")
	if not _must(state.set_broth_blend(["sardine"], "standard"), "sardine broth blend"):
		return
	if not _must(state.begin_broth(), "begin sardine broth"):
		return
	var finished: Dictionary = state.advance_broth(120.0)
	if not _must(finished, "sardine broth finishes") or not _must(state.use_broth(int(finished["index"])), "apply the developed broth"):
		return
	var row: Dictionary = _row(Plan.describe(state, "harbor_sea"), SARDINE)
	check.call(row["stock"] == 1 and bool(row["prepared"]) and row["prepared_count"] == 1 and bool(row["sample_ready"]), "developed broth plus one sample funds a tasting")
	if not _must(state.taste(), "paid tasting with the developed sardine broth"):
		return
	var saved: String = _json(state)
	var plan: Dictionary = Plan.describe(state, "harbor_sea")
	row = _row(plan, SARDINE)
	check.call(_json(state) == saved, "projection of the real archive changes no saved state")
	check.call(state.sample_stock(SARDINE) == 0 and bool(row["unlocked"]), "the real tasting spent the only sardine sample")
	check.call(bool(row["prepared"]) and row["prepared_count"] == 1 and bool(row["usable"]) and not bool(row["sample_ready"]) and not bool(plan["ready"]), "archive stays browsable at stock0 but is not sample-ready")
	check.call(row["status"] == "연구 샘플 0/1개 · 완성품 1개" and str(plan["error"]) == "", "status shows the shortage and the kept product")
	if not _must(state.set_draft_price(int(state.draft_config["price"]) + 100), "changed prototype"):
		return
	row = _row(Plan.describe(state, "harbor_sea"), SARDINE)
	check.call(not bool(row["sample_ready"]) and bool(row["prepared"]), "a changed prototype still needs a sample")
	saved = _json(state)
	check.call(not bool(state.taste()["ok"]) and _json(state) == saved, "the real tasting also refuses without a sample")


# ---------- 보드 ----------

func _node(board: Control, node_name: String) -> Node:
	return board.find_child(node_name, true, false)


func _texts(node: Node) -> Array:
	var out: Array = []
	for child in node.get_children():
		if child is Label:
			out.append(str(child.text))
		out.append_array(_texts(child))
	return out


func _buttons(node: Node) -> Array:
	var out: Array = []
	for child in node.get_children():
		if child is Button:
			out.append(child)
		out.append_array(_buttons(child))
	return out


func _board() -> void:
	var fake: FakeState = _fake(2, SUPPLIERS["harbor"])
	fake.sample_block = {"harbor": BLOCKED}
	fake.broths = [_sardine_broth()]
	var before: String = fake.snapshot()
	var board := Board.new()
	var events: Array = []
	board.target_selected.connect(func(direction_id: String) -> void: events.append(["target", direction_id]))
	board.source_requested.connect(func(direction_id: String, ingredient_id: String) -> void: events.append(["source", direction_id, ingredient_id]))
	board.develop_requested.connect(func(direction_id: String, ingredient_id: String) -> void: events.append(["develop", direction_id, ingredient_id]))
	board.present(fake, "", false)

	# 목록: 다섯 개의 전체 카드 버튼, 상세 전용 버튼은 없다.
	for definition in Directions.catalog():
		var open: Node = _node(board, "GoalOpen_" + str(definition["id"]))
		check.call(open is Button, "list card is a real button: " + str(definition["id"]))
		if open is Button:
			check.call(not (open as Button).disabled and (open as Button).custom_minimum_size.y >= 78.0, "list card is enabled and at least 78px tall")
			check.call("accessibility_name" not in open or str(open.get("accessibility_name")) != "", "list card has an accessible name")
	check.call(_node(board, "GoalBoardBack") == null and _node(board, "GoalSelect_harbor_sea") == null and _node(board, "GoalSource_" + SARDINE) == null, "list shows no detail buttons")
	check.call(_buttons(board).size() == 5, "list has exactly five buttons")
	for text in _texts(board):
		check.call(str(text).length() <= 70, "list text stays concise: " + str(text))
	var first_open: Node = _node(board, "GoalOpen_citrus_clear")
	board.present(fake, "", false)
	check.call(_node(board, "GoalOpen_citrus_clear") == first_open, "same model keeps the same nodes (no rebuild mid-press)")

	# 카드 눌림: 글자가 흰색이 되고, 손을 떼면 원래 색으로, 드래그 취소는 신호가 없다.
	var open_button: Button = _node(board, "GoalOpen_harbor_sea") as Button
	var title: Label = open_button.get_parent().find_child("GoalCardTitle", true, false) as Label
	var ink: Color = title.get_theme_color("font_color")
	open_button.button_down.emit()
	check.call(title.get_theme_color("font_color") == Color.WHITE, "pressed card recolors its title")
	open_button.button_up.emit()
	check.call(title.get_theme_color("font_color") == ink and events.is_empty() and board.detail_id() == "", "drag cancel restores color and navigates nowhere")
	check.call(title.mouse_filter == Control.MOUSE_FILTER_IGNORE, "card text never steals input from the button")

	# 열기는 화면 안의 이동일 뿐 신호가 없다.
	open_button.pressed.emit()
	check.call(board.detail_id() == "harbor_sea" and events.is_empty(), "opening a goal emits nothing")
	var back: Node = _node(board, "GoalBoardBack")
	check.call(back is Button, "detail has a back button")
	check.call(_node(board, "GoalSource_" + SARDINE) is Button and _node(board, "GoalSource_" + SCALLOP) is Button, "both harbor materials have a source button")
	var develop_sardine: Button = _node(board, "GoalDevelop_" + SARDINE) as Button
	var develop_scallop: Button = _node(board, "GoalDevelop_" + SCALLOP) as Button
	check.call(develop_sardine != null and develop_scallop != null, "every material has an explicit experiment button")
	check.call(not develop_sardine.disabled and develop_sardine.text == "완성한 육수 보기", "completed broth at stock0 can still open its library")
	check.call(develop_scallop.disabled and develop_scallop.text == "이 재료로 실험", "an unusable ordinary topping cannot start an experiment")
	check.call(_node(board, "GoalSelect_harbor_sea") is Button and _node(board, "GoalOpen_citrus_clear") == null, "detail shows select, not the list")
	check.call(_node(board, "GoalArt_" + SARDINE) is TextureRect and _node(board, "GoalArt_" + SCALLOP) is TextureRect, "actual ingredient pictures are shown")
	check.call(_texts(board).has(BLOCKED), "the real departure blocker is shown")
	check.call(_texts(board).has("연구 샘플 0/1개 · 완성품 1개"), "stock0 completed broth status shows the sample shortage and the product")
	check.call(_texts(board).has("새 시식에는 연구 샘플 1개가 필요해요."), "the tasting sample shortage is stated")
	for text in _texts(board):
		check.call(str(text).length() <= 70, "detail text stays concise: " + str(text))
	for button in _buttons(board):
		check.call(str(button.name) != "" and str(button.text) != "" and ("accessibility_name" not in button or str(button.get("accessibility_name")) != ""), "detail button is named and labeled: " + str(button.name))

	# 길 버튼은 막혀 있어도 열람 신호를 보낸다(ID 만).
	var source: Button = _node(board, "GoalSource_" + SARDINE) as Button
	check.call(not source.disabled, "a blocked departure still allows opening the destination")
	source.pressed.emit()
	check.call(events == [["source", "harbor_sea", SARDINE]], "source request carries direction and ingredient only")
	events.clear()
	(_node(board, "GoalSource_" + SCALLOP) as Button).pressed.emit()
	develop_sardine.pressed.emit()
	check.call(events == [["source", "harbor_sea", SCALLOP], ["develop", "harbor_sea", SARDINE]], "second material and completed-component requests are ids only")
	events.clear()
	develop_scallop.pressed.emit()
	check.call(events.is_empty(), "an unusable material emits nothing even if the signal is forced")
	# 누르다 취소해도 신호가 없다.
	source.button_down.emit()
	source.button_up.emit()
	check.call(events.is_empty(), "canceled press emits nothing")

	# 목표 선택: 신호만 보내고 화면 이동/적용은 없다. 선택은 호출자가 다시 present 해야 바뀐다.
	var select: Button = _node(board, "GoalSelect_harbor_sea") as Button
	check.call(not select.disabled, "idle selection is enabled")
	select.pressed.emit()
	check.call(events == [["target", "harbor_sea"]] and board.detail_id() == "harbor_sea", "selecting only reports the id and does not navigate")
	events.clear()
	board.present(fake, "harbor_sea", false)
	var chosen: Button = _node(board, "GoalSelect_harbor_sea") as Button
	check.call(chosen.disabled and board.detail_id() == "harbor_sea" and chosen.text == "선택한 목표", "the selected goal is shown as chosen")

	# 바쁨: 선택만 잠기고 열람은 계속 된다.
	board.present(fake, "", true)
	var busy_select: Button = _node(board, "GoalSelect_harbor_sea") as Button
	check.call(busy_select.disabled, "selection is disabled during busy work")
	busy_select.pressed.emit()
	check.call(events.is_empty(), "busy selection emits nothing even if the signal is forced")
	var busy_source: Button = _node(board, "GoalSource_" + SARDINE) as Button
	var busy_develop: Button = _node(board, "GoalDevelop_" + SARDINE) as Button
	check.call(busy_source.disabled and busy_develop.disabled and not (_node(board, "GoalBoardBack") as Button).disabled, "source and develop are inert while busy, navigation stays")
	busy_source.pressed.emit()
	busy_develop.pressed.emit()
	check.call(events.is_empty(), "busy source and develop emit nothing even if forced")
	# 순위/날짜/자금으로 막힌 출발은 열람을 막지 않는다(바쁘지 않을 때).
	board.present(fake, "", false)
	check.call(not (_node(board, "GoalSource_" + SARDINE) as Button).disabled, "a blocked departure never blocks browsing when idle")
	board.present(fake, "", true)

	# 뒤로: 목록으로 돌아가고 신호가 없다.
	(_node(board, "GoalBoardBack") as Button).pressed.emit()
	check.call(board.detail_id() == "" and _node(board, "GoalOpen_harbor_sea") is Button and events.is_empty(), "back returns to the list silently")
	check.call(fake.snapshot() == before, "board interaction never changes the state")
	check.call(JSON.stringify(board.shown_model()).length() > 0 and board.shown_model()["busy"] == true, "shown model is an inspectable copy")

	# 두 방향 상세: 한 재료 방향에는 길 버튼 하나, 토핑 방향에는 개발 버튼이 없다.
	board.open_detail("shiitake_depth")
	check.call(_node(board, "GoalSource_" + SHIITAKE) is Button and (_node(board, "GoalDevelop_" + SHIITAKE) as Button).disabled, "topping experiment is disabled while it has no sample")
	var stocked := _fake(3, SUPPLIERS["mountain"])
	stocked.stock = {SHIITAKE: 1}
	board.present(stocked, "", false)
	var experiment: Button = _node(board, "GoalDevelop_" + SHIITAKE) as Button
	check.call(not experiment.disabled and experiment.text == "이 재료로 실험", "a stocked topping offers the explicit experiment callback")
	events.clear()
	experiment.pressed.emit()
	check.call(events == [["develop", "shiitake_depth", SHIITAKE]], "experiment request carries ids only")
	check.call(board.detail_id() == "shiitake_depth", "detail stays after present")
	board.open_detail("unknown")
	check.call(board.detail_id() == "shiitake_depth", "unknown detail id is ignored")
	# 방향 목록이 바뀌어 상세 대상이 사라지면 목록으로 돌아간다(상태 오류).
	board.present(null, "", false)
	check.call(board.detail_id() == "" and _node(board, "GoalBoardNotice") != null and _buttons(board).is_empty(), "invalid state shows a notice instead of buttons")
	board.present(Game.new(), "citrus_clear", false)
	check.call(_buttons(board).size() == 5, "real new game builds the list")
	board.free()
