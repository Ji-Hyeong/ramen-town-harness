# TASK
Add one actual base-server role challenge, '두 메뉴의 점심', connecting two new
culinary revisions to actual two-menu operation and modest permanent mastery.

## CONTEXT
Clean maine962eaf after PR49 actual raw staff audit. First standalone probe on an
actually earned raw rank2 checkpoint expanded the shop, developed two structural
revisions and sold them:9bowls(5+4), wait1258/9=139.78, stars33/9=3.667, prices
9000/9500. No invented money/rank/stock. This proves an attainable witness, not
human difficulty/fun. Basic server is existing staff, not a new hire/NPC system.

## CLAUDE OWNERSHIP
Implement ONLY:
- game/scripts/domain/server_challenge.gd (new pure module)
- game/tests/server_challenge_tests.gd (new pure run(check:Callable)->void)
Codex owns GameState/schema19/Staffing effect, old18 migration/safety, native
staff-growth/controller/portrait integration, actual gameplay tests/QA/docs/Git.
Serial repo writers. No other files/UIDs/AGENTS/tests/Git/settings edits.

## PURE API / STATE
Use a small bounded state {start:{},attempt:{},completed_day:0}, like Chef's
existing challenge. Provide empty_state(),level(),review(),begin(),observe(),
claim(),parse() with explicit error/state results for rejected transactions.
Suggested signatures: begin(state,records:Array,day:int,next_id:int,rank:int),
observe(state,records:Array,day:int,completed:Array),claim(state,day:int),
parse(raw,day,next_id,rank,slots,discovered,records). Report your exact final API.
Review returns status(open/active/ready/mastered),met,rows,attempt,completed_day.
Do not implement effects or mutate GameState yourself.

## REQUIREMENTS
- Explicit free acceptance at rank2+, with exactly2distinct actual existing
  selling records, before new development. Host also requires actual expansion
  and2selling slots. Capture day/min_record_id and2bounded baseline id/config
  snapshots. No reset/reaccept or past-service/old-record retroactive credit.
- Qualifying attempts come ONLY from actual completed two-menu service after
  acceptance. No tasting, forecast, st.serve/analytical estimate or partial/cancel
  can grant proof. Host will invoke observe only on validated actual settlement.
  Empty start/single-menu events may return unchanged as known non-applicable
  events; malformed two-menu/runtime evidence must explicitly fail.
- Six conditions, all required in ONE actual service:
  1. Both menus tasted after acceptance:record_id>=min_record_id,tasted_day>=start
     day. Both configurations structurally differ from EVERY captured baseline,
     and from each other, ignoring price. Price-only revision does not qualify.
  2. Each of the two menus has>=3completed orders.
  3. Total>=8completed orders.
  4. Average completed-order wait<=150game seconds.
  5. Average completed-order stars>=3.5 (integer comparison star_sum*2>=units*7).
  6. Both actual prices<=10000.
- Derive each menu's units from actual completed order.record_id. Check IDs
  belong to the2provided records; sum actual waits/stars, never forecasts.
- Persist only latest failed attempt / first passing attempt. Ready/mastered
  proof is sticky despite later failed service or notebook deletion. Claim is
  explicit once only on a later day than attempt.day, no cash/XP transaction.
  level returns0/1. Defensive copies throughout; UI cannot edit progress.
- Bounded attempt stores actual2id/name/tasted_day/config/units and totals/day.
  max1000completed bowls per proof, waits bounded by Session.HARD_LIMIT, stars
  in1..5 each (zero totals only for zero orders). Units sums/unique identities,
  chronology/ids/name/config/supplier/rank/slot constraints must validate.
- parse strictly rejects unknown/missing shapes, fractional/bool/negative or
  impossible counters, wrong chronology, duplicate menus, inconsistent units,
  forged ready/mastered proof or mismatched surviving notebook records. Deleted
  notebook records may retain validated proof. No silent reset/default on bad
  data. Host defaults empty only for genuine older save versions (<19).
- Preserve actual raw broth/noodle provenance and process. Reuse DataCheck,
  RecipeEvaluator and established config normalization; no new balance formula.

## EFFECT / INTEGRATION CONTEXT (CODEX OWNED)
After claim, next-service carry/return timing is20%shorter AFTER helper rounding,
rounded up/min1. No taste/demand/wage/employee-slot boost. Optional staffing.server
metadata only when mastered, preserving exact old snapshot shapes when0. Schema19
adds top-level server_challenge; v18 gets empty, no fabricated completion. Code
integration and actual after-claim effects/migration proof are Codex's work.

## TESTS / ACCEPTANCE
Pure focused tests: real evaluator-compatible two configurations and completed
orders; all6condition boundaries incl price-only/no-old-credit/mixed baselines,
each-menu counts/integer averages, unknown order IDs, sticky proof, once claim,
deep-copy/input immutability, active/failed/ready/mastered parse and malformed
states/chronology/config/record binding including deleted notebook preservation.
Tests may construct explicit pure fixtures; do not claim these are earned player
progress. No filesystem writes. Codex runs actual rank2 raw-service witnesses and
native acceptance independently, including true old18 saves and replay rejection.

## CONSTRAINTS
Read/Edit/Write/Glob/Grep only; restricted/dontAsk/strict empty MCP. No Bash,
network/subagents/credentials/outside-project reads/Git/push/deploy. No other
production changes, assets, stored fields or implicit rewards. Meaningful comments.
Return changed paths/exact API/state fields/decisions/UNRUN tests/denials. Max30.

## OBSERVED REWARD REVISION (Codex integration, 2026-10-29)
The first actual paired runtime showed the10% post-helper ceiling erased every
inner-seat benefit with a basic-trained hall helper. Revise ONLY the new server
mastery to20% (post-helper ceil/min1), preserving all old unmastered timings,
qualifications, wages, recipe/taste/demand rules and the six challenge conditions.
Repeat the same actual paired cases; do not reroll menus/days to invent success.
The former v4 native-app request is superseded; prepare a new exact app and ask
its action-time launch approval only after focused/layout/regression checks.
