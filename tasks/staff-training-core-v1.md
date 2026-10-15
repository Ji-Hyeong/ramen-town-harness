TASK
직원 한 명의 육성 규칙을 계산하는 순수 helper와 독립 시험만 구현한다. 모든 답변/주석은 한국어. Codex는 고용 목록, GameState/schema6, 영업 경험 정산, 직원 스냅샷, UI/QA/문서/공개를 담당한다.

CONTEXT
AGENTS.md 첫 26줄, CLAUDE.md, 이 계약과 game/scripts/domain/data_check.gd만 읽는다. 큰 run_tests/main/history를 읽지 않는다. 신규 브랜치는 검증된 main 0d0ddb5 기반. 사용자 요구: 직원 육성이 비용만 내면 끝나는 단순 강화보다 실무 경험과 조건/선택이 있는 성장이어야 한다. 보조 직원 2명부터 적용, 맛 점수 영향 없음.

REQUIREMENTS / API
신규 game/scripts/domain/staff_training.gd extends RefCounted. 직원 id/고용/자금 차감/파일/시계는 다루지 않는다. const MAX_DAY=99999, MAX_DAILY_BOWLS=2400, MAX_BOWLS=239995200 (99998*2400). static empty()->Dictionary: {bowls:0,work_days:0,last_work_day:0,lessons:[]}.
static level(entry)->int = lessons.size(). static effect(level:int,style:String)->Dictionary: {percent_discount,wage_delta,title}; 0/"" ->0/0/"입문",1/"basic" ->10/+150/"숙련",2/"speed" ->25/+400/"속도 전문",2/"economy" ->15/-100/"절약 전문". 그 외 {error:nonempty}. 할인은 기본80%(조리)/70%(홀)에서 빼고 운영비는 기본600/500에 더한다. 타입/키 오류를 숨기는 fallback 금지.
static accrue(entry:Dictionary,day:int,units:int)->Dictionary: {error,state}; 성공이면 새 deep copy 반환. 유효 day1..99998, units0..2400, day>last_work_day; units0이면 경험 변화 없음. 실제 완료 그릇만 +units, work_days+1,last_work_day=day; overflow 거부. 시작/취소/예측/로드는 호출자가 이 함수를 호출하지 않는다.
static review(entry:Dictionary,rank:int,wallet:int,day:int,style:String)->Dictionary: {error,eligible,reason,next_level,style,cost,min_bowls,min_work_days,min_rank,effect}. 1단계 basic:40그릇+실무2일+가게등급2+비용4000. 2단계 speed 또는 economy:160그릇+실무5일+등급3+비용12000. 레벨2 최대. 하루 같은 직원 훈련 1회(last lesson day<day), last_work_day<day. 모든 조건을 확인; 거부 이유 한국어, 조회는 불변. Unknown style, invalid rank/day/wallet 오류. valid but insufficient conditions error="",eligible=false.
static train(entry,rank,wallet,day,style)->Dictionary: {error,state,cost,receipt}; review eligible일 때만 lessons에 {day,rank,bowls,work_days,style} 추가; 경험 소비 없음, choice 영구/환불없음. 실패하면 원본 불변. 순서에 따라 레벨1 basic,2 speed/economy. 지급/차감은 Codex 호출자가 처리.
static parse(raw:Variant,current_day:int,current_rank:int)->Dictionary: {error,state}; 정확한 키/타입/정수(JSON float 정수만 허용)/범위, work_days<=current_day-1, last_work_day<=current_day-1 and>=work_days, bowls between work_days and work_days*2400; work_days0 iff bowls0,last_work_day0. lessons 배열<=2, exact receipt keys, styles 순서, strictly increasing days<=current_day, rank2/3 minimum and <=current_rank, rank nondecreasing, 각 receipt bowls/work_days thresholds, day>=work_days+1, receipt work_days<=current total and bowls<=current total, receipt bowls within workdays..workdays*2400. receipts bowls/work_days nondecreasing, 두 훈련이 다른 날이고 경험은 완료 영업에서만 오므로 2번째 receipt 전에 실무 최소1일 및1그릇 증가해야 함. receipt work_days <= current total - max(0,last_work_day-receipt.day+1)? 이 식은 잘못됨(쉬는 날 존재). 대신 last_work_day<receipt.day이면 receipt 경험과 현재 경험이 정확히 같아야 하고, last_work_day>=receipt.day이면 receipt work_days<current.work_days AND receipt.bowls<current.bowls이어야 함. 직원을 고용한 날짜는 별도 저장하지 않음; 암호학적 인증 주장 금지.
모든 숫자를 int로 정규화 후 반환. 사본 반환/입력 불변. helper는 내부 정상 entry 입력 API지만 공개 parse는 모든 Variant에 런타임 오류 없이 명시적 실패.

TESTS
신규 game/tests/staff_training_core_tests.gd extends SceneTree. 독립 실행/저장 없음. print checks/failures + quit(0) iff executed and 0fail, else1. 조건 경계/정확비용/등급/두 전문효과/하루 제한/한도/사본/영업0그릇/중복일/JSON roundtrip, malformed shape/types/fraction/bool/chronology/receipt counter inconsistencies 검증. 실제 accrue로2일40그릇→훈련1→3일120그릇→두 전문 분기. 거부가 원본을 바꾸지 않는지 확인. 테스트는 구현 그대로 복제하지 말고 수동 expected values 검증.

CONSTRAINTS
수정 허용 두 신규파일만. 기존코드/docs/AGENTS/uid/Git/network/환경/인증/서브에이전트 수정 금지. file tools only Read/Edit/Write/Glob/Grep. 최대18턴, compact helper ~280lines/test~150lines. 실행권한 없음. 테스트 NOT RUN으로 보고, 한국어 compact handoff(API/결정/검증미실행). Codex가 독립 실행한다.

VERIFICATION
Codex runs official Godot --headless --path game --script res://tests/staff_training_core_tests.gd; success JSON/exit alone is not acceptance. Independently inspect diff and integration regressions.

REVIEW CORRECTION (2026-10-15)
위 REQUIREMENTS의 두 영수증 사이 실무/그릇이 반드시 증가해야 한다는 문구는 폐기한다. 실제 최대 가격 메뉴의0판매 영업도 일차를 올리므로, 훈련을 미룬 직원이 이미 전문 조건을 채웠다면 같은 경험으로 다음 날 전문화할 수 있다. 영수증 날짜는 엄격 증가하되 bowls/work_days는 비감소로 검사한다. 날짜 간 증가 상한과 현재 경험/마지막 영업일 일관성은 유지한다. Claude 읽기전용 리뷰 지적을 Codex가 실제 시식/예측/영업 런타임/정산/전문화로 재현:97tests50982 중 이 사례1실패. 이 회귀 테스트를 남긴 채 수정한다.
