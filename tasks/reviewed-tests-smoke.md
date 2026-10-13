TASK
Verify the reviewed-tests profile without changing files.

CONTEXT
The completed connectivity fixture and expected file should be identical.

REQUIREMENTS
Read smoke/probe.txt and smoke/probe.expected.txt. Use Bash to execute exactly: cmp smoke/probe.txt smoke/probe.expected.txt

CONSTRAINTS
No file edits, other commands, credentials, networking, Git mutations or delegation. The only preapproved Bash command is the literal cmp command above. Do not edit AGENTS.md for this read-only test.

ACCEPTANCE CRITERIA
The actual Bash comparison exits 0. Do not claim completion based on reading alone.

VERIFICATION
Report the exact executed command, exit status, observed fixture status and nonce. If denied, report NOT RUN and the denial. Codex independently repeats the comparison.
