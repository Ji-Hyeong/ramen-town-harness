extends RefCounted
## Region facts are immutable. The shared ledger copies every transaction and
## replays these choices to validate saved fees, quantities and receipts.
const Core = preload("res://scripts/domain/sample_foraging.gd")
const IDS: Array = [
  "oil_roasted_sesame",
  "topping_citrus_peel"
]
const FEE: int = 1000
const CAPACITY: int = Core.CAPACITY
const MAX_HISTORY: int = Core.MAX_HISTORY
const SPEC: Dictionary = {
  "ids": [
    "oil_roasted_sesame",
    "topping_citrus_peel"
  ],
  "fee": 1000,
  "region": "market",
  "name": "새벽 장터 연구 재료 채집",
  "min_amount": 2,
  "max_amount": 5,
  "event_title": "노점 고르기",
  "quantity_title": "연구 분량 고르기",
  "targets": [
    {
      "id": "sesame_stall",
      "label": "볶음 양념 노점을 찾는다",
      "desc": "볶은 참깨유 연구 재료를 구해요.",
      "cost": 0,
      "ingredient_hint": "oil_roasted_sesame"
    },
    {
      "id": "citrus_cart",
      "label": "유자 수레를 찾는다",
      "desc": "유자 껍질 연구 재료를 구해요.",
      "cost": 0,
      "ingredient_hint": "topping_citrus_peel"
    },
    {
      "id": "market_group_buy",
      "title": "마감 공동구매",
      "label": "마감 공동구매에 낀다",
      "desc": "상인이 마감 물량을 나눠 줘요. 볶은 참깨유 2개 추가 0원, 또는 유자 껍질 5개 추가 900원.",
      "cost": 0,
      "ingredient_hint": "oil_roasted_sesame",
      "quantity_title": "나눌 몫 고르기",
      "quantity_text": "상인이 남은 마감 물량을 펼쳐 놓았어요. 어느 몫을 가져갈까요?",
      "quantities": [
        {
          "id": "share_sesame_two",
          "label": "참깨유를 조금씩 나눈다 · 볶은 참깨유 2개 / 추가 0원",
          "desc": "추가 비용 없이 볶은 참깨유 2개를 받아요.",
          "cost": 0,
          "ingredient": "oil_roasted_sesame",
          "amount": 2
        },
        {
          "id": "prepare_citrus_five",
          "label": "유자를 함께 손질한다 · 유자 껍질 5개 / 추가 900원",
          "desc": "900원을 더 내고 유자 껍질 5개를 받아요.",
          "cost": 900,
          "ingredient": "topping_citrus_peel",
          "amount": 5
        }
      ]
    }
  ],
  "quantities": [
    {
      "id": "take_two",
      "label": "연구용 두 개를 챙긴다",
      "desc": "추가 비용 없이 2개를 받아요.",
      "cost": 0,
      "amount": 2
    },
    {
      "id": "take_three",
      "label": "300원을 더 내고 세 개를 챙긴다",
      "desc": "추가 300원으로 3개를 받아요.",
      "cost": 300,
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
