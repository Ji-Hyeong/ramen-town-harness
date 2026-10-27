# Targeted correction: appearance input and legacy safety

## OBSERVED FAILURES
Codex independently ran the written tests: exit0 but SCRIPT ERROR Parse Error, `The member Shader shadows a native class` at recipe_appearance_tests.gd:7. A zero process exit is not acceptance. No assertions ran.

The implementation handoff also identifies loss of the historical broth/tare/oil shift when only noodle_recipe exists. This is a real supported old-save/new-noodle case, not hypothetical. Invalid raw input is silently ignored and tested as success; the global error-handling rules require an explicit error instead.

## REQUIRED CORRECTION (same four owned files only)
- Fix the test parser error and run its body only after the SceneTree/root/control is actually ready. Tests remain NOT RUN by Claude. Do not add code-string/Shader.code.contains assertions that mirror implementation; verify actual defaults/material parameters and meaningful presentation outputs.
- Preserve the old soup/tare/oil shift in a mixed historical broth + raw noodle bowl while expressing its new noodle appearance. Do not replace the old soup with an arbitrary helper fallback. When only raw broth exists, preserve old noodle appearance. Keep all-legacy path identical.
- Pure profile returns an explicit error field for malformed/unknown raw ingredients/methods/formula rather than silently skipping them or treating them as crafted. Reuse existing raw catalogs' validation where practical; no domain changes. Valid configs return empty error. Callers report an explicit invalid-profile failure; no hidden success-shaped fallback. Tests verify invalid result/error and no mutation.
- Keep tests honest: scalar color distance is parameter proof, not proof of readability at phone size. Codex will inspect native pixels.

Codex is waiting and will not edit repo concurrently. Resume only this task's recorded session. File-only Read/Edit/Write/Glob/Grep; no Bash/Git/network/docs/assets/subagents. Return changed files and NOT RUN status.
