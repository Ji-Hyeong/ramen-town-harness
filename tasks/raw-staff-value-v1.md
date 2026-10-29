# TASK
Implement a reproducible actual-production raw-menu staff-policy audit: two fixed
menus x three policies x14real completed services,84daily saves/reloads total.

## CONTEXT
Clean main2e88c66. The raw-campaign pacing report only established reachability;
it did not compare workers. Current user asks sustained work until Codex's5hour
remaining quota reaches30%. First bounded bundle compares actual paired policies,
then uses findings for a separately scoped gameplay improvement. No balance change
or new worker/story/city system belongs in this audit.

## CLAUDE OWNERSHIP
Write ONLY game/tools/audit_raw_staff_value.gd (new SceneTree CLI tool).
Own exploration, design and implementation of that tool. Codex owns this contract,
independent runs/safety checks/source conservation/report/evidence/publication.
Serial writers; no other repo edits, UIDs, tests, AGENTS, Git or settings.

## REQUIREMENTS
- Start each scenario from production game_state.gd directly:30000/day1/rank1,
  no premade broth/noodles, no legacy migration/fixture or test-helper imports.
- Prepare the same two actual raw recipes before the first service in every
  scenario, using public manufacturing/completion/use/taste APIs. Light:
  kelp+ginger,standard broth; wheat/clear/thin/standard noodles,shio/scallion,
  nori,firm,9000. Rich: pork_bone+garlic,standard; wheat/clear/thick/standard,
  shoyu/garlic,nori,normal,9500. Human names <=20characters. Earn hayoung_basic
  and dohyun_basic through actual paid records, never inject research/progress.
- For each fixed menu compare none,kitchen_policy,hall_policy. Select exactly
  that actual selling record with public APIs before EVERY service; prove the
  settled menu/price/config is the intended one, not the most recently tasted.
- Run14actual begin_service -> active_session.run_to_end -> settle_service
  journeys per scenario. Do not substitute forecasts, Sim.simulate or st.serve.
  Each settlement advances exactly one day. No money/rank/XP/stock assignments.
- Earn rank2 from real conditions after3services. For worker policies, purchase
  staff_1 and hire the specified helper when actually eligible/affordable. Train
  basic once when its real public review permits it; no specialization/rank3,
  forced XP, extra capacity/menu investment or score/visit buffs. Observe actual
  staff experience/training and actual facility/hire/training expenses. If not
  eligible by day14 report that fact, not fabricated training completion.
- No-policy case buys/hires/trains nothing. Same setup/config/policy chronology
  within each paired menu. Report differences against that menu's none case;
  do not attribute different-menu profits to workers.
- Every day write to a NEW disposable day subfolder, reload production State
  through SaveService, compare complete canonical state before/after and continue
  using the restored instance. Preserve all14daily inputs/receipts per scenario.
- Output one JSON report with explicit scenario/menu/policy/config signatures,
  daily wallet/rank/units/revenue/cost/overhead/net, selected selling witness,
  actual helper/training state, action days/costs, totals and actual failed checks.
  Report current saved fields accurately rather than inventing unavailable wait
  statistics. Keep source states and metadata distinguishable from forecasts.
- CLI --audit-out=<absolute new folder>. Reject missing/relative/user://res://
  or already-existing output paths before any write. Never use live user://,
  overwrite existing folders, write outside the provided output root, or delete
  files. Fail loudly with nonzero exit on unexpected mutation/API/roundtrip error.
  Bound loops and failure handling; engine parse/failed scenario must not idle
  forever or silently count as a successful audit. A timeout guard is appropriate.

## CONSTRAINTS
Read/Edit/Write/Glob/Grep only; restricted/dontAsk/strict empty MCP. No Bash,
network/subagents/credentials/outside-project reads/commits/push/deploy. Never
edit production domain/services/UI/assets/save formats. Meaningful comments.
Do not create helper abstractions or tests that mirror the implementation when
actual end-to-end scenarios provide stronger evidence.

## ACCEPTANCE CRITERIA / VERIFICATION
Codex independently inspects the tool and executes it in a fresh absolute scratch
directory with the already-verified Godot engine. Six complete scenarios,84actual
settlements/whole-state disk roundtrips, consistent paired configurations, correct
cost/training receipts and explicit summary. Independently recompute reported
totals from saved receipts; test invalid/existing output safety without live saves;
prove existing419runtime files/66domain-services/125assets unchanged. Exact new
tool SHA/command/exit/logs/raw states archived. New runtime tests or native graphics
are unnecessary for an excluded tools/ audit that does not change the game.
Return compact API/changed file/decisions/UNRUN tests/denials. Max-turn30.

## ACCEPTED CLOSEOUT

Actual6scenarios/84services/daily disk roundtrips3038/0, independent read-only
Python -O6231/0. Raw order traces allow independent price/cost/wait/stars checks;
all84saved games are byte-identical before/after instrumentation. Seven rejected
output-path cases preserve fixtures; six semantic mutations rejected with exit1.
Claude initial39/request30+same-task correction7/request10 both success/exit0/no
denials; final owned tool hash preserved. Codex supplies independent verifier and
source/receipt checks. Existing419runtime/66domain-services/125assets/schema18
unchanged; no new runtime/native tests are needed for excluded tools. Report and
exact artifacts archived outputs/ramen-raw-staff-value-v1/private-task. Future
server role challenge is a separate NOT IMPLEMENTED task. Standing READY PR,
attach, expected-head squash and clean main synchronization follows acceptance.
