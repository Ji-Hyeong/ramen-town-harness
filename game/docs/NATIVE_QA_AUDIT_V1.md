# 실제 QA 결과를 빠뜨리지 않고 대조하기

2026-11-02. `tools/audit_native_qa.py`는 이미 종료된 시험 앱의 결과를 읽는 도구다.
게임·앱·엔진을 실행하지 않고, 입력 파일도 바꾸지 않는다. 실행 결과를 성공으로
받았다는 이유만으로 화면 검증을 끝냈다고 보고하지 않도록 기계적 확인을 묶었다.

검사할 앱·정확한 실행 ID·소스 커밋·검토한 패키지와 엔진의 SHA256·기대 검사 수·
화면 크기별 캡처 수·기존 저장 파일을 JSON 명세에 명시한다. 명세의 패키지/엔진
해시는 앱 내부의 바뀔 수 있는 manifest와 별도로 고정해야 한다.

도구는 다음을 확인한다.

- 실제 시작/종료와 종료0, 캡처 모드의 유일한 성공 요약, 두 엔진 로그의 오류·경고 없음.
- 동결 소스 전체가 지정한 Git 커밋과 같은지, 패키지·엔진 해시와 현재 공급자 서명.
- 각 PNG의 전체 청크 CRC·크기·화면별 수량·실행 시간 내 생성 여부.
- 명시한 각 저장 파일 전체가 기준 파일과 바이트까지 같은지.
- 경로 이탈·입력 심볼릭 링크·기존 결과 덮어쓰기를 거부하고 새 보고서만 생성.

PNG 픽셀을 해석하거나 화면의 가독성·재미·iPhone 표시를 판정하는 도구가 아니다.
성공 보고서에도 `visual_review_required: true`, `pixel_content_decoded: false`와
`iphone_or_human_fun_acceptance: false`를 남긴다. 캡처를 직접 검토하는 절차는 유지한다.

## 실제 확인 결과

단위 테스트10개를 통과했다. 종료0인 오류 로그, ANSI 색이 들어간 경고, 캡처 모드
위장·중복 요약, 미완료 실행, 오래되거나 누락·추가·손상·다른 크기의 PNG,
소스·패키지·엔진 변경, 서명 실패, 저장 차이와 경로 문제 등을 거부했다.
패키지나 엔진과 manifest를 동시에 바꿔도 별도 고정 해시와 달라 실패한다.
테스트의 가짜 앱 자료는 실제 렌더링의 증거로 쓰지 않는다.

실제 검증은 이미 승인된 보관함 v3의 실행 `20261102T101349Z-56279`를 대상으로 했다.
소스 커밋 `ad9261936f6b95d9d5e4b8ba453ef1361bcc8c2e`, 474개 소스,
2,045개 검사·실패0·종료0·엔진 오류/경고0, 세 크기의 PNG30장과 전체 저장3쌍을
확인했다. 고정 패키지/엔진 해시와 공급자 서명도 통과했다. 실제 입력517개를
실행 전후 해시로 대조해 모두 같은 바이트임을 확인했다. 앱을 재실행한 결과가
아니며, 이전에 마친30장 직접 검토의 별도 대조 근거다.

## 사용

```sh
python3 game/tools/audit_native_qa.py --spec /absolute/spec.json --report /absolute/new-report.json
python3 -m unittest discover -s game/tools -p test_audit_native_qa.py -v
```

명세 필드: `app_root`, `run_id`, `git_repo`, `source_revision`(전체40자리),
`summary_prefix`, `expected_checks`, `expected_pack_sha256`, `expected_engine_sha256`,
`profiles`(예: `{"portrait":[390,844,10]}`), `baseline_data`, `save_files`.
모든 루트와 명세·보고서 경로는 절대 경로다. 저장 경로는 각 데이터 루트 아래의
상대 경로다. 보고서는 입력 앱·저장·저장소 밖의 새 파일로 지정한다.
서명 검사는 macOS의 고정된 `codesign` 검증만 사용한다. Git과 서명 검증 외의
프로그램·셸·네트워크 호출은 없으며, 잘못된 입력은 명시적인 실패로 종료한다.

[작업 계약](../../tasks/native-qa-audit-v1.md),
[근거](../../evidence/native-qa-audit-v1.json),
[검증한 보관함](BROTH_SHELF_ARCHIVE_V1.md).
원본 명세와 전체 보고서·읽기 전후 해시는 `outputs/ramen-native-qa-audit-v1/final`에 보존한다.
