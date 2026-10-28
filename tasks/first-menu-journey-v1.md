# TASK
Connect the early menu-development journey to actual sales and the next experiment.

## CONTEXT
Human approved the next task on 2026-10-28 after food/service expression PR42.
Start from clean synced main47099b. Preserve the selected food/wood/paper/navy/
teal/gold interface, raw broth/noodle creation, repeated toppings, and reveal
compatibility only after actual selection. This is a bounded early-play slice,
not a claim of observed30-minute fun or the full6-10h campaign.

## REQUIREMENTS
- Show one short current next action on the home screen. An existing customer's
  actual taste preference motivates the first dish; never pretend a story was
  accepted, a customer visited, or a reward was earned. Missing raw components,
  first tasting, selling selection and completed first sales must be distinguished.
- After actual sales offer three readable next choices: improve from an observed
  tasting, inspect ingredient exploration, or inspect existing research/growth.
  Navigation never starts/pays/settles/applies recipes automatically.
- A real tasted revision may compare its previous tasted configuration: food,
  taste, ingredient cost and prep time. No future score/compatibility prediction,
  guaranteed profit claim, fabricated baseline or stale sold-menu attribution.
- Keep all existing fees/samples/guards/transactions/schema18/save paths unchanged.
  No gating, forced tutorial, new rewards, customer/story/city systems or assets.
- Early guidance is derived from current state and survives restart without a new
  progress ledger. Busy actions are disabled. Existing save errors remain visible.
- Long names, portrait390x844/compact390x750/desktop1280x800 must remain usable;
  all buttons reuse click feedback and allow drag cancellation.

## OWNERSHIP / EDITABLE PATHS
Claude owns only these new files:
- game/scripts/ui/kitchen_journey.gd
- game/scripts/ui/journey_card.gd
- game/tests/kitchen_journey_tests.gd
Codex owns main/home/results/editor integration, actual QA, builder, docs/evidence.
Serial writers: Codex will not edit repo while Claude implementation runs.

## CLAUDE INTERFACE
`kitchen_journey.gd` is a pure RefCounted view, never mutates state or files:
- static describe(state:Object,busy:bool=false)->Dictionary with keys id,title,
  hint,action,customer,disabled. Allowed actions broth/noodle/compose/selling/
  goals/resume_exploration/wait. Prioritize an active expedition and busy state;
  then missing components, no paid tasting, no selling menu, first sale, goals.
  First-sale action opens the existing selling view, it does not begin service.
- static choices(state:Object)->Array of dictionaries with title,hint,action,
  customer. Actions improve/explore/research. Reuse actual public state and
  CustomerCatalog/observed tasting where appropriate; no hidden forecast.
- static comparison(record:Dictionary)->Dictionary with error,available,rows.
  Rows contain label,before,after,unit from a genuinely tasted record and its
  immutable comparison.prev_config, max4 concise metrics (unit cost/prep and
  up to2 changed taste axes). No fabricated zero baseline for first versions.
- Prefer cheap describe() reads; do not evaluate all records every frame.
`journey_card.gd` is an actual native reusable clickable card extending Control,
signal action_requested(action:String), method present(model:Dictionary).
Use existing Shared.make_button/Mock/Art/Pixel portrait image and real fonts,
minimum78px height, explicit frame padding, portrait40px and concise title16/
hint14, icon chevron. Name button JourneyAction and text JourneyTitle/JourneyHint.
It must be keyboard/click accessible, full card clickable, child mouse-ignore,
disabled while busy, support bounded width without border collisions, and never
own business state. Update only when model changes. No new visual direction.

## CONSTRAINTS
Claude file-only Read/Edit/Write/Glob/Grep, restricted/dontAsk, empty MCP; no Bash,
network/Git/credentials/settings/subagents/outside paths or instruction/doc edits.
No commit/push/deploy. Tests are NOT RUN in this profile; give exact commands.
Do not broaden permission after a denial. Non-obvious code needs precise comments.

## ACCEPTANCE CRITERIA
Independent pure tests prove state is byte-for-byte unchanged by projection and
navigation; staged new-game/old-save readiness, canceled/ongoing work, first sale,
missing/deleted records, real comparison/first-version absence and bad input.
Fresh actual native QA proves raw manufacture->compose->paid tasting->real sales
->chosen next goal, result money/one-time settlement/save/restart, no preselected
recipe/samples/spend on browse, disabled busy paths and compact geometry.
Relevant existing cycle/home/result/editor/touch regressions must pass. Inspect
actual current source-matched rendered PNGs against fresh prior-main captures.

## VERIFICATION
Codex reviews then imports/runs new pure test and reviewed native fixture from a
fresh copied official-engine/PCK app. Require exit0 and no engine/parse errors,
source/PCK equality, strict official engine signature and actual nonblank PNGs.
Use only isolated QA data; never normal saves/phone/old folders/preserved stash.
Do not count Mac/layout checks as iPhone or human fun acceptance. Publish ready
PR, attach it, matching-head squash and ff-only local main sync under standing
authorization after independent acceptance.

## OUTCOME
Implemented the derived home action, explicit unapplied-product resume, optional
three-goal depth, actual same-customer feedback, tasted food comparison and real
session-only previous-receipt comparison. No new domain rules/schema/rewards.
Claude owns projection/card/tests with a targeted correction; Codex refines the
unapplied step and integrates/independently verifies. The CLI success reports
44/27num_turns despite requested max30/10; raw counters are preserved, not quota
percentages or proof of cap semantics. Both calls exit0/success/no denials and
explicitly report tests NOT RUN; Codex executes all acceptance.

Final v4:383source hashes equal embedded/exported pack; native449+780+479+280+
532=2520checks/0failures/130PNG, exits0/engine0, post-run strict signature0.
Pure191/0, historical129tests59458/0, current finger49/0(layout), helper24/0.
Same-first-recipe baseline17/0/2PNG from previous main. Gallery12current+2before
originals opened individually. Preserve initial full-slot QA failure, weaker
v1 typography and v3 parse/zero-exit diagnostics; the builder now rejects those
engine errors before producing an app. Source/raw evidence stays private in
outputs/ramen-first-menu-journey-v1/final-v4. Phone/live saves/stash untouched.
Implementation and verification complete; ready publication/matching-head merge
and local main sync follow standing authorization. Human fun acceptance remains
separate from automated elapsed-time checks.
