# TASK
Replace premade-only soup selection with raw-material broth development.

## CONTEXT
Human explicitly rejects completed broth being supplied as the main development loop. Official Ramen Sensei description includes soup/noodle creation, while current code only selects catalog broth and cooking modifiers. Prioritize raw-material experimentation within the accepted native visual language. Do not delegate to Claude.

## REQUIREMENTS
- New players begin with no completed broth; guide the first raw-ingredient blend, brew and explicit use in ramen. Reuse previously brewed recipes in later menus.
- Original bone/seafood/vegetable pantry with meaningful cost/flavor/preparation tradeoffs, repeated portions and rank-scaled capacity. Additional materials use actual supplier discovery gates; display precise sources.
- Focused native broth sheet: visible pot/ingredient portions, categories, details, clear method/cost/time, brewing progress, cancel and completed-product receipt. Whole-card scrolling and existing action feedback. Fixed primary action; comfortable text padding.
- Completed blend deterministically determines soup identity and actual ramen evaluation, per-bowl cost/time and visible appearance. Changing raw materials invalidates the completed draft. No fake score bonuses or instant progress masquerading as brewing.
- Persist unfinished blend and completed recipes, validate immutable recipe snapshots, and migrate schema1..15 without modifying old tasted records/scores/balances. New-game gate cannot be bypassed through direct taste or catalog choice calls. Old prepared menus remain usable.
- Charge brewing once on successful completion. Cancel/refusal/save failure must be handled explicitly; no duplicate products, partial charges or hidden sample consumption. Raw pantry uses established supply rather than forcing farming for every sold bowl.

## CONSTRAINTS
Editable domain/state/catalog/evaluation/config validators, connected native views/controller/tests, docs/evidence/AGENTS only. No phone install, Claude, credentials, unrelated city/staff/story features, destructive Git, normal player-save modification or asset replacement. Preserve previous folders and stash.

## ACCEPTANCE CRITERIA
Fresh start -> choose raw ingredients -> method -> visible brew -> explicit use -> noodle/toppings -> taste -> service -> disk restart. Compare at least three distinct blends; prove material/cost/time differences and a non-universal tradeoff. Test repeated inputs, cancellation, duplicate completion, rank/source locks, invalid nested configs, old-save fidelity and current finger input.

## VERIFICATION
Freeze current main/v15 source and run baseline domains in isolated paths before edits. Focused broth domain/config/save and native portrait/desktop captures, then relevant evaluator/service/save/touch regressions. Compare actual screenshots using accepted native references; reject clipping/black captures. Source-matched PCK, actual exits and engine errors are acceptance evidence. Publish ready PR and verified-head squash merge under standing user authorization after acceptance.

## OUTCOME
- Complete: fresh-game mandatory raw broth, nine original raw materials, three rank capacities, locked suppliers and real harbor research sampling, deterministic recipes and explicit use.
- Complete: frame-driven brew/cancel, archive, honest fee/stock accounting, UI feedback and raw source navigation; old prepared menus retained only through v1..15 compatibility.
- Complete: raw226/0 (fresh-only six research/rank3, service, sources and old bytes); historical129tests59458/0 with explicit v15 fixtures. Native235/0 + editor528/0 with52 actual PNG; touch49/0; flow577/0 and payoff427/0 layout-only; QA helper23/0. Every accepted process exits0, engine/script errors0.
- Complete: selected actual frames reviewed and13 published.336 game sources equal final-v5 snapshot/PCK2ee1d9234ddd4bbd3d6021460f344ba5f223233980e30db75896c1f2d83ba5c8; strict post-run vendor signature0. Evidence and archive paths recorded.
- Excluded: phone installation, raw noodle/seasoning manufacture, physical-device gameplay acceptance and complete campaign fun/balance. No Claude or normal player-save work. Publish accepted result under standing ready-PR/matching-head squash authorization.
