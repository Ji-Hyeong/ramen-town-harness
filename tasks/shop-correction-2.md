# TASK
Finish targeted UI correction and final handoff for the SAME shop implementation; preserve all accepted behavior. The previous resumed 10-turn invocation ended error_max_turns before a final report, despite completing edits. Do not restart.

# CONTEXT
Codex independently executed final modified files: run_tests.gd -> 30 tests, 1593 checks, zero failures. Real main scene ran headless for 60 frames -> exit 0, no errors. CPU art inspection generated actual procedural backgrounds and runtime-driven people successfully (not a full UI screenshot). qa_capture.gd layout-only -> 1488 checks, exactly 2 failures: '스크롤 영역 안으로 들어오지 않아요: Card_dohyun', '... Card_maru'. Everything else, including save failure scenario, service start/finish/cancel/reload and shop screen area passes. Native UI tool currently reports Mac locked, so real rendered capture still unverified. Previous tests/QA are independent Codex executions, not Claude self-test evidence.

# REQUIREMENTS
1. Fix the actual feedback card reachability problem in the development drawer, particularly portrait 390x844. The current helper requires full card rect within its scroll viewport after ensure_control_visible. Do NOT weaken that assertion or hide the card. Make the layout/contents fit (remove unnecessary always-visible developer save path/footer space, compact excessive margins/text, move extended details into a user-opened section if necessary). Keep customer identity, rating, causal feedback readable at appropriate font/touch sizes.
2. Improve failure messages in _reachable to include viewport size and actual control/scroll rects so any remaining issue can be reproduced precisely. Preserve the full reachability criterion.
3. Root README and GAME_DESIGN still describe the old form-first version and 'concept features not implemented'. Update current behavior truthfully to match actual shop implementation. Historical screenshots explicitly old UI. Preserve long-term employee/story goals; not implemented yet. Clearly acknowledge accepted concept is isometric while current procedural shop is frontal, and density/details less than concept: direction acceptance is NOT final visual/play approval.
4. Append AGENTS history. Final compact handoff MUST be returned before turn exhaustion; no extra broad reading/refactor. Include files/decisions/NOT RUN self tests and independent test evidence supplied here. If unfinished, report concrete status promptly rather than emitting tools until turn limit.

# CONSTRAINTS
Editable game/scripts/ui/main.gd, game/tests/qa_capture.gd, game/README.md, game/VERIFICATION.md, game/DESIGN_DIRECTION.md, README.md, GAME_DESIGN.md, AGENTS.md history only. File tools only. No shell/network/git/install/subagents or credentials. Do not change runtime/domain/sales/save behavior or passing regression assertions. Avoid broader redesign.

# ACCEPTANCE CRITERIA
Cards fully reachable and readable in both sizes; no weakened assertions; accurate docs; nonempty final report.

# VERIFICATION
Self tests NOT RUN (file-only tools). Codex reruns only relevant UI QA, broadens tests only if new changes justify. Exact command: ../../work/tools/godot-4.7.2/Godot.app/Contents/MacOS/Godot --headless --path game --script res://tests/qa_capture.gd -- --qa-out=<new absolute work directory> --layout-only. This does not verify real renderer or iPhone device.
