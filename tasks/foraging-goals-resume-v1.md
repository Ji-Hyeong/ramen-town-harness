# Resume only the remaining correction work

The correction reached its max-turn boundary: exit1/subtype error_max_turns,
num_turns11, no denials. Same session dac6475b-1be6-4b77-9738-7b7aa4389fa7.
Codex inspected the partial files: readiness/error changes and ordinary material
develop callbacks are present. Tests now CALL `_real_market_sample()` and
`_real_harbor_archive()` but these functions are NOT DEFINED, so the test module
does not compile. This partial state is explicitly rejected, not accepted.

Finish the two actual public-transaction test functions and reconcile existing
assertions with sample_ready/required_samples/explicit archive error. Verify the
board ready count uses sample_ready and busy source/develop callbacks are inert.
Do not redesign/rewrite the task or re-explore unrelated code. The original
correction contract remains active with the same three editable paths only.
foraging_plan_runner.gd is Codex-owned; do not modify it. It now dynamically loads
the test module and fails cleanly rather than idling on a parse failure.

No Bash, other paths, Git, credential or permission expansion. Tests remain NOT
RUN for Claude. Return a compact completion, exact remaining risks and unrun
command: Godot --headless --path game --script res://tests/foraging_plan_runner.gd.
