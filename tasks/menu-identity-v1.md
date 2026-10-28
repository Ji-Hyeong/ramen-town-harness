# TASK
Make a tasted ramen's culinary identity memorable and carry it into actual sales
results. Extend the selected native design, without adding score bonuses, recipes,
currency rewards, inferred sales causes or a new saved collection ledger.

## CONTEXT
Human approved priority1 after PR44/main45f6058: menu discovery, tasting and sales
should communicate distinct results. Raw broth/noodle creation, ingredient-led food
appearance, known-only compatibility, actual customer tasting, real per-menu sales
and goal-driven farming already exist. Do not duplicate these or replace them with
large text panels. Existing RecipeDiscovery.describe already derives identity/tags;
reuse its thresholds/facts where appropriate rather than inventing another scoring
system. A descriptor is not a unique discovered recipe, achievement or earned bonus.

## REQUIREMENTS
- New compact native culinary identity card after a real paid tasting: actual food
  ingredients, at most2 clear character features, and actual tasting preference
  with customer portrait. Keep authored menu name untouched. A small descriptive
  heading may distinguish light/aromatic, rich, spicy or noodle-led dishes, but
  never claim every config has a unique identity or add invisible quality tiers.
- Snapshot facts come from the immutable tasted record, never the current edited
  draft. Recalculate actual recipe values using existing evaluators/canonical raw
  component APIs. Require a real-shaped positive record_id/version/name/config
  input and reject invalid data explicitly. Do not accept a bare draft as tasting.
- No compatibility/score/consumer preference for untried recipes. The host only
  calls describe on actual records. Price/name changes and topping order cannot
  alter culinary character; repeated portions, raw formulas and methods may.
- A separate sale projection uses a real per-menu completed receipt. Units and
  customer counts are actual orders. Menu margin is revenue minus ingredient cost,
  never net profit after guessed overhead. Average wait only if wait_total exists
  and units>0. Tasting preference is never called an observed sales reaction.
  No completed orders -> no invented best customer, satisfaction or wait.
- Historical receipt config may be absent/empty. Show unavailable identity instead
  of copying the current draft or pretending old menu facts can be recovered.
  Do not infer per-customer sales stars, which receipts do not preserve.
- Reuse existing actual ingredient/customer art, Pretendard, padded cream/navy/
  teal/gold frames and whole-card pressed/drag-cancel behavior. No new raster,
  hand-drawn placeholder, icon system, web scaffold, fonts or major layout redesign.
  Add semantic caption to distinguish tasting preference from actual purchase.
- Compact result card, deeper detail on deliberate click. Text readable at390x750,
  390x844/1280x800;44px+ targets, explicit padding. Shared.make_button is in
  service_result_view which loads bowl_workbench: runtime-load its factory to
  avoid a static preload cycle, as foraging_goal_board does.
- Reveal animation is explicit play_reveal(), called by host only on a genuinely
  completed tasting. present()/ready()/reopen/detail changes must not auto-replay
  a discovery reward. No game-state changes, callback rewards or auto-navigation.

## OWNERSHIP / EDITABLE PATHS
Claude owns ONLY these new files:
- game/scripts/ui/menu_identity.gd
- game/scripts/ui/menu_identity_card.gd
- game/tests/menu_identity_tests.gd
Codex owns existing bowl editor/service result/controller integration, independent
native acceptance, tests runner/builder registration and docs. Serial repo writers.
Do not edit other paths, AGENTS/CLAUDE/docs, existing domain/services/tests or UIDs.

## INTERFACE
MenuIdentity extends RefCounted, pure static methods:
- describe(record:Dictionary)->Dictionary: error,kind="tasting",available:bool,
  headline:String,features:Array[String](<=2),materials:Array[String](<=3 actual
  canonical catalog IDs),config:Dictionary(copy),record_id:int,recipe_name:String,
  version:int,unit_cost:int,prep_seconds:int,customers:Array of {id,name,score}.
  customers = actual best tasted preference(s), include all equal top scorers in
  catalog order rather than an arbitrary winner. Card may cap visible portraits
  but must state ties accurately. Validate saved record scores against evaluator
  if used; don't trust arbitrary score fields. Return compact explicit error on
  invalid record. All returned mutable data defensive copies.
- sales(row:Dictionary)->Dictionary: same identity fields (if known config) plus
  kind="sales",units:int,margin:int,has_wait:bool,average_wait:float,
  customers:Array of {id,name,units}. Only highest positive actual by_source
  purchaser count(s), stable ties; units0 ->[]. Missing/empty config is a valid
  unavailable identity, not missing recipe synthesized from row name.
  Real row fields: record_id,recipe_name,version,config,price,units,revenue,
  ingredient_cost,margin,by_source, optional wait_total. Single legacy report is
  normalized by service_result_view. No dependency on GameState or live controller.
MenuIdentityCard extends VBoxContainer:
- present(model:Dictionary) renders compact padded actual facts and portrait(s).
- signal details_requested() from one whole-card actual click target.
- play_reveal() explicit, reversible visual animation only; no auto-run in present.
- shown_model()->Dictionary returns defensive copy for verification.
- button.name="MenuIdentityOpen", title label="MenuIdentityTitle".
  If materials displayed, actual food textures via existing art patterns; no new
  Dish preload/static editor cycle. Reuse ingredient art helper patterns.
- Return a clearly visible error/unavailable note on bad/unavailable model.
  Disable detail on invalid input but historical unavailable receipt remains legible.

## CONSTRAINTS
File-only Read/Edit/Write/Glob/Grep, restricted/dontAsk, strict empty MCP. No Bash,
network/Git/credentials/global settings/subagents/outside-project reads/other edits.
Do not commit/push/deploy. Do not widen permissions after denial. All verification
is NOT RUN by Claude in this profile. Keep meaningful explanatory comments.

## ACCEPTANCE CRITERIA
Focused tests run(callback:Callable)->void on actual public GameState paid records:
light/raw broth, rich/raw broth, distinct raw noodle/real farmed ingredient cases;
name/price/order invariance vs repeated portions/formula/method differences; input
immutable, rejected malformed record/config/scores; customer ties and no false
purchase claims. Actual completed one/two-menu receipts, all0 units, wait absent,
unknown legacy config, mismatched counts, typed/invalid costs and defensive copies.
UI card mode captions, actual art, padded full target, pressed text/drag cancel,
unavailable/error note and explicit-only reveal should be verifiable.
Codex independently exercises actual paid taste->card->detail->actual sale->menu
detail, saved/reopened/edited-draft isolation, multiple distinct bowls and compact
viewport, real ledger/stock invariance for read-only actions and relevant regression.

## VERIFICATION
Claude reports changed files/decisions/UNRUN tests/denials compactly in Korean.
Codex independently runs pure tests and fresh source-matched official Godot native
QA; parser/engine errors reject even exit0. Compare fresh before/current originals,
verify source/PCK/copy signature, preserve domain/services/schema18/assets/live
saves/phone/old folders/stash. Standing READY PR/attach/exact-head squash/main sync
after acceptance. No fixed quota percentages, human fun or full campaign claim.
