extends RefCounted
## 재료 데이터. 모든 재료는 여기 데이터로만 정의하고 UI/평가 코드는 id로 참조한다.
##
## 맛 축(axes)은 0~10 정수 척도의 다섯 가지:
##   rich(진함) salt(염도) aroma(향) chew(면 식감) spice(매운맛)
## 각 재료는 축에 정수 기여값을 더한다. 합산 결과는 평가기에서 0~10으로 제한한다.
## id는 슬롯 접두사를 포함해 전체에서 유일하다(예: broth_tonkotsu).

const Noodle = preload("res://scripts/domain/noodle_workshop.gd")
const Broth = preload("res://scripts/domain/broth_workshop.gd")
const AXES: Array[String] = ["rich", "salt", "aroma", "chew", "spice"]

const AXIS_NAMES: Dictionary = {
	"rich": "진함",
	"salt": "염도",
	"aroma": "향",
	"chew": "면 식감",
	"spice": "매운맛",
}

const SLOTS: Array[String] = ["broth", "tare", "oil", "noodle", "topping", "cook"]

## 토핑만 여러 개를 고를 수 있다(상한은 가게 등급으로 열리는 슬롯 수, 절대 상한 MAX_TOPPINGS).
## 나머지 슬롯(육수/타레/향미유/면/익힘)은 언제나 하나만 고른다.
const TOPPING_SLOT: String = "topping"
const MAX_TOPPINGS: int = 4

const SLOT_NAMES: Dictionary = {
	"broth": "육수",
	"tare": "타레(간)",
	"oil": "향미유",
	"noodle": "면",
	"topping": "토핑",
	"cook": "익힘 정도",
}

const PRICE_MIN: int = 1000
const PRICE_MAX: int = 30000
const PRICE_STEP: int = 100
const DEFAULT_PRICE: int = 9000

