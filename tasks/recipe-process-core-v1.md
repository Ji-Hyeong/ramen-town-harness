TASK
새 순수 공법 카탈로그와 focused 시험만 구현한다. 한국어 주석/간단한 결과 보고. 읽을 파일은 이 계약과 AGENTS.md 첫26줄, CLAUDE.md뿐이다. 기존 큰 코드/테스트/이력은 읽지 않는다.

OWNERSHIP
쓰기 허용: game/scripts/domain/recipe_process.gd, game/tests/recipe_process_core_tests.gd 두 신규 파일만. Codex가 모든 기존 파일과 통합 검증을 담당한다. 다른 파일/uid/AGENTS/Git/환경/인증/도구권한 수정 금지. file tools Read/Edit/Write/Glob/Grep only, 실행/Bash/네트워크/서브에이전트 금지.

API / DATA
recipe_process.gd extends RefCounted. 순수 데이터/계산만, 어떤 기존파일도 preload하지 않는다(의존성 순환 방지).
맛 프로필은0~10이므로 아래 작은 델타를 그대로 사용한다(100점 축이 아님).
SLOTS:Array[String]=[broth,noodle], AXES:Array[String]=[rich,salt,aroma,chew,spice].
definitions: 각 슬롯 standard/gentle/rolling 또는 standard/moist/rested 순서.
method(slot:String,id:String)->Dictionary deep copy 또는 {}. 반환키 정확히 id,name,desc,rank,cost,seconds,work_extra,axes(5축 모두정수).
broth standard: 기본 우림, rank1,cost0,seconds0,work_extra0.0,axes모두0.
broth gentle: 약불 우림,rank1,cost180,seconds8,work_extra1.0,axes rich-1/aroma2/나머지0. 섬세한 향, 진함 감소/비용과 준비시간 증가를 desc에 명시.
broth rolling: 강불 추출,rank2,cost300,seconds12,work_extra1.5,axes rich2/aroma-1/나머지0.
noodle standard: 기본 반죽,rank1,0/0/0.0/axes0.
noodle moist: 고가수 반죽,rank1,cost80,seconds-8,work_extra0.5,axes chew-2/나머지0. 빠른 조리와 부드러운 식감.
noodle rested: 저가수 숙성,rank2,cost140,seconds10,work_extra2.0,axes chew2/aroma-1/나머지0.
ids(slot:String)->Array[String] 새배열; 모르는슬롯빈배열.
error(raw:Variant)->String: 빈Dictionary는 두 standard를 뜻한다. 비어있지 않으면 정확히 broth,noodle 두 키, 각TYPE_STRING/알려진id. 누락/추가/빈문자/숫자/bool/null/array 모두오류. 순서무관. 기존전체recipe config는 이 함수에 주지 않는다(공법사전만 받음).
effects(raw:Variant={})->Dictionary: error!=empty면 {error:...}만. 유효시 {error:'',axes:5축합,cost:합,seconds:합,work_seconds:4.0+work_extra합,rank:최대rank}. 입력불변/반환사본, 결정적. work_seconds는 시식 제조 연출시간이며 영업조리seconds와 다르다.
selected(raw:Dictionary,slot:String)->String: 유효공법사전과알려진slot에서 id, 빈사전은standard. 모르는slot/무효사전은빈문자열. summary(raw:Dictionary={})->String: 유효공법은 '약불 우림 · 저가수 숙성'처럼두이름(기본도표시), 무효는error문장. 효과설명/클램프/실제레시피평가/돈/가게상태/저장은하지않는다.

TESTS
recipe_process_core_tests.gd extends SceneTree, print checks/failures, 전체끝까지후0 iff실패0. 기존게임파일preload없이 helper만읽는다.9조합의 exact독립기대값/최대등급/제조시간4~7.5(rolling+rested=7.5)/타입검증/순서결정/모든API반환사본/입력불변/기본효과0/두축장단점/유효id 정확범위. 같은effects호출로기대값만들지말것. helper~160lines,test~120lines로간결하게.

VERIFICATION
요청max-turns14, 실제관측턴/성공은Codex가별도확인. 실행권한없으므로NOT RUN으로명시. Codex가공식Godot --headless --path game --script res://tests/recipe_process_core_tests.gd 를독립실행한다. 한국어로파일/API/미실행검증만짧게보고한다.
