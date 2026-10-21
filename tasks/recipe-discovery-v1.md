# TASK
Make menu development a directed experiment: distinct ramen identities, a small
research map tied to real ingredient sources, and comparison with tasted menus.
User rejected current depth and explicitly deferred iPhone connection/install.
This extends unmerged PR16; keep its reviewed topping/effect work intact.

## CONTEXT
Codex owns UI, integration and independent verification. User explicitly asks to
work with Claude too. Claude owns only the bounded pure discovery component and
its focused tests, using file tools. No concurrent repository writers.

## REQUIREMENTS
- Pure module `game/scripts/domain/recipe_discovery.gd`, no state/schema writes.
- `describe(config: Dictionary) -> Dictionary`: validate via existing DataCheck;
  return `{error, title, subtitle, tags}`. Title is a suggested ramen identity
  derived from actual broth/tare/oil/topping portions, never overwrites user name.
  Tags use existing evaluated taste/process facts, not invented score bonuses.
  Price/name cannot create another identity. Repeated portions must be reflected.
- `catalog() -> Array`: eight original research directions, each includes
  `id`, `title`, `hint`, `origin`, and documented actual match criteria. Include
  basic accessible routes, repeat-topping route, discovered clam/mushroom route,
  and both farmed ingredients (citrus peel / roasted sesame oil). Requirements
  should allow more than a single exact full recipe; these are research themes,
  not a claim of eight distinct playable content systems.
- `matched_ids(config: Dictionary) -> Array[String]`: actual matching themes,
  price-independent, supports repeated portions, invalid configs match nothing.
- `pages(records: Array, draft: Dictionary, available: Array[String]) -> Array`:
  one dictionary per catalog entry, adding `tested` (any retained actual tasted
  record config matches), `ready` (draft matches), `progress`/`total` (actual
  satisfied criteria count), `missing` (Array[String] human hints for unmet
  criteria), `unavailable` (Array[String] ingredient IDs still unavailable).
  Do not count un-tasted drafts as tested, double count repeated records, infer
  success from price/name, or mutate any input/catalog. Explanatory metadata is
  derived from currently retained notebook records; deletion can remove tested
  status. UI explicitly says so; no persistent lifetime collection is claimed.
- Error handling explicit, typed GDScript consistent with repo; comments explain
  matching/identity semantics. Reuse catalog/evaluator instead of copying axes.
- Focused SceneTree tests `game/tests/recipe_discovery_tests.gd`: known witnesses
  for all eight themes; missing/repeated/price/order/process/invalid input,
  draft-vs-tasted distinction, deletion and pure input invariance. Exit1 on errors.

## EDITABLE PATHS FOR CLAUDE
Only `game/scripts/domain/recipe_discovery.gd` and
`game/tests/recipe_discovery_tests.gd`. Do NOT edit UI, existing domain/state,
docs, AGENTS, tools or fixtures. No Bash, Git, credentials, network tools or
subagents. Do not execute tests: Codex runs them independently after handoff.
Inspect only relevant existing catalog/evaluator/check/process and tests.

## CODEX INTEGRATION
Workbench: descriptive bowl title/tags, selectable research target with real
requirements/source link, actual draft-vs-selected-record flavor/cost/time change.
Notebook: expandable research map, tasted/untried/needs-farming distinction.
Feedback: actual newly matched themes vs before successful tasting, derived from
retained records; unchanged save schema/economy, no fabricated rewards.
Preserve swipe cancellation, input-transparent effects and old saves/scores.

## VERIFICATION
Codex reviews exact diff + runs new pure tests, focused real-scene goal/comparison/
taste/cancel/restart/save-failure tests, existing domain and touch regressions,
two-size layout and fresh native render if approved at action time. iPhone
installation explicitly deferred by user, not a development blocker. No real
player-save writes or stale screenshot acceptance. Report actual usage fields
from Claude response only, never convert tokens to quota percentages.

## CLAUDE HANDOFF
Compact report of changed files, APIs/criteria, unrun tests, permission denials,
and risks. Do not paste full source or claim UI/save/renderer completion.

## CURRENT OUTCOME
Claude owns discovery module/core tests and actual target/map component (two
restricted successful calls18/17turns, no denials); Codex owns main integration,
comparison/fixed tasting/refusal/cache and real-scene regression tests. Existing
schema12/evaluator/economy untouched:102of103 prior files equal, only main changed;
eight new source/UID files, total111 bundled. All tests independently run by Codex:
277pure,1694scene and actual PCK,70touch,126domain/58238checks, full layout18576;
failures0/exit0/engine-errors0. Initial deletion fixture expectation and dynamic
typed-array scene errors rejected and corrected; original logs preserved.
Fresh exact native QA prepared/source/signature verified, launch approval pending.
iPhone installation explicitly deferred, not a development blocker. Keep public
PR16 ready/non-draft; actual visual acceptance/main merge not yet claimed.
