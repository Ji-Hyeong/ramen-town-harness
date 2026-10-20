# iPhone 실기기 준비 v1

2026-10-20. 사용자가 iOS 준비를 승인했고 첫 후보는 iPhone15Pro다. 실제 기종과 iOS 버전은 아직 확인하지 않았다. **공식 템플릿·작업용 복사본 준비까지 통과했으며 iOS 앱 빌드/서명/설치/실기기 검증은 아직 하지 않았다.** [계약](../../tasks/ios-device-preparation-v1.md), [선별 증거](../../evidence/ios-device-preparation-v1.json).

## 확인한 상태

| 항목 | 실제 결과 |
| --- | --- |
| Mac | macOS26.5.2, arm64. 최초 확인 여유193GiB |
| 현재 개발 도구 | 별도 `/Applications/Xcode-26.6.app` 설치. `DEVELOPER_DIR`를 지정한 버전 명령은 Xcode26.6/17F113, 종료0. 전역 선택은 기존 CommandLineTools 유지 |
| App Store 설치 | 공식 Xcode가 macOS26.6 이상을 요구해 설치 거부. OS는 변경하지 않음 |
| 호환 경로 | 공식 Apple Silicon XIP 수신 완료, Apple 패키지 서명/압축 해제 확인. 설치 앱의 엄격 서명과 Gatekeeper 모두 통과 |
| 설치 메타데이터 | 첫 엄격 서명은 복사본 루트의 FinderInfo 때문에 실패. 해당 표시 정보만 별도 보존 후 제거했고 다른 루트 속성은 동일. 최종 엄격 서명 종료0, 보안 속성·코드 서명 변경 없음 |
| SDK·첫 실행 | iOS26.5 기기/시뮬레이터 SDK 파일 존재. 실제 SDK 명령/첫 실행 검사 종료69: 라이선스 미동의. CUA로 연 약관 화면에서 사용자 동의 대기. 시뮬레이터 런타임은 확인하지 않음 |
| Godot | 공식4.7.2 표준 내보내기 TPZ의 SHA256와 별도 공식 SHA512 모두 일치. iOS ZIP202,976,946바이트/76항목, 디버그·릴리스에 실제 iOS arm64 라이브러리 있음 |
| 준비용 프로젝트 | 원본95개 소스를 복사하고 별도 override/preset 생성. 엄격 서명된 복사 엔진으로 실제 import 성공/오류0 |
| 화면 설정 | 세로,390×844 논리 기준, canvas_items/expand, 터치→마우스 입력. iPhone15Pro의 실제 화면/DPI/안전 영역을 검증했다는 뜻은 아님 |
| 내보내기 설정 | iPhone/arm64 전용, 임시 최소iOS17.0, 개발용 bundle ID, Xcode 프로젝트만 내보내기. 출시 지원 범위 확정이 아님 |
| 서명·Xcode 프로젝트 | 실제 Team ID를 얻지 않아 비워둠. Godot는 프로젝트 생성에도 이 값이 필요하므로 아직 내보내지 않음 |
| 사용자 저장 | 읽거나 설치 시험하지 않음. 기존 Mac 앱/PCK/게임 소스 보존 |

## 재현 가능한 준비 도구

`game/tools/prepare_ios.py`는 원본 프로젝트/엔진/전역 Godot 설정을 편집하지 않는다. 새 출력 폴더에만 엔진·허용 소스·검증된 템플릿을 복사하고, staging의 `override.cfg`와 `export_presets.cfg`를 만든다. 파일 도구/문서/QA 스크립트는 iOS 내보내기에서 제외한다. 원본95개 파일의 해시는 임포트 전후와 검증한 Mac 소스에 맞춰 확인한다.

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

## 남은 진행 순서

1. Apple 로그인·공식 XIP 수신·설치·앱 신뢰 검증은 완료됐다. 앞선 자동 다운로드 시간 초과 두 건은 이력으로 보존한다. `xip` 출력 자체는 인증서 검증을 시도하지 않았다고 표시했으므로 별도 `pkgutil`의 Apple 서명, 설치 앱의 엄격 `codesign`, Gatekeeper 통과를 근거로 사용한다. 비밀번호/인증번호/브라우저 쿠키는 읽지 않았다.
2. 현재 열린 `Xcode and Apple SDKs Agreement`를 사용자가 검토·동의하고 관리자 인증이 나타나면 직접 완료한다. 법적 약관의 최종 동의는 화면 제어 규칙상 실행 시점 확인이 필요하며 자동 동의하지 않는다. OS 업데이트·보안 우회는 하지 않는다.
3. 동의 후 SDK 버전과 첫 실행 준비 상태를 실제 명령으로 다시 확인하고 필요한 구성 요소만 준비한다. 도구 경로는 빌드별 `DEVELOPER_DIR=/Applications/Xcode-26.6.app/Contents/Developer`로 지정하고 기존 전역 선택은 보존한다.
4. Xcode에서 Apple 계정과 실제 서명 팀을 확인한다. 고유 bundle ID/자동 서명으로 프로젝트를 생성하고 먼저 서명 없는 기기 빌드를 검증한다. 무료 Personal Team/유료 배포는 구분한다.
5. iPhone을 연결하고 실제 기종/iOS를 확인한다. 사용자가 기기의 신뢰/개발자 모드/암호 입력을 완료한 뒤 설치한다. iPhone이 Xcode/SDK와 호환되는지도 실제 연결 결과로 확인한다.
6. 터치·스크롤·한글 키보드·노치/하단 안전 영역, 채집→시식→판매, 저장/종료/재시작, 백그라운드/잠금 복귀, 대기/발열/성능을 별도 기록한다. 현재 미완료 영업은 영업 전으로 돌아가는 정책이며 iOS 중단/복귀 검증 전 보존을 약속하지 않는다.

Mac에서 한12개 설정 검사와9개 도구 안전성 시험은 iOS 빌드 또는 실제 기기 통과를 대체하지 않는다. 계정·기기 없이 끝낼 수 있는 준비와 이후 작업을 분리한다. `/private/tmp` 준비물은 임시이므로 재시작 후에는 이 도구로 새 폴더에 다시 준비하고 보고서를 재확인한다. 공식 템플릿 원본과 선별 로그는 작업 공간 `work/tools/godot-ios-4.7.2-v1` 및 `work/ios-preparation-*`에 보존한다.

## 공식 근거

- [Apple Xcode 호환표](https://developer.apple.com/xcode/system-requirements): 현재 OS에 맞는 Xcode 선택 기준.
- [Apple 개인 개발 팀](https://developer.apple.com/help/account/basics/about-your-developer-account): 개인 기기 무료 시험과7일 프로비저닝 제한.
- [Godot iOS 내보내기](https://docs.godotengine.org/en/4.7/tutorials/export/exporting_for_ios.html): macOS/Xcode/템플릿/팀·bundle ID 요구.
- [Godot4.7 iOS 내보내기 설정](https://docs.godotengine.org/en/4.7/classes/class_editorexportplatformios.html): project-only와 플랫폼 옵션.
- [공식4.7.2 배포](https://github.com/godotengine/godot-builds/releases/tag/4.7.2-stable): 템플릿과 SHA512-SUMS 출처.
