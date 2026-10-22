# 항구 채집 화면 점검

현재 결과: **수정본 v2의 항구 흐름 화면 검증 통과**. 자동 검사와 별도로 새 원본28장 전체와 전후 비교7장을 직접 검토했다.

## 현재 v2 흐름

새 Mac OpenGL 실행20261022T072702Z-2212는962확인·실패0·종료0·엔진 오류0이다.
가로1280×800·세로390×844 각14장/총28장 원본이며, 실제 게임 씬을 OpenGL SubViewport로 캡처했다.
회색 시험용 루트 창은 화면 증거로 사용하지 않았다. 원본38파일은 바이트 그대로 별도 보존했다.

| 단계 | 현재 세로 화면 | 상태 |
| --- | --- | --- |
| 1 | [잠긴 항구](v2/portrait_harbor_01_locked.png) | 정상: 사용 가능한 장터 뒤 간단한 다음 목표 |
| 2 | [상세](v2/portrait_harbor_02_details.png) | 정상: 재료 아이콘·재고·맛·원가·시간 |
| 3 | [이동](v2/portrait_harbor_03_travel.png) | 정상: 이미 낸 비용·진행률 |
| 4 | [재료 선택](v2/portrait_harbor_04_target.png) | 정상: 육수/가리비의 다른 특징 |
| 5 | [수량 선택](v2/portrait_harbor_05_quantity.png) | 정상: 수량과 추가 비용을 선택 전에 표시 |
| 6 | [수령 대기](v2/portrait_harbor_06_waiting.png) | 수정 확인: 수령 버튼이 바로 보임 |
| 7 | [수령](v2/portrait_harbor_07_received.png) | 정상: 가리비3개와 개발 이동 |
| 8 | [개발 이동](v2/portrait_harbor_08_workbench.png) | 수정 확인: 실제 가리비 버튼까지 보임·초안 유지 |
| 9 | [반복 고명 그릇](v2/portrait_harbor_09_triple_dish.png) | 수정 확인: 실제 개발 화면·가리비3분량·원가/시간 |
| 10 | [시식 결과](v2/portrait_harbor_10_result.png) | 수정 확인: 실제 결과 그릇·손님 초상·평가 |
| 11 | [재방문](v2/portrait_harbor_11_broth.png) | 정상: 다음 날 육수1개·가리비0개 |
| 12 | [육수 선택](v2/portrait_harbor_12_broth_choices.png) | 수정 확인: 한 줄 버튼 이름과 전체 상세 이름 |
| 13 | [육수 그릇](v2/portrait_harbor_13_broth_dish.png) | 정상: 실제 국물/김 그릇·다른 비용과 시간 |
| 14 | [저장 실패](v2/portrait_harbor_14_save_warning.png) | 정상: 저장 경고가 수령 버튼 자동 이동보다 우선 |

[전후 수령](comparisons/portrait_06_waiting.png) · [전후 재료 이동](comparisons/portrait_08_workbench.png) · [전후 이름](comparisons/portrait_12_label.png) · [이름 확대 비교](comparisons/portrait_label_focus.png) · [그릇 캡처 수정](comparisons/portrait_09_triple_dish.png) · [시식 캡처 수정](comparisons/portrait_10_result.png) · [기존 스타일 비교](comparisons/portrait_style_reference.png)

비교 이미지는 같은 크기의 원본을 한 캔버스에 놓은 분석 자료다. 전체 화면은1배 밀도이며 이름 부분만 최근접3배로 확대했다.
기존 공급처 화면과 새 채집 화면의 내용/스크롤 차이는 의도한 변경이며 픽셀 단위 복제라고 주장하지 않는다.
[현재28장 해시·전체 수동 검토](v2-review.json) · [디자인 검증](../../../design-qa.md)

## 이전 v1 진단 기록

## 첫 실행의 실제 흐름

2026-10-22 새 Mac OpenGL 실행20261022T070256Z-95998에서24장을 생성했다.
자동688확인·실패0·종료0·엔진 오류0이었으나, 원본24장을 모두 직접 열어 다음 문제를 발견했다.
아래 표는 같은 세로390×844 화면의 순서다. 가로1280×800 원본도 같은 이름의 desktop 접두사로 보존한다.

