# iPhone 실기기 준비 v1

## 최신 산골 채집 버전 설치 · 2026-10-26

main `59c0845`의 산골 반복 채집·메밀/산표고 메뉴 실험·최신 네이티브 UI·요리사 성장을
**0.15(빌드 15.0.1)**로 iPhone 15 Pro/iOS 26.6.2에 설치하고 실행했습니다.
설치·버전 조회·신뢰 후 실행 JSON 성공과 실제 실행 중인 앱 프로세스를 확인했습니다.
처음 실행은 iOS 보안 확인으로 거부됐고 사용자가 개발자 앱 신뢰를 완료한 뒤 성공했습니다.

설치 전 같은 식별자의 앱은 없었습니다. 제거 작업은 하지 않았으며 기존 저장의
전후 보존을 확인했다고 주장하지 않습니다. 325개 게임 소스는 검증한 main과 같고,
임시 iOS 설정만 변경했습니다. 서명 빌드·프로필·기기·번들·내장 PCK·실제 패키지
시작 검사는 통과했습니다. 개발용 서명은 **2026-10-27 23:45:57(한국 시간)**까지 유효합니다.
서명 앱과 원본 로그는 비공개로 보존했습니다. 실제 조작·소리·한글 키보드·중단 복귀의
사용자 평가는 별도이며, 설치 요청을 마친 뒤 추가 기기 조작은 하지 않습니다.

[설치 검증 기록](../../evidence/ios-mountain-install-v1.json)

## 최신 메뉴 개발 버전 업데이트 (2026-10-23)

사용자가 iPhone을 연결하고 이전 버전 삭제 후 설치 또는 업데이트를 요청했다.
실제 USB 연결된 iPhone15Pro/iOS26.6.2의 신뢰·개발자 모드를 확인하고,
PR19의 main `2f43dbd`를 **0.13(빌드13.0.1)**로 같은 앱에 업데이트했다.
삭제하지 않았으며 실제 설치 버전 조회와 실행 JSONsuccess/종료0을 확인했다.
[이번 계약](../../tasks/ios-workbench-update-v1.md),
[개인 식별자를 제외한 실제 증거](../../evidence/ios-workbench-update-v1.json).

설치 전 게임의 저장·일반 백업만 비공개로 복사했다. 기존 저장은v11이며,
복사본에서 최신 서비스로 읽기→v13저장→다시 읽기를 수행해 상태 일치를 확인했다.
복사본의 최초v11 보관 파일도 원본과 바이트 일치했다. 실제 기기의 두 파일은
설치 직전 다시 복사하고 **설치 직후·새 앱 실행 전 두 파일 모두 바이트 일치**를 확인했다.
이 검증은 설치 중 보존의 증거이며 이후 사용자의 플레이로 생기는 정상 저장까지
바이트가 계속 같아야 한다는 뜻은 아니다. 사용자 저장·기기 식별자·계정·프로필은 Git에 넣지 않았다.

새 격리 프로젝트161소스는 수락된 main과 같고, 복사본 project.godot에만 기존
iOS 세로390×844/터치/모바일 텍스처 설정을 병합했다. 버전은 생성 프로젝트의
Xcode 빌드 설정으로 지정했으며 게임 소스와 전역 개발 도구 선택은 그대로다.
실제 내보낸 PCK25확인·실패0·종료0·엔진 오류0으로 설정·개발 파일 제외·세 방향·
효과음8개·스키마13을 확인했다. 실제 팀 서명 빌드와 엄격 서명, 프로필의 기기/
팀/앱 일치·유효기간, 불필요한 푸시/Game Center 권한 없음, 내장 PCK 일치를 확인했다.
설치한14파일 앱은 비공개 영구 폴더에 바이트 일치 보존하고 서명도 다시 검사했다.

현재 개발용 프로필의 만료는 **2026-10-27 14:45:57 UTC(한국23:45:57)**다.
만료 후 실행하려면 같은 개발 앱을 재서명/업데이트해야 한다. 스토어 배포판이 아니다.
기존 템플릿 경고6개(미사용 카메라/사진/마이크 설명의 빈 값3개,
pragma once2개, AppIntents 미사용1개)는 남아 있다. 경고0을 주장하지 않는다.

로컬 검증기의 첫 메타데이터 확인은 일반적인 Xcode 변수 치환을 리터럴로 예상해
중단됐다. 참조된 실제 번들 빌드 설정을 검사하도록 바로잡았고 소스는 변경하지 않았다.
첫 실행 명령도 앱 인수 뒤 옵션을 넣어 로컬 파서에서 종료64로 거부됐다.
문서화된 인수 순서로 고친 새 명령은 실제 기기 실행 JSONsuccess/종료0이다.
기기 인증 오류나 재로그인으로 분류하지 않는다.