# cost: 한 그릇 재료비(원), seconds: 한 그릇 준비 시간(초)
const ITEMS: Dictionary = {
	"broth": [
		{"id": "broth_tonkotsu", "name": "돼지뼈 진국", "cost": 900, "seconds": 35,
			"desc": "오래 우린 뽀얀 국물. 진하고 든든하지만 비싸고 시간이 걸려요.",
			"axes": {"rich": 6, "salt": 1, "aroma": 2}},
		{"id": "broth_chicken", "name": "맑은 닭 육수", "cost": 600, "seconds": 20,
			"desc": "깔끔하고 고소한 맑은 국물. 가볍고 빠르게 준비돼요.",
			"axes": {"rich": 3, "salt": 1, "aroma": 3}},
		{"id": "broth_dashi", "name": "해물 다시", "cost": 700, "seconds": 25,
			"desc": "멸치·다시마·가쓰오로 낸 국물. 향이 섬세하고 담백해요.",
			"axes": {"rich": 2, "salt": 2, "aroma": 4}},
	],
	"tare": [
		{"id": "tare_shoyu", "name": "간장 타레", "cost": 200, "seconds": 5,
			"desc": "짭짤하고 향이 있는 정석 간. 어떤 국물과도 무난해요.",
			"axes": {"salt": 4, "aroma": 2}},
		{"id": "tare_shio", "name": "소금 타레", "cost": 150, "seconds": 5,
			"desc": "맑고 깔끔한 간. 재료 본연의 맛을 드러내요.",
			"axes": {"salt": 3}},
		{"id": "tare_miso", "name": "된장 타레", "cost": 250, "seconds": 8,
			"desc": "구수하고 묵직한 간. 국물을 한 겹 더 진하게 만들어요.",
			"axes": {"rich": 2, "salt": 3, "aroma": 1}},
	],
	"oil": [
		{"id": "oil_garlic", "name": "마늘유", "cost": 150, "seconds": 5,
			"desc": "볶은 마늘 향이 확 올라와요. 강한 국물에 힘을 보태요.",
			"axes": {"rich": 1, "aroma": 3}},
		{"id": "oil_chili", "name": "고추기름", "cost": 180, "seconds": 5,
			"desc": "얼큰한 매운맛을 더해요. 매운 걸 못 먹는 손님도 있어요.",
			"axes": {"rich": 1, "aroma": 1, "spice": 5}},
		{"id": "oil_scallion", "name": "파기름", "cost": 120, "seconds": 5,
			"desc": "은은하게 달큰한 파 향. 맑은 국물과 잘 어울려요.",
			"axes": {"aroma": 2}},
	],
	"noodle": [
		{"id": "noodle_thin", "name": "가는 직면", "cost": 250, "seconds": 40,
			"desc": "빨리 삶기고 후루룩 넘어가요. 오래 익히면 쉽게 퍼져요.",
			"axes": {"chew": 3}},
		{"id": "noodle_medium", "name": "중간 물결면", "cost": 300, "seconds": 70,
			"desc": "국물을 적당히 머금는 균형 잡힌 면이에요.",
			"axes": {"chew": 5}},
		{"id": "noodle_thick", "name": "굵은 꼬불면", "cost": 400, "seconds": 100,
			"desc": "씹는 맛이 좋고 진한 국물이 잘 붙어요. 삶는 시간이 길어요.",
			"axes": {"chew": 7}},
	],
	"topping": [
		{"id": "topping_chashu", "name": "차슈", "cost": 700, "seconds": 15,
			"desc": "두툼한 돼지고기 조림. 든든하지만 원가가 가장 높아요.",
			"axes": {"rich": 1, "salt": 1}},
		{"id": "topping_egg", "name": "반숙란", "cost": 300, "seconds": 8,
			"desc": "부드러운 노른자가 국물을 순하게 감싸요.",
			"axes": {"rich": 1}},
		{"id": "topping_sprouts", "name": "숙주·파채", "cost": 150, "seconds": 6,
			"desc": "아삭한 채소로 느끼함을 덜고 향을 살려요.",
			"axes": {"rich": -1, "aroma": 1}},
		{"id": "topping_nori", "name": "김", "cost": 100, "seconds": 3,
			"desc": "바다 향과 약간의 짠맛. 가장 저렴한 마무리예요.",
			"axes": {"salt": 1, "aroma": 1}},
	],
	# 익힘은 면 식감(chew)에 직접 영향을 주고, 면 종류와의 궁합도 있다.
	"cook": [
		{"id": "cook_firm", "name": "꼬들하게", "cost": 0, "seconds": 0,
			"desc": "면을 덜 익혀 쫄깃해요. 가장 빠르게 나가요.",
			"axes": {"chew": 2}},
		{"id": "cook_normal", "name": "보통", "cost": 0, "seconds": 15,
			"desc": "표준 익힘. 면 본래의 식감 그대로예요.",
			"axes": {}},
		{"id": "cook_soft", "name": "푹 익힘", "cost": 0, "seconds": 30,
			"desc": "부드럽게 푹 익혀요. 오래 걸리고 식감은 약해져요.",
			"axes": {"chew": -2}},
	],
}


