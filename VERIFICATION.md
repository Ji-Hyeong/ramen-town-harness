# Verification record - 2026-10-13

## Final result: PASS

- User completed login and authorized CLI updates.
- Native CLI installed at /Users/ji/.local/bin/claude: 2.1.296. Homebrew CLI upgraded to 2.1.287; plain claude resolves to /opt/homebrew/bin/claude. No shell profile changes were made.
- The native CLI, explicit claude-sonnet-5-5 model, restricted mode, five file tools, dontAsk and 20-turn limit passed. See README.md for the verified invocation.
- Process exit code: 0. JSON: subtype=success, is_error=false, num_turns=6, permission_denials=[]. A nonempty completion report included the original nonce.
- Codex compared probe.txt and probe.expected.txt byte-for-byte: equal.
- Codex compared SHA-256 hashes of all nine existing project files against the pre-retry baseline: only smoke/probe.txt changed. Only three expected invocation response files were added. Documentation updates were made by Codex after this check.
- Login retry response: smoke/result-retry.json (obsolete default model 404).
- Old CLI explicit-model response: smoke/result-model-retry.json (fixture edited correctly, but error_max_turns; not accepted as full completion).
- Final accepted response: smoke/result-updated.json.
- At the time of the smoke test: no game code, Git mutation, push or deployment. Game-specific build/test validation awaits actual game requirements. The subsequent user-authorized publication preparation initializes a local repository; remote publication is a separate step.

## Initial attempt (historical; superseded by the passing result)

| Check | Observed result |
| --- | --- |
| Existing project | Current conversation directory contained no repository or application files. Created outputs/v0-harness only. |
| Codex installation | /opt/homebrew/bin/codex, codex-cli 0.147.0 |
| Codex authentication | codex login status: Logged in using ChatGPT |
| Codex model execution | Not separately tested; this check establishes installation and reported login state only. |
| Claude installation | /opt/homebrew/bin/claude, Claude Code 1.0.120 |
| Restricted execution | Initial diagnostic failed with EPERM on Claude local state; retried with approved normal Mac execution. |
| Claude noninteractive invocation | Command in README.md accepted; process exited 1. |
| Claude authentication | Failed: Invalid API key, Please run /login. |
| JSON handling | type=result, subtype=success, is_error=true, num_turns=1. Therefore subtype alone must not determine success. |
| File read/edit | NOT VERIFIED: fixture remains status=pending; authentication failed before tools ran. |
| Game implementation | None created. |
| Git/publish/deploy | No Git mutation, push or deployment performed. |

The original failed response is smoke/result.json. No credential values were read or printed. The initial authentication blocker was resolved by user login; final independent acceptance is recorded above.
