# Harbor flow design verification

final result: blocked

## Source and target
- Existing native Godot project and accepted paper/red/teal controls are the design source.
- Visual reference opened: game/docs/exploration-screenshots/portrait_35_exploration_harbor.png (390x844, old supplier-trip state). This is a style reference, not current-run audit evidence.
- Intended current implementation: game/tests/harbor_foraging_ui_tests.gd, landscape1280x800 / portrait390x844, native SubViewport density1.
- Current implementation screenshot path: pending exact fresh QA app execution.

## Comparison and findings
No visual pass or source/implementation comparison is claimed. No fresh current-run screenshots exist yet.
The old supplier-trip state and the new repeat-sampling flow are intentionally different; their
screens must not be described as a pixel-identical recreation. Typography, spacing, palette,
asset legibility and copy will be reviewed from the new renderer captures.

## Flow checks to capture
1. Compact locked harbor goal after usable market.
2. Ingredient card: visible stock, icon/chevron, expanded flavor/cost/time.
3. Departure/travel and explicit target choice.
4. Quantity/extra-cost decision and unaffordable/capacity feedback.
5. Waiting reward, restart, explicit collection and daily lock.
6. No-spend handoff to existing workbench and repeated scallop dish.
7. Cooking/cancel and completed tasting with actual sample consumption.
8. Zero-stock sale, next-day revisit and sardine-broth dish.

## Evidence limits
Headless scene checks validate transitions/layout and do not capture rendering. Fresh Mac native
execution is required before this report can pass. iPhone physical input, VoiceOver, dynamic
type and subjective fun remain separate; screenshots cannot establish accessibility compliance.

## Implementation checklist
- Complete domain, migration, gesture and responsive regression checks.
- Freeze exact source/PCK and prepare one current QA app.
- Obtain the action-time confirmation required for this locally generated app, then execute via CUA.
- Inspect fresh saved screenshots and write step-linked Product Design notes.
- Fix any material findings, recapture changed states, and update this report before merge.
