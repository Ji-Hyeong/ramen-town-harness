# 라멘 아틀리에 — 레시피 개발 프로토타입

Godot 4.7(타입 지정 GDScript) 프로젝트입니다. 라멘 레시피를 만들고, 단골 세 분의 시식 반응을 읽고, 개정해 비교한 뒤 하루 영업으로 정산하는 작은 연구소 루프를 담았습니다. Mac 데스크톱에서 실행하며 세로(390x844) 터치 레이아웃도 지원합니다. iOS 내보내기와 실제 기기 검증은 아직 하지 않았습니다.

## 플레이 흐름
1. **연구**: 육수·타레·향미유·면·토핑·익힘을 고르고 판매 가격을 정합니다. 각 선택지의 비용·준비 시간·맛 기여가 표시됩니다.
2. **시식**: 이름을 붙여 시식하면 한도윤·서하영·윤마루의 점수와 이유(맛 수치, 취향, 재료 궁합, 가격 반응)를 읽을 수 있습니다. 시제품 재료비가 자금에서 빠집니다.
3. **개정**: 노트에서 레시피를 불러오면 구성·가격·익힘이 복원되고, 바꿔서 다시 시식하면 같은 이름의 새 버전이 되며 이전 버전과의 비교가 표시됩니다.
4. **영업**: 노트에서 고른 레시피로 **하루** 영업합니다. 한 번 누르면 1일이 지나며 판매량·매출·재료비·운영비·순영업이익이 정산됩니다.

## 규칙 요약
- 손님마다 취향 수치와 궁합 민감도, 기대 가격이 달라 모두에게 최고인 레시피는 없습니다(테스트가 972개 조합 전수로 확인).
- 노트는 최대 30개이며 같은 구성·가격·익힘은 중복 기록되지 않습니다. 기록은 불변 스냅샷이고, 삭제는 두 번 눌러야 합니다.
- 가격은 1,000~30,000원(100원 단위). 비싸면 수요가 줄고, 준비 시간이 길면 점심 피크(40분)에 만들 수 있는 양이 줄어듭니다.

## 저장
- 일반 실행은 `user://ramen_lab_save.json`(+ `.bak`, 쓰기용 `.tmp`)을 씁니다. 임시 파일에 쓰고 내용을 확인한 뒤 교체합니다.
- 저장이 없으면 첫 방문으로 시작합니다. 손상되었거나 지원하지 않는 버전이면 화면에 알리고 파일을 건드리지 않으며(자동 저장 중지), 사용자가 버튼을 눌러야 파일을 따로 보관하고 새로 시작합니다.
- 개발/QA용: `-- --dev-data-dir=<절대 경로>` 를 주면 그 폴더에 저장하고 화면 아래에 "개발용 저장 위치"가 표시됩니다. 잘못된 경로는 `user://`로 대체하지 않고 오류를 보여 줍니다.

## 실행과 검증
Godot 4.7.2에서 `game/project.godot`를 가져오고 프로젝트 실행(F5)을 사용합니다. 다른 컴퓨터에서는 Godot을 별도로 설치해야 합니다. 엔진 바이너리는 Git에 포함하지 않습니다.

현재 Mac의 iTerm에서는 아래 **한 명령**으로 개발 저장 위치를 분리해 게임을 시작할 수 있습니다. 어느 폴더에서 실행해도 됩니다.

```sh
/Users/ji/Documents/Codex/2026-10-13/referenced-chatgpt-conversation-this-is-an/work/tools/godot-4.7.2/Godot.app/Contents/MacOS/Godot --path /Users/ji/Documents/Codex/2026-10-13/referenced-chatgpt-conversation-this-is-an/outputs/v0-harness/game -- --dev-data-dir=/Users/ji/Documents/Codex/2026-10-13/referenced-chatgpt-conversation-this-is-an/work/player-save
```

검증용 예시는 저장소 루트에서 실행하며, 먼저 아래 변수를 설정합니다. 다른 컴퓨터에서는 자신의 실행 파일 경로로 바꿉니다.