## 탐험으로 발견해야 열리는 재료 6개(면/익힘은 없음). 시작부터 쓸 수 있는 ITEMS 와 일부러 분리했다:
##  - items(slot)은 예전 재료만 돌려준다. 그래서 기존 조합 열거(972가지)와 시험이 늘어나지 않고, 예전 재료의 데이터/평가는 한 글자도 바뀌지 않는다.
##  - all_items(slot)은 예전 재료 뒤에 발견 재료를 붙인 전체(카탈로그 순서)다. find/is_valid/평가기/저장 검증은 전체를 안다.
##  - "region" 은 이 재료를 발견할 수 있는 지역 id(ingredient_exploration.gd 의 REGIONS 와 일치해야 한다).
## 발견 전에는 상태(GameState)가 선택/시식/불러오기를 막는다. 카탈로그는 "알려진 id 인가"만 안다(발견 여부는 상태의 몫).
## 모두 보편 상위호환이 아니다: 비용/시간/맛 축에 장단이 있고 손님마다 점수가 갈리며(시험으로 확인), 궁합 규칙도 장단이 있다.
const DISCOVERY_ITEMS: Dictionary = {
	"broth": [
		{"id": "broth_clam", "name": "조개 맑은탕", "cost": 800, "seconds": 28, "region": "harbor",
			"desc": "항구에서 갓 캔 조개로 낸 맑고 짭짤한 국물. 간과 향이 살지만 진한 맛은 약하고 비싸요.",
			"axes": {"rich": 2, "salt": 3, "aroma": 3}},
	],
	"tare": [
		{"id": "tare_plum", "name": "매실 타레", "cost": 260, "seconds": 8, "region": "market",
			"desc": "새콤달콤한 매실로 맞춘 간. 향은 살리지만 염도가 약하고 국물이 가벼워져요.",
			"axes": {"rich": -1, "salt": 2, "aroma": 2}},
	],
	"oil": [
		{"id": "oil_shrimp", "name": "새우유", "cost": 220, "seconds": 7, "region": "harbor",
			"desc": "새우 머리를 볶아 낸 기름. 진함과 향이 오르지만 맑은 국물에는 무거워요.",
			"axes": {"rich": 2, "aroma": 3, "spice": 1}},
		{"id": "oil_pepper", "name": "초피유", "cost": 200, "seconds": 6, "region": "mountain",
			"desc": "산초 열매로 낸 얼얼한 기름. 향과 매운맛이 오르고 매운 걸 못 먹는 손님은 힘들어해요.",
			"axes": {"aroma": 2, "spice": 3}},
	],
	"topping": [
		{"id": "topping_pickle", "name": "절임 무", "cost": 120, "seconds": 4, "region": "market",
			"desc": "아삭한 장터표 절임. 느끼함을 확 걷어내지만 국물의 진함도 같이 줄어요.",
			"axes": {"rich": -2, "salt": 1}},
		{"id": "topping_mushroom", "name": "표고 조림", "cost": 350, "seconds": 10, "region": "mountain",
			"desc": "산골 농가식 표고 조림. 진함과 향을 보태 주지만 원가와 손이 더 들어요.",
			"axes": {"rich": 2, "salt": 1, "aroma": 1}},
	],
}


static func items(slot: String) -> Array:
	if not ITEMS.has(slot):
		return []
	return ITEMS[slot]


## 발견 재료만(슬롯별). 없는 슬롯은 빈 목록.
static func discovery_items(slot: String) -> Array:
	if not DISCOVERY_ITEMS.has(slot):
		return []
	return DISCOVERY_ITEMS[slot]


## 전체 재료(예전 재료 먼저, 발견 재료 뒤). 순서는 토핑 정규 순서의 기준이다.
## Research-only samples are separate from the six permanent exploration
## unlocks. Old catalog enumeration and exploration receipts keep their meaning.
const FARMED_ITEMS: Dictionary = {
	"broth": [{"id": "broth_roasted_sardine", "name": "구운 정어리 육수", "short_name": "정어리 육수", "cost": 450, "seconds": 30, "region": "harbor",
		"desc": "항구의 작은 생선을 구워 낸 맑은 육수. 향이 강하고 간이 있지만 진함은 낮아요. 손질에는 시간이 들어요.", "axes": {"rich": 1, "salt": 2, "aroma": 5}}],
	"noodle": [{"id":"noodle_buckwheat", "name":"산메밀면", "cost":480, "seconds":65, "region":"mountain",
		"desc":"산골 제분소의 향긋한 메밀면. 식감이 단단하고 메밀 향이 있지만 가는 면보다 비싸고 천천히 삶아야 해요.", "axes":{"aroma":2,"chew":6}}],
	"oil": [{"id": "oil_roasted_sesame", "name": "볶은 참깨유", "cost": 240, "seconds": 12,
		"desc": "장터에서 구한 고소한 연구 재료. 진함과 향이 강하고 손질 시간이 길어요.", "axes": {"rich": 2, "aroma": 4}}],
	"topping": [{"id": "topping_citrus_peel", "name": "유자 껍질", "cost": 220, "seconds": 4,
		"desc": "장터의 산뜻한 노란 고명. 국물을 가볍게 하고 향을 더해요.", "axes": {"rich": -2, "aroma": 2}},
		{"id": "topping_scallop", "name": "가리비 고명", "cost": 550, "seconds": 16, "region": "harbor",
		"desc": "노릇하게 구운 항구 가리비. 진함과 향을 보태요. 겹쳐 넣으면 원가와 준비 시간도 함께 늘어요.", "axes": {"rich": 2, "aroma": 1}},
		{"id":"topping_grilled_shiitake", "name":"구운 산표고", "cost":460, "seconds":19, "region":"mountain",
		"desc":"농가에서 통째로 구운 산표고. 향과 씹는 맛은 더하지만 국물은 가벼워지고 준비 시간이 늘어요.", "axes":{"rich":-1,"aroma":3,"chew":1}}],
}


