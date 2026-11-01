# Harness instruction history

Read the [active root instructions](../../AGENTS.md) and the current task first.
These snapshots preserve historical evidence, not active instructions or new
authorization. Do not load the whole archive into routine implementation context.
For a concrete historical question, search a named snapshot and read the relevant
entry only. Older relative links retain their original repository-root context.

| Snapshot | Original commit | Bytes | Scope |
| --- | --- | ---: | --- |
| [Accepted main](AGENTS-main-6e0cbb4.md) | `6e0cbb4463bdfb765c7dd54f68dfac2ce9d5a080` | 198519 | Full accepted root before compaction |
| [Pending PR 52](AGENTS-pending-pr52-d64586a.md) | `d64586aaf045d2fabd756f7e24c20e6ec2a49c35` | 201531 | Full feature-branch root; native acceptance was still pending |
| [Sales-loop headless](AGENTS-sales-loop-headless-932cb6b.md) | `932cb6b148e854a709c76c41ebca4801628e76e7` | 14065 | Full 12-entry root before the next compact history |

[Provenance](provenance.json) records exact commit, byte count and SHA256 for each
unchanged Git blob. The files overlap intentionally: neither history is truncated
or deduplicated. Keep future archives lossless and link them here. The root retains
current safeguards, project navigation, role/quota preferences and immediate history.

The root file became smaller by moving old records, not by measuring model tokens
or subscription quota. No percentage of service usage savings is promised.
