# TASK
Fix finger scrolling across the entire scrollable content on iPhone, especially
when the finger starts over cards, text or buttons rather than the scrollbar.

## CONTEXT
Start from main f11e5d2 after merged PR14. User completed developer-app trust;
actual iPhone15Pro/iOS26.6.2 app launch now succeeds. Xcode captures show the game
and research tab, but the user reports severely uncomfortable dragging and
explicitly requires dragging anywhere in scrollable content. Previous QA moved
scroll offsets programmatically and did not validate real gesture routing.

## REQUIREMENTS
- Reproduce event propagation using real Godot viewport input dispatch before
  choosing a fix. Support dragging on cards, labels, gaps and enabled buttons.
- A normal tap or small finger jitter still activates a button exactly once;
  swiping cancels the pending button action and must not purchase or submit.
- Retain native scrolling/inertia and desktop wheel input where feasible.
- Do not change game economics, progression, save format or unrelated screens.
- Preserve the user's real iPhone/Mac save data. Reinstall the same development
  bundle with a verified profile; never uninstall/reset the app. Back up this
  app's save before replacing/terminating it when accessible.

## CONSTRAINTS
Codex implements. Editable paths: scoped UI helpers/main.gd, focused gesture
tests and their required test integration, iOS preparation tooling only if
needed, relevant docs/evidence/AGENTS and this contract. No broad UI redesign,
additional features, OS/security changes or unrelated phone data inspection.
Use current actual team/device privately; no IDs, profiles or accounts in Git.

## ACCEPTANCE CRITERIA
Gesture dispatch tests cover content/button starts, tiny jitter tap, canceled
tap on drag, both directions, inertia/cancellation and desktop wheel behavior.
Relevant regression checks pass. Build/sign/install corrected iPhone app without
losing saves, inspect actual screen and obtain honest physical drag feedback;
automated offsets or screenshots alone are not touch acceptance.

## VERIFICATION
Use isolated test saves and reviewed Godot4.7.2. Keep failing baseline evidence,
then rerun the same routed input gestures against the corrected UI. Check app
pack/profile/signature before same-bundle device update. Publish ready PR under
standing merge authorization only for the explicitly verified scope, recording
remaining physical play-feel checks accurately.

## OUTCOME
Reproduced native event blocking; changed only production UI input routing and
added a scoped LineEdit helper. Same66 routed/native-touch checks: old main32
failures/exit1, corrected0/exit0/no engine errors.125domain tests/58,220checks
pass. Full layout outcome is recorded in evidence/ios-touch-scroll-v1.json.

Fresh99-source export and signed device build pass. Existing94non-UI sources
match the accepted95-source baseline. Actual signature/profile/device/team/app
coherence and embedded pack equality pass. Same-bundle update/install and launch
both exit0/JSONsuccess; this app's save and backup were backed up immediately
before replacement and remain byte-identical after installation. No uninstall.
Actual1179x2556 game-launch screenshot reviewed. Durable signed app stays private.

The user directly confirmed on the installed corrected iPhone build that swipes
anywhere scroll and taps work normally. Physical swipe/tap acceptance therefore
passes based on actual user feedback, not on automated checks. Actual virtual
keyboard/Korean composition and lifecycle checks remain pending. A name-field drag has no custom fling; ordinary content retains
native ScrollContainer inertia. Publish only this explicitly verified fix scope
under standing ready-PR/merge authorization; do not claim complete mobile QA.
