# TASK
Make the harbor a repeatable research-material loop, connected to the existing recipe workbench.

## CONTEXT
The user prioritizes farming and meaningful menu experiments. Product Design is explicitly requested. The existing Godot game, region art, paper/red/teal palette, disclosure cards, and swipe-anywhere controls are the design source. Codex implements and verifies everything; no Claude calls until a new user instruction.

## REQUIREMENTS
- Preserve original supplier discoveries. Harbor sampling unlocks after its two suppliers and rank 2.
- Let the player choose roasted sardine broth or scallop topping, then a visible quantity/cost tradeoff. Departure 1,200 won; one free sample or three samples for an extra 600 won. No random reward or hidden fee.
- Share the single daily departure with market sampling and original trips; respect service/work locks.
- Collect explicitly once, preserve each active stage across save/restart, retain paid costs/day on retirement.
- Consume samples per actual ingredient portion only on successful tasting. Sales use ordinary costs at zero research stock.
- Show stock, actual flavor/cost/time differences, and a no-spend handoff to the corresponding existing lab section.
- Schema 13 validates old versions before migration, preserves exact original backups, validates receipt paths, stock conservation, supplier chronology, cross-route calendar, and retained sample-use witnesses.
- Use the generated transparent scallop asset for its icon and dish, preserving all previous dish pixels for old configurations.

## CONSTRAINTS
Editable: game/scripts/domain, game/scripts/ui, game/assets/ingredients, game/tests, game/docs, tasks, evidence, AGENTS.md, CLAUDE.md, README.md. No city/staff/story expansion. No normal save writes, iPhone install, credential access, Claude calls or destructive Git. Preserve prior builds and captures.

## ACCEPTANCE CRITERIA
Complete real supplier-unlock, trip, claim, repeated topping, tasting, sale and restart transactions. Reject invalid and duplicate operations atomically. Existing domain/input/layout checks must pass without engine errors. Fresh Mac renderer evidence is required for visual acceptance, never infer it from headless checks.

## VERIFICATION
Use a fresh imported snapshot and disposable absolute test-data paths. Focused harbor domain/scene tests plus existing domain, touch and layout checks. Prepare an exact fresh signed-engine QA app and request launch confirmation only after the build is concrete. Product Design flow audit uses fresh captures of departure, event, claim, workbench and result in landscape/portrait; typography, density, contrast, asset legibility and touch affordances are checked explicitly.
