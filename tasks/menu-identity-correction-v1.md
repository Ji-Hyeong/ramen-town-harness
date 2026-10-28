# TASK
Targeted test-only correction, same menu-identity session
412352bc-fb9e-4da0-b053-acc11c14cbe4. Resume after successful CLI handoff, NOT
accepted tests. Codex independently ran the real headless runner:
exit1, MENU IDENTITY PURE checks151/failures1 plus engine error.

## OBSERVED / EXPECTED
- menu_identity_tests.gd:380 intentionally passes malformed nonempty config to
  _row; _row:300 reads config["price"] before projection sees it, causing
  Invalid access to key price. Construct a valid receipt first, then replace only
  its config for that rejection case. Do not weaken production validation or
  make the test helper silently turn bad recipes into valid recipes.
- _ties_and_copies loops five3-choice axes (3^5=243) but asserts seen==81.
  Correct the count to243 and compare returned exact leader IDs against the real
  evaluator's equal-maximum set in catalog order. Existing check only checks
  returned subset sorting/equal scores, so missing equal leaders could pass.
- Add one real farmed-ingredient record via public supplier/sample transactions
  (existing harbor_foraging_tests.ready fixture is allowed), actual sardine sample
  claim, real raw sardine broth/noodle manufacture/application and paid taste.
  Check canonical identity and exact successful sample consumption. No hand-injected
  discovered/rank/stock values and no copied record pretending collection occurred.

## OWNERSHIP / CONSTRAINTS
Edit ONLY game/tests/menu_identity_tests.gd. Existing projection/card compile and
the first150 checks passed before the wrong loop count/runtime fixture error;
don't rewrite them. Keep original contract's restricted/dontAsk/file-only/empty
MCP/no outside reads/no Bash/network/Git rules. No Codex repo writes during this
call. Tests remain NOT RUN by Claude; Codex independently reruns the whole module.
Return compact changed path/decision/UNRUN tests/denials. No full-task retry.
