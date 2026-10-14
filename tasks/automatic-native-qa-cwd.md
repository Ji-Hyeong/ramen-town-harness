TASK
Correct the observed native QA launch working-directory error, preserving passing QA and current helper safety.

CONTEXT
Codex built output ramen-native-qa-v4 successfully (Python 17 tests, actual headless import/export exit0) and launched the self-contained app through cua.getApp. It generated all 26 renderer captures, QA checks2698 failures0, actual exit_status0. However console.log contains many Godot getcwd(real_current_dir_name,2048) null errors and a shader-cache error. The launcher currently cd's into the Documents output RUN. In this app execution context that cwd cannot be resolved even though absolute file reads/writes succeed. Godot DirAccessUnix explicitly calls getcwd before absolute path operations (official source https://raw.githubusercontent.com/godotengine/godot/master/drivers/unix/dir_access_unix.cpp). We need a stable readable working directory; this is ordinary process configuration, not an access-rule workaround. Do not change permissions, TCC, security or game assertions.

REQUIREMENTS
- Run the bundled Godot with cwd '/' (read-only stable system directory). Keep ALL engine/PCK/log/QA output/data/tmp paths absolute and confined to the fresh authorized output directory. No writes under '/'. Remove unnecessary cd OUT/RUN; create files with their absolute paths. Fail explicitly if stable cwd cannot be entered/resolved. Record launch cwd in run diagnostics.
- Extend focused launcher integration test to assert the fake engine actually sees cwd '/', with hostile paths still inert and failure exit recorded. Keep all 17 existing criteria intact.
- Update the new QA README section to describe this configuration and record native v4 passed checks but engine errors still under correction. Add history line tests NOT RUN by Claude.

CONSTRAINTS
Only game/tools/build_qa_app.py, game/tools/test_build_qa_app.py, game/README.md, AGENTS.md. File tools only, no Bash/Git/security/global settings, no gameplay or QA edits. No HOME override. No suppression of log errors. No custom engine build.

ACCEPTANCE CRITERIA
Fresh build and supported app launch produce real 26 PNGs, checks2698/0, exit0 without getcwd errors. If shader-cache access remains a separate error, report it precisely; do not invent a user-data-dir CLI option (installed --help has none), suppress errors or widen permissions.

VERIFICATION
Claude NOT RUN. Codex runs focused tests, fresh build, native launch, actual output/error scan, PNG metadata and visual comparison.
