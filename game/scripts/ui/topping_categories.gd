extends RefCounted
## 탐색용 UI 분류만 정의한다. 맛, 비용, 해금, 재고 또는 저장 데이터에는 관여하지 않는다.
const GROUPS: Array[String] = ["전체", "고기·달걀", "채소·과일", "해산물"]
const MEMBERS: Dictionary = {
	"고기·달걀": ["topping_chashu", "topping_egg"],
	"채소·과일": ["topping_sprouts", "topping_pickle", "topping_mushroom", "topping_citrus_peel", "topping_grilled_shiitake"],
	"해산물": ["topping_nori", "topping_scallop"],
}


static func category(id: String) -> String:
	for group in MEMBERS:
		if id in MEMBERS[group]:
			return str(group)
	push_error("토핑 UI 분류 누락: " + id)
	return ""


static func filter_items(items: Array, group: String) -> Array:
	var result: Array = []
	for item in items:
		var actual: String = category(str(item["id"]))
		if group == GROUPS[0] or actual == group:
			result.append(item)
	return result
