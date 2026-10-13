Correct independently observed taste-balance defects in tasks/ramen-lab.md. Preserve the original scope and implemented UI/save behavior.

Codex ran all 19 headless tests: 428 checks, 3 failures:
- test_preferences_differ: hayoung scores rich=100 and light=100; the lighter recipe must be preferred.
- test_no_universal_best: all three customers selected the same first maximum; the scoring clamps too many combinations to 100.
- test_compatibility_matters: dashi+thick noodle is not worse for hayoung than dashi+thin noodle.

Fix the scoring/balance cause, do not relax these behavioral assertions or game requirements to hide the issue. Review the entire score distribution when selecting constants. The positive compatibility bonus must not erase substantial preference mismatch. Keep deterministic feedback consistent with scoring, and update math comments.

Codex reviewed tests/run_tests.gd: only isolated known test files are removed; no network/process execution. For this correction, you may run this literal command from repository root:
../../work/tools/godot-4.7.2/Godot.app/Contents/MacOS/Godot --headless --path game --log-file /Users/ji/Documents/Codex/2026-10-13/referenced-chatgpt-conversation-this-is-an/work/runs/claude-tests.log --script res://tests/run_tests.gd -- --test-data-dir=/Users/ji/Documents/Codex/2026-10-13/referenced-chatgpt-conversation-this-is-an/work/test-data/claude-ramen-lab

Do not run any other Bash commands, install, network, Git or deployment. You may edit game/** and AGENTS.md history only. If the command is denied report NOT RUN; do not expand permissions. Engine startup may show environment errors for user:// creation or system certificates, but tests use the isolated supplied path; distinguish these environment errors from game failures. Fix desktop default file logging being enabled despite [debug] file_logging/enable_file_logging=false by explicitly disabling its .pc feature override as appropriate; never suppress real game errors.

The real-renderer QA CLI aborted with exit 134 in Codex's execution environment, so visual verification will use native Godot; do not claim screenshots passed yet. Keep changes focused. Normally 10 correction turns, report remaining work if you need more.