static func farmed_items(slot: String) -> Array:
	return FARMED_ITEMS.get(slot, [])


static func is_farmed(id: String) -> bool:
	for slot in FARMED_ITEMS:
		for item in FARMED_ITEMS[slot]:
			if item["id"] == id:
				return true
	return false


static func all_items(slot: String) -> Array:
	var out: Array = items(slot).duplicate()
	out.append_array(discovery_items(slot))
	out.append_array(farmed_items(slot))
	return out


## 발견해야 열리는 재료 id 전체(슬롯 순서).
static func discovery_ids() -> Array[String]:
	var out: Array[String] = []
	for slot in SLOTS:
		for item in discovery_items(slot):
			out.append(str((item as Dictionary)["id"]))
	return out


static func is_discovery(id: String) -> bool:
	return discovery_ids().has(id)


static func find(id: String) -> Dictionary:
	for slot in SLOTS:
		for item in all_items(slot):
			var d: Dictionary = item
			if str(d["id"]) == id:
				return d
	return {}


## id가 해당 슬롯에 실제로 존재하는지 확인한다(발견 재료도 "알려진 id"). 발견 여부는 여기서 보지 않는다.
static func is_valid(slot: String, id: String) -> bool:
	for item in all_items(slot):
		var d: Dictionary = item
		if str(d["id"]) == id:
			return true
	return false


## 기본 구성은 정규(canonical) 형태다: 토핑은 "toppings" 배열 하나(카탈로그 순서).
static func default_config() -> Dictionary:
	var config: Dictionary = {}
	for slot in SLOTS:
		var list: Array = items(slot)
		var first: Dictionary = list[0]
		if slot == TOPPING_SLOT:
			config["toppings"] = [str(first["id"])]
		else:
			config[slot] = str(first["id"])
	config["price"] = DEFAULT_PRICE
	return config


# ---------- 토핑 추출/정규화 (모든 계산이 쓰는 단 하나의 경로) ----------
##
## 구성 딕셔너리는 두 모양을 받는다.
##  - 정규: {"toppings": [id, ...]} (1~4개, 카탈로그 순서, 중복 분량 허용). 메모리/기록/저장 v12의 표준 모양.
##  - 옛 모양: {"topping": id} 하나. v1/v2 저장과 예전 시험/증인 조합이 쓴다. 읽을 때만 정규로 바꾼다.
## 평가/원가/시간/궁합/장면 그림은 반드시 toppings_of()/item_ids()로만 토핑을 읽는다(구성["topping"]을 직접 읽지 않는다).
## 그래서 토핑이 하나인 옛 구성은 정규 구성과 점수·원가·시간이 정확히 같고, 여러 개여도 토핑마다 정확히 한 번씩 반영된다.

## 카탈로그 안에서의 토핑 순서(알 수 없는 id는 -1).
static func topping_order(id: String) -> int:
	var list: Array = all_items(TOPPING_SLOT)
	for i in list.size():
		if str((list[i] as Dictionary)["id"]) == id:
			return i
	return -1


## 선택된 토핑 id를 입력 모양 그대로 꺼낸다(검증/정렬/중복 제거 없음). 배열이 아니면 빈 목록.
static func toppings_of(config: Dictionary) -> Array[String]:
	var out: Array[String] = []
	if config.has("toppings"):
		var raw: Variant = config["toppings"]
		if typeof(raw) == TYPE_ARRAY:
			for v in (raw as Array):
				out.append(str(v))
		return out
	if config.has("topping"):
		out.append(str(config["topping"]))
	return out