이 설치 작업에서는 최신 실제 화면 캡처·손가락 입력·청취·한글 키보드·중단 복귀·
발열/성능을 새로 수락하지 않았다. 예전 스크롤에 대한 사용자의 직접 확인은 아래
이력으로 유지하며 최신 전체 조작의 일괄 수락으로 확대하지 않는다. Claude 호출은0회다.

## 실제 기기 연결 후 상태

실제 기기는 iPhone15Pro/iPhone16,1, iOS26.6.2다. USB 페어링·연결과 개발자 모드 활성화를 확인했다. 푸시 옵션의 빈 문자열이 의도와 달리 APNS 권한을 생성해 첫 서명은 실패했다. Godot의 정확한 `Disabled` 값으로 수정하고 실제 권한 파일 검사와 회귀2개를 추가했다(전체 도구31시험/실패0). 새 내보내기/실제 팀 서명 빌드/엄격 서명/기기·팀·앱 프로필 일치와 설치가 통과했다. [기기 검증 계약](../../tasks/ios-device-validation-v1.md), [선별 증거](../../evidence/ios-device-validation-v1.json).

2026-10-21 사용자가 기기의 개발자 앱 신뢰를 완료한 뒤 실제 실행이 종료0/JSONsuccess로 통과했고 Xcode 기기 캡처에서 게임·연구 화면을 확인했습니다. 이후 사용자는 손가락 스크롤이 매우 불편하고 스크롤바 대신 화면 어디서나 밀 수 있어야 한다고 지적했습니다. 실행·캡처 성공을 조작감 수용으로 간주하지 않습니다. 아래 터치 수정 기록이 현재 상태입니다.

아래 기록은 PR13에서 완료한 최초 미서명 준비 단계의 결과다. 그때의 기기0대/미설치 상태는 이 연결 후 결과로 갱신한다. 기존 Mac 게임·실제 저장은 그대로다.

## 손가락 스크롤 수정 (2026-10-21)

버튼·카드의 기본 STOP 필터가 터치 이동을 부모 ScrollContainer에 보내지 않았고, 드래그 허용 거리0은 작은 손 떨림도 스크롤로 판단했습니다. 카드와 일반/재료 버튼을 PASS로, 장식 그림·별점을 IGNORE로 바꾸고 허용 거리를10논리 픽셀로 설정했습니다. 드래그가 시작되면 엔진의 SCROLL_BEGIN이 대기 중 버튼 클릭을 취소합니다. LineEdit는 PASS여도 눌림을 소비하므로 이름 입력란에만 세로 드래그 전달을 추가했습니다. 일반 내용의 관성·휠은 엔진이 처리하고, 이름 입력란에서 시작한 드래그는 별도 관성 없이 이동합니다.

`touch_scroll_tests.gd`는 실제 Viewport 입력과 ScreenTouch/ScreenDrag→마우스 변환으로 두 화면 크기를 검사합니다. 카드·문자·그림·활성/비활성 버튼·재료 토글·이름 입력란에서 시작하는 스와이프, 역방향, 드래그 클릭 취소,2픽셀 떨림의 한 번 탭, 이름 탭/문자 입력, 관성 중지·데스크톱 휠을 포함합니다. 같은66확인에서 원본은32실패/종료1, 수정본은실패0/종료0/엔진 오류0입니다. 기존 도메인125시험/58,220확인과 전체 두 크기 배치17,758확인도 실패0/종료0/엔진 오류0입니다. 입력 위치를 보내서 결과를 검사하며, 테스트의 준비 단계 외에 스크롤 위치 변경이나 pressed 신호를 손가락 입력의 증거로 쓰지 않습니다.

새 iOS 내보내기99소스 중 기존95개에서 UI main.gd만 바뀌고 나머지94개는 동일합니다. 추가4개는 입력란 헬퍼·회귀 시험과 UID입니다. 복사본 설정을 제외한 내보내기 해시를 검사했고 실제 팀 서명 빌드·엄격 서명·프로필/기기/팀/앱 일치·APNS 없음·앱 PCK와 내보낸 PCK 일치가 통과했습니다. 같은 번들 앱으로 삭제 없이 교체·실행했고, 직전 백업한 저장과 `.bak`는 교체 직후 모두 바이트 일치했습니다. 실제1179×2556 기기 화면에서 수정본의 실행 화면도 확인했습니다.

