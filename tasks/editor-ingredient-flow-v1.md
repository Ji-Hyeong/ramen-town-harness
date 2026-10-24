# TASK
Improve the native ingredient-detail/selection journey while preserving the
selected option3 editor composition accepted for continued work after PR26.

## CONTEXT
Current main ac467b8. Fresh same-source native baseline captures the editor,
ingredient detail and long broth/oil selector before implementation. The item
detail has no action; broth/tare/oil/process share a long scroll. A full topping
dock disables list-add without a visible path to choose a replacement.

## REQUIREMENTS
- Use the existing navy/cream/teal/gold native frames, original food art and fonts.
- Add a fixed actionable ingredient-detail footer. Browsing is read-only. Apply
  through the existing guarded controller only; no implicit payment/save/trip.
- At capacity, offer an explicit choice of which actual topping to replace, with
  cancel/back preserving the draft and current category/scroll/selection.
- Broth selection uses fixed 육수/타레/향미유/공법 tabs; noodle selection uses
  면/익힘/반죽 tabs. Retain each tab's own scroll and actual selected markers.
- Preserve details-return context and reachable44px+ touch targets. Committed
  changes keep existing click/food feedback; canceled drags do not apply changes.
- Keep the initial chosen-mock composition and primary editor actions intact.

## CONSTRAINTS
Codex only; no Claude calls, phone work, domain/services/controller/schema/balance
changes, ordinary saves, new art generation or unrelated journey stash restore.
Preserve the old Documents copies and unfinished stash. No destructive Git.

## EDITABLE PATHS
game/scripts/ui/bowl_workbench.gd; game/tests/bowl_editor_qa.gd and dedicated
ingredient-flow QA fixture; related AGENTS/task/readme/design-QA/native docs and
fresh selected source/current/before-after evidence. No first-screen asset edits.

## ACCEPTANCE CRITERIA
Real native pointer flow opens details, applies/adds/replaces only on a deliberate
action, preserves draft on canceled/read-only paths, and returns to the right
category/tab/scroll. Selected markers match accepted state. Full-capacity choice
replaces exactly one portion. Current initial/editor/result/failed-save and
shorter390x750 flows remain usable. Fresh actual native captures compare both
sizes, selected first-screen source and new detail states, with honest manual scope.

## VERIFICATION
Review exact commands and fixture before execution. Isolated fresh absolute paths.

```sh
"$GODOT" --headless --path game --script res://tests/bowl_editor_qa.gd -- --qa-out="$ABS_FRESH_OUT" --layout-only
python3 game/tools/build_qa_app.py --godot "$GODOT" --project "$ABS_PROJECT_GAME" --output-dir "$ABS_FRESH_APP_OUT" --fixture bowl-editor
```

Run dedicated flow and compact fixtures from the same frozen pack, then native
launcher by the established human-authorized terminal QA method. Review actual
screens, source/PCK equality, engine errors, exit status and strict official-engine
signature. Publish ready PR and expected-head squash merge under standing consent.

## Final result
`tests/ingredient_flow_qa.gd` is the dedicated actual-pointer fixture. Run it with
the same frozen `--main-pack` as the editor fixture; `--layout-only --flow-compact`
is its explicit390x750 layout variant. Current v7 native flow567/0/exit0 and editor
regression524/0/exit0 (18+30PNGs), engine errors0. Same packed compact flow261/0
and editor219/0. Live open-sheet narrowing and real nonzero tab-scroll restoration
are included; targeted pre-fix500/2 reproduced offscreen desktop-created actions.

277 source files match; exported/embedded PCK
2c0b06b227f8b7f667f3d572aa144c63e8b36ddcaf9e112fd2b2a76421e3c8f8 and
post-run strict vendor signature0 verified.14 new and8 regression originals plus
5 composed source/current/before-after views opened; exact boundaries and hashes
in game/docs/uiux-reset/ingredient-flow-v1/review.json. Raw baseline/flow/regression
directories preserved privately byte-equal (10/22/42files). No phone/Claude/normal
save/domain changes, first-screen assets/fonts preserved. Standing-authorized
ready PR and verified-head squash merge follow final documentation review.
