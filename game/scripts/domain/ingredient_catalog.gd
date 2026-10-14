extends RefCounted
## 재료 데이터. 모든 재료는 여기 데이터로만 정의하고 UI/평가 코드는 id로 참조한다.
##
## 맛 축(axes)은 0~10 정수 척도의 다섯 가지:
##   rich(진함) salt(염도) aroma(향) chew(면 식감) spice(매운맛)
## 각 재료는 축에 정수 기여값을 더한다. 합산 결과는 평가기에서 0~10으로 제한한다.
## id는 슬롯 접두사를 포함해 전체에서 유일하다(예: broth_tonkotsu).

const AXES: Array[String] = ["rich", "salt", "aroma", "chew", "spice"]

const AXIS_NAMES: Dictionary = {
	"rich": "진함",
	"salt": "염도",
	"aroma": "향",
	"chew": "면 식감",
	"spice": "매운맛",
}

const SLOTS: Array[String] = ["broth", "tare", "oil", "noodle", "topping", "cook"]

## 토핑만 여러 개를 고를 수 있다(상한은 등급 + 조리대 확장으로 정해지는 슬롯 수, 절대 상한 MAX_TOPPINGS).
## 나머지 슬롯(육수/타레/향미유/면/익힘)은 언제나 하나만 고른다.
const TOPPING_SLOT: String = "topping"
const MAX_TOPPINGS: int = 3

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


static func items(slot: String) -> Array:
	if not ITEMS.has(slot):
		return []
	return ITEMS[slot]


static func find(id: String) -> Dictionary:
	for slot in SLOTS:
		for item in items(slot):
			var d: Dictionary = item
			if str(d["id"]) == id:
				return d
	return {}


## id가 해당 슬롯에 실제로 존재하는지 확인한다.
static func is_valid(slot: String, id: String) -> bool:
	for item in items(slot):
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
##  - 정규: {"toppings": [id, ...]} (1~3개, 카탈로그 순서, 중복 없음). 메모리/기록/저장 v3의 유일한 표준 모양.
##  - 옛 모양: {"topping": id} 하나. v1/v2 저장과 예전 시험/증인 조합이 쓴다. 읽을 때만 정규로 바꾼다.
## 평가/원가/시간/궁합/장면 그림은 반드시 toppings_of()/item_ids()로만 토핑을 읽는다(구성["topping"]을 직접 읽지 않는다).
## 그래서 토핑이 하나인 옛 구성은 정규 구성과 점수·원가·시간이 정확히 같고, 여러 개여도 토핑마다 정확히 한 번씩 반영된다.

## 카탈로그 안에서의 토핑 순서(알 수 없는 id는 -1).
static func topping_order(id: String) -> int:
	var list: Array = items(TOPPING_SLOT)
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


## 토핑 id를 카탈로그 순서로 정렬한 새 배열(중복은 그대로 남겨 검증이 잡게 한다). 순서만 다른 구성은 같은 구성이다.
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
	for slot in SLOTS:
		if slot == TOPPING_SLOT:
			out["toppings"] = canonical_toppings(toppings_of(config))
		elif config.has(slot):
			out[slot] = config[slot]
	if config.has("price"):
		out["price"] = config["price"]
	return out


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
	for t in canonical_toppings(toppings_of(config)):
		var item: Dictionary = find(str(t))
		names.append(str(item["name"]) if not item.is_empty() else str(t))
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
