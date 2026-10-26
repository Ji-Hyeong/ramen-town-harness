# 개발품 비교·개량의 실제 화면

이전 main77947d5의 실제 완성품 목록을 새로 캡처한 뒤, 선택한 기존 프레임·글꼴·음식 그림을 유지해 흐름을 확장했다. 시안 이미지를 실행 증거로 대신하지 않는다. 세로390×844와 가로1280×800은 Mac의 실제 렌더링이며 물리 iPhone 테스트는 아니다.

1. [이전 면 목록](before/portrait_before_noodle_library.png), [이전 육수 목록](before/desktop_before_broth_library.png): 완성품 적용만 가능했다. 기준 소스347개는 이전 수락 main과 해시가 모두 같다. 이전 캡처와 현재 캡처의 시험 시식 횟수는 다르므로 잔액의 픽셀/경제 비교 자료로 사용하지 않는다.
2. [미완성 새 게임](portrait_component_00_partial.png), [이미 사용 중인 육수](portrait_component_01_already_applied.png): 실제 준비 상태를 구분하고, 없는 기준 그릇이나 허위 점수를 만들지 않는다. 현재 사용 중이면 중복 적용 버튼을 끈다.
3. [면의 변화](portrait_component_02_noodle.png): 식감·향의 양수/음수 차이와 원가·준비 시간을 읽는다. 수치는 한 줄로 유지하고 카드·버튼에서 밀어도 스크롤한다.
4. [한 그릇 예상](portrait_component_03_noodle_ramen.png), [가로 육수 예상](desktop_component_03_broth_ramen.png): 같은 그릇에서 선택한 면/육수만 바꾼다. 그림 위의 밀기도 스크롤하며 선택·재료 소모를 일으키지 않는다. 실제 시식 기록과 구분한 단골의 예상 평가다.
5. [배합 불러오기와 저장 거부](portrait_component_06_noodle_unsaved.png), [새 시식 기록](portrait_component_08_revised_tasting.png): 불러오기는 개발실 초안만 바꾸고, 변경 제작·명시적 사용·새 시식 뒤에 실제 기록을 만든다. 저장 거부 화면은 보호된 시험 저장소를 의도적으로 사용한 장면이며, 해제 후 무료 재저장도 검사한다.
6. [최신 목록](portrait_component_09_page_one.png), [이전 목록](portrait_component_10_page_two.png), [오래된 배합을 개량한 직후](portrait_component_11_newest_completion.png):6개씩 페이지를 넘기고, 새 제작이 끝나면 방금 결과가 있는 최신 페이지로 돌아온다. 실제 보관 기록은 재정렬하거나 삭제하지 않는다.

화면에서 확인한 것은 실제 표기·여백·버튼과 목록의 배치다. 자동 입력으로 클릭/스크롤 취소와 실제 배합·저장 상태를 별도 검사한다. 스크린리더·물리 안전 영역·진동·사람의 재미와 장시간 밸런스는 이번 증거로 수락하지 않는다.

최종 소스·패키지·전체 원본 캡처·별도 저장·로그·종료 상태는 원래 작업 공간 `outputs/ramen-component-comparison-v1/final-v3`에 보관한다. 소스 해시와 분담·실제 검증 결과는 저장소 루트 `evidence/component-comparison-v1.json`, 기능 규칙은 [설명](../../COMPONENT_COMPARISON_V1.md)에 기록한다.
