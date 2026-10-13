TASK
Add a small local macOS launcher builder for the existing Godot prototype and QA script. Do not change gameplay.

CONTEXT
Codex independently reran headless tests: 20 tests, 446 checks, 0 failures; the actual main scene also ran headlessly for 60 frames without game errors. Graphical Godot from the restricted shell exits 134 before producing output. Native Godot launched through the computer-use app interface works, but editor run controls did not respond reliably. We need native .app launch entry points for the existing game and existing QA SceneTree script, using the official verified editor executable already downloaded. This is a local dev convenience, not an exported, signed or distributable game binary.

REQUIREMENTS
Create game/tools/build_local_apps.py (stdlib only) and document it in game/README.md.
Inputs: explicit absolute --godot executable path, --project path, --output-dir and --data-dir; also --qa-out for QA screenshots. Refuse missing executable/project, non-absolute paths, outputs outside the supplied output directory, and pre-existing .app destinations (do not recursively overwrite/delete anything).
Build two lightweight app bundles in the supplied output directory: Ramen Atelier.app and Ramen QA.app. Each has a valid minimal Info.plist, a locally unique bundle identifier and an executable shell launcher under Contents/MacOS. Each launcher execs the trusted specified Godot binary with the project path, a log file inside output-dir, explicit developer save path, and (for QA) --script res://tests/qa_capture.gd plus --qa-out. Use proper shell quoting (shlex.quote), no eval, no credentials/network/install, no HOME/PATH changes, no GUI automation in the script. macOS launch through the native app tool will execute these bundles; the builder itself only writes files.
The script should create necessary explicitly supplied output/data directories and only two new app bundles; no copying the engine or editing global config. Explain that iOS and a standalone Godot export still require future work.
Keep existing engine --headless checks and QA script intact. Append AGENTS.md history. No other changes.

VERIFICATION
No Bash in this call; Codex reviews the builder then runs it with known absolute workspace paths. Report exact command and files, NOT RUN checks. Limit 10 turns and concise Korean handoff.
