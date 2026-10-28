# TASK
Add three meaningful material-sharing encounters to repeat farming, one per
region. Connect them to three later cross-region culinary goals in a separate
Codex integration. Human asks to continue remaining development until usage limits.
This first bounded content bundle is encounters+cross-region experiments, not the
entire remaining campaign or a new ingredient/rarity system.

## CONTEXT
Start clean main81db0ad/403source schema18. Current sample_foraging is a strict
two-choice ledger shared by market/harbor/mountain, each with two sample IDs.
Old targets map to spec.ids by array index; appending a story target needs explicit
ingredient_hint mapping. Existing save/history replay must stay exact. Keep all
original target/quantity IDs, costs, quantities and existing supplier/rank/day locks.
No user save access, schema/field reset or invented rewards.

## CLAUDE OWNERSHIP
Edit ONLY:
- game/scripts/domain/sample_foraging.gd
- game/scripts/domain/market_foraging.gd
- game/scripts/domain/harbor_foraging.gd
- game/scripts/domain/mountain_foraging.gd
- game/tests/sample_encounter_tests.gd (new, run(callback:Callable)->void)
Codex owns RecipeDirections cross-goals, goal/category/native exploration UI,
GameState integration if strictly necessary, independent runners/native/save
compatibility evidence and docs. Serial repo writers; don't modify other paths,
UIDs, AGENTS/CLAUDE, assets, GameState, tests or Git.

## REQUIREMENTS / REAL CONTENT
Append ONE new story target after each region's two original targets. Same
two-step path/stage/receipt shape; no third phase or schema change. Target has a
short actual situation plus custom follow-up title/text and two explicit outcomes.
Use optional target-level quantities (or an equivalent small clear catalog field)
whose rows can specify a different ingredient from that target's hint. All
ingredient IDs must belong to the same region. Original generic quantities still
work byte-equivalently for original paths.

1. Market target id="market_group_buy", title="마감 공동구매". Merchant shares a
   closing lot; choose sesame in small portions or fund citrus bulk preparation.
   - id="share_sesame_two": oil_roasted_sesame2, additional0.
   - id="prepare_citrus_five": topping_citrus_peel5, additional900.
   Default ingredient_hint sesame. Base departure1000 unchanged.
2. Harbor target id="harbor_shared_catch", title="새벽 어획물 나눔". Split a mixed
   catch; choose a small sardine lot or pay for a larger scallop lot.
   - id="sort_sardine_two": broth_roasted_sardine2, additional400.
   - id="sort_scallop_five": topping_scallop5, additional1400.
   Default hint sardine. Base departure1200 unchanged.
3. Mountain target id="mountain_shared_mill", title="제분소 공동 주문". The farm
   groups orders; choose bulk buckwheat flour or a smaller grilled mushroom lot.
   - id="mill_buckwheat_five": noodle_buckwheat5, additional1800.
   - id="share_shiitake_two": topping_grilled_shiitake2, additional500.
   Default hint buckwheat. Base departure1600 unchanged.

No random/drop rarity, fake timing/quality difference, new staff/stock currency,
day rotation or content unlock. Briefs must show ingredient/quantity/extra cost
before committing; narrative1short sentence, not paragraphs. Original min_amount
stays2market/1others; max_amount becomes5. Old paths retain all exact effects.

## TRANSACTION / SAVE CONTRACT
- choices/outcome/active_view return defensive copies. Outcome replays known
  target then its own valid second choice only. Wrong target-specific choice,
  unknown paths/length/fees/ingredient/amount/stage are rejected. No fallback to
  a different reward or silently swallowed malformed state.
- First target and its live UI availability must consider reachable specific
  outcomes: a new event can be selected if ANY SAME outcome is both affordable
  and fits stock. Don't reject merely because its hint ingredient is full; don't
  combine affordable-but-full option with unaffordable-but-fitting option.
  Original targets have the same behavior as before. Correct final choice checks
  actual ingredient/amount before changing money/path. No early samples.
- Preserve20stock cap, shared one departure/day, supplier/rank/busy guards, explicit
  finish, one-time reward, retire rules, tasting-only sample use and selling at0.
- Parse both old18 active/claimed/retired/truncated-history shapes and new paths
  without altering existing saved values. Exact fee/amount replay, conservation,
  first-day chronology and next-record use bounds remain enforced atomically.
- Old300000 lifetime counter bound assumed max3/day; five/day can legitimately
  exceed it before the existing99999-game-day limit. Adjust only the necessary
  lifetime counter bound to the actual max5/day and keep stock/day/history
  constraints, with an explicit comment and bounded high-counter regression.
  This is no permission for arbitrary huge counters or weaker history replay.
- No persistent field additions and no migration that fabricates old quantities.
  Keep original spec.ids exactly2, original targets/quantities exactly unchanged
  apart from appending new target/data and raising truthful max_amount.

## FOCUSED TESTS
run(callback) pure/in-memory only, no filesystem writes. Cover all6new outcomes,
original paths equivalence, actual public GameState transactions (fixture.ready
helpers allowed), exact fee/extra/deferred claim/one-time claim/retire and day
locks. Capacity on cross-ingredient choices, same-option affordability+capacity,
partial/result/claimed save parse/whole-value restore, bad path/fee/count/ingredient
or stage atomic rejection, truncated history and legitimate lifetime>300000.
Do not replace existing suites or prove transactions with injected wallet/rank/
stock. Focused pure boundary fixtures may construct explicit conserved ledgers,
clearly distinct from actual public acquisition tests. Meaningful comments.

## CONSTRAINTS / VERIFICATION
Read/Edit/Write/Glob/Grep only; restricted/dontAsk/strict empty MCP. No Bash,
network/subagents/credentials/global settings/outside reads/Git/push/deploy.
Denied operations do not authorize widening permissions. Tests are NOT RUN by
Claude. Return changed paths, real decisions, UNRUN tests, denials and assumptions.
Codex independently reviews/diffs/runs actual old-v18 compatibility and new native
journeys at390x844/390x750/1280x800 with isolated data and exact frozen sources.
Actual paid cross-region recipes must satisfy the three added directions rather
than hand-written expected profiles. Keep original assets/phone/live saves/old
folders/stash. READY PR/attach/exact-head squash/local main sync after acceptance.

## ACCEPTED IMPLEMENTATION / CLOSEOUT

2026-10-29: Implemented and independently accepted. Claude's5owned files remain
unchanged after handoff. Codex integrates3cross-goals,5+3category board, actual
pictured outcome cards/raw fish+flour depiction and concise combined status.
No GameState/schema/new ingredient/art modifications. Final409source pack
7cb518a4823fd55b2bc91a10cb78e71a9d9daf537d49d6dcfaab7c6f28d10eca.
Native4567/0/151PNG across exact documented v5+v3; final pure1952/0;
historical129tests59458/0;27real old18fixtures190/0 + fullJSON equality.
Genuine new-game progression293/0 + paid cross-goal continuation72/0,
22daily disk reloads, no legacy supplies/progress injection. Not human-time/fun QA.
See evidence/foraging-encounters-v1.json and published actual originals.
READY publication/expected-head squash/local-main sync follows under standing authorization.
