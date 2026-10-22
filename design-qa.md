# Harbor flow design verification

final result: passed

## Current-run evidence and source
- Fresh native run:20261022T070256Z-95998, official OpenGL4.1/Metal engine,688checks/failure0/exit0/engine-errors0. All24PNG originals were opened and manually inspected; full32-file run preserved byte-equal.
- Viewports:portrait390x844 and landscape1280x800, SubViewport density1, no device bezel or density rescaling.
- Evidence manifest:game/docs/harbor-screenshots/v1-review.json. Current-run diagnostics:game/docs/harbor-screenshots/v1-diagnostics/.
- Existing project/style source:game/docs/exploration-screenshots/portrait_35_exploration_harbor.png. This older source is a style reference only, not evidence for current behavior. New sampling and old supplier trips intentionally have different content.
- Accepted current implementation run:20261022T072702Z-2212, actual OpenGL SubViewport capture962checks/failure0/exit0/engine-errors0,28PNG originals all manually opened. Full38-file run preserved byte-equal.
- Current implementation screenshots:game/docs/harbor-screenshots/v2/; hashes/manual-review state:game/docs/harbor-screenshots/v2-review.json.
- Source/implementation full-view comparisons were composed and opened together:game/docs/harbor-screenshots/comparisons/portrait_06_waiting.png, portrait_08_workbench.png, portrait_12_label.png, portrait_09_triple_dish.png, portrait_10_result.png and portrait_style_reference.png. Both original images remain390x844 at density1; canvas adds only labels/a16px gutter, no density scaling. Different scroll positions for collection/handoff are the intentional fix, not a geometry discrepancy.
- Focused comparison opened:comparisons/portrait_label_focus.png. Each151x90 actual button-region crop is displayed at3x nearest-neighbor for reading; no image content or colors were edited. The shorter button naturally occupies less height. Original full views were also inspected.
- Old supplier-trip/source reference and current sampling are intentionally different states. The style comparison establishes retained font/palette/border/sprite direction, not a pixel-identical clone. Current audit findings rely on the two fresh runs only.

## Resolved findings from iteration1
1. [P2] Portrait pending-claim action below fold. Evidence:portrait_harbor_06_waiting.png. Repeated instructions precede the result, leaving its primary collection action out of view. Fix:after layout, reveal the pending harbor collection button without collecting or changing tabs. A failed-save warning keeps priority. Resolved in v2 portrait06; portrait14/desktop14 preserve the warning.
2. [P2] Handoff exposes a section header, with the actual catch below the viewport. Evidence:portrait_harbor_08_workbench.png and matching desktop08. Fix:open the existing section, then reveal the catch's actual ingredient control without selecting it or changing the draft. Resolved in v2 portrait08/desktop08; actual scallop button visible.
3. [P2] Sardine broth title wraps its last syllable onto a separate line. Evidence:portrait_harbor_12_broth_dish.png (actually a choices screen) and desktop12. Fix:compact ingredient-button label; retain full name in stock, section headers and details. Resolved in v2 portrait12/desktop12 and focused before-after crop.
4. [P1 verification gap] Declared dish/result captures09/10 show the shop, in both sizes. The test toggled an already open overlay closed and then emitted hidden semantic button signals. Reject these four files as dish/result evidence. Fix:open the lab idempotently, assert the overlay/dish are visible and explicitly capture the actual BowlPreview and FeedbackBowl. Add a separate broth-dish capture; old12 is only choices evidence. Resolved in v2 screenshots09/10/13 in both sizes; each shows the declared actual scene/dish.

## Required surfaces
- Typography:existing GowunDodum and hierarchy retained; full names/details are readable. Compact broth button fits one line in v2; the full name remains in its section and details. Existing long descriptions wrap naturally inside their scroll area.
- Spacing/layout:fixed navigation/footer remain visible. Scroll overflow is intentional; the collection action and catch are now visible at the destination without test-driven scrolling. The failed-save case deliberately stays at the warning.
- Color/tokens:paper, brown borders, vermilion titles and teal progress match the existing game. Screenshots do not establish WCAG compliance; color is accompanied by labels/chevrons/counts. Existing code-token contrast is about4.48:1 teal/paper and4.49:1 vermilion/paper versus4.90/4.91 on light card surfaces: a retained, marginal P3 palette follow-up, not an AA-compliance claim.
- Image quality:original region art retained with hard pixel edges. Generated scallop icon is distinct on the paper card; no opaque rectangular background observed. V2 images09/10/13 show actual triple scallops and a distinct broth/nori dish with readable cost/time facts. No old screenshot substitutes for these states.
- Copy:departure1200, optional extra600/three vs free/one, stock3 then0/1 and read-only development handoff are visible and match transactions. Technical duplicate-claim reassurance and repeated instructions remain P3 copy refinements.

## Comparison history
- Iteration1:24fresh PNGs inspected. Three product P2 findings and one capture-verification gap recorded; no visual completion accepted.
- Corrections:reward/control auto-reveal, compact sardine-button label, actual visible-state assertions/dish captures, and failed-save-warning priority test.
- Negative control:new assertions on frozen pre-fix source yield860checks/5failures/exit1/engine-errors0. Same assertions on fixed source yield860/0/exit0/engine-errors0. This is layout/behavior evidence, not the required post-fix rendering.
- Iteration2:final focused878/packed878/touch70/domain127tests58423/full two-size layout19066 all0/exit0/engine0. Fresh native962/0 and28originals plus7combined comparisons inspected. Source135/PCK2da6bdc7 unchanged, vendor signature0 after run. Earlier P1/P2 findings are resolved; no new actionable P0/P1/P2 finding in the bounded harbor flow.

## Final implementation checklist
- [x] Explicit fees/quantities, stock changes, repeat portions, zero-stock sales and restart states covered by real transactions.
- [x] Reproduce pre-fix UI failures; retain source/dish-state assertions and failed-save warning-priority regression.
- [x] Fresh corrected collection/control/label/actual-dish/warning captures in both sizes, all28 manually inspected.
- [x] Full-view and focused source/implementation comparisons composed together, opened and reviewed.
- [x] Typography, spacing, tokens, asset fidelity and copy reviewed from current renders.

## P3 follow-up and limits
Repeated instructions, technical duplicate-claim reassurance, some existing locked-ingredient label density and marginal palette contrast remain polish follow-ups; they do not block this bounded loop. This is not full accessibility compliance, production readiness or proof of6–10hours of fun. Physical iPhone input, VoiceOver, Dynamic Type and reduced-motion preference remain separate. Native tests route Godot viewport input; the gray harness root-window observation was not accepted as a game screenshot. Actual image evidence comes from OpenGL-rendered scene SubViewports. No iPhone install or normal-save write occurred.
