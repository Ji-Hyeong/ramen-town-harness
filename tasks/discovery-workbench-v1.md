# TASK
Connect farming to three distinguishable recipe directions and make food, not
administrative cards, lead the existing native Godot development experience.

## CONTEXT
User accepts the status-review recommendation and asks to continue. Current main
7fe2964 has26ingredients, market/harbor sampling, detailed dynamic48x32 dishes,
real tasting, retained-record research, swipe-safe disclosures and common input
feedback. Codex owns this work; Claude delegation and iPhone install are deferred.
Use existing native assets/components, not a browser/mobile-web replacement.

## REQUIREMENTS
- Larger centered live/result dishes, concise actual flavor/cost/time facts;
  expand navigation/details deliberately without removing any existing action.
- Three open-ended directions: citrus/light, sesame/rich, sardine/scallop/sea.
  They require real ingredient/profile differences, allow multiple solutions,
  show actual readiness and retained tasted evidence, and provide source/choice
  navigation. Reading or choosing a direction never fills a recipe or spends.
- First-in-retained-record result only after successful paid tasting; re-reading,
  price/name changes, canceled/failed work and reload do not fabricate discovery.
  No permanent collection, reward or new save field is introduced.
- Distinct ingredient/cooking/plating/completion cues; bounded original audio
  with visible mute. Swipe cancellation never plays committed tap feedback.
- Preserve recipe evaluator, real service timing, money/stock/save transactions,
  all old recipes and small service sprites. Clearly distinguish presentation
  duration from actual prep time. Failed-save warnings must stay visible.

## EDITABLE PATHS
game/scripts/domain/recipe_directions.gd (new pure read model);
game/scripts/ui/main.gd, action_feedback.gd, action_audio.gd;
game/assets/audio/, game/tools/generate_action_audio.py;
focused tests/UID/import metadata, relevant docs/evidence and AGENTS.md.
Do not alter GameState/evaluator/save schema/economy to make fixtures pass.

## ACCEPTANCE CRITERIA
Each direction has at least two different valid compositions and meaningful
profile/cost/time differences. Actual paid records are the only tasted evidence.
Input snapshots unchanged by reading/goal/navigation/mute; shortage/busy/cancel/
save failure stay truthful. Native two-size screenshots show food and actions
without overflow. Touch drag still scrolls across cards/images/buttons; canceled
swipes neither choose nor make a committed tap sound. All actions remain reachable.

## VERIFICATION
Pure independent evaluator fixtures; real routed pointer lifecycle and actual
sampling-to-tasting witnesses; focused packed/native capture, existing touch/depth/
expression/harbor regressions, full domain tests and full two-size layout. Use
isolated QA storage, reject script/engine errors even on exit0. Fresh native app
requires exact-app action-time confirmation; prepare all reviewable work first.
Publish ready PR and matching-head squash merge under standing user authorization
only after relevant tests and fresh visual acceptance. Do not claim human fun,
6-10hour completion, iPhone or audible device acceptance from automated checks.

## CURRENT OUTCOME
Implementation and independent headless/package verification are complete:
pure55, packed1896, expression/depth3724, harbor918, touch70, domain127/58423,
full landscape/portrait layout19496 all failure0/exit0/engine0. Original8audio
assets reproduce byte-equal;161sources/PCK976beff7 match fresh signed QA v1.
The human approved the exact QA v1 app. Fresh native OpenGL run
20261022T163531Z-15310 passed1980/0/exit0/engine0; all28 original landscape/
portrait PNGs were individually opened and reviewed. Five combined source/current,
focused bowl and three-dish/result comparisons were also opened. No actionable
P0/P1/P2 remains in this bounded flow; design-qa.md records P3 and acceptance limits.
All36 run files are privately preserved byte-equal. Postrun161sources/PCK976beff7/
engine hash match and vendor strict signature0. Public gallery, hashes and evidence
record current acceptance. Ready PR publication and matching-head squash merge use
standing authorization; final PR/merge identity is recorded in the chat and private
checkpoint. This completes the bounded iteration, not the whole game;
human enjoyment, audible-device acceptance and deferred iPhone work remain separate.
