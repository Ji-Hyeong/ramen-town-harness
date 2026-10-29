# TASK
Show a short accurate consequence summary in the existing finished broth/noodle
comparison, so a known recipe with the same taste but extra cost/prep is readable.

## CONTEXT
Clean main6e0cbb4,430accepted runtime files/schema19. PR51's actual evaluator study
found e.g. pork_bone2→3 standard has equal profile/compat/customer scores in3fixed
bowls while cost+480/prep+24. This is a bounded observation, not universal taste
equality or a reason to raise caps. User prioritizes menu development, short copy,
selected native food/cream/navy/teal/gold design, details depth and tactile cards.
User resumed sustained development and the5hour quota actually reset (used1%).
Keep the earlier30%remaining stop threshold for this run; reserve completion time.

## OWNERSHIP
Claude ONLY:
- new game/scripts/ui/recipe_change_summary.gd (pure presentation projection)
- new game/tests/recipe_change_summary_tests.gd (pure run(check:Callable)->void)
Codex owns existing native integration, actual production and knowledge fixtures,
baseline/native QA, source/state preservation, docs/evidence/Git. Serial writers.
No edits to other files/UIDs/AGENTS/settings/Git. File-only tools; max30turn.

## REQUIREMENTS
- Existing Comparison/GameState/Evaluator/Knowledge are the source of truth.
  Do NOT change them, save fields/economy/recipe identity/caps/compatibility rules.
- Suggested pure API project(before:Dictionary,after:Dictionary,before_known:bool,
  after_known:bool)->Dictionary. Report exact API/result fields. Use actual
  evaluator-shaped dictionaries, defensive copies and meaningful comments.
- The host independently obtains both known flags using state.recipe_known for
  the actual current bowl and candidate. A comparison never grants knowledge.
- Only when BOTH are known may a headline assert taste equal/changed, compare
  compatibility, customer scores or infer quality. Every other flag combination
  returns a neutral short prompt (e.g. 담은 뒤 맛 비교), no hidden score/compat/
  equality/cap info even in result data, hidden labels or explanatory strings.
  Public cost/prep changes may be returned for valid complete evaluations because
  the existing UI already shows those without unlocking taste knowledge.
- Exact taste equality means all5profile axes, compat_total, the SAME customer
  ID set and each customer's score, plus average_score agree. Customer order must
  not matter. Price/cost/prep/name/recipe text aren't taste. No average-only test.
- For known exact-equal taste, distinguish unchanged economics, increased burden,
  savings and mixed cost/time tradeoffs without calling one universally better.
  Mixed cost↑/time↓ and cost↓/time↑ are tradeoffs, not pure loss/saving.
- Changed taste never means universally better/worse: use neutral direction copy.
  Do not invent a saturation/cap cause just because profiles match. Scope equality
  to THIS complete bowl. No automatic recipe application, selection, payment,
  gifting, celebration, or modification of an input.
- Concise Korean title (aim<=20characters), compact optional reason for disclosure,
  signed actual cost/prep deltas if legitimate. No paragraphs on the main screen.
- Malformed/error/missing known evaluations, impossible/non-integral/bool values,
  duplicate/missing customer IDs must be explicit error/unavailable, not a success
  classification. Unknown handling must never leak evaluator-sensitive fields.
  Follow existing pure UI helper conventions and reuse DataCheck where sensible.

## TESTS / ACCEPTANCE
Pure focused: all4known flag pairs; same taste with same/higher/lower/mixed costs
and prep; per-axis/compat/per-customer changes even when average equal; customer
reordering; no unknown info leakage; no input mutation; deep-copy output; invalid
whole/bool/fraction/negative/missing/duplicate/error/empty inputs. Use valid real
Evaluator results for positive cases, crafted malformed fixtures explicitly.
Codex independently runs actual raw manufacture/selection scenarios: pork2 vs3
and a genuinely changed broth/noodle, unknown→explicit known→saved restart,
zero transactions or knowledge change by browsing, current/candidate identity.
Native3sizes show short summary/expanded details, pressed/tap/scroll cancellation,
existing explicit use/reload and warnings remain reachable. Preserve all430old
runtime files except scoped integration/tests; no asset or live-save/phone change.

## RETURN / CONSTRAINTS
Read/Edit/Write/Glob/Grep only, restricted/dontAsk/strict empty MCP. No Bash,
network, subagents, credentials, outside-project reads, Git/push/deploy. Tests are
UNRUN until Codex actually runs them. Return owned paths/API/wording/UNRUN/denials.
