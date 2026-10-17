extends RefCounted
## 실제 기존 재료/평가기 탐색으로 찾은12단계 증인. 초기 장은7000원, 다음 장은7500원으로 서로 다른 구성이다.
const WITNESSES: Dictionary = {
	"dohyun:hearty:0": {
		"broth": "broth_tonkotsu",
		"cook": "cook_firm",
		"noodle": "noodle_thin",
		"oil": "oil_garlic",
		"price": 7500,
		"tare": "tare_shoyu",
		"toppings": [
			"topping_chashu"
		]
	},
	"dohyun:hearty:1": {
		"broth": "broth_tonkotsu",
		"cook": "cook_firm",
		"noodle": "noodle_thin",
		"oil": "oil_garlic",
		"price": 7500,
		"tare": "tare_miso",
		"toppings": [
			"topping_nori"
		]
	},
	"dohyun:quick:0": {
		"broth": "broth_tonkotsu",
		"cook": "cook_firm",
		"noodle": "noodle_thin",
		"oil": "oil_garlic",
		"price": 7500,
		"tare": "tare_shoyu",
		"toppings": [
			"topping_chashu"
		]
	},
	"dohyun:quick:1": {
		"broth": "broth_tonkotsu",
		"cook": "cook_firm",
		"noodle": "noodle_thin",
		"oil": "oil_garlic",
		"price": 7500,
		"tare": "tare_shoyu",
		"toppings": [
			"topping_chashu"
		]
	},
	"hayoung:aroma:0": {
		"broth": "broth_tonkotsu",
		"cook": "cook_firm",
		"noodle": "noodle_thin",
		"oil": "oil_garlic",
		"price": 7500,
		"tare": "tare_shoyu",
		"toppings": [
			"topping_chashu"
		]
	},
	"hayoung:aroma:1": {
		"broth": "broth_tonkotsu",
		"cook": "cook_firm",
		"noodle": "noodle_thin",
		"oil": "oil_garlic",
		"price": 7500,
		"tare": "tare_shoyu",
		"toppings": [
			"topping_sprouts"
		]
	},
	"hayoung:light:0": {
		"broth": "broth_chicken",
		"cook": "cook_firm",
		"noodle": "noodle_thin",
		"oil": "oil_garlic",
		"price": 7500,
		"tare": "tare_shoyu",
		"toppings": [
			"topping_sprouts"
		]
	},
	"hayoung:light:1": {
		"broth": "broth_chicken",
		"cook": "cook_firm",
		"noodle": "noodle_thin",
		"oil": "oil_garlic",
		"price": 7500,
		"tare": "tare_shoyu",
		"toppings": [
			"topping_sprouts"
		]
	},
	"maru:budget:0": {
		"broth": "broth_tonkotsu",
		"cook": "cook_firm",
		"noodle": "noodle_thin",
		"oil": "oil_chili",
		"price": 7500,
		"tare": "tare_shoyu",
		"toppings": [
			"topping_chashu"
		]
	},
	"maru:budget:1": {
		"broth": "broth_chicken",
		"cook": "cook_firm",
		"noodle": "noodle_thin",
		"oil": "oil_chili",
		"price": 7500,
		"tare": "tare_shoyu",
		"toppings": [
			"topping_nori"
		]
	},
	"maru:spicy:0": {
		"broth": "broth_tonkotsu",
		"cook": "cook_firm",
		"noodle": "noodle_thin",
		"oil": "oil_chili",
		"price": 7500,
		"tare": "tare_shoyu",
		"toppings": [
			"topping_chashu"
		]
	},
	"maru:spicy:1": {
		"broth": "broth_tonkotsu",
		"cook": "cook_firm",
		"noodle": "noodle_thin",
		"oil": "oil_chili",
		"price": 7500,
		"tare": "tare_shoyu",
		"toppings": [
			"topping_chashu"
		]
	}
}

static func config(customer: String, route: String, chapter: int) -> Dictionary:
	var out: Dictionary = WITNESSES[customer+":"+route+":"+str(chapter)].duplicate(true)
	out["price"] = 7000 if chapter == 0 else 7500
	return out
