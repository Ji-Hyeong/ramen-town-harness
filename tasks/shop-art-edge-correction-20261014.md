# TASK
Correct one boundary assertion and return a compact handoff.

# CONTEXT
After slice/departure fixes, Codex ran 30 tests / 40404 checks / 1 failure; layout QA 1464 checks / 0 failures / exit 0; CPU compositions exit 0. Counter/facade now appear at correct global locations. Only failure: portrait facade:low@ left edge 0, expected -6.

# REQUIREMENTS
In run_tests.gd slice-extent assertion, inspect whether the expected projected edge -6 is legitimately outside the image. Painter draws to an Image of layout size, so clipped output cannot have negative x. Compare visible extents against projected geometry intersected with image bounds (for both sides), retaining tight tolerance and the counter/collapsed-at-zero detection. Do not widen tolerances or remove the assertion. If instead a real render defect exists, fix it and explain. Preserve all other tests/code.

# CONSTRAINTS
Only game/tests/run_tests.gd and AGENTS history editable. File tools only, no Bash/network/git/runtime changes. No unrelated edits.

# ACCEPTANCE CRITERIA
Assertion tests visible image extents correctly and still catches collapsed misplaced slice groups. No unsupported passing-test claim.

# VERIFICATION
Do not run tests. Codex reruns the suite. Briefly report exact correction and unrun status.
