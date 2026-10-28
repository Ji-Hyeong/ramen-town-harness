extends RefCounted
## Region facts are immutable. The shared ledger copies every transaction and
## replays these choices to validate saved fees, quantities and receipts.
const Core = preload("res://scripts/domain/sample_foraging.gd")
const IDS: Array = [
  "broth_roasted_sardine",
  "topping_scallop"
]
const FEE: int = 1200
const CAPACITY: int = Core.CAPACITY
const MAX_HISTORY: int = Core.MAX_HISTORY
const SPEC: Dictionary = {
  "ids": [
    "broth_roasted_sardine",
    "topping_scallop"
  ],
  "fee": 1200,
  "region": "harbor",
  "name": "항구 연구 재료 채집",
  "min_amount": 1,
  "max_amount": 5,
  "event_title": "오늘의 어획물 고르기",
  "quantity_title": "어부의 손질 제안",
  "targets": [
    {
      "id": "sardine_boat",
      "label": "구운 정어리 육수를 찾는다",
      "desc": "맑고 향이 강한 육수. 진함은 낮고 간이 있어 타레 선택이 중요해요.",
      "cost": 0,
      "ingredient_hint": "broth_roasted_sardine"
    },
    {
      "id": "scallop_diver",
      "label": "가리비 고명을 찾는다",
      "desc": "국물을 진하게 하는 고명. 같은 고명을 겹치면 재료비·준비 시간도 늘어요.",
      "cost": 0,
      "ingredient_hint": "topping_scallop"
    },
    {
      "id": "harbor_shared_catch",
      "title": "새벽 어획물 나눔",
      "label": "새벽 어획물 나눔에 낀다",
      "desc": "어부들이 섞어 잡은 어획물을 나눠요. 구운 정어리 육수 2개 추가 400원, 또는 가리비 고명 5개 추가 1400원.",
      "cost": 0,
      "ingredient_hint": "broth_roasted_sardine",
      "quantity_title": "나눌 어획 고르기",
      "quantity_text": "어부들이 어획물을 갈라 놓았어요. 어느 몫을 손질해 갈까요?",
      "quantities": [
        {
          "id": "sort_sardine_two",
          "label": "정어리 몫을 고른다 · 구운 정어리 육수 2개 / 추가 400원",
          "desc": "400원을 더 내고 구운 정어리 육수 2개를 받아요.",
          "cost": 400,
          "ingredient": "broth_roasted_sardine",
          "amount": 2
        },
        {
          "id": "sort_scallop_five",
          "label": "가리비 몫을 고른다 · 가리비 고명 5개 / 추가 1400원",
          "desc": "1400원을 더 내고 가리비 고명 5개를 받아요.",
          "cost": 1400,
          "ingredient": "topping_scallop",
          "amount": 5
        }
      ]
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
      "label": "손질을 부탁한다 · 3개 / 추가 600원",
      "desc": "600원을 더 내고 연구 재료 3개를 받아요. 반복 고명이나 여러 실험에 쓸 수 있어요.",
      "cost": 600,
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
