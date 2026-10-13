# V0 orchestration harness

## Roles and workflow
- Communicate with the user in Korean. This directory is a standalone harness; do not create a game until the user supplies requirements.
- Codex is Lead / Orchestrator / Reviewer. Claude Code is the primary implementation agent and sole writer of nontrivial code changes. Codex may write task contracts, instructions and verification fixtures.
- Before delegating, inspect repository state and preserve existing user changes. Start new work from main on a task branch without discarding changes. The initial publication creates the main baseline for this previously unversioned harness.
- Write a task contract containing TASK, CONTEXT, REQUIREMENTS, CONSTRAINTS, ACCEPTANCE CRITERIA and VERIFICATION. Include explicit editable paths and test commands.
- Invoke Claude serially in this project root using the command in README.md. Never run simultaneous writers. Never bypass permissions or widen access automatically after denial.
- Independently inspect actual files, git diff (including staged and untracked changes), and rerun relevant tests. Claude's completion message is not evidence of success. Without Git, compare before/after file contents or hashes.
- Require exit code 0, JSON subtype=success, is_error=false, a nonempty result, and no unresolved permission denials. Check all of them: a turn-limit failure was observed with is_error=false and exit code 0. A successful invocation is not equivalent to accepted implementation.
- On defects, issue a targeted correction with exact file, observed failure, expected behavior and verification. Repeat independent checks; after three unsuccessful corrections report the concrete blocker rather than loop indefinitely.
- No destructive Git, deployment, credential inspection or credential output. Claude must not commit or push. Codex may commit and push when explicitly requested by the user; repository visibility must follow the user's choice. Do not touch unrelated paths or user configuration.
- V0 gives Claude file tools only. Codex executes reviewed test commands and sends their results back. Add shell permissions only when the actual project requires them and the command's effects have been reviewed.
- Record project changes in the history section immediately.

## 프로젝트 변경 이력
- 2026-10-13: Created isolated V0 harness instructions and file-edit connectivity fixture. Game implementation is intentionally pending user requirements. Verification results are recorded in VERIFICATION.md.
- 2026-10-13: Added concrete version-compatible command template and independent acceptance procedure. Codex login confirmed; Claude invocation blocked by authentication error. File-tool verification remains pending login.
- 2026-10-13: User completed login and authorized CLI updates. Installed native 2.1.296 and upgraded Homebrew 1.0.120 to 2.1.287. Explicit native invocation with Sonnet 5.5, restricted file tools and 20-turn limit passed in six turns. Independent byte comparison and before/after hashes confirmed only the fixture changed. Updated README and acceptance rules; ready for game requirements.
- 2026-10-13: User selected iPhone as the primary mobile target and requested GitHub publication. Added Korean portfolio overview, game direction, selected response evidence and raw-log exclusions. Publication is authorized for Codex; game implementation has not started. Remote publication status must be verified separately.
