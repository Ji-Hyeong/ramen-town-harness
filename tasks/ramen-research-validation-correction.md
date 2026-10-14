# TASK
Correct two independently reproduced research consistency defects, and retain full-card QA coverage. Targeted continuation of the same research feature.

# CONTEXT
Initial Claude invocation completed exit 0, success/is_error=false, nonempty handoff, no denials. Codex independent import had no errors; 40 tests / 41007 checks / 0 failures / exit 0; layout QA 2574 / 0 / exit 0. A real schema-v1 save generated before your implementation (2 records, day 2, wallet 88300) loaded and roundtripped without changing prior values. An extra diagnostic adding entire Research_<id> cards to both existing reachability loops also passed 2646 / 0.
However, the independent consistency probe failed twice: default recipe tasted at price 7500 fails maru_basic, but (a) Research.check with the same config and fabricated scores.maru=99 returns all_met=true, and (b) adding a Research.make_entry('maru_basic', that unmet retained record, day) to research.completed lets load_from_dict accept it. The fixture uses only normal public APIs and does not alter private fields.

# REQUIREMENTS
- In the actual Research.check/submission/UI path, freshly calculated existing Evaluator results must determine score conditions, or a mismatch against persisted record scores must be rejected explicitly. The evaluator is already called but its actual scores are currently ignored in favor of the passed scores. Do not change evaluator balance or let arbitrary stored scores complete a request.
- In parse_progress, when the referenced immutable recipe remains in the notebook, validate that it really satisfies that completed request using authoritative evaluator values, in addition to current identity/day/reward checks. Reject an impossible completion atomically. Keep legitimate completed progress after record deletion: do not add a live-reference requirement or invent claims of tamper-proof deleted-record receipts. This is data consistency, not save encryption/authentication work.
- Add meaningful regressions for fabricated in-range scores and a valid-shape completion tied to a retained unmet record. Check rejected load leaves target fully unchanged, successful normal completion/reload still works, and deleted-recipe progress remains valid. Do not weaken any tests.
- Update both existing research reachability loops in qa_capture.gd to include the complete Research_<id> cards, not just their individual title/status/condition/button controls. Codex's identical extra diagnostic already passed; preserve it as regression coverage.
- Update AGENTS history and compact handoff. Do not claim tests have run.

# CONSTRAINTS
Editable only ramen_research.gd, game_state.gd if needed, research tests in run_tests.gd, the two reachability lists in qa_capture.gd and AGENTS history. File tools only; no Bash/network/Git/credentials/renderer/other gameplay changes. Preserve all six conditions, reward quantities and valid v1 migration.

# ACCEPTANCE CRITERIA
Unmet configuration cannot qualify merely through fabricated stored score values; retained recipe completion must match real conditions; failed loads/claims do not mutate state. Normal rewards, unlock, deletion and migration still work. Whole request-card reachability is asserted.

# VERIFICATION
You run nothing. Codex independently reruns expanded suite, actual v1 migration fixture, consistency probe and two-size layout QA before native capture. Return exact changes and unrun status. Max 20 turns, compact handoff.
