TASK
Prove noninteractive file reading and editing within this harness.

CONTEXT
This is a disposable connectivity fixture, not a game.

REQUIREMENTS
Read AGENTS.md, CLAUDE.md and smoke/probe.txt. Change only the status line from pending to verified. Preserve the nonce exactly. In your final report quote the nonce you read.

CONSTRAINTS
Only smoke/probe.txt is editable. No Bash, networking tools, credentials, other agents, Git mutations or other file changes.

ACCEPTANCE CRITERIA
The file contains the original nonce and status=verified, with no other modifications.

VERIFICATION
Read the edited file again and report its contents. Codex independently compares it to the fixture baseline.
