extends RefCounted
## 단골의 선택별 사연과 메뉴 조건. 경제/저장/진행 상태를 가지지 않는 순수 카탈로그다.
const DATA: Dictionary = {
	"dohyun": {"id":"dohyun", "title":"꺼지지 않는 사무실 불빛", "opening":"배포가 끝나도 자꾸 노트북을 펴게 돼요. 오늘은 제 퇴근 시간을 지켜 줄 한 그릇을 부탁해도 될까요?", "routes":[
		{"id":"hearty", "label":"천천히 먹을 든든한 국물", "reply":"그럼 오늘만큼은 알림을 꺼 둘게요. 국물부터 천천히 맛보고 싶어요.", "chapters":[
			{"title":"알림을 끄는 저녁", "dialogue":"진한 국물이 있으면 급하게 먹지 않아도 될 것 같아요. 가게에 들를 테니 따뜻하게 준비해 주세요.", "success":"노트북을 가방에서 꺼내지도 않았네요. 제 저녁을 되찾은 기분이에요.", "requirements":{"score_min":80,"rich_min":8}},
			{"title":"내 몫의 퇴근 시간", "dialogue":"다음에는 동료도 데려오려고요. 첫 그릇에서 한 발 더 나아간, 가게다운 진한 메뉴를 만들어 주세요.", "success":"동료에게 오늘은 먼저 퇴근하자고 말했어요. 이 국물을 먹으러 올 시간이 필요하니까요.", "requirements":{"score_min":85,"rich_min":9}}], "ending":"사무실 단체방에 퇴근 후 라멘 약속이 생겼어요. 도윤은 이 자리에서만큼은 휴대폰을 뒤집어 놓습니다."},
		{"id":"quick", "label":"일찍 귀가할 빠른 한 그릇", "reply":"저녁을 거르지 않고도 일찍 집에 갈 수 있겠네요. 오늘은 창가 자리로 부탁해요.", "chapters":[
			{"title":"막차보다 이른 저녁", "dialogue":"든든한 맛은 좋지만 오래 기다리면 다시 메일을 보게 돼요. 준비가 빠른 메뉴를 부탁해요.", "success":"오늘은 막차 시간을 확인하지 않았어요. 배부르게 먹고도 산책할 시간이 남았네요.", "requirements":{"score_min":80,"prep_max":150}},
			{"title":"남겨 둔 산책길", "dialogue":"빠른 메뉴도 맛을 더 다듬을 수 있겠죠? 전보다 만족스러우면서 준비시간은 길어지지 않았으면 해요.", "success":"먼저 퇴근하고 걸어오는 길이 이제 익숙해졌어요. 다음 산책도 여기서 시작할게요.", "requirements":{"score_min":85,"prep_max":150}}], "ending":"도윤은 가게까지 오는 골목 산책 지도를 만들었어요. 사무실 불이 켜져 있어도 자신의 저녁은 챙기기로 했답니다."}]},
	"hayoung": {"id":"hayoung", "title":"점심시간의 작은 쉼표", "opening":"아이들 발표회를 준비하다 보니 제 점심은 늘 뒷전이에요. 오늘은 어떤 한 그릇으로 잠깐 쉬어 갈까요?", "routes":[
		{"id":"aroma", "label":"향을 천천히 즐기는 점심", "reply":"교실 꽃병에 물 주듯, 저도 잠깐 숨을 돌려야겠어요. 향이 좋은 국물이 떠오르네요.", "chapters":[
			{"title":"창문을 여는 향", "dialogue":"국물에서 좋은 향이 올라오면 잠시 교실 일을 잊을 것 같아요. 향긋한 메뉴를 기다릴게요.", "success":"첫 숟가락 전에 향부터 맡았어요. 오늘 수업에서 아이들에게도 이런 작은 발견을 이야기하고 싶네요.", "requirements":{"score_min":80,"aroma_min":7}},
			{"title":"발표회 뒤의 약속", "dialogue":"발표회가 끝나면 동료 선생님과 올게요. 첫 메뉴보다 향이 또렷한 새 한 그릇을 부탁해요.", "success":"동료와 점심 약속을 잡았어요. 바쁜 날에도 우리가 좋아하는 것을 하나쯤 남겨 두려고요.", "requirements":{"score_min":85,"aroma_min":8}}], "ending":"발표회 뒤 가게 창가에 작은 감사 카드가 놓였어요. 하영은 꽃을 그린 카드에 오늘 맡은 국물 향을 적었습니다."},
		{"id":"light", "label":"오후가 가벼워지는 점심", "reply":"오후 수업까지 편안했으면 좋겠어요. 무겁지 않은 국물이면 다시 힘을 낼 수 있겠죠.", "chapters":[
			{"title":"가벼운 첫 숟가락", "dialogue":"진한 맛보다 부담 없이 먹을 한 그릇이 필요해요. 점심 뒤에도 편안한 메뉴로 부탁해요.", "success":"점심을 건너뛸 이유가 하나 줄었네요. 아이들 이야기도 여유롭게 들을 수 있을 것 같아요.", "requirements":{"score_min":80,"rich_max":4}},
			{"title":"돌아갈 여유", "dialogue":"더 가볍고 준비도 빠른 새 메뉴가 생긴다면 점심시간에 자주 올 수 있겠어요. 맛까지 더 다듬어 주세요.", "success":"서두르지 않아도 수업 전에 돌아갈 수 있네요. 이제 점심시간을 제 일정에도 적어 둘래요.", "requirements":{"score_min":85,"rich_max":3,"prep_max":100}}], "ending":"하영의 수첩에 점심시간이 빈칸으로 남지 않게 됐어요. 교실로 돌아가는 발걸음에도 작은 여유가 생겼습니다."}]},
	"maru": {"id":"maru", "title":"논문 옆에 놓인 한 그릇", "opening":"수정할 논문은 산더미인데 식비부터 계산하고 있네요. 오늘은 어떤 메뉴로 다시 힘을 내 볼까요?", "routes":[
		{"id":"spicy", "label":"다시 도전할 얼큰한 메뉴", "reply":"얼큰하게 먹고 빨간 수정 표시도 씩씩하게 볼게요. 그래도 용돈 안에서는 해결해야 해요!", "chapters":[
			{"title":"수정 표시보다 붉게", "dialogue":"지갑을 비우지 않는 얼큰한 메뉴가 있으면 좋겠어요. 먹고 나면 수정할 문장 하나는 떠오를 것 같아요.", "success":"오늘은 논문을 덮고 밥부터 먹길 잘했어요. 빨간 표시가 전부 실패라는 뜻은 아니니까요.", "requirements":{"score_min":75,"spice_min":5,"price_max":8500}},
			{"title":"제출 전 마지막 저녁", "dialogue":"제출 전에 한 번 더 올게요. 얼큰함은 살리면서 맛을 더 다듬은 새 메뉴로 응원해 주세요.", "success":"제출 버튼을 누르기 전에 이 맛이 먼저 생각났어요. 오늘의 얼큰함은 꽤 오래 기억날 것 같아요.", "requirements":{"score_min":80,"spice_min":5,"price_max":8500}}], "ending":"논문을 제출한 마루가 빈 그릇 옆에 작은 체크 표시를 그렸어요. 다음 목표도 이 가게에서 정해 보기로 했답니다."},
		{"id":"budget", "label":"매주 먹을 수 있는 가성비", "reply":"한 번의 특별식보다 매주 올 수 있는 메뉴가 좋아요. 가게도 오래 남을 수 있는 가격이면 좋겠네요.", "chapters":[
			{"title":"한 주의 식비 노트", "dialogue":"판매가가 부담스럽지 않아야 또 올 수 있어요. 저한테 잘 맞는 한 그릇으로 부탁해요.", "success":"이번 주 식비에 라멘 한 번을 더 적었어요. 굶어서 아끼는 것보다 훨씬 좋은 계획이네요.", "requirements":{"score_min":75,"price_max":7500}},
			{"title":"오래 남을 메뉴", "dialogue":"싼 메뉴라도 사장님이 손해 보면 안 되잖아요. 원가를 아끼면서 맛을 더 다듬은 새 메뉴를 부탁해요.", "success":"가격표만 보고 고른 메뉴가 이제 좋아서 찾는 메뉴가 됐어요. 다음 주에도 같은 자리에서 만나요.", "requirements":{"score_min":80,"price_max":7500,"cost_max":1500}}], "ending":"마루의 식비 노트에 가게 이름이 정기 일정처럼 적혔어요. 논문이 끝나도 이 한 그릇은 남겨 두기로 했습니다."}]}
}
const LABELS: Dictionary = {"score_min":"시식 점수", "price_max":"판매가", "prep_max":"레시피 준비(초)", "rich_min":"진함", "rich_max":"진함", "aroma_min":"향", "spice_min":"매운맛", "cost_max":"그릇 원가"}

