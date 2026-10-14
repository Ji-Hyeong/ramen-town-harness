extends RefCounted
## 입력값/저장 데이터 검증 도구.
## JSON 파싱은 모든 숫자를 float로 돌려주므로 "정수로 표현 가능한 값"만 정수로 인정한다.
## (bool, 문자열, 소수, NaN/무한대는 모두 거부한다.)

const Catalog = preload("res://scripts/domain/ingredient_catalog.gd")

const CONFIG_KEYS: Array = ["broth", "tare", "oil", "noodle", "topping", "cook", "price"]
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


## 메모리 상의 설정(이미 정수 가격)을 검증한다.
static func config_error(config: Dictionary) -> String:
	var key_err: String = keys_error(config, CONFIG_KEYS, "레시피 구성")
	if key_err != "":
		return key_err
	for slot in Catalog.SLOTS:
		var v: Variant = config[slot]
		if typeof(v) != TYPE_STRING or not Catalog.is_valid(slot, str(v)):
			return "알 수 없는 재료입니다 (%s)." % slot
	var price: Variant = config["price"]
	if typeof(price) != TYPE_INT:
		return "가격은 정수여야 해요."
	var p: int = price
	if p < Catalog.PRICE_MIN or p > Catalog.PRICE_MAX or p % Catalog.PRICE_STEP != 0:
		return "가격은 %d~%d원, %d원 단위여야 해요." % [Catalog.PRICE_MIN, Catalog.PRICE_MAX, Catalog.PRICE_STEP]
	return ""


## 저장 파일 등 외부에서 온 값을 정규화(float→int)한 뒤 검증한다.
## 반환: {"error": String, "config": Dictionary}
static func parse_config(raw: Variant, ctx: String) -> Dictionary:
	if typeof(raw) != TYPE_DICTIONARY:
		return {"error": ctx + ": 구조가 올바르지 않아요.", "config": {}}
	var d: Dictionary = raw
	var key_err: String = keys_error(d, CONFIG_KEYS, ctx)
	if key_err != "":
		return {"error": key_err, "config": {}}
	var config: Dictionary = {}
	for slot in Catalog.SLOTS:
		config[slot] = d[slot]
	if not is_whole(d["price"]):
		return {"error": ctx + ": 가격 형식이 올바르지 않아요.", "config": {}}
	config["price"] = int(d["price"])
	var err: String = config_error(config)
	if err != "":
		return {"error": ctx + ": " + err, "config": {}}
	return {"error": "", "config": config}


static func same_config(a: Dictionary, b: Dictionary) -> bool:
	for k in CONFIG_KEYS:
		if a[k] != b[k]:
			return false
	return true
