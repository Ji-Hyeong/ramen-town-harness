# Native editor typography and spacing review

final result: passed

2026-10-23. Bounded internal review of the human-reported font/border-crowding
problem. This is not whole-game design acceptance, human approval of this new
appearance, exact mock reproduction or physical iPhone acceptance. The human's
rejection superseded the previous v5 technical pass.

## Findings and corrections

1. P2, broth/noodle summaries: headings touched their top border. A full-rect child
   had only horizontal5px margins; Button style padding did not inset it. Actual
   horizontal12/vertical10px insets,4px title/value separation, centered headings
   and76px height fix this. Tests assert actual child rectangles inside the inset.
   The opened top-focused before/after visibly confirms the breathing room.
2. P2, typography: bitmap Galmuri Bold was used for small filters, ingredient names
   and all buttons. Original licensed Pretendard Regular/SemiBold replaces it:
   header22px, summary18px, names17px, price/time14px, portion15px and CTA22px.
   Full and lower-focused comparisons show smooth readable type and calmer weight.
3. P2 regression, shorter390x750: larger text-card padding also consumed the image
   stage and list. Packedv2 compact202checks/5failures is preserved. Image-only stage
   uses its actual2px frame rather than text padding, four-slot preview408px and
   major gaps5px. Current packed compact202/0 retains the bowl, list and fixed CTA.

## Comparison evidence

Target: game/docs/uiux-reset/refinements/concept-03-categories-v1.png,
853x1844 normalized with Lanczos to390x844. Before: actual native-v5 portrait
initial, explicitly the human-rejected historical baseline. After: actual fresh
portrait initial in game/docs/uiux-reset/typography-v1/,390x844/density1 native
SubViewport; desktop1280x800 is responsive adaptation, no drawn OS/device chrome.

Three-way full/source/before/after and focused comparisons were composed and
opened in typography-v1/comparisons/. Common crops (0,58,390,105) summaries and
(0,420,390,424) lower controls are enlarged2x nearest. Only captions/gutters and
normalization are added. Full view checks composition; focused views check type
and padding at readable size.

Current actual OpenGL4.1/Metal run20261023T110902Z-58114:490checks/0failures,
exit0/engine-errors0,30original PNGs (15/profile). All dimensions/nonblank checked.
13 current originals and3 comparisons opened; exact paths/hashes/manual scope in
typography-v1/review.json. Do not claim all30 were individually opened.09d may
equal09b when the entire numeric comparison already fits, not distinct gameplay.
All42 raw-run files preserved byte-equal privately. All240 source hashes, actual
exported/embedded PCK4da0e678a91027a521720446045fd56766d730ebaa4209a3f749aeff87420d4d,
and copied official-engine strict signature0 match after execution. Current
actual packed compact390x750202/0 passes; this is not physical safe-area proof.

## Five fidelity surfaces

Fonts: real Regular/SemiBold faces, not simulated bold. Original officialv1.3.9
archive/font hashes, full OFL and provenance retained. The actual pack's full OFL
is checked. The generated mock has no exact font file; this is the human-requested
readable approximation. Legacy numeric comparison retains its established body
theme; this does not migrate unrelated game screens.
The original upstream OFL's single trailing space is retained byte-for-byte;
only this vendor license is excluded from the staged whitespace check.

Spacing: real summary insets, shared10px horizontal/8px vertical text-card padding;
rows8px,72px minimum height,8px horizontal gaps and4px name/price gap. Row borders
are lighter1px, native hits remain48px/categories>=44px. Initial390x844 shows three
complete rows instead of the source's four; preserving readable text and touch
space is intentional, independent scrolling/categories handle more. Portions and
footer remain enclosed in initial, notice, result and synthetic rank projection.

Colors: navy/cream/teal/gold and disabled/selected distinctions remain. This is
not contrast/accessibility certification. Images/icons: original food/background/
steam/library-icon bytes untouched, correct aspect/separate repeated portions
retained; no fake replacement assets or system font install. Copy: real names,
costs/time/rank, all selected-customer reasons and price reaction remain available;
illustrative mock values do not replace game data.

Native pointer verification covers category changes, button-start swipe/canceled
press, duplicates/replacement/minimum-one removal, locked details, broth markers,
name/price, actual cooking/cancel/once-only payment, selected customer/full reasons/
price note/version comparison/clues, notebook and isolated failed-save recovery.
Domain/services/schema unchanged; earlier domain totals are not claimed as rerun.

## Iterations, limits and completion

First refinement packv1 failed test script parsing (untyped inset), despite exit0:
no checks/graphics accepted. Explicit Rect2 fixes it. V2 standard source400/0
preceded its compact regression; it is not final visual acceptance. V3 actual
490/0 and final packed compact202/0 are current. Failed logs/packs preserved.

Source beveled ornament/callout tails/coin decoration remain known polish debt;
this targets the human's font/padding complaint, not complete source reproduction.
Some real Mac result captures retain a hover label over the bowl, not baked image
text. Whole-game aesthetics/fun, VoiceOver/text scaling/reduced motion/keyboard
focus and physical iPhone safe areas/touch require separate validation. Phone work
remains excluded; no Claude delegation, normal-save access or security change.

Completed: preserve all10 unexpected copies in place; independent main-based
checkout; licensed type/real insets; actual guards; fresh native pack/capture;
compact regression correction; full/focused comparison; postrun source/pack/
signature checks and bounded evidence. Ready publication/matching-head merge is
already authorized by the standing human instruction.
