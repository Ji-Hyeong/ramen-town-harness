TASK
Bounded continuation of feedback-play-feel, after requested30 turns reached error_max_turns, exit1, is_error=true. Preserve the existing implementation; finish missing verification code/docs plus the exact review fixes below. Do not restart the feature.

CONTEXT
UI/art/tasting_work.gd changes are already present (main.gd ~362 added lines); no new tests or QA adaptations were written, and no successful handoff exists. Codex is importing the partial code to check parse errors. Read the original contract and current files. GAME_DESIGN.md priority table and first AGENTS history entry were written by Codex; don't overwrite them. Existing tests and QA tasting calls expect instant results and must be adapted without weakening assertions. Actual player files never used by tests.

REQUIREMENTS
- Finish meaningful run_tests/qa_capture tests from the original contract. Core old 42 tests keep existing checks. Add helper/UI tests for immutable start snapshot, finite time handling, single completion, cancel, busy guards and real manual save/corrupt-save lock/forced failure/reload. QA explicitly advance isolated work instances and capture preparation progress and manual-save state in each size. Add actual three portrait reachability and text-fit checks. Preserve all old layout/service/save/research assertions and tab order.
- Review fix: TastingWork.snapshot() currently returns the mutable internal dictionary. Return a defensive deep copy; verify caller nested mutation cannot alter it. advance() must reject nonfinite seconds (currently Infinity completes work despite the documented invalid-input handling); test no progress/completion for NaN/Infinity/negative.
- Review fix: start_tasting() silently skips the probe if load_from_dict(state.to_dict()) fails. Fail explicitly via _taste_refused with a clear error instead of continuing from an inconsistent state. Preserve all existing domain rules and no charge before completion.
- Add README instructions for 4-second progress/cancel/portraits/glyph-free shop/manual and automatic save semantics, limitations and exact unrun commands. Fix stale top research native-capture text. Update AGENTS history accurately: first run turn-limit, continuation written, tests NOT RUN by Claude. Don't claim screenshots or tests passed.

CONSTRAINTS
File tools only, no commands/Git/network/credentials/install/global settings or agent spawning. Editable only original contract paths. No domain/evaluator/schema changes. No rank/exploration features in this continuation. Minimal edits; no suppressed errors or relaxed QA.

ACCEPTANCE CRITERIA
Partial implementation completed with meaningful tests/QA/docs; actual Codex executions and native captures decide acceptance. Correctness of cancellation/charging/manual save/research/old service preserved.

VERIFICATION
Claude tests NOT RUN. Codex imports, runs test suite, layout QA, native app and visually reviews real current screenshots. Return compact handoff, pending checks and blockers.
