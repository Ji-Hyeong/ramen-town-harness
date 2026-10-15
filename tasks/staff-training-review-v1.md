TASK
한국어로 직원 육성 저장/정산의 구체적인 결함만 독립 검토한다. 파일 수정/실행 금지. max8턴. 큰 역사/문서/게임 전부 읽지 말고 이 계약과 아래 정의/함수만 확인한다.

SCOPE
- game/scripts/domain/staff_training.gd: 전체 ~250줄. parse의 날짜/경험/훈련 영수증 도달 가능성, train/accrue 관계.
- game/scripts/domain/shop_staffing.gd: snapshot/snapshot_error와 실제 시간/임금 계산.
- game/scripts/domain/game_state.gd: Grep으로 serve,settle_service,_service_experience,current_staffing,hire_staff,training_review,train_staff,to_dict,load_from_dict 위치를 찾고 필요한 offset/limit만 읽기. 핵심은 _training 추가 부분과 v5 migration/원자적 정산. 다른 대회/탐색 구현 전체는 읽지 않는다.
- game/tests/run_tests.gd 새 test_training_* 약300줄: 테스트가 놓친 실질적 반례가 있는 경우만. 기존8.8만 토큰 시험/문서 읽기 금지.

EXPECTED
고용후 실제 완료 그릇만 경험; 실무 0그릇이면 경험/실무일 증가0. 하루 정산1회. 훈련 basic40/2/rank2/4000, speed/economy160/5/rank3/12000, 경험 비소비, 같은직원 하루1회/선택영구. 속도25%p/임금+400,절약15%p/-100(기본prep80/floor70/wage600/500). 스냅샷은 기본4키, 훈련한 직원이 있을 때만training 자격배열. 자격에서 효과 재계산. schema6 고용자별training 일치, 이전1~5는기존모든값/돈/기사/탐색그대로+새XP0. 실행중영업 저장 없음. 로컬JSON 암호학적 인증/고용일 증명은 범위아님.

Codex 독립96 tests/50883 checks/0/exit0와 pure95/0 통과. 실제v5 eightfixtures124 generation +48 migration/backup/fullvaluechecks 통과(현재실행결과 보고서 확인 중). 숫자정규화/날짜간실무증가 상한은 Codex가 추가했다. 주장만 믿지 말고 구체적인 reachable bad state/missed mutation을 제시한다.

OUTPUT
문제가 있으면 심각도/파일함수·줄/정확한 반례·영향·작은수정제안. 문제 없으면 발견사항없음+검토한범위·미검증. 기능확장/일반권고/전체프로젝트재설계 금지. Read/Glob/Grep만, 네트워크/셸/Git/사용자설정/위임/자격증명 접근 금지. 완결된 한국어 compact report.
