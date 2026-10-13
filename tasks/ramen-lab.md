TASK
Implement the first playable Ramen Town recipe-development prototype in Godot 4.7.2 with typed GDScript. You are the implementation agent; Codex will review and run tests after checking your scripts.

CONTEXT
Read AGENTS.md, CLAUDE.md and GAME_DESIGN.md. The user authorized game development. iPhone is the first mobile target, but this deliverable runs on Mac and supports a portrait touch-friendly layout; do not claim iOS export or device verification. This repo has no game yet. Codex provided an OFL Korean font at game/assets/fonts/GowunDodum-Regular.ttf with its license; preserve these files.

REQUIREMENTS
- Create game/project.godot, a main scene, typed GDScript domain/UI/save services, meaningful headless tests and a concise Korean game/README.md. Put all game implementation in game/. You may update AGENTS.md only to append the required history entry. Do not edit root README or other harness artifacts; Codex updates them after verification.
- Gameplay: choose broth, tare, aroma oil, noodles and a topping (at least 3, 3, 2, 3, 4 distinct choices respectively) plus a controlled cook-intensity choice. Ingredients are data-driven. Show description and cost/time tradeoffs; no arbitrary universal best recipe.
- Create a named trial recipe, evaluate it for three distinct recurring customers with names/personality and concrete taste preferences. Ratings must be deterministic and have causal Korean feedback tied to recipe attributes/compatibility, not random generic compliments. Broth/tare/oil/noodle compatibility must matter. Evaluation is separate from UI.
- Recipe revisions: selecting a recipe from the notebook restores its ingredient IDs, price and cook choice; editing and tasting gives a new version with visible comparison to the previous version. Store immutable snapshots; later selection changes must not mutate prior results. Prevent accidental duplication and bound notebook growth (e.g. 30 records).
- Include a lightweight one-day sales simulation based on price, cost, prep time and the three customer reactions, reporting units, revenue, ingredient cost and net operating profit. Price must influence demand so expensive menus do not win automatically. One simulation is one day; make this explicit and show day count/balance. Never allow invalid/negative quantities or prices. This is a small lab/shop loop, not city construction or full employee/story systems.
- Save recipes, current selection, wallet/day and last feedback locally; load after restart with a visible status. Validate persisted IDs, ranges, schema version and structures. Handle missing save as a normal first launch and corrupted/unsupported saves visibly without silently overwriting them. Avoid lossy partial data acceptance and broad catch/fallback. Use a safe temp/backup or equivalent strategy for save writes.
- Normal builds use user:// saves. For development/QA, support an explicit --dev-data-dir=<absolute writable directory> command-line argument and display/document that dev save location; this allows sandbox testing without touching real save data. Tests pass their own isolated temporary path and clean only their fixtures. No credentials or arbitrary file scanning.
- Korean UI: warm ivory/paper, vermilion signage, dark ink, muted teal accents. Use bundled GowunDodum, original code-drawn ramen bowl/steam or simple vector art (no copyrighted assets). Clear visual hierarchy, generous touch targets (>=44px), informative feedback and a recipe notebook. Meaningful short reveal for tasting; respect usability and no blocking long animation. Make it feel like a small ramen atelier, not a generic dashboard.
- Responsive desktop 1280x800 and portrait 390x844. Use tabs and scroll containers so selectors, price, buttons and feedback remain reachable. Avoid clipping and horizontal scroll. Draw bowl to fit its allotted area. No implementation details in user-facing flows except the explicit developer save indicator.
- Include headless tests that actually exit nonzero on failure (do not rely on assert alone). Cover different customer preferences, compatibility tradeoff, pricing effect on sales, immutable history/revision, save/load roundtrip, invalid IDs/ranges and malformed/future-version save rejection. Use isolated data only. No external test packages.
- Provide an optional QA SceneTree script that instantiates the real UI and captures desktop and portrait screenshots to an explicitly supplied output directory, using the actual viewport renderer (run without --headless). It should also exercise select/taste/notebook/serve via the real UI handlers or signals and assert reachable controls/absence of horizontal overflow in portrait. Use stable names for key controls to enable review.

CONSTRAINTS
Minimal bounded feature, no install/network/Git mutations/deploy/subagents. Only game/** and AGENTS.md history are editable. No Bash tools for this initial implementation: Codex must review scripts before approving test execution. Do not modify provided font/license. Comments should explain non-obvious taste math, immutable history and persistence validation. Use proper typed values and no hidden errors. Do not claim unrun tests passed. Do not build a separate mock page or replace the Godot game with a web app.

ACCEPTANCE CRITERIA
Mac Godot loads with no parse/runtime errors. A player can select ingredients, taste, read differentiated feedback, revise and compare, sell a day and reload saved progress. Tests above pass. Desktop and portrait show readable Korean, full accessible controls, usable scroll/navigation and no horizontal overflow.

VERIFICATION
Codex has the binary at ../../work/tools/godot-4.7.2/Godot.app/Contents/MacOS/Godot relative to this repo, and will inspect executable scripts then run --headless --path game --editor --import, the test SceneTree script, and your real UI QA capture script. Save/capture paths are supplied explicitly in writable work directories. Report exact commands needed. Keep debug/file_logging disabled or use explicit --log-file to avoid default engine log writes outside the sandbox.

EXECUTION LIMIT
30 turns. If you run out, report remaining tasks for targeted continuation, do not restart. Use Read/Glob/Grep/Write/Edit only.

HANDOFF
Compact Korean report: changed files, behavior and key decisions, exact verification commands, NOT RUN checks and blockers. Do not paste full source.
