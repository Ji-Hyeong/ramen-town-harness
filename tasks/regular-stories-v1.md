TASK
세 단골의 사연을 실제 메뉴 개발과 완료 영업으로 풀어내는 작은 분기 이야기 첫 버전을 만든다.

CONTEXT / OWNERSHIP
PR10 main f99877e에서 시작. 사용자가 다음 작업 진행을 요청했다. Codex 주 구현/통합/검증, Claude는 새 순수 카탈로그와 전용 시험 두 파일만 담당한다. 동시 작성 금지. 게임의 기존8탭과 경제/그림/시식 평가는 유지한다.

REQUIREMENTS
- 기존 연구 탭에 연구/단골 이야기 전환을 둔다(기존 연구가 기본). 세 단골마다 사연 하나, 처음 대화에서 두 가지 요리 방향 중 선택, 선택별 두 장과 결말(총6분기). 초상/실제 대사/다음 조건/선택 확인/이전 이야기 다시 보기.
- 한 번 영업을 마친 뒤(day>=2) 시작. 방향 선택은 무료, 확인 후 이번 이야기 동안 고정. 메뉴 조건뿐 아니라 수락 이후 실제 해당 단골이 먹기까지 완료한 해당 메뉴의 최근 영업 보고가 필요하다. 자동 완료/소급 보상 금지. 시식만으로 달성되지 않는다. 기본/증축 복수메뉴 모두 정확한 메뉴와 손님의 완료 수량을 사용한다.
- 두 번째 장은 첫 답례를 받은 날 이후 새로 시식한 서로 다른 구성의 메뉴와 더 높은 조건 및 새로운 완료 영업이 필요하다. 이전 장의 같은 보고/구성 재사용 불가. 명시적 대화 완료 행동 때만 장별2000/4000원을 한 번 지급(최대18000). 종료/중복/자금상한/영업·탐색·제조 중 실패는 원자적. 상태 거래 후 실제 저장 결과 안내/수동 복구.
- schema9 stories 추가. 이전1~8 모든값 유지+빈 이야기, 원본 버전 영구 백업. 선택/순서/날짜/엄격 숫자/구성/재계산 조건/해금/남아있는 기록과 스냅샷 일치 검증 후 전체 반영. 메뉴 삭제 후에도 이전 대사/결말/영수증은 보존. 로컬 저장은 암호학적으로 인증하지 않는다.

CONSTRAINTS
새 손님/새 탭/메뉴 버프/손님 수요 보정/재료/랭크/시설/도시/장시간 타이머는 이번 범위 밖. 기존 연구 보상/승급조건에 이야기 진행을 섞지 않는다. 현재 사용자 저장은 자동 실행/시험 금지. 기존47복사본 보존. 파괴Git/push/deploy는 Claude 금지.

VERIFICATION
모든12단계 달성 가능 실제 평가 증인, 선택/시식만/취소/잘못된 고객·메뉴/0판매·일부영업/복수메뉴/중복/새개정·새영업/영수증 삭제·재시작/손상저장 원자거부. 기존 전체 기능 회귀, 실제 구v8 합성 저장 이행/원본/백업/전체값, 기존경제/그림 골든. 두 크기 전체UI와 새 native 캡처/소스·PCK일치/실제종료·오류·내용 검토. 같은PCK 플레이 앱/격리메인 스모크. 검증된 READY PR만 기존승인으로 merge/원본main안전FF.

STATUS (2026-10-17)
IMPLEMENTED: all game/domain/dialogue/UI/save code by Codex after Claude helper authentication failure before edits.
VERIFIED:119tests/57027checks/0/exit0, pure189/0, focused462/0, final full two-size layout14990/0. Actual-v8 thirteen fixtures150generation/78migration+permanent backup+roundtrip/13whole-value equality;64old service cases+4CPU rasters260/0. All12chapter recipe witnesses reachable.47original unknown copies unchanged. Headless engine emits separate systemCA lookup error; no script errors.
BLOCKED: actual renderer/new PCK player/publication acceptance. Strict vendor signature check fails in current sandbox though all80copied engine files equal official archived ZIP and binary/Info hashes match previous verified snapshot. Read-only escalated verification rejected, permission-request tool unavailable. No bypass/security weakening. Session execution-permission question pending. Git fetch works; no GitHub outage claimed. Keep current v8 app/main; do not publish/merge this checkpoint before native acceptance.
