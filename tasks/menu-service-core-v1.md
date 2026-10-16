TASK
두 메뉴가 같은 손님과 주방을 공유하는 하루 영업 계산 helper와 독립 시험만 구현한다. 한국어 주석/보고. Codex가 GameState/저장/세션/그림/UI/통합 검증을 맡는다.

CONTEXT
AGENTS.md 첫26줄, CLAUDE.md, 이 계약, sales_simulator.gd/customer_catalog.gd/recipe_evaluator.gd/data_check.gd의 관련 API만 읽는다. 거대한 run_tests/UI/history는 읽지 않는다. main f489dcd의 feature/ramen-expansion-menus-v1. 기존 단일 Sim은 변경하지 않는다. 기존 직원 스냅샷은 자격에 따른 조리 시간/일당을 이미 포함한다.

REQUIREMENTS / API
신규 game/scripts/domain/menu_sales.gd extends RefCounted. static simulate(records:Array,day:int,staffing:Dictionary={})->Dictionary.
records는 길이1~2의 불변 시식 기록 {record_id,name,version,config,scores,...}; id/name/version/config를 검증하고 점수는 실제 Evaluator.evaluate에서 다시 계산해 신뢰하지 않는다. id양의정수/중복금지, 이름 Check.name_error,version1..9999,config Check.config_error/Catalog.normalize_config. 외부입력형식/알수없는재료/날짜/직원 오류는 {error:nonempty}로 실패하고 입력불변. 내부 config price는 int. 레시피 점수내용은 입력의scores 대신 실제 평가를 쓴다. 최대day99999.
성공 결과: 기존 Sim 필드 error,units,revenue,ingredient_cost,overhead,net,demand,capacity,by_source 유지 + menus:Array. 각 menu행: {record_id,recipe_name,version,config,scores,prep,price,unit_cost,demand,units,revenue,ingredient_cost,margin,by_source}. price는 정수, margin=revenue-ingredient_cost (공통 운영비 전). 공통 overhead=Sim.overhead_for(staffing) 정확히 한 번. 행순서는 입력순서. 모든 조회/입력 사본.
1개 메뉴는 기존 Sim.simulate(config,authoritative scores,day,staffing)의 모든 필드와 정확히 같고 menus 한 행만 더한다. 기본 영업 호환은 Codex가 옛 경로 그대로 유지할 예정.
2개 메뉴는 손님 그룹(Customers.ids +walkin)별 두 메뉴의 수요를 기존 Sim._demand와 동일한 공식으로 구한다. 실제 점수, 고객 base/fair/max/sens/patience, Staffing.effective_prep, 요일 적용. walkin은 해당 메뉴 단골 평균. helper 재사용 가능(Sim._demand 정적 함수), 공식 중복 최소화.
그룹 방문 수는 max(demandA,demandB) 한 번만: 두 메뉴 수요를 더해서 손님을 두 배로 만들지 않는다. 그 방문을 각 메뉴 수요 비율로 배분(내림+최대 나머지, 동률이면 더 작은 record_id). 수요0 메뉴는0. 동일 record집합의 입력순서를 바꿔도 menu ID별 결과가 같아야 한다.
주방 총2400초를 공유한다. menu+source 셀을 record_id오름차순/Customers순서로 정렬하고, 라운드마다 각 셀에1그릇씩 준비 시간만큼 예산을 차감하면서 수요 또는 남은 시간이 부족할 때까지 배분. 어느메뉴도 총 조리시간을 별도로2400초 얻으면 안 된다. 총최대200그릇을 넘으면 명시적 오류. demand<=200도 확인. capacity=2400/min(menu prep), units<=capacity. by_source는 실제배분합, demand는 그룹별max의합, net=메뉴margin합-overhead. 부동소수 정규화는 경계에만, 정수배분/결정성.
도착 시각/난수/좌석/운영 세션/가격설정/돈 차감/영업일 저장은 여기서 하지 않는다. 한 고객그룹이 선호·가격에 따라 실제로 서로 다른 메뉴를 선택하는 증인 제공.

TESTS
신규 game/tests/menu_sales_core_tests.gd extends SceneTree. 파일/저장/세션/UI 없이 print checks/failures, 끝까지 실행된 경우0 iff 실패0. meaningful tests:1메뉴전필드동일(가격/날짜/직원4조합),2메뉴공유손님수=각그룹별max(독립합아님),주방시간<=2400,요금/원가/공통운영비1회,동일입력결정/입력순서독립ID별비교,고가메뉴수요0,모든메뉴수요0,고객선호다른선택,다중토핑+육성스냅샷,입력타입/이름/id/중복/개수/비용오류,사본안전. 실제평가기손님점수구조먼저확인. 기대값은 테스트에서 독립계산하고 같은 helper호출로대체하지 말 것. 가능한 간결하게 helper~250lines/test~170lines.

CONSTRAINTS
두 신규 파일만 쓰기. 기존코드/AGENTS/docs/uid/Git/네트워크/환경/인증/서브에이전트 수정 금지. file tools only Read/Edit/Write/Glob/Grep. max18턴. 실행권한없음, NOT RUN으로 한국어 compact API/검증미실행/위험 보고. Codex가 실제 실행/검토/통합한다.

VERIFICATION
공식 Godot --headless --path game --script res://tests/menu_sales_core_tests.gd. JSON성공/exit만으로 완료판정하지 않고 Codex가 실제diff/독립실행/회귀로 판단.
