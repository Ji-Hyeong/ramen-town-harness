# Harbor flow design verification

final result: blocked

## Current-run evidence and source
- Fresh native run:20261022T070256Z-95998, official OpenGL4.1/Metal engine,688checks/failure0/exit0/engine-errors0. All24PNG originals were opened and manually inspected; full32-file run preserved byte-equal.
- Viewports:portrait390x844 and landscape1280x800, SubViewport density1, no device bezel or density rescaling.
- Evidence manifest:game/docs/harbor-screenshots/v1-review.json. Current-run diagnostics:game/docs/harbor-screenshots/v1-diagnostics/.
- Existing project/style source:game/docs/exploration-screenshots/portrait_35_exploration_harbor.png. This older source is a style reference only, not evidence for current behavior. New sampling and old supplier trips intentionally have different content.
- No combined source/final comparison or final visual pass is claimed yet. Revised native captures are required.

## Findings from iteration1
1. [P2] Portrait pending-claim action below fold. Evidence:portrait_harbor_06_waiting.png. Repeated instructions precede the result, leaving its primary collection action out of view. Fix:after layout, reveal the pending harbor collection button without collecting or changing tabs. A failed-save warning keeps priority.
2. [P2] Handoff exposes a section header, with the actual catch below the viewport. Evidence:portrait_harbor_08_workbench.png and matching desktop08. Fix:open the existing section, then reveal the catch's actual ingredient control without selecting it or changing the draft.
3. [P2] Sardine broth title wraps its last syllable onto a separate line. Evidence:portrait_harbor_12_broth_dish.png (actually a choices screen) and desktop12. Fix:compact ingredient-button label; retain full name in stock, section headers and details.
4. [P1 verification gap] Declared dish/result captures09/10 show the shop, in both sizes. The test toggled an already open overlay closed and then emitted hidden semantic button signals. Reject these four files as dish/result evidence. Fix:open the lab idempotently, assert the overlay/dish are visible and explicitly capture the actual BowlPreview and FeedbackBowl. Add a separate broth-dish capture; old12 is only choices evidence.

## Required surfaces
- Typography:existing GowunDodum and hierarchy retained; full names/details are readable. Orphaned broth label is actionable until recaptured after the compact-label fix.
- Spacing/layout:fixed navigation/footer remain visible. Scroll overflow is intentional; hiding the next collection action and actual target is actionable and being corrected.
- Color/tokens:paper, brown borders, vermilion titles and teal progress match the existing game. Screenshots do not establish WCAG compliance; color is accompanied by labels/chevrons/counts.
- Image quality:original region art retained with hard pixel edges. Generated scallop icon is distinct on the paper card; no opaque rectangular background observed. Actual detailed scallop/broth dishes remain unverified because the first declared dish shots showed the wrong state.
- Copy:departure1200, optional extra600/three vs free/one, stock3 then0/1 and read-only development handoff are visible and match transactions. Technical duplicate-claim reassurance and repeated instructions remain P3 copy refinements.

## Comparison history
- Iteration1:24fresh PNGs inspected. Three product P2 findings and one capture-verification gap recorded; no visual completion accepted.
- Corrections:reward/control auto-reveal, compact sardine-button label, actual visible-state assertions/dish captures, and failed-save-warning priority test.
- Negative control:new assertions on frozen pre-fix source yield860checks/5failures/exit1/engine-errors0. Same assertions on fixed source yield860/0/exit0/engine-errors0. This is layout/behavior evidence, not the required post-fix rendering.
- Iteration2:pending a fresh source-matched QA app and native captures. Full-view/focused before-after comparisons will be composed at equal pixel density and inspected before acceptance.

## Remaining acceptance
- Freshly capture corrected collection, actual-catch handoff, compact label, real triple-scallop/result/broth dishes and failed-save notice in both sizes.
- Inspect each required state, compare same-state before/after images in a combined input, and update this report.
- Physical iPhone input, VoiceOver, Dynamic Type, motion preference and subjective fun remain separate. No full accessibility or device acceptance claim.
