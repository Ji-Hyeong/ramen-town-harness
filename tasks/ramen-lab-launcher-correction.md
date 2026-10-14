Fix game/tools/build_local_apps.py only (and append AGENTS.md history) after native launch validation.

Ramen QA.app reached the actual OpenGL renderer, but LaunchServices provided an unusable current directory. Godot emitted getcwd errors, then could not open res://tests/qa_capture.gd despite the absolute --path. Generated launchers must explicitly cd into the validated project directory before exec. Use shlex.quote for the cd operand, check failure and exit nonzero (e.g. cd <quoted project> || exit 1). Retain all arguments, safe quoting, no overwrite behavior and no other changes. Mention the working-directory requirement in the script comment. Codex will generate fresh apps in a new output directory and retry.

No Bash/tools beyond file tools; limit 5 turns; compact handoff.
