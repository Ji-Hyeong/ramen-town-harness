# TASK
Continue the SAME recipe-discovery implementation: targeted corrections plus
the actual research-map/target UI component. User explicitly asks for meaningful
Claude ownership, not a tiny symbolic review. Codex integrates after handoff.

## OBSERVED CORRECTIONS
Codex independently ran recipe_discovery_tests.gd with real Godot4.7.2:
272checks/1failure/exit1, no engine/script errors. Failing label: deleting a record
removes tested status. Its retained fire_oil witness ALSO matches bone_depth.
Fix fixture to retain a genuinely non-bone recipe that still matches fire_oil,
and ADD a separate overlap regression: deleting one of two matching records
must KEEP tested status. Do not weaken production matching to satisfy this test.
Replace inaccurate `장터 재배` and `발견/재배` wording with actual existing
`새벽 장터 채집`/discovery-collection terminology. Real source names are
새벽 장터, 아침 항구, 산골 농가; do not imply a farming/cultivation system.

## UI COMPONENT API
Only add `game/scripts/ui/recipe_journal.gd`, extends VBoxContainer. Reuse existing
paper/wood/vermilion/teal visual language and inherited font. No class_name.
Signals: `target_selected(id: String)`, `book_requested`, `exploration_requested`.
Property `mode: String = "target"` (caller sets before adding; other value "map").
Method `present(pages: Array, selected_id: String, busy: bool = false,
sample_error: String = "") -> void` rebuilds/synchronizes presentation safely.
Never reads GameState/files or writes to any game state. It only renders supplied
pure pages and emits intent. No resource/network/download/Git/Bash/subagents.

### Target mode
Compact visually distinctive research note (not another generic settings form):
eyebrow `이번 실험`, selected title, actual progress bar and satisfied/total count,
short missing-criteria hints OR `조건 완성 · 시식으로 확인하세요`.
Already tested must say retained notebook match, not a lifetime unlock or reward.
Source note from page.origin; button `연구 지도` -> book_requested.
If unavailable IDs OR sample_error is nonempty, show honest need-material/sample
message and `재료 찾기` -> exploration_requested. sample_error is actual domain
refusal for current draft, NOT a new reward, point bonus, or hidden charge.
Keep text wrapping at minimum width around300px; target card should be compact.

### Map mode
Heading `라멘 연구 지도`, retained matching themes count/total and explicit note:
`보관 중인 시식 노트 기준 · 기록을 지우면 수록 표시도 바뀌어요`.
Eight numbered cards, own title/status, criteria and source, progress, and
`이번 목표로` button -> target_selected(id). Distinguish tested/ready/untried/
needs ingredients; one recipe may match multiple themes, no eight-recipe claim.
Use consistent 48px+ controls, wrap long Korean source/criteria text. Price-only
changes never shown as new discoveries; rely entirely on supplied pages.

## INPUT AND INTEGRATION CONTRACT
Buttons and panel/card containers MOUSE_FILTER_PASS; labels/progress/decoration
IGNORE. Preserve swipe-anywhere semantics. All action buttons disabled while
busy, and callbacks guard busy too (test direct signal calls). No timers/tweens
which write after freed; safely remove old children before queue_free, no duplicate
node names during a same-frame present() refresh. Parent owns data/locks.
Stable names: `JournalTargetTitle`, `JournalTargetProgress`, `JournalMissing`,
`JournalSampleError`, `JournalOpenBook`, `JournalFindMaterials`, `JournalMapSummary`,
`JournalTheme_<id>`, `JournalSelect_<id>`. Hidden optional nodes may stay hidden.
Document unexpected empty/invalid caller pages explicitly rather than pretending
all goals succeeded. No fabricated sample inventory or automatic recipe filling.

## EDITABLE PATHS
recipe_discovery.gd, recipe_discovery_tests.gd (corrections above), NEW
game/scripts/ui/recipe_journal.gd only. Do not edit main.gd, existing other source,
AGENTS/docs/tools/save fixtures. Codex owns integration and scene regressions.

## VERIFICATION / HANDOFF
File tools only; tests NOT RUN by Claude. Codex independently reruns corrected
pure tests, instantiates both component modes at1280x800 and390x844, checks
source/criteria/locks/swipe-through/target intent, and full integration.
Return compact file/API/correction summary and unrun checks. Do not paste source.
