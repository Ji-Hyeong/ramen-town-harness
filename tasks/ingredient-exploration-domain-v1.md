TASK
Complete DOMAIN/PERSISTENCE/DOMAIN TESTS only for tasks/ingredient-exploration-v1.md. Read that contract, AGENTS.md and CLAUDE.md. Do not edit UI/qa_capture yet. Current base main330e2f58 is accepted, clean feature/ramen-exploration-v1. Codex will independently test then delegate the UI/art/QA phase separately.

CONTEXT
Three rank-gated regions, at most1 departure/day, paid departure and2 durable choice encounters, permanent6-ingredient discoveries, explicit reward receipt/retire, no finite consumable inventory. Keep all old data/evaluation and schema1..3 history/growth. Do relevant analysis and choose minimal coherent APIs.

REQUIREMENTS
Implement the umbrella's catalogue, availability gating, state machine, atomic charges/rewards/busy locks, serialization/migration/permanent backup and meaningful domain regressions. Domain start/advance/finish/retire must reject service busy; UI will additionally guard tasting. Domain state machine must have an explicit result boundary so premature/repeated finish cannot reward. Document branch choices and costs, validation policies and computed availability. Retained old configurations and research fixtures stay valid; preserve existing tests but make genuinely old save fixtures old schema rather than assuming current schema3. All new tests need actual bodies, not just registry entries. Keep tests bounded; new catalogue entries must not explode existing enumeration without justification. Domain methods return honest errors, defensive copies and exact pre/post transaction effects.

CONSTRAINTS
Only game/scripts/domain/*.gd, game/scripts/services/save_service.gd, game/tests/run_tests.gd, AGENTS.md and game/README.md (domain API/NOT RUN notes). No UI/art/qa_capture/app tools/scenes/project settings/tasks/old evidence. File tools only, no Bash/credentials/Git/network/delegation. Detailed precise comments on persisted progress, reward idempotency, migration and locks. No runtime test execution available.

ACCEPTANCE CRITERIA
All domain behavior and tests complete, no missing registered test bodies; save migrations/backups integrated. UI remains explicitly pending, no playable/renderer acceptance claim.

VERIFICATION
Codex independently runs import/full tests/old-save probes. Return a compact handoff with changed files, exact public API names/structures, all3 region fees/rank/encounter paths/rewards,6 ingredient IDs/availability, save shape/migration/validation/history bound, new test count and NOT RUN commands, remaining UI integration and risks. Work within30 turns; if stopped, preserve partial files and report a specific continuation, do not restart the full task.
