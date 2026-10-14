TASK
Short READ-ONLY review of Codex's contest persistence helper, concentrating on unreachable accepted saves / valid saves wrongly rejected / repeat rewards. Report in KOREAN. User authorized adaptive distribution; Claude scoring helper is implemented and independently passed100 checks. Codex integration currently passes87 tests/50022 checks, but this is not proof of every parser invariant.

READABLE PATHS
game/scripts/domain/contest_progress.gd (entire new small module), ramen_contest.gd (your previously written scoring/catalog definitions), game_state.gd ONLY relevant new enter_contest/claim_magazine/load integration if needed. No full test/log/repo scan, credentials, Bash, file edits, delegation or settings. Read/Glob/Grep only, maximum8 turns.

CONTRACT
One paid entry per day, rank/day gates. Medals0..3, only improvement prize delta. Gold locks future entries. Latest12 attempt receipts; all3 best-medal receipts retained; best only changes when medal improves (not same-medal higher score). At >=silver a finite one-time magazine claim snapshots the best at CLAIM TIME; claiming after a later gold must feature that later gold, while a past claimed silver remains valid after later gold. Entries/deleted-menu snapshots remain valid with authoritative config rescoring, discovered ingredients must precede entry. Parse all before committing state. Earlier schemas migrate empty without rewards.

FOCUS
Check best/history/article chronological consistency including pruned history and attempts counters, original best snapshot legitimacy and magazine snapshot best-at-claim boundary. Look for concrete minimal mutated persisted states. Do not run anything or weaken tests. Return actionable findings with line/location, trigger and consequence; if none, explicitly say so and unverified execution limitations. Codex assesses and implements any correction.