```sh
RAMEN_GODOT=../../work/tools/godot-4.7.2/Godot.app/Contents/MacOS/Godot
```

```sh
# 최초 임포트(글꼴 등)
"$RAMEN_GODOT" --headless --path game --editor --import --quit

# 실행 (개발용 저장 폴더 지정)
"$RAMEN_GODOT" --path game -- --dev-data-dir=/절대/경로/dev-save

# 헤드리스 테스트: 실패하면 종료 코드 1 (인자 오류 2)
"$RAMEN_GODOT" --headless --path game --script res://tests/run_tests.gd -- --test-data-dir=/절대/경로/test-data

# 실제 렌더러 QA 캡처(--headless 금지): 데스크톱 1280x800, 세로 390x844
"$RAMEN_GODOT" --path game --script res://tests/qa_capture.gd -- --qa-out=/절대/경로/shots

# 레이아웃/핸들러 전용 QA(헤드리스): 스크린샷을 만들지 않음. 시각 렌더링·iPhone 검증이 아님
"$RAMEN_GODOT" --headless --path game --script res://tests/qa_capture.gd -- --layout-only --qa-out=/절대/경로/layout-only
```

`--layout-only`는 이미지 추출과 `frame_post_draw` 대기만 건너뛰고, 실제 메인 씬을 두 해상도 SubViewport에 띄워 선택·시식·개정·노트·영업·재시작 복원과 도달성·가로 넘침 검사를 그대로 실행합니다. 자동으로 켜지지 않으며 실행하면 "LAYOUT ONLY: no screenshots or visual rendering verified"를 출력합니다.

로그 파일을 따로 두려면 `--log-file <경로>` 를 추가하세요(기본 파일 로그는 꺼져 있습니다).

## 로컬 macOS 런처 앱 (개발 편의용)
`tools/build_local_apps.py`(표준 라이브러리만 사용)가 `Ramen Atelier.app`(게임)과 `Ramen QA.app`(`tests/qa_capture.gd`)을 `--output-dir`에 만듭니다. 각 앱은 `Info.plist`와 셸 런처만 가진 얇은 번들로, 지정한 Godot 실행 파일을 프로젝트 경로·`--log-file`(output-dir 안)·`--dev-data-dir`와 함께 `exec` 합니다. QA 앱은 `--qa-out`에 스크린샷을 저장하고 저장 폴더는 `<data-dir>/qa`를 씁니다. 스크립트는 파일만 쓰며 Godot를 실행하지 않고, 이미 있는 `.app`이 있으면 덮어쓰거나 지우지 않고 중단합니다.

```sh
python3 game/tools/build_local_apps.py --godot /절대/경로/Godot --project /절대/경로/game \
  --output-dir /절대/경로/apps --data-dir /절대/경로/dev-save --qa-out /절대/경로/shots
```

엔진을 복사하지 않고 서명도 하지 않은 로컬 전용 번들입니다. 독립 실행 가능한 Godot 내보내기 빌드와 iOS 빌드(Xcode, 서명, 실기기 검증)는 아직 하지 않았으며 이후 작업입니다.

현재 도구 환경에서 생성 앱의 정상 플레이 실행은 검증하지 못했습니다. 실제 렌더링 캡처는 사용자가 iTerm에서 Godot를 직접 실행해 확인했으므로, 우선 직접 실행 방법을 사용합니다. [구체적인 검증 범위](VERIFICATION.md)

## 화면 미리보기

![이전 레시피와 비교](docs/screenshots/desktop-comparison.png)

![세로 시식 화면](docs/screenshots/portrait-feedback.png)

## 구조
- `scripts/domain/` 재료·손님 데이터, 평가기, 판매 시뮬레이션, 게임 상태(UI와 분리)
- `scripts/services/` 저장 서비스, 저장 위치 결정
- `scripts/ui/` 메인 화면, 코드로 그린 그릇과 별 표시
- `tests/` 헤드리스 테스트, QA 캡처 스크립트
- `assets/fonts/` 고운돋움(OFL, 라이선스 동봉)
