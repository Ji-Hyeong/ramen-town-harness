# Ramen Town — Codex × Claude 개발 하네스

라멘 메뉴 개발, 직원 육성, 단골 이야기와 골목 성장을 연결하는 게임을 준비합니다. **현재는 Mac에서 실행하는 도트 라멘가게 프로토타입 단계입니다.** 직원 육성·단골 서사·골목 건설은 장기 목표이며 아직 구현하지 않았고, iOS 빌드와 실기기 검증도 하지 않았습니다.

## 현재 버전: 라멘 아틀리에 (매장 중심)

기본 화면은 코드로 그린 작은 도트 가게(주방·카운터·테이블·입구·골목 줄)입니다. 영업을 시작하면 손님이 줄을 서고 자리에 앉아 주문하고, 요리사가 만들고 서버가 나르며 손님이 먹고 반응한 뒤 떠납니다. 먹기를 마친 주문만 매출로 정산되며, 영업을 끝까지 마쳐야 저장됩니다(도중에 끄면 영업 전 상태로 돌아옴). 메뉴 개발(재료 선택, 세 단골의 시식 피드백, 개정·비교, 노트)은 하단 버튼으로 여는 보조 서랍입니다. 기본 요리사·서버에 조리/홀 보조를 추가 채용할 수 있으며 육성·배치 편집·단골 분기 이야기는 후속입니다. [상세와 한계](game/README.md)

