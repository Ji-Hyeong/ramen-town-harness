# TASK
Make a paid tasting explicitly report the selected culinary goal rather than
whichever matching direction happens to occur first in the catalog.

## CONTEXT
Start clean main a02289d (merged PR46),409runtime files/schema18. Actual new
citrus_scallop and sesame_buckwheat tastings satisfy older directions as well;
the current result badge shows citrus_clear/sesame_depth first. The chosen goal
is therefore obscured even when it is met. A result refresh key also omits the
transient direction_target. Preserve actual food/paid records/transactions/art.

## CLAUDE OWNERSHIP
Implement ONLY these two new files:
- game/scripts/ui/tasting_goal_focus.gd
- game/tests/tasting_goal_focus_tests.gd (run(callback:Callable)->void)
Codex owns existing bowl_workbench.gd integration, key invalidation, result detail,
independent runner/native QA/builder/docs/evidence/publication. Serial writers.
Do not edit other files, UIDs, domain/services, AGENTS, tasks or Git.

## REQUIREMENTS
Implement a small pure read-only projection using RecipeDirections, real retained
record config and explicit selected direction ID. Choose a clear minimal API and
report its exact keys so Codex can integrate it. Main already supplies fresh-title
metadata only for the same last_feedback_record_id; accept it as an argument.

- Selected valid goal must take priority over another matching older direction.
- Whether the goal is met comes from this actual record, never the untasted draft,
  an unrelated older matching record, a supplied fresh title alone or all-notebook
  tested status. Actual selected-goal conditions may be shown after paid tasting.
- Newly matched selected goal: concise '<title> · 목표 달성'. Previously matched
  selected goal/retained result: '<title> · 목표 충족'. Both require actual match.
- Selected goal not met: concise '<title> · 더 실험'; neutral presentation, never
  celebrate success. The view may still reveal actually achieved other directions
  in detail. Return actual selected assessment and selected-first matching results.
- No selected goal preserves old generic discovery/theme fallback in Codex view.
  Empty record is an unavailable result. Malformed nonempty config and unknown
  nonempty direction IDs need explicit errors (no fake success/fallback solution).
- Defensive result copies; never change record/arguments/catalog or create saved
  fields, goal credit/rewards/unlocks/effects/timers. No new artwork or sources.

## TESTS / ACCEPTANCE
Focused pure tests: valid selected priority when one recipe matches2directions,
three new cross-region actual evaluator witnesses, fresh vs retained match,
unmet selection despite fake fresh-title metadata, empty selection/record,
invalid selected ID/config, returned-copy independence and input immutability.
Use real existing recipe witness configs/evaluator, do not invent pass profiles.
Tests do not write files. Codex will run independently. No claim tests ran.

## CONSTRAINTS / VERIFICATION
Read/Edit/Write/Glob/Grep only, restricted/dontAsk/strict empty MCP; no Bash,
network/subagents/credentials/Git/push/deploy/outside-project reads. Report compact
changed paths/API/decisions/UNRUN tests/denials. Max-turn30 is a turn limit, not a
token budget. Initial CLI completion is not acceptance. Codex verifies selected
goal result/details, real failed-goal feedback, live same-record target changes,
actual payment/sample conservation,3viewport renders and same-state regression.
READY PR/attach/expected-head squash/main sync under standing authorization.

## ACCEPTED CLOSEOUT

2026-10-29: Claude owns new pure projection+tests; both hashes unchanged after
successful12-turn handoff. Codex owns native badge/detail/cache integration and
independent acceptance. Actual419source frozen pack
5a4c36dd8449bea2b3ccc83cb8abd9b339a4fcb19adf75fd7e30cbb972a01f16:
primary1055/0 +identity953/0 +journey449/0 =2457/0/129PNG, all exits0/engine0.
Fresh previous-main baseline141/0/10PNG and entire9-record end state equal.
Focus48/0, builder24/0, layout884/0; strict vendor signature0. Domain/services66
and125assets unchanged, schema18/no newfields. Publish8current+2before originals,
all10opened. Preserve actual earned fixture/provenance and private CLI/source/pack
archive. No phone/live saves/campaign fun claims. Standing READY PR publication
and matching-head squash/local-main synchronization follows acceptance.
