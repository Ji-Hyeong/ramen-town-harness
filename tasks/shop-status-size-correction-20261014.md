# TASK
Fix desktop scene-size regression introduced by dynamic status sizing, then return a compact handoff.

# CONTEXT
Your mobile text edits are present but previous invocation ended error_max_turns, exit 1, 11 turns before handoff. Codex ran layout-only QA: 1548 checks / 6 failures. All new score/status text assertions passed; only failures are desktop first/selected/active scene scale falling from 4 to 3 and area below 55% (960x456). New status height consumes the narrow margin needed for a 320x152 scene at scale 4. Portrait criteria passed.

# REQUIREMENTS
- Keep corrected one-line scores and full mobile status/note text. Fit desktop status within the existing available height so actual scene remains 1280x608 at scale 4 in 1280x800.
- Inspect measurement, padding and current label line heights. Remove excessive measurement headroom or use a compact responsive status arrangement if needed, but never hide messages or permit text overflow. Preserve complete instructions, especially save failure guidance. Exact geometry/text fit tests are authoritative.
- Preserve ALL existing area/scale/status/score assertions; no tolerance widening. No game or art behavior change.
- Add AGENTS history and final handoff with files/decisions/unrun status. No planning-only finish.

# CONSTRAINTS
Editable only the status presentation in game/scripts/ui/main.gd, targeted QA if legitimately needed (no weakening), and AGENTS history. File tools only, no Bash/network/Git/global/runtime changes.

# ACCEPTANCE CRITERIA
Both sizes keep readable scores/status, text fits its strip above nav, scene stays >=55%, desktop scale>=4 and portrait>=2, all prior reachability/touch checks remain.

# VERIFICATION
Do not execute tests. Codex independently reruns layout QA and user native capture. Report compactly without claiming unrun checks pass.
