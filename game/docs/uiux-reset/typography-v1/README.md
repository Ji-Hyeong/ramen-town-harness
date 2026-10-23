# 글꼴·안쪽 여백 개선

2026-10-23. 아래 이미지는 새 Godot 실행에서 직접 얻은390×844 화면입니다.
기존 v5의 굵은 도트 글꼴과 국물·면 제목의 테두리 밀착을 지적한 사용자
피드백을 반영했습니다. 도트 그림은 유지하고 UI에 실제 Regular/SemiBold
글꼴을 적용했습니다. 요약 카드에는 좌우12px·위아래10px의 실제 여백을
넣었고, 목록·토핑·하단 재료비의 간격도 정리했습니다.

![현재 실제 화면](portrait_editor_01_initial.png)

[선택한 디자인·수정 전·수정 후 전체 비교](comparisons/portrait-full-source-before-after.png)
· [국물·면 확대](comparisons/portrait-summaries-source-before-after.png)
· [목록·시식 버튼 확대](comparisons/portrait-controls-source-before-after.png)

실제 Mac 실행490검사/실패0/종료0, 가로·세로30장입니다. 현재 원본13장과
비교3장을 직접 열어 검토했습니다. 나머지17장을 개별 육안 검토했다고
주장하지 않습니다. 전체42개 실행 파일은 별도로 바이트 일치 보존했습니다.
[검토 범위와 전체 캡처 해시](review.json), [최신 검토](../../../../design-qa.md).
4칸 화면은 합성한 랭크3 배치 검증이며 실제 성장/저장 결과가 아닙니다.
실패 저장 화면도 격리한 시험 저장소입니다. 호버 안내가 남은 일부 캡처는
Mac 포인터의 실제 상태입니다. 아이폰 설치·실기기 수용은 수행하지 않았습니다.

글꼴은 [Pretendard 공식 배포본v1.3.9](https://github.com/orioncactus/pretendard/releases/tag/v1.3.9)의
원본 Regular/SemiBold입니다. 원본 해시·전체 OFL은 assets/fonts/에 보존하며
실제 팩의 라이선스 포함도 검사합니다. 시스템 글꼴 설치는 하지 않습니다.
