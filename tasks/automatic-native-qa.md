TASK
Build a repeatable, local-only macOS QA application with bundled game resources so Codex can launch it through the supported Computer Use app launcher and inspect result files without asking the user to execute terminal commands.

CONTEXT
The user explicitly requests automatic graphical QA. Direct Godot GUI shell invocation in Codex exits 134 before logging. The existing thin Ramen QA.app launched by Computer Use reaches OpenGL but cannot read the external Documents project (getcwd null, res://tests/qa_capture.gd missing). Do not bypass sandbox, OS privacy, Gatekeeper or approval rules. A normal self-contained local development app is the next supported route. Godot officially supports --export-pack and --main-pack. Official docs: https://docs.godotengine.org/en/stable/tutorials/editor/command_line_tutorial.html and exporting_projects.html. Use the installed official Godot binary; no downloads or new global settings.

REQUIREMENTS
- Implement a stdlib-only helper game/tools/build_qa_app.py. Explicit absolute --godot, --project, --output-dir. Refuse existing output directories, never delete/overwrite source or user data. Create a self-contained local QA .app in output-dir with the verified engine copied into its bundle and a game PCK produced using headless import/export-pack. Use a temporary project snapshot and export preset under output-dir if needed; never modify source project or global engine settings. Resources are part of the authorized app, not a shell route around an access denial. Bundle only runtime assets/scenes/scripts/tests, necessary imported resources; exclude Git, docs, tools, evidence, credentials and unrelated files.
- Reuse current tests/qa_capture.gd unchanged. The app runs real rendering (never automatically fall back to headless/layout-only) and saves fresh captures and isolated QA data under output-dir. Record actual process exit status and log in output-dir, even on failed launches when execution reached the launcher. Report preparation failures explicitly and retain diagnostics.
- Use safely quoted shell arguments or argument arrays; no eval or shell interpolation of unchecked values. Bundle is local development only, not signed/release/iOS. Keep standard permissions and no network, install, git, privilege or persistent service.
- Add focused stdlib tests in game/tools/test_build_qa_app.py for unsafe/relative paths, overwrite prevention and quoting/scope as appropriate; avoid fake success or implementation-mirroring tests. A missing native runtime is a clear error.
- Document preparation, supported app launch and independent completion checks in game/README.md. Codex owns native execution; do not claim the app works before observed captures and result status.
- Add an immediate history entry describing implementation and unrun checks in AGENTS.md.

CONSTRAINTS
Editable paths only: game/tools/build_qa_app.py, game/tools/test_build_qa_app.py, game/README.md, AGENTS.md. No gameplay or QA assertions changed. Do not run commands (file tools only); do not commit/push/deploy. Do not inspect credentials, modify security controls or use terminal UI automation. Do not widen permissions after denial. Keep report concise; no source dump.

ACCEPTANCE CRITERIA
Codex reviews helper, runs focused tests, builds fresh app, launches through supported native app tool, then independently confirms 26 fresh real-renderer PNGs at 1280x800/390x844, QA failures=0, real exit status=0, and correct screenshot contents. Preparation success alone is not graphical success. If OS/tool denies access, report actual blocker without evasion.

VERIFICATION
Claude: NOT RUN (file tools only), supply exact preparation/test commands.
Codex: focused Python tests and headless package preparation; app launch with cua.getApp(absolute app path); inspect exit-status/log and image metadata/contents. Inspect repo state for unrelated edits.
