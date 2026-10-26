extends RefCounted
## 입력값/저장 데이터 검증 도구.
## JSON 파싱은 모든 숫자를 float로 돌려주므로 "정수로 표현 가능한 값"만 정수로 인정한다.
## (bool, 문자열, 소수, NaN/무한대는 모두 거부한다.)

const Catalog = preload("res://scripts/domain/ingredient_catalog.gd")
const ProcessRules = preload("res://scripts/domain/recipe_process.gd")
const Noodle = preload("res://scripts/domain/noodle_workshop.gd")
const Broth = preload("res://scripts/domain/broth_workshop.gd")

## 정규 구성의 키(토핑은 "toppings" 배열). 옛 구성(v1/v2 저장, 예전 시험 조합)은 "topping" 문자열 하나를 쓴다.
const CONFIG_KEYS: Array = ["broth", "tare", "oil", "noodle", "toppings", "cook", "price"]
const LEGACY_CONFIG_KEYS: Array = ["broth", "tare", "oil", "noodle", "topping", "cook", "price"]
const NAME_MAX: int = 20


static func is_whole(v: Variant) -> bool:
	var t: int = typeof(v)
	if t == TYPE_INT:
		return true
	if t == TYPE_FLOAT:
		var f: float = v
		return is_finite(f) and absf(f) < 1.0e12 and f == floorf(f)
	return false


static func in_range(v: Variant, lo: int, hi: int) -> bool:
	if not is_whole(v):
		return false
	var n: int = int(v)
	return n >= lo and n <= hi


## 기대 키와 정확히 일치해야 한다. 누락/미지의 키 모두 거부해 일부만 받아들이는 일을 막는다.
static func keys_error(d: Dictionary, expected: Array, ctx: String) -> String:
	for k in expected:
		if not d.has(k):
			return "%s: 항목 누락 (%s)" % [ctx, str(k)]
	for k in d.keys():
		if not expected.has(k):
			return "%s: 알 수 없는 항목 (%s)" % [ctx, str(k)]
	return ""


## 길이와 제어문자만 검사한다(앞뒤 공백 정리는 호출자의 책임).
static func name_error(text: String, allow_empty: bool) -> String:
	if text.length() == 0:
		return "" if allow_empty else "레시피 이름을 입력하세요."
	if text.length() > NAME_MAX:
		return "레시피 이름은 %d자까지예요." % NAME_MAX
	for i in text.length():
		var c: int = text.unicode_at(i)
		if c < 32 or c == 127:
			return "이름에 쓸 수 없는 문자가 있어요."
	return ""


## 메모리 상의 설정(이미 정수 가격)을 검증한다. 정규 모양("toppings" 배열 1~MAX_TOPPINGS개, 알려진 id, 중복 분량 허용)과
## 옛 모양("topping" 하나) 둘 다 받는다. 토핑 순서는 여기서 따지지 않는다(순서만 다르면 같은 구성: 정규화/same_config 참고).
## 슬롯 수 한도(등급/조리대)는 상태(GameState)가 정하므로 여기서는 절대 상한만 본다.
static func config_error(config: Dictionary) -> String:
	var legacy: bool = not config.has("toppings")
	var expected: Array = LEGACY_CONFIG_KEYS if legacy else CONFIG_KEYS
	if not legacy and config.has("process"):
		expected = CONFIG_KEYS + ["process"]
	if not legacy and config.has("noodle_recipe"):
		expected = expected + ["noodle_recipe"]
	if not legacy and config.has("broth_recipe"):
		expected = expected + ["broth_recipe"]
	var key_err: String = keys_error(config, expected, "레시피 구성")
	if key_err != "":
		return key_err
	if config.has("process"):
		var process_error: String = ProcessRules.error(config["process"])
		if process_error != "":
			return process_error
	if config.has("broth_recipe"):
		var broth_error: String = Broth.error(config["broth_recipe"])
		if broth_error != "": return broth_error
		if config["broth"] != Broth.base_id(config["broth_recipe"]): return "육수 종류가 원재료 배합과 달라요."
		if config["broth_recipe"]["method"] != ProcessRules.selected(config.get("process",{}),"broth"):
			return "육수를 우린 방식과 라멘 공법이 달라요."
	if config.has("noodle_recipe"):
		var noodle_error: String=Noodle.error(config["noodle_recipe"])
		if noodle_error!="": return noodle_error
		if config["noodle"]!=Noodle.base_id(config["noodle_recipe"]): return "면 종류가 제면 배합과 달라요."
		if config["noodle_recipe"]["method"]!=ProcessRules.selected(config.get("process",{}),"noodle"): return "제면 방식과 라멘 공법이 달라요."
	for slot in Catalog.SLOTS:
		if slot == Catalog.TOPPING_SLOT:
			continue
		var v: Variant = config[slot]
		if typeof(v) != TYPE_STRING or not Catalog.is_valid(slot, str(v)):
			return "알 수 없는 재료입니다 (%s)." % slot
	var top_err: String = _toppings_error(config, legacy)
	if top_err != "":
		return top_err
	var price: Variant = config["price"]
	if typeof(price) != TYPE_INT:
		return "가격은 정수여야 해요."
	var p: int = price
	if p < Catalog.PRICE_MIN or p > Catalog.PRICE_MAX or p % Catalog.PRICE_STEP != 0:
		return "가격은 %d~%d원, %d원 단위여야 해요." % [Catalog.PRICE_MIN, Catalog.PRICE_MAX, Catalog.PRICE_STEP]
	return ""