## 토핑 id를 카탈로그 순서로 정렬한 새 배열(중복은 분량이므로 그대로 남긴다). 순서만 다른 구성은 같은 구성이다.
static func canonical_toppings(ids: Array) -> Array:
	var out: Array = []
	for v in ids:
		out.append(str(v))
	out.sort_custom(func(a: String, b: String) -> bool:
		var oa: int = topping_order(a)
		var ob: int = topping_order(b)
		if oa != ob:
			return oa < ob
		return a < b)
	return out


## 옛 모양/정규 모양 어느 쪽이든 정규 구성(깊은 복사, 토핑 정렬)으로 바꾼다. 검증은 하지 않는다(Check.config_error 몫).
static func normalize_config(config: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	if config.has("noodle_recipe"):
		out["noodle_recipe"] = Noodle.canonical(config["noodle_recipe"])
	if config.has("broth_recipe"):
		out["broth_recipe"] = Broth.canonical(config["broth_recipe"])
	for slot in SLOTS:
		if slot == TOPPING_SLOT:
			out["toppings"] = canonical_toppings(toppings_of(config))
		elif config.has(slot):
			out[slot] = config[slot]
	if config.has("price"):
		out["price"] = config["price"]
	if config.has("process"):
		# 기본 공법은 예전 구성과 동일한 표현을 쓴다. 검증은 DataCheck가 하고 여기서는 사본만 만든다.
		var process: Variant = config["process"]
		if typeof(process) == TYPE_DICTIONARY:
			if not (process.size() == 2 and process.get("broth") == "standard" and process.get("noodle") == "standard") and not process.is_empty():
				out["process"] = process.duplicate(true)
		else:
			out["process"] = process
	return out


## A crafted broth replaces the catalog component; it is not an extra topping
## or a second score bonus. Historical configurations retain exact old values.
static func recipe_item(config: Dictionary, id: String) -> Dictionary:
	if config.has("broth_recipe") and id == str(config["broth"]):
		return Broth.product(config["broth_recipe"])
	if config.has("noodle_recipe") and id == str(config["noodle"]):
		return Noodle.product(config["noodle_recipe"])
	return find(id)


static func noodle_name(config: Dictionary) -> String:
	return str(recipe_item(config,str(config["noodle"]))["name"])


static func broth_name(config: Dictionary) -> String:
	return str(recipe_item(config,str(config["broth"]))["name"])


## 구성이 고른 모든 재료 id (슬롯 순서, 토핑은 선택한 개수만큼). 평가기의 원가/시간/프로필/궁합이 모두 이것을 훑는다.
static func item_ids(config: Dictionary) -> Array[String]:
	var out: Array[String] = []
	for slot in SLOTS:
		if slot == TOPPING_SLOT:
			for t in toppings_of(config):
				out.append(t)
		else:
			out.append(str(config[slot]))
	return out


## 화면용: 선택한 토핑 이름들을 " + "로 이은 글.
static func topping_names(config: Dictionary) -> String:
	var names: Array[String] = []
	var ids := canonical_toppings(toppings_of(config))
	var seen: Array[String] = []
	for value in ids:
		var id := str(value)
		if seen.has(id):
			continue
		seen.append(id)
		var item := find(id)
		var title := str(item["name"]) if not item.is_empty() else id
		var count := ids.count(id)
		names.append(title + (" ×%d" % count if count > 1 else ""))
	return " + ".join(names)


## "진함 +6, 염도 +1" 형태의 맛 기여 설명.
static func axes_text(item: Dictionary) -> String:
	var axes: Dictionary = item["axes"]
	var parts: Array[String] = []
	for axis in AXES:
		if axes.has(axis):
			var v: int = int(axes[axis])
			parts.append("%s %+d" % [str(AXIS_NAMES[axis]), v])
	if parts.is_empty():
		return "맛 변화 없음"
	return ", ".join(parts)
