# Staff/growth workbench design QA

final result: passed

2026-10-26. Bounded native staff/training/facility/expansion/rank design extension and interaction acceptance.

## Visual truth, state and comparison inputs

Selected truth:`game/docs/uiux-reset/refinements/concept-03-categories-v1.png`,853x1844, normalized to390x844 with Lanczos inside the composition only. Existing native editor/home/result assets and fonts supply the design system. The selected source is an editor; no staff-specific mock was selected. This deliberately extends its real imagery/frames/colors/type into staff pages and does not claim an exact staff-image clone.

Current raw screens:`game/docs/uiux-reset/staff-growth-workbench-v1/portrait_growth_01_initial.png`, `portrait_growth_07_training.png` at390x844 and `desktop_growth_07_training.png` at1280x800. Native SubViewport pixels are logical viewport pixels1:1; CSS density/browser/device chrome do not apply. The desktop original was opened separately because the chat viewer can shrink a wide composition.

Before code edits, capture a new native baseline with the293-file pack matching main7779866.118/0/exit0,8 captures. Same public transactions prepare the same progression: fresh30,000won, hired day6/wallet373,780, training day11/wallet712,280/46bowls/5workdays. No wallet/rank/XP injection. Intentional changes in information depth are explicitly not called the same interaction page: old mixed growth list becomes native roster and dedicated detail/training pages.

Combined full inputs in the gallery:`comparisons/portrait-design-system.png` contains source+native roster+native training. `portrait-initial-before-after.png`, `portrait-staff-before-after.png`, `portrait-training-before-after.png` and `desktop-training-before-after.png` contain actual baseline/current originals together. Focused combined input:`focused-effect-v1-v5.png`, real training-effect/footer crops at2x nearest, displays the first currency-wrapping defect and corrected output. Raw PNGs are untouched.

## Findings and fixes

- [P1 resolved] Existing growth is a long mixed paragraph list; portraits, hiring and training are separated by unrelated investments. Replace its current visible surface with staff/facility/shop tabs, full-card portrait/chevron entry and dedicated read-only details. Original state, forecasts and guarded handlers remain authoritative. Combined initial/staff/training inputs show the resulting hierarchy and retained facts.
- [P1 resolved] Native root feature siblings could remain visible after the common drawer close until another game frame, intercepting home touches. Initial actual home regression failed4 checks. Explicitly synchronize all native views inside the existing close function. Fresh V4 native home780/0 and editor524/0 verify the correction; no failed run is accepted as proof.
- [P2 resolved] Training-effect heading broke750 and the currency unit onto separate lines. Split effect and daily upkeep into explicit whole lines. Focused V1/V5 and final raw training show750won/1,000won legibly.
- [P2 resolved] A previous action error could look like a newly opened hire was blocked. Dismiss non-save notices on navigation, label remaining messages as recent work and keep disk-save warnings persistent. Actual current save state is separate from the recent transaction message, including recovery. Final hiring and failed-save originals verify the distinction.
- [P2 resolved] Financial/permanent-choice policy could fall below the scroll fold. Fix cost/refund/specialization policy above the primary footer. Confirmation/cancel/expiry and actual two-second training progression remain controller-owned. Final locked/ready/confirm/progress/specialization screens and actual pointer checks verify reachable fixed actions and canceled swipes.
- [P2 resolved] Home detail counted only optional assistants against total staff capacity. Include the existing fixed chef/server2 in the projection. New transaction QA opens real home details and verifies3/3 after hiring; native home original shows2/2 initially.
- [P2 resolved] Test preparation attempted to taste an already recorded research recipe. Reuse that actual notebook entry for submission instead. Final public-transaction preparation has no engine errors; intermediate nil/duplicate-fixture failures are retained privately and rejected.

No unresolved P0/P1/P2 findings in this bounded scope. Remaining notebook/research/contest/story styling and additional growth content are outside this pass.

## Five fidelity surfaces