static func _toppings_error(config: Dictionary, legacy: bool) -> String:
	if legacy:
		var one: Variant = config["topping"]
		if typeof(one) != TYPE_STRING or not Catalog.is_valid(Catalog.TOPPING_SLOT, str(one)):
			return "알 수 없는 재료입니다 (topping)."
		return ""
	var raw: Variant = config["toppings"]
	if typeof(raw) != TYPE_ARRAY:
		return "토핑 목록 구조가 올바르지 않아요."
	var list: Array = raw
	if list.size() < 1:
		return "토핑은 최소 1개를 골라야 해요."
	if list.size() > Catalog.MAX_TOPPINGS:
		return "토핑은 최대 %d개까지예요." % Catalog.MAX_TOPPINGS
	# Each repeated ID is a paid portion, bounded by the total position count.
	for v in list:
		if typeof(v) != TYPE_STRING or not Catalog.is_valid(Catalog.TOPPING_SLOT, str(v)):
			return "알 수 없는 재료입니다 (topping)."
	return ""


## 저장 파일 등 외부에서 온 값을 정규화(float→int)한 뒤 검증한다.
## legacy=true 는 v1/v2 저장의 구성("topping" 하나, "toppings" 없음)이다: 정규 구성으로 바꿔 돌려준다(점수/원가/시간은 같다).
## legacy=false(v3)는 "toppings" 배열이 카탈로그 순서로 정렬돼 있어야 한다(섞인 순서는 변조/손상으로 거부).
## 반환: {"error": String, "config": Dictionary(정규 모양)}
static func parse_config(raw: Variant, ctx: String, legacy: bool = false) -> Dictionary:
	if typeof(raw) != TYPE_DICTIONARY:
		return {"error": ctx + ": 구조가 올바르지 않아요.", "config": {}}
	var d: Dictionary = raw
	var expected: Array = LEGACY_CONFIG_KEYS if legacy else CONFIG_KEYS
	if not legacy and d.has("process"):
		expected = CONFIG_KEYS + ["process"]
	if not legacy and d.has("noodle_recipe"):
		expected = expected + ["noodle_recipe"]
	if not legacy and d.has("broth_recipe"):
		expected = expected + ["broth_recipe"]
	var key_err: String = keys_error(d, expected, ctx)
	if key_err != "":
		return {"error": key_err, "config": {}}
	var config: Dictionary = {}
	for slot in Catalog.SLOTS:
		if slot == Catalog.TOPPING_SLOT:
			continue
		config[slot] = d[slot]
	if legacy:
		config["topping"] = d["topping"]
	else:
		config["toppings"] = d["toppings"]
	if d.has("process"):
		config["process"] = d["process"]
	if d.has("noodle_recipe"):
		config["noodle_recipe"] = d["noodle_recipe"]
	if d.has("broth_recipe"):
		config["broth_recipe"] = d["broth_recipe"]
	if not is_whole(d["price"]):
		return {"error": ctx + ": 가격 형식이 올바르지 않아요.", "config": {}}
	config["price"] = int(d["price"])
	var err: String = config_error(config)
	if err != "":
		return {"error": ctx + ": " + err, "config": {}}
	var canonical: Dictionary = Catalog.normalize_config(config)
	if d.has("broth_recipe") and d["broth_recipe"] != canonical["broth_recipe"]:
		return {"error":ctx+": 육수 원재료 순서가 올바르지 않아요.","config":{}}
	if d.has("process") and not canonical.has("process"):
		return {"error": ctx + ": 기본 공법은 별도 키 없이 저장해야 해요.", "config": {}}
	if not legacy:
		var given: Array = []
		for t in Catalog.toppings_of(config):
			given.append(t)
		if str(given) != str(canonical["toppings"]):
			return {"error": ctx + ": 토핑 순서가 올바르지 않아요.", "config": {}}
	return {"error": "", "config": canonical}


## 구성이 같은지: 옛/정규 모양을 가리지 않고, 토핑은 순서와 무관하게 같은 종류별 분량이면 같은 구성이다(중복을 제거하지 않는다).
static func same_config(a: Dictionary, b: Dictionary) -> bool:
	var na: Dictionary = Catalog.normalize_config(a)
	var nb: Dictionary = Catalog.normalize_config(b)
	for k in CONFIG_KEYS:
		if not na.has(k) or not nb.has(k):
			return false
		if k == "toppings":
			if str(na[k]) != str(nb[k]):
				return false
		elif na[k] != nb[k]:
			return false
	return na.get("process", {}) == nb.get("process", {}) and na.get("broth_recipe",{}) == nb.get("broth_recipe",{}) and na.get("noodle_recipe",{}) == nb.get("noodle_recipe",{})
