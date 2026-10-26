# Shop home workbench design QA

final result: passed

Date:2026-10-26. Bounded native shop-home extension/interaction acceptance only.

## Visual truth and normalization

- Selected source:`game/docs/uiux-reset/refinements/concept-03-categories-v1.png`,853x1844; normalized to390x844 with Lanczos only inside compositions. The source is an editor screen. There is no selected home-specific mock. Carrying its supplied frames, coin, bowl layers, icons, palette and Pretendard into the existing home is intentional; this does not claim an exact home clone.
- Current implementation:`game/docs/uiux-reset/shop-home-workbench-v1/portrait_home_02_selling.png`,390x844; `desktop_home_06_expanded.png`,1280x800. Native SubViewport pixels equal their logical viewport1:1; no browser/device chrome or CSS density applies.
- Fresh baseline: same directory `baseline/`; previous-main377513e frozen289-file pack,116/0/exit0,8 captures before runtime edits. Empty, single selling and expanded idle use the same public-state transactions, recipes, prices, wallet and day. Current subsequent draft edits are not substituted for the selling roster. Baseline60s/current300s active scenes are not claimed as same-state comparisons.
- Full combined inputs: `comparisons/portrait-design-system.png`, `portrait-empty-before-after.png`, `portrait-selling-before-after.png`, `portrait-expanded-before-after.png`, `desktop-expanded-before-after.png`. They contain actual source/baseline/current images together. Desktop comparison may be scaled by the chat viewer; original1280x800 images were also opened.
- Focused combined inputs: `comparisons/focused-header.png` compares genuine source/current crops at2x; `focused-summary-v1-v5.png` shows the actual first broken summary versus current at2x nearest. No raw screenshot was retouched.

## Findings resolved and post-fix evidence

- [P1 resolved] First compact header expanded to232px because a shrinking, wrapped date column had almost zero width. Give date/rank their real unwrapped text minimum, reserve52px header/64px scene inset and center its column. Current raw and compact geometry retain the original2x portrait/4x desktop shop with no overlap.
- [P1 resolved] V1 clock wrapped vertically and displaced the actual dish/title outside the summary despite the overall card geometry passing. Disable clock wrapping; enforce text and dish containment inside real frame padding. Actual V5 originals and focused V1/V5 composition show a complete one-line phase, dish, name/price and teal chevron. No early screenshot-only pass is used.
- [P2 resolved] The warning icon initially squeezed its caption away. Give the warning affordance86px and unwrapped text, and put an explicit failure line in the selling summary. Raw `portrait_home_08_save_warning.png` and `10_protected_home.png` show both actual states; the full original banner/reset is reachable in09/11.
- [P2 resolved] A manual-save refusal was initially below the scroll fold. Move the actual response above the fixed save button and clear it on reopening/reset. Raw05 shows truthful active-service refusal without scrolling; tests cover real write failure/retry/recovery and corrupt-file archive byte preservation.
- [P2 resolved] Live details could remain behind an automatically opened settlement. Dismiss them on the existing report route so the result's home action returns to the shop. Actual pointer/settlement QA covers the transition and once-only net/day mutation.
- [P3 resolved] Disabled route icons inherited near-white tint on cream. Apply a scoped muted disabled-icon token. V5 live detail shows visible muted icons beside disabled text.
- No remaining P0/P1/P2 findings within the stated home scope. Other old staff/growth/story pages are separate future work, not included in this pass.

## Required fidelity surfaces

1. Fonts/typography: original supplied Pretendard Regular/Bold, no new fonts/fallbacks. Day/wallet18 bold, selling title16 bold, phase/metadata14, detail16 and heading22. Rank12 remains secondary to the readable enlarged detail. Same selected-source hierarchy carries to fixed gold CTA and navy headings. Intentional one-line selling-name ellipsis opens a full wrapping name in detail. Actual font measurement guards day/wallet/clock height and summary containment; originals and focus crops show no text touching frame borders.
2. Spacing/layout:6px outer home gap,12px header side insets,10px/6px summary padding,14px detail frame padding, fixed44px+ targets. Compact stacked summary/nav reserve158px; desktop uses one84px row side by side, preserving the actual isometric world. Detail is scrollable within a centered720px maximum and has fixed close/save.390x750 live resize tests preserve scene scale and reachable actions. Full/focused combined comparisons confirm the change from a dense two-line brown strip to food-led summary.
3. Colors/tokens: byte-identical original blue/cream/gold/teal frame textures; navy18354f body/headings, teal087e80 actionable status, redaa3828 failure, white-on-blue primary metadata. Scoped disabled grey/cream is intentional. Contrast remains based on the established native design, not a full accessibility certification.
4. Image quality/assets: original coin, noodle empty-state icon, actual layered selling bowls, Material rounded icon resources and unchanged integer-scale shop pixel art. No generated additions, placeholders, handcrafted icons or code-drawn replacement art. Summary60x38/paired48x38 dish is intentionally a thumbnail; full detail is84x60. New preview data always belongs to the selling records, never a current draft. Side-by-side composition preserves the original shop size/art.
5. Copy/content: real day/rank/seats/staff/capacity/wallet, roster/version/price and session stats. Actual anticipated units are clearly labeled as forecasts in detail. Empty menus have an explicit first-menu path; active service preserves double-confirm stop and exact settlement. Full actual save warnings/protection and manual outcome are accessible; no invented successful saves or historical dish guesses. Technical recipe suffixes in the two-menu fixture are actual prior test recipe names, not new product copy.

## Interaction and evidence

- Same final293-source V5 pack:`637eb1d970d6da293ed4ff15dbf49854d81283955e4c1682363db85ad073369e`; export equals embedded PCK; post-run official strict engine signature exit0.
- Actual native home780/0, editor524/0, service-result466/0; all actual exits0 and engine errors0.10 runtime logs checked. No CI inference: these are local runs.
- Same packed390x750 home356/0 and service202/0, layout-only/exit0. Rendering explicitly not claimed for these runs.
- Actual pointer checks: home/info/summary/close, press acknowledgement, canceled card swipe, first-menu editor, selling/growth/exploration/report routes, live speed/progress, protected roster, double-confirm abort, exact settlement, automatic result replacing details, resumed travel, save failure/retry/recovery and explicit corrupt-byte archive/reset.
- Opened final home16 originals, current editor4, current service2, baseline4 and all7 combined comparisons; exact names/hashes in `evidence/shop-home-workbench-v1.json` and gallery `review.json`. Final generated76 originals; public home24+regression6, baseline8. All raw isolated outputs retained privately. Not every generated original was manually opened.

## Implementation checklist

- [x] Preserve selected-source assets, existing shop and domain/save/financial rules.
- [x] Render fresh native baseline and final states, compare combined full/focused inputs and resolve listed findings.
- [x] Verify actual pointer transitions, compact geometry, isolated failure/protection and current editor/service regressions.
- [x] Verify source/PCK equality, post-run signature and precise evidence/manual scope.
- [x] Prepare ready publication under existing human authorization; actual remote/local merge outcome is recorded separately after completion.

## Limits

No physical iPhone work, Claude delegation, ordinary saves, domain/services/schema/balance/assets/fonts changes or unfinished stash restoration. This is bounded internal UI acceptance, not whole-game aesthetic/fun completion or a general accessibility/physical-touch certification. The native artifact is not a web prototype; no fake browser preview URL is provided.
