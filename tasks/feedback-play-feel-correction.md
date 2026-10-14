TASK
Targeted correction of independently observed first-milestone verification failures. Preserve implementation, tests and assertions.

CONTEXT
Codex ran the current code. run_tests exited1:45 tests,41101 checks,3 failures (all portrait border color equality). QA script failed to parse at qa_capture.gd:292 because FileAccess.get_file_as_text() is not a static API; process exited0 without running QA, so it is NOT a passed check. Full logs are workspace work/feedback-tests-v1.log and feedback-layout-v1.log, outside Git. Import of the prior partial UI had no parse errors. Also the newly added work scenario awaits many layout/reachability operations during a 4-second real-time job and can race completion; it explicitly acknowledges this risk.

REQUIREMENTS
- Fix QA static file read using the file's existing _read_file helper (or FileAccess.open + instance get_as_text), keeping JSON parse/type errors explicit. No invented static API.
- Fix border expectation to account for Image RGBA8 encoding. Art.INK is floating point (e.g.0.149) and get_pixel is quantized (38/255); the image border is correct. Compare exact canonical RGBA8 encoded expected INK (e.g. encode INK in a 1x1 RGBA8 Image and compare its pixel), rather than changing art or removing the assertion. All three border checks stay; distinctness/motif checks stay.
- Make work QA deterministic: separately observe real frame-based progress/motion before completion, then freeze only the isolated main instance's automatic _process for the long busy/mutation/cancel assertions and screenshots, advancing work explicitly. Keep the real-time progress assertion and re-enable when needed. Do NOT pause production games or global engine time, change the four-second duration, loosen assertions, skip paths or automatically fall back to layout-only.
- Update history with observed failures and fixes, tests NOT RUN by Claude. No unverified success claims.

CONSTRAINTS
File tools only. Editable only game/tests/run_tests.gd, game/tests/qa_capture.gd and AGENTS.md. No UI/domain/evaluator/schema/global settings/Git/install/credentials or subprocesses. Use the existing original/resumed task context; don't restart the feature.

ACCEPTANCE CRITERIA
45-test suite and actual layout/native work/save/old flows run to completion, no parse errors, all current assertions preserved with correct representation and deterministic fixture timing.

VERIFICATION
Claude NOT RUN. Codex repeats failed checks and native captures after they pass.
