extends RefCounted
## Region facts are immutable. The shared ledger copies every transaction and
## replays these choices to validate saved fees, quantities and receipts.
const Core = preload("res://scripts/domain/sample_foraging.gd")
const IDS: Array = [
  "noodle_buckwheat",
  "topping_grilled_shiitake"
]
const FEE: int = 1600
const CAPACITY: int = Core.CAPACITY
const MAX_HISTORY: int = Core.MAX_HISTORY
const SPEC: Dictionary = {
  "ids": [
    "noodle_buckwheat",
    "topping_grilled_shiitake"
  ],
  "fee": 1600,
  "region": "mountain",
  "name": "산골 연구 재료 채집",
  "min_amount": 1,
  "max_amount": 3,
  "event_title": "농가의 연구 재료 고르기",
  "quantity_title": "농부의 분량 제안",
  "targets": [
    {
      "id": "buckwheat_mill",
      "label": "제면용 산메밀을 찾는다",
      "desc": "산메밀 배합분으로 제면을 개발해요. 향은 좋지만 재료비가 올라가요.",
      "cost": 0,
      "ingredient_hint": "noodle_buckwheat"
    },
    {
      "id": "shiitake_grill",
      "label": "구운 산표고를 찾는다",
      "desc": "직화 향을 더하는 산표고. 향은 강하지만 손질 시간이 길고 국물은 가벼워져요.",
      "cost": 0,
      "ingredient_hint": "topping_grilled_shiitake"
    }
  ],
  "quantities": [
    {
      "id": "take_one",
      "label": "직접 손질한다 · 1개 / 추가 0원",
      "desc": "출발비만 내고 연구 재료 1개를 받아요. 작은 실험부터 시작해요.",
      "cost": 0,
      "amount": 1
    },
    {
      "id": "clean_three",
      "label": "손질을 부탁한다 · 3개 / 추가 800원",
      "desc": "800원을 더 내고 연구 재료 3개를 받아요. 반복 고명이나 여러 실험에 쓸 수 있어요.",
      "cost": 800,
      "amount": 3
    }
  ]
}

static func empty_state() -> Dictionary:
	return Core.empty_state(SPEC)

static func discoveries(state: Dictionary) -> Array:
	return Core.discoveries(SPEC, state)

static func choices(path: Array) -> Array:
	return Core.choices(SPEC, path)

static func outcome(path: Array) -> Dictionary:
	return Core.outcome(SPEC, path)

static func begin(state: Dictionary, day: int, wallet: int) -> Dictionary:
	return Core.begin(SPEC, state, day, wallet)

static func choose(state: Dictionary, id: String, wallet: int) -> Dictionary:
	return Core.choose(SPEC, state, id, wallet)

static func finish(state: Dictionary, retire: bool = false) -> Dictionary:
	return Core.finish(SPEC, state, retire)

static func use_samples(state: Dictionary, config: Dictionary) -> Dictionary:
	return Core.use_samples(SPEC, state, config)

static func active_view(state: Dictionary, wallet: int) -> Dictionary:
	return Core.active_view(SPEC, state, wallet)

static func parse(raw: Variant, day: int, next_record: int, max_uses_per_recipe: int = 1) -> Dictionary:
	return Core.parse(SPEC, raw, day, next_record, max_uses_per_recipe)
