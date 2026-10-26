# 직접 원재료를 배합하는 육수 개발 · 실제 화면

Mac 공식 Godot4.7.2의 실제 OpenGL 렌더러에서 최종336소스와 같은 PCK로 자동 입력·캡처했다. 세로390×844와 가로1280×800이며 아이폰 실기기 캡처나 새 아이폰 설치가 아니다. 전체52장은 비공개 검증 보관본에 유지하고 현재 기능을 설명하는13장을 선별했다.

| 실제 장면 | 세로 | 가로 |
| --- | --- | --- |
| 완성 육수가 없는 새 게임 | [첫 개발](portrait_broth_00_first.png) | — |
| 원재료 성질·공급처 | [돼지뼈 상세](portrait_broth_02_raw_detail.png) | — |
| 배합과 취소 후 동일 배합 복귀 | [원재료3칸](portrait_broth_05_cancel.png) | [선택 목록·우림 방식](desktop_broth_03_blend.png) |
| 실제 시간으로 우림 진행 | [솥·진행·취소](portrait_broth_04_brewing.png) | [우림](desktop_broth_04_brewing.png) |
| 완성 후 명시적으로 사용 | [육수 보관함](portrait_broth_06_complete.png) | [보관함](desktop_broth_06_complete.png) |
| 자동 저장 거부를 알림 | [저장 경고](portrait_broth_06_unsaved.png) | — |
| 직접 만든 육수를 라멘에 적용 | [그릇](portrait_broth_07_applied.png) | — |
| 기존 공급처ID도 원재료로 연결 | [정어리 원재료](portrait_broth_07_source.png) | — |
| 실제 시식 기록·인물 반응 | [완성 시식](portrait_broth_08_tasted.png) | [완성 시식](desktop_broth_08_tasted.png) |

저장 경고 장면은 시험 저장 보호를 의도적으로 켜서 실제 완료 시 자동 저장을 거부한 상태다. 보호를 풀고 수동 저장을 재시도해 개발비 중복 결제 없이 복원한 뒤 정상 보관함을 촬영했다. 배합 이미지는 취소 후 복귀 상태이며 현재 육수를 자동 교체하거나 개발비를 쓰지 않았다. 선택/우림/보관/사용/시식은 서로 다른 상태다.

메뉴·토핑·가격·시식의 기존 편집 흐름도 같은 패키지에서 별도 실제 렌더링으로 검사했다. 글자/솥/빈 화면 검사를 시험 수만으로 대체하지 않으며 선택 장면의 실제 배치와 내용을 확인했다.

[육수 규칙](../../RAW_BROTH_DEVELOPMENT_V1.md) · [최종 선별 증거](../../../../evidence/raw-broth-development-v1.json).
