# iPhone 실기기 준비 v1

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
