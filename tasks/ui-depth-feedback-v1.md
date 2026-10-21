# TASK
Extend current unmerged PR16 with progressive disclosure and universal action
acknowledgement. User permits deeper screens instead of cramming one page, wants
clickable details recognizable by design (not text-only links), and feedback on
every action. iPhone installation remains explicitly deferred.

## OWNERSHIP
Claude owns a reusable disclosure component, the actual journal target/map
refactor, and component tests. Codex owns main-screen integration/ingredient and
flavor depth, centralized button feedback, routed-input and integration checks.
Serial repository writers only. This is the next iteration of existing UI work,
not a separate overlapping branch or a new game system.

## CLAUDE EDITABLE PATHS
NEW game/scripts/ui/disclosure_card.gd
game/scripts/ui/recipe_journal.gd
NEW game/tests/disclosure_card_tests.gd
Do not edit main.gd/action_feedback.gd/domain/saves/docs/AGENTS/other tests/tools.
Read only relevant UI styles/current journal and focused scene/test patterns.
No Bash/Git/network/credentials/subagents. Codex independently executes tests.

## DISCLOSURE COMPONENT API
extends VBoxContainer, no class_name. Public fields:
`header_button: Button`, `body: VBoxContainer`, `expanded: bool = false`.
`configure(title: String, summary: String, icon: Texture2D = null) -> void` updates
summary without replacing header, rebuilding body, resetting expanded state or
emitting toggled. Caller sets root name before configure. Header stable name is
`str(name) + "Toggle"`; body name `str(name) + "Body"`.
`set_expanded(value: bool) -> void`; signal `toggled(expanded: bool)` only on change.
Body starts collapsed and contains caller's detail controls. Header stays visible.
Optional expanded-state restoration across parent journal present() rebuilds.

Header is a clearly raised clickable whole-card row, minimum48px: optional
ingredient/book-like icon left, title and short summary, and a DRAWN chevron at
right which points down/up with expansion. Do not rely on a Unicode glyph/font
for the affordance or a literal "상세보기" text link. Drawn chevron must remain
visible at300px width. Maintain paper/wood/vermilion/teal style and inherited font,
wrap text, explicit pressed/focus appearance. Preserve accessible button label
(use supported Godot property only; Codex can validate actual engine properties).
All decoration IGNORE and layout/card/header PASS for swipe-through.
Do not transform/move actual touch targets for a press effect. Content fade is
allowed; no animated viewport height or timers which mutate game state.

## JOURNAL REFACTOR
Preserve existing API/signals and stable data node names from current journal.
Target mode: compact title/progress/status, visible current sample/material
blocking warning and material route button when relevant. Put complete criteria,
long source/context in disclosure body, not all expanded by default. Keep
JournalOpenBook visible so the map is one deliberate tap away. Retain readable
titles; visual chevrons/icons convey which card opens details.
Map mode: eight compact numbered summary cards with status/progress; clicking a
whole chevron header expands its criteria/source and JournalSelect_<id> button.
Reuse DisclosureCard (root JournalTheme_<id>), cache expanded ids before present
rebuild, restore only known IDs. Target disclosure root JournalTargetDetails.
Keep JournalTargetTitle/JournalTargetProgress/JournalMissing/JournalSampleError/
JournalFindMaterials/JournalMapSummary and intent semantics. Merely opening
details never selects goal, starts exploration, pays or changes game state.
Sample shortage must not become hidden behind a collapsed warning.
Use short natural Korean product copy; no engineering explanations in game UI.

## ACTION FEEDBACK BOUNDARY
Do NOT implement a second particle service. Codex will bind all dynamic
BaseButtons centrally via ActionFeedback, including these headers/actions.
Your pressed/focus styles and chevron state provide immediate local acknowledgement.
set_busy must still guard intent callbacks; ensure newly rebuilt controls inherit
busy and removed nodes never call stale state. Fix direct-forced disabled header
signal toggles if necessary; real disabled buttons never emit user actions.

## TESTS
SceneTree component tests: default collapsed; configure preserves header identity,
content and expanded state; exactly one toggle signal for one real change; no
signal for same state; drawn chevron exists and has nonzero area; wrapping at
300px; PASS/IGNORE policy; journal compact map/target, expand/refresh preserved,
missing stock remains visible; busy intent rejection, stable names and no duplicate
children after repeated present. Use supplied actual domain pages/fixtures.
Tests NOT RUN by Claude; exit1 for failure and compact Korean handoff.

## CODEX ACCEPTANCE
Independently review exact files, test real pointer/native touch: detail tap opens
only detail, swipe opens nothing and emits no committed effects; dynamic journal
actions and all existing button factories have one acknowledgement; canceled
drag/disabled action no click effect. Verify2sizes and actual fresh renderer if
approved. No save/schema/economy changes or stale capture/device claims.

## CURRENT OUTCOME
Claude delivered disclosure/journal/components in one successful restricted call
(20turns/no denials); Codex integrated ingredient/process/flavor depth and universal
dynamic button acknowledgement. Component167, real-scene3150, actual packed
scene3150, original touch70 and full two-size layout18638 all pass/exit0/engine0.
Initial normal unnamed-node duplicate fixture and missing-meta engine errors were
rejected and corrected; count-label wrapping fixed with a one-line regression.
All46 domain/services files remain byte-equal; no save/economy changes. Frozen
117sources match prepared fresh QA and PCK67123e93. Exact new-app launch approval
pending; actual renderer/images/main merge are not claimed. Phone remains deferred.
