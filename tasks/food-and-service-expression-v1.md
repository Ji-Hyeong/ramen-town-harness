# Food and service expression V1

## TASK
The human approved the next priority: distinguish actual ingredient-led food results and strengthen visible cooking/serving/customer reactions in the existing shop. Preserve the selected original art/layout and native game. This bounded task does not add content, economy, employees, city systems, rewards or save fields.

## CONTEXT
Base mainb517337 has raw broth/noodle manufacture, actual canonical recipes and completed first-development flow. The accepted layered food image still makes many raw blends look alike; the small service scene already moves real customers/staff and bubbles, but state changes are quiet. Improve their expression, not an unrelated UI redesign. Existing code is the visual target; original PNGs/fonts remain byte-identical.

## REQUIREMENTS / CLAUDE OWNERSHIP
Implement substantial food appearance in ONLY:
- game/scripts/ui/recipe_appearance.gd (new)
- game/scripts/ui/layered_recipe_view.gd
- game/scripts/ui/bowl_broth_tint.gdshader
- game/tests/recipe_appearance_tests.gd (new)

Use the actual applied config's broth_recipe/noodle_recipe, tare, oil and existing cut-specific original bowl textures. At least clear seafood/kelp, golden chicken, creamy bone, chili-red and herb/oil-led examples should be meaningfully distinguishable at phone size. Raw quantities/methods can modulate a bounded appearance; do not invent scores/compatibility/rarity labels or imply every combination has unique art. Do not replace originals with primitive fake food, tint the whole ceramic or independently layered toppings, or draw unrelated new garnish ingredients. Preserve transparent exterior/atlas handling, buckwheat cutout, existing repeated portions, steam/addition, mouse-ignore behavior and sizing. Use code-native shader/compositing to extend the existing rendering system; no imagegen or PNG editing needed.

Provide a pure read-only helper RecipeAppearance.profile(config) returning at minimum {crafted:bool, broth_color:Color}; other parameters are yours to design. Codex will use broth_color only when crafted is true for tiny service food. Preserve exact legacy rendering paths when both raw recipe keys are absent. Shader changes must have a disabled/default branch that reproduces existing legacy shader behavior. A color-only global hue wash is not enough: make the selected soup and actual oil/noodle identity readable while retaining food texture/detail and the red ceramic. Do not couple presentation to mutable state, randomness or current draft outside the supplied config.

Tests meaningfully prove determinism/input immutability, actual source differences including the same base ID with different raw composition/method, cut/flour/water expression where supported, repeated topping preservation, legacy default branch and no gameplay/knowledge writes. Tests remain isolated; file tools only, NOT RUN report. Do not expand into generic exhaustive implementation mirrors. Explain non-obvious masks/atlas/legacy invariants in concise comments.

## CODEX OWNERSHIP AFTER HANDOFF
Integrate the same crafted broth identity into tiny service bowls. Add visible, bounded state-linked kitchen/serving/first-bite/reaction feedback from the actual ServiceSession snapshot; no fake diners, randomized praise, per-frame burst replay or transactions in rendering. Preserve integer pixel scaling, furniture/person depth, truthful idle/busy/hired states and scene input. Actual native dish comparison and service stage captures, same-state before/current, independent tests and relevant regressions decide acceptance. Codex will not edit repository files while Claude is writing.

## CONSTRAINTS
Claude: file-only Read/Edit/Write/Glob/Grep, restricted/dontAsk, empty MCP; no Bash/network/Git/credentials/global config/subagents/assets/instructions/docs/other paths. No commit/push/deploy. Do not edit domain/services/schema18 or game rules. Return changed paths, decisions, known limitations and tests NOT RUN. Codex independently imports and runs the code, requests a targeted correction on actual defects, and preserves rejected diagnostics.

## ACCEPTANCE / VERIFICATION
Real native390x844/1280x800 food variants visibly differ for actual ingredient choices, without changing ceramic/toppings or leaking unknown compatibility. Real service states show cooking/serving/eating/reaction events once and reset safely on new sessions; reading/drawing cannot affect money/time/orders. Source/pack equality, nonblank captures, actual exit0 and no engine errors, relevant domain/cycle/editor/home/service-result regressions, compact input checks and strict official engine signatures are required. No live saves/iPhone/old folders/stash. Standing ready PR, matching-head squash and main sync follow bounded acceptance.

## ACCEPTED RESULT
Completed2026-10-28. Claude implements actual profile/layer/shader/tests and two corrections; Codex refines shader multiplication/pixel verification, integrates small food/real service cues and optional portrait kitchen close view, independently verifies. Final profile's crafted flag means RAW BROTH; noodle_crafted is independent, preserving mixed historical soup. Optional outside-project capture reads were denied and cancelled; no permission expansion/retry, subsequent project-only read-only closeout clean. Preserve earlier non-clean call diagnostics; do not claim Claude saw or tested native frames.

Same375sources/PCKa1596823dcdbb9229ca9d36748985fbe0a56c237706fc58eba8ce21897bb5aa5: native2397/0/122PNG, extra actual app326/0/22PNG, accepted exits0/engine0; pure63/0+14/0,129tests59458/0, touch49/0(layout), helper23/0. Legacy1080tiny sprites and controlled native legacy dish match. Actual GPU ceramic body/topping guards pass. Domain/services66, schema18, original assets125 unchanged. Publish14 originals and review3 regression originals; not all122 manually opened. Source/pack/logs/private implementation evidence archived outputs/ramen-food-and-service-expression-v1/final-v4. Delivery uses standing ready PR/matching-head squash/main sync; actual publication recorded privately after success. Phone/live saves/stash untouched. Limits in game/docs/FOOD_SERVICE_EXPRESSION_V1.md.
