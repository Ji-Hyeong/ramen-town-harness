# 그릇에서 시작하는 메뉴 실험 · 현재 Mac 화면

2026-10-23(한국 시간), 새 OpenGL 실행 `20261022T163531Z-15310`.
검사1,980개·실패0·종료0·엔진 오류0. 가로1280×800/세로390×844 원본28장을
모두 개별로 열어 직접 검토했다. 현재161소스/PCK976beff7과 실행 후에도 일치한다.
정상 저장과 분리된 시험 저장만 사용했고 전체 실행36파일은 별도 보존했다.

## 실제 흐름

| 상태 | 세로 | 가로 | 확인한 내용 |
| --- | --- | --- | --- |
| 시작 | [그릇](portrait_workbench_01_food.png) | [그릇](desktop_workbench_01_food.png) | 현재 조합을 크게 표시, 원가/시간, 고정 시식 버튼 |
| 작업 이동 | [펼침](portrait_workbench_02_navigation.png) | [펼침](desktop_workbench_02_navigation.png) | 기존8개 작업과 소리 설정, 선택 후 접힘 |
| 실험 방향 | [방향](portrait_workbench_03_directions.png) | [방향](desktop_workbench_03_directions.png) | 재료에서 여는 세 방향, 시식 기록 기준 |
| 기존 목표 | [목표](portrait_workbench_04_goal.png) | [목표](desktop_workbench_04_goal.png) | 기존 연구 조건/지도를 유지 |
| 유자 조합 | [조합](portrait_workbench_05_citrus_clear.png) | [조합](desktop_workbench_05_citrus_clear.png) | 유자·숙주/파채, 원가1,490원/준비80초 |
| 참깨 조합 | [조합](portrait_workbench_05_sesame_depth.png) | [조합](desktop_workbench_05_sesame_depth.png) | 참깨유·차슈/김, 원가2,540원/준비170초 |
| 바다 조합 | [조합](portrait_workbench_05_harbor_sea.png) | [조합](desktop_workbench_05_harbor_sea.png) | 정어리·가리비/김, 원가1,670원/준비129초 |
| 육수 제조 | [제조](portrait_workbench_06_broth.png) | [제조](desktop_workbench_06_broth.png) | 실제 단계 그림/진행률, 중복 시식 잠금, 취소 |
| 면 제조 | [제조](portrait_workbench_07_noodle.png) | [제조](desktop_workbench_07_noodle.png) | 면 단계와 진행률 |
| 담음새 | [제조](portrait_workbench_08_plating.png) | [제조](desktop_workbench_08_plating.png) | 토핑 단계와 진행률 |
| 유자 시식 | [결과](portrait_workbench_09_citrus_clear_result.png) | [결과](desktop_workbench_09_citrus_clear_result.png) | 실제 그릇·새 방향·수치, 접힌 영수증 |
| 참깨 시식 | [결과](portrait_workbench_09_sesame_depth_result.png) | [결과](desktop_workbench_09_sesame_depth_result.png) | 다른 그릇·평가·시간, 다음 한 그릇 이동 |
| 바다 시식 | [결과](portrait_workbench_09_harbor_sea_result.png) | [결과](desktop_workbench_09_harbor_sea_result.png) | 실제 바다 조합과 결과 |
| 재시작 | [복원](portrait_workbench_10_reloaded.png) | [복원](desktop_workbench_10_reloaded.png) | 보관한 세 시식 증빙, 새 발견 반복 알림 없음 |

위 수치는 실제 시험 조합의 예시이며 각 방향의 모든 조합을 고정하지 않는다.
새 재료는 실제 장터/항구 채집 거래를 거쳤고 각 유료 시식에서 돈·샘플을 사용했다.
자동 시험이 조합을 선택했으며 게임에 자동 정답 채움 기능은 넣지 않았다.

## 전후와 실제 결과 비교

- [세로 전후](comparisons/portrait_before_after.png), [가로 전후](comparisons/desktop_before_after.png): 같은 새 게임·초기 조합·원가2,200원/준비100초·스크롤 맨 위. 이전 화면은 스타일/변경 기준이며 현재 동작의 증거로 사용하지 않는다.
- [그릇 확대 비교](comparisons/portrait_bowl_focus.png): 같은224×144 영역 크기의 실제 화면 일부를 최근접3배로 표시했다. 게임 안 그릇은 기존2배에서4배로 의도적으로 커졌다.
- [세 실제 조합](comparisons/portrait_three_dishes.png), [세 실제 시식 결과](comparisons/portrait_three_results.png): 서로 다른 실제 거래이므로 돈·조합·평가가 다르다.

비교5장도 함께 열어 직접 검토했다. 전체 원본은 밀도1이며 비교 자료는 라벨/간격만
추가했다. 픽셀 색이나 내용을 바꾸지 않았고 확대 방식과 원본 해시를 남겼다.
[원본/비교 해시와 크기](review.json), [디자인 검증](../../../design-qa.md),
[기능과 검증 범위](../DISCOVERY_WORKBENCH_V1.md), [실행 증거](../../../evidence/discovery-workbench-v1.json).

## 남은 확인 범위

이번 흐름에 해결되지 않은 P0/P1/P2는 없었다. 성공 문구 반복, 긴 조건 줄바꿈,
기존 일부 색 대비는 후속 다듬기 항목이다. 물리적 iPhone 조작/성능, VoiceOver·글자 확대,
사람이 듣는 소리 품질/음량과 재미/본편6~10시간은 이 검사의 수락 범위에 포함하지 않는다.
