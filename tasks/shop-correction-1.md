# TASK
Resume the same store-first task after the observed 30-turn exhaustion. Most implementation is present. Finish with targeted fixes and compact final handoff. Do not restart or redesign the feature.

# CONTEXT
Codex independently ran run_tests.gd: 30 tests, 1148 checks, 1 failure. Existing 20 tests and nine runtime tests pass. shop_painter.gd:237 references WHITE without defining it, so test_shop_layout_and_art cannot call Painter.paint and fails. CPU asset inspection has the same parse error. The prior invocation exit=1, subtype=error_max_turns, is_error=true is recorded, NOT success.

# REQUIREMENTS
1. Fix the undefined WHITE in shop_painter.gd. Review other newly written scripts for similarly obvious compile mistakes. Preserve passing tests and assertions.
2. UI main.gd _persist() only records save errors inside the normally hidden drawer, while _finish_service() always says '영업이 끝나 저장했어요.' even if save failed or save_locked. Return/track actual save outcome and show an error on the visible shop/result screen; never claim saved on failure. In-memory settlement may remain, but tell the user it wasn't saved. Add a meaningful UI QA case that forces saving to fail using an explicit QA subdirectory/file conflict, verifies user-visible failure and no false saved claim, and touches no normal saves.
3. Review actual counter geometry: portrait seat feet y=100 and bowls y=62, landscape feet88 and bowls54. These put bowls far behind seated bodies. Counter diners must visually reach bowls on the counter, and server endpoints should approach reachable serving spots. Place diners/stools/bowls coherently; preserve clear walk routes. Portrait plant at (64,150) intersects main door-to-counter path through (64,150); remove/move this obstruction. Add meaningful geometry assertions (not just duplicate constants) to prevent this mismatch. Codex will inspect actual asset previews after compilation works.
4. Finish pending current-behavior documentation and AGENTS history. All tests, real captures and device checks remain NOT RUN by you unless actually executed. No new proof images yet; historical screenshots must remain labeled old prototype.

# CONSTRAINTS
Same editable scope: game/**, AGENTS.md history, GAME_DESIGN.md and root README.md behavior only. File tools only, no Bash/network/git/install/subagents/credentials. Preserve unrelated changes and don't weaken tests. Do not touch tasks/** or evidence/**. Keep incomplete-day persistence policy and selected-recipe locking.

# ACCEPTANCE CRITERIA
No missing-constant/parse errors; no false save success; coherent diner/counter/bowl geometry; no plant in main path; existing domain/runtime assertions preserved; final report present.

# VERIFICATION
Report NOT RUN, with exact commands for Codex. Codex will run headless run_tests, actual main-scene frames, layout-only QA at both sizes, and CPU asset inspection (not full screenshots). Return compact handoff. No artificial rush or shortened design due elapsed time, but this is a targeted correction, not a fresh feature.