**연구 의뢰(feature/ramen-research):** 메뉴 개발 서랍의 `연구` 탭에서 입문 3개·심화 3개를 진행합니다. 입문 두 개를 마치면 심화가 열리고, 실제 시식 기록을 제출하면 점수·자금을 한 번만 받습니다. 저장 v2는 기존 v1을 보존해 읽습니다. Codex 독립 검사 42개 테스트·41,034개 확인, 두 크기 UI 2,646개 확인이 통과했으며 연구 화면까지 Codex가 자동으로 앱을 실행해 2,698개 확인·실패 0, 새 PNG 26장과 종료 0을 확인했습니다. [검증 증거](evidence/ramen-research-runs.json). [상세](game/README.md#라멘-연구)

**자동 화면 검증:** Claude가 자체 포함 로컬 QA 앱 제작 도구를 작성하고 Codex가 검토·실행·수정을 검증했습니다. 사용자에게 매번 터미널 실행을 넘기던 흐름을 앱 준비 → Codex 실행 → 새 캡처·종료·오류 확인으로 바꿨습니다. [자동화 증거](evidence/automatic-native-qa.json), [사용 규칙](game/README.md#자체-포함-qa-앱-자동-그래픽-qa용-로컬-개발-전용).

**플레이 피드백 1차:** 글자 대신 그릇 문양 간판, 약 4초의 국물·면·시식 진행 연출, 단골별 작은 초상, 자동·수동 저장 안내를 추가했습니다. [작업 계약](tasks/feedback-play-feel.md), [실행 증거](evidence/feedback-play-feel-runs.json).

**현재 성장 버전(v3):** 등급 심사로 가게 랭크 3단계를 올리고, 조리대·직원 공간을 구매해 토핑 1→2→3개, 메뉴 개정 기록 6→12→30칸, 직원 2→3→4명을 열 수 있습니다. 직원은 별도 채용하며 실제 조리·서빙 시간과 일당이 영업에 반영됩니다. 기존 단일 토핑 점수·원가·시식평과 v1/v2 저장은 보존합니다. Claude가 코드·테스트를 작성하고 Codex가 60개 테스트/48,272개 확인, 배치 7,056개, 실제 OpenGL 화면 7,168개·56장·종료 0·엔진 오류 없음을 확인했습니다. [계약](tasks/shop-growth-v1.md), [독립 검증과 중단·재개 기록](evidence/shop-growth-runs.json), [성장 규칙](game/README.md#가게-성장). 재료 탐색·콘테스트·작은 이벤트는 후속이며 아직 없습니다.

**방향 수용 ≠ 최종 승인:** 수용한 [시안](game/DESIGN_DIRECTION.md)은 등각 투영(아이소메트릭)입니다. 현재 코드는 시안을 베끼지 않고 직접 짠 도트 규칙으로 등각 컷어웨이 가게(마름모 바닥 타일, 입체 카운터/테이블/의자, 세운 벽·주방·선반, 파사드와 인도 줄, 이웃 건물·소품)를 그리도록 바뀌었습니다(세로 176×264 / 가로 320×152 논리 픽셀). 다만 이 그림은 시안보다 단순한 프로토타입이며 최종 사용자 화면 승인은 대기합니다. 시안은 방향 검토용 AI 생성 이미지일 뿐 구현 화면이 아닙니다.

추가 등각 투영 그림 보완은 Claude의 서버 인증 오류(`OAuth token revoked`)로 중단됐지만, 2026-10-14 재로그인 후 실제 모델 요청이 `AUTH_OK`로 성공해 복구했습니다([복구 확인](evidence/auth-recovery-20261014.json)). 등각 그림·조각 좌표·퇴장 경로와 모바일 표시를 보완했고, Codex 독립 검사 30개 테스트/40,404개 확인 및 두 크기 UI 1,548개 확인이 통과했습니다. 실제 캡처에서 표시 오류를 발견해 수정한 뒤 다시 실행했고, 렌더링 QA 1,588개 확인·실패 0과 [현재 화면 20장](game/docs/isometric-screenshots)을 확인했습니다. 최종 사용자 화면 승인과 플레이 감은 대기합니다.

아래는 현재 성장 버전의 실제 게임 화면입니다. 이전 화면은 검증 문서의 역사적 기록으로 보관합니다.

![확장·승급 조건과 직원 현황](game/docs/growth-screenshots/desktop_19_growth_purchased.png)
![추가 직원과 실제 영업](game/docs/growth-screenshots/portrait_27_full_service.png)

- [실행 방법과 게임 규칙](game/README.md) — Godot 4.7.2 안정 버전 사용. 다른 컴퓨터에서는 Godot 설치 후 game/project.godot를 가져와 실행합니다. 이 저장소에는 엔진 바이너리가 없습니다.
- [검증 기록](game/VERIFICATION.md) — 최신 성장 버전: 60개 테스트/48,272개 확인, 배치 7,056개 및 실제 화면 7,168개·56장 통과. 새 기능 사용자 플레이 감·iPhone은 별도 확인 범위입니다.
- [매장 재설계 위임 기록](evidence/shop-playable-runs.json) — 턴 제한 실패, 결함 수정, 실제 응답 필드와 Codex 독립 검사 결과를 구분합니다.
- [위임 실행과 사용량 기록](evidence/ramen-lab-runs.json) — 중단·인증 실패·수정 실행도 포함합니다. 서비스별 구독 사용률 절감이나 50:50 분배를 증명하지 않습니다.

장면의 도트(사람·가구·말풍선·그릇)는 외부 에셋 없이 코드로 찍었고 글꼴만 OFL 한국어 글꼴입니다. 상용 수준의 도트 아트·애니메이션은 후속 작업입니다.

Codex가 요구사항과 독립 검증을 담당하고 Claude Code가 코드·테스트를 구현합니다. 초기 연결 테스트와 첫 게임 구현의 검증 기록을 구분해 남기며, 이 저장소의 기록은 상용 게임 완성도를 증명하는 벤치마크는 아닙니다.

```mermaid
flowchart LR
    U[사용자 요구사항] --> C[Codex: 작업 계약 작성]
    C --> I[Claude Code: 구현]
    I --> V[Codex: 변경 내용 및 테스트 독립 검증]
    V -->|결함과 재현 조건| I
    V -->|통과| R[검증 결과 보고]
```

## 이 저장소에서 확인할 수 있는 것

| 내용 | 파일 |
| --- | --- |
| 역할 분담, 수정 루프, 완료 판단 규칙 | [AGENTS.md](AGENTS.md), [CLAUDE.md](CLAUDE.md) |
| 구현 범위와 검증 방법을 명시한 작업 계약 | [테스트 계약](tasks/smoke.md), [계약 템플릿](tasks/template.md) |
| 인증·모델·턴 제한 실패 및 최종 통과 기록 | [VERIFICATION.md](VERIFICATION.md) |
| 세션 식별자를 제외한 실제 응답 필드 | [검증 증거](evidence/smoke-summary.json) |
| iPhone 우선 플랫폼 방향과 게임 기획 | [GAME_DESIGN.md](GAME_DESIGN.md) |

## 검증에서 배운 점

- 프로세스 종료 코드가 0이어도 작업이 완료됐다고 단정할 수 없습니다. 실제로 턴 제한 응답은 종료 코드 0과 `is_error=false`를 반환했습니다.
- 완료 판정은 종료 코드, 응답 유형, 오류 여부, 보고 내용, 파일 상태를 함께 확인합니다.
- Claude가 수정했다고 보고한 파일을 Codex가 기준 파일과 바이트 단위로 비교하고, 기존 파일들의 해시로 범위 밖 변경 여부를 확인했습니다.
- 기본 프로필은 파일 도구만 제공합니다. 검토된 테스트 프로필에서는 지정한 명령만 Claude가 실행하고, Codex도 완료 기준을 독립 검증합니다. 전체 무인 개발 파이프라인은 아닙니다.

## 사용량 분산을 위한 V0 운영

목표는 Claude에 구현 작업을 충분히 맡기면서 Codex의 중복 분석을 줄이는 것입니다. 사용률을 자동으로 50:50으로 맞추는 기능은 없습니다.

| Claude Code | Codex |
| --- | --- |
| 관련 코드 탐색과 상세 설계 | 요구사항·범위·완료 기준 정의 |
| 코드 및 테스트 작성 | 변경 부분과 필요한 주변 코드 리뷰 |
| 허용된 명령으로 자체 검증 | 완료 기준과 회귀 테스트 독립 실행 |
| 결함 수정과 짧은 결과 보고 | 재현 조건을 포함한 구체적인 수정 지시 |

초기 작업은 독립된 계약으로 실행합니다. 같은 작업의 수정은 필요한 경우 로컬에 보관된 해당 세션 ID로 `--resume`하되, 권한과 파일 상태를 다시 검토합니다. 전체 대화나 소스 코드를 반복 전달하지 않습니다. 기본 턴 상한은 연결 테스트 20, 작은 구현 작업 30, 수정 요청 10이며 토큰 상한은 아닙니다. 한도 도달 시 상태를 확인하고 작업을 나누거나 이어갑니다.

Claude의 실제 응답에 usage/modelUsage/total_cost_usd가 있으면 로컬 실행 기록에 보관하고, 없는 값은 미확인으로 둡니다. 비용 추정값은 구독 청구액이 아니며 토큰 수로 서비스별 사용률을 환산하지 않습니다. Codex 사용률도 확인 가능한 경우에만 작업 전후 관찰값으로 기록하고, 다른 작업이 동시에 사용했다면 이 작업만의 소비라고 단정하지 않습니다. 실제 게임 작업 몇 건 후 위임 범위를 조정합니다.

원본 실행 로그는 로컬에 보관하고 Git에서는 제외합니다. 공개 증거에는 검증에 필요한 필드만 포함합니다. 아래 통과 기록은 최초 Mac 환경에서 관찰한 결과이며, 다른 계정·모델·CLI 버전에서는 다시 검증해야 합니다.

Start Codex in this project root so AGENTS.md is discovered. Authenticate both CLIs before reproducing the test. The checked-in fixture represents the completed test: change only status=verified to status=pending before running it again.

## Invocation contract

Codex writes a concrete contract using tasks/template.md. Execute from this directory, with a fresh result filename for each attempt:

```sh
"$HOME/.local/bin/claude" -p \
  --model claude-sonnet-5-5 \
  --output-format json \
  --max-turns 20 \
  --restricted \
  --permission-mode dontAsk \
  --strict-mcp-config \
  --mcp-config '{"mcpServers":{}}' \
  --tools 'Read,Edit,Write,Glob,Grep' \
  --allowedTools 'Read,Edit,Write,Glob,Grep' \
  < tasks/smoke.md > smoke/result-next.json
```

This option set passed with native Claude Code 2.1.296 at /Users/ji/.local/bin/claude. The explicit model avoids the obsolete default model in the old CLI. Homebrew Claude was also upgraded from 1.0.120 to 2.1.287; the current shell resolves plain `claude` to /opt/homebrew/bin/claude. This harness explicitly selects the verified native installation without modifying the user's PATH. The successful test used smoke/result-updated.json and completed in six turns.

Use shell input redirection for the contract, not command substitution or eval. Never interpolate the user's task into a shell command. Keep the working directory explicit. Do not use --continue; initial contracts are self-contained. Only explicitly resume the same task for corrections as described above. Do not use --dangerously-skip-permissions, bypassPermissions or additional directories.

The empty strict MCP configuration prevents unrelated MCP connections. Only five file tools are exposed; dontAsk rejects unapproved operations, and restricted confines file tools to the working directory and ignores ordinary user/project/local settings. Bash is unavailable, so Claude cannot run tests through Bash in this V0 profile. Codex runs reviewed verification commands independently and returns their results to Claude for targeted corrections. These CLI permissions are not an operating-system sandbox; only use this in a trusted project and enforce editable paths through contracts and independent change review.

For normal implementation, replace the input with the reviewed task contract, choose a unique output path, and set an appropriate finite turn limit. Monitor the process; cancel a stalled invocation rather than retrying concurrently. Retain failed output for diagnosis. Do not broaden permissions to solve an authentication error.

### Reviewed-tests profile

**상태: 허용된 명령 실행 PASS.** 개별 네트워크·Claude 상태 디렉터리 쓰기 권한 요청 후 기존 구독 로그인을 읽을 수 있었고, Claude의 실제 Read → Read → Bash 비교 실행과 Codex의 독립 비교가 통과했습니다. 허용되지 않은 명령의 거부 경로는 별도 미검증입니다. [검증 기록](VERIFICATION.md), [선별 실행 증거](evidence/reviewed-tests-summary.json)

Codex 실행에서 인증 오류가 나면 같은 CLI의 `auth status`를 사용자의 일반 터미널과 비교합니다. 일반 터미널에서 로그인됐는데 Codex에서만 실패하면 재로그인이나 토큰 복사 전에 실행 권한을 점검합니다. 이번에는 `request_permissions`로 네트워크 및 `~/.claude`, `~/.claude.json` 쓰기 접근을 승인받은 뒤 정상화됐습니다. 권한은 이번 턴 범위였으므로 다음 실행에서는 다시 필요할 수 있습니다. 전체 접근이나 전역 권한 변경 없이 확인했으며, 필요한 경로는 실행 환경에 맞춰 최소 범위로 요청합니다.

이 프로필은 파일 도구에 Bash를 추가하지만, 자동 허용은 계약에서 검토한 정확한 명령으로 제한합니다. 실행할 스크립트가 있다면 그 내용과 부작용도 먼저 확인합니다. 넓은 `Bash` 허용, 인터프리터 와일드카드, 설치·네트워크·Git 변경·배포 명령은 허용하지 않습니다. 파일 권한은 위 기본 프로필과 같으며 계약의 편집 범위도 계속 검증합니다.

```sh
"$HOME/.local/bin/claude" -p \
  --model claude-sonnet-5-5 \
  --output-format json \
  --max-turns 20 \
  --restricted \
  --permission-mode dontAsk \
  --strict-mcp-config \
  --mcp-config '{"mcpServers":{}}' \
  --tools 'Read,Edit,Write,Glob,Grep,Bash' \
  --allowedTools 'Read,Edit,Write,Glob,Grep' 'Bash(cmp smoke/probe.txt smoke/probe.expected.txt)' \
  < tasks/reviewed-tests-smoke.md > smoke/result-reviewed-tests.json
```

게임 구현 시에는 이 비교 명령을 그대로 쓰지 말고, 실제 테스트 명령을 검토한 뒤 계약과 허용 목록을 함께 바꿉니다. 거부된 명령은 자동 재시도하거나 권한을 넓히지 않습니다. 거부 경로의 자동 테스트는 아직 구성하지 않았습니다.

## Independent acceptance

1. Record the process exit code. Require exit code 0 and valid JSON with subtype=success AND is_error=false AND a nonempty result. Neither flag alone is sufficient: the authentication failure had subtype=success; a turn-limit failure had is_error=false and exit code 0.
2. Inspect permission_denials and the actual changed files. New untracked files must also be reviewed; git diff alone does not include them.
3. For this fixture, require exactly two lines: `nonce=v0-20261013-7a91c4e2` and `status=verified`, with a final newline. Compare with smoke/probe.expected.txt. Require the report to include the original nonce as additional reading evidence.
4. Require no unexpected changes. On a later Git project, inspect status, staged/unstaged diff and untracked files, then run relevant tests independently.
5. On failure, send a targeted correction contract with the failing command/output and expected behavior. Stop after three failed correction attempts and report the blocker.

To repeat a successful connectivity test, Codex must first reset only the dedicated smoke fixture to status=pending, preserving its nonce. Never reset a whole repository for this purpose.

## Ready state

After user login and CLI updates, authenticated reading and editing passed independent acceptance. The fixture currently has status=verified. Before another smoke test, reset only its status to pending. The user can now supply game requirements; Codex will prepare the contract, Claude will implement, and Codex will independently verify. Game-specific build tools and tests will be selected when the requirements are known.

## References

- [Claude Code CLI reference](https://code.claude.com/docs/en/cli-reference): print invocation, JSON output and tool permissions. Installed CLI help was used to check version compatibility.
- [Claude model IDs](https://platform.claude.com/docs/en/models/overview): source for the explicit Sonnet model identifier; availability was also verified by an actual invocation.
- [Claude installation and updates](https://code.claude.com/docs/en/setup): native and Homebrew update paths.
