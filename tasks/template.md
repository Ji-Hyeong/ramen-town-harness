TASK
Describe the requested implementation.

CONTEXT
Explain existing behavior and why it must change.

REQUIREMENTS
List concrete required behaviors and explicit editable paths.

CONSTRAINTS
Minimal changes; preserve unrelated work; no commit, push, deployment, destructive Git or credentials. Claude owns relevant exploration, detailed design, implementation and meaningful test writing. Specify profile: file-only or reviewed-tests. Do not expand scope on denial.

ACCEPTANCE CRITERIA
List observable success conditions, including regression cases.

VERIFICATION
List literal preapproved commands, working directory and expected outcomes. Codex reviews executable scripts before granting permission. Claude runs permitted self-tests; Codex independently runs acceptance/regression checks proportional to risk. Mark unavailable checks NOT RUN.

EXECUTION LIMIT
Normally 30 turns for a bounded implementation. Split larger work. Turn limits are not token budgets. No automatic full-task retry.

HANDOFF
Changed files; key behavior and decisions; exact test commands, exit status and outcomes; unrun checks; blockers. Keep the report compact, without full source or successful test logs.