**사용자 실기기 확인:** 수정본에서 “화면 어디서 밀어도 스크롤되고 탭도 정상”이라는 직접 답변을 받았습니다. 화면 전체 스와이프와 정상 탭은 사용자 확인을 완료했습니다. **남은 확인:** iOS 가상 키보드/한글 조합, 백그라운드·중단 복귀. 자동 시험과 캡처 또는 이번 스와이프 확인으로 이 별도 항목을 통과 처리하지 않습니다. 기존 Mac 앱·PCK·실제 저장은 변경하지 않았습니다. [터치 계약](../../tasks/ios-touch-scroll-v1.md), [선별 증거](../../evidence/ios-touch-scroll-v1.json).

재현은 격리 프로젝트와 새 절대 저장 경로를 사용합니다.

```sh
Godot --headless --path /absolute/isolated/project \
  --script res://tests/touch_scroll_tests.gd -- \
  --layout-only --qa-out=/absolute/fresh/touch-results
```

## 최초 준비 기록

2026-10-20. 사용자가 iOS 준비를 승인했고 첫 후보는 iPhone15Pro다. 실제 기종과 iOS 버전은 아직 확인하지 않았다. **공식 Xcode·계정·실제 팀 연결, iOS 프로젝트 내보내기와 서명 없는 iPhone arm64 빌드가 통과했다. 실제 서명·설치·기기 검증은 연결할 iPhone이 없어 아직 하지 않았다.** [계약](../../tasks/ios-device-preparation-v1.md), [선별 증거](../../evidence/ios-device-preparation-v1.json).

## 확인한 상태

| 항목 | 실제 결과 |
| --- | --- |
| Mac | macOS26.5.2, arm64. 최초 확인 여유193GiB |
| 현재 개발 도구 | 별도 `/Applications/Xcode-26.6.app` 설치. `DEVELOPER_DIR`를 지정한 버전 명령은 Xcode26.6/17F113, 종료0. 전역 선택은 기존 CommandLineTools 유지 |
| App Store 설치 | 공식 Xcode가 macOS26.6 이상을 요구해 설치 거부. OS는 변경하지 않음 |
| 호환 경로 | 공식 Apple Silicon XIP 수신 완료, Apple 패키지 서명/압축 해제 확인. 설치 앱의 엄격 서명과 Gatekeeper 모두 통과 |
| 설치 메타데이터 | 첫 엄격 서명은 복사본 루트의 FinderInfo 때문에 실패. 해당 표시 정보만 별도 보존 후 제거했고 다른 루트 속성은 동일. 최종 엄격 서명 종료0, 보안 속성·코드 서명 변경 없음 |
| SDK·첫 실행 | 사용자 약관 동의와 필수 구성 요소 설치 후 첫 실행 검사/SDK26.5 조회/SDK 목록 모두 종료0. SDK 조회 통과만으로 기기 빌드가 준비됐다는 뜻은 아님 |
| iOS 플랫폼 | 첫 빌드 종료70은 플랫폼 설치 후 해결. 공식 iOS26.5.1 + iOS26.5 Simulator 설치 완료, runtime inventory 종료0/사용 가능. 게임의 시뮬레이터 실행 검증은 별도 미완료 |
| Godot | 공식4.7.2 표준 내보내기 TPZ의 SHA256와 별도 공식 SHA512 모두 일치. iOS ZIP202,976,946바이트/76항목, 디버그·릴리스에 실제 iOS arm64 라이브러리 있음 |
| 준비용 프로젝트 | 원본95개 소스 보존. 복사본94개는 원본과 같고 복사본 project.godot만 iOS 설정을 병합. import/export와 엄격 엔진 서명 전후 종료0/오류0 |
| 화면 설정 | 세로,390×844 논리 기준, canvas_items/expand, 터치→마우스 입력. iPhone15Pro의 실제 화면/DPI/안전 영역을 검증했다는 뜻은 아님 |
| 내보내기 설정 | iPhone/arm64 전용, 임시 최소iOS17.0, 개발용 bundle ID, Xcode 프로젝트만 내보내기. 출시 지원 범위 확정이 아님 |
| 계정·Xcode 프로젝트 | 사용자 Xcode 로그인 완료, 실제 Personal Team을 로컬 환경에만 전달. 프로젝트 내보내기/스킴 조회 종료0. 계정·팀 값은 Git에 넣지 않음 |
| 실제 빌드 | 두 번째 서명 없는 generic iOS 빌드 종료0/BUILD SUCCEEDED. 실제 arm64 실행 파일·최소iOS17·iPhone 전용·세로 방향·내장 PCK 해시 일치 확인. codesign은 실제 미서명 상태 확인 |
| 내보낸 내용 검사 | 실제 iOS PCK에서 설정/개발 파일 제외13확인·실패0·종료0. 임시 불투명 라멘 아이콘1024PNG 확인; 출시 아트가 아님 |
| 실제 기기 | devicectl 목록 조회 종료0, 연결된 기기0대. 사용자 연결/신뢰 요청, 모델/iOS/개발자 모드/설치/수명 주기 시험은 미완료 |
| 사용자 저장 | 읽거나 설치 시험하지 않음. 기존 Mac 앱/PCK/게임 소스 보존 |

