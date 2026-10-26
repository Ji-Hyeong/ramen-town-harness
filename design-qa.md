# Mountain sampling / ingredient-led ramen design QA

final result: passed

Acceptance covers this bounded native game flow; it does not declare the full game complete or physically tested on iPhone.

## Source, state and evidence

Selected visual truth: game/docs/uiux-reset/refinements/concept-03-categories-v1.png (853×1844 raster), plus accepted native editor/exploration on mainc3d56e2. Current originals: game/docs/uiux-reset/mountain-foraging-v1/current/ (30 PNG,390×844 /1280×800). Actual Godot OpenGL rendering; one screenshot pixel per logical SubViewport pixel, no simulated OS chrome. Fresh before-run:28PNG,307 snapshot files independently equal accepted Git blobs.

[Source / before / current](game/docs/uiux-reset/mountain-foraging-v1/comparisons/source-before-current.png) · [Source and new dishes](game/docs/uiux-reset/mountain-foraging-v1/comparisons/source-and-new-dishes.png) · [Focused bowl / callout / slots](game/docs/uiux-reset/mountain-foraging-v1/comparisons/bowl-focused.png).

The source is normalized390×844 using Lanczos only in comparison boards; desktop contact sheets are half size. Published originals are unchanged. Six contact sheets cover every mountain state; selected original-size portraits/desktop scenes and six regression originals are opened separately. Dimensions/hashes/manual scope: game/docs/uiux-reset/mountain-foraging-v1/review.json.

The source has rank1/wheat/two slots, current earned rank3 has four slots/different foods. These are intentional state differences. Mountain exploration extends the accepted design language; no exact new-page mock or exact-font identity is claimed.

## Findings and comparison history

1. **P2, fixed: noodle art inconsistency.** Initial preview/detail used a primitive glyph; development reused yellow wheat despite a brown buckwheat bowl. [Before / final / detail](game/docs/uiux-reset/mountain-foraging-v1/comparisons/noodle-refinement.png). Add an original buckwheat bundle, reused in preview/reward/detail/selector/summary. Preserve originals. Scope display alpha clipping to the new generated bundle/bowl exterior; final native crops show clean silhouettes on paper/wood.
2. **P2, fixed: desktop cooking overflow.** A hidden wrapped VBox cached a narrow startup height, inflating the whole content grid when shown and moving bowl/footer outside1280×800. The added extent checks against oldV4 fail2/788. Bound the work body with its own ScrollContainer and retain the cancel action. [Same-state before / after](game/docs/uiux-reset/mountain-foraging-v1/comparisons/cooking-before-after.png). FinalV5 native878/0 and compact396/0 include cooking scene/footer extent checks. Both revised native states were opened at original size.
3. **Rejected validation artifacts, corrected:** the first touch fixture started at a deferred64×64 headless root. It now waits for resize, checks actual viewport and requires both profiles finish. V3 printed zero assertion failures despite null-texture metadata errors and was rejected. Initial unbound region images now receive no material. Accepted final logs have zero engine/script errors as well as zero assertion failures.

## Five required fidelity surfaces

| Surface | Review |
|---|---|
| Fonts / typography | Preserve existing Pretendard body/bold and native display hierarchy. Source raster font identity is unknown; no exact-font claim. Descriptions wrap inside padded paper, costs/time stay readable. Visible exploration labels pass measured line-height checks in both captures and compact layout. |
| Spacing / layout | Keep wood stage, paired callouts, portion dock, category tabs and fixed gold action. Four rank3 slots intentionally reduce visible rows relative to the two-slot mock. Test summary padding, bowl proportions and viewport extent; fix cooking overflow above. |
| Colors / tokens | Keep original navy/cream/teal/gold frames. Red signals locks/refusal, muted actions are disabled, active choices remain teal. Taupe bundle/dark noodles identify buckwheat; no global palette change. |
| Image quality | Real original raster foods, measured crops and scoped halo clipping. No substitute SVG/emoji/placeholder for new foods. Each repeated portion is a separate cluster. Existing tiny service art keeps its implementation;972 base dish pixels/evaluations equal accepted main. |
| Copy / content | Rank3/two suppliers, fee1600, extra800, stock, deliberate claim and successful-tasting-only consumption match actual transactions. Research describes real constraints and opens its own source without applying recipes. No fictitious guaranteed score/unlock/reward. |

## Real input and flow

1. Inspect locked mountain sampling without spending.
2. Earn rank/suppliers through public actions, choose target/quantity with actual pointer input, confirm exact cost.
3. Restart before claim, collect once, open current material details without changing draft.
4. Explicitly select buckwheat, cancel cooking without charge, complete once and see actual customer responses/direction discovery.
5. Collect shiitake and add the same topping to a second slot through the actual native add button; correct source navigation and exact final disk restart.
6. Current native finger input verifies portrait scrolling from enabled/disabled buttons, canceled swipes, one tap/one portion/one acknowledgement and name entry:49/0. Wide fitting desktop content correctly stays stationary.

Same final pack: mountain878/0+editor526/0+exploration678/0=2082/0,88 native originals, exits0/engine0. Domain129tests/59458checks, directions94 and compact396 pass. Counts do not prove fun, accessibility compliance or game length.

## Follow-up polish / limits

- P3: the accepted high-balance header ellipsis could use a future compact currency format; full wallet remains visible in exploration.
- P3: quantity labels repeat the correct extra fee in the generic cost line; the fixed confirmation shows the real charge.
- No physical iPhone touch, Korean IME, lifecycle, text scaling, assistive technology or long-term balance acceptance. No phone operation.
- Historical touch_scroll_tests.gd targets hidden TabLab and reproduces30 failures on both unchanged main and current. It is retained, not reported as passing current-screen acceptance. Current native_workbench_touch_tests.gd is documented in game/README.md.

## Completed checklist

Scoped food art/source navigation; paid/claim guards and strict save migration; both P2 corrections with revised original-size captures/focused comparisons; current native input and existing editor/exploration regression; source/PCK/signature equality. User-excluded iPhone work and full-game/physical-device acceptance are outside this task.
