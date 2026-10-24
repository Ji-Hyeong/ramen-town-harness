# TASK
Connect a developed menu to readable actual service results.

## CONTEXT
The human approved the next priority after PR29: show how developed dishes sell,
which customers eat them, and what money remains. Start from main97dd063.
Reuse the accepted native paper/navy/teal/gold design, actual food and fonts.
Human steering: strengthen design elements and match the selected mock. Actual
sold dishes, wood context, food cards, coin hierarchy, customer portraits and
clear tinted affordances must carry the result, not a plain wall of text.

## REQUIREMENTS
- Replace the dense settlement modal with a responsive actual report view:
  net result first, sales/units, actual per-menu rows, customer and cost details.
- Use existing settled report data and actual just-finished session evidence.
  Menu contribution excludes common overhead; deduct overhead exactly once.
  Distinguish completed orders, forecast demand, recipe taste and actual stars.
- Show a dish only from its actual sold snapshot. Never substitute today's
  draft for an old sold menu. Stored single-menu reports lack full configs and
  live stars/turnaways; omit unavailable information or label its absence.
- Reopen the last report from the existing service tab without settling again.
  Details, scrolling, back, dismiss and menu-development handoff must work.
- Preserve settlement/save/abort rules and clear full save-failure warnings.
  Add meaningful completed-result reveal and existing tap/drag feedback.

## CONSTRAINTS / EDITABLE PATHS
UI view/projection/controller adapters, focused QA and related docs/evidence.
No domain/services/schema/balance/asset/font changes, regular saves, phone,
Claude, deployment, old Documents repo or unfinished stash restoration.

## ACCEPTANCE CRITERIA
Fresh unchanged native baseline precedes runtime changes. Final native renders
at390x844/1280x800 and compact390x750 layout cover single and actual expanded
two-menu service, drilldowns, dismiss/reopen/restart, loss/zero-sale values,
abort, stale/current-draft independence, save failure and once-only settlement.
Compare actual same-state baseline/current and selected design-system source.
No normal saves; all fixtures use new isolated absolute directories.

## VERIFICATION
Review QA scripts before execution. Existing build_qa_app.py with bowl-editor
fixture freezes allowed sources. Dedicated service_result_qa.gd and relevant
editor/payoff regression use that exact pack. Explicitly reject engine errors
even on exit0. Verify source/PCK/signature, screenshots, links and Git diff.
Prepare ready PR, attach and expected-head squash merge after final acceptance
under standing human authorization. Terminal native QA is already authorized.

## OUTCOME
Complete: native result summary, actual food/coin/wood/portrait hierarchy,
per-menu/customer/cost/receipt depths, last-report reopening and draft-preserving
development handoff. Actual pointer tests exposed sibling input order and
frame-dependent editor handoff; both fixed. Nativev1 pale arrows/long desktop
rows corrected in finalv2; no-sale satisfaction is explicitly unaggregated.

Final289-source packv2: actual native service466/0 and editor524/0, exit0/errors0.
Same-pack compact layout service202/0 and payoff226/0, exit0. Fresh unchanged
previous-main285-source baseline108/0. Exact source/PCK/engine hash and post-run
strict signature verified. Actual same-state before/after, focused affordance
and design-system comparisons reviewed; manual scope/limits in design-qa.md.
Rejected setup/product diagnostics and full final isolated outputs preserved.
No ordinary saves, phone, Claude, original assets or domain rules changed.
Ready publication and expected-head merge follow standing authorization.
