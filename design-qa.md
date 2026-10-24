# Native service-result design and interaction review

final result: passed

2026-10-25. Bounded internal acceptance for actual service-result summary,
food/customer/cost details and history handoff. The human explicitly requested
more design elements aligned to chosen option3. Whole-game UI, physical iPhone,
accessibility certification and human fun acceptance are outside this slice.

## Source and comparison evidence

Visual truth: [chosen option3](game/docs/uiux-reset/refinements/concept-03-categories-v1.png)
and the accepted native editor/exploration design. The853x1844 reference alone is
normalized to390x844 with Lanczos; actual portrait390x844 and desktop1280x800
PNGs are unframed, unretouched native pixels. This is Godot, not CSS/browser
content, and no browser/device chrome is included. The chosen source depicts
menu editing. A service report is an intentional extension of its original food,
wood, frames, fonts and navy/cream/teal/gold palette, not an exact missing mock.

[Numbered actual flow, full comparisons and focused food-card crop](game/docs/uiux-reset/service-result-v1/),
[exact hashes and manual scope](game/docs/uiux-reset/service-result-v1/review.json).
Fresh285-file previous-main97dd063 baseline108/0/exit0 supplies matched single
and pair receipts. Same recipe/day/orders/revenue/cost/wallet are compared; the
baseline history capture shows the old service tab initially, not the actual old
receipt at a matched scroll position. Source/current editor/report are combined
in one comparison. The focused food card uses actual crops(22,360,369,495),2x
nearest enlargement only in evidence, to inspect the detail affordance and insets.
Desktop v1/v2 compares the same actual pair receipt at1280x800 without rescaling.

## Findings, iterations and fixes

1. P2 buried results: the baseline mixes full finance, two menu rows, customer
   sources and saving into a narrow long label. Show actual net/units/revenue
   first; clickable food cards lead to per-menu details; customers/cost/complete
   receipt have explicit depths. Fixed54px return/develop actions stay reachable.
2. P2 sparse visual hierarchy: respond to human feedback with original coin,
   actual sold dish thumbnails/large detail dish, wood context and actual customer
   portraits, licensed font hierarchy and supplied frame/CTA textures. Do not
   paint substitute art or add dashboard decoration unrelated to the game.
3. P1 reopened input: a visually higher result initially still sat before the
   drawer in sibling input order. Actual pointer regression reproduced a missed
   menu tap and wrong handoff. Move the result to the last sibling on open; final
   pointer tests cover reopening above the visible service drawer and detail taps.
4. P2 handoff: paused deterministic QA exposed reliance on the next process frame
   to show the editor. Explicitly synchronize the existing native editor after
   the development route. Preserve the whole draft/ledger; do not load a sold
   recipe automatically.
5. P2 v1 affordance/density: nativev1 showed a pale white detail arrow and two
   stretched desktop rows. Finalv2 uses a teal arrow/hover icon tint, real wood
   food context and side-by-side desktop cards. Focused/full same-state v1/v2
   comparisons verify the visible correction; portrait remains a scrolling list.
6. P2 misleading empty reaction: no completed orders means no satisfaction
   aggregate, not a bad0.0/5 review. Final loss screenshot shows0bowls/-3000 and
   no aggregate. Actual zero/negative amounts remain in the ledger unchanged.
7. P2 unavailable history: a stored old single receipt lacks full recipe/live
   reaction fields. Use the exact matching just-finished sold snapshot only;
   after restart omit missing dishes/stars explicitly. Stored expanded snapshots
   retain the real dish/wait. Current draft never substitutes historical food.
8. QA setup corrections: reject wrong baseline clock API and nil dish-property
   engine errors despite exit0/success counts. Use the existing advance helper
   and actual config property. Preserve all failed diagnostics separately. The
   product input/handoff failures above were fixed rather than weakening checks.

## Final verification and provenance

Final frozen packv2 only. Actual OpenGL4.1 Metal Apple M3 Pro: service466/0/exit0,
22PNGs; existing native editor524/0/exit0,30PNGs, run20261024T164353Z-24348.
Same packed390x750 service202/0 and ingredient payoff226/0 are explicitly
layout-only, both exit0; no compact rendering claim.13 final preparation/native/
baseline logs have no engine/script errors. No full-domain rerun or CI pass.

Real pointer coverage: summary/detail/back/receipt; card swipe cancellation;
fixed controls; reopen over drawer; current-draft independence; development
handoff; saved restart; actual two menus; live compact resize; zero-sale loss;
abort; actual isolated save failure, unchanged disk and successful recovery.
Settlement changes day/wallet once; a duplicate settlement is refused. Sum of
actual menu contributions minus common overhead equals the net once. All page
browsing/handoffs preserve the state. Existing editor/payoff regressions retain
prior tasting, sample, replacement, canceled input and save-failure coverage.

All289 runtime sources match the snapshot; exported and embedded pack
`8c7f0562733a38540bf6878882fa7a685d61aac9dc531523f65675603dcf9669` matches.
Official copied engine hash and post-run strict vendor signature pass. Whole
baseline/current/editor directories6/22/42files and18isolated data files are
privately preserved byte-equal, with source/pack/logs and rejected diagnostics.
Publish26current originals,6baseline originals and6comparisons.17/22result,
4/30editor,4/6baseline originals and6comparisons were opened. All52 current
originals satisfy actual fixture dimensions/nonblank guards; not all were read
manually. Two-menu fixture research names are actual QA-created records, not new
fixed product labels or evidence of first-time player progression.

## Five fidelity surfaces and residual limits

Typography: original licensed Pretendard Regular/Bold,32px net,22-24px heading/
figures,18px menu titles,14-16px supporting copy. Menu summary titles truncate
only after2lines; full titles are available in detail. Spacing:14px outer paper
insets,12px card content insets,10-12px gaps,126px full food-card targets and48px+
actions. Main body scrolls below fixed header/footer; desktop max860px and two
columns, compact margins14px. Colors: supplied navy/cream/teal/gold textures,
red losses/warnings; teal icon fix is inspected. No formal contrast certification.
Images: exact existing food/wood/coin/frame/portrait/font bytes, nearest food
sampling and no invented historic dish. Coarse older portraits/region art remain.
Copy: actual completed orders, per-menu contribution vs common operating cost,
net vs historic wallet, taste vs live stars, missing history and save failure
are distinguished. No invented reactions, forecast-as-actual or duplicate grant.

No actionable P0/P1/P2 observed in these bounded surfaces. P3 follow-ups include
coarser older character art, idle single-card space in the desktop grid and the
separate gray cooking progress styling. Surrounding shop/staff/story drawers
retain their older design and need a separate scope; this is not whole-game UI
completion. VoiceOver, keyboard-only, text scaling, reduced motion, real phone
safe areas/touch and human fun remain untested. No Claude, phone, normal save,
domain/service/schema/balance/asset/font or unfinished-stash changes.

Completed checklist: fresh baseline; bounded implementation; pointer/handoff and
visual fixes; final native/compact/regression checks; full/focused comparisons;
source/signature verification and exact preservation. Ready PR/verified-head
squash merge use standing human authorization. Earlier work remains in the
[ingredient payoff gallery](game/docs/uiux-reset/ingredient-payoff-v1/).
