# Focused development cycle V1

## TASK
Improve the existing food-centered ramen development cycle after the2026-10-27 evidence-based reference audit. The human authorized continuing the proposed work. Preserve the selected native cream/navy/teal/gold design and game mechanics; this is not a new app or visual direction.

## CONTEXT
Latest main11dc898 supports genuine raw broth/noodle manufacture, repeated toppings, recipe knowledge18 and actual tasting/sales. The audit found that making a noodle feels like filling a form across four selection depths; creation/completion/next action are fragmented. Existing selected bowl composition is the strongest screen and stays. Private audit: /Users/ji/Documents/Codex/2026-10-13/referenced-chatgpt-conversation-this-is-an/outputs/ramen-reference-audit-20261027/report.md. Do not read the entire history or huge AGENTS history; its current role rules and this contract suffice.

## REQUIREMENTS
Claude owns substantial actual noodle UI implementation:
- Replace the four field-to-subpage navigation in the normal noodle formula screen with directly visible, compact option cards for flour/water/cut/method on that same sheet. A player can select a formula without opening/backing out of four option pages. Use readable short captions and icons/real existing food textures; retain detailed traits/rank/source explanations behind an explicit optional disclosure. Do not move all prose into permanently visible rows or shrink fonts to fit.
- Keep a visible current noodle food preview and short accurate cost/time/texture facts while editing. Use existing original food textures for the ready formula; the existing NoodleView depicts only active knead/roll/cut work. Do not invent handmade replacement drawings, new palette or generated assets. Food texture choice may use the existing base_id; no fabricated recipe-specific art.
- Stable actual choice node names: NoodleChoose_<id> (all current option IDs are unique across fields). Each choice is a genuine Button with >=44px targets, clear exclusive selection, disabled rank/source/busy state, action feedback through existing global hooks, and scrolling from any choice cancels activation. Selection goes only through `_emit("noodle_set", {"field":field,"id":id})`. No domain state mutation in UI.
- Preserve current controller rebuild semantics. Keep formula scroll position through a successful choice/rebuild; no jump to top after every tap. Header and paid primary action remain fixed, outside the scroll. At390x844,390x750,1280x800 all content must remain reachable without horizontal clipping.
- Known min-rank/source requirements remain visible/reachable, including locked mountain buckwheat and rank2 rested dough. Negative aroma remains shown accurately. No spoilers for unknown full-ramen compatibility/customer scores. No automatic production/apply/knowledge/sample charge.
- Existing direct `_show_noodle_workshop(field)` entry points from ingredient/source navigation may highlight/scroll to that actual visible field, not change any selection or create a hidden compatibility facade. Library/cooking controls, explicit apply, cancel, real elapsed work, save-failure warning and retry remain intact.
- Update actual current noodle QA to operate the new visible controls, verify within-sheet choices with the current preview, preserve failed/locked/scroll/cancel/paid completion/save paths. Do not keep obsolete hidden old controls solely to satisfy tests. Comments explain non-obvious input/rebuild invariants. Do not claim unrun tests passed.

Codex owns after Claude completes:
- Integrate a concise visible development-stage cue and guarded next-stage navigation from applied broth/noodle back to the real bowl; never auto-start work, auto-select a recipe, spend money or replace a bowl by browsing.
- Make the immediate tasting response/next experiment readable in the existing result area, reusing actual evaluator data without revealing unknown counterfactuals or adding scores/rewards.
- Adapt adjacent tests, new focused cycle checks, independently review and verify every changed file; actual native before/current screenshots. Preserve game rules/schema/balance and normal player saves/iPhone.

## CONSTRAINTS
Claude may edit ONLY game/scripts/ui/bowl_workbench.gd (the `_show_noodle_workshop`, `_show_noodle_source`, `update_noodle_progress` implementation and directly supporting new noodle-only helpers/fields/preloads), game/scripts/ui/noodle_formula_choices.gd (new optional helper), and game/tests/noodle_workshop_qa.gd. Do not edit other methods or unrelated files, instructions, docs, tools, assets, controller, domain, schema or old evidence. No Bash/network/Git/credentials/global settings/subagents. File-only Read/Edit/Write/Glob/Grep, restricted/dontAsk. Codex will not edit repository files concurrently. Do not commit/push/deploy. Report exact changed files and tests NOT RUN.

## ACCEPTANCE CRITERIA
Real visible flour/water/cut/method changes happen on one stable formula sheet. Food preview and actual numeric facts follow selected state; scroll, locked choices and work/cancel/save behavior remain correct. New-user flow remains raw-broth+raw-noodle required. Explicit bowl apply learns knowledge only per existing rules. Actual source/pack/native proof must precede ready publication; not a claim of reference-level fun or phone acceptance.

## VERIFICATION
File-only Claude returns a compact handoff. Codex independently imports/parses with the official Godot4.7.2 engine, runs current noodle/domain/recipe-knowledge/component regression and risk-appropriate historical suites, meaningful visible pointer/drag/cycle/safe-save cases,390x750 layout and390x844/1280x800 actual native captures. New snapshots use game/tools/build_qa_app.py with strict official-engine signature validation. Preserve raw failed logs. Standing ready PR/verified-head squash/local main sync applies after acceptance. No live player save or iPhone installation.

## IMPLEMENTATION HANDOFF
Claude's file-only initial implementation and targeted correction both returned success/exit0, is_error=false and no permission denials. Reported turns were34 and14 against requested limits30 and10; these are observed response fields, not claims that the requested limit was enforced or a subscription quota ratio. The helper and noodle QA remain byte-identical to the accepted handoff. Codex subsequently adjusts workbench geometry/selection contrast alongside its completion/tasting integration.

Native review rejects duplicate floating completion text crossing the new sheet title; retain the particle effect and the truthful fixed title. Existing editor/payoff QA must return from the newly opened contextual selector before touching a control behind it. Preserve failed diagnostics; do not weaken transaction, discovery or sample assertions to obtain a pass. Final acceptance details: evidence/development-cycle-v1.json and game/docs/DEVELOPMENT_CYCLE_V1.md.

## ACCEPTED RESULT
Completed2026-10-28. Seven accepted native flows3736checks/0failures/208PNG, actual supported-app cycle280/0/24PNG, all accepted exits0/engine0. Touch49/0(layout), builder23/0; unchanged-domain regressions retained. The two frozen packages have identical application bytes and differ only in the corrected ingredient-payoff fixture; rejected earlier results stay explicit. Current365sources match v7. Strict official-engine post-run signatures pass. Public18 originals and7 regression originals reviewed. Private exact evidence: outputs/ramen-development-cycle-v1/final-v6 and final-v7. Delivery follows the standing ready-PR/matching-head squash/local-main-sync authorization; actual publication is recorded privately after success. No iPhone/live save work.