static func ids() -> Array[String]:
	return ["dohyun", "hayoung", "maru"]

static func story(customer: String) -> Dictionary:
	return DATA.get(customer, {}).duplicate(true)

static func route(customer: String, route_id: String) -> Dictionary:
	for item in story(customer).get("routes", []):
		if item["id"] == route_id:
			return item.duplicate(true)
	return {}

static func chapter(customer: String, route_id: String, index: int) -> Dictionary:
	var selected: Dictionary = route(customer, route_id)
	return {} if selected.is_empty() or index < 0 or index > 1 else selected["chapters"][index].duplicate(true)

## 저장된 점수를 신뢰하지 않고 호출 측이 실제 평가기로 계산한 지표를 받는다. JSON float/bool은 지표로 허용하지 않는다.
static func assess(customer: String, route_id: String, index: int, metrics: Dictionary) -> Dictionary:
	var definition: Dictionary = chapter(customer, route_id, index)
	var fail: Dictionary = {"error":"단골 메뉴 조건을 확인할 수 없어요.", "all_met":false, "lines":[]}
	if definition.is_empty() or metrics.size() != 5:
		return fail
	for key in ["score", "price", "prep", "cost", "profile"]:
		if not metrics.has(key):
			return fail
	for key in ["score", "price", "prep", "cost"]:
		if typeof(metrics[key]) != TYPE_INT or metrics[key] < (1 if key == "prep" else 0) or metrics[key] > (100 if key == "score" else 10000 if key == "prep" else 1000000000):
			return fail
	if typeof(metrics["profile"]) != TYPE_DICTIONARY or metrics["profile"].size() != 5:
		return fail
	for axis in ["rich", "salt", "aroma", "chew", "spice"]:
		if not metrics["profile"].has(axis) or typeof(metrics["profile"][axis]) != TYPE_INT or metrics["profile"][axis] < 0 or metrics["profile"][axis] > 10:
			return fail
	var lines: Array[String] = []
	var all_met: bool = true
	for key in definition["requirements"]:
		var base: String = str(key).trim_suffix("_min").trim_suffix("_max")
		var value: int = int(metrics[base]) if metrics.has(base) else int(metrics["profile"][base])
		var threshold: int = int(definition["requirements"][key])
		var minimum: bool = str(key).ends_with("_min")
		var met: bool = value >= threshold if minimum else value <= threshold
		all_met = all_met and met
		lines.append("%s %s %d%s · 지금 %d" % ["[달성]" if met else "[부족]", LABELS[key], threshold, " 이상" if minimum else " 이하", value])
	return {"error":"", "all_met":all_met, "lines":lines}
