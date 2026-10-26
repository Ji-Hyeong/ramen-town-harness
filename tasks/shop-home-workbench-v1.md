# TASK
Unify the shop home with the selected option3 native workbench design.

## CONTEXT
The user approved continuing the visual/UX work after the service result. The actual pixel shop remains the main scene. No home-specific mock was selected: this is an explicit extension of the accepted cream/navy/gold assets and typography, not an exact home-image clone.

## REQUIREMENTS
- Show real day, rank, wallet, selling dish and current service/travel status with clear touch targets.
- Compact home summary, fixed development/start/speed actions and reachable operating/menu/save details. Full save warning/reset remains accessible and visibly signposted.
- Keep the shop integer scale at least2 for390x844/390x750 and4 for1280x800; no overlap with chrome.
- Reuse supplied native frames, dish layers, coin, icons and Pretendard. Use existing global press feedback; all navigation is through existing guarded handlers.
- Preserve immutable selling recipes versus an edited draft, abort confirmation, exact once-only settlement, save protection and exploration continuation.

## CONSTRAINTS
Codex only; no Claude/auth probes, iPhone, ordinary saves, new assets/fonts, domain/services/schema/balance changes, destructive Git or stash restoration. Preserve stash9d2270c and old Documents folders. Editable runtime: game/scripts/ui/main.gd and a bounded shop_home_view.gd helper; tests/docs/evidence and generated UIDs only otherwise.

## ACCEPTANCE CRITERIA
Fresh prechange and final native captures in both target viewports; compact reflow; actual pointer opening/closing/routing/guarded operations; real live status/progress and actual selling snapshots. Isolated failure/recovery must never advertise successful saving. Current editor and service-result regressions pass without engine errors. Publish precise visual-review scope and source/PCK hashes.

## VERIFICATION
Use the reviewed official Godot runtime and game/tools/build_qa_app.py --fixture bowl-editor. QA scripts inherit bowl_editor_qa.gd and use explicit --qa-out/--dev-data-dir beneath private temporary directories. Run shop_home_qa.gd, service_result_qa.gd and bowl_editor_qa.gd as appropriate; --layout-only is explicitly not rendered evidence. Inspect originals and composed prechange/final/selected-source evidence. Verify frozen sources, PCK, strict engine signature and clean diff. Standing user authorization covers ready PR, verified-head squash merge and local main synchronization after acceptance.

## COMPLETION
- Completed: real home/read-only depths, original asset/scene reuse, guarded transitions, full visible save feedback/protection and current regressions.
- Completed: fresh native baseline116/0; final home780/0+editor524/0+service466/0; compact356/0+202/0 layout-only; actual exits0 and engine errors0.
- Completed: full/focused combined visual comparison, source293/PCK/hash/strict-signature and private byte-equal preservation. Evidence: evidence/shop-home-workbench-v1.json; design-qa.md; game/docs/uiux-reset/shop-home-workbench-v1.
- Excluded by scope: phone/Claude/ordinary saves, domain/rules/assets additions and whole-game staff/story redesign.
- Ready publication and verified-head merge use standing human authorization; actual completion recorded in the private checkpoint after remote verification.
