# TASK
Correct observed isometric rendering and departure defects, then finish the bounded art task with docs and handoff. Do not redo broad exploration.

# CONTEXT
Previous resume ended exit 1 / error_max_turns / 21 turns, not an authentication failure. Codex independently ran import (exit 0, no errors), tests (30 tests, 5366 checks, 8 failures) and two-size layout-only QA (1464 checks, 0 failures, exit 0). CPU compositions saved and inspected. All 8 failures say counter slices missing at server/patron columns, across both variants. The composition visibly collapses narrow furniture strips at the left edge and loses counter/facade geometry.

# REQUIREMENTS
1. Fix shop_painter.gd _emit_slices -> _push coordinates: get_region(Rect2i(sx,0,w,size.y)) makes a LOCAL-coordinate Image, but _push uses its used.position as global pos without adding sx. Preserve each slice's original global origin through the crop. Ensure CPU compose and ShopView both use corrected positions. Keep depth computed from the original world column. Existing assertions must pass; add a meaningful check that drawn slice extents coincide with the real counter/door, not collapse at x=0. Do not delete/relax existing geometry criteria.
2. Fix shop_scene.gd P_LEAVING route: the old screen-axis waypoint Vector2(door_out.x, exit_pos.y) is invalid for the tilted grid. For portrait it maps into the left wall/room after exiting the door. Use a shared logical sidewalk route projected through Layouts.proj; after door_out, remain outside ROOM_D and reach exit along the sidewalk. Add a regression that exercises actual Scene.build departure positions along progress and checks no re-entry/collision; don't test an unused hypothetical route. Keep ServiceSession timing/state untouched.
3. Finish original task docs and AGENTS history (auth recovery entry must be preserved). Current art is procedural isometric, but actual graphical playback and final user acceptance remain unverified. Report accurate canvas sizes, unrun tests and limitations. Don't claim the 8 failing checks passed until Codex reruns.

# CONSTRAINTS
Only original renderer/helper/art-layout-test/doc paths are editable, including existing shop_scene.gd. File tools only. No Bash, network, Git, credentials, subagents, runtime/domain/save/main UI changes. Keep existing acceptance tests, keyboard/touch controls and save behaviors.

# ACCEPTANCE CRITERIA
Counter/facade slices stay in their global image columns, staff/patrons/bowls align and depth order remains coherent. Actual departing patrons follow the exterior sidewalk without crossing shop walls. Existing regression/geometry/layout criteria retained. Final handoff is nonempty and explicitly distinguishes unrun checks from known results.

# VERIFICATION
You do not run tests. Codex independently reruns reviewed suite, layout QA, CPU compositions and attempts native visual QA after your changes. Return changed files and concise results/limitations. Max 10 turns; prioritize concrete corrections and handoff.
