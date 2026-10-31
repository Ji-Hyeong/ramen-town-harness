# TASK
Connect a tasted foraging research direction to actual selling preparation/results.

## CONTEXT
Start from accepted main df3741c. Independent PR54 paid-result title remains frozen
awaiting its exact native pair approval. The eight ingredient-led directions have
paid tasting witnesses but no direct follow-up into the existing selling screen.
User prioritizes menu development including farming, fewer words, clear clickable
cards and actual outcome feedback. This is a bounded read-only bridge, not the
full future timed-order/reward system or completed campaign content.

## REQUIREMENTS / OWNERSHIP
- Codex only. No Claude/subagents. Stop before actual remaining quota reaches 30%.
- Add a pure UI projection over retained paid records, actual selling records and
  the latest settled receipt. Add one existing-style actionable card to a research
  direction's detail once it has a paid witness or a matching actual receipt.
- Distinguish: choose this kind of tasted menu for sale; matching menu already
  selected; actual latest completed sales count. Reading a draft or forecast must
  not count as tasted/sold. Zero completed units must not claim a sale.
- Name the actual paid/sold menu and version. Match full food config and record
  identity; unrelated or changed current draft/menu must not replace old receipts.
  If the paid notebook record was deleted, the actual immutable receipt may still
  describe its completed sale. Existing pre-expansion receipts omit config/id;
  bind only one retained immutable paid witness with matching name/version,
  tasted date no later than service, price/revenue and completed ingredient cost.
  Missing/deleted/ambiguous witnesses are unavailable. Never use a live draft or
  create a saved snapshot to fill missing old receipt config.
- Caption explicitly says recent sales; do not imply permanent completion or a
  new customer request. No accept/reward/save ledger, fees, demand modifiers,
  score bonuses, sample use, time limits, new schema or domain changes.
- The card opens existing guarded selling preparation only. Do not auto-pick or
  apply a recipe, change selling menus, start service, charge or grant knowledge.
- Preserve goal category/selection, ingredient source/develop routes, disabled
  busy controls, existing feedback, padded fonts and scroll/tap cancellation.
- Projection must update if only selling selection/last receipt changes while
  detail remains open. No per-frame full history evaluation or bulk archive reads.

## EDITABLE PATHS
game/scripts/ui/foraging_sales_followup.gd, foraging_goal_board.gd,
bowl_workbench.gd (board callback only), focused tests/UIDs, builder reviewed
fixture registry, docs/evidence/tasks/AGENTS. Preserve PR54's independent changes.

## VERIFICATION
Pure defensive tests: unknown id/state, untried/draft-only, actual paid match,
unrelated selected recipe, selected match, wrong record/config, zero sales,
single/multiple settled menus, valid older expanded receipt after record deletion,
strict retained-witness binding for original single receipts, absent evidence,
reused names/future tasting/price/cost/ambiguous witness and malformed values.
Actual public raw/farming checkpoint provenance, real paid regional experiments,
explicit sales selection and completed begin/settle service. Reopen/save/restart,
later draft changes and stale report/selection refresh. Keep live data untouched.
Native three sizes: before tasting/no extra card, choose/selected/sold, held/drag
cancel, pointer navigation into selling with whole ledger identical, busy control,
old paid record deletion and preserved actual report. Headless is not rendering.
Run relevant original foraging/goal tests and selected-goal regression. Build fresh
isolated native QA, request exact path at action time, then review/publish READY PR
and synchronize main only after actual acceptance. No iPhone installation.