## 재현 가능한 준비 도구

`game/tools/prepare_ios.py`는 원본 프로젝트/엔진/전역 Godot 설정을 편집하지 않는다. 새 출력 폴더에 엔진·허용 소스·검증된 템플릿을 복사한다. 템플릿은 복사 엔진의 포터블 `runtime/editor_data/export_templates/4.7.2.stable/ios.zip`에만 설치한다. staging의 `override.cfg`, `export_presets.cfg`, 임시 아이콘을 생성하고 Godot ConfigFile로 iOS 설정을 **복사본 project.godot에만** 병합한다. 편집기 내보내기는 runtime override를 읽지 않으므로 이 병합이 필요하다. ETC2/ASTC 모바일 텍스처 임포트도 복사본에만 켠다. 원본95개와 복사본94개, 의도적으로 달라진 복사본 설정의 별도 해시를 임포트/내보내기 후 확인한다. 도구/문서/QA 스크립트는 내보내기에서 제외한다.

다음은 Codex가 실행하는 재현 예다. 세 입력 경로는 실제 설치 위치에 맞춰 전달하고, 출력은 아직 없는 새 폴더여야 한다. Documents에 복사한 엔진은 동기화 메타데이터 때문에 엄격 서명이 실패한 이력이 있어 준비 출력은 `/private/tmp`를 사용한다. 배포 파일은 Git에 넣지 않는다.

```sh
python3 game/tools/prepare_ios.py \
  --godot /absolute/vendor/Godot.app/Contents/MacOS/Godot \
  --project /absolute/repository/game \
  --ios-template /absolute/verified/ios.zip \
  --output-dir /private/tmp/ramen-ios-preparation-new
```

기본 실행의 성공 상태는 `staged_not_exported`이며 설치 가능한 앱이 아니다. 보고서 `preparation.json`은 빌드/서명/기기 검증을 각각false로 기록한다. 기존 출력·잘못된 템플릿/링크·프로젝트와 겹치는 경로는 거부한다. 실패하면 출력 안의 로그와 `FAILED.txt`를 보존한다. 엔진은 종료0이어도 스크립트/엔진 오류가 있으면 성공으로 처리하지 않는다.

Xcode 계정에서 실제 Team ID를 확인한 뒤 로컬 환경 변수 `RAMEN_IOS_TEAM_ID`로 명시하고 **새 출력 경로**와 `--export-project`를 주면 Xcode 프로젝트 생성 단계까지 시도한다. Team ID·서명키·프로비저닝·실제 계정 정보는 저장소에 넣지 않는다. 팀을 추측하거나 가짜 값으로 내보내기를 통과시키지 않는다. 이 옵션도 `.ipa`를 빌드/서명하거나 연결 기기에 설치하지 않는다.

플랫폼 설치 후 Codex가 실행하는 서명 없는 기기 빌드 예시는 다음과 같다. `stage`와 `derived-data-new`는 실제 생성 위치/새 출력 위치로 지정한다. 이 명령에는 자동 프로비저닝·계정 변경·기기 설치가 없다. 종료0과 `BUILD SUCCEEDED` 및 실제 arm64 산출물을 함께 확인해야 컴파일 성공으로 기록한다.

```sh
DEVELOPER_DIR=/Applications/Xcode-26.6.app/Contents/Developer \
  xcodebuild -project /absolute/stage/xcode/RamenAtelier.xcodeproj \
  -scheme RamenAtelier -configuration Debug -sdk iphoneos \
  -destination 'generic/platform=iOS' \
  -derivedDataPath /absolute/stage/derived-data-new \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO build
```

## 남은 진행 순서

