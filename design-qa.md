# Ingredient detail and selector journey review

final result: passed

2026-10-24. Bounded internal native UI/interaction review. The human authorized
next work after the selected-mock rebuild. Current scope preserves that first
screen while improving detail/selection, not whole-game aesthetics/fun or physical
iPhone acceptance. Claude remains disabled by standing human instruction.

## Sources and fresh baseline

Visual truth: [selected option3](game/docs/uiux-reset/refinements/concept-03-categories-v1.png)
for the first screen; its texture/font system grounds new sheets. The source does
not draw ingredient-detail/tab states: these are intentional flow extensions.
A fresh native48/0 baseline from unchanged mainac467b8 captured8 screens before
implementation;4 were opened. Findings below derive from those actual screens.

[Current/baseline originals and comparisons](game/docs/uiux-reset/ingredient-flow-v1/)
contain no screenshot shell or painted controls. Source-only normalization uses
Lanczos to390x844. Full source/current, focused lower controls2x nearest, actual
detail and oil-selector before/after, and a three-step current preview were all
composed and opened (5 views). Ingredient comparison uses the same initial recipe
and egg, with a selected empty slot in the new state. Selector comparison uses
the same oil catalog/garlic selection but different background topping drafts;
it demonstrates hierarchy/navigation, not exact whole-frame pixel identity.

## Findings and fixes

1. P2 dead-end detail: only information/back was available. Add a fixed deliberate
   apply action, actual price/time/traits, locked condition, and correct empty-slot
   addition versus occupied-slot replacement. Browsing/cancel never changes state.
2. P2 capacity path: disabled add lacked a clear next step. Show replacement hint
   and an explicit real-portion chooser from detail. Cancel preserves the draft;
   choosing replaces exactly one slot through the existing guarded controller.
3. P2 long selector: reaching oil required scrolling past unrelated categories.
   Fixed broth/tare/oil/method and noodle/firmness/dough tabs expose the relevant
   subset. Retain active tab/actual nonzero scroll after detail or tab return.
   Directed clues override a different remembered tab with the correct target.
4. P2 empty/occluding sheet: first native462/0 still left excessive full-height
   whitespace and hid the bowl. Compact440/560px ingredient and count-sized
   replacement sheets keep food context with scrollable body/fixed actions.
5. P2 live resize: targeted source run500/2 reproduced desktop sheet footer offscreen
   after narrowing the open window. Recompute maximum width/safe/height margins on
   every editor resize; final native/compact tests exercise this and actual nonzero
   scroll restoration. This is sheet coverage, not whole-game640px acceptance.

## Final current evidence

Same frozen v7 pack: actual OpenGL4.1 Metal Apple M3 Pro new flow567/0/exit0,
18PNGs; editor/cooking/result/failed-save regression524/0/exit0,30PNGs, run
20261024T104201Z-46751. Script/engine errors0; dimensions/nonblank checks pass.
14 new-flow and8 regression originals individually opened, plus5 composed views.
Do not claim all48 originals individually read.26 current and8 baseline originals
are public; all raw baseline/flow/regression directories are preserved byte-equal
privately (10/22/42files respectively), plus console logs.

Same packed390x750 layout-only: new flow261/0, editor219/0, exit0/errors0.
Pointer coverage includes locked/read-only detail, drag cancellation, scroll
return, free/selected-empty addition, occupied/preselected/full-capacity replacement,
correct category return, tab/detail return, selected markers, actual dough/firmness
choices, no premature payment/record, actual tasting and clue-target navigation.
Inherited regression retains cooking cancel/once-only charge, customer reasons/
price reaction/comparison/clues, notebook route and isolated save recovery.

All277 allowed current runtime files equal the snapshot with no additions/missing
files. Exported/embedded PCK both equal
2c0b06b227f8b7f667f3d572aa144c63e8b36ddcaf9e112fd2b2a76421e3c8f8.
Official engine strict signature passes after execution; import/export logs clean.
Only bowl_workbench.gd differs from prior275 runtime files;2 new QA source/UID
files are added. Domain/services/controller/scenes/schema/assets/fonts unchanged.
[Exact hashes and manual scope](game/docs/uiux-reset/ingredient-flow-v1/review.json).

## Five fidelity surfaces and limits

Fonts: original licensed Pretendard Regular/Bold unchanged;22px modal heading,
24px item price,18px description and14-16px secondary copy. No font install/new
fallback. Spacing: real14px/12px sheet insets, max680px width, fixed52px apply and
44px+ hits, scroll body and safe bounds. The same first-screen composition and
existing larger category hits remain. Colors: navy/cream/teal/gold and selected/
disabled distinctions retained; no contrast certification.

Images: no new or modified PNG/font bytes; reuse actual food, chosen filled pot/
noodle symbols and existing category art. Some legacy oil/firmness icons remain
coarser than the new food art, a known P3 polish item. No third-party game imagery
or fake placeholder asset is introduced. Copy: actual ingredient cost/time/traits/
locks and accepted choice markers remain; selected empty slot explicitly says
addition. Slot browse/cancel does not promise recipe rollback after applying.

No unresolved P1/P2 issue observed in the bounded opened surfaces. Some captures
retain transient actual tap feedback. Keyboard/VoiceOver/text scaling/reduced
motion, physical safe areas/touch, human design/fun judgment and broader farming/
exploration flow remain separate. No normal saves, phone or Claude actions.
Broad domain suites were not rerun or claimed as current.

Initial QA parse failure (wrong inherited Catalog constant) was rejected despite
exit0 and corrected. Prepared v2-v4 were superseded, v5 native494/0 preceded resize
fix, v6 native562/0 preceded empty-slot copy fix. Only final v7 counts are current.
Completed: fresh baseline audit, bounded native implementation/meaningful tests,
visual/resize corrections, source comparison, postrun provenance, published review
and standing-authorized ready PR/expected-head main merge.