| 단계 | 화면 | 상태와 발견 |
| --- | --- | --- |
| 1 | [잠긴 항구](v1-diagnostics/portrait_harbor_01_locked.png) | 정상. 초반 장터 뒤 짧은 다음 목표를 표시한다. |
| 2 | [재료 상세](v1-diagnostics/portrait_harbor_02_details.png) | 정상. 재고·맛·원가·시간과 아이콘/펼침 방향을 읽을 수 있다. |
| 3 | [이동](v1-diagnostics/portrait_harbor_03_travel.png) | 정상. 이미 낸 비용과 이동 진행률을 표시한다. |
| 4 | [목표 재료](v1-diagnostics/portrait_harbor_04_target.png) | 정상. 육수/고명 선택과 서로 다른 특징을 설명한다. |
| 5 | [손질 수량](v1-diagnostics/portrait_harbor_05_quantity.png) | 정상. 1개 추가0원 / 3개 추가600원을 선택 전에 보여준다. |
| 6 | [수령 대기](v1-diagnostics/portrait_harbor_06_waiting.png) | P2. 세로 화면에서 다음 수령 버튼이 긴 안내 아래로 밀린다. |
| 7 | [수령 후](v1-diagnostics/portrait_harbor_07_received.png) | 정상. 가리비 재고3과 개발 이동을 표시한다. 효과 전체 품질은 정지 화면만으로 평가하지 않는다. |
| 8 | [개발 이동](v1-diagnostics/portrait_harbor_08_workbench.png) | P2. 토핑 서랍만 보이고 실제 가리비 선택은 화면 아래에 있다. |
| 9 | [그릇 캡처 실패](v1-diagnostics/portrait_harbor_09_triple_dish.png) | 증거 거부. 검사 코드가 열린 서랍을 닫아 실제로는 매장만 보인다. |
| 10 | [결과 캡처 실패](v1-diagnostics/portrait_harbor_10_result.png) | 증거 거부. 실제 시식 거래는 성공했지만 이 이미지는 결과 화면을 입증하지 않는다. |
| 11 | [다음 날 재방문](v1-diagnostics/portrait_harbor_11_broth.png) | 정상. 사용한 가리비0과 새 육수1을 표시한다. |
| 12 | [육수 선택](v1-diagnostics/portrait_harbor_12_broth_dish.png) | P2. 이름의 마지막 글자가 홀로 줄바꿈된다. 파일 이름과 달리 선택 화면이며 그릇 그림의 증거로 사용하지 않는다. |

## 반영한 수정

수령 버튼이 보이도록 자동으로 이동하되 지급은 직접 누를 때만 한다.
저장 실패 시 자동 이동보다 저장 경고가 우선한다.
개발 이동은 초안을 유지하며 해당 재료 버튼까지 보여준다.
버튼에서는 '정어리 육수'로 줄이고 상세에는 전체 이름을 유지한다.
검사는 서랍·그릇이 실제로 보이는지 확인하고 개발/결과/육수 그릇을 따로 캡처한다.

새 위치 검사는 수정 전 코드에서5건 실패하고 수정 후 통과했다.
이는 동작·배치 증거이며 아직 수정된 실제 화면을 대신하지 않는다.
v2에서 같은 상태/해상도의 전후 화면을 함께 비교해 위 수정 결과를 확인했다.

## 확인 범위

GowunDodum 글꼴, 종이/갈색/주홍/청록 색, 도트 자산을 유지했다.
펼침 방향과 재고는 색만으로 전달하지 않으며 주요 버튼은 배치 검사에서44px 이상이다.
색 토큰 일부의 단순 대비 계산은 청록/종이 약4.48:1, 주홍/종이 약4.49:1로 경계에 있으므로
AA 준수를 선언하지 않는다. 전체 대비·보조기술·글자 확대·물리적 iPhone 조작은 별도 확인이 필요하다.
문구 반복과 중복 수령 안내는 다음 문구 정리 시 개선할 P3 사항이다.

[원본 해시·수동 검토·거부 역할](v1-review.json) · [현재 디자인 검증](../../../design-qa.md)
