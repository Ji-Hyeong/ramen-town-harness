TASK
Targeted review correction to automatic-native-qa. Preserve the self-contained QA app and file-only scope.

CONTEXT
Codex reviewed the helper before execution. The current helper overrides HOME in isolated_env and the shell launcher; active developer instructions explicitly forbid repurposing HOME. Godot portable mode (_sc_ marker next to its .app) can put editor_data under the fresh output directory instead. Source Godot is currently portable beside work/tools/...; using it for preparation can update its shared editor_data regardless of HOME. Also project.godot can be a symlink and is copied before link validation, and writing FAILED.txt currently uses silent except OSError: pass.

REQUIREMENTS
- Do not override HOME, home or CODEX_HOME anywhere. Use Godot's normal portable self-contained configuration: copy the verified engine bundle under output-dir before running its headless import/export; create the _sc_ marker beside that copied app. Use the copied engine for preparation and runtime. Keep all generated caches under output-dir. Preserve the existing caller's HOME if it must be present, never change it. TMPDIR/XDG scratch paths may remain scoped; remove misleading isolated-home claims/tests.
- Reject symlink project root and project.godot before copying/reading source content. Keep output overlap checks and allowed-folder link refusal.
- If diagnostic writing fails, explicitly include the diagnostic-write error in the raised error; no silent pass.
- Update focused tests for source engine content unchanged, portable marker/copied executable and no HOME override, symlink project.godot refusal, explicit diagnostic error if practical. Update the existing new README section and add a history line accurately naming tests NOT RUN.

CONSTRAINTS
Editable: game/tools/build_qa_app.py, game/tools/test_build_qa_app.py, game/README.md, AGENTS.md only. No commands, no Git/security/global settings, no gameplay/QA changes. Do not copy unrelated changes from Codex into your report.

ACCEPTANCE CRITERIA
No HOME override, preparation/runtime use private copied portable engine, symlink source refused, no silent diagnostic failure. Codex then runs tests and fresh real preparation/native capture.

VERIFICATION
Claude tests NOT RUN (file tools only). Codex runs the Python tests, fresh app build and supported native launch; actual result log/exit/PNGs decide success.