1. Fonts/typography: supplied Pretendard Regular/Bold, no font additions/fallback changes.22px page title,24px portrait name/key cost,18px card headings/effects,16px body,14px secondary/policy. State/cost headings are navy/teal; wrapping is intentional within the full name and full reason. Actual font-height checks and currency crop show no border-touching or cut currency. Fixed-wallet text remains unwrapped even above1,000,000won.
2. Spacing/layout rhythm:14px paper frame inset,12px card inset,10px portrait/body gaps,64/72px portraits,118px whole-card targets,44px+ back/tab targets and54px fixed primary. Long body scroll stays above policy/footer. Wide roster/facility lists use two columns inside860px centered frame; portrait uses one column. Live390x750 resize and actual drags over buttons/portraits preserve readable depth, scroll return and canceled activation. Empty space in the roster is intentional because only two optional employees exist; no fake staff fill it.
3. Colors/tokens: exact supplied navy/cream/gold/teal textures, ink18354f, teal087e80, redaa3828, muted disabled grey and cream. Progress bars use semantic teal over the existing neutral palette. Disabled options are visibly muted and retain readable text/icons. This reuses the accepted native palette without claiming a complete contrast/accessibility audit.
4. Image quality/assets: byte-identical supplied coin/frames/Material rounded icons and pre-existing pixel staff portrait renderer. Portraits use nearest scaling; custom imagery/handwritten icon replacements were not added. Standard facility/shop icons are intentional because there is no selected staff-specific illustration. No new assets/fonts, placeholders or invented characters. The underlying isometric shop/art is unchanged.
5. Copy/content: actual rank/staff totals/capacities/wallet, trained status/XP/workdays, current versus next effects, domain eligibility/prices, immutable same-day hiring forecast and permanent policy. Predictions are clearly marked and exclude the one-time hire fee; no promise of extra actual sales. Expansion states required rank separately from current rank. Recent message/current save state are separate. Stored restart/once-only costs and no XP reward from animation are tested. Technical research suffixes are names actually created by the public test fixture, not new product copy.

## Verification/provenance

- Final V5:297 frozen sources match current worktree; PCK ea3903b4d3ca290c91dc9ea575b31a5b0a072fe233301f6c010eedc1443642b3 equals exported/embedded pack. Native staff772/0,30PNG,exit0/engine0.
- V4 current application: native home780/0,24PNG; editor524/0,30PNG; actual exits0/engine0. V4/V5 snapshot diff is exactly `tests/staff_growth_qa.gd`, adding two drag assertions; every application runtime/resource and other test file is byte-identical. V4 regression PCK0211e4fba6cfad209c039f059021db481853124ce5d8bdc1da6ad47985e2c4c2. Do not relabel these as one-pack executions.
- Exact final source compact390x750348/0,exit0,layout-only. It is not rendered evidence. Existing pure training rules96/0,exit0; domain files unchanged.10 successful runtime logs have no engine errors. Both official engines pass strict post-run signature verification0.
- Actual pointer tests cover home entry/native replacement, detail/read-only locks, no-space/rank requirements, exact space/hire/expansion costs, actual preview, XP gate, live-service lock, confirmation/cancel/timeout, same-cost once-only qualification, half progress/no extra XP, rank with no cash reward, economy preview/speed permanent choice/reselection refusal, scrolled-list return, live compact resize, failure/recovery/current-save distinction, accurate home count and saved restart. Button/portrait drags scroll without activating or acknowledging a success.
- Opened final staff11 originals, current home/editor4, baseline4 and all6 final combined comparisons. Exact names/hash lists live in `evidence/staff-growth-workbench-v1.json` and gallery `review.json`. Publish staff30+regression4+baseline8 untouched originals; all84 accepted current originals, source/PCK/data/logs and rejected diagnostics are retained privately byte-equal. Not every generated PNG was manually opened.

## Implementation checklist

- [x] Original assets/type and bounded current native staff/growth depths connected through existing handlers.
- [x] Fresh baseline, native final/input/compact checks and current home/editor regressions.
- [x] Combined full/focused source/current comparison and listed fixes confirmed.
- [x] Source/PCK/post-run signatures, isolated data and precise manual scope preserved.
- [x] Ready publication prepared under standing human authorization; actual merge outcome recorded separately after remote/local verification.

## Limits

No Claude/auth, iPhone, ordinary saves, domain/services/schema/balance/assets/font changes or unfinished stash restoration. This is internal native UI/interaction acceptance, not whole-game aesthetic/fun completion or full accessibility/physical-touch certification. Native app evidence is supplied instead of a fake browser preview URL.