1. Apple 로그인·공식 XIP 수신·설치·앱 신뢰 검증은 완료됐다. 앞선 자동 다운로드 시간 초과 두 건은 이력으로 보존한다. `xip` 출력 자체는 인증서 검증을 시도하지 않았다고 표시했으므로 별도 `pkgutil`의 Apple 서명, 설치 앱의 엄격 `codesign`, Gatekeeper 통과를 근거로 사용한다. 비밀번호/인증번호/브라우저 쿠키는 읽지 않았다.
2. 사용자가 실제 Xcode 약관 동의를 완료했고 필수 시스템 구성 요소를 설치했다. 이후 실제 빌드의 플랫폼 부족 오류에 따라 필요한 iOS 플랫폼/시뮬레이터 묶음을 설치했다. 다른 플랫폼·코드 완성 모델·OS 업데이트·보안 우회·자동 약관 동의는 하지 않았다.
3. 동의 후 첫 실행 검사/SDK26.5 조회/SDK 목록을 실제 명령으로 확인해 모두 종료0이다. 도구 경로는 빌드별 `DEVELOPER_DIR=/Applications/Xcode-26.6.app/Contents/Developer`로 지정하고 기존 전역 선택은 보존한다.
4. 사용자 Xcode 로그인과 Personal Team 확인을 마쳤다. Xcode가 생성한 격리 임시 프로젝트에서 실제 팀 값을 로컬 환경에만 전달해 게임 프로젝트를 생성했다. 웹 로그인·Xcode 계정·개인 무료 시험·유료 배포는 구분한다. 플랫폼 설치 후 `RamenAtelier` 스킴의 서명 없는 기기 빌드 종료0과 실제 산출물을 검증했다. 실제 서명/프로비저닝은 기기 연결 후 진행한다.
5. iPhone을 연결하고 실제 기종/iOS를 확인한다. 사용자가 기기의 신뢰/개발자 모드/암호 입력을 완료한 뒤 설치한다. iPhone이 Xcode/SDK와 호환되는지도 실제 연결 결과로 확인한다.
6. 터치·스크롤·한글 키보드·노치/하단 안전 영역, 채집→시식→판매, 저장/종료/재시작, 백그라운드/잠금 복귀, 대기/발열/성능을 별도 기록한다. 현재 미완료 영업은 영업 전으로 돌아가는 정책이며 iOS 중단/복귀 검증 전 보존을 약속하지 않는다.

현재 전체 도구29시험(새 iOS9개)과 실제 내보낸 PCK13확인이 통과했다. 초기12개 runtime 설정 검사만으로 편집기 설정 적용을 판단할 수 없었고 이를 실제 내보내기로 바로잡았다. 실패한 내보내기1~4와 첫 빌드 결과를 보존하고 두 번째 빌드 성공을 별도로 기록한다. 생성한 템플릿의 pragma once, 사용하지 않는 카메라/사진/마이크 설명의 빈 문자열, AppIntents 미사용 경고가 남아 있으며 배포 전 정리 대상이다. 성공은 경고0을 뜻하지 않는다. `/private/tmp/ramen-ios-export-20261020-v5`의 프로젝트에서 빌드했고, 미서명 앱12파일을 `outputs/ramen-ios-device-build-v1/RamenAtelier.app`에 바이트 일치로 보존했다. Mac용 실행 앱이나 바로 설치 가능한 서명 앱은 아니다. `/private/tmp` 준비물은 임시이므로 재시작 후에는 도구로 새 폴더에 다시 준비한다. 공식 템플릿 원본과 선별 로그는 작업 공간 `work/tools/godot-ios-4.7.2-v1` 및 `work/ios-*`에 보존한다.

## 공식 근거

- [Apple Xcode 호환표](https://developer.apple.com/xcode/system-requirements): 현재 OS에 맞는 Xcode 선택 기준.
- [Apple 개인 개발 팀](https://developer.apple.com/help/account/basics/about-your-developer-account): 개인 기기 무료 시험과7일 프로비저닝 제한.
- [Godot iOS 내보내기](https://docs.godotengine.org/en/4.7/tutorials/export/exporting_for_ios.html): macOS/Xcode/템플릿/팀·bundle ID 요구.
- [Godot4.7 iOS 내보내기 설정](https://docs.godotengine.org/en/4.7/classes/class_editorexportplatformios.html): project-only와 플랫폼 옵션.
- [공식4.7.2 배포](https://github.com/godotengine/godot-builds/releases/tag/4.7.2-stable): 템플릿과 SHA512-SUMS 출처.
