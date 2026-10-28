# TASK
Make ingredient farming purposeful: choose an existing ramen experiment, inspect
its real material readiness and open the correct supplier/sampling/development path.

## CONTEXT
Human asks to continue after PR43 (main5b2caea). Menu development and ingredient
farming are the central priority. Existing direction_source always opens sampling,
even when required suppliers have not been found. Existing direction pages expose
long condition lists and no concise source/readiness board. Preserve the selected
food/wood/paper/navy/teal/gold interface and actual existing transactions.

## REQUIREMENTS
- Use the five existing RecipeDirections, not new recipes, ingredients or rewards.
  Show a short culinary brief and actual ingredient pictures, with one depth for
  source/preparation details. Never present an unmade finished bowl as an earned
  dish. No unknown compatibility, hidden score or guaranteed outcome preview.
- For each required ingredient distinguish permanent supplier discovery from
  consumable research samples, real stock and existing completed raw components.
  A developed sardine broth/buckwheat noodle can be applied to the bowl at stock0,
  but every new paid prototype still consumes samples under the existing rules.
  Distinguish completed-component application from tasting-sample readiness;
  repeat portions use the actual current draft's required count, minimum1.
- Source routing: rank/region requirements and actual supplier prerequisites come
  from current public GameState reviews; before both prerequisite suppliers are
  found, route to supplier mode. Afterwards use sampling mode. Never start or pay
  for a trip by selecting a goal/card. Show daily-use, money, rank, busy and full
  stock reasons without bypassing guards. Both materials of a multi-material
  direction remain visible, and a wrong reward cannot count as the target.
- Goal browsing and choosing only change existing session UI selection. No new
  save ledger, schema, economic rule, story/staff/city systems, assets or fonts.
  Preserve draft/lineage/records/knowledge/samples/money and all normal saves.
- New goals can lead back to a relevant real ingredient detail or completed raw
  component library without applying a recipe, spending, tasting or claiming.
  The actual controller recomputes readiness when a navigation callback executes.
- Reuse imported fonts, original ingredient art, explicit padding, full clickable
  cards and shared pressed/drag-cancel feedback. Support390x844/390x750/1280x800.

## OWNERSHIP / EDITABLE PATHS
Claude owns only these new files:
- game/scripts/ui/foraging_plan.gd (pure read-only projection)
- game/scripts/ui/foraging_goal_board.gd (actual native reusable board)
- game/tests/foraging_plan_tests.gd
Codex owns existing main/editor/exploration adapters, independent actual native
tests, builder registration and docs/evidence. Serial repo writers. Do not edit
other files. Study the relevant existing APIs yourself; reuse actual domain rules.

## CLAUDE INTERFACE
ForagingPlan extends RefCounted:
- static describe(state:Object,direction_id:String)->Dictionary with error,id,
  title,brief,tested and ingredients:Array. Each ingredient row has id,name,region,
  mode (supplier/sample),stock,prepared (completed applicable raw product exists),
  usable (permanent unlocked or sample stock or prepared),source_title,can_depart,
  reason,fee and a short status text. Display projected facts only; never mutate.
  Use explicit errors for bad IDs/input. Rank/fee/can_depart/reason must come from
  public state reviews; include caller-independent craft/service/trip busy states.
  For a sample region whose suppliers are missing, its source route is supplier.
- static catalog(state:Object)->Array of the five describe results in existing
  direction catalog order. Completion comes only from retained paid witnesses.
- A direction's raw broth/noodle source ingredient may be available as an
  immutable completed formula even at stock0. Use the real canonical base IDs.
ForagingGoalBoard extends VBoxContainer (embeddable in an existing padded/scrolling
native modal), present(state:Object, selected_id:String="", busy:bool=false).
Signals: target_selected(direction_id:String), source_requested(direction_id:String,
ingredient_id:String), develop_requested(direction_id:String,ingredient_id:String).
Use list->detail depth. Source callbacks only emit IDs, never perform a mutation.
Name buttons GoalOpen_<direction>, GoalSelect_<direction>, GoalSource_<ingredient>,
GoalDevelop_<ingredient>, GoalBoardBack. Selecting a target must not auto-navigate
or apply a recipe. All goal source buttons remain browsing actions even if departure
is currently blocked; show the blocker, allow the actual destination review.
Use actual existing ingredient art and styles (no ImageGen/new sprites). Avoid a
static preload cycle: Shared button factory is in service_result_view, which loads
the editor. Runtime-load that factory like JourneyCard if necessary. Actual press
must recolor child labels and drag cancellation must not emit navigation/success.
Keep text concise. No large explanatory paragraphs or numeric recipe-condition
solutions before trying the actual ingredient selection.

## CONSTRAINTS
File-only Read/Edit/Write/Glob/Grep; restricted/dontAsk, strict empty MCP. No Bash,
network/Git/credentials/global settings/subagents/outside reads/other edits. Do not
commit/push/deploy. Denied actions are not permission to widen access. All tests
are NOT RUN for Claude in this profile. Return a compact Korean handoff with
changed paths, real decisions, exact unrun commands, denials and limitations.

## ACCEPTANCE CRITERIA
Pure tests: new game, one/two suppliers, locked ranks, stock0/nonzero, repeat
portions, completed raw products stock0, active/canceled trip, daily departure,
bad IDs and saved-state round trips; projection cannot change any saved/transient
state. Board has actual full-card targets, concise bounds, accessible button
names and disabled selection during busy work.
Codex verifies source-matched actual native goal->supplier->paid trip->actual
reward->next prerequisite/sample->explicit material edit/taste with isolated data.
Test both required harbor materials, target/wrong receipts, restart, source paths,
read-only browse/press/drag, actual fees/samples/nonduplicated rewards and compact
geometry. Relevant exploration/payoff/editor/first-menu regressions pass. Human
fun/iPhone acceptance remain separate from native/layout automation.

## VERIFICATION
Independent code review, pure runner, fixed reviewed native fixture and existing
regressions using a fresh copied official Godot engine/PCK. Reject parser/engine
errors even at exit0. Verify source/PCK equality, strict vendor signature and
actual original PNGs. Capture a fresh previous-main baseline before integration.
No phone/live saves/old folders/preserved stash. Standing ready PR attachment,
matching-head squash merge and ff-only local main sync after acceptance.
