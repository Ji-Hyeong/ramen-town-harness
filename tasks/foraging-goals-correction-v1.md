# Targeted correction: sample readiness is not permanent discovery

Initial runner independently passes238/0, exit0/engine0. It also explicitly tests
an incorrect readiness interpretation, so it is not acceptance yet. Keep the
same three-file ownership; Codex added foraging_plan_runner.gd and owns it.

## Observed defects and actual existing rule
1. For a farmed citrus/scallop/etc, ingredient_unlocked remains true after stock
   is consumed. `_row.usable = unlocked || stock>0 || prepared` therefore calls
   an empty sample cupboard ready. Only permanent supplier ingredients may use
   unlocked alone. For farmed IDs use stock readiness (or a developed component
   for application/library navigation, which is different from tasting).
2. You correctly found that completed raw formulas can be applied at stock0,
   while EVERY NEW successful tasting still consumes samples by item_ids(config).
   Correct the interpretation of the initial contract: do NOT change domain
   rules. Add explicit row `required_samples` and `sample_ready`; minimum1 for
   a target, but if that ingredient is already in the actual current draft use
   its real count (repeat toppings included). `prepared` means a developed raw
   product can be browsed/applied, NOT that a new paid tasting is funded.
   Plan.ready and the board's ready count must use sample_ready, not unlocked or
   prepared alone. Show concise status e.g. research samples1/2 and separately
   developed broth1. Do not claim the entire recipe is valid just from these
   required-material rows. First-party existing GameState remains authority.
3. `_prepared_count` silently skips broken archive entries. On malformed recipe
   structure/canonical data return an explicit projection error (do not throw or
   silently produce a false usable fallback). Reuse Broth.error/Noodle.error.
4. Board GoalDevelop exists only for raw brood/noodle; ordinary farmed oil and
   toppings need a real explicit `이 재료로 실험` callback as well. Enable normal
   material development only when it is usable; completed raw product at stock0
   may still open its library, but show the actual tasting-sample shortage.
5. While caller busy, goal selection, source and develop buttons/callbacks must
   be inert/disabled. Rank/day/money blocked departures must still allow source
   browsing. Opening an item is never departure, tasting or application.

## Required meaningful tests
Replace the test that treats an unlocked sample with stock0 as ready. Include
actual public transaction fixtures, not only FakeState:
- Existing market_foraging_tests.ready() uses only public transactions and
  no files. Collect then consume sampled citrus in a real paid two-portion
  tasting, proving unlocked=true/stock0 but not sample_ready. Also stock1 vs
  current two-portion draft requires2. No direct money/rank/stock injection.
- Existing harbor_foraging_tests.ready() prepares rank2/suppliers legitimately.
  Collect real sardine sample, develop/apply raw broth, then consume the sample
  in an actual tasting. Archive remains while stock0: prepared=true, library
  usable=true, sample_ready=false. A later changed prototype still needs a sample.
- Explicit invalid archive error, duplicate/first witnesses, no input mutation,
  source browsing blocked by rank/day still emits IDs, busy emits none.
Tests run through Codex-owned foraging_plan_runner.gd; remain NOT RUN for Claude.

Same restricted/dontAsk file-only tools, strict empty MCP, no Bash/outside reads,
other file edits, Git, credentials or permission widening. Max10 requested turns.
Return compact Korean changed paths, exact unrun checks and limitations.
