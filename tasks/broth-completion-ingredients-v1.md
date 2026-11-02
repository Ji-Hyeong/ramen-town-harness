# TASK
Show the actually completed raw broth formula on its completion screen.

## CONTEXT
Base main8957192, PR66 ingredient library accepted. Its fresh completion capture
still shows only a generic pot/name and costs; the player's repeated portions
are visible only after navigating back to the library. Carry the same owned
ingredient cues into the result so manufacturing has an identifiable outcome.

## REQUIREMENTS
Reuse existing grouped pantry icon/name/portion cues. Show the owned extraction
method, preserve explicit use/library actions and once-only completion payment.
Allow the existing scroll body to grow with long formulas; keep the fixed use
action readable/reachable. No recipe score/compatibility reveal or hidden use.

## CONSTRAINTS
Runtime/QA editable: game/scripts/ui/bowl_workbench.gd and game/tests/broth_shelf_qa.gd.
Task/report/evidence/AGENTS/lossless history/original captures may change. No new
assets, domain, save schema, prices, catalog, phone/live saves, Claude or agents.
Do not alter the already-approved PR66 app or old screenshots.

## ACCEPTANCE CRITERIA
Actual paid61st broth completion displays exact earned raw ingredients, repeated
amounts and method; opening/dragging the result cannot charge again or apply it.
All three screen sizes retain meaningful breathing room and fixed primary use.
Five-portion centered layout probes remain explicitly synthetic, never claimed
as earned volume. Actual shelf domain, full UI/save/refusal/recovery/restart and
old component/formula flows pass; whole saves match PR66 native/headless bytes.
Fresh exact-app approval and all native captures reviewed before main merge.

## VERIFICATION
Frozen build_qa_app.py --fixture broth-shelf; run frozen broth_shelf_qa.gd with
--layout-only and isolated --qa-out. Existing domain425/component315/formula635.
Then approved native run, mechanical auditor with pinned commit/PCK/engine,
three profiles, whole save byte comparisons and all screenshots directly reviewed.

Documentation clarification: root README.md and game/README.md may gain a short
current-accepted-status section, preserving dated history. Their first entries
still described accepted comparison work as approval-pending and hid the newer
save21 archive/ingredient cues and mechanical-audit workflow.

## HEADLESS ACCEPTANCE
Frozen UI2831/domain425/component315/formula635 all0failures/exit0/errors-warnings0.
Source474/PCK/official engine signature exact; only UI and QA differ from8957192.
Three whole saved states equal accepted PR66 native bytes. Centered5portion/
long-name probes are synthetic; actual61st completion verifies earned formula
and read-only dragging. Exact v1 native app approval requested, no launch/merge.

## NATIVE ACCEPTANCE
Exact v1 approved; fresh run20261102T111940Z-74052 passes2921/0, actual exit0,
engine errors/warnings0. All30captures reviewed via9sheets and before completion.
Earned amounts/method, result spacing, explicit actions and shelf/save flows stay
readable. Mechanical auditor pins4cd6f56/474source/PCK/engine/signature/capture
structure and time. Three whole saves equal old native and three more equal new
headless. Publish3unmodified originals. All criteria complete; exact-head PR68
may merge. iPhone, human fun and campaign remain separate.
